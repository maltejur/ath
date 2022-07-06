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

The library exports a single function `ansi_to_html` with three overloads:

#### `string ansi_to_html(string ansi, AthOptions options)`

This is the simplest one. It takes a string as a input and returns a string as a
output.

#### `File ansi_to_html(File input, AthOptions options)`

This overload works with pipes in the form of `File`s. You pass it a `File` as
the input and it returns you a `File` as a output to read. This is especially
useful if you decide to disable the buffer (see explanation below).

#### `void ansi_to_html(File input, File output, AthOptions options)`

Pretty much the same as the previous overload, but this time you can pass the
output `File` directly instead of the function creating one for you.

### Optional Arguments

You can pass optional arguments in the form of the `AthOptions` struct. For
example:

```d
AthOptions options = { noPre: true };
writeln(ansi_to_html("abc\rxy", options)); // "xyc"
```

You have the following options available:

#### `bool noBuffer` (by default `false`)

By default ath keeps the input stream in a buffer, allowing for cursor sequences
to be used. Use this option to disable that behaviour and directly pass the
input stream through. May improve performance and memory consumption. Only
really makes sense if you use the piped version of the `ansi_to_html` function.

#### `bool dark` (by default `false`)

Use a dark color scheme.

#### `bool document` (by default `false`)

Generate a whole HTML document instead of just the `<pre>...</pre>` tag.

#### `bool noPre` (by default `false`)

Also leave out the `<pre>` tags.

## Credits

Thanks a lot to [theZiz](https://github.com/theZiz) for his great tool
[aha](https://github.com/theZiz/aha). I basically ported his code to D and
improved on it. I would have just contributed upstream, but I needed a D library
and thus it wasn't possible for me (with my technical knowledge) to just use
aha.
