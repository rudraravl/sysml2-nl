package BerlinUrbanMobilitySystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def PassengerCount :> ScalarValues::Integer;
  attribute def VehicleCount :> ScalarValues::Integer;
  attribute def Percent :> ScalarValues::Real;
  attribute def Euro :> ScalarValues::Real;
  attribute def CO2GramPerPassengerKm :> ScalarValues::Real;
  attribute def Minute :> ScalarValues::Real;
  attribute def Kilometer :> ScalarValues::Real;
  attribute def PassengerPerHour :> ScalarValues::Real;
  attribute def KilowattHour :> ScalarValues::Real;

  item def Passenger {
    attribute passengerId : String;
    attribute accessibilityNeed : Boolean;
    attribute hasValidFare : Boolean;
  }

  item def TripRequest {
    attribute originStation : String;
    attribute destinationStation : String;
    attribute requestedDepartureTime : String;
    attribute passengerCount : PassengerCount;
  }

  item def TripPlan {
    attribute routeId : String;
    attribute expectedTravelTime : Minute;
    attribute transferCount : ScalarValues::Integer;
    attribute expectedFare : Euro;
    attribute walkingDistance : Kilometer;
  }

  item def Ticket {
    attribute ticketId : String;
    attribute zone : String;
    attribute price : Euro;
    attribute validMinutes : Minute;
  }

  item def VehicleStatus {
    attribute vehicleId : String;
    attribute occupancy : Percent;
    attribute delay : Minute;
    attribute availableCapacity : PassengerCount;
  }

  item def ServiceAlert {
    attribute alertId : String;
    attribute affectedLine : String;
    attribute severity : String;
    attribute message : String;
  }

  port def PassengerServicePort {
    in request : TripRequest;
    out plan : TripPlan;
    out ticket : Ticket;
    out alert : ServiceAlert;
  }

  port def VehicleOperationsPort {
    in status : VehicleStatus;
    out dispatchCommand : String;
  }

  port def EnergyPort {
    in electricalEnergy : KilowattHour;
    out energyDemandForecast : KilowattHour;
  }

  part def BerlinMobilitySystem {
    attribute dailyRidership : PassengerCount;
    attribute averageTripTime : Minute;
    attribute networkLength : Kilometer;
    attribute peakCapacity : PassengerPerHour;
    attribute serviceAvailability : Percent;
    attribute emissionsIntensity : CO2GramPerPassengerKm;

    port passengerInterface : PassengerServicePort;
    port operationsInterface : VehicleOperationsPort;
    port gridInterface : EnergyPort;

    part journeyPlanner : JourneyPlanner;
    part fareManager : FareManager;
    part railNetwork : RailNetwork;
    part busNetwork : BusNetwork;
    part operationsCenter : OperationsCenter;
    part energyManager : EnergyManager;

    connect passengerInterface.request to journeyPlanner.tripRequest;
    connect journeyPlanner.tripPlan to passengerInterface.plan;
    connect passengerInterface.request to fareManager.tripRequest;
    connect fareManager.issuedTicket to passengerInterface.ticket;

    connect railNetwork.vehicleStatus to operationsCenter.railStatus;
    connect busNetwork.vehicleStatus to operationsCenter.busStatus;
    connect operationsCenter.railDispatchCommand to railNetwork.dispatchCommand;
    connect operationsCenter.busDispatchCommand to busNetwork.dispatchCommand;

    connect gridInterface.electricalEnergy to energyManager.energySupply;
    connect energyManager.energyDemandForecast to gridInterface.energyDemandForecast;
  }

  part def JourneyPlanner {
    port tripRequest {
      in request : TripRequest;
    }

    port tripPlan {
      out plan : TripPlan;
    }

    attribute maxTransferCount : ScalarValues::Integer = 3;
    attribute targetPlanningTime : Minute = 0.05;

    action computeTripPlan {
      in request : TripRequest;
      out plan : TripPlan;

      first start;
      then validateRequest;
      then evaluateRailOptions;
      then evaluateBusOptions;
      then selectLowestTravelTimeRoute;
      then publishPlan;
    }
  }

  part def FareManager {
    port tripRequest {
      in request : TripRequest;
    }

    port issuedTicket {
      out ticket : Ticket;
    }

    attribute baseFareAB : Euro = 3.50;
    attribute baseFareABC : Euro = 4.40;
    attribute standardValidity : Minute = 120.0;

    action issueTicket {
      in request : TripRequest;
      out ticket : Ticket;

      first determineZone;
      then calculateFare;
      then createDigitalTicket;
      then validateTicket;
    }
  }

  part def RailNetwork {
    attribute lineCount : ScalarValues::Integer = 16;
    attribute stationCount : ScalarValues::Integer = 175;
    attribute trainCount : VehicleCount;
    attribute nominalHeadway : Minute = 5.0;

    port vehicleStatus {
      out status : VehicleStatus;
    }

    port dispatchCommand {
      in command : String;
    }

    part ubahnFleet : RailFleet;
    part sbahnFleet : RailFleet;
    part railStations : StationGroup;
  }

  part def BusNetwork {
    attribute routeCount : ScalarValues::Integer = 150;
    attribute busCount : VehicleCount;
    attribute nominalHeadway : Minute = 10.0;

    port vehicleStatus {
      out status : VehicleStatus;
    }

    port dispatchCommand {
      in command : String;
    }

    part electricBusFleet : BusFleet;
    part busStops : StationGroup;
  }

  part def RailFleet {
    attribute vehicleCount : VehicleCount;
    attribute seatedCapacityPerVehicle : PassengerCount;
    attribute standingCapacityPerVehicle : PassengerCount;
    attribute maximumSpeed : Kilometer;
    attribute energyUsePerKm : KilowattHour;
  }

  part def BusFleet {
    attribute vehicleCount : VehicleCount;
    attribute passengerCapacityPerBus : PassengerCount;
    attribute batteryCapacity : KilowattHour;
    attribute energyUsePerKm : KilowattHour;
  }

  part def StationGroup {
    attribute locationCount : ScalarValues::Integer;
    attribute accessibleLocationPercent : Percent;
    attribute averagePlatformOccupancy : Percent;
  }

  part def OperationsCenter {
    port railStatus {
      in status : VehicleStatus;
    }

    port busStatus {
      in status : VehicleStatus;
    }

    port railDispatchCommand {
      out command : String;
    }

    port busDispatchCommand {
      out command : String;
    }

    attribute controlRoomStaff : ScalarValues::Integer;
    attribute incidentResponseTarget : Minute = 5.0;

    action regulateService {
      in railStatus : VehicleStatus;
      in busStatus : VehicleStatus;
      out railCommand : String;
      out busCommand : String;

      first collectVehicleTelemetry;
      then detectDelayAndCrowding;
      then prioritizeCriticalLines;
      then issueDispatchCommands;
    }

    state def OperationsState {
      entry action initializeMonitoring;

      state NormalService;
      state PeakLoadManagement;
      state DisruptionManagement;
      state EmergencyCoordination;

      transition first NormalService;
      transition NormalService to PeakLoadManagement
        if averageOccupancyExceeds85Percent;
      transition PeakLoadManagement to NormalService
        if averageOccupancyBelow70Percent;
      transition NormalService to DisruptionManagement
        if lineDelayExceeds10Minutes;
      transition PeakLoadManagement to DisruptionManagement
        if lineDelayExceeds10Minutes;
      transition DisruptionManagement to NormalService
        if disruptedLineRecovered;
      transition DisruptionManagement to EmergencyCoordination
        if safetyIncidentDeclared;
      transition EmergencyCoordination to DisruptionManagement
        if emergencyCleared;
    }
  }

  part def EnergyManager {
    port energySupply {
      in electricalEnergy : KilowattHour;
    }

    port energyDemandForecast {
      out forecast : KilowattHour;
    }

    attribute dailyTractionEnergy : KilowattHour;
    attribute renewableEnergyShare : Percent;
    attribute regenerativeBrakingRecovery : Percent;

    action forecastEnergyDemand {
      in plannedServiceKilometers : Kilometer;
      in expectedPassengerLoad : PassengerCount;
      out forecast : KilowattHour;

      first aggregateRailDemand;
      then aggregateBusDemand;
      then subtractRegenerativeRecovery;
      then publishForecast;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : BerlinMobilitySystem;

    require constraint {
      system.peakCapacity >= 60000.0
    }

    doc /* The Berlin mobility system shall provide coordinated, multimodal urban passenger transport across Berlin by planning trips, issuing fares, dispatching vehicles, managing disruptions, and minimizing passenger travel time at city scale. */
  }

  requirement def AccessibilityRequirement {
    subject stations : StationGroup;

    require constraint {
      stations.accessibleLocationPercent >= 95.0
    }

    doc /* Stations and stops shall support accessible passenger movement across the public transport network. */
  }

  requirement def ServiceAvailabilityRequirement {
    subject system : BerlinMobilitySystem;

    require constraint {
      system.serviceAvailability >= 99.0
    }

    doc /* The system shall maintain high transport service availability during normal operating days. */
  }

  requirement def EmissionsRequirement {
    subject system : BerlinMobilitySystem;

    require constraint {
      system.emissionsIntensity <= 35.0
    }

    doc /* The system shall limit operational emissions per passenger kilometer through electric traction, energy optimization, and high vehicle occupancy. */
  }

  requirement def TripPlanningRequirement {
    subject planner : JourneyPlanner;

    require constraint {
      planner.targetPlanningTime <= 0.10
    }

    doc /* The journey planner shall produce a valid multimodal trip plan quickly enough for interactive passenger use. */
  }

  part berlinTransportSystem : BerlinMobilitySystem {
    attribute dailyRidership = 3500000;
    attribute averageTripTime = 34.0;
    attribute networkLength = 1500.0;
    attribute peakCapacity = 75000.0;
    attribute serviceAvailability = 99.3;
    attribute emissionsIntensity = 28.0;

    part railNetwork {
      attribute lineCount = 16;
      attribute stationCount = 175;
      attribute trainCount = 1450;
      attribute nominalHeadway = 5.0;
    }

    part busNetwork {
      attribute routeCount = 150;
      attribute busCount = 1600;
      attribute nominalHeadway = 10.0;
    }

    part operationsCenter {
      attribute controlRoomStaff = 85;
      attribute incidentResponseTarget = 5.0;
    }

    part energyManager {
      attribute dailyTractionEnergy = 920000.0;
      attribute renewableEnergyShare = 68.0;
      attribute regenerativeBrakingRecovery = 18.0;
    }
  }

}