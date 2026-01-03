package MedicalDeviceConnectivitySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def DeviceIdentifier :> String;
    attribute def PatientIdentifier :> String;
    attribute def MessageIdentifier :> String;
    attribute def DataRate :> Real;
    attribute def SignalQuality :> Real;

    enum def DeviceType {
        ventilator;
        infusionPump;
        patientMonitor;
        ecgMonitor;
        pulseOximeter;
    }

    enum def ConnectionState {
        disconnected;
        discovering;
        authenticating;
        connected;
        transmitting;
        error;
    }

    enum def MessagePriority {
        critical;
        high;
        normal;
        low;
    }

    item def VitalSignData {
        attribute timestamp : TimeValue;
        attribute patientId : PatientIdentifier;
        attribute heartRate : Real;
        attribute bloodPressure : Real;
        attribute oxygenSaturation : Real;
        attribute temperature : TemperatureValue;
    }

    item def AlarmMessage {
        attribute messageId : MessageIdentifier;
        attribute deviceId : DeviceIdentifier;
        attribute priority : MessagePriority;
        attribute alarmCode : String;
        attribute timestamp : TimeValue;
    }

    item def DeviceConfiguration {
        attribute deviceId : DeviceIdentifier;
        attribute deviceType : DeviceType;
        attribute firmwareVersion : String;
        attribute configParameters : String;
    }

    port def WirelessCommunicationPort {
        attribute frequency : Real;
        attribute bandwidth : Real;
        attribute signalStrength : SignalQuality;
        attribute encryptionEnabled : Boolean;
    }

    port def DataStreamPort {
        in item incomingData : VitalSignData[*];
        out item outgoingData : VitalSignData[*];
    }

    port def AlarmPort {
        in item incomingAlarms : AlarmMessage[*];
        out item outgoingAlarms : AlarmMessage[*];
    }

    port def ConfigurationPort {
        in item configCommands : DeviceConfiguration[*];
        out item configStatus : DeviceConfiguration[*];
    }

    port def NetworkInterfacePort {
        attribute ipAddress : String;
        attribute portNumber : Integer;
        attribute protocol : String;
    }

    part def MedicalDevice {
        attribute deviceId : DeviceIdentifier;
        attribute deviceType : DeviceType;
        attribute batteryLevel : Real;
        attribute operationalStatus : ConnectionState;

        port wirelessComm : WirelessCommunicationPort;
        port dataStream : DataStreamPort;
        port alarmOut : AlarmPort;
        port configIn : ConfigurationPort;

        part sensorModule {
            attribute samplingRate : FrequencyValue;
            attribute accuracy : Real;
        }

        part processingUnit {
            attribute processorSpeed : FrequencyValue;
            attribute memoryCapacity : Real;
        }

        part communicationModule {
            attribute transmitPower : Real;
            attribute receivesSensitivity : Real;
            attribute currentState : ConnectionState;
        }

        part powerManagement {
            attribute batteryCapacity : Real;
            attribute currentDraw : ElectricCurrentValue;
            attribute voltage : ElectricPotentialValue;
        }
    }

    part def ConnectivityGateway {
        attribute gatewayId : DeviceIdentifier;
        attribute maxDeviceConnections : Integer;
        attribute activeConnections : Integer;
        attribute throughput : DataRate;

        port wirelessInterface : WirelessCommunicationPort[*];
        port dataAggregation : DataStreamPort[*];
        port alarmAggregation : AlarmPort[*];
        port configDistribution : ConfigurationPort[*];
        port networkInterface : NetworkInterfacePort;

        part radioTransceiver {
            attribute channels : Integer;
            attribute transmitPower : Real;
            attribute operatingFrequency : Real;
        }

        part dataProcessor {
            attribute bufferSize : Real;
            attribute processingCapacity : DataRate;
            attribute queueDepth : Integer;
        }

        part securityModule {
            attribute encryptionAlgorithm : String;
            attribute keyLength : Integer;
            attribute certificateValid : Boolean;
        }

        part routingEngine {
            attribute routingTable : String;
            attribute packetForwardingRate : Real;
        }
    }

    part def HospitalInformationSystem {
        attribute systemId : String;
        attribute databaseCapacity : Real;
        attribute activePatients : Integer;

        port networkAccess : NetworkInterfacePort;
        port dataIngestion : DataStreamPort;
        port alarmManagement : AlarmPort;
        port deviceManagement : ConfigurationPort;

        part dataRepository {
            attribute storageCapacity : Real;
            attribute recordCount : Integer;
            attribute backupEnabled : Boolean;
        }

        part clinicalDecisionSupport {
            attribute ruleEngineActive : Boolean;
            attribute alertThresholds : String;
        }

        part userInterface {
            attribute activeUsers : Integer;
            attribute displayRefreshRate : FrequencyValue;
        }

        part auditLog {
            attribute logRetentionPeriod : TimeValue;
            attribute complianceLevel : String;
        }
    }

    action def AcquireVitalSigns {
        in patientId : PatientIdentifier;
        in samplingInterval : TimeValue;
        out vitalData : VitalSignData;
    }

    action def TransmitData {
        in data : VitalSignData;
        in targetGateway : DeviceIdentifier;
        in priority : MessagePriority;
        out transmissionSuccess : Boolean;
    }

    action def ReceiveAndValidate {
        in receivedData : VitalSignData;
        out validatedData : VitalSignData;
        out validationStatus : Boolean;
    }

    action def AggregateDataStreams {
        in dataStreams : VitalSignData[*];
        out consolidatedData : VitalSignData;
    }

    action def ForwardToHIS {
        in data : VitalSignData;
        in networkAddress : String;
        out deliveryStatus : Boolean;
    }

    action def ProcessAlarm {
        in alarm : AlarmMessage;
        out escalationRequired : Boolean;
        out notificationSent : Boolean;
    }

    action def ManageConnectivity {
        first start;
        then merge monitorLoop;

        then action checkDeviceStatus {
            in deviceState : ConnectionState;
            out healthStatus : Real;
        }

        then decide;
            if checkDeviceStatus.healthStatus >= 0.8 then maintainConnection;
            if checkDeviceStatus.healthStatus < 0.8 and checkDeviceStatus.healthStatus >= 0.5 then degradedOperation;
            if checkDeviceStatus.healthStatus < 0.5 then initiateRecovery;

        action maintainConnection {
            in currentState : ConnectionState;
        }
        then monitorLoop;

        action degradedOperation {
            out reducedDataRate : DataRate;
        }
        then monitorLoop;

        action initiateRecovery {
            out recoveryAction : String;
            out recoverySuccessful : Boolean;
        }
        then decide;
            if initiateRecovery.recoverySuccessful then monitorLoop;
            else raiseAlert;

        action raiseAlert {
            out alertMessage : AlarmMessage;
        }
        then done;
    }

    state def DeviceConnectionLifecycle {
        entry; then idle;

        state idle;
        
        state discovery;
        
        state authentication;
        
        state operational {
            entry; then monitoring;
            
            state monitoring;
            
            state transmitting;
            
            state receiving;

            transition monitoring_to_transmitting
                first monitoring
                then transmitting;

            transition transmitting_to_monitoring
                first transmitting
                then monitoring;

            transition monitoring_to_receiving
                first monitoring
                then receiving;

            transition receiving_to_monitoring
                first receiving
                then monitoring;
        }

        state error;

        transition idle_to_discovery
            first idle
            then discovery;

        transition discovery_to_authentication
            first discovery
            then authentication;
            
        transition discovery_to_error
            first discovery
            then error;

        transition authentication_to_operational
            first authentication
            then operational;
            
        transition authentication_to_error
            first authentication
            then error;

        transition operational_to_error
            first operational
            then error;

        transition error_to_discovery
            first error
            then discovery;
            
        transition error_to_idle
            first error
            then idle;
    }

    part medicalConnectivitySystem {
        part ventilator1 : MedicalDevice {
            attribute :>> deviceId = "VNT-001";
            attribute :>> deviceType = DeviceType::ventilator;
            attribute :>> batteryLevel = 95.0;
            attribute :>> operationalStatus = ConnectionState::connected;
        }

        part monitor1 : MedicalDevice {
            attribute :>> deviceId = "MON-001";
            attribute :>> deviceType = DeviceType::patientMonitor;
            attribute :>> batteryLevel = 88.0;
            attribute :>> operationalStatus = ConnectionState::connected;
        }

        part infusionPump1 : MedicalDevice {
            attribute :>> deviceId = "INF-001";
            attribute :>> deviceType = DeviceType::infusionPump;
            attribute :>> batteryLevel = 72.0;
            attribute :>> operationalStatus = ConnectionState::connected;
        }

        part gateway : ConnectivityGateway {
            attribute :>> gatewayId = "GW-MAIN-01";
            attribute :>> maxDeviceConnections = 20;
            attribute :>> activeConnections = 3;
            attribute :>> throughput = 10000.0;
        }

        part hospitalSystem : HospitalInformationSystem {
            attribute :>> systemId = "HIS-PRIMARY";
            attribute :>> databaseCapacity = 1000000.0;
            attribute :>> activePatients = 150;
        }

        connection wirelessLink1 : WirelessLink
            connect ventilator1.wirelessComm to gateway.wirelessInterface;

        connection wirelessLink2 : WirelessLink
            connect monitor1.wirelessComm to gateway.wirelessInterface;

        connection wirelessLink3 : WirelessLink
            connect infusionPump1.wirelessComm to gateway.wirelessInterface;

        connection networkBackbone : EthernetConnection
            connect gateway.networkInterface to hospitalSystem.networkAccess;

        binding dataFlow1 of ventilator1.dataStream.outgoingData = gateway.dataAggregation.incomingData;
        binding dataFlow2 of monitor1.dataStream.outgoingData = gateway.dataAggregation.incomingData;
        binding dataFlow3 of infusionPump1.dataStream.outgoingData = gateway.dataAggregation.incomingData;

        binding alarmFlow1 of ventilator1.alarmOut.outgoingAlarms = gateway.alarmAggregation.incomingAlarms;
        binding alarmFlow2 of monitor1.alarmOut.outgoingAlarms = gateway.alarmAggregation.incomingAlarms;
        binding alarmFlow3 of infusionPump1.alarmOut.outgoingAlarms = gateway.alarmAggregation.incomingAlarms;
    }

    connection def WirelessLink {
        end source : WirelessCommunicationPort;
        end target : WirelessCommunicationPort;

        attribute protocol : String;
        attribute encryptionType : String;
        attribute linkQuality : SignalQuality;
    }

    connection def EthernetConnection {
        end source : NetworkInterfacePort;
        end target : NetworkInterfacePort;

        attribute speed : DataRate;
        attribute duplex : String;
        attribute vlanId : Integer;
    }

    requirement <'REQ-MDC-001'> primaryFunction {
        doc /* The medical device connectivity system shall enable seamless 
             * integration and real-time data exchange between bedside medical 
             * devices and the hospital information system to support clinical 
             * decision-making and patient care.
             */
        subject system :>> medicalConnectivitySystem;

        require continuousDataFlow;
        require reliableCommunication;
        require secureTransmission;
        require multiDeviceSupport;
    }

    requirement <'REQ-MDC-002'> continuousDataFlow {
        doc /* The system shall maintain continuous data flow from connected 
             * medical devices with a maximum interruption duration of 2 seconds.
             */
        subject gateway :>> medicalConnectivitySystem.gateway;

        assert constraint {
            gateway.throughput >= 5000.0
        }
    }

    requirement <'REQ-MDC-003'> reliableCommunication {
        doc /* The system shall achieve a data transmission reliability of 
             * 99.9% with automatic retry mechanisms for failed transmissions.
             */
        subject gateway :>> medicalConnectivitySystem.gateway;

        assert constraint {
            gateway.dataProcessor.processingCapacity >= 8000.0
        }
    }

    requirement <'REQ-MDC-004'> secureTransmission {
        doc /* All data transmitted between medical devices and the hospital 
             * information system shall be encrypted using AES-256 encryption.
             */
        subject gateway :>> medicalConnectivitySystem.gateway;

        assert constraint {
            gateway.securityModule.keyLength >= 256
        }
    }

    requirement <'REQ-MDC-005'> multiDeviceSupport {
        doc /* The connectivity gateway shall support simultaneous connections 
             * from at least 20 medical devices of various types.
             */
        subject gateway :>> medicalConnectivitySystem.gateway;

        assert constraint {
            gateway.maxDeviceConnections >= 20
        }
    }

    requirement <'REQ-MDC-006'> lowLatency {
        doc /* End-to-end latency from device data acquisition to hospital 
             * information system delivery shall not exceed 500 milliseconds 
             * for critical alarms.
             */
        subject system :>> medicalConnectivitySystem;
    }

    requirement <'REQ-MDC-007'> deviceAuthentication {
        doc /* Each medical device shall authenticate with the connectivity 
             * gateway using mutual certificate-based authentication before 
             * data transmission is permitted.
             */
        subject gateway :>> medicalConnectivitySystem.gateway;

        assert constraint {
            gateway.securityModule.certificateValid == true
        }
    }

    requirement <'REQ-MDC-008'> alarmPropagation {
        doc /* Critical alarms from medical devices shall be propagated to 
             * the hospital information system with highest priority and 
             * guaranteed delivery.
             */
        subject system :>> medicalConnectivitySystem;
    }

    satisfy primaryFunction by medicalConnectivitySystem;
    satisfy continuousDataFlow by medicalConnectivitySystem.gateway;
    satisfy reliableCommunication by medicalConnectivitySystem.gateway;
    satisfy secureTransmission by medicalConnectivitySystem.gateway;
    satisfy multiDeviceSupport by medicalConnectivitySystem.gateway;
}
