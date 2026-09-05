#ifndef DSI_RUBY_BINDINGS_H
#define DSI_RUBY_BINDINGS_H

#include <mruby.h>

void register_net_bindings(mrb_state *mrb);
void register_tls_bindings(mrb_state *mrb);
void register_input_bindings(mrb_state *mrb);
void register_gfx_bindings(mrb_state *mrb);
void register_video_bindings(mrb_state *mrb);
void register_fs_bindings(mrb_state *mrb);
void register_audio_bindings(mrb_state *mrb);
void register_system_bindings(mrb_state *mrb);

void gfx_init(void);
u8 *gfx_video_begin(const u16 *palette);
void gfx_video_end(void);
void fs_shutdown(void);
void tls_shutdown(void);
void audio_shutdown(void);
void video_shutdown(void);

#endif
