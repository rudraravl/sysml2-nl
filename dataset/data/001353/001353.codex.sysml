package AutomatedHighwaySystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def VehicleIdentifier :> String;
    attribute def LaneIdentifier :> String;
    attribute def RoadSegmentIdentifier :> String;
    attribute def ControlMode {
        enum manual;
        enum advisory;
        enum automated;
        enum degraded;
        enum emergencyStop;
    }

    item def VehicleState {
        attribute id : VehicleIdentifier;
        attribute position : LengthValue;
        attribute lane : LaneIdentifier;
        attribute speed : SpeedValue;
        attribute acceleration : AccelerationValue;
        attribute heading : PlaneAngleValue;
        attribute automationMode : ControlMode;
    }

    item def TrafficCommand {
        attribute targetVehicle : VehicleIdentifier;
        attribute targetLane : LaneIdentifier;
        attribute commandedSpeed : SpeedValue;
        attribute commandedHeadway : TimeValue;
        attribute validFor : TimeValue;
        attribute priority : Integer;
    }

    item def RoadwayCondition {
        attribute segment : RoadSegmentIdentifier;
        attribute visibility : LengthValue;
        attribute surfaceFrictionCoefficient : Real;
        attribute precipitationRate : SpeedValue;
        attribute incidentPresent : Boolean;
    }

    item def EmergencyAlert {
        attribute sourceVehicle : VehicleIdentifier;
        attribute affectedSegment : RoadSegmentIdentifier;
        attribute severity : Integer;
        attribute requiredSpeedLimit : SpeedValue;
    }

    item def PassengerTripRequest {
        attribute originSegment : RoadSegmentIdentifier;
        attribute destinationSegment : RoadSegmentIdentifier;
        attribute requestedArrivalTime : TimeValue;
    }

    port def VehicleTelemetryPort {
        out item vehicleState : VehicleState;
        out item emergencyAlert : EmergencyAlert;
    }

    port def VehicleCommandPort {
        in item trafficCommand : TrafficCommand;
        in item roadwayCondition : RoadwayCondition;
    }

    port def InfrastructureSensingPort {
        out item vehicleState : VehicleState;
        out item roadwayCondition : RoadwayCondition;
    }

    port def CorridorControlPort {
        in item vehicleState : VehicleState;
        in item roadwayCondition : RoadwayCondition;
        in item emergencyAlert : EmergencyAlert;
        out item trafficCommand : TrafficCommand;
    }

    port def PassengerInterfacePort {
        in item passengerTripRequest : PassengerTripRequest;
        out item vehicleState : VehicleState;
    }

    action def SenseTrafficAndRoadway {
        in item rawVehicleState : VehicleState;
        in item rawCondition : RoadwayCondition;
        out item fusedVehicleState : VehicleState;
        out item fusedCondition : RoadwayCondition;
    }

    action def ComputeCorridorPlan {
        in item fleetState : VehicleState;
        in item roadwayCondition : RoadwayCondition;
        out item trafficCommand : TrafficCommand;
    }

    action def ExecuteVehicleControl {
        in item trafficCommand : TrafficCommand;
        in item currentState : VehicleState;
        out item commandedState : VehicleState;
    }

    action def CoordinateLaneChange {
        in item requestingVehicle : VehicleState;
        in item adjacentVehicle : VehicleState;
        out item laneChangeCommand : TrafficCommand;
    }

    action def MaintainSafePlatoon {
        in item leadVehicle : VehicleState;
        in item followingVehicle : VehicleState;
        out item headwayCommand : TrafficCommand;
    }

    action def HandleEmergency {
        in item emergencyAlert : EmergencyAlert;
        in item roadwayCondition : RoadwayCondition;
        out item emergencyCommand : TrafficCommand;
    }

    state def VehicleAutomationStateMachine {
        entry action initializeVehicleControl;

        state manualControl;
        state joiningAutomatedLane;
        state automatedCruise;
        state cooperativeLaneChange;
        state platoonFollowing;
        state degradedOperation;
        state minimumRiskStop;

        transition first manualControl
            then joiningAutomatedLane
            accept PassengerTripRequest
            if tripRequestValid;

        transition joiningAutomatedLane
            then automatedCruise
            if vehicleAuthenticated and safeMergeGapAvailable;

        transition automatedCruise
            then platoonFollowing
            if compatibleLeadVehicleDetected;

        transition platoonFollowing
            then cooperativeLaneChange
            accept TrafficCommand
            if targetLaneDifferent;

        transition cooperativeLaneChange
            then automatedCruise
            if laneChangeComplete;

        transition automatedCruise
            then degradedOperation
            if sensorConfidenceLow or communicationQualityLow;

        transition platoonFollowing
            then degradedOperation
            if leadVehicleLost;

        transition degradedOperation
            then automatedCruise
            if sensorConfidenceRestored and communicationQualityRestored;

        transition degradedOperation
            then minimumRiskStop
            if safeAutomationCannotBeMaintained;

        transition automatedCruise
            then minimumRiskStop
            accept EmergencyAlert
            if severeIncidentAhead;
    }

    part def AutomatedVehicle {
        attribute vehicleId : VehicleIdentifier;
        attribute length : LengthValue = 4.8 [m];
        attribute maximumSpeed : SpeedValue = 33.3 [m/s];
        attribute maximumAcceleration : AccelerationValue = 3.0 [m/s^2];
        attribute maximumBrakingDeceleration : AccelerationValue = -8.0 [m/s^2];
        attribute minimumAutomatedHeadway : TimeValue = 1.2 [s];
        attribute lateralPositionErrorLimit : LengthValue = 0.15 [m];
        attribute mode : ControlMode = ControlMode::manual;

        port telemetry : VehicleTelemetryPort;
        port command : VehicleCommandPort;
        port passengerInterface : PassengerInterfacePort;

        part perceptionUnit {
            attribute detectionRange : LengthValue = 250 [m];
            attribute updatePeriod : TimeValue = 0.05 [s];
            attribute objectClassificationConfidence : Real;
        }

        part vehicleController {
            attribute controlCycle : TimeValue = 0.02 [s];
            attribute targetSpeed : SpeedValue;
            attribute targetHeadway : TimeValue;
            perform action executeControl : ExecuteVehicleControl;
        }

        part propulsionAndBraking {
            attribute availableTractiveForce : ForceValue;
            attribute availableBrakeForce : ForceValue;
        }

        part steeringSystem {
            attribute maximumSteeringAngle : PlaneAngleValue = 0.55 [rad];
            attribute steeringResponseTime : TimeValue = 0.12 [s];
        }

        behavior automationBehavior : VehicleAutomationStateMachine;
    }

    part def SmartLaneSegment {
        attribute segmentId : RoadSegmentIdentifier;
        attribute laneId : LaneIdentifier;
        attribute segmentLength : LengthValue = 1000 [m];
        attribute designSpeed : SpeedValue = 33.3 [m/s];
        attribute laneWidth : LengthValue = 3.7 [m];
        attribute maximumVehicleDensity : Real = 45.0;
        attribute operational : Boolean = true;

        port sensing : InfrastructureSensingPort;

        part roadsideSensorArray {
            attribute sensorSpacing : LengthValue = 100 [m];
            attribute detectionAccuracy : LengthValue = 0.25 [m];
            attribute refreshPeriod : TimeValue = 0.1 [s];
        }

        part vehicleToInfrastructureRadio {
            attribute communicationRange : LengthValue = 600 [m];
            attribute messageLatencyLimit : TimeValue = 0.05 [s];
            attribute packetDeliveryRatio : Real;
        }
    }

    part def CorridorControlCenter {
        attribute planningHorizon : TimeValue = 120 [s];
        attribute controlUpdatePeriod : TimeValue = 1 [s];
        attribute targetThroughput : Real = 7200.0;
        attribute nominalSpeedLimit : SpeedValue = 30 [m/s];
        attribute emergencySpeedLimit : SpeedValue = 8 [m/s];

        port corridorControl : CorridorControlPort;

        part trafficStateEstimator {
            perform action fuseTraffic : SenseTrafficAndRoadway;
        }

        part flowOptimizer {
            perform action computePlan : ComputeCorridorPlan;
            perform action maintainPlatoon : MaintainSafePlatoon;
            perform action coordinateLaneChange : CoordinateLaneChange;
        }

        part emergencyManager {
            perform action handleEmergency : HandleEmergency;
        }
    }

    part def AutomatedHighwaySystem {
        attribute systemName : String = "Automated Highway System";
        attribute primaryFunction : String =
            "Coordinate equipped vehicles and intelligent roadway infrastructure to provide safe, efficient, high-throughput automated travel along controlled highway lanes.";
        attribute corridorLength : LengthValue = 12000 [m];
        attribute nominalOperatingSpeed : SpeedValue = 30 [m/s];
        attribute minimumSafeHeadway : TimeValue = 1.2 [s];
        attribute maximumCommandLatency : TimeValue = 0.1 [s];

        part controlCenter : CorridorControlCenter;

        part laneSegment1 : SmartLaneSegment {
            attribute segmentId = "AHS-S01";
            attribute laneId = "AUTO-1";
        }

        part laneSegment2 : SmartLaneSegment {
            attribute segmentId = "AHS-S02";
            attribute laneId = "AUTO-1";
        }

        part laneSegment3 : SmartLaneSegment {
            attribute segmentId = "AHS-S03";
            attribute laneId = "AUTO-2";
        }

        part leadVehicle : AutomatedVehicle {
            attribute vehicleId = "VEH-LEAD-001";
            attribute mode = ControlMode::automated;
        }

        part followingVehicle : AutomatedVehicle {
            attribute vehicleId = "VEH-FOLLOW-002";
            attribute mode = ControlMode::automated;
        }

        part mergingVehicle : AutomatedVehicle {
            attribute vehicleId = "VEH-MERGE-003";
            attribute mode = ControlMode::advisory;
        }

        connect laneSegment1.sensing to controlCenter.corridorControl;
        connect laneSegment2.sensing to controlCenter.corridorControl;
        connect laneSegment3.sensing to controlCenter.corridorControl;

        connect leadVehicle.telemetry to controlCenter.corridorControl;
        connect followingVehicle.telemetry to controlCenter.corridorControl;
        connect mergingVehicle.telemetry to controlCenter.corridorControl;

        connect controlCenter.corridorControl to leadVehicle.command;
        connect controlCenter.corridorControl to followingVehicle.command;
        connect controlCenter.corridorControl to mergingVehicle.command;

        perform action continuousCorridorPlanning : ComputeCorridorPlan;
        perform action automatedVehicleFollowing : MaintainSafePlatoon;
        perform action controlledMerge : CoordinateLaneChange;
    }

    requirement def SafeAutomatedTravel {
        doc
        /* The automated highway system shall maintain safe automated vehicle motion while coordinating traffic flow. */

        require constraint {
            AutomatedHighwaySystem::minimumSafeHeadway >= 1.0 [s]
        }
    }

    requirement def LowLatencyControl {
        doc
        /* Command and telemetry exchange shall be fast enough to support cooperative automated control. */

        require constraint {
            AutomatedHighwaySystem::maximumCommandLatency <= 0.1 [s]
        }
    }

    requirement def ControlledLaneChange {
        doc
        /* Lane changes in automated lanes shall be authorized by the corridor control center and executed only when a safe gap is available. */

        require constraint {
            AutomatedVehicle::lateralPositionErrorLimit <= 0.20 [m]
        }
    }

    requirement def EmergencyResponse {
        doc
        /* The system shall detect severe roadway incidents and command affected vehicles toward a reduced speed or minimum risk stop. */

        require constraint {
            CorridorControlCenter::emergencySpeedLimit <= 10 [m/s]
        }
    }

    requirement def HighThroughputOperation {
        doc
        /* The automated highway system shall increase corridor throughput by coordinating vehicle spacing, speed, and lane use. */

        require constraint {
            CorridorControlCenter::targetThroughput >= 6000.0
        }
    }

    satisfy SafeAutomatedTravel by AutomatedHighwaySystem;
    satisfy LowLatencyControl by AutomatedHighwaySystem;
    satisfy ControlledLaneChange by AutomatedVehicle;
    satisfy EmergencyResponse by CorridorControlCenter;
    satisfy HighThroughputOperation by CorridorControlCenter;
}