#include <nds.h>
#include <dswifi9.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>
#include <string.h>

#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <stdint.h>

extern const uint8_t app_bytecode[];

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
  struct hostent *h = gethostbyname(RSTRING_PTR(host));
  if (!h || !h->h_addr_list[0])
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.dns: host not found");
  return mrb_str_new_cstr(mrb, inet_ntoa(*(struct in_addr *)h->h_addr_list[0]));
}

static mrb_value net_connect(mrb_state *mrb, mrb_value self)
{
  mrb_value host;
  mrb_int port;
  mrb_get_args(mrb, "Si", &host, &port);

  struct hostent *h = gethostbyname(RSTRING_PTR(host));
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

static mrb_value net_send(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_value data;
  mrb_get_args(mrb, "iS", &sock, &data);
  int n = send((int)sock, RSTRING_PTR(data), (int)RSTRING_LEN(data), 0);
  if (n < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.send: send failed");
  return mrb_int_value(mrb, n);
}

static mrb_value net_recv(mrb_state *mrb, mrb_value self)
{
  mrb_int sock, maxlen;
  mrb_get_args(mrb, "ii", &sock, &maxlen);
  char buf[2048];
  int cap = maxlen > (mrb_int)sizeof buf ? (int)sizeof buf : (int)maxlen;
  int n = recv((int)sock, buf, cap, 0);
  if (n < 0)
    mrb_raise(mrb, E_RUNTIME_ERROR, "Net.recv: recv failed");
  return mrb_str_new(mrb, buf, n);
}

static mrb_value net_close(mrb_state *mrb, mrb_value self)
{
  mrb_int sock;
  mrb_get_args(mrb, "i", &sock);
  closesocket((int)sock);
  return mrb_nil_value();
}

int main(void)
{
  consoleDemoInit();

  mrb_state *mrb = mrb_open();
  if (MRB_OPEN_FAILURE(mrb)) {
    mrb_print_error(mrb);
    mrb_close(mrb);
  }
  else {
    struct RClass *net = mrb_define_module(mrb, "Net");
    mrb_define_module_function(mrb, net, "wifi",    net_wifi,    MRB_ARGS_NONE());
    mrb_define_module_function(mrb, net, "ip",      net_ip,      MRB_ARGS_NONE());
    mrb_define_module_function(mrb, net, "dns",     net_dns,     MRB_ARGS_REQ(1));
    mrb_define_module_function(mrb, net, "connect", net_connect, MRB_ARGS_REQ(2));
    mrb_define_module_function(mrb, net, "send",    net_send,    MRB_ARGS_REQ(2));
    mrb_define_module_function(mrb, net, "recv",    net_recv,    MRB_ARGS_REQ(2));
    mrb_define_module_function(mrb, net, "close",   net_close,   MRB_ARGS_REQ(1));

    mrb_load_irep(mrb, app_bytecode);
    if (mrb->exc) mrb_print_error(mrb);
    mrb_close(mrb);
  }

  for (;;) swiWaitForVBlank();
}
