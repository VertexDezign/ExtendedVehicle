------------------------------------------------------------------------------------------------------------------------
-- XMLInjectionsManager
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Manager for XML injections into files
--
---@author John Deere 6930 @VertexDezign
---@author Grisu118 @VertexDezign
---@version 1.0.0.0
------------------------------------------------------------------------------------------------------------------------

---@class XMLInjectionsManager
---@field public modName string
---@field public modDirectory string
---@field public logger GrisuDebug
XMLInjectionsManager = {}

local xmlInjectionsManager_mt = Class(XMLInjectionsManager)

---Create new instance of XMLInjectionsManager
---@param modName string mod name
---@param modDirectory string mod directory
---@param customMt? metatable custom metatable
---@return XMLInjectionsManager
function XMLInjectionsManager.new(modName, modDirectory, customMt)
  local self = setmetatable({}, customMt or xmlInjectionsManager_mt)

  self.modName = modName
  self.modDirectory = modDirectory
  self.logger = GrisuDebug:create("XMLInjectionsManager")
  self.logger:setLogLvl(GrisuDebug.LEVEL.TRACE)

  return self
end

---Called on delete
function XMLInjectionsManager:delete()
  -- nothing to do
end

---Appended function of initInheritance, injects XML parts into XMLFile
---@param xmlFile XMLFile Instance of XMLFile
function XMLInjectionsManager:injectXMLData(xmlFile)
  if xmlFile.handle == nil then
    return
  end

  if xmlFile:getBool("vehicle.extendedVehicle#disableCover", false) then
    self.logger:debug("Removing cover from %s", xmlFile.filename)
    xmlFile:removeProperty("vehicle.cover")
  end
  if xmlFile:getBool("vehicle.extendedVehicle#disableFoldable", false) then
    self.logger:debug("Removing foldable from %s", xmlFile.filename)
    self:removeUsedBeaconLights(xmlFile)
    self:removeRWSAnimation(xmlFile)
    xmlFile:removeProperty("vehicle.foldable")
  end
end

---@param xmlFile XMLFile Instance of XMLFile
function XMLInjectionsManager:removeUsedBeaconLights(xmlFile)
  local foundBeacons = {}

  xmlFile:iterate("vehicle.extendedVehicle.beaconLightGroups.beaconLightGroup", function(_, key)
    local toggleInputButtonStr = xmlFile:getString(key .. "#toggleInputButton")
    if toggleInputButtonStr == "VD_EV_TOGGLE_RWS" then
      xmlFile:iterate(key .. ".beaconLight", function(_, beaconKey)
        local beacon = {}
        local node = xmlFile:getString(beaconKey .. "#node", nil)
        if node == nil then
          -- try static lights
          local staticLightNode = xmlFile:getString(beaconKey .. ".staticLight(0)#node", nil)
          if staticLightNode ~= nil then
            beacon.staticLightNode = staticLightNode
          end
        else
          beacon.node = node
        end
        table.addElement(foundBeacons, beacon)
      end)
    end
  end)

  -- no beacons found
  if table.getn(foundBeacons) == 0 then
    self.logger:debug("No beaconLights for RWS defined")
    return
  end

  self.logger:debug("Found %s beaconLights for RWS", table.getn(foundBeacons))

  local keysToRemove = {}

  local function handleBeaconLight(_, beaconKey)
    local node = xmlFile:getString(beaconKey .. "#node", nil)
    if node == nil then
      -- try static lights
      local staticLightNode = xmlFile:getString(beaconKey .. ".staticLight(0)#node", nil)
      if staticLightNode ~= nil then
        for _, beacon in ipairs(foundBeacons) do
          if beacon.staticLightNode == staticLightNode then
            table.addElement(keysToRemove, beaconKey)
            break
          end
        end
      end
    else
      for _, beacon in ipairs(foundBeacons) do
        if beacon.node == node then
          table.addElement(keysToRemove, beaconKey)
          break
        end
      end
    end
  end

  xmlFile:iterate("vehicle.lights.beaconLightConfigurations.beaconLightConfiguration", function(_, key)
    xmlFile:iterate(key .. ".beaconLight", handleBeaconLight)
  end)
  xmlFile:iterate("vehicle.lights.beaconLights.beaconLight", handleBeaconLight)

  self.logger:debug("Going to remove %s beacon lights", table.getn(keysToRemove))

  for _, key in ipairs(keysToRemove) do
    self.logger:trace("Removing %s from %s", key, xmlFile.filename)
    xmlFile:removeProperty(key)
  end
end

---@param xmlFile XMLFile Instance of XMLFile
function XMLInjectionsManager:removeRWSAnimation(xmlFile)
  local animationNames = {}

  xmlFile:iterate("vehicle.foldable.foldingConfigurations.foldingConfiguration", function(_, key)
    xmlFile:iterate(key .. ".foldingParts", function(_, partsKey)
      xmlFile:iterate(partsKey .. ".foldingPart", function(_, partKey)
        local animationName = xmlFile:getString(partKey .. "#animationName", nil)
        if animationName ~= nil then
          table.addElement(animationNames, animationName)
        end
      end)
    end)
  end)

  local numOfAnimations = table.getn(animationNames)
  self.logger:debug("Found %s animations for RWS", numOfAnimations)
  if numOfAnimations == 0 then
    return
  end

  local keysToRemove = {}

  local function handleAnimation(_, key)
    local name = xmlFile:getString(key .. "#name", nil)
    if name ~= nil then
      for _, animationName in ipairs(animationNames) do
        if animationName == name then
          table.addElement(keysToRemove, key)
          break
        end
      end
    end
  end

  xmlFile:iterate("vehicle.animations.animation", handleAnimation)
  xmlFile:iterate("vehicle.animations.animationConfigurations.animationConfiguration", function(_, key)
    xmlFile:iterate(key .. ".animation", handleAnimation)
  end)

  self.logger:debug("Going to remove %s animations", table.getn(keysToRemove))

  for _, key in ipairs(keysToRemove) do
    self.logger:trace("Removing %s from %s", key, xmlFile.filename)
    xmlFile:removeProperty(key)
  end
end