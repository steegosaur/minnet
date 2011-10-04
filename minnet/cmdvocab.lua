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
    say     = { "say" },
    set     = { "set%s+[^my]+" },
    help    = { "help" },
    load    = { "load", "reload%s.*hook" },
    reload  = { "reload" },
    db      = { "db", "database" },
    join    = { "join", "go%s+to" },
    unload  = { "unload", "remove" },
    part    = { "part", "get%s+out" },
    ignore  = { "ignore", "disregard" },
    unignore= { "unignore", "listen%s+to" },
    lignore = { "list%s.*ignore", "who'?[sre]-%s.*ignore" },
    identify= { "identify", "i'?%s-a?m" },
    reseed  = { "reseed", "reset%s+the%s+crypto.-seed" },
    quit    = { "shut%s+down", "quit", "disconnect", "die", "go%s+die" },
    version = { "version", "ctcp%s+version", "ask%s+for%s+.*version.*from" },
--    enfunc  = { "enable.*function", "enable.*command" },
--    disfunc = { "disable.*function", "disable.*command" },
    -- The IDB catches are special: the () catches aid in extracting info
    idb_set = {
        "[Ss]et%s+my%s+([^%.,%?]+)to%s+(.-)[%.%?!]-$",
        "[Mm]y%s+([%w%s]+)%sis%s+(.-)[%.%?!]-$"
    },
    idb_get = {
        -- Reverse syntax disabled at the moment; not implemented yet
        --"get%s+t?h?e?%s-(.-)%s+of%s+(%S+)",
        --"what%'?%s-i?s%s+t?h?e?%s+(.-)%s+of%s+(%S+)",
        "what%'?%s-i?s%s+([^%s%']+)%'s%s+(.-)%p-$",
        "what%'?%s-i?s%s+(my)%s+(.-)[%.,%?!]",
        "get%s+(%S+)%'?s?%s+(.-)[%.%?,!]",
        "tell%s+me%s.*(%S+)%'s%s-i?s?%s+(.-)[%.%?,!]",
        "tell%s+me%s.*%s(my)%s-i?s?%s+(.-)[%.%?,!]",
        "give%s+me%s+.*(%S+)%'s%s+i?s?%s-(.-)[%.%?,!]",
    },
    belong  = { "belong.*%sme", ".*%sme%s.*%sown%s+you", ".*%si%s.*own%s+you" },
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
