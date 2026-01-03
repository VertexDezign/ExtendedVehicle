------------------------------------------------------------------------------------------------------------------------
-- BeaconLightExtension
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Class for handling beacon lights in ExtendedVehicle.
--
---@author Grisu118 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class BeaconLightGroup
---@field name string
---@field inputMode InputMode
---@field toggleInputButton InputAction
---@field animation ExtendedVehicleAnimation
---@field beaconLights table<integer, BeaconLight>

---@class BeaconLightExtension : Extension
---@field logger GrisuDebug
---@field vehicle ExtendedVehicle
BeaconLightExtension = {}
BeaconLightExtension.NAME = "BeaconLightExtension"
local beaconLightExtension_mt = Class(BeaconLightExtension, Extension)

---Creates new instance of BeaconLightExtension
---@param vehicle table Target vehicle
---@return BeaconLightExtension
function BeaconLightExtension.new(vehicle, xmlKey, customMt)
  local self = BeaconLightExtension:superClass().new(vehicle, BeaconLightExtension.NAME, xmlKey, customMt or beaconLightExtension_mt)

  return self
end

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function BeaconLightExtension.registerVehicleXMLPaths(schema, basePath)
  BeaconLightExtension:superClass().registerVehicleXMLPaths(schema, basePath)

  local beaconLightGroupKey = basePath .. ".beaconLightGroup(?)"
  schema:register(XMLValueType.STRING, beaconLightGroupKey .. "#name", "Beacon light group name", nil, true)
  schema:register(XMLValueType.STRING, beaconLightGroupKey .. "#inputMode", "If it is a toggle or a button (SWITCH, BUTTON)", "SWITCH", true)
  schema:register(XMLValueType.STRING, beaconLightGroupKey .. "#toggleInputButton", "Toggle beacon light group input button", nil, true)

  ExtendedVehicleAnimation.registerXMLPaths(schema, beaconLightGroupKey .. ".animation")

  BeaconLight.registerVehicleXMLPaths(schema, beaconLightGroupKey .. ".beaconLight(?)")
end

---@param xmlFile XMLFile Instance of XMLFile
---@return boolean loaded True if loading succeeded, false otherwise
function BeaconLightExtension:load(xmlFile)
  if BeaconLightExtension:superClass().load(xmlFile) then

    self.beaconLightGroups = {}
    self.beaconLightGroupsByToggleInput = {}

    xmlFile:iterate(self.xmlKey .. ".beaconLightGroup", function(_, key)
      self:loadBeaconLightGroupFromXML(xmlFile, key)
    end)

    return true
  else
    return false
  end
end

---Load beacon light group from XMLFile
---@param xmlFile XMLFile instance of xml file
---@param key string xml key
function BeaconLightExtension:loadBeaconLightGroupFromXML(xmlFile, key)
  local name = xmlFile:getValue(key .. "#name")
  if name == nil or name == "" then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Please define a name in '%s'", key)
    return
  end

  ---@type BeaconLightGroup
  local beaconLightGroup = {}
  beaconLightGroup.name = name
  beaconLightGroup.inputMode = xmlFile:getValue(key .. "#inputMode", ExtendedVehicle.INPUT_MODE.SWITCH)

  local toggleInputButtonStr = xmlFile:getValue(key .. "#toggleInputButton")
  if toggleInputButtonStr == nil then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Please define 'toggleInputButton' in '%s'", key)
    return
  end

  beaconLightGroup.toggleInputButton = InputAction[toggleInputButtonStr]
  if beaconLightGroup.toggleInputButton == nil then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Invalid toggle input button '%s' in '%s'", toggleInputButtonStr, key)
    return
  end

  beaconLightGroup.isActive = false
  beaconLightGroup.beaconLights = {}

  local animation = ExtendedVehicleAnimation.new(self)
  if animation:loadFromXML(xmlFile, key .. ".animation") then
    beaconLightGroup.animation = animation
  end

  xmlFile:iterate(key .. ".beaconLight", function(_, beaconKey)
    BeaconLight.loadFromVehicleXML(beaconLightGroup.beaconLights, xmlFile, beaconKey, self.vehicle)
  end)

  table.addElement(self.beaconLightGroups, beaconLightGroup)
  self.beaconLightGroupsByToggleInput[beaconLightGroup.toggleInputButton] = beaconLightGroup
  self.active = true
end

---Returns beaconLightGroup by toggle input
---@param actionName string action name
---@return BeaconLightGroup beaconLightGroup
function BeaconLightExtension:getBeaconLightGroupByToggleInput(actionName)
  return self.beaconLightGroupsByToggleInput[actionName]
end

---Returns the index of the beaconLightGroup
---@param beaconLightGroup BeaconLightGroup
---@return integer the index
function BeaconLightExtension:getBeaconLightGroupIndex(beaconLightGroup)
  local index = TableUtils.indexOf(self.beaconLightGroups, beaconLightGroup)

  if index == -1 then
    self.logger:error("Given beaconLightGroup with name %s not found", beaconLightGroup.name)
  end

  return index
end

---Toggle beacon light group state
---@param beaconLightGroup BeaconLightGroup beaconLightGroup
function BeaconLightExtension:toggleBeaconLightGroupState(beaconLightGroup)
  if beaconLightGroup == nil then
    return
  end

  local index = self:getBeaconLightGroupIndex(beaconLightGroup)
  self:setBeaconLightGroupState(index, not beaconLightGroup.isActive)
end

---Set beacon light group state
---@param index integer beaconLightGroup index of self
---@param state boolean is beacon light group active
---@param noEventSend? boolean send no event
function BeaconLightExtension:setBeaconLightGroupState(index, state, noEventSend)
  local beaconLightGroup = self.beaconLightGroups[index]

  if beaconLightGroup == nil then
    return
  end

  if state ~= beaconLightGroup.isActive then
    AdditionalBeaconLightsEvent.sendEvent(self.vehicle, index, state, noEventSend)

    beaconLightGroup.isActive = state

    for _, beaconLight in ipairs(beaconLightGroup.beaconLights) do
      beaconLight:setIsActive(state)
    end

    if beaconLightGroup.animation ~= nil then
      beaconLightGroup.animation:setState(state)
    end
  end
end

function BeaconLightExtension:delete()
  BeaconLightExtension:superClass().delete(self)
  if self.vehicle.isClient then
    if self.beaconLightGroups ~= nil then
      for _, beaconLightGroup in ipairs(self.beaconLightGroups) do
        for _, beaconLight in ipairs(beaconLightGroup.beaconLights) do
          beaconLight:delete()
        end
      end
    end

    self.beaconLightGroups = nil
  end
end

---Called on client side on join
---@param streamId number stream id
---@param connection number connection id
function BeaconLightExtension:onReadStream(streamId, connection)
  BeaconLightExtension:superClass().onReadStream(self, streamId, connection)

  for index in ipairs(self.beaconLightGroups) do
    local isActive = streamReadBool(streamId)
    self:setBeaconLightGroupState(index, isActive, true)
  end
end

---Called on server side on join
---@param streamId number stream id
---@param connection number connection id
function BeaconLightExtension:onWriteStream(streamId, connection)
  BeaconLightExtension:superClass().onWriteStream(self, streamId, connection)

  for _, beaconLightGroup in ipairs(self.beaconLightGroups) do
    streamWriteBool(streamId, beaconLightGroup.isActive)
  end
end

---Register action events
function BeaconLightExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  BeaconLightExtension:superClass().onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)

  if self.vehicle:getIsActiveForInput(true, true) then

    for _, beaconLightGroup in ipairs(self.beaconLightGroups) do
      local triggerDown, triggerUp, triggerAlways = false, true, false
      if beaconLightGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
        triggerDown, triggerUp, triggerAlways = true, true, false
      end

      local _, actionEventId = self.vehicle:addActionEvent(self.actionEvents, beaconLightGroup.toggleInputButton, self.vehicle, BeaconLightExtension.actionEventToggleBeaconLightGroup, triggerDown, triggerUp, triggerAlways, true, nil)
      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
      g_inputBinding:setActionEventTextVisibility(actionEventId, true)
    end
  end
end

---Action event to toggle beacon light group
---@param self ExtendedVehicle
---@param actionName string
---@param inputValue number
function BeaconLightExtension.actionEventToggleBeaconLightGroup(self, actionName, inputValue, callbackState, isAnalog)
  local extension = self:getExtendedVehicleExtensionByName(BeaconLightExtension.NAME)

  local beaconLightGroup = extension:getBeaconLightGroupByToggleInput(actionName)

  if beaconLightGroup == nil then
    return
  end

  if beaconLightGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
    local index = extension:getBeaconLightGroupIndex(beaconLightGroup)
    extension:setBeaconLightGroupState(index, inputValue > 0)
  else
    extension:toggleBeaconLightGroupState(beaconLightGroup)
  end
end