package MiWiWirelessSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def FrequencyGHz :> ScalarValues::Real;
    attribute def BatteryVoltage :> ScalarValues::Real;
    attribute def SignalStrength :> ScalarValues::Real;
    attribute def Duration_ms :> ScalarValues::Real;
    attribute def Current_uA :> ScalarValues::Real;

    item def MiWiPacket {
        attribute sourceAddr : String;
        attribute destAddr : String;
        attribute payload : String;
        attribute sequenceNum : Integer;
        attribute ackRequired : Boolean;
    }

    item def JoinRequest {
        attribute deviceAddr : String;
        attribute deviceType : String;
        attribute capabilities : String;
    }

    item def JoinResponse {
        attribute networkId : String;
        attribute granted : Boolean;
        attribute assignedAddr : String;
        attribute channel : Integer;
    }

    item def Ack {
        attribute sequenceNum : Integer;
        attribute status : Boolean;
    }

    item def BeaconFrame {
        attribute networkId : String;
        attribute channel : Integer;
        attribute coordinatorAddr : String;
        attribute permitJoining : Boolean;
    }

    item def SensorReading {
        attribute sensorType : String;
        attribute value : Real;
        attribute unit : String;
    }

    port def WirelessPort {
        in item rxPacket : MiWiPacket;
        out item txPacket : MiWiPacket;
        in item rxJoinReq : JoinRequest;
        out item txJoinReq : JoinRequest;
        in item rxJoinResp : JoinResponse;
        out item txJoinResp : JoinResponse;
        in item rxAck : Ack;
        out item txAck : Ack;
        in item rxBeacon : BeaconFrame;
        out item txBeacon : BeaconFrame;
    }

    port def MCUInterface {
        in item dataToMCU : SensorReading;
        out item dataFromMCU : SensorReading;
    }

    part def MCU {
        attribute clockSpeedMHz : Integer;
        attribute flashMemoryKB : Integer;
        attribute ramKB : Integer;
        port dataBus : MCUInterface;
        state MCUState {
            entry; then Idle;
            state Idle;
            state Processing;
            transition idle_to_processing first Idle accept data : SensorReading via dataBus then Processing;
            transition processing_to_idle first Processing then Idle;
        }
    }

    part def RFTransceiver {
        attribute operatingFrequencyHz : Real = 2.4e9;
        attribute txPowerDbm : SignalStrength;
        attribute modulation : String = "FSK";
        attribute dataRateKbps : Integer;
        attribute channel : Integer;
        port airInterface : WirelessPort;
        state TransceiverState {
            entry; then Idle;
            state Idle;
            state Transmitting;
            state Receiving;
            state Sleeping;
            transition idle_to_tx first Idle accept pkt : MiWiPacket via airInterface then Transmitting;
            transition tx_to_idle first Transmitting then Idle;
            transition idle_to_sleep first Idle then Sleeping;
            transition sleep_to_idle first Sleeping then Idle;
        }
    }

    abstract part def MiWiDevice {
        attribute deviceAddress : String;
        attribute networkId : String;
        attribute channel : Integer;
        part mcu : MCU;
        part rfTransceiver : RFTransceiver;
        connect mcu.dataBus to rfTransceiver.airInterface;
        port wirelessPort : WirelessPort;
    }

    part def NetworkCoordinator :> MiWiDevice {
        attribute permitJoining : Boolean = true;
        attribute routingTable : String;
        state CoordinatorBehavior {
            entry; then NetworkInit;
            state NetworkInit {
                entry; then Broadcasting;
            }
            state Broadcasting {
                entry send new BeaconFrame(networkId, channel, deviceAddress, permitJoining) via wirelessPort;
                then Listening;
            }
            state Listening;
            transition acceptJoin
                first Listening
                accept req : JoinRequest via wirelessPort
                do send new JoinResponse(networkId, true, req.deviceAddr, channel) via wirelessPort
                then Listening;
            transition routePacket
                first Listening
                accept pkt : MiWiPacket via wirelessPort
                if pkt.destAddr != deviceAddress
                do send pkt via wirelessPort
                then Listening;
            transition processData
                first Listening
                accept pkt : MiWiPacket via wirelessPort
                if pkt.destAddr == deviceAddress
                do send new Ack(pkt.sequenceNum, true) via wirelessPort
                then Listening;
        }
    }

    part def EndDevice :> MiWiDevice {
        attribute batteryLevel : BatteryVoltage;
        attribute sensorType : String;
        attribute parentAddr : String;
        attribute sleepMode : Boolean = false;
        state EndDeviceBehavior {
            entry; then Scanning;
            state Scanning;
            state WaitForJoin;
            state Connected;
            state WaitForAck;
            state Sleeping;
            transition sendJoin
                first Scanning
                do send new JoinRequest(deviceAddress, sensorType, "basic") via wirelessPort
                then WaitForJoin;
            transition joinAccepted
                first WaitForJoin
                accept resp : JoinResponse via wirelessPort
                if resp.granted == true
                then Connected;
            transition joinDenied
                first WaitForJoin
                accept resp : JoinResponse via wirelessPort
                if resp.granted == false
                then Scanning;
            transition sendData
                first Connected
                do send new MiWiPacket(deviceAddress, "coordinator", "sensor_data", 1, true) via wirelessPort
                then WaitForAck;
            transition relayPacket
                first Connected
                accept pkt : MiWiPacket via wirelessPort
                if pkt.destAddr != deviceAddress
                do send pkt via wirelessPort
                then Connected;
            transition receiveData
                first Connected
                accept pkt : MiWiPacket via wirelessPort
                if pkt.destAddr == deviceAddress
                do send new Ack(pkt.sequenceNum, true) via wirelessPort
                then Connected;
            transition receivedAck
                first WaitForAck
                accept ackMsg : Ack via wirelessPort
                if ackMsg.status == true
                then Connected;
            transition ackTimeout
                first WaitForAck
                then Connected;
            transition enterSleep
                first Connected
                then Sleeping;
            transition wakeUp
                first Sleeping
                then Connected;
        }
    }

    connection def WirelessLink {
        end source : WirelessPort;
        end target : WirelessPort;
        attribute signalStrength : SignalStrength;
        attribute latency : Duration_ms;
    }

    connection def MeshRelay {
        end source : WirelessPort;
        end target : WirelessPort;
    }

    part def MiWiNetwork {
        part coordinator : NetworkCoordinator {
            attribute deviceAddress = "COORD_001";
            attribute networkId = "PAN_0001";
            attribute channel = 11;
        }
        part endDevices[1..*] : EndDevice;
        connect coordinator.wirelessPort to endDevices.wirelessPort;
    }

    part miwiDeployment : MiWiNetwork {
        part coordinator : NetworkCoordinator {
            attribute deviceAddress = "COORD_001";
            attribute networkId = "PAN_0001";
            attribute channel = 11;
        }
        part tempSensor : EndDevice {
            attribute deviceAddress = "END_001";
            attribute sensorType = "temperature";
            attribute batteryLevel = 3.7;
        }
        part lightSwitch : EndDevice {
            attribute deviceAddress = "END_002";
            attribute sensorType = "actuator";
            attribute batteryLevel = 4.2;
        }
        part relayNode : EndDevice {
            attribute deviceAddress = "END_003";
            attribute sensorType = "relay";
            attribute batteryLevel = 3.5;
        }
        connect coordinator.wirelessPort to tempSensor.wirelessPort;
        connect tempSensor.wirelessPort to relayNode.wirelessPort;
        connect relayNode.wirelessPort to lightSwitch.wirelessPort;
    }

    requirement def LowPowerOperation {
        doc /* End devices must support sleep mode for battery conservation. */
        subject endDevice : EndDevice;
        attribute maxSleepCurrent : Current_uA = 10.0;
        attribute wakeUpTime : Duration_ms = 5.0;
        constraint { endDevice.batteryLevel >= 0.0 }
    }

    requirement def ReliableDelivery {
        doc /* Packet delivery must be acknowledged when ackRequired is set. */
        subject packet : MiWiPacket;
        attribute maxRetries : Integer = 3;
        attribute ackTimeout : Duration_ms = 50.0;
        constraint { packet.ackRequired == true implies true }
    }

    requirement def FrequencyBandCompliance {
        doc /* The system shall operate in the 2.4 GHz ISM band. */
        subject transceiver : RFTransceiver;
        attribute minFrequency : Real = 2.400e9;
        attribute maxFrequency : Real = 2.4835e9;
        attribute availableChannels : Integer[16] = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26];
        constraint { transceiver.operatingFrequencyHz >= 2.400e9 and transceiver.operatingFrequencyHz <= 2.4835e9 }
    }

    requirement def MeshTopologySupport {
        doc /* End devices must be able to relay packets for other end devices to extend range. */
        subject endDevice : EndDevice;
        attribute maxHops : Integer = 5;
        constraint { endDevice.wirelessPort.txPacket != null }
    }

    requirement def CoordinatorManagement {
        doc /* Coordinator must establish network and authorize joins. */
        subject coordinator : NetworkCoordinator;
        attribute uniqueAddressSpace : Integer = 65535;
        attribute joinTimeout : Duration_ms = 30000.0;
        constraint { coordinator.networkId != null }
    }

    satisfy LowPowerOperation by EndDevice;
    satisfy ReliableDelivery by MiWiPacket;
    satisfy FrequencyBandCompliance by RFTransceiver;
    satisfy MeshTopologySupport by EndDevice;
    satisfy CoordinatorManagement by NetworkCoordinator;
}
