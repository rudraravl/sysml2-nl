package IntelligentSupportSurface {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----

    value type MassValue :> Real {
        unit 'kg';
    }

    value type ForceValue :> Real {
        unit 'N';
    }

    value type PressureValue :> Real {
        unit 'Pa';
    }

    value type LengthValue :> Real {
        unit 'm';
    }

    value type TemperatureValue :> Real {
        unit 'degC';
    }

    value type HumidityValue :> Real {
        unit '%';
    }

    value type DeflectionValue :> Real {
        unit 'mm';
    }

    value type StressValue :> Real {
        unit 'MPa';
    }

    value type AreaValue :> Real {
        unit 'm^2';
    }

    // ---- Item Types ----

    item def AppliedLoad {
        attribute totalMass : MassValue;
        attribute centerOfPressureX : LengthValue;
        attribute centerOfPressureY : LengthValue;
        attribute pressureDistribution : PressureValue[0..*];
    }

    item def StructuralHealthReport {
        attribute deflection : DeflectionValue;
        attribute maxStress : StressValue;
        attribute integrityStatus : IntegrityKind;
    }

    item def EnvironmentalCondition {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }

    enum IntegrityKind { nominal; warning; critical; }

    enum LoadAssessmentResult { safe; unsafe; }

    // ---- Port Definitions ----

    port def LoadBearingPort {
        in appliedLoad : AppliedLoad;
        out loadDetected : Boolean;
    }

    port def StructuralMonitoringPort {
        out healthReport : StructuralHealthReport;
    }

    port def EnvironmentalPort {
        out condition : EnvironmentalCondition;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    // ---- Component Part Definitions ----

    part def StructuralCore {
        attribute length : LengthValue = 3.0;
        attribute width : LengthValue = 2.0;
        attribute thickness : LengthValue = 0.15;
        attribute maxBendingStress : StressValue = 250.0;
        attribute maxAllowableDeflection : DeflectionValue = 5.0;
        port deflectionOut : StructuralMonitoringPort;
    }

    part def LoadBearingLayer {
        attribute thickness : LengthValue = 0.02;
        attribute wearResistanceRating : Real = 8.5;
        attribute maxContactPressure : PressureValue = 5.0e6;
        port loadIn : LoadBearingPort;
    }

    part def EdgeSupport {
        attribute sectionModulus : Real = 1.2e-4;
        attribute yieldStrength : StressValue = 355.0;
    }

    part def AnchorageSystem {
        attribute anchorCount : Integer = 8;
        attribute lateralLoadCapacity : ForceValue = 50000.0;
        attribute boltDiameter : LengthValue = 0.024;
    }

    part def LoadSensorArray {
        attribute sensorCount : Integer = 16;
        attribute samplingRateHz : Real = 100.0;
        port loadOut : LoadBearingPort;
    }

    part def StructuralSensorArray {
        attribute strainGaugeCount : Integer = 12;
        attribute deflectionSensorCount : Integer = 4;
        port healthOut : StructuralMonitoringPort;
    }

    part def EnvironmentalSensorArray {
        port envOut : EnvironmentalPort;
    }

    part def LoadController {
        attribute maxCapacity : MassValue = 1000.0;
        attribute safeWorkingLimit : MassValue = 750.0;
        port controlIn : ControlPort;
        port assessmentOut : LoadAssessmentResult;
    }

    // ---- Main System ----

    part def IntelligentSupportSurfaceSystem {

        // Physical dimensions and capacity
        attribute platformLength : LengthValue = 3.0;
        attribute platformWidth : LengthValue = 2.0;
        attribute maxLoadCapacity : MassValue = 1000.0;
        attribute safeWorkingLoad : MassValue = 750.0;

        // Sub-parts
        part structuralCore : StructuralCore {
            part deflectionOut : StructuralMonitoringPort;
        }

        part loadBearingLayer : LoadBearingLayer {
            part loadIn : LoadBearingPort;
        }

        part edgeSupports : EdgeSupport[4];

        part anchorageSystem : AnchorageSystem;

        part loadSensorArray : LoadSensorArray;

        part structuralSensorArray : StructuralSensorArray;

        part environmentalSensorArray : EnvironmentalSensorArray;

        part loadController : LoadController;

        // External ports
        port loadBearingInterface : LoadBearingPort;
        port structuralMonitoringInterface : StructuralMonitoringPort;
        port environmentalInterface : EnvironmentalPort;
        port controlInterface : ControlPort;

        // Internal connections
        connection loadBearingLayer.loadIn to loadSensorArray.loadOut;
        connection loadSensorArray.loadOut to loadController.controlIn;
        connection structuralCore.deflectionOut to structuralSensorArray.healthOut;
        connection structuralSensorArray.healthOut to loadController.controlIn;
        connection environmentalSensorArray.envOut to loadController.controlIn;

        // External interface bindings
        binding loadBearingInterface = loadBearingLayer.loadIn;
        binding structuralMonitoringInterface = structuralSensorArray.healthOut;
        binding environmentalInterface = environmentalSensorArray.envOut;
        binding controlInterface = loadController.controlIn;

        // ---- State Machine Behavior ----

        state def SupportSurfaceStateMachine {

            state unloaded {
                entry {
                    // Initialize sensors and clear last load data
                    loadSensorArray.samplingRateHz = 100.0;
                }
                do {
                    // Idle monitoring: continuously poll environmental and structural sensors
                    send environmentalSensorArray.envOut.condition to loadController.controlIn;
                }
                transition unloaded to evaluating
                    when loadBearingInterface.loadDetected == true;
            }

            state evaluating {
                entry {
                    // Acquire load measurement from sensor array
                }
                do {
                    // Assess total mass against safe working limit
                    if loadBearingInterface.appliedLoad.totalMass <= safeWorkingLoad {
                        loadController.assessmentOut = LoadAssessmentResult::safe;
                    } else {
                        loadController.assessmentOut = LoadAssessmentResult::unsafe;
                    }
                }
                transition evaluating to loaded
                    when loadController.assessmentOut == LoadAssessmentResult::safe
                    and loadBearingInterface.appliedLoad.totalMass <= maxLoadCapacity;

                transition evaluating to unloaded
                    when loadController.assessmentOut == LoadAssessmentResult::unsafe
                    or loadBearingInterface.appliedLoad.totalMass > maxLoadCapacity {
                        // Reject load: raise alarm and lock out acceptance
                        send "LOAD_REJECTED" to controlInterface.status;
                    }
            }

            state loaded {
                entry {
                    // Confirm load acceptance and begin active monitoring
                    send "LOAD_ACCEPTED" to controlInterface.status;
                }
                do {
                    // Continuously monitor deflection, stress, and integrity
                    if structuralMonitoringInterface.healthReport.deflection > structuralCore.maxAllowableDeflection {
                        send "DEFLECTION_WARNING" to controlInterface.status;
                    }
                    if structuralMonitoringInterface.healthReport.maxStress > structuralCore.maxBendingStress {
                        send "STRESS_CRITICAL" to controlInterface.status;
                    }
                    if structuralMonitoringInterface.healthReport.integrityStatus == IntegrityKind::critical {
                        send "INTEGRITY_CRITICAL" to controlInterface.status;
                    }
                }
                transition loaded to unloaded
                    when loadBearingInterface.loadDetected == false;
            }
        }

        // Instantiate state machine
        part behavior : SupportSurfaceStateMachine;

        // ---- Actions ----

        action def AssessLoad {
            in appliedLoad : AppliedLoad;
            out result : LoadAssessmentResult;
            perform {
                if appliedLoad.totalMass <= 750.0 {
                    result = LoadAssessmentResult::safe;
                } else {
                    result = LoadAssessmentResult::unsafe;
                }
            }
        }

        action def MonitorStructuralHealth {
            in deflection : DeflectionValue;
            in stress : StressValue;
            out report : StructuralHealthReport;
            perform {
                if deflection > 5.0 or stress > 250.0 {
                    report.integrityStatus = IntegrityKind::critical;
                } else if deflection > 3.0 or stress > 200.0 {
                    report.integrityStatus = IntegrityKind::warning;
                } else {
                    report.integrityStatus = IntegrityKind::nominal;
                }
                report.deflection = deflection;
                report.maxStress = stress;
            }
        }
    }

    // ---- Requirements ----

    requirement def PlatformDimensionRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            platform.platformLength == 3.0 [m];
            platform.platformWidth == 2.0 [m];
        }
    }

    requirement def LoadCapacityRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            platform.maxLoadCapacity == 1000.0 [kg];
            platform.safeWorkingLoad == 750.0 [kg];
        }
    }

    requirement def StructuralIntegrityRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            platform.structuralCore.maxAllowableDeflection <= 5.0 [mm];
            platform.structuralCore.maxBendingStress >= 250.0 [MPa];
        }
    }

    requirement def LoadRejectionRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            // Any load exceeding maxLoadCapacity must be rejected
            platform.behavior.evaluating.transition[1].guard == true;
        }
    }

    requirement def ContinuousMonitoringRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            // Structural health must be monitored continuously in loaded state
            platform.behavior.loaded.do != null;
        }
    }

    requirement def EnvironmentalSensingRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            platform.environmentalInterface.condition.temperature != null;
            platform.environmentalInterface.condition.humidity != null;
        }
    }

    requirement def AnchorageStabilityRequirement {
        subject platform : IntelligentSupportSurfaceSystem;
        requirement {
            platform.anchorageSystem.lateralLoadCapacity >= 50000.0 [N];
            platform.anchorageSystem.anchorCount >= 8;
        }
    }

    // ---- Requirement Satisfaction ----

    satisfaction PlatformDimensionRequirement by IntelligentSupportSurfaceSystem;
    satisfaction LoadCapacityRequirement by IntelligentSupportSurfaceSystem;
    satisfaction StructuralIntegrityRequirement by IntelligentSupportSurfaceSystem;
    satisfaction LoadRejectionRequirement by IntelligentSupportSurfaceSystem;
    satisfaction ContinuousMonitoringRequirement by IntelligentSupportSurfaceSystem;
    satisfaction EnvironmentalSensingRequirement by IntelligentSupportSurfaceSystem;
    satisfaction AnchorageStabilityRequirement by IntelligentSupportSurfaceSystem;

}
