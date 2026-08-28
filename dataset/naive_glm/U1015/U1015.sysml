package RoboticCompanionSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----

    value def BatteryLevel :> Real {
        unit %;
    }

    value def Distance :> Real {
        unit m;
    }

    value def Speed :> Real {
        unit 'm/s';
    }

    value def TimeDuration :> Real {
        unit s;
    }

    value def Power :> Real {
        unit W;
    }

    value def Coordinate :> Real {
        unit m;
    }

    // ---- Enumerations ----

    enum def TaskType {
        delivery;
        inspection;
        surveillance;
    }

    enum def PriorityLevel {
        low;
        medium;
        high;
    }

    enum def RobotState {
        idle;
        checkingBattery;
        navigating;
        performingTask;
        returning;
        charging;
        aborted;
    }

    enum def NavigationStatus {
        inProgress;
        arrived;
        blocked;
    }

    // ---- Item Definitions ----

    item def TaskCommand {
        attribute taskType : TaskType;
        attribute priority : PriorityLevel;
        attribute targetLocationX : Coordinate;
        attribute targetLocationY : Coordinate;
    }

    item def TaskResult {
        attribute success : Boolean;
        attribute executionTime : TimeDuration;
        attribute taskType : TaskType;
    }

    item def SensorReading {
        attribute positionX : Coordinate;
        attribute positionY : Coordinate;
        attribute batteryLevel : BatteryLevel;
        attribute obstacleDetected : Boolean;
        attribute obstacleDistance : Distance;
    }

    item def BatteryStatus {
        attribute currentLevel : BatteryLevel;
        attribute charging : Boolean;
    }

    item def NavigationCommand {
        attribute targetX : Coordinate;
        attribute targetY : Coordinate;
        attribute speed : Speed;
    }

    item def ChargeCommand {
        attribute requestedLevel : BatteryLevel;
    }

    // ---- Interfaces ----

    interface def CommandInterface {
        end commandPort : TaskCommand;
    }

    interface def ResultInterface {
        end resultPort : TaskResult;
    }

    interface def SensorDataInterface {
        end sensorPort : SensorReading;
    }

    interface def NavigationInterface {
        end navPort : NavigationCommand;
    }

    interface def ChargingInterface {
        end chargePort : ChargeCommand;
        end batteryFeedback : BatteryStatus;
    }

    // ---- Requirements ----

    requirement def TaskExecutionRequirement {
        attribute id : String = "REQ-001";
        doc /* The companion robot shall execute assigned tasks autonomously and report results. */
        subject robot : CompanionRobot;
        objective {
            doc /* Robot completes tasks and reports success and execution time. */
        }
    }

    requirement def BatteryManagementRequirement {
        attribute id : String = "REQ-002";
        doc /* The robot shall abort missions if battery level is below 20% to ensure safe return. */
        attribute minBatteryThreshold : BatteryLevel = 20.0;
        subject robot : CompanionRobot;
        objective {
            doc /* Robot checks battery before mission start and aborts if below threshold. */
        }
    }

    requirement def ChargingRequirement {
        attribute id : String = "REQ-003";
        doc /* The charging station shall recharge the robot battery to full capacity between tasks. */
        subject station : ChargingStation;
        objective {
            doc /* Station charges robot to at least 95% capacity. */
        }
    }

    requirement def ObstacleDetectionRequirement {
        attribute id : String = "REQ-004";
        doc /* The robot shall detect obstacles during navigation and adjust its path. */
        subject robot : CompanionRobot;
        objective {
            doc /* Robot avoids collisions using sensor data. */
        }
    }

    requirement def CommandDelegationRequirement {
        attribute id : String = "REQ-005";
        doc /* The main controller shall delegate high-level task commands to the robot and receive results. */
        subject controller : MainController;
        objective {
            doc /* Controller sends TaskCommand and receives TaskResult. */
        }
    }

    // ---- Parts ----

    part def Battery {
        attribute maxCapacity : BatteryLevel = 100.0;
        attribute currentLevel : BatteryLevel = 100.0;
        attribute charging : Boolean = false;

        action def discharge :> Action {
            in amount : BatteryLevel;
            then currentLevel = currentLevel - amount;
        }

        action def charge :> Action {
            in amount : BatteryLevel;
            then currentLevel = currentLevel + amount;
        }
    }

    part def Sensor {
        attribute sensorId : String;
        attribute active : Boolean = true;

        action def readSensor :> Action {
            out reading : SensorReading;
        }
    }

    part def Actuator {
        attribute actuatorId : String;
        attribute active : Boolean = true;

        action def actuate :> Action {
            in command : NavigationCommand;
        }
    }

    part def DriveSystem {
        part leftMotor : Actuator { actuatorId = "leftMotor"; }
        part rightMotor : Actuator { actuatorId = "rightMotor"; }
        attribute currentSpeed : Speed = 0.0;

        action def move :> Action {
            in navCmd : NavigationCommand;
            then currentSpeed = navCmd.speed;
        }

        action def stop :> Action {
            then currentSpeed = 0.0;
        }
    }

    part def RobotController {
        attribute state : RobotState = RobotState::idle;
        attribute currentTask : TaskCommand;

        action def processCommand :> Action {
            in cmd : TaskCommand;
            out result : TaskResult;
        }

        action def evaluateBattery :> Action {
            in level : BatteryLevel;
            out sufficient : Boolean;
            then sufficient = level >= 20.0;
        }

        action def executeTask :> Action {
            in task : TaskCommand;
            out success : Boolean;
            out execTime : TimeDuration;
        }
    }

    part def CompanionRobot {
        part battery : Battery;
        part frontCamera : Sensor { sensorId = "frontCamera"; }
        part lidar : Sensor { sensorId = "lidar"; }
        part bumperSensor : Sensor { sensorId = "bumper"; }
        part drive : DriveSystem;
        part controller : RobotController;

        port commandIn : TaskCommand;
        port resultOut : TaskResult;
        port sensorOut : SensorReading;
        port chargePort : ChargeCommand;
        port batteryFeedbackOut : BatteryStatus;

        attribute positionX : Coordinate = 0.0;
        attribute positionY : Coordinate = 0.0;
        attribute totalDistanceTraveled : Distance = 0.0;

        // State machine for robot operation
        state def RobotStateMachine {
            entry; then idle;

            state idle {
                entry { controller.state = RobotState::idle; }
            }

            state checkingBattery {
                entry { controller.state = RobotState::checkingBattery; }
            }

            state navigating {
                entry { controller.state = RobotState::navigating; }
            }

            state performingTask {
                entry { controller.state = RobotState::performingTask; }
            }

            state returning {
                entry { controller.state = RobotState::returning; }
            }

            state charging {
                entry { controller.state = RobotState::charging; }
            }

            state aborted {
                entry { controller.state = RobotState::aborted; }
            }

            transition idle_to_checkingBattery
                first idle
                then checkingBattery
                accept commandIn : TaskCommand;

            transition checkingBattery_to_navigating
                first checkingBattery
                then navigating
                when battery.currentLevel >= 20.0;

            transition checkingBattery_to_aborted
                first checkingBattery
                then aborted
                when battery.currentLevel < 20.0;

            transition navigating_to_performingTask
                first navigating
                then performingTask
                when positionX == controller.currentTask.targetLocationX
                    and positionY == controller.currentTask.targetLocationY;

            transition performingTask_to_returning
                first performingTask
                then returning
                after 60 [s];

            transition returning_to_idle
                first returning
                then idle
                when positionX == 0.0 and positionY == 0.0;

            transition aborted_to_idle
                first aborted
                then idle
                after 5 [s];

            transition idle_to_charging
                first idle
                then charging
                accept chargePort : ChargeCommand;

            transition charging_to_idle
                first charging
                then idle
                when battery.currentLevel >= 95.0;
        }

        state machine : RobotStateMachine;

        // Robot behaviors
        action def receiveCommand :> Action {
            in cmd : TaskCommand;
            then controller.currentTask = cmd;
            then commandIn = cmd;
        }

        action def navigateTo :> Action {
            in targetX : Coordinate;
            in targetY : Coordinate;
            in speed : Speed;
            then drive.move(NavigationCommand{targetX = targetX, targetY = targetY, speed = speed});
        }

        action def performInspection :> Action {
            out success : Boolean;
            out execTime : TimeDuration;
            then success = true;
            then execTime = 30.0;
        }

        action def performDelivery :> Action {
            out success : Boolean;
            out execTime : TimeDuration;
            then success = true;
            then execTime = 45.0;
        }

        action def performSurveillance :> Action {
            out success : Boolean;
            out execTime : TimeDuration;
            then success = true;
            then execTime = 120.0;
        }

        action def reportResult :> Action {
            in success : Boolean;
            in execTime : TimeDuration;
            out result : TaskResult;
            then result = TaskResult{success = success, executionTime = execTime, taskType = controller.currentTask.taskType};
            then resultOut = result;
        }

        action def monitorSensors :> Action {
            out reading : SensorReading;
            then frontCamera.readSensor(out reading);
            then lidar.readSensor(out reading);
            then sensorOut = reading;
        }

        satisfy TaskExecutionRequirement by robot;
        satisfy BatteryManagementRequirement by robot;
        satisfy ObstacleDetectionRequirement by robot;
    }

    part def MainController {
        port commandOut : TaskCommand;
        port resultIn : TaskResult;

        attribute pendingTasks : TaskCommand[0..*];
        attribute completedResults : TaskResult[0..*];

        action def receiveTask :> Action {
            in cmd : TaskCommand;
            then pendingTasks.append(cmd);
        }

        action def delegateTask :> Action {
            in cmd : TaskCommand;
            then commandOut = cmd;
        }

        action def receiveResult :> Action {
            in result : TaskResult;
            then completedResults.append(result);
        }

        action def manageTasks :> Action {
            then if pendingTasks.size() > 0 {
                delegateTask(pendingTasks.first());
                then pendingTasks.remove(0);
            }
        }

        satisfy CommandDelegationRequirement by controller;
    }

    part def ChargingStation {
        port chargeCmdIn : ChargeCommand;
        port batteryFeedbackIn : BatteryStatus;

        attribute maxOutputPower : Power = 50.0;
        attribute chargingActive : Boolean = false;
        attribute connectedRobotLevel : BatteryLevel = 0.0;

        action def startCharging :> Action {
            in cmd : ChargeCommand;
            then chargingActive = true;
        }

        action def stopCharging :> Action {
            then chargingActive = false;
        }

        action def supplyPower :> Action {
            out power : Power;
            then power = maxOutputPower;
        }

        action def monitorCharging :> Action {
            in status : BatteryStatus;
            then connectedRobotLevel = status.currentLevel;
            then if connectedRobotLevel >= 95.0 {
                stopCharging();
            }
        }

        satisfy ChargingRequirement by station;
    }

    // ---- System Assembly ----

    part def RoboticCompanionSystem {
        part mainController : MainController;
        part companionRobot : CompanionRobot;
        part chargingStation : ChargingStation;

        // Connections
        connection commandLink connect mainController.commandOut to companionRobot.commandIn;
        connection resultLink connect companionRobot.resultOut to mainController.resultIn;
        connection chargeLink connect companionRobot.chargePort to chargingStation.chargeCmdIn;
        connection batteryFeedbackLink connect companionRobot.batteryFeedbackOut to chargingStation.batteryFeedbackIn;

        // System-level requirement
        requirement SystemOperationalRequirement {
            doc /* The robotic companion system shall autonomously perform delivery, inspection, and surveillance tasks. */
            attribute id : String = "REQ-SYS-001";
            subject system : RoboticCompanionSystem;
            objective {
                doc /* System completes tasks with intelligent battery management and obstacle avoidance. */
            }
        }

        satisfy SystemOperationalRequirement by system;
    }

}
