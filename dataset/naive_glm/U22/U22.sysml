package JugglingRobotSystem {
    import ScalarValues::*;

    value type LengthValue :> Real { unit: "m"; }
    value type VelocityValue :> Real { unit: "m/s"; }
    value type ForceValue :> Real { unit: "N"; }
    value type TimeValue :> Real { unit: "s"; }
    value type FrequencyValue :> Real { unit: "Hz"; }
    value type VoltageValue :> Real { unit: "V"; }
    value type CurrentValue :> Real { unit: "A"; }

    item def JugglingBall;
    item def ElectricalPower;

    attribute def Coordinate3D {
        attribute x: LengthValue;
        attribute y: LengthValue;
        attribute z: LengthValue;
    }

    attribute def BallTrajectory {
        attribute ballId: Integer;
        attribute position: Coordinate3D;
        attribute velocity: VelocityValue;
        attribute timestamp: TimeValue;
    }

    attribute def MotionCommand {
        attribute targetPosition: Coordinate3D;
        attribute throwForce: ForceValue;
        attribute gripperAction: String;
    }

    action def TrackBalls {
        in ball: JugglingBall;
        out trajectory: BallTrajectory;
    }

    action def CalculateTrajectories {
        in rawTrajectory: BallTrajectory;
        out processedTrajectory: BallTrajectory;
    }

    action def PredictLanding {
        in processedTrajectory: BallTrajectory;
        out landingPoint: Coordinate3D;
    }

    action def PlanThrow {
        in landingPoint: Coordinate3D;
        out command: MotionCommand;
    }

    action def MoveArm {
        in command: MotionCommand;
    }

    action def ActuateGripper {
        in command: MotionCommand;
    }

    port def VisionDataOut {
        out trajectoryData: BallTrajectory;
    }

    port def VisionDataIn {
        in trajectoryData: BallTrajectory;
    }

    port def MotionCommandOut {
        out command: MotionCommand;
    }

    port def MotionCommandIn {
        in command: MotionCommand;
    }

    port def PowerOut {
        out power: ElectricalPower;
    }

    port def PowerIn {
        in power: ElectricalPower;
    }

    state machine def JugglingExecutionStates {
        state initialization;
        state calibration;
        state activeJuggling {
            state tracking;
            state catching;
            state throwing;
            
            transition T_track_catch source tracking target catching;
            transition T_catch_throw source catching target throwing;
            transition T_throw_track source throwing target tracking;
        }
        state recovery;
        state controlledShutdown;
        
        transition T_init_calib source initialization target calibration;
        transition T_calib_active source calibration target activeJuggling;
        transition T_active_recovery source activeJuggling target recovery when ballDropped;
        transition T_recovery_active source recovery target activeJuggling when patternRestored;
        transition T_recovery_shutdown source recovery target controlledShutdown when recoveryFailed;
    }

    requirement def AutonomousJugglingRequirement {
        doc /* The JugglingRobot shall autonomously juggle multiple balls using perception, computation, and mechanical action. */;
    }

    requirement def VisionTrackingRequirement {
        doc /* The VisionSystem shall track ball positions and trajectories in real-time. */;
    }

    requirement def ArmSynchronizationRequirement {
        doc /* The arms and vision system shall be synchronized during initialization and calibration. */;
    }

    requirement def RecoveryRequirement {
        doc /* The JugglingRobot shall enter recovery mode if a catch is missed and attempt to adjust its pattern. */;
    }

    requirement def ControlledShutdownRequirement {
        doc /* The JugglingRobot shall perform a controlled shutdown if it cannot recover from a dropped ball. */;
    }

    part def PowerSupply {
        port powerOutVision: PowerOut;
        port powerOutProcessor: PowerOut;
        port powerOutLeftArm: PowerOut;
        port powerOutRightArm: PowerOut;
        
        attribute outputVoltage: VoltageValue;
        attribute maxCurrent: CurrentValue;
    }

    part def VisionSystem {
        port visionOut: VisionDataOut;
        port powerIn: PowerIn;
        
        attribute frameRate: FrequencyValue;
        
        perform track: TrackBalls;
        
        satisfy VisionTrackingRequirement;
    }

    part def ControlProcessor {
        port visionIn: VisionDataIn;
        port leftArmCommandOut: MotionCommandOut;
        port rightArmCommandOut: MotionCommandOut;
        port powerIn: PowerIn;
        
        attribute processingRate: FrequencyValue;
        attribute ballDropped: Boolean;
        attribute patternRestored: Boolean;
        attribute recoveryFailed: Boolean;
        
        perform calcTraj: CalculateTrajectories;
        perform predLand: PredictLanding;
        perform planThrow: PlanThrow;
    }

    part def Gripper {
        port commandIn: MotionCommandIn;
        port powerIn: PowerIn;
        
        attribute isClosed: Boolean;
        
        perform grip: ActuateGripper;
    }

    part def RoboticArm {
        port commandIn: MotionCommandIn;
        port powerIn: PowerIn;
        
        part gripper: Gripper;
        attribute jointCount: Integer;
        
        perform move: MoveArm;
        
        connect powerIn to gripper.powerIn;
        connect commandIn to gripper.commandIn;
    }

    part def JugglingRobot {
        part powerSupply: PowerSupply;
        part visionSystem: VisionSystem;
        part controlProcessor: ControlProcessor;
        part leftArm: RoboticArm;
        part rightArm: RoboticArm;
        
        state machine executionStateMachine: JugglingExecutionStates;
        
        connect powerSupply.powerOutVision to visionSystem.powerIn;
        connect powerSupply.powerOutProcessor to controlProcessor.powerIn;
        connect powerSupply.powerOutLeftArm to leftArm.powerIn;
        connect powerSupply.powerOutRightArm to rightArm.powerIn;
        
        connect visionSystem.visionOut to controlProcessor.visionIn;
        connect controlProcessor.leftArmCommandOut to leftArm.commandIn;
        connect controlProcessor.rightArmCommandOut to rightArm.commandIn;
        
        satisfy AutonomousJugglingRequirement;
        satisfy ArmSynchronizationRequirement;
        satisfy RecoveryRequirement;
        satisfy ControlledShutdownRequirement;
    }
}
