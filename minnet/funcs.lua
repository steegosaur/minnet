#!/usr/bin/env lua
-- funcs.lua - functions file for minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet. 
-- Minnet is released under the GPLv3 - see ../COPYING 

function log(m, u, l) -- Log function, takes message, user table and loglevel
    if not m then
        err("No error message provided in call to log()")
    end
    if not l then       -- Because I'm too lazy to switch l and u in all calls
        if ( type(u) == "string" ) then
            l, u = u, nil
        end
    end
    if not l then
        err("No info level defined for parent function; FIXME")
    elseif ( levels[l] > verbosity ) then -- Lower value == higher prio
        return nil      -- We don't want this level; shut up
    end
    local mask
    if u then
        mask = u.nick .. "!" .. u.username .. "@" .. u.host .. ": "
    else
        mask = ""
    end
    l = l:upper() .. " "
    print(os.date("%F/%T : ") .. l .. mask .. m)
end
function err(m, file)
    if file then file = " " .. file else file = "" end
    log(m .. file, "error")
    --os.exit(1)
    error(m)
end

function send(n, chan, str)
    -- Wrapper func: should be changed according to irc framework used
    -- Allows for more dynamic rewriting of the well-used message sending.
    if ( type(chan) == "table" ) then
        if chan.nick then chan = chan.nick end
    end
    c.net[n]:sendChat(chan, str)
end
function sendRaw(n, str)
    -- Wrapper function for passing a rawquote to the server
    -- str must be preformatted; no assumptions about content are made
    c.net[n]:send(str)
end

function otkgen(n)
    otk[n] = tostring(math.random(100000000, 99999999999999))
end
function passgen(p)
    if ( not p ) or ( p == "" ) then return nil end
    local h = crypto.evp.digest("sha1", p)
    return h
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
    log("Added " .. c .. " to joined channel list on " .. bot.nets[n].name,
        "info")
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
        log("Removing channel " .. c .. " from joined channel list on " .. bot.nets[n].name,
            "info")
        table.remove(bot.nets[n].joined, num)
        return true
    else
        return false
    end
end

function wit(n, u, chan, m) -- Main hook function for reacting to commands
    local nickmatch = "^" .. c.net[n].nick .. "%s-[,:;%-$]+%s+"
    if m:match(nickmatch) then
        m = m:gsub(nickmatch, "")
    end
    if ( m == "" ) or m:match("^%s+") or m:match("%\001") then return nil end
    m = m:gsub("%s+$", "")
    cmdFound = false
    for i = 1, #bot.cmds do
        if m:lower():match("^" .. bot.cmds[i].name:lower() .. "$") or m:lower():match("^" .. bot.cmds[i].name:lower() .. "%W+") then
            log("Received command " .. m .. " on " .. bot.nets[n].name .. "/" .. chan, u, "debug")
            if bot.cmds[i].rep      then send(n, chan, bot.cmds[i].rep) end
            if bot.cmds[i].action   then bot.cmds[i].action(n, u, chan, m) end
            cmdFound = true
            break
        end
    end
    if ( cmdFound == false ) then
        log("Could not understand command: " .. m, u, "debug")
        send(n, chan, "Excuse me?")
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
        if ( days ~= "" ) or ( hours ~= "" ) then
            pre = " and "
        else
            pre = ""
        end
        mins = pre .. time.min .. " minute" .. ending.minute
    else
        mins = ""
    end
    return days, hours, mins
end

-- Create msg.help() function; read name, version and append to --help message
name = ""
io.input(arg[0])
local matchstring = "^%-%-%s-(" .. arg[0]:match("%p*(%S+)") .. ".*)$"
while not name:match(matchstring) or not io.read() do
    name = io.read()
end
io.close()
name = name:gsub("^%W*", "")
version = name:match("^%S+%s+(%d%.%d%.%d%.?%d?)")
msg.help = function()
    print(name)
    print("Usage: " .. arg[0] .. " [--help|--dry|--run]")
    os.exit()
end
-- EOF
