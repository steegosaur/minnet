#!/usr/bin/env lua
-- minnet.lua 0.7.6 - the unuseful lua irc bot
-- Copyright Stæld Lakorv, 2010-2012 <staeld@illumine.ch>
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
-- Libraries we depend on:
require("irc")      -- Base irc lib
require("socket")   -- Base socket networking lib
require("lsqlite3") -- lsqlite3 for database
require("crypto")   -- openssl for password protection
require("lfs")      -- luafilesystem for easier fs interaction (logs etc)
-- Minnet's modules:
require("minnet.config")
require("minnet.funcs")
require("minnet.db")
require("minnet.idb")
require("minnet.ctcp")
require("minnet.hooks")
require("minnet.logging")
require("minnet.rss")
require("minnet.time")     -- Time functionality
require("minnet.cmdarray") -- The command functions
require("minnet.cmdvocab") -- The command recognition vocabulary

udb = sqlite3.open(db.file)     -- The user auth database
infodb = sqlite3.open(idb.file) -- The user info database
bot.start = os.time()
math.randomseed(os.time())
create_help()
-- }}}

-- {{{ Runtime arg check
-- Non-executing modes first:
if arg[1] == "--licence" then
    local read = {
        list  = { "less", "more", "nano", "emacs",
            "vim", "vi", "pico", "dog", "cat" },
        cmd = nil
    }
    for i, command in ipairs(read.list) do
        local path = io.popen("which " .. command):read()
        if result:match("^/.*" .. command .. "$") then
            read.cmd = path
            break
        end
    end
    if read.cmd then
        os.execute(read.cmd .. " COPYING")
        -- TODO: make this dynamically find the licence
    else
        io.stdout:write("Could not find a program for viewing the licence ",
        "file; please take a look at the GPL v3 yourself. It can be found in ",
        "the file COPYING in Minnet's main directory.\n")
    end
    os.exit()
elseif arg[1] == "--help" then
    msg.help()
end

-- Check args for runmode and eventual level
for i, val in ipairs(arg) do
    if val:match("^%-%-verbos") or ( val == "-v" ) then
        if not arg[i+1] then
            verbosity = levels["debug"] - 1 -- Make it the level above debug
        else
            verbosity = levels[arg[i+1]]
            if not verbosity then
                verbosity = levels["info"]  -- Set nonexisting level to default
                err(msg.noargs)
            end
        end
    elseif val:match("^%-%-net[work]*$") or ( val == "-n" ) then
        local nname = arg[i+1] or nil
        if ( not nname ) or nname:match("%-") then
            err(msg.noargs)
        end
        for j, net in ipairs(bot.nets) do
            if net.name:lower() == nname:lower() then
                netnr = j
                break
            end
        end
        if not netnr then
            err("Unknown network '" .. nname .. "'")
        end
    elseif val:match("^%-%-dry") then
        runmode = "dry"
    end
end
-- }}}

-- {{{ Run
if runmode == "dry" then
    if not ( arg[-1] and arg[-1] == "-i" ) then
        print("Attempting to re-run self in interactive mode..")
        print("If this doesn't work, please run Minnet manually, " ..
            "using `lua -i ./minnet.lua --dry' from within the installation directory.")
        print()
        os.execute("lua -i " .. arg[0] .. " --dry -v debug")
    else
        require("dryrun")
        print("Entering debug mode - dryrun variables for u and conn set.")
    end
else
    -- This is where the bot actually connects
    log("Starting Minnet..", "info")
    if not netnr then -- No network defined by switch; look for a default net
        for i, net in ipairs(bot.nets) do
            if net.default and net.default == true then
                netnr = i
            end
        end
    end
    if not netnr then err("No default net specified in config! " ..
    "Go edit it, foo'!") end
    n   = netnr
    net = bot.nets[n] -- Convenience, since there is only one connected network

    -- Check that the config is more or less complete
    require("minnet.validate")

    -- Check that logdirs exist
    check_create_dir(logdir)
    syslog = logdir .. "/debug_" .. os.date("%F_%H%M%S", bot.start) .. ".log"
    netdir = logdir .. "/" .. net.name
    check_create(syslog)        -- Create system logfile
    check_create_dir(netdir)    -- Create network log dir if not existing
    logs[syslog] = io.open(syslog, "a+")    -- Open syslog for writing

    -- Check that the databases are ok and ready, or do what's necessary to fix
    db.check()
    idb.check()
    db.ucheck()

    net.id = idb.get_netid()    -- Get the net's ID for use w/the info database
    conn = irc.new({            -- Create new irc object
        nick = bot.nick,
        username = bot.uname,
        realname = bot.rname
    })
    log("", "info")

    -- Tables to be initiated during startup:
    net.joined = {}
    howdoTime = {}

    net.port   = net.port or "6667"    -- TODO: check if this is necessary
    net.secure = net.secure or false
    if net.secure then require("ssl") else net.secure = false end
    log("Connecting to " .. net.name .. " server at " .. net.addr, "info")
    conn:connect({ host = net.addr, port = net.port, secure = net.secure})

    -- Add usermodes for self if defined in config
    if net.modes and net.modes ~= "" then
        log("Setting mode +" .. net.modes .. " on self", "info")
        conn:setMode({ target = conn.nick, add = net.modes })
    end

    log("Current nick on " .. net.name .. ": " .. conn.nick, "info")

    -- Call the 'reidentify' command as a special case, with 'startup' as true,
    --+ for identifying with NickServ if configured
    cmdlist.reidentify.func(nil, nil, nil, nil, true)

    for _, channel in ipairs(net.c) do
        log("Joining channel " .. channel .. " on " .. net.name, "info")
        conn:join(channel)
        channel_add(channel)
    end

    -- Register event hooks
    log("Registering hooks..", "debug")
    for _, h in ipairs(hooks) do
        log("Assigning hook " .. h.name .. " for event " .. h.event, "debug")
        conn:hook(h.event, h.name, h.action)
    end
    log("", "info")
    log("Successfully connected to network, awaiting commands.", "info")
    log("", "info")

    rss.init()        -- Ready the rss functionality
    local randCounter = 0
    local rssCounter  = 0
    while true do
        -- Make sure to change seed for math.random now and then
        randCounter = randCounter + 1
        if randCounter > 2400 then
            randCounter = 0
            math.randomseed(os.time())
        end
        if rss and rss.feeds[net.name:lower()] then
            rssCounter = rssCounter + 1
            if rssCounter > 100 then -- Only refresh every n-th cycle (roughly ½s)
                rssCounter = 0
                rss.update_feeds()
            end
        end
        conn:think()        -- The black magic stuff
        socket.sleep(0.5)   -- Take 0.5-second breaks
    end
end
-- }}}
-- EOF
