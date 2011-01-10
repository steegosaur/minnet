#!/usr/bin/env lua
-- commands.lua - config file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet.  
-- Minnet is released under the GPLv3 - see ../COPYING 
bot.cmds  = {
    {
        name    = "how long",
        comment = "you want to know my uptime?",
        action  = function(n, u, chan, m)
            m = m:lower()
            local arg = m:match("^how%s+long%s+(.*)$")
            if ( ( arg:match("online") or arg:match("%s+up[%s%p]+") or arg:match("uptime") or arg:match("connected") or arg:match("running") ) and arg:match("you") and not ( arg:match("system") or arg:match("computer") or arg:match("server") ) ) then
                local diff = os.difftime(os.time(), bot.start)
                local days, hours, mins = timecal(diff)
                if ( days == "" ) and ( hours == "" ) and ( mins == "" ) then
                    c.net[n]:sendChat(chan, u.nick .. ": I just got online!")
                else
                    c.net[n]:sendChat(chan, u.nick .. ": I've been online for " .. days .. hours .. mins .. ".")
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
                    c.net[n]:sendChat(chan, u.nick .. ": It was just booted!")
                else
                    c.net[n]:sendChat(chan, u.nick .. ": The " .. sysword .. " went up " .. days .. hours .. mins .. " ago.")
                end
            else
                c.net[n]:sendChat(chan, "Err, what?")
                log("Could not recognise enough keywords, ignoring command")
            end
        end
    },
    {
        name    = "be",
        comment = "make me be what you think I should be.",
        action  = function(n, u, chan, m)
            local arg = getarg(m)
            local smile
            if not arg then
                c.net[n]:sendChat(chan, u.nick .. ": Be what?")
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
                ctcp.action(n, chan, "is " .. arg .. smile)
            end
        end
    },
    {
        name    = "go to",
        comment = "make me join a channel.",
        action  = function(n, u, chan, m)
            if db.check_auth(n, u, "admin") then
                local arg = m:match("^go%s+to%s+(#.*)")
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Go to what channel?")
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
--[[                    arg = arg:gsub("^[paskey]+word%s+", "")
                    arg = arg:gsub("^key%s+", "")
                    local k = arg:match("(%S+)") --]]
                    if check_joined(n, cn) then
                        c.net[n]:sendChat(chan, "I'm already there!")
                    else
                        channel_add(n, cn)
                        ctcp.action(n, chan, msg.joining .. cn)
                        if k then
                            c.net[n]:join(cn, k)
                        else
                            c.net[n]:join(cn)
                        end
                    end
                end
            else
                db.error(n, u, msg.notauth)
            end
        end
    },
    {
        name    = "get out",
        comment = "make me part from a channel.",
        action  = function(n, u, chan, m)
            if db.check_auth(n, u, "admin") then
                m = m:lower()
                local arg = m:match("^get%s+out[!%.]?%s-(of%s+#?[^%s%.!,]+)")
                if ( not arg ) or arg:match("^of%s+here") then
                    c.net[n]:sendChat(chan, msg.bye)
                    c.net[n]:part(chan)
                    log("Leaving channel " .. chan .. " on " .. bot.nets[n].name)
                    if not channel_remove(n, chan) then
                        log("Error: Could not remove channel " .. chan .. " from table bot.nets[" .. n .. "].joined (" .. bot.nets[n].name .. ")")
                    end
                elseif arg:match("^of%s+#%S") then
                    arg = arg:match("^of%s+(#[^%s%.!,]+)")
                    c.net[n]:sendChat(chan, "Leaving " .. arg)
                    c.net[n]:sendChat(arg, msg.bye)
                    c.net[n]:part(arg)
                    log("Leaving channel " .. arg .. " on " .. bot.nets[n].name)
                    if not channel_remove(n, arg) then
                        log("Error: Could not remove channel " .. arg .. " from table bot.nets[" .. n .. "].joined (" .. bot.nets[n].name .. ")")
                    end
                else
                    log("No understandable channel given to part from")
                    c.net[n]:sendChat(chan, "Sorry, what channel did you say I should part from?")
                end
            else
                db.error(n, u, msg.notauth)
            end
        end
    },
    {
        name    = "say",
        comment = "make me say something.",
        action  = function(n, u, chan, m)
            if db.check_auth(n, u, "oper") then
                local arg = getarg(m)
                if not arg then
                    cpnet[n]:sendChat(chan. u.nick .. ": Say what?")
                else
                    local say = ""
                    local t = arg:match("^%s-(#%S+)%s+%S+")
                    if t then
                        say = arg:match("^%s-" .. t .. "%s+(%S+.*)$")
                    else
                        t = chan
                        say = arg:match("^(.*)$")
                    end
                    --[[
                    local firstchar = say:sub(1, 1)
                    firstchar = firstchar:upper()
                    say = say:sub(2) --]]
                    say = say:gsub(say:sub(1, 1), say:sub(1, 1):upper(), 1)
                    c.net[n]:sendChat(t, say)
                end
            else
                db.error(n, u, msg.notauth)
            end
        end
    },
    {
        name    = "version",
        comment = "ctcp version someone and hear the result in current channel.",
        action  = function(n, u, chan, m)
            if db.check_auth(n, u, "oper") then
                local arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Version who?")
                else
                    ctcp.version(n, arg)
                    vchan = chan
                end
            else
                db.error(n, u, msg.notauth)
            end
        end
    },
    {
        name    = "identify",
        comment = "say, who are you again?",
        action  = function(n, u, chan, m)
            local args = getarg(m)
            args = args:gsub("^me%s+", "")
            if args:match("^for%s+%S+") then
                args = args:gsub("^for%s+", "")
            elseif args:match("^as%s+%S+") then
                args = args:gsub("^as%s+", "")
            end
            args = args:gsub("^user%s+", "")
            local name = args:match("^(%S+)%s+%S+") -- Capture the name
            args = args:gsub("^" .. name .. "%s+", "")
            if args:match("^with%s+%S+") then
                args = args:gsub("with%s+", "")
            end
            args = args:gsub("password%s+", "")
            local passwd = args:match("(%S+)")
            db.ident_user(n, u, name, passwd)
        end
    },
    {
        name    = "db",
        comment = "database management. ('db help' for more info)",
        action  = function(n, u, chan, m)
            if chan:match("^#") then
                c.net[n]:sendChat(chan, "I can't let you do database operations in a channel, sorry.")
                return nil
            end
            local arg = getarg(m) or ""
            local cmd = arg:match("^%s-(%S+)") or ""
            local arg = arg:match("^" .. cmd .. "%s-(%S+.*)") or ""
            if ( cmd == "mod" ) or ( cmd == "add" ) then
                -- Just bloody fix this inefficiency, please? FIXME: INEFFICIENT
                -- (Possibly, try using catches and %n)
                local nick      = arg:match("^(%S+)") or ""
                nick    = nick:gsub("(%p)", "%%%1")
                local level     = arg:match("^" .. nick .. "%s+(%S+)") or ""
                level   = level:gsub("(%p)", "%%%1")
                local host      = arg:match("^" .. nick .. "%s+" .. level .. "%s+(%S+)") or ""
                host    = host:gsub("([%p])", "%%%1")
                local passhash  = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+(%S+)") or ""
                local email     = arg:match("^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+" .. passhash .. "%s+(%S+)") or ""
                email   = email:gsub("([%p])", "%%%1")
                local passhash  = passgen(passhash)
                local allowed_level
                if db.check_auth(n, u, "admin") then
                    allowed_level = "admin"
                elseif db.check_auth(n, u, "oper") then
                    allowed_level = "user"
                else
                    log("Attempted to add or modify user on " .. bot.nets[n].name, u)
                    c.net[n]:sendChat(u.nick, msg.notauth)
                    return nil
                end
                db.set_data(n, u, cmd, allowed_level, nick, level, host, passhash, email)
            elseif ( cmd == "otk" ) then
                local key = arg:match("(%d+)")
                if key and ( key:len() == 14 ) then
                    db.check_otk(n, u, key)
                end
            elseif ( cmd == "remove" ) or ( cmd == "delete" ) then
                arg = arg:gsub("^%S+%s+", "")
                arg = arg:gsub("^the%s+", "")
                arg = arg:gsub("^user%s+", "")
                local name = arg:match("^(%S+)")
                if not name then
                    c.net[n]:sendChat(u.nick, "I'm sorry, I didn't seem to catch the username. Could you please say that again?")
                    return nil
                end
                db.rem_user(n, u, name)
            elseif ( cmd == "get" ) then
                arg = arg:gsub("user%s+", "")
                arg = arg:gsub("info[rmation]-%s+", "")
                arg = arg:gsub("on%s+", "")
                arg = arg:gsub("about%s+", "")
                local name = arg:match("(%S+)")
                db.show_user(n, u, name)
            elseif ( cmd == "set" ) then
                local mode, value = arg:match("(%S+)%s+(%S+)")
                db.set_user(n, u, mode, value)
            --[[ elseif ( cmd == "update" ) then
                local nick, host = arg:match("(%S+)%s+(%S+)")
                db.upd_user(n, u, u.nick, nick, host) --]]
            elseif ( cmd == "help" ) then
                c.net[n]:sendChat(chan, "Syntax: db (set|update|get|mod|add)")
                c.net[n]:sendChat(chan, "Add and mod are admin-level, and need NICK, LEVEL, HOST, PASSWORD and EMAIL, separated by spaces. EMAIL is voluntary.")
                c.net[n]:sendChat(chan, "Get needs NICK, and shows the registered information for that nick.")
                c.net[n]:sendChat(chan, "Set needs MODE and VALUE. It allows you to set you email and password.")
                c.net[n]:sendChat(chan, "Update needs NICK and HOST, and update your information automatically.")
            else
                c.net[n]:sendChat(chan, "I don't know what you meant I should do with the database. Maybe you need some help?")
            end
        end
    },
    {
        name    = "get off",
        comment = "shut me down.",
        action  = function(n, u, chan, m)
            if db.check_auth(n, u, "admin") then
                if udb:isopen() and ( udb:close() ~= sqlite3.OK ) then
                    db.error(n, u, "Could not close database: " .. udb:errcode() .. " - " .. udb:errmsg())
                end
                c.net[n]:sendChat(chan, msg.bye)
                for i = 1, #c.net do
                    c.net[i]:disconnect(msg.quitting)
                end
                log("")
                log(msg.quitting)
            else
                db.error(n, u, msg.notauth)
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
    action  = function(n, u, chan, m)
        arg = getarg(m)
        if arg then
            found = false
            for i = 1, #bot.cmds do
                if ( bot.cmds[i].name == arg ) then
                    c.net[n]:sendChat(chan, bot.cmds[i].name .. ": " .. bot.cmds[i].comment)
                    found = true
                    break
                end
            end
            if ( found ~= true ) then
                c.net[n]:sendChat(chan, "I don't know that command!")
            end
        else
            c.net[n]:sendChat(chan, name)
            c.net[n]:sendChat(chan, "Commands: " .. bot.cmds.list .. ", help")
        end
    end
})
-- }}}
-- EOF
