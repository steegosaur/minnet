#!/usr/bin/env lua
-- db.lua - info database functions file for minnet
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

require("lsqlite3")

-- idb.check(): Check whether network table exists at startup
function idb.check()
    infodb:exec([[CREATE TABLE IF NOT EXISTS nets (
        netid       INTEGER     PRIMARY KEY,
        netname     TEXT        UNIQUE
        );]])
    infodb:exec([[CREATE TABLE IF NOT EXISTS chans (
        chanid      INTEGER     PRIMARY KEY,
        channame    TEXT,
        netid       INTEGER
        );]])
    infodb:exec([[CREATE TABLE IF NOT EXISTS nicks (
        nickid      INTEGER     PRIMARY KEY,
        nick        TEXT,
        chanid      INTEGER,
        todo        TEXT
        );]])

    -- Check if net exists in the tables; TODO: Tidy this code
    if not idb.get_netid() then
        -- Net does not yet exist; check how many do
        log("Net " .. net.name .. " not found in the IDB; adding..", "info")
        local net_count = db.countrows(infodb, "nets")
        local net_id    = net_count + 1
        -- Add the net and check for success
        if infodb:exec("INSERT INTO nets VALUES (" .. net_id .. ", '" ..
          net.name .. "');") ~= sqlite3.OK then
            err("Could not add current net to the nets list: " ..
                infodb:errcode() .. " - " .. infodb:errmsg())
        else
            log("Added net " .. net.name .. " to nets list in the IDB as " ..
                "net no. " .. net_id, "info")
        end
    else
        log("Net " .. net.name .. " already present in IDB, using existing " ..
            "data..", "debug")
    end
end

-- idb.get_data(): main function for checking stored data
function idb.get_data(u, chan, nick, field, selfcheck)
    if selfcheck then nick = u.nick end
    local chan_id = idb.get_chanid(chan)
    if not chan_id then
        send(chan, "Sorry, I've no info for this channel.")
        return nil
    end
    local nick_id = idb.get_nickid(chan_id, nick)
    if not nick_id then
        if selfcheck then
            send(chan, "Sorry, I don't know you yet. You tell me!")
        else
            send(chan, "Sorry, I don't know that person.")
        end
        return nil
    end

    -- field will be sanitised in idb.get_field(); pass it raw
    local data = idb.get_field(nick_id, field)
    if not data then
        send(chan, "Uh, I don't know. Go ask them yourself! Sheesh.")
    elseif selfcheck then
        send(chan, u.nick .. ": Your " .. field .. " is " .. data .. ".")
        log("Reporting " .. nick .. "'s " .. field .. " on " .. chan,
            u, "debug")
    else
        send(chan, u.nick .. ": " .. nick .. "'s " .. field .. " is " ..
            data .. ".")
        log("Reporting " .. nick .. "'s " .. field .. " on " .. chan,
            u, "debug")
    end
end

-- idb.get_netid(): get the current net's netid (non-dynamic on purpose)
function idb.get_netid()
    for result in infodb:nrows("SELECT * FROM nets WHERE netname = '" ..
      net.name .. "';") do
        return result.netid
    end
    -- If we're here, no result was found; return nil (no netid)
    --+ nb: netid creation is handled in idb.check() at startup; this should
    --+ not be used for anything but idb.check() and defining a global netid
    return nil
end

-- idb.chanid(): get or create chanid for given channel (locked to current net)
function idb.get_chanid(chan)
    local get_stmt = infodb:prepare("SELECT * FROM chans WHERE " ..
        "channame=$chan AND netid=$netid")
    get_stmt:bind_names({ chan = chan, netid = net.id })
    for result in get_stmt:nrows() do
        get_stmt:reset()
        return result.chanid
    end
    -- If we're here, there was no id. Return nil.
    return nil
end

-- idb.get_nickid(): get the nickid of specified nick using unique chanid
function idb.get_nickid(chanid, nick)
    nick = nick:lower()
    for result in infodb:nrows("SELECT * FROM nicks WHERE chanid = " ..
      chanid .. " AND nick = '" .. nick .. "';") do
        return result.nickid
    end
    -- Again, if this executes, there's no nickid.
    return nil
end

-- idb.get_field(): fetch a given piece of stored data from the nicks table
function idb.get_field(nickid, field)
    -- Sanitise the field we're querying for
    field = field:lower()
    field = field:gsub("%p", "")
    field = field:gsub("%s+", "_")
    -- Minor security check; do not give out internal data
    if field == "nickid" or field == "nick" or field == "chanid" then
        return nil
    end
    -- Query the database; this should not create anything
    for result in infodb:nrows("SELECT * FROM nicks where nickid = " .. nickid) do
        return result[field]
    end
    -- If nothing found, return nil
    return nil
end

-- idb.set_data(): main function for saving data to the idb
function idb.set_data(u, chan, nick, field, value)
    local chan_id   -- Make sure it's defined in a broad enough scope
    chan = chan:lower()
    chan_id = idb.get_chanid(chan)
    if not chan_id then
        -- If we're here, there is no chanid for this channel yet; fix that!
        local chan_count = db.countrows(infodb, "chans")
        chan_id = chan_count + 1
        -- Add channel and check for success
        local set_stmt = infodb:prepare("INSERT INTO chans VALUES ( " ..
            "$chan_id, $chan, $net_id )")
        set_stmt:bind_names({ chan_id = chan_id, chan = chan, net_id = net.id})

        if set_stmt:step() ~= sqlite3.DONE then
            db.error(u, "Could not add " .. chan .. " to the chans list: " ..
                infodb:errcode() .. " - " .. infodb:errmsg())
            return nil
        else
            log("Added channel " .. chan .. " to chans list in the IDB as " ..
                "no. " .. chan_id, "info")
        end
    end
    -- So we definitely have a chan_id. Now we need a nick_id
    local nick_id
    nick_id = idb.get_nickid(chan_id, nick)
    if not nick_id then
        -- Seems we're dealing with a new person - better add them
        local nick_count = db.countrows(infodb, "nicks")
        nick_id = nick_count + 1
        -- Add nick and check for success
        if infodb:exec("INSERT INTO nicks (nickid, nick, chanid) VALUES (" ..
          nick_id .. ", '" .. nick:lower() .. "', " ..
          chan_id .. ");") ~= sqlite3.OK then
            db.error(u, "Could not add " .. nick .. " to the nicklist: " ..
                infodb:errcode() .. " - " .. infodb:errmsg())
            return nil
        else
            log("Added nick " .. nick:lower() .. " to nicklist in the IDB " ..
                "as no. " .. nick_id, "info")
        end
    end
    -- Next we need to know if the specified column exists. Sanitise and check.
    field = field:lower()
    field = field:gsub("%p", "")
    field = field:gsub("%s+", "_")
    if db.check_column(infodb, "nicks", field) ~= true then
        -- Column doesn't exist; create and populate
        if infodb:exec("ALTER TABLE nicks ADD COLUMN " .. field ..
          ";") ~= sqlite3.OK then
            db.error(u, "Could not add column " .. field .. " to the IDB: " ..
                infodb:errcode() .. " - " .. infodb:errmsg())
            return nil
        else
            log("Added column " .. field .. " to info database", "info")
        end
    end
    local didWrite = idb.set_field(nick_id, field, value)
    if didWrite == true then
        send(chan, "Whatever floats your boat.")
        log("Set " .. field .. " to '" .. value .. "' in the IDB", u, "debug")
    elseif didWrite == 1 then
        send(chan, u.nick .. ": That's reserved, go set something else.")
    else
        send(chan, "Sorry, I couldn't write that down.. Come again?")
    end
end

-- idb.set_field(): populate a field in the nicks table, IDB
function idb.set_field(nick_id, field, value)
    if field == "nickid" or field == "nick" or field == "chanid" or
      field = "todo" then
        return 1
    end
    local upd_stmt = infodb:prepare("UPDATE nicks SET \"" .. field ..
        "\" = $val WHERE nickid = $nickid;" )
    upd_stmt:bind_names({ val = value, nickid = nick_id })
    if upd_stmt:step() == sqlite3.DONE then
        return true
    else
        return false
    end
end
