#!/usr/bin/env python3
"""Convert JPEG images to PNG format for COLMAP mask matching."""

import argparse
import os
from PIL import Image
import glob
from concurrent.futures import ThreadPoolExecutor, as_completed

def convert_single_image(jpg_path):
    """Convert a single JPEG image to PNG."""
    png_path = jpg_path.replace('.jpg', '.png')
    
    # Open and convert
    img = Image.open(jpg_path)
    img.save(png_path, 'PNG')
    
    # Remove original JPEG
    os.remove(jpg_path)
    
    return os.path.basename(jpg_path)

def convert_images_to_png(image_dir="images"):
    """Convert all JPEG images to PNG format."""
    jpg_files = glob.glob(os.path.join(image_dir, "*.jpg"))
    
    print(f"Found {len(jpg_files)} JPEG files to convert")
    
    converted = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(convert_single_image, jpg_path): jpg_path 
                   for jpg_path in jpg_files}
        
        for future in as_completed(futures):
            try:
                filename = future.result()
                converted += 1
                if converted % 50 == 0:
                    print(f"Converted {converted}/{len(jpg_files)} images...")
            except Exception as e:
                print(f"Error converting {futures[future]}: {e}")
    
    print(f"Successfully converted {converted} images from JPEG to PNG")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert JPEG images to PNG format for COLMAP mask matching.")
    parser.add_argument("--image-dir", type=str, default="images", help="Directory containing image files (default: images)")
    args = parser.parse_args()

    convert_images_to_png(args.image_dir)