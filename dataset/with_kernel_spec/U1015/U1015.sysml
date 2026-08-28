package RoboticCompanionSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    enum def TaskType {
        delivery;
        inspection;
        surveillance;
    }

    enum def Priority {
        low;
        medium;
        high;
    }

    attribute def Location {
        attribute x : Real;
        attribute y : Real;
        attribute z : Real;
    }

    attribute def TaskCommand {
        attribute taskType : TaskType;
        attribute priority : Priority;
        attribute targetLocation : Location;
    }

    attribute def TaskResult {
        attribute success : Boolean;
        attribute executionTime : Real;
    }

    attribute def SigCommandReceived;
    attribute def SigBatteryLow;
    attribute def SigBatteryOK;
    attribute def SigTargetReached;
    attribute def SigTaskComplete;
    attribute def SigArrivedAtBase;
    attribute def SigDocked;
    attribute def SigChargeComplete;

    port def CommandPort;
    port def ResultPort;
    port def PowerPort;
    port def BatteryMonitorPort;
    port def SensorDataPort;

    part def Battery {
        attribute chargeLevel : Real;
        attribute capacity : Real;
        port powerOut : PowerPort;
        port chargeIn : PowerPort;
        port monitor : BatteryMonitorPort;
    }

    abstract part def Sensor {
        port dataOut : SensorDataPort;
    }

    part def NavigationSensor :> Sensor;
    part def ObstacleSensor :> Sensor;

    abstract part def Actuator {
        port controlPort : PowerPort;
    }

    part def Motor :> Actuator;

    part def PowerManager {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port batteryMonitor : BatteryMonitorPort;
    }

    part def RobotController {
        port commandIn : CommandPort;
        port resultOut : ResultPort;
        port sensorInputs : SensorDataPort;
        port batteryMonitorIn : BatteryMonitorPort;

        attribute chargeLevel : Real;

        action executeMission {
            in command : TaskCommand;
            out result : TaskResult;
            first start;
            then action checkBattery;
            then if chargeLevel < 20 {
                action abortMission;
            } else {
                action navigate;
                then action performTask;
                then action returnToBase;
                then action reportResult;
            }
            then done;
        }

        state missionStates {
            entry; then idle;
            state idle;
            accept SigCommandReceived then checkBattery;
            accept SigDocked then charging;
            state checkBattery;
            accept SigBatteryLow then aborting;
            accept SigBatteryOK then navigating;
            state aborting;
            accept SigArrivedAtBase then idle;
            state navigating;
            accept SigTargetReached then performing;
            state performing;
            accept SigTaskComplete then returning;
            state returning;
            accept SigArrivedAtBase then idle;
            state charging;
            accept SigChargeComplete then idle;
        }
    }

    part def CompanionRobot {
        port taskCommandIn : CommandPort;
        port taskResultOut : ResultPort;
        port chargePort : PowerPort;

        part controller : RobotController;
        part battery : Battery;
        part powerManager : PowerManager;
        part motors : Motor[4];
        part navSensor : NavigationSensor;
        part obsSensor : ObstacleSensor;

        connect taskCommandIn to controller.commandIn;
        connect controller.resultOut to taskResultOut;
        connect battery.powerOut to powerManager.powerIn;
        connect powerManager.powerOut to motors.controlPort;
        connect battery.monitor to powerManager.batteryMonitor;
        connect powerManager.batteryMonitor to controller.batteryMonitorIn;
        connect navSensor.dataOut to controller.sensorInputs;
        connect obsSensor.dataOut to controller.sensorInputs;
        connect chargePort to battery.chargeIn;
    }

    part def MainController {
        port taskOut : CommandPort;
        port resultIn : ResultPort;

        action dispatchTask {
            out command : TaskCommand;
            first start;
            then action generateCommand;
            then done;
        }

        action receiveResult {
            in result : TaskResult;
            first start;
            then action logResult;
            then done;
        }
    }

    part def ChargingStation {
        port powerOutlet : PowerPort;

        action supplyCharge {
            first start;
            then action providePower;
            then done;
        }
    }

    part roboticCompanionSystem {
        part mainController : MainController;
        part companionRobot : CompanionRobot;
        part chargingStation : ChargingStation;

        connect mainController.taskOut to companionRobot.taskCommandIn;
        connect companionRobot.taskResultOut to mainController.resultIn;
        connect chargingStation.powerOutlet to companionRobot.chargePort;
    }

    requirement def TaskExecutionRequirement {
        doc /* The system shall successfully execute delegated tasks and report results including success status and execution time to the main controller. */
    }

    requirement def BatteryManagementRequirement {
        doc /* The companion robot shall monitor its battery level and abort missions if charge falls below 20 percent to ensure safe return. */
    }

    requirement def AutonomousOperationRequirement {
        doc /* The system shall operate autonomously to perform assigned tasks including delivery inspection and surveillance without human intervention. */
    }

    requirement def ObstacleAvoidanceRequirement {
        doc /* The companion robot shall use its sensors to detect and avoid obstacles during navigation. */
    }

    requirement taskExecution : TaskExecutionRequirement;
    requirement batteryManagement : BatteryManagementRequirement;
    requirement autonomousOperation : AutonomousOperationRequirement;
    requirement obstacleAvoidance : ObstacleAvoidanceRequirement;

    satisfy taskExecution by roboticCompanionSystem.companionRobot;
    satisfy batteryManagement by roboticCompanionSystem.companionRobot;
    satisfy autonomousOperation by roboticCompanionSystem;
    satisfy obstacleAvoidance by roboticCompanionSystem.companionRobot;
}
