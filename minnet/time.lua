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
time.expressions = {
    yesterday = "-1d", tomorrow = "+1d", today = "+0d"
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
    local mod = { text = m:match("([%+%-][%d:hmd]+)") }
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
        mod.d = tonumber(mod.text:match("^%p(%d+)d"))       -- Days
        mod.h = tonumber(mod.text:match("%d-d?%s-(%d%d?)")) -- Hours
        mod.m = tonumber(mod.text:match("%d%d:?(%d%d)"))    -- Minutes
        mod.vars = { day = 1, month = 1, year = 1970 }      -- 0 seconds

        -- Modifiers for day, hour and minute
        if mod.d and mod.op == "+" then
            mod.vars.day = mod.vars.day - mod.d
        elseif mod.d and mod.op == "-" then
            mod.vars.day = mod.vars.day + mod.d
        end
        if mod.h and mod.op == "+" then
            mod.vars.hour = 1 - mod.h
        elseif mod.h and mod.op == "-" then
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

-- time.calculate(): New time calculation algorithm, trying to fix what just
--+ doesn't work with the previous one, in a simpler way (hopefully)
function time.calculate(t, dump)
    -- t is a time difference as returned by os.difftime();
    --+ on POSIX and Windows systems, this amounts to a seconds count. We take
    --+ advantage of this, and simply count how many weeks, days etc. are in
    --+ that count.
    local d = { seconds = t, weeks = 0, day = 0, hour = 0, min = 0 }
    while d.seconds >= 604800 do -- This is the amount of seconds in a week
        d.weeks = d.weeks + 1
        d.seconds = d.seconds - 604800
    end
    -- Now we've subtracted all the weeks contained; next up: the days
    while d.seconds >= 86400 do
        d.day = d.day + 1
        d.seconds = d.seconds - 86400
    end
    -- Hours:
    while d.seconds >= 3600 do
        d.hour = d.hour + 1
        d.seconds = d.seconds - 3600
    end
    -- Aaaand minutes:
    while d.seconds >= 60 do
        d.min = d.min + 1
        d.seconds = d.seconds - 60
    end
    if dump == true then return d end
    local ending = { weeks = "", day = "", hour = "", min = "" }
    for _, unit in ipairs({ "weeks", "day", "hour", "min" }) do
        if d[unit] > 1 then
            ending[unit] = "s"
        end
    end
    local weeks, days, hours, mins
    local pre = ""
    local prev = 0
    if d.weeks > 0 then
        weeks = d.weeks .. " week" .. ending.weeks
        prev = d.weeks
    else
        weeks = ""
    end
    if d.day > 0 then
        if weeks ~= "" and ( d.hour > 0 or d.min > 0 ) then
            pre = ", "
        elseif days ~= "" and ( d.hour <= 0 or d.min <= 0 ) then
            pre = " and "
        else
            pre = ""
        end
        days = pre .. d.day .. " day" .. ending.day
        prev = d.day
    else
        days = ""
    end
    if d.hour > 0 then
        if days ~= "" and d.min > 0 then
            pre = ", "
        elseif days ~= "" and d.min <= 0 then
            pre = " and "
        end
        hours = pre .. d.hour .. " hour" .. ending.hour
        prev = d.hour
    else
        hours = ""
    end
    if d.min > 0 then
        if weeks ~= "" or days ~= "" or hours ~= "" then
            pre = " and "
        else
            pre = ""
        end
        mins = pre .. d.min .. " minute" .. ending.min
    else
        mins = ""
    end
    return weeks, days, hours, mins
end

function time.get_date(text)
    local result, array
    local now = os.date("*t")
    local format = "%.4d-%.2d-%.2d"
    -- Check if it's a known, simple expression
    for e, mod in pairs(time.expressions) do
        if text:match(e) then
            array = time.get_current(mod)
        end
    end
    -- Raw date?
    local date = text:match("(%d%d%d%d%-%d%d%-%d%d)")
    if date then return date end
    -- Weekday based?
    local weekday = text:match("(%a+day)")
    if weekday and not array then
        local futpast
        local tenses = {
            past = { "[lp]ast", "previous" },
            fut = { "next", "coming" }
        }
        for tense, words in pairs(tenses) do
            for _, word in ipairs(words) do
                if text:match(word .. "%s+%a+day") then
                    futpast = tense
                end
            end
        end
        if not futpast then return nil end
        for number, day in ipairs(time.wdays.long) do
            if weekday:lower() == day:lower() then
                local diff = number - now.wday
                if futpast == "past" then
                    if diff >= 0 then
                        diff = diff - 7
                    elseif diff < -7 then
                        diff = diff + 7
                    end
                elseif futpast == "fut" then
                    if diff <= 0 then
                        diff = diff + 7
                    elseif diff > 7 then
                        diff = diff - 7
                    end
                end
                local secs = 3600 * 24 * diff
                local then_time
                if tense == "past" then
                    then_time = os.time() - secs
                else then_time = os.time() + secs end
                array = os.date("*t", then_time)
            end
        end
    end
    if array then
        result = format:format(array.year, array.month, array.day)
    else result = nil end
    return result
end

-- Command plugins
bot.commands.time = {
    "what'?%s-i?s%s+.*%s+time", "what'?%s-i?s%s+.*%s+clock", "time",
    "what%stime'?%s-i?s'?%s-it" }
bot.commands.uptime = { "how%s+long", "for%s+how%s+long", "what'?s?%s+.*uptime.*", "uptime" }
bot.commands.timezones = {
    "what.*timezones", "list.*timezones", "timezone%s+list", "how.*timezones",
    "which.*timezones" }
bot.commands.twentytwo_seven = {
    ".*%sut[øoe]+ya", ".*%soslo", "[howhen]+.*22/7", ".*2011%-07%-22",
    ".*22nd%s+[of%s]*jul[yi]" }

cmdlist.time = {
    help = "Want to know what the time is?",
    func = function(u, chan, m)
        local response = "%s: The time is currently %.2d:%.2d:%.2d %s, " ..
            "%s %.4d-%.2d-%.2d."
        local now, tz = time.get_current(m)
        if tz == "unknown" then
            send(chan, u.nick .. ": Sorry, I don't know that timezone.")
            return nil
        elseif not now then
            return nil
        end
        send(chan, response:format(u.nick, now.hour, now.min, now.sec, tz,
            time.wdays.short[now.wday], now.year, now.month, now.day))
    end
}
cmdlist.timezones = {
    help = "Want a list of the timezones I know?",
    func = function(u, chan, m)
        local tzs = time.timezones
        table.sort(tzs)
        local list, i = {}, 1
        for zone in pairs(tzs) do
            if not list[1] then
                list[1] = u.nick .. ": The timezones I know are:"
                i = i + 1
            end
            if not list[i] then
                list[i] = zone
            elseif list[i] and string.len(list[i] .." ".. zone) < 81 then
                list[i] = list[i] .. " " .. zone
            elseif list[i] and string.len(list[i] .." ".. zone) > 80 then
                i = i + 1
                list[i] = zone
            end
        end
        log("Outputting timezone list to " .. chan, u, "debug")
        for i, line in ipairs(list) do
            send(chan, line)
        end
    end
}
cmdlist.twentytwo_seven = {
    help = "The worst tragedy in Norwegian history - how long has it been?",
    func = function(u, chan, m)
        local when = {
            -- Times have been converted to UTC (local time was +2h)
            year  = 2011,
            month = 7,
            day   = 22,
            oslo  = { hour = 13, min = 26 },
            utoya = { hour = 15, min = 15 }
        }
        m = m:lower()
        local now = os.time(time.get_current(" UTC"))
        local incident, incident_time, inc_var
        if m:match("ut[oøe]+ya") then
            incident, inc_var = "Utøya", "utoya"
        elseif ( m:match("oslo") or m:match("norway")) and m:match("bomb") then
            incident, inc_var = "Oslo",  "oslo"
        end
        if incident then
            incident_time = os.time({ year = when.year, month = when.month,
                day = when.day, hour = when[inc_var].hour,
                min = when[inc_var].min })
            local diff = os.difftime(now, incident_time)
            local weeks, days, hours, mins = time.calculate(diff)
            local re_pattern = "%s: It has been %s%s%s%s since the %s " ..
                "attack, which occured at %.4d-%.2d-%.2d, %.2d:%.2d UTC."
            local response = re_pattern:format(u.nick, weeks, days, hours,
                mins, incident, when.year, when.month, when.day,
                when[inc_var].hour, when[inc_var].min)
            send(chan, response)
        else
            send(chan, u.nick .. ": Pardon, what did you say?")
        end
    end
}
cmdlist.uptime = {
    help = "Report uptime of server or connection.",
    func = function(u, chan, m)
        m = m:lower()
        if
         (
          (
           m:match("online") or m:match("%s+up[%s%p]+") or
           m:match("uptime") or m:match("connected") or m:match("running")
          ) and
          (
           m:match("you") or m:match("ya%s") or m:match("yer%s")
          ) and not
          ( m:match("system") or m:match("computer") or m:match("server") )
         )
        then
            local diff = os.difftime(os.time(), bot.start)
            local weeks, days, hours, mins = time.calculate(diff)
            if weeks == "" and days == "" and hours == "" and mins == "" then
                send(chan, u.nick .. ": I just got online!")
            else
                send(chan, u.nick .. ": I've been online for " ..
                    weeks .. days .. hours .. mins .. ".")
            end
        elseif
         (
          (
           m:match("%s+up[%s%p]+") or m:match("uptime") or m:match("online") or m:match("running")
          ) and
          (
           m:match("system") or m:match("server") or m:match("computer") or
           m:match("host")
          )
         )
        then
            local r = { "system", "server", "computer" }
            local sysword = r[math.random(1, #r)]
            -- Read standard GNU/Linux uptime file
            -- TODO: Make this cross-platform by implementing Windows alternative too?
            local uptime_file = io.open("/proc/uptime")
            if not uptime_file then
                log("/proc/uptime unavailable, skipping uptime reporting", "trivial")
                send(chan, "Sorry, but I couldn't find the uptime.")
                return nil
            end
            local utime = uptime_file:read()
            uptime_file:close()
            utime = tonumber(utime:match("^(%d+)%.%d%d%s+"))
            local weeks, days, hours, mins = time.calculate(utime)
            if weeks == "" and days == "" and hours == "" and mins == "" then
                send(chan, u.nick .. ": It was just booted!")
            else
                send(chan, u.nick .. ": The " .. sysword .. " went up " ..
                    weeks .. days .. hours .. mins .. " ago.")
            end
        else
            send(chan, "Err, what?")
            log("Could not recognise enough keywords for uptime command, ignoring", "trivial")
        end
    end
}

-- EOF
