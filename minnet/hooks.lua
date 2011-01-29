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
            if ( chan == conn.nick ) then chan = u.nick end
            m = m:lower()
            if m:match("^don'?t%s+worry%p?%s-be%s+happy") or m:match("^be%s+happy%p?%s-don'?t%s+worry") then
                ctcp.action(chan, "doesn't worry, is happy! :D")
            end
        end
    },
    --[[
    {
        event   = "OnChat",
        name    = "debug",
        action  = function(u, chan, m)
            print(u.nick, chan, m)
        end
    }, --]]
    {   -- Main hook for command reading
        event   = "OnChat",
        name    = "wit",
        action  = function(u, chan, m)
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
    {   -- Be a lil' polite, will ya?
        event   = "OnChat",
        name    = "greet",
        action  = function(u, chan, m)
            if ( chan == conn.nick ) then return nil end
            m = m:lower()
            if not m:match(conn.nick:lower()) then return nil end
            local g = { "[hj']?ello", "o?hi", "o?hey", "[h']?allo", "hei",
                "sal[uton]-", "yo", "g[od%s']+day", "mor[rnigow]+", "o?hai",
                "eve[ning]-", "afternoon", "g[od%s]+[ou]n[e']?",
                "greetin[g']s", "g[od%s]+nig?h?te?"
            }
            local r = {
                hi  = { "Hi", "Hello", "Hey" },
                sal = { "Sal", "Saluton" },
                hei = { "Hei", "Hallo" },
                nite= { "G'nite", "Good night", "Night" }
            }
            for i = 1, #g do
                if m:match("^%S-%s-%S-%s-" .. g[i] .. "[%s%p]+" .. conn.nick:lower()) then
                    local word
                    if i == 1 or i == 2 or i == 3 or i == 7 or i == 10 or i == 14 then
                        local num = math.random(1, #r.hi)
                        word = r.hi[num]
                    elseif i == 4 or i == 5 then
                        local num = math.random(1, #r.hei)
                        word = r.hei[num]
                    elseif i == 6 then
                        local num = math.random(1, #r.sal)
                        word = r.sal[num]
                    elseif i == 15 then
                        local num = math.random(1, #r.nite)
                        word = r.nite[num]
                    elseif i == 8 or i == 9 or i == 11 or i == 12 or i == 13 then
                        local hour = tonumber(os.date("%H"))
                        if ( hour < 12 ) and ( hour >= 4 ) then
                            word = "G'morrow"
                        elseif ( hour < 4 ) or ( hour >= 20 ) then
                            word = "Good evening"
                        elseif ( hour >= 12 ) and ( hour < 16 ) then
                            word = "G'day"
                        elseif ( hour >= 16 ) and ( hour < 20 ) then
                            word = "Good afternoon"
                        else
                            log("Out of cheese in time calculation for greeting hook!", "error")
                            word = "Hello" -- Safe fallback in case of fuckup
                        end
                    else
                        word = "'Ello"
                    end
                    send(chan, word .. ", " .. u.nick .. ".")
                    log("Greeted " .. u.nick .. " in channel " .. chan .. " on net " .. net.name, "debug")
                end
            end
        end
    }, --]]
}
