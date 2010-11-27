#!/usr/bin/env lua
-- funcs.lua - functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet. 
-- Minnet is released under the GPLv3 - see ../COPYING 
function log(m)
    if not t then t = "" end
    print(os.date("%F/%T: ") .. m)
end
function err(m, f)
    if f then f = " " .. f else f = "" end
    log("error: " .. m .. f)
    os.exit(1)
end
function getarg(m)
    local arg = string.match(m, "%s+(%S+.*)")
    return arg
end
function isowner(n, u, chan)
    if not ( u.username == owner.uname1 ) or ( u.username == owner.uname2 ) and string.match(u.host, owner.host) then
        c.net[n]:sendChat(chan, msg.notowner)
        log("Unauthorised command received from " .. u.nick .. "!" .. u.username .. "@" .. u.host .. " on " .. bot.nets[n].name .. "/" .. chan)
        return false
    else
        return true
    end
end
function wit(n, u, chan, m) -- Hook function for reacting to normal commands
    if string.match(m, bot.cmdstring) then
        m = string.gsub(m, bot.cmdstring, "")
    end
    if ( m == "" ) or string.match(m, "^%s+") then return nil end
    cmdFound = false
    for i = 1, #bot.cmds do
        if string.match(m, "^" .. bot.cmds[i].name) then
            log("Received command " .. m .. " from " .. u.nick .. "!" .. u.username .. "@" .. u.host .. " on " .. bot.nets[n].name .. "/" .. chan)
            if bot.cmds[i].rep      then c.net[n]:sendChat(chan, bot.cmds[i].rep) end
            if bot.cmds[i].action   then bot.cmds[i].action(n, u, chan, m) end
            cmdFound = true
        end
    end
    if ( cmdFound == false ) then
        c.net[n]:sendChat(chan, "Nevermore!")
    end
end
function ctcp.action(n, chan, act)
    c.net[n]:send("PRIVMSG " .. chan .. " :\001ACTION " .. act .. "\001")
    log("Sent ctcp.action " .. act .. " to " .. bot.nets[n].name .. "/" .. chan)
end
function ctcp.version(n, arg)
    arg = string.match(arg, "^(%S+)")
    c.net[n]:send("PRIVMSG " .. arg .. " :\001VERSION\001")
    log("Sent ctcp.version to " .. arg .. " on " .. bot.nets[n].name)
end
function passgen(p)
    local h = crypto.evp.digest("sha1", p)
    return h
end
-- Create msg.help() function
name = ""
io.input(arg[0])
while not string.match(name, "^%-%-%s-(minnet%.lua.*)$") or not io.read() do
    name = io.read()
end
name = string.gsub(name, "^%W*", "")
msg.help = function()
    print(name)
    print("Usage: " .. arg[0] .. " [--help|--run]")
    os.exit()
end
-- EOF
