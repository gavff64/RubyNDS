#include <nds.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/string.h>

#include "pvmp3decoder_api.h"

#include "bindings.h"

#define MP3_MAX_SAMPLES 2304

static tPVMP3DecoderExternal s_mp3;
static void *s_mp3_memory = NULL;
static int16 s_pcm[MP3_MAX_SAMPLES];

static mrb_value mp3_open(mrb_state *mrb, mrb_value self)
{
  if (!s_mp3_memory) {
    s_mp3_memory = malloc(pvmp3_decoderMemRequirements());
    if (!s_mp3_memory)
      mrb_raise(mrb, E_RUNTIME_ERROR, "MP3.open: allocation failed");
  }

  memset(&s_mp3, 0, sizeof s_mp3);
  s_mp3.equalizerType = flat;
  pvmp3_InitDecoder(&s_mp3, s_mp3_memory);
  return mrb_nil_value();
}

static mrb_value mp3_decode(mrb_state *mrb, mrb_value self)
{
  if (!s_mp3_memory)
    mrb_raise(mrb, E_RUNTIME_ERROR, "MP3.decode: decoder is not open");

  mrb_value data;
  mrb_int offset = 0;
  mrb_int length = -1;
  mrb_get_args(mrb, "S|ii", &data, &offset, &length);

  if (offset < 0 || offset > RSTRING_LEN(data))
    mrb_raise(mrb, E_ARGUMENT_ERROR, "MP3.decode: invalid offset");
  if (length < 0)
    length = RSTRING_LEN(data) - offset;
  if (length < 0 || length > RSTRING_LEN(data) - offset)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "MP3.decode: invalid length");

  s_mp3.pInputBuffer = (uint8 *)RSTRING_PTR(data) + offset;
  s_mp3.inputBufferCurrentLength = length;
  s_mp3.inputBufferMaxLength = length;
  s_mp3.inputBufferUsedLength = 0;
  s_mp3.pOutputBuffer = s_pcm;
  s_mp3.outputFrameSize = MP3_MAX_SAMPLES;

  ERROR_CODE error = pvmp3_framedecoder(&s_mp3, s_mp3_memory);
  mrb_int used = s_mp3.inputBufferUsedLength;
  if (error != NO_DECODING_ERROR && used == 0)
    used = 1;

  mrb_int samples = error == NO_DECODING_ERROR ? s_mp3.outputFrameSize : 0;
  mrb_value result[4];
  result[0] = mrb_str_new(mrb, (const char *)s_pcm, samples * sizeof *s_pcm);
  result[1] = mrb_int_value(mrb, used);
  result[2] = mrb_int_value(mrb, s_mp3.samplingRate);
  result[3] = mrb_int_value(mrb, s_mp3.num_channels);
  return mrb_ary_new_from_values(mrb, 4, result);
}

static mrb_value mp3_close(mrb_state *mrb, mrb_value self)
{
  free(s_mp3_memory);
  s_mp3_memory = NULL;
  memset(&s_mp3, 0, sizeof s_mp3);
  return mrb_nil_value();
}

void mp3_shutdown(void)
{
  free(s_mp3_memory);
  s_mp3_memory = NULL;
  memset(&s_mp3, 0, sizeof s_mp3);
}

void register_mp3_bindings(mrb_state *mrb)
{
  struct RClass *mp3 = mrb_define_module(mrb, "MP3");
  mrb_define_module_function(mrb, mp3, "open", mp3_open, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, mp3, "decode", mp3_decode, MRB_ARGS_ARG(1, 2));
  mrb_define_module_function(mrb, mp3, "close", mp3_close, MRB_ARGS_NONE());
}
