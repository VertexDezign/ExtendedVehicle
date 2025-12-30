------------------------------------------------------------------------------------------------------------------------
-- ExtendedVehicleAnimation
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Class for handling animations in ExtendedVehicle.
--
---@author Junie
------------------------------------------------------------------------------------------------------------------------

---@class ExtendedVehicleAnimation
ExtendedVehicleAnimation = {}
local ExtendedVehicleAnimation_mt = Class(ExtendedVehicleAnimation)

---Creates new instance of ExtendedVehicleAnimation
---@param vehicle table Target vehicle
---@return ExtendedVehicleAnimation
function ExtendedVehicleAnimation.new(vehicle, customMt)
    local self = setmetatable({}, customMt or ExtendedVehicleAnimation_mt)

    self.vehicle = vehicle

    return self
end

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function ExtendedVehicleAnimation.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING, basePath .. "#name", "Animation name")
    schema:register(XMLValueType.FLOAT, basePath .. "#speedScale", "Animation speed scale", 1.0)
end

---Loads ExtendedVehicleAnimation data from xmlFile, returns true if loading was successful, false otherwise
---@param xmlFile XMLFile Instance of XMLFile
---@param key string XML key to load from
---@return boolean loaded True if loading succeeded, false otherwise
function ExtendedVehicleAnimation:loadFromXML(xmlFile, key)
    if self.vehicle.playAnimation == nil then
        return false
    end

    local name = xmlFile:getValue(key .. "#name")
    if name == nil then
        return false
    end

    if not self.vehicle:getAnimationExists(name) then
        Logging.xmlWarning(xmlFile, "Unable to find animation '%s' in target vehicle, ignoring animation!", name)
        return false
    end

    self.name = name
    self.speedScale = xmlFile:getValue(key .. "#speedScale", 1.0)

    return true
end

---Updates animation by state
---@param state boolean New state
function ExtendedVehicleAnimation:setState(state)
    if self.vehicle.playAnimation ~= nil then
        local speed = self.speedScale
        if not state then
            speed = -speed
        end

        self.vehicle:playAnimation(self.name, speed, self.vehicle:getAnimationTime(self.name), true)
    end
end
