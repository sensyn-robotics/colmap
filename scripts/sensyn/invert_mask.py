#!/usr/bin/env python3
"""Invert mask images for COLMAP."""

import argparse
import os
from PIL import Image, ImageOps
import glob


def invert_masks(mask_dir="masks"):
    """Invert all mask images (black to white, white to black)."""
    mask_files = glob.glob(os.path.join(mask_dir, "*.png"))

    print(f"Found {len(mask_files)} mask files to invert")

    for i, mask_path in enumerate(mask_files):
        if (i + 1) % 50 == 0:
            print(f"Processing {i + 1}/{len(mask_files)}...")

        # Open the mask
        img = Image.open(mask_path)

        # Invert the image
        inverted_img = ImageOps.invert(img.convert('RGB'))

        # Convert back to original mode if needed
        if img.mode == 'L':
            inverted_img = inverted_img.convert('L')

        # Save back to the same file
        inverted_img.save(mask_path)

    print(f"Successfully inverted {len(mask_files)} masks")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Invert mask images for COLMAP."
    )
    parser.add_argument(
        "--mask-dir",
        type=str,
        default="masks",
        help="Directory containing mask images (default: masks)"
    )
    args = parser.parse_args()

    invert_masks(args.mask_dir)
