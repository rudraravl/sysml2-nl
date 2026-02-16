package PLCBUSHomeAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def HomeCode :> String;
	attribute def UnitCode :> Integer;
	attribute def CommandCode :> Integer;
	attribute def DataByte :> Integer;
	
	enum def PLCBUSCommandType {
		enum allUnitsOff;
		enum allLightsOn;
		enum on;
		enum off;
		enum dim;
		enum bright;
		enum allLightsOff;
		enum statusRequest;
		enum statusOn;
		enum statusOff;
		enum presetDim;
		enum getSignalStrength;
	}
	
	enum def TransmissionPhase {
		enum positive;
		enum negative;
		enum both;
	}
	
	item def PLCBUSMessage {
		attribute startCode : Integer;
		attribute homeCode : HomeCode;
		attribute unitCode : UnitCode;
		attribute commandType : PLCBUSCommandType;
		attribute dataField1 : DataByte;
		attribute dataField2 : DataByte;
		attribute rxTxSwitch : Boolean;
		attribute phase : TransmissionPhase;
	}
	
	attribute def CarrierFrequency :> ISQ::frequency {
		attribute nominalValue : Real = 131.0;
	}
	
	attribute def BitRate :> Real {
		attribute nominalValue : Real = 1200.0;
	}
	
	port def PLCBUSCommunicationPort {
		in item receivedMessages : PLCBUSMessage[*];
		out item transmittedMessages : PLCBUSMessage[*];
		attribute carrierFrequency : CarrierFrequency;
		attribute signalStrength : ISQ::power;
	}
	
	part def PowerLineNetwork {
		doc /* Represents the AC power line infrastructure used as the communication medium. */
		attribute lineVoltage : ISQ::voltage;
		attribute lineFrequency : ISQ::frequency;
		port networkPort[2..*] : PLCBUSCommunicationPort;
	}
	
	part def PLCBUSTransceiver {
		doc /* Physical layer device that modulates and demodulates PLCBUS signals on the power line. */
		attribute deviceAddress : HomeCode;
		port powerLinePort : PLCBUSCommunicationPort;
		
		part modulator {
			in attribute messageToSend : PLCBUSMessage;
			out attribute modulatedSignal : ISQ::power;
		}
		
		part demodulator {
			in attribute receivedSignal : ISQ::power;
			out attribute decodedMessage : PLCBUSMessage;
		}
		
		part transmitDriver {
			in attribute signal : ISQ::power;
			attribute outputPower : ISQ::power;
		}
		
		part receiveAmplifier {
			out attribute signal : ISQ::power;
			attribute gain : Real;
		}
	}
	
	part def PLCBUSController {
		doc /* Central controller that manages PLCBUS communication and device coordination. */
		attribute controllerHomeCode : HomeCode;
		port commPort : PLCBUSCommunicationPort;
		
		perform action controllerBehavior;
	}
	
	part def DimmableLight {
		doc /* A lighting load controlled via PLCBUS with dimming capability. */
		attribute assignedHomeCode : HomeCode;
		attribute assignedUnitCode : UnitCode;
		attribute currentBrightness : Real;
		attribute powerState : Boolean;
		port controlPort : PLCBUSCommunicationPort;
		
		part loadRelay {
			attribute isEngaged : Boolean;
		}
		
		part dimmerCircuit {
			attribute dimLevel : Real;
			attribute minLevel : Real = 0.0;
			attribute maxLevel : Real = 100.0;
		}
		
		perform action lightBehavior;
	}
	
	part def SwitchedOutlet {
		doc /* An electrical outlet controlled via PLCBUS with on/off capability. */
		attribute assignedHomeCode : HomeCode;
		attribute assignedUnitCode : UnitCode;
		attribute powerState : Boolean;
		attribute maxLoad : ISQ::power;
		port controlPort : PLCBUSCommunicationPort;
		
		part switchRelay {
			attribute isEngaged : Boolean;
		}
		
		perform action outletBehavior;
	}
	
	part def WallSwitch {
		doc /* A wall-mounted switch that transmits PLCBUS commands when pressed. */
		attribute transmitterHomeCode : HomeCode;
		attribute targetUnitCode : UnitCode;
		port commPort : PLCBUSCommunicationPort;
		
		perform action switchBehavior;
	}
	
	action def EncodeMessage {
		in homeCode : HomeCode;
		in unitCode : UnitCode;
		in command : PLCBUSCommandType;
		in data1 : DataByte;
		in data2 : DataByte;
		out message : PLCBUSMessage;
	}
	
	action def DecodeMessage {
		in message : PLCBUSMessage;
		out homeCode : HomeCode;
		out unitCode : UnitCode;
		out command : PLCBUSCommandType;
		out data1 : DataByte;
		out data2 : DataByte;
	}
	
	action def TransmitOnPowerLine {
		in message : PLCBUSMessage;
		in port : PLCBUSCommunicationPort;
		out success : Boolean;
	}
	
	action def ReceiveFromPowerLine {
		in port : PLCBUSCommunicationPort;
		out message : PLCBUSMessage;
		out valid : Boolean;
	}
	
	action def UpdateDeviceState {
		in command : PLCBUSCommandType;
		in currentState : Boolean;
		in currentLevel : Real;
		out newState : Boolean;
		out newLevel : Real;
	}
	
	action def PLCBUSCommunicationProtocol {
		first start;
		then merge listenLoop;
		then action receive : ReceiveFromPowerLine {
			out receivedMessage : PLCBUSMessage;
			out isValid : Boolean;
		}
		then decide;
			if receive.isValid then decode;
			if not receive.isValid then listenLoop;
		action decode : DecodeMessage {
			in message = receive.receivedMessage;
			out homeCode : HomeCode;
			out unitCode : UnitCode;
			out command : PLCBUSCommandType;
		}
		then action validateAddress {
			in receivedHome : HomeCode = decode.homeCode;
			in receivedUnit : UnitCode = decode.unitCode;
			out addressMatch : Boolean;
		}
		then decide;
			if validateAddress.addressMatch then processCommand;
			if not validateAddress.addressMatch then listenLoop;
		action processCommand : UpdateDeviceState {
			in command = decode.command;
			out newState : Boolean;
			out newLevel : Real;
		}
		then action applyState {
			in state : Boolean = processCommand.newState;
			in level : Real = processCommand.newLevel;
		}
		then action sendAcknowledgment : TransmitOnPowerLine {
			out ackSuccess : Boolean;
		}
		then listenLoop;
	}
	
	part plcbusHomeSystem {
		doc /* Complete PLCBUS-based home automation system with controller and multiple controlled devices. */
		
		attribute systemHomeCode : HomeCode = "A";
		attribute systemVoltage : ISQ::voltage = 120.0 [SI::V];
		attribute systemFrequency : ISQ::frequency = 60.0 [SI::Hz];
		
		part powerLine : PowerLineNetwork {
			attribute lineVoltage = plcbusHomeSystem.systemVoltage;
			attribute lineFrequency = plcbusHomeSystem.systemFrequency;
		}
		
		part controller : PLCBUSController {
			attribute controllerHomeCode = plcbusHomeSystem.systemHomeCode;
			perform action controllerBehavior : PLCBUSCommunicationProtocol;
		}
		
		part livingRoomLight : DimmableLight {
			attribute assignedHomeCode = plcbusHomeSystem.systemHomeCode;
			attribute assignedUnitCode = 1;
			attribute currentBrightness = 0.0;
			attribute powerState = false;
			perform action lightBehavior : PLCBUSCommunicationProtocol;
		}
		
		part bedroomLight : DimmableLight {
			attribute assignedHomeCode = plcbusHomeSystem.systemHomeCode;
			attribute assignedUnitCode = 2;
			attribute currentBrightness = 0.0;
			attribute powerState = false;
			perform action lightBehavior : PLCBUSCommunicationProtocol;
		}
		
		part kitchenOutlet : SwitchedOutlet {
			attribute assignedHomeCode = plcbusHomeSystem.systemHomeCode;
			attribute assignedUnitCode = 3;
			attribute powerState = false;
			attribute maxLoad = 1800.0 [SI::W];
			perform action outletBehavior : PLCBUSCommunicationProtocol;
		}
		
		part hallwaySwitch : WallSwitch {
			attribute transmitterHomeCode = plcbusHomeSystem.systemHomeCode;
			attribute targetUnitCode = 1;
			perform action switchBehavior : PLCBUSCommunicationProtocol;
		}
		
		part controllerTransceiver : PLCBUSTransceiver {
			attribute deviceAddress = plcbusHomeSystem.systemHomeCode;
		}
		
		connection controllerToPowerLine connect 
			controller.commPort to powerLine.networkPort;
		
		connection livingRoomLightToPowerLine connect 
			livingRoomLight.controlPort to powerLine.networkPort;
		
		connection bedroomLightToPowerLine connect 
			bedroomLight.controlPort to powerLine.networkPort;
		
		connection kitchenOutletToPowerLine connect 
			kitchenOutlet.controlPort to powerLine.networkPort;
		
		connection hallwaySwitchToPowerLine connect 
			hallwaySwitch.commPort to powerLine.networkPort;
		
		connection transceiverToPowerLine connect 
			controllerTransceiver.powerLinePort to powerLine.networkPort;
	}
	
	requirement def CommunicationReliability {
		doc /* PLCBUS communication shall provide reliable message delivery across the power line network. */
		
		require constraint messageDeliveryRate {
			doc /* Message delivery success rate shall exceed 95 percent under normal operating conditions. */
		}
		
		require constraint collisionHandling {
			doc /* System shall detect and recover from message collisions on the shared power line medium. */
		}
	}
	
	requirement def DeviceAddressing {
		doc /* PLCBUS system shall support unique addressing of multiple devices. */
		
		require constraint addressSpace {
			doc /* System shall support 256 home codes and 256 unit codes per home code. */
		}
		
		require constraint addressUniqueness {
			doc /* Each device shall respond only to messages matching its assigned home and unit code. */
		}
	}
	
	requirement def PowerLineCompatibility {
		doc /* PLCBUS system shall operate on standard residential AC power infrastructure. */
		
		require constraint voltageCompatibility {
			doc /* System shall operate on power lines with voltage between 100V and 240V AC. */
		}
		
		require constraint frequencyCompatibility {
			doc /* System shall operate on power lines with frequency of 50Hz or 60Hz. */
		}
		
		require constraint noiseImmunity {
			doc /* System shall maintain communication in presence of typical power line noise. */
		}
	}
	
	requirement def CommandExecution {
		doc /* PLCBUS devices shall execute received commands accurately and promptly. */
		
		require constraint responseTime {
			doc /* Device shall respond to valid commands within 200 milliseconds. */
		}
		
		require constraint commandAccuracy {
			doc /* Device shall execute commanded state changes with 100 percent accuracy. */
		}
	}
	
	requirement <'PLCBUS-SYS-REQ-001'> plcbusSystemRequirement {
		doc /* The PLCBUS home automation system shall enable centralized and distributed control 
		       of electrical devices throughout a residence by transmitting digital control commands 
		       over existing AC power line wiring, eliminating the need for dedicated control wiring 
		       while providing reliable two-way communication between controllers and controlled devices. */
		
		subject plcbusHomeSystem;
		
		assume constraint powerLineInfrastructure {
			doc /* Standard residential AC power line infrastructure is available and operational. */
		}
		
		assume constraint deviceInstallation {
			doc /* PLCBUS-compatible devices are properly installed and configured with unique addresses. */
		}
		
		require CommunicationReliability;
		require DeviceAddressing;
		require PowerLineCompatibility;
		require CommandExecution;
	}
}
