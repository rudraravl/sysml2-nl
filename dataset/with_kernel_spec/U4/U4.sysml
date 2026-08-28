package AutonomousGroundRobot {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    attribute def LocationValue {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    attribute def BatteryLevel {
        attribute percent : Real;
    }

    attribute def Path {
        attribute waypoints : LocationValue[0..*];
    }

    item def TaskCommand {
        attribute taskType : String;
        attribute targetLocation : LocationValue;
    }

    item def EmergencySignal;
    item def ResetSignal;
    item def LowBatteryAlert;
    item def ChargeComplete;
    item def TaskComplete;
    item def ArrivedAtTarget;
    item def ArrivedAtCharger;
    item def PathPlanned;

    part def Chassis {
        attribute length : LengthValue = 0.8 [m];
        attribute mass : MassValue = 45 [kg];
    }

    part def Lidar {
        out port mapData;
    }

    part def Camera {
        out port visualData;
    }

    part def MotorController {
        in port cmdPort;
        in port pwrPort;
    }

    part def WheelAssembly {
        part controller : MotorController;
    }

    part def BatteryPack {
        attribute chargeLevel : Real = 100;
        out port pwrPort;
        out port statusPort;
    }

    part def CentralProcessingUnit {
        in port lidarPort;
        in port cameraPort;
        in port cmdPort;
        in port batteryPort;
        out port motorPort[4];
    }

    action def PlanPath {
        in targetLocation : LocationValue;
        out path : Path;
    }

    action def Navigate {
        in path : Path;
    }

    action def ExecuteTask {
        in taskType : String;
    }

    action def ChargeBattery {
    }

    action def HandleEmergency {
    }

    part def Robot {
        attribute currentTask : TaskCommand;
        attribute currentPath : Path;

        part chassis : Chassis;
        part lidar : Lidar;
        part camera : Camera;
        part wheels[4] : WheelAssembly;
        part battery : BatteryPack;
        part cpu : CentralProcessingUnit;

        connect lidar.mapData to cpu.lidarPort;
        connect camera.visualData to cpu.cameraPort;
        connect battery.statusPort to cpu.batteryPort;
        connect cpu.motorPort to wheels.controller.cmdPort;
        connect battery.pwrPort to wheels.controller.pwrPort;

        state RobotStates {
            entry; then standby;

            state standby;
            transition standby_to_planning
                first standby
                accept task : TaskCommand via cpu.cmdPort
                then planning;
            transition standby_to_emergency
                first standby
                accept emergency : EmergencySignal
                then emergencyState;

            state planning;
            transition planning_to_navigating
                first planning
                accept PathPlanned
                then navigating;
            transition planning_to_charger
                first planning
                accept lowBattery : LowBatteryAlert via battery.statusPort
                then navigateToCharger;
            transition planning_to_emergency
                first planning
                accept emergency : EmergencySignal
                then emergencyState;

            state navigating;
            transition navigating_to_executing
                first navigating
                accept ArrivedAtTarget
                then executing;
            transition navigating_to_charger
                first navigating
                accept lowBattery : LowBatteryAlert via battery.statusPort
                then navigateToCharger;
            transition navigating_to_emergency
                first navigating
                accept emergency : EmergencySignal
                then emergencyState;

            state executing;
            transition executing_to_standby
                first executing
                accept TaskComplete
                then standby;
            transition executing_to_charger
                first executing
                accept lowBattery : LowBatteryAlert via battery.statusPort
                then navigateToCharger;
            transition executing_to_emergency
                first executing
                accept emergency : EmergencySignal
                then emergencyState;

            state navigateToCharger;
            transition charger_to_charging
                first navigateToCharger
                accept ArrivedAtCharger
                then charging;
            transition charger_to_emergency
                first navigateToCharger
                accept emergency : EmergencySignal
                then emergencyState;

            state charging;
            transition charging_to_standby
                first charging
                accept ChargeComplete
                then standby;
            transition charging_to_emergency
                first charging
                accept emergency : EmergencySignal
                then emergencyState;

            state emergencyState;
            transition emergency_to_standby
                first emergencyState
                accept ResetSignal
                then standby;
        }
    }

    requirement def RobotRequirements {
        requirement ChassisSpec {
            subject robot : Robot;
            constraint { robot.chassis.length == 0.8 [m] }
            constraint { robot.chassis.mass == 45 [kg] }
        }
        requirement AutonomousNavigation {
            subject robot : Robot;
            doc /* The robot shall autonomously navigate to a target location while avoiding obstacles. */
        }
        requirement LowBatteryReturn {
            subject robot : Robot;
            doc /* If battery charge drops below 20%, the robot shall navigate to a charging station. */
        }
        requirement EmergencyHandling {
            subject robot : Robot;
            doc /* The robot shall enter an emergency state upon critical failure and await reset. */
        }
    }
}
