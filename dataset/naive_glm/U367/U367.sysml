package MedicalMonitoringSystem {
    import ScalarValues::*;
    
    // ===== Value Types with Units =====
    
    attribute def ElectricPotentialValue :> Real {
        doc "Electric potential in millivolts (mV)";
    }
    
    attribute def HeartRateValue :> Real {
        doc "Heart rate in beats per minute (bpm)";
    }
    
    attribute def RatioValue :> Real {
        doc "Dimensionless ratio value";
    }
    
    attribute def TimeValue :> Real {
        doc "Time in seconds (s)";
    }
    
    // ===== Enumeration =====
    
    enum RhythmStatus {
        normal;
        elevated;
        critical;
    }
    
    // ===== Item Types =====
    
    item def ECGSample {
        doc "Single sample of ECG data";
        attribute amplitude : ElectricPotentialValue;
        attribute timestamp : TimeValue;
    }
    
    item def ECGSignal {
        doc "Raw ECG signal stream from patient's heart";
        attribute samples : ECGSample[0..*] ordered;
        attribute samplingRate : HeartRateValue;
        attribute duration : TimeValue;
    }
    
    item def AtrialRate {
        doc "Measured atrial chamber rate";
        attribute value : HeartRateValue;
        attribute timestamp : TimeValue;
        attribute confidence : RatioValue;
    }
    
    item def VentricularRate {
        doc "Measured ventricular chamber rate";
        attribute value : HeartRateValue;
        attribute timestamp : TimeValue;
        attribute confidence : RatioValue;
    }
    
    item def RAIReport {
        doc "RAI calculation result with rhythm classification";
        attribute rai : RatioValue;
        attribute atrialRate : HeartRateValue;
        attribute ventricularRate : HeartRateValue;
        attribute status : RhythmStatus;
        attribute timestamp : TimeValue;
    }
    
    item def AlertSignal {
        doc "Critical alert signal for clinician notification";
        attribute severity : RhythmStatus;
        attribute message : String;
        attribute timestamp : TimeValue;
        attribute patientId : String;
    }
    
    // ===== Port Definitions =====
    
    port def ECGOutPort {
        attribute ecgSignal : ECGSignal;
    }
    
    port def ECGInPort {
        attribute ecgSignal : ECGSignal;
    }
    
    port def AtrialRateOutPort {
        attribute atrialRate : AtrialRate;
    }
    
    port def AtrialRateInPort {
        attribute atrialRate : AtrialRate;
    }
    
    port def VentricularRateOutPort {
        attribute ventricularRate : VentricularRate;
    }
    
    port def VentricularRateInPort {
        attribute ventricularRate : VentricularRate;
    }
    
    port def RAIReportOutPort {
        attribute report : RAIReport;
    }
    
    port def RAIReportInPort {
        attribute report : RAIReport;
    }
    
    port def AlertOutPort {
        attribute alert : AlertSignal;
    }
    
    // ===== Action Definitions =====
    
    action def AcquireECG {
        doc "Acquire raw ECG signal from patient";
        in patientId : String;
        out ecgSignal : ECGSignal;
    }
    
    action def DetectAtrialRate {
        doc "Detect and measure atrial rate from ECG signal";
        in ecg : ECGSignal;
        out rate : AtrialRate;
    }
    
    action def DetectVentricularRate {
        doc "Detect and measure ventricular rate from ECG signal";
        in ecg : ECGSignal;
        out rate : VentricularRate;
    }
    
    action def CalculateRAI {
        doc "Calculate RAI from atrial and ventricular rates and classify rhythm status";
        in atrial : AtrialRate;
        in ventricular : VentricularRate;
        in elevatedThreshold : RatioValue;
        in criticalThreshold : RatioValue;
        out report : RAIReport;
    }
    
    action def GenerateAlert {
        doc "Generate alert signal for critical rhythm status";
        in report : RAIReport;
        out alert : AlertSignal;
    }
    
    // ===== Part Definitions =====
    
    part def ECGSensor {
        doc "Component responsible for acquiring the raw electrical signal from the patient's heart";
        port ecgOut : ECGOutPort;
        attribute samplingRate : HeartRateValue = 250;
        attribute isAcquiring : Boolean = false;
        attribute patientConnected : Boolean = false;
        attribute patientId : String;
        
        state machine ECGSensorStates {
            idle;
            acquiring {
                entry { AcquireECG(patientId, ecgOut.ecgSignal); }
            }
            transition idle to acquiring when patientConnected;
            transition acquiring to idle when !patientConnected;
        }
    }
    
    part def AtrialAnalyzer {
        doc "Processes ECG signal to detect and measure the rate of the atria";
        port ecgIn : ECGInPort;
        port atrialRateOut : AtrialRateOutPort;
        attribute currentAtrialRate : HeartRateValue = 0;
        attribute detectionConfidence : RatioValue = 0;
        
        state machine AtrialAnalyzerStates {
            idle;
            analyzing {
                entry { DetectAtrialRate(ecgIn.ecgSignal, atrialRateOut.atrialRate); }
            }
            transition idle to analyzing when ecgIn.ecgSignal != null;
            transition analyzing to idle when ecgIn.ecgSignal == null;
        }
    }
    
    part def VentricularAnalyzer {
        doc "Processes ECG signal to detect and measure the rate of the ventricles";
        port ecgIn : ECGInPort;
        port ventricularRateOut : VentricularRateOutPort;
        attribute currentVentricularRate : HeartRateValue = 0;
        attribute detectionConfidence : RatioValue = 0;
        
        state machine VentricularAnalyzerStates {
            idle;
            analyzing {
                entry { DetectVentricularRate(ecgIn.ecgSignal, ventricularRateOut.ventricularRate); }
            }
            transition idle to analyzing when ecgIn.ecgSignal != null;
            transition analyzing to idle when ecgIn.ecgSignal == null;
        }
    }
    
    part def RAIProcessor {
        doc "Core analytical unit that receives atrial and ventricular rates, calculates RAI, and classifies rhythm status";
        port atrialRateIn : AtrialRateInPort;
        port ventricularRateIn : VentricularRateInPort;
        port raiReportOut : RAIReportOutPort;
        attribute elevatedThreshold : RatioValue = 1.2;
        attribute criticalThreshold : RatioValue = 1.5;
        attribute lastRAI : RatioValue = 0;
        attribute lastStatus : RhythmStatus = RhythmStatus::normal;
        
        state machine RAIProcessorStates {
            idle;
            processing {
                entry { CalculateRAI(atrialRateIn.atrialRate, ventricularRateIn.ventricularRate, elevatedThreshold, criticalThreshold, raiReportOut.report); }
            }
            transition idle to processing when atrialRateIn.atrialRate != null and ventricularRateIn.ventricularRate != null;
            transition processing to idle when raiReportOut.report != null;
        }
    }
    
    part def AlertController {
        doc "Monitors RAI reports and generates alerts when rhythm status is classified as critical";
        port raiReportIn : RAIReportInPort;
        port alertOut : AlertOutPort;
        attribute alertActive : Boolean = false;
        attribute lastAlertTimestamp : TimeValue = 0;
        
        state machine AlertControllerStates {
            idle;
            monitoring;
            alerting {
                entry { alertActive := true; GenerateAlert(raiReportIn.report, alertOut.alert); }
                exit { alertActive := false; }
            }
            transition idle to monitoring;
            transition monitoring to alerting when raiReportIn.report.status == RhythmStatus::critical;
            transition alerting to monitoring when raiReportIn.report.status != RhythmStatus::critical;
        }
    }
    
    // ===== System Definition =====
    
    part def MedicalMonitoringSystem {
        doc "Continuous cardiac monitoring system for arrhythmia detection using Relative Atrial Index (RAI)";
        attribute systemActive : Boolean = true;
        attribute sensorEnabled : Boolean = true;
        attribute monitoringDuration : TimeValue = 0;
        attribute patientId : String;
        
        part ecgSensor : ECGSensor;
        part atrialAnalyzer : AtrialAnalyzer;
        part ventricularAnalyzer : VentricularAnalyzer;
        part raiProcessor : RAIProcessor;
        part alertController : AlertController;
        
        connect ecgSensor.ecgOut to atrialAnalyzer.ecgIn;
        connect ecgSensor.ecgOut to ventricularAnalyzer.ecgIn;
        connect atrialAnalyzer.atrialRateOut to raiProcessor.atrialRateIn;
        connect ventricularAnalyzer.ventricularRateOut to raiProcessor.ventricularRateIn;
        connect raiProcessor.raiReportOut to alertController.raiReportIn;
        
        state machine SystemStates {
            idle;
            operating {
                entry { sensorEnabled := true; }
                exit { sensorEnabled := false; }
            }
            transition idle to operating when systemActive;
            transition operating to idle when !systemActive;
        }
    }
    
    // ===== Requirements =====
    
    requirement def ContinuousMonitoringRequirement {
        doc "System shall provide real-time, uninterrupted cardiac monitoring";
        subject system : MedicalMonitoringSystem;
        assume { system.systemActive == true; }
        require { system.sensorEnabled == true; }
    }
    
    requirement def ECGAcquisitionRequirement {
        doc "System shall acquire ECG signal from patient's heart";
        subject system : MedicalMonitoringSystem;
        assume { system.sensorEnabled == true; }
        require { system.ecgSensor.ecgOut.ecgSignal != null; }
    }
    
    requirement def DualAnalyzerRequirement {
        doc "ECG signal shall be sent to both atrial and ventricular analyzers";
        subject system : MedicalMonitoringSystem;
        require { system.atrialAnalyzer.ecgIn.ecgSignal == system.ecgSensor.ecgOut.ecgSignal; }
        require { system.ventricularAnalyzer.ecgIn.ecgSignal == system.ecgSensor.ecgOut.ecgSignal; }
    }
    
    requirement def ArrhythmiaDetectionRequirement {
        doc "RAI Processor shall calculate RAI as atrial rate divided by ventricular rate";
        subject system : MedicalMonitoringSystem;
        require { system.raiProcessor.lastRAI == system.raiProcessor.atrialRateIn.atrialRate.value / system.raiProcessor.ventricularRateIn.ventricularRate.value; }
    }
    
    requirement def RhythmClassificationRequirement {
        doc "System shall classify rhythm status as normal, elevated, or critical based on RAI thresholds";
        subject system : MedicalMonitoringSystem;
        require { system.raiProcessor.lastRAI < system.raiProcessor.elevatedThreshold implies system.raiProcessor.lastStatus == RhythmStatus::normal; }
        require { system.raiProcessor.lastRAI >= system.raiProcessor.elevatedThreshold and system.raiProcessor.lastRAI < system.raiProcessor.criticalThreshold implies system.raiProcessor.lastStatus == RhythmStatus::elevated; }
        require { system.raiProcessor.lastRAI >= system.raiProcessor.criticalThreshold implies system.raiProcessor.lastStatus == RhythmStatus::critical; }
    }
    
    requirement def CriticalAlertRequirement {
        doc "Alert Controller shall generate alert when rhythm status is critical";
        subject system : MedicalMonitoringSystem;
        assume { system.raiProcessor.lastStatus == RhythmStatus::critical; }
        require { system.alertController.alertActive == true; }
        require { system.alertController.alertOut.alert != null; }
    }
}
