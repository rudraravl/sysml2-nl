package AutonomousMobileRobotSystem {
    attribute def Coordinates {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
    }

    item def TaskCommand {
        attribute priority : ScalarValues::Integer;
        attribute targetLocation : Coordinates;
    }

    item def TaskReport {
        attribute missionId : ScalarValues::String;
        attribute success : ScalarValues::Boolean;
        attribute details : ScalarValues::String;
    }

    item def SensorData {
        attribute distance : ISQ::LengthValue;
        attribute obstacleDetected : ScalarValues::Boolean;
    }

    item def PathPlan {
        attribute pathLength : ISQ::LengthValue;
        attribute estimatedTime : ISQ::DurationValue;
    }

    item def OperationResult {
        attribute executed : ScalarValues::Boolean;
        attribute measurement : ISQ::LengthValue;
    }

    item def MaintenanceStartSig;
    item def MaintenanceCompleteSig;
    item def FaultSig;
    item def FaultResetSig;

    port def CommandSendPort {
        out command : TaskCommand;
        in report : TaskReport;
        out maintenanceStart : MaintenanceStartSig;
        out maintenanceComplete : MaintenanceCompleteSig;
        out fault : FaultSig;
        out faultReset : FaultResetSig;
    }

    port def CommandReceivePort {
        in command : TaskCommand;
        out report : TaskReport;
        in maintenanceStart : MaintenanceStartSig;
        in maintenanceComplete : MaintenanceCompleteSig;
        in fault : FaultSig;
        in faultReset : FaultResetSig;
    }

    port def PowerOutPort {
        out voltage : ISQ::ElectricPotentialValue;
    }

    port def PowerInPort {
        in voltage : ISQ::ElectricPotentialValue;
    }

    port def DataOutPort {
        out data : SensorData;
    }

    port def DataInPort {
        in data : SensorData;
    }

    action def ScanEnvironment {
        out sensorData : SensorData;
    }

    action def PlanPath {
        in sensorData : SensorData;
        in target : Coordinates;
        out pathPlan : PathPlan;
    }

    action def TravelToDestination {
        in pathPlan : PathPlan;
        out arrivalStatus : ScalarValues::Boolean;
    }

    action def ExecuteOperation {
        in target : Coordinates;
        out operationResult : OperationResult;
    }

    action def ValidateOperation {
        in operationResult : OperationResult;
        out validationStatus : ScalarValues::Boolean;
    }

    action def ReportOutcome {
        in validationStatus : ScalarValues::Boolean;
        out taskReport : TaskReport;
    }

    action def ManagePower {
        out voltage : ISQ::ElectricPotentialValue;
    }

    action def DispatchMission {
        out command : TaskCommand;
    }

    action def ExecuteMission {
        in taskCommand : TaskCommand;
        out taskReport : TaskReport;

        action scan : ScanEnvironment;
        action plan : PlanPath;
        action travel : TravelToDestination;
        action operate : ExecuteOperation;
        action validate : ValidateOperation;
        action report : ReportOutcome;

        bind plan.target = taskCommand.targetLocation;
        bind operate.target = taskCommand.targetLocation;
        flow from scan.sensorData to plan.sensorData;
        flow from plan.pathPlan to travel.pathPlan;
        flow from operate.operationResult to validate.operationResult;
        flow from validate.validationStatus to report.validationStatus;
        bind report.taskReport = taskReport;

        first scan;
        then plan;
        then travel;
        then operate;
        then validate;
        then report;
        then done;
    }

    part def SensorModule {
        attribute maxRange : ISQ::LengthValue = 50 [SI::m];
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
        perform action scan : ScanEnvironment;
    }

    part def NavigationModule {
        attribute maxSpeed : ISQ::SpeedValue = 3 [SI::m / SI::s];
        attribute positioningAccuracy : ISQ::LengthValue = 5 [SI::cm];
        port dataIn : DataInPort;
        port powerIn : PowerInPort;
        perform action planPath : PlanPath;
        perform action travel : TravelToDestination;
    }

    part def OperationModule {
        attribute operationalPrecision : ISQ::LengthValue = 1 [SI::cm];
        port powerIn : PowerInPort;
        perform action executeOp : ExecuteOperation;
        perform action validateOp : ValidateOperation;
    }

    part def CommunicationModule {
        attribute range : ISQ::LengthValue = 200 [SI::m];
        port commPort : CommandReceivePort;
        port powerIn : PowerInPort;
        perform action sendReport : ReportOutcome;
    }

    part def PowerModule {
        attribute batteryCapacity : ISQ::ElectricChargeValue = 1000 [SI::C];
        port powerOut : PowerOutPort;
        perform action managePower : ManagePower;
    }

    part def Robot {
        port commPort : CommandReceivePort;

        part sensorModule : SensorModule;
        part navigationModule : NavigationModule;
        part operationModule : OperationModule;
        part communicationModule : CommunicationModule;
        part powerModule : PowerModule;

        connect sensorModule.dataOut to navigationModule.dataIn;
        connect powerModule.powerOut to sensorModule.powerIn;
        connect powerModule.powerOut to navigationModule.powerIn;
        connect powerModule.powerOut to operationModule.powerIn;
        connect powerModule.powerOut to communicationModule.powerIn;
        connect commPort to communicationModule.commPort;

        perform action executeMission : ExecuteMission;

        state RobotBehavior {
            entry;
            then standby;
            state standby;
            transition first standby
                accept cmd : TaskCommand via commPort
                then active;
            state active {
                do executeMission;
            }
            transition first active then standby;
            state maintenance;
            transition first standby
                accept m : MaintenanceStartSig via commPort
                then maintenance;
            transition first maintenance
                accept m : MaintenanceCompleteSig via commPort
                then standby;
            state fault;
            transition first standby
                accept e : FaultSig via commPort
                then fault;
            transition first active
                accept e : FaultSig via commPort
                then fault;
            transition first maintenance
                accept e : FaultSig via commPort
                then fault;
            transition first fault
                accept r : FaultResetSig via commPort
                then maintenance;
        }
    }

    part def CentralControlStation {
        port commandPort : CommandSendPort;
        perform action dispatchMission : DispatchMission;
    }

    part autonomousRobotSystem {
        part controlStation : CentralControlStation;
        part robot : Robot;
        connect controlStation.commandPort to robot.commPort;
    }

    requirement Req_SensorRange {
        id = "REQ-001";
        text = "Sensor module shall scan environment up to 50 meters.";
    }
    satisfy Req_SensorRange by autonomousRobotSystem.robot.sensorModule;

    requirement Req_NavigationAccuracy {
        id = "REQ-002";
        text = "Navigation module shall operate at speeds up to 3 m/s with 5 cm positioning accuracy.";
    }
    satisfy Req_NavigationAccuracy by autonomousRobotSystem.robot.navigationModule;

    requirement Req_OperationPrecision {
        id = "REQ-003";
        text = "Operation module shall perform physical tasks with 1 cm precision.";
    }
    satisfy Req_OperationPrecision by autonomousRobotSystem.robot.operationModule;

    requirement Req_CommunicationRange {
        id = "REQ-004";
        text = "Communication module shall maintain link up to 200 meters.";
    }
    satisfy Req_CommunicationRange by autonomousRobotSystem.robot.communicationModule;

    requirement Req_OperationalModes {
        id = "REQ-005";
        text = "Robot shall operate in standby, active, maintenance, and fault modes.";
    }
    satisfy Req_OperationalModes by autonomousRobotSystem.robot.RobotBehavior;

    requirement Req_MissionSequence {
        id = "REQ-006";
        text = "Upon receiving a task command, the robot shall scan, plan, travel, operate, validate, and report before returning to standby.";
    }
    satisfy Req_MissionSequence by autonomousRobotSystem.robot.executeMission;
}
