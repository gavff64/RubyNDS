#include <nds.h>

#include <mruby.h>
#include <mruby/string.h>
#include <string.h>

#include "bindings.h"

#define GFX_SCREEN_W 256
#define GFX_SCREEN_H 192
#define GFX_PITCH_PX 256

static u16 *s_fb = NULL;

void gfx_init(void)
{
  videoSetMode(MODE_5_2D);
  vramSetBankA(VRAM_A_MAIN_BG);
  int bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0);
  s_fb = bgGetGfxPtr(bg);
}

static void check_screen_is_top(mrb_state *mrb, mrb_value v)
{
  if (mrb_symbol_p(v) && strcmp(mrb_sym_name(mrb, mrb_symbol(v)), "top") == 0)
    return;
  mrb_raise(mrb, E_ARGUMENT_ERROR, "screen must be :top");
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

  check_screen_is_top(mrb, screen_v);
  check_rect(mrb, x, y, w, h);

  mrb_int need = w * h * 2;
  if (RSTRING_LEN(pixels) < need)
    mrb_raise(mrb, E_ARGUMENT_ERROR,
              "Gfx.blit: pixel string too short for the rectangle");

  const u8 *src = (const u8 *)RSTRING_PTR(pixels);
  for (mrb_int row = 0; row < h; row++) {
    u16 *dst = s_fb + (y + row) * GFX_PITCH_PX + x;
    memcpy(dst, src + (size_t)row * w * 2, (size_t)w * 2);
  }
  return mrb_nil_value();
}

static mrb_value gfx_fill_rect(mrb_state *mrb, mrb_value self)
{
  mrb_value screen_v;
  mrb_int x, y, w, h, color;
  mrb_get_args(mrb, "oiiiii", &screen_v, &x, &y, &w, &h, &color);

  check_screen_is_top(mrb, screen_v);
  check_rect(mrb, x, y, w, h);

  if (color < 0 || color > 0xFFFF)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "color must be a 16-bit pixel value");

  for (mrb_int row = 0; row < h; row++) {
    u16 *dst = s_fb + (y + row) * GFX_PITCH_PX + x;
    for (mrb_int col = 0; col < w; col++)
      dst[col] = (u16)color;
  }
  return mrb_nil_value();
}

void register_gfx_bindings(mrb_state *mrb)
{
  struct RClass *gfx = mrb_define_module(mrb, "Gfx");
  mrb_define_module_function(mrb, gfx, "blit",      gfx_blit,      MRB_ARGS_REQ(6));
  mrb_define_module_function(mrb, gfx, "fill_rect", gfx_fill_rect, MRB_ARGS_REQ(6));
}
