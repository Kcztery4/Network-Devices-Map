# Network Devices Map

A standalone application (Godot 4.5) for visualizing a network on a map:
placing network devices (Rack, Switch, Access Point) on a map background
(PNG/SVG), drawing uplink connections between them, saving/loading the
project, and exporting the view to PNG.

## Features

- Load a map background (PNG or SVG)
- Add devices: Rack, Switch, Access Point
- Dock Switches into Racks (drag and drop)
- Draw uplink arrows (Copper / Fiber 1G / Fiber 10G) between devices
- Name and scale objects
- Save/load the project (Godot `Resource`/`.tres`)
- Export the map view to PNG

## Requirements

- [Godot Engine 4.5](https://godotengine.org/)

## Running from source

1. Open the project folder in Godot Engine (`project.godot`).
2. Run the main scene (`F5`) or build an `.exe` via Project → Export.

## Downloads

Pre-built Windows releases are available on the
[Releases](https://github.com/Kcztery4/Network-Devices-Map/releases) page.

## Status

Actively developed, in stages — see commit history.

## License

No explicit license yet — all rights reserved unless stated otherwise.
