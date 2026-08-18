#include <nds.h>
#include <filesystem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/string.h>

#include "bindings.h"

#define FS_MAX_FILES 8

static FILE *s_files[FS_MAX_FILES];

static FILE *file_for_handle(mrb_state *mrb, mrb_int handle)
{
  if (handle < 1 || handle > FS_MAX_FILES || !s_files[handle - 1])
    mrb_raise(mrb, E_ARGUMENT_ERROR, "FS: invalid or closed file handle");
  return s_files[handle - 1];
}

static mrb_value fs_open(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  FILE *f = fopen(RSTRING_PTR(path), "rb");
  if (!f)
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.open: cannot open file");

  for (mrb_int i = 0; i < FS_MAX_FILES; i++) {
    if (!s_files[i]) {
      s_files[i] = f;
      return mrb_int_value(mrb, i + 1);
    }
  }
  fclose(f);
  mrb_raise(mrb, E_RUNTIME_ERROR, "FS.open: too many open files");
  return mrb_nil_value();
}

static mrb_value fs_read(mrb_state *mrb, mrb_value self)
{
  mrb_int handle, length;
  mrb_get_args(mrb, "ii", &handle, &length);
  FILE *f = file_for_handle(mrb, handle);

  if (length < 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "FS.read: length must not be negative");
  if (length == 0)
    return mrb_str_new(mrb, NULL, 0);

  mrb_value str = mrb_str_new(mrb, NULL, length);
  size_t got = fread(RSTRING_PTR(str), 1, (size_t)length, f);
  if (got < (size_t)length && ferror(f))
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.read: read error");
  if (got < (size_t)length)
    mrb_str_resize(mrb, str, (mrb_int)got);
  return str;
}

static mrb_value fs_seek(mrb_state *mrb, mrb_value self)
{
  mrb_int handle, offset;
  mrb_int whence = SEEK_SET;
  mrb_get_args(mrb, "ii|i", &handle, &offset, &whence);

  FILE *f = file_for_handle(mrb, handle);
  if (whence < 0 || whence > 2)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "FS.seek: whence must be 0, 1 or 2");
  if (fseek(f, (long)offset, (int)whence) != 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.seek: seek failed");
  long pos = ftell(f);
  if (pos < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.seek: ftell failed");
  return mrb_int_value(mrb, (mrb_int)pos);
}

static mrb_value fs_close(mrb_state *mrb, mrb_value self)
{
  mrb_int handle;
  mrb_get_args(mrb, "i", &handle);

  FILE *f = file_for_handle(mrb, handle);
  fclose(f);
  s_files[handle - 1] = NULL;
  return mrb_nil_value();
}

void fs_shutdown(void)
{
  for (mrb_int i = 0; i < FS_MAX_FILES; i++) {
    if (s_files[i]) {
      fclose(s_files[i]);
      s_files[i] = NULL;
    }
  }
}

void register_fs_bindings(mrb_state *mrb)
{
  struct RClass *fs = mrb_define_module(mrb, "FS");
  mrb_define_module_function(mrb, fs, "open",  fs_open,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "read",  fs_read,  MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, fs, "seek",  fs_seek,  MRB_ARGS_ARG(2, 1));
  mrb_define_module_function(mrb, fs, "close", fs_close, MRB_ARGS_REQ(1));
}
