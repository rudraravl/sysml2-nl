package AutonomousMobileManipulator {

import ScalarValues::*;

// ===== VALUE TYPES WITH UNITS =====

value def Distance :> Real {
    doc "Distance in meters (m)"
}
value def MassValue :> Real {
    doc "Mass in kilograms (kg)"
}
value def ForceValue :> Real {
    doc "Force in Newtons (N)"
}
value def TorqueValue :> Real {
    doc "Torque in Newton-meters (N·m)"
}
value def AngleValue :> Real {
    doc "Angle in radians (rad)"
}
value def AngularVel :> Real {
    doc "Angular velocity in radians per second (rad/s)"
}
value def LinearVel :> Real {
    doc "Linear velocity in meters per second (m/s)"
}
value def TimeValue :> Real {
    doc "Time in seconds (s)"
}
value def DurationVal :> TimeValue {
    doc "Duration in seconds (s)"
}
value def CurrentVal :> Real {
    doc "Electric current in Amperes (A)"
}
value def VoltageVal :> Real {
    doc "Voltage in Volts (V)"
}
value def PowerVal :> Real {
    doc "Power in Watts (W)"
}
value def FreqVal :> Real {
    doc "Frequency in Hertz (Hz)"
}
value def PercentVal :> Real {
    doc "Percentage from 0 to 100"
}

// ===== ITEM DEFINITIONS =====

item def Pose3D {
    attribute x : Distance;
    attribute y : Distance;
    attribute z : Distance;
    attribute roll : AngleValue;
    attribute pitch : AngleValue;
    attribute yaw : AngleValue;
}

item def Point3D {
    attribute x : Distance;
    attribute y : Distance;
    attribute z : Distance;
}

item def PointCloud {
    attribute points : Point3D[0..*];
    attribute timestamp : TimeValue;
    attribute numPoints : Integer;
}

item def RGBImage {
    attribute width : Integer;
    attribute height : Integer;
    attribute timestamp : TimeValue;
}

item def DepthImage {
    attribute width : Integer;
    attribute height : Integer;
    attribute maxRange : Distance;
    attribute timestamp : TimeValue;
}

item def OccupancyMap {
    attribute resolution : Distance;
    attribute width : Integer;
    attribute height : Integer;
    attribute origin : Pose3D;
    attribute timestamp : TimeValue;
}

item def DetectedObject {
    attribute objectClass : String;
    attribute position : Pose3D;
    attribute boundingBoxSize : Point3D;
    attribute confidence : PercentVal;
    attribute estimatedWeight : MassValue;
}

item def Path2D {
    attribute waypoints : Pose3D[0..*];
    attribute totalLength : Distance;
    attribute estimatedDuration : DurationVal;
    attribute clearance : Distance;
}

item def JointTrajectory {
    attribute jointPositions : AngleValue[7];
    attribute jointVelocities : AngularVel[7];
    attribute duration : DurationVal;
    attribute maxJointTorque : TorqueValue;
}

item def NavCommand {
    attribute linearVelocity : LinearVel;
    attribute angularVelocity : AngularVel;
    attribute targetHeading : AngleValue;
}

item def GripperCommand {
    attribute targetForce : ForceValue;
    attribute targetPosition : Distance;
    attribute isClosing : Boolean;
    attribute holdDuration : DurationVal;
}

item def MissionSpec {
    attribute missionId : String;
    attribute targetObjectClass : String;
    attribute dropOffPose : Pose3D;
    attribute homePose : Pose3D;
    attribute maxDuration : DurationVal;
}

item def StatusReport {
    attribute stateName : String;
    attribute currentPose : Pose3D;
    attribute missionProgress : PercentVal;
    attribute timestamp : TimeValue;
    attribute errorCode : Integer;
}

// ===== PORT DEFINITIONS =====

port def RotationFlow {
    out angularPosition : AngleValue;
    out angularVelocity : AngularVel;
}

port def LidarFlow {
    out pointCloud : PointCloud;
    out occupancyMap : OccupancyMap;
}

port def CameraFlow {
    out rgbImage : RGBImage;
    out depthImage : DepthImage;
}

port def EncoderFlow {
    out leftEncoderTicks : Integer;
    out rightEncoderTicks : Integer;
    out estimatedPose : Pose3D;
}

port def PerceptionFlow {
    out detectedObjects : DetectedObject[0..*];
    out updatedMap : OccupancyMap;
    out robotPose : Pose3D;
}

port def NavCmdFlow {
    out navCommand : NavCommand;
}

port def ArmCmdFlow {
    out armTrajectory : JointTrajectory;
}

port def GripperCmdFlow {
    out gripperCommand : GripperCommand;
}

port def PowerSupply {
    out voltage : VoltageVal;
    out maxCurrent : CurrentVal;
}

port def MissionFlow {
    out mission : MissionSpec;
    in status : StatusReport;
}

// ===== SUB-COMPONENT PART DEFINITIONS =====

part def Wheel {
    attribute radius : Distance;
    attribute maxAngularSpeed : AngularVel;
    attribute currentAngularSpeed : AngularVel;
    attribute currentTorque : TorqueValue;

    port rotationOut : RotationFlow;
    port powerIn : ~PowerSupply;
}

part def WheelEncoder {
    attribute ticksPerRevolution : Integer;
    attribute wheelRadius : Distance;
    attribute lastTickReading : Integer;

    port rotationIn : ~RotationFlow;
    port encoderOut : EncoderFlow;

    action def MeasureRotation {
        in angularPosition : AngleValue;
        in angularVelocity : AngularVel;
        out tickCount : Integer;
    }

    perform MeasureRotation;
}

part def Joint {
    attribute jointId : Integer;
    attribute jointName : String;
    attribute currentAngle : AngleValue;
    attribute minAngle : AngleValue;
    attribute maxAngle : AngleValue;
    attribute maxTorque : TorqueValue;
    attribute currentTorque : TorqueValue;
    attribute maxVelocity : AngularVel;

    port powerIn : ~PowerSupply;
}

// ===== SENSOR PART DEFINITIONS =====

part def LidarSensor {
    attribute scanRange : Distance;
    attribute angularResolution : AngleValue;
    attribute scanRate : FreqVal;
    attribute numBeams : Integer;
    attribute mountHeight : Distance;

    port lidarOut : LidarFlow;

    action def ScanEnvironment {
        out cloud : PointCloud;
        out map : OccupancyMap;
    }

    action def DetectObstacles {
        in cloud : PointCloud;
        in map : OccupancyMap;
        out clearPath : Boolean;
        out clearance : Distance;
    }

    perform ScanEnvironment;
    perform DetectObstacles;
}

part def RGBDCamera {
    attribute colorResolution : String;
    attribute depthRange : Distance;
    attribute fieldOfView : AngleValue;
    attribute frameRate : FreqVal;
    attribute mountHeight : Distance;

    port cameraOut : CameraFlow;

    action def Capture {
        out rgb : RGBImage;
        out depth : DepthImage;
    }

    action def ComputeDepth3D {
        in rgb : RGBImage;
        in depth : DepthImage;
        out objectPositions : Point3D[0..*];
    }

    perform Capture;
    perform ComputeDepth3D;
}

// ===== ACTUATOR PART DEFINITIONS =====

part def MobileBase {
    attribute wheelbase : Distance;
    attribute maxLinearSpeed : LinearVel;
    attribute maxAngularSpeed : AngularVel;
    attribute clearanceHeight : Distance;
    attribute totalMass : MassValue;

    part leftWheel : Wheel;
    part rightWheel : Wheel;
    part leftEncoder : WheelEncoder;
    part rightEncoder : WheelEncoder;

    port encoderData : EncoderFlow;
    port navCmd : ~NavCmdFlow;

    connection from leftWheel.rotationOut to leftEncoder.rotationIn;
    connection from rightWheel.rotationOut to rightEncoder.rotationIn;

    action def Odometry {
        in leftTicks : Integer;
        in rightTicks : Integer;
        in prevPose : Pose3D;
        out newPose : Pose3D;
    }

    action def DriveDifferential {
        in cmd : NavCommand;
        out leftWheelSpeed : AngularVel;
        out rightWheelSpeed : AngularVel;
    }

    perform Odometry;
    perform DriveDifferential;
}

part def ManipulatorArm {
    attribute dof : Integer;
    attribute maxReach : Distance;
    attribute maxPayload : MassValue;
    attribute baseMountHeight : Distance;

    part joints : Joint[7];

    port armCmd : ~ArmCmdFlow;
    port armFeedback : ArmCmdFlow;

    action def InverseKinematics {
        in targetPose : Pose3D;
        in currentAngles : AngleValue[7];
        out jointAngles : AngleValue[7];
        out solutionFound : Boolean;
    }

    action def ExecuteTrajectory {
        in trajectory : JointTrajectory;
        out executionComplete : Boolean;
        out finalPose : Pose3D;
    }

    action def ForwardKinematics {
        in jointAngles : AngleValue[7];
        out endEffectorPose : Pose3D;
    }

    perform InverseKinematics;
    perform ExecuteTrajectory;
    perform ForwardKinematics;
}

part def ParallelGripper {
    attribute maxOpening : Distance;
    attribute maxClosingForce : ForceValue;
    attribute currentForce : ForceValue;
    attribute fingerStroke : Distance;
    attribute isGrasping : Boolean;
    attribute currentOpening : Distance;

    port gripperCmd : ~GripperCmdFlow;

    action def Grasp {
        in targetForce : ForceValue;
        in targetPosition : Distance;
        out graspSuccess : Boolean;
        out achievedForce : ForceValue;
    }

    action def Release {
        out released : Boolean;
    }

    action def MonitorGrasp {
        in appliedForce : ForceValue;
        out slipDetected : Boolean;
        out currentGripForce : ForceValue;
    }

    perform Grasp;
    perform Release;
    perform MonitorGrasp;
}

// ===== CONTROL SYSTEM DEFINITIONS =====

part def PerceptionProcessor {
    attribute processingFrequency : FreqVal;
    attribute detectionConfidenceThreshold : PercentVal;

    port lidarIn : ~LidarFlow;
    port cameraIn : ~CameraFlow;
    port encoderIn : ~EncoderFlow;
    port perceptionOut : PerceptionFlow;

    action def FuseSensorData {
        in lidarCloud : PointCloud;
        in rgb : RGBImage;
        in depth : DepthImage;
        in encoderPose : Pose3D;
        out detectedObjects : DetectedObject[0..*];
        out fusedMap : OccupancyMap;
        out fusedPose : Pose3D;
    }

    action def DetectObjects {
        in rgb : RGBImage;
        in depth : DepthImage;
        in cameraPose : Pose3D;
        out detected : DetectedObject[0..*];
    }

    action def RunSLAM {
        in lidarCloud : PointCloud;
        in encoderPose : Pose3D;
        out updatedMap : OccupancyMap;
        out correctedPose : Pose3D;
    }

    action def ClassifyTarget {
        in detected : DetectedObject[0..*];
        in targetClass : String;
        out selectedTarget : DetectedObject;
    }

    perform FuseSensorData;
    perform DetectObjects;
    perform RunSLAM;
    perform ClassifyTarget;
}

part def NavigationPlanner {
    attribute safeMargin : Distance;
    attribute replanningRate : FreqVal;
    attribute maxPlanningTime : DurationVal;

    port perceptionIn : ~PerceptionFlow;
    port navOut : NavCmdFlow;

    action def PlanGlobalPath {
        in currentPose : Pose3D;
        in targetPose : Pose3D;
        in occupancyMap : OccupancyMap;
        out path : Path2D;
    }

    action def PlanLocalPath {
        in currentPose : Pose3D;
        in globalPath : Path2D;
        in occupancyMap : OccupancyMap;
        out navCmd : NavCommand;
        out localPath : Path2D;
    }

    action def CheckClearance {
        in path : Path2D;
        in occupancyMap : OccupancyMap;
        out isClear : Boolean;
        out clearanceDistance : Distance;
    }

    action def ReplanPath {
        in currentPose : Pose3D;
        in occupancyMap : OccupancyMap;
        in targetPose : Pose3D;
        out newPath : Path2D;
    }

    perform PlanGlobalPath;
    perform PlanLocalPath;
    perform CheckClearance;
    perform ReplanPath;
}

part def MotionPlanner {
    attribute planningAlgorithm : String;
    attribute maxPlanningTime : DurationVal;
    attribute graspApproachDistance : Distance;

    port perceptionIn : ~PerceptionFlow;
    port armOut : ArmCmdFlow;
    port gripperOut : GripperCmdFlow;

    action def PlanArmMotion {
        in targetPose : Pose3D;
        in currentJointAngles : AngleValue[7];
        out trajectory : JointTrajectory;
    }

    action def PlanGrasp {
        in objectPose : Pose3D;
        in objectWeight : MassValue;
        in objectSize : Point3D;
        out gripperCmd : GripperCommand;
        out approachTrajectory : JointTrajectory;
    }

    action def PlanPlace {
        in dropOffPose : Pose3D;
        in currentJointAngles : AngleValue[7];
        out placeTrajectory : JointTrajectory;
        out releaseCmd : GripperCommand;
    }

    action def PlanRetract {
        in currentPose : Pose3D;
        out retractTrajectory : JointTrajectory;
    }

    perform PlanArmMotion;
    perform PlanGrasp;
    perform PlanPlace;
    perform PlanRetract;
}

// ===== CENTRAL CONTROLLER =====

part def CentralController {
    attribute cycleTime : DurationVal;
    attribute maxMissionDuration : DurationVal;
    attribute controlFrequency : FreqVal;

    part perception : PerceptionProcessor;
    part navPlanner : NavigationPlanner;
    part motionPlanner : MotionPlanner;

    port lidarDataIn : ~LidarFlow;
    port cameraDataIn : ~CameraFlow;
    port encoderDataIn : ~EncoderFlow;
    port navCmdOut : NavCmdFlow;
    port armCmdOut : ArmCmdFlow;
    port gripperCmdOut : GripperCmdFlow;

    connection from lidarDataIn to perception.lidarIn;
    connection from cameraDataIn to perception.cameraIn;
    connection from encoderDataIn to perception.encoderIn;
    connection from perception.perceptionOut to navPlanner.perceptionIn;
    connection from perception.perceptionOut to motionPlanner.perceptionIn;
    connection from navPlanner.navOut to navCmdOut;
    connection from motionPlanner.armOut to armCmdOut;
    connection from motionPlanner.gripperOut to gripperCmdOut;

    state def MissionStateMachine {
        event startMission;
        event targetFound;
        event targetNotFound;
        event reachedTarget;
        event armInPosition;
        event graspConfirmed;
        event graspFailed;
        event objectLifted;
        event reachedDropoff;
        event objectPlaced;
        event reachedHome;
        event reset;
        event emergencyStop;
        event navigationFailed;

        state Idle {
            entry action ReportReady;
            do action AwaitCommand;
        }

        state Scanning {
            entry action ActivateSensors;
            do action ScanForObjects;
            exit action ReportDetectedObjects;
        }

        state Navigating {
            entry action PlanBasePath;
            do action ExecuteNavigation;
            exit action StopBase;
        }

        state Approaching {
            entry action PlanArmApproach;
            do action MoveArmToGrasp;
            exit action ReportArmReady;
        }

        state Grasping {
            entry action CloseGripper;
            do action MonitorGraspForce;
            exit action ReportGraspStatus;
        }

        state Lifting {
            entry action LiftArm;
            do action VerifyLift;
            exit action ReportLifted;
        }

        state Transporting {
            entry action PlanDropoffPath;
            do action NavigateToDropoff;
            exit action StopBase;
        }

        state Placing {
            entry action LowerArm;
            do action ReleaseGripper;
            exit action ReportPlaced;
        }

        state Returning {
            entry action PlanHomePath;
            do action NavigateToHome;
            exit action StopBase;
        }

        state Completed {
            entry action ReportComplete;
            do action AwaitNextCommand;
        }

        state Aborted {
            entry action ReportError;
            do action SafeShutdown;
        }

        transition t_init from Idle to Scanning when startMission;
        transition t_found from Scanning to Navigating when targetFound;
        transition t_notfound from Scanning to Aborted when targetNotFound;
        transition t_arrived from Navigating to Approaching when reachedTarget;
        transition t_navfail from Navigating to Aborted when navigationFailed;
        transition t_approach from Approaching to Grasping when armInPosition;
        transition t_grasped from Grasping to Lifting when graspConfirmed;
        transition t_graspfail from Grasping to Aborted when graspFailed;
        transition t_lifted from Lifting to Transporting when objectLifted;
        transition t_dropoff from Transporting to Placing when reachedDropoff;
        transition t_placed from Placing to Returning when objectPlaced;
        transition t_home from Returning to Completed when reachedHome;
        transition t_reset from Completed to Idle when reset;
        transition t_abort from * to Aborted when emergencyStop;
    }

    perform MissionStateMachine;

    action def ExecutePickAndPlace {
        in mission : MissionSpec;
        out status : StatusReport;

        action ScanArea {
            out detectedObjects : DetectedObject[0..*];
            out scanComplete : Boolean;
        }
        then action SelectTarget {
            in detectedObjects : DetectedObject[0..*];
            in targetClass : String;
            out target : DetectedObject;
        }
        then action NavigateToTarget {
            in target : DetectedObject;
            out arrived : Boolean;
        }
        then action PlanApproach {
            in target : DetectedObject;
            out approachTrajectory : JointTrajectory;
            out gripperSetup : GripperCommand;
        }
        then action ExecuteApproach {
            in approachTrajectory : JointTrajectory;
            out armAtObject : Boolean;
        }
        then action GraspObject {
            in gripperSetup : GripperCommand;
            out graspSuccess : Boolean;
        }
        then action LiftObject {
            in graspSuccess : Boolean;
            out lifted : Boolean;
        }
        then action NavigateToDropoff {
            in dropOffPose : Pose3D;
            out arrived : Boolean;
        }
        then action PlaceObject {
            in dropOffPose : Pose3D;
            out placed : Boolean;
        }
        then action ReturnHome {
            in homePose : Pose3D;
            out returned : Boolean;
        }

        ScanArea.detectedObjects >> SelectTarget.detectedObjects;
        ScanArea.detectedObjects >> NavigateToTarget.target;
        SelectTarget.target >> PlanApproach.target;
        PlanApproach.approachTrajectory >> ExecuteApproach.approachTrajectory;
        PlanApproach.gripperSetup >> GraspObject.gripperSetup;
        GraspObject.graspSuccess >> LiftObject.graspSuccess;
    }

    perform ExecutePickAndPlace;
}

// ===== TOP-LEVEL ROBOT SYSTEM =====

part def MobileManipulatorRobot {
    attribute robotName : String;
    attribute maxPayload : MassValue;
    attribute maxSpeed : LinearVel;
    attribute operatingTime : DurationVal;
    attribute totalMass : MassValue;

    part base : MobileBase;
    part arm : ManipulatorArm;
    part gripper : ParallelGripper;
    part lidar : LidarSensor;
    part camera : RGBDCamera;
    part controller : CentralController;

    port missionPort : ~MissionFlow;

    connection sys_lidar from lidar.lidarOut to controller.lidarDataIn;
    connection sys_camera from camera.cameraOut to controller.cameraDataIn;
    connection sys_encoder from base.encoderData to controller.encoderDataIn;
    connection sys_nav from controller.navCmdOut to base.navCmd;
    connection sys_arm from controller.armCmdOut to arm.armCmd;
    connection sys_gripper from controller.gripperCmdOut to gripper.gripperCmd;

    action def FullPickAndPlace {
        in mission : MissionSpec;
        out status : StatusReport;

        action Phase1_Scan {
            out objects : DetectedObject[0..*];
        }
        then action Phase2_Navigate {
            in target : DetectedObject;
            out arrived : Boolean;
        }
        then action Phase3_Grasp {
            in target : DetectedObject;
            out grasped : Boolean;
        }
        then action Phase4_Lift {
            in grasped : Boolean;
            out lifted : Boolean;
        }
        then action Phase5_Transport {
            in dropOff : Pose3D;
            out delivered : Boolean;
        }
        then action Phase6_Place {
            in dropOff : Pose3D;
            out placed : Boolean;
        }
        then action Phase7_Return {
            in home : Pose3D;
            out returned : Boolean;
        }

        Phase1_Scan.objects >> Phase2_Navigate.target;
        Phase2_Navigate.arrived >> Phase3_Grasp.target;
        Phase3_Grasp.grasped >> Phase4_Lift.grasped;
        Phase4_Lift.lifted >> Phase5_Transport.dropOff;
        Phase5_Transport.delivered >> Phase6_Place.dropOff;
        Phase6_Place.placed >> Phase7_Return.home;
    }

    perform FullPickAndPlace;
}

// ===== REQUIREMENTS =====

requirement def PayloadCapacity {
    doc "The manipulator arm must lift objects weighing up to 5 kilograms"
    subject arm : ManipulatorArm;
    requirement maxPayloadLimit {
        doc "Maximum payload shall be at least 5 kg"
        assert { arm.maxPayload >= 5.0 }
    }
}

requirement def NavigationAccuracy {
    doc "Robot must navigate to within 5 cm of the target location"
    subject base : MobileBase;
    attribute requiredAccuracy : Distance = 0.05;
    requirement encoderResolution {
        doc "Wheel encoder resolution shall support 5 cm positioning accuracy"
        assert { base.leftEncoder.ticksPerRevolution >= 512 }
    }
}

requirement def ObstacleAvoidanceMargin {
    doc "Robot must maintain a minimum clearance of 30 cm from all obstacles"
    subject navPlanner : NavigationPlanner;
    attribute safeClearance : Distance = 0.30;
    requirement clearanceThreshold {
        doc "Navigation planner safe margin shall be at least 30 cm"
        assert { navPlanner.safeMargin >= 0.30 }
    }
}

requirement def CycleTimeLimit {
    doc "A full pick-and-place cycle must complete in under 60 seconds"
    subject controller : CentralController;
    attribute maxCycleTime : DurationVal = 60.0;
    requirement cycleDuration {
        doc "Controller maximum mission duration shall not exceed 60 seconds"
        assert { controller.maxMissionDuration <= 60.0 }
    }
}

requirement def LidarRange {
    doc "The LiDAR sensor must scan the area to detect obstacles up to 20 m"
    subject lidar : LidarSensor;
    requirement minScanRange {
        doc "LiDAR scan range shall be at least 20 m"
        assert { lidar.scanRange >= 20.0 }
    }
}

requirement def GripperForceControl {
    doc "The parallel gripper must grasp objects with controlled force up to 40 N"
    subject gripper : ParallelGripper;
    requirement maxGraspForce {
        doc "Gripper maximum closing force shall not exceed 40 N"
        assert { gripper.maxClosingForce <= 40.0 }
    }
}

requirement def ArmDOF {
    doc "The manipulator arm must have 7 joints for high flexibility"
    subject arm : ManipulatorArm;
    requirement dofCount {
        doc "Number of degrees of freedom shall be 7"
        assert { arm.dof == 7 }
    }
}

requirement def TwoWheelMobility {
    doc "The mobile base shall use a two-wheeled differential drive"
    subject base : MobileBase;
    requirement differentialDrive {
        doc "Base shall have two wheels with positive wheelbase"
        assert { base.wheelbase > 0.0 }
    }
}

// ===== REQUIREMENT USAGES =====

requirement payloadReq : PayloadCapacity;
requirement navAccReq : NavigationAccuracy;
requirement obstacleMarginReq : ObstacleAvoidanceMargin;
requirement cycleTimeReq : CycleTimeLimit;
requirement lidarRangeReq : LidarRange;
requirement gripperForceReq : GripperForceControl;
requirement armDofReq : ArmDOF;
requirement twoWheelReq : TwoWheelMobility;

// ===== INSTANCE CONFIGURATION =====

part mobileManipulator : MobileManipulatorRobot {
    attribute robotName = "AutoManip-01";
    attribute maxPayload = 5.0;
    attribute maxSpeed = 1.5;
    attribute operatingTime = 28800.0;
    attribute totalMass = 45.0;

    part base : MobileBase {
        attribute wheelbase = 0.50;
        attribute maxLinearSpeed = 1.5;
        attribute maxAngularSpeed = 2.0;
        attribute clearanceHeight = 0.15;
        attribute totalMass = 12.0;

        part leftWheel : Wheel {
            attribute radius = 0.10;
            attribute maxAngularSpeed = 10.0;
        }
        part rightWheel : Wheel {
            attribute radius = 0.10;
            attribute maxAngularSpeed = 10.0;
        }
        part leftEncoder : WheelEncoder {
            attribute ticksPerRevolution = 1024;
            attribute wheelRadius = 0.10;
        }
        part rightEncoder : WheelEncoder {
            attribute ticksPerRevolution = 1024;
            attribute wheelRadius = 0.10;
        }
    }

    part arm : ManipulatorArm {
        attribute dof = 7;
        attribute maxReach = 0.90;
        attribute maxPayload = 5.0;
        attribute baseMountHeight = 0.30;

        part joints : Joint[7];
    }

    part gripper : ParallelGripper {
        attribute maxOpening = 0.08;
        attribute maxClosingForce = 40.0;
        attribute fingerStroke = 0.04;
        attribute isGrasping = false;
        attribute currentOpening = 0.04;
    }

    part lidar : LidarSensor {
        attribute scanRange = 20.0;
        attribute angularResolution = 0.01745;
        attribute scanRate = 10.0;
        attribute numBeams = 360;
        attribute mountHeight = 0.25;
    }

    part camera : RGBDCamera {
        attribute colorResolution = "1920x1080";
        attribute depthRange = 5.0;
        attribute fieldOfView = 1.047;
        attribute frameRate = 30.0;
        attribute mountHeight = 0.40;
    }

    part controller : CentralController {
        attribute cycleTime = 0.01;
        attribute maxMissionDuration = 60.0;
        attribute controlFrequency = 100.0;

        part perception : PerceptionProcessor {
            attribute processingFrequency = 30.0;
            attribute detectionConfidenceThreshold = 75.0;
        }
        part navPlanner : NavigationPlanner {
            attribute safeMargin = 0.30;
            attribute replanningRate = 10.0;
            attribute maxPlanningTime = 2.0;
        }
        part motionPlanner : MotionPlanner {
            attribute planningAlgorithm = "RRT-Connect";
            attribute maxPlanningTime = 5.0;
            attribute graspApproachDistance = 0.05;
        }
    }

    satisfy payloadReq by arm;
    satisfy navAccReq by base;
    satisfy obstacleMarginReq by controller.navPlanner;
    satisfy cycleTimeReq by controller;
    satisfy lidarRangeReq by lidar;
    satisfy gripperForceReq by gripper;
    satisfy armDofReq by arm;
    satisfy twoWheelReq by base;
}

}
