package ESP32IoTSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MACAddress :> String;
	attribute def SSID :> String;
	attribute def IPAddressValue :> String;
	
	item def SensorDataPacket {
		attribute temperature : ThermodynamicTemperatureValue;
		attribute humidity : Real;
		attribute pressure : PressureValue;
		attribute timestamp : TimeValue;
	}
	
	item def WiFiCredentials {
		attribute networkSSID : SSID;
		attribute password : String;
	}
	
	item def ControlMessage {
		attribute deviceID : String;
		attribute command : String;
		attribute parameter : Real;
	}
	
	port def WiFiPort {
		out item txData : SensorDataPacket;
		in item rxCommand : ControlMessage;
		out item credentials : WiFiCredentials;
		in item assignedIP : IPAddressValue;
	}
	
	port def SensorInterfacePort {
		in item sensorData : SensorDataPacket;
	}
	
	port def PowerInputPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def GPIOPort {
		out attribute digitalOut : Boolean;
		in attribute digitalIn : Boolean;
	}
	
	part def ESP32Microcontroller {
		attribute processorCores : Integer = 2;
		attribute clockFrequency : FrequencyValue = 240.0;
		attribute flashSize : Real = 4.0;
		attribute sramSize : Real = 520.0;
		attribute macAddress : MACAddress;
		attribute operatingVoltage : ElectricPotentialValue = 3.3;
		
		port wifi : WiFiPort;
		port power : PowerInputPort;
		port gpio : GPIOPort[40];
		port sensorInterface : SensorInterfacePort;
		
		perform action executeMainLoop;
	}
	
	part def BME280Sensor {
		attribute i2cAddress : Integer = 118;
		attribute temperatureRange_min : ThermodynamicTemperatureValue = 233.15;
		attribute temperatureRange_max : ThermodynamicTemperatureValue = 358.15;
		attribute humidityRange_min : Real = 0.0;
		attribute humidityRange_max : Real = 100.0;
		attribute pressureRange_min : PressureValue = 30000.0;
		attribute pressureRange_max : PressureValue = 110000.0;
		
		port dataOutput : SensorInterfacePort;
		port power : PowerInputPort;
		
		perform action acquireMeasurements;
	}
	
	part def VoltageRegulator {
		attribute inputVoltageRange_min : ElectricPotentialValue = 4.5;
		attribute inputVoltageRange_max : ElectricPotentialValue = 12.0;
		attribute outputVoltage : ElectricPotentialValue = 3.3;
		attribute maxOutputCurrent : ElectricCurrentValue = 0.8;
		attribute efficiency : Real = 0.85;
		
		port input : PowerInputPort;
		port output : PowerInputPort[*];
	}
	
	part def WiFiAccessPoint {
		attribute ssid : SSID;
		attribute channel : Integer = 6;
		attribute frequency : FrequencyValue = 2.4;
		attribute maxConnections : Integer = 10;
		
		port networkInterface : WiFiPort[*];
	}
	
	part def LEDIndicator {
		attribute color : String;
		attribute forwardVoltage : ElectricPotentialValue = 2.0;
		attribute forwardCurrent : ElectricCurrentValue = 0.02;
		
		port control : GPIOPort;
		port power : PowerInputPort;
		
		perform action illuminate;
	}
	
	action def AcquireSensorData {
		out temperature : ThermodynamicTemperatureValue;
		out humidity : Real;
		out pressure : PressureValue;
	}
	
	action def PackageData {
		in temp : ThermodynamicTemperatureValue;
		in humid : Real;
		in press : PressureValue;
		out packet : SensorDataPacket;
	}
	
	action def TransmitOverWiFi {
		in dataPacket : SensorDataPacket;
		in wifiCreds : WiFiCredentials;
		out transmitSuccess : Boolean;
	}
	
	action def ReceiveControlCommand {
		out controlMsg : ControlMessage;
		out commandReceived : Boolean;
	}
	
	action def ProcessCommand {
		in command : ControlMessage;
		out actionRequired : Boolean;
		out ledState : Boolean;
	}
	
	action def UpdateLEDStatus {
		in state : Boolean;
	}
	
	state def OperationalStateMachine {
		entry; then initialization;
		
		state initialization;
		then wifiConnection;
		
		state wifiConnection;
		then normalOperation;
		
		state normalOperation {
			entry; then sensing;
			
			state sensing;
			then dataProcessing;
			
			state dataProcessing;
			then transmission;
			
			state transmission;
			then commandCheck;
			
			state commandCheck;
			then commandExecution;
			
			state commandExecution;
			then sensing;
		}
		
		state errorRecovery;
		then initialization;
	}
	
	action def ESP32MainOperation {
		first start;
		
		then action initializeHardware {
			out initComplete : Boolean;
		}
		
		then action connectToWiFi : TransmitOverWiFi {
			in dataPacket;
			in wifiCreds;
			out transmitSuccess;
		}
		
		then merge operationCycle;
		
		then action readSensor : AcquireSensorData {
			out temperature;
			out humidity;
			out pressure;
		}
		
		then action packageSensorData : PackageData {
			in temp = readSensor.temperature;
			in humid = readSensor.humidity;
			in press = readSensor.pressure;
			out packet;
		}
		
		then action transmitData : TransmitOverWiFi {
			in dataPacket = packageSensorData.packet;
			in wifiCreds;
			out transmitSuccess;
		}
		
		then action checkForCommands : ReceiveControlCommand {
			out controlMsg;
			out commandReceived;
		}
		
		then decide;
			if checkForCommands.commandReceived then processControlCommand;
		
		action processControlCommand : ProcessCommand {
			in command = checkForCommands.controlMsg;
			out actionRequired;
			out ledState;
		}
		
		then action updateIndicator : UpdateLEDStatus {
			in state = processControlCommand.ledState;
		}
		
		then operationCycle;
	}
	
	part esp32System {
		attribute systemID : String = "ESP32-ENV-MONITOR-001";
		attribute firmwareVersion : String = "v2.1.0";
		
		part mcu : ESP32Microcontroller {
			perform action mainOperation : ESP32MainOperation;
		}
		
		part environmentSensor : BME280Sensor {
			perform mainOperation.readSensor;
		}
		
		part powerRegulator : VoltageRegulator;
		
		part statusLED : LEDIndicator {
			attribute :>> color = "blue";
			perform mainOperation.updateIndicator;
		}
		
		part accessPoint : WiFiAccessPoint {
			attribute :>> ssid = "ESP32_IoT_Network";
		}
		
		connection powerToRegulator connect powerRegulator.input to mcu.power;
		connection regulatorToMCU connect powerRegulator.output to mcu.power;
		connection regulatorToSensor connect powerRegulator.output to environmentSensor.power;
		connection regulatorToLED connect powerRegulator.output to statusLED.power;
		
		connection sensorToMCU connect environmentSensor.dataOutput to mcu.sensorInterface;
		connection mcuToWiFi connect mcu.wifi to accessPoint.networkInterface;
		connection mcuToLED connect mcu.gpio to statusLED.control;
	}
	
	requirement def SystemRequirement;
	
	requirement <'SYS-REQ-001'> primaryFunction : SystemRequirement {
		doc /* The ESP32 system shall acquire environmental sensor data (temperature, 
		     humidity, pressure) and wirelessly transmit this data to a remote server 
		     via WiFi network connectivity at regular intervals. */
		
		subject esp32System;
	}
	
	requirement <'SYS-REQ-002'> powerSpecification : SystemRequirement {
		doc /* The system shall operate from a DC power source with input voltage 
		     between 4.5V and 12V, regulated to 3.3V for the ESP32 and sensors. */
		
		subject esp32System.powerRegulator;
		
		assume constraint inputVoltageRange {
			esp32System.powerRegulator.inputVoltageRange_min >= 4.5 and
			esp32System.powerRegulator.inputVoltageRange_max <= 12.0
		}
		
		require constraint regulatedOutput {
			esp32System.powerRegulator.outputVoltage == 3.3
		}
		
		require constraint currentCapacity {
			esp32System.powerRegulator.maxOutputCurrent >= 0.8
		}
	}
	
	requirement <'SYS-REQ-003'> processingCapability : SystemRequirement {
		doc /* The ESP32 microcontroller shall provide dual-core processing at 240 MHz 
		     with sufficient memory for data buffering and WiFi stack operation. */
		
		subject esp32System.mcu;
		
		require constraint dualCoreProcessing {
			esp32System.mcu.processorCores == 2
		}
		
		require constraint clockSpeed {
			esp32System.mcu.clockFrequency >= 240.0
		}
		
		require constraint memoryCapacity {
			esp32System.mcu.sramSize >= 512.0 and
			esp32System.mcu.flashSize >= 4.0
		}
	}
	
	requirement <'SYS-REQ-004'> sensorPerformance : SystemRequirement {
		doc /* The BME280 sensor shall provide accurate environmental measurements 
		     within specified operating ranges for temperature, humidity, and pressure. */
		
		subject esp32System.environmentSensor;
		
		require constraint temperatureRange {
			esp32System.environmentSensor.temperatureRange_min <= 233.15 and
			esp32System.environmentSensor.temperatureRange_max >= 358.15
		}
		
		require constraint humidityRange {
			esp32System.environmentSensor.humidityRange_min == 0.0 and
			esp32System.environmentSensor.humidityRange_max == 100.0
		}
		
		require constraint pressureRange {
			esp32System.environmentSensor.pressureRange_min <= 30000.0 and
			esp32System.environmentSensor.pressureRange_max >= 110000.0
		}
	}
	
	requirement <'SYS-REQ-005'> connectivityRequirement : SystemRequirement {
		doc /* The system shall establish and maintain WiFi connectivity on the 2.4 GHz 
		     band and successfully transmit sensor data packets to the network. */
		
		subject esp32System.accessPoint;
		
		require constraint wifiFrequency {
			esp32System.accessPoint.frequency == 2.4
		}
		
		require constraint networkCapacity {
			esp32System.accessPoint.maxConnections >= 1
		}
	}
}
