#!/usr/bin/env lua
-- logging.lua - logging functions for Minnet
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

function logwrite(m, u, l, f) -- msg, u, level, output-file
    if not f then
        f = io.stdout
    elseif not logs[f] then
        local filecheck = io.open(f, "r")
        if filecheck then
            -- File exists, open it in nondestructive append mode
            logs[f] = io.open(f, "a+")
        else
            -- File does not exist, create in write mode
            logs[f] = io.open(f, "w")
        end
        filecheck:close()

        if not logs[f] then -- io.open() returns nil on error
            err("Could not open logfile", f)
        else
            log("Opened logfile " .. f, "info")
            f = logs[f]
        end
    else    -- 'f' is a recognised channel name with log
        f = logs[f]
    end
    local mask
    if u then
        mask = u.nick .. "!" .. u.username .. "@" .. u.host .. ": "
    else
        mask = ""
    end
    l = l:upper()
    local fmtstr = "%s : %s %s%s\n"
    if ( io.type(f) ~= "file" ) then
        return nil
    end
    f:write(fmtstr:format(os.date("%F/%T"), l, mask, m))
    f:flush()
end

function log(m, u, l) -- Log function, takes message, user table and loglevel
    if not m then
        err("No error message provided in call to log()")
    end
    if not l then     -- Because I'm too lazy to switch l and u in all calls
        if ( type(u) == "string" ) then
            l, u = u, nil
        end
    end
    if not l then
        err("No info level defined for parent function; FIXME")
    end

    -- Log to syslog before filtering for verbosity
    if logs[syslog] then
        logwrite(m, u, l, syslog)
    end

    if ( levels[l] > verbosity ) then -- Lower value == higher prio
        return nil      -- We don't want this level; shut up
    end

    -- Log to stdout
    logwrite(m, u, l)
end

function err(m, file)
    if file then file = " " .. file else file = "" end
    log(m .. file, "error")
    error(m)
    os.exit(1)
end

function logchan(mode, u, chan, m, bullet)
    if ( type(u) == "string" ) then
        local nick = u
        u = { nick = nick }
    end
    local logfile
    chan = chan:lower()
    if not logs[chan] then
        logs[chan] = io.open(logdir .. "/" .. net.name .. "/" .. chan .. ".log", "w")
        if not logs[chan] then
            err("Could not open logfile " .. netdir .. "/" .. chan .. ".log")
        else
            log("Opened logfile " .. chan .. ".log", "info")
            logfile = logs[chan]
        end
    else
        logfile = logs[chan]
    end
    if ( io.type(logfile) ~= "file" ) then
        return nil
    end

    local entry, fmtstr
    if ( mode == "chat" ) then
        fmtstr = "%s: %s: %s\n"
        entry  = fmtstr:format(os.date("%F/%T"), u.nick, m)
    elseif ( mode == "note" ) then
        bullet = bullet or "*"
        fmtstr = "%s: %s %s %s\n"
        entry  = fmtstr:format(os.date("%F/%T"), bullet, u.nick, m)
    else
        log("Erroneous chatlog() mode; FIXME", "error")
    end
    logfile:write(entry, "\n")
    logfile:flush()
    logfile = nil
end

function lognote(u, chan, m, bullet)
    logchan("note", u, chan, m, bullet)
    log(m, u, "trivial")
end
function logchat(u, chan, m)
    logchan("chat", u, chan, m)
end
