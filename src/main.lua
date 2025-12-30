-- ExtendedVehicles
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0.0.0 - 2025-04-14 - Initial implementation
-- @Descripion: Registers extended vehicle into enterable
-- @web: https://grisu118.ch or https://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

local modDirectory = g_currentModDirectory
local modName = g_currentModName
---@type ExtendedVehicleManager
local modEnvironment

---Source files to load, there are loaded in order, so if there is a dependency to another file, at it after the file it requires
---@type table<string> files to source.
local sourceFiles = {
  -- Utils
  "src/utils/TableUtils.lua",
  -- xml injection
  "src/misc/XMLInjectionsManager.lua",
  -- manager
  "src/misc/ExtendedVehicleManager.lua",

  "src/extendedVehicle/animation/ExtendedVehicleAnimation.lua",

  -- extensions
  "src/extendedVehicle/Extension.lua",
  -- beacon light
  "src/extendedVehicle/light/BeaconLightExtension.lua",
  "src/extendedVehicle/light/events/AdditionalBeaconLightsEvent.lua",
  -- sound group
  "src/extendedVehicle/sound/SoundGroupExtension.lua",
  "src/extendedVehicle/sound/events/CurrentExtendedSoundEvent.lua",
  "src/extendedVehicle/sound/events/ExtendedSoundEvent.lua",
  "events/PumpVehicleEvent.lua",
}

-- create logger
local logger = GrisuDebug:create("ExtendedVehiclesMain")
logger:setLogLvl(GrisuDebug.LEVEL.INFO)

logger:trace("Loading lua files")
for _, file in ipairs(sourceFiles) do
  source(modDirectory .. file)
end

---Returns true when the current mod env is loaded, false otherwise.
local function isLoaded()
  return modEnvironment ~= nil
end

local function load(mission)

end

---Unload the mod when the mod is unselected and savegame is (re)loaded or game is closed.
local function unload()
  if not isLoaded() then
    return
  end

  if modEnvironment ~= nil then
    modEnvironment:delete()
    modEnvironment = nil
  end
end

---Injects extended vehicle
---@param typeManager table typeManager table
local function validateTypes(typeManager)
  if typeManager.typeName == "vehicle" then
    -- register ic, load seems to be to late for the xml schemas and init is too early as we load before IC
    if FS25_interactiveControl ~= nil and FS25_interactiveControl.InteractiveFunctions ~= nil then
      logger:info("Found FS25_interactiveControl, register IC extensions")
      BeaconLightExtension.registerInteractiveControl(FS25_interactiveControl.InteractiveFunctions)
    end

    ExtendedVehicleManager.installSpecializations(typeManager, g_specializationManager, modDirectory, modName, logger)
  end
end

---Appended function: XMLFile.initInheritance
---Adds xml injections to XMLFile
---@param xmlFile XMLFile Instance of XMLFile
local function postInitInheritance(xmlFile)
  if not isLoaded() or modEnvironment.injectionManager == nil then
    return
  end

  modEnvironment.injectionManager:injectXMLData(xmlFile)
end

local function init()
  modEnvironment = ExtendedVehicleManager.new(modName, modDirectory)

  -- load
  Mission00.load = Utils.prependedFunction(Mission00.load, load)
  -- cleanup
  FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
  -- install spec
  TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

  -- XMLInjectionsManager
  XMLFile.initInheritance = Utils.appendedFunction(XMLFile.initInheritance, postInitInheritance)

  g_extendedVehicle = modEnvironment

  logger:info("Initialization complete")
end

-- save current mod name in global variable for later use in spec
g_extendedVehicleModName = modName

init()

