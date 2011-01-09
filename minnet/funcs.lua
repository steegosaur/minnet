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
function otkgen(n)
    --[[
    local seed = tostring(math.random())
    seed = seed:match("%.(%d+)")
    seed = tonumber(seed)
    math.randomseed(seed) --]]
    otk[n] = tostring(math.random())
    otk[n] = otk[n]:match("%.(%d+)")
end
function getarg(m) -- Gets everything after *first* word
    local arg = m:match("^%S+%s+(%S+.*)")
    return arg
end

function check_joined(n, c) -- Returns true if c is in n's joined list
    local found
    for i = 1, #bot.nets[n].joined do
        if ( bot.nets[n].joined[i] == c ) then
            found = true
            break
        end
    end
    if found then
        return true
    else
        return false
    end
end
function channel_add(n, c)
    table.insert(bot.nets[n].joined, c)
    log("Added " .. c .. " to joined channel list on " .. bot.nets[n].name)
end
function channel_remove(n, c)
    local num, found
    for i = 1, #bot.nets[n].joined do
        if ( bot.nets[n].joined[i] == c ) then
            found = true
            num = i
            break
        end
    end
    if found then
        log("Removing channel " .. c .. " from joined channel list on " .. bot.nets[n].name)
        table.remove(bot.nets[n].joined, num)
        return true
    else
        return false
    end
end
function wit(n, u, chan, m) -- Main hook function for reacting to commands
    if m:match(bot.cmdstring) then
        m = m:gsub(bot.cmdstring, "")
    end
    if ( m == "" ) or m:match("^%s+") then return nil end
    cmdFound = false
    for i = 1, #bot.cmds do
        if m:lower():match("^" .. bot.cmds[i].name:lower() .. "%s-$") or m:lower():match("^" .. bot.cmds[i].name:lower() .. "%W+") then
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
function timecal(t)
    local time = os.date("*t", t)
    time.day, time.hour = time.day - 1, time.hour - 1
    local ending = { day = "", hour = "", minute = "" }
    if ( time.day   ~= 1 ) then ending.day      = "s" end
    if ( time.hour  ~= 1 ) then ending.hour     = "s" end
    if ( time.min   ~= 1 ) then ending.minute   = "s" end
    local days, hours, mins
    local pre = ""
    if ( time.day  > 0 ) then
        days = time.day .. " day" .. ending.day
    else
        days = ""
    end
    if ( time.hour > 0 ) then
        if ( days ~= "" ) and ( time.min > 0 ) then
            pre = ", "
        elseif ( days ~= "" ) and ( time.minute <= 0 ) then
            pre = " and "
        end
        hours = pre .. time.hour .. " hour" .. ending.hour
    else
        hours = ""
    end
    if ( time.min > 0 ) then
        if ( days ~= "" ) or ( hours ~= "" ) then pre = " and " else pre = "" end
        mins = pre .. time.min .. " minute" .. ending.minute
    else
        mins = ""
    end
    return days, hours, mins
end
function ctcp.action(n, chan, act)
    act = act:gsub("%%", "%%%%")
    c.net[n]:send("PRIVMSG " .. chan .. " :\001ACTION " .. act .. "\001")
    log("Sent ctcp.action " .. act .. " to " .. bot.nets[n].name .. "/" .. chan, u)
end
function ctcp.version(n, arg)
    arg = arg:match("^(%S+)")
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
local matchstring = "^%-%-%s-(" .. arg[0]:match("%p*(%S+)") .. ".*)$"
while not name:match(matchstring) or not io.read() do
    name = io.read()
end
io.close()
name = name:gsub("^%W*", "")
msg.help = function()
    print(name)
    print("Usage: " .. arg[0] .. " [--help|--dry|--run]")
    os.exit()
end
-- EOF
