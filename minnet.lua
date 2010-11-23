#!/usr/bin/env lua
-- minnet.lua 0.0.1 - personal irc bot written in lua
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
        --{ name = "furnet", addr = "eu.irc.furnet.org" },
        { name = "scoutlink", addr = "irc.scoutlink.org", c = { "#test", } },
    },
}
c   = { net = {} } -- c == Connection list
msg = {
    noargs  = "invalid arguments specified, exiting..",
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
function err(msg)
    print(msg)
    os.exit(1)
end
if not arg[1] then
    err(msg.noargs)
elseif ( arg[1] == "--help" ) then
    msg.help()
end

-- }}}

-- {{{ Run
-- Create c.net list containing connections
for i = 1, #bot.nets do
    c.net[i] = irc.new{ nick = bot.nick, username = bot.uname, realname = bot.rname }
    c.net[i]:connect(bot.nets[i].addr)
    for j = 1, #bot.nets[i].c do
        c.net[i]:join(bot.nets[i].c[j])
    end
end

while true do
    for i = 1, #c.net do
        c.net[i]:think()
        socket.sleep(1)
    end
end
-- }}}
-- EOF
