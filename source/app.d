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

import std.stdio : stdin, stdout;
import std.algorithm : canFind;
import std.string : strip;
import ath;

const string ver = strip(import("version"));

void main(string[] argv)
{
  if (argv.canFind("--help"))
    return showHelp();
  if (argv.canFind("--version"))
    return showVersion();
  if (argv.canFind("--license"))
    return showLicense();
  ansi_to_html(stdin, stdout, AthOptions(
      argv.canFind("--no-buffer"),
      argv.canFind("--dark"),
      argv.canFind("--document"),
      argv.canFind("--no-pre")));
}

void showHelp()
{
  stdout.writefln("\033[1m\033[37math (ansi to html) cli\033[0m %s
Copyright (C) 2022      Malte Jürgens <maltejur@dismail.de>
Copyright (C) 2012-2021 Alexander Matthes (Ziz) , ziz_at_mailbox.org

Reads the input stream and converts the containing ANSI into HTML.

\033[4mOptions\033[0m:
  --no-buffer   By default ath keeps the input stream in a buffer,
                allowing for cursor sequences to be used. Use this 
                option to disable that behaviour and directly pass 
                the input stream through. May improve performance 
                and memory consumption.
  --dark        Use a dark color scheme.
  --document    Generate a whole HTML document instead of just
                the <pre>...</pre> tag.
  --no-pre      Also leave out the <pre> tags.
  --help        Display the current page
  --version     Display the installed version of the ath cli
  --license     Display the GNU LGPL-3.0 license
	
\033[4mExamples\033[0m:
  Turn this help page into a HTMl file
    $ ath --help | ath --document --dark >/tmp/ath-help.html

  View your PCs stats in a web browser
    $ neofetch | ath --document >/tmp/neofetch.html && open /tmp/neofetch.html

  RGB fortune from Tux
    $ fortune | cowsay -f tux | lolcat -f | ath --document --dark >/tmp/fortune.html

This program is subject to the LGPL version 3.0 or later. It comes 
with  ABSOLUTELY NO WARRANTY. This is free software, and you are 
welcome to redistribute it under certain conditions. See 
`ath --license` for a copy of the LGPL-3.0.

\033[25C\033[30m\033[40m  \033[31m\033[41m  \033[32m\033[42m  \033[33m\033[43m  "
      ~ "\033[34m\033[44m  \033[35m\033[45m  \033[36m\033[46m  \033[37m\033[47m  \033[m
\033[25C\033[38;5;8m\033[48;5;8m  \033[38;5;9m\033[48;5;9m  \033[38;5;10m\033[48;5;10m  "
      ~ "\033[38;5;11m\033[48;5;11m  \033[38;5;12m\033[48;5;12m  \033[38;5;13m\033[48;5;13m  "
      ~ "\033[38;5;14m\033[48;5;14m  \033[38;5;15m\033[48;5;15m  \033[m", ver);
}

void showVersion()
{
  stdout.writeln(ver);
}

void showLicense()
{
  stdout.write(import("LICENSE"));
}
