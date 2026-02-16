package 'OneWireSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def DeviceROMCode {
		doc /* Unique 64-bit identifier for each 1-Wire device consisting of family code, serial number, and CRC. */
		attribute familyCode : String;
		attribute serialNumber : String;
		attribute crc : String;
	}
	
	attribute def CommandCode : String;
	attribute def DataByte : String;
	
	item def OneWireFrame {
		attribute resetPulse : Boolean;
		attribute presencePulse : Boolean;
		attribute command : CommandCode;
		attribute data : DataByte[*];
	}
	
	port def OneWireBusPort {
		attribute busVoltage : ISQ::voltage;
		attribute pullupResistance : ISQ::electricalResistance;
		inout signal : OneWireFrame;
	}
	
	part def OneWireMaster {
		doc /* Master controller that initiates all communication on the 1-Wire bus. */
		
		port busInterface : OneWireBusPort;
		
		attribute operatingVoltage : ISQ::voltage = 5.0 [SI::V];
		attribute knownDevices : DeviceROMCode[*] nonunique;
		
		perform action manageBus;
	}
	
	part def OneWireSlave {
		doc /* Base slave device connected to the 1-Wire bus. */
		
		port busInterface : OneWireBusPort;
		
		attribute romCode : DeviceROMCode;
		attribute parasitePowered : Boolean;
		
		perform action respondToMaster;
	}
	
	part def DS18B20TemperatureSensor :> OneWireSlave {
		doc /* Digital temperature sensor with 1-Wire interface. */
		
		attribute currentTemperature : ISQ::thermodynamicTemperature;
		attribute resolution : Real = 0.0625;
		attribute conversionTime : ISQ::time = 750.0 [SI::ms];
		
		state temperatureSensorState {
			entry; then idle;
			
			state idle {
				doc /* Waiting for conversion command. */
			}
			accept convertCommand
			then converting;
			
			state converting {
				doc /* Performing temperature measurement. */
			}
			accept after conversionTime
			then dataReady;
			
			state dataReady {
				doc /* Temperature data available in scratchpad. */
			}
			accept readCommand
			then idle;
		}
	}
	
	part def DS2431EEPROM :> OneWireSlave {
		doc /* 1024-bit EEPROM memory with 1-Wire interface. */
		
		attribute memorySize : ISQ::informationCapacity = 1024.0 [SI::bit];
		attribute memoryContents : DataByte[128];
		
		perform action readMemory {
			in address : Integer;
			out data : DataByte;
		}
		
		perform action writeMemory {
			in address : Integer;
			in data : DataByte;
		}
	}
	
	action def GenerateResetPulse {
		doc /* Master pulls bus low for 480-960 microseconds. */
		in duration : ISQ::time;
		out resetSignal : Boolean;
	}
	
	action def DetectPresence {
		doc /* Slave responds with presence pulse 15-60 microseconds after reset. */
		in resetDetected : Boolean;
		out presenceSignal : Boolean;
	}
	
	action def WriteZeroBit {
		doc /* Master pulls bus low for 60-120 microseconds. */
		in slotDuration : ISQ::time;
		out bitWritten : Boolean;
	}
	
	action def WriteOneBit {
		doc /* Master pulls bus low for 1-15 microseconds then releases. */
		in slotDuration : ISQ::time;
		out bitWritten : Boolean;
	}
	
	action def ReadBit {
		doc /* Master initiates read slot, slave pulls low for 0 or releases for 1. */
		in slotDuration : ISQ::time;
		out bitValue : Boolean;
	}
	
	action def SearchROM {
		doc /* Algorithm to discover all devices on the bus. */
		out discoveredDevices : DeviceROMCode[*];
	}
	
	action def MatchROM {
		doc /* Select specific device by ROM code. */
		in targetDevice : DeviceROMCode;
		out deviceSelected : Boolean;
	}
	
	action def SkipROM {
		doc /* Address all devices simultaneously. */
		out allDevicesSelected : Boolean;
	}
	
	action def ReadScratchpad {
		doc /* Read device scratchpad memory. */
		in deviceAddress : DeviceROMCode;
		out scratchpadData : DataByte[9];
	}
	
	action def ConvertTemperature {
		doc /* Initiate temperature conversion on DS18B20. */
		in deviceAddress : DeviceROMCode;
		out conversionStarted : Boolean;
	}
	
	action def OneWireTransaction {
		doc /* Complete 1-Wire communication sequence with device. */
		
		in masterVoltage : ISQ::voltage;
		in targetDevice : DeviceROMCode;
		in commandToExecute : CommandCode;
		in writeData : DataByte[*];
		out dataReceived : DataByte[*];
		
		first start;
		
		then action reset : GenerateResetPulse {
			in duration = 480.0 [SI::us];
			out resetSignal;
		}
		
		then action presence : DetectPresence {
			in resetDetected = reset.resetSignal;
			out presenceSignal;
		}
		
		then decide;
			if presence.presenceSignal then selectDevice;
			if !presence.presenceSignal then abortTransaction;
		
		action selectDevice : MatchROM {
			in targetDevice = OneWireTransaction::targetDevice;
			out deviceSelected;
		}
		
		then action executeCommand {
			private attribute commandBits : Boolean[8];
			
			for bit in commandBits {
				decide;
					if bit then writeOne;
					if !bit then writeZero;
				
				action writeOne : WriteOneBit {
					in slotDuration = 60.0 [SI::us];
					out bitWritten;
				}
				
				action writeZero : WriteZeroBit {
					in slotDuration = 60.0 [SI::us];
					out bitWritten;
				}
			}
		}
		
		then action transferData {
			private attribute receivedBytes : DataByte[*] := ();
			
			for writeByte in writeData {
				private attribute byteBits : Boolean[8];
				for bit in byteBits {
					decide;
						if bit then writeDataOne;
						if !bit then writeDataZero;
					
					action writeDataOne : WriteOneBit {
						in slotDuration = 60.0 [SI::us];
						out bitWritten;
					}
					
					action writeDataZero : WriteZeroBit {
						in slotDuration = 60.0 [SI::us];
						out bitWritten;
					}
				}
			}
			
			then for idx in Sequence{1..9} {
				private attribute readByteBits : Boolean[8] := ();
				
				for bitIdx in Sequence{1..8} {
					perform action readBit : ReadBit {
						in slotDuration = 60.0 [SI::us];
						out bitValue;
					}
					then assign readByteBits := readByteBits->including(readBit.bitValue);
				}
				
				then assign receivedBytes := receivedBytes->including("byte");
			}
			
			then assign dataReceived := receivedBytes;
		}
		
		then done;
		
		action abortTransaction;
		then done;
	}
	
	action def TemperatureMonitoring {
		doc /* Continuous temperature monitoring from multiple sensors. */
		
		in sensorAddresses : DeviceROMCode[*];
		in pollingInterval : ISQ::time;
		out temperatureReadings : ISQ::thermodynamicTemperature[*];
		
		first start;
		
		then merge monitoringLoop;
		
		then action initiateConversion {
			for sensor in sensorAddresses {
				perform action convert : OneWireTransaction {
					in masterVoltage = 5.0 [SI::V];
					in targetDevice = sensor;
					in commandToExecute = "0x44";
					in writeData = ();
					out dataReceived;
				}
			}
		}
		
		then accept conversionWait : ISQ::time {
			where { value >= 750.0 [SI::ms] }
		}
		
		then action readTemperatures {
			private attribute readings : ISQ::thermodynamicTemperature[*] := ();
			
			for sensor in sensorAddresses {
				perform action readData : OneWireTransaction {
					in masterVoltage = 5.0 [SI::V];
					in targetDevice = sensor;
					in commandToExecute = "0xBE";
					in writeData = ();
					out dataReceived;
				}
				
				then assign readings := readings->including(298.15 [SI::K]);
			}
			
			then assign temperatureReadings := readings;
		}
		
		then accept pollingWait : ISQ::time {
			where { value == pollingInterval }
		}
		
		then monitoringLoop;
	}
	
	part oneWireSystem {
		doc /* 
			A 1-Wire system enables half-duplex bidirectional communication between a single 
			master controller and multiple slave devices over a single data line plus ground. 
			The system's primary function is to provide low-cost, reliable serial communication 
			for distributed sensing and data logging applications, where each device possesses 
			a unique 64-bit ROM code enabling selective addressing on a shared multi-drop bus.
		*/
		
		part master : OneWireMaster {
			port masterBus : OneWireBusPort {
				attribute busVoltage = 5.0 [SI::V];
				attribute pullupResistance = 4700.0 [SI::Ohm];
			}
			
			attribute knownDevices = (sensor1.romCode, sensor2.romCode, sensor3.romCode, memory1.romCode);
		}
		
		part sensor1 : DS18B20TemperatureSensor {
			port sensorBus1 : OneWireBusPort;
			
			attribute romCode : DeviceROMCode {
				attribute familyCode = "00101000";
				attribute serialNumber = "000000000001";
				attribute crc = "10101010";
			}
			attribute parasitePowered = true;
			attribute currentTemperature = 298.15 [SI::K];
		}
		
		part sensor2 : DS18B20TemperatureSensor {
			port sensorBus2 : OneWireBusPort;
			
			attribute romCode : DeviceROMCode {
				attribute familyCode = "00101000";
				attribute serialNumber = "000000000010";
				attribute crc = "01010101";
			}
			attribute parasitePowered = true;
			attribute currentTemperature = 295.65 [SI::K];
		}
		
		part sensor3 : DS18B20TemperatureSensor {
			port sensorBus3 : OneWireBusPort;
			
			attribute romCode : DeviceROMCode {
				attribute familyCode = "00101000";
				attribute serialNumber = "000000000011";
				attribute crc = "11001100";
			}
			attribute parasitePowered = false;
			attribute currentTemperature = 301.45 [SI::K];
		}
		
		part memory1 : DS2431EEPROM {
			port memoryBus : OneWireBusPort;
			
			attribute romCode : DeviceROMCode {
				attribute familyCode = "00101101";
				attribute serialNumber = "000000000100";
				attribute crc = "00110011";
			}
			attribute parasitePowered = false;
		}
		
		connection busConnection1 connect master.masterBus to sensor1.sensorBus1;
		connection busConnection2 connect master.masterBus to sensor2.sensorBus2;
		connection busConnection3 connect master.masterBus to sensor3.sensorBus3;
		connection busConnection4 connect master.masterBus to memory1.memoryBus;
		
		perform action monitorTemperatures : TemperatureMonitoring {
			in sensorAddresses = (sensor1.romCode, sensor2.romCode, sensor3.romCode);
			in pollingInterval = 5.0 [SI::s];
			out temperatureReadings;
		}
	}
	
	requirement def TimingCompliance {
		doc /* The 1-Wire bus shall meet all specified timing requirements for reliable operation. */
		
		attribute resetPulseDuration : ISQ::time;
		attribute presencePulseDuration : ISQ::time;
		attribute writeSlotDuration : ISQ::time;
		attribute readSlotDuration : ISQ::time;
		attribute recoveryTime : ISQ::time;
		
		require constraint timingLimits {
			resetPulseDuration >= 480.0 [SI::us] and
			resetPulseDuration <= 960.0 [SI::us] and
			presencePulseDuration >= 60.0 [SI::us] and
			presencePulseDuration <= 240.0 [SI::us] and
			writeSlotDuration >= 60.0 [SI::us] and
			writeSlotDuration <= 120.0 [SI::us] and
			readSlotDuration >= 60.0 [SI::us] and
			readSlotDuration <= 120.0 [SI::us] and
			recoveryTime >= 1.0 [SI::us]
		}
	}
	
	requirement def ElectricalCompliance {
		doc /* The 1-Wire bus shall maintain proper electrical characteristics. */
		
		attribute busVoltage : ISQ::voltage;
		attribute pullupResistance : ISQ::electricalResistance;
		attribute maxCapacitance : ISQ::capacitance;
		
		require constraint electricalLimits {
			busVoltage >= 2.8 [SI::V] and
			busVoltage <= 6.0 [SI::V] and
			pullupResistance >= 1000.0 [SI::Ohm] and
			pullupResistance <= 15000.0 [SI::Ohm] and
			maxCapacitance <= 800.0 [SI::pF]
		}
	}
	
	requirement def CommunicationReliability {
		doc /* The 1-Wire system shall ensure reliable data transfer with error detection. */
		
		require constraint crcValidation {
			doc /* All ROM codes and data transfers shall include CRC-8 validation. */
		}
		
		require constraint uniqueAddressing {
			doc /* Each device shall have a unique 64-bit ROM code. */
		}
	}
	
	requirement def PowerDelivery {
		doc /* The 1-Wire system shall support both parasitic and external power modes. */
		
		require constraint parasiticPower {
			doc /* Bus shall provide sufficient power during idle and read slots for parasitic devices. */
		}
		
		require constraint strongPullup {
			doc /* Master shall provide strong pullup during conversion for parasitic sensors. */
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the 1-Wire communication system. */
		
		subject oneWireSystem;
		
		require timingCompliance : TimingCompliance {
			attribute resetPulseDuration = 480.0 [SI::us];
			attribute presencePulseDuration = 60.0 [SI::us];
			attribute writeSlotDuration = 60.0 [SI::us];
			attribute readSlotDuration = 60.0 [SI::us];
			attribute recoveryTime = 1.0 [SI::us];
		}
		
		require electricalCompliance : ElectricalCompliance {
			attribute busVoltage = 5.0 [SI::V];
			attribute pullupResistance = 4700.0 [SI::Ohm];
			attribute maxCapacitance = 400.0 [SI::pF];
		}
		
		require communicationReliability : CommunicationReliability;
		require powerDelivery : PowerDelivery;
	}
}
