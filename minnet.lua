#!/usr/bin/env lua
-- minnet.lua 0.4.0 - the unuseful lua irc bot
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
--
-- This file is part of Minnet
--
-- Minnet is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Minnet is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Minnet. If not, see <http://www.gnu.org/licenses/>.

-- {{{ Init
require("irc")
require("socket")
require("lsqlite3")
require("crypto")
require("minnet.config")
require("minnet.funcs")
require("minnet.ctcp")
require("minnet.commands")
require("minnet.db")
require("minnet.hooks")
udb = sqlite3.open(db.file)
bot.start = os.time()
-- }}}

-- {{{ Runtime arg check
-- Non-executing modes first:
if ( arg[1] == "--help" ) then
    msg.help()
elseif ( arg[1] == "--licence" ) then
    local read = {
        list  = { "/bin/less", "/bin/more", "/usr/bin/nano", "/usr/bin/emacs",
            "/usr/bin/vim", "/usr/bin/vi", "/bin/cat" },
        cmd = nil
    }
    for i = 1, #read.list do
        if io.open(read.list[i], "r") then
            read.cmd = read.list[i]
            break
        end
    end
    if read.cmd then
        os.execute(read.cmd .. " COPYING")
    else
        io.stdout:write("Could not find a program for viewing the licence ")
        io.stdout:write("file; please take a look at the GPL v3 yourself. It ")
        io.stdout:write("can be found in the file COPYING in the Minnet main directory.\n")
    end
    os.exit()
elseif not arg[1] then
    err(msg.noargs)
end

-- Check args for runmode and eventual level
for i = 1, #arg do
    if arg[i]:match("^%-%-verbos") or arg[i]:match("^%-v$") then
        if not arg[i+1] then
            verbosity = levels["debug"] - 1     -- Make it whatever level is above debug
        else
            verbosity = levels[arg[i+1]]
            if not verbosity then
                verbosity = levels["info"]      -- Repair nonexisting level to default
                err(msg.noargs)
            end
        end
    elseif ( arg[i] == "--dry" ) then
        runmode = "dry"
    elseif ( arg[i] == "--run" ) then
        runmode = "run"
    end
end

-- Runmode evaluation
if ( runmode == "dry" ) then
    local verbosity = verbosity or levels["debug"]
    run = false
    if not ( arg[-1] == "-i" ) then
        print("Attempting to re-run self in interactive mode..")
        print("If this doesn't work, run lua manually, specifying -i for interactive execution.")
        print()
        os.execute("lua -i " .. arg[0] .. " --dry -v debug")
    else
        require("dryrun")
        print("Entering debug mode - dryrun variables for u and c.net set.")
    end
elseif ( runmode ~= "run" ) then
    err(msg.noargs)
end
-- }}}

-- {{{ Run
if ( runmode == "run" ) then
log("Starting Minnet..", "info")
for n = 1, #bot.nets do
    db.check(n)     -- Check that the net's table exists
    log("Adding net " .. bot.nets[n].name, "info")
    c.net[n] = irc.new({ nick = bot.nick, username = bot.uname, realname = bot.rname })
    db.ucheck(n)    -- Check that the net's table is not empty

    log("Connecting to " .. bot.nets[n].name .. " server at " .. bot.nets[n].addr, "info")
    c.net[n]:connect(bot.nets[n].addr)

    -- Add usermodes for self if defined in config
    if bot.nets[n].modes and ( bot.nets[n].modes ~= "" ) then
        log("Setting mode +" .. bot.nets[n].modes, "info")
        c.net[n]:setMode({ target = bot.nick, add = bot.nets[n].modes })
    end

    log("Current nick on " .. bot.nets[n].name .. ": " .. c.net[n].nick, "info")

    for j = 1, #bot.nets[n].c do
        log("Joining channel " .. bot.nets[n].c[j] .. " on " .. bot.nets[n].name, "info")
        c.net[n]:join(bot.nets[n].c[j])
        channel_add(i, bot.nets[n].c[j])
    end

    -- Register event hooks
    --[[
    c.net[n]:hook("OnChat", "happy", function(u, chan, m) -- Just for the lulz
        if ( chan == c.net[n].nick ) then chan = u.nick end
        if m:match("^[Bb]e%s+happy%p?%s-[Dd]on%'?t%s+worry") or m:match("^[Dd]on%'?t%s+worry%p?%s-[Bb]e%s+happy") then
            ctcp.action(n, chan, "doesn't worry, is happy! :D")
        end
    end)
    c.net[n]:hook("OnChat", "wit", function(u, chan, m)
        local ismsg = false
        if ( chan == c.net[n].nick ) then ismsg = true; chan = u.nick end
        if ( ismsg == true ) or m:match("^" .. c.net[n].nick .. "[,:]-%s+") then
            wit(n, u, chan, m)
        end
    end)
    c.net[n]:hook("OnRaw", "ctcpRead", function(l) ctcp.read(n, l) end)
    --]]
    
    log("Registering hooks..", "info")
    for i, j in ipairs(hooks) do
        log("Assigning hook " .. j.name .. " for event " .. j.event, "debug")
        c.net[n]:hook(j.event, j.name, j.action)
    end
    log("", "info") -- Separate nets with an empty log line
end
log("All networks connected. Awaiting commands.", "info")
log("", "info")

while true do
    for i = 1, #c.net do
        n = i
        c.net[n]:think()    -- The black magic stuff
        socket.sleep(1)
    end
end
end
-- }}}
-- EOF
