package 'Berlin Urban Transit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def PassengerCount;
	attribute def StationIdentifier;
	attribute def RouteIdentifier;
	attribute def VehicleIdentifier;
	
	item def Passenger {
		attribute boardingStation : StationIdentifier;
		attribute destinationStation : StationIdentifier;
	}
	
	item def TransitTicket {
		attribute validFrom : ISQ::TimeValue;
		attribute validUntil : ISQ::TimeValue;
		attribute zonesCovered : Integer;
	}
	
	port def PassengerInterface {
		in passengers : Passenger[*];
		out tickets : TransitTicket[*];
	}
	
	port def PowerSupply {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
	}
	
	port def SignalInterface {
		in routeCommand : RouteIdentifier;
		out positionReport : ISQ::LengthValue;
	}
	
	part def Station {
		attribute stationId : StationIdentifier;
		attribute location : ISQ::LengthValue[2];
		attribute platformCount : Integer;
		port passengerAccess : PassengerInterface;
	}
	
	part def TransitVehicle {
		attribute vehicleId : VehicleIdentifier;
		attribute capacity : PassengerCount;
		attribute currentSpeed : ISQ::SpeedValue;
		attribute position : ISQ::LengthValue;
		port power : PowerSupply;
		port signaling : SignalInterface;
		port boarding : PassengerInterface;
	}
	
	part def ControlCenter {
		attribute activeRoutes : RouteIdentifier[*];
		port vehicleControl[*] : SignalInterface;
	}
	
	part def PowerGrid {
		attribute totalCapacity : ISQ::PowerValue;
		port distribution[*] : PowerSupply;
	}
	
	part def TicketingSystem {
		attribute dailyRevenue : Real;
		port customerInterface[*] : PassengerInterface;
	}
	
	action def BoardPassengers {
		in station : StationIdentifier;
		in availableCapacity : PassengerCount;
		out boardedCount : PassengerCount;
	}
	
	action def AlightPassengers {
		in station : StationIdentifier;
		in currentPassengers : PassengerCount;
		out alightedCount : PassengerCount;
	}
	
	action def MoveToNextStation {
		in currentPosition : ISQ::LengthValue;
		in targetStation : StationIdentifier;
		in maxSpeed : ISQ::SpeedValue;
		out newPosition : ISQ::LengthValue;
		out travelTime : ISQ::TimeValue;
	}
	
	action def ValidateTicket {
		in ticket : TransitTicket;
		in currentTime : ISQ::TimeValue;
		out isValid : Boolean;
	}
	
	action def OperateTransitRoute {
		in routeId : RouteIdentifier;
		in stationSequence : StationIdentifier[*];
		in assignedVehicle : VehicleIdentifier;
		in totalStationsInSequence : Integer;
		
		private attribute currentStationIndex : Integer := 0;
		
		first start;
		then merge continueRoute;
		
		then action checkSchedule {
			out nextStation : StationIdentifier;
			out departureTime : ISQ::TimeValue;
		}
		
		then action moveVehicle : MoveToNextStation {
			in currentPosition;
			in targetStation = checkSchedule.nextStation;
			in maxSpeed;
			out newPosition;
			out travelTime;
		}
		
		then action arriveAtStation {
			in station = checkSchedule.nextStation;
		}
		
		then action alightPassengers : AlightPassengers {
			in station = checkSchedule.nextStation;
			in currentPassengers;
			out alightedCount;
		}
		
		then action boardPassengers : BoardPassengers {
			in station = checkSchedule.nextStation;
			in availableCapacity;
			out boardedCount;
		}
		
		then decide routeComplete;
			if currentStationIndex >= totalStationsInSequence then endRoute;
			else continueRoute;
		
		action endRoute;
		then done;
	}
	
	action def ManageSystemOperations {
		in operatingHours : ISQ::TimeValue;
		in activeVehicleCount : Integer;
		
		first start;
		then merge operationCycle;
		
		then action monitorVehicles {
			out vehicleStatus : VehicleIdentifier[*];
			out systemLoad : Real;
		}
		
		then action dispatchVehicles {
			in vehicleStatus = monitorVehicles.vehicleStatus;
			out routeAssignments : RouteIdentifier[*];
		}
		
		then action coordinateSchedules {
			in assignments = dispatchVehicles.routeAssignments;
			out optimizedSchedule : ISQ::TimeValue[*];
		}
		
		then action processTicketing {
			out ticketsSold : Integer;
			out revenue : Real;
		}
		
		then decide continueOperations;
			if monitorVehicles.systemLoad > 0.0 then operationCycle;
			else shutdown;
		
		action shutdown;
		then done;
	}
	
	part def BerlinTransitSystem {
		attribute systemName : String = "Berlin U-Bahn and S-Bahn Network";
		attribute stationCount : Integer = 173;
		attribute routeLength : ISQ::LengthValue = 350[km];
		attribute passengerCount : PassengerCount = 1500000;
		
		part stations[173] : Station;
		part vehicles[*] : TransitVehicle;
		part controlCenter : ControlCenter;
		part powerGrid : PowerGrid;
		part ticketingSystem : TicketingSystem;
		
		connect powerGrid.distribution to vehicles.power;
		connect controlCenter.vehicleControl to vehicles.signaling;
		connect ticketingSystem.customerInterface to stations.passengerAccess;
		
		perform action systemOperation[*] ordered : ManageSystemOperations;
	}
	
	part berlinTransit : BerlinTransitSystem {
		part alexanderplatz : Station {
			attribute stationId = "U2-AP";
			attribute platformCount = 4;
		}
		
		part hauptbahnhof : Station {
			attribute stationId = "S5-HBF";
			attribute platformCount = 6;
		}
		
		part vehicle1 : TransitVehicle {
			attribute vehicleId = "U-1001";
			attribute capacity = 900;
			perform systemOperation.dispatchVehicles;
		}
		
		part vehicle2 : TransitVehicle {
			attribute vehicleId = "S-2001";
			attribute capacity = 1200;
			perform systemOperation.dispatchVehicles;
		}
		
		part cc : ControlCenter {
			perform systemOperation.coordinateSchedules;
		}
		
		part pg : PowerGrid {
			attribute totalCapacity = 150000000[W];
		}
		
		part ts : TicketingSystem {
			perform systemOperation.processTicketing;
		}
	}
	
	requirement <'BTS-1'> primaryFunctionRequirement {
		doc /* The Berlin Transit System shall provide efficient, reliable public transportation 
		       throughout the city, enabling passengers to travel between stations on scheduled routes. */
		
		assume constraint {
			berlinTransit.stationCount >= 100
		}
		
		require constraint {
			berlinTransit.vehicles->notEmpty()
		}
	}
	
	requirement <'BTS-2'> capacityRequirement {
		doc /* The system shall transport a minimum of 1.5 million passengers daily 
		       across all routes and vehicle types. */
		
		require constraint {
			berlinTransit.passengerCount >= 1500000
		}
	}
	
	requirement <'BTS-3'> reliabilityRequirement {
		doc /* The system shall maintain 95% on-time performance for all scheduled services 
		       during normal operating conditions. */
	}
	
	requirement <'BTS-4'> coverageRequirement {
		doc /* The transit network shall provide comprehensive coverage with stations 
		       distributed to serve all major districts of Berlin. */
		
		require constraint {
			berlinTransit.routeLength >= 300[km]
		}
	}
	
	requirement <'BTS-5'> safetyRequirement {
		doc /* The system shall operate with automated signaling and control systems 
		       to ensure passenger safety and prevent collisions. */
	}
	
	requirement <'BTS-6'> accessibilityRequirement {
		doc /* The ticketing system shall provide multiple payment options and 
		       zone-based fare structures accessible to all passengers. */
	}
}
