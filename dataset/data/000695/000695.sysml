package 'Military Anti-Shock Trousers System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VitalSignData;
    attribute def InflationCommand;
    attribute def DeflationCommand;
    attribute def EmergencyStop;
    
    value def BloodPressureValue :> ISQ::PressureValue {
        attribute systolic : ISQ::PressureValue;
        attribute diastolic : ISQ::PressureValue;
        attribute mean : ISQ::PressureValue;
    }
    
    value def HeartRateValue :> ISQ::FrequencyValue;
    
    value def ShockSeverityLevel {
        attribute severityIndex : Real;
        attribute classification : ShockClassification;
    }
    
    enum def ShockClassification {
        none;
        class_I;
        class_II;
        class_III;
        class_IV;
    }
    
    enum def CompartmentStatus {
        deflated;
        inflating;
        pressurized;
        deflating;
        fault;
    }
    
    enum def TreatmentPhase {
        standby;
        assessment;
        deployment;
        maintenance;
        weaning;
        complete;
    }
    
    port def VitalSignsMonitorPort {
        out bloodPressure : BloodPressureValue;
        out heartRate : HeartRateValue;
        out perfusionStatus : Boolean;
    }
    
    port def PneumaticPort {
        inout airPressure : ISQ::PressureValue;
        inout flowRate : ISQ::VolumeFlowRateValue;
    }
    
    port def ControlSignalPort {
        in commandSignal : InflationCommand;
        out statusFeedback : CompartmentStatus;
    }
    
    part def PatientMonitoringUnit {
        port vitalsOut : VitalSignsMonitorPort;
        
        attribute systolicBP : ISQ::PressureValue;
        attribute diastolicBP : ISQ::PressureValue;
        attribute heartRate : HeartRateValue;
        attribute capillaryRefillTime : ISQ::TimeValue;
        
        perform action continuousMonitoring {
            out currentBP : BloodPressureValue;
            out currentHR : HeartRateValue;
            out perfusionAdequate : Boolean;
        }
    }
    
    part def PneumaticControlUnit {
        port airSupply : PneumaticPort;
        port controlInterface : ControlSignalPort;
        
        attribute maxPressure : ISQ::PressureValue;
        attribute inflationRate : ISQ::VolumeFlowRateValue;
        attribute safetyThreshold : ISQ::PressureValue;
        
        perform action regulateAirflow {
            in targetPressure : ISQ::PressureValue;
            out deliveredPressure : ISQ::PressureValue;
        }
        
        perform action emergencyRelease;
    }
    
    part def InflatableCompartment {
        attribute compartmentID : String;
        attribute maxVolume : ISQ::VolumeValue;
        attribute currentPressure : ISQ::PressureValue;
        attribute targetPressure : ISQ::PressureValue;
        attribute status : CompartmentStatus;
        
        port pneumaticInput : PneumaticPort;
        
        perform action inflateToTarget {
            in desiredPressure : ISQ::PressureValue;
            out achievedPressure : ISQ::PressureValue;
        }
        
        perform action maintainPressure {
            in setpoint : ISQ::PressureValue;
        }
        
        perform action controlledDeflate {
            in deflationRate : ISQ::VolumeFlowRateValue;
        }
        
        perform action rapidDeflate;
    }
    
    part def TherapyController {
        attribute shockDetected : Boolean;
        attribute treatmentActive : Boolean;
        attribute currentPhase : TreatmentPhase;
        
        perform action analyzeVitals {
            in vitals : VitalSignData;
            out shockSeverity : ShockSeverityLevel;
            out treatmentRequired : Boolean;
        }
        
        perform action calculateTherapy {
            in severity : ShockSeverityLevel;
            out legPressure : ISQ::PressureValue;
            out abdominalPressure : ISQ::PressureValue;
        }
        
        perform action coordinateDeflation {
            in patientStability : Boolean;
            out deflationSequence : String[*];
        }
    }
    
    part def PressureSensor {
        attribute sensorID : String;
        attribute accuracy : Real;
        
        perform action measurePressure {
            out reading : ISQ::PressureValue;
        }
    }
    
    action def AssessPatientCondition {
        in bloodPressure : BloodPressureValue;
        in heartRate : HeartRateValue;
        out shockLevel : ShockSeverityLevel;
        out requiresIntervention : Boolean;
    }
    
    action def DeployCompression {
        in targetLegPressure : ISQ::PressureValue;
        in targetAbdomenPressure : ISQ::PressureValue;
        out deploymentComplete : Boolean;
    }
    
    action def MaintainHemodynamicSupport {
        in currentVitals : VitalSignData;
        in compartmentPressures : ISQ::PressureValue[*];
        out pressureAdjustments : ISQ::PressureValue[*];
    }
    
    action def ControlledWean {
        in patientStabilized : Boolean;
        in currentPressures : ISQ::PressureValue[*];
        out weaningComplete : Boolean;
    }
    
    part def MAST_System;
    
    part militaryAntiShockTrousers : MAST_System {
        part patientMonitor : PatientMonitoringUnit {
            :>> systolicBP = 80.0 [SI::'Pa'];
            :>> diastolicBP = 50.0 [SI::'Pa'];
            :>> heartRate = 120.0 [SI::'Hz'];
        }
        
        part therapyController : TherapyController {
            :>> currentPhase = TreatmentPhase::standby;
        }
        
        part pneumaticControl : PneumaticControlUnit {
            :>> maxPressure = 120.0 [SI::'Pa'];
            :>> inflationRate = 0.0005 [SI::'m'^3/'s'];
            :>> safetyThreshold = 100.0 [SI::'Pa'];
        }
        
        part leftLegCompartment : InflatableCompartment {
            :>> compartmentID = "LeftLeg";
            :>> maxVolume = 0.002 [SI::'m'^3];
            :>> targetPressure = 40.0 [SI::'Pa'];
        }
        
        part rightLegCompartment : InflatableCompartment {
            :>> compartmentID = "RightLeg";
            :>> maxVolume = 0.002 [SI::'m'^3];
            :>> targetPressure = 40.0 [SI::'Pa'];
        }
        
        part abdominalCompartment : InflatableCompartment {
            :>> compartmentID = "Abdomen";
            :>> maxVolume = 0.003 [SI::'m'^3];
            :>> targetPressure = 20.0 [SI::'Pa'];
        }
        
        part leftLegSensor : PressureSensor {
            :>> sensorID = "LeftLegSensor";
            :>> accuracy = 0.95;
        }
        
        part rightLegSensor : PressureSensor {
            :>> sensorID = "RightLegSensor";
            :>> accuracy = 0.95;
        }
        
        part abdominalSensor : PressureSensor {
            :>> sensorID = "AbdominalSensor";
            :>> accuracy = 0.95;
        }
        
        connection monitorToController connect patientMonitor.vitalsOut to therapyController;
        connection controllerToPneumatic connect therapyController to pneumaticControl.controlInterface;
        
        connection pneumaticToLeftLeg connect pneumaticControl.airSupply to leftLegCompartment.pneumaticInput;
        connection pneumaticToRightLeg connect pneumaticControl.airSupply to rightLegCompartment.pneumaticInput;
        connection pneumaticToAbdomen connect pneumaticControl.airSupply to abdominalCompartment.pneumaticInput;
        
        connection leftLegSensorConnection connect leftLegSensor to leftLegCompartment;
        connection rightLegSensorConnection connect rightLegSensor to rightLegCompartment;
        connection abdominalSensorConnection connect abdominalSensor to abdominalCompartment;
        
        perform action provideShockTreatment : ProvideAntiShockTherapy;
    }
    
    action def ProvideAntiShockTherapy {
        doc /*
            Primary Function: Automatically detect hemorrhagic shock and apply graduated 
            circumferential pneumatic compression to the lower extremities and abdomen to 
            redistribute blood volume from peripheral circulation to central circulation, 
            thereby increasing venous return, cardiac preload, and mean arterial pressure 
            to maintain vital organ perfusion during traumatic hemorrhage until definitive 
            surgical intervention is available.
        */
        
        first start;
        
        then merge continuousAssessment;
        
        then action assessPatient : AssessPatientCondition {
            in bloodPressure : BloodPressureValue;
            in heartRate : HeartRateValue;
            out shockLevel : ShockSeverityLevel;
            out requiresIntervention : Boolean;
        }
        
        then decide;
            if assessPatient.requiresIntervention then initiateTherapy;
            if !assessPatient.requiresIntervention then continuousAssessment;
        
        action initiateTherapy {
            first action deployLegs : DeployCompression {
                in targetLegPressure : ISQ::PressureValue;
                in targetAbdomenPressure : ISQ::PressureValue;
                out deploymentComplete : Boolean;
            }
            
            then action evaluateLegResponse {
                in vitalSigns : VitalSignData;
                out bpImproved : Boolean;
            }
            
            then decide;
                if evaluateLegResponse.bpImproved then proceedToMaintenance;
                if !evaluateLegResponse.bpImproved then deployAbdomen;
            
            action deployAbdomen : DeployCompression {
                in targetLegPressure : ISQ::PressureValue;
                in targetAbdomenPressure : ISQ::PressureValue;
                out deploymentComplete : Boolean;
            }
            
            then proceedToMaintenance;
            
            action proceedToMaintenance;
        }
        
        then action maintainSupport : MaintainHemodynamicSupport {
            in currentVitals : VitalSignData;
            in compartmentPressures : ISQ::PressureValue[*];
            out pressureAdjustments : ISQ::PressureValue[*];
        }
        
        then merge evaluateStability;
        
        then action checkStabilization {
            in vitals : VitalSignData;
            in treatmentDuration : ISQ::TimeValue;
            out isStabilized : Boolean;
            out readyForWean : Boolean;
        }
        
        then decide;
            if checkStabilization.readyForWean then beginWean;
            if !checkStabilization.readyForWean then evaluateStability;
        
        action beginWean : ControlledWean {
            in patientStabilized : Boolean;
            in currentPressures : ISQ::PressureValue[*];
            out weaningComplete : Boolean;
        }
        
        then continuousAssessment;
    }
    
    requirement def <'MAST-REQ-001'> shockDetectionRequirement {
        doc /*
            The system shall continuously monitor patient vital signs and detect 
            hemorrhagic shock conditions (systolic BP < 90 mmHg with tachycardia) 
            within 15 seconds of onset.
        */
        
        subject monitor : PatientMonitoringUnit;
        
        require constraint detectionTime {
            doc /* Detection latency shall not exceed 15 seconds. */
        }
    }
    
    requirement def <'MAST-REQ-002'> compressionGradientRequirement {
        doc /*
            The system shall apply graduated compression with leg compartments 
            pressurized to 30-40 mmHg and abdominal compartment to 15-25 mmHg 
            to optimize blood redistribution without compromising tissue perfusion.
        */
        
        subject compartments : InflatableCompartment[*];
        
        require constraint legPressureRange {
            doc /* Leg compartment pressure: 30-40 mmHg. */
        }
        
        require constraint abdominalPressureRange {
            doc /* Abdominal compartment pressure: 15-25 mmHg. */
        }
    }
    
    requirement def <'MAST-REQ-003'> hemodynamicResponseRequirement {
        doc /*
            The system shall achieve a minimum 10 mmHg increase in mean arterial 
            pressure within 3 minutes of full deployment to restore adequate 
            perfusion to vital organs.
        */
        
        subject therapy : ProvideAntiShockTherapy;
        
        require constraint pressureIncrease {
            doc /* MAP increase >= 10 mmHg within 3 minutes. */
        }
    }
    
    requirement def <'MAST-REQ-004'> safetyAndControlRequirement {
        doc /*
            The system shall incorporate pressure relief valves, continuous pressure 
            monitoring, and emergency rapid deflation capability (< 30 seconds) to 
            prevent compartment syndrome and allow immediate intervention for 
            adverse reactions.
        */
        
        subject safetySystem : PneumaticControlUnit;
        
        require constraint maxPressureLimit {
            doc /* Absolute maximum pressure: 100 mmHg with automatic relief. */
        }
        
        require constraint emergencyDeflation {
            doc /* Complete deflation achievable in < 30 seconds. */
        }
    }
    
    requirement def <'MAST-REQ-005'> sequentialDeploymentRequirement {
        doc /*
            The system shall deploy compression in a sequential manner: lower 
            extremities first, followed by abdominal compartment only if leg 
            compression alone is insufficient, to minimize risk of blood volume 
            shifts causing cardiac overload.
        */
        
        subject deployment : DeployCompression;
        
        require constraint deploymentSequence {
            doc /* Legs inflate before abdomen; abdomen only if BP target not met. */
        }
    }
    
    requirement <'MAST-MISSION'> missionRequirement {
        doc /*
            The Military Anti-Shock Trousers system shall provide automated 
            hemorrhagic shock management in field trauma conditions by detecting 
            hypovolemic shock, applying graduated circumferential compression to 
            redistribute blood volume centrally, maintaining hemodynamic stability, 
            and supporting controlled weaning to prevent rebound hypotension, thereby 
            sustaining life until surgical hemorrhage control is achieved.
        */
        
        assume constraint traumaticHemorrhage {
            doc /* Patient has sustained traumatic injury with ongoing blood loss. */
        }
        
        assume constraint fieldConditions {
            doc /* Treatment occurs in austere environment with limited resources. */
        }
        
        require shockDetectionRequirement;
        require compressionGradientRequirement;
        require hemodynamicResponseRequirement;
        require safetyAndControlRequirement;
        require sequentialDeploymentRequirement;
    }
}
