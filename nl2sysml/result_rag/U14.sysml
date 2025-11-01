// Create a requirement that an elevator stops at requested floors within 3 s.
package ElevatorSystem {
	private import SI::*;
	
	package Types {
		attribute def floorNumber is Integer;
		
		item def FloorRequest {
			attribute target : floorNumber;
			attribute requestTime : TimeValue;
		}
		
		item def CarStatus {
			attribute currentFloor : floorNumber;
			attribute doorsAreOpen : Boolean;
		}
		
		item def MotorCommand {
			attribute destination : floorNumber;
		}
	}
	
	package Behaviors {
		private import Types::*;
		
		action def ReceiveRequest {
			out request : FloorRequest;
			attribute startTime : TimeValue;
			
			bind request.requestTime = startTime;
		}
		
		action def ArriveAtDestination {
			in floor : floorNumber;
			attribute startTime : TimeValue;
		}
		
		behavior def ServiceRequestJourney {
			step requestReceived : ReceiveRequest;
			step carArrived : ArriveAtDestination;
			
			succession first requestReceived then carArrived;
			
			constraint {
				carArrived.floor == requestReceived.request.target
			}
		}
		
		state machine def ElevatorControllerLogic {
			initial state Idle;
			state Moving;
			state ServicingFloor;
			
			transition from Idle to Moving 
				when FloorRequest
				/ { send MotorCommand; }
			
			transition from Moving to ServicingFloor
				when CarStatus.currentFloor == MotorCommand.destination
				/ { entry OpenDoors; }
			
			transition from ServicingFloor to Idle
				after 2 [s]
				/ { entry CloseDoors; }
		}
	}
	
	package Requirements {
		private import Behaviors::ServiceRequestJourney;
		
		requirement def StopAtFloorInTime {
			doc "An elevator must stop at a requested floor within 3 seconds of the request being registered.";
			
			subject journey : ServiceRequestJourney;
			
			require constraint ResponseTime {
				journey.carArrived.startTime - journey.requestReceived.startTime <= 3.0 [s]
			}
		}
	}
	
	package Architecture {
		private import Types::*;
		private import Behaviors::*;
		private import Requirements::*;
		
		port def RequestPort {
			in req : FloorRequest;
		}
		
		port def StatusPort {
			out status : CarStatus;
			in status : CarStatus;
		}
		
		port def CommandPort {
			out cmd : MotorCommand;
		}
		
		part def ControlSystem {
			port requests : RequestPort;
			port commands : CommandPort;
			port carStatusIn : StatusPort { in status; }
			
			state machine logic : ElevatorControllerLogic;
		}
		
		part def HoistMotor {
			port commandIn : CommandPort { in cmd; }
			port statusOut : StatusPort { out status; }
			
			attribute targetFloor : floorNumber;
			bind targetFloor = commandIn.cmd.destination;
		}
		
		part def ElevatorCar {
			port statusOut : StatusPort { out status; }
			attribute currentFloor : floorNumber = 1;
			attribute doorsOpen : Boolean = true;
			
			bind statusOut.status.currentFloor = currentFloor;
			bind statusOut.status.doorsAreOpen = doorsOpen;
		}
		
		part def Elevator {
			port floorCall : RequestPort;
			
			part car : ElevatorCar;
			part motor : HoistMotor;
			part controller : ControlSystem;
			
			connect floorCall to controller.requests;
			connect controller.commands to motor.commandIn;
			
			// Feedback loop for car status
			connect car.statusOut to controller.carStatusIn;
			// Motor could also provide status, but for simplicity we use the car's
			connect car.statusOut to motor.statusOut;
			
			// The overall system behavior is a sequence of service journeys
			perform serviceJourney[*] : ServiceRequestJourney;
			
			// Bind the performed behavior to the system's interface
			bind serviceJourney.requestReceived.request <~ floorCall.req;
			bind serviceJourney.carArrived.floor = car.currentFloor;
			
			// The system's behavior must satisfy the requirement
			satisfy StopAtFloorInTime by serviceJourney;
		}
	}
}
