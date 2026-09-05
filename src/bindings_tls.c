#include <nds.h>
#include <fat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>

#include <mruby.h>
#include <mruby/string.h>

#include "bindings.h"
#include "bearssl.h"
#include "tls_roots.h"

typedef struct {
  br_ssl_client_context client;
  br_x509_minimal_context x509;
  br_sslio_context io;
  unsigned char buffer[BR_SSL_BUFSIZE_MONO];
  int socket;
} tls_state_t;

static tls_state_t *s_tls = NULL;
static br_hmac_drbg_context s_random;
static bool s_seeded = false;

static mrb_value tls_seed(mrb_state *mrb, mrb_value self)
{
  mrb_value path;
  mrb_get_args(mrb, "S", &path);
  if (s_seeded)
    return mrb_nil_value();

  fatInitDefault();
  FILE *file = fopen(mrb_string_cstr(mrb, path), "r+b");
  if (!file)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.seed: cannot open writable seed file");

  unsigned char seed[32];
  if (fread(seed, 1, sizeof seed, file) != sizeof seed || fgetc(file) != EOF) {
    fclose(file);
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.seed: expected a private 32-byte seed file");
  }

  br_hmac_drbg_init(&s_random, &br_sha256_vtable, seed, sizeof seed);
  br_hmac_drbg_generate(&s_random, seed, sizeof seed);
  bool saved = fseek(file, 0, SEEK_SET) == 0 &&
    fwrite(seed, 1, sizeof seed, file) == sizeof seed;
  if (fclose(file) != 0)
    saved = false;
  memset(seed, 0, sizeof seed);

  if (!saved)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.seed: cannot replace seed file");
  s_seeded = true;
  return mrb_nil_value();
}

static int tls_read(void *context, unsigned char *data, size_t length)
{
  int count = recv(*(int *)context, data, length, 0);
  return count > 0 ? count : -1;
}

static int tls_write(void *context, const unsigned char *data, size_t length)
{
  int count = send(*(int *)context, data, length, 0);
  return count > 0 ? count : -1;
}

void tls_shutdown(void)
{
  if (s_tls) {
    memset(s_tls, 0, sizeof *s_tls);
    free(s_tls);
    s_tls = NULL;
  }
}

static void tls_check_open(mrb_state *mrb)
{
  if (!s_tls)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS: connection is not open");
}

static void tls_error(mrb_state *mrb)
{
  int error = br_ssl_engine_last_error(&s_tls->client.eng);
  tls_shutdown();
  mrb_raisef(mrb, E_RUNTIME_ERROR, "TLS: handshake or I/O failed (%i)", (mrb_int)error);
}

static mrb_value tls_open(mrb_state *mrb, mrb_value self)
{
  mrb_int socket;
  mrb_value host;
  mrb_get_args(mrb, "iS", &socket, &host);
  const char *name = mrb_string_cstr(mrb, host);

  if (s_tls)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.open: already open; close first");
  if (!s_seeded)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.open: call TLS.seed first");
  if (socket < 0 || !*name || strlen(name) > 253)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "TLS.open: invalid socket or hostname");

  s_tls = calloc(1, sizeof *s_tls);
  if (!s_tls)
    mrb_raise(mrb, E_RUNTIME_ERROR, "TLS.open: allocation failed");
  s_tls->socket = socket;
  br_ssl_client_init_full(&s_tls->client, &s_tls->x509, TAs, TAs_NUM);
  br_x509_minimal_set_minrsa(&s_tls->x509, 256);
  br_ssl_engine_set_versions(&s_tls->client.eng, BR_TLS12, BR_TLS12);
  br_ssl_engine_add_flags(&s_tls->client.eng, BR_OPT_NO_RENEGOTIATION);

  static const uint16_t suites[] = {
    BR_TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
    BR_TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
    BR_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
    BR_TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  };
  br_ssl_engine_set_suites(&s_tls->client.eng, suites, sizeof suites / sizeof suites[0]);
  br_ssl_engine_set_buffer(&s_tls->client.eng, s_tls->buffer, sizeof s_tls->buffer, 0);

  unsigned char seed[32];
  br_hmac_drbg_generate(&s_random, seed, sizeof seed);
  br_ssl_engine_inject_entropy(&s_tls->client.eng, seed, sizeof seed);
  memset(seed, 0, sizeof seed);

  if (!br_ssl_client_reset(&s_tls->client, name, 0))
    tls_error(mrb);
  br_sslio_init(&s_tls->io, &s_tls->client.eng,
    tls_read, &s_tls->socket, tls_write, &s_tls->socket);
  if (br_sslio_flush(&s_tls->io) < 0)
    tls_error(mrb);
  return mrb_true_value();
}

static mrb_value tls_send(mrb_state *mrb, mrb_value self)
{
  mrb_value data;
  mrb_get_args(mrb, "S", &data);
  tls_check_open(mrb);

  int count = br_sslio_write(&s_tls->io, RSTRING_PTR(data), RSTRING_LEN(data));
  if (count < 0 || br_sslio_flush(&s_tls->io) < 0)
    tls_error(mrb);
  return mrb_int_value(mrb, count);
}

static mrb_value tls_recv(mrb_state *mrb, mrb_value self)
{
  mrb_int length;
  mrb_get_args(mrb, "i", &length);
  tls_check_open(mrb);
  if (length < 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "TLS.recv: length must not be negative");
  if (length > 16384)
    length = 16384;

  mrb_value data = mrb_str_new(mrb, NULL, length);
  int count = br_sslio_read(&s_tls->io, RSTRING_PTR(data), length);
  if (count < 0) {
    if (br_ssl_engine_last_error(&s_tls->client.eng) != BR_ERR_OK)
      tls_error(mrb);
    count = 0;
  }
  mrb_str_resize(mrb, data, count);
  return data;
}

static mrb_value tls_close(mrb_state *mrb, mrb_value self)
{
  tls_shutdown();
  return mrb_nil_value();
}

void register_tls_bindings(mrb_state *mrb)
{
  struct RClass *tls = mrb_define_module(mrb, "TLS");
  mrb_define_module_function(mrb, tls, "seed",  tls_seed,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "open",  tls_open,  MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, tls, "send",  tls_send,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "recv",  tls_recv,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "close", tls_close, MRB_ARGS_NONE());
}
