#!/usr/bin/env lua
-- hacks.lua - file to write hacks for Minnet that will be inserted while running
-- Copyright Stæld Lakorv, 2011 <staeld@staeld.co.cc>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3, see ../COPYING

local list = ""
for i, e in pairs(logs) do
    list = tostring(e) .. " "
end
send("#fire_island", list)
