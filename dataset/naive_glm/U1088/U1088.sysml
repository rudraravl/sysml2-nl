package HumanoidRobotSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type LengthValue :> Real { unit 'm'; }
    value type MassValue :> Real { unit 'kg'; }
    value type TimeValue :> Real { unit 's'; }
    value type SpeedValue :> Real { unit 'm/s'; }
    value type ForceValue :> Real { unit 'N'; }
    value type TorqueValue :> Real { unit 'Nm'; }
    value type AngleValue :> Real { unit 'rad'; }
    value type PowerValue :> Real { unit 'W'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type CapacityValue :> Real { unit 'Wh'; }
    value type BatteryPercentValue :> Real { unit '%'; }
    value type ResolutionValue :> Integer { unit 'px'; }

    // ===== Enumerations =====
    enum def OperationalMode {
        standby;
        operational;
        maintenance;
        emergency;
    }

    enum def TaskStatusKind {
        idle;
        scanning;
        planning;
        navigating;
        grasping;
        completed;
        aborted;
    }

    enum def CommandKind {
        retrieve;
        transport;
        returnHome;
        halt;
    }

    enum def GripperState {
        opened;
        closed;
        holding;
    }

    enum def JointState {
        idle;
        moving;
        holding;
    }

    // ===== Item Definitions =====
    item def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def DetectedObject {
        attribute id : String;
        attribute position : Position3D;
        attribute confidence : Real;
        attribute recognized : Boolean;
    }

    item def TaskCommand {
        attribute commandId : String;
        attribute kind : CommandKind;
        attribute targetObjectId : String;
        attribute targetLocation : Position3D;
    }

    item def StatusReport {
        attribute commandId : String;
        attribute status : TaskStatusKind;
        attribute mode : OperationalMode;
        attribute batteryLevel : BatteryPercentValue;
        attribute message : String;
    }

    item def PathPlan {
        attribute waypoints : Position3D[0..*];
        attribute estimatedDuration : TimeValue;
        attribute estimatedDistance : LengthValue;
    }

    item def JointCommand {
        attribute jointId : String;
        attribute targetAngle : AngleValue;
        attribute targetTorque : TorqueValue;
    }

    item def BaseCommand {
        attribute targetSpeed : SpeedValue;
        attribute targetHeading : AngleValue;
    }

    item def JointFeedback {
        attribute jointId : String;
        attribute currentAngle : AngleValue;
        attribute currentTorque : TorqueValue;
        attribute state : JointState;
    }

    item def BaseFeedback {
        attribute currentSpeed : SpeedValue;
        attribute currentHeading : AngleValue;
        attribute currentLocation : Position3D;
    }

    // ===== Port Definitions =====
    port def CommandPort {
        in command : TaskCommand;
        out report : StatusReport;
    }

    port def PerceptionPort {
        out objects : DetectedObject[0..*];
    }

    port def PowerPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
        out level : BatteryPercentValue;
    }

    port def JointActuationPort {
        in command : JointCommand;
        out feedback : JointFeedback;
    }

    port def BaseMotionPort {
        in command : BaseCommand;
        out feedback : BaseFeedback;
    }

    // ===== Action Definitions =====
    action def ScanEnvironment {
        out detectedObjects : DetectedObject[0..*];
    }

    action def PlanPath {
        in target : Position3D;
        out path : PathPlan;
    }

    action def PlanArmMotion {
        in target : Position3D;
        out jointCommands : JointCommand[0..*];
    }

    action def NavigateTo {
        in path : PathPlan;
    }

    action def GraspObject {
        in target : DetectedObject;
    }

    // ===== Requirements =====
    requirement def RobotDimensionSpec {
        doc { The humanoid robot shall be 1.7 meters tall. }
        attribute nominalHeight : LengthValue = 1.7 [m];
        attribute minHeight : LengthValue = 1.6 [m];
        attribute maxHeight : LengthValue = 1.8 [m];
    }

    requirement def RobotMassSpec {
        doc { The humanoid robot shall weigh approximately 80 kilograms. }
        attribute nominalMass : MassValue = 80 [kg];
        attribute maxMass : MassValue = 90 [kg];
    }

    requirement def BatteryEnduranceSpec {
        doc { The robot shall always maintain sufficient battery power for operation. }
        attribute minOperationalBattery : BatteryPercentValue = 20 [%];
        attribute warningBatteryLevel : BatteryPercentValue = 30 [%];
    }

    requirement def VisionSpec {
        doc { The vision system shall capture 2048p video at 60 fps and detect objects in 3D space. }
        attribute resolution : ResolutionValue = 2048 [px];
        attribute frameRate : FrequencyValue = 60 [Hz];
    }

    requirement def ArmDexteritySpec {
        doc { Each arm shall feature seven joints for a wide range of motion. }
        attribute jointCount : Integer = 7;
    }

    requirement def GripperSpec {
        doc { Each gripper shall be a two-fingered gripper with controlled force for holding objects. }
        attribute fingerCount : Integer = 2;
        attribute maxForce : ForceValue = 30 [N];
    }

    requirement def SafetyPerimeterSpec {
        doc { The robot shall operate within a defined work zone monitored by a safety perimeter. }
        attribute maxBoundaryRadius : LengthValue = 10 [m];
    }

    requirement def OperationalModeSpec {
        doc { The system shall operate under standby, operational, and maintenance modes. }
    }

    requirement def EmergencyAvoidanceSpec {
        doc { The system shall include built-in checks to avoid entering emergency state. }
    }

    requirement def ContinuousCommunicationSpec {
        doc { The robot shall continuously communicate task progress to the control center. }
    }

    requirement def TaskExecutionSpec {
        doc { The robot shall receive a command, scan the area, plan a path, navigate to the target, and grasp the object. }
    }

    // ===== Part Definitions =====
    part def Joint {
        doc { A single joint in a robotic arm with angle and torque control. }
        attribute id : String;
        attribute jointNumber : Integer;
        attribute minAngle : AngleValue = -3.14 [rad];
        attribute maxAngle : AngleValue = 3.14 [rad];
        attribute maxTorque : TorqueValue = 50 [Nm];
        attribute currentAngle : AngleValue = 0 [rad];
        attribute currentTorque : TorqueValue = 0 [Nm];
        attribute state : JointState = JointState::idle;
        port actuation : JointActuationPort;

        action moveTo {
            in target : JointCommand;
        }
    }

    part def Gripper {
        doc { A two-fingered gripper with open, close, and hold capabilities. }
        attribute id : String;
        attribute fingerCount : Integer = 2;
        attribute maxOpening : LengthValue = 0.1 [m];
        attribute maxForce : ForceValue = 30 [N];
        attribute currentOpening : LengthValue = 0 [m];
        attribute currentForce : ForceValue = 0 [N];
        attribute state : GripperState = GripperState::opened;
        attribute objectHeld : Boolean = false;

        action open {
            attribute currentOpening = maxOpening;
            attribute state = GripperState::opened;
            attribute objectHeld = false;
        }

        action close {
            in targetForce : ForceValue;
            attribute currentOpening = 0 [m];
            attribute state = GripperState::closed;
        }

        action hold {
            in gripForce : ForceValue;
            attribute currentForce = gripForce;
            attribute state = GripperState::holding;
            attribute objectHeld = true;
        }
    }

    part def Arm {
        doc { A 7-joint robotic arm with gripper for manipulation. }
        attribute id : String;
        attribute jointCount : Integer = 7;
        attribute reach : LengthValue = 0.8 [m];
        port armCmdIn : JointActuationPort;
        part joints : Joint[7];
        part gripper : Gripper;

        action reachTo {
            in target : Position3D;
        }

        action graspObject {
            in target : DetectedObject;
            action closeGripper {
                action close : Gripper::close;
            }
        }

        action releaseObject {
            action openGripper {
                action open : Gripper::open;
            }
        }
    }

    part def Battery {
        doc { Large-capacity rechargeable battery powering the entire robot. }
        attribute id : String;
        attribute capacity : CapacityValue = 400 [Wh];
        attribute nominalVoltage : VoltageValue = 24 [V];
        attribute maxCurrent : CurrentValue = 50 [A];
        attribute level : BatteryPercentValue = 100 [%];
        attribute charging : Boolean = false;
        port power : PowerPort;

        action discharge {
            in duration : TimeValue;
            in powerDemand : PowerValue;
        }

        action recharge { }

        action checkLevel {
            out currentLevel : BatteryPercentValue;
        }
    }

    part def WheeledBase {
        doc { Mobile base with wheels and integrated large-capacity battery. }
        attribute id : String;
        attribute maxSpeed : SpeedValue = 2 [m/s];
        attribute wheelRadius : LengthValue = 0.1 [m];
        attribute wheelCount : Integer = 4;
        attribute currentLocation : Position3D;
        attribute currentSpeed : SpeedValue = 0 [m/s];
        attribute currentHeading : AngleValue = 0 [rad];
        part battery : Battery;
        port motion : BaseMotionPort;
        port power : PowerPort;

        action move {
            in baseCmd : BaseCommand;
        }

        action stop {
            attribute currentSpeed = 0 [m/s];
        }

        action getLocation {
            out location : Position3D;
        }
    }

    part def VisionSystem {
        doc { High-performance vision system capturing 2048p at 60 fps with 3D object detection. }
        attribute id : String;
        attribute resolution : ResolutionValue = 2048 [px];
        attribute frameRate : FrequencyValue = 60 [Hz];
        attribute maxRange : LengthValue = 5 [m];
        attribute fieldOfView : AngleValue = 1.57 [rad];
        port perceptionOut : PerceptionPort;

        action scan : ScanEnvironment;

        action detectObjects3D {
            out objects : DetectedObject[0..*];
        }
    }

    part def MotionController {
        doc { High-frequency motion controller serving as the robot's brain for movement. }
        attribute id : String;
        attribute operatingFrequency : FrequencyValue = 1000 [Hz];
        attribute currentPath : PathPlan;
        attribute currentJointCommands : JointCommand[0..*];
        port perceptionIn : ~PerceptionPort;
        port baseCmdOut : ~BaseMotionPort;
        port leftArmCmd : ~JointActuationPort;
        port rightArmCmd : ~JointActuationPort;

        action planPath : PlanPath;
        action planArmMotion : PlanArmMotion;

        action computeSafePath {
            in obstacles : DetectedObject[0..*];
            in target : Position3D;
            out path : PathPlan;
        }
    }

    part def HumanoidRobot {
        doc { 1.7-meter, 80-kilogram humanoid robot with mobility and manipulation capabilities. }
        attribute id : String = "HR-001";
        attribute name : String = "Humanoid-01";
        attribute height : LengthValue = 1.7 [m];
        attribute mass : MassValue = 80 [kg];
        attribute mode : OperationalMode = OperationalMode::standby;
        attribute currentTaskStatus : TaskStatusKind = TaskStatusKind::idle;
        attribute currentCommandId : String;
        attribute currentTargetLocation : Position3D;
        attribute detectedObjects : DetectedObject[0..*];
        attribute currentPath : PathPlan;
        attribute armInUse : String;
        attribute taskActive : Boolean = false;
        attribute commandReceived : Boolean = false;
        attribute batteryLevel : BatteryPercentValue = 100 [%];

        port command : CommandPort;

        part base : WheeledBase;
        part vision : VisionSystem;
        part controller : MotionController;
        part leftArm : Arm;
        part rightArm : Arm;

        connect vision.perceptionOut to controller.perceptionIn;
        connect controller.baseCmdOut to base.motion;
        connect controller.leftArmCmd to leftArm.armCmdIn;
        connect controller.rightArmCmd to rightArm.armCmdIn;
        connect base.battery.power to base.power;

        state robotStates {
            state standby {
                entry {
                    attribute mode = OperationalMode::standby;
                }
            }

            state operational {
                entry {
                    attribute mode = OperationalMode::operational;
                }

                state idle;
                state scanning;
                state planning;
                state navigating;
                state grasping;
                state taskCompleted;
                state taskAborted;

                transition idle -> scanning;
                transition scanning -> planning;
                transition planning -> navigating;
                transition navigating -> grasping;
                transition grasping -> taskCompleted;
                transition idle -> taskAborted when !commandReceived;
                transition scanning -> taskAborted;
                transition planning -> taskAborted;
                transition navigating -> taskAborted;
                transition grasping -> taskAborted;
            }

            state maintenance {
                entry {
                    attribute mode = OperationalMode::maintenance;
                }
            }

            state emergency {
                entry {
                    attribute mode = OperationalMode::emergency;
                }
            }

            transition initial -> standby;
            transition standby -> operational when commandReceived && base.battery.level > 20 [%];
            transition operational -> standby when currentTaskStatus == TaskStatusKind::completed;
            transition operational -> standby when currentTaskStatus == TaskStatusKind::aborted;
            transition standby -> maintenance;
            transition maintenance -> standby;
            transition operational -> emergency when base.battery.level < 20 [%];
            transition emergency -> maintenance;
        }

        action executeTask {
            in taskCommand : TaskCommand;

            action receiveCommand {
                attribute currentCommandId = taskCommand.commandId;
                attribute currentTargetLocation = taskCommand.targetLocation;
                attribute commandReceived = true;
                attribute taskActive = true;
            }

            action scanArea {
                action scanAction : vision.scan;
                attribute currentTaskStatus = TaskStatusKind::scanning;
            }

            action planRoute {
                action planAction : controller.planPath;
                attribute currentTaskStatus = TaskStatusKind::planning;
            }

            action navigateToTarget {
                action navigateAction : controller.computeSafePath;
                action baseMove : base.move;
                attribute currentTaskStatus = TaskStatusKind::navigating;
            }

            action graspTarget {
                action graspAction : leftArm.graspObject;
                attribute currentTaskStatus = TaskStatusKind::grasping;
            }

            action reportCompletion {
                attribute currentTaskStatus = TaskStatusKind::completed;
                attribute taskActive = false;
            }

            action reportAbort {
                attribute currentTaskStatus = TaskStatusKind::aborted;
                attribute taskActive = false;
            }
        }

        action reportProgress {
            in status : TaskStatusKind;
            in message : String;
            out report : StatusReport;
        }

        action checkBatteryLevel {
            action check : base.battery.checkLevel;
            attribute batteryLevel = base.battery.level;
        }

        action checkSafetyBounds {
            in robotLocation : Position3D;
            out withinBounds : Boolean;
        }
    }

    part def SafetyPerimeter {
        doc { Monitors a defined work zone to ensure robot operates within bounds. }
        attribute id : String = "SP-001";
        attribute boundaryRadius : LengthValue = 10 [m];
        attribute boundaryCenter : Position3D;
        attribute violationDetected : Boolean = false;
        attribute monitored : Boolean = true;
        attribute lastRobotLocation : Position3D;

        action monitor {
            in robotLocation : Position3D;
            out withinBounds : Boolean;
        }

        action raiseAlarm {
            attribute violationDetected = true;
        }
    }

    part def ControlCenter {
        doc { Central control center that issues commands and receives status updates. }
        attribute id : String = "CC-001";
        attribute name : String = "CentralControlCenter";
        attribute activeCommands : TaskCommand[0..*];
        attribute lastKnownStatus : StatusReport;
        attribute monitored : Boolean = true;
        port robotCommand : ~CommandPort;

        action issueCommand {
            in command : TaskCommand;
        }

        action receiveStatus {
            in report : StatusReport;
            attribute lastKnownStatus = report;
        }

        action monitorRobotStatus {
            action receive : receiveStatus;
        }
    }

    part def WorkZone {
        doc { Defined work zone within which the robot operates. }
        attribute zoneId : String = "WZ-001";
        attribute zoneCenter : Position3D;
        attribute zoneRadius : LengthValue = 10 [m];
    }

    // ===== Top-Level System Assembly =====
    part def HumanoidRoboticSystem {
        doc { Complete humanoid robotic system for autonomous physical tasks within a defined work zone. }
        attribute systemId : String = "HRS-001";
        attribute systemName : String = "AutonomousHumanoidRobotSystem";

        part workZone : WorkZone;
        part controlCenter : ControlCenter;
        part perimeter : SafetyPerimeter;
        part robot : HumanoidRobot;

        connect controlCenter.robotCommand to robot.command;

        satisfy RobotDimensionSpec by robot;
        satisfy RobotMassSpec by robot;
        satisfy BatteryEnduranceSpec by robot.base.battery;
        satisfy VisionSpec by robot.vision;
        satisfy ArmDexteritySpec by robot.leftArm;
        satisfy ArmDexteritySpec by robot.rightArm;
        satisfy GripperSpec by robot.leftArm.gripper;
        satisfy GripperSpec by robot.rightArm.gripper;
        satisfy SafetyPerimeterSpec by perimeter;
        satisfy OperationalModeSpec by robot;
        satisfy EmergencyAvoidanceSpec by robot;
        satisfy ContinuousCommunicationSpec by robot;
        satisfy TaskExecutionSpec by robot;
    }
}
