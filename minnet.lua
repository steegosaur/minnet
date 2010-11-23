#!/usr/bin/env lua
-- minnet.lua 0.0.2 - personal irc bot written in lua
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- {{{ Init
require("irc")
require("socket")
require("ssl")
bot = {
    nick  = "Minnet",
    uname = "Minnet",
    rname = "Minnet",
    nets  = {
        --{ name = "furnet", addr = "eu.irc.furnet.org", c = { "#geekfurs", } },
        { name = "scoutlink", addr = "irc.scoutlink.org", c = { "#test", } },
    },
}
c   = { net = {} } -- Connection list
msg = {
    noargs = "invalid arguments specified. See --help",
    noconf = "could not find config file",
    
}
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
function err(msg, f)
    if f then f = " " .. f else f = "" end
    print("error: " .. msg .. f)
    os.exit(1)
end
if ( arg[1] == "--help" ) then
    msg.help()
elseif not ( arg[1] or arg[1] == "--run" ) then
    err(msg.noargs)
end
-- }}}

-- {{{ Run
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
