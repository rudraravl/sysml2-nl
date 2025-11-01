// Define the basic structure of a security system with a door sensor and an alarm.
package 'Security System' {
	private import ScalarValues::*;

	metadata def SecurityComponent {
		attribute criticality : Integer;
		attribute description : String;
	}

	enum def DoorStatus {
		open,
		closed
	}

	enum def AlarmCommand {
		activate,
		deactivate
	}

	enum def UserCommand {
		arm,
		disarm
	}

	port def DoorStatusOut {
		out status : DoorStatus;
	}

	port def DoorStatusIn {
		in status : DoorStatus;
	}

	port def AlarmCommandOut {
		out command : AlarmCommand;
	}

	port def AlarmCommandIn {
		in command : AlarmCommand;
	}

	port def UserCommandIn {
		in command : UserCommand;
	}

	part def DoorSensor {
		metadata isSecurityComponent : SecurityComponent {
			criticality = 1;
			description = "Detects the physical state of an entry point.";
		}
		port statusPort : DoorStatusOut;
		exhibit state currentStatus : DoorStatus = DoorStatus::closed;
		bind statusPort.status = currentStatus;
	}

	part def Alarm {
		metadata isSecurityComponent : SecurityComponent {
			criticality = 2;
			description = "Provides audible and/or visual notification of an alert state.";
		}
		port commandPort : AlarmCommandIn;

		state machine AlarmBehavior {
			initial state Idle;
			state Sounding;

			transition from Idle to Sounding
				accept at commandPort.command when commandPort.command == AlarmCommand::activate;

			transition from Sounding to Idle
				accept at commandPort.command when commandPort.command == AlarmCommand::deactivate;
		}
	}

	part def ControlPanel {
		metadata isSecurityComponent : SecurityComponent {
			criticality = 3;
			description = "Processes sensor data and user commands to manage system state.";
		}
		port sensorInput : DoorStatusIn;
		port alarmOutput : AlarmCommandOut;
		port userInput : UserCommandIn;

		state machine SystemLogic {
			initial state Disarmed {
				entry {
					alarmOutput.command = AlarmCommand::deactivate;
				}
			}
			state Armed;
			state Triggered {
				entry {
					alarmOutput.command = AlarmCommand::activate;
				}
			}

			transition armSystem from Disarmed to Armed
				accept at userInput.command when userInput.command == UserCommand::arm;

			transition disarmSystemFromArmed from Armed to Disarmed
				accept at userInput.command when userInput.command == UserCommand::disarm;

			transition triggerAlarm from Armed to Triggered
				accept at sensorInput.status when sensorInput.status == DoorStatus::open;

			transition disarmSystemFromTriggered from Triggered to Disarmed
				accept at userInput.command when userInput.command == UserCommand::disarm;
		}
	}

	part def HomeSecuritySystem {
		part sensor : DoorSensor;
		part alarm : Alarm;
		part controller : ControlPanel;
		port userInterface : UserCommandIn redefines controller.userInput;

		connect sensor.statusPort to controller.sensorInput;
		connect controller.alarmOutput to alarm.commandPort;
	}

	requirement def AlarmOnIntrusion {
		doc "The alarm must activate if the door is opened while the system is armed.";
		subject controller : ControlPanel;
	}

	requirement def NoAlarmWhenDisarmed {
		doc "The alarm must not activate if the door is opened while the system is disarmed.";
		subject controller : ControlPanel;
	}

	part system : HomeSecuritySystem {
		requirement alarmActivationReq : AlarmOnIntrusion {
			subject = controller;
		}
		requirement noFalseAlarmReq : NoAlarmWhenDisarmed {
			subject = controller;
		}

		satisfy alarmActivationReq by controller.SystemLogic.triggerAlarm;
		satisfy noFalseAlarmReq by controller.SystemLogic.Disarmed;
	}

	package 'Security Critical Parts' {
		public import system::*;
		filter @SecurityComponent;
	}
}
