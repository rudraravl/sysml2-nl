package AnthropomorphicRobotSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type TorqueUnit > Real {
        unit N*m;
    }

    value type ForceUnit > Real {
        unit N;
    }

    value type AngleUnit > Real {
        unit rad;
    }

    value type AngularVelocityUnit > Real {
        unit rad/s;
    }

    value type PowerUnit > Real {
        unit W;
    }

    value type VoltageUnit > Real {
        unit V;
    }

    value type CurrentUnit > Real {
        unit A;
    }

    value type EnergyUnit > Real {
        unit J;
    }

    value type MassUnit > Real {
        unit kg;
    }

    value type LengthUnit > Real {
        unit m;
    }

    value type TimeUnit > Real {
        unit s;
    }

    value type Percent > Real {
        unit %;
    }

    value type Pose {
        attribute positionX : LengthUnit;
        attribute positionY : LengthUnit;
        attribute positionZ : LengthUnit;
        attribute roll : AngleUnit;
        attribute pitch : AngleUnit;
        attribute yaw : AngleUnit;
    }

    value type Point3D {
        attribute x : LengthUnit;
        attribute y : LengthUnit;
        attribute z : LengthUnit;
    }

    value type BoundingBox3D {
        attribute minCorner : Point3D;
        attribute maxCorner : Point3D;
    }

    value type DetectedObject {
        attribute objectId : String;
        attribute center : Point3D;
        attribute bounds : BoundingBox3D;
        attribute confidence : Real;
    }

    value type DepthMap {
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute points : Point3D[0..*];
    }

    value type TrajectoryPoint {
        attribute timeFromStart : TimeUnit;
        attribute jointPositions : AngleUnit[0..*];
        attribute jointVelocities : AngularVelocityUnit[0..*];
    }

    value type Trajectory {
        attribute points : TrajectoryPoint[0..*];
        attribute isCollisionFree : Boolean;
    }

    value type GripCommand {
        attribute targetForce : ForceUnit;
        attribute fingerPositions : AngleUnit[5];
    }

    value type TaskDescriptor {
        attribute taskId : String;
        attribute description : String;
        attribute targetObject : String;
        attribute targetPose : Pose;
    }

    value type PowerState {
        attribute batteryLevel : Percent;
        attribute totalConsumption : PowerUnit;
        attribute supplyVoltage : VoltageUnit;
    }

    // ===== Item Definitions =====

    item def ElectricalPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def ImageData {
        attribute leftImageWidth : Integer;
        attribute leftImageHeight : Integer;
        attribute rightImageWidth : Integer;
        attribute rightImageHeight : Integer;
        attribute timestamp : TimeUnit;
    }

    item def SceneModel {
        attribute objects : DetectedObject[0..*];
        attribute depthMap : DepthMap;
        attribute timestamp : TimeUnit;
    }

    item def JointCommand {
        attribute jointId : Integer;
        attribute targetAngle : AngleUnit;
        attribute maxTorque : TorqueUnit;
    }

    item def ArmCommandSet {
        attribute jointCommands : JointCommand[0..*];
        attribute trajectory : Trajectory;
    }

    item def GripperCommandSet {
        attribute gripCommand : GripCommand;
    }

    item def TaskCommand {
        attribute task : TaskDescriptor;
    }

    item def StatusReport {
        attribute componentId : String;
        attribute operational : Boolean;
        attribute faultCode : Integer;
    }

    // ===== Port Definitions =====

    port def PowerPort {
        attribute ratedVoltage : VoltageUnit;
        out power : ElectricalPower;
    }

    port def ImagePort {
        out images : ImageData;
    }

    port def ScenePort {
        out scene : SceneModel;
    }

    port def TaskPort {
        in task : TaskCommand;
        out status : StatusReport;
    }

    port def ArmCommandPort {
        out armCommands : ArmCommandSet;
        in armFeedback : StatusReport;
    }

    port def GripperCommandPort {
        out gripperCommands : GripperCommandSet;
        in gripperFeedback : StatusReport;
    }

    port def PowerMonitorPort {
        out powerState : PowerState;
    }

    // ===== Actuator Definitions =====

    part def RotaryActuator {
        attribute maxTorque : TorqueUnit;
        attribute maxSpeed : AngularVelocityUnit;
        attribute powerDraw : PowerUnit;
        port powerIn : PowerPort;
        attribute currentAngle : AngleUnit;
        attribute commandedAngle : AngleUnit;
    }

    part def LinearActuator {
        attribute maxForce : ForceUnit;
        attribute stroke : LengthUnit;
        attribute powerDraw : PowerUnit;
        port powerIn : PowerPort;
    }

    // ===== Joint Definitions =====

    part def ShoulderJoint {
        attribute jointLabel : String;
        part pitchActuator : RotaryActuator {
            rewrites maxTorque = 45.0 [N*m];
            rewrites maxSpeed = 2.0 [rad/s];
            rewrites powerDraw = 25.0 [W];
        }
        part rollActuator : RotaryActuator {
            rewrites maxTorque = 40.0 [N*m];
            rewrites maxSpeed = 2.0 [rad/s];
            rewrites powerDraw = 22.0 [W];
        }
        part yawActuator : RotaryActuator {
            rewrites maxTorque = 35.0 [N*m];
            rewrites maxSpeed = 2.5 [rad/s];
            rewrites powerDraw = 20.0 [W];
        }
        port powerIn : PowerPort;
        port commandIn : ArmCommandPort;
    }

    part def ElbowJoint {
        attribute jointLabel : String;
        part flexionActuator : RotaryActuator {
            rewrites maxTorque = 30.0 [N*m];
            rewrites maxSpeed = 2.5 [rad/s];
            rewrites powerDraw = 18.0 [W];
        }
        port powerIn : PowerPort;
        port commandIn : ArmCommandPort;
    }

    part def WristJoint {
        attribute jointLabel : String;
        part pitchActuator : RotaryActuator {
            rewrites maxTorque = 12.0 [N*m];
            rewrites maxSpeed = 3.0 [rad/s];
            rewrites powerDraw = 10.0 [W];
        }
        part yawActuator : RotaryActuator {
            rewrites maxTorque = 10.0 [N*m];
            rewrites maxSpeed = 3.0 [rad/s];
            rewrites powerDraw = 8.0 [W];
        }
        port powerIn : PowerPort;
        port commandIn : ArmCommandPort;
    }

    // ===== Finger Definition =====

    part def Finger {
        attribute fingerId : Integer;
        attribute fingerName : String;
        part proximalJoint : RotaryActuator {
            rewrites maxTorque = 3.0 [N*m];
            rewrites maxSpeed = 4.0 [rad/s];
            rewrites powerDraw = 4.0 [W];
        }
        part distalJoint : RotaryActuator {
            rewrites maxTorque = 1.5 [N*m];
            rewrites maxSpeed = 5.0 [rad/s];
            rewrites powerDraw = 2.5 [W];
        }
        attribute currentForce : ForceUnit;
        port powerIn : PowerPort;
        port commandIn : GripperCommandPort;
    }

    // ===== Gripper Definition =====

    part def AnthropomorphicGripper {
        attribute gripperLabel : String;
        attribute maxGripForce : ForceUnit = 60.0 [N];
        part thumb : Finger {
            rewrites fingerId = 1;
            rewrites fingerName = "thumb";
        }
        part indexFinger : Finger {
            rewrites fingerId = 2;
            rewrites fingerName = "index";
        }
        part middleFinger : Finger {
            rewrites fingerId = 3;
            rewrites fingerName = "middle";
        }
        part ringFinger : Finger {
            rewrites fingerId = 4;
            rewrites fingerName = "ring";
        }
        part littleFinger : Finger {
            rewrites fingerId = 5;
            rewrites fingerName = "little";
        }
        port powerIn : PowerPort;
        port commandIn : GripperCommandPort;
        port feedbackOut : GripperCommandPort;
    }

    // ===== Arm Definition =====

    part def AnthropomorphicArm {
        attribute armLabel : String;
        attribute totalMass : MassUnit;
        part shoulder : ShoulderJoint;
        part elbow : ElbowJoint;
        part wrist : WristJoint;
        part gripper : AnthropomorphicGripper;
        port powerIn : PowerPort;
        port commandIn : ArmCommandPort;
        port gripperCommandIn : GripperCommandPort;
        port feedbackOut : ArmCommandPort;

        connection shoulderToElbow connect shoulder.commandIn to elbow.commandIn;
        connection elbowToWrist connect elbow.commandIn to wrist.commandIn;
        connection wristToGripper connect wrist.commandIn to gripper.commandIn;
    }

    // ===== Stereo Vision System =====

    part def StereoCameraPair {
        attribute baseline : LengthUnit = 0.12 [m];
        attribute resolutionWidth : Integer = 1280;
        attribute resolutionHeight : Integer = 720;
        attribute frameRate : Real = 30.0;
        part leftCamera {
            attribute sensorType : String = "CMOS";
        }
        part rightCamera {
            attribute sensorType : String = "CMOS";
        }
        port powerIn : PowerPort;
        port imageOut : ImagePort;
    }

    part def StereoVisionSystem {
        attribute systemLabel : String = "StereoVisionSystem";
        part cameraPair : StereoCameraPair;
        part depthProcessor {
            attribute processingFrequency : Real = 15.0;
            attribute maxRange : LengthUnit = 5.0 [m];
        }
        port powerIn : PowerPort;
        port imageOut : ImagePort;
        port sceneOut : ScenePort;

        action processImages {
            in images : ImageData;
            out scene : SceneModel;
        }

        connection powerToCamera connect powerIn to cameraPair.powerIn;
        connection cameraToProcessor connect cameraPair.imageOut to depthProcessor;
        connection processorToScene connect depthProcessor to sceneOut;
    }

    // ===== Motion Planner =====

    part def MotionPlanner {
        attribute plannerLabel : String = "CentralMotionPlanner";
        attribute planningHorizon : TimeUnit = 5.0 [s];
        attribute collisionCheckResolution : LengthUnit = 0.01 [m];
        port powerIn : PowerPort;
        port sceneIn : ScenePort;
        port taskIn : TaskPort;
        port leftArmCommandOut : ArmCommandPort;
        port rightArmCommandOut : ArmCommandPort;
        port leftGripperCommandOut : GripperCommandPort;
        port rightGripperCommandOut : GripperCommandPort;

        action planTrajectory {
            in scene : SceneModel;
            in task : TaskDescriptor;
            out leftTrajectory : Trajectory;
            out rightTrajectory : Trajectory;
            out leftGrip : GripCommand;
            out rightGrip : GripCommand;
        }

        action computeGripSequence {
            in targetObject : DetectedObject;
            out gripCommand : GripCommand;
        }
    }

    // ===== Power Management Unit =====

    part def BatteryPack {
        attribute nominalVoltage : VoltageUnit = 48.0 [V];
        attribute capacity : EnergyUnit = 200000.0 [J];
        attribute currentLevel : Percent = 100.0 [%];
        port powerOut : PowerPort;
    }

    part def PowerManagementUnit {
        attribute unitLabel : String = "PowerManagementUnit";
        attribute maxOutputPower : PowerUnit = 500.0 [W];
        attribute warningThreshold : Percent = 20.0 [%];
        attribute criticalThreshold : Percent = 10.0 [%];
        part battery : BatteryPack;
        port visionPowerOut : PowerPort;
        port plannerPowerOut : PowerPort;
        port leftArmPowerOut : PowerPort;
        port rightArmPowerOut : PowerPort;
        port monitorOut : PowerMonitorPort;

        action monitorPower {
            out powerState : PowerState;
        }

        action distributePower {
            in source : ElectricalPower;
            out toVision : ElectricalPower;
            out toPlanner : ElectricalPower;
            out toLeftArm : ElectricalPower;
            out toRightArm : ElectricalPower;
        }

        connection batteryToDistribute connect battery.powerOut to distributePower;
    }

    // ===== Robot System =====

    part def AnthropomorphicRobot {
        attribute robotId : String;
        attribute robotName : String;

        part powerManagement : PowerManagementUnit;
        part visionSystem : StereoVisionSystem;
        part motionPlanner : MotionPlanner;
        part leftArm : AnthropomorphicArm {
            rewrites armLabel = "LeftArm";
            rewrites totalMass = 6.5 [kg];
        }
        part rightArm : AnthropomorphicArm {
            rewrites armLabel = "RightArm";
            rewrites totalMass = 6.5 [kg];
        }

        port externalTaskPort : TaskPort;
        port powerMonitorExternal : PowerMonitorPort;

        // Power distribution connections
        connection pmuToVision connect powerManagement.visionPowerOut to visionSystem.powerIn;
        connection pmuToPlanner connect powerManagement.plannerPowerOut to motionPlanner.powerIn;
        connection pmuToLeftArm connect powerManagement.leftArmPowerOut to leftArm.powerIn;
        connection pmuToRightArm connect powerManagement.rightArmPowerOut to rightArm.powerIn;

        // Vision to planner
        connection visionToPlanner connect visionSystem.sceneOut to motionPlanner.sceneIn;

        // Planner to arms
        connection plannerToLeftArm connect motionPlanner.leftArmCommandOut to leftArm.commandIn;
        connection plannerToRightArm connect motionPlanner.rightArmCommandOut to rightArm.commandIn;
        connection plannerToLeftGripper connect motionPlanner.leftGripperCommandOut to leftArm.gripperCommandIn;
        connection plannerToRightGripper connect motionPlanner.rightGripperCommandOut to rightArm.gripperCommandIn;

        // External task interface
        connection externalTaskToPlanner connect externalTaskPort to motionPlanner.taskIn;

        // Power monitoring external
        connection monitorExternal connect powerManagement.monitorOut to powerMonitorExternal;

        // Robot operational state machine
        state def RobotOperationalStates;

        state machine RobotOperation : RobotOperationalStates {
            state idle {
                entry action {
                    /* Await high-level task command */
                }
            }
            state perceiving {
                entry action {
                    /* Activate stereo vision and build scene model */
                }
            }
            state planning {
                entry action {
                    /* Compute collision-free trajectory and grip sequence */
                }
            }
            state executing {
                entry action {
                    /* Execute coordinated reach and grasp actions */
                }
            }

            transition idle_to_perceiving
                source idle
                target perceiving
                when externalTaskPort.task.task.taskId != null;

            transition perceiving_to_planning
                source perceiving
                target planning
                when visionSystem.sceneOut.scene.objects->size() > 0;

            transition planning_to_executing
                source planning
                target executing
                when motionPlanner.leftArmCommandOut.armCommands.trajectory.isCollisionFree == true;

            transition executing_to_idle
                source executing
                target idle
                when leftArm.feedbackOut.armFeedback.operational == true
                    and rightArm.feedbackOut.armFeedback.operational == true;
        }
    }

    // ===== Requirements =====

    requirement def VisionSystemRequirement {
        subject visionSystem : StereoVisionSystem;
        requirement {
            /* The stereo vision system shall capture and process visual information
               to create a 3D map of its surroundings. */
        }
        attribute requiredMaxRange : LengthUnit = 5.0 [m];
        attribute requiredFrameRate : Real = 30.0;
    }

    requirement def ArmManipulatorRequirement {
        subject arm : AnthropomorphicArm;
        requirement {
            /* Each arm shall include a three-axis shoulder joint, a single-axis
               elbow joint, and a two-axis wrist joint. */
        }
        attribute shoulderAxesCount : Integer = 3;
        attribute elbowAxesCount : Integer = 1;
        attribute wristAxesCount : Integer = 2;
    }

    requirement def GripperRequirement {
        subject gripper : AnthropomorphicGripper;
        requirement {
            /* The gripper shall have five fingers and shall support adjustable
               grip force up to a defined maximum. */
        }
        attribute fingerCount : Integer = 5;
        attribute maxGripForce : ForceUnit = 60.0 [N];
    }

    requirement def MotionPlannerRequirement {
        subject planner : MotionPlanner;
        requirement {
            /* The motion planner shall use scene data from the vision system to
               calculate a smooth, collision-free trajectory and determine the
               grip sequence and force. */
        }
        attribute requiredCollisionCheckResolution : LengthUnit = 0.01 [m];
    }

    requirement def PowerManagementRequirement {
        subject pmu : PowerManagementUnit;
        requirement {
            /* The power management unit shall distribute electrical power to the
               vision system, motion planner, and all arm and gripper actuators,
               and shall monitor power consumption and battery levels. */
        }
        attribute warningThreshold : Percent = 20.0 [%];
        attribute criticalThreshold : Percent = 10.0 [%];
    }

    requirement def OperationalSequenceRequirement {
        subject robot : AnthropomorphicRobot;
        requirement {
            /* The robot shall transition through idle, perceiving, planning, and
               executing states in sequence upon receiving a task. */
        }
    }

    requirement visionReq : VisionSystemRequirement {
        subject :>> visionSystem = AnthropomorphicRobot.visionSystem;
    }

    requirement leftArmReq : ArmManipulatorRequirement {
        subject :>> arm = AnthropomorphicRobot.leftArm;
    }

    requirement rightArmReq : ArmManipulatorRequirement {
        subject :>> arm = AnthropomorphicRobot.rightArm;
    }

    requirement leftGripperReq : GripperRequirement {
        subject :>> gripper = AnthropomorphicRobot.leftArm.gripper;
    }

    requirement rightGripperReq : GripperRequirement {
        subject :>> gripper = AnthropomorphicRobot.rightArm.gripper;
    }

    requirement plannerReq : MotionPlannerRequirement {
        subject :>> planner = AnthropomorphicRobot.motionPlanner;
    }

    requirement pmuReq : PowerManagementRequirement {
        subject :>> pmu = AnthropomorphicRobot.powerManagement;
    }

    requirement opSeqReq : OperationalSequenceRequirement {
        subject :>> robot = AnthropomorphicRobot;
    }

}
