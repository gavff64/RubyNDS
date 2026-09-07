#include <nds.h>
#include <filesystem.h>
#include <stdint.h>

#include <mruby.h>
#include <mruby/irep.h>

#include "bindings.h"

extern const uint8_t app_bytecode[];

int main(void)
{
  consoleDemoInit();
  gfx_init();
  if (!nitroFSInit(NULL))
    printf("warning: NitroFS not found; assets unavailable\n");

  mrb_state *mrb = mrb_open();
  if (MRB_OPEN_FAILURE(mrb)) {
    if (mrb) mrb_print_error(mrb);
    if (mrb) mrb_close(mrb);
  }
  else {
    register_net_bindings(mrb);
    register_tls_bindings(mrb);
    register_input_bindings(mrb);
    register_gfx_bindings(mrb);
    register_video_bindings(mrb);
    register_fs_bindings(mrb);
    register_audio_bindings(mrb);
    register_mp3_bindings(mrb);
    register_system_bindings(mrb);

    mrb_load_irep(mrb, app_bytecode);
    if (mrb->exc) {
      consoleDemoInit();
      mrb_print_error(mrb);
    }

    video_shutdown();
    tls_shutdown();
    audio_shutdown();
    mp3_shutdown();
    fs_shutdown();
    mrb_close(mrb);
  }

  while (pmMainLoop()) swiWaitForVBlank();
  return 0;
}
