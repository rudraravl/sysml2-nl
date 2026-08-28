package IntegratedPatientCareSystem {
    import ScalarValues::*;
    import SI::*;
    import Time::*;

    // ============================================================
    // Units
    // ============================================================
    package Units {
        import ScalarValues::*;
        import SI::*;

        unit 'bpm';
        unit 'mmHg';
        unit 'percent' :> 0.01;
        unit 'breathsPerMin';
        unit 'mLperHr';
        unit 'mg';
        unit 'kg' :> SI::kg;
        unit 'h' :> 3600 * SI::s;
        unit 'W' :> SI::W;
        unit 'V' :> SI::V;
        unit 'bitPerS';
        unit 'Ah';
        unit 'bytes';
    }

    // ============================================================
    // Value Types
    // ============================================================
    value type HeartRateValue :> Real {
        doc /* Heart rate measured in beats per minute */;
        unit 'bpm';
        attribute min : HeartRateValue = 0;
        attribute max : HeartRateValue = 250;
    }

    value type SystolicPressureValue :> Real {
        doc /* Systolic blood pressure in millimetres of mercury */;
        unit 'mmHg';
        attribute min : SystolicPressureValue = 0;
        attribute max : SystolicPressureValue = 300;
    }

    value type DiastolicPressureValue :> Real {
        doc /* Diastolic blood pressure in millimetres of mercury */;
        unit 'mmHg';
        attribute min : DiastolicPressureValue = 0;
        attribute max : DiastolicPressureValue = 200;
    }

    value type OxygenSaturationValue :> Real {
        doc /* Peripheral oxygen saturation in percent */;
        unit 'percent';
        attribute min : OxygenSaturationValue = 0;
        attribute max : OxygenSaturationValue = 100;
    }

    value type RespiratoryRateValue :> Real {
        doc /* Respiratory rate in breaths per minute */;
        unit 'breathsPerMin';
        attribute min : RespiratoryRateValue = 0;
        attribute max : RespiratoryRateValue = 80;
    }

    value type FlowRateValue :> Real {
        doc /* Infusion flow rate in millilitres per hour */;
        unit 'mLperHr';
        attribute min : FlowRateValue = 0;
        attribute max : FlowRateValue = 1200;
    }

    value type DosageValue :> Real {
        doc /* Drug dosage in milligrams */;
        unit 'mg';
        attribute min : DosageValue = 0;
        attribute max : DosageValue = 1000;
    }

    value type MassValue :> Real {
        doc /* Total system mass in kilograms */;
        unit 'kg';
        attribute min : MassValue = 0;
        attribute max : MassValue = 5;
    }

    value type DurationHoursValue :> Real {
        doc /* Duration in hours */;
        unit 'h';
        attribute min : DurationHoursValue = 0;
    }

    value type PowerValue :> Real {
        doc /* Power in watts */;
        unit 'W';
        attribute min : PowerValue = 0;
    }

    value type VoltageValue :> Real {
        doc /* Voltage in volts */;
        unit 'V';
        attribute min : VoltageValue = 0;
        attribute max : VoltageValue = 250;
    }

    value type BatteryCapacityValue :> Real {
        doc /* Battery capacity in ampere-hours */;
        unit 'Ah';
        attribute min : BatteryCapacityValue = 0;
    }

    value type DataRateValue :> Real {
        doc /* Data rate in bits per second */;
        unit 'bitPerS';
        attribute min : DataRateValue = 0;
    }

    value type MemorySizeValue :> Real {
        doc /* Memory size in bytes */;
        unit 'bytes';
        attribute min : MemorySizeValue = 0;
    }

    // ============================================================
    // Enumerations
    // ============================================================
    enum def AlarmSeverity {
        info;
        warning;
        critical;
    }

    enum def SystemMode {
        off;
        standby;
        active;
        therapy;
        fault;
    }

    enum def PowerSourceKind {
        mains;
        battery;
    }

    enum def DrugType {
        noradrenaline;
        dopamine;
        insulin;
        heparin;
        saline;
    }

    enum def EncryptionStandard {
        AES256GCM;
        RSA4096;
    }

    // ============================================================
    // Attribute Definitions
    // ============================================================
    attribute def VitalThresholds {
        attribute hrLow : HeartRateValue = 40;
        attribute hrHigh : HeartRateValue = 130;
        attribute systolicLow : SystolicPressureValue = 90;
        attribute systolicHigh : SystolicPressureValue = 180;
        attribute diastolicLow : DiastolicPressureValue = 50;
        attribute diastolicHigh : DiastolicPressureValue = 110;
        attribute spo2Low : OxygenSaturationValue = 92;
        attribute rrLow : RespiratoryRateValue = 8;
        attribute rrHigh : RespiratoryRateValue = 30;
    }

    attribute def SafetyLimits {
        attribute hrCriticalLow : HeartRateValue = 30;
        attribute hrCriticalHigh : HeartRateValue = 160;
        attribute systolicCritical : SystolicPressureValue = 200;
        attribute spo2Critical : OxygenSaturationValue = 85;
        attribute rrCriticalLow : RespiratoryRateValue = 5;
        attribute rrCriticalHigh : RespiratoryRateValue = 40;
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def VitalSigns {
        attribute heartRate : HeartRateValue;
        attribute systolicBP : SystolicPressureValue;
        attribute diastolicBP : DiastolicPressureValue;
        attribute oxygenSaturation : OxygenSaturationValue;
        attribute respiratoryRate : RespiratoryRateValue;
        attribute timestamp : Time;
    }

    item def TherapyOrder {
        attribute drug : DrugType;
        attribute dosage : DosageValue;
        attribute flowRate : FlowRateValue;
        attribute prescribedAt : Time;
        attribute therapyId : String;
    }

    item def AlarmEvent {
        attribute severity : AlarmSeverity;
        attribute message : String;
        attribute raisedAt : Time;
        attribute alarmId : String;
    }

    item def ComplianceReport {
        attribute mdrCompliant : Boolean;
        attribute iso13485Compliant : Boolean;
        attribute checkedAt : Time;
        attribute details : String;
        attribute reportId : String;
    }

    item def PatientData {
        attribute patientId : String;
        attribute vitalSigns : VitalSigns;
        attribute collectedAt : Time;
        attribute encrypted : Boolean;
    }

    item def EncryptedPayload {
        attribute ciphertext : String;
        attribute algorithm : EncryptionStandard = AES256GCM;
        attribute iv : String;
        attribute generatedAt : Time;
    }

    item def PowerStatus {
        attribute source : PowerSourceKind;
        attribute voltage : VoltageValue;
        attribute batteryRemaining : DurationHoursValue;
        attribute mainsAvailable : Boolean;
    }

    // ============================================================
    // Flow Definitions
    // ============================================================
    flow def VitalSignsFlow {
        end source : VitalSignsSource;
        end sink : VitalSignsSink;
        item : VitalSigns;
    }

    flow def TherapyFlow {
        end source : TherapySource;
        end sink : TherapySink;
        item : TherapyOrder;
    }

    flow def AlarmFlow {
        end source : AlarmSource;
        end sink : AlarmSink;
        item : AlarmEvent;
    }

    flow def EncryptedDataFlow {
        end source : DataSource;
        end sink : DataSink;
        item : EncryptedPayload;
    }

    flow def ComplianceFlow {
        end source : ComplianceSource;
        end sink : ComplianceSink;
        item : ComplianceReport;
    }

    flow def PowerFlow {
        end source : PowerSourcePort;
        end sink : PowerSinkPort;
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
    }

    // ============================================================
    // Interface Definitions
    // ============================================================
    interface def VitalSignsInterface {
        end producer : VitalSignsSource;
        end consumer : VitalSignsSink;
        flow of VitalSignsFlow;
    }

    interface def TherapyInterface {
        end producer : TherapySource;
        end consumer : TherapySink;
        flow of TherapyFlow;
    }

    interface def AlarmInterface {
        end producer : AlarmSource;
        end consumer : AlarmSink;
        flow of AlarmFlow;
    }

    interface def NetworkInterface {
        end producer : DataSource;
        end consumer : DataSink;
        flow of EncryptedDataFlow;
    }

    interface def ComplianceInterface {
        end producer : ComplianceSource;
        end consumer : ComplianceSink;
        flow of ComplianceFlow;
    }

    interface def PowerInterface {
        end provider : PowerSourcePort;
        end consumer : PowerSinkPort;
        flow of PowerFlow;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def VitalSignsSource {
        out item : VitalSigns;
    }

    port def VitalSignsSink {
        in item : VitalSigns;
    }

    port def TherapySource {
        out item : TherapyOrder;
    }

    port def TherapySink {
        in item : TherapyOrder;
    }

    port def AlarmSource {
        out item : AlarmEvent;
    }

    port def AlarmSink {
        in item : AlarmEvent;
    }

    port def DataSource {
        out item : EncryptedPayload;
    }

    port def DataSink {
        in item : EncryptedPayload;
    }

    port def ComplianceSource {
        out item : ComplianceReport;
    }

    port def ComplianceSink {
        in item : ComplianceReport;
    }

    port def PowerSourcePort {
        out attribute voltage : VoltageValue;
        out attribute power : PowerValue;
        out attribute status : PowerStatus;
    }

    port def PowerSinkPort {
        in attribute voltage : VoltageValue;
        in attribute power : PowerValue;
        in attribute status : PowerStatus;
    }

    // ============================================================
    // Action Definitions
    // ============================================================
    action def AcquireVitalSigns {
        in samplingInterval : Time;
        out vitals : VitalSigns;
    }

    action def AnalyzeVitalSigns {
        in vitals : VitalSigns;
        in thresholds : VitalThresholds;
        in safetyLimits : SafetyLimits;
        out assessment : AssessmentOutcome;
    }

    action def ComputeTherapy {
        in assessment : AssessmentOutcome;
        in vitals : VitalSigns;
        out order : TherapyOrder;
    }

    action def DeliverTherapy {
        in order : TherapyOrder;
        out delivered : TherapyOrder;
    }

    action def RaiseAlarm {
        in severity : AlarmSeverity;
        in message : String;
        out alarm : AlarmEvent;
    }

    action def EncryptPatientData {
        in data : PatientData;
        out payload : EncryptedPayload;
    }

    action def VerifyCompliance {
        in data : PatientData;
        in order : TherapyOrder;
        out report : ComplianceReport;
    }

    item def AssessmentOutcome {
        attribute isCritical : Boolean;
        attribute isTherapyRequired : Boolean;
        attribute severity : AlarmSeverity;
        attribute details : String;
        attribute generatedAt : Time;
    }

    // ============================================================
    // State Definitions
    // ============================================================
    state def SystemLifecycle {
        entry;
        exit;

        state standby;
        state active {
            state monitoring;
            state evaluating;
            state delivering;
            transition monitoring -> evaluating [vitalsReceived];
            transition evaluating -> delivering [therapyRequired];
            transition evaluating -> monitoring [~therapyRequired];
            transition delivering -> monitoring [deliveryComplete];
        }
        state fault;

        transition initial -> standby [powerOn];
        transition standby -> active [patientAdmitted];
        transition active -> standby [patientDischarged];
        transition standby -> fault [faultDetected];
        transition active -> fault [safetyViolation];
        transition fault -> standby [faultCleared];
        transition standby -> final [powerOff];
    }

    state def PowerManagementState {
        initial -> mainsPowered;
        state mainsPowered;
        state batteryPowered;
        state batteryLow;
        transition mainsPowered -> batteryPowered [mainsLost];
        transition batteryPowered -> mainsPowered [mainsRestored];
        transition batteryPowered -> batteryLow [remaining <= 0.5];
        transition batteryLow -> mainsPowered [mainsRestored];
    }

    // ============================================================
    // Part Definitions
    // ============================================================
    part def VitalSignsMonitor {
        doc /* High-precision bedside vital signs acquisition unit */;
        attribute samplingInterval : Time = 1;
        attribute thresholds : VitalThresholds;
        attribute accuracy : Real = 0.02;

        port vitalOut : VitalSignsSource;
        port powerIn : PowerSinkPort;

        perform action acquire : AcquireVitalSigns {
            in samplingInterval = samplingInterval;
            out vitals : VitalSigns;
        }

        exhibit state acquisitionState {
            initial -> measuring;
            state measuring {
                entry { perform acquire; }
            }
        }
    }

    part def ClinicalDecisionEngine {
        doc /* Certified real-time clinical decision and therapy engine */;
        attribute analysisWindow : Time = 5;
        attribute thresholds : VitalThresholds;
        attribute safetyLimits : SafetyLimits;
        attribute certified : Boolean = true;
        attribute version : String = "MDR-CE-2024";

        port vitalIn : VitalSignsSink;
        port therapyOut : TherapySource;
        port alarmOut : AlarmSource;
        port complianceOut : ComplianceSource;
        port dataIn : DataSink;
        port powerIn : PowerSinkPort;

        perform action analyze : AnalyzeVitalSigns;
        perform action compute : ComputeTherapy;
        perform action raiseAlarm : RaiseAlarm;

        exhibit state decisionState {
            initial -> idle;
            state idle;
            state analyzing;
            state commanding;
            state alerting;

            transition idle -> analyzing [vitalsAvailable];
            transition analyzing -> commanding [assessment.isTherapyRequired];
            transition analyzing -> alerting [assessment.isCritical];
            transition analyzing -> idle [~assessment.isTherapyRequired & ~assessment.isCritical];
            transition commanding -> alerting [assessment.isCritical];
            transition commanding -> idle [orderSent];
            transition alerting -> idle [alarmSent];
        }
    }

    part def InfusionPump {
        doc /* Integrated drug delivery pump with safety interlocks */;
        attribute maxFlowRate : FlowRateValue = 1200;
        attribute maxPressure : SystolicPressureValue = 300;
        attribute calibrated : Boolean = true;

        port therapyIn : TherapySink;
        port powerIn : PowerSinkPort;

        perform action deliver : DeliverTherapy;
    }

    part def AlarmSystem {
        doc /* Multi-tier bedside alarm subsystem */;
        attribute audible : Boolean = true;
        attribute visual : Boolean = true;
        attribute minVolume : Real = 45;

        port alarmIn : AlarmSink;

        exhibit state alarmState {
            initial -> silent;
            state silent;
            state info;
            state warning;
            state critical;
            transition silent -> info [severity == AlarmSeverity::info];
            transition silent -> warning [severity == AlarmSeverity::warning];
            transition silent -> critical [severity == AlarmSeverity::critical];
            transition info -> silent [acknowledged];
            transition warning -> silent [acknowledged];
            transition critical -> silent [acknowledged];
        }
    }

    part def PowerSupply {
        doc /* Dual-source power supply with battery backup */;
        attribute mainsVoltage : VoltageValue = 230;
        attribute batteryCapacity : BatteryCapacityValue = 12;
        attribute backupDuration : DurationHoursValue = 6;
        attribute chargeLevel : BatteryCapacityValue;

        port powerOut : PowerSourcePort;

        exhibit state powerState : PowerManagementState {
            attribute currentSource : PowerSourceKind;
        }
    }

    part def DataSecurityModule {
        doc /* GDPR-compliant encryption module for patient data */;
        attribute algorithm : EncryptionStandard = AES256GCM;
        attribute keyLength : Integer = 256;
        attribute gdrpCompliant : Boolean = true;

        port dataIn : DataSink;
        port dataOut : DataSource;
        port powerIn : PowerSinkPort;

        perform action encrypt : EncryptPatientData;
    }

    part def RegulatoryComplianceMonitor {
        doc /* Continuously verifies MDR and ISO 13485 conformance */;
        attribute mdrVersion : String = "EU 2017/745";
        attribute isoVersion : String = "ISO 13485:2016";
        attribute checkInterval : Time = 60;

        port complianceOut : ComplianceSource;
        port powerIn : PowerSinkPort;

        perform action verify : VerifyCompliance;

        exhibit state complianceState {
            initial -> compliant;
            state compliant;
            state nonCompliant;
            transition compliant -> nonCompliant [violationDetected];
            transition nonCompliant -> compliant [remediationApplied];
        }
    }

    part def UserInterface {
        doc /* Touchscreen display for clinicians */;
        attribute displaySize : Real = 10.1;
        port alarmIn : AlarmSink;
        port dataIn : DataSink;
        port powerIn : PowerSinkPort;
    }

    part def Chassis {
        doc /* Self-contained bedside enclosure */;
        attribute totalMass : MassValue = 4.6;
        attribute ingressProtection : String = "IP54";
    }

    // ============================================================
    // Top-level System
    // ============================================================
    part def IntegratedPatientCareSystem {
        doc /* Bedside integrated patient monitoring and therapy delivery unit */;

        attribute deviceIdentifier : String = "IPCS-CC-001";
        attribute totalMass : MassValue = 4.6;
        attribute operationalMode : SystemMode = standby;

        // Sub-parts
        part vitalsMonitor : VitalSignsMonitor;
        part decisionEngine : ClinicalDecisionEngine;
        part infusionPump : InfusionPump;
        part alarmSystem : AlarmSystem;
        part powerSupply : PowerSupply;
        part securityModule : DataSecurityModule;
        part complianceMonitor : RegulatoryComplianceMonitor;
        part userInterface : UserInterface;
        part chassis : Chassis;

        // Ports of the overall system
        port hospitalNetworkOut : DataSource;
        port operatorAlarmOut : AlarmSource;
        port powerIn : PowerSinkPort;

        // Internal connections
        connection vitalsToEngine : VitalSignsInterface {
            end producer = vitalsMonitor.vitalOut;
            end consumer = decisionEngine.vitalIn;
        }

        connection engineToPump : TherapyInterface {
            end producer = decisionEngine.therapyOut;
            end consumer = infusionPump.therapyIn;
        }

        connection engineToAlarm : AlarmInterface {
            end producer = decisionEngine.alarmOut;
            end consumer = alarmSystem.alarmIn;
        }

        connection alarmToUI : AlarmInterface {
            end producer = decisionEngine.alarmOut;
            end consumer = userInterface.alarmIn;
        }

        connection engineToCompliance : ComplianceInterface {
            end producer = decisionEngine.complianceOut;
            end consumer = complianceMonitor.complianceOut;
        }

        connection securityToNetwork : NetworkInterface {
            end producer = securityModule.dataOut;
            end consumer = hospitalNetworkOut;
        }

        connection decisionToSecurity : NetworkInterface {
            end producer = decisionEngine.dataIn;
            end consumer = securityModule.dataIn;
        }

        // Power distribution
        connection powerToMonitor : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = vitalsMonitor.powerIn;
        }

        connection powerToEngine : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = decisionEngine.powerIn;
        }

        connection powerToPump : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = infusionPump.powerIn;
        }

        connection powerToSecurity : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = securityModule.powerIn;
        }

        connection powerToCompliance : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = complianceMonitor.powerIn;
        }

        connection powerToUI : PowerInterface {
            end provider = powerSupply.powerOut;
            end consumer = userInterface.powerIn;
        }

        // System lifecycle behaviour
        exhibit state lifecycle : SystemLifecycle;

        // Compliance verification action
        perform action verifyOperations : VerifyCompliance {
            in data : PatientData;
            in order : TherapyOrder;
            out report : ComplianceReport;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def MassRequirement {
        doc /* The complete device shall weigh less than 5 kilograms. */;
        attribute maxMass : MassValue = 5;
        constraint { maxMass <= 5 }
    }

    requirement def BatteryBackupRequirement {
        doc /* Battery backup shall sustain full operation for at least 6 hours during mains power loss. */;
        attribute minDuration : DurationHoursValue = 6;
        constraint { minDuration >= 6 }
    }

    requirement def VitalMonitoringRequirement {
        doc /* The system shall continuously monitor heart rate, systolic and diastolic blood pressure, oxygen saturation, and respiratory rate. */;
    }

    requirement def TherapyDeliveryRequirement {
        doc /* The system shall automatically compute and command precise drug dosage and flow rate via the integrated infusion pump. */;
    }

    requirement def AlarmRequirement {
        doc /* The system shall raise info, warning and critical alarms when patient vitals exit safe ranges. */;
    }

    requirement def DataSecurityRequirement {
        doc /* All patient data shall be encrypted to GDPR standards before transmission over the hospital network. */;
    }

    requirement def RegulatoryComplianceRequirement {
        doc /* Operations shall continuously conform to EU MDR and ISO 13485 quality standards. */;
    }

    requirement def LifecycleRequirement {
        doc /* The system shall proceed through power-up, standby, active monitoring, therapy delivery and fault states as defined by its lifecycle. */;
    }

    requirement def SelfContainedUnitRequirement {
        doc /* The entire system shall be a single, self-contained bedside unit. */;
    }

    requirement reqMass : MassRequirement;
    requirement reqBattery : BatteryBackupRequirement;
    requirement reqVitals : VitalMonitoringRequirement;
    requirement reqTherapy : TherapyDeliveryRequirement;
    requirement reqAlarm : AlarmRequirement;
    requirement reqSecurity : DataSecurityRequirement;
    requirement reqRegulatory : RegulatoryComplianceRequirement;
    requirement reqLifecycle : LifecycleRequirement;
    requirement reqSelfContained : SelfContainedUnitRequirement;

    // ============================================================
    // Satisfactions
    // ============================================================
    part ipcsInstance : IntegratedPatientCareSystem {
        satisfy reqMass by chassis.totalMass;
        satisfy reqBattery by powerSupply.backupDuration;
        satisfy reqVitals by vitalsMonitor;
        satisfy reqTherapy by decisionEngine;
        satisfy reqAlarm by alarmSystem;
        satisfy reqSecurity by securityModule;
        satisfy reqRegulatory by complianceMonitor;
        satisfy reqLifecycle by lifecycle;
        satisfy reqSelfContained by chassis;
    }
}
