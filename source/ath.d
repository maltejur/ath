/*
  This file is part of ath (ansi to html), ported from aha

  Copyright (C) 2022      Malte Jürgens <maltejur@dismail.de>
  Copyright (C) 2012-2021 Alexander Matthes (Ziz) , ziz_at_mailbox.org

  ath is free software: you can redistribute it and/or modify it under the
  terms of the GNU Lesser General Public License as published by the Free
  Software Foundation, either version 3 of the License, or (at your option) any
  later version.

  ath is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
  PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License along
  with ath. If not, see <https://www.gnu.org/licenses/>. 
*/

module ath;

import std.format : format;
import std.stdio : File, stdout, stderr, writef, writefln;
import std.process : Pipe, pipe;
import std.array : join;
import std.ascii : newline;
import std.algorithm : max, min;
import std.algorithm.mutation : swap;
import core.stdc.stdio : fgetc, EOF, FILE;

class AthException : Exception
{
  this(
    string msg,
    string file = __FILE__,
    size_t line = __LINE__,
    Throwable nextInChain = null
  ) pure nothrow @nogc @safe
  {
    super(msg, file, line, nextInChain);
  }
}

struct AthOptions
{
  bool noBuffer = false;
  bool dark = false;
  bool document = false;
  bool noPre = false;
}

const string[] palleteDark = [
  "dimgray", "red", "lime", "yellow", "#3333FF", "fuchsia", "aqua", "white",
  "black", "white"
];
const string[] palleteLight = [
  "dimgray", "red", "green", "olive", "blue", "purple", "teal", "gray", "white",
  "black"
];

enum ColorMode
{
  MODE_3BIT,
  MODE_8BIT,
  MODE_24BIT
}

private struct State
{
  int fc;
  int bc;
  bool bold;
  bool faint;
  bool italic;
  bool underline;
  bool blink;
  bool crossedout;
  bool inverted;
  bool hidden;
  bool overlined;
  ColorMode fc_colormode;
  ColorMode bc_colormode;
  bool fc_highlighted;
  bool bc_highlighted;
}

private struct Cell
{
  char value;
  State state;
  bool empty = true;

  this(char value, State state)
  {
    this.value = value;
    this.state = state;
    this.empty = false;
  }
}

private const State defaultState = {
  fc: -1,
  bc: -1,
  bold: false,
  faint: false,
  italic: false,
  underline: false,
  blink: false,
  crossedout: false,
  inverted: false,
  hidden: false,
  overlined: false,
  fc_colormode: ColorMode.MODE_3BIT,
  bc_colormode: ColorMode.MODE_3BIT,
  fc_highlighted: false,
  bc_highlighted: false
};

private int getNextChar(FILE* fp)
{

  int c;
  if ((c = fgetc(fp)) != EOF)
  {
    // stderr.write(cast(char)(c));
    return c;
  }

  throw new AthException("Unexpected EOF");
}

private string make_rgb(int color_id)
{
  if (color_id < 16 || color_id > 255)
    return "#000000";
  if (color_id >= 232)
  {
    int index = color_id - 232;
    int grey = index * 256 / 24;
    return format("#%02x%02x%02x", grey, grey, grey);
  }

  int index_R = (color_id - 16) / 36;
  int rgb_R;
  if (index_R > 0)
    rgb_R = 55 + index_R * 40;
  else
    rgb_R = 0;

  int index_G = ((color_id - 16) % 36) / 6;
  int rgb_G;
  if (index_G > 0)
    rgb_G = 55 + index_G * 40;
  else
    rgb_G = 0;

  int index_B = ((color_id - 16) % 6);
  int rgb_B;
  if (index_B > 0)
    rgb_B = 55 + index_B * 40;
  else
    rgb_B = 0;

  return format("#%02x%02x%02x", rgb_R, rgb_G, rgb_B);
}

private void swapColors(State* state)
{
  state.inverted = !state.inverted;

  if (state.bc_colormode == ColorMode.MODE_3BIT && state.bc == -1)
    state.bc = -2;
  if (state.fc_colormode == ColorMode.MODE_3BIT && state.fc == -1)
    state.fc = -2;

  swap(state.fc, state.bc);
  swap(state.fc_colormode, state.bc_colormode);
  swap(state.fc_highlighted, state.bc_highlighted);
}

void ansi_to_html(File input, File output, AthOptions options = AthOptions())
{
  Cell[][] buf;
  int c;
  int line = 0;
  int saved_line = 0;
  int col = 0;
  int saved_col = 0;
  State state = defaultState;
  State oldState = defaultState;

  void ensureBuffer()
  {
    buf.length = max(buf.length, line + 1);
    buf[line].length = max(buf[line].length, col + 1);
  }

  string escapeHtml(char c)
  {
    string s = [c];

    if (s == "&")
      s = "&amp;";
    if (s == "<")
      s = "&lt;";
    if (s == ">")
      s = "&gt;";
    if (s == "\"")
      s = "&quot;";

    return s;
  }

  void write(char c)
  {
    if (options.noBuffer)
      output.write(escapeHtml(c));
    else
    {
      ensureBuffer();
      buf[line][col] = Cell(c, state);
    }
  }

  void handleNewState(State oldState, State newState)
  {
    //Checking the differences
    if (newState != oldState)
    {

      // If old state was different than the default one, close the current <span>
      if (oldState != defaultState)
        output.write("</span>");

      // Open new <span> if current state differs from the default one
      if (newState != defaultState)
      {
        output.write("<span style=\"");

        if (newState.bold)
          output.write("font-weight:bold;");
        else if (newState.faint)
          output.write("font-weight:lighter;");

        if (newState.italic)
          output.write("font-style:italic;");

        if (newState.underline || newState.blink || newState.crossedout || newState.overlined)
        {
          output.write("text-decoration:");

          if (newState.underline)
            output.write(" underline");
          if (newState.blink)
            output.write(" blink");
          if (newState.crossedout)
            output.write(" line-through");
          if (newState.overlined)
            output.write(" overline");

          output.write(";");
        }

        if (newState.hidden)
          output.write("opacity:0;");

        if (newState.fc_highlighted || newState.bc_highlighted)
          output.write("filter: contrast(70%) brightness(190%);");

        const string default_fc_color = options.dark ? "lightgray" : "black";
        string fc_color = default_fc_color;
        final switch (newState.fc_colormode)
        {
        case ColorMode.MODE_3BIT:
          if (newState.fc >= 0 && newState.fc <= 9)
            fc_color = options.dark ? palleteDark[newState.fc] : palleteLight[newState.fc];
          break;

        case ColorMode.MODE_8BIT:
          if (newState.fc >= 0 && newState.fc <= 7)
            fc_color = options.dark ? palleteDark[newState.fc] : palleteLight[newState.fc];
          else
            fc_color = make_rgb(newState.fc);
          break;

        case ColorMode.MODE_24BIT:
          fc_color = format("#%06x", newState.fc);
          break;
        }

        const string default_bc_color = options.dark ? "black" : "lightgray";
        string bc_color = default_bc_color;
        final switch (newState.bc_colormode)
        {
        case ColorMode.MODE_3BIT:
          if (newState.bc >= 0 && newState.bc <= 9)
            bc_color = options.dark ? palleteDark[newState.bc] : palleteLight[newState.bc];
          break;

        case ColorMode.MODE_8BIT:
          if (newState.bc >= 0 && newState.bc <= 7)
            bc_color = options.dark ? palleteDark[newState.bc] : palleteLight[newState.bc];
          else
            bc_color = make_rgb(newState.bc);
          break;

        case ColorMode.MODE_24BIT:
          bc_color = format("#%06x", newState.bc);
          break;
        }

        if (newState.inverted)
          swap(fc_color, bc_color);

        if (fc_color != default_fc_color)
          output.write(format("color:%s;", fc_color));
        if (bc_color != default_bc_color)
          output.write(format("background-color:%s;", bc_color));

        output.write("\">");
      }
    }
  }

  /// Make sure new state is still picked up when jumping to new cursor position
  void saveStateEmpty()
  {
    ensureBuffer(); // buf[line] is accessed, gotta make sure it exists
    if (col + 1 >= buf[line].length || buf[line][col + 1].empty)
    {
      col += 1;
      ensureBuffer();
      buf[line][col] = Cell(' ', state);
      col -= 1;
    }
  }

  void newline()
  {
    if (options.noBuffer)
      output.write("\n");
    else
      saveStateEmpty();
    line += 1;
    col = 0;
  }

  void carriageReturn()
  {
    if (options.noBuffer)
      return;
    saveStateEmpty();
    col = 0;
  }

  void moveCursor(int deltaX, int deltaY)
  {
    if (options.noBuffer)
      return;

    saveStateEmpty();

    // Ensure bounds
    line = max(line + deltaY, 0);
    col = max(col + deltaX, 0);
  }

  FILE* fp = input.getFP();

  if (options.document)
  {
    output.writeln("<!DOCTYPE html>
<head>
  <meta charset=\"UTF-8\">
  <meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>ath</title>");
    if (options.dark)
      output.writeln("<style>body{background-color:black;color:lightgray;}</style>");
    output.writeln("</head>
<body>
<pre>");
  }
  else if (!options.noPre)
  {
    if (options.dark)
      output.write("<pre style=\"background-color:black;color:lightgray;\">");
    else
      output.write("<pre>");
  }

  while ((c = fgetc(fp)) != EOF)
  {
    // ESC
    if (c == '\033')
    {
      // Searching the end (a letter) and safe the insert:
      c = getNextChar(fp);
      if (c == '[') // CSI code, see https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
      {
        int[] elems;
        int elem = 0;
        int value = 0;

        while (true)
        {
          c = getNextChar(fp);

          if (((c >= 'A') && (c <= 'Z')) || ((c >= 'a') && (c <= 'z')))
          {
            elems ~= value;
            break;
          }

          if (c == ';' || c == ':' || c == 0)
          {
            elems ~= value;
            value = 0;
            continue;
          }

          value = (value * 10) + (c - '0');
        }

        switch (c)
        {
        case 'A': // Cursor Up
          int deltaY = elems[0] == 0 ? -1 : -elems[0];
          moveCursor(0, deltaY);
          break;

        case 'B': // Cursor Down
          int deltaY = elems[0] == 0 ? 1 : elems[0];
          moveCursor(0, deltaY);
          break;

        case 'C': // Cursor Forward
          int deltaX = elems[0] == 0 ? 1 : elems[0];
          moveCursor(deltaX, 0);
          break;

        case 'D': // Cursor Back
          int deltaX = elems[0] == 0 ? -1 : -elems[0];
          moveCursor(deltaX, 0);
          break;

        case 'E': // Cursor Next Line
          carriageReturn();
          int deltaY = elems[0] == 0 ? 1 : elems[0];
          moveCursor(0, deltaY);
          break;

        case 'F': // Cursor Previous Line
          carriageReturn();
          int deltaY = elems[0] == 0 ? -1 : -elems[0];
          moveCursor(0, deltaY);
          break;

        case 'G': // Cursor Horizontal Absolute
          int newCol = elems[0] == 0 ? 1 : elems[0];
          moveCursor(newCol - 1 - col, 0);
          break;

        case 'H': // Cursor Position
        case 'f': // Horizontal Vertical Position
          int newLine = elems[0] == 0 ? 1 : elems[0];
          int newCol = (elems.length == 1 || elems[1] == 0) ? 1 : elems[1];
          moveCursor(newCol - 1 - col, newLine - 1 - line);
          break;

        case 'J': // Erase in Display
          switch (elems[0])
          {
          case 0: // Clear from cursor to end of screen
            buf.length = line + 1;
            for (int i = col; i < buf[line].length; i += 1)
              buf[line][col].empty = true;
            break;

          case 1: // Clear from cursor to beginning of the screen
            ulong height = buf.length;
            Cell[][] tmp = buf[line .. buf.length];
            buf.length = 0;
            buf.length = height;
            buf[line .. buf.length] = tmp;
            for (int i = col; i >= 0; i -= 1)
              buf[line][col].empty = true;
            break;

          case 2:
          case 3:
            buf.length = 0;
            buf.length = line + 1;
            break;

          default:
            break;
          }
          break;

        case 'K': // Erase in Line
          switch (elems[0])
          {

          case 0: // Clear from cursor to the end of the line
            for (int i = col; i < buf[line].length; i += 1)
              buf[line][col].empty = true;
            break;

          case 1: // Clear from cursor to beginning of the line
            for (int i = col; i >= 0; i -= 1)
              buf[line][col].empty = true;
            break;

          case 2:
            for (int i = 0; i < buf[line].length; i += 1)
              buf[line][col].empty = true;
            break;

          default:
            break;
          }
          break;

        case 'm':
          while (elem < elems.length)
          {
            switch (elems[elem])
            {
            case 0: // 0 - Reset all
              state = defaultState;
              break;

            case 1: // 1 - Enable Bold
              state.bold = true;
              break;

            case 2: // 2 - Enable Faint
              state.faint = true;
              break;

            case 3: // 3 - Enable Italic
              state.italic = true;
              break;

            case 4: // 4 - Enable underline
              state.underline = true;
              break;

            case 5: // 5 - Slow Blink
              state.blink = true;
              break;

            case 7: // 7 - Inverse video
              state.inverted = true;
              break;

            case 8: // 8 - Conceal or hide 
              state.hidden = true;
              break;

            case 9: // 9 - Enable hide
              state.crossedout = true;
              break;

            case 21: // 21 - Reset bold
            case 22: // 22 - Not bold, not "high intensity" color
              state.bold = false;
              state.faint = false;
              break;

            case 23: // 23 - Reset italic
              state.italic = false;
              break;

            case 24: // 23 - Reset underline
              state.underline = false;
              break;

            case 25: // 25 - Reset blink
              state.blink = false;
              break;

            case 27: // 27 - Reset Inverted
              state.inverted = false;
              break;

            case 28: // 28 - Reveal
              state.hidden = false;
              break;

            case 29: // 29 - Reset crossed-out
              state.crossedout = false;
              break;

            case 30:
            case 31:
            case 32:
            case 33:
            case 34:
            case 35:
            case 36:
            case 37: // 30-37 - Set foreground color (3 bit)
              state.fc_colormode = ColorMode.MODE_3BIT;
              state.fc = elems[elem] - 30;
              break;

            case 38:
              if (elems[elem + 1] == 5) // 38 - Set foreground color (8 bit)
              {
                state.fc_colormode = ColorMode.MODE_8BIT;
                if (elems[elem + 2] >= 8 && elems[elem + 2] <= 15)
                {
                  state.fc = elems[elem + 2] - 8;
                  state.fc_highlighted = true;
                }
                else
                {
                  state.fc = elems[elem + 2];
                  state.fc_highlighted = false;
                }
                elem += 2;
              }
              else if (elems[elem + 1] == 2) // 38 - Set foreground color (24 bit)
              {
                int r = elems[elem + 2];
                int g = elems[elem + 3];
                int b = elems[elem + 4];

                state.fc_colormode = ColorMode.MODE_24BIT;
                state.fc =
                  (r & 255) * 65_536 +
                  (g & 255) * 256 +
                  (b & 255);
                state.fc_highlighted = false;

                elem += 4;
              }
              break;

            case 39: // 39 - Default foreground color
              state.fc_colormode = ColorMode.MODE_3BIT;
              state.fc = -1;
              state.fc_highlighted = false;
              break;

            case 40:
            case 41:
            case 42:
            case 43:
            case 44:
            case 45:
            case 46:
            case 47: // 40-47 - Set background color (3 bit)
              state.bc_colormode = ColorMode.MODE_3BIT;
              state.bc = elems[elem] - 40;
              break;

            case 48:
              if (elems[elem + 1] == 5) // 48 - Set background color (8 bit)
              {
                state.bc_colormode = ColorMode.MODE_8BIT;
                if (elems[elem + 2] >= 8 && elems[elem + 2] <= 15)
                {
                  state.bc = elems[elem + 2] - 8;
                  state.bc_highlighted = true;
                }
                else
                {
                  state.bc = elems[elem + 2];
                  state.bc_highlighted = false;
                }
                elem += 2;
              }
              else if (elems[elem + 1] == 2) // 48 - Set background color (24 bit)
              {
                int r = elems[elem + 2];
                int g = elems[elem + 3];
                int b = elems[elem + 4];

                state.bc_colormode = ColorMode.MODE_24BIT;
                state.bc =
                  (r & 255) * 65_536 +
                  (g & 255) * 256 +
                  (b & 255);
                state.bc_highlighted = false;

                elem += 4;
              }
              break;

            case 49: // 49 - Default background color
              state.bc_colormode = ColorMode.MODE_3BIT;
              state.bc = -1;
              state.bc_highlighted = false;
              break;

            case 53: // 53 - Overlined
              state.overlined = true;
              break;

            case 55: // 55 - Not overlined
              state.overlined = false;
              break;

            default:
              break;
            }
            elem += 1;
          }
          break;

        case 's':
          saved_line = line;
          saved_col = col;
          break;

        case 'u':
          line = saved_line;
          col = saved_col;
          buf.length = max(buf.length, line + 1);
          break;

        default:
          break;
        }

        if (options.noBuffer)
          handleNewState(oldState, state);
      }
    }
    else if (c == '\n')
      newline();
    else if (c == '\r')
      carriageReturn();
    else
    {
      write(cast(char)(c));
      col += 1;
    }

    oldState = state;
  }

  if (!options.noBuffer)
    foreach (size_t i, Cell[] lineContent; buf)
    {
      foreach (size_t y, Cell cell; lineContent)
        if (!cell.empty)
        {
          handleNewState(oldState, cell.state);
          output.write(escapeHtml(cell.value));
          oldState = cell.state;
        }
        else
        {
          handleNewState(oldState, oldState);
          output.write(" ");
        }
      if (i + 1 != buf.length)
      {
        handleNewState(state, defaultState);
        output.write("\n");
      }
    }

  handleNewState(state, defaultState);

  if (options.document)
    output.write("</pre>
</body>
</html>");
  else if (!options.noPre)
    output.write("</pre>");

  output.close();
}

File ansi_to_html(File input, AthOptions options = AthOptions())
{
  Pipe output = pipe();
  ansi_to_html(input, output.writeEnd, options);
  return output.readEnd;
}

string ansi_to_html(string ansi, AthOptions options = AthOptions())
{
  Pipe input = pipe();
  input.writeEnd.write(ansi);
  input.writeEnd.close();
  File result = ansi_to_html(input.readEnd, options);
  return cast(string)(result.byLine.join(newline));
}
