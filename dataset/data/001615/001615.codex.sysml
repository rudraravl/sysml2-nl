package UnmannedGroundVehicleSystem {

    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;

    attribute def Percent :> ScalarValues::Real;
    attribute def Degree :> ScalarValues::Real;
    attribute def Meter :> ScalarValues::Real;
    attribute def MeterPerSecond :> ScalarValues::Real;
    attribute def NewtonMeter :> ScalarValues::Real;
    attribute def WattHour :> ScalarValues::Real;
    attribute def Volt :> ScalarValues::Real;
    attribute def Ampere :> ScalarValues::Real;
    attribute def Celsius :> ScalarValues::Real;
    attribute def Kilogram :> ScalarValues::Real;
    attribute def Second :> ScalarValues::Real;
    attribute def Hertz :> ScalarValues::Real;
    attribute def BitPerSecond :> ScalarValues::Real;

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : ScalarValues::Real;
    }

    item def MotionCommand {
        attribute targetSpeed : MeterPerSecond;
        attribute steeringAngle : Degree;
        attribute brakeRequest : Percent;
        attribute commandTimestamp : Second;
    }

    item def NavigationCommand {
        attribute destinationLatitude : ScalarValues::Real;
        attribute destinationLongitude : ScalarValues::Real;
        attribute desiredArrivalRadius : Meter;
        attribute missionPriority : ScalarValues::Integer;
    }

    item def PoseEstimate {
        attribute latitude : ScalarValues::Real;
        attribute longitude : ScalarValues::Real;
        attribute heading : Degree;
        attribute speed : MeterPerSecond;
        attribute positionUncertainty : Meter;
    }

    item def TerrainObservation {
        attribute obstacleRange : Meter;
        attribute obstacleBearing : Degree;
        attribute traversabilityScore : Percent;
        attribute slopeEstimate : Degree;
    }

    item def HealthStatus {
        attribute batteryStateOfCharge : Percent;
        attribute driveTemperature : Celsius;
        attribute computeTemperature : Celsius;
        attribute faultCount : ScalarValues::Integer;
        attribute emergencyStopActive : ScalarValues::Boolean;
    }

    item def TelemetryPacket {
        attribute pose : PoseEstimate;
        attribute health : HealthStatus;
        attribute linkQuality : Percent;
        attribute packetTime : Second;
    }

    item def PayloadData {
        attribute sampleTime : Second;
        attribute imageFrameRate : Hertz;
        attribute dataRate : BitPerSecond;
        attribute detectedObjectCount : ScalarValues::Integer;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def MotionCommandOutPort {
        out item command : MotionCommand;
    }

    port def MotionCommandInPort {
        in item command : MotionCommand;
    }

    port def NavigationCommandInPort {
        in item command : NavigationCommand;
    }

    port def PoseOutPort {
        out item pose : PoseEstimate;
    }

    port def PoseInPort {
        in item pose : PoseEstimate;
    }

    port def TerrainOutPort {
        out item terrain : TerrainObservation;
    }

    port def TerrainInPort {
        in item terrain : TerrainObservation;
    }

    port def HealthOutPort {
        out item status : HealthStatus;
    }

    port def HealthInPort {
        in item status : HealthStatus;
    }

    port def TelemetryOutPort {
        out item telemetry : TelemetryPacket;
    }

    port def TelemetryInPort {
        in item telemetry : TelemetryPacket;
    }

    port def PayloadDataOutPort {
        out item data : PayloadData;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 48.0;
        attribute usableEnergy : WattHour = 2400.0;
        attribute maxContinuousCurrent : Ampere = 120.0;
        attribute stateOfCharge : Percent;
        attribute temperature : Celsius;

        port powerOut : PowerOutPort;
        port healthOut : HealthOutPort;
    }

    part def PowerDistributionUnit {
        attribute busVoltage : Volt = 48.0;
        attribute maxOutputCurrent : Ampere = 140.0;
        attribute protectedCircuitCount : ScalarValues::Integer = 8;

        port mainPowerIn : PowerInPort;
        port drivePowerOut : PowerOutPort;
        port computePowerOut : PowerOutPort;
        port sensorPowerOut : PowerOutPort;
        port payloadPowerOut : PowerOutPort;
    }

    part def DriveController {
        attribute controlRate : Hertz = 100.0;
        attribute maxTorqueCommand : NewtonMeter = 180.0;
        attribute temperature : Celsius;

        port powerIn : PowerInPort;
        port commandIn : MotionCommandInPort;
        port healthOut : HealthOutPort;
    }

    part def LeftTrackDrive {
        attribute maximumTorque : NewtonMeter = 160.0;
        attribute maximumSpeed : MeterPerSecond = 2.5;
        attribute mass : Kilogram = 18.0;

        port powerIn : PowerInPort;
        port commandIn : MotionCommandInPort;
    }

    part def RightTrackDrive {
        attribute maximumTorque : NewtonMeter = 160.0;
        attribute maximumSpeed : MeterPerSecond = 2.5;
        attribute mass : Kilogram = 18.0;

        port powerIn : PowerInPort;
        port commandIn : MotionCommandInPort;
    }

    part def LocalizationSubsystem {
        attribute updateRate : Hertz = 20.0;
        attribute nominalAccuracy : Meter = 0.5;

        port powerIn : PowerInPort;
        port poseOut : PoseOutPort;
    }

    part def PerceptionSubsystem {
        attribute lidarRange : Meter = 80.0;
        attribute cameraHorizontalFieldOfView : Degree = 120.0;
        attribute updateRate : Hertz = 15.0;

        port powerIn : PowerInPort;
        port terrainOut : TerrainOutPort;
    }

    part def MissionComputer {
        attribute processorPower : ScalarValues::Real = 45.0;
        attribute autonomyUpdateRate : Hertz = 10.0;
        attribute safeStopDistance : Meter = 1.5;

        port powerIn : PowerInPort;
        port navigationCommandIn : NavigationCommandInPort;
        port poseIn : PoseInPort;
        port terrainIn : TerrainInPort;
        port healthIn : HealthInPort;
        port motionCommandOut : MotionCommandOutPort;
        port telemetryOut : TelemetryOutPort;
    }

    part def CommunicationsModule {
        attribute nominalRange : Meter = 1000.0;
        attribute uplinkRate : BitPerSecond = 250000.0;
        attribute downlinkRate : BitPerSecond = 2000000.0;

        port powerIn : PowerInPort;
        port navigationCommandOut : NavigationCommandInPort;
        port telemetryIn : TelemetryInPort;
        port payloadDataIn : PayloadDataOutPort;
    }

    part def PayloadSensorModule {
        attribute sensorMass : Kilogram = 4.5;
        attribute scanRate : Hertz = 10.0;
        attribute payloadDataRate : BitPerSecond = 1500000.0;

        port powerIn : PowerInPort;
        port poseIn : PoseInPort;
        port payloadDataOut : PayloadDataOutPort;
    }

    part def EmergencyStopUnit {
        attribute wirelessStopRange : Meter = 100.0;
        attribute stopReactionTime : Second = 0.2;

        port powerIn : PowerInPort;
        port motionCommandOut : MotionCommandOutPort;
        port healthOut : HealthOutPort;
    }

    action def PlanGroundRoute {
        in item mission : NavigationCommand;
        in item currentPose : PoseEstimate;
        in item terrain : TerrainObservation;
        out item command : MotionCommand;

        objective {
            doc /* Compute a traversable motion command that moves the vehicle toward the mission destination while avoiding detected terrain hazards. */
        }
    }

    action def ExecuteMobilityCommand {
        in item command : MotionCommand;
        out item health : HealthStatus;

        objective {
            doc /* Convert target speed, steering angle, and brake request into synchronized left and right track drive actuation. */
        }
    }

    action def ReportVehicleTelemetry {
        in item pose : PoseEstimate;
        in item health : HealthStatus;
        out item telemetry : TelemetryPacket;

        objective {
            doc /* Publish current vehicle position, mobility state, energy state, and fault status to the remote operator station. */
        }
    }

    state def UGVOperationalState {
        entry action initializeVehicle;
        state Off;
        state Booting;
        state Standby;
        state AutonomousTraverse;
        state RemoteHold;
        state ObstacleAvoidance;
        state ReturnToBase;
        state EmergencyStop;
        state FaultRecovery;
        state Shutdown;

        transition first Off;
        transition Off_to_Booting
            first Off
            then Booting;

        transition Booting_to_Standby
            first Booting
            then Standby;

        transition Standby_to_AutonomousTraverse
            first Standby
            then AutonomousTraverse;

        transition AutonomousTraverse_to_ObstacleAvoidance
            first AutonomousTraverse
            then ObstacleAvoidance;

        transition ObstacleAvoidance_to_AutonomousTraverse
            first ObstacleAvoidance
            then AutonomousTraverse;

        transition AutonomousTraverse_to_ReturnToBase
            first AutonomousTraverse
            then ReturnToBase;

        transition Standby_to_RemoteHold
            first Standby
            then RemoteHold;

        transition Any_to_EmergencyStop
            first AutonomousTraverse
            then EmergencyStop;

        transition EmergencyStop_to_FaultRecovery
            first EmergencyStop
            then FaultRecovery;

        transition FaultRecovery_to_Standby
            first FaultRecovery
            then Standby;

        transition Standby_to_Shutdown
            first Standby
            then Shutdown;
    }

    part def UnmannedGroundVehicle {
        attribute vehicleMass : Kilogram = 145.0;
        attribute maximumSpeed : MeterPerSecond = 2.2;
        attribute nominalEndurance : Second = 10800.0;
        attribute payloadCapacity : Kilogram = 20.0;
        attribute minimumTurningRadius : Meter = 0.8;
        attribute groundClearance : Meter = 0.22;

        port missionCommandIn : NavigationCommandInPort;
        port telemetryOut : TelemetryOutPort;
        port payloadDataOut : PayloadDataOutPort;

        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part missionComputer : MissionComputer;
        part localization : LocalizationSubsystem;
        part perception : PerceptionSubsystem;
        part driveController : DriveController;
        part leftTrack : LeftTrackDrive;
        part rightTrack : RightTrackDrive;
        part communications : CommunicationsModule;
        part payloadSensor : PayloadSensorModule;
        part emergencyStop : EmergencyStopUnit;

        perform stateMachine : UGVOperationalState;

        connection battery_to_pdu
            connect battery.powerOut to powerDistribution.mainPowerIn;

        connection pdu_to_mission_computer
            connect powerDistribution.computePowerOut to missionComputer.powerIn;

        connection pdu_to_localization
            connect powerDistribution.sensorPowerOut to localization.powerIn;

        connection pdu_to_perception
            connect powerDistribution.sensorPowerOut to perception.powerIn;

        connection pdu_to_drive_controller
            connect powerDistribution.drivePowerOut to driveController.powerIn;

        connection pdu_to_left_track
            connect powerDistribution.drivePowerOut to leftTrack.powerIn;

        connection pdu_to_right_track
            connect powerDistribution.drivePowerOut to rightTrack.powerIn;

        connection pdu_to_communications
            connect powerDistribution.computePowerOut to communications.powerIn;

        connection pdu_to_payload
            connect powerDistribution.payloadPowerOut to payloadSensor.powerIn;

        connection pdu_to_estop
            connect powerDistribution.computePowerOut to emergencyStop.powerIn;

        connection external_mission_to_comms
            connect missionCommandIn to communications.navigationCommandOut;

        connection comms_to_mission_computer
            connect communications.navigationCommandOut to missionComputer.navigationCommandIn;

        connection localization_to_mission_computer
            connect localization.poseOut to missionComputer.poseIn;

        connection perception_to_mission_computer
            connect perception.terrainOut to missionComputer.terrainIn;

        connection mission_computer_to_drive_controller
            connect missionComputer.motionCommandOut to driveController.commandIn;

        connection drive_controller_to_left_track
            connect missionComputer.motionCommandOut to leftTrack.commandIn;

        connection drive_controller_to_right_track
            connect missionComputer.motionCommandOut to rightTrack.commandIn;

        connection estop_to_drive
            connect emergencyStop.motionCommandOut to driveController.commandIn;

        connection battery_health_to_mission_computer
            connect battery.healthOut to missionComputer.healthIn;

        connection drive_health_to_mission_computer
            connect driveController.healthOut to missionComputer.healthIn;

        connection estop_health_to_mission_computer
            connect emergencyStop.healthOut to missionComputer.healthIn;

        connection mission_telemetry_to_comms
            connect missionComputer.telemetryOut to communications.telemetryIn;

        connection comms_to_external_telemetry
            connect missionComputer.telemetryOut to telemetryOut;

        connection pose_to_payload
            connect localization.poseOut to payloadSensor.poseIn;

        connection payload_to_comms
            connect payloadSensor.payloadDataOut to communications.payloadDataIn;

        connection payload_to_external
            connect payloadSensor.payloadDataOut to payloadDataOut;
    }

    requirement def PrimaryFunctionRequirement {
        subject vehicle : UnmannedGroundVehicle;

        doc /* The unmanned ground vehicle shall autonomously traverse outdoor ground terrain to transport and operate a payload while maintaining remote telemetry and accepting operator mission commands. */

        require constraint {
            vehicle.maximumSpeed >= 1.5
        }

        require constraint {
            vehicle.payloadCapacity >= 15.0
        }

        require constraint {
            vehicle.nominalEndurance >= 7200.0
        }
    }

    requirement def MobilityRequirement {
        subject vehicle : UnmannedGroundVehicle;

        doc /* The vehicle shall generate and execute track-drive motion commands for forward motion, turning, braking, and obstacle avoidance on uneven terrain. */

        require constraint {
            vehicle.minimumTurningRadius <= 1.0
        }

        require constraint {
            vehicle.groundClearance >= 0.18
        }
    }

    requirement def AutonomyRequirement {
        subject computer : MissionComputer;

        doc /* The mission computer shall use navigation commands, pose estimates, and terrain observations to plan safe local motion commands without continuous operator input. */

        require constraint {
            computer.autonomyUpdateRate >= 5.0
        }

        require constraint {
            computer.safeStopDistance >= 1.0
        }
    }

    requirement def EnergyRequirement {
        subject battery : BatteryPack;

        doc /* The battery pack shall provide regulated electrical power sufficient for mobility, autonomy, sensing, communications, and payload operation for the nominal mission duration. */

        require constraint {
            battery.nominalVoltage == 48.0
        }

        require constraint {
            battery.usableEnergy >= 2000.0
        }
    }

    requirement def CommunicationsRequirement {
        subject radio : CommunicationsModule;

        doc /* The communications module shall exchange mission commands, telemetry, and payload data with a remote operator station within the expected operating area. */

        require constraint {
            radio.nominalRange >= 800.0
        }

        require constraint {
            radio.downlinkRate >= 1000000.0
        }
    }

    requirement def SafetyRequirement {
        subject stopUnit : EmergencyStopUnit;

        doc /* The emergency stop unit shall force the vehicle to halt when commanded or when a critical safety fault is detected. */

        require constraint {
            stopUnit.stopReactionTime <= 0.5
        }

        require constraint {
            stopUnit.wirelessStopRange >= 50.0
        }
    }

    requirement def PayloadRequirement {
        subject payload : PayloadSensorModule;

        doc /* The payload sensor module shall collect mission data and associate the data with current vehicle pose for remote monitoring or later analysis. */

        require constraint {
            payload.scanRate >= 5.0
        }

        require constraint {
            payload.sensorMass <= 8.0
        }
    }

    part ugvSystem : UnmannedGroundVehicle {
        attribute vehicleMass = 145.0;
        attribute maximumSpeed = 2.2;
        attribute nominalEndurance = 10800.0;
        attribute payloadCapacity = 20.0;
        attribute minimumTurningRadius = 0.8;
        attribute groundClearance = 0.22;
    }

    satisfy PrimaryFunctionRequirement by ugvSystem;
    satisfy MobilityRequirement by ugvSystem;
    satisfy AutonomyRequirement by ugvSystem.missionComputer;
    satisfy EnergyRequirement by ugvSystem.battery;
    satisfy CommunicationsRequirement by ugvSystem.communications;
    satisfy SafetyRequirement by ugvSystem.emergencyStop;
    satisfy PayloadRequirement by ugvSystem.payloadSensor;
}