#include <nds.h>

#include <mruby.h>

#include "bindings.h"

static bool s_touched = false;
static u16 s_px = 0;
static u16 s_py = 0;
static touchPosition s_touch;

static mrb_value input_update(mrb_state *mrb, mrb_value self)
{
  scanKeys();
  s_touched = touchRead(&s_touch);
  if (s_touched) {
    s_px = s_touch.px;
    s_py = s_touch.py;
  }
  return mrb_nil_value();
}

static mrb_value input_held(mrb_state *mrb, mrb_value self)
{
  return mrb_int_value(mrb, (mrb_int)keysHeld());
}

static mrb_value input_down(mrb_state *mrb, mrb_value self)
{
  return mrb_int_value(mrb, (mrb_int)keysDown());
}

static mrb_value input_up(mrb_state *mrb, mrb_value self)
{
  return mrb_int_value(mrb, (mrb_int)keysUp());
}

static mrb_value input_touch_p(mrb_state *mrb, mrb_value self)
{
  return s_touched ? mrb_true_value() : mrb_false_value();
}

static mrb_value input_touch_x(mrb_state *mrb, mrb_value self)
{
  return mrb_int_value(mrb, (mrb_int)s_px);
}

static mrb_value input_touch_y(mrb_state *mrb, mrb_value self)
{
  return mrb_int_value(mrb, (mrb_int)s_py);
}

void register_input_bindings(mrb_state *mrb)
{
  struct RClass *inp = mrb_define_module(mrb, "Input");
  mrb_define_module_function(mrb, inp, "update",   input_update,   MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "held",     input_held,     MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "down",     input_down,     MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "up",       input_up,       MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch?",   input_touch_p,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch_x",  input_touch_x,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch_y",  input_touch_y,  MRB_ARGS_NONE());
}
