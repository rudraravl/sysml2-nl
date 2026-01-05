package 'CBus Building Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /*
	 * This model describes a C-Bus building automation system that coordinates distributed 
	 * intelligent control of lighting, climate, and security functions across a building.
	 * 
	 * The system's primary function is to enable real-time communication and coordination 
	 * between multiple autonomous controllers connected via a shared two-wire electrical bus.
	 * Each controller can both transmit commands and respond to messages from other devices,
	 * creating a peer-to-peer network where control intelligence is distributed rather than 
	 * centralized.
	 * 
	 * The C-Bus operates by encoding digital data onto a low-voltage power line, allowing 
	 * simultaneous power delivery and data communication. Controllers arbitrate bus access 
	 * using priority-based collision detection, ensuring critical messages are delivered 
	 * reliably even under high network load.
	 */
	
	attribute def DeviceAddress :> Integer;
	attribute def MessageID :> Integer;
	attribute def CommandCode :> Integer;
	attribute def BusVoltage :> ISQ::ElectricPotentialDifferenceValue;
	attribute def BusCurrent :> ISQ::ElectricCurrentValue;
	attribute def DataRate :> ISQ::FrequencyValue;
	attribute def LightLevel :> Real;
	attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
	
	enum def MessagePriority {
		critical;
		high;
		normal;
		low;
	}
	
	enum def DeviceStatus {
		online;
		offline;
		fault;
	}
	
	item def CBusMessage {
		attribute sourceAddress : DeviceAddress;
		attribute destinationAddress : DeviceAddress;
		attribute messageID : MessageID;
		attribute priority : MessagePriority;
		attribute command : CommandCode;
		attribute payload : Real;
		attribute timestamp : ISQ::TimeValue;
		attribute checksum : Integer;
	}
	
	port def CBusPort {
		attribute voltage : BusVoltage;
		attribute current : BusCurrent;
		in item rxMessages : CBusMessage[*];
		out item txMessages : CBusMessage[*];
	}
	
	port def PowerSupplyPort {
		in voltage : BusVoltage;
		in current : BusCurrent;
	}
	
	part def CBusNetwork {
		port trunk : CBusPort;
		attribute nominalVoltage : BusVoltage;
		attribute maxDataRate : DataRate;
		attribute networkLoad : Real;
	}
	
	part def PowerSupplyUnit {
		port dcOutput : PowerSupplyPort;
		attribute outputVoltage : BusVoltage;
		attribute maxCurrent : BusCurrent;
		attribute efficiency : Real;
	}
	
	part def CBusController {
		port busConnection : CBusPort;
		port powerInput : PowerSupplyPort;
		attribute deviceAddress : DeviceAddress;
		attribute status : DeviceStatus;
		attribute firmwareVersion : String;
	}
	
	part def LightingController :> CBusController {
		attribute currentLevel : LightLevel;
		attribute targetLevel : LightLevel;
		attribute rampRate : Real;
		perform action controlLighting;
	}
	
	part def ClimateController :> CBusController {
		attribute currentTemp : TemperatureSetpoint;
		attribute targetTemp : TemperatureSetpoint;
		attribute fanSpeed : Real;
		attribute mode : String;
		perform action regulateClimate;
	}
	
	part def SecurityController :> CBusController {
		attribute armed : Boolean;
		attribute zoneStatus : Boolean[*];
		attribute alarmActive : Boolean;
		perform action monitorSecurity;
	}
	
	part def OccupancySensor :> CBusController {
		attribute detectionRange : ISQ::LengthValue;
		attribute occupancyDetected : Boolean;
		attribute lastMotionTime : ISQ::TimeValue;
		perform action detectOccupancy;
	}
	
	action def EncodeMessage {
		in message : CBusMessage;
		out encodedData : Integer[*];
	}
	
	action def DecodeMessage {
		in encodedData : Integer[*];
		out message : CBusMessage;
		out valid : Boolean;
	}
	
	action def ArbitrateBusAccess {
		in requestingDevices : DeviceAddress[*];
		in priorities : MessagePriority[*];
		out grantedDevice : DeviceAddress;
	}
	
	action def ValidateChecksum {
		in message : CBusMessage;
		out isValid : Boolean;
	}
	
	action def TransmitOnBus {
		in message : CBusMessage;
		in busPort : CBusPort;
		out success : Boolean;
		
		first action encode : EncodeMessage {
			in message = TransmitOnBus::message;
			out encodedData;
		}
		then action send {
			in data = encode.encodedData;
			out transmitted : Boolean;
		}
		then assign success := send.transmitted;
	}
	
	action def ReceiveFromBus {
		in busPort : CBusPort;
		out message : CBusMessage;
		out valid : Boolean;
		
		first action listen {
			out rawData : Integer[*];
		}
		then action decode : DecodeMessage {
			in encodedData = listen.rawData;
			out message;
			out valid;
		}
		then action validate : ValidateChecksum {
			in message = decode.message;
			out isValid;
		}
		then assign message := decode.message;
		then assign valid := decode.valid && validate.isValid;
	}
	
	action def CoordinateBuildingAutomation {
		in controllers : CBusController[*];
		in network : CBusNetwork;
		
		first start;
		then merge operationLoop;
		
		then action monitorNetwork {
			in activeControllers = controllers;
			out pendingMessages : CBusMessage[*];
			out busLoad : Real;
		}
		
		then decide;
			if monitorNetwork.pendingMessages->size() > 0 then processMessages;
			if monitorNetwork.pendingMessages->size() == 0 then operationLoop;
		
		action processMessages {
			first action arbitrate : ArbitrateBusAccess {
				in requestingDevices;
				in priorities;
				out grantedDevice;
			}
			then action transmit : TransmitOnBus {
				in message;
				in busPort = network.trunk;
				out success;
			}
			then action receive : ReceiveFromBus {
				in busPort = network.trunk;
				out message;
				out valid;
			}
			then decide;
				if receive.valid then routeMessage;
				if !receive.valid then operationLoop;
			
			action routeMessage {
				in targetMessage = receive.message;
				out targetController : CBusController;
			}
			then action deliverToController {
				in controller = routeMessage.targetController;
				in deliveredMessage = receive.message;
			}
		}
		
		then operationLoop;
	}
	
	state def CBusDeviceState {
		entry; then initializing;
		
		state initializing {
			entry action performSelfTest;
			do action loadConfiguration;
		}
		transition init_to_idle
			first initializing
			if selfTestPassed
			then idle;
		
		state idle {
			entry action enterLowPower;
		}
		transition idle_to_listening
			first idle
			accept busActivity
			then listening;
		
		state listening {
			do action monitorBus;
		}
		transition listening_to_receiving
			first listening
			if messageAddressMatch
			then receiving;
		transition listening_to_idle
			first listening
			if noMessageForDevice
			then idle;
		
		state receiving {
			entry action prepareBuffer;
			do action receiveData;
		}
		transition receiving_to_processing
			first receiving
			if messageComplete
			then processing;
		
		state processing {
			do action executeCommand;
		}
		transition processing_to_transmitting
			first processing
			if responseRequired
			then transmitting;
		transition processing_to_idle
			first processing
			if noResponseRequired
			then idle;
		
		state transmitting {
			entry action waitForBusClear;
			do action transmitData;
		}
		transition transmitting_to_idle
			first transmitting
			if transmissionComplete
			then idle;
		
		state fault {
			entry action logError;
			do action attemptRecovery;
		}
		transition any_to_fault
			accept errorDetected
			then fault;
		transition fault_to_initializing
			first fault
			if recoverySuccessful
			then initializing;
	}
	
	requirement def SystemRequirements {
		doc /* Top-level requirements for the C-Bus building automation system. */
		
		requirement <'REQ-001'> primaryFunction {
			doc /* The system shall coordinate distributed control of building functions 
			       through peer-to-peer communication over a shared electrical bus. */
		}
		
		requirement <'REQ-002'> reliableCommunication {
			doc /* The system shall deliver messages with 99.9% reliability under 
			       normal operating conditions. */
			attribute targetReliability : Real = 0.999;
		}
		
		requirement <'REQ-003'> priorityArbitration {
			doc /* The system shall arbitrate bus access based on message priority, 
			       ensuring critical messages are transmitted within 50ms. */
			attribute maxLatency : ISQ::TimeValue = 50[ms];
		}
		
		requirement <'REQ-004'> scalability {
			doc /* The system shall support up to 100 devices on a single bus network 
			       without degradation of performance. */
			attribute maxDevices : Integer = 100;
		}
		
		requirement <'REQ-005'> powerEfficiency {
			doc /* The system shall operate at 36V DC with total network power 
			       consumption not exceeding 50W under full load. */
			attribute nominalVoltage : BusVoltage = 36[V];
			attribute maxPower : ISQ::PowerValue = 50[W];
		}
	}
	
	part buildingAutomationSystem {
		doc /* Complete C-Bus building automation system instance. */
		
		satisfy SystemRequirements::primaryFunction;
		satisfy SystemRequirements::reliableCommunication;
		satisfy SystemRequirements::priorityArbitration;
		satisfy SystemRequirements::scalability;
		satisfy SystemRequirements::powerEfficiency;
		
		part psu : PowerSupplyUnit {
			attribute :>> outputVoltage = 36[V];
			attribute :>> maxCurrent = 2[A];
			attribute :>> efficiency = 0.92;
		}
		
		part cBusNetwork : CBusNetwork {
			attribute :>> nominalVoltage = 36[V];
			attribute :>> maxDataRate = 3400[Hz];
			attribute :>> networkLoad = 0.0;
		}
		
		part zone1Lighting : LightingController {
			attribute :>> deviceAddress = 10;
			attribute :>> status = DeviceStatus::online;
			attribute :>> currentLevel = 0.0;
			attribute :>> targetLevel = 0.0;
			attribute :>> rampRate = 2.0;
		}
		
		part zone2Lighting : LightingController {
			attribute :>> deviceAddress = 11;
			attribute :>> status = DeviceStatus::online;
			attribute :>> currentLevel = 0.0;
			attribute :>> targetLevel = 0.0;
			attribute :>> rampRate = 2.0;
		}
		
		part hvacController : ClimateController {
			attribute :>> deviceAddress = 20;
			attribute :>> status = DeviceStatus::online;
			attribute :>> currentTemp = 295.15[K];
			attribute :>> targetTemp = 294.15[K];
			attribute :>> fanSpeed = 0.5;
			attribute :>> mode = "cooling";
		}
		
		part securityPanel : SecurityController {
			attribute :>> deviceAddress = 30;
			attribute :>> status = DeviceStatus::online;
			attribute :>> armed = false;
			attribute :>> alarmActive = false;
		}
		
		part motionSensor1 : OccupancySensor {
			attribute :>> deviceAddress = 40;
			attribute :>> status = DeviceStatus::online;
			attribute :>> detectionRange = 8[m];
			attribute :>> occupancyDetected = false;
		}
		
		part motionSensor2 : OccupancySensor {
			attribute :>> deviceAddress = 41;
			attribute :>> status = DeviceStatus::online;
			attribute :>> detectionRange = 8[m];
			attribute :>> occupancyDetected = false;
		}
		
		connect psu.dcOutput to cBusNetwork.trunk;
		connect zone1Lighting.busConnection to cBusNetwork.trunk;
		connect zone2Lighting.busConnection to cBusNetwork.trunk;
		connect hvacController.busConnection to cBusNetwork.trunk;
		connect securityPanel.busConnection to cBusNetwork.trunk;
		connect motionSensor1.busConnection to cBusNetwork.trunk;
		connect motionSensor2.busConnection to cBusNetwork.trunk;
		
		connect psu.dcOutput to zone1Lighting.powerInput;
		connect psu.dcOutput to zone2Lighting.powerInput;
		connect psu.dcOutput to hvacController.powerInput;
		connect psu.dcOutput to securityPanel.powerInput;
		connect psu.dcOutput to motionSensor1.powerInput;
		connect psu.dcOutput to motionSensor2.powerInput;
		
		perform action systemOperation : CoordinateBuildingAutomation {
			in controllers = (zone1Lighting, zone2Lighting, hvacController, 
			                  securityPanel, motionSensor1, motionSensor2);
			in network = cBusNetwork;
		}
		
		assert constraint voltageConsistency {
			doc /* All devices must operate at the same bus voltage. */
			psu.outputVoltage == cBusNetwork.nominalVoltage
		}
		
		assert constraint addressUniqueness {
			doc /* All device addresses must be unique on the network. */
			zone1Lighting.deviceAddress != zone2Lighting.deviceAddress and
			zone1Lighting.deviceAddress != hvacController.deviceAddress and
			zone1Lighting.deviceAddress != securityPanel.deviceAddress and
			zone1Lighting.deviceAddress != motionSensor1.deviceAddress and
			zone1Lighting.deviceAddress != motionSensor2.deviceAddress and
			zone2Lighting.deviceAddress != hvacController.deviceAddress and
			zone2Lighting.deviceAddress != securityPanel.deviceAddress and
			zone2Lighting.deviceAddress != motionSensor1.deviceAddress and
			zone2Lighting.deviceAddress != motionSensor2.deviceAddress and
			hvacController.deviceAddress != securityPanel.deviceAddress and
			hvacController.deviceAddress != motionSensor1.deviceAddress and
			hvacController.deviceAddress != motionSensor2.deviceAddress and
			securityPanel.deviceAddress != motionSensor1.deviceAddress and
			securityPanel.deviceAddress != motionSensor2.deviceAddress and
			motionSensor1.deviceAddress != motionSensor2.deviceAddress
		}
	}
}
