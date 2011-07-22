#!/usr/bin/env lua
-- hooks.lua - hook register for Minnet
-- Copyright Stæld Lakorv, 2010-2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING
hooks = {
    {   -- Hook for replying to "don't worry, be happy" lines
        event   = "OnChat",
        name    = "happy",
        action  = function(u, chan, m)
            if check_disabled(chan) == true then return nil end
            if ( chan == conn.nick ) then chan = u.nick end
            m = m:lower()
            if m:match("^don'?t%s+worry%p?%s-be%s+happy") or m:match("^be%s+happy%p?%s-don'?t%s+worry") then
                ctcp.action(u, chan, "doesn't worry, is happy! :D")
            end
        end
    },
    {
        event   = "OnChat",
        name    = "logchat",
        action  = function(u, chan, m)
            if ( chan == conn.nick ) then
                chan = u.nick
            end
            m = desat(m)
            logchat(u, chan, m)
        end
    },
    {
        event   = "OnJoin",
        name    = "logjoin",
        action  = function(u, chan)
            lognote(u, chan, "[" .. u.username .. "@" .. u.host .. "]", "<--")
        end
    },
    {
        event   = "OnPart",
        name    = "logpart",
        action  = function(u, chan)
            lognote(u, chan, "[" .. u.username .. "@" .. u.host .. "]", "-->")
        end
    },
    {
        event   = "OnKick",
        name    = "logkick",
        action  = function(chan, nick, k, r)
            if not ( nick:lower() == conn.nick:lower() ) then
                local u = conn:whois(nick).userinfo
                u.nick     = nick
                u.username = u.username or "user"
                u.host     = u.host     or "host"
                lognote(u, chan, "[" .. u.username .. "@" .. u.host .. "] was kicked by " .. k.nick .. " (" .. r .. ")", "-->")
            end
        end
    },
    --[[
    {
        event   = "OnQuit",
        name    = "logquit",
        action  = function(u, msg)
            lognote(u, chan, "[" .. u.username .. "@" .. u.host .. "] ", "-->")
        end
    }, --]]
    {   -- Main hook for command reading
        event   = "OnChat",
        name    = "wit",
        action  = function(u, chan, m)
            m = desat(m)
            local ismsg = false
            if ( chan:lower() == conn.nick:lower() ) then ismsg = true; chan = u.nick end
            if ( ismsg == true ) or m:lower():match("^" .. conn.nick:lower() .. "%s-[,:]%s+") then
                wit(u, chan, m)
            end
        end
    },
    {   -- Hook for ctcp parsing
        event   = "OnRaw",
        name    = "ctcpRead",
        action  = function(l) ctcp.read(l) end
    },
    {
        event   = "OnKick",
        name    = "rejoin",
        action  = function(chan, nick, k, r)
            if ( nick:lower() == conn.nick:lower() ) then
                log("Kicked from channel " .. chan, k, "info")
                if not channel_remove(chan) then
                    log("Error: Could not remove channel " .. chan ..
                      " from table bot.nets[" .. n  .. "].joined (" ..
                      net.name .. ")", "warn")
                end
                --if not db.check_auth(k, "oper") then
                    conn:join(chan)
                    channel_add(chan)
                --end
            else
                if check_disabled(chan) == true then return nil end
                send(chan, "o/` Another one bites the dust, oh - " ..
                  "another one bites the dust! o/`")
            end
        end
    },
    {   -- Be a lil' polite, will ya?
        event   = "OnChat",
        name    = "greet",
        action  = function(u, chan, m)
            if check_disabled(chan) == true then return nil end
            if ( chan == conn.nick ) then chan = u.nick end
            m = m:lower()
            if not m:match(conn.nick:lower()) then return nil end
            local g = {
                hei = { "hei", "[h']?allo" },
                hi  = { "[h']?ello", "o?h[ae]?[iy][2%a]-", "yo",
                    "r[ao]wr2?[you]-", "[h']?errow?"
                },
                bye = { "bye%s?", "see%s-y[aou]+", "cya" },
                sal = { "sal", "saluton" },
                tim = { "g[od%s']+day", "g?[od%s']-mor[rownig']+", "eve[nig]-",
                    "afternoon", "g[od%s]+[ou]n[e']?"
                },
                nite= { "[god%s']-nigh?h?te?" },
                wb  = { "wi?bs?", "welc%ame?%s-back" },
                how = { "how[%s's%-are]-y?[aou]-d?o?i?n?g?" },
            }
            local r = {
                hi  = { "Hi", "Hello", "Hey", "'Ello" },
                bye = { "Bye", "Good bye", "G'bye", "See ya", "See you" },
                sal = { "Sal", "Saluton" },
                hei = { "Hei", "Hallo" },
                nite= { "G'nite", "Good night", "Night" },
                wb  = { "Thanks" },
                morning = { "G'morrow", "Good morning", "Morning" },
                day = { "G'day", "Good day" },
                eve = { "Good evening", "Eve" },
                noon= { "Good afternoon" },
                how = { "I'm fine thanks", "I'm good", "All's well with me",
                    "Eh, I'm alright", "I'm doing fine", "Meh, could've been better",
                    "Well - I am"
                },
            }
            local wordFound = false
            for name, t in pairs(g) do
            for i, pattern in ipairs(t) do
                if m:match(pattern .. "[%s%p]+" .. conn.nick:lower()) then
                    local word

                    if ( name == "tim" ) then  -- What time is it?
                        local hour = time.get_current().hour
                        if ( hour < 12 ) and ( hour >= 4 ) then
                            word = r.morning[math.random(1, #r.morning)]
                        elseif ( hour < 4 ) or ( hour >= 20 ) then
                            word = r.eve[math.random(1, #r.eve)]
                        elseif ( hour >= 12 ) and ( hour < 16 ) then
                            word = r.day[math.random(1, #r.day)]
                        elseif ( hour >= 16 ) and ( hour < 20 ) then
                            word = r.noon[math.random(1, #r.noon)]
                        else -- How the hell did we get here?
                            log("Out of cheese in time calculation for greeting hook - time is " .. tostring(hour), "warn")
                            word = "Hello" -- Safe fallback in case of fuckup
                        end
                    elseif ( name == "how" ) then
                        local now = os.time()
                        local diff = os.difftime(now, howdoTime[chan]) or 200
                        if ( diff < 60 ) then
                            log("Was asked for feelings <60s ago, grumbling..", u, "debug")
                            local grbl = {
                                "I just said", "You must be deaf",
                                "You oughta have heard the first time",
                            }
                            word = grbl[math.random(1, #grbl)]
                        elseif ( diff < 120 ) then
                            log("Was asked for feelings <120s ago, repeating..", u, "debug")
                            word = "I said like a minute ago. " .. r[name][wordNum]
                        else
                            howdoTime[chan] = os.time()
                            wordNum = math.random(1, #r[name])
                            word = r[name][wordNum]
                        end
                    elseif ( name == "hi" ) then
                        word = r[name][math.random(1, #r[name])]
                        if ( math.random(1, 8 ) < 3 ) then
                            word = word .. " there"
                        end
                    elseif ( name == "hei" ) then
                        word = r[name][math.random(1, #r[name])]
                        if ( math.random(1, 8 ) < 3 ) then
                            word = word .. " der"
                        end
                    else
                        word = r[name][math.random(1, #r[name])] or "'Ello"
                    end
                    if word then
					    wordFound = true
					end
                    send(chan, word .. ", " .. u.nick .. ".")
                    log("Greeted " .. u.nick .. " in channel " .. chan, "debug")
                    return nil
                end
            end -- per-word
            end -- per-class
        end
    },
    --[[
    {
        event   = "OnRaw",
        name    = "dump",
        action  = function(m)
            io.write(m, "\n")
        end
    } --]]
}
