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
function db.ucheck(n)
    local info
    for result in udb:nrows("SELECT * FROM " .. bot.nets[n].name .. " LIMIT 1;") do
        info = result
    end
    if not info then
        otkgen(n)
        print()
        print("Error: There are no users in this network's database.")
        print("A one-time authentification key has been generated. To identify yourself as an administrator, please run the following command in a qurey to " .. c.net[n].nick .. ":")
        print("db otk " .. otk[n])
        print()
    end
end
function db.check_otk(n, u, key)
    if not otk[n] then
        log("Received OTK auth attempt, but no OTK specified for the network", u)
        c.net[n]:sendChat(u.nick, "There is no active OTK for this network.")
    else
        if ( key == otk[n] ) then
            otk[n] = nil
            log("Successful OTK auth; admin access granted", u)
            -- Data:    n, u, mode,  allowed_level, nick,   level,   host,   passhash,        email)
            db.set_data(n, u, "add", "admin",       u.nick, "admin", u.host, passgen(tostring(otk[n])), nil)
            c.net[n]:sendChat(u.nick, "Congrats, you just identified and added yourself as the administrator, with the otk as your password.")
            c.net[n]:sendChat(u.nick, "You will want to modify your database entry asap by writing 'db mod " .. u.nick .. " admin " .. u.host .. " <password> <email>'.")
            c.net[n]:sendChat(u.nick, "For more help on managing the database, write 'db help'.")
        else
            log("Attempted to gain access through OTK auth with wrong key", u)
            c.net[n]:sendChat(u.nick, "I'm sorry, but that's not the active key for this network.")
        end
    end
end
local function forgot(n, u, f)
    c.net[n]:sendChat(u.nick, "I can't use that user info; you forgot telling me the " .. f .. ".")
end
function db.sanitise(...)
    for i = 1, #arg do
        arg[i] = arg[i]:lower()
        arg[i] = arg[i]:gsub("[,;']+", "")
        arg[i] = arg[i]:gsub("(%p)", "\\%1")
    end
    return arg
end
function db.revsan(...)
    for i = 1, #arg do
        arg[i] = arg[i]:gsub("\\", "%%")
    end
    return arg
end
function db.remsan(...)
    for i = 1, #arg do
        arg[i] = arg[i]:gsub("\\", "")
    end
    return arg
end
function db.check_table(table, data)
    for i in udb:rows("SELECT * FROM " .. table .. " WHERE nick='" .. data .. "' LIMIT 1;") do
        return i
    end
end
function db.get_user(n, nick)
    nick = db.sanitise(nick)[1]
    for userinfo in udb:nrows("SELECT nick,level,host,passhash,email,cur_nick FROM " .. bot.nets[n].name .. " WHERE cur_nick='" .. nick .. "' or NICK = '" .. nick .. "' LIMIT 1;") do
        return userinfo
    end
end
function db.check_auth(n, u, level) -- Checks if the user is authenticated
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
function db.ident_user(n, u, name, passwd)
    local ref = db.get_user(n, name)
    local passwd = passgen(passwd)
    if ( ref.passhash == passwd ) then
        --          n, u, cur_nick, nick, host
        db.upd_user(n, u,   u.nick, name, u.host)
    else
        log("Unsuccessful login attempt for user " .. name, u)
        c.net[n]:sendChat(u.nick, "Umm, nope, can't say I remember you.")
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
        db.error(n, u, "I don't know anyone with that name.")
        return nil
    end
    if not user.email or ( user.email == "" ) then
        user.email = "not listed"
    end
    if user.passhash then
        user.passhash = "stored"
    else
        user.passhash = "unavailable"
    end
    user.nick     = db.remsan(user.nick)[1]
    user.level    = db.remsan(user.level)[1]
    user.cur_nick = db.remsan(user.cur_nick)[1]
    user.host     = db.remsan(user.host)[1]
    user.email    = db.remsan(user.host)[1]
    c.net[n]:sendChat(u.nick, "Registered info on user " .. name .. ":")
    c.net[n]:sendChat(u.nick, "Nick:            " .. user.nick)
    c.net[n]:sendChat(u.nick, "Access level:    " .. user.level)
    c.net[n]:sendChat(u.nick, "Current nick:    " .. user.cur_nick)
    socket.sleep(0.7)
    c.net[n]:sendChat(u.nick, "Hostmask:        " .. user.host)
    c.net[n]:sendChat(u.nick, "Email address:   " .. user.email)
    c.net[n]:sendChat(u.nick, "Password hash:   " .. user.passhash)
end

function db.rem_user(n, u, nick)
    if not db.check_auth(n, u, "admin") then
        log("Unauthorised user attempted to remove user " .. nick .. " from table " .. bot.nets[n].name, u)
        c.net[n]:sendChat(u.nick, msg.notauth)
    else
        nick = db.sanitise(nick)[1]
        if not db.check_table(bot.nets[n].name, nick) then
            log("User " .. nick .. " does not exist, ignoring", u)
            c.net[n]:sendChat(u.nick, "I don't know anyone by that name.")
            return nil
        end
        log("Deleting user " .. nick .. " from table " .. bot.nets[n].name, u)
        if ( udb:exec("DELETE FROM " .. bot.nets[n].name .. " WHERE nick = '" .. nick .. "';") ~= sqlite3.OK ) then
            db.error(n, u, "Could not remove user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            c.net[n]:sendChat(u.nick, "That's okay, I'll pretend I don't know them the next time.")
        end
    end
end
-- db mod/add function
function db.set_data(n, u, mode, allowed_level, nick, level, host, passhash, email)
    if not allowed_level then
        db.error(n, u, "Could not calculate grantable authorisation level; aborting database access")
        return nil
    end
    -- local nick = db.sanitise(nick)[1] or ""
    if     not nick     or ( nick     == "" ) then forgot(n, u, "nick")
    elseif not level    or ( level    == "" ) then forgot(n, u, "level")
    elseif not host     or ( host     == "" ) then forgot(n, u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(n, u, "password")
    elseif ( bot.levels[level] < bot.levels[allowed_level] ) then
        log("Attempted to add user " .. nick .. " as " .. level .. " without sufficient permissions to do so.", u)
        c.net[n]:sendChat(u.nick, msg.notauth)

    else -- Parametres acceptable; add user
        if ( not email ) or ( email == "" ) then
            log("No email specified for user " .. nick) -- 2011-01-06 FIXME: DOES NOT RECOGNISE EMAIL
            email = ""
        end

        if nick:match("%%")     then nick  = nick:gsub("%%", "") end
        if level:match("%%")    then level = level:gsub("%%", "")  end
        if host:match("%%")     then host  = host:gsub("%%", "")   end
        if email and email:match("%%") then email = email:gsub("%%", "") end
        local list = db.sanitise(level, host, passhash, email, nick)
        level, host, passhash, email, nick = list[1], list[2], list[3], list[4], list[5]
        local cur_nick = nick

        if ( mode == "add" ) then
            if db.check_table(bot.nets[n].name, nick) then
                log("User " .. nick .. " already exists, ignoring", u)
                c.net[n]:sendChat(u.nick, "I already know that guy. Try modifying the user instead.")
                return nil
            end
            --nick, level, host, passhash, email, cur_nick = "'" .. nick .. "'", "'" .. level .. "'", "'" .. host .. "'", "'" .. passhash .. "'", "'" .. email .. "'", "'" .. cur_nick .. "'"
            if ( udb:exec("INSERT INTO " .. bot.nets[n].name .. " VALUES ('" .. nick .. "', '" .. level .. "', '" .. host .. "', '" .. passhash .. "', '" .. email .. "', '" .. cur_nick .. "')") ~= sqlite3.OK ) then
                db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Added user with fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") on net " .. bot.nets[n].name, u)
                c.net[n]:sendChat(u.nick, "I added the user.")
            end
        elseif ( mode == "mod" ) then
            if not db.check_table(bot.nets[n].name, nick) then
                log("User " .. nick .. " doesn't exist, ignoring", u)
                c.net[n]:sendChat(u.nick, "I don't know anyone by that name. Try adding the user first.")
                return nil
            end
            if ( udb:exec("UPDATE " .. bot.nets[n].name .. " SET nick='" .. nick .. "', level='" .. level .. "', host='" .. host .. "', passhash='" .. passhash .. "', email='" .. email .. "' WHERE nick='" .. nick .. "';") ~= sqlite3.OK ) then
                db.error(n, u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Modified fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") for user " .. nick .. " on net " .. bot.nets[n].name, u)
                c.net[n]:sendChat(u.nick, "Got it.")
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
            c.net[n]:sendChat(u.nick, "Right, sorry about that. I'll try to remember next time.")
        end
    end
end
function db.set_user(n, u, mode, val)
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
