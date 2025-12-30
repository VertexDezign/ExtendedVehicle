-- ExtendedVehicles
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0.0.0 - 2025-04-14 - Initial implementation
-- @Descripion: Registers extended vehicle into enterable
-- @web: https://grisu118.ch or https://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

local modDirectory = g_currentModDirectory
local modName = g_currentModName

---Source files to load, there are loaded in order, so if there is a dependency to another file, at it after the file it requires
---@type table<string> files to source.
local sourceFiles = {
  -- Utils
  "utils/TableUtils.lua",

  -- Events
  "events/CurrentExtendedSoundEvent.lua",
  "events/ExtendedSoundEvent.lua",
  "events/AdditionalBeaconLightsEvent.lua",
}

-- create logger
local logger = GrisuDebug:create("ExtendedVehiclesMain")
logger:setLogLvl(GrisuDebug.TRACE)

logger:trace("Loading lua files")
for _, file in ipairs(sourceFiles) do
  source(modDirectory .. file)
end

-- save current mod name in global variable for later use in spec
g_extendedVehicleModName = modName

local function printSpecs()
  logger:tPrint("HandToolSpecs", g_handToolSpecializationManager:getSpecializations(), true)
end

local function init()
  -- install spec
  --Mission00.load = Utils.prependedFunction(Mission00.load, printSpecs)

  logger:info("Initialization complete")
end

init()

