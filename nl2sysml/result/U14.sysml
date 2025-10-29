// Create a requirement that an elevator stops at requested floors within 3 s.
package 'ElevatorSystem' {
	private import SI::*;
	part def Elevator {
		perform stopAtFloor : StopAtFloor;
	}
	action def StopAtFloor;
	requirement elevatorStopResponseTime {
		subject elevator : Elevator;
		require constraint {
			elevator.stopAtFloor.duration <= 3.0 [s]
		}
	}
}
