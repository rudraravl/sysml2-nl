package IntelligentCorsetSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    attribute def TorsoCircumference :> Real {
        doc "Torso circumference measurement in millimeters.";
        unit mm;
    }

    attribute def PostureAngle :> Real {
        doc "Spinal alignment angle relative to vertical in degrees.";
        unit deg;
    }

    attribute def CompressionForce :> Real {
        doc "Force applied by the lacing mechanism in newtons.";
        unit N;
    }

    attribute def TensionLevel :> Real {
        doc "Normalized tension level from 0.0 (loose) to 1.0 (max).";
    }

    attribute def AngularDeviation :> Real {
        doc "Difference between measured and ideal posture angle in degrees.";
        unit deg;
    }

    attribute def TimeStamp :> Real {
        doc "Elapsed time since system startup in seconds.";
        unit s;
    }

    // ===== Item Definitions =====

    item def PostureSample {
        attribute measuredAngle : PostureAngle;
        attribute measuredCircumference : TorsoCircumference;
        attribute timestamp : TimeStamp;
    }

    item def CorrectionCommand {
        attribute targetTension : TensionLevel;
        attribute requestedForce : CompressionForce;
        attribute timestamp : TimeStamp;
    }

    item def SystemStatus {
        attribute active : Boolean;
        attribute currentTension : TensionLevel;
        attribute currentForce : CompressionForce;
        attribute faultDetected : Boolean;
    }

    // ===== Port Definitions =====

    port def PostureDataOut {
        out postureSample : PostureSample;
    }

    port def PostureDataIn {
        in postureSample : PostureSample;
    }

    port def CommandOut {
        out command : CorrectionCommand;
    }

    port def CommandIn {
        in command : CorrectionCommand;
    }

    port def StatusOut {
        out status : SystemStatus;
    }

    port def MechanicalInterface {
        attribute appliedForce : CompressionForce;
        attribute appliedTension : TensionLevel;
    }

    // ===== Part Definitions =====

    part def MetalBoning {
        attribute material : String = "SpringSteel";
        attribute length : LengthValue = 300 [mm];
        attribute stiffness : Real = 180.0; // N/mm
        attribute position : String; // e.g., "front", "side-left", "back"
        attribute active : Boolean = true;
    }

    part def StructuralFrame {
        attribute frameId : String;
        attribute maxAdjustmentRange : LengthValue = 120 [mm];
        attribute minCircumference : TorsoCircumference = 600 [mm];
        attribute maxCircumference : TorsoCircumference = 950 [mm];

        part boningElements : MetalBoning[8] {
            // Distributed around torso
        }

        port mechanicalInterface : MechanicalInterface;

        exhibit state FrameBehavior {
            entry; then Idle;
            state Idle;
            transition Idle to Idle
                when mechanicalInterface.appliedForce > 0 [N];
        }
    }

    part def LacingMechanism {
        attribute currentTension : TensionLevel = 0.0;
        attribute currentForce : CompressionForce = 0 [N];
        attribute maxForce : CompressionForce = 80 [N];
        attribute minForce : CompressionForce = 5 [N];
        attribute adjustmentSpeed : Real = 2.0; // N/s

        port mechanicalIn : MechanicalInterface;
        port mechanicalOut : MechanicalInterface;

        exhibit action AdjustTension
            in requestedTension : TensionLevel
            in requestedForce : CompressionForce {
            // Clamp to safe limits
            if requestedForce > maxForce {
                currentForce := maxForce;
            } else if requestedForce < minForce {
                currentForce := minForce;
            } else {
                currentForce := requestedForce;
            }
            currentTension := requestedTension;
            mechanicalOut.appliedForce := currentForce;
            mechanicalOut.appliedTension := currentTension;
        }
    }

    part def PostureSensor {
        attribute samplingRate : Real = 10.0; // Hz
        attribute calibrated : Boolean = false;

        port dataOut : PostureDataOut;

        exhibit action SamplePosture {
            out sample : PostureSample;
            // Reads spinal alignment and torso circumference
            sample.measuredAngle := 0 [deg];
            sample.measuredCircumference := 750 [mm];
            sample.timestamp := 0 [s];
            send sample via dataOut.postureSample;
        }

        exhibit state SensorStateMachine {
            entry; then Calibrating;
            state Calibrating {
                entry { calibrated := false; }
                do { calibrated := true; }
            }
            transition Calibrating to Active
                when calibrated == true;
            state Active {
                do { perform SamplePosture(); }
            }
            transition Active to Fault
                when samplingRate <= 0.0;
            state Fault {
                entry { calibrated := false; }
            }
        }
    }

    part def ControlUnit {
        attribute idealPostureAngle : PostureAngle = 0 [deg];
        attribute maxCompressionForce : CompressionForce = 80 [N];
        attribute minCompressionForce : CompressionForce = 5 [N];
        attribute deviationThreshold : AngularDeviation = 5 [deg];
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.05;
        attribute derivativeGain : Real = 0.1;
        attribute integralAccumulator : Real = 0.0;
        attribute previousDeviation : AngularDeviation = 0 [deg];
        attribute controlLoopPeriod : Real = 0.1; // seconds

        port sensorIn : PostureDataIn;
        port actuatorOut : CommandOut;
        port statusOut : StatusOut;

        exhibit action EvaluatePosture
            in sample : PostureSample
            out command : CorrectionCommand {
            attribute deviation : AngularDeviation = sample.measuredAngle - idealPostureAngle;
            attribute derivative : AngularDeviation = deviation - previousDeviation;
            integralAccumulator := integralAccumulator + deviation;
            attribute correction : Real = proportionalGain * deviation
                + integralGain * integralAccumulator
                + derivativeGain * derivative;
            attribute targetForce : CompressionForce;
            if correction > 0 {
                targetForce := maxCompressionForce * (correction / 45.0);
            } else {
                targetForce := minCompressionForce;
            }
            if targetForce > maxCompressionForce {
                targetForce := maxCompressionForce;
            }
            if targetForce < minCompressionForce {
                targetForce := minCompressionForce;
            }
            command.targetTension := targetForce / maxCompressionForce;
            command.requestedForce := targetForce;
            command.timestamp := sample.timestamp;
            previousDeviation := deviation;
        }

        exhibit state ControlLoop {
            entry; then Monitoring;
            state Monitoring {
                do {
                    accept sample : PostureSample via sensorIn.postureSample;
                    attribute cmd : CorrectionCommand;
                    perform EvaluatePosture(in sample, out cmd);
                    send cmd via actuatorOut.command;
                }
            }
            transition Monitoring to Monitoring
                when true; // continuous loop
            transition Monitoring to SafeMode
                when sensorIn.postureSample == null;
            state SafeMode {
                entry {
                    attribute safeCmd : CorrectionCommand;
                    safeCmd.targetTension := 0.0;
                    safeCmd.requestedForce := minCompressionForce;
                    safeCmd.timestamp := 0 [s];
                    send safeCmd via actuatorOut.command;
                }
            }
            transition SafeMode to Monitoring
                when sensorIn.postureSample != null;
        }
    }

    part def CompressionActuator {
        attribute ratedForce : CompressionForce = 100 [N];
        attribute responseTime : Real = 0.2; // seconds
        attribute currentForce : CompressionForce = 0 [N];

        port commandIn : CommandIn;
        port mechanicalOut : MechanicalInterface;

        exhibit action ApplyCommand
            in cmd : CorrectionCommand {
            currentForce := cmd.requestedForce;
            mechanicalOut.appliedForce := currentForce;
            mechanicalOut.appliedTension := cmd.targetTension;
        }

        exhibit state ActuatorStateMachine {
            entry; then Idle;
            state Idle;
            transition Idle to Adjusting
                when commandIn.command != null;
            state Adjusting {
                do { perform ApplyCommand(in commandIn.command); }
            }
            transition Adjusting to Idle
                when mechanicalOut.appliedForce == currentForce;
            transition Adjusting to Overload
                when currentForce > ratedForce;
            state Overload {
                entry { currentForce := 0 [N]; }
            }
        }
    }

    part def CorsetSystem {
        attribute systemId : String = "ICS-001";
        attribute wearerProfile : String;
        attribute maxCompressionLimit : CompressionForce = 80 [N];
        attribute adjustmentRange : LengthValue = 120 [mm];
        attribute powered : Boolean = false;

        port externalStatus : StatusOut;

        part frame : StructuralFrame {
            attribute frameId := "Frame-A";
        }

        part lacing : LacingMechanism;

        part sensor : PostureSensor;

        part controller : ControlUnit {
            attribute maxCompressionForce := maxCompressionLimit;
        }

        part actuator : CompressionActuator;

        connection sensorDataFlow connect sensor.dataOut to controller.sensorIn;
        connection commandFlow connect controller.actuatorOut to actuator.commandIn;
        connection mechanicalLink1 connect actuator.mechanicalOut to lacing.mechanicalIn;
        connection mechanicalLink2 connect lacing.mechanicalOut to frame.mechanicalInterface;
        connection statusReport connect controller.statusOut to externalStatus;

        exhibit state SystemOperation {
            entry { powered := true; }
            then PowerOn;
            state PowerOn {
                entry {
                    attribute initStatus : SystemStatus;
                    initStatus.active := true;
                    initStatus.currentTension := 0.0;
                    initStatus.currentForce := 0 [N];
                    initStatus.faultDetected := false;
                    send initStatus via externalStatus.status;
                }
            }
            transition PowerOn to Operational
                when sensor.calibrated == true;
            state Operational {
                do {
                    // Continuous monitoring and correction loop
                    accept sample : PostureSample via sensor.dataOut.postureSample;
                }
            }
            transition Operational to Shutdown
                when powered == false;
            state Shutdown {
                entry {
                    attribute finalStatus : SystemStatus;
                    finalStatus.active := false;
                    finalStatus.currentTension := 0.0;
                    finalStatus.currentForce := 0 [N];
                    finalStatus.faultDetected := false;
                    send finalStatus via externalStatus.status;
                }
            }
        }
    }

    // ===== Requirements =====

    requirement def PostureCorrectionRequirement {
        doc "The system shall continuously monitor and correct wearer posture.";
        attribute targetDeviation : AngularDeviation = 5 [deg];
        attribute responseTime : Real = 1.0; // seconds
        subject corset : CorsetSystem;
        objective {
            corset.controller.deviationThreshold <= targetDeviation
            and corset.controller.controlLoopPeriod <= responseTime;
        }
    }

    requirement def SafetyRequirement {
        doc "The system shall not exceed configurable maximum compression force.";
        attribute maxSafeForce : CompressionForce = 80 [N];
        subject corset : CorsetSystem;
        objective {
            corset.lacing.currentForce <= maxSafeForce
            and corset.actuator.currentForce <= corset.actuator.ratedForce;
        }
    }

    requirement def AdaptabilityRequirement {
        doc "The system shall accommodate different body types via configurable adjustment range.";
        attribute minRange : LengthValue = 100 [mm];
        subject corset : CorsetSystem;
        objective {
            corset.frame.maxAdjustmentRange >= minRange;
        }
    }

    requirement def ContinuousOperationRequirement {
        doc "The sensing, calculating, and adjusting process shall run in a continuous loop.";
        subject corset : CorsetSystem;
        objective {
            corset.controller.ControlLoop.Monitoring.reentry == true;
        }
    }

    requirement corsetRequirements : PostureCorrectionRequirement {
        targetDeviation := 5 [deg];
        responseTime := 1.0;
    }

    requirement safetyRequirements : SafetyRequirement {
        maxSafeForce := 80 [N];
    }

    requirement adaptabilityRequirements : AdaptabilityRequirement {
        minRange := 100 [mm];
    }

    requirement continuousOperationRequirements : ContinuousOperationRequirement;

    // ===== Satisfaction =====

    satisfaction corsetRequirements by corsetSystemInstance.controller;
    satisfaction safetyRequirements by corsetSystemInstance.lacing;
    satisfaction adaptabilityRequirements by corsetSystemInstance.frame;
    satisfaction continuousOperationRequirements by corsetSystemInstance.controller;

    // ===== Instance =====

    part corsetSystemInstance : CorsetSystem {
        attribute systemId := "ICS-001";
        attribute wearerProfile := "Adult-Medium";
        attribute maxCompressionLimit := 75 [N];
        attribute adjustmentRange := 110 [mm];

        part frame {
            attribute frameId := "Frame-A";
            part boningElements[8] {
                attribute position := {"front", "front-left", "side-left", "back-left", "back", "back-right", "side-right", "front-right"};
            }
        }

        part lacing {
            attribute maxForce := 75 [N];
        }

        part sensor {
            attribute samplingRate := 12.0;
        }

        part controller {
            attribute idealPostureAngle := 0 [deg];
            attribute maxCompressionForce := 75 [N];
            attribute deviationThreshold := 4 [deg];
        }

        part actuator {
            attribute ratedForce := 90 [N];
        }
    }

}
