---@alias integer number

---@class ExtendedVehicleSpec
---@field debugger GrisuDebug
---@field active boolean
---@field actionEvents table
---@field disableCover boolean
---@field disableFoldable boolean
---@field soundGroups table<integer, SoundGroup>
---@field extensions table<integer, Extension>
---@field extensionsByName table<string, Extension>

---@class ExtendedVehicle : Vehicle
---@field spec_extendedVehicle ExtendedVehicleSpec
ExtendedVehicle = {}
---@alias SoundGroupInputType "TOGGLE" | "SWITCH"
ExtendedVehicle.SOUND_GROUP_INPUT_TYPE = {
  TOGGLE = "TOGGLE",
  SWITCH = "SWITCH"
}
---@alias InputMode "SWITCH" | "BUTTON"
ExtendedVehicle.INPUT_MODE = {
  SWITCH = "SWITCH",
  BUTTON = "BUTTON"
}

function ExtendedVehicle.initSpecialization()
  g_vehicleConfigurationManager:addConfigurationType("soundGroup", g_i18n:getText("configuration_soundGroup"), "extendedVehicle", VehicleConfigurationItem)

  local schema = Vehicle.xmlSchema
  local basePath = "vehicle.extendedVehicle"

  schema:setXMLSpecializationType("ExtendedVehicle")
  schema:register(XMLValueType.BOOL, basePath .. "#disableFoldable", "True if foldable should be disable", false, true)
  schema:register(XMLValueType.BOOL, basePath .. "#disableCover", "True if cover should be disable", false, true)

  BeaconLightExtension.registerVehicleXMLPaths(schema, basePath .. ".beaconLightGroups")

  local soundGroupConfigKey = "vehicle.extendedVehicle.soundGroupConfigurations.soundGroupConfiguration(?)"
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

  schema:setXMLSpecializationType()

  -- add to vehicle savegame schema
  local schemaSavegame = Vehicle.xmlSchemaSavegame
  local savegameSoundGroupKey = ("vehicles.vehicle(?).%s.extendedVehicle.soundGroupConfigurations.soundGroupConfiguration(?)"):format(g_extendedVehicleModName)
  schemaSavegame:register(XMLValueType.INT, savegameSoundGroupKey .. ".soundGroup(?)#currentSoundIndex", "Current sound index", 0)
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
  -- sound groups
  SpecializationUtil.registerFunction(vehicleType, "loadSoundGroupFromXML", ExtendedVehicle.loadSoundGroupFromXML)
  SpecializationUtil.registerFunction(vehicleType, "loadExtendedSoundFromXML", ExtendedVehicle.loadExtendedSoundFromXML)
  SpecializationUtil.registerFunction(vehicleType, "getSoundGroupByInput", ExtendedVehicle.getSoundGroupByInput)
  SpecializationUtil.registerFunction(vehicleType, "getCurrentExtendedSound", ExtendedVehicle.getCurrentExtendedSound)
  SpecializationUtil.registerFunction(vehicleType, "toggleCurrentExtendedSound", ExtendedVehicle.toggleCurrentExtendedSound)
  SpecializationUtil.registerFunction(vehicleType, "setExtendedSoundStateByIndex", ExtendedVehicle.setExtendedSoundStateByIndex)
  SpecializationUtil.registerFunction(vehicleType, "setSoundGroupCurrentSound", ExtendedVehicle.setSoundGroupCurrentSound)
end

function ExtendedVehicle:onLoad(savegame)
  local basePath = "vehicle.extendedVehicle"

  self.spec_extendedVehicle = {
    debugger = GrisuDebug:create("ExtendedVehicleSpec"),
    actionEvents = {},
    active = false,
    -- use a array like table to have a stable iteration order (required for read and write stream
    extensions = {
      BeaconLightExtension.new(self, basePath .. ".beaconLightGroups")
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

  spec.soundGroups = {}
  spec.soundGroupsByToggleInput = {}
  spec.soundGroupsBySwitchInput = {}
  spec.extendedSounds = {}

  local soundGroupConfigurationId = self.configurations["soundGroup"] or 1
  local configKey = string.format("vehicle.extendedVehicle.soundGroupConfigurations.soundGroupConfiguration(%d)", soundGroupConfigurationId - 1)
  self.xmlFile:iterate(configKey .. ".soundGroup", function (_, key)
    self:loadSoundGroupFromXML(self.xmlFile, key)
  end)
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

  if savegame ~= nil and not savegame.resetVehicles then
    local xmlFile = savegame.xmlFile
    local soundGroupConfigurationId = self.configurations["soundGroup"] or 1
    local key = ("%s.%s.extendedVehicle.soundGroupConfigurations.soundGroupConfiguration(%d)"):format(savegame.key, g_extendedVehicleModName, soundGroupConfigurationId - 1)

    xmlFile:iterate(key .. ".soundGroup", function (index, soundGroupKey)
      local soundGroup = spec.soundGroups[index]
      if soundGroup ~= nil then
        soundGroup.currentSoundIndex = xmlFile:getValue(soundGroupKey .. "#currentSoundIndex", soundGroup.currentSoundIndex)
      end
    end)
  end

  for _, soundGroup in ipairs(spec.soundGroups) do
    if not soundGroup.playExtendedSoundAnimationOnToggle then
      local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
      spec.debugger:debug("Setting animation for soundGroup %s and currentExtendedSound %s", soundGroup.name, currentExtendedSound)
      if currentExtendedSound ~= nil and currentExtendedSound.animation ~= nil then
        currentExtendedSound.animation:setState(true)
      end
    end
  end
end

function ExtendedVehicle:saveToXMLFile(xmlFile, key, usedModNames)
  local spec = self.spec_extendedVehicle
  -- call on saveToXMLFiled for all extensions
  for _, extension in ipairs(spec.extensions) do
    extension:saveToXMLFile(xmlFile, key)
  end

  local soundGroupConfigurationId = self.configurations["soundGroup"] or 1
  for i, soundGroup in ipairs(spec.soundGroups) do
    local soundGroupKey = string.format("%s.soundGroupConfigurations.soundGroupConfiguration(%d).soundGroup(%d)", key, soundGroupConfigurationId - 1, i - 1)
    xmlFile:setValue(soundGroupKey .. "#currentSoundIndex", soundGroup.currentSoundIndex)
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

  if self.isClient then
    for _, soundGroup in ipairs(spec.soundGroups) do
      for _, extendedSound in ipairs(soundGroup.extendedSounds) do
        g_soundManager:deleteSample(extendedSound.sound)
      end
    end

    if spec.honkSampleBackup ~= nil then
      g_soundManager:deleteSample(spec.honkSampleBackup)
    end
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

  for _, soundGroup in ipairs(spec.soundGroups) do
    soundGroup.currentSoundIndex = streamReadUInt8(streamId)

    if not soundGroup.playExtendedSoundAnimationOnToggle then
      local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
      if currentExtendedSound ~= nil and currentExtendedSound.animation ~= nil then
        currentExtendedSound.animation:setState(true)
      end
    end
  end

  for index in ipairs(spec.extendedSounds) do
    local isPlaying = streamReadBool(streamId)

    self:setExtendedSoundStateByIndex(index, isPlaying, true)
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

  for _, soundGroup in ipairs(spec.soundGroups) do
    streamWriteUInt8(streamId, soundGroup.currentSoundIndex)
  end

  for _, extendedSound in ipairs(spec.extendedSounds) do
    streamWriteBool(streamId, extendedSound.isPlaying)
  end
end

---@return Extension | nil the found extension or nil
function ExtendedVehicle:getExtendedVehicleExtensionByName(name)
  local spec = self.spec_extendedVehicle
  return spec.extensionsByName[name]
end

-----------------------
--- ExtendedSounds ---
-----------------------

---Load extended sound group from XMLFile
---@param xmlFile XMLFile instance of xml file
---@param key string xml key
function ExtendedVehicle:loadSoundGroupFromXML(xmlFile, key)
  local spec = self.spec_extendedVehicle

  local name = xmlFile:getValue(key .. "#name")
  if name == nil or name == "" then
    spec.debugger:xmlWarn(xmlFile, "ExtendedVehicle: Please define a name in '%s'", key)
    return
  end

  ---@class SoundGroup
  ---@field name string the name of the sound group
  ---@field inputMode InputMode
  ---@field toggleInputButton InputAction
  ---@field switchInputButton InputAction
  ---@field playExtendedSoundAnimationOnToggle boolean
  ---@field animation ExtendedVehicleAnimation
  local soundGroup = {}
  soundGroup.name = name
  soundGroup.inputMode = xmlFile:getValue(key .. "#inputMode", ExtendedVehicle.INPUT_MODE.SWITCH)
  soundGroup.playExtendedSoundAnimationOnToggle = xmlFile:getValue(key .. "#playExtendedSoundAnimationOnToggle", true)

  local toggleInputButtonStr = xmlFile:getValue(key .. "#toggleInputButton")
  if toggleInputButtonStr == nil then
    spec.debugger:xmlWarn(xmlFile, "ExtendedVehicle: Please define 'toggleInputButton' in '%s'", key)
    return
  end

  soundGroup.toggleInputButton = InputAction[toggleInputButtonStr]
  if soundGroup.toggleInputButton == nil then
    spec.debugger:xmlWarn(xmlFile, "ExtendedVehicle: Invalid toggle input button '%s' in '%s'", toggleInputButtonStr, key)
    return
  end

  soundGroup.currentSoundIndex = 0
  soundGroup.extendedSounds = {}

  local animation = ExtendedVehicleAnimation.new(self)
  if animation:loadFromXML(xmlFile, key .. ".animation") then
    soundGroup.animation = animation
  end

  xmlFile:iterate(key .. ".extendedSound", function (_, soundKey)
    local entry = {}

    if self:loadExtendedSoundFromXML(xmlFile, soundKey, entry) then
      table.addElement(soundGroup.extendedSounds, entry)
      spec.extendedSounds[entry.index] = entry
    end
  end)

  if #soundGroup.extendedSounds > 1 then
    local switchInputButtonStr = xmlFile:getValue(key .. "#switchInputButton")
    if switchInputButtonStr == nil then
      spec.debugger:xmlWarn(xmlFile, "ExtendedVehicle: Please define 'switchInputButton' in '%s'", key)
      return
    end

    soundGroup.switchInputButton = InputAction[switchInputButtonStr]
    if soundGroup.switchInputButton == nil then
      spec.debugger:xmlWarn(xmlFile, "ExtendedVehicle: Invalid switch input button '%s' in '%s'", switchInputButtonStr, key)
      return
    end
  end

  table.addElement(spec.soundGroups, soundGroup)
  spec.soundGroupsByToggleInput[soundGroup.toggleInputButton] = soundGroup
  spec.active = true

  if soundGroup.switchInputButton ~= nil then
    spec.soundGroupsBySwitchInput[soundGroup.switchInputButton] = soundGroup
  end
end

---Load extended sound  from XMLFile
---@param xmlFile XMLFile instance of xml file
---@param key string xml key
---@param entry table extendedSound
---@return boolean
function ExtendedVehicle:loadExtendedSoundFromXML(xmlFile, key, entry)
  local spec = self.spec_extendedVehicle

  entry.index = #spec.extendedSounds + 1
  entry.isPlaying = false

  local animation = ExtendedVehicleAnimation.new(self)
  if animation:loadFromXML(xmlFile, key .. ".animation") then
    entry.animation = animation
  end

  if self.isClient then
    entry.sound = g_soundManager:loadSampleFromXML(xmlFile, key, "sound", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
  end

  return true
end

---Returns soundGroup by toggle input
---@param actionName string action name
---@param type SoundGroupInputType the type of the input
---@return table soundGroup
function ExtendedVehicle:getSoundGroupByInput(actionName, type)
  local spec = self.spec_extendedVehicle
  if type == ExtendedVehicle.SOUND_GROUP_INPUT_TYPE.TOGGLE then
    return spec.soundGroupsByToggleInput[actionName]
  elseif type == ExtendedVehicle.SOUND_GROUP_INPUT_TYPE.SWITCH then
    return spec.soundGroupsBySwitchInput[actionName]
  else
    spec.debugger:error("Invalid sound group input type " .. type)
  end
end

---Returns current extendedSound of soundGroup
---@param soundGroup table soundGroup
---@return table|nil extendedSound
function ExtendedVehicle:getCurrentExtendedSound(soundGroup)
  if soundGroup == nil or #soundGroup.extendedSounds == 0 then
    return nil
  end

  return soundGroup.extendedSounds[soundGroup.currentSoundIndex + 1]
end

---Toggle current extendedSound state
---@param soundGroup table soundGroup
function ExtendedVehicle:toggleCurrentExtendedSound(soundGroup)
  local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)

  if currentExtendedSound ~= nil then
    self:setExtendedSoundStateByIndex(currentExtendedSound.index, not currentExtendedSound.isPlaying)
  end
end

---Set extendedSound state
---@param index integer extendedSound index of spec
---@param state boolean is sound active
---@param noEventSend? boolean send no event
function ExtendedVehicle:setExtendedSoundStateByIndex(index, state, noEventSend)
  local spec = self.spec_extendedVehicle
  local extendedSound = spec.extendedSounds[index]

  if extendedSound == nil then
    return
  end

  if state ~= extendedSound.isPlaying then
    ExtendedSoundEvent.sendEvent(self, index, state, noEventSend)

    extendedSound.isPlaying = state

    if state then
      if self.isClient then
        g_soundManager:playSample(extendedSound.sound)
      end
    else
      g_soundManager:stopSample(extendedSound.sound)
    end

    for _, soundGroup in ipairs(spec.soundGroups) do
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
function ExtendedVehicle:setSoundGroupCurrentSound(soundGroupIndex, index, noEventSend)
  local spec = self.spec_extendedVehicle
  local soundGroup = spec.soundGroups[soundGroupIndex]
  if soundGroup == nil then
    return
  end

  local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
  if currentExtendedSound == nil or index == nil or soundGroup.currentSoundIndex == index then
    return
  end

  CurrentExtendedSoundEvent.sendEvent(self, soundGroupIndex, index, noEventSend)
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
    self:clearActionEventsTable(spec.actionEvents)

    if self:getIsActiveForInput(true, true) then

      -- sound groups
      for _, soundGroup in ipairs(spec.soundGroups) do
        local triggerDown, triggerUp, triggerAlways = false, true, false
        if soundGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
          triggerDown, triggerUp, triggerAlways = true, true, false
        end

        _, actionEventId = self:addActionEvent(spec.actionEvents, soundGroup.toggleInputButton, self, ExtendedVehicle.actionEventToggleSoundGroup, triggerDown, triggerUp, triggerAlways, true, nil)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventTextVisibility(actionEventId, true)

        if soundGroup.switchInputButton ~= nil then
          _, actionEventId = self:addActionEvent(spec.actionEvents, soundGroup.switchInputButton, self, ExtendedVehicle.actionEventSwitchSoundGroup, false, true, false, true, nil)
          g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
          g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        end
      end
    end
  end
end

---Action event to toggle sound group state
---@param self ExtendedVehicle
---@param actionName string
---@param inputValue number
function ExtendedVehicle.actionEventToggleSoundGroup(self, actionName, inputValue, callbackState, isAnalog)
  local soundGroup = self:getSoundGroupByInput(actionName, ExtendedVehicle.SOUND_GROUP_INPUT_TYPE.TOGGLE)

  if soundGroup == nil then
    return
  end

  if soundGroup.inputMode == ExtendedVehicle.INPUT_MODE.BUTTON then
    local currentExtendedSound = self:getCurrentExtendedSound(soundGroup)
    if currentExtendedSound ~= nil then
      self:setExtendedSoundStateByIndex(currentExtendedSound.index, inputValue > 0)
    end
  else
    self:toggleCurrentExtendedSound(soundGroup)
  end
end

---Action event to switch sound of sound group
---@param self ExtendedVehicle
---@param actionName string
---@param inputValue number
function ExtendedVehicle.actionEventSwitchSoundGroup(self, actionName, inputValue, callbackState, isAnalog)
  local soundGroup = self:getSoundGroupByInput(actionName, ExtendedVehicle.SOUND_GROUP_INPUT_TYPE.SWITCH)
  if soundGroup == nil then
    return
  end

  -- look for next index or go back to 0 if there are no more
  local currentSoundIndex = soundGroup.currentSoundIndex + 1
  if currentSoundIndex >= #soundGroup.extendedSounds then
    currentSoundIndex = 0
  end

  local spec = self.spec_extendedVehicle
  local soundGroupIndex = TableUtils.indexOf(spec.soundGroups, soundGroup)

  if soundGroupIndex ~= -1 then
    self:setSoundGroupCurrentSound(soundGroupIndex, currentSoundIndex)
  end
end
