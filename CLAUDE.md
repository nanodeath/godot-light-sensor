# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Godot Light Sensor 3D** is a Godot 4 addon that provides light measurement capabilities for 3D scenes. It implements a light detection system using SubViewport rendering to measure light levels and colors at specific points in 3D space.

## Development Commands

This is a Godot addon project with no external build system. Development is done entirely within the Godot Editor:

- **Run Example**: Open `addons/light_sensor_3d/example/root.tscn` in Godot Editor and press F6
- **Testing**: Manual testing through the example scene - no automated test framework
- **Main Scene**: `addons/light_sensor_3d/example/root.tscn` (configured in project.godot)

## Core Architecture

### Plugin Structure
- **Entry Point**: `addons/light_sensor_3d/plugin.gd` - registers the addon with Godot
- **Core Implementation**: `addons/light_sensor_3d/light_sensor_3d.gd` - main LightSensor3D class
- **Editor Integration**: `addons/light_sensor_3d/light_sensor_3d_gizmo_plugin.gd` - visual gizmos
- **Internal Scene**: `addons/light_sensor_3d/light_sensor_scene.tscn` - SubViewport setup for light capture

### Light Detection System
The addon uses a SubViewport (4x4 pixels) with an orthogonal camera pointing at a white plane to capture light data:

1. **SubViewport Rendering**: Tiny viewport for efficient light sampling
2. **GPU-CPU Transfer**: Downloads texture data to calculate color/luminance (~0.2ms operation)
3. **Layer-based Filtering**: Uses Godot's layer system to selectively detect light sources
4. **Signal System**: Emits `color_updated` and `light_level_updated` signals

### Performance Considerations
- **Expensive Operation**: Each `refresh()` call requires GPU-CPU texture transfer
- **Recommended Refresh Rate**: 1-4 Hz (250ms-1000ms intervals) to maintain performance
- **Multi-sensor Scaling**: Stagger refresh timing for multiple sensors

## Key Files and Their Roles

### Core Plugin Files (`addons/light_sensor_3d/`)
- `plugin.cfg` - Plugin metadata (version 1.0.0)
- `plugin.gd` - Plugin lifecycle management, registers gizmo plugin
- `light_sensor_3d.gd` - Main sensor class extending Node3D, handles light detection logic
- `light_sensor_3d_gizmo_plugin.gd` - Editor gizmos for visual representation
- `light_sensor_scene.tscn` - Internal SubViewport architecture

### Example Implementation (`addons/light_sensor_3d/example/`)
- `root.tscn` - Demo scene showing sensor usage with Timer node
- `sensor_label.gd` - Example script demonstrating real-time light level display

### Configuration Files
- `project.godot` - Godot 4.2 project configuration, Mobile features enabled
- `.gitattributes` - LF line endings, export rules for Asset Library distribution
- `.gitignore` - Excludes `.godot/` build artifacts

## Development Workflow

### Testing Changes
1. Open project in Godot Editor
2. Run the example scene (`addons/light_sensor_3d/example/root.tscn`)
3. Observe light sensor readings in the label display
4. Test with different lighting setups and layer configurations

### Common Development Tasks

#### Adding New Features to LightSensor3D
- Modify `addons/light_sensor_3d/light_sensor_3d.gd`
- Update example scene if needed to demonstrate new functionality
- Test with various lighting conditions

#### Editor Integration Changes
- Modify `addons/light_sensor_3d/light_sensor_3d_gizmo_plugin.gd` for visual gizmo changes
- Plugin registration handled in `addons/light_sensor_3d/plugin.gd`

### Layer Configuration Patterns
- **Sensor Layer**: Should NOT be visible to main camera (avoids visual artifacts)
- **Light Sources**: Should be visible to sensor layer for detection
- **Shadow Casters**: Should be on layers that interact with light sources

### Distribution
The project is configured for Godot Asset Library distribution via `.gitattributes` export rules that only include the addon folder.