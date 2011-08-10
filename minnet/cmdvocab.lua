#!/usr/bin/env lua
-- cmdvocab.lua - command vocabulary file for minnet
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file is used as an abstraction layer between the received commands
--  and the actual, known commands. This permits for looser command recognition
--  while avoiding duplicate functions.

-- Syntax: funcname = { "pattern%s+matching%s+the%s+said%s+command" }

bot.commands = {
    join    = { "join", "go%s+to" },
    part    = { "part", "get%s+out" },
    quit    = { "get%s+off", "shut%s+down", "quit", "disconnect", "die" },
    reload  = { "reload" },
    set     = { "set" },
    load    = { "load" },
    unload  = { "unload", "remove" },
    reseed  = { "reseed", "reset%s+the%s+crypto.-seed" },
    say     = { "say" },
    version = { "version", "ctcp%s+version", "ask%s+for%s+.*version.*from" },
    identify= { "identify", "i'?%s-a?m" },
    db      = { "db", "database" },
    belong  = { "belong.*%sme", ".*%sme%s.*%sown%s+you", ".*%si%s.*own%s+you" },
    ignore  = { "ignore", "disregard" },
    help    = { "help", },
    owner   = {
        "who.*'?i?s%s+y[aoue]+r.*%s+owner", "who.*%sowns?%s+y[aoue]+",
        "be%s+mine", "be%s+my"
    },
    uptime  = {
        "how%s+long", "for%s+how%s+long", "what'?s?%s+.*uptime.*", "uptime"
    },
    time    = {
        "what'?%s-i?s%s+.*%s+time", "what'?%s-i?s%s+.*%s+clock",
        "what%stime'?%s-i?s'?%s-it", "time"
    },
    disable = {
        "shut%s-up", "shaddap", "keep%s+quiet", "be%s+quiet", "stay%s+quiet",
        "silence", "stay%s+off", "disable"
    },
    be      = { "be%s+" },
    enable  = {
        "y[oua]+'?re?%s+free", "speak", "r?e?%-?enable", "unsilence",
        "live", "go%s+on"
    },
    timezones = {
        "what.*timezones", "list.*timezones", "timezone%s+list",
        "how.*timezones", "which.*timezones"
    },
    twentytwo_seven = {
        ".*%sut[øoe]-ya", ".*%soslo", "[howhen]+.*22/7", ".*2011%-07%-22",
        ".*22nd%s+[of%s]*jul[yi]"
    },
}
-- EOF
