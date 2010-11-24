#!/usr/bin/env lua
-- Hooks file for minnet
-- Hooks are registered for each network ([i])
c.net[i]:hook("OnChat", "wit", function(u, chan, m)
    msg = false
    local n = i
    if ( chan == c.net[n].nick ) then msg = true; chan = u.nick end
    if ( msg == true ) or string.match(m, bot.cmdstring) then wit(n, u, chan, m) end
end)
c.net[i]:hook("OnRaw", "versionparse", function(l)
    local n = i
    if string.match(l, "\001VERSION%s.*") then
        local reply = string.match(l, "VERSION%s?(.*)%\001$")
        if not reply then reply = "no understandable VERSION reply" end
        c.net[n]:sendChat(vchan, reply)
    end
end)

