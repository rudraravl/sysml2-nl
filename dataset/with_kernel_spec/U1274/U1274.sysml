package BerlinUrbanTransit {
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::DateTime;
    private import SequenceFunctions::size;

    attribute def TransitId :> String;
    attribute def StationName :> String;
    attribute def PassengerCount :> Integer;
    attribute def ZoneId :> String;
    attribute def Revenue :> Real;

    item def TransitCommand {
        attribute routeId : TransitId;
        attribute targetStation : TransitId;
        attribute targetSpeed : SpeedValue;
    }

    item def PositionReport {
        attribute vehicleId : TransitId;
        attribute position : LengthValue;
        attribute speed : SpeedValue;
        attribute passengers : PassengerCount;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }

    item def Ticket {
        attribute ticketId : String;
        attribute validFrom : DateTime;
        attribute validTo : DateTime;
        attribute zone : ZoneId;
        attribute price : Revenue;
    }

    item def PassengerFlow {
        attribute boarding : PassengerCount;
        attribute alighting : PassengerCount;
    }

    attribute def RouteAssignment {
        attribute routeId : TransitId;
        attribute stationSequence : TransitId[*] ordered;
        attribute departureTimes : DateTime[*] ordered;
    }

    part def TransitVehicle {
        attribute id : TransitId;
        attribute capacity : PassengerCount;
        attribute currentPassengers : PassengerCount := 0;
        attribute position : LengthValue;
        attribute speed : SpeedValue;
        attribute assignedRoute : RouteAssignment;

        port commandPort {
            in command : TransitCommand;
        }
        port reportPort {
            out report : PositionReport;
        }
        port powerPort {
            in power : ElectricalPower;
        }
        port passengerPort {
            in boarding : PassengerFlow;
            out alighting : PassengerFlow;
        }

        exhibit state operationalState {
            entry; then idle;
            state idle;
            then moving;
            state moving;
            then stopped;
            state stopped;
            then doorsOpen;
            state doorsOpen;
            then boarding;
            state boarding;
            then moving;
        }

        action executeRoute {
            action accelerate;
            then action travel;
            then action decelerate;
            then action arrive;
            then action openDoors;
            then action alightPassengers;
            then action boardPassengers;
            then action closeDoors;
            then action depart;
        }
    }

    part def Station {
        attribute id : TransitId;
        attribute name : StationName;
        attribute location : LengthValue;
        attribute platformCount : Integer;

        port ticketPort {
            in issuedTicket : Ticket;
            out validatedTicket : Ticket;
        }
        port boardingPort {
            out boarding : PassengerFlow;
            in alighting : PassengerFlow;
        }
        port signalPort {
            out arrivingTrain : TransitId;
            out departingTrain : TransitId;
        }

        occurrence trainArrival;
        occurrence trainDeparture;
    }

    part def ControlCenter {
        attribute dispatchedVehicles : TransitId[*];
        attribute routes : RouteAssignment[*] ordered;

        port commandPort {
            out command : TransitCommand;
        }
        port reportPort {
            in report : PositionReport;
        }
        port stationPort {
            in trainArrival : TransitId;
            in trainDeparture : TransitId;
        }

        action monitorNetwork {
            action assignRoutes;
            then action dispatchVehicles;
            then action receiveReports;
        }
    }

    part def PowerGrid {
        attribute totalCapacity : PowerValue;
        attribute currentLoad : PowerValue;

        port powerPort {
            out power : ElectricalPower;
        }
    }

    part def TicketingSystem {
        attribute dailyRevenue : Revenue := 0;
        attribute ticketsIssued : Integer := 0;

        port stationPort {
            out issuedTicket : Ticket;
            in validatedTicket : Ticket;
        }

        action sellTicket {
            in zone : ZoneId;
            out ticket : Ticket;
        }

        action validateTicket {
            in ticket : Ticket;
            out isValid : Boolean;
        }

        action calculateDailyRevenue;
    }

    part def BerlinTransitSystem {
        attribute dailyPassengers : PassengerCount;
        attribute stationCount : Integer;

        part controlCenter : ControlCenter;
        part powerGrid : PowerGrid;
        part ticketingSystem : TicketingSystem;
        part stations : Station[170..*];
        part vehicles : TransitVehicle[1..*];

        interface powerInterface connect powerGrid.powerPort to vehicles.powerPort {
            flow powerFlow of ElectricalPower
                from powerGrid.powerPort.power to vehicles.powerPort.power;
        }

        interface commandInterface connect controlCenter.commandPort to vehicles.commandPort {
            flow commandFlow of TransitCommand
                from controlCenter.commandPort.command to vehicles.commandPort.command;
        }

        interface reportInterface connect vehicles.reportPort to controlCenter.reportPort {
            flow reportFlow of PositionReport
                from vehicles.reportPort.report to controlCenter.reportPort.report;
        }

        interface stationSignalInterface connect stations.signalPort to controlCenter.stationPort {
            flow arrivalFlow of TransitId
                from stations.signalPort.arrivingTrain to controlCenter.stationPort.trainArrival;
            flow departureFlow of TransitId
                from stations.signalPort.departingTrain to controlCenter.stationPort.trainDeparture;
        }

        interface ticketingInterface connect ticketingSystem.stationPort to stations.ticketPort {
            flow issueFlow of Ticket
                from ticketingSystem.stationPort.issuedTicket to stations.ticketPort.issuedTicket;
            flow validationFlow of Ticket
                from stations.ticketPort.validatedTicket to ticketingSystem.stationPort.validatedTicket;
        }

        interface passengerInterface connect stations.boardingPort to vehicles.passengerPort {
            flow boardingFlow of PassengerFlow
                from stations.boardingPort.boarding to vehicles.passengerPort.boarding;
            flow alightingFlow of PassengerFlow
                from vehicles.passengerPort.alighting to stations.boardingPort.alighting;
        }
    }

    occurrence def DailyOperation {
        attribute date : DateTime;
        attribute totalPassengers : PassengerCount;
        attribute totalRevenue : Revenue;
        occurrence morningRush;
        occurrence midday;
        occurrence eveningRush;
    }

    occurrence dailyOps : DailyOperation;

    requirement def TransitEfficiencyRequirement {
        subject system : BerlinTransitSystem;
        doc /* The system shall provide efficient public transportation serving approximately 1.5 million passengers daily across at least 170 stations. */
        constraint { system.dailyPassengers >= 1500000 }
        constraint { system.stationCount >= 170 }
    }

    requirement def ReliabilityRequirement {
        subject system : BerlinTransitSystem;
        doc /* The system shall ensure on-time performance and coordinated scheduling across the network. */
    }

    requirement def SafetyRequirement {
        subject system : BerlinTransitSystem;
        doc /* All trains shall maintain safe following distances as enforced by the control center signaling system. */
    }

    requirement efficiencyReq : TransitEfficiencyRequirement;
    requirement reliabilityReq : ReliabilityRequirement;
    requirement safetyReq : SafetyRequirement;
}
