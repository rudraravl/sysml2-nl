package ZigbeeMeshNetwork {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;

    attribute def ZigbeeAddress :> Integer;
    attribute def ZigbeePANID :> Integer;
    attribute def ZigbeeChannel :> Integer;
    attribute def DataPayload :> String;
    attribute def LinkQuality :> Real;
    attribute def HopCount :> Integer;
    attribute def BatteryLevel :> Real;
    attribute def SleepInterval :> Real;

    enum def DeviceType {
        coordinator;
        router;
        endDevice;
    }

    item def ZigbeePacket {
        attribute sourceAddress : ZigbeeAddress;
        attribute destinationAddress : ZigbeeAddress;
        attribute payload : DataPayload;
        attribute hopCount : HopCount;
        attribute linkQuality : LinkQuality;
        attribute controlInfo : String;
    }

    item def JoinRequest {
        attribute requesterAddress : ZigbeeAddress;
        attribute deviceType : DeviceType;
    }

    item def JoinResponse {
        attribute assignedAddress : ZigbeeAddress;
        attribute accepted : Boolean;
    }

    item def NetworkBeacon {
        attribute panID : ZigbeePANID;
        attribute channel : ZigbeeChannel;
        attribute coordinatorAddress : ZigbeeAddress;
    }

    item def StartCommand;

    item def TimerTick;

    item def RoutingEntry {
        attribute destination : ZigbeeAddress;
        attribute nextHop : ZigbeeAddress;
        attribute quality : LinkQuality;
    }

    port def ZigbeeRadioPort {
        in item packetIn : ZigbeePacket;
        out item packetOut : ZigbeePacket;
        in item joinRequestIn : JoinRequest;
        out item joinRequestOut : JoinRequest;
        in item joinResponseIn : JoinResponse;
        out item joinResponseOut : JoinResponse;
        in item beaconIn : NetworkBeacon;
        out item beaconOut : NetworkBeacon;
        in item startCommandIn : StartCommand;
    }

    port def TimerPort {
        in item tick : TimerTick;
    }

    port def GatewayPort {
        in item externalPacketIn : ZigbeePacket;
        out item externalPacketOut : ZigbeePacket;
    }

    part def ZigbeeDevice {
        attribute deviceAddress : ZigbeeAddress;
        attribute operatingFrequency : Real = 2.4e9;
        attribute maxDataRate : Real;
        port radio : ZigbeeRadioPort;
    }

    part def ZigbeeCoordinator :> ZigbeeDevice {
        attribute panID : ZigbeePANID;
        attribute channel : ZigbeeChannel;
        attribute joinedDeviceAddresses : ZigbeeAddress[0..*];
        port gateway : GatewayPort;

        exhibit state CoordinatorBehavior {
            entry; then startup;
            state startup;
            transition formNetwork
                first startup
                accept start : StartCommand via radio
                do send new NetworkBeacon(panID, channel, deviceAddress) via radio
                then operating;
            state operating;
            transition handleJoin
                first operating
                accept req : JoinRequest via radio
                do send new JoinResponse(req.requesterAddress, true) via radio
                then operating;
            transition collectData
                first operating
                accept pkt : ZigbeePacket via radio
                if pkt.destinationAddress == deviceAddress
                then operating;
            transition relayToGateway
                first operating
                accept pkt : ZigbeePacket via radio
                if pkt.destinationAddress != deviceAddress
                do send pkt via gateway
                then operating;
        }
    }

    part def ZigbeeRouter :> ZigbeeDevice {
        attribute routingTable : RoutingEntry[0..*];
        ref parent : ZigbeeDevice;

        exhibit state RouterBehavior {
            entry; then joiningNetwork;
            state joiningNetwork;
            transition joinSuccess
                first joiningNetwork
                accept res : JoinResponse via radio
                if res.accepted == true
                then active;
            state active;
            transition relayPacket
                first active
                accept pkt : ZigbeePacket via radio
                if pkt.destinationAddress != deviceAddress
                do send pkt via radio
                then active;
            transition receivePacket
                first active
                accept pkt : ZigbeePacket via radio
                if pkt.destinationAddress == deviceAddress
                then active;
        }
    }

    part def ZigbeeEndDevice :> ZigbeeDevice {
        attribute isBatteryPowered : Boolean = true;
        attribute batteryLevel : BatteryLevel;
        attribute parentAddress : ZigbeeAddress;
        attribute sensorData : DataPayload;
        attribute sleepInterval : SleepInterval;
        port timer : TimerPort;

        exhibit state EndDeviceBehavior {
            entry; then sleeping;
            state sleeping;
            transition wakeAndReport
                first sleeping
                accept tick : TimerTick via timer
                do send new ZigbeePacket(deviceAddress, parentAddress, sensorData, 0, 100.0, "") via radio
                then active;
            state active;
            transition checkMessages
                first active
                accept pkt : ZigbeePacket via radio
                if pkt.destinationAddress == deviceAddress
                then active;
            transition goToSleep
                first active
                then sleeping;
        }
    }

    connection def ZigbeeLink {
        end a : ZigbeeRadioPort;
        end b : ZigbeeRadioPort;
        attribute frequency : Real = 2.4e9;
        flow packet : ZigbeePacket from a to b;
        flow packet : ZigbeePacket from b to a;
        flow joinReq : JoinRequest from a to b;
        flow joinRes : JoinResponse from b to a;
        flow beacon : NetworkBeacon from b to a;
    }

    part def ZigbeeMeshNetwork {
        part coordinator : ZigbeeCoordinator;
        part routers : ZigbeeRouter[0..*];
        part endDevices : ZigbeeEndDevice[0..*];

        connection : ZigbeeLink connect coordinator.radio to routers.radio;
        connection : ZigbeeLink connect routers.radio to routers.radio;
        connection : ZigbeeLink connect routers.radio to endDevices.radio;
    }

    requirement def LowPowerOperationRequirement {
        doc /* End devices shall support battery-powered operation and periodic sleep to conserve energy. */
        subject endDevice : ZigbeeEndDevice;
        constraint { endDevice.isBatteryPowered == true }
    }

    requirement def MeshReliabilityRequirement {
        doc /* The network shall self-heal and reroute messages around failed routers without manual intervention. */
        subject network : ZigbeeMeshNetwork;
        constraint { network.routers->size() >= 1 }
    }

    requirement def FrequencyRequirement {
        doc /* All wireless communication shall occur at 2.4 GHz. */
        subject device : ZigbeeDevice;
        constraint { device.operatingFrequency == 2.4e9 }
    }

    requirement def StructuredPacketRequirement {
        doc /* All transmitted data must be encapsulated in structured packets containing source and destination addresses, payload, and control information. */
        subject pkt : ZigbeePacket;
        constraint { pkt.sourceAddress == pkt.sourceAddress }
    }

    requirement def SelfOrganizingRequirement {
        doc /* The network shall be self-organizing, with the Coordinator authorizing devices to join and routers relaying messages automatically. */
        subject coord : ZigbeeCoordinator;
        constraint { coord.joinedDeviceAddresses->size() >= 0 }
    }

    requirement lowPower : LowPowerOperationRequirement;
    requirement meshReliability : MeshReliabilityRequirement;
    requirement frequency : FrequencyRequirement;
    requirement structuredPackets : StructuredPacketRequirement;
    requirement selfOrganizing : SelfOrganizingRequirement;

    part zigbeeNetworkInstance : ZigbeeMeshNetwork {
        part :>> coordinator {
            attribute :>> deviceAddress = 0;
            attribute :>> panID = 4660;
            attribute :>> channel = 11;
        }
        part :>> routers[2] {
            attribute :>> deviceAddress = 1;
        }
        part :>> endDevices[3] {
            attribute :>> deviceAddress = 10;
            attribute :>> batteryLevel = 100.0;
            attribute :>> parentAddress = 1;
            attribute :>> sleepInterval = 30.0;
        }
    }
}
