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
  "src/utils/TableUtils.lua",
  "src/extendedVehicle/ExtendedVehicleAnimation.lua",

  -- Events
  "src/extendedVehicle/events/CurrentExtendedSoundEvent.lua",
  "src/extendedVehicle/events/ExtendedSoundEvent.lua",
  "src/extendedVehicle/events/AdditionalBeaconLightsEvent.lua",
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

local function installSpec(typeManager)
  if typeManager.typeName == "vehicle" then
    -- register spec
    g_specializationManager:addSpecialization("extendedVehicle", "ExtendedVehicle", Utils.getFilename("src/vehicles/specializations/ExtendedVehicle.lua", modDirectory), nil)

    -- add spec to vehicle types
    local totalCount = 0
    local modified = 0
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
      totalCount = totalCount + 1
      if SpecializationUtil.hasSpecialization(AnimatedVehicle, typeEntry.specializations) and
          not SpecializationUtil.hasSpecialization(Rideable, typeEntry.specializations) and
          not SpecializationUtil.hasSpecialization(ExtendedVehicle, typeEntry.specializations) then
        typeManager:addSpecialization(typeName, modName .. ".extendedVehicle")
        modified = modified + 1
        logger:trace("Adding ExtendedVehicle spec to " .. typeName)
      else
        logger:trace("Not adding ExtendedVehicle spec to " .. typeName)
      end
    end

    logger:info(string.format("Inserted ExtendedVehicle spec into %i of %i vehicle types", modified, totalCount))
  end
end


local function init()
  -- install spec
  TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, installSpec)

  --Mission00.load = Utils.prependedFunction(Mission00.load, printSpecs)

  logger:info("Initialization complete")
end

init()

