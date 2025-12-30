---
--- PumpVehicle specialization for fire trucks with a water tank and a pump.
---
--- @author  Grisu118 - VertexDezign.net
--- @history 2025-12-30 - Initial implementation
---

PumpVehicle = {}

function PumpVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(FillUnit, specializations)
end

function PumpVehicle.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("PumpVehicle")

    schema:register(XMLValueType.INT, "vehicle.pumpVehicle#fillUnitIndex", "Index of the water tank fill unit", 1)
    schema:register(XMLValueType.FLOAT, "vehicle.pumpVehicle#litersPerSecond", "Water consumption per second when pumping", 5.0)

    schema:register(XMLValueType.L10N_STRING, "vehicle.pumpVehicle#turnOnText", "Turn on pump text", "action_turnOnPump")
    schema:register(XMLValueType.L10N_STRING, "vehicle.pumpVehicle#turnOffText", "Turn off pump text", "action_turnOffPump")

    SoundManager.registerSampleXMLPaths(schema, "vehicle.pumpVehicle.sounds", "work(?)")
    EffectManager.registerEffectXMLPaths(schema, "vehicle.pumpVehicle.effects")

    schema:setXMLSpecializationType()
end

function PumpVehicle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", PumpVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", PumpVehicle)
end

function PumpVehicle.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setIsPumpOn", PumpVehicle.setIsPumpOn)
    SpecializationUtil.registerFunction(vehicleType, "getIsPumpOn", PumpVehicle.getIsPumpOn)
end

function PumpVehicle:onLoad(savegame)
    self.spec_pumpVehicle = {
        logger = GrisuDebug:create("PumpVehicle"),
        actionEvents = {},
    }
    local spec = self.spec_pumpVehicle

    spec.fillUnitIndex = self.xmlFile:getValue("vehicle.pumpVehicle#fillUnitIndex", 1)
    spec.litersPerSecond = self.xmlFile:getValue("vehicle.pumpVehicle#litersPerSecond", 5.0)

    spec.isPumpOn = false

    if self.isClient then
        spec.samples = {}
        spec.samples.work = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.pumpVehicle.sounds", "work", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
        spec.effects = g_effectManager:loadEffect(self.xmlFile, "vehicle.pumpVehicle.effects", self.components, self, self.i3dMappings)
    end

    spec.turnOnText = self.xmlFile:getValue("vehicle.pumpVehicle#turnOnText", "action_turnOnPump", self.customEnvironment, true)
    spec.turnOffText = self.xmlFile:getValue("vehicle.pumpVehicle#turnOffText", "action_turnOffPump", self.customEnvironment, true)

    spec.dirtyFlag = self:getNextDirtyFlag()
end

function PumpVehicle:onDelete()
    local spec = self.spec_pumpVehicle
    if self.isClient then
        g_soundManager:deleteSamples(spec.samples)
        g_effectManager:deleteEffects(spec.effects)
    end
end

function PumpVehicle:onUpdate(dt)
    local spec = self.spec_pumpVehicle
    if spec.isPumpOn then
        if self.isServer then
            local fillLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
            if fillLevel <= 0 then
                self:setIsPumpOn(false)
            end
        end

        if self.isClient then
            if not g_soundManager:getIsSamplePlaying(spec.samples.work) then
                g_soundManager:playSample(spec.samples.work)
            end
            g_effectManager:setEffectTypeInfo(spec.effects, FillType.WATER)
            g_effectManager:startEffects(spec.effects)
        end
    else
        if self.isClient then
            if g_soundManager:getIsSamplePlaying(spec.samples.work) then
                g_soundManager:stopSample(spec.samples.work)
            end
            g_effectManager:stopEffects(spec.effects)
        end
    end
end

function PumpVehicle:onReadStream(streamId, connection)
    local isPumpOn = streamReadBool(streamId)
    self:setIsPumpOn(isPumpOn, true)
end

function PumpVehicle:onWriteStream(streamId, connection)
    local spec = self.spec_pumpVehicle
    streamWriteBool(streamId, spec.isPumpOn)
end

function PumpVehicle:onReadUpdateStream(streamId, timestamp, connection)
    if not connection:getIsServer() then
        local spec = self.spec_pumpVehicle
        if streamReadBool(streamId) then
            local isPumpOn = streamReadBool(streamId)
            self:setIsPumpOn(isPumpOn, true)
        end
    end
end

function PumpVehicle:onWriteUpdateStream(streamId, connection, dirtyMask)
    if connection:getIsServer() then
        local spec = self.spec_pumpVehicle
        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.isPumpOn)
        end
    end
end

function PumpVehicle:setIsPumpOn(isPumpOn, noEventSend)
    local spec = self.spec_pumpVehicle
    if isPumpOn ~= spec.isPumpOn then
        PumpVehicleEvent.sendEvent(self, isPumpOn, noEventSend)
        local fillLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
        if isPumpOn and fillLevel <= 0 then
            g_currentMission:showBlinkingWarning("No water in the tank", 2000)
        end

        spec.isPumpOn = isPumpOn
        if self.isClient then
            PumpVehicle.updateActionEvents(self)
        end
        self:raiseDirtyFlags(spec.dirtyFlag)
    end
end

function PumpVehicle:getIsPumpOn()
    return self.spec_pumpVehicle.isPumpOn
end

function PumpVehicle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_pumpVehicle
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            --TODO custom button
            local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, "IMPLEMENT_EXTRA", self, PumpVehicle.actionEventTogglePump, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)

            PumpVehicle.updateActionEvents(self)
        end
    end
end

function PumpVehicle.updateActionEvents(self)
    local spec = self.spec_pumpVehicle
    local actionEvent = spec.actionEvents["IMPLEMENT_EXTRA"]
    if actionEvent ~= nil then
        local text
        if spec.isPumpOn then
            text = spec.turnOffText
        else
            text = spec.turnOnText
        end
        g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
    end
end

function PumpVehicle.actionEventTogglePump(self, actionName, inputValue, callbackState, isAnalog)
    self:setIsPumpOn(not self:getIsPumpOn())
end
