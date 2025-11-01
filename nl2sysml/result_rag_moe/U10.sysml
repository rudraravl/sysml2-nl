// Model a smart home system that is able to turn on the lights.
package 'Smart Home Lighting System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	// Value and Item Definitions
	attribute def PowerCommand :> Boolean;
	attribute def LuminousIntensityValue specializing ISQ::LuminousIntensityValue;
	item def ElectricalPower;

	// Port Definitions for command signals
	port def UserCommandPort {
		out command : PowerCommand;
	}

	port def LightControlPort {
		out command : PowerCommand;
	}

	// Port Definitions for physical power flow
	port def PowerInputPort {
		in power : ElectricalPower;
	}

	port def PowerOutputPort {
		out power : ElectricalPower;
	}

	// Part Definitions
	part def UserInterface {
		port commandPort : UserCommandPort;
	}

	part def PowerSource {
		attribute voltage : ElectricPotentialValue = 120.0 [V];
		port powerPort : PowerOutputPort;
	}

	part def LightFixture {
		attribute powerConsumption : PowerValue = 60.0 [W];
		attribute currentIntensity : LuminousIntensityValue;

		port controlPort : ~LightControlPort;
		port powerIn : ~PowerInputPort;

		state machine lightState {
			initial state Off;

			state Off {
				entry assign currentIntensity = 0.0 [cd];
			}

			state On {
				entry assign currentIntensity = 100.0 [cd];
			}

			transition turnOn from Off to On
				accept at controlPort.command
				if controlPort.command == true;

			transition turnOff from On to Off
				accept at controlPort.command
				if controlPort.command == false;
		}
	}

	part def SmartController {
		port fromUser : ~UserCommandPort;
		port toLight : LightControlPort;

		state machine controllerLogic {
			initial state Listening;
			state Listening {
				accept at fromUser.command {
					assign toLight.command = fromUser.command;
				}
			}
		}
	}

	// Top-level System Definition and Usage
	part smartHomeSystem {
		part ui : UserInterface;
		part controller : SmartController;
		part light : LightFixture;
		part power : PowerSource;

		interface userToController connect ui.commandPort to controller.fromUser;
		interface controllerToLight connect controller.toLight to light.controlPort;

		flow of ElectricalPower from power.powerPort to light.powerIn;
	}

	// Requirement Definition
	requirement def LightingControlRequirement {
		doc "The system shall provide the capability to control lighting based on user input.";
		id = "SH-L-01";
		subject system : smartHomeSystem;

		require turnOnRequirement {
			doc "The system shall turn the light on when the user issues an 'on' command.";
			id = "SH-L-01.1";
		}

		require turnOffRequirement {
			doc "The system shall turn the light off when the user issues an 'off' command.";
			id = "SH-L-01.2";
		}
	}

	// Requirement Usage
	requirement mainRequirement : LightingControlRequirement {
		subject = smartHomeSystem;
		text = "The smart home system shall allow a user to turn the light fixture on and off via a user interface and a central controller.";
	}
}
