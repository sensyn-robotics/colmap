#!/usr/bin/env python3
"""
Convert metadata.json to campose.txt format for COLMAP model alignment.

This script replaces poslog2campose.py to read camera positions from
metadata.json instead of poslog.csv.
"""

import json
import os


def main():
    script_path = os.path.dirname(os.path.realpath(__file__))

    # Input: metadata.json file
    metadata_path = os.path.join(
        script_path, "../../dataset/sample/metadata.json"
    )

    # Output: campose.txt file
    output_path = os.path.join(script_path, "../../dataset/work/campose.txt")

    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # Read metadata.json
    try:
        with open(metadata_path) as f:
            metadata = json.load(f)
    except FileNotFoundError:
        print(f"Error: {metadata_path} not found")
        return 1
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return 1

    # Extract camera positions and write to campose.txt
    with open(output_path, "w") as f:
        # If metadata contains image entries as values
        for key, entry in metadata.items():
            if key == "poses":
                # image loop
                for i, pose in enumerate(entry):
                    if isinstance(pose, list) and len(pose) >= 7:
                        # Get image name from metadata or generate it
                        image_name = f"{i}.jpg"

                        # Extract x, y, z coordinates
                        x, y, z = pose[4], pose[5], pose[6]
                    else:
                        print(
                            f"Warning: Invalid position format for entry {i} in {key}"
                        )
                        continue

                    f.write(f"{image_name} {x} {y} {z}\n")

    print(f"Successfully created {output_path}")
    return 0


def write_position_line(file, image_name, position):
    """Write a position line to the output file."""
    if isinstance(position, dict):
        x = position.get("x", 0)
        y = position.get("y", 0)
        z = position.get("z", 0)
    elif isinstance(position, list) and len(position) >= 3:
        x, y, z = position[0], position[1], position[2]
    else:
        print(f"Warning: Invalid position format for {image_name}")
        return

    file.write(f"{image_name} {x} {y} {z}\n")


if __name__ == "__main__":
    exit(main())
