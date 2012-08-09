#!/usr/bin/env lua
-- db.lua - info database functions file for minnet
-- Copyright Stæld Lakorv, 2011-2012 <staeld@illumine.ch>
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
        );]])
    infodb:exec([[CREATE TABLE IF NOT EXISTS todo (
        id          INTEGER     PRIMARY KEY,
        nick        TEXT,
        net         INTEGER,
        entry       TEXT,
        entry_id    INTEGER
        );]])
    infodb:exec([[CREATE TABLE IF NOT EXISTS karma (
        id          INTEGER     PRIMARY KEY,
        item        TEXT,
        chan        INTEGER,
        karma       INTEGER
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
        "channame = $chan AND netid = $netid")
    get_stmt:bind_names({ chan = chan, netid = net.id })
    for result in get_stmt:nrows() do
        get_stmt:reset()
        return result.chanid
    end
    -- If we're here, there was no id. Make one and return it.
    return idb.new_chanid(chan)
end

-- idb.new_chanid(): create a new chanid
function idb.new_chanid(chan, u)
    local set_stmt = infodb:prepare("INSERT INTO chans (channame, netid) VALUES ($c, $ni)")
    set_stmt:bind_names({ c = chan, ni = net.id })
    if set_stmt:step() ~= sqlite3.DONE then
        local errmsg = "Could not add " .. chan .. " to the chans list: " ..
            infodb:errcode() .."-".. infodb:errmsg()
        if u then db.error(u, errmsg) else log(errmsg, "error") end
    else
        log("Added channel ".. chan .." to chans list in IDB", "info")
        return idb.get_chanid(chan)
    end
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
    return nil -- If nothing found, return nil
end

-- idb.set_data(): main function for saving data to the idb
function idb.set_data(u, chan, nick, field, value)
    local chan_id   -- Make sure it's defined in a broad enough scope
    chan = chan:lower()
    chan_id = idb.get_chanid(chan)
    --[[ Obsolete
    if not chan_id then
        -- If we're here, there is no chanid for this channel yet; fix that!
        chan_id = idb.new_chanid(chan, u)
    end --]]
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
      field == "todo" then
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

-- Todo list functionality

-- idb.set_todo(): save an item to the todo list
function idb.set_todo(u, chan, note)
    -- Fetch the registered nick for the user
    local nick = db.get_user(u.nick).nick
    -- Find out how many notes the user has, and increment by one for new id
    local id_query = infodb:prepare("SELECT * FROM todo " ..
        "WHERE nick = $nick AND net = $net")
    id_query:bind_names({ nick = nick, net = netid }) -- Use current netid
    local id = id_query:numrows() -- This needs to be fixed, not correct
    id = id + 1

    -- Prepare the insertion of the new note
    local query = infodb:prepare("INSERT INTO todo " ..
        "(nick, net, entry_id, entry) VALUES ($nick, $net, $id, $entry)")
    query:bind_names({ nick = nick, net = netid, id = id, entry = note })
    if query:step() ~= sqlite3.DONE then
        db.error(u, "Could not add item to todo list: " ..
            infodb:errcode() .. " - " .. infodb:errmsg())
    else
        send(chan, u.nick .. ": Well, since *you* obviously can't remember..")
        log("Added entry " .. id .. " to todo list", u, "trivial")
    end
    query:reset()
end
-- idb.get_todo(): retrieve item from todo list
function idb.get_todo(u, chan, id)
    -- Fetch the registered nick for the user
    local nick = db.get_user(u.nick).nick
    local get_stmt = infodb:prepare("SELECT entry FROM todo WHERE " ..
        "nick = $nick AND net = $net AND entry_id = $id LIMIT 1")
    get_stmt:bind_names({ nick = nick, net = netid, id = id })
    -- FIXME: This weird way of handling stuff really should be unnecessary
    for result in get_stmt:nrows() do
        if result and result.entry then
            -- TODO: Check if the entry is actually located in 'result.entry'
            log("Was asked for todo entry " .. id, u, "debug")
            local sendstring = '%s: Entry no. %d: "%s"'
            send(chan, sendstring:format(u.nick, id, result.entry))
        end
    end
    get_stmt:reset()
    -- If we're here, something went wrong, or nothing was found
    log("Received query for nonexisting todo entry", u, "trivial")
    send(chan, u.nick .. ": How about you actually make a todo list that's " ..
        "that long, before you ask me to read from it?")
    return nil
end
-- idb.del_todo(): delete item from todo list
function idb.del_todo(u, chan, id)
    -- Fetch the registered nick for the user
    local nick = db.get_user(u.nick).nick
    local del_stmt = infodb:prepare("DELETE FROM todo WHERE " ..
        "nick = $nick AND net = $net AND entry_id = $id")
    del_stmt:bind_names({ nick = nick, net = netid, id = id })
    if del_stmt:step() ~= sqlite3.DONE then
        db.error(u, "Couldn't delete that todo entry: " .. infodb:errcode() ..
            " - " .. infodb:errmsg())
    else
        log("Deleted todo entry " .. id, u, "trivial")
        send(chan, "By time you got that sorted out anyway.")
    end
    del_stmt:reset()
end

karma = { times = {} }
function karma.get_id(item, chan)
    log("Getting id for '".. item .."' in ".. chan, "internal")
    local ci = idb.get_chanid(chan) -- or idb.new_chanid(chan) Obsolete
    log("Channel id is ".. ci, "internal")
    local get_stmt = infodb:prepare("SELECT id FROM karma WHERE item = $i AND chan = $ci")
    get_stmt:bind_names({ i = item, ci = ci })
    for result in get_stmt:nrows() do
        log("Returned id: " .. result.id, "internal")
        return result.id
    end
end
function karma.get(id, chan)
    if chan then    -- Was given item + chan, not id; used in cmdarray.lua
        id = karma.get_id(id, chan)
    end
    local get_stmt = infodb:prepare("SELECT karma FROM karma WHERE id = $id")
    get_stmt:bind_names({ id = id })
    for result in get_stmt:nrows() do
        get_stmt:reset()
        return tonumber(result.karma)
    end
end
function karma.mod(item, chan, int)
    local id = karma.get_id(item, chan)
    if not id then
        id = karma.add(item, chan)
    end
    log("Modifying karma item with id ".. id, "internal")
    local cur_karma = karma.get(id) or 0
    local new_karma = cur_karma + int   -- To lower, use int = -1
    karma.set(id, new_karma)
    return new_karma
end
function karma.add(item, chan)
    local ci = idb.get_chanid(chan) -- or idb.new_chanid(chan)
    local ins_stmt = infodb:prepare("INSERT INTO karma (item, chan, karma) " ..
        "VALUES ($i, $ci, 0)")
    ins_stmt:bind_names({ i = item, ci = ci })
    if ins_stmt:step() ~= sqlite3.DONE then
        log("Could not insert item into karma database", "error")
    end
    log("Added item '".. item .."' to karma database in ".. chan, "trivial")
    return karma.get_id(item, chan)
end
function karma.set(id, value)   -- Call this in hacks.lua for "rigging"/fixing
    local set_stmt = infodb:prepare("UPDATE karma SET karma=$k WHERE id = $id")
    set_stmt:bind_names({ k = value, id = id})
    set_stmt:step()
end
function karma.del(item, chan)
    local id = karma.get_id(item, chan)
    if not id then return false end
    local del_stmt = infodb:prepare("DELETE FROM karma WHERE id = $id")
    del_stmt:bind_names({ id = id })
    del_stmt:step()
    log("Deleted karma item with id " .. id, "trivial")
    return true
end
function karma.reset(item, chan)    -- Just pretty, syntactical sugar
    local id = karma.get_id(item, chan)
    karma.set(id, 0)
    log("Reset karma for '".. item .."' in ".. chan, "trivial")
end
function karma.checktime(chan, nick)
    if karma.times[chan] and karma.times[chan][u.nick]
      and os.difftime(os.time(), karma.times[chan][u.nick]) < 60 then
        -- Nick has modified a karma within the last minute; ignore
        return nil
    else
        -- Update time and allow karma mod
        if not karma.times[chan] then karma.times[chan] = {} end
        karma.times[chan][u.nick] = os.time()
        return true
    end
end
function karma.cleantimes()
    for c, t in pairs(karma.times) do
        for u, time in pairs(t) do
            if os.difftime(os.time(), time) > 60 then
                -- Get rid of unnecessary times
                karma.times[c][u] = nil
            end
        end
    end
end
