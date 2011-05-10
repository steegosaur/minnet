#!/usr/bin/env lua
-- hacks.lua - file to write hacks for Minnet that will be inserted while running
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3, see ../COPYING

--[[
    Code that does one-time stuff,
    fixes bugs or unwanted situations,
    or just outputs more useful debugging information
    goes here.

    This is executed by calling 'reload hacks',
    which is the safer (albeit more thorough)
    way of injecting Lua code directly into Minnet.

    -Stæld
--]]
