package PatientMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def HeartRateValue :> Real {
        attribute unit : String = "bpm";
    }
    value def PressureValue :> Real {
        attribute unit : String = "mmHg";
    }
    value def SpO2Value :> Real {
        attribute unit : String = "%";
    }
    value def TemperatureValue :> Real {
        attribute unit : String = "degC";
    }
    value def TimestampValue :> Integer {
        attribute unit : String = "ms";
    }
    value def DataRateValue :> Integer {
        attribute unit : String = "Hz";
    }

    // ===== Item Definitions =====
    item def VitalSignSample {
        attribute patientId : String;
        attribute timestamp : TimestampValue;
        attribute sourceDevice : String;
    }
    item def ECGSample :> VitalSignSample {
        attribute heartRate : HeartRateValue;
    }
    item def BloodPressureSample :> VitalSignSample {
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
    }
    item def PulseOximeterSample :> VitalSignSample {
        attribute spo2 : SpO2Value;
    }
    item def AggregatedPatientData {
        attribute patientId : String;
        attribute timestamp : TimestampValue;
        attribute heartRate : HeartRateValue[0..1];
        attribute systolic : PressureValue[0..1];
        attribute diastolic : PressureValue[0..1];
        attribute spo2 : SpO2Value[0..1];
    }
    item def AlarmSignal {
        attribute patientId : String;
        attribute timestamp : TimestampValue;
        attribute alarmType : String;
        attribute severity : String;
        attribute measuredValue : Real;
        attribute threshold : Real;
    }
    item def DisplayPacket {
        attribute patientId : String;
        attribute currentData : AggregatedPatientData;
        attribute historicalData : AggregatedPatientData[*];
        attribute activeAlarms : AlarmSignal[*];
    }
    item def ArchiveRecord {
        attribute patientId : String;
        attribute data : AggregatedPatientData;
        attribute alarms : AlarmSignal[*];
        attribute archiveTimestamp : TimestampValue;
    }
    item def FHIRMessage {
        attribute resourceType : String;
        attribute patientId : String;
        attribute payload : String;
    }
    item def DICOMMessage {
        attribute studyInstanceUID : String;
        attribute patientId : String;
        attribute payload : String;
    }
    item def ExternalHealthRecord {
        attribute patientId : String;
        attribute content : String;
    }

    // ===== Port Definitions =====
    port def VitalSignOutPort {
        out item sample : VitalSignSample;
    }
    port def VitalSignInPort {
        in item sample : VitalSignSample;
    }
    port def AggregatedDataOutPort {
        out item data : AggregatedPatientData;
    }
    port def AggregatedDataInPort {
        in item data : AggregatedPatientData;
    }
    port def ProcessedDataOutPort {
        out item data : AggregatedPatientData;
        out item alarm : AlarmSignal[0..*];
    }
    port def ProcessedDataInPort {
        in item data : AggregatedPatientData;
        in item alarm : AlarmSignal[0..*];
    }
    port def DisplayOutPort {
        out item packet : DisplayPacket;
    }
    port def DisplayInPort {
        in item packet : DisplayPacket;
    }
    port def ArchiveOutPort {
        out item record : ArchiveRecord;
    }
    port def ArchiveInPort {
        in item record : ArchiveRecord;
    }
    port def GatewayOutPort {
        out item fhir : FHIRMessage[0..*];
        out item dicom : DICOMMessage[0..*];
    }
    port def GatewayInPort {
        in item data : AggregatedPatientData;
        in item alarm : AlarmSignal[0..*];
    }
    port def ExternalSystemPort {
        inout item record : ExternalHealthRecord;
    }

    // ===== Threshold Definitions =====
    part def VitalSignThresholds {
        attribute minHeartRate : HeartRateValue = 50;
        attribute maxHeartRate : HeartRateValue = 120;
        attribute minSystolic : PressureValue = 90;
        attribute maxSystolic : PressureValue = 180;
        attribute minDiastolic : PressureValue = 50;
        attribute maxDiastolic : PressureValue = 110;
        attribute minSpO2 : SpO2Value = 92;
        attribute maxSpO2 : SpO2Value = 100;
    }

    // ===== Device Interfaces =====
    part def ECGMonitor {
        port ecgOut : VitalSignOutPort;
        attribute patientId : String;
        attribute samplingRate : DataRateValue = 250;
        attribute isActive : Boolean = true;

        action def generateECGSample {
            out sample : ECGSample;
        }
        exhibit state ecgBehavior {
            entry; then Monitoring;
            state Monitoring;
            transition Monitoring to Monitoring
                when isActive
                do generateECGSample;
        }
    }

    part def BloodPressureMonitor {
        port bpOut : VitalSignOutPort;
        attribute patientId : String;
        attribute samplingRate : DataRateValue = 1;
        attribute isActive : Boolean = true;

        action def generateBPSample {
            out sample : BloodPressureSample;
        }
        exhibit state bpBehavior {
            entry; then Measuring;
            state Measuring;
            transition Measuring to Measuring
                when isActive
                do generateBPSample;
        }
    }

    part def PulseOximeter {
        port spo2Out : VitalSignOutPort;
        attribute patientId : String;
        attribute samplingRate : DataRateValue = 1;
        attribute isActive : Boolean = true;

        action def generateSpO2Sample {
            out sample : PulseOximeterSample;
        }
        exhibit state spo2Behavior {
            entry; then Sensing;
            state Sensing;
            transition Sensing to Sensing
                when isActive
                do generateSpO2Sample;
        }
    }

    // ===== Data Aggregator =====
    part def DataAggregator {
        port ecgIn : VitalSignInPort;
        port bpIn : VitalSignInPort;
        port spo2In : VitalSignInPort;
        port aggregatedOut : AggregatedDataOutPort;

        attribute patientId : String;
        attribute buffer : VitalSignSample[*];

        action def aggregateData {
            in ecgSample : ECGSample;
            in bpSample : BloodPressureSample;
            in spo2Sample : PulseOximeterSample;
            out data : AggregatedPatientData;
        }

        exhibit state aggregatorBehavior {
            entry; then Collecting;
            state Collecting {
                entry do aggregateData;
            }
            transition Collecting to Collecting
                when (ecgIn.sample->notEmpty() and bpIn.sample->notEmpty() and spo2In.sample->notEmpty())
                do aggregateData;
        }
    }

    // ===== Clinical Data Processor =====
    part def ClinicalDataProcessor {
        port dataIn : AggregatedDataInPort;
        port processedOut : ProcessedDataOutPort;

        attribute thresholds : VitalSignThresholds;
        attribute activeAlarms : AlarmSignal[*];

        action def analyzeVitalSigns {
            in data : AggregatedPatientData;
            out processedData : AggregatedPatientData;
            out alarms : AlarmSignal[0..*];

            if data.heartRate < thresholds.minHeartRate or data.heartRate > thresholds.maxHeartRate then {
                // generate heart rate alarm
            }
            if data.systolic < thresholds.minSystolic or data.systolic > thresholds.maxSystolic then {
                // generate blood pressure alarm
            }
            if data.spo2 < thresholds.minSpO2 then {
                // generate SpO2 alarm
            }
        }

        action def checkThresholds {
            in data : AggregatedPatientData;
            out alarms : AlarmSignal[0..*];
        }

        exhibit state processorBehavior {
            entry; then Idle;
            state Idle;
            state Analyzing {
                entry do analyzeVitalSigns;
            }
            state AlarmActive;
            transition Idle to Analyzing
                when dataIn.data->notEmpty();
            transition Analyzing to Idle
                when activeAlarms->isEmpty();
            transition Analyzing to AlarmActive
                when activeAlarms->notEmpty();
            transition AlarmActive to Analyzing
                when dataIn.data->notEmpty();
        }
    }

    // ===== Clinical Display =====
    part def ClinicalDisplay {
        port displayIn : DisplayInPort;

        attribute patientId : String;
        attribute currentDisplay : DisplayPacket;
        attribute historyBuffer : AggregatedPatientData[*];
        attribute alarmList : AlarmSignal[*];

        action def updateDisplay {
            in packet : DisplayPacket;
        }
        action def renderVitalSigns {
            in data : AggregatedPatientData;
        }
        action def renderAlarms {
            in alarms : AlarmSignal[*];
        }

        exhibit state displayBehavior {
            entry; then Blank;
            state Blank;
            state Displaying {
                entry do updateDisplay;
                do renderVitalSigns;
                do renderAlarms;
            }
            state AlarmView {
                entry do renderAlarms;
            }
            transition Blank to Displaying
                when displayIn.packet->notEmpty();
            transition Displaying to Displaying
                when displayIn.packet->notEmpty()
                do updateDisplay;
            transition Displaying to AlarmView
                when displayIn.packet.activeAlarms->notEmpty();
            transition AlarmView to Displaying
                when displayIn.packet.activeAlarms->isEmpty();
        }
    }

    // ===== Data Repository =====
    part def DataRepository {
        port archiveIn : ArchiveInPort;

        attribute archive : ArchiveRecord[*];
        attribute retentionPeriodYears : Integer = 7;
        attribute maxCapacity : Integer = 1000000;

        action def storeRecord {
            in record : ArchiveRecord;
        }
        action def purgeExpiredRecords {
            // remove records older than retentionPeriodYears
        }

        exhibit state repositoryBehavior {
            entry; then Ready;
            state Ready;
            state Storing {
                entry do storeRecord;
            }
            state Purging {
                entry do purgeExpiredRecords;
            }
            transition Ready to Storing
                when archiveIn.record->notEmpty();
            transition Storing to Ready
                when archive->size() < maxCapacity;
            transition Ready to Purging
                when archive->size() >= maxCapacity;
            transition Purging to Ready;
        }
    }

    // ===== Interoperability Gateway =====
    part def InteroperabilityGateway {
        port gatewayIn : GatewayInPort;
        port externalOut : ExternalSystemPort;

        attribute supportedProtocols : String[*] = {"HL7_FHIR", "DICOM"};
        attribute encryptionEnabled : Boolean = true;
        attribute authenticatedSystems : String[*];

        action def translateToFHIR {
            in data : AggregatedPatientData;
            in alarm : AlarmSignal[0..*];
            out message : FHIRMessage;
        }
        action def translateToDICOM {
            in data : AggregatedPatientData;
            out message : DICOMMessage;
        }
        action def transmitExternal {
            in fhir : FHIRMessage[0..*];
            in dicom : DICOMMessage[0..*];
            out record : ExternalHealthRecord;
        }

        exhibit state gatewayBehavior {
            entry; then Standby;
            state Standby;
            state Translating {
                entry do translateToFHIR;
                do translateToDICOM;
            }
            state Transmitting {
                entry do transmitExternal;
            }
            state Error;
            transition Standby to Translating
                when gatewayIn.data->notEmpty();
            transition Translating to Transmitting
                when encryptionEnabled;
            transition Transmitting to Standby;
            transition Translating to Error
                when not encryptionEnabled;
            transition Error to Standby;
        }
    }

    // ===== Distribution Hub =====
    part def DistributionHub {
        port processedIn : ProcessedDataInPort;
        port displayOut : DisplayOutPort;
        port archiveOut : ArchiveOutPort;
        port gatewayOut : GatewayOutPort;

        attribute patientId : String;

        action def distributeData {
            in data : AggregatedPatientData;
            in alarms : AlarmSignal[0..*];
            out displayPacket : DisplayPacket;
            out archiveRecord : ArchiveRecord;
            out gatewayData : AggregatedPatientData;
            out gatewayAlarms : AlarmSignal[0..*];
        }

        exhibit state distributionBehavior {
            entry; then Waiting;
            state Waiting;
            state Distributing {
                entry do distributeData;
            }
            transition Waiting to Distributing
                when processedIn.data->notEmpty();
            transition Distributing to Waiting;
        }
    }

    // ===== Top-Level System =====
    part def PatientMonitoringSystem {
        attribute systemId : String;
        attribute facilityName : String;
        attribute operationalStatus : String = "online";

        part ecgMonitor : ECGMonitor {
            attribute patientId = "PATIENT-001";
        }
        part bpMonitor : BloodPressureMonitor {
            attribute patientId = "PATIENT-001";
        }
        part pulseOx : PulseOximeter {
            attribute patientId = "PATIENT-001";
        }
        part aggregator : DataAggregator {
            attribute patientId = "PATIENT-001";
        }
        part processor : ClinicalDataProcessor {
            part thresholds : VitalSignThresholds;
        }
        part distributionHub : DistributionHub {
            attribute patientId = "PATIENT-001";
        }
        part display : ClinicalDisplay {
            attribute patientId = "PATIENT-001";
        }
        part repository : DataRepository;
        part gateway : InteroperabilityGateway;

        // External system port
        port ehrSystem : ExternalSystemPort;

        // Connections from devices to aggregator
        connection ecgMonitor.ecgOut to aggregator.ecgIn;
        connection bpMonitor.bpOut to aggregator.bpIn;
        connection pulseOx.spo2Out to aggregator.spo2In;

        // Connection from aggregator to processor
        connection aggregator.aggregatedOut to processor.dataIn;

        // Connection from processor to distribution hub
        connection processor.processedOut to distributionHub.processedIn;

        // Connections from distribution hub to destinations
        connection distributionHub.displayOut to display.displayIn;
        connection distributionHub.archiveOut to repository.archiveIn;
        connection distributionHub.gatewayOut to gateway.gatewayIn;

        // Connection from gateway to external EHR
        connection gateway.externalOut to ehrSystem;

        exhibit state systemBehavior {
            entry; then Initializing;
            state Initializing {
                entry;
            }
            state Operational;
            state Degraded;
            state Maintenance;
            transition Initializing to Operational
                when operationalStatus == "online";
            transition Operational to Degraded
                when (ecgMonitor.isActive == false) or (bpMonitor.isActive == false) or (pulseOx.isActive == false);
            transition Degraded to Operational
                when (ecgMonitor.isActive == true) and (bpMonitor.isActive == true) and (pulseOx.isActive == true);
            transition Operational to Maintenance
                when operationalStatus == "maintenance";
            transition Maintenance to Operational
                when operationalStatus == "online";
        }
    }

    // ===== Requirements =====
    requirement def ContinuousDataCollectionRequirement {
        attribute id : String = "REQ-001";
        subject : PatientMonitoringSystem;
        objective {
            doc /* The system shall continuously collect vital signs from connected bedside medical devices including ECG, blood pressure, and pulse oximeter. */
        }
    }

    requirement def DataAggregationRequirement {
        attribute id : String = "REQ-002";
        subject : DataAggregator;
        objective {
            doc /* The data aggregator shall combine multiple vital sign streams, correlating by patient and timestamp to produce a unified patient data view. */
        }
    }

    requirement def ThresholdAnalysisRequirement {
        attribute id : String = "REQ-003";
        subject : ClinicalDataProcessor;
        attribute maxDetectionLatencySeconds : Integer = 5;
        objective {
            doc /* The clinical data processor shall analyze incoming vital signs against predefined safe thresholds and generate alarm signals within 5 seconds when any measurement falls outside the safe range. */
        }
    }

    requirement def RealTimeDisplayRequirement {
        attribute id : String = "REQ-004";
        subject : ClinicalDisplay;
        objective {
            doc /* The clinical display shall provide real-time visualization of current and historical vital signs along with active alarm statuses. */
        }
    }

    requirement def LongTermArchivalRequirement {
        attribute id : String = "REQ-005";
        subject : DataRepository;
        attribute minimumRetentionYears : Integer = 7;
        objective {
            doc /* The data repository shall securely archive complete patient records for a minimum of 7 years for legal and medical auditing purposes. */
        }
    }

    requirement def InteroperabilityRequirement {
        attribute id : String = "REQ-006";
        subject : InteroperabilityGateway;
        attribute supportedProtocols : String[*] = {"HL7_FHIR", "DICOM"};
        objective {
            doc /* The interoperability gateway shall securely share patient data with external healthcare systems using HL7 FHIR and DICOM protocols to ensure seamless communication and data integrity. */
        }
    }

    requirement def SimultaneousDistributionRequirement {
        attribute id : String = "REQ-007";
        subject : DistributionHub;
        objective {
            doc /* The system shall distribute processed patient data and alarm statuses simultaneously to the clinical display, data repository, and interoperability gateway. */
        }
    }

    requirement def DataSecurityRequirement {
        attribute id : String = "REQ-008";
        subject : PatientMonitoringSystem;
        objective {
            doc /* All patient data transmission within and external to the system shall be encrypted to maintain patient confidentiality and data integrity. */
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy ContinuousDataCollectionRequirement by PatientMonitoringSystem::ecgMonitor;
    satisfaction satisfy ContinuousDataCollectionRequirement by PatientMonitoringSystem::bpMonitor;
    satisfaction satisfy ContinuousDataCollectionRequirement by PatientMonitoringSystem::pulseOx;
    satisfaction satisfy DataAggregationRequirement by PatientMonitoringSystem::aggregator;
    satisfaction satisfy ThresholdAnalysisRequirement by PatientMonitoringSystem::processor;
    satisfaction satisfy RealTimeDisplayRequirement by PatientMonitoringSystem::display;
    satisfaction satisfy LongTermArchivalRequirement by PatientMonitoringSystem::repository;
    satisfaction satisfy InteroperabilityRequirement by PatientMonitoringSystem::gateway;
    satisfaction satisfy SimultaneousDistributionRequirement by PatientMonitoringSystem::distributionHub;
    satisfaction satisfy DataSecurityRequirement by PatientMonitoringSystem::gateway;
}
