package PapooseBoardSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ClockFrequency :> ISQ::FrequencyValue;
	attribute def DataRate :> ISQ::FrequencyValue;
	attribute def StorageCapacity :> ISQ::InformationValue;
	attribute def PowerConsumption :> ISQ::PowerValue;
	attribute def OperatingVoltage :> ISQ::VoltageValue;
	attribute def OperatingCurrent :> ISQ::ElectricCurrentValue;
	attribute def BoardTemperature :> ISQ::TemperatureValue;
	
	item def SensorReading {
		attribute timestamp : Real;
		attribute value : Real;
		attribute sensorId : String;
	}
	
	item def ControlCommand {
		attribute commandType : String;
		attribute targetDevice : String;
		attribute parameters : Real[*];
	}
	
	item def PowerSignal {
		attribute voltage : OperatingVoltage;
		attribute current : OperatingCurrent;
	}
	
	item def DataPacket {
		attribute payload : String;
		attribute size : StorageCapacity;
	}
	
	item def StartCommand;
	item def StopCommand;
	item def ErrorEvent;
	item def ResetCommand;
	
	port def PowerInputPort {
		in item powerSupply : PowerSignal;
	}
	
	port def PowerOutputPort {
		out item regulatedPower : PowerSignal;
	}
	
	port def SensorPort {
		in item readings : SensorReading[*];
	}
	
	port def ActuatorPort {
		out item commands : ControlCommand[*];
	}
	
	port def CommunicationPort {
		in item incomingData : DataPacket[*];
		out item outgoingData : DataPacket[*];
	}
	
	part def Microcontroller {
		attribute processorSpeed : ClockFrequency;
		attribute coreCount : Integer;
		attribute ramSize : StorageCapacity;
		attribute flashSize : StorageCapacity;
		
		port sensorInterface : SensorPort;
		port actuatorInterface : ActuatorPort;
		port commInterface : CommunicationPort;
		port powerIn : PowerInputPort;
		
		action def ProcessSensorData {
			in sensorInputs : SensorReading[*];
			out processedData : Real[*];
		}
		
		action def GenerateControlOutputs {
			in processedData : Real[*];
			out controlOutputs : ControlCommand[*];
		}
		
		action def ManageCommunication {
			in dataToSend : DataPacket[*];
			out transmittedData : DataPacket[*];
		}
	}
	
	part def PowerRegulator {
		attribute inputVoltageMin : OperatingVoltage;
		attribute inputVoltageMax : OperatingVoltage;
		attribute outputVoltage : OperatingVoltage;
		attribute maxCurrent : OperatingCurrent;
		attribute efficiency : Real;
		
		port powerInput : PowerInputPort;
		port powerOutput1 : PowerOutputPort;
		port powerOutput2 : PowerOutputPort;
		port powerOutput3 : PowerOutputPort;
		port powerOutput4 : PowerOutputPort;
		
		state def RegulatorStates {
			entry; then off;
			
			state off;
			
			transition powerUp
				first off
				then startup;
			
			state startup;
			
			transition stabilized
				first startup
				then regulating;
			
			state regulating {
				state monitoringLoad;
				state adjustingOutput;
			}
			
			transition overload
				first regulating
				then protection;
			
			state protection;
			
			transition recovered
				first protection
				then regulating;
			
			transition shutdown
				first regulating
				then off;
		}
	}
	
	part def SensorArray {
		attribute sensorCount : Integer;
		attribute samplingRate : DataRate;
		
		port dataOutput : SensorPort;
		port powerIn : PowerInputPort;
		
		action def AcquireSensorData {
			out readings : SensorReading[*];
		}
	}
	
	part def ActuatorController {
		attribute channelCount : Integer;
		attribute updateRate : DataRate;
		
		port commandInput : ActuatorPort;
		port powerIn : PowerInputPort;
		
		action def ExecuteCommands {
			in commands : ControlCommand[*];
		}
	}
	
	part def CommunicationModule {
		attribute protocol : String;
		attribute baudRate : DataRate;
		attribute bufferSize : StorageCapacity;
		
		port dataInterface : CommunicationPort;
		port powerIn : PowerInputPort;
		
		action def TransmitData {
			in data : DataPacket[*];
			out transmitted : DataPacket[*];
		}
		
		action def ReceiveData {
			out received : DataPacket[*];
		}
	}
	
	part def PapooseBoard {
		doc /*
		Embedded computing platform integrating microcontroller, power management,
		sensor interfaces, actuator control, and communication capabilities for
		real-time data acquisition and control applications.
		*/
		
		attribute boardId : String;
		attribute operatingTemp : BoardTemperature;
		attribute totalPowerDraw : PowerConsumption;
		
		part mcu : Microcontroller {
			attribute :>> processorSpeed = 168.0 [SI::Hz];
			attribute :>> coreCount = 1;
			attribute :>> ramSize = 524288.0 [SI::B];
			attribute :>> flashSize = 2097152.0 [SI::B];
		}
		
		part powerMgmt : PowerRegulator {
			attribute :>> inputVoltageMin = 7.0 [SI::V];
			attribute :>> inputVoltageMax = 24.0 [SI::V];
			attribute :>> outputVoltage = 3.3 [SI::V];
			attribute :>> maxCurrent = 3.0 [SI::A];
			attribute :>> efficiency = 0.85;
		}
		
		part sensors : SensorArray {
			attribute :>> sensorCount = 8;
			attribute :>> samplingRate = 1000.0 [SI::Hz];
		}
		
		part actuators : ActuatorController {
			attribute :>> channelCount = 4;
			attribute :>> updateRate = 500.0 [SI::Hz];
		}
		
		part commModule : CommunicationModule {
			attribute :>> protocol = "UART";
			attribute :>> baudRate = 115200.0 [SI::Hz];
			attribute :>> bufferSize = 256.0 [SI::B];
		}
		
		connection mcuPower connect powerMgmt.powerOutput1 to mcu.powerIn;
		connection sensorPower connect powerMgmt.powerOutput2 to sensors.powerIn;
		connection actuatorPower connect powerMgmt.powerOutput3 to actuators.powerIn;
		connection commPower connect powerMgmt.powerOutput4 to commModule.powerIn;
		
		connection sensorData connect sensors.dataOutput to mcu.sensorInterface;
		connection actuatorControl connect mcu.actuatorInterface to actuators.commandInput;
		connection communication connect mcu.commInterface to commModule.dataInterface;
		
		perform action executeControlCycle {
			doc /*
			Primary function: Continuously acquire sensor data, process it in real-time,
			generate appropriate control commands, and communicate status to external systems.
			*/
			
			first start;
			
			then action initializeSystem {
				doc /* Power up subsystems and initialize peripherals */
			}
			
			then merge controlLoop;
			
			then action acquireSensorData : sensors::AcquireSensorData {
				out sensorReadings : SensorReading[*];
			}
			
			then action processSensorData : mcu::ProcessSensorData {
				in sensorInputs = acquireSensorData.sensorReadings;
				out processedData : Real[*];
			}
			
			then action computeControl : mcu::GenerateControlOutputs {
				in processedData = processSensorData.processedData;
				out controlOutputs : ControlCommand[*];
			}
			
			then action applyControl : actuators::ExecuteCommands {
				in commands = computeControl.controlOutputs;
			}
			
			then action transmitStatus : commModule::TransmitData {
				in data : DataPacket[*];
				out transmitted : DataPacket[*];
			}
			
			then action checkSystemHealth {
				doc /* Monitor temperature, power consumption, and error conditions */
			}
			
			then decide;
				if checkSystemHealth then controlLoop;
				if not checkSystemHealth then shutdownSequence;
			
			action shutdownSequence {
				doc /* Safely power down all subsystems */
			}
			
			then done;
		}
		
		exhibit state systemBehavior : SystemStateMachine;
	}
	
	state def SystemStateMachine {
		entry; then idle;
		
		state idle;
		
		transition startOperation
			first idle
			accept StartCommand
			then active;
		
		state active {
			state acquiring;
			
			state processing;
			
			state actuating;
			
			state communicating;
			
			transition acquiring_to_processing
				first acquiring
				then processing;
			
			transition processing_to_actuating
				first processing
				then actuating;
			
			transition actuating_to_communicating
				first actuating
				then communicating;
			
			transition communicating_to_acquiring
				first communicating
				then acquiring;
		}
		
		transition stopOperation
			first active
			accept StopCommand
			then idle;
		
		transition errorDetected
			first active
			accept ErrorEvent
			then fault;
		
		state fault;
		
		transition recover
			first fault
			accept ResetCommand
			then idle;
	}
	
	requirement def SystemRequirement;
	
	requirement <'REQ-001'> processingPerformance : SystemRequirement {
		doc /*
		The Papoose board shall provide sufficient processing capability to execute
		real-time control algorithms at minimum 100 Hz update rate.
		*/
		
		subject board : PapooseBoard;
		
		require constraint processorSpeed {
			board.mcu.processorSpeed >= 100000000.0 [SI::Hz]
		}
		
		require constraint memoryCapacity {
			board.mcu.ramSize >= 262144.0 [SI::B]
		}
	}
	
	requirement <'REQ-002'> powerManagement : SystemRequirement {
		doc /*
		The Papoose board shall regulate input power and provide stable voltage
		to all subsystems with efficiency greater than 80%.
		*/
		
		subject board : PapooseBoard;
		
		require constraint voltageStability {
			board.powerMgmt.outputVoltage >= 3.2 [SI::V] and
			board.powerMgmt.outputVoltage <= 3.4 [SI::V]
		}
		
		require constraint efficiency {
			board.powerMgmt.efficiency >= 0.80
		}
	}
	
	requirement <'REQ-003'> sensorIntegration : SystemRequirement {
		doc /*
		The Papoose board shall support multiple sensor inputs with configurable
		sampling rates up to 1 kHz per channel.
		*/
		
		subject board : PapooseBoard;
		
		require constraint sensorChannels {
			board.sensors.sensorCount >= 4
		}
		
		require constraint samplingRate {
			board.sensors.samplingRate >= 1000.0 [SI::Hz]
		}
	}
	
	requirement <'REQ-004'> actuatorControl : SystemRequirement {
		doc /*
		The Papoose board shall provide actuator control outputs with update
		rates sufficient for closed-loop control applications.
		*/
		
		subject board : PapooseBoard;
		
		require constraint controlChannels {
			board.actuators.channelCount >= 2
		}
		
		require constraint updateRate {
			board.actuators.updateRate >= 100.0 [SI::Hz]
		}
	}
	
	requirement <'REQ-005'> thermalOperation : SystemRequirement {
		doc /*
		The Papoose board shall operate reliably within industrial temperature
		range without thermal throttling or damage.
		*/
		
		subject board : PapooseBoard;
		
		require constraint operatingTemperature {
			board.operatingTemp >= 253.15 [SI::K] and
			board.operatingTemp <= 343.15 [SI::K]
		}
	}
	
	requirement papooseBoardMission {
		doc /*
		The Papoose board system shall function as an integrated embedded platform
		that acquires sensor data, executes real-time control algorithms, drives
		actuators, and communicates system status through continuous operation cycles,
		enabling autonomous monitoring and control of physical processes.
		*/
		
		assume constraint externalPowerAvailable {
			doc /* Stable external power supply within 7-24V range is provided */
		}
		
		assume constraint sensorsConnected {
			doc /* Valid sensors are connected to sensor interface ports */
		}
		
		require processingPerformance;
		require powerManagement;
		require sensorIntegration;
		require actuatorControl;
		require thermalOperation;
	}
	
	part papooseBoardInstance : PapooseBoard {
		attribute :>> boardId = "PB-001";
		attribute :>> operatingTemp = 308.15 [SI::K];
		attribute :>> totalPowerDraw = 4.5 [SI::W];
	}
}
