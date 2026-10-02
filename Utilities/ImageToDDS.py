#!/usr/bin/env python3
"""Convert a font atlas image to an uncompressed BGRA8 DDS.

Requires Pillow: py -m pip install Pillow
Examples:
    py image_to_dds.py atlas.png
    py image_to_dds.py atlas.png font.dds
    py image_to_dds.py atlas.png font.dds --channel alpha

Default: preserve RGBA pixel values, including encoded font metadata.
No resizing, mipmaps, compression, glyph rearrangement, or metadata generation.
For a monospace renderer, the input image must already have the expected grid.
"""
import argparse
from pathlib import Path
import struct
import sys


def dds_header(width, height):
    # DDS_HEADER followed by its embedded DDS_PIXELFORMAT. Legacy BGRA8
    # masks match the existing LiberationSans atlas and expose red normally
    # to Texture2D<float>. One mip level, ordinary 2D texture.
    fields = [
        124, 0x100F, height, width, width * 4, 0, 0,
        *([0] * 11),
        32, 0x41, 0, 32,
        0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000,
        0x1000, 0, 0, 0, 0,
    ]
    return b'DDS ' + struct.pack('<31I', *fields)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('input', type=Path, help='Source PNG, BMP, TGA, or other Pillow-supported image')
    parser.add_argument('output', type=Path, nargs='?', help='Defaults to the input filename with .dds extension')
    parser.add_argument('--channel', choices=('rgba', 'red', 'alpha', 'luminance'), default='rgba',
                        help='rgba preserves pixels; other modes copy the selected mask to RGB with opaque alpha')
    parser.add_argument('--force', action='store_true', help='Replace an existing output file')
    args = parser.parse_args()
    output = args.output or args.input.with_suffix('.dds')
    if args.input.resolve() == output.resolve():
        parser.error('Input and output must be different files.')
    if output.suffix.lower() != '.dds':
        parser.error('Output must have a .dds extension.')
    try:
        from PIL import Image
    except ImportError:
        parser.exit(1, 'Pillow is required. Install it with: py -m pip install Pillow\n')
    try:
        with Image.open(args.input) as source:
            if args.channel == 'alpha' and 'A' not in source.getbands() and 'transparency' not in source.info:
                parser.error('The input has no alpha channel or transparency. Use --channel red or luminance.')
            rgba = source.convert('RGBA')
            if args.channel != 'rgba':
                if args.channel == 'luminance':
                    mask = rgba.convert('RGB').convert('L')
                else:
                    mask = rgba.getchannel('R' if args.channel == 'red' else 'A')
                rgba = Image.merge('RGBA', (mask, mask, mask, Image.new('L', rgba.size, 255)))
            payload = dds_header(*rgba.size) + rgba.tobytes('raw', 'BGRA')
            width, height = rgba.size
        # Exclusive creation by default avoids accidentally replacing an atlas.
        with output.open('wb' if args.force else 'xb') as target:
            target.write(payload)
    except FileExistsError:
        parser.exit(1, f'Output already exists: {output}. Use --force to replace it.\n')
    except (OSError, ValueError) as error:
        parser.exit(1, f'Conversion failed: {error}\n')
    print(f'Saved {output} ({width} x {height}, uncompressed BGRA8, channel={args.channel})')


if __name__ == '__main__':
    main()
