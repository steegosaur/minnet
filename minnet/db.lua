#!/usr/bin/env lua
-- db.lua - database functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet.  
-- Minnet is released under the GPLv3 - see ../COPYING 

require("lsqlite3")

function db.error(n, u, m)
    log(m)
    c.net[n]:sendChat(u.nick, m)
end
function db.check(n)
    udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES (db_test);")
    if ( tostring(udb:errcode()) == "1" ) then
        udb:exec("CREATE TABLE " .. bot.nets[n].name .. " (nick,level,host,passhash,email,cur_nick);")
        log("Created sql table " .. bot.nets[n].name)
    end
end
local function forgot(n, u, f)
    c.net[n]:sendChat(u.nick, "I couldn't use the user info; you forgot telling me the " .. f .. ".")
end
function db.get_user(n, nick)
    local userinfo = udb:nrows("SELECT nick,level,host,passhash,email FROM " .. bot.nets[n].name .. " WHERE cur_nick=" .. nick .. " OR nick=" .. nick)
    return userinfo
end
function db.add_user(n, u, nick, level, host, passhash, email)
    local cur_nick = nick
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not level    or ( level    == "" ) then forgot(n, u, "level")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(n, u, "password")
    elseif not email    or ( email    == "" ) then forgot(n, u, "email")
    else
        udb:exec("SELECT * FROM " .. bot.nets[n].name .. " WHERE nick=" .. nick .. ";")
        if ( udb:errmsg() ~= "no such column: " .. nick ) then
            log("User already exists")
            c.net[n]:sendChat(u.nick, "I already know that guy. Try setting the info instead.")
            return nil
        end
        nick, level, host, passhash, email, cur_nick = "'" .. nick .. "'", "'" .. level .. "'", "'" .. host .. "'", "'" .. passhash .. "'", "'" .. email .. "'", "'" .. cur_nick .. "'"
        if ( udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ", " .. cur_nick .. ")") ~= sqlite3.OK ) then
            db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            log("Added user with fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ", " .. cur_nick .. ") on net " .. bot.nets[n].name)
            c.net[n]:sendChat(u.nick, "I added the user.")
        end
    end
end
function db.upd_user(n, u, cur_nick, nick, host)
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not cur_nick or ( cur_nick == "" ) then forgot(n, u, "current nick")
    else
        nick, host, cur_nick = "'" .. nick .. "'", "'" .. host .. "'", "'" .. cur_nick .. "'"
        if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET cur_nick=" .. cur_nick .. ", host=" .. host .. " WHERE nick=" .. nick) ~= sqlite3.OK ) then
            db.error(n, u, "Could not update user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            log("Updated user with fields cur_nick, host (" .. cur_nick .. ", " .. host .. ") on net " .. bot.nets[n].name)
            c.net[n]:sendChat(u.nick, "I updated the user information.")
        end
    end
end
function db.set_user(n, u, nick, level, host, passhash, email, cur_nick)
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not level    or ( level    == "" ) then forgot(n, u, "level")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(n, u, "password")
    elseif not email    or ( email    == "" ) then forgot(n, u, "email")
    else
        if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET nick=" .. nick .. ", level=" .. level .. ", host=" .. host .. ", passhash=" .. passhash .. ", email" .. email .. ")") ~= sqlite3.OK ) then
            db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            log("Set new fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") on net " .. bot.nets[n].name)
        end
    end
end

-- EOF
