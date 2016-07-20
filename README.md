lua-dotty
=========

[![Build Status](https://travis-ci.org/aperezdc/lua-dotty.svg?branch=master)](https://travis-ci.org/aperezdc/lua-dotty)
[![Coverage Status](https://coveralls.io/repos/github/aperezdc/lua-dotty/badge.svg?branch=master)](https://coveralls.io/github/aperezdc/lua-dotty?branch=master)

Usage
-----

```lua
local ttyctl = require "dotty.ttyctl"
print("Press any key to continue...")
ttyctl:with_cbreak(function () io.read(1) end)
```

### More Examples

* [examples/descape-delegate.lua](./examples/descape-delegate.lua): Shows how
  to use `dotty.ttycl`, `dotty.descape`, and `dotty.unidecode` to process
  UTF-8 input coming from a terminal which may contain terminal escape
  sequences.

For the `dotty.ttyctl` module:

* [examples/ttyctl-getch.lua](./examples/ttyctl-getch.lua): Implements a
  `getch()` function which waits for a single key press.


Installation
------------

[LuaRocks](https://luarocks.org) is recommended for installation.

The development version can be installed with:

```sh
luarocks install --server=https://luarocks.org/dev dotty
```


Resources
---------

* [ANSI escape code (Wikipedia)](https://en.wikipedia.org/wiki/ANSI_escape_code).
* [Extended CSI sequences](http://www.leonerd.org.uk/hacks/fixterms/).
* [vt100.net](http://www.vt100.net).
