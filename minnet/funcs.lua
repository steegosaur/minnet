#!/usr/bin/env lua
-- funcs.lua - functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet. 
-- Minnet is released under the GPLv3 - see ../COPYING 
function log(m, u)
    if not m then
        err("No error message provided in call to log()")
        return nil
    end
    local mask
    if u then
        mask = u.nick .. "!" .. u.username .. "@" .. u.host .. ": "
    else
        mask = ""
    end
    print(os.date("%F/%T : ") .. mask .. m)
end
function err(m, f)
    if f then f = " " .. f else f = "" end
    log("error: " .. m .. f)
    os.exit(1)
end
function getarg(m)
    local arg = m:match("^%S+%s+(%S+.*)")
    return arg
end
-- Deprecated, should be replaced by intricate and horrible privilege checking through sqlite3/udb
--[[
function isowner(n, u, chan)
    if not ( u.username == owner.uname1 ) or ( u.username == owner.uname2 ) and string.match(u.host, owner.host) then
        c.net[n]:sendChat(chan, msg.notowner)
        log("Unauthorised command received on " .. bot.nets[n].name .. "/" .. chan, u)
        return false
    else
        return true
    end
end
--]]
function wit(n, u, chan, m) -- Main hook function for reacting to commands
    if m:match(bot.cmdstring) then
        m = m:gsub(bot.cmdstring .. "%S-", "")
    end
    if ( m == "" ) or m:match("^%s+") then return nil end
    cmdFound = false
    for i = 1, #bot.cmds do
        if m:match("^" .. bot.cmds[i].name .. "%s-$") or m:match("^" .. bot.cmds[i].name .. "%s+") then
            log("Received command " .. m .. " on " .. bot.nets[n].name .. "/" .. chan, u)
            if bot.cmds[i].rep      then c.net[n]:sendChat(chan, bot.cmds[i].rep) end
            if bot.cmds[i].action   then bot.cmds[i].action(n, u, chan, m) end
            cmdFound = true
            break
        end
    end
    if ( cmdFound == false ) then
        c.net[n]:sendChat(chan, "Excuse me?")
    end
end
function ctcp.action(n, chan, act)
    act = string.gsub(act, "%%", "%%%%")
    c.net[n]:send("PRIVMSG " .. chan .. " :\001ACTION " .. act .. "\001")
    log("Sent ctcp.action " .. act .. " to " .. bot.nets[n].name .. "/" .. chan, u)
end
function ctcp.version(n, arg)
    arg = string.match(arg, "^(%S+)")
    c.net[n]:send("PRIVMSG " .. arg .. " :\001VERSION\001")
    log("Sent ctcp.version to " .. arg .. " on " .. bot.nets[n].name, u)
end
function passgen(p)
    if ( not p ) or ( p == "" ) then return nil end
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
