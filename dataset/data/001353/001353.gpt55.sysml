package AutomatedHighwaySystemModel {

    import ScalarValues::*;

    attribute def Speed_kmPerHour :> Real {
        attribute unitSymbol : String = "km/h";
        attribute quantityKind : String = "speed";
    }

    attribute def Acceleration_mPerSecondSquared :> Real {
        attribute unitSymbol : String = "m/s^2";
        attribute quantityKind : String = "acceleration";
    }

    attribute def Distance_m :> Real {
        attribute unitSymbol : String = "m";
        attribute quantityKind : String = "distance";
    }

    attribute def Time_s :> Real {
        attribute unitSymbol : String = "s";
        attribute quantityKind : String = "time";
    }

    attribute def Time_min :> Real {
        attribute unitSymbol : String = "min";
        attribute quantityKind : String = "time";
    }

    attribute def Throughput_vehiclesPerHour :> Real {
        attribute unitSymbol : String = "vehicles/h";
        attribute quantityKind : String = "traffic throughput";
    }

    attribute def DataRate_Mbps :> Real {
        attribute unitSymbol : String = "Mb/s";
        attribute quantityKind : String = "data rate";
    }

    attribute def Availability_percent :> Real {
        attribute unitSymbol : String = "%";
        attribute quantityKind : String = "availability";
    }

    attribute def VehicleCount :> Integer {
        attribute unitSymbol : String = "vehicles";
        attribute quantityKind : String = "count";
    }

    enum def LaneStatusKind {
        enum open;
        enum controlled;
        enum restricted;
        enum closed;
        enum emergencyOnly;
    }

    enum def IncidentSeverityKind {
        enum none;
        enum minor;
        enum major;
        enum emergency;
    }

    enum def AutomationModeKind {
        enum manual;
        enum advisory;
        enum cooperativeAdaptiveCruise;
        enum fullyCoordinated;
        enum minimalRisk;
    }

    item def VehicleStateReport {
        attribute vehicleId : String;
        attribute timestamp : Time_s;
        attribute longitudinalPosition : Distance_m;
        attribute lateralOffset : Distance_m;
        attribute currentLaneIndex : Integer;
        attribute currentSpeed : Speed_kmPerHour;
        attribute currentAcceleration : Acceleration_mPerSecondSquared;
        attribute automationMode : AutomationModeKind;
        attribute brakingAvailable : Boolean;
        attribute steeringAvailable : Boolean;
        attribute communicationHealthy : Boolean;
    }

    item def VehicleControlCommand {
        attribute commandId : String;
        attribute targetVehicleId : String;
        attribute issueTime : Time_s;
        attribute targetSpeed : Speed_kmPerHour;
        attribute targetLaneIndex : Integer;
        attribute minimumTimeGap : Time_s;
        attribute maximumAcceleration : Acceleration_mPerSecondSquared;
        attribute maximumDeceleration : Acceleration_mPerSecondSquared;
        attribute validFor : Time_s;
        attribute modeRequest : AutomationModeKind;
    }

    item def RoadsideSensorObservation {
        attribute stationId : String;
        attribute observationTime : Time_s;
        attribute laneIndex : Integer;
        attribute meanSpeed : Speed_kmPerHour;
        attribute vehicleDensity : VehicleCount;
        attribute detectedQueueLength : Distance_m;
        attribute incidentSeverity : IncidentSeverityKind;
        attribute visibilityRange : Distance_m;
        attribute surfaceFrictionEstimate : Real;
    }

    item def SensorDirective {
        attribute directiveId : String;
        attribute reportingPeriod : Time_s;
        attribute enableHighResolutionTracking : Boolean;
        attribute laneOfInterest : Integer;
    }

    item def TrafficFlowPlan {
        attribute planId : String;
        attribute generatedAt : Time_s;
        attribute corridorTargetSpeed : Speed_kmPerHour;
        attribute rampMeterCycleTime : Time_s;
        attribute managedLaneCount : Integer;
        attribute expectedThroughput : Throughput_vehiclesPerHour;
        attribute incidentManagementActive : Boolean;
    }

    item def LaneControlDirective {
        attribute directiveId : String;
        attribute laneIndex : Integer;
        attribute status : LaneStatusKind;
        attribute postedSpeedLimit : Speed_kmPerHour;
        attribute minimumFollowingGap : Time_s;
    }

    item def TravelerAdvisory {
        attribute advisoryId : String;
        attribute issuedAt : Time_s;
        attribute messageText : String;
        attribute recommendedSpeed : Speed_kmPerHour;
        attribute expectedDelay : Time_min;
        attribute applicableSegmentStart : Distance_m;
        attribute applicableSegmentEnd : Distance_m;
    }

    item def EmergencyNotice {
        attribute noticeId : String;
        attribute issuedAt : Time_s;
        attribute severity : IncidentSeverityKind;
        attribute affectedLaneIndex : Integer;
        attribute incidentPosition : Distance_m;
        attribute requiredResponseTime : Time_s;
    }

    item def HealthReport {
        attribute sourceId : String;
        attribute generatedAt : Time_s;
        attribute available : Boolean;
        attribute degraded : Boolean;
        attribute availability : Availability_percent;
        attribute diagnosticMessage : String;
    }

    port def VehicleCoordinationServicePort {
        in item vehicleReport : VehicleStateReport;
        out item vehicleCommand : VehicleControlCommand;
        out item travelerAdvisory : TravelerAdvisory;
    }

    port def VehicleClientPort {
        out item vehicleReport : VehicleStateReport;
        in item vehicleCommand : VehicleControlCommand;
        in item travelerAdvisory : TravelerAdvisory;
    }

    port def RoadsideDataProviderPort {
        out item observation : RoadsideSensorObservation;
        in item directive : SensorDirective;
    }

    port def RoadsideDataConsumerPort {
        in item observation : RoadsideSensorObservation;
        out item directive : SensorDirective;
    }

    port def TrafficManagementPlannerPort {
        out item flowPlan : TrafficFlowPlan;
        out item laneDirective : LaneControlDirective;
        in item healthReport : HealthReport;
        in item emergencyNotice : EmergencyNotice;
    }

    port def TrafficManagementExecutionPort {
        in item flowPlan : TrafficFlowPlan;
        in item laneDirective : LaneControlDirective;
        out item healthReport : HealthReport;
        out item emergencyNotice : EmergencyNotice;
    }

    port def OperatorSupervisionPort {
        in item healthReport : HealthReport;
        in item travelerAdvisory : TravelerAdvisory;
        out item emergencyNotice : EmergencyNotice;
        out item laneDirective : LaneControlDirective;
    }

    port def CommunicationBackbonePort {
        inout item vehicleReport : VehicleStateReport;
        inout item vehicleCommand : VehicleControlCommand;
        inout item observation : RoadsideSensorObservation;
        inout item flowPlan : TrafficFlowPlan;
        inout item laneDirective : LaneControlDirective;
        inout item healthReport : HealthReport;
        inout item emergencyNotice : EmergencyNotice;
        inout item travelerAdvisory : TravelerAdvisory;
    }

    part def LaneSegment {
        attribute laneIndex : Integer;
        attribute segmentLength : Distance_m;
        attribute nominalWidth : Distance_m;
        attribute postedSpeedLimit : Speed_kmPerHour;
        attribute minimumAutomatedGap : Time_s;
        attribute status : LaneStatusKind;

        port laneControl : TrafficManagementExecutionPort;
    }

    part def RampMeter {
        attribute rampId : String;
        attribute meteringCycleTime : Time_s;
        attribute queueStorageLength : Distance_m;
        attribute enabled : Boolean;

        port management : TrafficManagementExecutionPort;
    }

    part def VariableMessageSign {
        attribute signId : String;
        attribute location : Distance_m;
        attribute maximumMessageLength : Integer;
        attribute active : Boolean;

        port advisoryInput : TrafficManagementExecutionPort;
    }

    part def RoadsideSensorStation {
        attribute stationId : String;
        attribute location : Distance_m;
        attribute sensingRange : Distance_m;
        attribute reportingPeriod : Time_s;
        attribute availabilityTarget : Availability_percent;

        port trafficData : RoadsideDataProviderPort;
        port health : TrafficManagementExecutionPort;
    }

    part def HighwayCorridor {
        attribute corridorId : String;
        attribute corridorLength : Distance_m;
        attribute designSpeed : Speed_kmPerHour;
        attribute nominalCapacity : Throughput_vehiclesPerHour;

        part managedLane[4] : LaneSegment {
            attribute segmentLength = 5000.0;
            attribute nominalWidth = 3.7;
            attribute minimumAutomatedGap = 1.2;
            attribute status = LaneStatusKind::controlled;
        }

        part entryRamp[3] : RampMeter {
            attribute enabled = true;
            attribute meteringCycleTime = 6.0;
            attribute queueStorageLength = 450.0;
        }

        part exitRamp[3] : RampMeter {
            attribute enabled = true;
            attribute meteringCycleTime = 0.0;
            attribute queueStorageLength = 300.0;
        }
    }

    part def RoadsideInfrastructure {
        attribute subsystemId : String;
        attribute coverageLength : Distance_m;
        attribute minimumSensorAvailability : Availability_percent;

        part sensorStation[20] : RoadsideSensorStation {
            attribute sensingRange = 350.0;
            attribute reportingPeriod = 0.5;
            attribute availabilityTarget = 99.5;
        }

        part messageSign[10] : VariableMessageSign {
            attribute maximumMessageLength = 160;
            attribute active = true;
        }

        port roadsideData : RoadsideDataProviderPort;
        port execution : TrafficManagementExecutionPort;
    }

    part def CentralTrafficManager {
        attribute managerId : String;
        attribute optimizationPeriod : Time_s;
        attribute predictionHorizon : Time_min;
        attribute nominalCoordinatedSpeed : Speed_kmPerHour;
        attribute minimumThroughputObjective : Throughput_vehiclesPerHour;

        port roadsideInput : RoadsideDataConsumerPort;
        port planningOutput : TrafficManagementPlannerPort;
        port vehicleCoordination : VehicleCoordinationServicePort;
        port operatorInterface : OperatorSupervisionPort;
    }

    part def VehicleCoordinationGateway {
        attribute gatewayId : String;
        attribute maximumManagedVehicles : VehicleCount;
        attribute commandUpdatePeriod : Time_s;
        attribute requiredVehicleDataRate : DataRate_Mbps;

        port vehicleSide : VehicleCoordinationServicePort;
        port managerSide : VehicleCoordinationServicePort;
        port communications : CommunicationBackbonePort;
    }

    part def CommunicationsNetwork {
        attribute networkId : String;
        attribute targetLatency : Time_s;
        attribute minimumBackboneDataRate : DataRate_Mbps;
        attribute availabilityTarget : Availability_percent;

        port backbone : CommunicationBackbonePort;
        port roadsideBackhaul : CommunicationBackbonePort;
        port vehicleWirelessAccess : CommunicationBackbonePort;
        port operationsAccess : CommunicationBackbonePort;
    }

    part def SafetySupervisor {
        attribute supervisorId : String;
        attribute maximumAllowedCommandAge : Time_s;
        attribute emergencyBroadcastPeriod : Time_s;
        attribute minimumSafeGap : Time_s;

        port monitor : TrafficManagementExecutionPort;
        port vehicleSafety : VehicleCoordinationServicePort;
        port operatorSafety : OperatorSupervisionPort;
    }

    part def OperationsCenter {
        attribute centerId : String;
        attribute staffed : Boolean;
        attribute maximumOperatorResponseTime : Time_s;

        port supervision : OperatorSupervisionPort;
    }

    action def CollectTrafficState {
        in item vehicleReports : VehicleStateReport[0..*];
        in item roadsideObservations : RoadsideSensorObservation[0..*];
        out item consolidatedObservations : RoadsideSensorObservation[0..*];
    }

    action def EstimateCorridorState {
        in item consolidatedObservations : RoadsideSensorObservation[0..*];
        out item meanCorridorSpeed : Speed_kmPerHour;
        out item activeIncident : EmergencyNotice;
    }

    action def OptimizeTrafficFlow {
        in item meanCorridorSpeed : Speed_kmPerHour;
        in item activeIncident : EmergencyNotice;
        out item plan : TrafficFlowPlan;
        out item laneDirectives : LaneControlDirective[0..*];
    }

    action def CoordinateAutomatedVehicles {
        in item plan : TrafficFlowPlan;
        in item vehicleReports : VehicleStateReport[0..*];
        out item commands : VehicleControlCommand[0..*];
        out item advisories : TravelerAdvisory[0..*];
    }

    action def ExecuteRoadsideControls {
        in item plan : TrafficFlowPlan;
        in item laneDirectives : LaneControlDirective[0..*];
        out item health : HealthReport;
    }

    action def ManageIncident {
        in item activeIncident : EmergencyNotice;
        out item emergencyLaneDirective : LaneControlDirective;
        out item emergencyAdvisory : TravelerAdvisory;
        out item minimalRiskCommands : VehicleControlCommand[0..*];
    }

    action def OperateAutomatedHighwaySystem {
        in item incomingVehicleReports : VehicleStateReport[0..*];
        in item incomingRoadsideObservations : RoadsideSensorObservation[0..*];
        out item outboundVehicleCommands : VehicleControlCommand[0..*];
        out item outboundTravelerAdvisories : TravelerAdvisory[0..*];
        out item outboundLaneDirectives : LaneControlDirective[0..*];

        action collect : CollectTrafficState;
        action estimate : EstimateCorridorState;
        action optimize : OptimizeTrafficFlow;
        action coordinate : CoordinateAutomatedVehicles;
        action executeControls : ExecuteRoadsideControls;
        action incidentResponse : ManageIncident;

        first collect;
        then estimate;
        then optimize;
        then coordinate;
        then executeControls;

        flow incomingVehicleReports to coordinate.vehicleReports;
        flow incomingRoadsideObservations to collect.roadsideObservations;
        flow collect.consolidatedObservations to estimate.consolidatedObservations;
        flow estimate.meanCorridorSpeed to optimize.meanCorridorSpeed;
        flow estimate.activeIncident to optimize.activeIncident;
        flow optimize.plan to coordinate.plan;
        flow optimize.plan to executeControls.plan;
        flow optimize.laneDirectives to executeControls.laneDirectives;
        flow coordinate.commands to outboundVehicleCommands;
        flow coordinate.advisories to outboundTravelerAdvisories;
        flow optimize.laneDirectives to outboundLaneDirectives;
        flow estimate.activeIncident to incidentResponse.activeIncident;
    }

    state def AutomatedHighwayOperationalStates {
        state poweredOff;
        state initializing;
        state selfTest;
        state standby;
        state coordinatedOperation;
        state degradedOperation;
        state incidentManagement;
        state emergencyStop;
        state maintenance;

        transition powerOn first poweredOff then initializing;
        transition initializationComplete first initializing then selfTest;
        transition selfTestPassed first selfTest then standby;
        transition enableCoordination first standby then coordinatedOperation;
        transition communicationsDegraded first coordinatedOperation then degradedOperation;
        transition communicationsRecovered first degradedOperation then coordinatedOperation;
        transition incidentDetected first coordinatedOperation then incidentManagement;
        transition incidentStabilized first incidentManagement then degradedOperation;
        transition severeHazardDetected first coordinatedOperation then emergencyStop;
        transition severeHazardWhileDegraded first degradedOperation then emergencyStop;
        transition operatorMaintenanceRequest first standby then maintenance;
        transition maintenanceComplete first maintenance then standby;
        transition shutdownFromStandby first standby then poweredOff;
        transition shutdownFromMaintenance first maintenance then poweredOff;
    }

    part def AutomatedHighwaySystem {
        attribute systemId : String;
        attribute controlledCorridorLength : Distance_m;
        attribute primaryFunction : String;
        attribute nominalCoordinatedSpeed : Speed_kmPerHour;
        attribute maximumCommandLatency : Time_s;
        attribute minimumManagedThroughput : Throughput_vehiclesPerHour;
        attribute targetAvailability : Availability_percent;

        part corridor : HighwayCorridor {
            attribute corridorId = "AHS-CORRIDOR-01";
            attribute corridorLength = 5000.0;
            attribute designSpeed = 120.0;
            attribute nominalCapacity = 7200.0;
        }

        part roadsideInfrastructure : RoadsideInfrastructure {
            attribute subsystemId = "AHS-RSI-01";
            attribute coverageLength = 5000.0;
            attribute minimumSensorAvailability = 99.5;
        }

        part centralTrafficManager : CentralTrafficManager {
            attribute managerId = "AHS-CTM-01";
            attribute optimizationPeriod = 1.0;
            attribute predictionHorizon = 15.0;
            attribute nominalCoordinatedSpeed = 100.0;
            attribute minimumThroughputObjective = 6800.0;
        }

        part vehicleGateway : VehicleCoordinationGateway {
            attribute gatewayId = "AHS-VCG-01";
            attribute maximumManagedVehicles = 2500;
            attribute commandUpdatePeriod = 0.2;
            attribute requiredVehicleDataRate = 50.0;
        }

        part communicationsNetwork : CommunicationsNetwork {
            attribute networkId = "AHS-COMMS-01";
            attribute targetLatency = 0.1;
            attribute minimumBackboneDataRate = 1000.0;
            attribute availabilityTarget = 99.99;
        }

        part safetySupervisor : SafetySupervisor {
            attribute supervisorId = "AHS-SAFE-01";
            attribute maximumAllowedCommandAge = 0.5;
            attribute emergencyBroadcastPeriod = 0.1;
            attribute minimumSafeGap = 1.2;
        }

        part operationsCenter : OperationsCenter {
            attribute centerId = "AHS-OPS-01";
            attribute staffed = true;
            attribute maximumOperatorResponseTime = 30.0;
        }

        port vehicleAccess : VehicleCoordinationServicePort;
        port roadsideAccess : RoadsideDataConsumerPort;
        port operatorAccess : OperatorSupervisionPort;
        port networkAccess : CommunicationBackbonePort;

        connection roadsideToManager connect roadsideInfrastructure.roadsideData to centralTrafficManager.roadsideInput;
        connection managerToRoadsideExecution connect centralTrafficManager.planningOutput to roadsideInfrastructure.execution;
        connection managerToVehicleGateway connect centralTrafficManager.vehicleCoordination to vehicleGateway.managerSide;
        connection gatewayToVehicles connect vehicleGateway.vehicleSide to vehicleAccess;
        connection managerToSafetySupervisor connect centralTrafficManager.planningOutput to safetySupervisor.monitor;
        connection safetyToVehicleAccess connect safetySupervisor.vehicleSafety to vehicleAccess;
        connection safetyToOperator connect safetySupervisor.operatorSafety to operationsCenter.supervision;
        connection operatorToManager connect operationsCenter.supervision to centralTrafficManager.operatorInterface;
        connection networkBackbone connect communicationsNetwork.backbone to networkAccess;
        connection gatewayNetwork connect vehicleGateway.communications to communicationsNetwork.vehicleWirelessAccess;

        exhibit state operationalStates : AutomatedHighwayOperationalStates;
        perform action primaryOperation : OperateAutomatedHighwaySystem;
    }

    constraint def CommandLatencyConstraint {
        in actualLatency : Time_s;
        in allowedLatency : Time_s;
        actualLatency <= allowedLatency;
    }

    constraint def SafeGapConstraint {
        in commandedGap : Time_s;
        in minimumGap : Time_s;
        commandedGap >= minimumGap;
    }

    constraint def ThroughputConstraint {
        in achievedThroughput : Throughput_vehiclesPerHour;
        in requiredThroughput : Throughput_vehiclesPerHour;
        achievedThroughput >= requiredThroughput;
    }

    constraint def AvailabilityConstraint {
        in achievedAvailability : Availability_percent;
        in requiredAvailability : Availability_percent;
        achievedAvailability >= requiredAvailability;
    }

    requirement def PrimaryFunctionRequirement {
        subject ahs : AutomatedHighwaySystem;
        doc /* The Automated Highway System shall provide the high-level primary function of safely and efficiently coordinating traffic flow on a controlled highway corridor by sensing roadway conditions, planning corridor-level speed and lane strategies, issuing vehicle coordination commands and traveler advisories, managing ramps and lanes, and responding to incidents. */
    }

    requirement def VehicleCoordinationRequirement {
        subject ahs : AutomatedHighwaySystem;
        require constraint safeGap : SafeGapConstraint {
            in commandedGap = 1.2;
            in minimumGap = ahs.safetySupervisor.minimumSafeGap;
        }
    }

    requirement def LowLatencyCommandRequirement {
        subject ahs : AutomatedHighwaySystem;
        require constraint latency : CommandLatencyConstraint {
            in actualLatency = ahs.communicationsNetwork.targetLatency;
            in allowedLatency = ahs.maximumCommandLatency;
        }
    }

    requirement def CorridorThroughputRequirement {
        subject ahs : AutomatedHighwaySystem;
        require constraint throughput : ThroughputConstraint {
            in achievedThroughput = ahs.centralTrafficManager.minimumThroughputObjective;
            in requiredThroughput = ahs.minimumManagedThroughput;
        }
    }

    requirement def SystemAvailabilityRequirement {
        subject ahs : AutomatedHighwaySystem;
        require constraint availability : AvailabilityConstraint {
            in achievedAvailability = ahs.communicationsNetwork.availabilityTarget;
            in requiredAvailability = ahs.targetAvailability;
        }
    }

    requirement def IncidentResponseRequirement {
        subject ahs : AutomatedHighwaySystem;
        doc /* The system shall detect major or emergency roadway incidents, transition to incident management or emergency stop states, issue lane restrictions, broadcast traveler advisories, and command automated vehicles toward a minimal-risk condition. */
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject ahs = automatedHighwaySystem;
    }

    requirement vehicleCoordinationRequirement : VehicleCoordinationRequirement {
        subject ahs = automatedHighwaySystem;
    }

    requirement lowLatencyCommandRequirement : LowLatencyCommandRequirement {
        subject ahs = automatedHighwaySystem;
    }

    requirement corridorThroughputRequirement : CorridorThroughputRequirement {
        subject ahs = automatedHighwaySystem;
    }

    requirement systemAvailabilityRequirement : SystemAvailabilityRequirement {
        subject ahs = automatedHighwaySystem;
    }

    requirement incidentResponseRequirement : IncidentResponseRequirement {
        subject ahs = automatedHighwaySystem;
    }

    part automatedHighwaySystem : AutomatedHighwaySystem {
        attribute systemId = "AHS-01";
        attribute controlledCorridorLength = 5000.0;
        attribute primaryFunction = "Safely coordinate automated and connected vehicles, roadside infrastructure, lane controls, ramp meters, and traveler information to maintain efficient traffic flow across a controlled highway corridor.";
        attribute nominalCoordinatedSpeed = 100.0;
        attribute maximumCommandLatency = 0.5;
        attribute minimumManagedThroughput = 6500.0;
        attribute targetAvailability = 99.9;
    }

    satisfy primaryFunctionRequirement by automatedHighwaySystem;
    satisfy vehicleCoordinationRequirement by automatedHighwaySystem.vehicleGateway;
    satisfy lowLatencyCommandRequirement by automatedHighwaySystem.communicationsNetwork;
    satisfy corridorThroughputRequirement by automatedHighwaySystem.centralTrafficManager;
    satisfy systemAvailabilityRequirement by automatedHighwaySystem.communicationsNetwork;
    satisfy incidentResponseRequirement by automatedHighwaySystem.safetySupervisor;
}
