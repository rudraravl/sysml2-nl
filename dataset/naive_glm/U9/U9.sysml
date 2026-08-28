package AMR_System {

    package Units {
        unit m;
        unit s;
        unit rad;
        unit percent;
        unit Ah;
        unit V;
        unit W;
        unit Hz;
        unit mps = m / s;
        unit rps = rad / s;
    }

    package ValueTypes {
        value type Length :> Real { unit m; }
        value type Distance :> Real { unit m; }
        value type Angle :> Real { unit rad; }
        value type LinearVelocity :> Real { unit mps; }
        value type AngularVelocity :> Real { unit rps; }
        value type Charge :> Real { unit percent; }
        value type BatteryCapacity :> Real { unit Ah; }
        value type Voltage :> Real { unit V; }
        value type Power :> Real { unit W; }
        value type Time :> Real { unit s; }
        value type Frequency :> Real { unit Hz; }
    }

    package Items {
        item def Pose {
            attribute x : Length;
            attribute y : Length;
            attribute theta : Angle;
        }

        item def ScanData {
            attribute ranges : Length[0..*];
            attribute angleMin : Angle;
            attribute angleMax : Angle;
            attribute resolution : Angle;
        }

        item def Path {
            attribute waypoints : Pose[0..*];
            attribute totalLength : Distance;
        }

        item def Task {
            attribute id : String;
            attribute destination : Pose;
            attribute priority : Integer;
            attribute description : String;
        }

        item def RobotStatus {
            attribute robotId : String;
            attribute state : String;
            attribute batteryLevel : Charge;
            attribute currentPose : Pose;
            attribute currentTaskId : String;
            attribute faultCode : Integer;
        }

        item def FaultAlert {
            attribute faultCode : Integer;
            attribute description : String;
        }
    }

    package Ports {
        port def ScanPort {
            out scanData : Items::ScanData;
        }

        port def PathPort {
            out path : Items::Path;
        }

        port def MotionPort {
            in linearVelocity : ValueTypes::LinearVelocity;
            in angularVelocity : ValueTypes::AngularVelocity;
        }

        port def CommandPort {
            in task : Items::Task;
            in abort : Boolean;
            out status : Items::RobotStatus;
        }

        port def DockPort {
            in docked : Boolean;
            out supplyVoltage : ValueTypes::Voltage;
            out chargingPower : ValueTypes::Power;
        }
    }

    package Components {

        part def LidarSensor {
            port scanOut : Ports::ScanPort;
            attribute scanRate : ValueTypes::Frequency = 10;
            attribute maxRange : ValueTypes::Length = 30;
            attribute angularResolution : ValueTypes::Angle = 0.01745;

            action scan {
                out scanData : Items::ScanData;
            }

            action detectObstacles {
                in scanData : Items::ScanData;
                out obstacleDetected : Boolean;
            }

            action estimatePose {
                in scanData : Items::ScanData;
                out pose : Items::Pose;
            }
        }

        part def PathPlanner {
            port scanIn : ~Ports::ScanPort;
            port pathOut : Ports::PathPort;
            attribute currentPose : Items::Pose;
            attribute targetPose : Items::Pose;
            attribute lastScanData : Items::ScanData;

            action planPath {
                in currentPose : Items::Pose;
                in targetPose : Items::Pose;
                in scanData : Items::ScanData;
                out path : Items::Path;
            }

            action replanPath {
                in newScanData : Items::ScanData;
                out path : Items::Path;
            }
        }

        part def MotionController {
            port pathIn : ~Ports::PathPort;
            port motionOut : ~Ports::MotionPort;
            attribute currentPose : Items::Pose;
            attribute currentLinearVelocity : ValueTypes::LinearVelocity = 0;
            attribute currentAngularVelocity : ValueTypes::AngularVelocity = 0;
            attribute pathProgress : Real = 0;

            action executePath {
                in path : Items::Path;
                out linearVelocity : ValueTypes::LinearVelocity;
                out angularVelocity : ValueTypes::AngularVelocity;
            }

            action stopMotion {
                out linearVelocity : ValueTypes::LinearVelocity = 0;
                out angularVelocity : ValueTypes::AngularVelocity = 0;
            }

            action updatePose {
                in linearVelocity : ValueTypes::LinearVelocity;
                in angularVelocity : ValueTypes::AngularVelocity;
                in deltaTime : ValueTypes::Time;
                out pose : Items::Pose;
            }
        }

        part def DriveSystem {
            port motionIn : Ports::MotionPort;
            attribute maxLinearVelocity : ValueTypes::LinearVelocity = 1.5;
            attribute maxAngularVelocity : ValueTypes::AngularVelocity = 2.0;
            attribute wheelBase : ValueTypes::Length = 0.5;
            attribute leftWheelVelocity : ValueTypes::LinearVelocity = 0;
            attribute rightWheelVelocity : ValueTypes::LinearVelocity = 0;

            action drive {
                in linearVelocity : ValueTypes::LinearVelocity;
                in angularVelocity : ValueTypes::AngularVelocity;
            }

            action computeWheelVelocities {
                in linearVelocity : ValueTypes::LinearVelocity;
                in angularVelocity : ValueTypes::AngularVelocity;
                out leftWheelVelocity : ValueTypes::LinearVelocity;
                out rightWheelVelocity : ValueTypes::LinearVelocity;
            }

            action emergencyStop {
                out leftWheelVelocity : ValueTypes::LinearVelocity = 0;
                out rightWheelVelocity : ValueTypes::LinearVelocity = 0;
            }
        }

        part def BatterySystem {
            port dockIn : ~Ports::DockPort;
            attribute capacity : ValueTypes::BatteryCapacity = 50;
            attribute currentCharge : ValueTypes::Charge = 100;
            attribute nominalVoltage : ValueTypes::Voltage = 24;
            attribute criticalThreshold : ValueTypes::Charge = 20;
            attribute fullChargeThreshold : ValueTypes::Charge = 100;
            attribute chargingRate : ValueTypes::Power = 100;
            attribute dischargeRate : ValueTypes::Power = 25;
            attribute faultDetected : Boolean = false;

            action monitorCharge {
                out level : ValueTypes::Charge;
                out faultDetected : Boolean;
            }

            action recharge {
                in supplyVoltage : ValueTypes::Voltage;
                in chargingPower : ValueTypes::Power;
                out updatedCharge : ValueTypes::Charge;
            }

            action consumePower {
                in power : ValueTypes::Power;
                in duration : ValueTypes::Time;
                out remainingCharge : ValueTypes::Charge;
            }

            action checkHealth {
                out faultDetected : Boolean;
                out faultCode : Integer;
            }
        }
    }

    part def MobileRobot {
        part lidar : Components::LidarSensor;
        part pathPlanner : Components::PathPlanner;
        part motionController : Components::MotionController;
        part driveSystem : Components::DriveSystem;
        part battery : Components::BatterySystem;

        port commandPort : Ports::CommandPort;
        port dockPort : ~Ports::DockPort;

        attribute robotId : String;
        attribute currentPose : Items::Pose;
        attribute currentTask : Items::Task;
        attribute taskAssigned : Boolean = false;
        attribute taskComplete : Boolean = false;
        attribute destinationReached : Boolean = false;
        attribute docked : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute faultCleared : Boolean = false;
        attribute dockPose : Items::Pose;

        connection lidar.scanOut to pathPlanner.scanIn;
        connection pathPlanner.pathOut to motionController.pathIn;
        connection motionController.motionOut to driveSystem.motionIn;
        connection dockPort to battery.dockIn;

        action updateStatus {
            out status : Items::RobotStatus;
        }

        action navigateToDestination {
            in destination : Items::Pose;
        }

        action executeWorkTask {
            in task : Items::Task;
        }

        action returnToBase {
            in targetDockPose : Items::Pose;
        }

        action performCharging {
            in supplyVoltage : ValueTypes::Voltage;
            in chargingPower : ValueTypes::Power;
        }

        action haltAllMotion {
        }

        action reportFault {
            out faultAlert : Items::FaultAlert;
        }

        state robotBehavior {

            state idle;
            state navigating;
            state executingTask;
            state returningToBase;
            state charging;
            state error;

            transition initial to idle;

            transition idle to navigating
                when taskAssigned
                if battery.currentCharge >= battery.criticalThreshold;

            transition idle to returningToBase
                when taskAssigned
                if battery.currentCharge < battery.criticalThreshold;

            transition idle to error when faultDetected;

            transition navigating to executingTask when destinationReached;

            transition navigating to returningToBase
                when battery.currentCharge < battery.criticalThreshold;

            transition navigating to error when faultDetected;

            transition executingTask to idle when taskComplete;

            transition executingTask to returningToBase
                when battery.currentCharge < battery.criticalThreshold;

            transition executingTask to error when faultDetected;

            transition returningToBase to charging when docked;

            transition returningToBase to error when faultDetected;

            transition charging to idle
                when battery.currentCharge >= battery.fullChargeThreshold;

            transition charging to error when faultDetected;

            transition error to idle when faultCleared;
        }
    }

    part def ChargingDock {
        port dockPort : Ports::DockPort;
        attribute dockId : String;
        attribute dockPose : Items::Pose;
        attribute outputVoltage : ValueTypes::Voltage = 24;
        attribute chargingPower : ValueTypes::Power = 100;
        attribute occupied : Boolean = false;

        action provideCharge {
            out supplyVoltage : ValueTypes::Voltage;
            out chargingPower : ValueTypes::Power;
        }

        action detectDocking {
            in robotPose : Items::Pose;
            out docked : Boolean;
        }

        action releaseRobot {
            out occupied : Boolean = false;
        }
    }

    part def MissionController {
        port commandPorts[0..*] : ~Ports::CommandPort;
        attribute taskQueue : Items::Task[0..*];
        attribute registeredRobotIds : String[0..*];
        attribute robotStatuses : Items::RobotStatus[0..*];
        attribute dispatchPolicy : String = "priority";

        action enqueueTask {
            in task : Items::Task;
        }

        action dispatchTask {
            in availableRobotIds : String[0..*];
            in task : Items::Task;
            out assignedRobotId : String;
        }

        action monitorRobots {
            in statuses : Items::RobotStatus[0..*];
        }

        action updateRobotStatus {
            in status : Items::RobotStatus;
        }

        action abortRobotTask {
            in robotId : String;
        }

        action checkTaskCompletion {
            in status : Items::RobotStatus;
            out taskCompleted : Boolean;
        }
    }

    part def AMRSystem {
        part missionController : MissionController;
        part chargingDock : ChargingDock;
        part robots[1..*] : MobileRobot;

        connection missionController.commandPorts to robots.commandPort;
        connection chargingDock.dockPort to robots.dockPort;
    }

    package Requirements {

        requirement def AutonomousNavigationReq {
            subject robot : MobileRobot;
            doc /* The robot shall autonomously navigate to assigned destinations using obstacle-free paths computed from Lidar scan data. */;
        }

        requirement def LowBatteryReturnReq {
            subject robot : MobileRobot;
            doc /* When the robot battery charge drops below 20 percent, the robot shall suspend its current task and navigate to the designated charging dock. */;
        }

        requirement def BatteryRechargeReq {
            subject robot : MobileRobot;
            doc /* The robot shall recharge at the charging dock until battery charge reaches 100 percent before resuming operations. */;
        }

        requirement def SafetyHaltReq {
            subject robot : MobileRobot;
            doc /* Upon detection of a system fault, the robot shall enter an error state and halt all motion immediately. */;
        }

        requirement def TaskDispatchReq {
            subject controller : MissionController;
            doc /* The mission controller shall maintain a queue of work tasks and dispatch them to available idle robots. */;
        }

        requirement def RobotMonitoringReq {
            subject controller : MissionController;
            doc /* The mission controller shall monitor the status of each robot to ensure tasks are completed successfully. */;
        }

        requirement def ObstacleDetectionReq {
            subject lidar : Components::LidarSensor;
            doc /* The Lidar sensor shall continuously scan the environment to detect obstacles and determine robot position and orientation. */;
        }

        requirement def PathPlanningReq {
            subject planner : Components::PathPlanner;
            doc /* The path planner shall calculate the most efficient obstacle-free route to the target location. */;
        }

        requirement def MotionControlReq {
            subject controller : Components::MotionController;
            doc /* The motion controller shall execute the planned path by controlling the robot linear and angular velocity. */;
        }

        requirement def RobotStatesReq {
            subject robot : MobileRobot;
            doc /* The robot shall operate in one of the following states: idle, navigating, executing task, returning to base, charging, or error. */;
        }

        requirement def BatteryMonitoringReq {
            subject battery : Components::BatterySystem;
            doc /* The robot shall intelligently monitor its battery charge level and trigger self-preservation behavior when charge drops below the critical threshold. */;
        }

        requirement autonomousNav : AutonomousNavigationReq;
        requirement lowBatteryReturn : LowBatteryReturnReq;
        requirement batteryRecharge : BatteryRechargeReq;
        requirement safetyHalt : SafetyHaltReq;
        requirement taskDispatch : TaskDispatchReq;
        requirement robotMonitoring : RobotMonitoringReq;
        requirement obstacleDetection : ObstacleDetectionReq;
        requirement pathPlanning : PathPlanningReq;
        requirement motionControl : MotionControlReq;
        requirement robotStates : RobotStatesReq;
        requirement batteryMonitoring : BatteryMonitoringReq;
    }

    package Satisfaction {
        satisfy Requirements::autonomousNav by MobileRobot::robotBehavior;
        satisfy Requirements::lowBatteryReturn by MobileRobot::robotBehavior;
        satisfy Requirements::batteryRecharge by MobileRobot::robotBehavior;
        satisfy Requirements::safetyHalt by MobileRobot::robotBehavior;
        satisfy Requirements::taskDispatch by MissionController::dispatchTask;
        satisfy Requirements::robotMonitoring by MissionController::monitorRobots;
        satisfy Requirements::obstacleDetection by Components::LidarSensor::scan;
        satisfy Requirements::pathPlanning by Components::PathPlanner::planPath;
        satisfy Requirements::motionControl by Components::MotionController::executePath;
        satisfy Requirements::robotStates by MobileRobot::robotBehavior;
        satisfy Requirements::batteryMonitoring by Components::BatterySystem::monitorCharge;
    }
}
