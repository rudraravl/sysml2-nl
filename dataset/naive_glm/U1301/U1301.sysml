package MiWiWirelessSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type FrequencyValue :> Real { unit 'GHz'; }
    value type PowerValue :> Real { unit 'mW'; }
    value type DataRateValue :> Real { unit 'kbps'; }
    value type RSSIValue :> Real { unit 'dBm'; }
    value type DurationValue :> Real { unit 'ms'; }
    value type PayloadSize :> Integer { unit 'byte'; }
    value type BatteryLevel :> Real { unit 'percent'; }
    value type TemperatureValue :> Real { unit 'degC'; }
    value type HumidityValue :> Real { unit 'percent'; }
    value type ChannelNumber :> Integer;
    value type PanId :> Integer;
    value type NodeAddress :> Integer;
    value type SequenceNumber :> Integer;

    // ---- Item definitions ----
    item def Address {
        attribute panId : PanId;
        attribute nodeAddr : NodeAddress;
    }

    item def Packet {
        attribute source : Address;
        attribute destination : Address;
        attribute payload : String;
        attribute payloadSize : PayloadSize;
        attribute requiresAck : Boolean = true;
        attribute sequenceNumber : SequenceNumber;
        attribute ackReceived : Boolean = false;
        attribute hopCount : Integer = 0;
    }

    item def JoinRequest {
        attribute candidateAddress : NodeAddress;
        attribute supportedChannels : ChannelNumber[*];
        attribute deviceCapability : String;
    }

    item def JoinResponse {
        attribute accepted : Boolean;
        attribute assignedAddress : NodeAddress;
        attribute networkPanId : PanId;
        attribute channel : ChannelNumber;
    }

    item def AckPacket {
        attribute ackSequence : SequenceNumber;
        attribute source : Address;
        attribute destination : Address;
    }

    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : DurationValue;
    }

    item def ActuatorCommand {
        attribute commandId : String;
        attribute target : Address;
        attribute parameter : String;
    }

    // ---- Port definitions ----
    port def RFPort {
        out item txPacket : Packet;
        in  item rxPacket : Packet;
        out item joinReq : JoinRequest;
        in  item joinResp : JoinResponse;
        out item ack : AckPacket;
    }

    port def ControlPort {
        out item command : String;
        in  item status : String;
    }

    port def ApplicationPort {
        in  item sensorInput : SensorData;
        out item actuatorOutput : ActuatorCommand;
    }

    // ---- Antenna ----
    part def Antenna {
        attribute gain : Real { unit 'dBi'; } = 2.0;
        attribute impedance : Real { unit 'ohm'; } = 50;
        port rfIf : RFPort;
    }

    // ---- RF Transceiver ----
    part def RFTransceiver {
        attribute operatingFrequency : FrequencyValue = 2.4;
        attribute txPower : PowerValue = 10;
        attribute rxSensitivity : RSSIValue = -90;
        attribute supportedDataRate : DataRateValue = 250;
        attribute currentChannel : ChannelNumber;
        attribute active : Boolean = true;

        port rfFront : RFPort;
        port control : ControlPort;

        state def TransceiverState {
            entry; then Idle;
            state Idle;
            state Transmitting {
                entry { txPacket.payloadSize > 0; }
            }
            state Receiving;
            state Sleeping;

            transition Idle to Sleeping
                when control.command == "sleep";
            transition Sleeping to Idle
                when control.command == "wakeup";
            transition Idle to Transmitting
                when rfFront.txPacket != null;
            transition Transmitting to Idle
                when rfFront.ack != null or timeout;
            transition Idle to Receiving
                when rfFront.rxPacket != null;
            transition Receiving to Idle
                when rfFront.rxPacket.processed == true;
        }

        state transceiverBehavior : TransceiverState;
    }

    // ---- Microcontroller Unit (base) ----
    part def MicrocontrollerUnit {
        attribute clockSpeed : Integer { unit 'MHz'; }
        attribute firmwareVersion : String = "MiWi-1.0";
        attribute memorySize : Integer { unit 'kB'; }

        port radioControl : ControlPort;
        port application : ApplicationPort;
    }

    // ---- Coordinator MCU ----
    part def CoordinatorMCU :> MicrocontrollerUnit {
        attribute networkPanId : PanId;
        attribute operatingChannel : ChannelNumber;
        attribute authorizedNodes : NodeAddress[*] := {};
        attribute routingTable : NodeAddress[*] := {};
        attribute maxChildren : Integer = 32;

        state def CoordinatorStateMachine {
            entry; then Initializing;
            state Initializing {
                entry {
                    operatingChannel = 11;
                    networkPanId = 0x1A2B;
                }
            }
            state NetworkOpen;
            state Authorizing;
            state Routing;
            state Idle;

            transition Initializing to NetworkOpen
                when operatingChannel != null and networkPanId != null;
            transition NetworkOpen to Authorizing
                when radioControl.command == "joinRequest";
            transition Authorizing to NetworkOpen
                when authorizedNodes->size() > 0;
            transition NetworkOpen to Routing
                when application.actuatorOutput != null;
            transition Routing to NetworkOpen
                when routingComplete == true;
            transition NetworkOpen to Idle
                when idleTimeout == true;
            transition Idle to NetworkOpen
                when activityDetected == true;
        }

        state coordinatorBehavior : CoordinatorStateMachine;
    }

    // ---- End Device MCU ----
    part def EndDeviceMCU :> MicrocontrollerUnit {
        attribute assignedAddress : NodeAddress;
        attribute batteryLevel : BatteryLevel = 100;
        attribute sleepInterval : DurationValue = 1000;
        attribute parentAddress : NodeAddress;

        state def EndDeviceStateMachine {
            entry; then PowerOn;
            state PowerOn;
            state Scanning;
            state Joining;
            state Connected;
            state Transmitting;
            state Listening;
            state Sleeping;

            transition PowerOn to Scanning
                when bootComplete == true;
            transition Scanning to Joining
                when networkFound == true;
            transition Joining to Connected
                when authorized == true;
            transition Connected to Transmitting
                when application.sensorInput != null;
            transition Transmitting to Connected
                when radioControl.status == "ackReceived";
            transition Connected to Listening
                when listenWindow == true;
            transition Listening to Connected
                when listenWindow == false;
            transition Connected to Sleeping
                when idleTimeout == true;
            transition Sleeping to Connected
                when wakeupTimer == true;
        }

        state endDeviceBehavior : EndDeviceStateMachine;
    }

    // ---- Wireless Device (base composition) ----
    part def WirelessDevice {
        attribute deviceAddress : NodeAddress;
        attribute deviceType : String;
        port airInterface : RFPort;

        part mcu : MicrocontrollerUnit;
        part transceiver : RFTransceiver;
        part antenna : Antenna;

        connection mcu.radioControl to transceiver.control;
        connection transceiver.rfFront to antenna.rfIf;
        connection antenna.rfIf to airInterface;
    }

    // ---- Network Coordinator ----
    part def NetworkCoordinator :> WirelessDevice {
        attribute networkId : PanId;
        attribute channel : ChannelNumber;
        attribute routingTable : NodeAddress[*];

        part redef mcu : CoordinatorMCU;
    }

    // ---- End Device ----
    part def EndDevice :> WirelessDevice {
        attribute batteryPowered : Boolean = true;
        attribute deviceType : String = "EndDevice";

        part redef mcu : EndDeviceMCU;
    }

    // ---- Temperature Sensor ----
    part def TemperatureSensor :> EndDevice {
        attribute deviceType := "TemperatureSensor";
        attribute samplingInterval : DurationValue = 5000;
        attribute lastReading : SensorData;

        action def readSensor {
            in tempInput : TemperatureValue;
            in humidInput : HumidityValue;
            out data : SensorData;
        }
    }

    // ---- Light Actuator ----
    part def LightActuator :> EndDevice {
        attribute deviceType := "LightActuator";
        attribute lightOn : Boolean = false;

        action def toggleLight {
            in cmd : ActuatorCommand;
            out newState : Boolean;
        }
    }

    // ---- MiWi Network ----
    part def MiWiNetwork {
        attribute networkPanId : PanId;
        attribute operatingChannel : ChannelNumber;
        attribute operatingFrequency : FrequencyValue = 2.4;
        attribute topology : String = "mesh";

        part coordinator : NetworkCoordinator;
        part endDevices : EndDevice[*];

        connection coordinator.airInterface to endDevices.airInterface;
        connection endDevices.airInterface to endDevices.airInterface;
    }

    // ---- Requirements ----
    requirement def FrequencyBandRequirement {
        subject network : MiWiNetwork;
        objective {
            doc "The system shall operate in the 2.4 GHz ISM band."
        }
        require network.operatingFrequency == 2.4;
    }

    requirement def NetworkEstablishmentRequirement {
        subject coordinator : NetworkCoordinator;
        objective {
            doc "The coordinator shall establish a MiWi network on a specific channel with a unique PAN ID."
        }
        require coordinator.networkId != null and coordinator.channel != null;
    }

    requirement def DeviceAuthorizationRequirement {
        subject coordinator : NetworkCoordinator;
        subject endDevice : EndDevice;
        objective {
            doc "The coordinator shall authorize end devices to join the network."
        }
        require endDevice.mcu.assignedAddress != null;
    }

    requirement def LowPowerRequirement {
        subject endDevice : EndDevice;
        objective {
            doc "End devices shall support sleep mode to conserve battery power."
        }
        require endDevice.batteryPowered == true;
    }

    requirement def MeshRoutingRequirement {
        subject network : MiWiNetwork;
        objective {
            doc "The network shall support mesh topology for relaying packets through intermediate devices."
        }
        require network.topology == "mesh" and network.endDevices->size() >= 2;
    }

    requirement def ReliableDeliveryRequirement {
        subject packet : Packet;
        objective {
            doc "Packets shall include source/destination addresses and acknowledgment mechanisms."
        }
        require packet.source != null and packet.destination != null and packet.requiresAck == true;
    }

    requirement def PacketStructureRequirement {
        subject packet : Packet;
        objective {
            doc "Each packet shall contain source address, destination address, payload, and sequence number."
        }
        require packet.source != null and packet.destination != null and packet.payload != null and packet.sequenceNumber != null;
    }

    // ---- Requirement satisfaction ----
    satisfaction FrequencyBandRequirement {
        subject network : MiWiNetwork;
    }
    satisfaction NetworkEstablishmentRequirement {
        subject coordinator : NetworkCoordinator;
    }
    satisfaction LowPowerRequirement {
        subject endDevice : EndDevice;
    }
    satisfaction MeshRoutingRequirement {
        subject network : MiWiNetwork;
    }
    satisfaction ReliableDeliveryRequirement {
        subject packet : Packet;
    }
}
