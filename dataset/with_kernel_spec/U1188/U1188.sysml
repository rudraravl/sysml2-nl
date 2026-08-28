package 'Autonomous Exploration SLAM' {
    private import ISQ::*;
    private import ScalarValues::*;

    enum def CellState {
        unknown;
        free;
        occupied;
    }

    item def Pose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute theta : AngleValue;
    }

    item def LaserScan {
        attribute ranges : LengthValue[0..*];
        attribute angles : AngleValue[0..*];
        attribute timestamp : TimeValue;
    }

    item def Odometry {
        attribute distance : LengthValue;
        attribute heading : AngleValue;
    }

    item def OccupancyGrid {
        attribute resolution : LengthValue;
        attribute width : Integer;
        attribute height : Integer;
        attribute cells : CellState[0..*];
        attribute exploredPercentage : Real;
    }

    item def Frontier {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute score : Real;
    }

    item def NavigationCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : Real;
    }

    item def MotorPower {
        attribute leftMotorPower : Real;
        attribute rightMotorPower : Real;
    }

    item def MapStatus {
        attribute exploredPercentage : Real;
        attribute isComplete : Boolean;
    }

    action def CaptureSensorData {
        out scan : LaserScan;
        out odom : Odometry;
    }

    action def Localize {
        in scan : LaserScan;
        in odom : Odometry;
        in currentMap : OccupancyGrid;
        out pose : Pose;
    }

    action def UpdateMap {
        in pose : Pose;
        in scan : LaserScan;
        in currentMap : OccupancyGrid;
        out updatedMap : OccupancyGrid;
    }

    action def PlanExploration {
        in currentMap : OccupancyGrid;
        in currentPose : Pose;
        out navCommand : NavigationCommand;
        out mapStatus : MapStatus;
    }

    action def ExecuteMotion {
        in navCommand : NavigationCommand;
        out motorPower : MotorPower;
    }

    action def DriveMotors {
        in motorPower : MotorPower;
    }

    part def LIDAR {
        port scanOut {
            out scan : LaserScan;
        }
    }

    part def WheelEncoder {
        port odomOut {
            out odom : Odometry;
        }
    }

    part def LocalizationProcessor {
        port scanIn {
            in scan : LaserScan;
        }
        port odomIn {
            in odom : Odometry;
        }
        port mapIn {
            in currentMap : OccupancyGrid;
        }
        port poseOut {
            out pose : Pose;
        }
    }

    part def MappingProcessor {
        port scanIn {
            in scan : LaserScan;
        }
        port poseIn {
            in pose : Pose;
        }
        port mapOut {
            out updatedMap : OccupancyGrid;
        }
    }

    part def ExplorationPlanner {
        port mapIn {
            in currentMap : OccupancyGrid;
        }
        port poseIn {
            in pose : Pose;
        }
        port commandOut {
            out navCommand : NavigationCommand;
        }
        port statusOut {
            out mapStatus : MapStatus;
        }
    }

    part def MotionExecutor {
        port commandIn {
            in navCommand : NavigationCommand;
        }
        port powerOut {
            out motorPower : MotorPower;
        }
    }

    part def MotorDriver {
        port powerIn {
            in motorPower : MotorPower;
        }
    }

    part def AutonomousRobot {
        part lidar : LIDAR;
        part wheelEncoder : WheelEncoder;
        part localization : LocalizationProcessor;
        part mapper : MappingProcessor;
        part planner : ExplorationPlanner;
        part executor : MotionExecutor;
        part motor : MotorDriver;

        flow lidarToLocalization of LaserScan
            from lidar.scanOut.scan to localization.scanIn.scan;
        flow lidarToMapping of LaserScan
            from lidar.scanOut.scan to mapper.scanIn.scan;
        flow odomToLocalization of Odometry
            from wheelEncoder.odomOut.odom to localization.odomIn.odom;
        flow mapToLocalization of OccupancyGrid
            from mapper.mapOut.updatedMap to localization.mapIn.currentMap;
        flow poseToMapping of Pose
            from localization.poseOut.pose to mapper.poseIn.pose;
        flow poseToPlanner of Pose
            from localization.poseOut.pose to planner.poseIn.pose;
        flow mapToPlanner of OccupancyGrid
            from mapper.mapOut.updatedMap to planner.mapIn.currentMap;
        flow commandToExecutor of NavigationCommand
            from planner.commandOut.navCommand to executor.commandIn.navCommand;
        flow powerToMotor of MotorPower
            from executor.powerOut.motorPower to motor.powerIn.motorPower;

        action exploreEnvironment {
            in initialMap : OccupancyGrid;
            in explorationThreshold : Real = 0.95;
            out finalMap : OccupancyGrid;
            private attribute currentMap : OccupancyGrid := initialMap;
            private attribute currentPose : Pose;
            private attribute currentScan : LaserScan;
            private attribute currentOdom : Odometry;
            private attribute currentCommand : NavigationCommand;
            private attribute currentMotorPower : MotorPower;
            private attribute mapStatus : MapStatus;
            private attribute missionComplete : Boolean = false;

            while !missionComplete {
                perform action sense : CaptureSensorData {
                    out scan;
                    out odom;
                }
                then assign currentScan := sense.scan;
                then assign currentOdom := sense.odom;

                then perform action localize : Localize {
                    in scan = currentScan;
                    in odom = currentOdom;
                    in currentMap = currentMap;
                    out pose;
                }
                then assign currentPose := localize.pose;

                then perform action mapUpdate : UpdateMap {
                    in pose = currentPose;
                    in scan = currentScan;
                    in currentMap = currentMap;
                    out updatedMap;
                }
                then assign currentMap := mapUpdate.updatedMap;

                then perform action plan : PlanExploration {
                    in currentMap = currentMap;
                    in currentPose = currentPose;
                    out navCommand;
                    out mapStatus;
                }
                then assign currentCommand := plan.navCommand;
                then assign mapStatus := plan.mapStatus;
                then assign missionComplete := mapStatus.exploredPercentage >= explorationThreshold;

                then perform action move : ExecuteMotion {
                    in navCommand = currentCommand;
                    out motorPower;
                }
                then assign currentMotorPower := move.motorPower;
            }
            assign finalMap := currentMap;
        }
    }

    requirement def HighAccuracyReq {
        doc /* The system shall maintain position accuracy within 0.05 m and orientation accuracy within 1 degree during exploration. */
    }

    requirement def RealTimeReq {
        doc /* The SLAM and planning cycle shall complete within 100 ms to ensure real-time obstacle avoidance. */
    }

    requirement def SafetyReq {
        doc /* The system shall maintain a minimum clearance of 0.1 m from all detected obstacles during navigation. */
    }

    requirement def ExplorationEfficiencyReq {
        doc /* The system shall map at least 95% of the accessible environment before completing the mission. */
    }

    part robotSystem : AutonomousRobot {
        satisfy HighAccuracyReq;
        satisfy RealTimeReq;
        satisfy SafetyReq;
        satisfy ExplorationEfficiencyReq;
    }
}
