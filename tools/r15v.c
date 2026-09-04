#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fastlz.h"

static void write_u16(FILE *file, uint16_t value)
{
  fputc(value & 0xFF, file);
  fputc(value >> 8, file);
}

static void write_u32(FILE *file, uint32_t value)
{
  fputc(value & 0xFF, file);
  fputc(value >> 8, file);
  fputc(value >> 16, file);
  fputc(value >> 24, file);
}

static uint16_t rgb15(uint16_t color)
{
  color &= 0x7FFF;
  return (uint16_t)((color & 0x001F) << 10 |
                    (color & 0x03E0) |
                    (color & 0x7C00) >> 10);
}

static size_t read_exact(void *data, size_t length)
{
  size_t total = 0;

  while (total < length) {
    size_t count = fread((uint8_t *)data + total, 1, length - total, stdin);
    if (count == 0)
      break;
    total += count;
  }

  return total;
}

int main(int argc, char **argv)
{
  if (argc != 6)
    return 1;

  int width = atoi(argv[1]);
  int height = atoi(argv[2]);
  int frame_rate = atoi(argv[3]);
  int frame_size = width * height;
  int key_interval = frame_rate / 2;
  if (key_interval < 1)
    key_interval = 1;

  if (width <= 0 || width > 256 || height <= 0 || height > 192 ||
      frame_rate <= 0 || frame_rate > 60)
    return 1;

  FILE *palette_file = fopen(argv[4], "rb");
  FILE *output = fopen(argv[5], "wb+");
  uint8_t palette_data[512];
  uint16_t palette[256];
  uint8_t lookup[32768];
  uint8_t *pixels = malloc((size_t)frame_size * 2);
  uint8_t *frame = malloc((size_t)frame_size);
  uint8_t *previous = calloc((size_t)frame_size, 1);
  uint8_t *delta = malloc((size_t)frame_size);
  uint8_t *packed_frame = malloc((size_t)frame_size + frame_size / 20 + 66);
  uint8_t *packed_delta = malloc((size_t)frame_size + frame_size / 20 + 66);

  if (!palette_file || !output || !pixels || !frame || !previous || !delta ||
      !packed_frame || !packed_delta)
    return 1;
  if (fread(palette_data, 1, sizeof palette_data, palette_file) != sizeof palette_data)
    return 1;

  fclose(palette_file);

  for (int i = 0; i < 256; i++) {
    uint16_t color = rgb15(palette_data[i * 2] | palette_data[i * 2 + 1] << 8);
    palette[i] = color | 0x8000;
  }

  for (int color = 0; color < 32768; color++) {
    int red = color & 31;
    int green = color >> 5 & 31;
    int blue = color >> 10 & 31;
    int best = 0;
    int best_distance = 3073;

    for (int i = 0; i < 256; i++) {
      int other = palette[i] & 0x7FFF;
      int red_distance = red - (other & 31);
      int green_distance = green - (other >> 5 & 31);
      int blue_distance = blue - (other >> 10 & 31);
      int distance = red_distance * red_distance +
        green_distance * green_distance + blue_distance * blue_distance;

      if (distance < best_distance) {
        best = i;
        best_distance = distance;
      }
    }

    lookup[color] = (uint8_t)best;
  }

  fwrite("R15V", 1, 4, output);
  write_u16(output, (uint16_t)width);
  write_u16(output, (uint16_t)height);
  write_u16(output, (uint16_t)frame_rate);
  write_u32(output, 0);
  fwrite("FLZ1", 1, 4, output);
  write_u16(output, (uint16_t)key_interval);

  for (int i = 0; i < 256; i++)
    write_u16(output, palette[i]);

  uint32_t frames = 0;

  for (;;) {
    size_t count = read_exact(pixels, (size_t)frame_size * 2);
    if (count == 0)
      break;
    if (count != (size_t)frame_size * 2)
      return 1;

    for (int i = 0; i < frame_size; i++) {
      uint16_t color = rgb15(pixels[i * 2] | pixels[i * 2 + 1] << 8);
      uint8_t index = lookup[color];
      delta[i] = index ^ previous[i];
      frame[i] = index;
    }

    int frame_packed_size = fastlz_compress_level(1, frame, frame_size, packed_frame);
    int delta_packed_size = fastlz_compress_level(1, delta, frame_size, packed_delta);
    int absolute = frames % key_interval == 0 ||
      frame_packed_size < delta_packed_size;
    int packed_size = absolute ? frame_packed_size : delta_packed_size;
    uint8_t *packed = absolute ? packed_frame : packed_delta;
    uint8_t *data = absolute ? frame : delta;
    uint32_t flag = absolute ? 0x80000000 : 0;

    if (packed_size > 0 && packed_size < frame_size) {
      write_u32(output, flag | (uint32_t)packed_size);
      fwrite(packed, 1, (size_t)packed_size, output);
    }
    else {
      write_u32(output, flag | (uint32_t)frame_size);
      fwrite(data, 1, (size_t)frame_size, output);
    }

    memcpy(previous, frame, (size_t)frame_size);
    frames++;
  }

  if (frames == 0 || ferror(stdin) || ferror(output))
    return 1;

  fseek(output, 10, SEEK_SET);
  write_u32(output, frames);
  fclose(output);
  free(pixels);
  free(frame);
  free(previous);
  free(delta);
  free(packed_frame);
  free(packed_delta);
  return 0;
}
