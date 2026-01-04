------------------------------------------------------------------------------------------------------------------------
-- Extension
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Base functionality for extension of ExtendedVehicle
--
---@author Grisu118 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class Extension
---@field logger GrisuDebug
---@field name string
---@field vehicle ExtendedVehicle
---@field xmlKey string
---@field active boolean
---@field actionEvents table
Extension = {}

local extension_mt = Class(Extension)

---Register XMLPaths to XMLSchema of the vehicle
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function Extension.registerVehicleXMLPaths(schema, basePath)
end

---Register XMLPaths to XMLSchema of the savegame
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function Extension.registerSavegameXMLPaths(schema, basePath)
end

---Creates new instance of Extension
---@param vehicle ExtendedVehicle
---@param name string The name of this extension
---@param xmlKey string The basePath for the vehicleXml
---@param customMt? metatable custom metatable
---@return Extension
function Extension.new(vehicle, name, xmlKey, customMt)
  local self = setmetatable({}, customMt or extension_mt)

  self.logger = GrisuDebug:create(name)
  self.logger:setLogLvl(g_extendedVehicle:getLogLevel(name))
  self.name = name
  self.vehicle = vehicle
  self.xmlKey = xmlKey
  self.active = false
  self.actionEvents = {}

  return self
end

---@param xmlFile XMLFile Instance of XMLFile
---@param key string XML key to load from
---@return boolean loaded True if loading succeeded, false otherwise
function Extension:load(xmlFile)
  return true
end

---Called after load
---@param savegame table savegame
function Extension:onPostLoad(savegame)
end

---Called on delete
function Extension:delete()
end

function Extension:saveToXMLFile(xmlFile, key)
end

---@return boolean True if this extension is active in this vehicle, false otherwise.
function Extension:isActive()
  return self.active
end

---@return string The name of this extension
function Extension:getName()
  return self.name
end

---Called on client side on join
---@param streamId number stream id
---@param connection number connection id
function Extension:onReadStream(streamId, connection)
end

---Called on server side on join
---@param streamId number stream id
---@param connection number connection id
function Extension:onWriteStream(streamId, connection)
end

---Register action events
function Extension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  self.vehicle:clearActionEventsTable(self.actionEvents)
end