#!/usr/bin/env lua
-- validate.lua - validate minnet's config
-- Copyright Stæld Lakorv, 2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- Basic settings

if ( not logdir ) or logdir == "" then
    err("You need to specify where the logfiles go! (Option 'logdir')")
elseif not ( bot and msg ) then
    err("What did you do to the config? Please copy the sample " ..
        "configuration and edit that. (File 'config.lua.sample')")
elseif not ( bot.nets and not bot.nets[1] ) then
    err("There are no configured networks. Please fix this by copying " ..
        "the sample configuration and substituting with your own data. " ..
        "(File 'config.lua.sample')")

-- Loaded network (be lazy and check only the one we're connecting to)

elseif not ( net.name and net.name:match("%a") ) then
    err("This network doesn't seem to have a valid name")
elseif not ( net.addr and net.addr ~= "" ) then
    err("This network doesn't seem to have a valid address")
elseif net.port and net.port ~= "" and not net.port:match("^%d+$") ) then
    -- Remember that the port setting is optional, but it should only contain
    --+ digits if it is actually set
    err("This network doesn't seem to have a valid port")
elseif net.secure and net.secure ~= true then
    -- If 'secure' has been set, but is not a boolean, assume this means true
    net.secure = true
    log("The 'secure' option should be either true or false. Assuming that " ..
        net.secure .. " means true. (Option 'net.secure')", "warn")
elseif net.modes and not ( type(net.modes) == "string" and net.modes:match("^%l+$") ) then
    err("This network doesn't seem to have a valid set of modes configured." ..
        " (Option 'net.modes')")

-- Internal settings

elseif not ( bot.levels and bot.levels.owner ) then
    err("Access levels definition not sufficient. Please make sure that " ..
        "you have all necessary levels defined. (Option 'bot.levels')")
elseif not ( bot.smiles and bot.smiles[1] ) then
    log("No smiles defined; the 'be' command will not trigger any smilies",
        "trivial")
-- Can't be bothered complaining about these - just initialise them and stfu
elseif not bot.disabled then    bot.disabled = {}
elseif not bot.ignore   then    bot.ignore   = {}
elseif not bot.disfuncs then    bot.disfuncs = {}
elseif not ( levels and levels["info"] ) then
    err("Logging levels not properly defined. (Option 'levels')")
elseif not verbosity    then    verbosity = levels["info"]
elseif not db then
    err("No user database has been specified. (Option 'db')")
elseif not idb then
    err("No info database has been specified. (Option 'idb')")
elseif not cprefix then
    log("No channel prefixes defined, falling back to '#'", "warn")
    cprefix = "#"

-- NickServ

elseif net.services and net.services.nickserv.enabled == true then
    if ( not net.services.nickserv.servnick ) or
      net.services.nickserv.servnick == "" then
        log("", "warn")
        log("NickServ's nick hasn't been set. Falling back to " ..
            "'NickServ'. This is dangerous if not correct!", "warn")
        log("Please fix this by setting net.services.nickserv.servnick " ..
            "in the configuration", "warn")
        log("", "warn")
    end
    if ( not net.services.nickserv.passwd ) or
      net.services.nickserv.passwd == "" then
        log("", "warn")
        log("NickServ was enabled in the config, but no password has " ..
            "been set. NickServ integration will be disabled until " ..
            "this has been fixed.", "warn")
        log("", "warn")
    end
end

