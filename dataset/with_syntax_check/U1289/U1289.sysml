package 'HomeLink Wireless Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def RFSignal {
		attribute frequency : FrequencyValue;
		attribute encodedData : String;
		attribute signalStrength : PowerValue;
	}
	
	item def DeviceCode {
		attribute manufacturerID : String;
		attribute deviceID : String;
		attribute rollingCode : Integer;
	}
	
	item def UserCommand {
		attribute buttonID : Integer;
		attribute timestamp : Real;
	}
	
	enum def OperationMode {
		enum normal;
		enum programming;
		enum transmitting;
	}
	
	enum def DoorState {
		enum closed;
		enum opening;
		enum open;
		enum closing;
	}
	
	port def UserInputPort {
		in item buttonPress : UserCommand;
	}
	
	port def RFTransmitPort {
		out item signal : RFSignal;
	}
	
	port def RFReceivePort {
		in item signal : RFSignal;
	}
	
	port def ActuatorPort {
		out item activationSignal : Boolean;
	}
	
	part def ControlButton {
		attribute buttonNumber : Integer;
		attribute assignedDeviceSlot : Integer;
		port userInterface : UserInputPort;
		
		action def SendButtonPress {
			in press : UserCommand;
		}
		
		perform action handleButtonPress : SendButtonPress;
	}
	
	part def MemoryStorage {
		attribute storedCodes : DeviceCode[3];
		attribute maxCapacity : Integer = 3;
		
		action def StoreDeviceCode {
			in code : DeviceCode;
			in slot : Integer;
			out success : Boolean;
		}
		
		action def RetrieveDeviceCode {
			in slot : Integer;
			out code : DeviceCode;
		}
		
		action def EraseDeviceCode {
			in slot : Integer;
			out success : Boolean;
		}
	}
	
	part def RFTransceiver {
		attribute operatingFrequency : FrequencyValue;
		attribute transmitPower : PowerValue;
		attribute range : LengthValue;
		port transmit : RFTransmitPort;
		port receive : RFReceivePort;
		
		action def EncodeAndTransmit {
			in deviceCode : DeviceCode;
			in command : UserCommand;
			out rfSignal : RFSignal;
		}
		
		action def ReceiveAndDecode {
			in rfSignal : RFSignal;
			out deviceCode : DeviceCode;
		}
	}
	
	part def ControlProcessor {
		attribute currentMode : OperationMode;
		
		action def ProcessUserInput {
			in userCmd : UserCommand;
			in deviceCode : DeviceCode;
			out transmitSignal : RFSignal;
		}
		
		action def LearnDevice {
			in receivedSignal : RFSignal;
			in targetSlot : Integer;
			out learnedCode : DeviceCode;
		}
	}
	
	part def GarageDoorReceiver {
		attribute deviceID : String;
		attribute validCodes : DeviceCode[*];
		port rfInput : RFReceivePort;
		port motorOutput : ActuatorPort;
		
		action def ValidateAndActivate {
			in receivedSignal : RFSignal;
			out activationCommand : Boolean;
		}
	}
	
	part def GarageDoorMechanism {
		attribute currentPosition : DoorState;
		port controlInput : ActuatorPort;
		
		action def OperateDoor {
			in activationSignal : Boolean;
		}
	}
	
	part def HomeLinkModule {
		attribute moduleVersion : String;
		attribute powerVoltage : VoltageValue;
		
		part buttons : ControlButton[3] {
			:>> buttonNumber = (1, 2, 3);
			:>> assignedDeviceSlot = (1, 2, 3);
		}
		
		part transceiver : RFTransceiver {
			:>> operatingFrequency = 315[MHz];
			:>> transmitPower = 0.1[W];
			:>> range = 50[m];
		}
		
		part memory : MemoryStorage;
		part processor : ControlProcessor;
		
		connection btn1ToProc connect buttons[1].userInterface to processor;
		connection btn2ToProc connect buttons[2].userInterface to processor;
		connection btn3ToProc connect buttons[3].userInterface to processor;
		connection procToTx connect processor to transceiver.transmit;
		connection rxToProc connect transceiver.receive to processor;
		connection procToMem connect processor to memory;
	}
	
	part def GarageDoorSystem {
		part receiver : GarageDoorReceiver;
		part door : GarageDoorMechanism;
		
		connection receiverToDoor connect receiver.motorOutput to door.controlInput;
	}
	
	part homeLinkSystem {
		part vehicleModule : HomeLinkModule {
			:>> moduleVersion = "Gen6";
			:>> powerVoltage = 12[V];
		}
		
		part garage : GarageDoorSystem {
			:>> receiver.deviceID = "GDO-12345";
		}
		
		connection wirelessLink connect vehicleModule.transceiver.transmit.signal 
			to garage.receiver.rfInput.signal;
	}
	
	action def OperateHomeLinkWorkflow {
		first start;
		then action userActivatesButton {
			out buttonCmd : UserCommand;
		}
		then action retrieveCode : MemoryStorage::RetrieveDeviceCode {
			in slot = userActivatesButton.buttonCmd.buttonID;
			out code;
		}
		then action processCommand : ControlProcessor::ProcessUserInput {
			in userCmd = userActivatesButton.buttonCmd;
			in deviceCode = retrieveCode.code;
			out transmitSignal;
		}
		then action transmitRF : RFTransceiver::EncodeAndTransmit {
			in deviceCode = retrieveCode.code;
			in command = userActivatesButton.buttonCmd;
			out rfSignal;
		}
		then action receiveAtGarage : RFTransceiver::ReceiveAndDecode {
			in rfSignal = transmitRF.rfSignal;
			out deviceCode;
		}
		then action activateDoor {
			in validatedCode = receiveAtGarage.deviceCode;
		}
		then done;
	}
	
	requirement def RangeRequirement {
		doc /* The HomeLink system shall transmit RF signals capable of operating 
		       devices at a minimum distance of 30 meters under normal conditions. */
		
		subject module : HomeLinkModule;
		
		require constraint {
			module.transceiver.range >= 30[m]
		}
	}
	
	requirement def DeviceCapacityRequirement {
		doc /* The HomeLink system shall support storage and control of at least 
		       three independent wireless devices simultaneously. */
		
		subject module : HomeLinkModule;
		
		require constraint {
			module.memory.maxCapacity >= 3
		}
	}
	
	requirement def SecurityRequirement {
		doc /* The HomeLink system shall employ rolling code encryption to prevent 
		       unauthorized signal interception and replay attacks. */
		
		subject code : DeviceCode;
		
		require constraint {
			code.rollingCode > 0
		}
	}
	
	requirement def FrequencyComplianceRequirement {
		doc /* The HomeLink system shall operate on the 315 MHz frequency band 
		       in compliance with FCC regulations for low-power transmitters. */
		
		subject module : HomeLinkModule;
		
		require constraint {
			module.transceiver.operatingFrequency == 315[MHz] and
			module.transceiver.transmitPower <= 0.25[W]
		}
	}
	
	requirement primarySystemRequirement {
		doc /* The HomeLink Wireless Control System shall provide secure, convenient 
		       wireless control of residential access devices such as garage door openers 
		       and gate systems from within a vehicle, enabling users to operate multiple 
		       devices through programmable buttons integrated into the vehicle interior. */
		
		assume constraint { 
			homeLinkSystem.vehicleModule.powerVoltage == 12[V];
		}
		
		require RangeRequirement;
		require DeviceCapacityRequirement;
		require SecurityRequirement;
		require FrequencyComplianceRequirement;
	}
}
