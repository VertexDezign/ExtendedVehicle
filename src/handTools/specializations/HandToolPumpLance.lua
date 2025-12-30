---
--- HandToolPumpLance specialization for hand tools connected to a PumpVehicle.
---
--- @author  Grisu118 - VertexDezign.net
---

HandToolPumpLance = {}

function HandToolPumpLance.registerXMLPaths(xmlSchema)
    xmlSchema:setXMLSpecializationType("HandToolPumpLance")
    xmlSchema:register(XMLValueType.NODE_INDEX, "handTool.handToolPumpLance.lance#raycastNode", "The node from which the raycast is performed", nil, false)
    xmlSchema:register(XMLValueType.FLOAT, "handTool.handToolPumpLance.lance#washDistance", "The range in metres that the lance can wash things", "10 metres", false)
    xmlSchema:register(XMLValueType.FLOAT, "handTool.handToolPumpLance.lance#washMultiplier", "The multiplier applied to the wash amount", "1x", false)
    
    EffectManager.registerEffectXMLPaths(xmlSchema, "handTool.handToolPumpLance.effects")
    SoundManager.registerSampleXMLPaths(xmlSchema, "handTool.handToolPumpLance.sounds", "washing")
end

function HandToolPumpLance.registerFunctions(handToolType)
    SpecializationUtil.registerFunction(handToolType, "onWashAction", HandToolPumpLance.onWashAction)
    SpecializationUtil.registerFunction(handToolType, "setIsActivated", HandToolPumpLance.setIsActivated)
    SpecializationUtil.registerFunction(handToolType, "onLanceCallback", HandToolPumpLance.onLanceCallback)
end

function HandToolPumpLance.registerOverwrittenFunctions(handToolType)
    SpecializationUtil.registerOverwrittenFunction(handToolType, "getCanBeDropped", HandToolPumpLance.getCanBeDropped)
end

function HandToolPumpLance.registerEventListeners(handToolType)
    SpecializationUtil.registerEventListener(handToolType, "onLoad", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onDelete", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onWriteUpdateStream", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onReadUpdateStream", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onUpdate", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onRegisterActionEvents", HandToolPumpLance)
    SpecializationUtil.registerEventListener(handToolType, "onHeldEnd", HandToolPumpLance)
end

function HandToolPumpLance.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(HandToolTethered, specializations)
end

function HandToolPumpLance:onLoad(xmlFile, baseDirectory)
    self.spec_handToolPumpLance = {}
    local spec = self.spec_handToolPumpLance

    spec.raycastNode = xmlFile:getValue("handTool.handToolPumpLance.lance#raycastNode", nil, self.components, self.i3dMappings)
    spec.washDistance = xmlFile:getValue("handTool.handToolPumpLance.lance#washDistance", 10)
    spec.washMultiplier = xmlFile:getValue("handTool.handToolPumpLance.lance#washMultiplier", 1)

    if self.isClient then
        spec.effects = g_effectManager:loadEffect(xmlFile, "handTool.handToolPumpLance.effects", self.components, self, self.i3dMappings)
        g_effectManager:setEffectTypeInfo(spec.effects, FillType.WATER)
        spec.washingSample = g_soundManager:loadSampleFromXML(xmlFile, "handTool.handToolPumpLance.sounds", "washing", baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
    end

    spec.isActivated = false
    spec.targetedVehicleId = nil
    spec.activateActionEventId = nil

    spec.isActivatedSent = false
    spec.targetedVehicleIdSent = nil

    spec.dirtyFlag = self:getNextDirtyFlag()
end

function HandToolPumpLance:onDelete()
    local spec = self.spec_handToolPumpLance
    if self.isClient then
        g_effectManager:deleteEffects(spec.effects)
        g_soundManager:deleteSample(spec.washingSample)
    end
end

function HandToolPumpLance:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self.spec_handToolPumpLance
    if streamWriteBool(streamId, spec.isActivatedSent) then
        if connection:getIsServer() then
            if streamWriteBool(streamId, spec.targetedVehicleIdSent ~= nil) then
                NetworkUtil.writeNodeObjectId(streamId, spec.targetedVehicleIdSent)
            end
        end
    end
end

function HandToolPumpLance:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self.spec_handToolPumpLance
    local isActivated = streamReadBool(streamId)
    spec.targetedVehicleId = nil

    if isActivated then
        if not connection:getIsServer() then
            if streamReadBool(streamId) then
                local targetedVehicleId = NetworkUtil.readNodeObjectId(streamId)
                local carryingPlayer = self:getCarryingPlayer()
                if carryingPlayer ~= nil and not carryingPlayer.isOwner then
                    spec.targetedVehicleId = targetedVehicleId
                end
            end
        end
    end

    self:setIsActivated(isActivated)
end

function HandToolPumpLance:onUpdate(dt)
    local carryingPlayer = self:getCarryingPlayer()
    if carryingPlayer == nil then
        return
    end

    local spec = self.spec_handToolPumpLance

    if not spec.isActivated then
        spec.targetedVehicleId = nil
        return
    end

    -- Check if we are connected to a PumpVehicle and if the pump is ON
    local tetheredSpec = self.spec_tethered
    local pumpVehicle = nil
    if tetheredSpec ~= nil and tetheredSpec.attachedHolder ~= nil then
        local vehicle = tetheredSpec.attachedHolder.parent
        if vehicle ~= nil and vehicle.spec_pumpVehicle ~= nil then
            pumpVehicle = vehicle
        end
    end

    if pumpVehicle == nil or not pumpVehicle:getIsPumpOn() then
        if self.isServer then
            self:setIsActivated(false)
        end
        return
    end

    local pumpSpec = pumpVehicle.spec_pumpVehicle
    local fillUnitIndex = pumpSpec.fillUnitIndex
    local fillLevel = pumpVehicle:getFillUnitFillLevel(fillUnitIndex)

    if fillLevel <= 0 then
        if self.isServer then
            self:setIsActivated(false)
        end
        return
    end

    -- Core logic: Cleaning
    if carryingPlayer.isOwner then
        local x, y, z = getWorldTranslation(spec.raycastNode)
        local dirX, dirY, dirZ = localDirectionToWorld(spec.raycastNode, 0, 0, 1)
        raycastClosestAsync(x, y, z, dirX, dirY, dirZ, spec.washDistance, "onLanceCallback", self, CollisionFlag.VEHICLE)

        if spec.targetedVehicleId ~= spec.targetedVehicleIdSent then
            spec.targetedVehicleIdSent = spec.targetedVehicleId
            self:raiseDirtyFlags(spec.dirtyFlag)
        end

        if spec.targetedVehicleId == nil then
            g_inputBinding:setActionEventText(spec.activateActionEventId, string.format(self.activateText, ""))
        else
            local vehicle = NetworkUtil.getObject(spec.targetedVehicleId)
            if vehicle ~= nil then
                g_inputBinding:setActionEventText(spec.activateActionEventId, string.format(self.activateText, vehicle.typeDesc))
            end
        end
    end

    if self.isServer then
        if spec.targetedVehicleId ~= nil then
            local vehicle = NetworkUtil.getObject(spec.targetedVehicleId)
            if vehicle ~= nil then
                -- Remove the dirt from the vehicle.
                vehicle:cleanVehicle((spec.washMultiplier * dt) / vehicle:getWashDuration())
            end
        end

        -- Consume water from the vehicle
        local litersToConsume = pumpSpec.litersPerSecond * dt * 0.001
        pumpVehicle:addFillUnitFillLevel(self:getOwnerFarmId(), fillUnitIndex, -litersToConsume, pumpVehicle:getFillUnitFillType(fillUnitIndex), ToolType.UNDEFINED, nil)
    end

    if self.isClient then
        g_effectManager:setEffectTypeInfo(spec.effects, FillType.WATER)
    end
end

function HandToolPumpLance:onLanceCallback(nodeId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
    local spec = self.spec_handToolPumpLance
    spec.targetedVehicleId = nil

    if nodeId == 0 then
        return false
    end

    local object = g_currentMission:getNodeObject(nodeId)
    if object ~= nil and object.isa ~= nil and object:isa(Vehicle) then
        if object.getAllowsWashingByType ~= nil and object:getAllowsWashingByType(Washable.WASHTYPE_HIGH_PRESSURE_WASHER) then
            spec.targetedVehicleId = NetworkUtil.getObjectId(object)
        end
    end

    return true
end

function HandToolPumpLance:setIsActivated(isActivated)
    local spec = self.spec_handToolPumpLance
    if spec.isActivated == isActivated then
        return
    end

    local carryingPlayer = self:getCarryingPlayer()
    if carryingPlayer == nil then
        return
    end

    spec.isActivated = isActivated

    if carryingPlayer.isOwner then
        spec.isActivatedSent = isActivated
        self:raiseDirtyFlags(spec.dirtyFlag)
    end

    if spec.isActivated then
        if self.isClient then
            g_effectManager:startEffects(spec.effects)
            g_soundManager:playSample(spec.washingSample)
        end
    else
        if self.isClient then
            g_effectManager:stopEffects(spec.effects)
            g_soundManager:stopSample(spec.washingSample)
        end
    end
end

function HandToolPumpLance:onRegisterActionEvents()
    if not self:getIsActiveForInput(true) then
        return
    end

    local spec = self.spec_handToolPumpLance
    local _, actionEventId = self:addActionEvent(InputAction.ACTIVATE_HANDTOOL, self, HandToolPumpLance.onWashAction, false, false, true, true, nil)
    spec.activateActionEventId = actionEventId
    g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
    g_inputBinding:setActionEventText(actionEventId, string.format(self.activateText, ""))
end

function HandToolPumpLance:onWashAction(_, inputValue)
    self:setIsActivated(inputValue > 0)
end

function HandToolPumpLance:getCanBeDropped(superFunc)
    return false
end

function HandToolPumpLance:onHeldEnd()
    self:setIsActivated(false)
    self:returnToHolder(true)
end
