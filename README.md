# lua_menhir
lua_menhir provides a framework for converting [Menhir] grammars and [lrgrep]'s
`.mlyl` files to Lua. This is used to provide better Lua syntax errors for 
the [CC: Tweaked](https://github.com/cc-tweaked/CC-Tweaked) Minecraft mod.

This project is composed of several components:
 - `lrgrep/`: A copy of [lrgrep], modified to generate Lua code.
 - `parser/`: The Menhir grammar and parse errors file, largely copied from
   [illuaminate]. This also includes some debugging tools (`repl.ml`,
   `interpreter.ml`) for easier debugging of lrgrep rules.
 - `lua_menhir/`: This consumes our generated lrgrep file and Menhir parser, and
   stitches everything together into a single Lua file.
 - `lua/`: The generated parser, along with some tests and support code. This is
   a copy of what is shipped in CC: Tweaked.

This project is currently built for one purpose (better error messages in Lua)
and so is definitely not recommended for general-purpose use. It doesn't even
support semantic actions!

[menhir]: https://gallium.inria.fr/~fpottier/menhir/
[lrgrep]: https://github.com/let-def/lrgrep
[illuaminate]: https://github.com/Squiddev/illuaminate
