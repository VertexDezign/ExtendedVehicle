------------------------------------------------------------------------------------------------------------------------
-- SoundGroupExtension
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Class for handling sounds in ExtendedVehicle.
--
---@author Grisu118 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class SoundGroup
---@field name string the name of the sound group
---@field inputMode InputMode
---@field toggleInputButton InputAction
---@field switchInputButton InputAction
---@field playExtendedSoundAnimationOnToggle boolean
---@field animation ExtendedVehicleAnimation

---@class SoundGroupExtension : Extension
SoundGroupExtension = {}
SoundGroupExtension.NAME = "SoundGroupExtension"
local soundGroupExtension_mt = Class(SoundGroupExtension, Extension)

---@alias SoundGroupInputType "TOGGLE" | "SWITCH"
SoundGroupExtension.SOUND_GROUP_INPUT_TYPE = {
  TOGGLE = "TOGGLE",
  SWITCH = "SWITCH"
}

---Creates new instance of SoundGroupExtension
---@param vehicle table Target vehicle
---@return SoundGroupExtension
function SoundGroupExtension.new(vehicle, xmlKey, customMt)
  local self = SoundGroupExtension:superClass().new(vehicle, SoundGroupExtension.NAME, xmlKey, customMt or soundGroupExtension_mt)

  return self
end

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function SoundGroupExtension.registerVehicleXMLPaths(schema, basePath)
  SoundGroupExtension:superClass().registerVehicleXMLPaths(schema, basePath)

  g_vehicleConfigurationManager:addConfigurationType("soundGroup", g_i18n:getText("configuration_soundGroup"), "extendedVehicle", VehicleConfigurationItem)

  local soundGroupConfigKey = basePath .. ".soundGroupConfiguration(?)"
  local soundGroupKey = soundGroupConfigKey .. ".soundGroup(?)"
  schema:register(XMLValueType.STRING, soundGroupKey .. "#name", "Sound group name", nil, true)
  schema:register(XMLValueType.STRING, soundGroupKey .. "#inputMode", "If it is a toggle or a button (SWITCH, BUTTON)", "SWITCH", true)
  schema:register(XMLValueType.STRING, soundGroupKey .. "#toggleInputButton", "Toggle sound group input button", nil, true)
  schema:register(XMLValueType.STRING, soundGroupKey .. "#switchInputButton", "Switch sound group input button")
  schema:register(XMLValueType.BOOL, soundGroupKey .. "#playExtendedSoundAnimationOnToggle", "Play switch animation on toggle", true)

  ExtendedVehicleAnimation.registerXMLPaths(schema, soundGroupKey .. ".animation")

  schema:register(XMLValueType.STRING, soundGroupKey .. ".extendedSound(?)#name", "Sound name", nil, true)
  ExtendedVehicleAnimation.registerXMLPaths(schema, soundGroupKey .. ".extendedSound(?).animation")
  SoundManager.registerSampleXMLPaths(schema, soundGroupKey .. ".extendedSound(?)", "sound")
end

---Register XMLPaths to XMLSchema of the savegame
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
function SoundGroupExtension.registerSavegameXMLPaths(schema, basePath)
  local savegameSoundGroupKey = basePath .. ".soundGroupConfiguration(?)"
  schema:register(XMLValueType.INT, savegameSoundGroupKey .. ".soundGroup(?)#currentSoundIndex", "Current sound index", 0)
end

---@param xmlFile XMLFile Instance of XMLFile
---@return boolean loaded True if loading succeeded, false otherwise
function SoundGroupExtension:load(xmlFile)
  if SoundGroupExtension:superClass().load(xmlFile) then

    self.soundGroups = {}
    self.soundGroupsByToggleInput = {}
    self.soundGroupsBySwitchInput = {}
    self.extendedSounds = {}

    local soundGroupConfigurationId = self.vehicle.configurations["soundGroup"] or 1
    local configKey = string.format(self.xmlKey .. ".soundGroupConfiguration(%d)", soundGroupConfigurationId - 1)
    xmlFile:iterate(configKey .. ".soundGroup", function (_, key)
      self:loadSoundGroupFromXML(xmlFile, key)
    end)

    return true
  else
    return false
  end
end

function SoundGroupExtension:onPostLoad(savegame)
  SoundGroupExtension:superClass().onPostLoad(self, savegame)

  if savegame ~= nil and not savegame.resetVehicles then
    local xmlFile = savegame.xmlFile
    local soundGroupConfigurationId = self.vehicle.configurations["soundGroup"] or 1
    local key = ("%s.%s.extendedVehicle.soundGroupConfigurations.soundGroupConfiguration(%d)"):format(savegame.key, g_extendedVehicleModName, soundGroupConfigurationId - 1)

    xmlFile:iterate(key .. ".soundGroup", function (index, soundGroupKey)
      local soundGroup = self.soundGroups[index]
      if soundGroup ~= nil then
        soundGroup.currentSoundIndex = xmlFile:getValue(soundGroupKey .. "#currentSoundIndex", soundGroup.currentSoundIndex)
      end
    end)
  end

  for _, soundGroup in ipairs(self.soundGroups) do
    if not soundGroup.playExtendedSoundAnimationOnToggle then
      local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
      self.logger:debug("Setting animation for soundGroup %s and currentExtendedSound %s", soundGroup.name, currentExtendedSound)
      if currentExtendedSound ~= nil and currentExtendedSound.animation ~= nil then
        currentExtendedSound.animation:setState(true)
      end
    end
  end
end

function SoundGroupExtension:saveToXMLFile(xmlFile, key)
  SoundGroupExtension:superClass().saveToXMLFile(self, xmlFile, key)

  local soundGroupConfigurationId = self.vehicle.configurations["soundGroup"] or 1
  for i, soundGroup in ipairs(self.soundGroups) do
    local soundGroupKey = string.format("%s.soundGroupConfigurations.soundGroupConfiguration(%d).soundGroup(%d)", key, soundGroupConfigurationId - 1, i - 1)
    xmlFile:setValue(soundGroupKey .. "#currentSoundIndex", soundGroup.currentSoundIndex)
  end
end


---Load extended sound group from XMLFile
---@param xmlFile XMLFile instance of xml file
---@param key string xml key
function SoundGroupExtension:loadSoundGroupFromXML(xmlFile, key)

  local name = xmlFile:getValue(key .. "#name")
  if name == nil or name == "" then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Please define a name in '%s'", key)
    return
  end

  ---@type SoundGroup
  local soundGroup = {}
  soundGroup.name = name
  soundGroup.inputMode = xmlFile:getValue(key .. "#inputMode", ExtendedVehicle.INPUT_MODE.SWITCH)
  soundGroup.playExtendedSoundAnimationOnToggle = xmlFile:getBool(key .. "#playExtendedSoundAnimationOnToggle", true)

  local toggleInputButtonStr = xmlFile:getValue(key .. "#toggleInputButton")
  if toggleInputButtonStr == nil then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Please define 'toggleInputButton' in '%s'", key)
    return
  end

  soundGroup.toggleInputButton = InputAction[toggleInputButtonStr]
  if soundGroup.toggleInputButton == nil then
    self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Invalid toggle input button '%s' in '%s'", toggleInputButtonStr, key)
    return
  end

  soundGroup.currentSoundIndex = 0
  soundGroup.extendedSounds = {}

  local animation = ExtendedVehicleAnimation.new(self.vehicle)
  if animation:loadFromXML(xmlFile, key .. ".animation") then
    soundGroup.animation = animation
  end

  xmlFile:iterate(key .. ".extendedSound", function (_, soundKey)
    local entry = {}

    if self:loadExtendedSoundFromXML(xmlFile, soundKey, entry) then
      table.addElement(soundGroup.extendedSounds, entry)
      self.extendedSounds[entry.index] = entry
    end
  end)

  if #soundGroup.extendedSounds > 1 then
    local switchInputButtonStr = xmlFile:getValue(key .. "#switchInputButton")
    if switchInputButtonStr == nil then
      self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Please define 'switchInputButton' in '%s'", key)
      return
    end

    soundGroup.switchInputButton = InputAction[switchInputButtonStr]
    if soundGroup.switchInputButton == nil then
      self.logger:xmlWarn(xmlFile, "ExtendedVehicle: Invalid switch input button '%s' in '%s'", switchInputButtonStr, key)
      return
    end
  end

  table.addElement(self.soundGroups, soundGroup)
  self.soundGroupsByToggleInput[soundGroup.toggleInputButton] = soundGroup
  self.active = true

  if soundGroup.switchInputButton ~= nil then
    self.soundGroupsBySwitchInput[soundGroup.switchInputButton] = soundGroup
  end
end

---Load extended sound  from XMLFile
---@param xmlFile XMLFile instance of xml file
---@param key string xml key
---@param entry table extendedSound
---@return boolean
function SoundGroupExtension:loadExtendedSoundFromXML(xmlFile, key, entry)

  entry.index = #self.extendedSounds + 1
  entry.isPlaying = false

  local animation = ExtendedVehicleAnimation.new(self.vehicle)
  if animation:loadFromXML(xmlFile, key .. ".animation") then
    entry.animation = animation
  end

  if self.vehicle.isClient then
    entry.sound = g_soundManager:loadSampleFromXML(xmlFile, key, "sound", self.vehicle.baseDirectory, self.vehicle.components, 0, AudioGroup.VEHICLE, self.vehicle.i3dMappings, self.vehicle)
  end

  return true
end

---Returns soundGroup by toggle input
---@param actionName string action name
---@param type SoundGroupInputType the type of the input
---@return table soundGroup
function SoundGroupExtension:getSoundGroupByInput(actionName, type)
  if type == SoundGroupExtension.SOUND_GROUP_INPUT_TYPE.TOGGLE then
    return self.soundGroupsByToggleInput[actionName]
  elseif type == SoundGroupExtension.SOUND_GROUP_INPUT_TYPE.SWITCH then
    return self.soundGroupsBySwitchInput[actionName]
  else
    self.logger:error("Invalid sound group input type " .. type)
  end
end

---Returns current extendedSound of soundGroup
---@param soundGroup table soundGroup
---@return table|nil extendedSound
function SoundGroupExtension:getCurrentExtendedSound(soundGroup)
  if soundGroup == nil or #soundGroup.extendedSounds == 0 then
    return nil
  end

  return soundGroup.extendedSounds[soundGroup.currentSoundIndex + 1]
end

---Toggle current extendedSound state
---@param soundGroup table soundGroup
function SoundGroupExtension:toggleCurrentExtendedSound(soundGroup)
  local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)

  if currentExtendedSound ~= nil then
    self:setExtendedSoundStateByIndex(currentExtendedSound.index, not currentExtendedSound.isPlaying)
  end
end

---Set extendedSound state
---@param index integer extendedSound index of self
---@param state boolean is sound active
---@param noEventSend? boolean send no event
function SoundGroupExtension:setExtendedSoundStateByIndex(index, state, noEventSend)
  local extendedSound = self.extendedSounds[index]

  if extendedSound == nil then
    return
  end

  if state ~= extendedSound.isPlaying then
    ExtendedSoundEvent.sendEvent(self.vehicle, index, state, noEventSend)

    extendedSound.isPlaying = state

    if state then
      if self.vehicle.isClient then
        g_soundManager:playSample(extendedSound.sound)
      end
    else
      g_soundManager:stopSample(extendedSound.sound)
    end

    for _, soundGroup in ipairs(self.soundGroups) do
      local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
      if currentExtendedSound == extendedSound then
        if soundGroup.animation ~= nil then
          soundGroup.animation:setState(state)
        end
        if soundGroup.playExtendedSoundAnimationOnToggle then
          if extendedSound.animation ~= nil then
            extendedSound.animation:setState(state)
          end
        end
      end
    end
  end
end

---Set extendedSound of soundGroup by index
---@param soundGroupIndex integer soundGroup index
---@param index integer index to set
---@param noEventSend? boolean send no event
function SoundGroupExtension:setSoundGroupCurrentSound(soundGroupIndex, index, noEventSend)
  local soundGroup = self.soundGroups[soundGroupIndex]
  if soundGroup == nil then
    return
  end

  local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
  if currentExtendedSound == nil or index == nil or soundGroup.currentSoundIndex == index then
    return
  end

  CurrentExtendedSoundEvent.sendEvent(self.vehicle, soundGroupIndex, index, noEventSend)
  local soundWasPlaying = currentExtendedSound.isPlaying
  local playExtendedSoundAnimationOnToggle = soundGroup.playExtendedSoundAnimationOnToggle

  -- deactivate current sound
  if not playExtendedSoundAnimationOnToggle and currentExtendedSound.animation ~= nil then
    currentExtendedSound.animation:setState(false)
  end

  if soundWasPlaying then
    self:setExtendedSoundStateByIndex(currentExtendedSound.index, false, true)
  end

  soundGroup.currentSoundIndex = index
  currentExtendedSound = self:getCurrentExtendedSound(soundGroup)

  if currentExtendedSound == nil then
    return
  end

  -- replay new current sound
  if not playExtendedSoundAnimationOnToggle then
    if currentExtendedSound.animation ~= nil then
      currentExtendedSound.animation:setState(true)
    end
  end

  if soundWasPlaying then
    self:setExtendedSoundStateByIndex(currentExtendedSound.index, true, true)
  end
end

function SoundGroupExtension:delete()
  SoundGroupExtension:superClass().delete(self)

  if self.vehicle.isClient then
    for _, soundGroup in ipairs(self.soundGroups) do
      for _, extendedSound in ipairs(soundGroup.extendedSounds) do
        g_soundManager:deleteSample(extendedSound.sound)
      end
    end
  end
end

---Called on client side on join
---@param streamId number stream id
---@param connection number connection id
function SoundGroupExtension:onReadStream(streamId, connection)
  SoundGroupExtension:superClass().onReadStream(self, streamId, connection)

  for _, soundGroup in ipairs(self.soundGroups) do
    soundGroup.currentSoundIndex = streamReadUInt8(streamId)

    if not soundGroup.playExtendedSoundAnimationOnToggle then
      local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
      if currentExtendedSound ~= nil and currentExtendedSound.animation ~= nil then
        currentExtendedSound.animation:setState(true)
      end
    end
  end

  for index in ipairs(self.extendedSounds) do
    local isPlaying = streamReadBool(streamId)

    self:setExtendedSoundStateByIndex(index, isPlaying, true)
  end
end

---Called on server side on join
---@param streamId number stream id
---@param connection number connection id
function SoundGroupExtension:onWriteStream(streamId, connection)
  SoundGroupExtension:superClass().onWriteStream(self, streamId, connection)

  for _, soundGroup in ipairs(self.soundGroups) do
    streamWriteUInt8(streamId, soundGroup.currentSoundIndex)
  end

  for _, extendedSound in ipairs(self.extendedSounds) do
    streamWriteBool(streamId, extendedSound.isPlaying)
  end
end

---Register action events
function SoundGroupExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  SoundGroupExtension:superClass().onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)

  if self.vehicle:getIsActiveForInput(true, true) then

    for _, soundGroup in ipairs(self.soundGroups) do
      local triggerDown, triggerUp, triggerAlways = false, true, false
      if soundGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
        triggerDown, triggerUp, triggerAlways = true, true, false
      end

      _, actionEventId = self.vehicle:addActionEvent(self.actionEvents, soundGroup.toggleInputButton, self.vehicle, SoundGroupExtension.actionEventToggleSoundGroup, triggerDown, triggerUp, triggerAlways, true, nil)
      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
      g_inputBinding:setActionEventTextVisibility(actionEventId, true)

      if soundGroup.switchInputButton ~= nil then
        _, actionEventId = self.vehicle:addActionEvent(self.actionEvents, soundGroup.switchInputButton, self.vehicle, SoundGroupExtension.actionEventSwitchSoundGroup, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventTextVisibility(actionEventId, true)
      end
    end
  end
end

---Action event to toggle sound group state
---@param self ExtendedVehicle
---@param actionName string
---@param inputValue number
function SoundGroupExtension.actionEventToggleSoundGroup(self, actionName, inputValue, callbackState, isAnalog)
  local extension = self:getExtendedVehicleExtensionByName(SoundGroupExtension.NAME)

  local soundGroup = extension:getSoundGroupByInput(actionName, SoundGroupExtension.SOUND_GROUP_INPUT_TYPE.TOGGLE)

  if soundGroup == nil then
    return
  end

  if soundGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
    local currentExtendedSound = extension:getCurrentExtendedSound(soundGroup)
    if currentExtendedSound ~= nil then
      extension:setExtendedSoundStateByIndex(currentExtendedSound.index, inputValue > 0)
    end
  else
    extension:toggleCurrentExtendedSound(soundGroup)
  end
end

---Action event to switch sound of sound group
---@param self ExtendedVehicle
---@param actionName string
---@param inputValue number
function SoundGroupExtension.actionEventSwitchSoundGroup(self, actionName, inputValue, callbackState, isAnalog)
  local extension = self:getExtendedVehicleExtensionByName(SoundGroupExtension.NAME)

  local soundGroup = extension:getSoundGroupByInput(actionName, SoundGroupExtension.SOUND_GROUP_INPUT_TYPE.SWITCH)
  if soundGroup == nil then
    return
  end

  -- look for next index or go back to 0 if there are no more
  local currentSoundIndex = soundGroup.currentSoundIndex + 1
  if currentSoundIndex >= #soundGroup.extendedSounds then
    currentSoundIndex = 0
  end

  local soundGroupIndex = TableUtils.indexOf(extension.soundGroups, soundGroup)

  if soundGroupIndex ~= -1 then
    extension:setSoundGroupCurrentSound(soundGroupIndex, currentSoundIndex)
  end
end