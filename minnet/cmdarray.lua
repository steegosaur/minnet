#!/usr/bin/env lua
-- cmdarray.lua - command file for minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file contains an array which is referenced by the meta-array in
--  cmdvocab.lua, so that several triggers there can use the same command
--  definition, thus enabling re-use of portions or wholes of the code.

cmdlist = {
    -- uptime: report uptime of self or server hosting self
    uptime = function(u, chan, m)
        m = m:lower()
        if ( ( m:match("online") or m:match("%s+up[%s%p]+") or
          m:match("uptime") or m:match("connected") or m:match("running") ) and
          m:match("you") and not ( m:match("system") or
          m:match("computer") or m:match("server") ) ) then
            local diff = os.difftime(os.time(), bot.start)
            local days, hours, mins = timecal(diff)
            if ( days == "" ) and ( hours == "" ) and ( mins == "" ) then
                send(chan, u.nick .. ": I just got online!")
            else
                send(chan, u.nick .. ": I've been online for " .. days .. hours .. mins .. ".")
            end
        elseif ( ( m:match("%s+up[%s%p]+") or m:match("uptime") or
          m:match("running") ) and ( m:match("system") or
          m:match("server") or m:match("computer") ) ) then
            local r = { "system", "server", "computer" }
            local sysword = r[math.random(1, #r)]
            -- Read standard GNU/Linux uptime file
            -- TODO: Make this cross-platform by implementing Windows alternative too?
            io.input("/proc/uptime")
            local utime = io.read()
            io.close()
            utime = tonumber(utime:match("^(%d+)%.%d%d%s+"))
            local days, hours, mins = timecal(utime)
            if ( days == "" ) and ( hours == "" ) and ( mins == "" ) then
                send(chan, u.nick .. ": It was just booted!")
            else
                send(chan, u.nick .. ": The " .. sysword .. " went up " ..
                  days .. hours .. mins .. " ago.")
            end
        else
            send(chan, "Err, what?")
            log("Could not recognise enough keywords for uptime command, ignoring", "trivial")
        end
    end,

    -- be: send /me is 'arg' to 'chan'
    be = function(u, chan, m)
        if db.check_auth(u, "user") then
            local arg = getarg(m)
            local smile
            if not arg then
                send(chan, u.nick .. ": Be what?")
            else
                for i = 1, #bot.smiles do
                    if string.match(m, "%s+" .. bot.smiles[i].text) then
                        smile = " " .. bot.smiles[i].face
                        break
                    end
                end
                if not smile then smile = "" end
                local arg1 = arg:match("^%s-(#%S+)%s+%S+")
                if arg1 then chan = arg1; arg = arg:match("^%s-%S+%s+(.*)$") end
                ctcp.action(chan, "is " .. arg .. smile)
            end
        else
            log("Received unauthorised be command", u, "trivial")
            send(u.nick, msg.notauth)
        end
    end,

    -- join: join 'chan'
    join = function(u, chan, m, catch)
        if db.check_auth(u, "admin") then
            local arg = m:match(catch .. "%s+(.*)")
            if not arg then
                send(chan, u.nick .. ": Go to what channel?")
            else
                local cn = arg:match("(#[^%s%.,]+)")
                arg = arg:gsub("^.*channel%s+", "")
                arg = arg:gsub("#%S+%s+", "")
                --arg = arg:gsub("^with%s+", "")
                local k
                if arg:match("key%s+%S+") then
                    k = arg:match("key%s+(%S+)")
                elseif arg:match("word%s+%S+") then
                    k = arg:match("word%s+(%S+)")
                end
                if check_joined(cn) then
                    send(chan, "I'm already there!")
                else
                    channel_add(cn)
                    ctcp.action(chan, msg.joining .. cn)
                    if k then
                        conn:join(cn, k)
                    else
                        conn:join(cn)
                    end
                end
            end
        else
            log("Received unauthorised join command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- part: part 'chan'
    part = function(u, chan, m, catch)
        if db.check_auth(u, "admin") then
            m = m:lower()
            local arg = m:match(catch .. "%s+(of%s+#?[^%s%.!,]+)")
            if ( not arg ) or arg:match("^of%s+here") then
                send(chan, msg.bye)
                conn:part(chan)
                log("Leaving channel " .. chan .. " on " .. net.name, "info")
                if not channel_remove(chan) then
                    log("Error: Could not remove channel " .. chan ..
                        " from table bot.nets[" .. n .. "].joined (" ..
                        net.name .. ")", "warn")
                end
            elseif arg:match("^of%s+#%S") then
                arg = arg:match("^of%s+(#[^%s%.!,]+)")
                send(chan, "Leaving " .. arg)
                send(arg, msg.bye)
                conn:part(arg)
                log("Leaving channel " .. arg .. " on " .. net.name, "info")
                if not channel_remove(arg) then
                    log("Error: Could not remove channel " .. arg ..
                        " from table bot.nets[" .. n .. "].joined (" ..
                        net.name .. ")", "warn")
                end
            else
                log("No understandable channel given to part from", "trivial")
                send(chan, "Sorry, what channel didya say I should part from?")
            end
        else
            log("Received unauthorised part command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- reload: reload/rerun files
    reload = function(u, chan, m)
        if db.check_auth(u, "admin") then
            local arg = getarg(m)
            if not arg then
                send(chan, u.nick .. ": Reload what?")
            else
                arg = arg:gsub("%s*the%s+", "")
                arg = arg:gsub("%s*your%s+", "")
                arg = arg:gsub("%s*file%s*", "")
                local file = arg:match("^(%S+)")
                file = file:match("^(%a+)")
                if file then
                    reload(u, chan, file)
                else
                    log("No file specified or recognised for reload command", "trivial")
                    send(chan, u.nick ": Reload what?")
                end
            end
        else
            log("Received unauthorised reload command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- set: set variables
    set = function(u, chan, m)
        if db.check_auth(u, "admin") then
            m = m:lower()
            arg = getarg(m)
            arg = arg:gsub("%s*the%s+", "", 1)
            local cmd = arg:match("^(%a+)")
            local arg = getarg(arg)
            if ( cmd == "logging" ) or cmd:match("^verbos") or cmd:match("^debug") then
                arg = arg:gsub("%s*the%s+", "")
                arg = arg:gsub("%s*level%s*", "")
                arg = arg:gsub("%s*to%s+", "")
                if arg then
                    local level = arg:match("^(%a+)")
                    if levels[level] then
                        verbosity = levels[level]
                        log("Set verbosity level to " .. level .. " (" .. verbosity .. ")", u, "info")
                        send(chan, u.nick .. ": Done.")
                    else
                        log("Attempted to set unknown verbosity level " .. level, u, "trivial")
                        send(chan, u.nick .. ": I don't recognise that level.. could you try another?")
                    end
                else
                    log("No verbosity level specified", u, "debug")
                    send(chan, u.nick .. ": Set it to what?")
                end
            else
                log("User did not specify anything to set", u, "debug")
                send(chan, u.nick .. ": Set what?")
            end
        else
            log("Received unauthorised command: " .. m, u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- load: load stuff (atm: hooks)
    load = function(u, chan, m)
        if db.check_auth(u, "admin") then
            m = getarg(m)
            m = m:gsub("%s*the%s*", "", 1)
            m = m:gsub("%s*hook%s*", "", 1)
            m = m:gsub("%s*called%s*", "", 1)
            local hookname = m:match("^['\"«»]-([^%s'\"»«]+)")
            if hookname then
                local hookfound = false
                for i, h in ipairs(hooks) do
                    if ( h.name == hookname ) then
                        log("Assigning hook " .. h.name .. " for event " ..
                            h.event, u, "info")
                        conn:hook(h.event, h.name, h.action)
                        send(chan, u.nick .. ": Okay, I added the hook.")
                        hookfound = true
                        break
                    end
                end
                if not hookfound then
                    log("Attempted to load unknown hook " .. hookname, u, "trivial")
                    send(chan, u.nick .. ": I'm sorry, but I couldn't find any hook by that name.")
                end
            else
                log("Could not understand hook name", u, "trivial")
                send(chan, u.nick .. ": Load what?")
            end
        else
            log("Received unauthorised load command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- reseed: reseed random number seed
    -- TODO: Automate this?
    reseed = function(u, chan, m)
        math.randomseed(os.time())
        log("Reseeded math.random", u, "info")
        send(chan, u.nick .. ": Done.")
    end,

    -- say: output message to channel
    say = function(u, chan, m)
        if db.check_auth(u, "oper") then
            local arg = getarg(m)
            if not arg then
                send(chan, u.nick .. ": Say what?")
            else
                local inchan = false
                local nick
                local say = ""
                local t = arg:match("^%s-(#%S+)%s+%S+") -- Channel to output to?
                if arg:match("%s+to%s+%S+%s-%p-$") then -- Telling someone something?
                    nick = arg:match("([^%s%.,!%?]+)%s-[%.,!%?]-$")
                    local q = conn:whois(nick)
                    if q.channels then
                        for w in q.channels[3]:gmatch("(#%S+)") do
                            if ( w == chan ) then
                                inchan = true
                                break
                            end
                        end
                    end
                end
                if t then
                    say = arg:match("^%s-" .. t .. "%s+(%S+.*)$") -- Cut out channel name
                    if not check_joined(t) then
                        log("Attempted to say something in non-joined channel", u, "warn")
                        send(chan, "I can't - I'm not it that channel!")
                        return nil
                    end
                else
                    -- No channel specified, use the one we received the command in
                    t = chan
                    say = arg:match("^(.*)$")
                end

                if inchan then -- It's to a user, who has been found to be in the channel
                    say = say:gsub("%s+%S+%s+%S+%s-%p-$", "")
                    say = nick .. ": " .. say
                    log("Saying " .. say .. " to " .. nick .. " on channel " .. chan, u, "debug")
                end

                local subit, subto
                if ( say:sub(1, 1) == "%" ) then
                    subit, subto = "%%", "%%"
                else
                    if inchan then
                        subit = say:match("^%S+:%s+(%S)")
                        say = say:gsub(":%s+" .. subit, ": " .. subit:upper())
                    else
                        subit = say:sub(1, 1)
                        subto = say:sub(1, 1):upper()
                        say = say:gsub(subit, subto, 1)
                    end
                end
                send(t, say)
            end
        else
            log("Received unauthorised say command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- version: send a CTCP VERSION request to someone
    version = function(u, chan, m, catch)
        if db.check_auth(u, "user") then
            local arg = m:match(catch .. "%s+(.*)")
            if not arg then
                send(chan, u.nick .. ": Version who?")
            else
                if not check_user(arg) then return nil end
                ctcp.version(arg)
                vchan = chan
                table.insert(ctcp.active.version, arg)
            end
        else
            log("Received unauthorised version command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- identify: identify user with self
    identify = function(u, chan, m, catch)
        local args = m:match(catch .. "%s+(.*)") or ""
        args = args:gsub("^me%s+", "")
        if args:match("^for%s+%S+") then
            args = args:gsub("^for%s+", "")
        elseif args:match("^as%s+%S+") then
            args = args:gsub("^as%s+", "")
        end
        args = args:gsub("^user%s+", "")
        local name = args:match("^([^%s%.,]+)") -- Capture the name
        args = args:gsub("^" .. name:gsub("(%p)", "%%%1") .. "%s*", "")
        if args:match("^with%s+%S+") then
            args = args:gsub("with%s+", "")
        end
        args = args:gsub("^the%s+", "")
        args = args:gsub("^password%s+", "")
        local passwd = args:match("^(%S+)")
        if not name then
            send(u.nick, "You forgot telling me your name.")
            return nil
        elseif not passwd then
            send(u.nick, "You forgot the password.")
            return nil
        end
        db.ident_user(u, name, passwd)
    end,

    -- db: database management meta-command
    db = function(u, chan, m, catch)
        if chan:match("^#") then
            send(chan, "I can't let you do database operations in a channel, sorry.")
            return nil
        end
        local arg = m:match(catch .. "%s+(.*)") or ""
        -- Catch what db operation we're doing:
        local cmd = arg:match("^%s-(%S+)") or ""
        -- Catch the arguments for the db operation:
        local arg = arg:match("^" .. cmd .. "%s-(%S+.*)") or ""

        if ( cmd == "mod" ) or ( cmd == "add" ) then
            -- Just bloody fix this inefficiency, please? FIXME: INEFFICIENT
            -- (Possibly, try using catches and %n)
            arg   = arg:gsub("^the%s+", "")
            arg   = arg:gsub("^user%s+", "")
            local nick  = arg:match("^(%S+)") or ""
            nick  = nick:gsub("(%p)", "%%%1")
            local level = arg:match("^" .. nick .. "%s+(%S+)") or ""
            level = level:gsub("(%p)", "%%%1")
            local host  = arg:match("^" .. nick .. "%s+" .. level .. "%s+(%S+)") or ""
            host  = host:gsub("(%p)", "%%%1")
            local passhash = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+(%S+)") or ""
            local email = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+" .. passhash .. "%s+(%S+)") or ""
            email = email:gsub("(%p)", "%%%1")
            local passhash  = passgen(passhash)
            db.set_data(u, cmd, nick, level, host, passhash, email)
        elseif ( cmd == "otk" ) then
            local key = arg:match("(%d+)")
            if key then
                db.check_otk(u, key)
            end
        elseif ( cmd == "remove" ) or ( cmd == "delete" ) then
            arg = arg:gsub("^%S+%s+", "")
            arg = arg:gsub("^the%s+", "")
            arg = arg:gsub("^user%s+", "")
            local name = arg:match("^(%S+)")
            if not name then
                send(u.nick, "I'm sorry, I didn't seem to catch the username. Could you please say that again?")
                return nil
            end
            db.rem_user(u, name)
        elseif ( cmd == "get" ) then
            arg = arg:gsub("user%s+", "")
            arg = arg:gsub("info[rmation]-%s+", "")
            arg = arg:gsub("on%s+", "")
            arg = arg:gsub("about%s+", "")
            local name = arg:match("(%S+)")
            db.show_user(u, name)
        elseif ( cmd == "set" ) then
            local mode, value = arg:match("(%S+)%s+(%S+)")
            db.set_user(u, mode, value)
        elseif ( cmd == "flush" ) then
            db.flush(u)
        elseif ( cmd == "help" ) then
            send(chan, "Syntax: db (set|get|mod|add)")
            send(chan, "Add and mod are admin-level, and need NICK, LEVEL, HOST, PASSWORD and EMAIL, separated by spaces. EMAIL is voluntary.")
            send(chan, "Get needs NICK, and shows the registered information for that nick.")
            send(chan, "Set needs MODE and VALUE. It allows you to set you email and password.")
        else
            send(chan, "I don't know what you meant I should do with the database. Maybe you need some help?")
        end
    end,

    -- vocablist: list all known command vocab in raw form
    --[[ WIP
    vocablist = function(u, chan, m)
        if db.check_auth(u, "user") then
            local cmds = {}
            for cmd, names in pairs(bot.commands) do
                local cmd = {}
                table.insert(cmds, cmd)
                for _, name in ipairs(names) do
                    table.insert(cmds[cmd], name)
                end
            end
            log("Listing all available commands and their patterns in "..
                "channel " .. chan, u, "info")
            -- OUTPUT GOES HERE
        else
            log("Received unauthorised quit command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,
    --]]

    -- disable: do not respond to anything
    disable = function(u, chan, m)
        if db.check_auth(u, "oper") then
            log("Entering response freeze for channel " .. chan, u, "info")
            bot.disabled[chan] = true
            send(chan, msg.shutup)
        else
            log("Received unauthorised disabling command", u, "warn")
            send(u.nick, msg.nothauth)
        end
    end,

    -- enable: commence responding again
    enable = function(u, chan, m)
        if db.check_auth(u, "oper") then
            log("Unfreezing channel " .. chan, u, "info")
            bot.disabled[chan] = false
            send(chan, msg.talk)
        else
            log("Received unauthorised enabling command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,

    -- quit: disconnect from the network
    quit = function(u, chan, m)
        if db.check_auth(u, "owner") then
            if udb:isopen() and ( udb:close() ~= sqlite3.OK ) then
                db.error(u, "Could not close database: " .. udb:errcode() ..
                    " - " .. udb:errmsg())
            end
            send(chan, msg.bye)
            for i, f in pairs(logs) do
                f:write("-- Log closed at ", os.date("%F/%T"), "\n")
                f:close()
            end
            log("", "info")
            log("Received quit command", u, "info")
            log("", "info")
            conn:disconnect(msg.quitting)
        else
            log("Received unauthorised quit command", u, "warn")
            send(u.nick, msg.notauth)
        end
    end,
}

-- EOF
