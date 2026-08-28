package EngineKnockControlSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def KnockIntensity :> Real;
    attribute def KnockThreshold :> Real;
    attribute def SparkRetard :> PlaneAngleValue;
    attribute def FuelEnrichment :> Real;
    
    enum def KnockSeverityLevel :> Integer {
        none = 0;
        light = 1;
        moderate = 2;
        severe = 3;
    }
    
    item def VibrationSignal {
        attribute amplitude : AccelerationValue;
        attribute frequency : FrequencyValue;
        attribute cylinderID : Integer;
        attribute timestamp : TimeValue;
    }
    
    item def KnockEvent {
        attribute intensity : KnockIntensity;
        attribute severity : KnockSeverityLevel;
        attribute location : Integer;
    }
    
    item def IgnitionCommand {
        attribute sparkAdvance : PlaneAngleValue;
        attribute cylinderID : Integer;
    }
    
    item def FuelCommand {
        attribute enrichmentRatio : FuelEnrichment;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    item def WarningSignal {
        attribute messageText : String;
        attribute severity : KnockSeverityLevel;
    }
    
    port def VibrationSensorPort {
        out vibration : VibrationSignal;
    }
    
    port def KnockAnalysisPort {
        in vibration : VibrationSignal;
        out knockEvent : KnockEvent;
    }
    
    port def IgnitionControlPort {
        in command : IgnitionCommand;
        out sparkTiming : PlaneAngleValue;
    }
    
    port def FuelControlPort {
        in command : FuelCommand;
        out fuelFlow : VolumeFlowRateValue;
    }
    
    port def WarningPort {
        out warning : WarningSignal;
    }
    
    part def Cylinder {
        attribute id : Integer;
        attribute compressionRatio : Real;
        attribute knockSensitivity : Real;
        attribute currentKnockIntensity : KnockIntensity;
        port vibrationOut : VibrationSensorPort;
        port ignitionIn : IgnitionControlPort;
        port fuelIn : FuelControlPort;
    }
    
    part def EngineBlock {
        attribute cylinderCount : Integer = 4;
        attribute blockResonantFrequency : FrequencyValue = 6500 [Hz];
        part cylinder1 : Cylinder { :>> id = 1; }
        part cylinder2 : Cylinder { :>> id = 2; }
        part cylinder3 : Cylinder { :>> id = 3; }
        part cylinder4 : Cylinder { :>> id = 4; }
    }
    
    part def KnockSensor {
        attribute bandpassCenter : FrequencyValue = 6500 [Hz];
        attribute bandpassWidth : FrequencyValue = 3000 [Hz];
        attribute sensitivity : Real = 0.95;
        port vibrationIn : VibrationSensorPort;
        port signalOut : VibrationSensorPort;
    }
    
    part def EngineControlUnit {
        attribute normalKnockThreshold : KnockThreshold = 0.60;
        attribute severeKnockThreshold : KnockThreshold = 0.85;
        attribute maxSparkRetard : SparkRetard = 0.262 [rad];
        attribute maxEnrichment : FuelEnrichment = 1.15;
        attribute responseTime : TimeValue = 0.020 [s];
        port knockAnalysisIn : KnockAnalysisPort;
        port ignitionOut : IgnitionControlPort;
        port fuelOut : FuelControlPort;
        port warningOut : WarningPort;
    }
    
    part def IgnitionActuator {
        attribute baseSparkAdvance : PlaneAngleValue = 0.436 [rad];
        attribute currentSparkTiming : PlaneAngleValue;
        port commandIn : IgnitionControlPort;
    }
    
    part def FuelInjector {
        attribute nominalFlowRate : VolumeFlowRateValue;
        attribute currentFlowRate : VolumeFlowRateValue;
        port commandIn : FuelControlPort;
    }
    
    part def DriverDisplay {
        attribute warningActive : Boolean;
        port warningIn : WarningPort;
    }
    
    action def SenseVibration {
        in cylinderVibration : VibrationSignal;
        out filteredSignal : VibrationSignal;
    }
    
    action def AnalyzeKnock {
        in vibration : VibrationSignal;
        in threshold : KnockThreshold;
        out knockDetected : Boolean;
        out intensity : KnockIntensity;
        out severity : KnockSeverityLevel;
    }
    
    action def CalculateSparkCorrection {
        in knockIntensity : KnockIntensity;
        in severity : KnockSeverityLevel;
        in currentTiming : PlaneAngleValue;
        out retardAmount : SparkRetard;
    }
    
    action def CalculateFuelCorrection {
        in knockIntensity : KnockIntensity;
        in severity : KnockSeverityLevel;
        in currentRatio : FuelEnrichment;
        out enrichmentAmount : FuelEnrichment;
    }
    
    action def ApplyIgnitionCorrection {
        in retard : SparkRetard;
        out command : IgnitionCommand;
    }
    
    action def ApplyFuelCorrection {
        in enrichment : FuelEnrichment;
        out command : FuelCommand;
    }
    
    action def IssueWarning {
        in severity : KnockSeverityLevel;
        out warning : WarningSignal;
    }
    
    action def RestoreNominalSettings {
        out ignitionCommand : IgnitionCommand;
        out fuelCommand : FuelCommand;
    }
    
    action def ControlEngineKnock {
        out ignitionCommand : IgnitionCommand;
        out fuelCommand : FuelCommand;
        out warningSignal : WarningSignal;
        
        first start;
        then merge monitorLoop;
        then action sense : SenseVibration {
            in cylinderVibration : VibrationSignal;
            out filteredSignal : VibrationSignal;
        }
        then action analyze : AnalyzeKnock {
            in vibration = sense.filteredSignal;
            in threshold = 0.60;
            out knockDetected : Boolean;
            out intensity : KnockIntensity;
            out severity : KnockSeverityLevel;
        }
        then decide;
            if analyze.knockDetected == false then restoreNominal;
            if analyze.severity == KnockSeverityLevel::light then applyLightMitigation;
            if analyze.severity == KnockSeverityLevel::moderate then applyModerateMitigation;
            if analyze.severity == KnockSeverityLevel::severe then applySevereMitigation;
        
        action restoreNominal : RestoreNominalSettings {
            out ignitionCommand = ControlEngineKnock::ignitionCommand;
            out fuelCommand = ControlEngineKnock::fuelCommand;
        }
        then monitorLoop;
        
        action applyLightMitigation : ApplyIgnitionCorrection {
            in retard : SparkRetard = 0.087 [rad];
            out command = ControlEngineKnock::ignitionCommand;
        }
        then monitorLoop;
        
        action applyModerateMitigation {
            action calcSpark : CalculateSparkCorrection {
                in knockIntensity = analyze.intensity;
                in severity = analyze.severity;
                in currentTiming = 0.436 [rad];
                out retardAmount : SparkRetard;
            }
            then action applySpark : ApplyIgnitionCorrection {
                in retard = calcSpark.retardAmount;
                out command = ControlEngineKnock::ignitionCommand;
            }
            then action calcFuel : CalculateFuelCorrection {
                in knockIntensity = analyze.intensity;
                in severity = analyze.severity;
                in currentRatio = 1.0;
                out enrichmentAmount : FuelEnrichment;
            }
            then action applyFuel : ApplyFuelCorrection {
                in enrichment = calcFuel.enrichmentAmount;
                out command = ControlEngineKnock::fuelCommand;
            }
        }
        then monitorLoop;
        
        action applySevereMitigation {
            action calcSpark : CalculateSparkCorrection {
                in knockIntensity = analyze.intensity;
                in severity = analyze.severity;
                in currentTiming = 0.436 [rad];
                out retardAmount : SparkRetard;
            }
            then action applySpark : ApplyIgnitionCorrection {
                in retard = calcSpark.retardAmount;
                out command = ControlEngineKnock::ignitionCommand;
            }
            then action calcFuel : CalculateFuelCorrection {
                in knockIntensity = analyze.intensity;
                in severity = analyze.severity;
                in currentRatio = 1.0;
                out enrichmentAmount : FuelEnrichment;
            }
            then action applyFuel : ApplyFuelCorrection {
                in enrichment = calcFuel.enrichmentAmount;
                out command = ControlEngineKnock::fuelCommand;
            }
            then action warn : IssueWarning {
                in severity = analyze.severity;
                out warning = ControlEngineKnock::warningSignal;
            }
        }
        then monitorLoop;
    }
    
    state def KnockControlState {
        entry;
        state normal;
        state detecting;
        state mitigating;
        state protecting;
        
        transition normal_to_detecting
            first normal
            accept KnockEvent
            then detecting;
        
        transition detecting_to_mitigating
            first detecting
            then mitigating;
        
        transition mitigating_to_protecting
            first mitigating
            accept KnockEvent
            then protecting;
        
        transition mitigating_to_normal
            first mitigating
            then normal;
        
        transition protecting_to_normal
            first protecting
            then normal;
    }
    
    constraint def KnockIntensityLimit {
        in measuredIntensity : KnockIntensity;
        in maxIntensity : KnockIntensity;
        measuredIntensity <= maxIntensity
    }
    
    constraint def SparkRetardLimit {
        in appliedRetard : SparkRetard;
        in maxRetard : SparkRetard;
        appliedRetard <= maxRetard
    }
    
    constraint def FuelEnrichmentLimit {
        in appliedEnrichment : FuelEnrichment;
        in maxEnrichment : FuelEnrichment;
        appliedEnrichment <= maxEnrichment
    }
    
    constraint def ResponseTimeLimit {
        in actualResponse : TimeValue;
        in requiredResponse : TimeValue;
        actualResponse <= requiredResponse
    }
    
    requirement def KnockDetectionRequirement {
        doc /* The system shall continuously monitor engine vibration and detect knock events with intensity above threshold within 20 milliseconds. */
        subject ecu : EngineControlUnit;
        require constraint responseLimit : ResponseTimeLimit {
            in actualResponse = ecu.responseTime;
            in requiredResponse = 0.020 [s];
        }
    }
    
    requirement def KnockMitigationRequirement {
        doc /* The system shall automatically retard ignition timing when knock is detected to reduce knock intensity below the normal threshold. */
        subject ecu : EngineControlUnit;
        require constraint sparkLimit : SparkRetardLimit {
            in appliedRetard : SparkRetard;
            in maxRetard = ecu.maxSparkRetard;
        }
    }
    
    requirement def EngineSafetyRequirement {
        doc /* The system shall prevent engine damage by limiting knock intensity to safe levels through combined ignition and fuel adjustments. */
        subject system : EngineKnockControlSystemPart;
        require constraint intensityLimit : KnockIntensityLimit {
            in measuredIntensity : KnockIntensity;
            in maxIntensity = 0.85;
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall maintain optimal engine performance by minimizing ignition retard to only the amount necessary to eliminate knock. */
        subject ecu : EngineControlUnit;
    }
    
    requirement knockDetectionReq : KnockDetectionRequirement;
    requirement knockMitigationReq : KnockMitigationRequirement;
    requirement engineSafetyReq : EngineSafetyRequirement;
    requirement performanceReq : PerformanceRequirement;
    
    requirement <'EKCS-1'> primaryKnockControlRequirement {
        doc /* The engine knock control system shall continuously monitor combustion conditions, detect abnormal detonation, and automatically adjust ignition timing and fuel mixture to prevent engine damage while maintaining optimal performance. */
        require knockDetectionReq;
        require knockMitigationReq;
        require engineSafetyReq;
        require performanceReq;
    }
    
    part def EngineKnockControlSystemPart {
        attribute maxAllowedKnockIntensity : KnockIntensity = 0.85;
        attribute systemResponseTime : TimeValue = 0.020 [s];
        
        part engine : EngineBlock;
        
        part sensor1 : KnockSensor;
        part sensor2 : KnockSensor;
        part sensor3 : KnockSensor;
        part sensor4 : KnockSensor;
        
        part ecu : EngineControlUnit;
        
        part ignition1 : IgnitionActuator;
        part ignition2 : IgnitionActuator;
        part ignition3 : IgnitionActuator;
        part ignition4 : IgnitionActuator;
        
        part fuel1 : FuelInjector;
        part fuel2 : FuelInjector;
        part fuel3 : FuelInjector;
        part fuel4 : FuelInjector;
        
        part display : DriverDisplay;
        
        connect engine.cylinder1.vibrationOut to sensor1.vibrationIn;
        connect engine.cylinder2.vibrationOut to sensor2.vibrationIn;
        connect engine.cylinder3.vibrationOut to sensor3.vibrationIn;
        connect engine.cylinder4.vibrationOut to sensor4.vibrationIn;
        
        connect sensor1.signalOut to ecu.knockAnalysisIn;
        connect sensor2.signalOut to ecu.knockAnalysisIn;
        connect sensor3.signalOut to ecu.knockAnalysisIn;
        connect sensor4.signalOut to ecu.knockAnalysisIn;
        
        connect ecu.ignitionOut to ignition1.commandIn;
        connect ecu.ignitionOut to ignition2.commandIn;
        connect ecu.ignitionOut to ignition3.commandIn;
        connect ecu.ignitionOut to ignition4.commandIn;
        
        connect ecu.fuelOut to fuel1.commandIn;
        connect ecu.fuelOut to fuel2.commandIn;
        connect ecu.fuelOut to fuel3.commandIn;
        connect ecu.fuelOut to fuel4.commandIn;
        
        connect ignition1.commandIn to engine.cylinder1.ignitionIn;
        connect ignition2.commandIn to engine.cylinder2.ignitionIn;
        connect ignition3.commandIn to engine.cylinder3.ignitionIn;
        connect ignition4.commandIn to engine.cylinder4.ignitionIn;
        
        connect fuel1.commandIn to engine.cylinder1.fuelIn;
        connect fuel2.commandIn to engine.cylinder2.fuelIn;
        connect fuel3.commandIn to engine.cylinder3.fuelIn;
        connect fuel4.commandIn to engine.cylinder4.fuelIn;
        
        connect ecu.warningOut to display.warningIn;
        
        action knockControlAction : ControlEngineKnock;
        perform knockControlAction;
        
        assert constraint systemKnockLimit : KnockIntensityLimit {
            in measuredIntensity = max(max(engine.cylinder1.currentKnockIntensity, 
                                           engine.cylinder2.currentKnockIntensity),
                                       max(engine.cylinder3.currentKnockIntensity,
                                           engine.cylinder4.currentKnockIntensity));
            in maxIntensity = maxAllowedKnockIntensity;
        }
        
        assert constraint ecuResponseTime : ResponseTimeLimit {
            in actualResponse = ecu.responseTime;
            in requiredResponse = systemResponseTime;
        }
        
        assert constraint sparkRetardConstraint : SparkRetardLimit {
            in appliedRetard : SparkRetard;
            in maxRetard = ecu.maxSparkRetard;
        }
        
        assert constraint fuelEnrichmentConstraint : FuelEnrichmentLimit {
            in appliedEnrichment : FuelEnrichment;
            in maxEnrichment = ecu.maxEnrichment;
        }
    }
    
    part knockControlSystem : EngineKnockControlSystemPart;
}
