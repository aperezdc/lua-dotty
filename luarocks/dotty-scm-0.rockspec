package = "dotty"
version = "scm-0"
source = {
   url = "git://github.com/aperezdc/lua-dotty"
}
description = {
   maintainer = "Adrián Pérez de Castro <aperez@igalia.com>",
   summary = "Idiomatic wrapper for terminal handling",
   homepage = "https://github.com/aperezdc/lua-dotty",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1",
   "luaposix >= 33",
   "bit32",
}
build = {
   type = "builtin",
   modules = {
      ["dotty.ttyctl"]     = "dotty/ttyctl.lua",
      ["dotty.descape"]    = "dotty/descape.lua",
      ["dotty.unidecode"]  = "dotty/unidecode.lua",
      ["dotty.asciicodes"] = "dotty/asciicodes.lua",
   }
}
