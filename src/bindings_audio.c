#include <nds.h>
#include <maxmod9.h>
#include <string.h>

#include <mruby.h>
#include <mruby/string.h>

#include "bindings.h"

#define AUDIO_MAX_RATE 32768

typedef struct {
  bool open;
  u32 bits;
  u32 channels;
  u32 sample_bytes;
  mm_word volume;
  const u8 *feed;
  u32 feed_len;
  u32 feed_consumed;
} audio_state_t;

static audio_state_t s_audio;
static bool s_mm_inited = false;

static void audio_raise_closed(mrb_state *mrb)
{
  mrb_raise(mrb, E_RUNTIME_ERROR, "Audio: stream is not open");
}

static mm_word audio_fill(mm_word length, mm_addr dest, mm_stream_formats format)
{
  u8 *out = (u8 *)dest;
  u32 want = (u32)length * s_audio.sample_bytes;
  u32 available = s_audio.feed_len - s_audio.feed_consumed;
  u32 take = want < available ? want : available;
  mm_word vol = s_audio.volume;

  if (take > 0) {
    const u8 *src = s_audio.feed + s_audio.feed_consumed;
    if (vol != 1024) {
      s16 *dst = (s16 *)out;
      u32 frames = take / 2;
      for (u32 i = 0; i < frames; i++) {
        s32 s = ((const s16 *)src)[i];
        s = (s * (s32)vol) >> 10;
        if (s > 32767) s = 32767;
        if (s < -32768) s = -32768;
        dst[i] = (s16)s;
      }
    }
    else {
      memcpy(out, src, take);
    }
    s_audio.feed_consumed += take;
  }
  if (take < want)
    memset(out + take, 0, want - take);
  return length;
}

static mrb_value audio_open(mrb_state *mrb, mrb_value self)
{
  if (s_audio.open)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Audio.open: already open; close first");

  mrb_int kw_num = 3;
  mrb_int kw_required = 3;
  mrb_sym kw_names[] = { mrb_intern_lit(mrb, "sample_rate"),
                         mrb_intern_lit(mrb, "bits"),
                         mrb_intern_lit(mrb, "channels") };
  mrb_value kw_values[3];
  mrb_kwargs kwargs = { kw_num, kw_required, kw_names, kw_values, NULL };
  mrb_get_args(mrb, ":", &kwargs);

  mrb_int rate = mrb_as_int(mrb, kw_values[0]);
  mrb_int bits = mrb_as_int(mrb, kw_values[1]);
  mrb_int channels = mrb_as_int(mrb, kw_values[2]);

  if (rate < 1024 || rate > AUDIO_MAX_RATE)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: sample_rate must be 1024..32768");
  if (bits != 16)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: only 16-bit PCM is supported");
  if (channels != 1 && channels != 2)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: channels must be 1 or 2");

  if (!s_mm_inited) {
    mm_ds_system sys;
    memset(&sys, 0, sizeof sys);
    sys.mod_count = 0;
    sys.samp_count = 0;
    sys.mem_bank = 0;
    mmInit(&sys);
    s_mm_inited = true;
  }

  s_audio.open = true;
  s_audio.bits = (u32)bits;
  s_audio.channels = (u32)channels;
  s_audio.sample_bytes = (u32)(bits / 8) * (u32)channels;
  s_audio.volume = 1024;
  s_audio.feed = NULL;
  s_audio.feed_len = 0;
  s_audio.feed_consumed = 0;

  mm_stream stream;
  memset(&stream, 0, sizeof stream);
  stream.sampling_rate = (mm_word)rate;
  stream.buffer_length = 4096;
  stream.callback = audio_fill;
  stream.format = channels == 2 ? MM_STREAM_16BIT_STEREO : MM_STREAM_16BIT_MONO;
  stream.manual = true;
  mmStreamOpen(&stream);

  return mrb_nil_value();
}

static mrb_value audio_update(mrb_state *mrb, mrb_value self)
{
  if (!s_audio.open)
    audio_raise_closed(mrb);

  mrb_value data;
  mrb_get_args(mrb, "S", &data);

  if (RSTRING_LEN(data) % s_audio.sample_bytes != 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR,
              "Audio.update: byte length must be a multiple of the frame size");

  s_audio.feed = (const u8 *)RSTRING_PTR(data);
  s_audio.feed_len = (u32)RSTRING_LEN(data);
  s_audio.feed_consumed = 0;
  mmStreamUpdate();
  s_audio.feed = NULL;
  s_audio.feed_len = 0;
  return mrb_int_value(mrb, s_audio.feed_consumed);
}

static mrb_value audio_set_volume(mrb_state *mrb, mrb_value self)
{
  if (!s_audio.open)
    audio_raise_closed(mrb);

  mrb_int volume;
  mrb_get_args(mrb, "i", &volume);
  if (volume < 0 || volume > 100)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.volume=: must be 0..100");
  s_audio.volume = (mm_word)(volume * 1024 / 100);
  return mrb_nil_value();
}

static mrb_value audio_close(mrb_state *mrb, mrb_value self)
{
  if (!s_audio.open)
    audio_raise_closed(mrb);

  mmStreamClose();
  memset(&s_audio, 0, sizeof s_audio);
  return mrb_nil_value();
}

void audio_shutdown(void)
{
  if (s_audio.open) {
    mmStreamClose();
    memset(&s_audio, 0, sizeof s_audio);
  }
}

void register_audio_bindings(mrb_state *mrb)
{
  struct RClass *audio = mrb_define_module(mrb, "Audio");
  mrb_define_module_function(mrb, audio, "open",   audio_open,   MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "update", audio_update, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "volume=", audio_set_volume, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "close",  audio_close,  MRB_ARGS_NONE());
}
