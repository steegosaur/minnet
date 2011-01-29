#!/usr/bin/env lua
-- commands.lua - config file for minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING
bot.cmds  = {
    {
        name    = "how long",
        comment = "you want to know my uptime?",
        action  = function(u, chan, m)
            m = m:lower()
            local arg = m:match("^how%s+long%s+(.*)$")
            if ( ( arg:match("online") or arg:match("%s+up[%s%p]+") or
              arg:match("uptime") or arg:match("connected") or arg:match("running") ) and
              arg:match("you") and not ( arg:match("system") or arg:match("computer") or arg:match("server") ) ) then
                local diff = os.difftime(os.time(), bot.start)
                local days, hours, mins = timecal(diff)
                if ( days == "" ) and ( hours == "" ) and ( mins == "" ) then
                    send(chan, u.nick .. ": I just got online!")
                else
                    send(chan, u.nick .. ": I've been online for " .. days .. hours .. mins .. ".")
                end
            elseif ( ( arg:match("%s+up[%s%p]+") or arg:match("uptime") or arg:match("running") ) and ( arg:match("system") or arg:match("server") or arg:match("computer") ) ) then
                -- Custom response in style with query
                local sysword
                if arg:match("system") then
                    sysword = "system"
                elseif arg:match("server") then
                    sysword = "server"
                elseif arg:match("computer") then
                    sysword = "computer"
                else
                    sysword = "system"
                end
                -- Read standard GNU/Linux uptime file
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
                log("Could not recognise enough keywords for 'how long', ignoring command", "trivial")
            end
        end
    },
    {
        name    = "be",
        comment = "make me be what you think I should be.",
        action  = function(u, chan, m)
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
        end
    },
    {
        name    = "go to",
        comment = "make me join a channel.",
        action  = function(u, chan, m)
            if db.check_auth(u, "admin") then
                local arg = m:match("^go%s+to%s+(#.*)")
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
        end
    },
    {
        name    = "get out",
        comment = "make me part from a channel.",
        action  = function(u, chan, m)
            if db.check_auth(u, "admin") then
                m = m:lower()
                local arg = m:match("^get%s+out[!%.]?%s-(of%s+#?[^%s%.!,]+)")
                if ( not arg ) or arg:match("^of%s+here") then
                    send(chan, msg.bye)
                    conn:part(chan)
                    log("Leaving channel " .. chan .. " on " .. net.name, "info")
                    if not channel_remove(chan) then
                        log("Error: Could not remove channel " .. chan .. " from table bot.nets[" .. n .. "].joined (" .. net.name .. ")", "warn")
                    end
                elseif arg:match("^of%s+#%S") then
                    arg = arg:match("^of%s+(#[^%s%.!,]+)")
                    send(chan, "Leaving " .. arg)
                    send(arg, msg.bye)
                    conn:part(arg)
                    log("Leaving channel " .. arg .. " on " .. net.name, "info")
                    if not channel_remove(arg) then
                        log("Error: Could not remove channel " .. arg .. " from table bot.nets[" .. n .. "].joined (" .. net.name .. ")", "warn")
                    end
                else
                    log("No understandable channel given to part from", "trivial")
                    send(chan, "Sorry, what channel did you say I should part from?")
                end
            else
                log("Received unauthorised part command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    },
    {
        name    = "say",
        comment = "make me say something.",
        action  = function(u, chan, m)
            if db.check_auth(u, "oper") then
                local arg = getarg(m)
                if not arg then
                    send(chan. u.nick .. ": Say what?")
                else
                    local inchan = false
                    local nick
                    local say = ""
                    local t = arg:match("^%s-(#%S+)%s+%S+")
                    if arg:match("%s+to%s+%S+$") then
                        nick = arg:match("(%S+)$")
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
                        say = arg:match("^%s-" .. t .. "%s+(%S+.*)$")
                    else
                        t = chan
                        say = arg:match("^(.*)$")
                    end

                    if inchan then
                        say = say:gsub("%s+%S+%s+%S+$", "")
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
        end
    },
    {
        name    = "version",
        comment = "ctcp version someone and hear the result in current channel.",
        action  = function(u, chan, m)
            if db.check_auth(u, "oper") then
                local arg = getarg(m)
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
    {
        name    = "identify",
        comment = "say, who are you again?",
        action  = function(u, chan, m)
            local args = getarg(m)
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
        end
    },
    {
        name    = "db",
        comment = "database management. ('db help' for more info)",
        action  = function(u, chan, m)
            if chan:match("^#") then
                send(chan, "I can't let you do database operations in a channel, sorry.")
                return nil
            end
            local arg = getarg(m) or ""
            local cmd = arg:match("^%s-(%S+)") or ""
            local arg = arg:match("^" .. cmd .. "%s-(%S+.*)") or ""
            if ( cmd == "mod" ) or ( cmd == "add" ) then
                -- Just bloody fix this inefficiency, please? FIXME: INEFFICIENT
                -- (Possibly, try using catches and %n)
                arg   = arg:gsub("^user%s+", "")
                local nick  = arg:match("^(%S+)") or ""
                nick  = nick:gsub("(%p)", "%%%1")
                local level = arg:match("^" .. nick .. "%s+(%S+)") or ""
                level = level:gsub("(%p)", "%%%1")
                local host  = arg:match("^" .. nick .. "%s+" .. level .. "%s+(%S+)") or ""
                host  = host:gsub("([%p])", "%%%1")
                local passhash = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+(%S+)") or ""
                local email = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+" .. passhash .. "%s+(%S+)") or ""
                email = email:gsub("([%p])", "%%%1")
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
        end
    },
    {
        name    = "get off",
        comment = "shut me down.",
        action  = function(u, chan, m)
            if db.check_auth(u, "admin") then
                if udb:isopen() and ( udb:close() ~= sqlite3.OK ) then
                    db.error(u, "Could not close database: " .. udb:errcode() .. " - " .. udb:errmsg())
                end
                send(chan, msg.bye)
                conn:disconnect(msg.quitting)
                log("", "info")
                log("Received quit command", u, "info")
                log(msg.quitting, "info")
            else
                log("Received unauthorised quit command", u, "warn")
                send(u.nick, msg.notauth)
            end
        end
    }
}

for i = 1, #bot.cmds do
    if not bot.cmds.list then
        bot.cmds.list = bot.cmds[i].name
    else
        bot.cmds.list = bot.cmds.list .. ", " .. bot.cmds[i].name
    end
end
table.insert(bot.cmds,{
    name    = "help",
    comment = "help message with cmd list",
    action  = function(u, chan, m)
        arg = getarg(m)
        if arg then
            found = false
            for i = 1, #bot.cmds do
                if ( bot.cmds[i].name == arg ) then
                    send(chan, bot.cmds[i].name .. ": " .. bot.cmds[i].comment)
                    found = true
                    break
                end
            end
            if ( found ~= true ) then
                send(chan, "I don't know that command!")
            end
        else
            send(chan, name)
            send(chan, "Commands: " .. bot.cmds.list .. ", help")
        end
    end
})
-- }}}
-- EOF
