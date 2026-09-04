#include <nds.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/string.h>

#include "bindings.h"
#include "fastlz.h"

#define VIDEO_SCREEN_W 256
#define VIDEO_SCREEN_H 192
#define VIDEO_ABSOLUTE 0x80000000
#define VIDEO_SIZE 0x7FFFFFFF

typedef struct {
  FILE *file;
  int width;
  int height;
  int frame_rate;
  int key_interval;
  u32 frame_count;
  u32 frame_index;
  long data_start;
  u32 *offsets;
  u16 palette[256];
  u8 *frame;
  u8 *delta;
  u8 *packed;
  u8 *screen;
} video_state_t;

static video_state_t s_video;

static int video_read_u16(FILE *file, u16 *value)
{
  int low = fgetc(file);
  int high = fgetc(file);
  if (low == EOF || high == EOF)
    return 0;
  *value = (u16)(low | high << 8);
  return 1;
}

static int video_read_u32(FILE *file, u32 *value)
{
  int a = fgetc(file);
  int b = fgetc(file);
  int c = fgetc(file);
  int d = fgetc(file);
  if (a == EOF || b == EOF || c == EOF || d == EOF)
    return 0;
  *value = (u32)a | (u32)b << 8 | (u32)c << 16 | (u32)d << 24;
  return 1;
}

static void video_raise_closed(mrb_state *mrb)
{
  mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: video is not open");
}

static void video_check_screen(mrb_state *mrb, mrb_value value)
{
  if (mrb_symbol_p(value) && strcmp(mrb_sym_name(mrb, mrb_symbol(value)), "top") == 0)
    return;
  mrb_raise(mrb, E_ARGUMENT_ERROR, "screen must be :top");
}

static void video_check_position(mrb_state *mrb, mrb_int x, mrb_int y)
{
  if (x < 0 || y < 0 || x > VIDEO_SCREEN_W - s_video.width ||
      y > VIDEO_SCREEN_H - s_video.height)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "video must fit within 256x192");
}

static void video_open_fail(mrb_state *mrb, FILE *file, u8 *frame,
                            u8 *delta, u8 *packed, u32 *offsets,
                            const char *message)
{
  free(frame);
  free(delta);
  free(packed);
  free(offsets);
  fclose(file);
  memset(&s_video, 0, sizeof s_video);
  mrb_raise(mrb, E_RUNTIME_ERROR, message);
}

static void video_reset(mrb_state *mrb)
{
  if (fseek(s_video.file, s_video.data_start, SEEK_SET) != 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: cannot rewind video");
  memset(s_video.frame, 0, (size_t)s_video.width * s_video.height);
  s_video.frame_index = 0;
}

static void video_decode(mrb_state *mrb)
{
  if (s_video.frame_index == s_video.frame_count)
    video_reset(mrb);

  u32 packet;
  int frame_size = s_video.width * s_video.height;

  if (!video_read_u32(s_video.file, &packet))
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: cannot read frame");

  mrb_bool absolute = packet & VIDEO_ABSOLUTE;
  u32 packed_size = packet & VIDEO_SIZE;

  if (packed_size == 0 || packed_size > (u32)frame_size ||
      (s_video.frame_index % s_video.key_interval == 0 && !absolute))
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: invalid R15V frame");

  if (packed_size == (u32)frame_size) {
    if (fread(s_video.delta, 1, (size_t)frame_size, s_video.file) != (size_t)frame_size)
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: cannot read frame");
  }
  else {
    if (fread(s_video.packed, 1, packed_size, s_video.file) != packed_size)
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: cannot read frame");
    if (fastlz_decompress(s_video.packed, (int)packed_size,
                          s_video.delta, frame_size) != frame_size)
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video: cannot decompress frame");
  }

  if (absolute)
    memcpy(s_video.frame, s_video.delta, (size_t)frame_size);
  else
    for (int i = 0; i < frame_size; i++)
      s_video.frame[i] ^= s_video.delta[i];

  s_video.frame_index++;
}

static void video_blit(mrb_int x, mrb_int y)
{
  int frame_size = s_video.width * s_video.height;

  if (s_video.width == VIDEO_SCREEN_W) {
    DC_FlushRange(s_video.frame, (u32)frame_size);
    dmaCopy(s_video.frame, s_video.screen + y * VIDEO_SCREEN_W, (u32)frame_size);
  }
  else {
    for (int row = 0; row < s_video.height; row++)
      memcpy(s_video.screen + (y + row) * VIDEO_SCREEN_W + x,
             s_video.frame + row * s_video.width, (size_t)s_video.width);
  }
}

static mrb_value video_open(mrb_state *mrb, mrb_value self)
{
  if (s_video.file)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video_open: already open; close first");

  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  FILE *file = fopen(RSTRING_PTR(path), "rb");
  if (!file)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video_open: cannot open file");

  char magic[4];
  char codec[4];
  u16 width;
  u16 height;
  u16 frame_rate;
  u16 key_interval;
  u32 frame_count;

  if (fread(magic, 1, 4, file) != 4 || memcmp(magic, "R15V", 4) != 0 ||
      !video_read_u16(file, &width) || !video_read_u16(file, &height) ||
      !video_read_u16(file, &frame_rate) || !video_read_u32(file, &frame_count) ||
      fread(codec, 1, 4, file) != 4 || memcmp(codec, "FLZ1", 4) != 0 ||
      !video_read_u16(file, &key_interval) ||
      width == 0 || width > VIDEO_SCREEN_W || height == 0 || height > VIDEO_SCREEN_H ||
      frame_rate == 0 || frame_rate > 60 || frame_count == 0 ||
      key_interval == 0 || key_interval > frame_count) {
    fclose(file);
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video_open: invalid R15V video");
  }

  for (int i = 0; i < 256; i++) {
    if (!video_read_u16(file, &s_video.palette[i])) {
      fclose(file);
      memset(&s_video, 0, sizeof s_video);
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video_open: invalid R15V palette");
    }
  }

  int frame_size = width * height;
  long data_start = ftell(file);
  if (data_start < 0)
    video_open_fail(mrb, file, NULL, NULL, NULL, NULL,
                    "Gfx.video_open: cannot read video");

  u32 key_count = (frame_count + key_interval - 1) / key_interval;
  u32 *offsets = malloc((size_t)key_count * sizeof *offsets);
  u32 packed_capacity = 1;

  if (!offsets)
    video_open_fail(mrb, file, NULL, NULL, NULL, offsets,
                    "Gfx.video_open: allocation failed");

  for (u32 i = 0; i < frame_count; i++) {
    long position = ftell(file);
    u32 packet;

    if (position < 0 || position > (long)VIDEO_SIZE ||
        !video_read_u32(file, &packet) ||
        (packet & VIDEO_SIZE) == 0 || (packet & VIDEO_SIZE) > (u32)frame_size ||
        (i % key_interval == 0 && !(packet & VIDEO_ABSOLUTE)) ||
        fseek(file, (long)(packet & VIDEO_SIZE), SEEK_CUR) != 0)
      video_open_fail(mrb, file, NULL, NULL, NULL, offsets,
                      "Gfx.video_open: invalid R15V frames");

    if (i % key_interval == 0)
      offsets[i / key_interval] = (u32)position;
    if ((packet & VIDEO_SIZE) < (u32)frame_size &&
        (packet & VIDEO_SIZE) > packed_capacity)
      packed_capacity = packet & VIDEO_SIZE;
  }

  u8 *frame = calloc((size_t)frame_size, 1);
  u8 *delta = malloc((size_t)frame_size);
  u8 *packed = malloc(packed_capacity);

  if (!frame || !delta || !packed)
    video_open_fail(mrb, file, frame, delta, packed, offsets,
                    "Gfx.video_open: allocation failed");

  if (fseek(file, data_start, SEEK_SET) != 0)
    video_open_fail(mrb, file, frame, delta, packed, offsets,
                    "Gfx.video_open: cannot rewind video");

  s_video.file = file;
  s_video.width = width;
  s_video.height = height;
  s_video.frame_rate = frame_rate;
  s_video.key_interval = key_interval;
  s_video.frame_count = frame_count;
  s_video.frame_index = 0;
  s_video.data_start = data_start;
  s_video.offsets = offsets;
  s_video.frame = frame;
  s_video.delta = delta;
  s_video.packed = packed;
  s_video.screen = gfx_video_begin(s_video.palette);

  mrb_value info[] = {
    mrb_int_value(mrb, width),
    mrb_int_value(mrb, height),
    mrb_int_value(mrb, frame_rate),
    mrb_int_value(mrb, frame_count)
  };
  return mrb_ary_new_from_values(mrb, 4, info);
}

static mrb_value video_frame(mrb_state *mrb, mrb_value self)
{
  if (!s_video.file)
    video_raise_closed(mrb);

  mrb_value screen;
  mrb_int x;
  mrb_int y;
  mrb_int index;
  mrb_get_args(mrb, "oiii", &screen, &x, &y, &index);

  video_check_screen(mrb, screen);
  video_check_position(mrb, x, y);
  if (index < 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "frame must not be negative");

  u32 target = (u32)index % s_video.frame_count;
  if (s_video.frame_index == target + 1) {
    video_blit(x, y);
    return mrb_nil_value();
  }

  u32 start = target - target % s_video.key_interval;

  u32 sequential = target >= s_video.frame_index ?
    target - s_video.frame_index + 1 : s_video.frame_count;
  u32 seek = target - start + 1;

  if (target + 1 < s_video.frame_index || seek < sequential) {
    if (fseek(s_video.file, s_video.offsets[start / s_video.key_interval], SEEK_SET) != 0)
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.video_frame: cannot seek");
    s_video.frame_index = start;
  }

  while (s_video.frame_index <= target)
    video_decode(mrb);

  video_blit(x, y);
  return mrb_nil_value();
}

static mrb_value video_close(mrb_state *mrb, mrb_value self)
{
  if (!s_video.file)
    video_raise_closed(mrb);
  video_shutdown();
  return mrb_nil_value();
}

void video_shutdown(void)
{
  if (s_video.file) {
    fclose(s_video.file);
    gfx_video_end();
  }
  free(s_video.offsets);
  free(s_video.frame);
  free(s_video.delta);
  free(s_video.packed);
  memset(&s_video, 0, sizeof s_video);
}

void register_video_bindings(mrb_state *mrb)
{
  struct RClass *gfx = mrb_define_module(mrb, "Gfx");
  mrb_define_module_function(mrb, gfx, "video_open", video_open, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, gfx, "video_frame", video_frame, MRB_ARGS_REQ(4));
  mrb_define_module_function(mrb, gfx, "video_close", video_close, MRB_ARGS_NONE());
}
