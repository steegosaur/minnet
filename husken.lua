#!/usr/bin/env lua
-- husken.lua - config file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
c   = { net = {} } -- Connection list
owner = {
    uname1 = "a6af798b68",
    uname2 = "~Staeld",
    host = "%.id%.au$"
}
bot = {
    nick  = "Minnet",
    uname = "Minnet",
    rname = "Minnet",
    cmdstring = "^%%",
    nets  = {
        { name = "furnet", addr = "eu.irc.furnet.org", c = { "#dilldall" } },
--        { name = "scoutlink", addr = "irc.scoutlink.org", c = { "#test" } }
    },
    cmds  = {
        {
            name    = "test",
            comment = "dummy command",
            rep     = "Go test yourself! Sheesh."
        },
        {
            name    = "quit",
            comment = "shut down bot",
            rep     = "Bye.",
            action  = function(n, u, chan, m)
                if ( u.username == owner.uname1 ) or ( u.username == owner.uname2 ) and string.match(u.host, owner.host) then
                    for i = 1, #c.net do
                        c.net[i]:disconnect("Minnet quitting..")
                    end
                else
                    c.net[n]:sendChat(chan, "Hey, wait a minute! I'm not taking commands from you.")
                end
            end
        }
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
    --rep     = "Lorem ipsum dolor sit helpet.",
    action  = function(n, u, chan, m)
        cmd = string.match(m, "^help")
        arg = string.match(m, "%s+(%S+)")
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
msg = {
    noargs = "invalid arguments specified. See --help",
    noconf = "could not find config file",
}

-- Functions
function err(msg, f)
    if f then f = " " .. f else f = "" end
    print("error: " .. msg .. f)
    os.exit(1)
end
function wit(n, u, chan, m) -- Hook function for reacting to normal commands
    if string.match(m, bot.cmdstring) then
        m = string.gsub(m, bot.cmdstring, "")
    end
    if ( m == "" ) or string.match(m, "^%s+") then return nil end
    cmdFound = false
    for i = 1, #bot.cmds do
        if string.match(m, "^" .. bot.cmds[i].name) then -- Improve this for argument support!
            print("Received command " .. m .. " from " .. u.nick .. "!" .. u.username .. "@" .. u.host .. " on " .. bot.nets[n].name .. "/" .. chan)
            if bot.cmds[i].rep      then c.net[n]:sendChat(chan, bot.cmds[i].rep); print(os.date("%F/%T:") .. m) end
            if bot.cmds[i].action   then bot.cmds[i].action(n, u, chan, m) end
            cmdFound = true
        end
    end
    if ( cmdFound == false ) then
        c.net[n]:sendChat(chan, "Nevermore!")
    end
end
-- Create msg.help() function
name = ""
io.input(arg[0])
while not string.match(name, "^%-%-%s-(minnet%.lua.*)$") or not io.read() do
    name = io.read()
end
name = string.gsub(name, "^%W*", "")
msg.help = function()
    print(name)
    print("Usage: " .. arg[0] .. " [--help]")
    os.exit()
end
-- }}}
-- EOF
