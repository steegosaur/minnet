#!/usr/bin/env lua
-- hooks.lua - hook register for Minnet
-- Copyright Stæld Lakorv, 2010-2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING
hooks = {
    {   -- Hook for replying to "don't worry, be happy" lines
        event   = "OnChat",
        name    = "happy",
        action  = function(u, chan, m)
            -- Make sure the message is supposed to be heard
            if is_ignored(u, chan, true) or check_disabled(chan) == true then
                return nil
            end
            if chan == conn.nick then chan = u.nick end
            -- Remove colours and make lowercase:
            m = desat(m):lower()
            if m:match("^don'?t%s+worry%p?%s-be%s+happy")
              or m:match("^be%s+happy%p?%s-don'?t%s+worry") then
                log("Triggered hook 'happy'", "internal")
                ctcp.action(u, chan, "doesn't worry, is happy! :D")
            end
        end
    },
    {
        -- Ownership hook, for imitating common ownership scripts
        event   = "OnChat",
        name    = "own",
        action  = function(u, chan, m)
            if is_ignored(u, chan, true) or
              check_disabled(chan, "belong") == true then
                return nil
            end
            m = desat(m):lower()
            if m:match("^!" .. conn.nick:lower()) then
                log("Triggered hook 'own'", u, "internal")
                cmdlist.belong.func(u, chan) -- Call function from cmdarray.lua
            end
        end
    },
    {
        -- Chat logging hook, responsible for logging general channel activity
        event   = "OnChat",
        name    = "logchat",
        action  = function(u, chan, m)
            if chan == conn.nick then
                chan = u.nick
            end
            m = desat(m) -- Not lowercase: could screw intentional formatting
            if m:match("^[^%l%s]-ACTION") then
                m = m:gsub("^[^%l%s]-ACTION%s+", "") -- Remove the ACTION part
                lognote(u, chan, m, "*")    -- Log as action
            else
                logchat(u, chan, m)         -- Log as chat message
            end
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
            local u = conn:whois(nick).userinfo
            if not u then u = {} end
            u.nick     = nick
            u.username = u[3] or "user"
            u.host     = u[4] or "host"
            local entry = "[%s@%s] was kicked by %s (%s)"
            locnote(u, chan, entry:format(u.username, u.host, k.nick, r), "-->")
        end
    },
    --[[ Disabled due to lack of channel information, which makes it hard to log
    {
        event   = "OnQuit",
        name    = "logquit",
        action  = function(u, msg)
            lognote(u, chan, "[" .. u.username .. "@" .. u.host .. "] (" .. msg .. ")", "-->")
        end
    }, --]]
    {   -- Main hook for command reading
        event   = "OnChat",
        name    = "wit",
        action  = function(u, chan, m)
            m = desat(m)
            local ismsg = false
            -- Check if this is a query message; if true, reply in query
            if chan:lower() == conn.nick:lower() then ismsg = true; chan = u.nick end
            -- Criteria for a message to be a command:
            --+ query, nick prepended or nick appended
            if ismsg == true
              -- TODO: Sync these patterns with the one used in funcs.lua for wit()
              or m:lower():match("^" .. conn.nick:lower() .. "%s-[,:;%-]%s+")
              or m:lower():match("[,]+%s-" .. conn.nick:lower() .. "[%.%?!%s]*$") then
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
            if nick:lower() == conn.nick:lower() then
                log("Kicked from channel " .. chan, k, "warn")
                if not channel_remove(chan) then
                    log("Error: Could not remove channel " .. chan ..
                      " from table bot.nets[" .. n  .. "].joined (" ..
                      net.name .. ")", "warn")
                end
                -- We'll just rejoin, since someone who would actually be
                --+ authorised to make us leave should just use the 'part' cmd
                conn:join(chan)
                channel_add(chan)
            else
                -- Someone else was kicked; check if silenced, else respond
                if check_disabled(chan) == true then return nil end
                log("Triggered OnKick hook for other nick", "internal")
                send(chan, "o/` Another one bites the dust, oh - " ..
                  "another one bites the dust! o/`")
            end
        end
    },
    --[[ Extreme debug: dump all input completely raw
    {
        event   = "OnRaw",
        name    = "dump",
        action  = function(m)
            io.write(m, "\n")
        end
    } --]]
}
