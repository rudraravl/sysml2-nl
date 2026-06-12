package GreenPeakTechnologiesSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    alias mW for PowerValue;
    alias dBm for Real;
    alias GHz for FrequencyValue;
    alias kbps for Real;
    alias percent for Real;
    alias ms for TimeValue;
    alias year for TimeValue;

    attribute def PacketLossRatio : Real {
        constraint range { 0.0 <= self and self <= 1.0; }
    }

    attribute def LinkQualityIndex : Real {
        constraint range { 0.0 <= self and self <= 255.0; }
    }

    attribute def NetworkAddress : String;
    attribute def DeviceIdentifier : String;
    attribute def SecurityKey : String;

    enum def DeviceRole {
        enum coordinator;
        enum router;
        enum endDevice;
    }

    enum def RadioBand {
        enum ism2400MHz;
    }

    enum def MessagePriority {
        enum low;
        enum normal;
        enum high;
        enum emergency;
    }

    item def SensorReading {
        attribute sourceId : DeviceIdentifier;
        attribute measuredValue : Real;
        attribute unitSymbol : String;
        attribute timestampMs : Real;
        attribute priority : MessagePriority = MessagePriority::normal;
    }

    item def ControlCommand {
        attribute destinationId : DeviceIdentifier;
        attribute commandName : String;
        attribute commandValue : String;
        attribute priority : MessagePriority = MessagePriority::normal;
    }

    item def WirelessFrame {
        attribute sourceAddress : NetworkAddress;
        attribute destinationAddress : NetworkAddress;
        attribute payloadLengthBytes : Real;
        attribute encrypted : Boolean = true;
        attribute lqi : LinkQualityIndex;
        attribute retryCount : Real;
    }

    item def ApplicationEvent {
        attribute eventName : String;
        attribute sourceId : DeviceIdentifier;
        attribute severity : MessagePriority;
        attribute eventTimeMs : Real;
    }

    port def WirelessRadioPort {
        out item transmittedFrame : WirelessFrame;
        in item receivedFrame : WirelessFrame;
        attribute centerFrequency : GHz;
        attribute transmitPower : dBm;
        attribute receiverSensitivity : dBm;
    }

    port def SensorInterfacePort {
        in item reading : SensorReading;
    }

    port def CommandInterfacePort {
        out item command : ControlCommand;
    }

    port def GatewayApplicationPort {
        out item event : ApplicationEvent;
        in item command : ControlCommand;
    }

    port def PowerPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute availableCurrent : CurrentValue;
        out attribute consumedPower : PowerValue;
    }

    action def AcquireSensorReading {
        in item rawReading : SensorReading;
        out item normalizedReading : SensorReading;
    }

    action def EncryptPayload {
        in item plainReading : SensorReading;
        in attribute key : SecurityKey;
        out item encryptedFrame : WirelessFrame;
    }

    action def TransmitWirelessFrame {
        in item frameToSend : WirelessFrame;
        out attribute transmissionSucceeded : Boolean;
    }

    action def ReceiveWirelessFrame {
        in item inboundFrame : WirelessFrame;
        out item decodedReading : SensorReading;
    }

    action def PublishApplicationEvent {
        in item reading : SensorReading;
        out item event : ApplicationEvent;
    }

    action def RouteMeshFrame {
        in item receivedFrame : WirelessFrame;
        out item forwardedFrame : WirelessFrame;
    }

    state def EndDeviceOperatingState {
        entry action initializeRadio;
        state sleeping;
        state sampling;
        state encrypting;
        state transmitting;
        state waitingForAck;
        state fault;

        transition first sleeping;
        transition wakeUp
            first sleeping then sampling;

        transition sampleComplete
            first sampling then encrypting;

        transition payloadSecured
            first encrypting then transmitting;

        transition frameSent
            first transmitting then waitingForAck;

        transition ackReceived
            first waitingForAck then sleeping;

        transition retryRequired
            first waitingForAck then transmitting;

        transition unrecoverableRadioError
            first transmitting then fault;

        transition resetComplete
            first fault then sleeping;
    }

    state def GatewayOperatingState {
        state commissioning;
        state networkFormed;
        state monitoring;
        state commandDispatch;
        state degradedOperation;

        transition first commissioning;
        transition networkReady
            first commissioning then networkFormed;

        transition beginMonitoring
            first networkFormed then monitoring;

        transition commandReceived
            first monitoring then commandDispatch;

        transition commandSent
            first commandDispatch then monitoring;

        transition linkQualityLow
            first monitoring then degradedOperation;

        transition meshRecovered
            first degradedOperation then monitoring;
    }

    part def GreenPeakWirelessChip {
        attribute deviceId : DeviceIdentifier;
        attribute supportedBand : RadioBand = RadioBand::ism2400MHz;
        attribute nominalFrequency : GHz = 2.4 [GHz];
        attribute maxDataRate : kbps = 250.0;
        attribute sleepPower : mW = 0.003 [mW];
        attribute activeReceivePower : mW = 45.0 [mW];
        attribute activeTransmitPower : mW = 55.0 [mW];
        attribute integratedSecurityEnabled : Boolean = true;

        port radio : WirelessRadioPort {
            attribute centerFrequency = 2.4 [GHz];
            attribute transmitPower = 8.0;
            attribute receiverSensitivity = -97.0;
        }

        port power : PowerPort;
    }

    part def ZigbeeMeshProtocolStack {
        attribute networkId : NetworkAddress;
        attribute role : DeviceRole;
        attribute maximumRoutingHops : Real = 8.0;
        attribute securityKey : SecurityKey;
        attribute targetPacketLoss : PacketLossRatio = 0.01;

        perform action routeFrame : RouteMeshFrame;
    }

    part def LowPowerSensorNode {
        attribute nodeId : DeviceIdentifier;
        attribute role : DeviceRole = DeviceRole::endDevice;
        attribute batteryCapacityMah : Real = 220.0;
        attribute expectedBatteryLife : year = 2.0 [year];
        attribute reportingInterval : ms = 60000 [ms];

        part chip : GreenPeakWirelessChip;
        part protocol : ZigbeeMeshProtocolStack {
            attribute role = DeviceRole::endDevice;
        }

        port sensorIn : SensorInterfacePort;
        port radio : WirelessRadioPort;
        port power : PowerPort;

        perform action acquire : AcquireSensorReading;
        perform action encrypt : EncryptPayload;
        perform action transmit : TransmitWirelessFrame;

        exhibit state behavior : EndDeviceOperatingState;

        bind chip.radio = radio;
        bind chip.power = power;

        flow sensorIn.reading to acquire.rawReading;
        flow acquire.normalizedReading to encrypt.plainReading;
        flow protocol.securityKey to encrypt.key;
        flow encrypt.encryptedFrame to transmit.frameToSend;
        flow transmit.frameToSend to radio.transmittedFrame;
    }

    part def SmartHomeGateway {
        attribute gatewayId : DeviceIdentifier;
        attribute role : DeviceRole = DeviceRole::coordinator;
        attribute supportedNodes : Real = 64.0;
        attribute cloudBridgeEnabled : Boolean = true;

        part chip : GreenPeakWirelessChip;
        part protocol : ZigbeeMeshProtocolStack {
            attribute role = DeviceRole::coordinator;
        }

        port radio : WirelessRadioPort;
        port application : GatewayApplicationPort;
        port power : PowerPort;

        perform action receive : ReceiveWirelessFrame;
        perform action publish : PublishApplicationEvent;

        exhibit state behavior : GatewayOperatingState;

        bind chip.radio = radio;
        bind chip.power = power;

        flow radio.receivedFrame to receive.inboundFrame;
        flow receive.decodedReading to publish.reading;
        flow publish.event to application.event;
    }

    part def MeshRepeater {
        attribute repeaterId : DeviceIdentifier;
        attribute role : DeviceRole = DeviceRole::router;
        attribute mainsPowered : Boolean = true;

        part chip : GreenPeakWirelessChip;
        part protocol : ZigbeeMeshProtocolStack {
            attribute role = DeviceRole::router;
        }

        port radio : WirelessRadioPort;
        port power : PowerPort;

        perform action route : RouteMeshFrame;

        bind chip.radio = radio;
        bind chip.power = power;

        flow radio.receivedFrame to route.receivedFrame;
        flow route.forwardedFrame to radio.transmittedFrame;
    }

    part def GreenPeakSmartHomeWirelessSystem {
        doc /* High-level primary function: provide ultra-low-power short-range wireless communication for connected home devices, allowing battery-powered sensors, remotes, and controllers to securely exchange status and control data through a Zigbee-style mesh network. */

        attribute systemName : String = "GreenPeak Technologies Low-Power Smart Home Wireless System";
        attribute primaryFunction : String = "Enable energy-efficient secure wireless connectivity for smart home sensing, monitoring, and control.";
        attribute operatingBand : RadioBand = RadioBand::ism2400MHz;
        attribute nominalNetworkFrequency : GHz = 2.4 [GHz];
        attribute targetNetworkAvailability : percent = 99.5;
        attribute maximumEndToEndLatency : ms = 250 [ms];

        part gateway : SmartHomeGateway {
            attribute gatewayId = "GP-GW-001";
        }

        part temperatureSensor : LowPowerSensorNode {
            attribute nodeId = "GP-TS-101";
            attribute reportingInterval = 60000 [ms];
        }

        part doorContactSensor : LowPowerSensorNode {
            attribute nodeId = "GP-DC-102";
            attribute reportingInterval = 1000 [ms];
        }

        part lightingRemote : LowPowerSensorNode {
            attribute nodeId = "GP-LR-103";
            attribute reportingInterval = 500 [ms];
        }

        part hallwayRepeater : MeshRepeater {
            attribute repeaterId = "GP-RP-201";
        }

        connect temperatureSensor.radio to hallwayRepeater.radio;
        connect doorContactSensor.radio to hallwayRepeater.radio;
        connect lightingRemote.radio to gateway.radio;
        connect hallwayRepeater.radio to gateway.radio;

        port homeAutomationApplication : GatewayApplicationPort;

        bind gateway.application = homeAutomationApplication;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : GreenPeakSmartHomeWirelessSystem;
        require constraint {
            system.primaryFunction == "Enable energy-efficient secure wireless connectivity for smart home sensing, monitoring, and control."
        }
    }

    requirement def LowPowerOperationRequirement {
        subject node : LowPowerSensorNode;
        require constraint {
            node.expectedBatteryLife >= 2.0 [year]
        }
    }

    requirement def SecureCommunicationRequirement {
        subject chip : GreenPeakWirelessChip;
        require constraint {
            chip.integratedSecurityEnabled == true
        }
    }

    requirement def LatencyRequirement {
        subject system : GreenPeakSmartHomeWirelessSystem;
        require constraint {
            system.maximumEndToEndLatency <= 250 [ms]
        }
    }

    requirement def ReliabilityRequirement {
        subject protocol : ZigbeeMeshProtocolStack;
        require constraint {
            protocol.targetPacketLoss <= 0.01
        }
    }

    requirement def MeshCapacityRequirement {
        subject gateway : SmartHomeGateway;
        require constraint {
            gateway.supportedNodes >= 64.0
        }
    }

    satisfy PrimaryFunctionRequirement by GreenPeakSmartHomeWirelessSystem;
    satisfy LowPowerOperationRequirement by LowPowerSensorNode;
    satisfy SecureCommunicationRequirement by GreenPeakWirelessChip;
    satisfy LatencyRequirement by GreenPeakSmartHomeWirelessSystem;
    satisfy ReliabilityRequirement by ZigbeeMeshProtocolStack;
    satisfy MeshCapacityRequirement by SmartHomeGateway;

}