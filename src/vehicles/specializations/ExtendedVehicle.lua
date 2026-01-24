---@alias integer number

---@class ExtendedVehicleSpec
---@field debugger GrisuDebug
---@field disableCover boolean
---@field disableFoldable boolean
---@field extensions table<integer, Extension>
---@field extensionsByName table<string, Extension>

---@class ExtendedVehicle : Vehicle
---@field spec_extendedVehicle ExtendedVehicleSpec
ExtendedVehicle = {}

---@alias InputMode "SWITCH" | "BUTTON"
ExtendedVehicle.INPUT_MODE = {
  SWITCH = "SWITCH",
  BUTTON = "BUTTON"
}

function ExtendedVehicle.initSpecialization()
  print("ExtendedVehicle.initSpecialization")
  local schema = Vehicle.xmlSchema
  local basePath = "vehicle.extendedVehicle"

  schema:setXMLSpecializationType("ExtendedVehicle")
  schema:register(XMLValueType.BOOL, basePath .. "#disableFoldable", "True if foldable should be disable", false, true)
  schema:register(XMLValueType.BOOL, basePath .. "#disableCover", "True if cover should be disable", false, true)

  BeaconLightExtension.registerVehicleXMLPaths(schema, basePath .. ".beaconLightGroups")
  SoundGroupExtension.registerVehicleXMLPaths(schema, basePath .. ".soundGroupConfigurations")

  schema:setXMLSpecializationType()

  -- add to vehicle savegame schema
  local savegameBasePath = ("vehicles.vehicle(?).%s.extendedVehicle"):format(g_extendedVehicleModName)
  local schemaSavegame = Vehicle.xmlSchemaSavegame
  SoundGroupExtension.registerSavegameXMLPaths(schemaSavegame, savegameBasePath .. ".soundGroupConfigurations")
end

function ExtendedVehicle.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations)
end

function ExtendedVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ExtendedVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", ExtendedVehicle)
end

function ExtendedVehicle.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getExtendedVehicleExtensionByName", ExtendedVehicle.getExtendedVehicleExtensionByName)
end

function ExtendedVehicle:onLoad(savegame)
  local basePath = "vehicle.extendedVehicle"

  self.spec_extendedVehicle = {
    debugger = GrisuDebug:create("ExtendedVehicleSpec"),
    -- use a array like table to have a stable iteration order (required for read and write stream
    extensions = {
      BeaconLightExtension.new(self, basePath .. ".beaconLightGroups"),
      SoundGroupExtension.new(self, basePath .. ".soundGroupConfigurations"),
    }
  }
  local spec = self.spec_extendedVehicle
  spec.debugger:setLogLvl(g_extendedVehicle:getLogLevel("specialization"))

  spec.disableCover = self.xmlFile:getBool(basePath .. "#disableCover", false)
  spec.disableFoldable = self.xmlFile:getBool(basePath .. "#disableFoldable", false)

  -- call on load for all extensions and build mapping by name
  spec.extensionsByName = {}
  for _, extension in ipairs(spec.extensions) do
    extension:load(self.xmlFile)
    spec.extensionsByName[extension:getName()] = extension
  end
end

---Called after load
---@param savegame table savegame
function ExtendedVehicle:onPostLoad(savegame)
  local spec = self.spec_extendedVehicle

  -- remove event listeners if extendedVehicle is not present on the vehicle
  if not TableUtils.anyMatch(spec.extensions, function(ext) return ext:isActive() end) then
    spec.debugger:trace("No extended vehicle configuration found on vehicle %s", self:getFullName())
    SpecializationUtil.removeEventListener(self, "onReadStream", ExtendedVehicle)
    SpecializationUtil.removeEventListener(self, "onWriteStream", ExtendedVehicle)
    SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", ExtendedVehicle)
    SpecializationUtil.removeEventListener(self, "saveToXMLFile", ExtendedVehicle)

    return
  end

  -- call on post load for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:onPostLoad(savegame)
  end
end

function ExtendedVehicle:saveToXMLFile(xmlFile, key, usedModNames)
  local spec = self.spec_extendedVehicle
  -- call on saveToXMLFiled for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:saveToXMLFile(xmlFile, key)
  end
end

---Called on delete.
function ExtendedVehicle:onDelete()
  local spec = self.spec_extendedVehicle
  if spec == nil then
    return
  end

  -- call on delete for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:delete()
  end
end

---Called on client side on join
---@param streamId number stream id
---@param connection number connection id
function ExtendedVehicle:onReadStream(streamId, connection)
  local spec = self.spec_extendedVehicle

  -- call on onReadStream for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:onReadStream(streamId, connection)
  end
end

---Called on server side on join
---@param streamId number stream id
---@param connection number connection id
function ExtendedVehicle:onWriteStream(streamId, connection)
  local spec = self.spec_extendedVehicle

  -- call on onWriteStream for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:onWriteStream(streamId, connection)
  end
end

---@return Extension | nil the found extension or nil
function ExtendedVehicle:getExtendedVehicleExtensionByName(name)
  local spec = self.spec_extendedVehicle
  return spec.extensionsByName[name]
end

---------------------
--- Action Events ---
---------------------

---Register action events
function ExtendedVehicle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if self.isClient then
    local spec = self.spec_extendedVehicle
    -- call on delete for all extensions
    for _, extension in ipairs(spec.extensions) do
      extension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    end
  end
end
