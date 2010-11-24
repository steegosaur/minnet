#!/usr/bin/env lua
-- Functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- Released under the GPLv3+
function err(msg, f)
    if f then f = " " .. f else f = "" end
    print("error: " .. msg .. f)
    os.exit(1)
end
function getarg(m)
    local arg = string.match(m, "%s+(%S+.*)")
    return arg
end
function wit(n, u, chan, m) -- Hook function for reacting to normal commands
    if string.match(m, bot.cmdstring) then
        m = string.gsub(m, bot.cmdstring, "")
    end
    if ( m == "" ) or string.match(m, "^%s+") then return nil end
    cmdFound = false
    for i = 1, #bot.cmds do
        if string.match(m, "^" .. bot.cmds[i].name) then -- Improve this for argument support!
            print(os.date("%F/%T: ") .. "Received command " .. m .. " from " .. u.nick .. "!" .. u.username .. "@" .. u.host .. " on " .. bot.nets[n].name .. "/" .. chan)
            if bot.cmds[i].rep      then c.net[n]:sendChat(chan, bot.cmds[i].rep) end
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

