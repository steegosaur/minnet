#!/usr/bin/env lua
-- funcs.lua - functions file for minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- {{{ Internal functionality
-- check_disabled(): Check if disabled in a channel
function check_disabled(chan, cmdfunc)
    if bot.disabled[chan] == true and cmdfunc ~= "enable" then
        return true
    else
        return false
    end
end

-- desat(): Strip colours from messages
function desat(m)
    if not m then return nil end
    m = tostring(m)
    m = m:gsub("^%W%d%d", "")
    return m
end

-- reload(): Reload one or more files while running
function reload(u, chan, file)
    if not file then
        return nil
    end
    if ( file == "functions" ) then file = "funcs"
    elseif ( file == "configuration" ) then file = "config"
    elseif ( file == "database" ) then file = "db"
    elseif ( file == "log" ) then file = "logging"
    end
    if ( file == "funcs" or file == "ctcp" or
      file == "db" or file == "hooks" or file == "config" or
      file == "cmdvocab" or file == "cmdarray" or
      file == "logging" or file == "hacks" ) then
        if assert(io.open("minnet/" .. file .. ".lua", "r")) then
            dofile("minnet/" .. file .. ".lua")
        else
            log("No such file: minnet/" .. file .. ".lua", u, "warn")
            send(chan, u.nick .. ": Sorry, but I couldn't find the file.")
            return nil
        end
        log("Reloaded " .. file .. ".lua", u, "info")
        send(chan, u.nick .. ": I reloaded " .. file .. ".lua.")
    elseif file == "commands" then
        local cmdfiles = { "cmdarray", "cmdvocab" }
        for _, file in ipairs(cmdfiles) do
            if assert(io.open("minnet/" .. file .. ".lua", "r")) then
                dofile("minnet/" .. file .. ".lua")
            else
                log("No such file: minnet/" .. file .. ".lua", u, "warn")
                send(chan, u.nick .. ": Sorry, but I couldn't find the file.")
                return nil
            end
        end
        log("Reloaded command files", u, "info")
        send(chan, u.nick .. ": I reloaded the command files.")
    else
        log("Attempt to reload unknown file " .. file .. ".lua", u, "warn")
        send(chan, u.nick .. ": I don't know what you're talking about.")
    end
end

-- check_create_dir(): Ensure that a dir exists; if not, attempt to create
function check_create_dir(d)
    if not io.open(d, "r") then
        local stat, errmsg = assert(lfs.mkdir(d))
        if stat then
            log("Created dir " .. d, "info")
        else
            err("Error creating dir " .. d .. ": " .. errmsg)
        end
    else
        if ( lfs.attributes(d, "mode") ~= "directory" ) then
            err(d .. " is not a directory")
        else
            log("Dir " .. d .. " exists, using..", "debug")
        end
    end
end
-- check_create(): Ensure that a file exists; if not, attempt to create
function check_create(f)
    if not io.open(f, "r") then
        local stat, errmsg = assert(io.open(f, "w"))
        if stat then
            log("Created file " .. f, "info")
            stat:close()
        else
            err("Error creating file " .. f .. ": " .. errmsg)
        end
    else
        if ( lfs.attributes(f, "mode") ~= "file" ) then
            err(f .. " is not a file")
        else
            log("File " .. f .. " exists, using..", "debug")
        end
    end
end
-- }}}

-- {{{ IRC framework
function send(chan, str)
    -- Wrapper func: should be changed according to irc framework used
    -- Allows for more dynamic rewriting of the well-used message sending.
    if ( type(chan) == "table" ) then
        if chan.nick then chan = chan.nick end
    end
    conn:sendChat(chan, str)
end

function sendRaw(str)
    -- Wrapper function for passing a rawquote to the server
    -- str must be preformatted; content is not examined
    conn:send(str)
end

function sendNotice(nick, str)
    -- Wrapper function for sending notices
    -- Mostly used for ctcp replies
    sendRaw("NOTICE " .. nick .. " :" .. str)
end

function check_user(nick) -- Whois function to check if a user exists
    local uinfo = conn:whois(nick)
    if uinfo.userinfo then
        return true
    else
        return nil
    end
end

-- check_joined(): Check if Minnet is joined to 'c'
function check_joined(c) -- Returns true if c is in n's joined list
    c = c:lower()
    local found
    for i = 1, #net.joined do
        if ( net.joined[i] == c ) then
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

-- channel_add(): Add 'c' to list of joined channels
function channel_add(c)
    c = c:lower()
    table.insert(net.joined, c)
    log("Added " .. c .. " to joined channel list on " .. net.name,
        "info")
end

-- channel_remove(): Remove 'c' from list of joined channels
function channel_remove(c)
    c = c:lower()
    local num, found
    for i = 1, #net.joined do
        if ( net.joined[i] == c ) then
            found = true
            num = i
            break
        end
    end
    if found then
        log("Removing channel " .. c .. " from joined channel list on " ..
            net.name, "info")
        table.remove(net.joined, num)
        return true
    else
        return false
    end
end
-- }}}

-- {{{ Parsing and maths
function otkgen()
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

function wit(u, chan, m) -- Main hook function for reacting to commands
    local nickmatch = "^" .. conn.nick .. "%s-[,:;%-$]+%s+"
    if m:match(nickmatch) then
        m = m:gsub(nickmatch, "")
    end
    if ( m == "" ) or m:match("^%s+") or m:match("%\001") then return nil end
    m = m:gsub("%s+$", "")
    cmdFound = false
    local cmdfunc, catch
    for cmd, names in pairs(bot.commands) do
        for _, name in ipairs(names) do
            catch = m:lower():match("^(" .. name .. ")")
            if catch then
                cmdFound = true
                break
            end
        end
        if cmdFound == true then
            cmdfunc = cmd
            break
        end
    end
    if cmdFound == true then
        log("chan == " .. chan .. "; cmdfunc == " .. cmdfunc, u, "internal")
        if check_disabled(chan, cmdfunc) == true then return nil end
        log("Received command '" .. m .. "' on " .. net.name .. "/" .. chan,
            u, "debug")
        local func = cmdlist[cmdfunc].func
        if type(func) == "function" then
            func(u, chan, m, catch)
        end
    else
        log("Could not understand command '" .. m .. "'", u, "debug")
        send(chan, "Excuse me?")
    end
end

-- Create msg.help() function; read name, version and append to --help message
function create_help()
    name = ""
    io.input(arg[0])
    local matchstring = "^%-%-%s-(" .. arg[0]:match("%p*(%S+)") .. ".*)$"
    while not name:match(matchstring) or not io.read() do
        name = io.read()
    end
    io.close()
    name = name:gsub("^%W*", "")
    version = name:match("^%S+%s+(%d%.%d%.%d%.?%d?)")
end
msg.help = function()
    print(name)
    print("Usage: " .. arg[0] .. " [--help|--dry] [OPTIONS]")
    print()
    print("OPTIONS is one or more of the following:")
    print("    -v, --verbose [LEVEL]    set to output debug info, or set output to specified level")
    print("    -n, --network NET        connect to network NET, as identified by name")
    os.exit()
end
-- }}}
-- EOF
