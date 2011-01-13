#!/usr/bin/env lua
-- ctcp.lua - ctcp functions file for minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

function ctcp.action(n, chan, act)
    act = act:gsub("%%", "%%%%")
    sendRaw(n, "PRIVMSG " .. chan .. " :\001ACTION " .. act .. "\001")
    log("Sent ctcp.action " .. act .. " to " .. bot.nets[n].name .. "/" .. chan, u, "info")
end
function ctcp.version(n, arg)
    arg = arg:match("^(%S+)")
    sendRaw(n, "PRIVMSG " .. arg .. " :\001VERSION\001")
    log("Sent CTCP VERSION request to " .. arg .. " on " .. bot.nets[n].name, u, "info")
end

function ctcp.read(n, l)
    local origin = l:match("^:(%S+)")
    if l:match("\001%s*VERSION") then
        if l:match("\001VERSION%s*%\001") then
            log("Received CTCP VERSION request from " .. origin .. " on " .. bot.nets[n].name, "trivial")
            sendRaw(n, "PRIVMSG " .. origin .. " :\001VERSION Minnet:" .. version .. ":using Sockets, irc.lua and black magic\001")
        else
            local reply = l:match("VERSION%s*(.-)%\001")
            log("Received CTCP VERSION reply from " .. origin .. " on " .. bot.nets[n].name, "debug")
            send(n, vchan, "VERSION reply from " .. origin .. ": " .. reply)
        end
    elseif l:match("\001%s*SOURCE%\001") then
        log("Received CTCP SOURCE request from " .. origin .. " on " .. bot.nets[n].name, "info")
        sendRaw(n, "PRIVMSG " .. origin .. " :\001SOURCE git://github.com/staeld/minnet/::\001")
    elseif l:match("\001%s*TIME%s*%\001") then
        log("Received CTCP TIME request from " .. origin .. " on " .. bot.nets[n].name, "info")
        sendRaw(n, "PRIVMSG " .. origin .. " :\001TIME :" .. os.date("%F %T %Z") .. "\001")
    else
        log("Received unsupported CTCP notice from " .. origin .. " on " .. bot.nets[n].name .. ", ignoring..", "trivial")
    end
end

