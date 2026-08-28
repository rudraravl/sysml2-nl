package RainbowRB5 {

    import ScalarValues::*;

    // ===== Value Types =====

    value type TorqueValue :> Real { unit 'N.m'; }
    value type ForceValue :> Real { unit 'N'; }
    value type AngleValue :> Real { unit 'rad'; }
    value type AngularVelocityValue :> Real { unit 'rad/s'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type MassValue :> Real { unit 'kg'; }
    value type LengthValue :> Real { unit 'm'; }
    value type TimeValue :> Real { unit 's'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type ConfidenceValue :> Real { unit '1'; }

    // ===== Item Definitions =====

    item def JointCommand {
        attribute targetAngle : AngleValue;
        attribute targetVelocity : AngularVelocityValue;
        attribute maxTorque : TorqueValue;
    }

    item def JointFeedback {
        attribute actualAngle : AngleValue;
        attribute actualVelocity : AngularVelocityValue;
        attribute actualCurrent : CurrentValue;
        attribute actualTorque : TorqueValue;
    }

    item def CartesianPose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def Waypoint {
        attribute pose : CartesianPose;
        attribute arrivalTime : TimeValue;
    }

    item def Trajectory {
        attribute waypoints : Waypoint[0..*] ordered;
    }

    item def GripperCommand {
        attribute grasp : Boolean;
        attribute targetForce : ForceValue;
    }

    item def GripperFeedback {
        attribute isClosed : Boolean;
        attribute measuredForce : ForceValue;
    }

    item def Wrench {
        attribute fx : ForceValue;
        attribute fy : ForceValue;
        attribute fz : ForceValue;
        attribute tx : TorqueValue;
        attribute ty : TorqueValue;
        attribute tz : TorqueValue;
    }

    item def Image {
        attribute width : Integer;
        attribute height : Integer;
        attribute data : String;
    }

    item def DetectedPart {
        attribute partId : String;
        attribute pose : CartesianPose;
        attribute confidence : ConfidenceValue;
    }

    item def Part {
        attribute partId : String;
        attribute mass : MassValue;
    }

    item def TaskCommand {
        attribute commandId : String;
        attribute taskType : String;
        attribute sourcePose : CartesianPose;
        attribute targetPose : CartesianPose;
    }

    // ===== Port Definitions =====

    port def JointControlPort {
        out command : JointCommand;
        in feedback : JointFeedback;
    }

    port def GripperControlPort {
        out command : GripperCommand;
        in feedback : GripperFeedback;
    }

    port def FTDataPort {
        out wrench : Wrench;
    }

    port def VisionDataPort {
        out image : Image;
        out detectedParts : DetectedPart[0..*];
    }

    port def TaskCommandPort {
        in task : TaskCommand;
    }

    port def PowerPort {
        in voltage : VoltageValue;
    }

    // ===== Part Definitions =====

    part def JointActuator {
        port controlPort : JointControlPort;
        port powerPort : PowerPort;

        attribute jointId : String;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute maxTorque : TorqueValue;
        attribute maxVelocity : AngularVelocityValue;
        attribute gearRatio : Real;

        attribute currentAngle : AngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute currentTorque : TorqueValue;

        action def Actuate {
            in cmd : JointCommand;
            out fb : JointFeedback;
        }
    }

    part def Link {
        attribute linkId : String;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute material : String;
    }

    part def Gripper {
        port controlPort : GripperControlPort;

        attribute maxForce : ForceValue;
        attribute currentForce : ForceValue;
        attribute isGrasping : Boolean;

        action def Grasp {
            in targetForce : ForceValue;
        }

        action def Release {}
    }

    part def ForceTorqueSensor {
        port dataPort : FTDataPort;

        attribute maxForce : ForceValue;
        attribute maxTorque : TorqueValue;
        attribute measuredWrench : Wrench;
        attribute collisionThreshold : ForceValue;

        action def MeasureWrench {
            out wrench : Wrench;
        }

        action def DetectCollision {
            in wrench : Wrench;
            out collisionDetected : Boolean;
        }
    }

    part def VisionSensor {
        port dataPort : VisionDataPort;

        attribute resolution : String;
        attribute frameRate : FrequencyValue;

        action def CaptureImage {
            out image : Image;
        }

        action def DetectParts {
            in image : Image;
            out parts : DetectedPart[0..*];
        }
    }

    part def Controller {
        port taskPort : TaskCommandPort;
        port jointPort1 : JointControlPort;
        port jointPort2 : JointControlPort;
        port jointPort3 : JointControlPort;
        port jointPort4 : JointControlPort;
        port jointPort5 : JointControlPort;
        port jointPort6 : JointControlPort;
        port gripperPort : GripperControlPort;
        port ftPort : FTDataPort;
        port visionPort : VisionDataPort;
        port powerPort : PowerPort;

        attribute cycleTime : TimeValue;
        attribute collisionForceThreshold : ForceValue;
        attribute calibrationComplete : Boolean;
        attribute taskComplete : Boolean;
        attribute currentTrajectory : Trajectory;

        action def PlanTrajectory {
            in task : TaskCommand;
            out trajectory : Trajectory;
        }

        action def InverseKinematics {
            in cartesian : CartesianPose;
            out jointCommands : JointCommand[6];
        }

        action def MonitorSafety {
            in wrench : Wrench;
            out collisionDetected : Boolean;
        }

        action def CalibrateJoints {}
    }

    // ===== Robot Arm Assembly =====

    part def RobotArm {
        attribute model : String = "Rainbow RB-5";
        attribute payload : MassValue = 5.0;
        attribute reach : LengthValue = 0.85;
        attribute repeatability : LengthValue = 0.02;

        port taskInterface : TaskCommandPort;
        port powerInput : PowerPort;

        part controller : Controller {
            cycleTime = 0.001;
            collisionForceThreshold = 50.0;
            calibrationComplete = false;
            taskComplete = false;
        }

        part base : Link {
            linkId = "base";
            mass = 5.0;
            length = 0.0;
            material = "aluminum";
        }

        part link1 : Link {
            linkId = "link1";
            mass = 3.5;
            length = 0.2;
            material = "aluminum";
        }

        part link2 : Link {
            linkId = "link2";
            mass = 3.0;
            length = 0.25;
            material = "aluminum";
        }

        part link3 : Link {
            linkId = "link3";
            mass = 2.5;
            length = 0.2;
            material = "aluminum";
        }

        part link4 : Link {
            linkId = "link4";
            mass = 1.5;
            length = 0.1;
            material = "aluminum";
        }

        part link5 : Link {
            linkId = "link5";
            mass = 1.0;
            length = 0.08;
            material = "aluminum";
        }

        part link6 : Link {
            linkId = "link6";
            mass = 0.5;
            length = 0.05;
            material = "aluminum";
        }

        part joint1 : JointActuator {
            jointId = "J1_base";
            minAngle = -3.14;
            maxAngle = 3.14;
            maxTorque = 150.0;
            maxVelocity = 2.0;
            gearRatio = 160.0;
        }

        part joint2 : JointActuator {
            jointId = "J2_shoulder";
            minAngle = -1.57;
            maxAngle = 1.57;
            maxTorque = 120.0;
            maxVelocity = 2.0;
            gearRatio = 120.0;
        }

        part joint3 : JointActuator {
            jointId = "J3_elbow";
            minAngle = -3.0;
            maxAngle = 1.0;
            maxTorque = 80.0;
            maxVelocity = 2.5;
            gearRatio = 100.0;
        }

        part joint4 : JointActuator {
            jointId = "J4_wrist1";
            minAngle = -3.14;
            maxAngle = 3.14;
            maxTorque = 30.0;
            maxVelocity = 3.0;
            gearRatio = 50.0;
        }

        part joint5 : JointActuator {
            jointId = "J5_wrist2";
            minAngle = -2.0;
            maxAngle = 2.0;
            maxTorque = 20.0;
            maxVelocity = 3.0;
            gearRatio = 50.0;
        }

        part joint6 : JointActuator {
            jointId = "J6_wrist3";
            minAngle = -3.14;
            maxAngle = 3.14;
            maxTorque = 15.0;
            maxVelocity = 3.5;
            gearRatio = 30.0;
        }

        part gripper : Gripper {
            maxForce = 40.0;
            currentForce = 0.0;
            isGrasping = false;
        }

        part ftSensor : ForceTorqueSensor {
            maxForce = 200.0;
            maxTorque = 10.0;
            collisionThreshold = 50.0;
        }

        part camera : VisionSensor {
            resolution = "1280x720";
            frameRate = 30.0;
        }

        // Connections
        connection taskLink connect taskInterface to controller.taskPort;
        connection powerLink connect powerInput to controller.powerPort;

        connection j1Ctrl connect controller.jointPort1 to joint1.controlPort;
        connection j2Ctrl connect controller.jointPort2 to joint2.controlPort;
        connection j3Ctrl connect controller.jointPort3 to joint3.controlPort;
        connection j4Ctrl connect controller.jointPort4 to joint4.controlPort;
        connection j5Ctrl connect controller.jointPort5 to joint5.controlPort;
        connection j6Ctrl connect controller.jointPort6 to joint6.controlPort;

        connection gripperCtrl connect controller.gripperPort to gripper.controlPort;
        connection ftLink connect ftSensor.dataPort to controller.ftPort;
        connection visionLink connect camera.dataPort to controller.visionPort;

        // State Machine
        state def OperatingStates {
            entry; then PoweredOff;

            state PoweredOff {
                doc "Robot is powered off and not operational.";
            }

            transition powerOn
                first PoweredOff
                then Initializing
                when powerInput.voltage > 0.0;

            state Initializing {
                doc "Calibration phase: determine precise position of all joints.";
                entry action controller.CalibrateJoints();
            }

            transition calibrationDone
                first Initializing
                then Ready
                when controller.calibrationComplete == true;

            state Ready {
                doc "Robot is calibrated and ready to receive task commands.";
            }

            transition taskReceived
                first Ready
                then Executing
                when taskInterface.task.commandId != "";

            state Executing {
                doc "Robot is executing a pick-and-place or assembly trajectory.";
                entry action controller.PlanTrajectory();
            }

            transition taskDone
                first Executing
                then Ready
                when controller.taskComplete == true;

            transition collisionFromReady
                first Ready
                then EmergencyStop
                when ftSensor.measuredWrench.fz > ftSensor.collisionThreshold;

            transition collisionFromExecuting
                first Executing
                then EmergencyStop
                when ftSensor.measuredWrench.fz > ftSensor.collisionThreshold;

            state EmergencyStop {
                doc "Emergency stop: all joints halted immediately for safety.";
            }

            transition resetFromEStop
                first EmergencyStop
                then PoweredOff
                when powerInput.voltage == 0.0;
        }
    }

    // ===== Requirements =====

    requirement def RobotArmRequirement {
        doc "Base requirement for the Rainbow RB-5 collaborative robot arm.";
        subject robot : RobotArm;
    }

    requirement SixAxisConfiguration :> RobotArmRequirement {
        doc "The robot shall consist of six rigid links connected by six motorized joint actuators, providing six degrees of freedom for positioning and orienting the end-effector.";
    }

    requirement EndEffectorGripper :> RobotArmRequirement {
        doc "The robot shall be equipped with a gripper at the end of the arm to grasp and release objects with controlled force.";
        constraint { robot.gripper.maxForce <= 40.0 }
    }

    requirement CentralController :> RobotArmRequirement {
        doc "The robot shall include a central controller that receives high-level commands and translates them into precise control signals for each of the six joint actuators.";
    }

    requirement VisionCapability :> RobotArmRequirement {
        doc "The robot shall be equipped with a vision sensor to identify parts and perform quality inspections.";
    }

    requirement ForceTorqueSensing :> RobotArmRequirement {
        doc "The robot shall include a force-torque sensor at the wrist to detect contact and control forces during delicate operations.";
    }

    requirement InitializationCalibration :> RobotArmRequirement {
        doc "After being powered on, the robot shall enter an initialization and calibration phase to precisely determine the position of all its joints.";
    }

    requirement TrajectoryExecution :> RobotArmRequirement {
        doc "Once ready, the robot shall execute complex trajectories, moving its gripper smoothly between multiple waypoints.";
    }

    requirement ContinuousSafetyMonitoring :> RobotArmRequirement {
        doc "The robot shall continuously monitor for collisions; if a collision is detected, the system shall immediately enter an emergency stop state to ensure safety.";
        constraint { robot.ftSensor.collisionThreshold > 0.0 }
    }

    requirement PickAndPlaceOperation :> RobotArmRequirement {
        doc "The robot shall perform pick-and-place tasks: picking up a part from a feeder, moving it to an assembly point, and releasing it with high accuracy and repeatability.";
        constraint { robot.repeatability <= 0.05 }
    }
}
