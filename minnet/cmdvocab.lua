#!/usr/bin/env lua
-- cmdvocab.lua - command vocabulary file for minnet
-- Copyright Stæld Lakorv, 2011-2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file is used as an abstraction layer between the received commands
--  and the actual, known commands. This permits for looser command recognition
--  while avoiding duplicate functions.

-- Syntax: funcname = { "pattern%s+matching%s+the%s+said%s+command" }

bot.commands = {
    say     = { "say" },
    help    = { "help" },
    set     = { "set%s+[^mywch]+" },
    areyou  = { "are%s+you%s-(.*)" },
    load    = { "load", "reload%s.*hook" },
    reload  = { "reload" },
    db      = { "db", "database" },
    join    = { "join", "go%s+to" },
    unload  = { "unload", "remove" },
    part    = { "part", "get%s+out" },
    ignore  = { "ignore", "disregard" },
    remember= {
        "remind%s+me%s+to%s+([^,%.]+)", "remind%s+me%s+that%s+([^,%.]+)",
        "remember%s+that%s+([^,%.]+)", "todo%s+add:?%s+(.+)$", "add%s+todo:?%s+(.+)$",
        "add%s+(.-)%s+to%s+my%s+todo", "todo%s+new:?%s+(.+)$"
    },
    remind  = {
        "what.+%smy%s+todo.*(%d*)", "remind%s+me.*(%d*)", "todo%s+(%d*)",
        "todo%s+read%s-(%d*)", "todo%s+get%s-(%d*)", "read%s.*todo%s*(%d*)"
    },
    forget  = {
        "delete%s.-todo.-(%d+)", "forget%s.-(%d+)", "todo%s+delete%s.-(%d+)",
        "todo%s+forget%s.-(%d+)"
    }
    unignore= { "unignore", "listen%s+to" },
    lignore = { "list%s.*ignore", "who'?[sre]-%s.*ignore" },
    identify= { "identify", "i'?%s-a?m" },
    reseed  = { "reseed", "reset%s+the%s+crypto.-seed" },
    quit    = { "shut%s+down", "quit", "disconnect", "die", "go%s+die" },
    version = { "version", "ctcp%s+version", "ask%s+for%s+.*version.*from" },
    topic   = { "set%s+.*topic%s+[to:]%s+(.+)$", "[new]-%s-topic:?%s+(.+)$" },
    enfunc  = { "enable.*function", "enable.*command" },
    disfunc = { "disable.*function", "disable.*command" },
    -- The IDB catches are special: the () catches aid in extracting info
    idb_set = {
        "set%s+my%s+([^%.,%?]+)to%s+(.-)[%.%?!]-$",
        "my%s+([%w%s]+)%sis%s+(.-)[%.%?!]-$"
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
        "silence", "stay%s+off", "disable%s+[^c]+$" -- Ignore disfunc calls
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
        ".*%sut[øoe]+ya", ".*%soslo", "[howhen]+.*22/7", ".*2011%-07%-22",
        ".*22nd%s+[of%s]*jul[yi]"
    },
    greet  = {  -- FIXME: This is a very suboptimal solution;
                --+ These patterns are now duplicated in cmdvocab and cmdarray
        "o?he?[iy]+a?", "[h']?[ae]llo", "yo", "r[ao]wr2?[you]-", "[h']?errow?",
        "bye", "see%s-y[aou]+", "cya", "sal", "saluton", "g[od%s']+day",
        "g?[od%s']-mor[rownig']+", "eve[nig]-", "afternoon", "'?noon",
        "g[od%s]+[ou]n[e']?", "wi?bs?", "welc[aou]me?%s-back", "greetings",
        "how[s's%-are]-y?[aou]-",
        -- Special catches for greeting as a command:
        "greet%s+([^%s%.%?!,]+)", "say%s+hi%s+to%s+([^%s!%?%.,]+)"
    },
}
-- EOF
