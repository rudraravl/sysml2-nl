package RoboticPrimaryTaskSystem {
    import ScalarValues::*;

    enum def UnitSymbol {
        enum m;
        enum s;
        enum kg;
        enum deg;
        enum V;
        enum A;
        enum W;
        enum Wh;
        enum N;
        enum Nm;
        enum mps;
        enum radps;
        enum percent;
        enum C;
        enum bitps;
        enum lx;
        enum count;
    }

    enum def TaskKind {
        enum inspect;
        enum pickAndPlace;
        enum transport;
        enum dock;
        enum standby;
    }

    enum def HealthState {
        enum nominal;
        enum degraded;
        enum faulted;
        enum emergencyStop;
    }

    enum def CompletionState {
        enum notStarted;
        enum running;
        enum completed;
        enum failed;
        enum aborted;
    }

    attribute def Quantity {
        attribute magnitude : Real;
        attribute unit : UnitSymbol;
    }

    attribute def Length :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::m;
    }

    attribute def Duration :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::s;
    }

    attribute def Mass :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::kg;
    }

    attribute def Angle :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::deg;
    }

    attribute def Voltage :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::V;
    }

    attribute def Current :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::A;
    }

    attribute def Power :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::W;
    }

    attribute def Energy :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::Wh;
    }

    attribute def Force :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::N;
    }

    attribute def Torque :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::Nm;
    }

    attribute def LinearSpeed :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::mps;
    }

    attribute def AngularSpeed :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::radps;
    }

    attribute def Percentage :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::percent;
    }

    attribute def Temperature :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::C;
    }

    attribute def DataRate :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::bitps;
    }

    attribute def Illuminance :> Quantity {
        attribute unit : UnitSymbol = UnitSymbol::lx;
    }

    attribute def Position3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    attribute def Orientation3D {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    attribute def Pose3D {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
    }

    attribute def BoundingBox {
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def MissionCommand {
        attribute commandId : String;
        attribute taskKind : TaskKind;
        attribute targetPose : Pose3D;
        attribute maximumDuration : Duration;
        attribute requiredPayloadMass : Mass;
        attribute operatorAuthorization : Boolean;
    }

    item def MotionCommand {
        attribute targetPose : Pose3D;
        attribute maximumLinearSpeed : LinearSpeed;
        attribute maximumAngularSpeed : AngularSpeed;
        attribute pathTolerance : Length;
    }

    item def ManipulatorCommand {
        attribute gripperForce : Force;
        attribute wristTorqueLimit : Torque;
        attribute targetPose : Pose3D;
        attribute payloadExpected : Boolean;
    }

    item def SensorFrame {
        attribute frameId : String;
        attribute timestamp : Duration;
        attribute robotPose : Pose3D;
        attribute obstacleCount : Integer;
        attribute minimumObstacleRange : Length;
        attribute illumination : Illuminance;
    }

    item def MapData {
        attribute mapId : String;
        attribute resolution : Length;
        attribute knownFreeArea : Quantity;
        attribute obstacleCount : Integer;
        attribute lastUpdated : Duration;
    }

    item def RobotStatus {
        attribute health : HealthState;
        attribute taskState : CompletionState;
        attribute batteryStateOfCharge : Percentage;
        attribute pose : Pose3D;
        attribute activeFaultCode : String;
        attribute primaryTaskExecutor : Boolean;
    }

    item def TaskReport {
        attribute commandId : String;
        attribute finalState : CompletionState;
        attribute completionTime : Duration;
        attribute finalPose : Pose3D;
        attribute payloadHandled : Boolean;
        attribute anomaliesDetected : Integer;
        attribute robotUsed : Boolean;
    }

    port def MissionCommandInputPort {
        in item command : MissionCommand;
    }

    port def MissionCommandOutputPort {
        out item command : MissionCommand;
    }

    port def MotionCommandInputPort {
        in item command : MotionCommand;
    }

    port def MotionCommandOutputPort {
        out item command : MotionCommand;
    }

    port def ManipulatorCommandInputPort {
        in item command : ManipulatorCommand;
    }

    port def ManipulatorCommandOutputPort {
        out item command : ManipulatorCommand;
    }

    port def StatusInputPort {
        in item status : RobotStatus;
    }

    port def StatusOutputPort {
        out item status : RobotStatus;
    }

    port def ReportInputPort {
        in item report : TaskReport;
    }

    port def ReportOutputPort {
        out item report : TaskReport;
    }

    port def ElectricalPowerInputPort {
        in item power : ElectricalPower;
    }

    port def ElectricalPowerOutputPort {
        out item power : ElectricalPower;
    }

    port def SensorFrameInputPort {
        in item frame : SensorFrame;
    }

    port def SensorFrameOutputPort {
        out item frame : SensorFrame;
    }

    port def MapInputPort {
        in item map : MapData;
    }

    port def MapOutputPort {
        out item map : MapData;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage;
        attribute capacity : Energy;
        attribute stateOfCharge : Percentage;
        attribute maximumDischargePower : Power;
        attribute temperature : Temperature;

        port powerOut : ElectricalPowerOutputPort;
        port statusOut : StatusOutputPort;

        action def SupplyElectricalPower {
            out item power : ElectricalPower;
        }

        action def MonitorBattery {
            out item status : RobotStatus;
        }

        perform action supplyPower : SupplyElectricalPower;
        perform action monitorBattery : MonitorBattery;
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : Voltage;
        attribute regulatedBusVoltage : Voltage;
        attribute maximumOutputPower : Power;
        attribute efficiency : Percentage;

        port batteryPowerIn : ElectricalPowerInputPort;
        port controllerPowerOut : ElectricalPowerOutputPort;
        port drivePowerOut : ElectricalPowerOutputPort;
        port manipulatorPowerOut : ElectricalPowerOutputPort;
        port sensorPowerOut : ElectricalPowerOutputPort;
    }

    part def RobotController {
        attribute processorLoad : Percentage;
        attribute controlCycleTime : Duration;
        attribute commandTimeout : Duration;
        attribute safeStopRequested : Boolean;

        port missionCommandIn : MissionCommandInputPort;
        port mapIn : MapInputPort;
        port sensorIn : SensorFrameInputPort;
        port motionCommandOut : MotionCommandOutputPort;
        port manipulatorCommandOut : ManipulatorCommandOutputPort;
        port statusOut : StatusOutputPort;
        port reportOut : ReportOutputPort;
        port powerIn : ElectricalPowerInputPort;

        action def PlanTask {
            in item command : MissionCommand;
            in item map : MapData;
            out item motion : MotionCommand;
            out item manipulation : ManipulatorCommand;
        }

        action def AssessSafety {
            in item frame : SensorFrame;
            out item status : RobotStatus;
        }

        action def GenerateTaskReport {
            in item status : RobotStatus;
            out item report : TaskReport;
        }

        perform action planTask : PlanTask;
        perform action assessSafety : AssessSafety;
        perform action generateReport : GenerateTaskReport;
    }

    part def PerceptionSubsystem {
        attribute cameraFieldOfView : Angle;
        attribute lidarRange : Length;
        attribute frameRate : Quantity;
        attribute minimumDetectableObstacle : Length;

        port powerIn : ElectricalPowerInputPort;
        port frameOut : SensorFrameOutputPort;
        port statusOut : StatusOutputPort;

        action def AcquireSensorFrame {
            out item frame : SensorFrame;
        }

        action def DetectObstacles {
            in item frame : SensorFrame;
            out item annotatedFrame : SensorFrame;
        }

        perform action acquireFrame : AcquireSensorFrame;
        perform action detectObstacles : DetectObstacles;
    }

    part def MobilitySubsystem {
        attribute wheelBase : Length;
        attribute trackWidth : Length;
        attribute maximumLinearSpeed : LinearSpeed;
        attribute maximumAngularSpeed : AngularSpeed;
        attribute maximumSlope : Angle;

        port powerIn : ElectricalPowerInputPort;
        port motionCommandIn : MotionCommandInputPort;
        port statusOut : StatusOutputPort;

        action def FollowTrajectory {
            in item command : MotionCommand;
            out item status : RobotStatus;
        }

        action def HoldPosition {
            out item status : RobotStatus;
        }

        perform action followTrajectory : FollowTrajectory;
        perform action holdPosition : HoldPosition;
    }

    part def ManipulatorSubsystem {
        attribute degreesOfFreedom : Integer;
        attribute reach : Length;
        attribute payloadCapacity : Mass;
        attribute maximumGripForce : Force;
        attribute repeatability : Length;

        port powerIn : ElectricalPowerInputPort;
        port manipulationCommandIn : ManipulatorCommandInputPort;
        port statusOut : StatusOutputPort;

        action def ExecuteManipulation {
            in item command : ManipulatorCommand;
            out item status : RobotStatus;
        }

        action def ReleasePayload {
            out item status : RobotStatus;
        }

        perform action executeManipulation : ExecuteManipulation;
        perform action releasePayload : ReleasePayload;
    }

    part def CommunicationSubsystem {
        attribute uplinkDataRate : DataRate;
        attribute downlinkDataRate : DataRate;
        attribute maximumRange : Length;
        attribute encryptionEnabled : Boolean;

        port commandIn : MissionCommandInputPort;
        port commandOut : MissionCommandOutputPort;
        port statusIn : StatusInputPort;
        port reportIn : ReportInputPort;
        port statusOut : StatusOutputPort;
        port reportOut : ReportOutputPort;
        port powerIn : ElectricalPowerInputPort;

        action def ReceiveMissionCommand {
            in item command : MissionCommand;
            out item forwardedCommand : MissionCommand;
        }

        action def TransmitStatusAndReport {
            in item status : RobotStatus;
            in item report : TaskReport;
        }

        perform action receiveMissionCommand : ReceiveMissionCommand;
        perform action transmitStatusAndReport : TransmitStatusAndReport;
    }

    action def PerformPrimaryTask {
        in item command : MissionCommand;
        in item map : MapData;
        out item report : TaskReport;

        action receiveCommand;
        action perceiveWorkspace;
        action planRobotMotion;
        action moveRobotToTarget;
        action executeRobotManipulation;
        action verifyTaskCompletion;
        action publishReport;

        first receiveCommand;
        then perceiveWorkspace;
        then planRobotMotion;
        then moveRobotToTarget;
        then executeRobotManipulation;
        then verifyTaskCompletion;
        then publishReport;
    }

    action def EnterSafeStop {
        in item currentStatus : RobotStatus;
        out item stoppedStatus : RobotStatus;

        action stopMobility;
        action holdManipulator;
        action notifyOperator;

        first stopMobility;
        then holdManipulator;
        then notifyOperator;
    }

    state def RobotOperatingStates {
        state poweredOff;
        state booting;
        state standby;
        state executingPrimaryTask;
        state safeStop;
        state charging;
        state faulted;

        transition initialToPoweredOff first poweredOff;
        transition powerOn first poweredOff then booting;
        transition bootComplete first booting then standby;
        transition commandAccepted first standby then executingPrimaryTask;
        transition taskComplete first executingPrimaryTask then standby;
        transition lowBattery first standby then charging;
        transition chargeComplete first charging then standby;
        transition hazardDetected first executingPrimaryTask then safeStop;
        transition faultDetected first standby then faulted;
        transition executionFault first executingPrimaryTask then faulted;
        transition resetFault first faulted then standby;
    }

    part def Robot {
        attribute robotId : String;
        attribute isPrimaryTaskExecutor : Boolean = true;
        attribute maximumOperatingDuration : Duration;
        attribute mass : Mass;
        attribute envelope : BoundingBox;
        attribute health : HealthState;
        attribute currentTaskState : CompletionState;
        attribute primaryTaskCompletion : CompletionState;

        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part controller : RobotController;
        part perception : PerceptionSubsystem;
        part mobility : MobilitySubsystem;
        part manipulator : ManipulatorSubsystem;
        part communications : CommunicationSubsystem;

        port commandIn : MissionCommandInputPort;
        port mapIn : MapInputPort;
        port statusOut : StatusOutputPort;
        port reportOut : ReportOutputPort;
        port externalPowerIn : ElectricalPowerInputPort;

        connect battery.powerOut to powerDistribution.batteryPowerIn;
        connect powerDistribution.controllerPowerOut to controller.powerIn;
        connect powerDistribution.drivePowerOut to mobility.powerIn;
        connect powerDistribution.manipulatorPowerOut to manipulator.powerIn;
        connect powerDistribution.sensorPowerOut to perception.powerIn;
        connect commandIn to communications.commandIn;
        connect communications.commandOut to controller.missionCommandIn;
        connect mapIn to controller.mapIn;
        connect perception.frameOut to controller.sensorIn;
        connect controller.motionCommandOut to mobility.motionCommandIn;
        connect controller.manipulatorCommandOut to manipulator.manipulationCommandIn;
        connect controller.statusOut to communications.statusIn;
        connect controller.reportOut to communications.reportIn;
        connect communications.statusOut to statusOut;
        connect communications.reportOut to reportOut;

        exhibit state operatingStates : RobotOperatingStates;

        perform action primaryTask : PerformPrimaryTask;
        perform action safeStop : EnterSafeStop;
    }

    part def OperatorStation {
        attribute operatorId : String;
        attribute authorized : Boolean;
        attribute displayUpdatePeriod : Duration;

        port commandOut : MissionCommandOutputPort;
        port statusIn : StatusInputPort;
        port reportIn : ReportInputPort;

        action def AuthorizeMission {
            out item command : MissionCommand;
        }

        action def DisplayRobotStatus {
            in item status : RobotStatus;
        }

        action def ArchiveTaskReport {
            in item report : TaskReport;
        }

        perform action authorizeMission : AuthorizeMission;
        perform action displayStatus : DisplayRobotStatus;
        perform action archiveReport : ArchiveTaskReport;
    }

    part def Workspace {
        attribute workspaceId : String;
        attribute size : BoundingBox;
        attribute ambientTemperature : Temperature;
        attribute minimumAisleWidth : Length;
        attribute fixedObstacleCount : Integer;

        port mapOut : MapOutputPort;

        action def ProvideWorkspaceMap {
            out item map : MapData;
        }

        perform action provideMap : ProvideWorkspaceMap;
    }

    part def ChargingDock {
        attribute dockId : String;
        attribute outputVoltage : Voltage;
        attribute maximumChargePower : Power;
        attribute alignmentTolerance : Length;

        port powerOut : ElectricalPowerOutputPort;
        port statusOut : StatusOutputPort;

        action def ChargeRobotBattery {
            out item power : ElectricalPower;
        }

        perform action chargeRobot : ChargeRobotBattery;
    }

    part def RoboticSystem {
        attribute systemId : String;
        attribute primaryTaskKind : TaskKind = TaskKind::pickAndPlace;
        attribute primaryTaskCompleted : Boolean = false;
        attribute allowableTaskDuration : Duration;
        attribute minimumBatteryReserve : Percentage;

        part robot : Robot;
        part operatorStation : OperatorStation;
        part workspace : Workspace;
        part chargingDock : ChargingDock;

        port externalCommandIn : MissionCommandInputPort;
        port systemStatusOut : StatusOutputPort;
        port systemReportOut : ReportOutputPort;

        connect operatorStation.commandOut to robot.commandIn;
        connect externalCommandIn to robot.commandIn;
        connect workspace.mapOut to robot.mapIn;
        connect robot.statusOut to operatorStation.statusIn;
        connect robot.reportOut to operatorStation.reportIn;
        connect robot.statusOut to systemStatusOut;
        connect robot.reportOut to systemReportOut;
        connect chargingDock.powerOut to robot.externalPowerIn;

        perform action mission : PerformPrimaryTask;
    }

    constraint def BatteryReserveConstraint {
        in currentCharge : Percentage;
        in reserveCharge : Percentage;

        constraint reserveMaintained {
            currentCharge.magnitude >= reserveCharge.magnitude
        }
    }

    constraint def TaskDurationConstraint {
        in actualDuration : Duration;
        in allowedDuration : Duration;

        constraint withinAllowedDuration {
            actualDuration.magnitude <= allowedDuration.magnitude
        }
    }

    constraint def RobotPayloadConstraint {
        in requestedPayload : Mass;
        in robotPayloadCapacity : Mass;

        constraint payloadWithinCapacity {
            requestedPayload.magnitude <= robotPayloadCapacity.magnitude
        }
    }

    requirement def PrimaryTaskUsesRobotRequirement {
        subject system : RoboticSystem;

        require constraint robotIsExecutor {
            system.robot.isPrimaryTaskExecutor == true
        }
    }

    requirement def PrimaryTaskCompletionRequirement {
        subject system : RoboticSystem;

        require constraint primaryTaskCompleted {
            system.primaryTaskCompleted == true
        }
    }

    requirement def OperatorAuthorizationRequirement {
        subject command : MissionCommand;

        require constraint operatorAuthorized {
            command.operatorAuthorization == true
        }
    }

    requirement def RobotStatusReportingRequirement {
        subject robot : Robot;

        require constraint robotReportsTaskState {
            robot.currentTaskState != CompletionState::notStarted
        }
    }

    requirement def SafeStopRequirement {
        subject robot : Robot;

        require constraint safeStopAvailable {
            robot.health != HealthState::emergencyStop
        }
    }

    requirement def PayloadCapabilityRequirement {
        subject robot : Robot;

        require constraint payloadCapacityPositive {
            robot.manipulator.payloadCapacity.magnitude > 0.0
        }
    }

    part roboticSystem : RoboticSystem {
        attribute systemId = "RPS-001";
        attribute primaryTaskKind = TaskKind::pickAndPlace;
        attribute primaryTaskCompleted = true;

        part robot {
            attribute robotId = "Robot-Primary-01";
            attribute isPrimaryTaskExecutor = true;
            attribute health = HealthState::nominal;
            attribute currentTaskState = CompletionState::completed;
            attribute primaryTaskCompletion = CompletionState::completed;
        }

        part operatorStation {
            attribute operatorId = "Operator-A";
            attribute authorized = true;
        }

        part workspace {
            attribute workspaceId = "Cell-A";
            attribute fixedObstacleCount = 6;
        }

        part chargingDock {
            attribute dockId = "Dock-01";
        }
    }

    requirement primaryTaskUsesRobot : PrimaryTaskUsesRobotRequirement {
        subject system = roboticSystem;
    }

    requirement primaryTaskCompletion : PrimaryTaskCompletionRequirement {
        subject system = roboticSystem;
    }

    requirement robotReportsStatus : RobotStatusReportingRequirement {
        subject robot = roboticSystem.robot;
    }

    requirement robotPayloadCapability : PayloadCapabilityRequirement {
        subject robot = roboticSystem.robot;
    }
}
