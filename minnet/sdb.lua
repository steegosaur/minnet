#!/usr/bin/env lua
-- sdb.lua - study database functions file for minnet
-- Copyright Stæld Lakorv, 2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file contains the functions to create, manipulate and use a database
--+ of studying records, somewhat like the "6-week challenge" Twitter bot.

require("lsqlite3")
depends({ "time", "db" })

-- Variables
sdb = { file = "studies.minnet.db" }
studb = sqlite3.open(sdb.file)

sdb.subjs = {   -- Predefined word matches and categories
    language = {
        de = { "german", "deutsch", "tysk" },
        en = { "english", "engelsk" },
        fi = { "finnish", "suomi", "finsk" },
        fr = { "french", "français", "fransk" },
        eo = { "esperanto" },
        es = { "spanish", "español", "spansk" },
        no = { "norwegian", "norsk" },
    },
    code = {
        lua = { "lua" },
        php = { "php" },
        js  = { "javascript" },
    },
}
sdb.types = {   -- Predefined studying methods
    memorising = { "memoris", "flash%s-cards", "anki", "memrise" },
    reading   = { "read", "text", "book" },
    speaking  = { "speak", "talk", "convers" },
    writing   = { "writ" },
    listening = { "listen", "hear", "audio", "radio" },
    watching  = { "video", "film", "movie", "watch" },
    coding    = { "script[ei][dn]", "cod[ei][dn]" },
}

-- Command pieces
bot.commands.sdb_reg = {
    "i?%s-studied%s+(%d+%s*[hm])%l-%s+o?f?%s-(%S+)",
    "i%s+did%s+(%d+%s*[hm])%l-%s+o?f?%s-(%S+)",
    "record%s+(%d+%s*[hm])%l*%s+o?f?%s-(%S+)"
}
cmdlist.sdb_reg = {
    help = "You study anything lately?",
    func = function(u, chan, m, catch)
        local dur, subj = m:match(catch)
        local type = sdb.get_type(m)
        local comment = m:match("%b()")
        -- Remove the comment from the text, so time.get_date won't be confused
        m = m:gsub(comment, "")
        -- Remove parens from comment
        comment = comment:sub(2, -2)
        local date = time.get_date(m)
        if sdb.add(u, subj, dur, type, comment, date) == 0 then
            send(chan, "Nice, let me just write that down..")
        end
    end
}
bot.commands.sdb_selfstats = {
    "what%s+are%s+my%s+(%S+)%s+stat", "what%s+are%s+my%s+(stats)"
}
cmdlist.sdb_selfstats = {
    help = "Want to see some stats on your studies?",
    func = function(u, chan, m, catch)
        local subj = m:match(catch)
        local outline = "%s%s: %.1f hours (last study: %.1f hours%s, %s%s)"
        if subj:match("stud") or subj == "stats" then
            local get_stmt = studb:prepare("SELECT * FROM studies WHERE " ..
                " nickid = $ni")
            local nickid = sdb.get_nickid(u.nick, true)
            get_stmt:bind_names({ni = nickid})
            local count, results, i = {}, {}, 0
            for t in get_stmt:nrows() do
                i = i + 1
                if count[t.subj] then
                    count[t.subj] = count[t.subj] + t.time
                else count[t.subj] = t.time end
                -- Save all results to a table so we can determine the last one
                results[t.date] = t
            end
            if i == 0 then
                -- There was no returned counts, meaning user has no records
                send(chan, "You don't have any recorded studies, ".. u.nick ..".")
                return nil
            end
            -- Find out which was the last recorded study of each subject
            local last = {}
            for subject in pairs(count) do
                last[subject] = sdb.determine_last(results, subject)
            end
            for subject, count in pairs(count) do
                local l = last[subject]
                local _, cat = sdb.get_subject(subject)
                if cat == "NULL" then cat = ""
                else cat = " (" .. cat .. ")" end
                if l.type == "NULL" or l.type == nil then l.type = ""
                else l.type = " " .. l.type end
                if not l.comment or l.comment == "" or l.comment == "NULL" then
                    l.comment = ""
                else
                    l.comment = " [" .. l.comment .. "]"
                end
                send(u.nick, outline:format(subject, cat, count/60, l.time/60, l.type, l.date, l.comment))
            end
        else
            local subj, cat = sdb.get_subject(subj)
            if cat == "NULL" then cat = ""
            else cat = " (" .. cat .. ")" end
            local get_stmt = studb:prepare("SELECT * FROM studies WHERE " ..
                " nickid = $ni AND subj = $s")
            local nickid = sdb.get_nickid(u.nick, true)
            get_stmt:bind_names({ni = nickid, s = subj})
            local count, results, i = 0, {}, 0
            for t in get_stmt:nrows() do
                i = i + 1
                if count == 0 then count = t.time
                else count = count + t.time end
                results[t.date] = t
            end
            if i == 0 then
                -- No records for given subject
                send(chan, "You don't seem to have studied that yet.")
                return nil
            end
            local last = sdb.determine_last(results)
            if last.type == "NULL" or last.type == nil then last.type = ""
            else last.type = " " .. last.type end
            if not last.comment or last.comment == "" or last.comment == "NULL" then
                last.comment = ""
            else
                last.comment = " [" .. last.comment .. "]"
            end
            send(chan, u.nick .. ": Stats for " ..
                outline:format(subj, cat, count/60, last.time/60, last.type, last.date, last.comment))
        end
    end
}

-- Functions
-- sdb.check(): Create database if necessary
function sdb.check()
    -- We want our studies to be channel-independent,
    --+ so we use our own nick table for just this info
    studb:exec([[CREATE TABLE IF NOT EXISTS nicks (
        nickid  INTEGER     PRIMARY KEY,
        nick    TEXT        NOT NULL,
        netid   INTEGER     NOT NULL
    );]])
    studb:exec([[CREATE TABLE IF NOT EXISTS studies (
        id      INTEGER     PRIMARY KEY,
        nickid  INTEGER     NOT NULL,
        subj    TEXT        NOT NULL,
        time    INT         NOT NULL,    -- In minutes
        type    TEXT,
        comment TEXT,
        date    TEXT
    );]])
    studb:exec([[CREATE TABLE IF NOT EXISTS times (
        id      INTEGER     PRIMARY KEY,
        nickid  INTEGER     NOT NULL,
        subj    TEXT        NOT NULL,
        total   INT         NOT NULL,
        comment TEXT,
        last    TEXT,
        type    TEXT
    );]])
end

-- sdb.determine_last(): Find the last entry of a series (if subj, only of that)
function sdb.determine_last(array, subject)
    local last = { yr = 0, mo = 0, d = 0, type = "", time = 0, date = "0-0-0" }
    for date, t in pairs(array) do
        local yr, mo, d = date:match("(%d+)%-(%d+)%-(%d+)")
        yr, mo, d = tonumber(yr), tonumber(mo), tonumber(d)
        if yr >= last.yr
          and ( ( mo > last.mo ) or ( mo == last.mo and d >= last.d ) )
          and ( ( subject and t.subj == subject ) or not subject ) then
            last = { yr = yr, mo = mo, d = d,
                type = t.type, comment = t.comment, time = t.time, date = date }
        end
    end
    return last
end

-- sdb.get_subject(): Returns internal name of subject, and its category
function sdb.get_subject(subj)
    subj = subj:gsub("[%p%s%d]", ""):lower() -- Simple sanitising
    -- Traverse the predefined subject table to see if we get a match
    for cat, t in pairs(sdb.subjs) do
        for code, matches in pairs(t) do
            if subj == code then return code, cat end
            for _, match in ipairs(matches) do
                if subj == match then
                    return code, cat
                end
            end
        end
    end
    -- If we're here, there was no match; use what we got and no category
    return subj, "NULL"
end

-- sdb.get_type(): Finds and returns internal name of type of study
function sdb.get_type(type)
    type = type:gsub("[%p%s%d]", ""):lower()
    for name, matches in pairs(sdb.types) do
        for _, match in ipairs(matches) do
            if type:match(match) then
                return name
            end
        end
    end
    return type or "NULL"
end

-- sdb.get_nickid(): Gets (or creates if not nocreate) nick id for given nick
function sdb.get_nickid(nick, nocreate)
    nick = nick:lower()
    local get_stmt = studb:prepare("SELECT * FROM nicks WHERE " ..
        "nick = $n AND netid = $net")
    get_stmt:bind_names({ n = nick, net = n })
    for result in get_stmt:nrows() do
        if result then return result.nickid end
    end
    if nocreate then return nil end
    log("Adding new nick to SDB", "internal")
    local ins_stmt = studb:prepare("INSERT INTO nicks (nick, netid) VALUES ($n, $i)")
    ins_stmt:bind_names({ n = nick, i = n })
    if ins_stmt:step() ~= sqlite3.DONE then
        local errmsg = "Could not add nick ".. nick .." to study db: " ..
            studb:errcode() .."-".. studb:errmsg()
        log(errmsg, "warn")
        return nil, errmsg
    else
        log("Added nick " .. nick .. " to SDB", "trivial")
        -- It's been added, now get it so we can return the id (no creation)
        return sdb.get_nickid(nick, true)
    end
end

-- sdb.add(): Main function, adds a record to the study database
function sdb.add(u, subj, length, type, comment, date)
    subj = sdb.get_subject(subj)
    local duration = 0
    do -- Figure out the length
        local hours = length:match("(%d+)%s-h") or length:match("(%d%d?):") or length:match("(%d+)%s+hour") or 0
        duration = hours * 60
        local minutes = length:match("%d+:(%d%d)") or length:match("(%d+)%s-m") or length:match("(%d+)%s+min") or 0
        duration = duration + minutes
    end
    if duration == 0 then
        send(chan, "Sorry, but you need to have studied for *some* time.")
        return nil
    end
    local nickid, errmsg = sdb.get_nickid(u.nick)
    if errmsg then
        db.error(u, errmsg)
        return nil
    end
    type = sdb.get_type(type)
    if not comment then comment = "NULL" end
    if not date then date = os.date("%F")
    else date = time.get_date(date) end
    local ins_stmt = studb:prepare([[INSERT INTO studies
        ( nickid, subj, time, type, comment, date ) VALUES
        ( $n, $s, $time, $tp, $c, $d )]])
    ins_stmt:bind_names({ n = nickid, s = subj, time = duration, tp = type,
        c = comment, d = date })
    -- Update user's statistics
    local old_total, old_last = sdb.get_times(nickid, subj)
    local new_total = old_total + duration
    local new_last
    do -- Figure out if this is more recent than last addition
        local old, new = {}, {}
        old.yr, old.mo, old.d = old_last:match("(%d+)%-(%d+)%-(%d+)")
        new.yr, new.mo, new.d = date:match("(%d+)%-(%d+)%-(%d+)")
        if new.yr >= old.yr
          and ( new.mo > old.mo or ( new.mo == old.mo and new.d >= old.d ) ) then
            new_last = new.yr .."-".. new.mo .."-".. new.d
        else
            new_last = old_last
        end
    end
    local upd_stmt
    if old_total == 0 then
        -- We're not updating but creating a new record
        upd_stmt = studb:prepare("INSERT INTO times " ..
            "(nickid, subj, total, last, comment, type) " ..
            "VALUES ($ni, $s, $t, $l, $c, $tp)")
    else -- The user has a record for this subject; update it
        upd_stmt = studb:prepare("UPDATE times SET total = $t, last = $l, " ..
            "type = $tp, comment = $c WHERE nickid = $ni AND subj = $s")
    end
    upd_stmt:bind_names({ t = new_total, l = new_last, c = comment, tp = type,
        ni = nickid, s = subj })
    if upd_stmt:step() ~= sqlite3.DONE then
        db.error(u, "Could not update total count for your subject: " ..
            studb:errcode() .."-".. studb:errmsg())
        -- TODO: Update db.error to take (u, message, db) and use _G[db]:errcode()
    else
        log("SDB: Updated total count for subject " .. subj, u, "debug")
    end
    if ins_stmt:step() ~= sqlite3.DONE then
        db.error(u, "Could not record studying: " ..
            studb:errcode() .."-".. studb:errmsg())
    else
        log("SDB: Successfully recorded studying", u, "debug")
        return 0
    end
end

-- sdb.get_times(): Returns user's total studying time for given subject
function sdb.get_times(nick, subject)
    if type(nick) == "string" then
        nick = sdb.get_nickid(nick, true)
    end
    local get_stmt = studb:prepare("SELECT * FROM times WHERE nickid = $ni AND subj = $s")
    get_stmt:bind_names({ni = nick, s = subject})
    for t in get_stmt:nrows() do
        return t.total, t.last
    end
    -- In case of no previous record:
    return 0, "0-0-0"
end

-- Code to execute upon startup
sdb.check()

-- EOF
