package 'Robotic Navigation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def Pose {
        attribute position : Position;
        attribute orientation : Orientation;
    }
    
    attribute def Velocity {
        attribute linear : SpeedValue;
        attribute angular : AngularVelocityValue;
    }
    
    item def ObstacleData {
        attribute distance : LengthValue;
        attribute bearing : Real;
        attribute confidence : Real;
    }
    
    item def PathSegment {
        attribute waypoint : Pose;
        attribute timestamp : TimeValue;
        attribute velocity : Velocity;
    }
    
    item def NavigationGoal {
        attribute targetPose : Pose;
        attribute maxSpeed : SpeedValue;
        attribute arrivalTolerance : LengthValue;
    }
    
    port def SensorDataPort {
        out obstacles : ObstacleData[*];
        out currentPose : Pose;
    }
    
    port def MotorCommandPort {
        in velocityCommand : Velocity;
        out actualVelocity : Velocity;
    }
    
    port def NavigationCommandPort {
        in goal : NavigationGoal;
        out status : String;
        out currentPath : PathSegment[*];
    }
    
    part def LidarSensor {
        port sensorOut : SensorDataPort;
        attribute scanRate : FrequencyValue;
        attribute maxRange : LengthValue;
        attribute angularResolution : Real;
        
        action def ScanEnvironment {
            out detectedObstacles : ObstacleData[*];
        }
    }
    
    part def InertialMeasurementUnit {
        port poseOut : SensorDataPort;
        attribute updateRate : FrequencyValue;
        attribute positionAccuracy : LengthValue;
        attribute orientationAccuracy : Real;
        
        action def MeasurePose {
            out measuredPose : Pose;
        }
    }
    
    part def DriveMotor {
        port motorControl : ~MotorCommandPort;
        attribute maxTorque : TorqueValue;
        attribute maxSpeed : AngularVelocityValue;
        
        action def ExecuteVelocity {
            in command : Velocity;
            out achieved : Velocity;
        }
    }
    
    part def LocalizationModule {
        in sensorData : ObstacleData[*];
        in imuPose : Pose;
        out estimatedPose : Pose;
        out localizationConfidence : Real;
        
        action def EstimatePose {
            in lidarData : ObstacleData[*];
            in inertialPose : Pose;
            out fusedPose : Pose;
            out confidence : Real;
        }
    }
    
    part def ObstacleDetectionModule {
        in rawSensorData : ObstacleData[*];
        out validatedObstacles : ObstacleData[*];
        out minClearance : LengthValue;
        
        action def FilterObstacles {
            in rawObstacles : ObstacleData[*];
            out filteredObstacles : ObstacleData[*];
            out nearestDistance : LengthValue;
        }
    }
    
    part def PathPlanningModule {
        in currentPose : Pose;
        in targetPose : Pose;
        in obstacles : ObstacleData[*];
        out plannedPath : PathSegment[*];
        out pathValid : Boolean;
        
        action def GeneratePath {
            in start : Pose;
            in goal : Pose;
            in obstacleMap : ObstacleData[*];
            out trajectory : PathSegment[*];
            out isValid : Boolean;
        }
    }
    
    part def MotionControlModule {
        in desiredPath : PathSegment[*];
        in currentPose : Pose;
        in currentVelocity : Velocity;
        out controlCommand : Velocity;
        
        action def ComputeControl {
            in targetSegment : PathSegment;
            in actualPose : Pose;
            in actualVelocity : Velocity;
            out velocityCommand : Velocity;
        }
    }
    
    action def SenseEnvironment {
        out lidarObstacles : ObstacleData[*];
        out robotPose : Pose;
    }
    
    action def LocalizeRobot {
        in sensorObstacles : ObstacleData[*];
        in imuData : Pose;
        out estimatedPose : Pose;
        out confidence : Real;
    }
    
    action def DetectObstacles {
        in environmentData : ObstacleData[*];
        out validObstacles : ObstacleData[*];
        out clearance : LengthValue;
    }
    
    action def PlanNavigationPath {
        in currentPosition : Pose;
        in goalPosition : Pose;
        in obstacleList : ObstacleData[*];
        out trajectory : PathSegment[*];
        out pathIsValid : Boolean;
    }
    
    action def ControlMotion {
        in path : PathSegment[*];
        in pose : Pose;
        in velocity : Velocity;
        out velocityCommand : Velocity;
    }
    
    action def ExecuteMotion {
        in velocityCmd : Velocity;
        out actualVelocity : Velocity;
    }
    
    action def CheckGoalReached {
        in current : Pose;
        in target : Pose;
        in tolerance : LengthValue;
        out result : Boolean;
    }
    
    action def AutonomousNavigation {
        in navigationGoal : NavigationGoal;
        out navigationComplete : Boolean;
        
        first start;
        then merge navigationCycle;
        
        action sense : SenseEnvironment {
            out lidarObstacles;
            out robotPose;
        }
        
        then action localize : LocalizeRobot {
            in sensorObstacles = sense.lidarObstacles;
            in imuData = sense.robotPose;
            out estimatedPose;
            out confidence;
        }
        
        then action detectObstacles : DetectObstacles {
            in environmentData = sense.lidarObstacles;
            out validObstacles;
            out clearance;
        }
        
        then action planPath : PlanNavigationPath {
            in currentPosition = localize.estimatedPose;
            in goalPosition = navigationGoal.targetPose;
            in obstacleList = detectObstacles.validObstacles;
            out trajectory;
            out pathIsValid;
        }
        
        then decide;
            if !planPath.pathIsValid then navigationCycle;
            if planPath.pathIsValid then control;
        
        action control : ControlMotion {
            in path = planPath.trajectory;
            in pose = localize.estimatedPose;
            in velocity;
            out velocityCommand;
        }
        
        then action execute : ExecuteMotion {
            in velocityCmd = control.velocityCommand;
            out actualVelocity;
        }
        
        then action checkGoal : CheckGoalReached {
            in current = localize.estimatedPose;
            in target = navigationGoal.targetPose;
            in tolerance = navigationGoal.arrivalTolerance;
            out result;
        }
        
        then decide;
            if checkGoal.result then goalAchieved;
            if !checkGoal.result then navigationCycle;
        
        action goalAchieved {
            assign navigationComplete := true;
        }
        then done;
    }
    
    part def RobotNavigationSystem {
        doc /* 
            The Robotic Navigation System autonomously guides a mobile robot from its 
            current location to a specified goal position while avoiding obstacles in 
            real-time. The system continuously senses the environment using lidar and 
            inertial sensors, localizes the robot within its environment, detects and 
            validates obstacles, plans collision-free paths, and executes precise motion 
            commands. This perception-planning-control cycle repeats until the robot 
            successfully reaches its destination within the specified tolerance.
        */
        
        port navCommand : NavigationCommandPort;
        
        part lidar : LidarSensor {
            attribute :>> scanRate = 10.0 [Hz];
            attribute :>> maxRange = 30.0 [m];
            attribute :>> angularResolution = 0.25;
        }
        
        part imu : InertialMeasurementUnit {
            attribute :>> updateRate = 100.0 [Hz];
            attribute :>> positionAccuracy = 0.05 [m];
            attribute :>> orientationAccuracy = 0.1;
        }
        
        part leftMotor : DriveMotor {
            attribute :>> maxTorque = 5.0 [N*m];
            attribute :>> maxSpeed = 10.0 [rad/s];
        }
        
        part rightMotor : DriveMotor {
            attribute :>> maxTorque = 5.0 [N*m];
            attribute :>> maxSpeed = 10.0 [rad/s];
        }
        
        part localization : LocalizationModule;
        part obstacleDetection : ObstacleDetectionModule;
        part pathPlanning : PathPlanningModule;
        part motionControl : MotionControlModule;
        
        connect lidar.sensorOut.obstacles to obstacleDetection.rawSensorData;
        connect lidar.sensorOut.obstacles to localization.sensorData;
        connect imu.poseOut.currentPose to localization.imuPose;
        connect localization.estimatedPose to pathPlanning.currentPose;
        connect obstacleDetection.validatedObstacles to pathPlanning.obstacles;
        connect pathPlanning.plannedPath to motionControl.desiredPath;
        connect localization.estimatedPose to motionControl.currentPose;
        connect motionControl.controlCommand to leftMotor.motorControl.velocityCommand;
        connect motionControl.controlCommand to rightMotor.motorControl.velocityCommand;
        connect leftMotor.motorControl.actualVelocity to motionControl.currentVelocity;
        
        perform action navigate : AutonomousNavigation[*] ordered;
    }
    
    part robotNavigationSystem : RobotNavigationSystem;
    
    requirement def SafeNavigationRequirement {
        doc /* The robot shall maintain minimum safe clearance from all detected obstacles during navigation. */
        
        subject robot : RobotNavigationSystem;
        
        require constraint {
            robot.obstacleDetection.minClearance >= 0.5 [m]
        }
    }
    
    requirement def NavigationAccuracyRequirement {
        doc /* The robot shall reach the goal position within specified position and orientation tolerances. */
        
        subject robot : RobotNavigationSystem;
        
        attribute positionTolerance : LengthValue = 0.1 [m];
        attribute orientationTolerance : Real = 5.0;
    }
    
    requirement def RealtimePerformanceRequirement {
        doc /* The navigation system shall update at minimum frequency to ensure responsive and safe control. */
        
        subject robot : RobotNavigationSystem;
        
        require constraint {
            robot.localization.updateRate >= 10.0 [Hz]
        }
        
        require constraint {
            robot.lidar.scanRate >= 10.0 [Hz]
        }
    }
    
    requirement def RobustLocalizationRequirement {
        doc /* The localization system shall maintain high confidence in pose estimation during navigation. */
        
        subject robot : RobotNavigationSystem;
        
        require constraint {
            robot.localization.localizationConfidence >= 0.8
        }
    }
    
    requirement autonomousNavigationMission {
        doc /* The robotic navigation system shall autonomously navigate from start to goal while avoiding obstacles and meeting performance requirements. */
        
        subject robot : RobotNavigationSystem;
        
        assume constraint validEnvironment {
            doc /* The environment is structured with detectable obstacles and sufficient sensor coverage. */
        }
        
        require safeNavigation : SafeNavigationRequirement;
        require accurateNavigation : NavigationAccuracyRequirement;
        require realtimePerformance : RealtimePerformanceRequirement;
        require robustLocalization : RobustLocalizationRequirement;
    }
}
