#include <nds.h>
#include <maxmod9.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/string.h>

#include "bindings.h"

#define AUDIO_MAX_RATE 48000
#define AUDIO_DEFAULT_BUFFER 4096
#define AUDIO_MIN_BUFFER 64
#define AUDIO_MAX_BUFFER 65536
#define AUDIO_MAX_SAMPLES 16
#define AUDIO_SAMPLE_8BIT 0
#define AUDIO_SAMPLE_16BIT 1
#define AUDIO_SAMPLE_REPEAT 1
#define AUDIO_SAMPLE_ONCE 2

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

typedef struct {
  bool loaded;
  mm_ds_sample sample;
  void *data;
} audio_sample_t;

static audio_state_t s_audio;
static audio_sample_t s_samples[AUDIO_MAX_SAMPLES];
static bool s_mm_inited = false;

static void audio_init(void)
{
  if (s_mm_inited)
    return;

  mm_ds_system sys;
  memset(&sys, 0, sizeof sys);
  sys.mod_count = 0;
  sys.samp_count = 0;
  sys.mem_bank = 0;
  mmInit(&sys);
  s_mm_inited = true;
}

static audio_sample_t *audio_sample_for_handle(mrb_state *mrb, mrb_int handle)
{
  if (handle < 1 || handle > AUDIO_MAX_SAMPLES || !s_samples[handle - 1].loaded)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio: invalid sample handle");
  return &s_samples[handle - 1];
}

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
      if (s_audio.bits == 8) {
        for (u32 i = 0; i < take; i++) {
          s32 s = ((const s8 *)src)[i];
          s = (s * (s32)vol) >> 10;
          if (s > 127) s = 127;
          if (s < -128) s = -128;
          ((s8 *)out)[i] = (s8)s;
        }
      }
      else {
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

  mrb_int kw_num = 4;
  mrb_int kw_required = 3;
  mrb_sym kw_names[] = { mrb_intern_lit(mrb, "sample_rate"),
                         mrb_intern_lit(mrb, "bits"),
                         mrb_intern_lit(mrb, "channels"),
                         mrb_intern_lit(mrb, "buffer_length") };
  mrb_value kw_values[4];
  mrb_kwargs kwargs = { kw_num, kw_required, kw_names, kw_values, NULL };
  mrb_get_args(mrb, ":", &kwargs);

  if (mrb_undef_p(kw_values[3]))
    kw_values[3] = mrb_fixnum_value(AUDIO_DEFAULT_BUFFER);

  mrb_int rate = mrb_as_int(mrb, kw_values[0]);
  mrb_int bits = mrb_as_int(mrb, kw_values[1]);
  mrb_int channels = mrb_as_int(mrb, kw_values[2]);
  mrb_int buffer_length = mrb_as_int(mrb, kw_values[3]);

  if (rate < 1024 || rate > AUDIO_MAX_RATE)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: sample_rate must be 1024..48000");
  if (bits != 8 && bits != 16)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: bits must be 8 or 16");
  if (channels != 1 && channels != 2)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: channels must be 1 or 2");
  if (buffer_length < AUDIO_MIN_BUFFER || buffer_length > AUDIO_MAX_BUFFER)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.open: buffer_length must be 64..65536");

  audio_init();

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
  stream.buffer_length = (mm_word)buffer_length;
  stream.callback = audio_fill;
  if (bits == 8)
    stream.format = channels == 2 ? MM_STREAM_8BIT_STEREO : MM_STREAM_8BIT_MONO;
  else
    stream.format = channels == 2 ? MM_STREAM_16BIT_STEREO : MM_STREAM_16BIT_MONO;
  stream.manual = true;
  mmStreamOpen(&stream);

  return mrb_nil_value();
}

static mrb_value audio_sample_load(mrb_state *mrb, mrb_value self)
{
  mrb_value data;
  mrb_int kw_num = 3;
  mrb_int kw_required = 1;
  mrb_sym kw_names[] = { mrb_intern_lit(mrb, "sample_rate"),
                         mrb_intern_lit(mrb, "bits"),
                         mrb_intern_lit(mrb, "loop") };
  mrb_value kw_values[3];
  mrb_kwargs kwargs = { kw_num, kw_required, kw_names, kw_values, NULL };
  mrb_get_args(mrb, "S:", &data, &kwargs);

  if (mrb_undef_p(kw_values[1])) kw_values[1] = mrb_fixnum_value(16);
  if (mrb_undef_p(kw_values[2])) kw_values[2] = mrb_false_value();

  mrb_int rate = mrb_as_int(mrb, kw_values[0]);
  mrb_int bits = mrb_as_int(mrb, kw_values[1]);
  mrb_bool loop = mrb_bool(kw_values[2]);
  mrb_int length = RSTRING_LEN(data);

  if (rate < 1024 || rate > AUDIO_MAX_RATE)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.sample_load: sample_rate must be 1024..48000");
  if (bits != 8 && bits != 16)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.sample_load: bits must be 8 or 16");
  if (length <= 0 || length % 4 != 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.sample_load: byte length must be a positive multiple of 4");

  mrb_int handle = 0;
  for (mrb_int i = 0; i < AUDIO_MAX_SAMPLES; i++) {
    if (!s_samples[i].loaded) {
      handle = i + 1;
      break;
    }
  }
  if (!handle)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Audio.sample_load: too many loaded samples");

  void *copy = malloc((size_t)length);
  if (!copy)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Audio.sample_load: allocation failed");
  memcpy(copy, RSTRING_PTR(data), (size_t)length);

  audio_sample_t *slot = &s_samples[handle - 1];
  memset(slot, 0, sizeof *slot);
  slot->sample.loop_start = 0;
  slot->sample.length = (mm_word)length / 4;
  slot->sample.format = bits == 8 ? AUDIO_SAMPLE_8BIT : AUDIO_SAMPLE_16BIT;
  slot->sample.repeat_mode = loop ? AUDIO_SAMPLE_REPEAT : AUDIO_SAMPLE_ONCE;
  slot->sample.base_rate = (mm_hword)((u32)rate * 1024 / 32768);
  slot->sample.data = copy;
  slot->data = copy;
  slot->loaded = true;
  DC_FlushRange(copy, (u32)length);
  DC_FlushRange(&slot->sample, sizeof slot->sample);

  audio_init();
  return mrb_int_value(mrb, handle);
}

static mrb_value audio_effect_play(mrb_state *mrb, mrb_value self)
{
  mrb_int sample_handle;
  mrb_int kw_num = 3;
  mrb_int kw_required = 0;
  mrb_sym kw_names[] = { mrb_intern_lit(mrb, "volume"),
                         mrb_intern_lit(mrb, "pan"),
                         mrb_intern_lit(mrb, "rate") };
  mrb_value kw_values[3];
  mrb_kwargs kwargs = { kw_num, kw_required, kw_names, kw_values, NULL };
  mrb_get_args(mrb, "i:", &sample_handle, &kwargs);

  if (mrb_undef_p(kw_values[0])) kw_values[0] = mrb_fixnum_value(100);
  if (mrb_undef_p(kw_values[1])) kw_values[1] = mrb_fixnum_value(50);
  if (mrb_undef_p(kw_values[2])) kw_values[2] = mrb_fixnum_value(100);

  mrb_int volume = mrb_as_int(mrb, kw_values[0]);
  mrb_int pan = mrb_as_int(mrb, kw_values[1]);
  mrb_int rate = mrb_as_int(mrb, kw_values[2]);

  if (volume < 0 || volume > 100)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_play: volume must be 0..100");
  if (pan < 0 || pan > 100)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_play: pan must be 0..100");
  if (rate < 25 || rate > 400)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_play: rate must be 25..400");

  audio_sample_t *sample = audio_sample_for_handle(mrb, sample_handle);
  mm_sound_effect effect;
  memset(&effect, 0, sizeof effect);
  effect.sample = &sample->sample;
  effect.rate = (mm_hword)(rate * 1024 / 100);
  effect.volume = (mm_byte)(volume * 255 / 100);
  effect.panning = (mm_byte)(pan * 255 / 100);

  mm_sfxhand handle = mmEffectEx(&effect);
  if (!handle)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Audio.effect_play: no effect channel available");
  return mrb_int_value(mrb, handle);
}

static mrb_value audio_effect_stop(mrb_state *mrb, mrb_value self)
{
  mrb_int handle;
  mrb_get_args(mrb, "i", &handle);
  mmEffectCancel((mm_sfxhand)handle);
  return mrb_nil_value();
}

static mrb_value audio_effect_release(mrb_state *mrb, mrb_value self)
{
  mrb_int handle;
  mrb_get_args(mrb, "i", &handle);
  mmEffectRelease((mm_sfxhand)handle);
  return mrb_nil_value();
}

static mrb_value audio_effect_volume(mrb_state *mrb, mrb_value self)
{
  mrb_int handle, volume;
  mrb_get_args(mrb, "ii", &handle, &volume);
  if (volume < 0 || volume > 100)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_volume: volume must be 0..100");
  mmEffectVolume((mm_sfxhand)handle, (mm_byte)(volume * 255 / 100));
  return mrb_nil_value();
}

static mrb_value audio_effect_pan(mrb_state *mrb, mrb_value self)
{
  mrb_int handle, pan;
  mrb_get_args(mrb, "ii", &handle, &pan);
  if (pan < 0 || pan > 100)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_pan: pan must be 0..100");
  mmEffectPanning((mm_sfxhand)handle, (mm_byte)(pan * 255 / 100));
  return mrb_nil_value();
}

static mrb_value audio_effect_rate(mrb_state *mrb, mrb_value self)
{
  mrb_int handle, rate;
  mrb_get_args(mrb, "ii", &handle, &rate);
  if (rate < 25 || rate > 400)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.effect_rate: rate must be 25..400");
  mmEffectRate((mm_sfxhand)handle, (mm_word)(rate * 1024 / 100));
  return mrb_nil_value();
}

static mrb_value audio_update(mrb_state *mrb, mrb_value self)
{
  if (!s_audio.open)
    audio_raise_closed(mrb);

  mrb_value data;
  mrb_int offset = 0;
  mrb_int length = -1;
  mrb_get_args(mrb, "S|ii", &data, &offset, &length);

  if (offset < 0 || offset > RSTRING_LEN(data))
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.update: invalid offset");
  if (length < 0)
    length = RSTRING_LEN(data) - offset;
  if (length < 0 || length > RSTRING_LEN(data) - offset)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Audio.update: invalid length");

  if (length % s_audio.sample_bytes != 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR,
              "Audio.update: byte length must be a multiple of the frame size");

  s_audio.feed = (const u8 *)RSTRING_PTR(data) + offset;
  s_audio.feed_len = (u32)length;
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
  if (s_mm_inited) {
    mmEffectCancelAll();
    swiWaitForVBlank();
    for (mrb_int i = 0; i < AUDIO_MAX_SAMPLES; i++) {
      if (s_samples[i].loaded) {
        free(s_samples[i].data);
        memset(&s_samples[i], 0, sizeof s_samples[i]);
      }
    }
  }
}

void register_audio_bindings(mrb_state *mrb)
{
  struct RClass *audio = mrb_define_module(mrb, "Audio");
  mrb_define_module_function(mrb, audio, "open",   audio_open,   MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "update", audio_update, MRB_ARGS_ARG(1, 2));
  mrb_define_module_function(mrb, audio, "volume=", audio_set_volume, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "close",  audio_close,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, audio, "sample_load", audio_sample_load, MRB_ARGS_REQ(1) | MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "effect_play", audio_effect_play, MRB_ARGS_REQ(1) | MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "effect_stop", audio_effect_stop, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "effect_release", audio_effect_release, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "effect_volume", audio_effect_volume, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, audio, "effect_pan", audio_effect_pan, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, audio, "effect_rate", audio_effect_rate, MRB_ARGS_REQ(2));
}
