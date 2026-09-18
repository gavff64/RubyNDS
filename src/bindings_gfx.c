#include <nds.h>

#include <mruby.h>
#include <mruby/string.h>
#include <string.h>

#include "bindings.h"
#include "JPEGDEC.h"

#define GFX_SCREEN_W 256
#define GFX_SCREEN_H 192
#define GFX_PITCH_PX 256

static u16 *s_fb = NULL;
static u16 *s_bottom_fb = NULL;
static int s_bg = 0;
static int s_bottom_bg = 0;
static bool s_video = false;
static bool s_bottom_terminal = true;
static JPEGIMAGE s_jpeg __attribute__((section(".itcm"), aligned(32)));

static int jpeg_output(JPEGDRAW *draw)
{
  u16 *framebuffer = draw->pUser;

  for (int row = 0; row < draw->iHeight; row++) {
    u16 *source = draw->pPixels + row * draw->iWidth;
    u16 *dest = framebuffer + (draw->y + row) * GFX_PITCH_PX + draw->x;
    memcpy(dest, source, draw->iWidthUsed * 2);
  }

  return 1;
}

void gfx_init(void)
{
  videoSetMode(MODE_5_2D);
  vramSetBankA(VRAM_A_MAIN_BG);
  s_bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
  s_fb = bgGetGfxPtr(s_bg);
}

u8 *gfx_video_begin(const u16 *palette)
{
  s_bg = bgInit(3, BgType_Bmp8, BgSize_B8_256x256, 0, 0);
  u8 *framebuffer = (u8 *)bgGetGfxPtr(s_bg);
  int background = 0;
  int darkness = 94;

  for (int i = 0; i < 256; i++) {
    int color = palette[i];
    int value = (color & 31) + (color >> 5 & 31) + (color >> 10 & 31);
    if (value < darkness) {
      background = i;
      darkness = value;
    }
  }

  DC_FlushRange(palette, 512);
  dmaCopy(palette, BG_PALETTE, 512);
  dmaFillWords((u32)background * 0x01010101, framebuffer, 256 * 256);
  s_video = true;
  return framebuffer;
}

void gfx_video_end(void)
{
  if (!s_video)
    return;
  s_bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
  s_fb = bgGetGfxPtr(s_bg);
  dmaFillWords(0, s_fb, 256 * 256 * 2);
  s_video = false;
}

static u16 *screen_framebuffer(mrb_state *mrb, mrb_value screen)
{
  if (!mrb_symbol_p(screen))
    mrb_raise(mrb, E_ARGUMENT_ERROR, "screen must be :top or :bottom");

  const char *name = mrb_sym_name(mrb, mrb_symbol(screen));

  if (strcmp(name, "top") == 0) {
    if (s_video)
      mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx: drawing is unavailable while video is open");
    return s_fb;
  }

  if (strcmp(name, "bottom") == 0)
    return s_bottom_terminal ? NULL : s_bottom_fb;

  mrb_raise(mrb, E_ARGUMENT_ERROR, "screen must be :top or :bottom");
  return NULL;
}

static void check_rect(mrb_state *mrb, mrb_int x, mrb_int y,
                       mrb_int w, mrb_int h)
{
  if (x < 0 || y < 0 || w <= 0 || h <= 0 ||
      x >= GFX_SCREEN_W || y >= GFX_SCREEN_H ||
      w > GFX_SCREEN_W - x || h > GFX_SCREEN_H - y)
    mrb_raise(mrb, E_ARGUMENT_ERROR,
              "rectangle must be positive and fit within 256x192");
}

static mrb_value gfx_blit(mrb_state *mrb, mrb_value self)
{
  mrb_value screen_v, pixels;
  mrb_int x, y, w, h;
  mrb_get_args(mrb, "oiiiiS", &screen_v, &x, &y, &w, &h, &pixels);

  u16 *framebuffer = screen_framebuffer(mrb, screen_v);
  check_rect(mrb, x, y, w, h);

  if (!framebuffer)
    return mrb_nil_value();

  mrb_int need = w * h * 2;
  if (RSTRING_LEN(pixels) < need)
    mrb_raise(mrb, E_ARGUMENT_ERROR,
              "Gfx.blit: pixel string too short for the rectangle");

  const u8 *src = (const u8 *)RSTRING_PTR(pixels);
  for (mrb_int row = 0; row < h; row++) {
    u16 *dst = framebuffer + (y + row) * GFX_PITCH_PX + x;
    memcpy(dst, src + (size_t)row * w * 2, (size_t)w * 2);
  }
  return mrb_nil_value();
}

static mrb_value gfx_fill_rect(mrb_state *mrb, mrb_value self)
{
  mrb_value screen_v;
  mrb_int x, y, w, h, color;
  mrb_get_args(mrb, "oiiiii", &screen_v, &x, &y, &w, &h, &color);

  u16 *framebuffer = screen_framebuffer(mrb, screen_v);
  check_rect(mrb, x, y, w, h);

  if (!framebuffer)
    return mrb_nil_value();

  if (color < 0 || color > 0xFFFF)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "color must be a 16-bit pixel value");

  for (mrb_int row = 0; row < h; row++) {
    u16 *dst = framebuffer + (y + row) * GFX_PITCH_PX + x;
    for (mrb_int col = 0; col < w; col++)
      dst[col] = (u16)color;
  }
  return mrb_nil_value();
}

static mrb_value gfx_jpeg(mrb_state *mrb, mrb_value self)
{
  mrb_value screen_v, data;
  mrb_int x, y, scale = 0;
  mrb_get_args(mrb, "oiiS|i", &screen_v, &x, &y, &data, &scale);

  if (scale < 0 || scale > 3)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Gfx.jpeg: scale must be 0..3");

  u16 *framebuffer = screen_framebuffer(mrb, screen_v);
  if (!framebuffer)
    return mrb_nil_value();

  if (!JPEG_openRAM(&s_jpeg, (u8 *)RSTRING_PTR(data), RSTRING_LEN(data), jpeg_output))
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.jpeg: invalid JPEG");

  int unit = 1 << scale;
  int width = (s_jpeg.iWidth + unit - 1) >> scale;
  int height = (s_jpeg.iHeight + unit - 1) >> scale;
  if (x == -1) x = (GFX_SCREEN_W - width) / 2;
  if (y == -1) y = (GFX_SCREEN_H - height) / 2;
  if (x < 0 || y < 0 || x + width > GFX_SCREEN_W || y + height > GFX_SCREEN_H)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Gfx.jpeg: image must fit within 256x192");

  s_jpeg.pUser = framebuffer;
  if (!JPEG_decode(&s_jpeg, x, y, scale ? 1 << scale : 0))
    mrb_raise(mrb, E_RUNTIME_ERROR, "Gfx.jpeg: decode failed");
  return mrb_nil_value();
}

static mrb_value gfx_bottom_mode(mrb_state *mrb, mrb_value self)
{
  mrb_sym mode;
  mrb_get_args(mrb, "n", &mode);

  const char *name = mrb_sym_name(mrb, mode);
  if (strcmp(name, "graphics") == 0 && s_bottom_terminal) {
    videoSetModeSub(MODE_5_2D);
    vramSetBankC(VRAM_C_SUB_BG);
    s_bottom_bg = bgInitSub(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
    s_bottom_fb = bgGetGfxPtr(s_bottom_bg);
    dmaFillWords(0, s_bottom_fb, 256 * 256 * 2);
    s_bottom_terminal = false;
  }
  else if (strcmp(name, "terminal") == 0 && !s_bottom_terminal) {
    consoleDemoInit();
    s_bottom_fb = NULL;
    s_bottom_terminal = true;
  }
  else if (strcmp(name, "graphics") != 0 && strcmp(name, "terminal") != 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "mode must be :graphics or :terminal");

  return mrb_nil_value();
}

static mrb_value gfx_stretch(mrb_state *mrb, mrb_value self)
{
  mrb_sym screen;
  mrb_int width, height;
  mrb_get_args(mrb, "nii", &screen, &width, &height);

  if (width <= 0 || width > 256 || height <= 0 || height > 192)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "size must fit within 256x192");

  const char *name = mrb_sym_name(mrb, screen);
  if (strcmp(name, "top") == 0)
    bgSetScale(s_bg, width, height * 4 / 3);
  else if (strcmp(name, "bottom") == 0 && !s_bottom_terminal)
    bgSetScale(s_bottom_bg, width, height * 4 / 3);
  else
    mrb_raise(mrb, E_ARGUMENT_ERROR, "screen must use graphics mode");

  bgUpdate();
  return mrb_nil_value();
}

void register_gfx_bindings(mrb_state *mrb)
{
  struct RClass *gfx = mrb_define_module(mrb, "Gfx");
  mrb_define_module_function(mrb, gfx, "blit",      gfx_blit,      MRB_ARGS_REQ(6));
  mrb_define_module_function(mrb, gfx, "fill_rect", gfx_fill_rect, MRB_ARGS_REQ(6));
  mrb_define_module_function(mrb, gfx, "jpeg",      gfx_jpeg,      MRB_ARGS_ARG(4, 1));
  mrb_define_module_function(mrb, gfx, "bottom_mode", gfx_bottom_mode, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, gfx, "stretch",   gfx_stretch,   MRB_ARGS_REQ(3));
}
