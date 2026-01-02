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
    xmlFile:removeProperty("vehicle.foldable")
  end
end
