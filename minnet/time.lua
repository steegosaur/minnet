#!/usr/bin/env lua
-- time.lua - time-related functions and data for minnet
-- Copyright Stæld Lakorv, 2011-2012 <staeld@illumine.ch>
-- This file is part of Minnet.
-- Minnet is released under the GPLv3 - see ../COPYING

-- This file contains various commands, functions and tables that relate to
--  time calculations and the likes, as these are generally quite space-hogging
time = {}
time.wdays = {  -- Days of the week, Sun first; used with os.date("*t").wday
    short = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
    long  = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
        "Saturday" }
}
time.timezones = {
    GMT = "+0", UTC = "+0", WET = "+0",
    BST = "+1", CET = "+1", DFT = "+1", IST = "+1", WAT = "+1", WEDT = "+1",
    WEST = "+1",
    CAT = "+2", CEDT = "+2", CEST = "+2", EET = "+2", SAST = "+2",
    EAT = "+3", EEDT = "+3", EEST= "+3", IDT = "+3", MSK = "+3",
    IRST = "+0330",
    AMT = "+4", AZT = "+4", GET = "+4", GST = "+4", MSD = "+4", MUT = "+4",
    RET = "+4", SAMT = "+4", SCT = "+4", AFT = "+0430",
    AMST = "+5", HMT = "+5", PKT = "+5", YEKT = "+5", IST = "+0530",
    SLT = "+0530", NPT = "+0545",
    BIOT = "+6", BTT = "+6", OMST = "+6", UT = "+6", XT = "+6", XUT = "+6",
    CCT = "+0630",
    CXT = "+7", ICT = "+7", KRAT = "+7", THA = "+7",
    ACT = "+8", AWST = "+8", BDT = "+8", BT = "+8", CT = "+8", HKT = "+8",
    IRKT = "+8", MST = "+8", MYT = "+8", SGT = "+8", SST = "+8", WST = "+8",
    AWDT = "+9", JST = "+9", KST = "+9", YAKT = "+9", ACST = "+0930",
    AEST = "+10", CHST = "+10", VLAT = "+10", ACDT = "+1030", LHST = "+1030",
    AEDT = "+11", MAGT = "+11", SBT = "+11", NFT = "+1130",
    FJT = "+12", GILT = "+12", NZST = "+12", PETT = "+12", CHAST = "+1245",
    NZDT = "+13", PHOT = "+13", CHADT = "+1345",
    LINT = "+14",
    AZOST = "-1", CVT = "-1",
    GST = "-2", UYST = "-2", NDT = "-0230",
    ADT = "-3", ART = "-3", BRT = "-3", CLST = "-3", FKST = "-3", GFT = "-3",
    UYT = "-3", NST = "-0330", NT = "-0330",
    AST = "-4", BOT = "-4", CLT = "-4", COST = "-4", ECT = "-4", EDT = "-4",
    FKT = "-4", GYT = "-4", VET = "-0430",
    CDT = "-5", COT = "-5", ECT = "-5", EST = "-5",
    CST = "-6", EAST = "-6", GALT = "-6", MDT = "-6",
    MST = "-7", PDT = "-7",
    AKDT = "-8", CIST = "-8", PST = "-8",
    AKST = "-9", GIT = "-9", HADT = "-9", MIT = "-0930",
    CKT = "-10", HAST = "-10", HST = "-10", TAHT = "-10",
    SST = "-11", BIT = "-12"
}

-- time.get_current(): Analyse string m (user-input) to determine time and zone
--  Also returns local time and zone w/out input or by unspecified input
function time.get_current(m)
    if not m then return os.date("*t"), os.date("%z") end
    local now, tz
    local nonnum = false
    local mod = { text = m:match("([%+%-]%d%d?:?%d?%d?)") }
    if not mod.text then
        for zone, value in pairs(time.timezones) do
            if m:match("%W" .. zone) then
                tz       = zone
                mod.text = value
                nonnum   = true
                break
            end
        end
    end
    if nonnum == false and m:match("%s%u%u%u[%.%?!,%)%]%s]") then
        return nil, "unknown"
    end
    if mod.text then
        mod.op = mod.text:match("^([%+%-])")    -- Add or subtract?
        mod.h = tonumber(mod.text:match("^%p(%d%d?)"))      -- Hours
        mod.m = tonumber(mod.text:match("^%p%d%d:?(%d%d)")) -- Minutes
        mod.vars = { day = 1, month = 1, year = 1970 }      -- 0 seconds

        -- Modifiers for hour and minute
        if mod.op == "+" then
            mod.vars.hour = 1 - mod.h
        elseif mod.op == "-" then
            mod.vars.hour = 1 + mod.h
        end
        if mod.m and mod.op == "+" then
            mod.vars.min = 0 - mod.m
        elseif mod.m and mod.op == "-" then
            mod.vars.min = 0 + mod.m
        end

        local timediff = os.time(mod.vars)
        local localtime = os.difftime(os.time(), timediff)
        now = os.date("!*t", localtime)
        if nonnum ~= true then tz = mod.text end
    else
        now = os.date("*t")
        tz = tostring(os.date("%z"))
    end
    return now, tz
end

-- time.calculate(): Calculate the amount of weeks, days, hours and minutes
--+ a given timediff contains; this expects Unix behaviour
function time.calculate(t, utc)
    local length
    if utc then
        length = os.date("!*t", t)
    else
        length = os.date("*t", t)
    end
    length.weeks = 0
    -- Subtract Unix epoch values
    length.day, length.hour = length.day - 1, length.hour - 1
    length.month, length.year = length.month - 1, length.year - 1970
    -- Calculate weeks
    while length.day > 6 do
        length.day = length.day - 7
        length.weeks = length.weeks + 1
    end
    local ending = { weeks = "", day = "", hour = "", min = "" }
    if length.weeks ~= 1 then ending.weeks = "s" end
    if length.day   ~= 1 then ending.day   = "s" end
    if length.hour  ~= 1 then ending.hour  = "s" end
    if length.min   ~= 1 then ending.min   = "s" end
    local weeks, days, hours, mins
    local pre = ""
    local prev = 0
    if length.weeks > 0 then
        weeks = length.weeks .. " week" .. ending.weeks
        prev = length.weeks
    else
        weeks = ""
    end
    if length.day > 0 then
        if weeks ~= "" and ( length.hour > 0 or length.min > 0 ) then
            pre = ", "
        elseif days ~= "" and ( length.hour <= 0 or length.min <= 0 ) then
            pre = " and "
        else
            pre = ""
        end
        days = pre .. length.day .. " day" .. ending.day
        prev = length.day
    else
        days = ""
    end
    if length.hour > 0 then
        if days ~= "" and length.min > 0 then
            pre = ", "
        elseif days ~= "" and length.min <= 0 then
            pre = " and "
        end
        hours = pre .. length.hour .. " hour" .. ending.hour
        prev = length.hour
    else
        hours = ""
    end
    if length.min > 0 then
        if weeks ~= "" or days ~= "" or hours ~= "" then
            pre = " and "
        else
            pre = ""
        end
        mins = pre .. length.min .. " minute" .. ending.min
    else
        mins = ""
    end
    return weeks, days, hours, mins
end
-- EOF
