#!/usr/bin/lua
-- rss.lua - rss-related functions for minnet
-- Copyright Stæld Lakorv, 2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- RSS/Atom feeds configuration
rss = {
    maxnew = 6,     -- Max number of new entries to report per feed, per update
    feeds = {       -- Network names _must_ be lowercase
        illumine = {
            {
            name = "World-wiki",
            url  = "http://staeld.illumine.ch/wiki/index.php?title=Spesial:Siste_endringar&feed=atom",
            out  = "%s",
            patt = "^<p>(.-)</p>",
            chan = { "#valo" },
            freq = "30m",
            maxnew = 4, -- Same as above, but feed-specific
            },
            {
            name = "Minnet-git",
            url  = "https://github.com/staeld/minnet/commits/serv-dev.atom",
            out  = "",
            patt = "",
            chan = { "#valo" },
            freq = "60m",
            maxnew = 3,
            },
        },
    },
    fetch_cmd = "wget -q -O %s '%s'",
}

-- End configuration, begin functions libary

fp = require("feedparser")
-- Check for the needed fetching helper
do
    local fetch_helper = fetch_cmd:match("^(%S+)")
    if io.popen("which " .. fetch_helper):read("*a") == "" then
        log(fetch_helper .. " not found", "error")
    end
end

function rss.init() -- Called during bot init, because we need the net.name
    for _, f in ipairs(rss.feeds[net.name:lower()]) do
        f.updated = 0
    end
    rss.dir = logdir .."/".. net.name .."/.rss"
    check_create_dir(rss.dir)
    rss.read_times()
end

-- Main functions

function rss.fetch_feed(url, name)
    if not rss.dir then -- Because rss.init() only defines it on startup
        rss.dir = logdir .."/".. net.name .."/.rss"
    end
    local oldname = rss.dir .."/" .. name
    local newname = oldname .. ".new"

    if type(url) ~= "string" or not ( url:match(".+%.%a%a%a?/.+")
      or url:match("%d+%.%d+%.%d+%.%d+/.+") ) then
        return nil
    end
    local exec = rss.fetch_cmd:format(newname, url)
    log("Calling " .. exec, "debug")
    os.execute(exec)
    if io.open(oldname, "r")
      and io.open(newname):read("*a") == io.open(oldname):read("*a") then
        os.remove(newname)
    elseif io.open(oldname, "r") then
        os.remove(oldname)
        os.rename(newname, oldname)
    else
        os.rename(newname, oldname)
    end
end

function rss.update_feeds()
    for i, f in ipairs(rss.feeds[net.name:lower()]) do
        local length = f.freq:match("%d+")
        local unit = f.freq:match("%l+")
        if unit == "h" then
            length = length * 3600
        elseif unit == "m" then
            length = length * 60
        end
        if ( not f.updated or os.difftime(os.time(), f.updated) >= length )
          or not rss.has_feed(f.name) then
            -- Either hasn't been updated, or was updated and should be again
            log("Fetching feed " .. f.name, "debug")
            rss.fetch_feed(f.url, f.name)
            f.updated = os.time()           -- Update the timestamp
            rss.save_times()
            rss.read_new(f.name)            -- Check for new entries and report
        else
            log("Feed " .. f.name .. " not ripe; skipping..", "debug")
        end
    end
end

function rss.read_new(name)
    local path = rss.dir .. "/".. name
    local file = io.open(path, "r")
    if not file then return false end
    local f = rss.get_feed(name)
    local xml = file:read("*a")
    local parsed = fp.parse(xml)
    if parsed.feed.updated_parsed < ( f.updated - rss.get_freq(f) ) then
        -- Not updated since last refresh -> nothing new
        log("Nothing new to report from feed " .. name, "trivial")
        return
    end
    local newCount = 0
    for i, e in pairs(parsed.entries) do
        if e.updated_parsed > ( f.updated - rss.get_freq(f) ) then
            -- Entry was published after last check; report
            newCount = newCount + 1
            if (f.maxnew and newCount > f.maxnew) or newCount > rss.maxnew then
                log("Too many new entries for feed ".. f.name ..", cutting off", "warn")
                for _, chan in ipairs(f.chan) do
                    send(chan, "Too many new entries for ".. f.name ..", skipping the rest.")
                end
                break
            end
            log("Entry " ..i.. " of feed " ..name.. " new; reporting", "trivial")
            local printout = "%s: %s - %s: %s (%s)"
            local message
            -- Make sure there is a summary/content tag, and use it
            if e.summary then
                message = f.out:format(e.summary:match(f.patt))
            elseif e.content then
                message = f.out:format(e.content:match(f.patt))
            end
            message = message or ""    -- Fallback in case something went bork
            message = rss.strip_html(message)
            for _, chan in ipairs(f.chan) do
                send(chan, printout:format(f.name, e.author, e.title, message, e.link))
            end
        end
    end
end

-- Auxiliary functions

function rss.has_feed(nom)
    if io.open(rss.dir .."/".. nom, "r") then
        return true
    else
        return false
    end
end
function rss.get_feed(name) -- Takes feed name, returns feed's table
    for i, f in ipairs(rss.feeds[net.name:lower()]) do
        if f.name == name then return f end
    end
    log("No feed with name ".. name .."; providing substitute", "warn")
    return rss.feeds[net.name:lower()][1] -- Return first feed as fallback
end
function rss.get_freq(f) -- Takes feed name or table, returns freq in seconds
    if type(f) == "string" then f = rss.get_feed(f) end
    local length = f.freq:match("%d+") or 1     -- Fallback to evade math error
    local unit = f.freq:match("%d(%a)")         -- Just care for the 1st letter
    if unit == "w" then
        length = length * 3600 * 24 * 7
    elseif unit == "d" then
        length = length * 3600 * 24
    elseif unit == "h" then
        length = length * 3600
    elseif unit == "m" then
        length = length * 60
    end
    return length   -- In seconds
end

function rss.read_times()
    local file = io.open(rss.dir .."/.times", "r")
    if not file then
        log("No update times for rss feeds saved, skipping..", "debug")
        return
    end
    log("Restoring rss feed update times..", "trivial")
    for line in file:lines() do
        local name, time = line:match("^(%S+)%s+:%s+(%d+)")
        time = tonumber(time)
        log("Feed name: " .. name .. "; time: " .. time, "internal")
        for _, f in ipairs(rss.feeds[net.name:lower()]) do
            if f.name == name then
                f.updated = time
                break
            end
        end
    end
end
function rss.save_times()
    log("Saving rss feed update times..", "debug")
    local file = io.open(rss.dir .."/.times", "w+")
    if not file then
        log("Error saving rss update times! Skipping..", "warn")
        return
    end
    for _, f in ipairs(rss.feeds[net.name:lower()]) do
        if f.updated and f.updated > 0 then
            file:write(f.name, " : ", f.updated, "\n")
        end
    end
    file:close()
    log("Feed update times saved", "debug")
end

function rss.strip_html(s)
    if not type(s) == "string" then return nil end
    -- Presuming we are dealing with plain, unescaped html
    return s:gsub("%b<>", "")
end
