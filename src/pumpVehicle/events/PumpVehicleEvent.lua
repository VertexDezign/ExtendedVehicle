---
--- Event for syncing PumpVehicle state.
---
--- @author  Grisu118 - VertexDezign.net
--- @history 2025-12-30 - Initial implementation
---

PumpVehicleEvent = {}
PumpVehicleEvent_mt = Class(PumpVehicleEvent, Event)

InitEventClass(PumpVehicleEvent, "PumpVehicleEvent")

function PumpVehicleEvent.emptyNew()
    local self = Event.new(PumpVehicleEvent_mt)
    return self
end

function PumpVehicleEvent.new(vehicle, isPumpOn)
    local self = PumpVehicleEvent.emptyNew()
    self.vehicle = vehicle
    self.isPumpOn = isPumpOn
    return self
end

function PumpVehicleEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isPumpOn = streamReadBool(streamId)
    self:run(connection)
end

function PumpVehicleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isPumpOn)
end

function PumpVehicleEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setIsPumpOn(self.isPumpOn, true)
    end
end

function PumpVehicleEvent.sendEvent(vehicle, isPumpOn, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PumpVehicleEvent.new(vehicle, isPumpOn), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(PumpVehicleEvent.new(vehicle, isPumpOn))
        end
    end
end
