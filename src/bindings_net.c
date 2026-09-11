#include <nds.h>
#include <dswifi9.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <mruby.h>
#include <mruby/string.h>

#include "bindings.h"

#define NET_RECV_MAX 16384

static mrb_value net_wifi(mrb_state *mrb, mrb_value self)
{
  if (!Wifi_InitDefault(WFC_CONNECT))
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.wifi: no saved network found");
  return mrb_true_value();
}

static mrb_value net_ip(mrb_state *mrb, mrb_value self)
{
  struct in_addr ip, gw, mask, dns1, dns2;
  ip = Wifi_GetIPInfo(&gw, &mask, &dns1, &dns2);
  return mrb_str_new_cstr(mrb, inet_ntoa(ip));
}

static mrb_value net_dns(mrb_state *mrb, mrb_value self)
{
  mrb_value host;
  mrb_get_args(mrb, "S", &host);
  struct hostent *h = gethostbyname(mrb_string_cstr(mrb, host));
  if (!h || !h->h_addr_list[0])
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.dns: host not found");
  return mrb_str_new_cstr(mrb, inet_ntoa(*(struct in_addr *)h->h_addr_list[0]));
}

static mrb_value net_connect(mrb_state *mrb, mrb_value self)
{
  mrb_value host;
  mrb_int port;
  mrb_get_args(mrb, "Si", &host, &port);

  if (port < 0 || port > 65535)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Net.connect: port must be 0..65535");

  struct hostent *h = gethostbyname(mrb_string_cstr(mrb, host));
  if (!h || !h->h_addr_list[0])
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.connect: host not found");

  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.connect: socket failed");

  struct sockaddr_in sa;
  memset(&sa, 0, sizeof sa);
  sa.sin_family = AF_INET;
  sa.sin_port = htons((uint16_t)port);
  memcpy(&sa.sin_addr, h->h_addr_list[0], 4);

  if (connect(s, (struct sockaddr *)&sa, sizeof sa) < 0) {
    closesocket(s);
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.connect: connection failed");
  }
  return mrb_int_value(mrb, s);
}

static mrb_value net_listen(mrb_state *mrb, mrb_value self)
{
  mrb_int port, backlog = 1;
  mrb_get_args(mrb, "i|i", &port, &backlog);

  if (port < 0 || port > 65535)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Net.listen: port must be 0..65535");
  if (backlog < 1)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Net.listen: backlog must be positive");

  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.listen: socket failed");

  int enabled = 1;
  setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof enabled);

  struct sockaddr_in sa;
  memset(&sa, 0, sizeof sa);
  sa.sin_family = AF_INET;
  sa.sin_port = htons((uint16_t)port);
  sa.sin_addr.s_addr = INADDR_ANY;

  if (bind(s, (struct sockaddr *)&sa, sizeof sa) < 0 || listen(s, (int)backlog) < 0) {
    closesocket(s);
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.listen: failed");
  }
  return mrb_int_value(mrb, s);
}

static mrb_value net_accept(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_get_args(mrb, "i", &sock);

  struct sockaddr_in sa;
  socklen_t len = sizeof sa;
  int s = accept((int)sock, (struct sockaddr *)&sa, &len);
  if (s < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK)
      return mrb_nil_value();
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.accept: failed");
  }
  return mrb_int_value(mrb, s);
}

static mrb_value net_send(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_value data;
  mrb_get_args(mrb, "iS", &sock, &data);

  int n = send((int)sock, RSTRING_PTR(data), (int)RSTRING_LEN(data), 0);
  if (n < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK)
      return mrb_nil_value();
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.send: send failed");
  }
  return mrb_int_value(mrb, n);
}

static mrb_value net_recv(mrb_state *mrb, mrb_value self)
{
  mrb_int sock, maxlen;
  mrb_get_args(mrb, "ii", &sock, &maxlen);

  if (maxlen < 0)
    mrb_raise(mrb, E_ARGUMENT_ERROR, "Net.recv: maxlen must not be negative");
  if (maxlen == 0)
    return mrb_str_new(mrb, NULL, 0);
  if (maxlen > NET_RECV_MAX)
    maxlen = NET_RECV_MAX;

  mrb_value str = mrb_str_new(mrb, NULL, maxlen);
  int n = recv((int)sock, RSTRING_PTR(str), (int)maxlen, 0);
  if (n < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK)
      return mrb_nil_value();
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.recv: recv failed");
  }
  mrb_str_resize(mrb, str, n);
  return str;
}

static mrb_value net_nonblock(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_bool enabled;
  mrb_get_args(mrb, "ib", &sock, &enabled);

  int flag = enabled ? 1 : 0;
  if (ioctl((int)sock, FIONBIO, &flag) < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.nonblock: ioctl failed");
  return mrb_nil_value();
}

static mrb_value net_close(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_get_args(mrb, "i", &sock);
  closesocket((int)sock);
  return mrb_nil_value();
}

void register_net_bindings(mrb_state *mrb)
{
  struct RClass *net = mrb_define_module(mrb, "Net");
  mrb_define_module_function(mrb, net, "wifi",    net_wifi,    MRB_ARGS_NONE());
  mrb_define_module_function(mrb, net, "ip",      net_ip,      MRB_ARGS_NONE());
  mrb_define_module_function(mrb, net, "dns",     net_dns,     MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, net, "connect", net_connect, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "listen",  net_listen,  MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, net, "accept",  net_accept,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, net, "send",    net_send,    MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "recv",    net_recv,    MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "nonblock", net_nonblock, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "close",   net_close,   MRB_ARGS_REQ(1));
}
