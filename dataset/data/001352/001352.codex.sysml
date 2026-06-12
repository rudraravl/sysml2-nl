package AutomatedGuidedVehicleSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value type MassValue specializes Real { unit = kg; }
    value type LengthValue specializes Real { unit = m; }
    value type SpeedValue specializes Real { unit = m / s; }
    value type AccelerationValue specializes Real { unit = m / s^2; }
    value type TimeValue specializes Real { unit = s; }
    value type EnergyValue specializes Real { unit = J; }
    value type PowerValue specializes Real { unit = W; }
    value type VoltageValue specializes Real { unit = V; }
    value type CurrentValue specializes Real { unit = A; }
    value type TemperatureValue specializes Real { unit = K; }
    value type PercentValue specializes Real;
    value type ForceValue specializes Real { unit = N; }
    value type AngleValue specializes Real { unit = rad; }

    enum def MissionStateKind {
        idle;
        assigned;
        navigatingToPickup;
        loading;
        navigatingToDropoff;
        unloading;
        returningToBase;
        charging;
        faulted;
        emergencyStopped;
    }

    enum def LoadStateKind {
        unloaded;
        acquiringLoad;
        loaded;
        releasingLoad;
    }

    enum def ObstacleClassKind {
        none;
        staticObject;
        movingPerson;
        movingVehicle;
        blockedRoute;
    }

    item def TransportMission {
        attribute missionId : String;
        attribute pickupLocationId : String;
        attribute dropoffLocationId : String;
        attribute requestedPayloadMass : MassValue;
        attribute priority : Integer;
        attribute deadline : TimeValue;
    }

    item def RoutePlan {
        attribute routeId : String;
        attribute totalDistance : LengthValue;
        attribute nominalTravelTime : TimeValue;
        attribute maximumAllowedSpeed : SpeedValue;
    }

    item def VehiclePose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute heading : AngleValue;
        attribute confidence : PercentValue;
    }

    item def MotionCommand {
        attribute targetSpeed : SpeedValue;
        attribute targetAcceleration : AccelerationValue;
        attribute steeringAngle : AngleValue;
        attribute brakeForce : ForceValue;
    }

    item def BatteryStatus {
        attribute stateOfCharge : PercentValue;
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute temperature : TemperatureValue;
        attribute availableEnergy : EnergyValue;
    }

    item def SafetyEvent {
        attribute eventId : String;
        attribute obstacleClass : ObstacleClassKind;
        attribute distanceToHazard : LengthValue;
        attribute requiredStopDistance : LengthValue;
        attribute emergencyStopRequested : Boolean;
    }

    item def LoadStatus {
        attribute loadState : LoadStateKind;
        attribute measuredPayloadMass : MassValue;
        attribute loadSecured : Boolean;
        attribute loadPositionOffset : LengthValue;
    }

    item def FleetCommand {
        attribute commandId : String;
        attribute commandedMissionState : MissionStateKind;
        attribute targetLocationId : String;
    }

    port def MissionCommandPort {
        in item mission : TransportMission;
        in item fleetCommand : FleetCommand;
        out item missionState : MissionStateKind;
    }

    port def NavigationPort {
        in item routePlan : RoutePlan;
        in item poseEstimate : VehiclePose;
        out item motionCommand : MotionCommand;
    }

    port def SensorPort {
        out item poseEstimate : VehiclePose;
        out item safetyEvent : SafetyEvent;
        out item loadStatus : LoadStatus;
    }

    port def DrivePowerPort {
        in item motionCommand : MotionCommand;
        in item batteryStatus : BatteryStatus;
        out item actualSpeed : SpeedValue;
        out item tractionPower : PowerValue;
    }

    port def BatteryPort {
        out item batteryStatus : BatteryStatus;
        in item tractionPowerDemand : PowerValue;
        in item chargePower : PowerValue;
    }

    port def LoadHandlingPort {
        in item mission : TransportMission;
        in item loadCommand : LoadStateKind;
        out item loadStatus : LoadStatus;
    }

    port def SafetyPort {
        in item safetyEvent : SafetyEvent;
        in item actualSpeed : SpeedValue;
        out item safeMotionCommand : MotionCommand;
        out item emergencyStopActive : Boolean;
    }

    port def WirelessNetworkPort {
        in item mission : TransportMission;
        in item fleetCommand : FleetCommand;
        out item poseEstimate : VehiclePose;
        out item batteryStatus : BatteryStatus;
        out item loadStatus : LoadStatus;
        out item missionState : MissionStateKind;
    }

    part def AutomatedGuidedVehicle {
        attribute vehicleId : String;
        attribute maximumPayloadMass : MassValue = 1200 [kg];
        attribute maximumSpeedLoaded : SpeedValue = 1.5 [m / s];
        attribute maximumSpeedUnloaded : SpeedValue = 2.2 [m / s];
        attribute minimumObstacleStopDistance : LengthValue = 0.5 [m];
        attribute minimumOperatingCharge : PercentValue = 20.0;
        attribute nominalOperatingEndurance : TimeValue = 28800 [s];

        port missionPort : MissionCommandPort;
        port networkPort : WirelessNetworkPort;

        part missionManager : MissionManager;
        part navigationController : NavigationController;
        part safetyController : SafetyController;
        part driveSubsystem : DriveSubsystem;
        part batterySubsystem : BatterySubsystem;
        part sensorSubsystem : SensorSubsystem;
        part loadHandlingSubsystem : LoadHandlingSubsystem;
        part humanMachineInterface : HumanMachineInterface;

        connect networkPort.mission to missionManager.missionPort.mission;
        connect networkPort.fleetCommand to missionManager.missionPort.fleetCommand;
        connect missionManager.missionPort.missionState to networkPort.missionState;

        connect missionManager.routePlanOut to navigationController.navigationPort.routePlan;
        connect sensorSubsystem.sensorPort.poseEstimate to navigationController.navigationPort.poseEstimate;
        connect navigationController.navigationPort.motionCommand to safetyController.commandIn;

        connect sensorSubsystem.sensorPort.safetyEvent to safetyController.safetyPort.safetyEvent;
        connect driveSubsystem.drivePowerPort.actualSpeed to safetyController.safetyPort.actualSpeed;
        connect safetyController.safetyPort.safeMotionCommand to driveSubsystem.drivePowerPort.motionCommand;

        connect batterySubsystem.batteryPort.batteryStatus to driveSubsystem.batteryStatusIn;
        connect driveSubsystem.drivePowerPort.tractionPower to batterySubsystem.batteryPort.tractionPowerDemand;
        connect batterySubsystem.batteryPort.batteryStatus to networkPort.batteryStatus;

        connect missionManager.currentMission to loadHandlingSubsystem.loadHandlingPort.mission;
        connect missionManager.loadCommandOut to loadHandlingSubsystem.loadHandlingPort.loadCommand;
        connect loadHandlingSubsystem.loadHandlingPort.loadStatus to sensorSubsystem.loadStatusIn;
        connect sensorSubsystem.sensorPort.loadStatus to networkPort.loadStatus;

        connect sensorSubsystem.sensorPort.poseEstimate to networkPort.poseEstimate;
        connect safetyController.safetyPort.emergencyStopActive to humanMachineInterface.emergencyStopIndicator;
    }

    part def MissionManager {
        port missionPort : MissionCommandPort;
        out item routePlanOut : RoutePlan;
        out item currentMission : TransportMission;
        out item loadCommandOut : LoadStateKind;

        attribute currentState : MissionStateKind = MissionStateKind::idle;

        action def AssignMission {
            in item mission : TransportMission;
            out item activeMission : TransportMission;
            out item initialState : MissionStateKind;
        }

        action def RequestRouteToPickup {
            in item mission : TransportMission;
            out item route : RoutePlan;
        }

        action def RequestRouteToDropoff {
            in item mission : TransportMission;
            out item route : RoutePlan;
        }

        state def MissionLifecycle {
            state idle;
            state assigned;
            state navigatingToPickup;
            state loading;
            state navigatingToDropoff;
            state unloading;
            state returningToBase;
            state charging;
            state faulted;

            initial then idle;

            transition idle_to_assigned
                first idle
                accept TransportMission
                then assigned;

            transition assigned_to_pickup
                first assigned
                do RequestRouteToPickup
                then navigatingToPickup;

            transition pickup_arrived
                first navigatingToPickup
                accept FleetCommand
                if missionPort.fleetCommand.targetLocationId == missionPort.mission.pickupLocationId
                then loading;

            transition load_complete
                first loading
                if loadCommandOut == LoadStateKind::loaded
                do RequestRouteToDropoff
                then navigatingToDropoff;

            transition dropoff_arrived
                first navigatingToDropoff
                accept FleetCommand
                if missionPort.fleetCommand.targetLocationId == missionPort.mission.dropoffLocationId
                then unloading;

            transition unload_complete
                first unloading
                if loadCommandOut == LoadStateKind::unloaded
                then idle;

            transition low_charge_return
                first idle
                accept BatteryStatus
                if missionPort.missionState != MissionStateKind::assigned
                then returningToBase;

            transition base_arrived
                first returningToBase
                then charging;

            transition charge_complete
                first charging
                then idle;

            transition mission_fault
                first navigatingToPickup
                then faulted;

            transition transport_fault
                first navigatingToDropoff
                then faulted;
        }
    }

    part def NavigationController {
        port navigationPort : NavigationPort;

        attribute localizationAccuracy : LengthValue = 0.05 [m];
        attribute pathTrackingTolerance : LengthValue = 0.10 [m];
        attribute planningUpdatePeriod : TimeValue = 0.10 [s];

        action def EstimatePose {
            out item pose : VehiclePose;
        }

        action def FollowRoute {
            in item route : RoutePlan;
            in item pose : VehiclePose;
            out item command : MotionCommand;
        }

        action def ReplanAroundObstacle {
            in item safetyEvent : SafetyEvent;
            in item currentRoute : RoutePlan;
            out item revisedRoute : RoutePlan;
        }
    }

    part def SafetyController {
        port safetyPort : SafetyPort;
        in item commandIn : MotionCommand;

        attribute protectiveStopDistance : LengthValue = 1.2 [m];
        attribute emergencyStopDistance : LengthValue = 0.4 [m];
        attribute maximumDeceleration : AccelerationValue = 2.5 [m / s^2];

        action def LimitSpeed {
            in item requestedCommand : MotionCommand;
            in item event : SafetyEvent;
            out item limitedCommand : MotionCommand;
        }

        action def ApplyEmergencyStop {
            out item stoppedCommand : MotionCommand;
            out item emergencyStopActive : Boolean;
        }

        state def SafetyStateMachine {
            state normalOperation;
            state protectiveSlowdown;
            state emergencyStop;
            state manualResetRequired;

            initial then normalOperation;

            transition hazard_detected
                first normalOperation
                accept SafetyEvent
                if safetyPort.safetyEvent.distanceToHazard <= protectiveStopDistance
                do LimitSpeed
                then protectiveSlowdown;

            transition hazard_cleared
                first protectiveSlowdown
                accept SafetyEvent
                if safetyPort.safetyEvent.obstacleClass == ObstacleClassKind::none
                then normalOperation;

            transition emergency_required
                first protectiveSlowdown
                accept SafetyEvent
                if safetyPort.safetyEvent.emergencyStopRequested
                do ApplyEmergencyStop
                then emergencyStop;

            transition reset_requested
                first emergencyStop
                accept FleetCommand
                then manualResetRequired;

            transition reset_complete
                first manualResetRequired
                then normalOperation;
        }
    }

    part def DriveSubsystem {
        port drivePowerPort : DrivePowerPort;
        in item batteryStatusIn : BatteryStatus;

        attribute wheelBase : LengthValue = 1.15 [m];
        attribute driveWheelDiameter : LengthValue = 0.25 [m];
        attribute maximumTractiveForce : ForceValue = 1800 [N];
        attribute continuousMotorPower : PowerValue = 4500 [W];

        part leftDriveMotor : ElectricMotor;
        part rightDriveMotor : ElectricMotor;
        part motorController : MotorController;
        part brakeAssembly : BrakeAssembly;

        connect motorController.leftMotorPower to leftDriveMotor.powerIn;
        connect motorController.rightMotorPower to rightDriveMotor.powerIn;
        connect motorController.brakeCommand to brakeAssembly.brakeForceIn;
    }

    part def ElectricMotor {
        in item powerIn : PowerValue;
        out item shaftSpeed : SpeedValue;

        attribute ratedPower : PowerValue = 2500 [W];
        attribute ratedVoltage : VoltageValue = 48 [V];
        attribute peakCurrent : CurrentValue = 120 [A];
    }

    part def MotorController {
        in item requestedMotion : MotionCommand;
        out item leftMotorPower : PowerValue;
        out item rightMotorPower : PowerValue;
        out item brakeCommand : ForceValue;

        action def ConvertMotionToWheelPower {
            in item motionCommand : MotionCommand;
            out item leftPower : PowerValue;
            out item rightPower : PowerValue;
        }
    }

    part def BrakeAssembly {
        in item brakeForceIn : ForceValue;
        out item appliedBrakeForce : ForceValue;

        attribute maximumBrakeForce : ForceValue = 2200 [N];
        attribute brakeResponseTime : TimeValue = 0.15 [s];
    }

    part def BatterySubsystem {
        port batteryPort : BatteryPort;

        attribute nominalVoltage : VoltageValue = 48 [V];
        attribute usableEnergyCapacity : EnergyValue = 172800000 [J];
        attribute maximumDischargeCurrent : CurrentValue = 150 [A];
        attribute maximumChargePower : PowerValue = 3000 [W];

        part batteryPack : BatteryPack;
        part batteryManagementSystem : BatteryManagementSystem;
        part onboardCharger : OnboardCharger;

        connect batteryPack.statusOut to batteryManagementSystem.packStatusIn;
        connect onboardCharger.chargePowerOut to batteryPort.chargePower;
    }

    part def BatteryPack {
        out item statusOut : BatteryStatus;

        attribute cellCount : Integer = 16;
        attribute nominalCapacity : EnergyValue = 172800000 [J];
        attribute operatingTemperatureMinimum : TemperatureValue = 273 [K];
        attribute operatingTemperatureMaximum : TemperatureValue = 318 [K];
    }

    part def BatteryManagementSystem {
        in item packStatusIn : BatteryStatus;
        out item validatedStatusOut : BatteryStatus;

        action def ProtectBattery {
            in item status : BatteryStatus;
            out item permittedDischargePower : PowerValue;
            out item permittedChargePower : PowerValue;
        }
    }

    part def OnboardCharger {
        in item acInputPower : PowerValue;
        out item chargePowerOut : PowerValue;

        attribute inputVoltage : VoltageValue = 240 [V];
        attribute chargeEfficiency : PercentValue = 92.0;
    }

    part def SensorSubsystem {
        port sensorPort : SensorPort;
        in item loadStatusIn : LoadStatus;

        part lidarScanner : LidarScanner;
        part safetyBumper : SafetyBumper;
        part floorMarkerReader : FloorMarkerReader;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part wheelEncoders : WheelEncoderSet;
        part loadCells : LoadCellSet;

        connect floorMarkerReader.poseOut to sensorPort.poseEstimate;
        connect safetyBumper.safetyEventOut to sensorPort.safetyEvent;
        connect loadCells.loadStatusOut to sensorPort.loadStatus;
    }

    part def LidarScanner {
        out item safetyEventOut : SafetyEvent;

        attribute horizontalFieldOfView : AngleValue = 4.71 [rad];
        attribute detectionRange : LengthValue = 12 [m];
        attribute scanPeriod : TimeValue = 0.05 [s];
    }

    part def SafetyBumper {
        out item safetyEventOut : SafetyEvent;

        attribute activationForce : ForceValue = 50 [N];
        attribute bumperWidth : LengthValue = 0.85 [m];
    }

    part def FloorMarkerReader {
        out item poseOut : VehiclePose;

        attribute markerReadRange : LengthValue = 0.20 [m];
        attribute markerUpdatePeriod : TimeValue = 0.05 [s];
    }

    part def InertialMeasurementUnit {
        out item yawRate : AngleValue;
        out item acceleration : AccelerationValue;

        attribute updatePeriod : TimeValue = 0.01 [s];
    }

    part def WheelEncoderSet {
        out item leftWheelSpeed : SpeedValue;
        out item rightWheelSpeed : SpeedValue;

        attribute pulsesPerRevolution : Integer = 2048;
    }

    part def LoadCellSet {
        out item loadStatusOut : LoadStatus;

        attribute measurementRange : MassValue = 1500 [kg];
        attribute measurementAccuracy : MassValue = 5 [kg];
    }

    part def LoadHandlingSubsystem {
        port loadHandlingPort : LoadHandlingPort;

        attribute liftHeight : LengthValue = 0.12 [m];
        attribute liftCapacity : MassValue = 1200 [kg];
        attribute loadTransferTime : TimeValue = 20 [s];

        part liftActuator : LiftActuator;
        part loadClamp : LoadClamp;
        part palletPresenceSensor : PalletPresenceSensor;

        action def AcquireLoad {
            in item mission : TransportMission;
            out item status : LoadStatus;
        }

        action def SecureLoad {
            out item status : LoadStatus;
        }

        action def ReleaseLoad {
            out item status : LoadStatus;
        }

        state def LoadHandlingStateMachine {
            state unloaded;
            state acquiringLoad;
            state loaded;
            state releasingLoad;

            initial then unloaded;

            transition start_acquisition
                first unloaded
                accept TransportMission
                do AcquireLoad
                then acquiringLoad;

            transition load_secured
                first acquiringLoad
                do SecureLoad
                then loaded;

            transition start_release
                first loaded
                accept FleetCommand
                do ReleaseLoad
                then releasingLoad;

            transition release_complete
                first releasingLoad
                then unloaded;
        }
    }

    part def LiftActuator {
        in item liftCommand : LoadStateKind;
        out item liftPosition : LengthValue;

        attribute maximumLiftForce : ForceValue = 15000 [N];
        attribute liftSpeed : SpeedValue = 0.02 [m / s];
    }

    part def LoadClamp {
        in item clampCommand : Boolean;
        out item clampClosed : Boolean;

        attribute clampForce : ForceValue = 800 [N];
    }

    part def PalletPresenceSensor {
        out item palletPresent : Boolean;

        attribute sensingRange : LengthValue = 0.15 [m];
    }

    part def HumanMachineInterface {
        in item emergencyStopIndicator : Boolean;
        out item manualStopRequest : Boolean;
        out item resetRequest : Boolean;

        attribute localDisplayRefreshPeriod : TimeValue = 0.25 [s];
        attribute audibleAlarmLevel : Real = 85.0;
    }

    part def FleetManagementSystem {
        port networkPort : WirelessNetworkPort;

        attribute maximumManagedVehicles : Integer = 50;
        attribute missionAssignmentPeriod : TimeValue = 1 [s];

        action def AssignTransportMission {
            in item requestedMission : TransportMission;
            out item assignedMission : TransportMission;
        }

        action def MonitorVehicleProgress {
            in item pose : VehiclePose;
            in item missionState : MissionStateKind;
            in item batteryStatus : BatteryStatus;
        }
    }

    part def FacilityOperatingEnvironment {
        attribute aisleWidth : LengthValue = 2.4 [m];
        attribute maximumRouteGrade : AngleValue = 0.087 [rad];
        attribute nominalFloorFrictionCoefficient : Real = 0.65;

        part guidePathNetwork : GuidePathNetwork;
        part pickupStation : TransferStation;
        part dropoffStation : TransferStation;
        part chargingStation : ChargingStation;
        part fleetManager : FleetManagementSystem;
        part vehicle : AutomatedGuidedVehicle;

        connect fleetManager.networkPort.mission to vehicle.networkPort.mission;
        connect fleetManager.networkPort.fleetCommand to vehicle.networkPort.fleetCommand;
        connect vehicle.networkPort.poseEstimate to fleetManager.networkPort.poseEstimate;
        connect vehicle.networkPort.batteryStatus to fleetManager.networkPort.batteryStatus;
        connect vehicle.networkPort.loadStatus to fleetManager.networkPort.loadStatus;
        connect vehicle.networkPort.missionState to fleetManager.networkPort.missionState;
    }

    part def GuidePathNetwork {
        attribute routeCount : Integer = 64;
        attribute totalPathLength : LengthValue = 1850 [m];
        attribute markerSpacing : LengthValue = 2 [m];
    }

    part def TransferStation {
        attribute stationId : String;
        attribute dockingTolerance : LengthValue = 0.04 [m];
        attribute transferHeight : LengthValue = 0.30 [m];
        attribute maximumStationLoad : MassValue = 1200 [kg];
    }

    part def ChargingStation {
        attribute stationId : String;
        attribute outputVoltage : VoltageValue = 48 [V];
        attribute outputPower : PowerValue = 3000 [W];
        attribute dockingTolerance : LengthValue = 0.05 [m];
    }

    action def ExecuteMaterialTransportMission {
        in item mission : TransportMission;
        in item routeToPickup : RoutePlan;
        in item routeToDropoff : RoutePlan;
        out item finalMissionState : MissionStateKind;

        first start;
        then assignMission;
        then navigateToPickup;
        then acquireAndSecureLoad;
        then navigateToDropoff;
        then releaseLoad;
        then completeMission;

        action assignMission : MissionManager::AssignMission;
        action navigateToPickup : NavigationController::FollowRoute;
        action acquireAndSecureLoad : LoadHandlingSubsystem::AcquireLoad;
        action navigateToDropoff : NavigationController::FollowRoute;
        action releaseLoad : LoadHandlingSubsystem::ReleaseLoad;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The automated guided vehicle shall autonomously transport a palletized payload from an assigned pickup station to an assigned dropoff station within a facility while following a planned guide path, avoiding hazards, protecting personnel and equipment, monitoring its energy state, and reporting mission progress to fleet management. */

        subject agv : AutomatedGuidedVehicle;

        require constraint {
            agv.maximumPayloadMass >= 1200 [kg]
        }
    }

    requirement def PayloadCapacityRequirement {
        doc
        /* The vehicle shall carry payloads up to 1200 kg without exceeding drive, lift, braking, or stability limits. */

        subject agv : AutomatedGuidedVehicle;

        require constraint {
            agv.maximumPayloadMass >= 1200 [kg]
        }
    }

    requirement def SafeSpeedRequirement {
        doc
        /* The vehicle shall limit commanded speed based on load state and route limits. */

        subject agv : AutomatedGuidedVehicle;

        require constraint {
            agv.maximumSpeedLoaded <= 1.5 [m / s] and
            agv.maximumSpeedUnloaded <= 2.2 [m / s]
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        doc
        /* The vehicle shall detect obstacles on its route and enter protective slowdown or emergency stop before contact. */

        subject safety : SafetyController;

        require constraint {
            safety.emergencyStopDistance <= safety.protectiveStopDistance
        }
    }

    requirement def EnergyAutonomyRequirement {
        doc
        /* The vehicle shall monitor battery state of charge and reserve enough energy to return to a charging station before the state of charge falls below the minimum operating threshold. */

        subject agv : AutomatedGuidedVehicle;

        require constraint {
            agv.minimumOperatingCharge >= 20.0
        }
    }

    requirement def LocalizationRequirement {
        doc
        /* The vehicle shall estimate its pose accurately enough to dock at transfer stations and remain within the guide path tolerance. */

        subject nav : NavigationController;

        require constraint {
            nav.localizationAccuracy <= 0.05 [m] and
            nav.pathTrackingTolerance <= 0.10 [m]
        }
    }

    requirement def MissionReportingRequirement {
        doc
        /* The vehicle shall report pose, battery status, load status, and mission state to the fleet management system during operation. */

        subject agv : AutomatedGuidedVehicle;
    }

    requirement def EmergencyStopRequirement {
        doc
        /* The vehicle shall command zero traction speed and apply braking when an emergency stop is requested by safety sensors, fleet management, or local human interface. */

        subject safety : SafetyController;

        require constraint {
            safety.maximumDeceleration >= 2.5 [m / s^2]
        }
    }

    satisfy PrimaryFunctionRequirement by AutomatedGuidedVehicle;
    satisfy PayloadCapacityRequirement by LoadHandlingSubsystem;
    satisfy SafeSpeedRequirement by NavigationController;
    satisfy ObstacleAvoidanceRequirement by SafetyController;
    satisfy EnergyAutonomyRequirement by BatterySubsystem;
    satisfy LocalizationRequirement by NavigationController;
    satisfy MissionReportingRequirement by AutomatedGuidedVehicle;
    satisfy EmergencyStopRequirement by SafetyController;
}