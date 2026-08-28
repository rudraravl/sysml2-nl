package MedicalDeviceConnectivitySystem {

    // ===== Units =====
    unit bpm { doc /* beats per minute */ }
    unit mmHg { doc /* millimeters of mercury */ }
    unit pct { doc /* percentage */ }
    unit degC { doc /* degrees Celsius */ }
    unit dBm { doc /* decibel-milliwatts */ }
    unit kbps { doc /* kilobits per second */ }
    unit sec { doc /* seconds */ }

    // ===== Value Types =====
    value type HeartRateValue :> Real { unit bpm; }
    value type BloodPressureValue :> Real { unit mmHg; }
    value type OxygenSatValue :> Real { unit pct; }
    value type RespiratoryRateValue :> Real { unit bpm; }
    value type TemperatureValue :> Real { unit degC; }
    value type BatteryLevelValue :> Real { unit pct; }
    value type SignalStrengthValue :> Real { unit dBm; }
    value type DataRateValue :> Real { unit kbps; }
    value type DurationValue :> Real { unit sec; }
    value type TimestampValue :> Integer;
    value type DeviceIdValue :> String;
    value type PatientIdValue :> String;

    // ===== Item Definitions =====
    item def VitalSignData {
        attribute patientId : PatientIdValue;
        attribute deviceId : DeviceIdValue;
        attribute timestamp : TimestampValue;
        attribute heartRate : HeartRateValue;
        attribute systolicBP : BloodPressureValue;
        attribute diastolicBP : BloodPressureValue;
        attribute oxygenSat : OxygenSatValue;
        attribute respiratoryRate : RespiratoryRateValue;
        attribute temperature : TemperatureValue;
    }

    item def AlarmMessage {
        attribute patientId : PatientIdValue;
        attribute deviceId : DeviceIdValue;
        attribute timestamp : TimestampValue;
        attribute severity : String;
        attribute alarmCode : String;
        attribute message : String;
    }

    item def AggregatedDataPacket {
        attribute gatewayId : DeviceIdValue;
        attribute timestamp : TimestampValue;
        attribute deviceCount : Integer;
        attribute vitalSigns : VitalSignData[0..*];
        attribute alarms : AlarmMessage[0..*];
    }

    item def DiscoveryRequest {
        attribute deviceId : DeviceIdValue;
        attribute deviceType : String;
        attribute capabilities : String;
    }

    item def AuthenticationCredential {
        attribute deviceId : DeviceIdValue;
        attribute certificate : String;
        attribute token : String;
    }

    item def AuthenticationResponse {
        attribute deviceId : DeviceIdValue;
        attribute authenticated : Boolean;
        attribute sessionKey : String;
    }

    item def ConnectionStatus {
        attribute deviceId : DeviceIdValue;
        attribute state : String;
        attribute signalStrength : SignalStrengthValue;
    }

    item def ClinicalAlert {
        attribute patientId : PatientIdValue;
        attribute timestamp : TimestampValue;
        attribute alertType : String;
        attribute recommendation : String;
        attribute priority : Integer;
    }

    item def AuditLogEntry {
        attribute timestamp : TimestampValue;
        attribute actor : String;
        attribute action : String;
        attribute resourceId : String;
        attribute outcome : String;
    }

    // ===== Requirements =====
    requirement def ConnectivityRequirement {
        doc /* Base requirement for medical device connectivity within a hospital environment. */
    }

    requirement WirelessConnectivityRequirement :> ConnectivityRequirement {
        doc /* The gateway shall support at least 20 simultaneously connected medical devices. */
        attribute minDeviceCount : Integer = 20;
    }

    requirement SecureTransmissionRequirement :> ConnectivityRequirement {
        doc /* All patient data shall be encrypted during wireless and wired transmission. */
        attribute encryptionStandard : String = "AES-256";
    }

    requirement RealTimeDeliveryRequirement :> ConnectivityRequirement {
        doc /* Vital signs shall be delivered to HIS within 2 seconds of acquisition. */
        attribute maxLatency : DurationValue = 2 [sec];
    }

    requirement AutomaticRecoveryRequirement :> ConnectivityRequirement {
        doc /* The system shall automatically attempt to recover failed connections. */
        attribute maxRetryAttempts : Integer = 5;
        attribute retryInterval : DurationValue = 30 [sec];
    }

    requirement AuditComplianceRequirement :> ConnectivityRequirement {
        doc /* All data access events shall be logged for regulatory compliance. */
        attribute retentionPeriodDays : Integer = 365;
    }

    requirement DataIntegrityRequirement :> ConnectivityRequirement {
        doc /* Data integrity shall be maintained end-to-end from device to HIS. */
    }

    requirement DegradedModeRequirement :> ConnectivityRequirement {
        doc /* The system shall enter degraded mode when signal weakens and attempt automatic recovery. */
    }

    // ===== Port Definitions =====
    port def DeviceWirelessPort {
        out item vitalData : VitalSignData;
        out item alarm : AlarmMessage;
        in item authResponse : AuthenticationResponse;
        in item connectionAck : ConnectionStatus;
    }

    port def GatewayWirelessPort {
        in item vitalData : VitalSignData;
        in item alarm : AlarmMessage;
        in item discoveryReq : DiscoveryRequest;
        in item authCred : AuthenticationCredential;
        out item authResponse : AuthenticationResponse;
        out item connectionAck : ConnectionStatus;
    }

    port def GatewayWiredPort {
        out item aggregatedData : AggregatedDataPacket;
        in item command : String;
    }

    port def HisWiredPort {
        in item aggregatedData : AggregatedDataPacket;
        out item command : String;
    }

    port def ClinicalDisplayPort {
        out item patientData : VitalSignData;
        out item alert : ClinicalAlert;
        out item alarm : AlarmMessage;
    }

    // ===== State Machine Definitions =====
    state def DeviceConnectionLifecycle {
        attribute authenticated : Boolean = false;
        attribute signalStrength : SignalStrengthValue = -50 [dBm];
        attribute connectionLost : Boolean = false;
        attribute poweredOn : Boolean = false;
        attribute retryEnabled : Boolean = false;
        attribute gatewayFound : Boolean = false;

        initial state Off;
        state Discovering;
        state Authenticating;
        state Operational;
        state Degraded;
        state Recovering;
        state Failed;

        transition from Off to Discovering when poweredOn;
        transition from Discovering to Authenticating when gatewayFound;
        transition from Authenticating to Operational when authenticated;
        transition from Authenticating to Failed after 10 [sec];
        transition from Operational to Degraded when signalStrength < -70 [dBm];
        transition from Degraded to Operational when signalStrength >= -60 [dBm];
        transition from Degraded to Recovering when signalStrength < -80 [dBm];
        transition from Operational to Recovering when connectionLost;
        transition from Recovering to Operational when authenticated;
        transition from Recovering to Failed after 30 [sec];
        transition from Failed to Discovering when retryEnabled;

        entry state Operational action transmitData;
        entry state Degraded action reduceDataRate;
        entry state Recovering action attemptReconnection;
    }

    state def GatewayOperationLifecycle {
        attribute activeConnections : Integer = 0;
        attribute startup : Boolean = false;
        attribute maintenanceRequest : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute deviceDiscovered : Boolean = false;
        attribute authSuccess : Boolean = false;

        initial state Idle;
        state Discovering;
        state Authenticating;
        state Active;
        state Degraded;
        state Maintenance;

        transition from Idle to Discovering when startup;
        transition from Discovering to Authenticating when deviceDiscovered;
        transition from Authenticating to Active when authSuccess;
        transition from Active to Degraded when activeConnections < 5;
        transition from Degraded to Active when activeConnections >= 5;
        transition from Active to Maintenance when maintenanceRequest;
        transition from Maintenance to Idle when maintenanceComplete;

        entry state Active action aggregateAndForward;
        entry state Discovering action broadcastBeacon;
    }

    // ===== Medical Device =====
    part def MedicalDevice {
        attribute deviceId : DeviceIdValue;
        attribute deviceType : String;
        attribute patientId : PatientIdValue;
        attribute batteryLevel : BatteryLevelValue = 100 [pct];
        attribute isPowered : Boolean = false;

        port wireless : DeviceWirelessPort;

        part sensorModule {
            attribute samplingRate : Integer = 250;
            attribute isCalibrated : Boolean = true;

            item currentVitalData : VitalSignData;

            action def AcquireVitalSigns {
                out data : VitalSignData;
            }

            action acquire : AcquireVitalSigns;
        }

        part processingUnit {
            attribute cpuLoad : Integer = 0;
            attribute firmwareVersion : String = "1.0.0";

            action def ProcessData {
                in raw : VitalSignData;
                out processed : VitalSignData;
            }

            action def EvaluateAlarmConditions {
                in data : VitalSignData;
                out alarm : AlarmMessage;
            }

            action process : ProcessData;
            action evaluate : EvaluateAlarmConditions;
        }

        part powerManagement {
            attribute batteryCapacity : Integer = 5000;
            attribute isCharging : Boolean = false;
            attribute lowThreshold : BatteryLevelValue = 20 [pct];

            action def MonitorBattery {
                out level : BatteryLevelValue;
            }

            action def GenerateLowPowerAlarm {
                out alarm : AlarmMessage;
            }

            action monitor : MonitorBattery;
        }

        part wirelessCommModule {
            attribute protocol : String = "WiFi";
            attribute signalStrength : SignalStrengthValue = -50 [dBm];
            attribute encryptionEnabled : Boolean = true;
            attribute dataRate : DataRateValue = 250 [kbps];

            action def Transmit {
                in data : VitalSignData;
                in alarm : AlarmMessage;
            }

            action def ReceiveAck {
                in ack : ConnectionStatus;
            }

            action transmit : Transmit;
        }

        state connectionState : DeviceConnectionLifecycle;

        constraint batteryOk { batteryLevel > 0 [pct]; }
    }

    part def Ventilator :> MedicalDevice {
        attribute deviceType : String = "Ventilator";
        attribute tidalVolume : Real = 500;
        attribute respiratoryRateSetting : Integer = 12;
        attribute peakPressure : BloodPressureValue = 30 [mmHg];
    }

    part def PatientMonitor :> MedicalDevice {
        attribute deviceType : String = "PatientMonitor";
        attribute monitoringMode : String = "Continuous";
    }

    part def InfusionPump :> MedicalDevice {
        attribute deviceType : String = "InfusionPump";
        attribute flowRate : Real = 50;
        attribute volumeInfused : Real = 0;
        attribute drugName : String;
    }

    // ===== Connectivity Gateway =====
    part def ConnectivityGateway {
        attribute gatewayId : DeviceIdValue;
        attribute location : String;
        attribute maxDevices : Integer = 20;
        attribute activeConnections : Integer = 0;
        attribute firmwareVersion : String = "2.1.0";

        port wireless : GatewayWirelessPort;
        port wired : GatewayWiredPort;

        constraint maxDeviceSupport { maxDevices >= 20; }

        part discoveryModule {
            attribute discoveryInterval : DurationValue = 5 [sec];
            attribute discoveredDevices : Integer = 0;

            action def DiscoverDevices {
                in discoveryReq : DiscoveryRequest;
                out response : AuthenticationResponse;
            }

            action def BroadcastBeacon {
                out beacon : String;
            }

            action discover : DiscoverDevices;
        }

        part authenticationModule {
            attribute authMethod : String = "MutualTLS";
            attribute failedAttempts : Integer = 0;
            attribute maxFailedAttempts : Integer = 3;

            action def Authenticate {
                in credential : AuthenticationCredential;
                out response : AuthenticationResponse;
            }

            action authenticate : Authenticate;
        }

        part aggregationModule {
            attribute bufferSize : Integer = 1000;
            attribute currentBufferCount : Integer = 0;

            action def Aggregate {
                in vitalData : VitalSignData;
                in alarm : AlarmMessage;
                out packet : AggregatedDataPacket;
            }

            action aggregate : Aggregate;
        }

        part securityModule {
            attribute encryptionAlgorithm : String = "AES-256";
            attribute keyRotationPeriod : DurationValue = 3600 [sec];
            attribute keyActive : Boolean = true;

            action def Encrypt {
                in plaintext : String;
                out ciphertext : String;
            }

            action def Decrypt {
                in ciphertext : String;
                out plaintext : String;
            }

            action encrypt : Encrypt;
        }

        part forwardingModule {
            attribute forwardingInterval : DurationValue = 1 [sec];
            attribute packetsForwarded : Integer = 0;

            action def Forward {
                in packet : AggregatedDataPacket;
            }

            action forward : Forward;
        }

        state operationalState : GatewayOperationLifecycle;

        constraint latencyConstraint { forwardingModule.forwardingInterval <= 2 [sec]; }
    }

    // ===== Hospital Information System =====
    part def HospitalInformationSystem {
        attribute systemId : String;
        attribute version : String = "HIS-1.0";
        attribute uptime : DurationValue = 0 [sec];

        port wired : HisWiredPort;
        port display : ClinicalDisplayPort;

        part dataRepository {
            attribute storageCapacityGB : Integer = 5000;
            attribute backupEnabled : Boolean = true;
            attribute recordCount : Integer = 0;

            action def Ingest {
                in packet : AggregatedDataPacket;
            }

            action def UpdatePatientRecord {
                in patientId : PatientIdValue;
                in vitalData : VitalSignData;
            }

            action def QueryPatient {
                in patientId : PatientIdValue;
                out data : VitalSignData;
            }

            action ingest : Ingest;
            action updateRecord : UpdatePatientRecord;
        }

        part userInterface {
            attribute displayType : String = "Web";
            attribute refreshRate : DurationValue = 1 [sec];
            attribute activeUsers : Integer = 0;

            action def DisplayPatientData {
                in data : VitalSignData;
            }

            action def DisplayAlarms {
                in alarm : AlarmMessage;
            }

            action def DisplayAlerts {
                in alert : ClinicalAlert;
            }

            action displayData : DisplayPatientData;
            action displayAlarm : DisplayAlarms;
        }

        part clinicalDecisionSupport {
            attribute rulesCount : Integer = 500;
            attribute sensitivity : Real = 0.95;
            attribute alertsGenerated : Integer = 0;

            action def AnalyzeData {
                in data : VitalSignData;
                out alert : ClinicalAlert;
            }

            action def FlagPotentialIssues {
                in vitalData : VitalSignData;
                out alerts : ClinicalAlert;
            }

            action analyze : AnalyzeData;
            action flag : FlagPotentialIssues;
        }

        part auditLog {
            attribute retentionPeriodDays : Integer = 365;
            attribute entryCount : Integer = 0;

            action def LogEvent {
                in entry : AuditLogEntry;
            }

            action def LogDataAccess {
                in userId : String;
                in resourceId : String;
                in actionType : String;
            }

            action log : LogEvent;
        }
    }

    // ===== Top-Level System =====
    part def MedicalDeviceConnectivitySystem {
        attribute systemName : String = "MDCS";
        attribute deploymentSite : String;

        part medicalDevices : MedicalDevice[0..*];
        part gateway : ConnectivityGateway;
        part his : HospitalInformationSystem;

        connection deviceToGateway connect medicalDevices.wireless to gateway.wireless;
        connection gatewayToHIS connect gateway.wired to his.wired;
    }

    // ===== Deployed Instance =====
    part hospitalMDCS : MedicalDeviceConnectivitySystem {
        attribute deploymentSite = "GeneralHospital_ICU_WardA";
        attribute systemName = "MDCS-ICU-01";

        part gateway : ConnectivityGateway {
            attribute gatewayId = "GW-ICU-01";
            attribute location = "ICU Ward A - Server Room";
        }

        part his : HospitalInformationSystem {
            attribute systemId = "HIS-MAIN-01";
        }

        part medicalDevices : MedicalDevice[0..*] {
            part monitor1 : PatientMonitor {
                attribute deviceId = "PM-001";
                attribute patientId = "PAT-1001";
            }

            part monitor2 : PatientMonitor {
                attribute deviceId = "PM-002";
                attribute patientId = "PAT-1002";
            }

            part ventilator1 : Ventilator {
                attribute deviceId = "VENT-001";
                attribute patientId = "PAT-1003";
            }

            part ventilator2 : Ventilator {
                attribute deviceId = "VENT-002";
                attribute patientId = "PAT-1004";
            }

            part pump1 : InfusionPump {
                attribute deviceId = "INF-001";
                attribute patientId = "PAT-1005";
                attribute drugName = "Morphine";
            }

            part pump2 : InfusionPump {
                attribute deviceId = "INF-002";
                attribute patientId = "PAT-1006";
                attribute drugName = "Saline";
            }
        }
    }

    // ===== Requirement Satisfactions =====
    satisfy WirelessConnectivityRequirement by ConnectivityGateway::maxDevices;
    satisfy SecureTransmissionRequirement by ConnectivityGateway::securityModule;
    satisfy RealTimeDeliveryRequirement by ConnectivityGateway::forwardingModule;
    satisfy AutomaticRecoveryRequirement by MedicalDevice::connectionState;
    satisfy AuditComplianceRequirement by HospitalInformationSystem::auditLog;
    satisfy DataIntegrityRequirement by ConnectivityGateway::securityModule;
    satisfy DegradedModeRequirement by DeviceConnectionLifecycle;
}
