#!/usr/bin/env lua
-- cmdvocab.lua - command vocabulary file for minnet
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file is used as an abstraction layer between the received commands
--  and the actual, known commands. This permits for looser command recognition
--  while avoiding duplicate functions.
--  The actual implementation is still subject to change.

-- Syntax: funcname = { "pattern%s+matching%s+the%s+said%s+command$" }

bot.commands = {
    uptime  = { "how%s+long", "for%s+how%s+long", "what'?s?%s+.*uptime.*" },
    be      = { "be" },
    join    = { "join", "go%s+to" },
    part    = { "part", "get%s+out" },
    quit    = { "get%s+off", "shut%s+down", "quit", "disconnect" },
    reload  = { "reload" },
    set     = { "set" },
    load    = { "load" },
    reseed  = { "reseed", "reset%s+the%s+crypto.-seed" },
    say     = { "say" },
    version = { "version", "ctcp%s+version", "ask%s+for%s+.*version.*of" },
    identify= { "identify", "i'?%s-a?m" },
    db      = { "db", "database" },
    disable = {
        "shut%s-up", "shaddap", "keep%s+quiet", "be%s+quiet", "stay%s+quiet",
        "silence", "stay%s+off", "disable"
    },
    enable  = {
        "y[oua]+'?re?%s+free", "speak", "r?e?%-?enable", "unsilence",
        "live", "go%s+on"
    },
}
-- EOF
