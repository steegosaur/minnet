#!/usr/bin/env lua
-- commands.lua - config file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet.  
-- Minnet is released under the GPLv3 - see ../COPYING 
bot.cmds  = { -- Commands that the bot understands; nothing should need editing below this line
    {
        name    = "test",
        comment = "dummy command",
        rep     = "Go test yourself! Sheesh."
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
                local arg1 = string.match(arg, "^%s-(#%S+)%s+%S+")
                if arg1 then chan = arg1; arg = string.match(arg, "^%s-%S+%s+(.*)$") end
                ctcp.action(n, chan, "is " .. arg .. smile)
            end
        end
    },
    {
        name    = "join",
        comment = "make me join a channel.",
        action  = function(n, u, chan, m)
            --local pwnd = isowner(n, u, chan)
            --if pwnd then
            if db.check_auth(n, u, "admin") then
                local arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Join which channel?")
                else
                    local t = string.match(arg, "^(%S+)")
                    local k = string.match(arg, "^" .. t .. "%s+(%S+)")
                    ctcp.action(n, chan, msg.joining .. t)
                    if k then
                        c.net[n]:join(t, k)
                    else
                        c.net[n]:join(t)
                    end
                end
            else
                db.error(n, u, wsg.notauth)
            end
        end
    },
    {
        name    = "part",
        comment = "make me part a channel.",
        action  = function(n, u, chan, m)
            --local pwnd = isowner(n, u, chan)
            --if pwnd then
            if db.check_auth(n, u, "admin") then
                local arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, msg.bye)
                    c.net[n]:part(chan)
                else
                    c.net[n]:sendChat(chan, "Leaving " .. arg)
                    c.net[n]:part(arg)
                end
            else
                db.error(n, u, wsg.notauth)
            end
        end
    },
    {
        name    = "say",
        comment = "make me say something.",
        action  = function(n, u, chan, m)
            --local pwnd = isowner(n, u, chan)
            --if pwnd then
            if db.check_auth(n, u, "oper") then
                local arg = getarg(m)
                if not arg then
                    cpnet[n]:sendChat(chan. u.nick .. ": Say what?")
                else
                    local say = ""
                    local t = string.match(arg, "^%s-(#%S+)%s+%S+")
                    if t then
                        say = string.match(arg, "^%s-" .. t .. "%s+(%S+.*)$")
                    else
                        t = chan
                        say = string.match(arg, "^(.*)$")
                    end
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
            --local pwnd = isowner(n, u, chan)
            --if pwnd then
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
        name    = "db",
        comment = "database management. ('db help' for more info)",
        action  = function(n, u, chan, m)
--            local pwnd = isowner(n, u, chan)
--            if pwnd then
                if string.match(chan, "^#") then
                    c.net[n]:sendChat(chan, "I can't let you do database operations in a channel, sorry.")
                    return nil
                end
                local arg = getarg(m) or ""
                local cmd = string.match(arg, "^%s-(%S+)") or ""
                local arg = string.match(arg, "^" .. cmd .. "%s-(%S+.*)") or ""
                if ( cmd == "mod" ) or ( cmd == "add" ) then
                    -- Just bloody fix this inefficiency, please? FIXME: INEFFICIENT
                    -- (Possibly, try using catches and %n
                    local nick      = string.match(arg, "^(%S+)") or ""
                    local level     = string.match(arg, "^" .. nick .. "%s+(%S+)") or ""
                    local host      = string.match(arg, "^" .. nick .. "%s+" .. level .. "%s+(%S+)") or ""
                    local passhash  = string.match(arg, "^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+(%S+)") or ""
                    local email     = string.match(arg, "^" .. nick .. "%s+" .. level .. "%s+" .. host .. "%s+" .. passhash .. "%s+(%S+)") or ""
                    local passhash  = passgen(passhash)
                    db.set_data(n, u, cmd, nick, level, host, passhash, email)
                elseif ( cmd == "get" ) then
                    local name = string.match(arg, "(%S+)")
                    db.show_user(n, u, name)
                elseif ( cmd == "set" ) then
                    local mode, value = string.match(arg, "(%S+)%s+(%S+)")
                    db.set_user(n, u, mode, value)
                elseif ( cmd == "update" ) then
                    local nick, host = string.match(arg, "(%S+)%s+(%S+)")
                    db.upd_user(n, u, u.nick, nick, host)
                elseif ( cmd == "help" ) then
                    c.net[n]:sendChat(chan, "Syntax: db (set|update|get|mod|add)")
                    c.net[n]:sendChat(chan, "Add and mod are admin-level, and need NICK, LEVEL, HOST, PASSWORD and EMAIL, separated by spaces.")
                    c.net[n]:sendChat(chan, "Get needs NICK, and shows the registered information for that nick.")
                    c.net[n]:sendChat(chan, "Set needs MODE and VALUE. It allows you to set you email and password.")
                    c.net[n]:sendChat(chan, "Update needs NICK and HOST, and update your information automatically.")
                else
                    c.net[n]:sendChat(chan, "I don't know what you meant I should do with the database. Maybe you need some help?")
                end
            end
--        end
    },
    {
        name    = "quit",
        comment = "shut me down.",
        action  = function(n, u, chan, m)
            --local pwnd = isowner(n, u, chan)
            --if pwnd then
            if db.check_auth(n, u, "admin") then
                if udb:isopen() and ( udb:close() ~= sqlite3.OK ) then
                    db.error(n, u, "Could not close database: " .. udb:errcode() .. " - " .. udb:errmsg())
                end
                c.net[n]:sendChat(chan, msg.bye)
                for i = 1, #c.net do
                    c.net[i]:disconnect(msg.quitting)
                end
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
