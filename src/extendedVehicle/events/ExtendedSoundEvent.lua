---@class ExtendedSoundEvent

ExtendedSoundEvent = {}
local ExtendedSoundEvent_event = Class(ExtendedSoundEvent, Event)

InitEventClass(ExtendedSoundEvent, "ExtendedSoundEvent")

---@return ExtendedSoundEvent
function ExtendedSoundEvent.emptyNew()
    local self = Event.new(ExtendedSoundEvent_event)
    return self
end

function ExtendedSoundEvent.new(object, index, state)
    local self = ExtendedSoundEvent.emptyNew()

    self.object = object
    self.index = index
    self.state = state

    return self
end

function ExtendedSoundEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.index = streamReadUInt8(streamId)
    self.state = streamReadBool(streamId)

    self:run(connection)
end

function ExtendedSoundEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUInt8(streamId, self.index)
    streamWriteBool(streamId, self.state)
end

function ExtendedSoundEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setExtendedSoundStateByIndex(self.index, self.state, true)
end

function ExtendedSoundEvent.sendEvent(object, index, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ExtendedSoundEvent.new(object, index, state), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ExtendedSoundEvent.new(object, index, state))
        end
    end
end
