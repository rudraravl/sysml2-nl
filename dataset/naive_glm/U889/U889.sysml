package SpacecraftAttitudeControlSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;

    // ---------- Value Types ----------
    value def AngleDeg = Real { unit 'deg'; }
    value def AngularRateDegPerSec = Real { unit 'deg/s'; }
    value def AngularAccelerationDegPerSec2 = Real { unit 'deg/s2'; }
    value def TorqueNm = Real { unit 'N*m'; }
    value def WheelSpeedRPM = Real { unit 'rpm'; }
    value def InertiaKgM2 = Real { unit 'kg*m2'; }
    value def FrequencyHz = Real { unit 'Hz'; }
    value def TimeSec = Real { unit 's'; }

    item def AttitudeQuat {
        attribute w: Real;
        attribute x: Real;
        attribute y: Real;
        attribute z: Real;
    }

    item def AttitudeEuler {
        attribute roll: AngleDeg;
        attribute pitch: AngleDeg;
        attribute yaw: AngleDeg;
    }

    item def AngularRateVector {
        attribute x: AngularRateDegPerSec;
        attribute y: AngularRateDegPerSec;
        attribute z: AngularRateDegPerSec;
    }

    item def TorqueCommand {
        attribute x: TorqueNm;
        attribute y: TorqueNm;
        attribute z: TorqueNm;
    }

    item def WheelSpeedVector {
        attribute x: WheelSpeedRPM;
        attribute y: WheelSpeedRPM;
        attribute z: WheelSpeedRPM;
    }

    item def TargetAttitude {
        attribute attitude: AttitudeEuler;
    }

    item def StarTrackerData {
        attribute attitude: AttitudeQuat;
        attribute timestamp: TimeSec;
    }

    item def GyroData {
        attribute rate: AngularRateVector;
        attribute timestamp: TimeSec;
    }

    item def FusedAttitude {
        attribute attitude: AttitudeQuat;
        attribute rate: AngularRateVector;
        attribute timestamp: TimeSec;
    }

    item def ControlError {
        attribute attitudeError: AttitudeEuler;
        attribute rateError: AngularRateVector;
    }

    // ---------- Ports ----------
    port def TargetAttitudePort {
        out target: TargetAttitude;
    }

    port def StarTrackerDataPort {
        out starData: StarTrackerData;
    }

    port def GyroDataPort {
        out gyroData: GyroData;
    }

    port def FusedAttitudePort {
        out fused: FusedAttitude;
    }

    port def TorqueCommandPort {
        out torqueCmd: TorqueCommand;
    }

    port def WheelCommandPort {
        out wheelCmd: WheelSpeedVector;
    }

    port def WheelTelemetryPort {
        out wheelSpeed: WheelSpeedVector;
        out saturated: Boolean[3];
    }

    // ---------- Requirements ----------
    requirement def PointingAccuracyRequirement {
        doc /* The system shall maintain pointing accuracy within 0.01 degrees on all axes. */
        attribute maxError: AngleDeg = 0.01;
        subject attitudeControl: SpacecraftAttitudeControlSystem;
        require { attitudeControl.pointingError <= maxError; }
    }

    requirement def StabilizationTimeRequirement {
        doc /* The system shall stabilize the spacecraft within 60 seconds after a maneuver command. */
        attribute maxStabilizationTime: TimeSec = 60.0;
        subject attitudeControl: SpacecraftAttitudeControlSystem;
        require { attitudeControl.stabilizationTime <= maxStabilizationTime; }
    }

    requirement def TorqueAuthorityRequirement {
        doc /* The system shall generate at least 0.05 N*m of torque per axis for maneuvers. */
        attribute minTorque: TorqueNm = 0.05;
        subject attitudeControl: SpacecraftAttitudeControlSystem;
        require { attitudeControl.maxTorquePerAxis >= minTorque; }
    }

    requirement def SaturationHandlingRequirement {
        doc /* The system shall detect reaction wheel saturation and flag the affected axis. */
        subject attitudeControl: SpacecraftAttitudeControlSystem;
        require { attitudeControl.saturationDetection == true; }
    }

    requirement AttitudeControlRequirements {
        satisfy PointingAccuracyRequirement;
        satisfy StabilizationTimeRequirement;
        satisfy TorqueAuthorityRequirement;
        satisfy SaturationHandlingRequirement;
    }

    // ---------- Parts ----------
    part def StarTracker {
        port starOut: StarTrackerDataPort;
        attribute updateRate: FrequencyHz = 10.0;
        attribute accuracy: AngleDeg = 0.005;

        action computeAttitude {
            out data: StarTrackerData;
        }
    }

    part def GyroscopeUnit {
        port gyroOut: GyroDataPort;
        attribute updateRate: FrequencyHz = 100.0;
        attribute bandwidth: FrequencyHz = 50.0;

        action measureRate {
            out data: GyroData;
        }
    }

    part def ReactionWheel {
        attribute axis: String;
        attribute maxSpeed: WheelSpeedRPM = 6000.0;
        attribute inertia: InertiaKgM2 = 0.01;
        attribute currentSpeed: WheelSpeedRPM;
        attribute saturated: Boolean = false;
        attribute maxTorque: TorqueNm = 0.05;

        action spinWheel {
            in command: WheelSpeedRPM;
            out speed: WheelSpeedRPM;
            out saturatedFlag: Boolean;
        }

        state WheelStates {
            entry; then Operational;
            state Operational;
            transition Operational to Saturated
                if currentSpeed >= maxSpeed;
            state Saturated;
            transition Saturated to Operational
                if currentSpeed < maxSpeed;
        }
    }

    part def ReactionWheelAssembly {
        port wheelCmdIn: WheelCommandPort;
        port wheelTelemetryOut: WheelTelemetryPort;

        part wheelX: ReactionWheel { attribute axis = "X"; }
        part wheelY: ReactionWheel { attribute axis = "Y"; }
        part wheelZ: ReactionWheel { attribute axis = "Z"; }

        action applyCommands {
            in cmd: WheelSpeedVector;
            out telemetry: WheelSpeedVector;
            out saturation: Boolean[3];
        }
    }

    part def AttitudeControlComputer {
        port targetIn: TargetAttitudePort;
        port starIn: StarTrackerDataPort;
        port gyroIn: GyroDataPort;
        port fusedOut: FusedAttitudePort;
        port torqueOut: TorqueCommandPort;
        port wheelTelemetryIn: WheelTelemetryPort;

        attribute controlRate: FrequencyHz = 50.0;
        attribute pointingError: AngleDeg;
        attribute stabilizationTime: TimeSec;
        attribute maxTorquePerAxis: TorqueNm = 0.05;
        attribute saturationDetection: Boolean = true;

        action fuseSensorData {
            in star: StarTrackerData;
            in gyro: GyroData;
            out fused: FusedAttitude;
        }

        action computeError {
            in target: TargetAttitude;
            in measured: FusedAttitude;
            out error: ControlError;
        }

        action computeControl {
            in error: ControlError;
            in wheelTelemetry: WheelSpeedVector;
            out torque: TorqueCommand;
        }

        action convertTorqueToWheelCommand {
            in torque: TorqueCommand;
            out wheelCmd: WheelSpeedVector;
        }

        state ControlLoopStates {
            entry; then Idle;
            state Idle;
            transition Idle to Acquiring
                if targetIn.target != null;
            state Acquiring;
            transition Acquiring to Controlling
                if fusedOut.fused != null;
            state Controlling;
            transition Controlling to Stabilized
                if pointingError <= 0.01;
            state Stabilized;
            transition Stabilized to Controlling
                if pointingError > 0.01;
        }
    }

    part def SpacecraftAttitudeControlSystem {
        attribute pointingError: AngleDeg;
        attribute stabilizationTime: TimeSec;
        attribute maxTorquePerAxis: TorqueNm = 0.05;
        attribute saturationDetection: Boolean = true;

        port targetCommand: TargetAttitudePort;

        part controlComputer: AttitudeControlComputer {
            port targetIn = targetCommand;
        }
        part starTracker: StarTracker;
        part gyroUnit: GyroscopeUnit;
        part wheelAssembly: ReactionWheelAssembly;

        connection starTracker.starOut to controlComputer.starIn;
        connection gyroUnit.gyroOut to controlComputer.gyroIn;
        connection controlComputer.torqueOut to wheelAssembly.wheelCmdIn;
        connection wheelAssembly.wheelTelemetryOut to controlComputer.wheelTelemetryIn;

        action ControlLoop {
            action receiveTarget {
                out target: TargetAttitude;
            }
            action readSensors {
                out starData: StarTrackerData;
                out gyroData: GyroData;
            }
            action fuseData {
                in star: StarTrackerData;
                in gyro: GyroData;
                out fused: FusedAttitude;
            }
            action calculateError {
                in tgt: TargetAttitude;
                in fused: FusedAttitude;
                out error: ControlError;
            }
            action generateTorque {
                in err: ControlError;
                out torque: TorqueCommand;
            }
            action commandWheels {
                in torque: TorqueCommand;
                out wheelCmd: WheelSpeedVector;
            }
            action monitorSaturation {
                in wheelCmd: WheelSpeedVector;
                out saturated: Boolean[3];
            }

            flow receiveTarget.target to calculateError.tgt;
            flow readSensors.starData to fuseData.star;
            flow readSensors.gyroData to fuseData.gyro;
            flow fuseData.fused to calculateError.fused;
            flow calculateError.error to generateTorque.err;
            flow generateTorque.torque to commandWheels.torque;
            flow commandWheels.wheelCmd to monitorSaturation.wheelCmd;
        }

        satisfy AttitudeControlRequirements;
    }

    part def SpacecraftBus {
        part attitudeControl: SpacecraftAttitudeControlSystem;
    }

}
