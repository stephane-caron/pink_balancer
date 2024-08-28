#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-License-Identifier: Apache-2.0
# Copyright 2023 Inria

"""Wheel balancing using model predictive control with the ProxQP solver."""

import gin
import numpy as np
from qpmpc import MPCQP, Plan
from qpmpc.systems import WheeledInvertedPendulum
from qpsolvers import solve_problem
from upkie.utils.clamp import clamp_and_warn
from upkie.utils.filters import low_pass_filter
from upkie.utils.spdlog import logging

from .proxqp_workspace import ProxQPWorkspace
from .sagittal_balancer import SagittalBalancer


@gin.configurable
class MPCBalancer(SagittalBalancer):
    def __init__(
        self,
        leg_length: float,
        nb_timesteps: int,
        sampling_period: float,
        stage_input_cost_weight: float,
        stage_state_cost_weight: float,
        terminal_cost_weight: float,
        warm_start: bool,
    ):
        """
        Initialize balancer.

        Args:
            leg_length: Leg length in [m].
            stage_input_cost_weight: Weight for the stage input cost.
            stage_state_cost_weight: Weight for the stage state cost.
            terminal_cost_weight: Weight for the terminal cost.
            warm_start: If set, use the warm-starting feature of ProxQP.
        """
        super().__init__()
        max_ground_accel = self.max_ground_accel  # from parent ctor
        pendulum = WheeledInvertedPendulum(
            length=leg_length,
            max_ground_accel=max_ground_accel,
            nb_timesteps=nb_timesteps,
            sampling_period=sampling_period,
        )
        mpc_problem = pendulum.build_mpc_problem(
            terminal_cost_weight=terminal_cost_weight,
            stage_state_cost_weight=stage_state_cost_weight,
            stage_input_cost_weight=stage_input_cost_weight,
        )
        mpc_problem.initial_state = np.zeros(4)
        mpc_qp = MPCQP(mpc_problem)
        workspace = ProxQPWorkspace(mpc_qp)
        self.commanded_velocity = 0.0
        self.mpc_problem = mpc_problem
        self.mpc_qp = mpc_qp
        self.pendulum = pendulum
        self.warm_start = warm_start
        self.workspace = workspace

    def compute_ground_velocity(
        self,
        target_ground_velocity: float,  # TODO(scaron): use this
        observation: dict,
        dt: float,
    ) -> float:
        """
        Compute a new ground velocity.

        Args:
            target_ground_velocity: Target ground velocity in [m] / [s].
            observation: Latest observation dictionary.
            dt: Time in [s] until next cycle.

        Returns:
            New ground velocity, in [m] / [s].
        """
        floor_contact = observation["floor_contact"]["contact"]
        base_orientation = observation["base_orientation"]
        base_pitch = base_orientation["pitch"]
        base_angular_velocity = base_orientation["angular_velocity"][1]
        ground_position = observation["wheel_odometry"]["position"]
        ground_velocity = observation["wheel_odometry"]["velocity"]

        initial_state = np.array(
            [
                ground_position,
                base_pitch,
                ground_velocity,
                base_angular_velocity,
            ]
        )

        nx = WheeledInvertedPendulum.STATE_DIM
        target_states = np.zeros((self.pendulum.nb_timesteps + 1) * nx)
        self.mpc_problem.update_initial_state(initial_state)
        self.mpc_problem.update_goal_state(target_states[-nx:])
        self.mpc_problem.update_target_states(target_states[:-nx])

        self.mpc_qp.update_cost_vector(self.mpc_problem)
        if self.warm_start:
            qpsol = self.workspace.solve(self.mpc_qp)
        else:  # not self.warm_start
            qpsol = solve_problem(self.mpc_qp.problem, solver="proxqp")
        if not qpsol.found:
            logging.warn("No solution found to the MPC problem")
        plan = Plan(self.mpc_problem, qpsol)

        if not floor_contact:
            self.commanded_velocity = low_pass_filter(
                prev_output=self.commanded_velocity,
                cutoff_period=0.1,
                new_input=0.0,
                dt=dt,
            )
        elif plan.is_empty:
            logging.error("Solver found no solution to the MPC problem")
            logging.info("Re-sending previous ground velocity")
        else:  # plan was found
            self.pendulum.state = initial_state
            commanded_accel = plan.first_input[0]
            self.commanded_velocity = clamp_and_warn(
                self.commanded_velocity + commanded_accel * dt / 2.0,
                lower=-1.0,
                upper=+1.0,
                label="commanded_velocity",
            )
        return self.commanded_velocity

    def log(self) -> dict:
        """
        Log internal state to a dictionary.

        Returns:
            Log data as a dictionary.
        """
        return {
            "commanded_velocity": self.commanded_velocity,
        }
