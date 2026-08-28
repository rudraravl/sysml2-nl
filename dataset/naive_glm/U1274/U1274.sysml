package BerlinTransitSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value type LengthUnit => Real {
        unit 'm';
    }
    value type SpeedUnit => Real {
        unit 'm/s';
    }
    value type MassUnit => Real {
        unit 'kg';
    }
    value type PowerUnit => Real {
        unit 'W';
    }
    value type VoltageUnit => Real {
        unit 'V';
    }
    value type CurrentUnit => Real {
        unit 'A';
    }
    value type CurrencyUnit => Real {
        unit 'EUR';
    }
    value type TimeOfDay => Real {
        unit 's';
    }
    value type ZoneId => Integer;
    value type StationId => String;
    value type TrainId => String;
    value type RouteId => String;
    value type PlatformNumber => Integer;
    value type PassengerCount => Integer;
    value type OccupancyRatio => Real;

    value type GeoCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
    }

    value type TrainPosition {
        attribute coordinate : GeoCoordinate;
        attribute segmentId : String;
        attribute distanceAlongSegment : LengthUnit;
    }

    value type RoutePlan {
        attribute routeId : RouteId;
        attribute orderedStations : StationId[0..*];
        attribute scheduledArrivals : TimeOfDay[0..*];
        attribute scheduledDepartures : TimeOfDay[0..*];
    }

    value type Ticket {
        attribute ticketId : String;
        attribute validFrom : TimeOfDay;
        attribute validUntil : TimeOfDay;
        attribute zones : ZoneId[1..*];
        attribute price : CurrencyUnit;
        attribute fareClass : String;
    }

    value type SignalingCommand {
        attribute commandType : String;
        attribute targetTrain : TrainId;
        attribute speedLimit : SpeedUnit;
        attribute nextStation : StationId;
    }

    value type PositionReport {
        attribute trainId : TrainId;
        attribute position : TrainPosition;
        attribute speed : SpeedUnit;
        attribute timestamp : TimeOfDay;
    }

    // ===== Enumerations =====

    enum TrainType { ubahn, sbahn }
    enum TrainState { idle, accelerating, cruising, braking, dwelling, emergencyStop }
    enum PlatformStatus { available, occupied, maintenance }
    enum SignalAspect { green, yellow, red }
    enum TicketType { single, dayPass, monthly, reduced }

    // ===== Interfaces =====

    interface def PowerDelivery {
        in attribute voltage : VoltageUnit;
        in attribute current : CurrentUnit;
    }

    interface def SignalingLink {
        in attribute command : SignalingCommand;
        out attribute report : PositionReport;
    }

    interface def PassengerInterface {
        in attribute issuedTicket : Ticket;
        out attribute payment : CurrencyUnit;
    }

    interface def PlatformInterface {
        in attribute trainArrival : TrainId;
        out attribute boardingStatus : String;
    }

    // ===== Parts =====

    part def TransitVehicle {
        attribute trainId : TrainId;
        attribute trainType : TrainType;
        attribute maxCapacity : PassengerCount;
        attribute currentOccupancy : PassengerCount := 0;
        attribute position : TrainPosition;
        attribute speed : SpeedUnit := 0 [m/s];
        attribute assignedRoute : RoutePlan;

        port powerIn : PowerDelivery;
        port signalPort : SignalingLink;
        port platformPort : PlatformInterface;

        attribute state : TrainState := TrainState::idle;

        state vehicleStateMachine {
            entry; then idle;

            state idle;
            state accelerating;
            state cruising;
            state braking;
            state dwelling;
            state emergencyStop;

            transition idle_to_accelerating
                source idle
                target accelerating
                when signalPort.command.commandType == "dispatch";

            transition accelerating_to_cruising
                source accelerating
                target cruising
                when speed >= 20 [m/s];

            transition cruising_to_braking
                source cruising
                target braking
                when approachingStation();

            transition braking_to_dwelling
                source braking
                target dwelling
                when speed == 0 [m/s];

            transition dwelling_to_accelerating
                source dwelling
                target accelerating
                when dwellComplete();

            transition any_to_emergencyStop
                source *
                target emergencyStop
                when signalPort.command.commandType == "emergencyStop";

            transition emergencyStop_to_idle
                source emergencyStop
                target idle
                when signalPort.command.commandType == "clear";
        }

        compute updatePosition {
            // Action: update train position based on speed and time
        }

        compute updateOccupancy {
            // Action: adjust occupancy after boarding/alighting
        }

        private approachStation : Boolean;
        private approachStationFlag : Boolean := false;

        action def approachStationAction {
            in speed : SpeedUnit;
            in position : TrainPosition;
            out approaching : Boolean;
        }

        action def dwellAction {
            in station : StationId;
            in currentOccupancy : PassengerCount;
            out alighted : PassengerCount;
            out boarded : PassengerCount;
        }

        private approachingStation() : Boolean {
            return approachStationFlag;
        }

        private dwellComplete() : Boolean {
            return true;
        }
    }

    part def Station {
        attribute stationId : StationId;
        attribute location : GeoCoordinate;
        attribute zone : ZoneId;
        attribute platformCount : Integer;
        attribute platforms : PlatformNumber[0..*];

        port platformPorts : PlatformInterface[0..*];
        port passengerPorts : PassengerInterface[0..*];

        attribute platformStatus : PlatformStatus[0..*];

        compute managePlatforms {
            // Action: assign platforms to arriving trains
        }
    }

    part def Platform {
        attribute number : PlatformNumber;
        attribute status : PlatformStatus := PlatformStatus::available;
        port trainInterface : PlatformInterface;
        port passengerAccess : PassengerInterface;
    }

    part def ControlCenter {
        attribute networkId : String := "BerlinTransit";
        attribute managedTrains : TrainId[0..*];
        attribute managedStations : StationId[0..*];
        attribute routes : RoutePlan[0..*];

        port signalPorts : SignalingLink[0..*];

        compute assignRoute {
            in trainId : TrainId;
            in routePlan : RoutePlan;
            out command : SignalingCommand;
        }

        compute dispatchVehicle {
            in trainId : TrainId;
            out command : SignalingCommand;
        }

        compute receivePositionReport {
            in report : PositionReport;
            out updatedSchedule : RoutePlan;
        }

        compute coordinateSchedules {
            in allReports : PositionReport[0..*];
            out commands : SignalingCommand[0..*];
        }

        state controlCenterStateMachine {
            entry; then monitoring;

            state monitoring;
            state dispatching;
            state emergencyHandling;

            transition monitoring_to_dispatching
                source monitoring
                target dispatching
                when scheduleUpdateRequired();

            transition dispatching_to_monitoring
                source dispatching
                target monitoring
                when dispatchComplete();

            transition monitoring_to_emergencyHandling
                source monitoring
                target emergencyHandling
                when emergencyDetected();

            transition emergencyHandling_to_monitoring
                source emergencyHandling
                target monitoring
                when emergencyCleared();

            private scheduleUpdateRequired() : Boolean { return true; }
            private dispatchComplete() : Boolean { return true; }
            private emergencyDetected() : Boolean { return false; }
            private emergencyCleared() : Boolean { return true; }
        }
    }

    part def PowerGrid {
        attribute gridId : String := "BerlinTransitPower";
        attribute nominalVoltage : VoltageUnit := 750 [V];
        attribute nominalCurrent : CurrentUnit := 3000 [A];
        attribute totalPowerCapacity : PowerUnit := 2250000 [W];

        port powerOutPorts : PowerDelivery[0..*];

        compute distributePower {
            in demand : PowerUnit;
            out supplied : PowerUnit;
        }

        state powerGridStateMachine {
            entry; then normal;

            state normal;
            state loadBalancing;
            state fault;

            transition normal_to_loadBalancing
                source normal
                target loadBalancing
                when demandExceedsThreshold();

            transition loadBalancing_to_normal
                source loadBalancing
                target normal
                when demandStabilized();

            transition normal_to_fault
                source normal
                target fault
                when faultDetected();

            transition fault_to_normal
                source fault
                target normal
                when faultCleared();

            private demandExceedsThreshold() : Boolean { return false; }
            private demandStabilized() : Boolean { return true; }
            private faultDetected() : Boolean { return false; }
            private faultCleared() : Boolean { return true; }
        }
    }

    part def TicketingSystem {
        attribute systemId : String := "BerlinFareCollection";
        attribute dailyRevenue : CurrencyUnit := 0 [EUR];
        attribute ticketsIssued : Ticket[0..*];
        attribute fareZones : ZoneId[1..*] := {1, 2, 3};

        port passengerPorts : PassengerInterface[0..*];

        compute issueTicket {
            in ticketType : TicketType;
            in zones : ZoneId[1..*];
            in payment : CurrencyUnit;
            out ticket : Ticket;
        }

        compute validateTicket {
            in ticket : Ticket;
            in currentTime : TimeOfDay;
            in currentZone : ZoneId;
            out valid : Boolean;
        }

        compute updateRevenue {
            in payment : CurrencyUnit;
            out newTotal : CurrencyUnit;
        }

        state ticketingStateMachine {
            entry; then operational;

            state operational;
            state maintenance;

            transition operational_to_maintenance
                source operational
                target maintenance
                when maintenanceScheduled();

            transition maintenance_to_operational
                source maintenance
                target operational
                when maintenanceComplete();

            private maintenanceScheduled() : Boolean { return false; }
            private maintenanceComplete() : Boolean { return true; }
        }
    }

    part def TrackSegment {
        attribute segmentId : String;
        attribute fromStation : StationId;
        attribute toStation : StationId;
        attribute length : LengthUnit;
        attribute maxSpeed : SpeedUnit;
        attribute currentSignalAspect : SignalAspect := SignalAspect::green;

        port powerDelivery : PowerDelivery;
    }

    part def SignalingSystem {
        attribute systemId : String := "BerlinSignaling";
        port controlPort : SignalingLink[0..*];
        port trainPorts : SignalingLink[0..*];

        compute transmitCommand {
            in command : SignalingCommand;
            out transmitted : Boolean;
        }

        compute receiveReport {
            in report : PositionReport;
            out forwarded : Boolean;
        }
    }

    // ===== Requirements =====

    requirement def CapacityRequirement {
        subject system : BerlinTransitSystem;
        attribute minStations : Integer := 170;
        attribute minDailyPassengers : PassengerCount := 1500000;
        require system.stationCount >= minStations;
        require system.dailyPassengerVolume >= minDailyPassengers;
    }

    requirement def ReliabilityRequirement {
        subject system : BerlinTransitSystem;
        attribute minOnTimePerformance : Real := 0.95;
        require system.onTimePerformance >= minOnTimePerformance;
    }

    requirement def SafetyRequirement {
        subject system : BerlinTransitSystem;
        require all trains maintain safe following distance;
        require all trains respond to emergency stop commands within 2 [s];
    }

    requirement def PowerAvailabilityRequirement {
        subject grid : PowerGrid;
        require grid.nominalVoltage >= 600 [V];
        require grid.totalPowerCapacity >= 2000000 [W];
    }

    requirement def TicketingRequirement {
        subject ticketing : TicketingSystem;
        require ticketing.fareZones->size() >= 3;
        require ticketing.issueTicket returns valid Ticket for all TicketType;
    }

    // ===== Top-level System =====

    part def BerlinTransitSystem {
        attribute systemName : String := "Berlin Urban Transit";
        attribute stationCount : Integer := 175;
        attribute dailyPassengerVolume : PassengerCount := 1500000;
        attribute onTimePerformance : Real := 0.96;

        part controlCenter : ControlCenter;
        part powerGrid : PowerGrid;
        part ticketingSystem : TicketingSystem;
        part signalingSystem : SignalingSystem;

        part trains : TransitVehicle[0..*];
        part stations : Station[0..*];
        part trackSegments : TrackSegment[0..*];

        satisfy CapacityRequirement by system;
        satisfy ReliabilityRequirement by system;
        satisfy SafetyRequirement by system;
        satisfy PowerAvailabilityRequirement by powerGrid;
        satisfy TicketingRequirement by ticketingSystem;

        connection powerConnections connect powerGrid.powerOutPorts to trains.powerIn;
        connection signalingControl connect controlCenter.signalPorts to signalingSystem.controlPort;
        connection signalingTrain connect signalingSystem.trainPorts to trains.signalPort;
        connection platformConnections connect stations.platformPorts to trains.platformPort;
        connection passengerTicketing connect stations.passengerPorts to ticketingSystem.passengerPorts;
        connection trackPower connect trackSegments.powerDelivery to powerGrid.powerOutPorts;

        compute networkOperation {
            // Orchestrates dispatch, routing, and schedule coordination
            in dispatchRequests : TrainId[0..*];
            out commands : SignalingCommand[0..*];
        }
    }

    // ===== Instantiation =====

    part def BerlinTransitNetwork :> BerlinTransitSystem {
        // Representative subset of stations
        part alexanderplatz : Station {
            stationId = "U2_Alexanderplatz";
            location = GeoCoordinate { latitude = 52.5219; longitude = 13.4132; };
            zone = 1;
            platformCount = 6;
        }

        part hauptbahnhof : Station {
            stationId = "S_Hauptbahnhof";
            location = GeoCoordinate { latitude = 52.5251; longitude = 13.3694; };
            zone = 1;
            platformCount = 8;
        }

        part zoologischerGarten : Station {
            stationId = "S_ZoologischerGarten";
            location = GeoCoordinate { latitude = 52.5075; longitude = 13.3320; };
            zone = 1;
            platformCount = 4;
        }

        part trainU2_01 : TransitVehicle {
            trainId = "U2-001";
            trainType = TrainType::ubahn;
            maxCapacity = 800;
        }

        part trainS5_01 : TransitVehicle {
            trainId = "S5-001";
            trainType = TrainType::sbahn;
            maxCapacity = 1200;
        }

        part routeU2 : RoutePlan {
            routeId = "U2";
            orderedStations = ("Pankow", "Vinetastr", "Senefelderplatz", "Rosa-Luxemburg-Platz", "Alexanderplatz", "Klosterstr", "Markisches Museum", "Spittelmarkt", "Hausvogteiplatz", "Stadtmitte", "Mohrenstr", "Potsdamer Platz");
        }

        part routeS5 : RoutePlan {
            routeId = "S5";
            orderedStations = ("Ostkreuz", "Warschauer Str", "Frankfurter Allee", "Lichtenberg", "Alexanderplatz", "Hackescher Markt", "Friedrichstr", "Hauptbahnhof", "Bellevue", "Tiergarten", "Zoologischer Garten", "Charlottenburg", "Westkreuz");
        }
    }
}
