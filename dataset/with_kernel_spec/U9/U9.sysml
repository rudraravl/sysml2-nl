package AutonomousMobileRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def ChargeLevel :> Real;
    attribute def LinearVelocity :> Real;
    attribute def AngularVelocity :> Real;
    attribute def Distance :> Real;
    attribute def Angle :> Real;

    item def Pose {
        attribute x : Distance;
        attribute y : Distance;
        attribute heading : Angle;
    }
    item def ObstacleScan {
        attribute obstacleMap : Real[0..*];
        attribute derivedPose : Pose;
    }
    item def Path {
        attribute waypoints : Pose[0..*];
    }
    item def WorkTask {
        attribute id : String;
        attribute destination : Pose;
        attribute description : String;
    }
    item def RobotStatus {
        attribute stateName : String;
        attribute chargeLevel : ChargeLevel;
    }

    attribute def TaskAssigned;
    attribute def TaskComplete;
    attribute def AtTarget;
    attribute def Docked;
    attribute def SystemFault;
    attribute def FaultResolved;
    attribute def BatteryFull;

    action def ScanEnvironment {
        out scan : ObstacleScan;
    }
    action def PlanPath {
        in scan : ObstacleScan;
        in target : Pose;
        out path : Path;
    }
    action def ExecuteMotion {
        in path : Path;
        out linearVel : LinearVelocity;
        out angularVel : AngularVelocity;
    }
    action def ActuateDrive {
        in linearVel : LinearVelocity;
        in angularVel : AngularVelocity;
    }
    action def PerformWork {
        in task : WorkTask;
        out complete : Boolean;
    }
    action def NavigateToDock {
        out path : Path;
    }
    action def ChargeBattery {
        inout charge : ChargeLevel;
    }
    action def HaltMotion;

    port def SensorDataPort {
        out scanData : ObstacleScan;
    }
    port def PlannerOutputPort {
        in scanData : ObstacleScan;
        in target : Pose;
        out plannedPath : Path;
    }
    port def MotionCommandPort {
        in path : Path;
        out linearVel : LinearVelocity;
        out angularVel : AngularVelocity;
    }
    port def DriveCommandPort {
        in linearVel : LinearVelocity;
        in angularVel : AngularVelocity;
    }
    port def PowerMonitorPort {
        out chargeLevel : ChargeLevel;
    }
    port def MissionCommPort {
        out task : WorkTask;
        in status : RobotStatus;
    }
    port def DockCommPort {
        out powerSupply : Real;
        in chargeRequest : Boolean;
        out dockConnected : Boolean;
    }

    part def Lidar {
        port scanPort : SensorDataPort;
        perform action scan : ScanEnvironment {
            out scan;
            first start;
            then done;
        }
    }

    part def PathPlanner {
        port plannerPort : PlannerOutputPort;
        perform action plan : PlanPath {
            in scan;
            in target;
            out path;
            first start;
            then done;
        }
    }

    part def MotionController {
        port motionIn : MotionCommandPort;
        port motionOut : DriveCommandPort;
        perform action executeMotion : ExecuteMotion {
            in path;
            out linearVel;
            out angularVel;
            first start;
            then done;
        }
    }

    part def DriveSystem {
        port driveIn : DriveCommandPort;
        perform action actuate : ActuateDrive {
            in linearVel;
            in angularVel;
            first start;
            then done;
        }
    }

    part def Battery {
        attribute currentCharge : ChargeLevel = 100;
        port powerPort : PowerMonitorPort;
        perform action monitorCharge {
            out charge : ChargeLevel;
            first start;
            then done;
        }
        perform action chargeAction : ChargeBattery {
            inout charge = currentCharge;
            first start;
            then done;
        }
    }

    part def ChargingDock {
        port dockPort : DockCommPort;
        attribute location : Pose;
        perform action supplyPower {
            in chargeRequest : Boolean;
            out powerSupply : Real;
            out dockConnected : Boolean;
            first start;
            then done;
        }
    }

    part def MissionController {
        port robotPorts[1..*] : MissionCommPort;
        attribute taskQueue : WorkTask[0..*];
        perform action manageMissions {
            first start;
            then done;
        }
    }

    part def MobileRobot {
        port missionPort : MissionCommPort;
        port chargingPort : DockCommPort;
        attribute currentPose : Pose;
        attribute currentTask : WorkTask;
        attribute dockingPose : Pose;

        part lidar : Lidar;
        part pathPlanner : PathPlanner;
        part motionController : MotionController;
        part driveSystem : DriveSystem;
        part battery : Battery;

        exhibit state robotStates {
            entry; then idle;
            state idle;
            accept TaskAssigned
                then navigating;
            state navigating {
                do action scanEnv : ScanEnvironment;
                do action planRoute : PlanPath;
                do action moveRobot : ExecuteMotion;
            }
            accept AtTarget
                then executingTask;
            accept when battery.currentCharge < 20
                then returningToBase;
            accept SystemFault
                then error;
            state executingTask {
                do action doWork : PerformWork;
            }
            accept TaskComplete
                then idle;
            accept when battery.currentCharge < 20
                then returningToBase;
            accept SystemFault
                then error;
            state returningToBase {
                do action goToDock : NavigateToDock;
            }
            accept Docked
                then charging;
            accept SystemFault
                then error;
            state charging {
                do action chargeUp : ChargeBattery;
            }
            accept BatteryFull
                then idle;
            accept SystemFault
                then error;
            state error {
                entry action haltMotion : HaltMotion;
            }
            accept FaultResolved
                then idle;
        }

        connect lidar.scanPort to pathPlanner.plannerPort;
        connect pathPlanner.plannerPort.plannedPath to motionController.motionIn.path;
        connect motionController.motionOut to driveSystem.driveIn;
    }

    requirement def LowBatteryReturn {
        subject robot : MobileRobot;
        doc /* The robot shall automatically return to the charging dock when its battery charge drops below 20%. */
    }

    requirement def TaskDispatchRequirement {
        subject controller : MissionController;
        doc /* The mission controller shall dispatch tasks to available idle robots. */
    }

    requirement def ObstacleAvoidance {
        subject robot : MobileRobot;
        doc /* The robot shall use Lidar scan data to plan obstacle-free paths. */
    }

    requirement def ErrorStateHandling {
        subject robot : MobileRobot;
        doc /* The robot shall halt all motion and enter an error state upon system fault detection. */
    }

    part amrSystem {
        part missionController : MissionController;
        part chargingDock : ChargingDock;
        part mobileRobots[1..*] : MobileRobot;

        connect missionController.robotPorts to mobileRobots.missionPort;
        connect mobileRobots.chargingPort to chargingDock.dockPort;

        satisfy LowBatteryReturn by mobileRobots;
        satisfy TaskDispatchRequirement by missionController;
        satisfy ObstacleAvoidance by mobileRobots;
        satisfy ErrorStateHandling by mobileRobots;
    }
}
