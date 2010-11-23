#!/usr/bin/env lua
-- minnet.lua 0.0.5 - personal irc bot written in lua
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- {{{ Init
require("irc")
require("socket")
require("ssl")

c   = { net = {} } -- Connection list
bot = {
    nick  = "Minnet",
    uname = "Minnet",
    rname = "Minnet",
    cmdstring = "^%%",
    nets  = {
        --{ name = "furnet", addr = "eu.irc.furnet.org", c = { "#geekfurs", } },
        { name = "scoutlink", addr = "irc.scoutlink.org", c = { "#test", } },
    },
    cmds  = {
        {
            name    = "test",
            comment = "dummy command",
            rep     = "Go test yourself! Sheesh."
        },
        {
            name    = "help",
            comment = "help message with cmd list",
            rep     = "Lorem ipsum dolor sit helpet."
        },
        {
            name    = "quit",
            comment = "shut down bot", -- Careful with this function!
            rep     = "Bye.",
            action  = function(n)
                c.net[n]:disconnect("Minnet quitting..")
            end
        }
    }
}
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
function wit(n, u, chan, m)
    if string.match(m, bot.cmdstring) then
        m = string.gsub(m, bot.cmdstring, "")
    end
    for i = 1, #bot.cmds do
        if m == bot.cmds[i].name then -- Improve this for argument support!
            print("Received command " .. m .. " from " .. u.nick .. "!" .. u.username .. "@" .. u.host .. " on " .. bot.nets[n].name .. "/" .. chan)
            if bot.cmds[i].rep      then c.net[n]:sendChat(chan, bot.cmds[i].rep); print(os.date("%F/%T:") .. m) end
            if bot.cmds[i].action   then bot.cmds[i].action(n, u, chan, m) end
        end
    end
end
-- Create msg.help() function in local scope
do
    local name = ""
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
end
-- }}}

-- {{{ Run
if ( arg[1] == "--help" ) then
    msg.help()
elseif not ( arg[1] or arg[1] == "--run" ) then
    err(msg.noargs)
end
-- Not exited yet because of args, so we assume green light:
-- Create c.net list containing connections
print("Starting minnet..")
for i = 1, #bot.nets do
    print("Adding irc-net " .. bot.nets[i].name)
    c.net[i] = irc.new{ nick = bot.nick, username = bot.uname, realname = bot.rname }
    print("Connecting to " .. bot.nets[i].name .. " server at " .. bot.nets[i].addr)
    c.net[i]:connect(bot.nets[i].addr)
    for j = 1, #bot.nets[i].c do
        print("Joining channel " .. bot.nets[i].c[j] .. " on " .. bot.nets[i].name)
        c.net[i]:join(bot.nets[i].c[j])
    end
    -- Register hooks
    c.net[i]:hook("OnChat", function(u, chan, m)
        local net = i
        if ( chan == c.net[net].nick ) then msg = true; chan = u.nick end
        if ( msg == true ) or string.match(m, bot.cmdstring ) then wit(net, u, chan, m) end end)
end
print("All networks connected. Awaiting commands.")
while true do
    for i = 1, #c.net do
        c.net[i]:think()
        socket.sleep(1)
    end
end
-- }}}
-- EOF
