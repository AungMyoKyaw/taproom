#!/usr/bin/env python3
"""Generate Taproom's 1024x1024 macOS Liquid Glass app icon in VectorCraft."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESIGN_DIR = ROOT / "design"
SCRIPTS_DIR = DESIGN_DIR / "scripts"
RENDERS_DIR = DESIGN_DIR / "renders"

# 512x512 pt artboard exported at 144 ppi = 1024x1024 px
COMMANDS = [
    {
        "command": "file.new",
        "params": {
            "name": "TaproomIcon",
            "width": 512,
            "height": 512,
            "units": "Points",
            "backgroundContents": "transparent",
            "colorMode": "rgb",
        },
    },
    # 1. Deep obsidian macOS squircle backdrop
    {
        "command": "shape.rectangle",
        "params": {"x": 32, "y": 32, "width": 448, "height": 448, "radius": 100},
    },
    {
        "command": "paint.setFill",
        "params": {
            "gradient": {
                "type": "linear",
                "angle": -90,
                "stops": [
                    {"offset": 0.0, "color": "#262B35"},
                    {"offset": 0.55, "color": "#161920"},
                    {"offset": 1.0, "color": "#0E1014"},
                ],
            }
        },
    },
    {
        "command": "paint.setStroke",
        "params": {"color": "#FFFFFF", "opacity": 0.16},
    },
    # 2. Subtle warm amber ambient glow behind emblem
    {
        "command": "shape.ellipse",
        "params": {"x": 116, "y": 116, "width": 280, "height": 280},
    },
    {
        "command": "paint.setFill",
        "params": {
            "gradient": {
                "type": "radial",
                "stops": [
                    {"offset": 0.0, "color": "#F59E0B", "opacity": 0.24},
                    {"offset": 1.0, "color": "#F59E0B", "opacity": 0.0},
                ],
            }
        },
    },
    {"command": "paint.setStroke", "params": {"none": True}},
    # 3. Mug / vessel handle (right side)
    {
        "command": "shape.rectangle",
        "params": {"x": 318, "y": 212, "width": 74, "height": 124, "radius": 32},
    },
    {"command": "paint.setFill", "params": {"none": True}},
    {"command": "paint.setStroke", "params": {"color": "#F59E0B"}},
    {"command": "stroke.set", "params": {"weight": 24, "join": "round"}},
    # 4. Main Amber/Copper vessel body
    {
        "command": "shape.rectangle",
        "params": {"x": 146, "y": 176, "width": 196, "height": 218, "radius": 40},
    },
    {
        "command": "paint.setFill",
        "params": {
            "gradient": {
                "type": "linear",
                "angle": -90,
                "stops": [
                    {"offset": 0.0, "color": "#FBBF24"},
                    {"offset": 0.5, "color": "#F59E0B"},
                    {"offset": 1.0, "color": "#B45309"},
                ],
            }
        },
    },
    {"command": "paint.setStroke", "params": {"color": "#FDE68A", "opacity": 0.45}},
    {"command": "stroke.set", "params": {"weight": 2}},
    # 5. Precision flute grooves inside vessel (developer instrument motif)
    {
        "command": "shape.rectangle",
        "params": {"x": 188, "y": 236, "width": 22, "height": 116, "radius": 11},
    },
    {"command": "paint.setFill", "params": {"color": "#141619", "opacity": 0.26}},
    {"command": "paint.setStroke", "params": {"none": True}},
    {
        "command": "shape.rectangle",
        "params": {"x": 233, "y": 236, "width": 22, "height": 116, "radius": 11},
    },
    {"command": "paint.setFill", "params": {"color": "#141619", "opacity": 0.26}},
    {"command": "paint.setStroke", "params": {"none": True}},
    {
        "command": "shape.rectangle",
        "params": {"x": 278, "y": 236, "width": 22, "height": 116, "radius": 11},
    },
    {"command": "paint.setFill", "params": {"color": "#141619", "opacity": 0.26}},
    {"command": "paint.setStroke", "params": {"none": True}},
    # 6. Liquid Glass foam crown
    {
        "command": "shape.rectangle",
        "params": {"x": 136, "y": 134, "width": 216, "height": 64, "radius": 32},
    },
    {
        "command": "paint.setFill",
        "params": {
            "gradient": {
                "type": "linear",
                "angle": -90,
                "stops": [
                    {"offset": 0.0, "color": "#FFFFFF"},
                    {"offset": 1.0, "color": "#FEF3C7"},
                ],
            }
        },
    },
    {"command": "paint.setStroke", "params": {"color": "#FFFFFF", "opacity": 0.8}},
    {"command": "stroke.set", "params": {"weight": 1.5}},
    {
        "command": "shape.ellipse",
        "params": {"x": 162, "y": 106, "width": 84, "height": 84},
    },
    {"command": "paint.setFill", "params": {"color": "#FFFFFF"}},
    {"command": "paint.setStroke", "params": {"none": True}},
    {
        "command": "shape.ellipse",
        "params": {"x": 226, "y": 98, "width": 96, "height": 96},
    },
    {"command": "paint.setFill", "params": {"color": "#FFFBEB"}},
    {"command": "paint.setStroke", "params": {"none": True}},
    # 7. Top specular glass rim highlight across squircle
    {
        "command": "shape.rectangle",
        "params": {"x": 40, "y": 40, "width": 432, "height": 432, "radius": 92},
    },
    {"command": "paint.setFill", "params": {"none": True}},
    {"command": "paint.setStroke", "params": {"color": "#FFFFFF", "opacity": 0.12}},
    {"command": "stroke.set", "params": {"weight": 2}},
]


def main():
    cmd_path = SCRIPTS_DIR / "taproom-icon.json"
    cmd_path.write_text(json.dumps(COMMANDS, indent=2))

    out_vc = DESIGN_DIR / "taproom-icon.vectorcraft"
    out_svg = RENDERS_DIR / "app-icon.svg"
    out_png = RENDERS_DIR / "app-icon-1024.png"

    res = subprocess.run(
        [
            "vectorcraft-cli", "--safe-mode", "run",
            "--commands", str(cmd_path),
            "--export", str(out_vc),
            "--export", str(out_svg),
            "--export", str(out_png),
            "--ppi", "144",
        ],
        capture_output=True,
        text=True,
    )
    print(res.stdout)
    if res.returncode != 0:
        print("STDERR:", res.stderr)
        raise RuntimeError("vectorcraft-cli failed")


if __name__ == "__main__":
    main()
