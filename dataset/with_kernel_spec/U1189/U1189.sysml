package AutonomousNavigationSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    package Definitions {
        attribute def Distance :> LengthValue;
        attribute def Angle :> PlaneAngleValue;
        attribute def Velocity :> SpeedValue;
        
        attribute def Position {
            attribute x : Distance;
            attribute y : Distance;
        }
        attribute def Orientation {
            attribute theta : Angle;
        }
        attribute def Waypoint {
            attribute position : Position;
        }
        attribute def Path {
            attribute waypoints : Waypoint[0..*];
        }
        attribute def Obstacle {
            attribute distance : Distance;
            attribute bearing : Angle;
        }
        attribute def ObstacleList {
            attribute obstacles : Obstacle[0..*];
        }
        attribute def LidarData {
            attribute obstacles : Obstacle[0..*];
        }
        attribute def IMUData {
            attribute position : Position;
            attribute orientation : Orientation;
        }
        attribute def PositionEstimate {
            attribute position : Position;
            attribute orientation : Orientation;
        }
        attribute def VelocityCommands {
            attribute leftVelocity : Velocity;
            attribute rightVelocity : Velocity;
        }
        attribute def Goal {
            attribute targetPosition : Position;
            attribute tolerance : Distance;
        }
        
        calc def IsAtGoal {
            in current : Position;
            in goal : Goal;
            return : Boolean = (current.x - goal.targetPosition.x) * (current.x - goal.targetPosition.x) + (current.y - goal.targetPosition.y) * (current.y - goal.targetPosition.y) < goal.tolerance * goal.tolerance;
        }

        action def Sense {
            out lidarData : LidarData;
            out imuData : IMUData;
        }
        action def Localize {
            in lidarData : LidarData;
            in imuData : IMUData;
            out positionEstimate : PositionEstimate;
        }
        action def DetectObstacles {
            in lidarData : LidarData;
            out obstacles : ObstacleList;
        }
        action def PlanPath {
            in positionEstimate : PositionEstimate;
            in obstacles : ObstacleList;
            in goal : Goal;
            out plannedPath : Path;
        }
        action def ControlMotion {
            in positionEstimate : PositionEstimate;
            in plannedPath : Path;
            out velocityCommands : VelocityCommands;
        }
        action def Navigate {
            in goal : Goal;
            out velocityCommands : VelocityCommands;
        }
        
        part def DriveMotor {
            in attribute velocity : Velocity;
        }
        part def Lidar {
            out lidarData : LidarData;
        }
        part def IMU {
            out imuData : IMUData;
        }
        part def LocalizationModule {
            in lidarData : LidarData;
            in imuData : IMUData;
            out positionEstimate : PositionEstimate;
        }
        part def ObstacleDetectionModule {
            in lidarData : LidarData;
            out obstacles : ObstacleList;
        }
        part def PathPlanningModule {
            in positionEstimate : PositionEstimate;
            in obstacles : ObstacleList;
            in goal : Goal;
            out plannedPath : Path;
        }
        part def MotionControlModule {
            in positionEstimate : PositionEstimate;
            in plannedPath : Path;
            out velocityCommands : VelocityCommands;
        }
        part def Robot {
            part leftMotor : DriveMotor;
            part rightMotor : DriveMotor;
            part lidar : Lidar;
            part imu : IMU;
            part localization : LocalizationModule;
            part obstacleDetection : ObstacleDetectionModule;
            part pathPlanning : PathPlanningModule;
            part motionControl : MotionControlModule;
            
            flow lidar.lidarData to localization.lidarData;
            flow imu.imuData to localization.imuData;
            flow lidar.lidarData to obstacleDetection.lidarData;
            flow localization.positionEstimate to pathPlanning.positionEstimate;
            flow obstacleDetection.obstacles to pathPlanning.obstacles;
            flow localization.positionEstimate to motionControl.positionEstimate;
            flow pathPlanning.plannedPath to motionControl.plannedPath;
            bind leftMotor.velocity = motionControl.velocityCommands.leftVelocity;
            bind rightMotor.velocity = motionControl.velocityCommands.rightVelocity;
        }
        
        requirement def SafetyRequirement {
            subject theRobot : Robot;
            attribute minClearance : Distance = 0.5 [m];
            attribute obstacleDistance : Distance;
            constraint { obstacleDistance > minClearance }
        }
        requirement def PerformanceRequirement {
            subject theRobot : Robot;
            attribute maxLoopTime : DurationValue = 0.1 [s];
            attribute loopTime : DurationValue;
            constraint { loopTime < maxLoopTime }
        }
    }
    
    public import Definitions::*;
    
    package Usages {
        private import Definitions::*;
        
        part robot : Robot {
            requirement safety : SafetyRequirement {
                subject = robot;
            }
            requirement performance : PerformanceRequirement {
                subject = robot;
            }
        }
        
        action navigate : Navigate {
            in goal : Goal;
            out velocityCommands : VelocityCommands;
            loop action cycle {
                first start;
                then action sense : Sense {
                    out lidarData : LidarData;
                    out imuData : IMUData;
                }
                then action localize : Localize {
                    in lidarData = sense.lidarData;
                    in imuData = sense.imuData;
                    out positionEstimate : PositionEstimate;
                }
                then action detectObstacles : DetectObstacles {
                    in lidarData = sense.lidarData;
                    out obstacles : ObstacleList;
                }
                then action planPath : PlanPath {
                    in positionEstimate = localize.positionEstimate;
                    in obstacles = detectObstacles.obstacles;
                    in goal = navigate.goal;
                    out plannedPath : Path;
                }
                then action controlMotion : ControlMotion {
                    in positionEstimate = localize.positionEstimate;
                    in plannedPath = planPath.plannedPath;
                    out velocityCommands : VelocityCommands;
                }
            } until IsAtGoal(cycle.localize.positionEstimate.position, navigate.goal);
            then done;
        }
    }
}
