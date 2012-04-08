#!/usr/bin/env lua
-- serv.lua - service functions for minnet
-- Copyright Stæld Lakorv, 2010-2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file will provide basic Services functionality to Minnet
--+ including nick protection

-- Currently, this is merely a draft and not actually working

-- Do not do anything if not providing Services
if bot.ownServices.enabled == false then
    return nil
end
ident = { warned = {}, }

-- ident.warn(u): warn 'u' about not having identified
function ident.warn(u)
    send(u.nick, "Hey, you haven't identified yet! Get to it!")
    log("Warned " .. u.nick .. " about identifying", "debug")
    ident.warned[u.nick] = true
end

-- ident.sanction(u): sanction or warn 'u' if not identified
--+ This calls ident.warn() if applicable
function ident.sanction(u)
    if ident.warned[u.nick] then
        send(u.nick, "Sorry, but you didn't listen.")
        log("Sanctioning " .. u.nick .. " for not identifying", "trivial")
        renick(u.nick)  -- Abstracting function; needs implementation
    else
        -- User hasn't been warned, so do so
        ident.warn(u)
    end
end

