package JugglingRobotSystem {
    import ScalarValues::Real;
    import ScalarValues::Integer;
    import ScalarValues::Boolean;
    import ScalarValues::String;

    attribute def Length;
    attribute def Speed;
    attribute def ForceValue;
    attribute def Angle;
    attribute def TimeStamp;
    attribute def Voltage;
    attribute def Current;
    attribute def Frequency;
    attribute def Duration;

    item def BallPosition {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute vx : Speed;
        attribute vy : Speed;
        attribute vz : Speed;
        attribute timestamp : TimeStamp;
    }

    item def BallTrajectory {
        attribute ballId : Integer;
        attribute positions : BallPosition[0..*];
        attribute predictedLandingX : Length;
        attribute predictedLandingY : Length;
        attribute predictedLandingZ : Length;
        attribute predictedLandingTime : TimeStamp;
    }

    item def ArmCommand {
        attribute targetX : Length;
        attribute targetY : Length;
        attribute targetZ : Length;
        attribute gripperClose : Boolean;
        attribute throwForce : ForceValue;
        attribute throwAngle : Angle;
    }

    item def VisionData {
        attribute trackedBalls : BallTrajectory[0..*];
        attribute frameTimestamp : TimeStamp;
    }

    item def PowerStatus {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute batteryLevel : Real;
    }

    item def CalibrationResult {
        attribute armsCalibrated : Boolean;
        attribute visionCalibrated : Boolean;
        attribute timestamp : TimeStamp;
    }

    attribute def StartSignal;
    attribute def CalibrateSignal;
    attribute def BallDroppedSignal;
    attribute def RecoveryFailedSignal;
    attribute def ShutdownSignal;
    attribute def EmergencyStopSignal;
    attribute def PowerOnSignal;
    attribute def CalibrationCompleteSignal;

    port def VisionDataOutPort {
        out visionData : VisionData;
    }
    port def VisionDataInPort {
        in visionData : VisionData;
    }
    port def ArmCommandOutPort {
        out armCommand : ArmCommand;
    }
    port def ArmCommandInPort {
        in armCommand : ArmCommand;
    }
    port def PowerOutPort {
        out powerStatus : PowerStatus;
    }
    port def PowerInPort {
        in powerStatus : PowerStatus;
    }
    port def FeedbackOutPort {
        out positionX : Length;
        out positionY : Length;
        out positionZ : Length;
        out gripperClosed : Boolean;
    }
    port def FeedbackInPort {
        in positionX : Length;
        in positionY : Length;
        in positionZ : Length;
        in gripperClosed : Boolean;
    }
    port def CalibrationPort {
        in calibrationCommand : CalibrateSignal;
        out calibrationResult : CalibrationResult;
    }

    part def Gripper {
        attribute isOpen : Boolean;
        action grip {
            in close : Boolean;
            first start;
            then action actuateGripper;
            then done;
        }
    }

    part def Joint {
        attribute currentAngle : Angle;
        attribute targetAngle : Angle;
    }

    part def RoboticArm {
        attribute armId : Integer;
        port commandPort : ArmCommandInPort;
        port feedbackPort : FeedbackOutPort;
        part gripper : Gripper;
        part joints[6] : Joint;
        action executeCommand {
            in command : ArmCommand;
            first start;
            then action moveToPosition;
            then action operateGripper;
            then done;
        }
    }

    part def Camera {
        attribute resolution : Integer;
        attribute frameRate : Frequency;
    }

    part def VisionSystem {
        port visionDataPort : VisionDataOutPort;
        port calibrationPort : CalibrationPort;
        port powerIn : PowerInPort;
        part cameras[2] : Camera;
        action trackBalls {
            out data : VisionData;
            first start;
            then action captureFrames;
            then action identifyBalls;
            then action computeTrajectories;
            then action predictLandingPoints;
            then done;
        }
    }

    part def ControlProcessor {
        port visionDataPort : VisionDataInPort;
        port armFeedbackPortLeft : FeedbackInPort;
        port armFeedbackPortRight : FeedbackInPort;
        port leftArmCommandPort : ArmCommandOutPort;
        port rightArmCommandPort : ArmCommandOutPort;
        port powerIn : PowerInPort;
        action processVisionData {
            in data : VisionData;
            out leftCommand : ArmCommand;
            out rightCommand : ArmCommand;
            first start;
            then action analyzeTrajectories;
            then action selectArm;
            then action planCatch;
            then action planThrow;
            then done;
        }
        action calculateRecovery {
            out leftCommand : ArmCommand;
            out rightCommand : ArmCommand;
            first start;
            then action assessPattern;
            then action adjustTiming;
            then done;
        }
    }

    part def PowerSupply {
        port powerPort : PowerOutPort;
        attribute maxVoltage : Voltage;
        attribute maxCurrent : Current;
        action supplyPower {
            out status : PowerStatus;
            first start;
            then action monitorLoad;
            then done;
        }
    }

    part def JugglingRobot {
        port visionDataPort : VisionDataInPort;
        port powerPort : PowerInPort;
        port leftArmCommandPort : ArmCommandOutPort;
        port rightArmCommandPort : ArmCommandOutPort;
    }

    action performSelfTest;
    action calibrateArms;
    action calibrateVision;
    action systemReady;
    action receiveVisionData;
    action updateBallPositions;
    action predictLandingPoint;
    action moveArmToPosition;
    action closeGripper;
    action calculateThrowForce;
    action executeThrow;
    action checkBallCount;
    action checkArmStatus;
    action enterRecoveryMode;
    action adjustJugglingPattern;
    action resetArmPositions;
    action initiateControlledShutdown;
    action stopArms;
    action releaseGrippers;
    action powerDownSystems;

    state def JugglingStateMachine {
        entry; then Initializing;
        state Initializing;
        do action performSelfTest;
        do action calibrateArms;
        do action calibrateVision;
        accept CalibrateSignal then Ready;
        state Ready;
        do action systemReady;
        accept StartSignal then ActiveJuggling;
        accept ShutdownSignal then Shutdown;
        state ActiveJuggling parallel {
            state TrackingLoop {
                entry; then Tracking;
                state Tracking;
                do action receiveVisionData;
                do action updateBallPositions;
                transition first Tracking then Catching;
                state Catching;
                do action predictLandingPoint;
                do action moveArmToPosition;
                do action closeGripper;
                transition first Catching accept BallDroppedSignal then Recovery;
                transition first Catching then Throwing;
                state Throwing;
                do action calculateThrowForce;
                do action executeThrow;
                transition first Throwing then Tracking;
            }
            state MonitoringLoop {
                entry; then Monitoring;
                state Monitoring;
                do action checkBallCount;
                do action checkArmStatus;
                accept BallDroppedSignal then Recovery;
                accept EmergencyStopSignal then Shutdown;
            }
        }
        state Recovery;
        do action enterRecoveryMode;
        do action adjustJugglingPattern;
        do action resetArmPositions;
        accept StartSignal then ActiveJuggling;
        accept RecoveryFailedSignal then Shutdown;
        accept ShutdownSignal then Shutdown;
        state Shutdown;
        do action initiateControlledShutdown;
        do action stopArms;
        do action releaseGrippers;
        do action powerDownSystems;
        then done;
        accept EmergencyStopSignal then Shutdown;
    }

    requirement def JugglingCapability {
        attribute minBallsJuggled : Integer = 3;
        attribute maxThrowFrequency : Frequency = 2.0;
        subject jugglingRobot : JugglingRobot;
        require {
            jugglingRobot shall maintain continuous juggling of at least minBallsJuggled balls;
        }
    }

    requirement def VisionAccuracy {
        attribute trackingError : Length;
        attribute processingLatency : Duration;
        subject visionSystem : VisionSystem;
        require {
            visionSystem shall track ball positions with error less than trackingError;
            visionSystem shall provide trajectory data within processingLatency;
        }
    }

    requirement def ArmPrecision {
        attribute positioningAccuracy : Length;
        attribute gripperActuationTime : Duration;
        subject roboticArm : RoboticArm;
        require {
            roboticArm shall position gripper within positioningAccuracy of target;
            roboticArm shall actuate gripper within gripperActuationTime;
        }
    }

    requirement def RecoveryCapability {
        attribute maxRecoveryAttempts : Integer = 3;
        subject jugglingRobot : JugglingRobot;
        require {
            jugglingRobot shall attempt recovery up to maxRecoveryAttempts times before shutdown;
        }
    }

    requirement def SafetyShutdown {
        attribute maxShutdownTime : Duration = 5.0;
        subject jugglingRobot : JugglingRobot;
        require {
            jugglingRobot shall perform controlled shutdown within maxShutdownTime;
        }
    }

    part jugglingRobotSystem {
        part powerSupply : PowerSupply {
            port powerPort : PowerOutPort;
        }
        part visionSystem : VisionSystem {
            port visionDataPort : VisionDataOutPort;
            port calibrationPort : CalibrationPort;
            port powerIn : PowerInPort;
        }
        part controlProcessor : ControlProcessor {
            port visionDataPort : VisionDataInPort;
            port armFeedbackPortLeft : FeedbackInPort;
            port armFeedbackPortRight : FeedbackInPort;
            port leftArmCommandPort : ArmCommandOutPort;
            port rightArmCommandPort : ArmCommandOutPort;
            port powerIn : PowerInPort;
        }
        part leftArm : RoboticArm {
            :>> armId = 1;
            port commandPort : ArmCommandInPort;
            port feedbackPort : FeedbackOutPort;
        }
        part rightArm : RoboticArm {
            :>> armId = 2;
            port commandPort : ArmCommandInPort;
            port feedbackPort : FeedbackOutPort;
        }
        part jugglingRobot : JugglingRobot {
            port visionDataPort : VisionDataInPort;
            port powerPort : PowerInPort;
            port leftArmCommandPort : ArmCommandOutPort;
            port rightArmCommandPort : ArmCommandOutPort;
        }

        flow visionDataFlow of VisionData
            from visionSystem.visionDataPort.visionData
            to controlProcessor.visionDataPort.visionData;

        flow visionDataToRobotFlow of VisionData
            from visionSystem.visionDataPort.visionData
            to jugglingRobot.visionDataPort.visionData;

        flow powerFlow of PowerStatus
            from powerSupply.powerPort.powerStatus
            to jugglingRobot.powerPort.powerStatus;

        flow powerToVisionFlow of PowerStatus
            from powerSupply.powerPort.powerStatus
            to visionSystem.powerIn.powerStatus;

        flow powerToProcessorFlow of PowerStatus
            from powerSupply.powerPort.powerStatus
            to controlProcessor.powerIn.powerStatus;

        flow leftArmCommandFlow of ArmCommand
            from controlProcessor.leftArmCommandPort.armCommand
            to leftArm.commandPort.armCommand;

        flow rightArmCommandFlow of ArmCommand
            from controlProcessor.rightArmCommandPort.armCommand
            to rightArm.commandPort.armCommand;

        flow leftArmFeedbackX of Length
            from leftArm.feedbackPort.positionX
            to controlProcessor.armFeedbackPortLeft.positionX;

        flow leftArmFeedbackY of Length
            from leftArm.feedbackPort.positionY
            to controlProcessor.armFeedbackPortLeft.positionY;

        flow leftArmFeedbackZ of Length
            from leftArm.feedbackPort.positionZ
            to controlProcessor.armFeedbackPortLeft.positionZ;

        flow leftGripperFeedback of Boolean
            from leftArm.feedbackPort.gripperClosed
            to controlProcessor.armFeedbackPortLeft.gripperClosed;

        flow rightArmFeedbackX of Length
            from rightArm.feedbackPort.positionX
            to controlProcessor.armFeedbackPortRight.positionX;

        flow rightArmFeedbackY of Length
            from rightArm.feedbackPort.positionY
            to controlProcessor.armFeedbackPortRight.positionY;

        flow rightArmFeedbackZ of Length
            from rightArm.feedbackPort.positionZ
            to controlProcessor.armFeedbackPortRight.positionZ;

        flow rightGripperFeedback of Boolean
            from rightArm.feedbackPort.gripperClosed
            to controlProcessor.armFeedbackPortRight.gripperClosed;

        connect visionSystem.visionDataPort to controlProcessor.visionDataPort;
        connect visionSystem.visionDataPort to jugglingRobot.visionDataPort;
        connect powerSupply.powerPort to jugglingRobot.powerPort;
        connect powerSupply.powerPort to visionSystem.powerIn;
        connect powerSupply.powerPort to controlProcessor.powerIn;
        connect controlProcessor.leftArmCommandPort to leftArm.commandPort;
        connect controlProcessor.rightArmCommandPort to rightArm.commandPort;
        connect leftArm.feedbackPort to controlProcessor.armFeedbackPortLeft;
        connect rightArm.feedbackPort to controlProcessor.armFeedbackPortRight;

        satisfy jugglingCapabilityRequirement : JugglingCapability by jugglingRobot;
        satisfy visionAccuracyRequirement : VisionAccuracy by visionSystem;
        satisfy leftArmPrecisionRequirement : ArmPrecision by leftArm;
        satisfy rightArmPrecisionRequirement : ArmPrecision by rightArm;
        satisfy recoveryCapabilityRequirement : RecoveryCapability by jugglingRobot;
        satisfy safetyShutdownRequirement : SafetyShutdown by jugglingRobot;
    }
}
