package AutonomousMobileRobot {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def AngularVelocityValue :> Real;

    attribute def Pose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute theta : AngleValue;
    }

    attribute def RGBDImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute depthMaxRange : LengthValue;
    }

    attribute def PointCloud {
        attribute pointCount : Integer;
        attribute maxRange : LengthValue;
    }

    attribute def ObjectDetection {
        attribute classification : String;
        attribute position : Pose;
        attribute confidence : Real;
    }

    attribute def WorldModel {
        attribute robotPose : Pose;
        attribute detectedObjects : ObjectDetection[*];
    }

    attribute def Goal {
        attribute description : String;
        attribute targetPose : Pose;
        attribute targetObjectId : String;
    }

    attribute def MotionCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : AngularVelocityValue;
    }

    attribute def ManipulatorCommand {
        attribute jointAngles : AngleValue[6];
        attribute gripperOpen : Boolean;
    }

    port def ImageOutPort {
        out attribute image : RGBDImage;
    }

    port def ImageInPort {
        in attribute image : RGBDImage;
    }

    port def CloudOutPort {
        out attribute cloud : PointCloud;
    }

    port def CloudInPort {
        in attribute cloud : PointCloud;
    }

    port def WorldModelOutPort {
        out attribute world : WorldModel;
    }

    port def WorldModelInPort {
        in attribute world : WorldModel;
    }

    port def GoalInPort {
        in attribute goal : Goal;
    }

    port def MotionOutPort {
        out attribute cmd : MotionCommand;
    }

    port def MotionInPort {
        in attribute cmd : MotionCommand;
    }

    port def ManipOutPort {
        out attribute cmd : ManipulatorCommand;
    }

    port def ManipInPort {
        in attribute cmd : ManipulatorCommand;
    }

    part def RGBDCamera {
        port imageOut : ImageOutPort;
        attribute frameRate : FrequencyValue;
        attribute resolution : String;
    }

    part def LidarSensor {
        port cloudOut : CloudOutPort;
        attribute scanRate : FrequencyValue;
        attribute maxRange : LengthValue;
        attribute angularResolution : AngleValue;
    }

    part def MobileBase {
        port motionIn : MotionInPort;
        attribute maxLinearSpeed : SpeedValue;
        attribute maxAngularSpeed : AngularVelocityValue;
        attribute wheelbase : LengthValue;
    }

    part def RoboticArm {
        port manipIn : ManipInPort;
        attribute jointCount : Integer = 6;
        attribute payloadCapacity : MassValue;
        attribute reach : LengthValue;
    }

    part def PerceptionSubsystem {
        port cameraIn : ImageInPort;
        port lidarIn : CloudInPort;
        port worldOut : WorldModelOutPort;

        perform action fuseSensorData {
            in attribute image : RGBDImage;
            in attribute cloud : PointCloud;
            out attribute world : WorldModel;
            first start;
            then action detectObjects;
            then action localizeRobot;
            then action buildWorldModel;
            then done;
        }
    }

    part def PlanningSubsystem {
        port worldIn : WorldModelInPort;
        port goalIn : GoalInPort;
        port motionOut : MotionOutPort;
        port manipOut : ManipOutPort;

        perform action planMission {
            in attribute world : WorldModel;
            in attribute goal : Goal;
            out attribute motionCmd : MotionCommand;
            out attribute manipCmd : ManipulatorCommand;
            first start;
            then action generatePath;
            then action generateManipulationSequence;
            then done;
        }
    }

    part def CentralController {
        port worldIn : WorldModelInPort;
        port goalIn : GoalInPort;
        port motionCmdIn : MotionInPort;
        port manipCmdIn : ManipInPort;
        port motionOut : MotionOutPort;
        port manipOut : ManipOutPort;

        perform action coordinate {
            in attribute motionCmd : MotionCommand;
            in attribute manipCmd : ManipulatorCommand;
            first start;
            then action dispatchMotion;
            then action dispatchManipulation;
            then action monitorExecution;
            then done;
        }
    }

    attribute def SigStartMission;
    attribute def SigStopMission;
    attribute def SigEmergencyStop;
    attribute def SigPerceptionDone;
    attribute def SigPlanDone;
    attribute def SigActionDone;
    attribute def SigReset;

    part def Robot {
        port extGoalIn : GoalInPort;

        part camera : RGBDCamera {
            :>> frameRate = 30[SI::Hz];
            :>> resolution = "1920x1080";
        }
        part lidar : LidarSensor {
            :>> scanRate = 10[SI::Hz];
            :>> maxRange = 100[SI::m];
        }
        part base : MobileBase {
            :>> maxLinearSpeed = 2.0[SI::m/s];
            :>> maxAngularSpeed = 1.5;
            :>> wheelbase = 0.5[SI::m];
        }
        part arm : RoboticArm {
            :>> payloadCapacity = 5[SI::kg];
            :>> reach = 0.8[SI::m];
        }
        part perception : PerceptionSubsystem;
        part planner : PlanningSubsystem;
        part controller : CentralController;

        connection camToPerc connect camera.imageOut to perception.cameraIn;
        connection lidarToPerc connect lidar.cloudOut to perception.lidarIn;
        connection percToPlanner connect perception.worldOut to planner.worldIn;
        connection percToCtrl connect perception.worldOut to controller.worldIn;
        connection goalToPlanner connect extGoalIn to planner.goalIn;
        connection goalToCtrl connect extGoalIn to controller.goalIn;
        connection plannerMotionToCtrl connect planner.motionOut to controller.motionCmdIn;
        connection plannerManipToCtrl connect planner.manipOut to controller.manipCmdIn;
        connection ctrlMotionToBase connect controller.motionOut to base.motionIn;
        connection ctrlManipToArm connect controller.manipOut to arm.manipIn;

        state robotStates {
            entry; then off;
            state off;
            accept SigStartMission then sensing;
            state sensing;
            accept SigPerceptionDone then planning;
            accept SigStopMission then off;
            accept SigEmergencyStop then emergency;
            state planning;
            accept SigPlanDone then acting;
            accept SigStopMission then off;
            accept SigEmergencyStop then emergency;
            state acting;
            accept SigActionDone then sensing;
            accept SigStopMission then off;
            accept SigEmergencyStop then emergency;
            state emergency;
            accept SigReset then off;
        }
    }

    requirement def CollisionAvoidanceRequirement {
        subject robot : Robot;
        attribute minSafeDistance : LengthValue = 0.5[SI::m];
        doc /* The robot must maintain at least minSafeDistance from any detected obstacle in the world model at all times. */
    }

    requirement def DetectionAccuracyRequirement {
        subject perception : PerceptionSubsystem;
        attribute minDetectionConfidence : Real = 0.95;
        doc /* Object detection confidence must be at least minDetectionConfidence for all classified objects. */
    }

    requirement def ManipulationAccuracyRequirement {
        subject arm : RoboticArm;
        attribute positionTolerance : LengthValue = 0.005[SI::m];
        doc /* Arm end-effector positioning must be within positionTolerance of the target position. */
    }

    requirement def RealTimePerformanceRequirement {
        subject robot : Robot;
        attribute maxSensePlanActCycle : TimeValue = 0.1[SI::s];
        doc /* The sense-plan-act cycle must complete within maxSensePlanActCycle for real-time performance. */
    }

    requirement def SafetyStopRequirement {
        subject robot : Robot;
        attribute maxStopTime : TimeValue = 0.5[SI::s];
        doc /* Robot must cease all motion within maxStopTime of receiving an emergency stop signal. */
    }

    requirement collisionAvoidanceReq : CollisionAvoidanceRequirement;
    requirement detectionAccuracyReq : DetectionAccuracyRequirement;
    requirement manipulationAccuracyReq : ManipulationAccuracyRequirement;
    requirement realTimePerformanceReq : RealTimePerformanceRequirement;
    requirement safetyStopReq : SafetyStopRequirement;

    part autonomousRobotInstance : Robot {
        satisfy collisionAvoidanceReq;
        satisfy detectionAccuracyReq;
        satisfy manipulationAccuracyReq;
        satisfy realTimePerformanceReq;
        satisfy safetyStopReq;
    }
}
