package AutonomousUGVSystem {
    private import ISQ::MassValue;
    private import ISQ::LengthValue;
    private import ISQ::SpeedValue;
    private import ISQ::PowerValue;
    private import ISQ::EnergyValue;
    private import ISQ::DurationValue;
    private import ISQ::AngleValue;
    private import SI::kg;
    private import SI::km;
    private import SI::m;
    private import SI::s;
    private import SI::W;
    private import SI::J;
    private import SI::m_per_s;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    attribute def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    attribute def GPSWaypoint {
        attribute position : Position;
        attribute reached : Boolean;
    }

    attribute def MissionPlan {
        attribute waypoints : GPSWaypoint[*];
    }

    attribute def TelemetryPacket {
        attribute status : String;
        attribute position : Position;
        attribute batteryLevel : Real;
        attribute sensorData : String;
    }

    attribute def MissionPlanMsg {
        attribute plan : MissionPlan;
    }

    attribute def TelemetryMsg {
        attribute packet : TelemetryPacket;
    }

    attribute def ObstacleDetectedMsg {
        attribute distance : LengthValue;
    }

    attribute def ObstacleClearedMsg;
    attribute def WaypointReachedMsg;
    attribute def AllWaypointsReachedMsg;
    attribute def BaseReachedMsg;
    attribute def BatteryCriticalMsg;

    enum def CommandKind {
        newMission;
        returnToBase;
        emergencyStop;
        reset;
    }

    attribute def CommandMsg {
        attribute command : CommandKind;
    }

    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute chargeLevel : Real;
        attribute criticalThreshold : Real = 0.2;
        port powerOut {
            out attribute power : PowerValue;
        }
        port statusOut {
            out attribute chargeLevel : Real;
            out attribute batteryCritical : BatteryCriticalMsg;
        }
        perform action monitorCharge {
            out chargeLevelOut : Real;
            out batteryCriticalOut : BatteryCriticalMsg;
            first start;
            then action readVoltage;
            then action computeCharge;
            then action checkCritical;
            then done;
        }
    }

    part def ElectricMotor {
        attribute speed : SpeedValue;
        port powerIn {
            in attribute power : PowerValue;
        }
        port controlIn {
            in attribute throttle : Real;
        }
        perform action applyThrottle {
            in throttle : Real;
            first start;
            then action setPower;
            then done;
        }
    }

    part def SteeringActuator {
        attribute angle : AngleValue;
        port powerIn {
            in attribute power : PowerValue;
        }
        port controlIn {
            in attribute steeringAngle : AngleValue;
        }
        perform action setSteering {
            in steeringAngle : AngleValue;
            first start;
            then action moveToAngle;
            then done;
        }
    }

    part def LidarSensor {
        attribute maxRange : LengthValue = 50 [m];
        port obstacleOut {
            out attribute obstacle : ObstacleDetectedMsg;
        }
        perform action senseObstacles {
            out obstacle : ObstacleDetectedMsg;
            first start;
            then action scanEnvironment;
            then action computeDistance;
            then done;
        }
    }

    part def HighDefinitionCamera {
        port videoOut {
            out attribute videoData : String;
        }
        perform action captureVideo {
            out videoData : String;
            first start;
            then action acquireFrames;
            then done;
        }
    }

    part def GPSReceiver {
        port positionOut {
            out attribute position : Position;
        }
        perform action getPosition {
            out position : Position;
            first start;
            then action readSatellites;
            then action computePosition;
            then done;
        }
    }

    part def NavigationComputer {
        attribute currentWaypointIndex : Integer = 0;
        port powerIn {
            in attribute power : PowerValue;
        }
        port positionIn {
            in attribute position : Position;
        }
        port videoIn {
            in attribute videoData : String;
        }
        port obstacleIn {
            in attribute obstacle : ObstacleDetectedMsg;
        }
        port missionIn {
            in attribute missionPlan : MissionPlan;
        }
        port throttleOut {
            out attribute throttle : Real;
        }
        port steeringOut {
            out attribute steeringAngle : AngleValue;
        }
        port waypointOut {
            out attribute waypointReached : WaypointReachedMsg;
        }
        port allWaypointsOut {
            out attribute allWaypoints : AllWaypointsReachedMsg;
        }
        perform action computePath {
            in missionPlan : MissionPlan;
            in position : Position;
            out path : GPSWaypoint[*];
            first start;
            then action planRoute;
            then done;
        }
        perform action computeControl {
            in path : GPSWaypoint[*];
            in position : Position;
            in obstacle : ObstacleDetectedMsg;
            out throttle : Real;
            out steeringAngle : AngleValue;
            first start;
            then action calculateThrottle;
            then action calculateSteering;
            then done;
        }
        perform action checkWaypoint {
            in currentWaypoint : GPSWaypoint;
            in position : Position;
            out waypointReached : WaypointReachedMsg;
            out allWaypoints : AllWaypointsReachedMsg;
            first start;
            then action comparePosition;
            then done;
        }
    }

    part def AutonomousController {
        attribute safetyDistance : LengthValue = 5 [m];
        port powerIn {
            in attribute power : PowerValue;
        }
        port missionIn {
            in attribute missionPlan : MissionPlanMsg;
        }
        port commandIn {
            in attribute command : CommandMsg;
        }
        port lidarIn {
            in attribute obstacle : ObstacleDetectedMsg;
        }
        port batteryStatusIn {
            in attribute chargeLevel : Real;
            in attribute batteryCritical : BatteryCriticalMsg;
        }
        port waypointIn {
            in attribute waypointReached : WaypointReachedMsg;
        }
        port allWaypointsIn {
            in attribute allWaypoints : AllWaypointsReachedMsg;
        }
        port telemetryOut {
            out attribute telemetry : TelemetryMsg;
        }
        state controllerStates {
            entry; then standby;
            state standby;
            transition standby_to_navigating
                first standby
                accept mission : MissionPlanMsg via missionIn
                then navigating;
            transition standby_to_emergency
                first standby
                accept cmd : CommandMsg via commandIn
                if cmd.command == CommandKind::emergencyStop
                then emergencyStop;
            state navigating;
            transition navigating_to_obstacle
                first navigating
                accept obstacle : ObstacleDetectedMsg via lidarIn
                if obstacle.distance < safetyDistance
                then obstacleAvoidance;
            transition navigating_to_returning
                first navigating
                accept batteryCritical : BatteryCriticalMsg via batteryStatusIn
                then returningToBase;
            transition navigating_to_complete
                first navigating
                accept allWaypoints : AllWaypointsReachedMsg via allWaypointsIn
                then missionComplete;
            transition navigating_to_emergency
                first navigating
                accept cmd : CommandMsg via commandIn
                if cmd.command == CommandKind::emergencyStop
                then emergencyStop;
            state obstacleAvoidance;
            transition obstacle_to_navigating
                first obstacleAvoidance
                accept obstacleClear : ObstacleClearedMsg
                then navigating;
            transition obstacle_to_emergency
                first obstacleAvoidance
                accept cmd : CommandMsg via commandIn
                if cmd.command == CommandKind::emergencyStop
                then emergencyStop;
            state missionComplete;
            transition complete_to_returning
                first missionComplete
                then returningToBase;
            state returningToBase;
            transition returning_to_standby
                first returningToBase
                accept baseReached : BaseReachedMsg
                then standby;
            transition returning_to_emergency
                first returningToBase
                accept cmd : CommandMsg via commandIn
                if cmd.command == CommandKind::emergencyStop
                then emergencyStop;
            state emergencyStop;
            transition emergency_to_standby
                first emergencyStop
                accept cmd : CommandMsg via commandIn
                if cmd.command == CommandKind::reset
                then standby;
        }
    }

    part def CommunicationModule {
        port powerIn {
            in attribute power : PowerValue;
        }
        port telemetryIn {
            in attribute telemetry : TelemetryMsg;
        }
        port externalPort {
            in attribute command : CommandMsg;
            out attribute telemetry : TelemetryMsg;
        }
        port missionOut {
            out attribute missionPlan : MissionPlanMsg;
        }
        port commandOut {
            out attribute command : CommandMsg;
        }
        perform action forwardTelemetry {
            in telemetry : TelemetryMsg;
            first start;
            then action sendToAntenna;
            then done;
        }
        perform action receiveExternalCommand {
            out command : CommandMsg;
            out missionPlan : MissionPlanMsg;
            first start;
            then action listenToAntenna;
            then action decodeSignal;
            then done;
        }
    }

    part def ControlStation {
        port commPort {
            in attribute telemetry : TelemetryMsg;
            out attribute command : CommandMsg;
        }
        perform action displayTelemetry {
            in telemetry : TelemetryMsg;
            first start;
            then action renderStatus;
            then done;
        }
        perform action sendMissionCommand {
            out command : CommandMsg;
            first start;
            then action encodeCommand;
            then done;
        }
    }

    part def UGV {
        attribute mass : MassValue = 150 [kg];
        attribute topSpeed : SpeedValue = 15 [m_per_s];
        attribute maxRange : LengthValue = 50 [km];

        part battery : BatteryPack;
        part motor : ElectricMotor;
        part steering : SteeringActuator;
        part lidar : LidarSensor;
        part camera : HighDefinitionCamera;
        part gps : GPSReceiver;
        part navComputer : NavigationComputer;
        part controller : AutonomousController;
        part comm : CommunicationModule;

        connect battery.powerOut to motor.powerIn;
        connect battery.powerOut to steering.powerIn;
        connect battery.powerOut to navComputer.powerIn;
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to comm.powerIn;
        connect battery.statusOut to controller.batteryStatusIn;

        connect lidar.obstacleOut to navComputer.obstacleIn;
        connect lidar.obstacleOut to controller.lidarIn;
        connect camera.videoOut to navComputer.videoIn;
        connect gps.positionOut to navComputer.positionIn;

        connect navComputer.throttleOut to motor.controlIn;
        connect navComputer.steeringOut to steering.controlIn;
        connect navComputer.waypointOut to controller.waypointIn;
        connect navComputer.allWaypointsOut to controller.allWaypointsIn;

        connect controller.telemetryOut to comm.telemetryIn;
        connect comm.missionOut to controller.missionIn;
        connect comm.commandOut to controller.commandIn;
    }

    part ugv : UGV;
    part controlStation : ControlStation;

    connect ugv.comm.externalPort to controlStation.commPort;

    requirement def UGVPerformanceRequirements {
        subject ugv : UGV;
        attribute maxMass : MassValue = 150 [kg];
        attribute minRange : LengthValue = 50 [km];
        attribute minTopSpeed : SpeedValue = 15 [m_per_s];
        attribute minObstacleRange : LengthValue = 50 [m];
        constraint massConstraint { ugv.mass <= maxMass }
        constraint rangeConstraint { ugv.maxRange >= minRange }
        constraint speedConstraint { ugv.topSpeed >= minTopSpeed }
        constraint obstacleRangeConstraint { ugv.lidar.maxRange >= minObstacleRange }
    }

    requirement def UGVSafetyRequirements {
        subject ugv : UGV;
        attribute criticalBatteryThreshold : Real = 0.2;
        constraint obstacleAvoidanceConstraint { ugv.lidar.maxRange >= 50 [m] }
        constraint emergencyStopConstraint { ugv.controller.safetyDistance > 0 [m] }
        constraint returnHomeConstraint { ugv.battery.criticalThreshold <= criticalBatteryThreshold }
    }

    satisfy UGVPerformanceRequirements by ugv;
    satisfy UGVSafetyRequirements by ugv;
}
