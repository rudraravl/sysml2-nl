// Create a requirement that an elevator stops at requested floors within 3 s.
package ElevatorSystem {
	private import SI::*;
	private import ISQ::*;
	private import ScalarValues::*;

	package Types {
		value def SpeedValue redefines RealValue { in unit m_per_s; }
		value def PositionValue redefines RealValue { in unit m; }

		enum def MotorDirection { up; down; stop; }
		enum def DoorAction { open; close; }
		enum def DoorState { opened; closed; opening; closing; }

		item def FloorRequest {
			attribute floor : Integer;
		}
		item def MotorCommand {
			attribute direction : MotorDirection;
			attribute targetSpeed : SpeedValue;
		}
		item def DoorCommand {
			attribute action : DoorAction;
		}
	}

	package Components {
		private import Types::*;

		port def RequestPort {
			in request : FloorRequest;
		}
		port def MotorControlPort {
			out command : MotorCommand;
		}
		port def DoorControlPort {
			out command : DoorCommand;
		}

		part def Motor {
			port control : ~MotorControlPort;
			attribute currentSpeed : SpeedValue = 0.0 [m/s];
		}

		part def Doors {
			port control : ~DoorControlPort;
			attribute state : DoorState = DoorState::closed;
		}

		part def Cabin {
			attribute currentFloor : Integer = 1;
			attribute position : PositionValue = 0.0 [m];
		}

		state machine def ElevatorControllerBehavior {
			port in requestPort : RequestPort;
			
			attribute targetFloor : Integer;
			
			initial state Idle;
			state Moving;
			state Stopping;
			state DoorsOpen;

			transition from Idle to Moving 
				on reception of FloorRequest from requestPort {
				action {
					targetFloor = in.floor;
				}
			}

			transition from Moving to Stopping 
				when self.owningPart.cabin.currentFloor == targetFloor;

			transition from Stopping to DoorsOpen 
				when self.owningPart.motor.currentSpeed == 0.0 [m/s];

			transition from DoorsOpen to Idle 
				after 5.0 [s];
		}

		part def ElevatorController {
			port requestPort : RequestPort;
			port motorControl : MotorControlPort;
			port doorControl : DoorControlPort;

			ref cabin : Cabin;
			ref motor : Motor;

			exhibit state machine behavior : ElevatorControllerBehavior {
				port requestPort = self.requestPort;
			}
		}
	}

	package Requirements {
		private import Components::*;
		private import SI::*;

		requirement stopTimeRequirement {
			doc "The elevator, having been commanded to stop at a floor, must come to a complete rest within 3 seconds.";
			subject controller : Components::ElevatorController;
			require constraint {
				duration(controller.behavior.Stopping) <= 3.0 [s]
			}
		}
	}

	part def Elevator {
		part cabin : Components::Cabin;
		part motor : Components::Motor;
		part doors : Components::Doors;
		part controller : Components::ElevatorController {
			ref cabin = self.cabin;
			ref motor = self.motor;
		}

		port requests : Components::RequestPort;

		connect self.requests to self.controller.requestPort;
		connect self.controller.motorControl to self.motor.control;
		connect self.controller.doorControl to self.doors.control;
	}

	part elevator : Elevator;
	
	satisfy Requirements::stopTimeRequirement by elevator.controller;
}
