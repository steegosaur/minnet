#!/usr/bin/env lua
-- funcs.lua - functions file for minnet
-- Copyright Stæld Lakorv, 2010-2014 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- {{{ Internal functionality
-- check_disabled(): Check if disabled in a channel
function check_disabled(chan, cmdfunc)
    local is_disabled
    local targets = { bot.disfuncs[chan], bot.disfuncs["_" .. net.name] }
    for _, t in ipairs(targets) do
        if type(t) == "table" and cmdfunc and cmdfunc ~= "enable" then
            for _, f in ipairs(t) do
                if f == cmdfunc then
                    is_disabled = true
                    log("Command '" .. cmdfunc .. "' is disabled, skipping..",
                        "debug")
                    break
                end
            end
        end
    end
    if ( bot.disabled[chan] == true and cmdfunc ~= "enable" ) or
      is_disabled then
        return true
    else
        return false
    end
end

-- is_ignored(): Check if a user is to be ignored
function is_ignored(u, chan, bool)
    if chan == conn.nick then return nil end
    if db.check_auth(u, "oper") then
        if not bool then
            log("User is of oper or higher level; not ignoring..", u, "debug")
        end
        return nil
    end
    if not bot.ignore[chan] and not bot.ignore["_" .. net.name] then
        if not bool then
            log("No table for given channel, not ignoring.", "debug")
        end
        return nil
    end
    local is_ignored
    local targets = { bot.ignore[chan], bot.ignore["_" .. net.name] }
    for _, t in ipairs(targets) do
        if type(t) == "table" then
            for _, patt in ipairs(t) do
                local type = patt:match("^(%l+)/")
                patt = patt:gsub("^" .. type .. "/", "", 1)
                local field
                if type == "user" then
                    field = "username"
                else
                    field = type
                end
                if u[field]:lower():match(patt) then
                    return true
                end
            end
        end
    end
    if not bool then
        log("Did not find any matching ignore pattern; not ignoring.", u,
            "debug")
    end
end

-- desat(): Strip colours from messages
function desat(m)
    if not m then return nil end
    m = tostring(m)
    m = m:gsub("^[^%w%p%s]+%d%d?%d?", "")
    return m
end

-- depends(): Require some of Minnet's modules (dependencies)
function depends(t)
    for _, mod in ipairs(t) do loadmod(mod, true) end
end

-- loadmod(): Load a module
function loadmod(mod, startup)
    if startup and bot.mods.loaded[mod] == true then
        -- Because if it is already there, we don't need to reload it at boot
        return
    end
    if io.open(bot.mods.path .. mod ..".lua", "r") then
        log("Loading module " .. mod, "internal")
        dofile(bot.mods.path .. mod .. ".lua")
        bot.mods.loaded[mod] = true
    else
        log("Could not load module " .. mod, "warn")
    end
end

-- reload(): Reload one or more files while running
function reload(u, chan, file)
    if not file then
        return nil
    end
    -- TODO: Use array to scale this properly
    if file == "functions"          then file = "funcs"
    elseif file == "configuration"  then file = "config"
    elseif file == "infodb"         then file = "idb"
    elseif file == "database"       then file = "db"
    elseif file == "log"            then file = "logging"
    elseif file == "feeds"          then file = "rss"
    end
    if file == "funcs" or file == "ctcp" or file == "db" or file == "idb" or
      file == "hooks" or file == "config" or file == "cmdvocab" or
      file == "cmdarray" or file == "time" or file == "logging" or
      file == "hacks" or file == "rss" then
        loadmod(file)
        send(chan, u.nick .. ": I reloaded " .. file .. ".lua.")
    elseif file == "commands" then
        local cmdfiles = { "cmdarray", "cmdvocab" }
        for _, file in ipairs(cmdfiles) do
            loadmod(file)
        end
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
        if lfs.attributes(d, "mode") ~= "directory" then
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
        if lfs.attributes(f, "mode") ~= "file" then
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
    if type(chan) == "table" then
        if chan.nick then chan = chan.nick end
    end
    conn:sendChat(chan, str)
end

function sendRaw(str)
    -- Wrapper function for passing a rawquote to the server
    -- str must be preformatted; content is not examined
    conn:send(str)
end

function sendNotice(chan, str)
    -- Wrapper function for sending notices
    -- Mostly used for ctcp replies
    if type(chan) == "table" then
        if chan.nick then chan = chan.nick end
    end
    conn:sendNotice(chan, str)
end

function get_topic(chan)
    conn:topic(chan)
    return topics[chan] or ""
end
function set_topic(chan, topic)
    local str = "TOPIC %s :%s"
    str = str:format(chan, topic)
    sendRaw(str)
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
        if net.joined[i] == c then
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
        if net.joined[i] == c then
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
    if ( not p ) or p == "" then return nil end
    local h = crypto.evp.digest("sha1", p)
    return h
end

function getarg(m) -- Gets everything after *first* word
    local arg = m:match("^%S+%s+(%S+.*)")
    return arg
end

function wit(u, chan, m) -- Main hook function for reacting to commands
    -- Check if user is ignored
    if is_ignored(u, chan) then
        log("Ignoring user on channel " .. chan, u, "internal")
        return nil
    elseif net.services and u.nick:lower() == net.services.nickserv.servnick:lower() then
        log("Received mumblemumble from NickServ", "trivial")
        return nil
    end
    -- Check if bot's name is mentioned in one of two recognised ways
    --+ TODO: make this use string.sub() to find the location and what's actually said, and then gsub() that away
    local nickmatch = "^" .. conn.nick:lower() .. "%s-[,:;%-]+%s+"
    if m:lower():match(nickmatch) then
        -- Locate where the name is
        local start, fin = m:lower():find(nickmatch)
        -- Get the actual contents
        local remove = m:sub(start, fin)
        m = m:gsub(remove, "")
    else
        nickmatch = "([,]+%s-" .. conn.nick:lower() .. "%s-)[%.!%?]*$"
        if m:lower():match(nickmatch) then
            local remove = m:lower():match(nickmatch)
            local start, fin = m:lower():find(remove)
            remove = m:sub(start, fin)
            m = m:gsub(remove, "")
        end
    end
    -- Skip a few non-normal commands
    if m == "" or m:match("^!") or m:match("^%s+") or m:match("%\001") then
        return nil
    end
    m = m:gsub("%s+$", "")  -- Just a simple clean-up
    cmdFound = false
    local cmdfunc, catch
    for cmd, names in pairs(bot.commands) do
        for _, name in ipairs(names) do
            local match = m:lower():match("^" .. name)
            if match then
                catch = name
                cmdFound = true
                break
            end
        end
        if cmdFound == true then
            cmdfunc = cmd
            break
        end
    end
    -- Check if the command is disabled:
    -- (This currently only checks if the command is 'unsilence' or not;
    --+ it will later on enable per-channel per-function disabling)
    if check_disabled(chan, cmdfunc) == true then return nil end
    if cmdFound == true then
        log("chan == " .. chan .. "; cmdfunc == " .. cmdfunc, u, "internal")
        log("Received command '" .. m .. "' on " .. net.name .. "/" .. chan,
            u, "debug")
        local func = cmdlist[cmdfunc].func
        if type(func) == "function" then
            func(u, chan, m, catch)
        end
    else
        m = m:gsub("[^%s%p%w]", "")
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
