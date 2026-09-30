# Pink balancer

[![upkie](https://img.shields.io/badge/upkie-12.0.0-bbaacc)](https://github.com/upkie/upkie/tree/v12.0.0)

An agent for [Upkie](https://github.com/upkie/upkie/) that combines wheeled balancing with inverse kinematics computed by [Pink](https://github.com/stephane-caron/pink). This is the controller that runs in the [first](https://www.youtube.com/shorts/8b36XcCgh7s) [two](https://www.youtube.com/watch?v=NO_TkHGS0wQ) videos of Upkie.

## Installation

This agent uses [pixi](https://pixi.sh/latest/#installation) to manage its Python environment, both on your machine and on your Upkie.

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

### On your Upkie

Upload the agent to your robot (this assumes there is an `upkie` host in your SSH configuration):

```console
make upload
```

Then, start the pi3hat spine on the robot and run the agent from there:

```console
$ ssh upkie
user@upkie:~$ cd pink_balancer
user@upkie:pink_balancer$ pixi run agent
```

### Gamepad commands

Once the agent is running, you can direct your Upkie using the game controller 🎮

- **Left joystick:** go forward right backward
- **Right joystick:** turn left or right
- **Directional pad:** down to crouch, up to stand up
- **Right button:** (B on an Xbox controller, red circle on a PS4 controller) emergency stop 🚨 all motors will turn off
