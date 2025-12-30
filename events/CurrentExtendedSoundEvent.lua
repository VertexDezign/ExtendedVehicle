---@class CurrentExtendedSoundEvent

CurrentExtendedSoundEvent = {}
local currentExtendedSoundEvent_event = Class(CurrentExtendedSoundEvent, Event)

InitEventClass(CurrentExtendedSoundEvent, "CurrentExtendedSoundEvent")

---@return CurrentExtendedSoundEvent
function CurrentExtendedSoundEvent.emptyNew()
    local self = Event.new(currentExtendedSoundEvent_event)
    return self
end

function CurrentExtendedSoundEvent.new(object, soundGroupIndex, index)
    local self = CurrentExtendedSoundEvent.emptyNew()

    self.object = object
    self.soundGroupIndex = soundGroupIndex
    self.index = index

    return self
end

function CurrentExtendedSoundEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.soundGroupIndex = streamReadUInt8(streamId)
    self.index = streamReadUInt8(streamId)

    self:run(connection)
end

function CurrentExtendedSoundEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUInt8(streamId, self.soundGroupIndex)
    streamWriteUInt8(streamId, self.index)
end

function CurrentExtendedSoundEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setSoundGroupCurrentSound(self.soundGroupIndex, self.index, true)
end

function CurrentExtendedSoundEvent.sendEvent(object, soundGroupIndex, index, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(CurrentExtendedSoundEvent.new(object, soundGroupIndex, index), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(CurrentExtendedSoundEvent.new(object, soundGroupIndex, index))
        end
    end
end
