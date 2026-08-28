package AutonomousExplorationRobotModel {
    import ScalarValues::*;
    
    part def Unit;
    part m : Unit;
    part rad : Unit;
    part m_per_s : Unit;
    part rad_per_s : Unit;
    part percent : Unit;
    part A : Unit;
    part s : Unit;
    
    value type Length :> Real { unit m; }
    value type Angle :> Real { unit rad; }
    value type Velocity :> Real { unit m_per_s; }
    value type AngularVelocity :> Real { unit rad_per_s; }
    value type Percentage :> Real { unit percent; }
    value type Current :> Real { unit A; }
    value type Time :> Real { unit s; }
    
    enum def CellState {
        free;
        occupied;
        unknown;
    }
    
    item def LaserScan {
        attribute distances : Length[*];
        attribute angles : Angle[*];
        attribute timestamp : Time;
    }
    
    item def OdometryData {
        attribute distance : Length;
        attribute turn : Angle;
        attribute velocity : Velocity;
        attribute angularVelocity : AngularVelocity;
    }
    
    item def Pose2D {
        attribute x : Length;
        attribute y : Length;
        attribute theta : Angle;
    }
    
    item def OccupancyGrid {
        attribute width : Integer;
        attribute height : Integer;
        attribute resolution : Length;
        attribute cells : CellState[*];
        attribute mappedPercentage : Percentage;
    }
    
    item def NavCommand {
        attribute linearVelocity : Velocity;
        attribute angularVelocity : AngularVelocity;
    }
    
    item def MotorPower {
        attribute leftCurrent : Current;
        attribute rightCurrent : Current;
    }
    
    item def Frontier {
        attribute location : Pose2D;
        attribute size : Integer;
    }
    
    port def LaserScanPort {
        out scan : LaserScan;
    }
    
    port def OdometryPort {
        out odo : OdometryData;
    }
    
    port def Pose2DPort {
        out pose : Pose2D;
    }
    
    port def OccupancyGridPort {
        out map : OccupancyGrid;
    }
    
    port def NavCommandPort {
        out cmd : NavCommand;
    }
    
    port def MotorPowerPort {
        out power : MotorPower;
    }
    
    part def LaserRangeFinder {
        port scanOut : LaserScanPort;
        
        action generateScan {
            out scan : LaserScan;
        }
    }
    
    part def WheelEncoders {
        port odoOut : OdometryPort;
        
        action measureRotation {
            out odo : OdometryData;
        }
    }
    
    part def LocalizationProcessor {
        port scanIn : ~LaserScanPort;
        port odoIn : ~OdometryPort;
        port poseOut : Pose2DPort;
        
        action computeSLAM {
            in scan : LaserScan;
            in odo : OdometryData;
            out pose : Pose2D;
        }
    }
    
    part def MappingProcessor {
        port scanIn : ~LaserScanPort;
        port poseIn : ~Pose2DPort;
        port mapOut : OccupancyGridPort;
        
        action updateMap {
            in scan : LaserScan;
            in pose : Pose2D;
            out map : OccupancyGrid;
        }
    }
    
    part def ExplorationPlanner {
        port mapIn : ~OccupancyGridPort;
        port poseIn : ~Pose2DPort;
        port cmdOut : NavCommandPort;
        
        action identifyFrontiers {
            in map : OccupancyGrid;
            out frontiers : Frontier[*];
        }
        
        action selectTarget {
            in frontiers : Frontier[*];
            in currentPose : Pose2D;
            out target : Frontier;
        }
        
        action planPath {
            in map : OccupancyGrid;
            in target : Frontier;
            out cmd : NavCommand;
        }
    }
    
    part def MotionExecutor {
        port cmdIn : ~NavCommandPort;
        port odoIn : ~OdometryPort;
        port powerOut : MotorPowerPort;
        
        action executeCommand {
            in cmd : NavCommand;
            in odo : OdometryData;
            out power : MotorPower;
        }
    }
    
    part def DriveSystem {
        port powerIn : ~MotorPowerPort;
        
        action actuateMotors {
            in power : MotorPower;
        }
    }
    
    state def ExplorationState {
        attribute mappedPercentage : Percentage = 0;
        attribute targetMappedPercentage : Percentage = 95;
        
        state Initializing;
        state Sensing;
        state ProcessingSLAM;
        state PlanningExploration;
        state ExecutingMotion;
        state Finalizing;
        state MissionComplete;
        
        transition from Initializing to Sensing;
        transition from Sensing to ProcessingSLAM;
        transition from ProcessingSLAM to PlanningExploration;
        transition from PlanningExploration to ExecutingMotion;
        transition from ExecutingMotion to Sensing when mappedPercentage < targetMappedPercentage;
        transition from ExecutingMotion to Finalizing when mappedPercentage >= targetMappedPercentage;
        transition from Finalizing to MissionComplete;
    }
    
    requirement def AutonomousExplorationReq {
        doc "The system shall explore and map unknown environments without human intervention.";
    }
    
    requirement def SLAMReq {
        doc "The system shall build a 2D occupancy grid map while tracking its precise location using SLAM.";
    }
    
    requirement def SafetyReq {
        doc "The system shall plan collision-free paths and operate safely in real-time.";
    }
    
    requirement def CompletionReq {
        doc "The system shall finalize the map when >= 95% of the environment is mapped.";
    }
    
    part def AutonomousExplorationRobot {
        attribute systemName : String = "AutonomousExplorer";
        
        part lidar : LaserRangeFinder;
        part encoders : WheelEncoders;
        part localization : LocalizationProcessor;
        part mapping : MappingProcessor;
        part planner : ExplorationPlanner;
        part executor : MotionExecutor;
        part drive : DriveSystem;
        
        state missionState : ExplorationState;
        
        connect lidar.scanOut to localization.scanIn;
        connect lidar.scanOut to mapping.scanIn;
        connect encoders.odoOut to localization.odoIn;
        connect encoders.odoOut to executor.odoIn;
        connect localization.poseOut to mapping.poseIn;
        connect localization.poseOut to planner.poseIn;
        connect mapping.mapOut to planner.mapIn;
        connect planner.cmdOut to executor.cmdIn;
        connect executor.powerOut to drive.powerIn;
        
        satisfy AutonomousExplorationReq;
        satisfy SLAMReq;
        satisfy SafetyReq;
        satisfy CompletionReq;
    }
}
