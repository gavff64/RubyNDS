#include <nds.h>

#include <mruby.h>

#include "bindings.h"

static mrb_value sys_vblank(mrb_state *mrb, mrb_value self)
{
  swiWaitForVBlank();
  return mrb_nil_value();
}

static mrb_value sys_main_loop_p(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(pmMainLoop());
}

void register_system_bindings(mrb_state *mrb)
{
  struct RClass *sys = mrb_define_module(mrb, "System");
  mrb_define_module_function(mrb, sys, "vblank",    sys_vblank,    MRB_ARGS_NONE());
  mrb_define_module_function(mrb, sys, "main_loop?", sys_main_loop_p, MRB_ARGS_NONE());
}
