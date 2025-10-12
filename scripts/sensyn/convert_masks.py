#!/usr/bin/env python3
"""Convert RGB mask images to grayscale format for COLMAP."""

import argparse
import os
from PIL import Image
import glob

def convert_masks_to_grayscale(mask_dir="masks"):
    """Convert all RGB masks to grayscale L mode."""
    mask_files = glob.glob(os.path.join(mask_dir, "*.png"))

    print(f"Found {len(mask_files)} mask files to convert")

    for i, mask_path in enumerate(mask_files):
        if (i + 1) % 50 == 0:
            print(f"Processing {i + 1}/{len(mask_files)}...")

        # Open the RGB mask
        img = Image.open(mask_path)

        # Convert to grayscale (L mode)
        # Since masks are binary (0 or 255), any channel works
        gray_img = img.convert('L')

        # Save back to the same file
        gray_img.save(mask_path)

    print(f"Successfully converted {len(mask_files)} masks to grayscale")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert RGB mask images to grayscale format for COLMAP.")
    parser.add_argument("--mask-dir", type=str, default="masks", help="Directory containing mask images (default: masks)")
    args = parser.parse_args()

    convert_masks_to_grayscale(args.mask_dir)