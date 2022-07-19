# ath - ansi to html

ath is both a command line tool and a D library for converting text containing
ANSI escape sequences into HTML.

![](https://i.imgur.com/eRbWK7k.png)

## Features

- 3-bit, 8-bit and 24-bit color support
- Basic SGR sequences (bold, italic, underline, blink, crossedout, invert, hide,
  faint, overlined)
- Cursor control sequences (if buffer is enabled)

#### Not (yet) implemented:

- Obscure SGR sequences not listed above (most notably invert and hide)
- OSC sequences
- Some C0 control codes (like tab or backspace)

## Command Line Tool

### Installation

To install the command line tool, make sure you have
[ldc2](https://github.com/ldc-developers/ldc#installation) and dub installed.
Then, just run:

```bash
make

sudo make install
```

### Usage

The command line tool reads the input stream and converts the containing ANSI
into HTML. You can view `ath --help` for optional arguments and example
commands.

## Library

You can view the documentation of the library at
https://ath.dpldocs.info/ath.html.

## Credits

Thanks a lot to [theZiz](https://github.com/theZiz) for his great tool
[aha](https://github.com/theZiz/aha). I basically ported his code to D and
improved on it. I would have just contributed upstream, but I needed a D library
and thus it wasn't possible for me (with my technical knowledge) to just use
aha.
