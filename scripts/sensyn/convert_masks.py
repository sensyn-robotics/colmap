#!/usr/bin/env python3
"""Convert RGB mask images to grayscale format for COLMAP."""

import argparse
import os
import re
import shutil
from PIL import Image
import glob


def rename_masks_to_match_images(mask_dir="masks", image_dir="images"):
    """Rename mask files to match image filenames."""
    # Get all mask files
    mask_files = glob.glob(os.path.join(mask_dir, "*.png"))

    # Get all image files to match against
    image_files = glob.glob(os.path.join(image_dir, "*.png"))
    image_basenames = {os.path.basename(img) for img in image_files}

    print(f"Found {len(mask_files)} mask files")
    print(f"Found {len(image_files)} image files to match")

    renamed = 0
    skipped = 0

    for mask_path in mask_files:
        mask_basename = os.path.basename(mask_path)

        # Check if mask already has correct name matching an image
        if mask_basename in image_basenames:
            skipped += 1
            continue

        # Try to extract number from mask filename (e.g., 000075_mask.png -> 000075)
        match = re.match(r'(\d+)(_mask)?\.png', mask_basename)
        if match:
            number = match.group(1)
            target_name = f"{number}.png"

            # Check if this target exists in images
            if target_name in image_basenames:
                new_path = os.path.join(mask_dir, target_name)
                shutil.move(mask_path, new_path)
                renamed += 1

                if renamed % 50 == 0:
                    print(f"Renamed {renamed} files...")
            else:
                print(f"Warning: No matching image for mask {mask_basename}")
        else:
            print(f"Warning: Could not parse number from {mask_basename}")

    print(f"Renamed {renamed} mask files to match image names")
    print(f"Skipped {skipped} files that already matched")

    return renamed


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
    parser.add_argument("--image-dir", type=str, default="images", help="Directory containing image files (default: images)")
    args = parser.parse_args()

    # First, rename masks to match image filenames
    print("Step 1: Renaming masks to match image filenames...")
    rename_masks_to_match_images(args.mask_dir, args.image_dir)

    # Then, convert masks to grayscale
    print("\nStep 2: Converting masks to grayscale...")
    convert_masks_to_grayscale(args.mask_dir)