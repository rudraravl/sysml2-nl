package AutonomousRoboticVacuumCleaner {
    private import ScalarValues::*;

    value def BatteryPercent :> Real;
    value def DetectionRangeValue :> Real;
    value def BrushRotationalSpeed :> Real;
    value def FanSuctionPower :> Real;
    value def DirtLevelValue :> Real;
    value def DustbinCapacityValue :> Real;
    value def MotorCommandValue :> Real;

    attribute def StartCleaningSignal;
    attribute def UndockCompleteSignal;
    attribute def DockingCompleteSignal;
    attribute def BatteryFullSignal;
    attribute def ObstacleDetectedSignal;
    attribute def PathClearSignal;

    item def Dirt;
    item def Debris :> Dirt;

    action def MonitorBattery { out level : BatteryPercent; }
    action def DetectObstacles { out obstacleDetected : Boolean; }
    action def DetectDirt { out dirtLevel : DirtLevelValue; }
    action def AdjustCleaning {
        in dirtLevel : DirtLevelValue;
        out brushSpeed : BrushRotationalSpeed;
        out fanPower : FanSuctionPower;
    }
    action def Navigate {
        in obstacleDetected : Boolean;
        out leftMotorCmd : MotorCommandValue;
        out rightMotorCmd : MotorCommandValue;
    }
    action def Undock;
    action def ChangePath;
    action def LocateDock;
    action def NavigateToDock;
    action def Dock;
    action def StopCleaning;
    action def Recharge;

    action def CleanFloor {
        first start;
        then merge continueCleaning;
        then action monitorBattery : MonitorBattery { out level; }
        then action detectObstacles : DetectObstacles { out obstacleDetected; }
        then action detectDirt : DetectDirt { out dirtLevel; }
        then action adjustCleaning : AdjustCleaning {
            in dirtLevel = detectDirt.dirtLevel;
            out brushSpeed;
            out fanPower;
        }
        then action navigate : Navigate {
            in obstacleDetected = detectObstacles.obstacleDetected;
            out leftMotorCmd;
            out rightMotorCmd;
        }
        then decide;
            if monitorBattery.level < 20 then stopCleaning;
            if monitorBattery.level >= 20 then continueCleaning;
        action stopCleaning : StopCleaning;
        then done;
    }

    action def ReturnToDock {
        first start;
        then action locateDock : LocateDock;
        then action navigateToDock : NavigateToDock;
        then action dockAction : Dock;
        then done;
    }

    state def RobotLifecycle;

    part def RechargeableBattery {
        attribute level : BatteryPercent = 100;
        port powerOut { out attribute level : BatteryPercent; }
        port chargeIn { in attribute power : Real; }
    }

    part def RotatingBrush {
        attribute speed : BrushRotationalSpeed;
        port commandIn { in attribute speed : BrushRotationalSpeed; }
    }

    part def VacuumFan {
        attribute suctionPower : FanSuctionPower;
        port commandIn { in attribute power : FanSuctionPower; }
    }

    part def Dustbin {
        attribute capacity : DustbinCapacityValue = 500;
        attribute currentLoad : DirtLevelValue = 0;
    }

    part def WheelMotor {
        attribute speed : MotorCommandValue;
        port commandIn { in attribute command : MotorCommandValue; }
    }

    part def ObstacleSensor {
        attribute detectionRange : DetectionRangeValue = 15;
        port dataOut { out attribute obstacleDetected : Boolean; out attribute distance : DetectionRangeValue; }
    }

    part def DirtSensor {
        attribute dirtLevel : DirtLevelValue;
        port dataOut { out attribute dirtLevel : DirtLevelValue; }
    }

    part def NavigationController {
        port sensorIn { in attribute obstacleDetected : Boolean; in attribute distance : DetectionRangeValue; }
        port batteryIn { in attribute level : BatteryPercent; }
        port motorOut { out attribute command : MotorCommandValue; }
    }

    part def CleaningController {
        port dirtIn { in attribute dirtLevel : DirtLevelValue; }
        port brushOut { out attribute speed : BrushRotationalSpeed; }
        port fanOut { out attribute power : FanSuctionPower; }
    }

    part def ChargingDock {
        port dockInterface { in attribute dockingRequest : Boolean; out attribute docked : Boolean; out attribute chargingPower : Real; }
    }

    part def Robot {
        part battery : RechargeableBattery;
        part mainBrush : RotatingBrush;
        part sideBrushes[2] : RotatingBrush;
        part vacuumFan : VacuumFan;
        part dustbin : Dustbin;
        part wheelMotors[2] : WheelMotor;
        part obstacleSensors[6] : ObstacleSensor;
        part dirtSensor : DirtSensor;
        part navigationController : NavigationController;
        part cleaningController : CleaningController;

        port dockInterface { out attribute dockingRequest : Boolean; in attribute docked : Boolean; in attribute chargingPower : Real; }

        perform action 'clean floor' : CleanFloor;
        perform action 'return to dock' : ReturnToDock;

        connect battery.powerOut to navigationController.batteryIn;
        connect obstacleSensors.dataOut to navigationController.sensorIn;
        connect dirtSensor.dataOut to cleaningController.dirtIn;
        connect navigationController.motorOut to wheelMotors.commandIn;
        connect cleaningController.brushOut to mainBrush.commandIn;
        connect cleaningController.brushOut to sideBrushes.commandIn;
        connect cleaningController.fanOut to vacuumFan.commandIn;

        state 'robot lifecycle' : RobotLifecycle {
            entry; then idle;

            state idle;
            accept StartCleaningSignal
                then undocking;

            state undocking {
                do action undockAction : Undock;
            }
            accept UndockCompleteSignal
                then cleaning;

            state cleaning {
                do 'clean floor';
            }
            accept ObstacleDetectedSignal
                then avoiding;
            accept when battery.level < 20
                then returning;

            state avoiding {
                do action changePathAction : ChangePath;
            }
            accept PathClearSignal
                then cleaning;

            state returning {
                do 'return to dock';
            }
            accept DockingCompleteSignal
                then recharging;

            state recharging {
                do action rechargeAction : Recharge;
            }
            accept BatteryFullSignal
                then idle;
        }
    }

    part vacuumSystem {
        part robot : Robot;
        part chargingDock : ChargingDock;

        connect robot.dockInterface to chargingDock.dockInterface;
    }

    requirement def AutomatedCleaningRequirement {
        doc /* The robot shall autonomously remove dust and debris from indoor floor surfaces using a main brush, two side brushes, and a vacuum fan. */
        subject robot : Robot;
    }

    requirement def ObstacleAvoidanceRequirement {
        doc /* The robot shall be equipped with six obstacle sensors each capable of detecting objects within a 15 cm range. */
        subject robot : Robot;
    }

    requirement def LowBatteryReturnRequirement {
        doc /* When the battery level falls below 20 percent, the robot shall stop cleaning and return to the charging dock. */
        subject robot : Robot;
    }

    requirement def AutonomousOperationRequirement {
        doc /* The robot shall operate autonomously through idle, undocking, cleaning, avoiding, returning, and recharging states. */
        subject robot : Robot;
    }

    requirement def DirtAdaptiveCleaningRequirement {
        doc /* The cleaning controller shall adjust brush speed and suction power based on feedback from the dirt sensor. */
        subject robot : Robot;
    }

    requirement def DustbinCapacityRequirement {
        doc /* The robot shall contain a dustbin with a fixed capacity for collecting dirt and debris. */
        subject robot : Robot;
    }

    requirement automatedCleaningReq : AutomatedCleaningRequirement;
    requirement obstacleAvoidanceReq : ObstacleAvoidanceRequirement;
    requirement lowBatteryReturnReq : LowBatteryReturnRequirement;
    requirement autonomousOperationReq : AutonomousOperationRequirement;
    requirement dirtAdaptiveCleaningReq : DirtAdaptiveCleaningRequirement;
    requirement dustbinCapacityReq : DustbinCapacityRequirement;
}
