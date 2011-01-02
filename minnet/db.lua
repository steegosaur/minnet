#!/usr/bin/env lua
-- db.lua - database functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet.  
-- Minnet is released under the GPLv3 - see ../COPYING 

require("lsqlite3")

function db.error(n, u, m)
    log(m, u)
    c.net[n]:sendChat(u.nick, m)
end
function db.check(n)
    udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES (db_test);")
    if ( udb:errmsg() == "no such table: " .. bot.nets[n].name ) then
        udb:exec("CREATE TABLE " .. bot.nets[n].name .. " (nick,level,host,passhash,email,cur_nick);")
        log("Created sql table " .. bot.nets[n].name)
    end
end
local function forgot(n, u, f)
    c.net[n]:sendChat(u.nick, "I can't use that user info; you forgot telling me the " .. f .. ".")
end
function db.sanitise(...)
    for i = 1, #arg do
        arg[i] = string.lower(arg[i])
        arg[i] = string.gsub(arg[i], "[,;']+", "")
        arg[i] = string.gsub(arg[i], "(%p)", "\\%1")
    end
    return arg
end
function db.revsan(...)
    for i = 1, #arg do
        arg[i] = string.gsub(arg[i], "(\\)", "%%")
    end
    return arg
end
function db.get_user(n, nick)
    nick = db.sanitise(nick)[1]
    for userinfo in udb:nrows("SELECT nick,level,host,passhash,email,cur_nick FROM " .. bot.nets[n].name .. " WHERE cur_nick='" .. nick .. "' OR nick='" .. nick .. "' LIMIT 1;") do
        return userinfo
    end
end
function db.check_auth(n, u, level) -- Does not use authentication, only checks for matching nick and host in db; FIXME: UNSECURE
    local info = db.get_user(n, u.nick)
    if not info then
        return false
    end
    if ( bot.levels[level] >= bot.levels[info.level] ) then
        return true
    else
        return false
    end
end

-- getting info on users through irc
function db.show_user(n, u, name)
    if not db.check_auth(n, u, "admin") then
        log("Attempted to get info about user " .. name .. " on " .. bot.nets[n].name, u)
        c.net[n]:sendChat(u.nick, msg.notauth)
        return nil
    elseif not name then
        db.error(n, u, "You forgot telling me the user's nick.")
        return nil
    end
    local user = db.get_user(n, name)
    if not user then
        db.error(n, u, "I couldn't find a user with that nick.")
        return nil
    end
    if not user.passhash then
        user.passhash = "unavailable"
    else
        user.passhash = "available"
    end
    c.net[n]:sendChat(u.nick, "Registered info on user " .. name .. ":")
    c.net[n]:sendChat(u.nick, "Nick:            " .. user.nick)
    c.net[n]:sendChat(u.nick, "Access level:    " .. user.level)
    c.net[n]:sendChat(u.nick, "Current nick:    " .. user.cur_nick)
    socket.sleep(0.7)
    c.net[n]:sendChat(u.nick, "Hostmask:        " .. user.host)
    c.net[n]:sendChat(u.nick, "Email address:   " .. user.email)
    c.net[n]:sendChat(u.nick, "Password hash:   " .. user.passhash)
end
-- db mod/add function
function db.set_data(n, u, mode, nick, level, host, passhash, email, cur_nick)
    local allowed_level
    if db.check_auth(n, u, "admin") then
        allowed_level = "admin"
    elseif db.check_auth(n, u, "oper") then
        allowed_level = "user"
    else
        log("Attempted to add or modify user on " .. bot.nets[n].name, u)
        c.net[n]:sendChat(u.nick, msg.notauth)
        return nil
    end
    local nick = db.sanitise(nick)[1] or ""
    local cur_nick = cur_nick or nick
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not level    or ( level    == "" ) then forgot(n, u, "level")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(n, u, "password")
    elseif not email    or ( email    == "" ) then forgot(n, u, "email")
    elseif ( bot.levels[level] < bot.levels[allowed_level] ) then
        log("Attempted to add user " .. nick .. " as " .. level .. " without sufficient permissions to do so.", u)
        c.net[n]:sendChat(u.nick, msg.notauth)
    else
        local function checkTable(t, c)
            for i in udb:rows("SELECT * FROM " .. t .. " WHERE nick='" .. c .. "' LIMIT 1;") do
                return i
            end
        end

        local list = db.sanitise(level, host, passhash, email)
        level, host, passhash, email = list[1], list[2], list[3], list[4]

        if ( mode == "add" ) then
            if checkTable(bot.nets[n].name, nick) then
                log("User " .. nick .. " already exists, ignoring", u)
                c.net[n]:sendChat(u.nick, "I already know that guy. Try modifying the user instead.")
                return nil
            end
            --nick, level, host, passhash, email, cur_nick = "'" .. nick .. "'", "'" .. level .. "'", "'" .. host .. "'", "'" .. passhash .. "'", "'" .. email .. "'", "'" .. cur_nick .. "'"
            if ( udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES ('" .. nick .. "', '" .. level .. "', '" .. host .. "', '" .. passhash .. "', '" .. email .. "', '" .. cur_nick .. "')") ~= sqlite3.OK ) then
                db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Added user with fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ", " .. cur_nick .. ") on net " .. bot.nets[n].name, u)
                c.net[n]:sendChat(u.nick, "I added the user.")
            end
        elseif ( mode == "mod" ) then
                if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET nick='" .. nick .. "', level='" .. level .. "', host='" .. host .. "', passhash='" .. passhash .. "', email='" .. email .. "' WHERE nick='" .. nick .. "';") ~= sqlite3.OK ) then
                db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Modified fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") on net " .. bot.nets[n].name, u)
            end
        end
    end
end
function db.upd_user(n, u, cur_nick, nick, host)
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not cur_nick or ( cur_nick == "" ) then forgot(n, u, "current nick")
    else
        local list = db.sanitise(cur_nick, nick, host)
        cur_nick, nick, host = list[1], list[2], list[3]
        --nick, host, cur_nick = "'" .. nick .. "'", "'" .. host .. "'", "'" .. cur_nick .. "'"
        if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET cur_nick='" .. cur_nick .. "', host='" .. host .. "' WHERE nick='" .. nick .. "';") ~= sqlite3.OK ) then
            db.error(n, u, "Could not update user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            log("Updated user with fields nick, cur_nick, host (" .. nick .. ", " .. cur_nick .. ", " .. host .. ") on net " .. bot.nets[n].name, u)
            c.net[n]:sendChat(u.nick, "I updated the user information.")
        end
    end
end
function db.set_user(n, u, nick, mode, val)
    local nick = db.sanitise(u.nick)[1]

    if ( mode == "email" ) then
        if not val then
            c.net[n]:sendChat(u.nick, "You forgot telling me your new email.")
        else
            val = db.sanitise(val)[1]
            if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET email='" .. email .. "' WHERE cur_nick='" .. nick .. "';") ~= sqlite3.OK ) then
                db.error(n, u, "Could not update user data: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Updated user " .. nick .. " on net " .. bot.nets[n].name .. " with new email " .. val, u)
                c.net[n]:sendChat(u.nick, "Got it.")
            end
        end
    elseif ( mode == "password" ) then
        if not val then
            c.net[n]:sendChat(u.nick, "You forgot telling me your new password. Don't worry, I'm not telling it to anybody.")
        else
            local passhash = passgen(val)
            val = nil
            if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET passhash='" .. passhash .. "' WHERE cur_nick='" .. u.nick .. "';") ~= sqlite3.OK ) then
                db.error(n, u, "Could not update user data: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Updated user " .. u.nick .. " on net " .. bot.nets[n].name .. " with new password.", u)
                c.net[n]:sendChat(u.nick, "Got it.")
            end
        end
    else
        c.net[n]:sendChat(u.nick, "Uhm, sorry - I can either set your password or your email. Which did you want to change?")
    end
end
--[[function db.mod_user(n, u, nick, level, host, passhash, email, cur_nick)
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not level    or ( level    == "" ) then forgot(n, u, "level")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(n, u, "password")
    elseif not email    or ( email    == "" ) then forgot(n, u, "email")
    else
    end
end--]]

-- EOF
