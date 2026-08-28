package MedicalDeviceConnectivitySystem {
    private import ScalarValues::*;
    
    package ValueTypes {
        value def HeartRate :> Real;
        value def BloodPressure :> Real;
        value def OxygenSaturation :> Real;
        value def BatteryLevel :> Real;
        value def SignalStrength :> Real;
    }
    
    package Items {
        private import ValueTypes::*;
        
        item def VitalSigns {
            attribute heartRate : HeartRate;
            attribute systolicBP : BloodPressure;
            attribute diastolicBP : BloodPressure;
            attribute oxygenSat : OxygenSaturation;
        }
        
        item def AlarmMessage {
            attribute severity : String;
            attribute code : String;
            attribute timestamp : String;
        }
        
        item def PatientData {
            attribute deviceId : String;
            attribute vitalSigns : VitalSigns;
            attribute alarms : AlarmMessage[0..*];
        }
        
        item def AggregatedData {
            attribute batchId : String;
            ref patientData : PatientData[1..*];
        }
        
        item def AuthRequest {
            attribute deviceId : String;
            attribute token : String;
        }
        
        item def AuthResponse {
            attribute success : Boolean;
            attribute responseText : String;
        }
        
        item def EncryptedData {
            attribute ciphertext : String;
            attribute batchId : String;
        }
    }
    
    package Interfaces {
        private import Items::*;
        
        port def WirelessDataPort {
            out item data : PatientData;
            out item alarm : AlarmMessage;
            out item authReq : AuthRequest;
            in item authResp : AuthResponse;
        }
        
        port def WiredNetworkPort {
            in item encryptedData : EncryptedData;
            out item ack : String;
        }
    }
    
    package Events {
        occurrence def NetworkFound;
        occurrence def AuthSuccess;
        occurrence def AuthFailure;
        occurrence def SignalWeak;
        occurrence def SignalLost;
        occurrence def SignalRestored;
        occurrence def ConnectionRestored;
        occurrence def ReconnectFailed;
        occurrence def DeviceAuthRequested;
        occurrence def DeviceAuthenticated;
        occurrence def DataReceived;
        occurrence def EncryptedDataReceived;
        occurrence def RecordsUpdated;
    }
    
    package Behaviors {
        private import Events::*;
        
        action def discoverGateway;
        action def sendAuthRequest;
        action def startDataTransmission;
        action def reduceDataRate;
        action def attemptReconnect;
        action def authenticateDevice;
        action def monitorData;
        action def decryptData;
        action def ingestData;
        action def updateRecords;
        
        state def DeviceConnectionLifecycle {
            entry; then off;
            state off;
            state discovering;
            state authenticating;
            state operational;
            state degraded;
            state recovering;
            
            transition off_to_discovering
                first off
                then discovering
                accept NetworkFound;
                
            transition discovering_to_authenticating
                first discovering
                then authenticating
                accept DeviceAuthRequested;
                
            transition auth_to_operational
                first authenticating
                then operational
                accept AuthSuccess;
                
            transition auth_to_discovering
                first authenticating
                then discovering
                accept AuthFailure;
                
            transition operational_to_degraded
                first operational
                then degraded
                accept SignalWeak;
                
            transition degraded_to_recovering
                first degraded
                then recovering
                accept SignalLost;
                
            transition recovering_to_operational
                first recovering
                then operational
                accept ConnectionRestored;
                
            transition recovering_to_discovering
                first recovering
                then discovering
                accept ReconnectFailed;
                
            transition degraded_to_operational
                first degraded
                then operational
                accept SignalRestored;
        }
        
        state def GatewayConnectionManagement {
            entry; then idle;
            state idle;
            state authenticatingDevice;
            state connected;
            state monitoring;
            
            transition idle_to_auth
                first idle
                then authenticatingDevice
                accept DeviceAuthRequested;
                
            transition auth_to_connected
                first authenticatingDevice
                then connected
                accept DeviceAuthenticated;
                
            transition connected_to_monitoring
                first connected
                then monitoring
                accept DataReceived;
                
            transition monitoring_to_monitoring
                first monitoring
                then monitoring
                accept DataReceived;
        }
        
        state def HISIngestion {
            entry; then waiting;
            state waiting;
            state decrypting;
            state ingesting;
            state updatingRecords;
            
            transition waiting_to_decrypting
                first waiting
                then decrypting
                accept EncryptedDataReceived;
                
            transition decrypting_to_ingesting
                first decrypting
                then ingesting;
                
            transition ingesting_to_updating
                first ingesting
                then updatingRecords;
                
            transition updating_to_waiting
                first updatingRecords
                then waiting
                accept RecordsUpdated;
        }
    }
    
    package Components {
        private import ValueTypes::*;
        private import Items::*;
        private import Interfaces::*;
        private import Behaviors::*;
        
        part def SensorModule {
            out item vitalSigns : VitalSigns;
            out item alarm : AlarmMessage;
        }
        
        part def ProcessingUnit {
            in item rawVitalSigns : VitalSigns;
            in item rawAlarm : AlarmMessage;
            out item processedData : PatientData;
        }
        
        part def PowerManagement {
            attribute batteryLevel : BatteryLevel;
            attribute isCharging : Boolean;
        }
        
        part def WirelessCommModule {
            port wirelessPort : WirelessDataPort;
            attribute signalStrength : SignalStrength;
        }
        
        part def MedicalDevice {
            attribute deviceId : String;
            part sensor : SensorModule;
            part processor : ProcessingUnit;
            part power : PowerManagement;
            part comm : WirelessCommModule;
            
            connect sensor.vitalSigns to processor.rawVitalSigns;
            connect sensor.alarm to processor.rawAlarm;
            connect processor.processedData to comm.wirelessPort.data;
            
            perform deviceLifecycle : DeviceConnectionLifecycle;
        }
        
        part def Ventilator :> MedicalDevice;
        part def PatientMonitor :> MedicalDevice;
        part def InfusionPump :> MedicalDevice;
        
        part def SecurityModule {
            in item plainData : AggregatedData;
            out item encryptedData : EncryptedData;
            attribute isEncrypted : Boolean = true;
        }
        
        part def AggregationEngine {
            in item dataStream : PatientData;
            in item alarmStream : AlarmMessage;
            out item aggregatedData : AggregatedData;
        }
        
        part def DeviceManager {
            attribute registeredDevices : Integer;
            attribute maxDevices : Integer = 20;
        }
        
        part def ConnectivityGateway {
            port wirelessHubPort : ~WirelessDataPort[1..20];
            port wiredNetworkPort : WiredNetworkPort;
            
            part deviceManager : DeviceManager;
            part aggregator : AggregationEngine;
            part security : SecurityModule;
            
            connect wirelessHubPort.data to aggregator.dataStream;
            connect wirelessHubPort.alarm to aggregator.alarmStream;
            connect aggregator.aggregatedData to security.plainData;
            connect security.encryptedData to wiredNetworkPort.encryptedData;
            
            perform gatewayManagement : GatewayConnectionManagement;
        }
        
        part def DecryptionModule {
            in item encryptedData : EncryptedData;
            out item plainData : AggregatedData;
        }
        
        part def DataRepository {
            in item ingestedData : AggregatedData;
            attribute recordCount : Integer;
        }
        
        part def ClinicianUI {
            in item patientData : PatientData;
        }
        
        part def ClinicalDecisionSupport {
            in item patientData : PatientData;
            out item alert : AlarmMessage;
        }
        
        part def AuditLog {
            in item loggedData : AggregatedData;
        }
        
        part def HospitalInformationSystem {
            port hisNetworkPort : ~WiredNetworkPort;
            
            part decryptor : DecryptionModule;
            part dataRepository : DataRepository;
            part clinicianUI : ClinicianUI;
            part decisionSupport : ClinicalDecisionSupport;
            part auditLog : AuditLog;
            
            connect hisNetworkPort.encryptedData to decryptor.encryptedData;
            connect decryptor.plainData to dataRepository.ingestedData;
            connect decryptor.plainData to auditLog.loggedData;
            
            perform hisIngestion : HISIngestion;
        }
    }
    
    package System {
        private import Components::*;
        
        part medicalConnectivitySystem {
            part devices : MedicalDevice[1..*];
            part gateway : ConnectivityGateway;
            part his : HospitalInformationSystem;
            
            connect devices.comm.wirelessPort to gateway.wirelessHubPort;
            connect gateway.wiredNetworkPort to his.hisNetworkPort;
        }
    }
    
    package Requirements {
        private import Components::*;
        private import System::*;
        
        requirement def GatewayCapacityRequirement {
            doc /* The Connectivity Gateway shall be capable of managing wireless connections from at least 20 medical devices simultaneously. */
        }
        
        requirement def DataSecurityRequirement {
            doc /* All patient data and alarm messages transmitted between Medical Devices and the HIS shall be encrypted by the Gateway's security module. */
        }
        
        requirement def HighReliabilityRequirement {
            doc /* The system shall automatically manage device connectivity, transitioning to a degraded mode on weak signals and attempting automatic recovery upon connection failure. */
        }
        
        requirement def RealTimeIngestionRequirement {
            doc /* The HIS shall ingest validated and aggregated data into the central repository in real-time to update patient records. */
        }
        
        requirement def ContinuousDataFlowRequirement {
            doc /* The system shall ensure a continuous and reliable flow of critical patient data from bedside devices to clinical staff. */
        }
    }
}
