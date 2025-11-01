// Define the basic structure of a security system with a door sensor and an alarm.
package 'Security System' {
	private import ScalarValues::*;

	metadata def SecurityFeature;

	enum DoorState { open, closed }
	enum AlarmStatus { active, inactive }
	enum SystemState { armed, disarmed, triggered }

	item def DoorStatusReading {
		attribute state : DoorState;
	}

	item def AlarmCommand {
		attribute status : AlarmStatus;
	}

	port def DoorStatusOutPort {
		out :> DoorStatusReading;
	}

	port def DoorStatusInPort {
		in :> DoorStatusReading;
	}

	port def AlarmCommandOutPort {
		out :> AlarmCommand;
	}

	port def AlarmCommandInPort {
		in :> AlarmCommand;
	}

	flow def DoorStateFlow {
		ref :>> payload : DoorStatusReading;
		end sensorPort : DoorStatusOutPort;
		end controllerPort : DoorStatusInPort;
	}

	flow def AlarmControlFlow {
		ref :>> payload : AlarmCommand;
		end controllerPort : AlarmCommandOutPort;
		end alarmPort : AlarmCommandInPort;
	}

	@SecurityFeature
	part def DoorSensor {
		port statusOut : DoorStatusOutPort;
		attribute currentDoorState : DoorState = DoorState::closed;

		perform action senseAndReport {
			out reading : DoorStatusReading;
			bind reading.state = currentDoorState;
		}
		bind senseAndReport.reading to statusOut;
	}

	@SecurityFeature
	part def AlarmUnit {
		port commandIn : AlarmCommandInPort;

		exhibit state machine AlarmBehavior {
			initial state Inactive;

			state Inactive;
			state Active;

			transition from Inactive to Active
				when commandIn.status == AlarmStatus::active;

			transition from Active to Inactive
				when commandIn.status == AlarmStatus::inactive;
		}
	}

	@SecurityFeature
	part def SecurityController {
		port doorSensorIn : DoorStatusInPort;
		port alarmControlOut : AlarmCommandOutPort;

		exhibit state machine ControllerLogic {
			attribute command : AlarmCommand {
				attribute status : AlarmStatus = AlarmStatus::inactive;
			}

			initial state Disarmed {
				entry {
					command.status = AlarmStatus::inactive;
				}
			}

			state Armed {
				entry {
					command.status = AlarmStatus::inactive;
				}
			}

			state Triggered {
				entry {
					command.status = AlarmStatus::active;
				}
			}

			accept signal armSystem;
			accept signal disarmSystem;

			transition from Disarmed to Armed on armSystem;
			transition from Armed to Disarmed on disarmSystem;
			transition from Triggered to Disarmed on disarmSystem;

			transition from Armed to Triggered
				when doorSensorIn.state == DoorState::open;
		}
		bind ControllerLogic.command to alarmControlOut;
	}

	part homeSecuritySystem : SecurityController {
		part frontDoorSensor : DoorSensor;
		part mainAlarm : AlarmUnit;

		flow sensorToController : DoorStateFlow of DoorStatusReading
			from frontDoorSensor.statusOut to self.doorSensorIn;

		flow controllerToAlarm : AlarmControlFlow of AlarmCommand
			from self.alarmControlOut to mainAlarm.commandIn;
	}

	package Requirements {
		private import 'Security System'::*;

		requirement def SecuritySystemFunctionality {
			subject homeSecuritySystem;
			doc "The security system shall monitor a door and activate an alarm under specific conditions.";
		}

		requirement alarmActivation < SecuritySystemFunctionality {
			subject homeSecuritySystem;
			doc "When the system is armed and the monitored door is opened, the alarm shall be activated.";
		}

		requirement alarmDeactivation < SecuritySystemFunctionality {
			subject homeSecuritySystem;
			doc "When the system is disarmed, the alarm shall be inactive.";
		}

		satisfy alarmActivation by homeSecuritySystem.ControllerLogic;
		satisfy alarmDeactivation by homeSecuritySystem.ControllerLogic;
	}
}
