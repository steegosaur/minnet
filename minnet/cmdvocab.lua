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
    say     = { "say"  },
    help    = { "help" },
    set     = { "set%s+%w+%s+%w-%s-to%s+(.+)$", "set%s+the%s+%w+%s+%w-%s-to+%s+(.+)$" },
    areyou  = { "are", "do", "does", "will", "am", "can", "could" },
    load    = { "load", "reload%s.*hook" },
    unload  = { "unload", "remove" },
    reload  = { "reload" },
    join    = { "join", "go%s+to" },
    part    = { "part", "get%s+out", "go%s+away" },
    ignore  = { "ignore", "disregard" },
    unignore= { "unignore", "listen%s+to" },
    lignore = { "list%s.*ignore", "who'?[sre]-%s.*ignore" },
    reseed  = { "reseed", "reset%s+the%s+crypto.-seed" },
    quit    = { "shut%s+down", "quit", "disconnect", "die", "go%s+die" },
    version = { "version", "ctcp%s+version", "ask%s+for%s+.*version.*from" },
    topic   = { "[Nn]ew%s+topic:?%s+(.+)$", "[Tt]opic:?%s+(.+)$" },
    -- topic_edit: intended like ‘edit topic: ^(.-:) %w+ | @ %1 newword’, uses Lua string patterns
    topic_edit = { "[Ee]dit%s+topic%s+(#%w+):?%s*(.*)%s@@%s(.*)$", "[Ee]dit%s+topic:?%s+(.*)%s@@%s(.*)$" },
    enfunc  = { "enable.*function", "enable.*command" },
    disfunc = { "disable.*function", "disable.*command" },
    belong  = { "belong.*%sme", ".*%sme%s.*%sown%s+you", ".*%si%s.*own%s+you" },
    owner   = {
        "who.*'?i?s%s+y[aoue]+r.*%s+owner", "who.*%sowns?%s+y[aoue]+",
        "be%s+mine", "be%s+my"
    },
    disable = {
        "shut%s-up", "shaddap", "keep%s+quiet", "be%s+quiet", "stay%s+quiet",
        "silence", "stay%s+off", "disable%s+[^fc]", -- Ignore disfunc calls
        "quiet", "s+h+"
    },
    be      = { "be%s+" },
    enable  = {
        "y[oua]+'?re?%s+free", "speak", "r?e?%-?enable", "unsilence",
        "live", "go%s+on"
    },
    reidentify = {
        "talk%s+[towih]+%s+nickserv", "go%s+identify", "nickserv",
        "re%-?identify"
    },
    greet  = {  -- FIXME: This is a very suboptimal solution;
                --+ These patterns are now duplicated in cmdvocab and cmdarray
        "o?he?[iy]+a?", "[h']?[ae]llo", "yo[^u]", "r[ao]wr2?[you]-", "[h']?errow?",
        "bye", "see%s-y[aou]+", "cya", "sal", "saluton", "g[od%s']+day",
        "g?[od%s']-mor[rownig']+", "eve[nig]-", "afternoon", "'?noon",
        "g[od%s]+[ou]n[e']?", "wi?bs?", "welc[aou]me?%s-back", "greetings",
        "how['s%sare]+y[aou]+",
        -- Special catches for greeting as a command:
        "greet%s+([^%s%.%?!,]+)", -- "say%s+hi%s+to%s+([^%s!%?%.,]+)"
    },
}
-- EOF
