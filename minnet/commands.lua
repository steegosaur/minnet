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
                arg = string.gsub(arg, "%%", "%%%%")
                ctcp.action(n, chan, "is " .. arg .. smile)
            end
        end
    },
    {
        name    = "join",
        comment = "make me join a channel.",
        action  = function(n, u, chan, m)
            local pwnd = isowner(n, u, chan)
            if pwnd then
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
            end
        end
    },
    {
        name    = "part",
        comment = "make me part a channel (just 'part' uses current channel).",
        action  = function(n, u, chan, m)
            local pwnd = isowner(n, u, chan)
            if pwnd then
                local arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, msg.bye)
                    c.net[n]:part(chan)
                else
                    c.net[n]:sendChat(chan, "Leaving " .. arg)
                    c.net[n]:part(arg)
                end
            end
        end
    },
    {
        name    = "say",
        comment = "make me say something. [say [#channame] msg]",
        action  = function(n, u, chan, m)
            local pwnd = isowner(n, u, chan)
            if pwnd then
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
            end
        end
    },
    {
        name    = "version",
        comment = "ctcp version someone and hear the result in current channel.",
        action  = function(n, u, chan, m)
            local pwnd = isowner(n, u, chan)
            if pwnd then
                local arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Version who?")
                else
                    ctcp.version(n, arg)
                    vchan = chan
                end
            end
        end
    },
    {
        name    = "quit",
        comment = "shut me down.",
        action  = function(n, u, chan, m)
            local pwnd = isowner(n, u, chan)
            if pwnd then
                c.net[n]:sendChat(chan, msg.bye)
                for i = 1, #c.net do
                    c.net[i]:disconnect(msg.quitting)
                end
                print(msg.quitting)
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
