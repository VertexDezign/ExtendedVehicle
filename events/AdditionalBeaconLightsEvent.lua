---@class AdditionalBeaconLightsEvent

AdditionalBeaconLightsEvent = {}
local additionalBeaconLightsEvent_event = Class(AdditionalBeaconLightsEvent, Event)

InitEventClass(AdditionalBeaconLightsEvent, "AdditionalBeaconLightsEvent")

---@return AdditionalBeaconLightsEvent
function AdditionalBeaconLightsEvent.emptyNew()
    local self = Event.new(additionalBeaconLightsEvent_event)
    return self
end

function AdditionalBeaconLightsEvent.new(object, index, state)
    local self = AdditionalBeaconLightsEvent.emptyNew()

    self.object = object
    self.index = index
    self.state = state

    return self
end

function AdditionalBeaconLightsEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.index = streamReadUInt8(streamId)
    self.state = streamReadBool(streamId)
    self:run(connection)
end

function AdditionalBeaconLightsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUInt8(streamId, self.index)
    streamWriteBool(streamId, self.state)
end

function AdditionalBeaconLightsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil then
        self.object:setBeaconLightGroupState(self.index, self.state, true)
    end
end

function AdditionalBeaconLightsEvent.sendEvent(object, index, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(AdditionalBeaconLightsEvent.new(object, index, state), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(AdditionalBeaconLightsEvent.new(object, index, state))
        end
    end
end
