package AnneChamneySystem {
    import ScalarValues::*;
    
    // ================================================
    // Units
    // ================================================
    
    unit bpm;
    unit mmHg;
    unit percent;
    unit degC;
    
    // ================================================
    // Value Types
    // ================================================
    
    value type HeartRateValue :> Real {
        :>> unit = bpm;
    }
    
    value type SystolicPressureValue :> Real {
        :>> unit = mmHg;
    }
    
    value type DiastolicPressureValue :> Real {
        :>> unit = mmHg;
    }
    
    value type SpO2Value :> Real {
        :>> unit = percent;
    }
    
    value type TemperatureValue :> Real {
        :>> unit = degC;
    }
    
    value type RiskScoreValue :> Real;
    
    value type PatientId :> String;
    value type StaffId :> String;
    value type Timestamp :> Real;
    
    // ================================================
    // Enumerations
    // ================================================
    
    enum def PatientStatus {
        stable;
        attention;
        critical;
    }
    
    enum def SeverityLevel {
        low;
        medium;
        high;
        critical;
    }
    
    enum def VitalConcern {
        heartRate;
        bloodPressure;
        oxygenSaturation;
        temperature;
    }
    
    enum def InterventionType {
        medicationAdministration;
        lifeSupportAdjustment;
    }
    
    enum def CommandStatus {
        pending;
        validated;
        executing;
        delivered;
        failed;
    }
    
    // ================================================
    // Item Definitions
    // ================================================
    
    item def VitalSigns {
        attribute patientId : PatientId;
        attribute heartRate : HeartRateValue;
        attribute systolic : SystolicPressureValue;
        attribute diastolic : DiastolicPressureValue;
        attribute spo2 : SpO2Value;
        attribute temperature : TemperatureValue;
        attribute timestamp : Timestamp;
    }
    
    item def ClinicalAlert {
        attribute patientId : PatientId;
        attribute concern : VitalConcern;
        attribute severity : SeverityLevel;
        attribute timestamp : Timestamp;
        attribute measuredValue : String;
        attribute riskScore : RiskScoreValue;
    }
    
    item def TreatmentCommand {
        attribute patientId : PatientId;
        attribute intervention : InterventionType;
        attribute dosage : String;
        attribute parameters : String;
        attribute issuedAt : Timestamp;
        attribute issuedBy : StaffId;
    }
    
    item def HistoryQuery {
        attribute patientId : PatientId;
        attribute fromTime : Timestamp;
        attribute toTime : Timestamp;
    }
    
    item def HistoryReport {
        attribute patientId : PatientId;
        attribute vitals : VitalSigns[0..*];
        attribute alerts : ClinicalAlert[0..*];
        attribute generatedAt : Timestamp;
    }
    
    item def DeliveryConfirmation {
        attribute patientId : PatientId;
        attribute command : TreatmentCommand;
        attribute status : CommandStatus;
        attribute confirmedAt : Timestamp;
    }
    
    // ================================================
    // Port Definitions
    // ================================================
    
    port def VitalOutPort {
        out item vitalStream : VitalSigns;
    }
    
    port def VitalInPort {
        in item vitalStream : VitalSigns;
    }
    
    port def AlertOutPort {
        out item alertStream : ClinicalAlert;
    }
    
    port def AlertInPort {
        in item alertStream : ClinicalAlert;
    }
    
    port def CommandOutPort {
        out item commandStream : TreatmentCommand;
    }
    
    port def CommandInPort {
        in item commandStream : TreatmentCommand;
    }
    
    port def ConfirmationOutPort {
        out item confirmation : DeliveryConfirmation;
    }
    
    port def ConfirmationInPort {
        in item confirmation : DeliveryConfirmation;
    }
    
    port def QueryOutPort {
        out item query : HistoryQuery;
        in item report : HistoryReport;
    }
    
    port def QueryInPort {
        in item query : HistoryQuery;
        out item report : HistoryReport;
    }
    
    // ================================================
    // Part Definitions
    // ================================================
    
    part def Patient {
        attribute patientId : PatientId;
        attribute name : String;
    }
    
    // -------- Biomedical Sensor Array --------
    
    part def BiomedicalSensorArray {
        port vitalOut : VitalOutPort;
        port archiveVitalOut : VitalOutPort;
        
        attribute patientId : PatientId;
        attribute sampleInterval : Timestamp = 1;
        
        action measureHeartRate {
            out value : HeartRateValue;
        }
        action measureSystolic {
            out value : SystolicPressureValue;
        }
        action measureDiastolic {
            out value : DiastolicPressureValue;
        }
        action measureSpO2 {
            out value : SpO2Value;
        }
        action measureTemperature {
            out value : TemperatureValue;
        }
        action assembleVitals {
            out vitals : VitalSigns;
        }
        action transmitVitals {
            in vitals : VitalSigns;
        }
        
        exhibit state SensorOperation {
            entry; then measuring;
            
            state measuring {
                do measureHeartRate;
                do measureSystolic;
                do measureDiastolic;
                do measureSpO2;
                do measureTemperature;
                do assembleVitals;
                then transmitting;
            }
            
            state transmitting {
                do transmitVitals;
                then measuring;
            }
        }
    }
    
    // -------- Clinical Analysis Processor --------
    
    part def ClinicalAnalysisProcessor {
        port vitalIn : VitalInPort;
        port alertOut : AlertOutPort;
        port archiveAlertOut : AlertOutPort;
        
        attribute hrMin : HeartRateValue = 50;
        attribute hrMax : HeartRateValue = 120;
        attribute sysMin : SystolicPressureValue = 90;
        attribute sysMax : SystolicPressureValue = 180;
        attribute diaMin : DiastolicPressureValue = 50;
        attribute diaMax : DiastolicPressureValue = 110;
        attribute spo2Min : SpO2Value = 92;
        attribute tempMin : TemperatureValue = 35.0;
        attribute tempMax : TemperatureValue = 38.5;
        
        action evaluateVitals {
            in vitals : VitalSigns;
            out status : PatientStatus;
        }
        action calculateRiskScore {
            in vitals : VitalSigns;
            out score : RiskScoreValue;
        }
        action generateAlert {
            in vitals : VitalSigns;
            in severity : SeverityLevel;
            out alert : ClinicalAlert;
        }
        action archiveAlert {
            in alert : ClinicalAlert;
        }
        
        exhibit state AnalysisOperation {
            entry; then idle;
            
            state idle;
            
            transition from idle to evaluating on vitalIn.vitalStream;
            
            state evaluating {
                do evaluateVitals;
                then riskScoring;
            }
            
            state riskScoring {
                do calculateRiskScore;
                then alerting;
            }
            
            state alerting {
                do generateAlert;
                then archivingAlert;
            }
            
            state archivingAlert {
                do archiveAlert;
                then idle;
            }
        }
    }
    
    // -------- Clinical Response Team --------
    
    part def ClinicalResponseTeam {
        port alertIn : AlertInPort;
        port commandOut : CommandOutPort;
        port queryClient : QueryOutPort;
        port confirmationIn : ConfirmationInPort;
        
        action assessAlert {
            in alert : ClinicalAlert;
        }
        action reviewHistory {
            in patientId : PatientId;
        }
        action formulatePlan {
            in alert : ClinicalAlert;
            out command : TreatmentCommand;
        }
        action issueCommand {
            in command : TreatmentCommand;
        }
        action acknowledgeDelivery {
            in confirmation : DeliveryConfirmation;
        }
        
        exhibit state TeamOperation {
            entry; then standby;
            
            state standby;
            
            transition from standby to assessing on alertIn.alertStream;
            
            state assessing {
                do assessAlert;
                then reviewing;
            }
            
            state reviewing {
                do reviewHistory;
                then planning;
            }
            
            state planning {
                do formulatePlan;
                then issuing;
            }
            
            state issuing {
                do issueCommand;
                then awaiting;
            }
            
            state awaiting;
            
            transition from awaiting to standby on confirmationIn.confirmation;
        }
    }
    
    // -------- Intervention Controller --------
    
    part def InterventionController {
        port commandIn : CommandInPort;
        port confirmationOut : ConfirmationOutPort;
        
        action prepareCommand {
            in command : TreatmentCommand;
        }
        action validateCommand {
            in command : TreatmentCommand;
            out valid : Boolean;
        }
        action executeCommand {
            in command : TreatmentCommand;
        }
        action confirmDelivery {
            out confirmation : DeliveryConfirmation;
        }
        
        exhibit state InterventionState {
            entry; then standby;
            
            state standby;
            
            transition from standby to preparing on commandIn.commandStream;
            
            state preparing {
                do prepareCommand;
                then validating;
            }
            
            state validating {
                do validateCommand;
                then executing;
            }
            
            state executing {
                do executeCommand;
                then confirming;
            }
            
            state confirming {
                do confirmDelivery;
                then standby;
            }
        }
    }
    
    // -------- Data Archive System --------
    
    part def DataArchiveSystem {
        port vitalIn : VitalInPort;
        port alertIn : AlertInPort;
        port queryServer : QueryInPort;
        
        action logVitals {
            in vitals : VitalSigns;
        }
        action logAlert {
            in alert : ClinicalAlert;
        }
        action retrieveHistory {
            in query : HistoryQuery;
            out report : HistoryReport;
        }
        
        exhibit state ArchiveOperation {
            entry; then idle;
            
            state idle;
            
            transition from idle to loggingVitals on vitalIn.vitalStream;
            transition from idle to loggingAlert on alertIn.alertStream;
            transition from idle to servingQuery on queryServer.query;
            
            state loggingVitals {
                do logVitals;
                then idle;
            }
            
            state loggingAlert {
                do logAlert;
                then idle;
            }
            
            state servingQuery {
                do retrieveHistory;
                then idle;
            }
        }
    }
    
    // ================================================
    // Top-Level System
    // ================================================
    
    part def AnneChamneySystem {
        part patient : Patient;
        part sensorArray : BiomedicalSensorArray;
        part analysisProcessor : ClinicalAnalysisProcessor;
        part responseTeam : ClinicalResponseTeam;
        part interventionController : InterventionController;
        part dataArchive : DataArchiveSystem;
        
        connection sensorToProcessor from sensorArray.vitalOut to analysisProcessor.vitalIn;
        connection sensorToArchiveVitals from sensorArray.archiveVitalOut to dataArchive.vitalIn;
        connection processorToTeam from analysisProcessor.alertOut to responseTeam.alertIn;
        connection processorToArchiveAlerts from analysisProcessor.archiveAlertOut to dataArchive.alertIn;
        connection teamToController from responseTeam.commandOut to interventionController.commandIn;
        connection controllerToTeam from interventionController.confirmationOut to responseTeam.confirmationIn;
        connection teamToArchiveQuery from responseTeam.queryClient to dataArchive.queryServer;
    }
    
    part anneChamneySystemInstance : AnneChamneySystem;
    
    // ================================================
    // Requirements
    // ================================================
    
    requirement def ContinuousMonitoringRequirement {
        doc
        /* The BiomedicalSensorArray shall continuously measure heart rate, blood pressure
           (both systolic and diastolic), oxygen saturation, and body temperature, and stream
           the live vital signs data to the ClinicalAnalysisProcessor at regular intervals. */;
    }
    
    requirement def ThresholdDetectionRequirement {
        doc
        /* The ClinicalAnalysisProcessor shall evaluate incoming vital signs against predefined
           safety thresholds, calculate a risk score, and classify the patient status as stable,
           attention, or critical on every received measurement cycle. */;
    }
    
    requirement def AlertGenerationRequirement {
        doc
        /* When a vital sign breaches a safety threshold or exhibits a dangerous trend, the
           ClinicalAnalysisProcessor shall automatically generate a ClinicalAlert containing
           the patient ID, the vital sign of concern, the severity level, and the risk score,
           and transmit it to the ClinicalResponseTeam and the DataArchiveSystem. */;
    }
    
    requirement def ResponseTeamRequirement {
        doc
        /* Upon receiving a ClinicalAlert, the ClinicalResponseTeam shall assess the situation,
           review the patient history from the DataArchiveSystem, formulate an appropriate
           treatment plan, and issue a TreatmentCommand to the InterventionController. The
           team shall remain in an awaiting state until delivery confirmation is received. */;
    }
    
    requirement def InterventionExecutionRequirement {
        doc
        /* The InterventionController shall operate in distinct states, transitioning from
           standby through preparing, validating, executing, and confirming delivery of
           treatment commands. Each command shall be validated before execution, and a
           DeliveryConfirmation shall be sent to the ClinicalResponseTeam upon completion. */;
    }
    
    requirement def DataArchivalRequirement {
        doc
        /* The DataArchiveSystem shall timestamp and log all collected vital signs and all
           generated clinical alerts, creating a complete and timestamped medical record for
           each patient. The archive shall respond to history queries from the
           ClinicalResponseTeam with complete patient records. */;
    }
    
    requirement def ClosedLoopResponseTimeRequirement {
        doc
        /* From the detection of a threshold breach by the ClinicalAnalysisProcessor to the
           delivery confirmation of an intervention command by the InterventionController,
           the system shall complete the closed-loop response within 60 seconds. */;
    }
    
    requirement continuousMonitoring : ContinuousMonitoringRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement thresholdDetection : ThresholdDetectionRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement alertGeneration : AlertGenerationRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement responseTeamAction : ResponseTeamRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement interventionExecution : InterventionExecutionRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement dataArchival : DataArchivalRequirement {
        subject :> anneChamneySystemInstance;
    }
    
    requirement closedLoopResponseTime : ClosedLoopResponseTimeRequirement {
        subject :> anneChamneySystemInstance;
    }
}
