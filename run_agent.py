#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-License-Identifier: Apache-2.0

import argparse
import traceback

from loop_rate_limiters import RateLimiter
from upkie.envs.backends import SpineBackend
from upkie.logging import logger
from upkie.utils.raspi import configure_agent_process, on_raspi

from pinker_balancer import WholeBodyController


def parse_command_line_arguments() -> argparse.Namespace:
    """Parse command line arguments.

    Returns:
        Command-line arguments.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--visualize",
        help="Publish robot visualization to Viser for debugging",
        default=False,
        action="store_true",
    )
    return parser.parse_args()


def run(
    backend: SpineBackend,
    controller: WholeBodyController,
    frequency: float = 200.0,
) -> None:
    """Read observations and send actions to the spine.

    Args:
        backend: Spine backend.
        controller: Whole-body controller.
        frequency: Control frequency in Hz.
    """
    dt = 1.0 / frequency
    rate = RateLimiter(frequency, "controller")
    observation = backend.reset()
    while True:
        action = controller.cycle(observation, dt)
        observation = backend.step(action)
        rate.sleep()


if __name__ == "__main__":
    args = parse_command_line_arguments()

    # On Raspberry Pi, configure the process to run on a separate CPU core
    if on_raspi():
        configure_agent_process()

    controller = WholeBodyController(visualize=args.visualize)
    wheel_controller = controller.wheel_controller
    wheel_radius = wheel_controller.wheel_radius
    left_sign: float = 1.0 if wheel_controller.left_wheeled else -1.0
    right_sign = -left_sign
    spine_config = {
        "bullet": {
            "reset": {
                "joint_configuration": [0.1, 0.2, 0.0, 0.1, 0.2, 0.0],
            },
        },
        "wheel_odometry": {
            "signed_radius": {
                "left_wheel": left_sign * wheel_radius,
                "right_wheel": right_sign * wheel_radius,
            },
        },
    }
    backend = SpineBackend(spine_config=spine_config)

    max_rc_vel = wheel_controller.remote_control.max_linear_velocity
    max_ground_vel = wheel_controller.sagittal_balancer.max_ground_velocity
    logger.info(f"Knees bend {controller.height_controller.knee_side}")
    logger.info(f"Max. remote-control velocity: {max_rc_vel} m/s")
    logger.info(f"Max. commanded velocity: {max_ground_vel} m/s")
    logger.info(f"Wheel radius: {wheel_radius} m")
    logger.info(f"Additional spine config:\n\n{spine_config}\n\n")

    try:
        run(backend, controller)
    except KeyboardInterrupt:
        logger.info("Caught a keyboard interrupt")
    except Exception:
        logger.error("Controller raised an exception")
        print("")
        traceback.print_exc()
        print("")

    logger.info("Stopping the spine...")
    try:
        backend.close()
    except Exception:
        logger.error("Error while stopping the spine!")
        print("")
        traceback.print_exc()
        print("")
