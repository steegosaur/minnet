#!/usr/bin/env lua
-- commands.lua - config file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- Released under the GPLv3
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
            arg = getarg(m)
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
                ctcp.action(n, chan, "is " .. arg .. smile)
            end
        end
    },
    {
        name    = "join",
        comment = "make me join a channel.",
        action  = function(n, u, chan, m)
            m = getarg(m)
            if isowner(u) then
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Join which channel?")
                else
                    ctcp.action(n, chan, msg.joining .. m)
                    c.net[n]:join(m)
                end
            else
                c.net[n]:sendChat(chan, msg.notowner)
            end
        end
    },
    {
        name    = "part",
        comment = "make me part a channel (just 'part' means leaving current channel).",
        action  = function(n, u, chan, m)
            if isowner(u) then
                arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, msg.bye)
                    c.net[n]:part(chan)
                else
                    c.net[n]:sendChat(chan, "Leaving " .. arg)
                    c.net[n]:part(arg)
                end
            else
                c.net[n]:sendChat(chan, msg.notowner)
            end
        end
    {
        name    = "version",
        comment = "ctcp version someone and hear the result in current channel.",
        action  = function(n, u, chan, m)
            if isowner(u) then
                arg = getarg(m)
                if not arg then
                    c.net[n]:sendChat(chan, u.nick .. ": Version who?")
                else
                    ctcp.version(n, arg)
                    vchan = chan
                end
            else
                c.net[n]:sendChat(chan, msg.notowner)
            end
        end
    },
    {
        name    = "quit",
        comment = "shut me down.",
        action  = function(n, u, chan, m)
            if isowner(u) then
                c.net[n]:sendChat(chan, msg.bye)
                for i = 1, #c.net do
                    c.net[i]:disconnect(msg.quitting)
                end
                print(msg.quitting)
            else
                c.net[n]:sendChat(chan, msg.notowner)
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
