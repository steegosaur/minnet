#!/usr/bin/env lua
-- dryrun.lua - dummy stats for dry-running minnet.lua

u = {
    nick = "Lakorv",
    username = "Staeld",
    host = "purewhite.id.au"
}

c.net = {
    { sendChat = function(self, u, m) print(m) end }
}
n = 1 -- For when you forget using 1 instead of n.
