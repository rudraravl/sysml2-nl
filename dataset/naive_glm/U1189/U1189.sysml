package AutonomousNavigationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value type LengthValue :> Real {
        unit mm;
    }
    value type DistanceValue :> Real {
        unit m;
    }
    value type VelocityValue :> Real {
        unit 'm/s';
    }
    value type AngularVelocityValue :> Real {
        unit 'rad/s';
    }
    value type AngleValue :> Real {
        unit rad;
    }
    value type FrequencyValue :> Real {
        unit Hz;
    }
    value type TimeValue :> Real {
        unit s;
    }
    value type CoordinateValue :> Real {
        unit m;
    }

    // ---- Item Definitions ----

    item def LidarScan {
        attribute scanTimestamp : TimeValue;
        attribute ranges : DistanceValue[0..*] ordered;
        attribute bearings : AngleValue[0..*] ordered;
    }

    item def ImuData {
        attribute timestamp : TimeValue;
        attribute linearAccelerationX : VelocityValue;
        attribute linearAccelerationY : VelocityValue;
        attribute angularVelocityZ : AngularVelocityValue;
        attribute orientation : AngleValue;
    }

    item def PoseEstimate {
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute theta : AngleValue;
        attribute confidence : Real;
    }

    item def ObstacleList {
        attribute obstacleCount : Integer;
        attribute positionsX : CoordinateValue[0..*] ordered;
        attribute positionsY : CoordinateValue[0..*] ordered;
        attribute radii : DistanceValue[0..*] ordered;
    }

    item def PathSegment {
        attribute startX : CoordinateValue;
        attribute startY : CoordinateValue;
        attribute endX : CoordinateValue;
        attribute endY : CoordinateValue;
        attribute length : DistanceValue;
    }

    item def PlannedPath {
        attribute segmentCount : Integer;
        attribute segments : PathSegment[0..*] ordered;
        attribute totalLength : DistanceValue;
    }

    item def VelocityCommand {
        attribute linearVelocity : VelocityValue;
        attribute angularVelocity : AngularVelocityValue;
    }

    item def GoalPoint {
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute toleranceRadius : DistanceValue;
    }

    // ---- Port Definitions ----

    port def LidarOutPort {
        out scan : LidarScan;
    }
    port def ImuOutPort {
        out data : ImuData;
    }
    port def PoseOutPort {
        out pose : PoseEstimate;
    }
    port def ObstacleOutPort {
        out obstacles : ObstacleList;
    }
    port def PathOutPort {
        out path : PlannedPath;
    }
    port def VelocityCmdPort {
        out cmd : VelocityCommand;
    }
    port def GoalInPort {
        in goal : GoalPoint;
    }
    port def MotorCmdPort {
        out cmd : VelocityCommand;
    }

    // ---- Part Definitions ----

    part def LidarSensor {
        attribute maxRange : DistanceValue = 10.0;
        attribute angularResolution : AngleValue = 0.01745;
        attribute scanRate : FrequencyValue = 10.0;
        port lidarOut : LidarOutPort;

        action def PerformScan {
            out scanOut : LidarScan;
        }
        perform PerformScan;
    }

    part def ImuSensor {
        attribute sampleRate : FrequencyValue = 100.0;
        port imuOut : ImuOutPort;

        action def SampleImu {
            out dataOut : ImuData;
        }
        perform SampleImu;
    }

    part def DriveMotor {
        attribute maxLinearVelocity : VelocityValue = 1.5;
        attribute maxAngularVelocity : AngularVelocityValue = 5.0;
        port cmdIn : MotorCmdPort;
        attribute wheelRadius : DistanceValue = 0.05;
        attribute currentLinearVelocity : VelocityValue;
        attribute currentAngularVelocity : AngularVelocityValue;
    }

    part def LocalizationModule {
        port lidarIn : ~LidarOutPort;
        port imuIn : ~ImuOutPort;
        port poseOut : PoseOutPort;

        action def FuseData {
            in lidarScan : LidarScan;
            in imuData : ImuData;
            out pose : PoseEstimate;
        }
        perform FuseData;
    }

    part def ObstacleDetectionModule {
        port lidarIn : ~LidarOutPort;
        port obstacleOut : ObstacleOutPort;

        action def DetectObstacles {
            in scan : LidarScan;
            out obstacles : ObstacleList;
        }
        perform DetectObstacles;
    }

    part def PathPlanningModule {
        port poseIn : ~PoseOutPort;
        port obstacleIn : ~ObstacleOutPort;
        port goalIn : GoalInPort;
        port pathOut : PathOutPort;

        attribute replanningInterval : TimeValue = 0.2;

        action def PlanPath {
            in currentPose : PoseEstimate;
            in obstacles : ObstacleList;
            in goal : GoalPoint;
            out plannedPath : PlannedPath;
        }
        perform PlanPath;
    }

    part def MotionControlModule {
        port poseIn : ~PoseOutPort;
        port pathIn : ~PathOutPort;
        port leftMotorOut : MotorCmdPort;
        port rightMotorOut : MotorCmdPort;

        attribute controlLoopRate : FrequencyValue = 50.0;
        attribute minClearance : DistanceValue = 0.2;

        action def ComputeVelocity {
            in currentPose : PoseEstimate;
            in plannedPath : PlannedPath;
            out leftCmd : VelocityCommand;
            out rightCmd : VelocityCommand;
        }
        perform ComputeVelocity;
    }

    part def MobileRobotPlatform {
        attribute wheelBase : DistanceValue = 0.3;
        part leftMotor : DriveMotor;
        part rightMotor : DriveMotor;
        port leftMotorCmd : ~MotorCmdPort;
        port rightMotorCmd : ~MotorCmdPort;
    }

    // ---- Navigation Controller with State Machine ----

    part def NavigationController {
        port lidarIn : ~LidarOutPort;
        port imuIn : ~ImuOutPort;
        port goalIn : GoalInPort;
        port leftMotorCmdOut : MotorCmdPort;
        port rightMotorCmdOut : MotorCmdPort;

        attribute goalReachedTolerance : DistanceValue = 0.15;
        attribute minObstacleClearance : DistanceValue = 0.2;
        attribute controlLoopFrequency : FrequencyValue = 50.0;

        part localization : LocalizationModule;
        part obstacleDetection : ObstacleDetectionModule;
        part pathPlanning : PathPlanningModule;
        part motionControl : MotionControlModule;

        connection lidarToLocalization connect lidarIn to localization.lidarIn;
        connection lidarToObstacleDetection connect lidarIn to obstacleDetection.lidarIn;
        connection imuToLocalization connect imuIn to localization.imuIn;
        connection localizationToPathPlanning connect localization.poseOut to pathPlanning.poseIn;
        connection obstacleToPathPlanning connect obstacleDetection.obstacleOut to pathPlanning.obstacleIn;
        connection goalToPathPlanning connect goalIn to pathPlanning.goalIn;
        connection pathToMotionControl connect pathPlanning.pathOut to motionControl.pathIn;
        connection localizationToMotionControl connect localization.poseOut to motionControl.poseIn;
        connection leftCmdOut connect motionControl.leftMotorOut to leftMotorCmdOut;
        connection rightCmdOut connect motionControl.rightMotorOut to rightMotorCmdOut;

        state machine NavigationStateMachine {
            attribute missionComplete : Boolean = false;

            state Idle;
            state Sensing;
            state Planning;
            state Acting;
            state GoalReached;
            state EmergencyStop;

            transition init from Idle to Sensing when goalIn.goal.received;

            transition senseToPlan from Sensing to Planning
                when localization.poseOut.pose.confidence > 0.8;

            transition planToAct from Planning to Acting
                when pathPlanning.pathOut.path.segmentCount > 0;

            transition actToSense from Acting to Sensing
                when motionControl.ComputeVelocity.done;

            transition checkGoal from Acting to GoalReached
                when localization.poseOut.pose.x within goalIn.goal.toleranceRadius
                    and localization.poseOut.pose.y within goalIn.goal.toleranceRadius;

            transition obstacleEmergency from Sensing to EmergencyStop
                when obstacleDetection.obstacleOut.obstacles.obstacleCount > 0
                    and minObstacleClearance < 0.1;

            transition resumeFromEmergency from EmergencyStop to Sensing
                when obstacleDetection.obstacleOut.obstacles.obstacleCount == 0;

            entry Idle { assign missionComplete = false; }
            entry GoalReached { assign missionComplete = true; }
        }

        exhibit state NavigationStateMachine;
    }

    // ---- Top-Level System ----

    part def AutonomousNavigationSystem {
        attribute systemName : String = "AutonomousMobileRobotNavigation";
        attribute designMaxSpeed : VelocityValue = 1.0;
        attribute designMinClearance : DistanceValue = 0.2;

        part robotPlatform : MobileRobotPlatform;
        part lidar : LidarSensor;
        part imu : ImuSensor;
        part controller : NavigationController;

        connection lidarToController connect lidar.lidarOut to controller.lidarIn;
        connection imuToController connect imu.imuOut to controller.imuIn;
        connection leftCmdToMotor connect controller.leftMotorCmdOut to robotPlatform.leftMotorCmd;
        connection rightCmdToMotor connect controller.rightMotorCmdOut to robotPlatform.rightMotorCmd;

        port goalInput : GoalInPort;
        connection goalToController connect goalInput to controller.goalIn;
    }

    // ---- Requirements ----

    requirement def SafetyRequirement {
        attribute id : String = "SR-001";
        text "The system shall maintain a minimum clearance of 0.2 m from all detected obstacles during navigation.";
        subject : AutonomousNavigationSystem;
        objective {
            minObstacleClearance >= 0.2
        }
    }

    requirement def PerformanceRequirement {
        attribute id : String = "PR-001";
        text "The control loop shall execute at a frequency of at least 50 Hz to ensure responsive navigation.";
        subject : AutonomousNavigationSystem;
        objective {
            controller.controlLoopFrequency >= 50.0
        }
    }

    requirement def GoalReachRequirement {
        attribute id : String = "GR-001";
        text "The system shall navigate the robot to within 0.15 m of the specified goal coordinates.";
        subject : AutonomousNavigationSystem;
        objective {
            controller.goalReachedTolerance <= 0.15
        }
    }

    requirement def SensorAccuracyRequirement {
        attribute id : String = "SA-001";
        text "The Lidar sensor shall detect obstacles up to 10 m range with angular resolution of 1 degree.";
        subject : AutonomousNavigationSystem;
        objective {
            lidar.maxRange >= 10.0 and lidar.angularResolution <= 0.01745
        }
    }

    requirement def LocalizationAccuracyRequirement {
        attribute id : String = "LA-001";
        text "The Localization module shall produce pose estimates with confidence greater than 0.8.";
        subject : AutonomousNavigationSystem;
        objective {
            controller.localization.poseOut.pose.confidence > 0.8
        }
    }

    requirement def SystemRequirements {
        requirement safetyReq : SafetyRequirement;
        requirement performanceReq : PerformanceRequirement;
        requirement goalReachReq : GoalReachRequirement;
        requirement sensorAccuracyReq : SensorAccuracyRequirement;
        requirement localizationAccuracyReq : LocalizationAccuracyRequirement;
    }

    part navigationSystem : AutonomousNavigationSystem {
        satisfy SystemRequirements;
    }

}
