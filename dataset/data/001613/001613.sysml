package 'Universal Powerline Bus System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NetworkAddress :> Integer;
	attribute def CommandCode :> Integer;
	attribute def DimLevel :> Real;
	attribute def DeviceState;
	
	enum def DeviceStateKind :> DeviceState {
		off;
		on;
		dimmed;
	}
	
	enum def CommandType {
		turnOn;
		turnOff;
		setLevel;
		reportStatus;
		linkDevices;
	}
	
	item def UPBPacket {
		attribute sourceAddress : NetworkAddress;
		attribute destinationAddress : NetworkAddress;
		attribute commandType : CommandType;
		attribute levelValue : DimLevel;
		attribute checksum : Integer;
	}
	
	item def PowerlineSignal {
		attribute voltage : VoltageValue;
		attribute frequency : FrequencyValue;
		attribute modulatedData : UPBPacket;
	}
	
	port def PowerlineBusPort {
		inout signal : PowerlineSignal;
		out power : PowerValue;
	}
	
	part def PowerlineCarrier {
		attribute carrierFrequency : FrequencyValue = 40000.0 [Hz];
		
		action ModulateSignal {
			in packet : UPBPacket;
			in baseVoltage : VoltageValue;
			out modulatedSignal : PowerlineSignal;
		}
		
		action DemodulateSignal {
			in receivedSignal : PowerlineSignal;
			out extractedPacket : UPBPacket;
		}
	}
	
	part def UPBController {
		attribute controllerAddress : NetworkAddress = 1;
		port busInterface : PowerlineBusPort;
		
		action TransmitCommand {
			in targetAddress : NetworkAddress;
			in command : CommandType;
			in level : DimLevel;
			out transmittedPacket : UPBPacket;
			
			first start;
			then action buildPacket {
				out packet : UPBPacket;
			}
			then action modulate : PowerlineCarrier::ModulateSignal {
				in packet = buildPacket.packet;
				in baseVoltage : VoltageValue = 120.0 [V];
				out modulatedSignal;
			}
			then action transmit {
				assign busInterface.signal := modulate.modulatedSignal;
			}
			then done;
		}
		
		action ReceiveStatus {
			in receivedSignal : PowerlineSignal;
			out statusPacket : UPBPacket;
			
			first start;
			then action demodulate : PowerlineCarrier::DemodulateSignal {
				in receivedSignal = receivedSignal;
				out extractedPacket;
			}
			then action validateChecksum {
				in packet : UPBPacket = demodulate.extractedPacket;
				out isValid : Boolean;
			}
			then decide;
				if validateChecksum.isValid then processStatus;
				else discardPacket;
			action processStatus {
				assign statusPacket := demodulate.extractedPacket;
			}
			action discardPacket;
			then done;
		}
	}
	
	part def UPBDevice {
		attribute deviceAddress : NetworkAddress;
		attribute currentState : DeviceStateKind = DeviceStateKind::off;
		attribute currentLevel : DimLevel = 0.0;
		attribute powerConsumption : PowerValue;
		port busInterface : PowerlineBusPort;
		
		action ReceiveAndExecuteCommand {
			in receivedSignal : PowerlineSignal;
			
			first start;
			then action demodulate : PowerlineCarrier::DemodulateSignal {
				in receivedSignal = receivedSignal;
				out extractedPacket;
			}
			then decide;
				if demodulate.extractedPacket.destinationAddress == deviceAddress then processCommand;
				else ignoreCommand;
			
			action processCommand {
				then decide;
					if demodulate.extractedPacket.commandType == CommandType::turnOn then executeOn;
					if demodulate.extractedPacket.commandType == CommandType::turnOff then executeOff;
					if demodulate.extractedPacket.commandType == CommandType::setLevel then executeSetLevel;
					if demodulate.extractedPacket.commandType == CommandType::reportStatus then executeSendStatus;
				
				action executeOn {
					then assign currentState := DeviceStateKind::on;
					then assign currentLevel := 100.0;
					then updatePower;
				}
				
				action executeOff {
					then assign currentState := DeviceStateKind::off;
					then assign currentLevel := 0.0;
					then updatePower;
				}
				
				action executeSetLevel {
					then assign currentState := DeviceStateKind::dimmed;
					then assign currentLevel := demodulate.extractedPacket.levelValue;
					then updatePower;
				}
				
				action executeSendStatus {
					then action buildStatusPacket {
						out statusPacket : UPBPacket;
					}
					then action modulate : PowerlineCarrier::ModulateSignal {
						in packet = buildStatusPacket.statusPacket;
						in baseVoltage : VoltageValue = 120.0 [V];
						out modulatedSignal;
					}
					then action transmit {
						assign busInterface.signal := modulate.modulatedSignal;
					}
				}
				
				action updatePower {
					assign powerConsumption := currentLevel * 100.0 [W] / 100.0;
				}
			}
			
			action ignoreCommand;
			then done;
		}
	}
	
	part def DimmableLight :> UPBDevice {
		attribute maxBrightness : LuminousIntensityValue = 800.0 [cd];
		attribute ratedPower : PowerValue = 100.0 [W];
	}
	
	part def SwitchedOutlet :> UPBDevice {
		attribute maxLoad : PowerValue = 1800.0 [W];
	}
	
	part def PowerlineBus {
		attribute lineVoltage : VoltageValue = 120.0 [V];
		attribute lineFrequency : FrequencyValue = 60.0 [Hz];
		port nodes[*] : PowerlineBusPort;
	}
	
	action def ManageHomeAutomation {
		in controllerAddress : NetworkAddress;
		in deviceAddresses : NetworkAddress[*];
		
		first start;
		then merge operationLoop;
		
		then action monitorDevices {
			action sendStatusRequest : UPBController::TransmitCommand[*] {
				in targetAddress : NetworkAddress;
				in command : CommandType = CommandType::reportStatus;
				in level : DimLevel = 0.0;
				out transmittedPacket;
			}
			then action receiveStatuses : UPBController::ReceiveStatus[*] {
				in receivedSignal : PowerlineSignal;
				out statusPacket;
			}
		}
		
		then action controlDevices {
			action sendControlCommands : UPBController::TransmitCommand[*] {
				in targetAddress : NetworkAddress;
				in command : CommandType;
				in level : DimLevel;
				out transmittedPacket;
			}
		}
		
		then action processDeviceResponses {
			action receiveAndProcess : UPBDevice::ReceiveAndExecuteCommand[*] {
				in receivedSignal : PowerlineSignal;
			}
		}
		
		then operationLoop;
	}
	
	part universalPowerlineBusSystem {
		doc /*
		 * The Universal Powerline Bus (UPB) system provides reliable home automation
		 * by transmitting digital control signals over existing AC power lines.
		 * The system enables centralized control of lighting, outlets, and other
		 * electrical devices without requiring dedicated control wiring.
		 * 
		 * Primary Function: Encode and transmit command packets as modulated signals
		 * on the powerline carrier frequency, allowing multiple devices to receive
		 * power and control commands simultaneously over the same two-wire infrastructure.
		 */
		
		attribute systemVoltage : VoltageValue = 120.0 [V];
		attribute carrierFrequency : FrequencyValue = 40000.0 [Hz];
		attribute maxDevices : Integer = 250;
		
		part mainBus : PowerlineBus {
			attribute lineVoltage = universalPowerlineBusSystem::systemVoltage;
		}
		
		part systemController : UPBController {
			attribute controllerAddress = 1;
		}
		
		part livingRoomLight1 : DimmableLight {
			attribute deviceAddress = 10;
			attribute ratedPower = 75.0 [W];
		}
		
		part livingRoomLight2 : DimmableLight {
			attribute deviceAddress = 11;
			attribute ratedPower = 60.0 [W];
		}
		
		part kitchenOutlet : SwitchedOutlet {
			attribute deviceAddress = 20;
			attribute maxLoad = 1500.0 [W];
		}
		
		part bedroomLight : DimmableLight {
			attribute deviceAddress = 30;
			attribute ratedPower = 100.0 [W];
		}
		
		connection controllerToBus connect systemController.busInterface to mainBus.nodes;
		connection light1ToBus connect livingRoomLight1.busInterface to mainBus.nodes;
		connection light2ToBus connect livingRoomLight2.busInterface to mainBus.nodes;
		connection outletToBus connect kitchenOutlet.busInterface to mainBus.nodes;
		connection bedroomLightToBus connect bedroomLight.busInterface to mainBus.nodes;
		
		perform action automationControl : ManageHomeAutomation {
			in controllerAddress = systemController.controllerAddress;
			in deviceAddresses = (10, 11, 20, 30);
		}
	}
	
	requirement <'UPB-REQ-001'> powerlineCarrierCommunication {
		doc /*
		 * The system shall transmit digital control commands as modulated signals
		 * on the AC powerline using a carrier frequency between 20 kHz and 100 kHz,
		 * enabling simultaneous power delivery and data communication.
		 */
		
		subject universalPowerlineBusSystem;
		
		require constraint {
			universalPowerlineBusSystem.carrierFrequency >= 20000.0 [Hz] and
			universalPowerlineBusSystem.carrierFrequency <= 100000.0 [Hz]
		}
	}
	
	requirement <'UPB-REQ-002'> deviceAddressUniqueness {
		doc /*
		 * Each device connected to the UPB network shall have a unique network
		 * address to ensure unambiguous command routing and status reporting.
		 */
		
		subject universalPowerlineBusSystem;
		
		require constraint {
			universalPowerlineBusSystem.livingRoomLight1.deviceAddress <> 
			universalPowerlineBusSystem.livingRoomLight2.deviceAddress and
			universalPowerlineBusSystem.livingRoomLight1.deviceAddress <> 
			universalPowerlineBusSystem.kitchenOutlet.deviceAddress and
			universalPowerlineBusSystem.livingRoomLight1.deviceAddress <> 
			universalPowerlineBusSystem.bedroomLight.deviceAddress and
			universalPowerlineBusSystem.livingRoomLight2.deviceAddress <> 
			universalPowerlineBusSystem.kitchenOutlet.deviceAddress and
			universalPowerlineBusSystem.livingRoomLight2.deviceAddress <> 
			universalPowerlineBusSystem.bedroomLight.deviceAddress and
			universalPowerlineBusSystem.kitchenOutlet.deviceAddress <> 
			universalPowerlineBusSystem.bedroomLight.deviceAddress
		}
	}
	
	requirement <'UPB-REQ-003'> reliableCommandExecution {
		doc /*
		 * UPB devices shall correctly receive, validate, and execute commands
		 * addressed to them, updating their operational state and power consumption
		 * accordingly within 100 milliseconds of command reception.
		 */
		
		subject universalPowerlineBusSystem;
	}
	
	requirement <'UPB-REQ-004'> scalableNetworkCapacity {
		doc /*
		 * The UPB system shall support up to 250 uniquely addressable devices
		 * on a single powerline network segment without degradation of
		 * communication reliability or command response time.
		 */
		
		subject universalPowerlineBusSystem;
		
		require constraint {
			universalPowerlineBusSystem.maxDevices == 250
		}
	}
}
