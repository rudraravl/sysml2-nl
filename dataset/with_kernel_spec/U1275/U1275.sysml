package BticinoHomeAutomation {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::V;
	private import SI::A;

	item def Power27VDC {
		attribute voltage : Real = 27 [V];
		attribute current : Real;
	}

	item def Power230VAC {
		attribute voltage : Real = 230 [V];
		attribute current : Real;
	}

	enum def LightCommand {
		turnOn;
		turnOff;
		dim;
	}

	item def SCSMessage {
		attribute source : String;
		attribute destination : String;
		attribute command : LightCommand;
		attribute dimmingLevel : Real;
	}

	port def SCSPowerInPort {
		in power : Power27VDC;
	}

	port def SCSPowerOutPort {
		out power : Power27VDC;
	}

	port def SCSBusDevicePort {
		out power : Power27VDC;
		inout msg : SCSMessage;
	}

	port def SCSDevicePort {
		in power : Power27VDC;
		inout msg : SCSMessage;
	}

	interface def SCSConnection {
		end busPort : SCSBusDevicePort;
		end devicePort : SCSDevicePort;
		flow of Power27VDC from busPort.power to devicePort.power;
		flow of SCSMessage from busPort.msg to devicePort.msg;
		flow of SCSMessage from devicePort.msg to busPort.msg;
	}

	part def PowerSupply {
		port mainsIn {
			in power : Power230VAC;
		}
		port scsOut : SCSPowerOutPort;
	}

	part def SCSBus {
		port powerIn : SCSPowerInPort;
		port livingRoomPort : SCSBusDevicePort;
		port bedroomPort : SCSBusDevicePort;
		port kitchenPort : SCSBusDevicePort;
		port hallwayPort : SCSBusDevicePort;
		port entranceSensorPort : SCSBusDevicePort;
		port roomSensorPort : SCSBusDevicePort;
		port controllerPort : SCSBusDevicePort;
	}

	part def LightActuator {
		attribute address : String;
		port scsPort : SCSDevicePort;
		exhibit state lightState {
			entry; then off;
			state off;
			state on;
			state dimmed;
			transition turnOnCmd
				first off
				accept msg : SCSMessage via scsPort.msg
				if msg.destination == address and msg.command == LightCommand::turnOn
				then on;
			transition turnOffFromOn
				first on
				accept msg : SCSMessage via scsPort.msg
				if msg.destination == address and msg.command == LightCommand::turnOff
				then off;
			transition dimCmd
				first on
				accept msg : SCSMessage via scsPort.msg
				if msg.destination == address and msg.command == LightCommand::dim
				then dimmed;
			transition turnOffFromDimmed
				first dimmed
				accept msg : SCSMessage via scsPort.msg
				if msg.destination == address and msg.command == LightCommand::turnOff
				then off;
		}
	}

	part def TouchSensor {
		attribute address : String;
		attribute targetAddress : String;
		port scsPort : SCSDevicePort;
		perform action sendCommand {
			send new SCSMessage(address, targetAddress, LightCommand::turnOn, 100.0) via scsPort.msg;
		}
	}

	part def ScenarioController {
		attribute address : String;
		port scsPort : SCSDevicePort;
		perform action activateGoodnight {
			send new SCSMessage(address, "LivingRoom", LightCommand::turnOff, 0.0) via scsPort.msg;
			then send new SCSMessage(address, "Bedroom", LightCommand::turnOff, 0.0) via scsPort.msg;
			then send new SCSMessage(address, "Kitchen", LightCommand::turnOff, 0.0) via scsPort.msg;
			then send new SCSMessage(address, "Hallway", LightCommand::turnOff, 0.0) via scsPort.msg;
		}
	}

	requirement def SafeLowVoltageRequirement {
		subject powerSupply : PowerSupply;
		/* The power supply shall output 27V DC. */
	}

	requirement def MessageBasedCommunicationRequirement {
		/* All devices shall communicate using SCS messages with source and destination addresses. */
	}

	requirement def ScenarioControlRequirement {
		/* The Scenario Controller shall coordinate multiple actuators simultaneously based on preset scenarios. */
	}

	part def Residence {
		part powerSupply : PowerSupply;
		part scsBus : SCSBus;

		connect powerSupply.scsOut to scsBus.powerIn;

		part livingRoomLight : LightActuator {
			:>> address = "LivingRoom";
		}
		interface scsBus.livingRoomPort to livingRoomLight.scsPort : SCSConnection;

		part bedroomLight : LightActuator {
			:>> address = "Bedroom";
		}
		interface scsBus.bedroomPort to bedroomLight.scsPort : SCSConnection;

		part kitchenLight : LightActuator {
			:>> address = "Kitchen";
		}
		interface scsBus.kitchenPort to kitchenLight.scsPort : SCSConnection;

		part hallwayLight : LightActuator {
			:>> address = "Hallway";
		}
		interface scsBus.hallwayPort to hallwayLight.scsPort : SCSConnection;

		part entranceSensor : TouchSensor {
			:>> address = "Entrance";
			:>> targetAddress = "Hallway";
		}
		interface scsBus.entranceSensorPort to entranceSensor.scsPort : SCSConnection;

		part roomSensor : TouchSensor {
			:>> address = "LivingRoomSensor";
			:>> targetAddress = "LivingRoom";
		}
		interface scsBus.roomSensorPort to roomSensor.scsPort : SCSConnection;

		part scenarioController : ScenarioController {
			:>> address = "Controller";
		}
		interface scsBus.controllerPort to scenarioController.scsPort : SCSConnection;

		requirement safeLowVoltageReq : SafeLowVoltageRequirement;
		requirement messageBasedCommReq : MessageBasedCommunicationRequirement;
		requirement scenarioControlReq : ScenarioControlRequirement;

		satisfy safeLowVoltageReq by powerSupply;
		satisfy messageBasedCommReq by scsBus;
		satisfy scenarioControlReq by scenarioController;
	}
}
