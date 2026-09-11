#include <nds.h>
#include <dirent.h>
#include <fat.h>
#include <filesystem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include <mruby.h>
#include <mruby/array.h>
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
  mrb_value path, mode;
  mode = mrb_str_new_lit(mrb, "rb");
  mrb_get_args(mrb, "S|S", &path, &mode);

  FILE *f = fopen(RSTRING_PTR(path), RSTRING_PTR(mode));
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

static mrb_value fs_write(mrb_state *mrb, mrb_value self)
{
  mrb_int handle;
  mrb_value data;
  mrb_get_args(mrb, "iS", &handle, &data);
  FILE *f = file_for_handle(mrb, handle);

  size_t wrote = fwrite(RSTRING_PTR(data), 1, (size_t)RSTRING_LEN(data), f);
  if (wrote < (size_t)RSTRING_LEN(data) && ferror(f))
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.write: write error");
  return mrb_int_value(mrb, (mrb_int)wrote);
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

static mrb_value fs_mount(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(fatInitDefault());
}

static mrb_value fs_entries(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  DIR *dir = opendir(RSTRING_PTR(path));
  if (!dir)
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.entries: cannot open directory");

  mrb_value entries = mrb_ary_new(mrb);
  struct dirent *entry;
  while ((entry = readdir(dir)))
    mrb_ary_push(mrb, entries, mrb_str_new_cstr(mrb, entry->d_name));
  closedir(dir);
  return entries;
}

static mrb_value fs_directory(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  struct stat info;
  if (stat(RSTRING_PTR(path), &info) != 0)
    return mrb_false_value();
  return mrb_bool_value(S_ISDIR(info.st_mode));
}

static mrb_value fs_size(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);

  struct stat info;
  if (stat(RSTRING_PTR(path), &info) != 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "FS.size: cannot read file");
  return mrb_int_value(mrb, (mrb_int)info.st_size);
}

static mrb_value fs_mkdir(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);
  return mrb_bool_value(mkdir(RSTRING_PTR(path), 0777) == 0);
}

static mrb_value fs_remove(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);
  return mrb_bool_value(remove(RSTRING_PTR(path)) == 0);
}

static mrb_value fs_rename(mrb_state *mrb, mrb_value self)
{
  mrb_value from, to;
  mrb_get_args(mrb, "SS", &from, &to);
  return mrb_bool_value(rename(RSTRING_PTR(from), RSTRING_PTR(to)) == 0);
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
  mrb_define_module_function(mrb, fs, "mount", fs_mount, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, fs, "open",  fs_open,  MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, fs, "read",  fs_read,  MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, fs, "write", fs_write, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, fs, "seek",  fs_seek,  MRB_ARGS_ARG(2, 1));
  mrb_define_module_function(mrb, fs, "close", fs_close, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "entries", fs_entries, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "directory?", fs_directory, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "size", fs_size, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "mkdir", fs_mkdir, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "remove", fs_remove, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "rename", fs_rename, MRB_ARGS_REQ(2));
}
