package MedTechEuropeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::*;

    attribute def PatientIdentifier :> String;
    attribute def DeviceSerialNumber :> String;
    attribute def CertificationNumber :> String;
    attribute def ConcentrationValue :> Real;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def DosageValue :> Real;

    enum def RegulatoryClass {
        classI {
            doc /* Low risk medical devices */
        }
        classIIa {
            doc /* Medium risk medical devices */
        }
        classIIb {
            doc /* Medium-high risk medical devices */
        }
        classIII {
            doc /* High risk medical devices */
        }
    }

    enum def ComplianceStatus {
        inDevelopment;
        underReview;
        ceMarked;
        approved;
        suspended;
    }

    enum def AlarmSeverity {
        info;
        warning;
        critical;
    }

    item def PatientData {
        attribute patientID : PatientIdentifier;
        attribute heartRate : Real;
        attribute bloodPressure : PressureValue;
        attribute oxygenSaturation : Real;
        attribute respiratoryRate : Real;
        attribute timestamp : String;
    }

    item def TherapyParameters {
        attribute drugConcentration : ConcentrationValue;
        attribute flowRate : FlowRateValue;
        attribute totalDosage : DosageValue;
        attribute duration : TimeValue;
    }

    item def AlarmEvent {
        attribute severity : AlarmSeverity;
        attribute code : String;
        attribute alarmMessage : String;
        attribute timestamp : String;
    }

    item def AuditRecord {
        attribute eventType : String;
        attribute userID : String;
        attribute deviceID : DeviceSerialNumber;
        attribute timestamp : String;
        attribute dataHash : String;
    }

    port def SensorDataPort {
        out sensorReading : PatientData;
    }

    port def TherapyControlPort {
        in therapyCommand : TherapyParameters;
        out deliveryStatus : String;
    }

    port def AlarmPort {
        out alarmSignal : AlarmEvent;
    }

    port def NetworkPort {
        in configData : String;
        out telemetryData : PatientData;
        out auditData : AuditRecord;
    }

    port def PowerPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }

    part def VitalSignsMonitor {
        attribute sensorID : DeviceSerialNumber;
        attribute samplingRate : FrequencyValue;
        attribute accuracy : Real;

        port dataOutput : SensorDataPort;
        port power : PowerPort;

        perform action acquireVitals {
            out vitalData : PatientData;
        }
    }

    part def InfusionPump {
        attribute pumpID : DeviceSerialNumber;
        attribute maxFlowRate : FlowRateValue;
        attribute volumeDelivered : VolumeValue;
        attribute occlusion : Boolean;

        port controlInput : TherapyControlPort;
        port power : PowerPort;

        perform action deliverTherapy {
            in params : TherapyParameters;
            out status : String;
        }
    }

    part def ClinicalDecisionEngine {
        attribute algorithmVersion : String;
        attribute certificationLevel : CertificationNumber;
        attribute processingLoad : Real;

        port patientInput : SensorDataPort;
        port therapyOutput : TherapyControlPort;
        port alarmOutput : AlarmPort;

        perform action analyzePatientState {
            in vitals : PatientData;
            out recommendation : TherapyParameters;
            out alert : AlarmEvent;
        }
    }

    part def DataSecurityModule {
        attribute encryptionStandard : String;
        attribute keyLength : Real;
        attribute gdprCompliant : Boolean;

        port dataInput {
            in rawData : PatientData;
        }

        port dataOutput {
            out encryptedData : AuditRecord;
        }

        perform action encryptData {
            in data : PatientData;
            out secureRecord : AuditRecord;
        }
    }

    part def RegulatoryComplianceMonitor {
        attribute mdrCompliant : Boolean;
        attribute iso13485Certified : Boolean;
        attribute lastAuditDate : String;

        port complianceInput {
            in operationalData : String;
        }

        port complianceOutput {
            out complianceReport : String;
        }

        perform action verifyCompliance {
            in deviceOperation : String;
            out verified : Boolean;
        }
    }

    part def NetworkInterface {
        attribute protocol : String;
        attribute bandwidth : FrequencyValue;
        attribute encryption : Boolean;

        port networkPort : NetworkPort;

        perform action transmitData {
            in data : PatientData;
            out transmitted : Boolean;
        }
    }

    part def PowerSupply {
        attribute batteryCapacity : EnergyValue;
        attribute batteryLevel : Real;
        attribute acConnected : Boolean;
        attribute backupTime : TimeValue;

        port powerOut : PowerPort;

        perform action managePower {
            out voltage : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
    }

    action def MonitorPatient {
        in patient : PatientData;
        out vitals : PatientData;
    }

    action def AnalyzeVitals {
        in vitals : PatientData;
        out assessment : String;
        out therapyNeeded : Boolean;
    }

    action def DeliverTherapy {
        in therapy : TherapyParameters;
        out deliveryComplete : Boolean;
    }

    action def RaiseAlarm {
        in condition : String;
        out alarm : AlarmEvent;
    }

    action def LogEvent {
        in event : String;
        out auditRecord : AuditRecord;
    }

    action def VerifyCompliance {
        in operation : String;
        out compliant : Boolean;
    }

    action def SelfTest {
        out passed : Boolean;
    }

    state def SystemOperationalState {
        entry; then powerUp;

        state powerUp;
        then decide;
        if true then standby;

        state standby;
        then activeMonitoring;

        state activeMonitoring;
        then decide;
        if true then deliveringTherapy;

        state deliveringTherapy;
        then verifyingCompliance;

        state verifyingCompliance;
        then decide;
        if true then activeMonitoring;

        state alarmState;
        then decide;
        if true then fault;

        state fault;
        then powerDown;

        state powerDown;
        then done;
    }

    requirement def MedTechEuropeCompliance {
        doc /* Medical device system shall comply with EU Medical Device Regulation (MDR) 2017/745 
             * and ensure patient safety, data protection, and clinical effectiveness. */

        require patientSafetyRequirement;
        require dataProtectionRequirement;
        require clinicalEvidenceRequirement;
        require qualityManagementRequirement;
    }

    requirement <'REQ-MTE-001'> patientSafetyRequirement {
        doc /* The system shall ensure patient safety through continuous monitoring, 
             * risk management, and fail-safe mechanisms. */

        subject device : MedTechEuropeDevice;

        @StatusInfo {
            status = StatusKind::committed;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = medium;
            }
            owner = "Safety Engineering Team";
        }

        assert constraint {
            device.riskManagementActive == true and
            device.failSafeMechanisms == true
        }
    }

    requirement <'REQ-MTE-002'> dataProtectionRequirement {
        doc /* Patient data shall be protected according to GDPR and encrypted 
             * using industry-standard algorithms. */

        subject security : DataSecurityModule;

        @StatusInfo {
            status = StatusKind::committed;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = low;
            }
            owner = "Data Protection Officer";
        }

        assert constraint {
            security.gdprCompliant == true and
            security.keyLength >= 256
        }
    }

    requirement <'REQ-MTE-003'> clinicalEvidenceRequirement {
        doc /* The clinical decision engine shall be validated with sufficient 
             * clinical evidence and certified for medical use. */

        subject engine : ClinicalDecisionEngine;

        assert constraint {
            engine.certificationLevel != null
        }
    }

    requirement <'REQ-MTE-004'> qualityManagementRequirement {
        doc /* The system shall maintain ISO 13485 quality management standards 
             * and continuous post-market surveillance. */

        subject compliance : RegulatoryComplianceMonitor;

        assert constraint {
            compliance.iso13485Certified == true and
            compliance.mdrCompliant == true
        }
    }

    requirement <'REQ-MTE-005'> batteryBackupRequirement {
        doc /* The system shall provide minimum 4 hours of battery backup 
             * for continuous patient monitoring. */

        subject power : PowerSupply;

        assert constraint {
            power.backupTime >= 4 [h]
        }
    }

    part def MedTechEuropeDevice {
        doc /* 
         * MedTech Europe compliant integrated patient monitoring and therapy delivery system.
         * 
         * Primary Function:
         * This system provides continuous patient vital signs monitoring, intelligent clinical 
         * decision support, and automated therapy delivery for critical care environments. 
         * The system integrates multiple sensors to acquire patient data (heart rate, blood pressure, 
         * oxygen saturation, respiratory rate), processes this information through a certified 
         * clinical decision engine, and delivers precise therapeutic interventions via an infusion pump.
         * 
         * All operations comply with EU Medical Device Regulation (MDR) 2017/745, GDPR data protection 
         * requirements, and ISO 13485 quality management standards. The system ensures patient safety 
         * through continuous risk monitoring, encrypted data handling, comprehensive audit logging, 
         * and fail-safe alarm mechanisms. Battery backup ensures uninterrupted operation during 
         * power failures, while network connectivity enables remote monitoring and regulatory reporting.
         */

        attribute deviceID : DeviceSerialNumber;
        attribute regulatoryClass : RegulatoryClass;
        attribute complianceStatus : ComplianceStatus;
        attribute riskManagementActive : Boolean;
        attribute failSafeMechanisms : Boolean;
        attribute totalMass : MassValue;

        part vitalSignsMonitor : VitalSignsMonitor {
            attribute :>> sensorID = "VSM-2025-001";
            attribute :>> samplingRate = 100 [Hz];
            attribute :>> accuracy = 0.99;
        }

        part infusionPump : InfusionPump {
            attribute :>> pumpID = "IP-2025-001";
            attribute :>> maxFlowRate = 1000 [mL/h];
            attribute :>> volumeDelivered = 0 [mL];
            attribute :>> occlusion = false;
        }

        part clinicalEngine : ClinicalDecisionEngine {
            attribute :>> algorithmVersion = "3.2.1";
            attribute :>> certificationLevel = "CE-MDR-2025-042";
            attribute :>> processingLoad = 0.45;
        }

        part dataSecurity : DataSecurityModule {
            attribute :>> encryptionStandard = "AES-256-GCM";
            attribute :>> keyLength = 256;
            attribute :>> gdprCompliant = true;
        }

        part complianceMonitor : RegulatoryComplianceMonitor {
            attribute :>> mdrCompliant = true;
            attribute :>> iso13485Certified = true;
            attribute :>> lastAuditDate = "2025-01-15";
        }

        part networkInterface : NetworkInterface {
            attribute :>> protocol = "HL7 FHIR";
            attribute :>> bandwidth = 100 [MHz];
            attribute :>> encryption = true;
        }

        part powerSupply : PowerSupply {
            attribute :>> batteryCapacity = 200 [W*h];
            attribute :>> batteryLevel = 1.0;
            attribute :>> acConnected = true;
            attribute :>> backupTime = 6 [h];
        }

        perform state machine lifecycle : SystemOperationalState;

        connection monitorToEngine connect 
            vitalSignsMonitor.dataOutput to clinicalEngine.patientInput;

        connection engineToPump connect 
            clinicalEngine.therapyOutput to infusionPump.controlInput;

        connection engineToAlarm connect 
            clinicalEngine.alarmOutput to networkInterface.networkPort;

        connection monitorToSecurity connect 
            vitalSignsMonitor.dataOutput to dataSecurity.dataInput;

        connection securityToNetwork connect 
            dataSecurity.dataOutput to networkInterface.networkPort;

        connection powerToMonitor connect 
            powerSupply.powerOut to vitalSignsMonitor.power;

        connection powerToPump connect 
            powerSupply.powerOut to infusionPump.power;

        assert constraint massLimit {
            totalMass <= 5 [kg]
        }

        assert constraint powerBackup {
            powerSupply.backupTime >= 4 [h]
        }
    }

    part medTechSystem : MedTechEuropeDevice {
        attribute :>> deviceID = "MTE-SYSTEM-2025-001";
        attribute :>> regulatoryClass = RegulatoryClass::classIIb;
        attribute :>> complianceStatus = ComplianceStatus::ceMarked;
        attribute :>> riskManagementActive = true;
        attribute :>> failSafeMechanisms = true;
        attribute :>> totalMass = 4.2 [kg];
    }

    satisfy MedTechEuropeCompliance by medTechSystem;
    satisfy patientSafetyRequirement by medTechSystem;
    satisfy dataProtectionRequirement by medTechSystem.dataSecurity;
    satisfy clinicalEvidenceRequirement by medTechSystem.clinicalEngine;
    satisfy qualityManagementRequirement by medTechSystem.complianceMonitor;
    satisfy batteryBackupRequirement by medTechSystem.powerSupply;
}
