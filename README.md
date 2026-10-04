# Pinker balancer

[![upkie](https://img.shields.io/badge/upkie-13.0.1-d6336c)](https://github.com/upkie/upkie/tree/v13.0.1)

An agent for [Upkie](https://github.com/upkie/upkie/) that combines wheeled balancing with inverse kinematics computed by [Pinker](https://github.com/pink-kinematics/pinker).

## Installation

This agent uses [pixi](https://pixi.sh/latest/#installation) to manage its Python environment, both on your machine and on your Upkie. The first installation compiles Pinker's C extension, which takes a few seconds.

## Usage

### In simulation

Start a simulation spine:

```console
./start_simulation.sh
```

Then, in a separate terminal, run the agent:

```console
pixi run agent
```

To visualize the inverse kinematics of the legs in a [Viser](https://viser.studio) browser tab, run instead:

```console
pixi run agent-viz
```

The Viser panel has a crouch height slider that works like the directional pad of the gamepad.

### On your Upkie

Upload the agent to your robot (this assumes there is an `upkie` host in your SSH configuration):

```console
make upload
```

Then, start the pi3hat spine on the robot and run the agent from there:

```console
$ ssh upkie
user@upkie:~$ cd pinker_balancer
user@upkie:pinker_balancer$ pixi run agent
```

### Gamepad commands

Once the agent is running, you can direct your Upkie using the game controller 🎮

- **Left joystick:** go forward right backward
- **Right joystick:** turn left or right
- **Directional pad:** down to crouch, up to stand up
- **Right button:** (B on an Xbox controller, red circle on a PS4 controller) emergency stop 🚨 all motors will turn off
