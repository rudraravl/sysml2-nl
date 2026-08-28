package AutonomousRobotSLAM {
    import ScalarValues::*;
    import ISQ::*;

    value type Distance :> Real { unit "m"; }
    value type Angle :> Real { unit "rad"; }
    value type LinearVelocity :> Real { unit "m/s"; }
    value type AngularVelocity :> Real { unit "rad/s"; }
    value type Probability :> Real { unit "1"; min 0; max 1; }
    value type Time :> Real { unit "s"; }

    item def LaserScan {
        attribute ranges : Distance[0..*];
        attribute angles : Angle[0..*];
        attribute timestamp : Time;
    }
    item def Odometry {
        attribute distance : Distance;
        attribute heading : Angle;
        attribute timestamp : Time;
    }
    item def IMUData {
        attribute linearAccel : Distance[3];
        attribute angularVel : AngularVelocity[3];
        attribute timestamp : Time;
    }
    item def Pose {
        attribute x : Distance;
        attribute y : Distance;
        attribute theta : Angle;
        attribute timestamp : Time;
    }
    item def OccupancyGrid {
        attribute width : Integer;
        attribute height : Integer;
        attribute resolution : Distance;
        attribute cells : Probability[0..*];
    }
    item def MotionCommand {
        attribute linearVelocity : LinearVelocity;
        attribute angularVelocity : AngularVelocity;
    }
    item def TargetDestination {
        attribute x : Distance;
        attribute y : Distance;
    }

    port def LaserScanOut { out scan : LaserScan; }
    port def OdometryOut { out odom : Odometry; }
    port def IMUDataOut { out imuData : IMUData; }
    port def PoseOut { out pose : Pose; }
    port def MapOut { out map : OccupancyGrid; }
    port def CommandOut { out cmd : MotionCommand; }
    port def TargetIn { in target : TargetDestination; }

    requirement def SLAMRequirement {
        doc "The system shall simultaneously build a 2D map of its surroundings while accurately tracking its own position within that map."
    }
    requirement def SensorProcessingRequirement {
        doc "The system shall process LIDAR, odometry, and IMU data to estimate pose."
    }
    requirement def MapBuildingRequirement {
        doc "The system shall update and expand an occupancy grid map using the accurate pose and laser scan."
    }
    requirement def PathPlanningRequirement {
        doc "The system shall calculate and issue motion commands to navigate towards a target destination while avoiding obstacles."
    }

    part def LIDAR {
        port scanOut : LaserScanOut;
        attribute scanRate : Real;
    }
    part def WheelEncoders {
        port odomOut : OdometryOut;
    }
    part def IMU {
        port imuOut : IMUDataOut;
    }

    part def MotionModel {
        in port odomIn : OdometryOut;
        out port posePredOut : PoseOut;
    }
    part def ScanMatcher {
        in port scanIn : LaserScanOut;
        in port mapIn : MapOut;
        out port poseMatchOut : PoseOut;
    }
    part def PoseEstimator {
        in port posePredIn : PoseOut;
        in port poseMatchIn : PoseOut;
        in port imuIn : IMUDataOut;
        out port poseEstOut : PoseOut;
    }
    part def MapBuilder {
        in port poseIn : PoseOut;
        in port scanIn : LaserScanOut;
        out port mapOut : MapOut;
        attribute map : OccupancyGrid;
    }
    part def PathPlanner {
        in port poseIn : PoseOut;
        in port mapIn : MapOut;
        in port targetIn : TargetIn;
        out port cmdOut : CommandOut;
    }

    part def NavigationSystem {
        requirement slmReq : SLAMRequirement;
        requirement sensReq : SensorProcessingRequirement;
        requirement mapReq : MapBuildingRequirement;
        requirement pathReq : PathPlanningRequirement;

        part lidar : LIDAR;
        part encoders : WheelEncoders;
        part imu : IMU;

        part motionModel : MotionModel;
        part scanMatcher : ScanMatcher;
        part poseEstimator : PoseEstimator;
        part mapBuilder : MapBuilder;
        part pathPlanner : PathPlanner;

        connect lidar.scanOut to scanMatcher.scanIn;
        connect lidar.scanOut to mapBuilder.scanIn;
        connect encoders.odomOut to motionModel.odomIn;
        connect imu.imuOut to poseEstimator.imuIn;

        connect motionModel.posePredOut to poseEstimator.posePredIn;
        connect scanMatcher.poseMatchOut to poseEstimator.poseMatchIn;
        connect mapBuilder.mapOut to scanMatcher.mapIn;
        connect mapBuilder.mapOut to pathPlanner.mapIn;

        connect poseEstimator.poseEstOut to mapBuilder.poseIn;
        connect poseEstimator.poseEstOut to pathPlanner.poseIn;

        attribute sensorsReady : Boolean = false;

        state def NavigationStates {
            state Initializing {
                entry // initialize sensors and map
            }
            state ActiveMapping {
                entry // run SLAM loop
            }
            transition init_to_active
                source Initializing
                target ActiveMapping
                when sensorsReady;
        }

        action def SLAMCycle {
            in scan : LaserScan;
            in odom : Odometry;
            in imuData : IMUData;
            in currentMap : OccupancyGrid;
            out updatedMap : OccupancyGrid;
            out estimatedPose : Pose;
            out command : MotionCommand;
            
            action predictPose {
                in odom;
                out predictedPose : Pose;
            }
            action matchScan {
                in scan;
                in currentMap;
                out matchedPose : Pose;
            }
            action estimatePose {
                in predictedPose;
                in matchedPose;
                in imuData;
                out estimatedPose;
            }
            action updateMap {
                in scan;
                in estimatedPose;
                in currentMap;
                out updatedMap;
            }
            action planPath {
                in estimatedPose;
                in updatedMap;
                out command;
            }
            
            connect predictPose.predictedPose to estimatePose.predictedPose;
            connect matchScan.matchedPose to estimatePose.matchedPose;
            connect estimatePose.estimatedPose to updateMap.estimatedPose;
            connect updateMap.updatedMap to planPath.updatedMap;
        }
    }
}
