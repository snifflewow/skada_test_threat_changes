-- Run from the repository root with Lua 5.1: luajit tests/threat.lua
-- Exercises the real module with mocked WoW APIs; no game client required.
local clock, warnings = 0, 0
local units, threats, frames, timers, events = {}, {}, {}, {}, {}
local members = {}
local mode, options
local L = setmetatable({}, {__index = function(_, key) return key end})
local function wipe(t)
	for key in pairs(t) do t[key] = nil end
end
local function noop() end
local Skada = {
	Private = {
		guidToClass = {},
		UnitFullName = function(unit, owner)
			return owner and units[unit].name .. " <" .. units[owner].name .. ">" or units[unit].name
		end
	},
	inCombat = true,
	current = {GetTime = function() return 10 end},
	options = {args = {modules = {args = {}}}},
	cropTable = {},
	GetUnitRole = noop,
	GetUnitSpec = noop,
	RegisterBucketEvent = noop,
	RegisterCallback = noop,
	RegisterMessage = noop,
	UnregisterAllBuckets = noop,
	UnregisterAllCallbacks = noop,
	UnregisterAllMessages = noop,
	AddFeed = noop,
	RemoveFeed = noop,
	AddMode = noop,
	RemoveMode = noop,
	MediaList = function() return {} end,
	FormatName = function(_, name) return name end,
	FormatPercent = function(_, value) return string.format("%.1f%%", value) end,
	FormatValueCols = function(_, threat, tps, percent) return percent or threat or tps end,
	GroupIterator = function(callback, ...)
		for _, member in ipairs(members) do callback(member[1], member[2], ...) end
	end,
	RegisterEvent = function(_, event) events[event] = true end,
	UnregisterAllEvents = function() wipe(events) end,
	ScheduleRepeatingTimer = function(_, method, interval)
		timers[method] = interval
		return method
	end,
	CancelTimer = function(_, timer) timers[timer] = nil end
}
function Skada:NewModule()
	mode = {localeName = "Threat"}
	return mode
end
function Skada:RegisterModule(_, callback)
	options = self.options.args
	callback(L, {}, {}, {}, {}, options)
end

local env = setmetatable({
	UnitExists = function(unit) return units[unit] ~= nil end,
	UnitName = function(unit) return units[unit] and units[unit].name end,
	UnitGUID = function(unit) return units[unit] and units[unit].guid end,
	UnitClass = function() return "Warrior", "WARRIOR" end,
	UnitIsPlayer = function(unit) return units[unit].player end,
	UnitCanAttack = function(_, unit) return units[unit].enemy end,
	UnitHealth = function(unit) return units[unit].health or 100 end,
	UnitDetailedThreatSituation = function(unit, target)
		local row = threats[target] and threats[target][unit]
		if row then return row.tanking, 0, row.scaled, row.raw, row.value end
	end,
	CheckInteractDistance = function() return false end,
	GetItemInfo = function() return "Ruby Acorn" end,
	IsItemInRange = function() return 0 end,
	GetTime = function() return clock end,
	CreateFrame = function()
		local frame = {scripts = {}}
		function frame:Hide() self.shown = false end
		function frame:Show() self.shown = true end
		function frame:SetScript(event, callback) self.scripts[event] = callback end
		frames[#frames + 1] = frame
		return frame
	end,
	RED_FONT_COLOR = {}, GRAY_FONT_COLOR = {}, HIGHLIGHT_FONT_COLOR = {},
}, {__index = _G})
local chunk = assert(loadfile("Skada/Modules/Threat.lua"))
setfenv(chunk, env)
chunk("Skada", Skada)
mode:OnInitialize()
mode:OnEnable()
mode.Warn = function() warnings = warnings + 1 end
local win = {dataset = {}, metadata = {}}
function win:reset()
	for _, row in ipairs(self.dataset) do wipe(row) end
end
function win:nr(index)
	self.dataset[index] = self.dataset[index] or {}
	return self.dataset[index]
end
local function row(id)
	for _, data in ipairs(win.dataset) do if data.id == id then return data end end
end
local function update() mode:Update(win, {}) end
local function near(actual, expected)
	assert(actual and math.abs(actual - expected) < 0.001, tostring(actual) .. " ~= " .. expected)
end
local function threat(tanking, raw, scaled, value)
	return {tanking = tanking, raw = raw, scaled = scaled, value = value}
end
units.player = {name = "Hunter", guid = "hunter", player = true}
units.raid1 = {name = "Tank", guid = "tank", player = true}
units.pet = {name = "Wolf", guid = "wolf"}
units.target = {name = "Boss", guid = "boss", enemy = true}
members = {{"player"}, {"raid1"}, {"pet", "player"}}
threats.target = {
	player = threat(false, 120, 120 / 1.3, 120000),
	raid1 = threat(true, 100, 100, 100000),
	pet = threat(false, 50, 50 / 1.1, 50000)
}

mode.db.rawvalue = true
update()
assert(row("hunter").valuetext == "120.0%", "raw percentage must use the API's tank-relative value")
near(row("AGGRO").value, 130000)
near(row("AGGRO").threat, 130000)
near(win.metadata.maxvalue, 130000)
assert(not row("wolf"), "pets hidden by default")
mode.db.ignorePets = false
update()
assert(row("wolf").label == "Wolf <Hunter>")
assert(row("wolf").class == "PET")

mode.db.threshold = 110
mode:CheckWarnings()
assert(warnings == 1, "raw warning above 100% must work without a window update")
clock = 1
mode:CheckWarnings()
assert(warnings == 1, "warning cooldown")
clock = 2
mode:CheckWarnings()
assert(warnings == 2)
threats.target.player = threat(true, 100, 100, 100000)
mode.db.threshold = 90
clock = 4
mode:CheckWarnings()
assert(warnings == 2, "actual tanking suppresses warnings")
mode.db.notankwarnings = false
mode:CheckWarnings()
assert(warnings == 3, "tanking suppression can be disabled")
mode.db.notankwarnings = true
threats.target.player = threat(false, 120, 120 / 1.3, 120000)

mode.db.rawvalue = false
update()
near(row("AGGRO").value, 100)
near(row("AGGRO").threat, 130000)
near(win.metadata.maxvalue, 100)
near(row("hunter").value, 120 / 1.3)
mode.db.rawvalue = true
threats.target.player = threat(false, 125, 125 / 1.1, 125000)
update()
near(row("AGGRO").value, 110000)
near(win.metadata.maxvalue, 125000)
mode.db.rawvalue = false
update()
near(row("AGGRO").value, 100)
near(win.metadata.maxvalue, 125 / 1.1)
threats.target.player = threat(false, 120, 120 / 1.3, 120000)

-- Reassign a raid slot and then move that player to a new token mid-combat.
units.raid2, units.raid1 = units.raid1, {name = "Other", guid = "other", player = true}
members = {{"player"}, {"raid2"}, {"raid1"}}
threats.target.raid2 = threat(true, 100, 100, 100000)
threats.target.raid1 = threat(false, 20, 20 / 1.1, 20000)
update()
near(row("tank").threat, 100000)
near(row("other").threat, 20000)
assert(not row("wolf"), "removed pet must not leave a stale row")

-- Changing enemy must not retain the previous tank or player entries.
threats.target = {player = threat(false, 0, 0, 100)}
update()
assert(not row("tank") and not row("other") and not row("AGGRO"))
threats.target = {}
update()
assert(not row("hunter"), "empty threat table must clear the display")
units.target = nil
update()
assert(not row("AGGRO") and win.title == "Threat")

-- An ignored pet tank must still supply the correct pull threshold.
units.target = {name = "Boss", guid = "boss", enemy = true}
members = {{"player"}, {"pet", "player"}}
threats.target = {player = threat(false, 50, 50 / 1.3, 50000), pet = threat(true, 100, 100, 100000)}
mode.db.ignorePets = true
update()
assert(not row("wolf"))
near(row("AGGRO").threat, 130000)

-- Missing percentage data must not reuse old values or crash.
threats.target.player = {value = 50000}
update()
assert(not row("hunter"))
mode.db.rawvalue = true
threats.target.player = {value = 50000, scaled = 50}
update()
assert(not row("hunter"), "missing raw percentage must not fall back to scaled percentage")
threats.target.player = threat(false, 10, 10 / 1.3, -100)
update()
near(row("hunter").threat, 410065308)
clock = 10
mode:CheckWarnings()
assert(warnings == 3, "negative-threat workaround must not trigger warnings")
mode.db.rawvalue = false
update()
assert(not row("hunter"), "switching modes must clear synthetic values and colors")

units.focus = {name = "Friendly", guid = "friend", player = true}
units.focustarget = {name = "Focus Enemy", guid = "focusenemy", enemy = true}
mode.db.focustarget = true
mode:ApplySettings()
assert(mode.unitID == "focustarget", "focus preference must apply immediately")
units.focus = {name = "Enemy Focus", guid = "enemyfocus", enemy = true}
mode:FindUnit()
assert(mode.unitID == "focus")
mode.db.focustarget = false
mode:ApplySettings()
assert(mode.unitID == "target")
units.target.player, units.target.enemy = true, false
units.targettarget = {name = "Tank's Enemy", guid = "targetenemy", enemy = true}
mode:FindUnit()
assert(mode.unitID == "targettarget")
units.targettarget.health = 0
mode:FindUnit()
assert(not mode.unitID, "dead enemies must not remain selected")
assert(events.UNIT_TARGET and timers.CheckWarnings == 0.1)
mode:UNIT_TARGET(nil, "target")
assert(frames[1].shown)
mode:OnDisable()
assert(not next(timers) and not next(events) and not frames[1].shown)
assert(not mode.unitID)

print("Threat regression checks passed")
