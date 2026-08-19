#include "mruby.h"
#include "mruby/string.h"

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <stdarg.h>
#include <stdio.h>
#include <errno.h>

#ifndef FOREGROUND_MASK
# define FOREGROUND_MASK (FOREGROUND_RED|FOREGROUND_BLUE|FOREGROUND_GREEN|FOREGROUND_INTENSITY)
#endif
#ifndef BACKGROUND_MASK
# define BACKGROUND_MASK (BACKGROUND_RED|BACKGROUND_BLUE|BACKGROUND_GREEN|BACKGROUND_INTENSITY)
#endif

// Taken from https://github.com/mattn/ansicolor-w32.c

int
_fwrite_w32(wchar_t* buf) {
  static WORD attr_olds[2] = {-1, -1}, attr_old;
  int type = 0;
  HANDLE handle = INVALID_HANDLE_VALUE;
  WORD attr;
  DWORD written, csize;
  CONSOLE_CURSOR_INFO cci;
  CONSOLE_SCREEN_BUFFER_INFO csbi;
  COORD coord;
  const wchar_t *ptr = buf;

  handle = (HANDLE) GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(handle, &csbi);
  attr = csbi.wAttributes;

  if (attr_olds[type] == (WORD) -1) {
    attr_olds[type] = attr;
  }
  attr_old = attr;

  while (*ptr) {
    if (*ptr == '\033') {
      wchar_t c;
      int i, n = 0, m, v[6], w, h;
      for (i = 0; i < 6; i++) v[i] = -1;
      ptr++;
retry:
      if ((c = *ptr++) == 0) break;
      if (isdigit(c)) {
        if (v[n] == -1) v[n] = c - '0';
        else v[n] = v[n] * 10 + c - '0';
        goto retry;
      }
      if (c == '[') {
        goto retry;
      }
      if (c == ';') {
        if (++n == 6) break;
        goto retry;
      }
      if (c == '>' || c == '?') {
        m = c;
        goto retry;
      }

      switch (c) {
        case 'h':
          if (m == '?') {
            for (i = 0; i <= n; i++) {
              switch (v[i]) {
                case 3:
                  GetConsoleScreenBufferInfo(handle, &csbi);
                  w = csbi.dwSize.X;
                  h = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
                  csize = w * (h + 1);
                  coord.X = 0;
                  coord.Y = csbi.srWindow.Top;
                  FillConsoleOutputCharacter(handle, ' ', csize, coord, &written);
                  FillConsoleOutputAttribute(handle, csbi.wAttributes, csize, coord, &written);
                  SetConsoleCursorPosition(handle, csbi.dwCursorPosition);
                  csbi.dwSize.X = 132;
                  SetConsoleScreenBufferSize(handle, csbi.dwSize);
                  csbi.srWindow.Right = csbi.srWindow.Left + 131;
                  SetConsoleWindowInfo(handle, TRUE, &csbi.srWindow);
                  break;
                case 5:
                  attr =
                    ((attr & FOREGROUND_MASK) << 4) |
                    ((attr & BACKGROUND_MASK) >> 4);
                  SetConsoleTextAttribute(handle, attr);
                  break;
                case 9:
                  break;
                case 25:
                  GetConsoleCursorInfo(handle, &cci);
                  cci.bVisible = TRUE;
                  SetConsoleCursorInfo(handle, &cci);
                  break;
                case 47:
                  coord.X = 0;
                  coord.Y = 0;
                  SetConsoleCursorPosition(handle, coord);
                  break;
                default:
                  break;
              }
            }
          } else if (m == '>' && v[0] == 5) {
            GetConsoleCursorInfo(handle, &cci);
            cci.bVisible = FALSE;
            SetConsoleCursorInfo(handle, &cci);
          }
          break;
        case 'l':
          if (m == '?') {
            for (i = 0; i <= n; i++) {
              switch (v[i]) {
                case 3:
                  GetConsoleScreenBufferInfo(handle, &csbi);
                  w = csbi.dwSize.X;
                  h = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
                  csize = w * (h + 1);
                  coord.X = 0;
                  coord.Y = csbi.srWindow.Top;
                  FillConsoleOutputCharacter(handle, ' ', csize, coord, &written);
                  FillConsoleOutputAttribute(handle, csbi.wAttributes, csize, coord, &written);
                  SetConsoleCursorPosition(handle, csbi.dwCursorPosition);
                  csbi.srWindow.Right = csbi.srWindow.Left + 79;
                  SetConsoleWindowInfo(handle, TRUE, &csbi.srWindow);
                  csbi.dwSize.X = 80;
                  SetConsoleScreenBufferSize(handle, csbi.dwSize);
                  break;
                case 5:
                  attr =
                    ((attr & FOREGROUND_MASK) << 4) |
                    ((attr & BACKGROUND_MASK) >> 4);
                  SetConsoleTextAttribute(handle, attr);
                  break;
                case 25:
                  GetConsoleCursorInfo(handle, &cci);
                  cci.bVisible = FALSE;
                  SetConsoleCursorInfo(handle, &cci);
                  break;
                default:
                  break;
              }
            }
          }
          else if (m == '>' && v[0] == 5) {
            GetConsoleCursorInfo(handle, &cci);
            cci.bVisible = TRUE;
            SetConsoleCursorInfo(handle, &cci);
          }
          break;
        case 'm':
          attr = attr_old;
          for (i = 0; i <= n; i++) {
            if (v[i] == -1 || v[i] == 0)
              attr = attr_olds[type];
            else if (v[i] == 1)
              attr |= FOREGROUND_INTENSITY;
            else if (v[i] == 4)
              attr |= FOREGROUND_INTENSITY;
            else if (v[i] == 5)
              attr |= FOREGROUND_INTENSITY;
            else if (v[i] == 7)
              attr =
                ((attr & FOREGROUND_MASK) << 4) |
                ((attr & BACKGROUND_MASK) >> 4);
            else if (v[i] == 10)
              ; // symbol on
            else if (v[i] == 11)
              ; // symbol off
            else if (v[i] == 22)
              attr &= ~FOREGROUND_INTENSITY;
            else if (v[i] == 24)
              attr &= ~FOREGROUND_INTENSITY;
            else if (v[i] == 25)
              attr &= ~FOREGROUND_INTENSITY;
            else if (v[i] == 27)
              attr =
                ((attr & FOREGROUND_MASK) << 4) |
                ((attr & BACKGROUND_MASK) >> 4);
            else if (v[i] >= 30 && v[i] <= 37) {
              attr = (attr & BACKGROUND_MASK);
              if ((v[i] - 30) & 1)
                attr |= FOREGROUND_RED;
              if ((v[i] - 30) & 2)
                attr |= FOREGROUND_GREEN;
              if ((v[i] - 30) & 4)
                attr |= FOREGROUND_BLUE;
            }
            //else if (v[i] == 39)
            //attr = (~attr & BACKGROUND_MASK);
            else if (v[i] >= 40 && v[i] <= 47) {
              attr = (attr & FOREGROUND_MASK);
              if ((v[i] - 40) & 1)
                attr |= BACKGROUND_RED;
              if ((v[i] - 40) & 2)
                attr |= BACKGROUND_GREEN;
              if ((v[i] - 40) & 4)
                attr |= BACKGROUND_BLUE;
            }
            else if (v[i] >= 90 && v[i] <= 97) {
              attr = (attr & BACKGROUND_MASK) | FOREGROUND_INTENSITY;
              if ((v[i] - 90) & 1)
                attr |= FOREGROUND_RED;
              if ((v[i] - 90) & 2)
                attr |= FOREGROUND_GREEN;
              if ((v[i] - 90) & 4)
                attr |= FOREGROUND_BLUE;
            }
            else if (v[i] >= 100 && v[i] <= 107) {
              attr = (attr & FOREGROUND_MASK) | BACKGROUND_INTENSITY;
              if ((v[i] - 100) & 1)
                attr |= BACKGROUND_RED;
              if ((v[i] - 100) & 2)
                attr |= BACKGROUND_GREEN;
              if ((v[i] - 100) & 4)
                attr |= BACKGROUND_BLUE;
            }
            //else if (v[i] == 49)
            //attr = (~attr & FOREGROUND_MASK);
            else if (v[i] == 100)
              attr = attr_old;
          }
          SetConsoleTextAttribute(handle, attr);
          break;
        case 'K':
          GetConsoleScreenBufferInfo(handle, &csbi);
          coord = csbi.dwCursorPosition;
          switch (v[0]) {
            default:
              case 0:
              csize = csbi.dwSize.X - coord.X;
              break;
            case 1:
              csize = coord.X;
              coord.X = 0;
              break;
            case 2:
              csize = csbi.dwSize.X;
              coord.X = 0;
              break;
          }
          FillConsoleOutputCharacter(handle, ' ', csize, coord, &written);
          FillConsoleOutputAttribute(handle, csbi.wAttributes, csize, coord, &written);
          SetConsoleCursorPosition(handle, csbi.dwCursorPosition);
          break;
        case 'J':
          GetConsoleScreenBufferInfo(handle, &csbi);
          w = csbi.dwSize.X;
          h = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
          coord = csbi.dwCursorPosition;
          switch (v[0]) {
            default:
            case 0:
              csize = w * (h - coord.Y) - coord.X;
              coord.X = 0;
              break;
            case 1:
              csize = w * coord.Y + coord.X;
              coord.X = 0;
              coord.Y = csbi.srWindow.Top;
              break;
            case 2:
              csize = w * (h + 1);
              coord.X = 0;
              coord.Y = csbi.srWindow.Top;
              break;
          }
          FillConsoleOutputCharacter(handle, ' ', csize, coord, &written);
          FillConsoleOutputAttribute(handle, csbi.wAttributes, csize, coord, &written);
          SetConsoleCursorPosition(handle, csbi.dwCursorPosition);
          break;
        case 'H':
          GetConsoleScreenBufferInfo(handle, &csbi);
          coord = csbi.dwCursorPosition;
          if (v[0] != -1) {
            if (v[1] != -1) {
              coord.Y = csbi.srWindow.Top + v[0] - 1;
              coord.X = v[1] - 1;
            } else
              coord.X = v[0] - 1;
          } else {
            coord.X = 0;
            coord.Y = csbi.srWindow.Top;
          }
          if (coord.X < csbi.srWindow.Left)
            coord.X = csbi.srWindow.Left;
          else if (coord.X > csbi.srWindow.Right)
            coord.X = csbi.srWindow.Right;
          if (coord.Y < csbi.srWindow.Top)
            coord.Y = csbi.srWindow.Top;
          else if (coord.Y > csbi.srWindow.Bottom)
            coord.Y = csbi.srWindow.Bottom;
          SetConsoleCursorPosition(handle, coord);
          break;
        default:
          break;
      }
    } else {
      WriteConsoleW(handle, ptr, 1, &written, NULL);
      ptr++;
    }
  }
  return ptr - buf;
}
#endif

static void
printstr_ansi(mrb_state *mrb, mrb_value obj)
{
  if (mrb_string_p(obj)) {
#ifdef _WIN32
    if (isatty(fileno(stdout))) {
      int mlen       = RSTRING_LEN(obj);
      char* utf8     = RSTRING_PTR(obj);
      int wlen       = MultiByteToWideChar(CP_UTF8, 0, utf8, mlen, NULL, 0);
      wchar_t* utf16 = mrb_malloc(mrb, (wlen+1) * sizeof(wchar_t));
      if (utf16 == NULL) return;
      if (MultiByteToWideChar(CP_UTF8, 0, utf8, mlen, utf16, wlen) > 0) {
        utf16[wlen] = 0;
        _fwrite_w32(utf16);
      }
      mrb_free(mrb, utf16);
    } else
#endif
      fwrite(RSTRING_PTR(obj), RSTRING_LEN(obj), 1, stdout);
  }
}

mrb_value
mrb_printstr_ansi(mrb_state *mrb, mrb_value self)
{
  mrb_value argv;

  mrb_get_args(mrb, "o", &argv);
  printstr_ansi(mrb, argv);

  return argv;
}

void
mrb_mruby_ansi_colors_gem_init(mrb_state* mrb)
{
  struct RClass *krn;
  krn = mrb->kernel_module;

  mrb_define_method(mrb, krn, "__printstr__", mrb_printstr_ansi, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, krn, "__printansistr__", mrb_printstr_ansi, MRB_ARGS_REQ(1));
}

void
mrb_mruby_ansi_colors_gem_final(mrb_state* mrb)
{
}
