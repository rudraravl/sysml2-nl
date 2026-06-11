package AmazonScoutBasedDeliverySystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent :> Real {
    range = "0..100";
  }

  attribute def Speed_km_per_h :> Real {
    unit = "km/h";
  }

  attribute def Distance_m :> Real {
    unit = "m";
  }

  attribute def Mass_kg :> Real {
    unit = "kg";
  }

  attribute def Energy_Wh :> Real {
    unit = "W*h";
  }

  attribute def Power_W :> Real {
    unit = "W";
  }

  attribute def Time_s :> Real {
    unit = "s";
  }

  attribute def Temperature_C :> Real {
    unit = "degC";
  }

  enum def DeliveryMissionState {
    enum idle;
    enum loading;
    enum routePlanning;
    enum navigating;
    enum pedestrianYield;
    enum obstacleAvoidance;
    enum awaitingCustomer;
    enum compartmentOpen;
    enum returnToBase;
    enum charging;
    enum faulted;
  }

  enum def RobotHealthStatus {
    enum nominal;
    enum degraded;
    enum lowBattery;
    enum blocked;
    enum tamperDetected;
    enum emergencyStop;
    enum lostLocalization;
  }

  enum def PayloadSecurityState {
    enum locked;
    enum unlockAuthorized;
    enum open;
    enum closed;
    enum relocked;
  }

  item def Parcel {
    attribute trackingId : String;
    attribute destinationAddress : String;
    attribute recipientToken : String;
    attribute mass : Mass_kg;
    attribute maximumTemperature : Temperature_C;
    attribute fragile : Boolean;
  }

  item def RoutePlan {
    attribute routeId : String;
    attribute plannedDistance : Distance_m;
    attribute expectedTravelTime : Time_s;
    attribute maximumAllowedSpeed : Speed_km_per_h;
    attribute sidewalkPreferred : Boolean;
  }

  item def LocalizationEstimate {
    attribute latitude_deg : Real;
    attribute longitude_deg : Real;
    attribute heading_deg : Real;
    attribute confidence : Percent;
    attribute positionUncertainty : Distance_m;
  }

  item def ObstacleReport {
    attribute obstacleId : String;
    attribute range : Distance_m;
    attribute relativeBearing_deg : Real;
    attribute moving : Boolean;
    attribute vulnerableRoadUser : Boolean;
  }

  item def CustomerAuthorization {
    attribute trackingId : String;
    attribute oneTimeCode : String;
    attribute valid : Boolean;
  }

  item def DeliveryConfirmation {
    attribute trackingId : String;
    attribute delivered : Boolean;
    attribute timestampUtc : String;
    attribute compartmentClosed : Boolean;
  }

  item def TelemetryPacket {
    attribute missionState : DeliveryMissionState;
    attribute healthStatus : RobotHealthStatus;
    attribute batteryStateOfCharge : Percent;
    attribute currentSpeed : Speed_km_per_h;
    attribute locationConfidence : Percent;
  }

  port def ParcelLoadPort {
    in item parcelIn : Parcel;
    out item parcelOut : Parcel;
  }

  port def RouteDataPort {
    in item routeAssignment : RoutePlan;
    out item routeProgress : TelemetryPacket;
  }

  port def AuthorizationPort {
    in item authorization : CustomerAuthorization;
    out item deliveryConfirmation : DeliveryConfirmation;
  }

  port def PerceptionPort {
    out item localization : LocalizationEstimate;
    out item obstacle : ObstacleReport;
  }

  port def MotionCommandPort {
    in attribute targetSpeed : Speed_km_per_h;
    in attribute targetHeading_deg : Real;
    out attribute actualSpeed : Speed_km_per_h;
  }

  port def EnergyPort {
    in attribute chargePower : Power_W;
    out attribute batteryStateOfCharge : Percent;
  }

  part def ScoutBasedDeliveryRobot {
    attribute curbWeight : Mass_kg = 45.0;
    attribute payloadCapacity : Mass_kg = 9.0;
    attribute maximumSpeed : Speed_km_per_h = 6.4;
    attribute nominalRange : Distance_m = 9600.0;
    attribute batteryCapacity : Energy_Wh = 1050.0;
    attribute minimumDeliveryBatteryReserve : Percent = 20.0;
    attribute missionState : DeliveryMissionState = DeliveryMissionState::idle;
    attribute healthStatus : RobotHealthStatus = RobotHealthStatus::nominal;

    port loadingPort : ParcelLoadPort;
    port dispatchPort : RouteDataPort;
    port customerPort : AuthorizationPort;
    port perceptionPort : PerceptionPort;
    port driveCommandPort : MotionCommandPort;
    port chargePort : EnergyPort;

    part chassis {
      attribute wheelCount : Integer = 6;
      attribute weatherResistant : Boolean = true;
      attribute groundClearance : Distance_m = 0.08;
    }

    part batterySystem {
      attribute capacity : Energy_Wh = 1050.0;
      attribute stateOfCharge : Percent = 100.0;
      attribute reserveThreshold : Percent = 20.0;
      attribute chargingPowerLimit : Power_W = 450.0;
      port energy : EnergyPort;
    }

    part autonomousNavigationComputer {
      attribute processorRedundancy : Integer = 2;
      attribute localizationConfidence : Percent = 100.0;
      attribute routeLoaded : Boolean = false;
      port routeData : RouteDataPort;
      port perceptionData : PerceptionPort;
      port motionCommand : MotionCommandPort;
    }

    part perceptionSuite {
      attribute cameraCount : Integer = 8;
      attribute ultrasonicSensorCount : Integer = 12;
      attribute lidarEnabled : Boolean = true;
      attribute minimumObstacleDetectionRange : Distance_m = 0.15;
      attribute pedestrianDetectionRange : Distance_m = 12.0;
      port sensedWorld : PerceptionPort;
    }

    part driveBase {
      attribute motorCount : Integer = 6;
      attribute maxContinuousPower : Power_W = 600.0;
      attribute actualSpeed : Speed_km_per_h = 0.0;
      attribute commandedSpeed : Speed_km_per_h = 0.0;
      port command : MotionCommandPort;
    }

    part secureParcelCompartment {
      attribute internalVolume_L : Real = 32.0;
      attribute maximumParcelMass : Mass_kg = 9.0;
      attribute lockState : PayloadSecurityState = PayloadSecurityState::locked;
      attribute doorOpen : Boolean = false;
      port parcelAccess : ParcelLoadPort;
      port authorization : AuthorizationPort;
    }

    part communicationsModule {
      attribute cellularConnected : Boolean = true;
      attribute cloudHeartbeatPeriod : Time_s = 5.0;
      attribute encryptedTelemetry : Boolean = true;
      port missionData : RouteDataPort;
      port customerAuth : AuthorizationPort;
    }

    part humanInteractionPanel {
      attribute displayActive : Boolean = true;
      attribute speakerEnabled : Boolean = true;
      attribute accessCodeEntryEnabled : Boolean = true;
      port customerInteraction : AuthorizationPort;
    }

    connection connectPerceptionToNavigation
      connect perceptionSuite.sensedWorld to autonomousNavigationComputer.perceptionData;

    connection connectNavigationToDrive
      connect autonomousNavigationComputer.motionCommand to driveBase.command;

    connection connectBatteryToChargePort
      connect batterySystem.energy to chargePort;

    connection connectDispatchToComms
      connect dispatchPort to communicationsModule.missionData;

    connection connectCommsToNavigation
      connect communicationsModule.missionData to autonomousNavigationComputer.routeData;

    connection connectCustomerToPanel
      connect customerPort to humanInteractionPanel.customerInteraction;

    connection connectPanelToCompartment
      connect humanInteractionPanel.customerInteraction to secureParcelCompartment.authorization;

    connection connectLoadingToCompartment
      connect loadingPort to secureParcelCompartment.parcelAccess;

    state def DeliveryMissionBehavior {
      state idle;
      state loading;
      state routePlanning;
      state navigating;
      state pedestrianYield;
      state obstacleAvoidance;
      state awaitingCustomer;
      state compartmentOpen;
      state returnToBase;
      state charging;
      state faulted;

      entry action initializeMission {
        out missionReady : Boolean;
      }

      action acceptParcel {
        in parcel : Parcel;
        out accepted : Boolean;
      }

      action computeSidewalkRoute {
        in destination : String;
        out route : RoutePlan;
      }

      action followRoute {
        in route : RoutePlan;
        out progress : Percent;
      }

      action stopForPedestrian {
        out stopped : Boolean;
      }

      action maneuverAroundObstacle {
        in obstacle : ObstacleReport;
        out cleared : Boolean;
      }

      action authenticateCustomer {
        in authorization : CustomerAuthorization;
        out authorized : Boolean;
      }

      action releaseParcel {
        out confirmation : DeliveryConfirmation;
      }

      action navigateHome {
        out arrivedAtBase : Boolean;
      }

      action rechargeBattery {
        out chargeComplete : Boolean;
      }

      transition idle_to_loading
        first idle
        then loading
        accept LoadRequested;

      transition loading_to_routePlanning
        first loading
        then routePlanning
        if acceptParcel.accepted;

      transition routePlanning_to_navigating
        first routePlanning
        then navigating
        if computeSidewalkRoute.route.plannedDistance > 0.0;

      transition navigating_to_pedestrianYield
        first navigating
        then pedestrianYield
        accept PedestrianDetected;

      transition pedestrianYield_to_navigating
        first pedestrianYield
        then navigating
        if stopForPedestrian.stopped;

      transition navigating_to_obstacleAvoidance
        first navigating
        then obstacleAvoidance
        accept ObstacleBlockingPath;

      transition obstacleAvoidance_to_navigating
        first obstacleAvoidance
        then navigating
        if maneuverAroundObstacle.cleared;

      transition navigating_to_awaitingCustomer
        first navigating
        then awaitingCustomer
        accept DestinationReached;

      transition awaitingCustomer_to_compartmentOpen
        first awaitingCustomer
        then compartmentOpen
        if authenticateCustomer.authorized;

      transition compartmentOpen_to_returnToBase
        first compartmentOpen
        then returnToBase
        if releaseParcel.confirmation.delivered;

      transition navigating_to_returnToBase
        first navigating
        then returnToBase
        accept BatteryReserveReached;

      transition returnToBase_to_charging
        first returnToBase
        then charging
        accept BaseReached;

      transition charging_to_idle
        first charging
        then idle
        if rechargeBattery.chargeComplete;

      transition any_to_faulted
        first idle
        then faulted
        accept SafetyCriticalFault;
    }

    perform behavior deliveryMission : DeliveryMissionBehavior;
  }

  part def DispatchAndSupportService {
    port routeAssignmentPort : RouteDataPort;
    port customerAuthorizationPort : AuthorizationPort;

    part fleetScheduler {
      attribute activeRobots : Integer;
      attribute maximumConcurrentMissions : Integer = 50;
    }

    part routeService {
      attribute sidewalkMapVersion : String;
      attribute avoidsHighTrafficRoads : Boolean = true;
    }

    part customerNotificationService {
      attribute sendsArrivalNotice : Boolean = true;
      attribute sendsUnlockCode : Boolean = true;
    }
  }

  part def ResidentialDeliveryEnvironment {
    attribute sidewalkAvailable : Boolean = true;
    attribute maximumCurbHeight : Distance_m = 0.10;
    attribute pedestrianRightOfWay : Boolean = true;

    part sidewalkNetwork {
      attribute mappedLength : Distance_m;
      attribute minimumWidth : Distance_m = 1.2;
    }

    part customerDropOffLocation {
      attribute accessDistanceFromSidewalk : Distance_m = 2.0;
      attribute safeStoppingAreaAvailable : Boolean = true;
    }

    part chargingBase {
      attribute chargePowerAvailable : Power_W = 450.0;
      port charger : EnergyPort;
    }
  }

  part scoutDeliverySystem {
    part robot : ScoutBasedDeliveryRobot;
    part supportService : DispatchAndSupportService;
    part environment : ResidentialDeliveryEnvironment;

    connection dispatchRoute
      connect supportService.routeAssignmentPort to robot.dispatchPort;

    connection customerAuthorization
      connect supportService.customerAuthorizationPort to robot.customerPort;

    connection chargingConnection
      connect environment.chargingBase.charger to robot.chargePort;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall autonomously transport a customer parcel from a local dispatch point to a residential customer drop-off location using sidewalk-scale navigation, secure payload handling, obstacle avoidance, customer authorization, and return-to-base operation. */
  }

  requirement def LowSpeedSidewalkOperationRequirement {
    attribute maxPermittedSpeed : Speed_km_per_h = 6.4;
    require constraint {
      scoutDeliverySystem.robot.maximumSpeed <= maxPermittedSpeed
    }
  }

  requirement def PayloadCapacityRequirement {
    attribute requiredPayloadCapacity : Mass_kg = 9.0;
    require constraint {
      scoutDeliverySystem.robot.payloadCapacity >= requiredPayloadCapacity
    }
  }

  requirement def BatteryReserveRequirement {
    attribute minimumReserve : Percent = 20.0;
    require constraint {
      scoutDeliverySystem.robot.minimumDeliveryBatteryReserve >= minimumReserve
    }
  }

  requirement def ObstacleDetectionRequirement {
    attribute requiredPedestrianDetectionRange : Distance_m = 10.0;
    require constraint {
      scoutDeliverySystem.robot.perceptionSuite.pedestrianDetectionRange >= requiredPedestrianDetectionRange
    }
  }

  requirement def SecureDeliveryRequirement {
    doc /* The parcel compartment shall remain locked during travel and shall unlock only after receiving a valid customer authorization for the loaded parcel tracking identifier. */
  }

  requirement def TelemetryRequirement {
    doc /* The robot shall report mission state, health status, battery state of charge, speed, and localization confidence to the dispatch and support service at least once every five seconds during an active mission. */
    attribute maximumTelemetryPeriod : Time_s = 5.0;
    require constraint {
      scoutDeliverySystem.robot.communicationsModule.cloudHeartbeatPeriod <= maximumTelemetryPeriod
    }
  }

  requirement def FaultHandlingRequirement {
    doc /* The robot shall enter a faulted safe state and stop commanded motion when localization confidence is insufficient, tamper detection occurs, emergency stop is requested, or a safety-critical obstacle cannot be cleared. */
  }

  satisfy PrimaryFunctionRequirement by scoutDeliverySystem;
  satisfy LowSpeedSidewalkOperationRequirement by scoutDeliverySystem.robot;
  satisfy PayloadCapacityRequirement by scoutDeliverySystem.robot.secureParcelCompartment;
  satisfy BatteryReserveRequirement by scoutDeliverySystem.robot.batterySystem;
  satisfy ObstacleDetectionRequirement by scoutDeliverySystem.robot.perceptionSuite;
  satisfy SecureDeliveryRequirement by scoutDeliverySystem.robot.secureParcelCompartment;
  satisfy TelemetryRequirement by scoutDeliverySystem.robot.communicationsModule;
  satisfy FaultHandlingRequirement by scoutDeliverySystem.robot.autonomousNavigationComputer;
}