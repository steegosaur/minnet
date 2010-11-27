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
function db.get_user(n, nick)
    local userinfo = udb:nrows("SELECT nick,level,host,passhash,email FROM " .. bot.nets[n].name .. " WHERE cur_nick=" .. nick .. " OR nick=" .. nick)
    return userinfo
end
function db.add_user(n, u, nick, level, host, passhash, email)
    if ( udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ")") ~= sqlite3.OK ) then
        db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
    end
end
function db.upd_user(n, u, nick, cur_nick, host)
    if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET cur_nick=" .. cur_nick .. ", host=" .. host .. " WHERE nick=" .. nick) ~= sqlite3.OK ) then
        db.error(n, u, "Could not update user info: " .. udb:errcode() .. " - " .. udb:errmsg())
    end
function db.set_user(u, n, nick, level, host, passhash, email, cur_nick)
    reqs = { "nick", "level", "host", "passhash", "email" }
    local reqsmet = true
    for i in 1, #reqs do
        if not _G[reqs[i]] then -- This is horrible and I should probably be shot for it, but it should work.
            if ( reqs[i] == "passhash" ) then reqs[i] = "password" end
            c.net[n]:sendChat(u.nick, "I couldn't update the user; you forgot telling me the " .. reqs[i] .. ".")
            reqsmet = false
            break
        end
    end
    if ( reqsmet == true ) then
        if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET nick=" .. nick .. ", " ..  .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ")") ~= sqlite3.OK ) then
            db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        end
    end
end

-- EOF
