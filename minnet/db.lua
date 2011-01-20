#!/usr/bin/env lua
-- db.lua - database functions file for minnet
-- Copyright Stæld Lakorv, 2010 <staeld@staeld.co.cc>
-- This file is part of Minnet.  
-- Minnet is released under the GPLv3 - see ../COPYING 

require("lsqlite3")

function db.error(u, m)
    log(m, u, "error")
    send(u.nick, m)
end
function db.check()
    udb:exec("INSERT INTO " .. net.name .. " VALUES (db_test);")
    if ( udb:errmsg() == "no such table: " .. net.name ) then
        udb:exec("CREATE TABLE " .. net.name .. " (nick,level,host,passhash,email,cur_nick);")
        log("Created sql table " .. net.name, "info")
    end
end
function db.ucheck()
    local info
    for result in udb:nrows("SELECT * FROM " .. net.name .. " LIMIT 1;") do
        info = result
    end
    if not info then
        otkgen()
        print()
        print("Error: There are no users in this network's database.")
        print("A one-time authentification key has been generated. To identify yourself as an administrator, please run the following command in a qurey to " .. conn.nick .. ":")
        print("db otk " .. otk[n])
        print()
    end
end
function db.flush(u)
    if db.check_auth(u, "admin") then
        if ( udb:exec("COMMIT;") ~= sqlite3.OK or nil ) then
            send(u.nick, "I wrote the latest stuff down so I won't forget.")
            log("Committed recent changes to database", "info")
        else
            db.error(u, "Could not commit: " .. udb:errcode() .. " - " .. udb:errmsg())
        end
    else
        send(u.nick, msg.notauth)
        log("Unauthorised attempt at flushing SQL database", "warn")
    end
end
function db.check_otk(u, key)
    if not otk[n] then
        log("Received OTK auth attempt, but no OTK specified for the network", u, "warn")
        send(u.nick, "There is no active OTK for this network.")
    else
        if ( key == otk[n] ) then
            otk[n] = nil
            log("Successful OTK auth; admin access granted", u, "warn")
            -- Data:    n, u, mode,  allowed_level, nick,   level,   host,   passhash,        email)
            db.set_data(u, "add", "admin",       u.nick, "admin", u.host, passgen(tostring(otk[n])), nil)
            send(u.nick, "Congrats, you just identified and added yourself as the administrator, with the otk as your password.")
            send(u.nick, "You will want to modify your database entry asap by writing 'db mod " .. u.nick .. " admin " .. u.host .. " <password> <email>'.")
            send(u.nick, "For more help on managing the database, write 'db help'.")
        else
            log("Attempted to gain access through OTK auth with wrong key", u, "warn")
            send(u.nick, "I'm sorry, but that's not the active key for this network.")
        end
    end
end
local function forgot(u, f)
    send(u.nick, "I can't use that user info; you forgot telling me the " .. f .. ".")
end

-- TODO: Obsoletise sanitising functions; prepared statements should take over
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
function db.check_table(tab, data)
    local get_stmt = udb:prepare("SELECT * FROM " .. tab .. " WHERE nick=$nick LIMIT 1;")
    data = data:lower()
    get_stmt:bind_names({ nick = data })
    for i in get_stmt:nrows() do
        return i
    end
    get_stmt:reset()
end
function db.get_user(nick)
    local usr_stmt = udb:prepare("SELECT nick,level,host,passhash,email,cur_nick FROM " .. net.name .. " WHERE cur_nick = $nick or nick = $nick LIMIT 1;")
    usr_stmt:bind_names({ nick = nick:lower() })
    for userinfo in usr_stmt:nrows() do
        return userinfo
    end
    usr_stmt:reset()
end
function db.check_auth(u, level)
    local info = db.get_user(u.nick)
    if not info then
        return false
    end
    if ( bot.levels[level] >= bot.levels[info.level] ) then
        return true
    else
        return false
    end
end
function db.ident_user(u, name, passwd)
    name = name:lower()
    local ref = db.get_user(name)
    if not ref then
        send(u.nick, "I don't know anyone with that name.")
        return nil
    end
    local passwd = passgen(passwd)
    if ( ref.passhash == passwd ) then
        --          n, u,       cur_nick, nick, host
        db.upd_user(u, u.nick:lower(), name, u.host)
    else
        log("Unsuccessful login attempt for user " .. name, u, "warn")
        send(u.nick, "Umm, nope, can't say I remember you.")
    end
end

-- getting info on users through irc
function db.show_user(u, name)
    if not db.check_auth(u, "admin") then
        log("Attempted to get info about user " .. name .. " on " .. net.name, u, "warn")
        send(u.nick, msg.notauth)
        return nil
    elseif not name then
        send(u.nick, "You forgot telling me the user's nick.")
        log("No username specified for db.show_user()", u, "trivial")
        return nil
    end
    local user = db.get_user(name)
    if not user then
        send(u.nick, "I don't know anyone with that name.")
        log("Attempted to get information for unknown user " .. name, u, "trivial")
        return nil
    end
    if not user.email or ( user.email == "" ) then
        user.email = "n/a"
    end
    if user.passhash then
        user.passhash = "stored"
    else
        user.passhash = "unavailable"
    end
    send(u.nick, "Registered info on user " .. name .. ":")
    send(u.nick, "Nick:            " .. user.nick)
    send(u.nick, "Current nick:    " .. user.cur_nick)
    send(u.nick, "Access level:    " .. user.level)
    socket.sleep(0.7)
    send(u.nick, "Hostmask:        " .. user.host)
    send(u.nick, "Email address:   " .. user.email)
    send(u.nick, "Password hash:   " .. user.passhash)
end

function db.rem_user(u, nick)
    if not db.check_auth(u, "admin") then
        log("Unauthorised user attempted to remove user " .. nick .. " from table " .. net.name, u, "warn")
        send(u.nick, msg.notauth)
    else
        if not db.check_table(net.name, nick) then
            log("User " .. nick .. " does not exist, ignoring", u, "trivial")
            send(u.nick, "I don't know anyone by that name.")
            return nil
        end
        log("Deleting user " .. nick .. " from table " .. net.name, u, "info")
        local del_stmt = udb:prepare("DELETE FROM " .. net.name .. " WHERE nick = $nick")
        del_stmt:bind_names({ nick = nick })
        if ( del_stmt:step() ~= sqlite3.DONE ) then
            db.error(u, "Could not remove user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            send(u.nick, "That's okay, I'll pretend I don't know them the next time.")
        end
        del_stmt:reset()
    end
end

-- db mod/add function
function db.set_data(u, mode, allowed_level, nick, level, host, passhash, email)
    if not allowed_level then
        db.error(u, "Could not calculate grantable authorisation level; aborting database access")
        return nil
    end
    if     not nick     or ( nick     == "" ) then forgot(u, "nick")
    elseif not level    or ( level    == "" ) then forgot(u, "level")
    elseif not host     or ( host     == "" ) then forgot(u, "host")
    elseif not passhash or ( passhash == "" ) then forgot(u, "password")
    elseif ( bot.levels[level] < bot.levels[allowed_level] ) then
        log("Attempted to add user " .. nick .. " as " .. level .. " without sufficient permissions to do so.", u, "warn")
        send(u.nick, msg.notauth)

    else -- Parametres acceptable; add user
        if ( not email ) or ( email == "" ) then
            log("No email specified for user " .. nick, "trivial")
            email = ""
        end
        if nick:match("%%")     then nick  = nick:gsub("%%", "") end
        if level:match("%%")    then level = level:gsub("%%", "")  end
        if host:match("%%")     then host  = host:gsub("%%", "")   end
        if email and email:match("%%") then email = email:gsub("%%", "") end

        nick = nick:lower()
        local cur_nick = nick

        if ( mode == "add" ) then
            if db.check_table(net.name, nick) then
                log("User " .. nick .. " already exists, ignoring", u, "trivial")
                send(u.nick, "I already know that guy. Try modifying the user instead.")
                return nil
            end
            local ins_stmt = udb:prepare("INSERT INTO " .. net.name .. " VALUES ($nick, $level, $host, $pass, $email, $cur_nick)")
            ins_stmt:bind_names({ nick = nick, level = level, host = host,
                pass = passhash, email = email, cur_nick= cur_nick })

            if ( ins_stmt:step() ~= sqlite3.DONE ) then
                db.error(u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Added user with fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") on net " .. net.name, u, "info")
                send(u.nick, "I added the user.")
            end
            ins_stmt:reset()

        elseif ( mode == "mod" ) then
            if not db.check_table(net.name, nick) then
                log("User " .. nick .. " doesn't exist, ignoring", u, "trivial")
                send(u.nick, "I don't know anyone by that name. Try adding the user first.")
                return nil
            end
            local mod_stmt = udb:prepare("UPDATE " .. net.name .. " SET nick=$nick, level=$level, host=$host, passhash=$pass, email=$email WHERE nick = $nick")
            mod_stmt:bind_names({ nick = nick, level = level, host = host,
                pass = passhash, email = email })

            if ( mod_stmt:step() ~= sqlite3.DONE ) then
                db.error(u, "Could not insert user info: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Modified fields nick, level, host, passhash, email (" .. nick .. ", " .. level .. ", " .. host .. ", " .. passhash .. ", " .. email .. ") for user " .. nick .. " on net " .. net.name, u, "info")
                send(u.nick, "Got it.")
            end
            mod_stmt:reset()
        end
    end
end
function db.upd_user(u, cur_nick, nick, host)
    if     not nick     or ( nick     == "" ) then forgot(u, "nick")
    elseif not host     or ( host     == "" ) then forgot(u, "host")
    elseif not cur_nick or ( cur_nick == "" ) then forgot(u, "current nick")
    else
        nick = nick:lower()

        local upd_stmt = udb:prepare("UPDATE " .. net.name .. " SET cur_nick=$cur_nick, host=$host WHERE nick=$nick")
        upd_stmt:bind_names({ cur_nick = cur_nick, host = host, nick = nick })

        if ( upd_stmt:step() ~= sqlite3.DONE ) then
            db.error(u, "Could not update user info: " .. udb:errcode() .. " - " .. udb:errmsg())
        else
            log("Updated user with fields nick, cur_nick, host (" .. nick .. ", " .. cur_nick .. ", " .. host .. ") on net " .. net.name, u, "info")
            send(u.nick, "Right, sorry about that. I'll try to remember next time.")
        end
        upd_stmt:reset()
    end
end
function db.set_user(u, mode, val)
    if not db.check_table(net.name, u.nick) then
        send(u.nick, "I'm sorry, but I don't think I know you.")
        log("Tried to set information for an unknown user", u, "trivial")
        return nil
    end
    if ( mode == "email" ) then
        if not val then
            send(u.nick, "You forgot telling me your new email.")
        else
            local upd_stmt = udb:prepare("UPDATE " .. net.name .. " SET email = $email WHERE cur_nick = $nick;")
            upd_stmt:bind_names({ email = val, nick = u.nick })
            if ( upd_stmt:step() ~= sqlite3.DONE ) then
                db.error(u, "Could not update user data: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Updated user " .. u.nick .. " on net " .. net.name .. " with new email " .. val, u, "info")
                send(u.nick, "Got it.")
            end
        end
    elseif ( mode == "password" ) then
        if not val then
            send(u.nick, "You forgot telling me your new password. Don't worry, I'm not telling it to anybody.")
        else
            local val = passgen(val)
            local upd_stmt = udb:prepare("UPDATE " .. net.name .. " SET passhash = $pass WHERE cur_nick = $nick;")
            if ( upd_stmt:step() ~= sqlite3.DONE ) then
                db.error(u, "Could not update user data: " .. udb:errcode() .. " - " .. udb:errmsg())
            else
                log("Updated user " .. u.nick .. " on net " .. net.name .. " with new password.", u, "info")
                send(u.nick, "Got it.")
            end
        end
    else
        send(u.nick, "Uhm, sorry - I can either set your password or your email. Which did you want to change?")
    end
end

-- EOF
