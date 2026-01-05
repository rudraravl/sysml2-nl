package SmartDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def DeviceID;
	attribute def UserCommand;
	attribute def SensorData;
	attribute def ProcessedData;
	attribute def StatusMessage;
	
	attribute def BatteryLevel :> Real;
	
	enum def OperatingMode {
		active;
		idle;
		sleep;
		charging;
	}
	
	enum def ConnectivityState {
		connected;
		disconnected;
		connecting;
	}
	
	port def DataPort {
		in item dataIn : ProcessedData;
		out item dataOut : ProcessedData;
	}
	
	port def PowerPort {
		in attribute powerIn : ISQ::PowerValue;
		out attribute powerOut : ISQ::PowerValue;
	}
	
	port def NetworkPort {
		in item commandIn : UserCommand;
		out item statusOut : StatusMessage;
	}
	
	part def TemperatureSensor {
		out attribute temperature : ISQ::TemperatureValue;
		attribute samplingRate : Real;
	}
	
	part def MotionSensor {
		out attribute motionDetected : Boolean;
	}
	
	part def Processor {
		in attribute rawData : SensorData;
		out attribute processedData : ProcessedData;
		attribute processingPower : ISQ::PowerValue;
	}
	
	part def WirelessModule {
		port networkInterface : NetworkPort;
		attribute signalStrength : Real;
		attribute connectionState : ConnectivityState;
	}
	
	part def Battery {
		attribute chargeLevel : BatteryLevel;
		attribute capacity : ISQ::EnergyValue;
		port powerOutput : PowerPort;
	}
	
	part def Display {
		in attribute displayData : ProcessedData;
	}
	
	action def SenseEnvironment {
		out temperature : ISQ::TemperatureValue;
		out motion : Boolean;
	}
	
	action def ProcessData {
		in rawData : SensorData;
		out analyzedData : ProcessedData;
	}
	
	action def TransmitData {
		in dataToSend : ProcessedData;
		out status : StatusMessage;
	}
	
	action def ReceiveCommand {
		out command : UserCommand;
	}
	
	action def ExecuteCommand {
		in command : UserCommand;
		out result : StatusMessage;
	}
	
	action def MonitorBattery {
		out batteryStatus : BatteryLevel;
	}
	
	action def ManagePowerMode {
		in currentMode : OperatingMode;
		in batteryLevel : BatteryLevel;
		out newMode : OperatingMode;
	}
	
	part def SmartDevice {
		attribute deviceId : DeviceID;
		attribute currentBatteryLevel : BatteryLevel;
		attribute currentMode : OperatingMode;
		
		part tempSensor : TemperatureSensor {
			attribute samplingRate = 1.0;
		}
		
		part motionSensor : MotionSensor;
		
		part processor : Processor {
			attribute processingPower = 2.5[SI::W];
		}
		
		part wireless : WirelessModule {
			attribute signalStrength = 85.0;
			attribute connectionState = ConnectivityState::connected;
		}
		
		part powerSource : Battery {
			attribute chargeLevel = 100.0;
			attribute capacity = 3600.0[SI::J];
		}
		
		part display : Display;
		
		connection sensorToProcessor connect 
			tempSensor.temperature to processor.rawData;
		
		connection processorToWireless connect 
			processor.processedData to wireless.networkInterface.statusOut;
		
		connection wirelessToDisplay connect 
			wireless.networkInterface to display.displayData;
		
		connection batteryToPower connect 
			powerSource.powerOutput to processor;
	}
	
	state def SmartDeviceStates {
		in attribute batteryLevel : BatteryLevel;
		
		entry; then startup;
		
		state startup;
		transition startup_to_active
			first startup
			then active;
		
		state active {
			entry; then sensing;
			
			state sensing;
			transition sensing_to_processing
				first sensing
				then processing;
			
			state processing;
			transition processing_to_transmitting
				first processing
				then transmitting;
			
			state transmitting;
			transition transmitting_to_sensing
				first transmitting
				then sensing;
		}
		
		transition active_to_idle
			first active
			if batteryLevel < 20.0
			then idle;
		
		state idle;
		transition idle_to_sleep
			first idle
			then sleep;
		
		state sleep;
		transition sleep_to_active
			first sleep
			then active;
		
		transition any_to_charging
			first active
			then charging;
		
		state charging;
		transition charging_to_active
			first charging
			if batteryLevel >= 100.0
			then active;
	}
	
	action def SmartDeviceOperation {
		first start;
		then merge operationLoop;
		
		action monitorBattery : MonitorBattery {
			out batteryStatus : BatteryLevel;
		}
		
		then decide powerDecision;
			if monitorBattery.batteryStatus < 15.0 then enterLowPowerMode;
			if monitorBattery.batteryStatus >= 15.0 then normalOperation;
		
		action enterLowPowerMode {
			action managePower : ManagePowerMode {
				in currentMode = OperatingMode::active;
				in batteryLevel = monitorBattery.batteryStatus;
				out newMode : OperatingMode;
			}
		}
		then operationLoop;
		
		action normalOperation {
			first start;
			then action sense : SenseEnvironment {
				out temperature : ISQ::TemperatureValue;
				out motion : Boolean;
			}
			then action process : ProcessData {
				in rawData;
				out analyzedData : ProcessedData;
			}
			then merge communicationChoice;
			
			action receiveCmd : ReceiveCommand {
				out command : UserCommand;
			}
			then communicationChoice;
			
			then action transmit : TransmitData {
				in dataToSend = process.analyzedData;
				out status : StatusMessage;
			}
			then decide commandDecision;
				if receiveCmd.command != null then executeCmd;
				else continueOperation;
			
			action executeCmd : ExecuteCommand {
				in command = receiveCmd.command;
				out result : StatusMessage;
			}
			then continueOperation;
			
			action continueOperation;
			then done;
		}
		then operationLoop;
	}
	
	part smartDevice : SmartDevice {
		attribute deviceId : DeviceID;
		attribute currentBatteryLevel : BatteryLevel = 100.0;
		attribute currentMode : OperatingMode = OperatingMode::active;
		
		perform action deviceOperation : SmartDeviceOperation;
		
		exhibit state deviceStates : SmartDeviceStates {
			in attribute batteryLevel = smartDevice.currentBatteryLevel;
		}
	}
	
	requirement def <'REQ-001'> SmartDeviceFunctionalRequirement {
		doc /* The smart device shall continuously sense environmental conditions,
		     process the collected data, and transmit analyzed information to 
		     connected users or systems while managing power consumption efficiently. */
		
		subject device : SmartDevice;
		
		require constraint sensingCapability {
			doc /* Device must acquire sensor data at regular intervals */
			device.tempSensor.samplingRate >= 0.5
		}
		
		require constraint processingCapability {
			doc /* Device must process sensor data with adequate power */
			device.processor.processingPower >= 1.0[SI::W]
		}
		
		require constraint connectivityCapability {
			doc /* Device must maintain network connectivity */
			device.wireless.connectionState == ConnectivityState::connected
		}
		
		require constraint powerManagement {
			doc /* Device must operate efficiently on battery power */
			device.powerSource.chargeLevel > 10.0
		}
	}
	
	requirement <'REQ-002'> smartDeviceMission {
		doc /* The smart device system shall autonomously monitor its environment,
		     intelligently process sensory information, communicate with external 
		     systems, and adapt its behavior based on battery status and user commands
		     to provide continuous, reliable operation. */
		
		subject device : SmartDevice;
		
		assume constraint environmentalConditions {
			doc /* Device operates within specified temperature range */
			true
		}
		
		require functionalReq : SmartDeviceFunctionalRequirement {
			subject device = smartDevice;
		}
	}
}
