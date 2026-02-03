# Star Trek: Starship Command

A 3D starship flight simulator set in the Star Trek universe, built with Godot 4.5. Pilot iconic Federation starships through a realistically-scaled Sol system, engage warp drive, and explore the final frontier.

![Godot](https://img.shields.io/badge/Godot-4.5.1-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Multiple Playable Starships** - Command legendary vessels including:
  - USS Enterprise NCC-1701 (Constitution Class - TOS)
  - USS Enterprise NCC-1701-A (Constitution II Class)
  - USS Enterprise NCC-1701-B (Excelsior Class)
  - USS Enterprise NCC-1701-C (Ambassador Class)
  - USS Enterprise NCC-1701-D (Galaxy Class)
  - USS Enterprise NCC-1701-E (Sovereign Class)
  - USS Enterprise NCC-1701-F (Odyssey Class)
  - USS Enterprise NCC-1701-G (Constitution III Class)
  - USS Voyager NCC-74656 (Intrepid Class)
  - USS Defiant NX-74205 (Defiant Class)

- **Realistic Sol System** - Explore a scale model of our solar system:
  - Sun, Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune
  - Earth's Moon with proper orbital mechanics
  - Starbase 1 orbiting Earth
  - Realistic distances and planet sizes (100× uniform scale)

- **Authentic Warp Drive** - TNG-accurate warp scale:
  - Warp 1 = 1c (speed of light)
  - Warp 9 = 1,516c
  - Warp 9.9 = 3,053c
  - Safety systems prevent warp engagement near celestial bodies

- **LCARS Interface** - Star Trek-style HUD featuring:
  - Interactive minimap with clickable destinations
  - Course plotting and autopilot system
  - Warp and impulse speed indicators
  - Orbit and docking systems
  - ETA display during autopilot

- **Multiple Camera Modes** - View your ship from any angle:
  - External chase camera (F1)
  - Bridge view (F2)
  - Cinematic flyby (F3)
  - Free orbit camera (F4)

## Controls

### Flight Controls
| Key | Action |
|-----|--------|
| W / S | Pitch up / down |
| A / D | Yaw left / right |
| Z / C | Roll left / right |
| E | Increase impulse |
| Q | Decrease impulse |
| Space | Full stop |

### Warp Drive
| Key | Action |
|-----|--------|
| Shift + W | Engage / disengage warp |
| + | Increase warp factor |
| - | Decrease warp factor |

### Navigation
| Key | Action |
|-----|--------|
| M | Toggle minimap |
| O | Enter orbit (when near planet) |
| Click on minimap | Set course to destination |
| Autopilot button | Engage autopilot to destination |

### Camera
| Key | Action |
|-----|--------|
| F1 | External camera |
| F2 | Bridge camera |
| F3 | Flyby camera |
| F4 | Free camera |
| Mouse drag | Orbit camera (F1/F4) |
| Scroll wheel | Zoom in/out |

## Getting Started

### Requirements
- [Godot Engine 4.5.1](https://godotengine.org/download) or later

### Running the Game
1. Clone this repository
2. Open Godot Engine
3. Click "Import" and select the `project.godot` file
4. Press F5 or click the Play button

## Project Structure

```
Star Trek Game/
├── assets/
│   └── models/          # 3D ship models (.glb)
├── scenes/
│   ├── main.tscn        # Main game scene
│   ├── ship/            # Starship scene
│   ├── sectors/         # Sol system environment
│   ├── environment/     # Bridge interior
│   ├── camera/          # Camera system
│   └── ui/              # Ship selection screen
├── scripts/
│   ├── ship/            # Ship controller, warp drive
│   ├── camera/          # Camera manager
│   ├── hud/             # LCARS interface
│   ├── environment/     # Planet/sector generation
│   └── ui/              # UI controllers
└── project.godot
```

## Technical Details

### Scale (100× Uniform World Scale)
- 1 game unit = 10 kilometers
- Earth radius: 637 units (6,371 km)
- Earth-Sun distance: 14,960,000 units (149.6 million km / 1 AU)
- Full impulse = 0.25c (74,948 km/s = 7,495 units/s)
- Floating origin system prevents precision issues at large distances

### Warp Speed Formula
Uses the TNG warp scale where speed increases exponentially approaching Warp 10 (which is infinite and unattainable).

## Credits

### 3D Models
Ship models sourced from various Star Trek fan creators. All Star Trek-related content is the property of CBS/Paramount.

### Built With
- [Godot Engine 4.5](https://godotengine.org/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This is a fan-made project for educational purposes. Star Trek and all related marks are trademarks of CBS Studios Inc. This project is not affiliated with or endorsed by CBS Studios Inc.

---

*"Space: the final frontier..."*
