// Model a smart home system that is able to turn on the lights.
package 'Smart Home System' {
	private import ScalarValues::*;
	private import SI;

	// Value and Item Definitions
	enum def OnOffCommand {
		On,
		Off
	}

	attribute def LuminosityValue : Real {
		unit = SI::lumen;
	}

	item def Light {
		attribute luminosity : LuminosityValue;
	}

	item def UserCommand {
		attribute command : OnOffCommand;
	}

	// Port Definitions
	port def UserCommandPort {
		out command : UserCommand;
	}

	port def DeviceControlPort {
		in command : OnOffCommand;
	}

	port def LightPort {
		out light : Light;
	}

	// Part Definitions
	part def User {
		port commandPort : UserCommandPort;
	}

	part def SmartLightBulb {
		port controlPort : ~DeviceControlPort;
		port lightPort : LightPort;

		state LightState {
			initial state Off;
			state On {
				entry generateLight {
					out light = lightPort.light;
					light.luminosity = 800[SI::lumen];
				}
			}

			transition from Off to On
				when controlPort.command == OnOffCommand::On;

			transition from On to Off
				when controlPort.command == OnOffCommand::Off;
		}
	}

	part def SmartHomeHub {
		port userInterfacePort : ~UserCommandPort;
		port deviceNetworkPort : ~DeviceControlPort;

		accept userInterfacePort.command;
		emit deviceNetworkPort.command;

		flow from userInterfacePort.command.command to deviceNetworkPort.command;
	}

	part def Room {
		port illuminationPort : ~LightPort;
	}

	// System Composition and Behavior
	part def SmartHome {
		part user : User;
		part hub : SmartHomeHub;
		part livingRoomLight : SmartLightBulb;
		part livingRoom : Room;

		connect user.commandPort to hub.userInterfacePort;
		connect hub.deviceNetworkPort to livingRoomLight.controlPort;
		connect livingRoomLight.lightPort to livingRoom.illuminationPort;

		perform TurnOnLightScenario;
	}

	action def TurnOnLightScenario {
		action userIssuesCommand performed by SmartHome.user {
			out cmd : UserCommand = SmartHome.user.commandPort.command;
			cmd.command = OnOffCommand::On;
		}

		action hubProcessesCommand performed by SmartHome.hub {
			in userCmd : UserCommand = SmartHome.hub.userInterfacePort.command;
			out deviceCmd : OnOffCommand = SmartHome.hub.deviceNetworkPort.command;
			deviceCmd = userCmd.command;
		}

		action bulbActivates performed by SmartHome.livingRoomLight {
			in deviceCmd : OnOffCommand = SmartHome.livingRoomLight.controlPort.command;
			out lightOutput : Light = SmartHome.livingRoomLight.lightPort.light;
		}

		succession from userIssuesCommand to hubProcessesCommand;
		succession from hubProcessesCommand to bulbActivates;
	}

	// Requirements
	requirement def 'Light Activation' {
		subject system : SmartHome;
		doc "The smart home system shall activate the designated light bulb upon receiving an 'On' command from the user.";
	}

	satisfy 'Light Activation' by TurnOnLightScenario;
}
