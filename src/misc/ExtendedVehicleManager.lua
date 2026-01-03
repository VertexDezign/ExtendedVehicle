---@class ExtendedVehicleManager
---@field injectionManager XMLInjectionsManager
ExtendedVehicleManager = {}

local extendedVehicleManager_mt = Class(ExtendedVehicleManager)

function ExtendedVehicleManager.new(modName, modDirectory, customMt)
  local self = setmetatable({}, customMt or extendedVehicleManager_mt)

  self.modName = modName
  self.modDirectory = modDirectory
  self.logger = GrisuDebug:create("ExtendedVehicleManager")

  self.injectionManager = XMLInjectionsManager.new(modName, modDirectory)

  return self
end

function ExtendedVehicleManager:delete()
  self.injectionManager:delete()
end

function ExtendedVehicleManager.installSpecializations(typeManager, specializationManager, modDirectory, modName, logger)
  if typeManager.typeName == "vehicle" then
    -- register spec
    specializationManager:addSpecialization("extendedVehicle", "ExtendedVehicle", Utils.getFilename("src/vehicles/specializations/ExtendedVehicle.lua", modDirectory), nil)

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

---@param component string The component of which we want the log level
---@return number
function ExtendedVehicleManager:getLogLevel(component)
  return GrisuDebug.LEVEL.TRACE
end