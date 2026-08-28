package IoTGateway {
    import SI::*;
    import ScalarValues::*;

    -- ===== Value Types =====
    def TemperatureValue :> Real { unit '°C'; }
    def MotionValue :> Boolean;
    def MeterValue :> Real { unit 'kWh'; }
    def DataRate :> Real { unit 'kb/s'; }
    def Latency :> Real { unit 'ms'; }
    def Distance :> Real { unit 'm'; }
    def DeviceCount :> Integer;
    def Timestamp :> Real { unit 's'; }

    -- ===== Enums =====
    enum ProtocolKind { MQTT, CoAP, Zigbee }
    enum SensorKind { Temperature, Motion, SmartMeter }
    enum CloudStatus { Connected, Disconnected }

    -- ===== Item Definitions =====
    item def SensorData {
        attribute sensorId : String;
        attribute kind : SensorKind;
        attribute timestamp : Timestamp;
        attribute temperature : TemperatureValue optional;
        attribute motion : MotionValue optional;
        attribute meter : MeterValue optional;
    }

    item def AggregatedData {
        attribute packageId : String;
        attribute timestamp : Timestamp;
        attribute readings : SensorData[0..*];
    }

    item def EncryptedData {
        attribute payload : AggregatedData;
        attribute checksum : String;
    }

    item def DeviceRegistration {
        attribute deviceId : String;
        attribute kind : SensorKind;
        attribute protocol : ProtocolKind;
    }

    item def PerformanceMetrics {
        attribute connectedDevices : DeviceCount;
        attribute throughput : DataRate;
        attribute latency : Latency;
    }

    -- ===== Port Definitions =====
    port def SensorPort {
        out item data : SensorData;
        out item registration : DeviceRegistration;
    }

    port def AggregationPort {
        out item aggregated : AggregatedData;
    }

    port def CloudPort {
        in item payload : EncryptedData;
        out item status : CloudStatus;
    }

    port def MetricsPort {
        out item metrics : PerformanceMetrics;
    }

    -- ===== Abstract Sensor =====
    part def AbstractSensor {
        attribute sensorId : String;
        attribute kind : SensorKind;
        port sensorOut : SensorPort;
    }

    part def TemperatureSensor :> AbstractSensor {
        redefines kind = SensorKind::Temperature;
        attribute currentTemp : TemperatureValue;
    }

    part def MotionDetector :> AbstractSensor {
        redefines kind = SensorKind::Motion;
        attribute detected : MotionValue;
    }

    part def SmartMeter :> AbstractSensor {
        redefines kind = SensorKind::SmartMeter;
        attribute consumption : MeterValue;
    }

    -- ===== Gateway Components =====
    part def WirelessReceiver {
        attribute supportedProtocols : ProtocolKind[3] = [ProtocolKind::MQTT, ProtocolKind::CoAP, ProtocolKind::Zigbee];
        attribute range : Distance = 100.0;
        port receiverOut : SensorPort;
    }

    part def DeviceManager {
        attribute registeredDevices : DeviceCount = 0;
        attribute maxDevices : DeviceCount = 100;
        port managerIn : SensorPort;
        port managerOut : SensorPort;
        action registerDevice {
            in reg : DeviceRegistration;
            decision {
                if registeredDevices < maxDevices then {
                    registeredDevices := registeredDevices + 1;
                }
            }
        }
    }

    part def DataAggregator {
        attribute interval : Timestamp = 5.0;
        attribute buffer : SensorData[0..*];
        port aggregatorIn : SensorPort;
        port aggregatorOut : AggregationPort;
        action aggregate {
            in readings : SensorData[0..*];
            out result : AggregatedData;
        }
    }

    part def CloudConnector {
        attribute cloudStatus : CloudStatus = CloudStatus::Disconnected;
        port cloudIn : AggregationPort;
        port cloudOut : CloudPort;
        action transmit {
            in data : AggregatedData;
            out encrypted : EncryptedData;
        }
    }

    part def LocalStorage {
        attribute capacity : Integer = 10000;
        attribute storedItems : Integer = 0;
        port storageIn : AggregationPort;
        port storageOut : AggregationPort;
        action buffer {
            in data : AggregatedData;
        }
        action flush {
            out data : AggregatedData[0..*];
        }
    }

    part def EncryptionModule {
        attribute algorithm : String = "AES-256";
        port encryptIn : AggregationPort;
        port encryptOut : CloudPort;
        action encrypt {
            in data : AggregatedData;
            out encrypted : EncryptedData;
        }
    }

    part def SystemMonitor {
        attribute connectedDevices : DeviceCount = 0;
        attribute throughput : DataRate = 0.0;
        attribute latency : Latency = 0.0;
        port monitorOut : MetricsPort;
        action collectMetrics {
            out metrics : PerformanceMetrics;
        }
    }

    -- ===== Gateway Part with State Machine =====
    part def IoTGateway {
        attribute gatewayId : String;
        attribute maxDevices : DeviceCount = 100;

        port gatewaySensorIn : SensorPort;
        port gatewayCloudOut : CloudPort;
        port gatewayMetricsOut : MetricsPort;

        part receiver : WirelessReceiver;
        part deviceManager : DeviceManager;
        part aggregator : DataAggregator;
        part cloudConnector : CloudConnector;
        part localStorage : LocalStorage;
        part encryption : EncryptionModule;
        part monitor : SystemMonitor;

        -- Connections
        connect receiver.receiverOut to deviceManager.managerIn;
        connect deviceManager.managerOut to aggregator.aggregatorIn;
        connect aggregator.aggregatorOut to encryption.encryptIn;
        connect encryption.encryptOut to cloudConnector.cloudIn;
        connect cloudConnector.cloudOut to gatewayCloudOut;
        connect aggregator.aggregatorOut to localStorage.storageIn;
        connect localStorage.storageOut to encryption.encryptIn;
        connect monitor.monitorOut to gatewayMetricsOut;

        -- State Machine
        state def GatewayStates {
            entry; exit;
            state Initializing;
            state Ready;
            state ProcessingData;
            state Transmitting;
            state Buffering;
            state Maintenance;

            transition init_to_ready {
                from Initializing to Ready
                when receiver.supportedProtocols->isNotEmpty();
            }

            transition ready_to_processing {
                from Ready to ProcessingData
                when deviceManager.managerOut->isInvoked();
            }

            transition processing_to_transmitting {
                from ProcessingData to Transmitting
                when cloudConnector.cloudStatus == CloudStatus::Connected;
            }

            transition processing_to_buffering {
                from ProcessingData to Buffering
                when cloudConnector.cloudStatus == CloudStatus::Disconnected;
            }

            transition buffering_to_transmitting {
                from Buffering to Transmitting
                when cloudConnector.cloudStatus == CloudStatus::Connected;
            }

            transition transmitting_to_ready {
                from Transmitting to Ready
                when true;
            }

            transition any_to_maintenance {
                from Ready to Maintenance
                when false;
            }

            transition maintenance_to_ready {
                from Maintenance to Ready
                when true;
            }
        }

        exhibit behavior GatewayStates;
    }

    -- ===== Requirements =====
    requirement def DeviceManagementRequirement {
        doc "The gateway shall manage up to 100 IoT devices.";
        subject gateway : IoTGateway;
        assume {
            gateway.maxDevices == 100;
        }
    }

    requirement def WirelessRangeRequirement {
        doc "The wireless receiver shall communicate within a 100-meter range.";
        subject receiver : WirelessReceiver;
        assume {
            receiver.range >= 100.0;
        }
    }

    requirement def ProtocolSupportRequirement {
        doc "The gateway shall support MQTT, CoAP, and Zigbee protocols.";
        subject receiver : WirelessReceiver;
        assume {
            receiver.supportedProtocols->includes(ProtocolKind::MQTT) and
            receiver.supportedProtocols->includes(ProtocolKind::CoAP) and
            receiver.supportedProtocols->includes(ProtocolKind::Zigbee);
        }
    }

    requirement def DataBufferingRequirement {
        doc "If cloud connectivity is lost, the gateway shall buffer all incoming sensor data in local storage and forward it upon reconnection.";
        subject gateway : IoTGateway;
        assume {
            gateway.cloudConnector.cloudStatus == CloudStatus::Disconnected implies
            gateway.localStorage.storedItems > 0;
        }
    }

    requirement def EncryptionRequirement {
        doc "All data transmissions shall be encrypted.";
        subject encryption : EncryptionModule;
        assume {
            encryption.algorithm == "AES-256";
        }
    }

    requirement def MonitoringRequirement {
        doc "The system monitor shall track connected devices, throughput, and latency.";
        subject monitor : SystemMonitor;
        assume {
            monitor.connectedDevices >= 0 and
            monitor.throughput >= 0.0 and
            monitor.latency >= 0.0;
        }
    }

    requirement def StateManagementRequirement {
        doc "The gateway shall operate in states: initializing, ready, processing data, transmitting, buffering, and maintenance.";
        subject gateway : IoTGateway;
    }

    -- ===== Verification =====
    verification DeviceManagementVerification {
        objective {
            doc "Verify the gateway can register up to 100 devices.";
        }
        subject gateway : IoTGateway;
        verify DeviceManagementRequirement;
    }

    verification WirelessRangeVerification {
        objective {
            doc "Verify the wireless receiver operates within 100 meters.";
        }
        subject receiver : WirelessReceiver;
        verify WirelessRangeRequirement;
    }

    verification ProtocolSupportVerification {
        objective {
            doc "Verify MQTT, CoAP, and Zigbee are supported.";
        }
        subject receiver : WirelessReceiver;
        verify ProtocolSupportRequirement;
    }

    verification DataBufferingVerification {
        objective {
            doc "Verify data buffering during cloud disconnection.";
        }
        subject gateway : IoTGateway;
        verify DataBufferingRequirement;
    }

    verification EncryptionVerification {
        objective {
            doc "Verify encryption is applied to all transmissions.";
        }
        subject encryption : EncryptionModule;
        verify EncryptionRequirement;
    }

    verification MonitoringVerification {
        objective {
            doc "Verify system monitor tracks required metrics.";
        }
        subject monitor : SystemMonitor;
        verify MonitoringRequirement;
    }
}
}
