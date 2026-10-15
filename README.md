# BioSphere-X

A 2D top-down sci-fi survival game set on alien exoplanets, built with **Godot 4** and **GDScript**.

## Prerequisites

- [Godot 4.x](https://godotengine.org/download) (standard build)

## Setup

1. Clone or download this repository.
2. Open **Godot 4**, click **Import**, and select the `project.godot` file in this folder.
3. Godot will import all assets automatically.

## Run

- Press **F5** (or the ▶ button) inside the Godot editor to run the game.
- The main scene (`scenes/main/main.tscn`) is already configured as the entry point.

## Project Structure

```
├── assets/          # Art, audio, fonts, tilesets
│   ├── audio/
│   ├── fonts/
│   ├── sprites/
│   └── tilesets/
├── data/            # JSON / config data files
├── resources/       # Custom Godot resources (.tres)
├── scenes/          # All .tscn scene files
│   ├── enemies/
│   ├── items/
│   ├── main/        # Entry-point scene
│   ├── player/
│   └── world/
├── scripts/         # Shared GDScript files
│   ├── autoloads/   # Singleton scripts
│   ├── components/  # Reusable node components
│   └── utils/       # Helper functions
├── tests/           # Test scripts
├── ui/              # UI scenes & components
│   ├── components/
│   └── screens/
├── icon.svg
├── project.godot
└── README.md
```

## License

TBD
