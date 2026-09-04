#include <nds.h>

#include <mruby.h>

#include "bindings.h"

static mrb_value sys_vblank(mrb_state *mrb, mrb_value self)
{
  mrb_incremental_gc(mrb);
  swiWaitForVBlank();
  return mrb_nil_value();
}

static mrb_value sys_main_loop_p(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(pmMainLoop());
}

static mrb_value sys_milliseconds(mrb_state *mrb, mrb_value self)
{
  u64 milliseconds = tickGetCount() * 1000 / TICK_FREQ;
  return mrb_int_value(mrb, (mrb_int)(milliseconds & 0x7FFFFFFF));
}

void register_system_bindings(mrb_state *mrb)
{
  struct RClass *sys = mrb_define_module(mrb, "System");
  mrb_define_module_function(mrb, sys, "vblank",    sys_vblank,    MRB_ARGS_NONE());
  mrb_define_module_function(mrb, sys, "main_loop?", sys_main_loop_p, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, sys, "milliseconds", sys_milliseconds, MRB_ARGS_NONE());
}
