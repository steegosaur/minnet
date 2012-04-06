#!/usr/bin/env lua
-- cmdarray.lua - command file for minnet
-- Copyright Stæld Lakorv, 2010-2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file contains an array which is referenced by the meta-array in
--+ cmdvocab.lua, so that several triggers there can use the same command
--+ definition, thus enabling re-use of portions or wholes of the code.

cmdlist = {
    -- time: report the current time (optionally, in a given numerical tz)
    time = {
        help = "Want to know what the time is?",
        func = function(u, chan, m)
            local response = "%s: The time is currently %.2d:%.2d:%.2d %s, " ..
                "%s %.4d-%.2d-%.2d."
            local now, tz = time.get_current(m)
            if tz == "unknown" then
                send(chan, u.nick .. ": Sorry, I don't know that timezone.")
                return nil
            elseif not now then
                return nil
            end
            send(chan, response:format(u.nick, now.hour, now.min, now.sec, tz,
                time.wdays.short[now.wday], now.year, now.month, now.day))
        end
    },
    timezones = {
        help = "Want a list of the timezones I know?",
        func = function(u, chan, m)
            local tzs = time.timezones
            table.sort(tzs)
            local list, i = {}, 1
            for zone in pairs(tzs) do
                if not list[1] then
                    list[1] = u.nick .. ": The timezones I know are:"
                    i = i + 1
                end
                if not list[i] then
                    list[i] = zone
                elseif list[i] and string.len(list[i] .. " " .. zone) < 81 then
                    list[i] = list[i] .. " " .. zone
                elseif list[i] and string.len(list[i] .. " " .. zone) > 80 then
                    i = i + 1
                    list[i] = zone
                end
            end
            log("Outputting timezone list to " .. chan, u, "trivial")
            for i, line in ipairs(list) do
                send(chan, line)
            end
        end
    },
    twentytwo_seven = {
        help = "The worst tragedy in Norwegian history - how long has it been?",
        func = function(u, chan, m)
            local when = {
                -- Times are UTC (local time was +2h)
                year  = 2011,
                month = 7,
                day   = 22,
                oslo  = { hour = 13, min = 26 },
                utoya = { hour = 15, min = 15 }
            }
            m = m:lower()
            local now = os.time(time.get_current(" UTC"))
            local incident, incident_time
            if m:match("ut[oøe]-ya") then
                incident = "Utøya"
                inc_var  = "utoya"
            elseif ( m:match("oslo") or m:match("norway") ) and
              m:match("bomb") then
                incident = "Oslo"
                inc_var  = "oslo"
            end
            if incident then
                incident_time = os.time({ year = when.year, month = when.month,
                    day = when.day, hour = when[inc_var].hour,
                    min = when[inc_var].min })
                local diff = os.difftime(now, incident_time)
                local days, hours, mins = time.calculate(diff)
                local re_pattern = "%s: It has been %s%s%s since the %s " ..
                    "incident, which occured at %.4d-%.2d-%.2d, %.2d:%.2d UTC."
                local response = re_pattern:format(u.nick, days, hours, mins,
                    incident, when.year, when.month, when.day,
                    when[inc_var].hour, when[inc_var].min)
                send(chan, response)
            else
                send(chan, u.nick .. ": Pardon, what did you say?")
            end
        end
    },
    -- uptime: report uptime of self or server hosting self
    uptime = {
        help = "Report uptime of server or connection.",
        func = function(u, chan, m)
            m = m:lower()
            if
             (
              (
               m:match("online") or m:match("%s+up[%s%p]+") or
               m:match("uptime") or m:match("connected") or m:match("running")
              ) and
              (
               m:match("you") or m:match("ya%s") or m:match("yer%s")
              ) and not
              (
               m:match("system") or m:match("computer") or m:match("server")
              )
             )
            then
                local diff = os.difftime(os.time(), bot.start)
                local weeks, days, hours, mins = time.calculate(diff)
                if weeks == "" and days == "" and hours == "" and
                  mins == "" then
                    send(chan, u.nick .. ": I just got online!")
                else
                    send(chan, u.nick .. ": I've been online for " ..
                        weeks .. days .. hours .. mins .. ".")
                end
            elseif
             (
              (
               m:match("%s+up[%s%p]+") or m:match("uptime") or
               m:match("online") or m:match("running")
              ) and
              (
               m:match("system") or m:match("server") or m:match("computer") or
               m:match("host")
              )
             )
            then
                local r = { "system", "server", "computer" }
                local sysword = r[math.random(1, #r)]
                -- Read standard GNU/Linux uptime file
                -- TODO: Make this cross-platform by implementing Windows alternative too?
                local uptime_file = io.open("/proc/uptime")
                if not uptime_file then
                    log("/proc/uptime unavailable, skipping uptime reporting",
                        "info")
                    send(chan, "Sorry, but I couldn't find the uptime.")
                    return nil
                end
                local utime = uptime_file:read()
                uptime_file:close()
                utime = tonumber(utime:match("^(%d+)%.%d%d%s+"))
                local weeks, days, hours, mins = time.calculate(utime)
                if weeks == "" and days == "" and hours == "" and
                  mins == "" then
                    send(chan, u.nick .. ": It was just booted!")
                else
                    send(chan, u.nick .. ": The " .. sysword .. " went up " ..
                        weeks .. days .. hours .. mins .. " ago.")
                end
            else
                send(chan, "Err, what?")
                log("Could not recognise enough keywords for uptime command, ignoring", "trivial")
            end
        end
    },
    -- be: send /me is 'arg' to 'chan'
    be = {
        help = "Make me be something.",
        func = function(u, chan, m)
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
                    -- Check if we're outputting to another channel
                    local arg1 = arg:match("^%s-(" ..cprefix..cname_patt.. ")%s+%S+")
                    if arg1 and check_joined(arg1) then
                        chan = arg1
                        arg = arg:match("^%s-%S+%s+(.*)$")
                    end
                    ctcp.action(u, chan, "is " .. arg .. smile)
                end
            else
                log("Received unauthorised be command", u, "trivial")
                send(u.nick, msg.notauth)
            end
        end
    },
    belong = {
        help = "Want to own me?",
        func = function(u, chan)
            if db.check_auth(u, "owner") then
                send(chan, "You already own me, silly.")
            elseif db.check_auth(u, "oper") then
                local owner = db.get_owner()
                local first_letter = owner:sub(1, 1)
                owner = owner:gsub("^%l", first_letter:upper())
                send(chan, u.nick .. ": Sorry, you'll have to ask " .. owner ..
                    ".")
            else
                send(chan, "Who do you think you are?")
            end
        end
    },
    owner = {
        help = "Want to know who's my owner?",
        func = function(u, chan, m)
            local owner = tostring(db.get_owner())
            if owner:lower() == u.nick:lower() then
                send(chan, "You are my bloody owner.")
            else
                local first_letter = owner:sub(1, 1)
                owner = owner:gsub("^%l", first_letter:upper())
                send(chan, u.nick .. ": My owner is " .. owner .. ".")
            end
        end
    },
    -- join: join 'chan'
    join = {
        help = "Make me join a channel.",
        func = function(u, chan, m, catch)
            if db.check_auth(u, "admin") then
                local arg = m:match(catch .. "%s+(.*)")
                if not arg then
                    send(chan, u.nick .. ": Go to what channel?")
                else
                    local cn = arg:match("(" ..cprefix..cname_patt.. ")")
                    arg = arg:gsub("^.*channel%s+", "")
                    arg = arg:gsub("" ..cprefix..cname_patt.. "%s+", "")
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
                        ctcp.action(u, chan, msg.joining .. cn)
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
        end
    },
    -- part: part 'chan'
    part = {
        help = "Make me leave a channel.",
        func = function(u, chan, m, catch)
            if db.check_auth(u, "admin") then
                m = m:lower()
                local arg = m:match(catch .. "%s+(of%s+" .. cprefix .. "?" .. cname_patt ..")")
                if ( not arg ) or arg:match("^of%s+here") then
                    send(chan, msg.bye)
                    conn:part(chan)
                    log("Leaving channel " .. chan .. " on " .. net.name, "info")
                    if not channel_remove(chan) then
                        log("Error: Could not remove channel " .. chan ..
                            " from table bot.nets[" .. n .. "].joined (" ..
                            net.name .. ")", "warn")
                    end
                elseif arg:match("^of%s+" .. cprefix .. cname_patt) then
                    arg = arg:match("^of%s+(" ..cprefix..cname_patt.. ")")
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
        end
    },
    -- reload: reload/rerun files
    reload = {
        help = "Reload or re-run files.",
        func = function(u, chan, m)
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
        end
    },
    -- set: set variables
    set = {
        help = "Set variables.",
        func = function(u, chan, m)
            if db.check_auth(u, "admin") then
                m = m:lower()
                arg = getarg(m)
                arg = arg:gsub("%s*the%s+", "", 1)
                local cmd = arg:match("^(%a+)")
                local arg = getarg(arg)
                if cmd == "logging" or cmd:match("^verbos") or
                  cmd:match("^debug") or cmd:match("^output") then
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
        end
    },
    -- load: load stuff (atm: hooks)
    load = {
        help = "Load hooks or something.",
        func = function(u, chan, m)
            if db.check_auth(u, "admin") then
                m = getarg(m)
                m = m:gsub("%s*the%s*", "", 1)
                m = m:gsub("^%s*hooks?%s*", "", 1)
                m = m:gsub("%s*called%s*", "", 1)
                local hookname = m:match("^['\"«»]-([^%s'\"»«]+)")
                if hookname then
                    if hookname == "all" then
                        log("Reloading all hooks..", u, "info")
                        for i, h in ipairs(hooks) do
                            conn:hook(h.event, h.name, h.action)
                        end
                        send(chan, u.nick .. ": So, reloaded all the hooks.")
                        return nil
                    end
                    local hookfound = false
                    for i, h in ipairs(hooks) do
                        if h.name == hookname then
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
        end
    },
    -- unload: unload stuff (ie., hooks)
    unload = {
        help = "Unload hooks and stuff.",
        func = function(u, chan, m)
            if db.check_auth(u, "admin") then
                m = getarg(m)
                m = m:gsub("%s*the%s*", "", 1)
                m = m:gsub("%s*called%s*", "", 1)
                local hookname = m:match("^['\"«»]-([^%s'\"»«]+)")
                if hookname then
                    local hookfound = false
                    for i, h in ipairs(hooks) do
                        if h.name == hookname then
                            log("Removing hook " .. h.name .. " for event " ..
                                h.event, u, "info")
                            conn:hook(h.event, h.name, h.action)
                            send(chan, u.nick .. ": Okay, got rid of it.")
                            hookfound = true
                            break
                        end
                    end
                    if not hookfound then
                        log("Attempted to remove unknown hook " .. hookname,
                            u, "trivial")
                        send(chan, u.nick .. ": I'm sorry, but I couldn't " ..
                            "find any hook by that name.")
                    end
                else
                    log("Could not understand hook name", u, "trivial")
                    send(chan, u.nick .. ": Unload what?")
                end
            else
                log("Received unauthorised unload command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- reseed: reseed random number seed
    -- TODO: Automate this?
    reseed = {
        help = "Make a new seed for the random number generator.",
        func = function(u, chan, m)
            math.randomseed(os.time())
            log("Reseeded math.random", u, "info")
            send(chan, u.nick .. ": Done.")
        end
    },
    -- areyou: respond to stupid questions with stupid answers
    areyou = {
        help = "No.",
        func = function(u, chan, m, catch)
            local predic = m:match(catch)
            if predic and predic:match("^.+ing%s") then
                send(chan, "No, I'm not.")
            else
                local resp = { "Nope", "Nah", "Nay", "No", "Pff", "Duh", "Don't ask" }
                send(chan, resp[math.random(1, #resp)] .. ".")
            end
        end
    },
    -- say: output message to channel
    say = {
        help = "Make me say something.",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                local arg = getarg(m)
                if not arg then
                    send(chan, u.nick .. ": Say what?")
                else
                    local inchan = false
                    local nick
                    local say = ""
                    -- Channel to output to?
                    local t = arg:match("^%s-(" ..cprefix..cname_patt.. ")%s+%S+")
                    -- Telling someone something?
                    if arg:match("%s+to%s+[^%s!%?%.,]+") then
                        nick = arg:match("([^%s%.,!%?]+)%s-[%.,!%?]-$")
                        local q = conn:whois(nick)
                        if q.channels then
                            for w in q.channels[3]:gmatch("(" ..cprefix..cname_patt.. ")") do
                                if w == chan then
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

                    -- Fix uppercase letters and initial %'s
                    local subit, subto
                    if say:sub(1, 1) == "%" then
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
        end
    },
    -- version: send a CTCP VERSION request to someone
    version = {
        help = "Have me request a VERSION reply from someone.",
        func = function(u, chan, m, catch)
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
        end
    },
    -- identify: identify user with self
    identify = {
        help = "Identify yourself to validate your access level.",
        func = function(u, chan, m, catch)
        -- Syntax: identify nick password
            local args = m:lower()
            args = args:match(catch .. "%s+(.*)") or ""
            -- Get rid of human-input nonsense (might invalidate certain nicks)
            args = args:gsub("^me%p?%s+", "")
            if args:match("^for%s+%S+") then
                args = args:gsub("^for%s+", "")
            elseif args:match("^as%s+%S+") then
                args = args:gsub("^as%s+", "")
            end
            args = args:gsub("^the%s+", "")
            args = args:gsub("^user%s+", "")
            if args:match("^called%p?%s+%S+") then
                args = args:gsub("^called%p?%s+", "")
            elseif args:match("^named%p?%s+%S+") then
                args = args:gsub("^named%p?%s+", "")
            end
            local name = args:match("^(" .. nick_patt .. ")") -- Capture the name
            if not name then
                send(u.nick, "You forgot telling me your name.")
                return nil
            end
            args = args:gsub("^" .. name:gsub("(%p)", "%%%1") .. "%p?%s*", "")
            if args:match("^with%s+%S+") then
                args = args:gsub("with%s+", "")
            end
            args = args:gsub("^the%s+", "")
            args = args:gsub("^password%s+", "")
            args = args:gsub("^is%s+", "")
            local passwd = args:match("^(%S+)")
            if not passwd then
                send(u.nick, "You forgot the password.")
                return nil
            end
            db.ident_user(u, name, passwd)
        end
    },
    remember = {
        help = "Got anything you want me to remember?",
        func = function(u, chan, m, catch)
            local note = m:match(catch)
            log("remember triggered: catch == " .. catch, u, "internal")
            if not note then
                send(chan, "Eh, say what?")
                return nil
            end
            idb.set_todo(u, chan, note)
        end
    },
    remind = {
        help = "So you forgot, eh?",
        func = function(u, chan, m, catch)
            local item = m:match(catch)
            log("remind triggered: catch == " .. catch, u, "internal")
            if not item then
                send(chan, "I don't think you told me about that.")
                return nil
            end
            idb.get_todo(u, chan, item)
        end
    },
    -- idb_set: save user information in the infodb
    idb_set = {
        help = "Set user information.",
        func = function(u, chan, m, catch)
            local field, value = m:match(catch)
            log("idb_set triggered: field == " .. tostring(field) ..
                "; value == " .. tostring(value) .. "; catch == " .. catch,
                u, "internal")
            if not field then
                send(chan, "Sorry, I didn't get that.. what was it again?")
                return nil
            elseif not value then
                send(chan, "What did you say your " .. field .. " was?")
                return nil
            end
            field, value = field:gsub("%s+$", ""), value:gsub("%s+$", "")
            idb.set_data(u, chan, u.nick, field, value)
        end
    },
    -- idb_get: fetch user information in the infodb; TODO: add reverse syntax
    idb_get = {
        help = "Want to know something about someone?",
        func = function(u, chan, m, catch)
            local selfcheck
            local nick, field = m:match(catch)
            log("idb_get triggered: nick == " .. tostring(nick) ..
                "; field == " .. tostring(field) .. "; catch == " .. catch,
                u, "internal")
            if not nick then
                send(chan, "Huh? Who did you say?")
                return nil
            elseif not field then
                send(chan, "Uhm, say what?")
                return nil
            end
            if nick == "my" then
                selfcheck = true
            end
            field = field:gsub("%s+$", "")
            idb.get_data(u, chan, nick, field, selfcheck)
        end
    },
    -- db: database management meta-command
    db = {
        help = "Manage the database and carry out related operations; see " ..
            "'db help' for more information.",
        func = function(u, chan, m, catch)
            if chan:match("^" .. cprefix) then
                send(chan, "I can't let you do database operations in a " ..
                    "channel, sorry.")
                return nil
            end
            local arg = m:match(catch .. "%s+(.*)") or ""
            -- Catch what db operation we're doing:
            local cmd = arg:match("^%s-(%S+)") or ""
            -- Catch the arguments for the db operation:
            local arg = arg:match("^" .. cmd .. "%s-(%S+.*)") or ""

            if cmd == "mod" or cmd == "add" then
                -- Just bloody fix this inefficiency please? FIXME: INEFFICIENT
                -- (Possibly, try using catches and %n)
                arg   = arg:gsub("^the%s+", "")
                arg   = arg:gsub("^user%s+", "")
                local nick  = arg:match("^(%S+)") or ""
                nick  = nick:gsub("(%p)", "%%%1")
                local level = arg:match("^" .. nick .. "%s+(%S+)") or ""
                level = level:gsub("(%p)", "%%%1")
                local host  = arg:match("^" .. nick .. "%s+" .. level ..
                    "%s+(%S+)") or ""
                host  = host:gsub("(%p)", "%%%1")
                local passhash = arg:match("^" .. nick .. "%s+" .. level ..
                    "%s+" .. host .. "%s+(%S+)") or ""
                local email = arg:match("^" .. nick .. "%s+" .. level ..
                    "%s+" .. host .. "%s+" .. passhash .. "%s+(%S+)") or ""
                email = email:gsub("(%p)", "%%%1")
                local passhash  = passgen(passhash)
                db.set_data(u, cmd, nick, level, host, passhash, email)
            elseif cmd == "otk" then
                local key = arg:match("(%d+)")
                if key then
                    db.check_otk(u, key)
                end
            elseif cmd == "remove" or cmd == "delete" then
                arg = arg:gsub("^%S+%s+", "")
                arg = arg:gsub("^the%s+", "")
                arg = arg:gsub("^user%s+", "")
                local name = arg:match("^(%S+)")
                if not name then
                    send(u.nick, "I'm sorry, I didn't seem to catch the " ..
                        "username. Could you please say that again?")
                    return nil
                end
                db.rem_user(u, name)
            elseif cmd == "get" then
                arg = arg:gsub("user%s+", "")
                arg = arg:gsub("info[rmation]-%s+", "")
                arg = arg:gsub("on%s+", "")
                arg = arg:gsub("about%s+", "")
                local name = arg:match("(%S+)")
                db.show_user(u, name)
            elseif cmd == "set" then
                arg = arg:gsub("^my%s+", "")
                arg = arg:gsub("%s+to%s+", " ")
                local mode, value = arg:match("^(%S+)%s+(%S+)")
                db.set_user(u, mode, value)
            --[[ Bugged:
            elseif cmd == "flush" then
                local isauth = db.flush(udb, u)
                if isauth then db.flush(idb, u) end    -- Avoid double notauth --]]
            elseif cmd == "help" then
                send(chan, "Syntax: db (set|get|mod|add)")
                send(chan, "Add and mod are admin-level, and take NICK, " ..
                    "LEVEL, HOST, PASSWORD and EMAIL, separated by spaces. " ..
                    "All but NICK and LEVEL are voluntary for mod.")
                send(chan, "Get needs NICK, and shows the registered " ..
                    "information for that nick.")
                send(chan, "Set needs MODE and VALUE. It allows you to set " ..
                    "your email and password.")
            else
                send(chan, "I don't know what you meant I should do with " ..
                    "the database. Maybe you need some help?")
            end
        end
    },
    -- help: get general help, or help on a specific command
    help = {
        help = "You don't know what I can do!",
        func = function(u, chan, m, catch)
            if m:match("^" .. catch .. "[%s%p]-$") then
                -- Nothing more specified; show general help message
                log("Giving general help message in channel " .. chan,
                    "trivial")
                send(chan, "This is " .. name)
                send(chan, "For a full list of functionality, ask for help " ..
                    "on the commands.")
            elseif m:match("commands") then
                send(chan, "The available commands are:")
                -- Create plain cmdlist
                local commandlist = {}
                for cmd in pairs(bot.commands) do
                    table.insert(commandlist, cmd)
                end
                table.sort(commandlist)
                -- Crop the list so it fits IRC
                local width     = 92
                local cols      = 5
                local numprints = 0
                local sendtext  = ""
                for i, word in ipairs(commandlist) do
                    local spacing = width/cols - word:len()
                    sendtext = sendtext .. string.rep(" ", spacing) .. word
                    numprints = numprints + 1
                    if numprints == cols or i == #commandlist then
                        -- Line fully built; send it and start a new
                        send(chan, sendtext)
                        sendtext  = ""
                        numprints = 0
                    end
                end
                send(chan, "Remember that these are the internal " ..
                    "representations, and that they do not necessarily " ..
                    "correspond with the triggering commands.")
            else
                -- Something more than the catch was specified; identify it:
                --+ (pattern matches single word, only supports internal names)
                local helpcmd = m:match(catch .. "%s-(%l+)")
                local cmdFound = false
                for command in pairs(bot.commands) do
                    if helpcmd == command then
                        cmdFound = true
                        break
                    end
                end
                if cmdFound == true then
                    send(chan, cmdlist[helpcmd].help)
                    log("Sending help for command " .. helpcmd ..
                        " to channel " .. chan, "debug")
                else
                    send(chan, "Sorry, I don't know that command. Need " ..
                        "some help?")
                end
            end
        end
    },
    -- ignore: ignore users
    ignore = {
        help = "Make me ignore someone; specify whether given pattern is of " ..
            "type nick, user or host. Patterns are Lua-style. Remember to " ..
            "escape special characters like [] etc.",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                m = getarg(m)
                m = m:lower()
                local class
                if m:match("%s+user%s+") or m:match("username") then
                    class = "user"
                elseif m:match("%s+host[maskne]-") or m:match("%%%.") then
                    class = "host"
                else
                    class = "nick"
                    m = m:gsub("^%s-the%s+", "")
                    m = m:gsub("^%s-person%s+", "")
                    m = m:gsub("^with", "")
                    m = m:gsub("^%s-the", "")
                    m = m:gsub("^.*%sname%s+", "")
                end
                m = m:gsub("^.*%s-" .. class .. "%w-%s+", "")
                -- Ignore quotes when catching the pattern
                local pattern = m:match("^['\"«»]-([^%s'\"«»]+)")
                if not pattern then
                    send(chan, "Uhm, who did you say?")
                    log("Could not find pattern in ignore command", "debug")
                    return nil
                else
                    m = m:gsub(pattern .. "%s*", "", 1)
                    local channel
                    if m:match("global") or m:match("%Lnet") then
                    -- This is a global ignore
                        channel = "_" .. net.name
                    else
                        channel = m:match("(" ..cprefix..cname_patt.. ")")
                    end
                    if not channel then channel = chan end
                    log("Pattern found by ignore function: " .. pattern,
                        "internal")
                    if not bot.ignore[channel] then bot.ignore[channel] = {} end
                    table.insert(bot.ignore[channel], class .. "/" .. pattern)
                    log("Commencing ignoring of " .. class .. " '" ..
                        pattern .. "'", "info")
                    send(chan, "Okay, ignoring messages matching that.")
                end
            else
                log("Received unauthorised ignore command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- unignore: unignore a user
    unignore = {
        help = "Make me unignore someone; specify numeric index or pattern.",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                m = getarg(m)
                m = m:lower()
                local pattern = m:match("^(%S+)")
                local channel
                if m:match("global") or m:match("%Lnet") then
                -- This is a global ignore
                    channel = "_" .. net.name
                else
                    channel = m:match("(" ..cprefix..cname_patt.. ")")
                end
                if not channel then channel = chan end
                if not bot.ignore[channel] then
                    -- We don't have any ignores active here
                    send(chan, "Sorry, but there are no ignores for this " ..
                        "channel yet.")
                    log("Attempted to unignore in channel " .. channel ..
                        " without active ignore table", u, "debug")
                    return nil
                end
                if not pattern then
                    send(chan, "Unignore who?")
                    log("Could not find target in unignore command", "debug")
                else
                    if pattern:match("^%d+$") then
                    -- pattern is a numeric, thus gives a pattern id
                        local id = tonumber(pattern)
                        if not bot.ignore[channel][id] then
                            send(chan, "Sorry, that id is nonexisting.")
                            log("Caught out-of-bounds id for unignore",
                                "debug")
                            return nil
                        end
                        local remd = table.remove(bot.ignore[channel], id)
                        log("Unignored pattern '" .. remd .. "' with id " .. id,
                            u, "info")
                        send(chan, "Okay, not ignoring the user " ..
                            "any more.")
                    else
                        for i, entry in ipairs(bot.ignore[channel]) do
                            if entry:gsub("^%w+/", "", 1) == pattern then
                                log("Found match for pattern '" .. pattern ..
                                    "' in table; id = " .. i, "debug")
                                remd = table.remove(bot.ignore[channel], i)
                                log("Unignored pattern '" .. remd .. "' with"..
                                    " id " .. i, u, "info")
                                send(chan, "Okay, not ignoring the user " ..
                                    "any more.")
                                break
                            end
                        end
                    end
                end
            else
                log("Received unauthorised unignore command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    lignore = {
        help = "What, you don't remember who you told me to disregard?",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                -- Channel is either specified or current chan, or current net
                local channel
                if m:match("global") or m:match("%Lnet") then
                    channel = "_" .. net.name
                else
                    channel = m:match("(" ..cprefix..cname_patt.. ")") or chan
                end
                if bot.ignore[channel] and #bot.ignore[channel] > 0 then
                    log("Listing ignores for channel " .. channel, u, "info")
                    send(u.nick, "Ignores for channel " .. channel .. ":")
                    socket.sleep(0.2)
                    -- Output style: 1 (nick) someperson
                    local fmtstr = "%d (%s) %s"
                    -- Iterate over every ignore, sending one per line
                    for i, entry in ipairs(bot.ignore[channel]) do
                        local type = entry:match("^(%l+)/")
                        local patt = entry:match(type .. "/(%S+)")
                        if not ( type and patt ) then
                            log("Failed to extract class and pattern from " ..
                                "ignore list for 'lignore'", "error")
                        end
                        -- Output via query to avoid channel spam
                        send(u.nick, fmtstr:format(i, type, patt))
                        -- Minor pause per 5th sending
                        if i / 5 == math.floor(i / 5) then
                            socket.sleep(1)
                        end
                    end
                else
                    log("No users ignored for channel " .. channel ..
                        "; reporting empty list", u, "debug")
                    send(chan, u.nick .. ": There are no ignored users " ..
                        "in the list.")
                end
            else
                log("Received unauthorised request to list ignores", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- enfunc: re-enable a given function
    enfunc = {
        help = "",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                m = getarg(m)
                m = m:gsub("^your%s+", "")
                m = m:gsub("function%w*", "")
                local target = m:match("['\"«»]([%l_]+)")
                if not target then
                    target = m:match("^([%l_]+)")
                end
                if not target then
                    log("Could not catch function to enable", "debug")
                    send(chan, "Enable what, you say?")
                    return nil
                end
                m = m:gsub(target .. "%s*", "", 1)
                local channel
                if m:match("global") or m:match("%Lnet") then
                    channel = "_" .. net.name
                else
                    channel = m:match("(" ..cprefix..cname_patt.. ")")
                        or chan
                end
                if not bot.disfuncs[channel] or #bot.disfuncs[channel] < 1 then
                -- List is either nonexistent or empty
                    log("Received request to enable function '" .. target ..
                        "' in channel " .. channel .. ", but no functions " ..
                        "disabled", u, "debug")
                    send(chan, "Eh, say what? There's nothing currently " ..
                        "disabled.")
                    return nil
                end
                local index = nil
                for i, entry in ipairs(bot.disfuncs[channel]) do
                    if entry == target then
                        index = i
                        break
                    end
                end
                if not index then -- Didn't find target in the list
                    log("Received request to enable un-disabled function",
                        "debug")
                    send(chan, "You know.. that wasn't even disabled in " ..
                        "the first place.")
                    return nil
                end
                log("Enabling function '" .. target .. "' in " .. channel, u,
                    "info")
                table.remove(bot.disfuncs[channel], index)
                send(chan, u.nick .. ": Okay, I'll consider doing that. " ..
                    "If they're nice.")
            else
                log("Received unauthorised request to enable a function",
                    "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- disfunc: disable a given function
    disfunc = {
        help = "Want me to quit doing that one thing?",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                m = getarg(m)
                m = m:gsub("^your%s+", "")
                m = m:gsub("^the%s+", "")
                m = m:gsub("function%w*", "")
                local target = m:match("['\"«»]([%l_]+)")
                if not target then
                    target = m:match("^([%l_]+)")
                end
                if not target then
                    log("Could not catch function to disable", "debug")
                    send(chan, "Disable what, you say?")
                    return nil
                end
                m = m:gsub(target .. "%s*", "", 1)
                if m:match("global") or m:match("%Lnet") then
                    channel = "_" .. net.name
                else
                    channel = m:match("(" ..cprefix..cname_patt.. ")")
                        or chan
                end
                log("Disabling function '" .. target .. "' in " .. channel, u,
                    "info")
                if not bot.disfuncs[channel] then bot.disfuncs[channel] ={} end
                table.insert(bot.disfuncs[channel], target)
                send(chan, u.nick .. ": Fine, I'll quit doing that..")
            else
                log("Received unauthorised request to disable a function", u,
                    "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- disable: do not react to anything
    disable = {
        help = "Make me shut up.",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                local silchan = m:match("(" ..cprefix..cname_patt.. ")")
                if not silchan then silchan = chan end
                log("Entering response freeze for channel " .. silchan, u,
                    "info")
                bot.disabled[chan] = true
                send(chan, msg.shutup)
            else
                log("Received unauthorised disabling command", u, "warn")
                send(u.nick, msg.nothauth)
            end
        end
    },
    -- enable: commence responding again
    enable = {
        help = "Make me respond again.",
        func = function(u, chan, m)
            if db.check_auth(u, "oper") then
                log("Unfreezing channel " .. chan, u, "info")
                bot.disabled[chan] = false
                send(chan, msg.talk)
            else
                log("Received unauthorised enabling command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    -- quit: disconnect from the network
    quit = {
        help = "Disconnect me from the network.",
        func = function(u, chan, m)
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
        end
    },
}

-- EOF
