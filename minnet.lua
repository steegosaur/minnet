#!/usr/bin/env lua
-- minnet.lua 0.1.0 - personal irc bot written in lua
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- {{{ Init
conf = "husken"
require("irc")
require("socket")
require("ssl")
require(conf)
-- }}}

-- {{{ Run
if ( arg[1] == "--help" ) then
    msg.help()
elseif not ( arg[1] or arg[1] == "--run" ) then
    err(msg.noargs)
end
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
        msg = false
        local n = i
        if ( chan == c.net[n].nick ) then msg = true; chan = u.nick end
        if ( msg == true ) or string.match(m, bot.cmdstring) then wit(n, u, chan, m) end
    end)
end
print("All networks connected. Awaiting commands.")
while true do
    for n = 1, #c.net do
        c.net[n]:think()
        socket.sleep(1)
    end
end
-- }}}
-- EOF
