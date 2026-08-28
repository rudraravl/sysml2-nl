package AutonomousMobileRobotSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;
    import MeasurementReferences::*;

    // ===== Value Types =====
    value type Distance :> Real { unit 'm'; }
    value type Speed :> Real { unit 'm/s'; }
    value type LinearPrecision :> Real { unit 'cm'; }
    value type BatteryLevel :> Real { unit '%'; }
    value type LinkRange :> Real { unit 'm'; }
    value type ScanFrequency :> Real { unit 'Hz'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }

    // ===== Enumerations =====
    enumeration PriorityLevel { low; medium; high; critical; }
    enumeration OperationType { pick; place; inspect; measure; }
    enumeration RobotMode { standby; active; maintenance; fault; }
    enumeration MissionPhase { idle; scanning; planning; traveling; operating; validating; reporting; done; }

    // ===== Item Definitions =====
    item def TaskCommand {
        attribute taskId : String;
        attribute priority : PriorityLevel;
        attribute targetLocation : String;
        attribute operation : OperationType;
    }

    item def TaskResult {
        attribute taskId : String;
        attribute success : Boolean;
        attribute detail : String;
    }

    item def SensorData {
        attribute obstacleDetected : Boolean;
        attribute distanceToObstacle : Distance;
        attribute environmentMap : String;
        attribute timestamp : String;
    }

    item def PathPlan {
        attribute pathId : String;
        attribute estimatedDistance : Distance;
        attribute estimatedDuration : Real;
        attribute waypoints : String;
    }

    item def OperationOutcome {
        attribute operation : OperationType;
        attribute success : Boolean;
        attribute measuredValue : Real;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute batteryLevel : BatteryLevel;
    }

    item def CommandMessage {
        attribute payload : TaskCommand;
    }

    item def ResultMessage {
        attribute payload : TaskResult;
    }

    // ===== Port Definitions =====
    port def CommandLink {
        in item command : TaskCommand;
        out item result : TaskResult;
    }

    port def SensorDataOut {
        out item data : SensorData;
    }

    port def SensorDataIn {
        in item data : SensorData;
    }

    port def PathPlanOut {
        out item plan : PathPlan;
    }

    port def PathPlanIn {
        in item plan : PathPlan;
    }

    port def OperationRequest {
        in item plan : PathPlan;
        in item operation : OperationType;
        out item outcome : OperationOutcome;
    }

    port def PowerDistribution {
        out item supply : PowerSupply;
    }

    port def PowerConsumption {
        in item supply : PowerSupply;
    }

    // ===== Requirements =====
    requirement def RobotSystemRequirement {
        doc "The autonomous mobile robotic system shall execute task commands received from the control station with specified priority and target location."
        subject system : AutonomousMobileRobotSystem;
        attribute supportedPriorities : PriorityLevel[4] = (PriorityLevel::low, PriorityLevel::medium, PriorityLevel::high, PriorityLevel::critical);
    }

    requirement def SensorRangeRequirement {
        doc "The sensor module shall scan the environment up to 50 meters."
        subject sensor : SensorModule;
        attribute maxRange : Distance = 50 [m];
    }

    requirement def NavigationSpeedRequirement {
        doc "The navigation module shall navigate autonomously at speeds up to 3 m/s."
        subject nav : NavigationModule;
        attribute maxSpeed : Speed = 3 [m/s];
    }

    requirement def NavigationAccuracyRequirement {
        doc "The navigation module shall position itself with an accuracy of 5 centimeters."
        subject nav : NavigationModule;
        attribute positionAccuracy : LinearPrecision = 5 [cm];
    }

    requirement def OperationPrecisionRequirement {
        doc "The operation module shall perform physical tasks with a precision of 1 centimeter."
        subject op : OperationModule;
        attribute operationPrecision : LinearPrecision = 1 [cm];
    }

    requirement def CommunicationRangeRequirement {
        doc "The communication module shall maintain a link with the control center over a range of 200 meters."
        subject comm : CommunicationModule;
        attribute commRange : LinkRange = 200 [m];
    }

    requirement def PowerManagementRequirement {
        doc "The power module shall supply electricity to all other components of the robot."
        subject power : PowerModule;
        attribute nominalVoltage : Voltage = 24 [V];
    }

    // ===== Part Definitions =====
    part def SensorModule {
        port sensorOut : SensorDataOut;
        port powerIn : PowerConsumption;

        attribute scanRange : Distance = 50 [m];
        attribute scanFrequency : ScanFrequency = 10 [Hz];
        attribute active : Boolean = true;

        action def ScanEnvironment {
            out data : SensorData;
            perform {
                data.obstacleDetected := false;
                data.distanceToObstacle := 50 [m];
                data.environmentMap := "local_map";
                data.timestamp := "now";
            }
        }
    }

    part def NavigationModule {
        port sensorIn : SensorDataIn;
        port pathOut : PathPlanOut;
        port powerIn : PowerConsumption;

        attribute maxSpeed : Speed = 3 [m/s];
        attribute positionAccuracy : LinearPrecision = 5 [cm];
        attribute currentLocation : String = "origin";
        attribute targetLocation : String;

        action def PlanPath {
            in sensorData : SensorData;
            out plan : PathPlan;
            perform {
                plan.pathId := "path_001";
                plan.estimatedDistance := 25 [m];
                plan.estimatedDuration := 10.0;
                plan.waypoints := "wp1;wp2;wp3";
            }
        }

        action def TravelToTarget {
            in plan : PathPlan;
            perform {
                currentLocation := targetLocation;
            }
        }
    }

    part def OperationModule {
        port opPort : OperationRequest;
        port powerIn : PowerConsumption;

        attribute operationPrecision : LinearPrecision = 1 [cm];
        attribute currentOperation : OperationType;

        action def ExecuteOperation {
            in operation : OperationType;
            out outcome : OperationOutcome;
            perform {
                outcome.operation := operation;
                outcome.success := true;
                outcome.measuredValue := 0.0;
            }
        }

        action def ValidateOperation {
            in outcome : OperationOutcome;
            out validated : Boolean;
            perform {
                validated := outcome.success;
            }
        }
    }

    part def CommunicationModule {
        port commLink : CommandLink;
        port powerIn : PowerConsumption;

        attribute commRange : LinkRange = 200 [m];
        attribute connected : Boolean = true;
        attribute signalStrength : Real = 1.0;

        action def ReceiveCommand {
            out command : TaskCommand;
            perform {
                command := commLink.command;
            }
        }

        action def ReportResult {
            in result : TaskResult;
            perform {
                commLink.result := result;
            }
        }
    }

    part def PowerModule {
        port powerOut : PowerDistribution;

        attribute batteryLevel : BatteryLevel = 100 [%];
        attribute nominalVoltage : Voltage = 24 [V];
        attribute maxCurrent : Current = 10 [A];
        attribute capacity : Real = 5000;

        action def SupplyPower {
            out supply : PowerSupply;
            perform {
                supply.voltage := nominalVoltage;
                supply.current := 2 [A];
                supply.batteryLevel := batteryLevel;
            }
        }

        action def MonitorBattery {
            perform {
                if batteryLevel < 20 [%] { batteryLevel := batteryLevel; }
            }
        }
    }

    part def Robot {
        port robotComm : CommandLink;

        attribute currentMode : RobotMode = RobotMode::standby;
        attribute currentPhase : MissionPhase = MissionPhase::idle;
        attribute currentTask : TaskCommand;
        attribute lastResult : TaskResult;
        attribute missionCount : Integer = 0;

        part sensor : SensorModule {
            port sensorOut : SensorDataOut;
            port powerIn : PowerConsumption;
        }
        part navigation : NavigationModule {
            port sensorIn : SensorDataIn;
            port pathOut : PathPlanOut;
            port powerIn : PowerConsumption;
        }
        part operation : OperationModule {
            port opPort : OperationRequest;
            port powerIn : PowerConsumption;
        }
        part communication : CommunicationModule {
            port commLink : CommandLink;
            port powerIn : PowerConsumption;
        }
        part power : PowerModule {
            port powerOut : PowerDistribution;
        }

        // Internal connections
        connection sensorToNav connect sensor.sensorOut.data to navigation.sensorIn.data;
        connection navToOp connect navigation.pathOut.plan to operation.opPort.plan;
        connection commInternal connect communication.commLink to robotComm;
        connection powerToSensor connect power.powerOut.supply to sensor.powerIn.supply;
        connection powerToNav connect power.powerOut.supply to navigation.powerIn.supply;
        connection powerToOp connect power.powerOut.supply to operation.powerIn.supply;
        connection powerToComm connect power.powerOut.supply to communication.powerIn.supply;

        action def ExecuteMission {
            in task : TaskCommand;
            out result : TaskResult;

            action scan : SensorModule::ScanEnvironment {
                out data;
            }
            then action plan : NavigationModule::PlanPath {
                in sensorData = scan.data;
                out plan;
            }
            then action travel : NavigationModule::TravelToTarget {
                in plan = plan.plan;
            }
            then action execute : OperationModule::ExecuteOperation {
                in operation = task.operation;
                out outcome;
            }
            then action validate : OperationModule::ValidateOperation {
                in outcome = execute.outcome;
                out validated;
            }
            then action report : CommunicationModule::ReportResult {
                in result;
            }
            then {
                result.taskId := task.taskId;
                result.success := validate.validated;
                result.detail := "Mission completed";
            }
        }

        state machine RobotStateMachine {
            entry { currentMode := RobotMode::standby; currentPhase := MissionPhase::idle; }

            state standby {
                entry { currentMode := RobotMode::standby; currentPhase := MissionPhase::idle; }
                transition standby_to_active first standby
                    if robotComm.command->notEmpty()
                    then active;
                transition standby_to_maintenance first standby
                    if power.batteryLevel < 20 [%]
                    then maintenance;
            }

            state active {
                entry {
                    currentMode := RobotMode::active;
                    currentTask := robotComm.command;
                    currentPhase := MissionPhase::scanning;
                    perform ExecuteMission(currentTask, lastResult);
                    missionCount := missionCount + 1;
                }
                transition active_to_standby first active
                    if lastResult.success == true
                    then standby;
                transition active_to_fault first active
                    if lastResult.success == false
                    then fault;
            }

            state maintenance {
                entry { currentMode := RobotMode::maintenance; currentPhase := MissionPhase::idle; }
                transition maintenance_to_standby first maintenance
                    if power.batteryLevel >= 80 [%]
                    then standby;
            }

            state fault {
                entry { currentMode := RobotMode::fault; currentPhase := MissionPhase::idle; }
                transition fault_to_maintenance first fault
                    if true
                    then maintenance;
            }
        }
    }

    part def ControlStation {
        port commandLink : CommandLink;
        attribute issuedCommands : Integer = 0;
        attribute receivedResults : Integer = 0;

        action def IssueCommand {
            in task : TaskCommand;
            perform {
                commandLink.command := task;
                issuedCommands := issuedCommands + 1;
            }
        }

        action def ReceiveResult {
            in result : TaskResult;
            perform {
                receivedResults := receivedResults + 1;
            }
        }

        state machine ControlStationBehavior {
            state idle {
                transition idle_to_dispatching first idle
                    if commandLink.command->notEmpty()
                    then dispatching;
            }
            state dispatching {
                entry { issuedCommands := issuedCommands + 1; }
                transition dispatching_to_idle first dispatching
                    if commandLink.result->notEmpty()
                    then idle;
            }
        }
    }

    // ===== Top-Level System =====
    part def AutonomousMobileRobotSystem {
        attribute systemName : String = "AutonomousMobileRobotSystem";
        attribute deploymentEnvironment : String = "factory_floor";

        part controlStation : ControlStation {
            port commandLink : CommandLink;
        }
        part robot : Robot {
            port robotComm : CommandLink;
        }

        connection controlToRobot connect controlStation.commandLink to robot.robotComm;

        satisfy RobotSystemRequirement by AutonomousMobileRobotSystem;
        satisfy SensorRangeRequirement by robot.sensor;
        satisfy NavigationSpeedRequirement by robot.navigation;
        satisfy NavigationAccuracyRequirement by robot.navigation;
        satisfy OperationPrecisionRequirement by robot.operation;
        satisfy CommunicationRangeRequirement by robot.communication;
        satisfy PowerManagementRequirement by robot.power;
    }
}
