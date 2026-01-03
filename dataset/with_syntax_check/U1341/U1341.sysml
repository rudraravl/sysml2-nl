package HomeAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceID :> String;
	attribute def RoomName :> String;
	attribute def EventID :> String;
	
	item def SensorEvent {
		attribute eventID : EventID;
		attribute timestamp : ISQ::DurationValue;
		attribute sourceDevice : DeviceID;
		attribute eventType : String;
		attribute value : Real;
	}
	
	item def ControlCommand {
		attribute commandID : String;
		attribute targetDevice : DeviceID;
		attribute action : String;
		attribute parameter : Real;
		attribute priority : Integer;
	}
	
	item def DeviceStatusReport {
		attribute deviceID : DeviceID;
		attribute state : String;
		attribute lastUpdate : ISQ::DurationValue;
		attribute isOnline : Boolean;
	}
	
	attribute def TemperatureReading :> ISQ::ThermodynamicTemperatureValue;
	attribute def LightIntensity :> ISQ::LuminousIntensityValue;
	attribute def PowerLevel :> ISQ::PowerValue;
	attribute def HumidityLevel :> Real;
	
	port def SensorDataPort {
		out item eventData : SensorEvent;
	}
	
	port def ActuatorCommandPort {
		in item command : ControlCommand;
		out item statusReport : DeviceStatusReport;
	}
	
	port def ControllerNetworkPort {
		in item sensorInput : SensorEvent;
		out item actuatorOutput : ControlCommand;
	}
	
	part def TemperatureSensor {
		attribute sensorID : DeviceID;
		attribute location : RoomName;
		attribute currentTemperature : TemperatureReading;
		attribute sampleRate : ISQ::FrequencyValue;
		port dataOut : SensorDataPort;
	}
	
	part def HumiditySensor {
		attribute sensorID : DeviceID;
		attribute location : RoomName;
		attribute currentHumidity : HumidityLevel;
		port dataOut : SensorDataPort;
	}
	
	part def MotionDetector {
		attribute sensorID : DeviceID;
		attribute location : RoomName;
		attribute motionDetected : Boolean;
		attribute detectionRange : ISQ::LengthValue;
		port dataOut : SensorDataPort;
	}
	
	part def LightSensor {
		attribute sensorID : DeviceID;
		attribute location : RoomName;
		attribute ambientLight : LightIntensity;
		port dataOut : SensorDataPort;
	}
	
	part def SmartLight {
		attribute deviceID : DeviceID;
		attribute location : RoomName;
		attribute brightness : Real;
		attribute isOn : Boolean;
		attribute powerConsumption : PowerLevel;
		port controlIn : ActuatorCommandPort;
		
		exhibit state lightBehavior {
			state Off {
				entry action setOff {
					assign isOn := false;
					assign brightness := 0.0;
				}
			}
			state On {
				entry action setOn {
					assign isOn := true;
				}
			}
			state Dimmed {
				entry action setDimmed {
					assign isOn := true;
				}
			}
			
			transition first start then Off;
			
			transition turnOn
				first Off
				accept cmd : ControlCommand
				if cmd.action == "turnOn"
				then On;
			
			transition turnOff
				first On
				accept cmd : ControlCommand
				if cmd.action == "turnOff"
				then Off;
			
			transition dimLight
				first On
				accept cmd : ControlCommand
				if cmd.action == "dim"
				then Dimmed;
			
			transition brightenLight
				first Dimmed
				accept cmd : ControlCommand
				if cmd.action == "brighten"
				then On;
		}
	}
	
	part def SmartThermostat {
		attribute deviceID : DeviceID;
		attribute targetTemperature : TemperatureReading;
		attribute currentTemperature : TemperatureReading;
		attribute operatingMode : String;
		attribute fanSpeed : Integer;
		port controlIn : ActuatorCommandPort;
	}
	
	part def SmartPlug {
		attribute deviceID : DeviceID;
		attribute location : RoomName;
		attribute isActive : Boolean;
		attribute currentPower : PowerLevel;
		attribute energyUsed : ISQ::EnergyValue;
		port controlIn : ActuatorCommandPort;
	}
	
	part def DoorLock {
		attribute deviceID : DeviceID;
		attribute location : RoomName;
		attribute isLocked : Boolean;
		attribute batteryLevel : Real;
		port controlIn : ActuatorCommandPort;
	}
	
	part def HomeSeerController {
		attribute controllerID : DeviceID;
		attribute registeredDevices : DeviceID[*];
		attribute activeRules : Integer;
		attribute systemUptime : ISQ::DurationValue;
		
		port sensorNetwork : ControllerNetworkPort[*];
		port actuatorNetwork : ControllerNetworkPort[*];
		
		part ruleProcessor {
			perform action processAutomationRules[*] ordered;
		}
		
		part eventManager {
			perform action handleEvents[*] ordered;
		}
		
		part deviceRegistry {
			perform action manageDevices[*] ordered;
		}
		
		part commandScheduler {
			perform action scheduleCommands[*] ordered;
		}
	}
	
	action def CollectSensorData {
		out sensorEvents : SensorEvent[*];
	}
	
	action def AnalyzeEnvironment {
		in events : SensorEvent[*];
		out environmentState : String;
		out triggeredConditions : String[*];
	}
	
	action def EvaluateAutomationRules {
		in conditions : String[*];
		in environmentState : String;
		out applicableRules : String[*];
		out commandQueue : ControlCommand[*];
	}
	
	action def DispatchCommands {
		in commands : ControlCommand[*];
		out executionResults : DeviceStatusReport[*];
	}
	
	action def UpdateDeviceStatus {
		in statusReports : DeviceStatusReport[*];
	}
	
	action def LogAutomationActivity {
		in event : SensorEvent;
		in command : ControlCommand;
	}
	
	action def HomeAutomationCycle {
		first start;
		
		then merge continuousMonitoring;
		
		then action collectData : CollectSensorData {
			out sensorEvents : SensorEvent[*];
		}
		
		then action analyzeEnv : AnalyzeEnvironment {
			in events = collectData.sensorEvents;
			out environmentState : String;
			out triggeredConditions : String[*];
		}
		
		then action evaluateRules : EvaluateAutomationRules {
			in conditions = analyzeEnv.triggeredConditions;
			in environmentState = analyzeEnv.environmentState;
			out applicableRules : String[*];
			out commandQueue : ControlCommand[*];
		}
		
		then decide;
			if evaluateRules.commandQueue->size() > 0 then dispatchActions;
			if evaluateRules.commandQueue->size() == 0 then continuousMonitoring;
		
		action dispatchActions : DispatchCommands {
			in commands = evaluateRules.commandQueue;
			out executionResults : DeviceStatusReport[*];
		}
		
		then action updateStatus : UpdateDeviceStatus {
			in statusReports = dispatchActions.executionResults;
		}
		
		then action logActivity : LogAutomationActivity {
			in event : SensorEvent;
			in command : ControlCommand;
		}
		
		then continuousMonitoring;
	}
	
	action def InitializeController;
	action def DiscoverDevices;
	action def LoadRules;
	action def EnterLowPowerMode;
	action def ActivateSensors;
	action def EvaluateConditions;
	action def SendCommands;
	action def PerformDiagnostics;
	action def LogError;
	action def AttemptRecovery;
	
	state def ControllerOperationalState {
		entry action initCtrl : InitializeController;
		
		state Initializing {
			entry action discover : DiscoverDevices;
			entry action load : LoadRules;
		}
		
		state Idle {
			entry action lowPower : EnterLowPowerMode;
		}
		
		state Monitoring {
			entry action activate : ActivateSensors;
		}
		
		state Processing {
			entry action evaluate : EvaluateConditions;
		}
		
		state Executing {
			entry action send : SendCommands;
		}
		
		state Maintenance {
			entry action diagnose : PerformDiagnostics;
		}
		
		state Error {
			entry action logErr : LogError;
			entry action recover : AttemptRecovery;
		}
		
		transition first start then Initializing;
		
		transition initToIdle
			first Initializing
			then Idle;
		
		transition idleToMonitoring
			first Idle
			accept eventReceived : SensorEvent
			then Monitoring;
		
		transition monitoringToProcessing
			first Monitoring
			then Processing;
		
		transition processingToExecuting
			first Processing
			if commandsGenerated
			then Executing;
		
		transition processingToIdle
			first Processing
			if not commandsGenerated
			then Idle;
		
		transition executingToIdle
			first Executing
			then Idle;
		
		transition anyToMaintenance
			first Idle
			accept maintenanceScheduled
			then Maintenance;
		
		transition maintenanceToIdle
			first Maintenance
			then Idle;
		
		transition anyToError
			first Monitoring
			accept systemFault
			then Error;
		
		transition errorToIdle
			first Error
			accept recoveryComplete
			then Idle;
	}
	
	part homeAutomationSystem : HomeSeerController {
		perform action automationControl[*] ordered references HomeAutomationCycle;
		
		part livingRoomTempSensor : TemperatureSensor {
			:>> sensorID = "TEMP_LR_01";
			:>> location = "Living Room";
		}
		
		part livingRoomHumiditySensor : HumiditySensor {
			:>> sensorID = "HUM_LR_01";
			:>> location = "Living Room";
		}
		
		part hallwayMotionSensor : MotionDetector {
			:>> sensorID = "MOT_HALL_01";
			:>> location = "Hallway";
		}
		
		part bedroomMotionSensor : MotionDetector {
			:>> sensorID = "MOT_BED_01";
			:>> location = "Bedroom";
		}
		
		part outdoorLightSensor : LightSensor {
			:>> sensorID = "LIGHT_OUT_01";
			:>> location = "Outdoor";
		}
		
		part livingRoomLight : SmartLight {
			:>> deviceID = "LIGHT_LR_01";
			:>> location = "Living Room";
		}
		
		part bedroomLight : SmartLight {
			:>> deviceID = "LIGHT_BED_01";
			:>> location = "Bedroom";
		}
		
		part hallwayLight : SmartLight {
			:>> deviceID = "LIGHT_HALL_01";
			:>> location = "Hallway";
		}
		
		part mainThermostat : SmartThermostat {
			:>> deviceID = "THERM_MAIN_01";
			:>> operatingMode = "auto";
		}
		
		part coffeePlugControl : SmartPlug {
			:>> deviceID = "PLUG_COFFEE_01";
			:>> location = "Kitchen";
		}
		
		part lampPlugControl : SmartPlug {
			:>> deviceID = "PLUG_LAMP_01";
			:>> location = "Living Room";
		}
		
		part frontDoorLock : DoorLock {
			:>> deviceID = "LOCK_FRONT_01";
			:>> location = "Front Door";
		}
		
		part backDoorLock : DoorLock {
			:>> deviceID = "LOCK_BACK_01";
			:>> location = "Back Door";
		}
		
		connection sensorConnection1 connect 
			livingRoomTempSensor.dataOut to sensorNetwork;
		
		connection sensorConnection2 connect 
			livingRoomHumiditySensor.dataOut to sensorNetwork;
		
		connection sensorConnection3 connect 
			hallwayMotionSensor.dataOut to sensorNetwork;
		
		connection sensorConnection4 connect 
			bedroomMotionSensor.dataOut to sensorNetwork;
		
		connection sensorConnection5 connect 
			outdoorLightSensor.dataOut to sensorNetwork;
		
		connection actuatorConnection1 connect 
			actuatorNetwork to livingRoomLight.controlIn;
		
		connection actuatorConnection2 connect 
			actuatorNetwork to bedroomLight.controlIn;
		
		connection actuatorConnection3 connect 
			actuatorNetwork to hallwayLight.controlIn;
		
		connection actuatorConnection4 connect 
			actuatorNetwork to mainThermostat.controlIn;
		
		connection actuatorConnection5 connect 
			actuatorNetwork to coffeePlugControl.controlIn;
		
		connection actuatorConnection6 connect 
			actuatorNetwork to lampPlugControl.controlIn;
		
		connection actuatorConnection7 connect 
			actuatorNetwork to frontDoorLock.controlIn;
		
		connection actuatorConnection8 connect 
			actuatorNetwork to backDoorLock.controlIn;
	}
	
	requirement def SystemRequirement;
	
	requirement <'HS-REQ-001'> primaryFunctionRequirement : SystemRequirement {
		doc /* The HomeSeer system shall provide comprehensive home automation by continuously 
		       monitoring environmental conditions and occupancy through distributed sensors, 
		       evaluating automation rules based on collected data, and executing control commands 
		       to smart devices to optimize comfort, security, energy efficiency, and convenience. */
		
		subject homeAutomationSystem;
	}
	
	requirement <'HS-REQ-002'> deviceIntegrationRequirement : SystemRequirement {
		doc /* The system shall integrate and manage multiple heterogeneous smart home devices 
		       including sensors, lights, thermostats, plugs, and locks through a unified 
		       control interface. */
		
		subject homeAutomationSystem;
		
		require constraint minimumDeviceCount {
			homeAutomationSystem.registeredDevices->size() >= 10
		}
	}
	
	requirement <'HS-REQ-003'> realTimeProcessingRequirement : SystemRequirement {
		doc /* The system shall process sensor events and execute automation rules in real-time 
		       to ensure responsive control of home devices. */
		
		subject homeAutomationSystem.automationControl;
	}
	
	requirement <'HS-REQ-004'> reliabilityRequirement : SystemRequirement {
		doc /* The system shall maintain continuous operation with automatic error recovery 
		       to ensure reliable home automation services. */
		
		subject homeAutomationSystem;
		
		require constraint continuousOperation {
			homeAutomationSystem.automationControl->notEmpty()
		}
	}
	
	requirement <'HS-REQ-005'> energyOptimizationRequirement : SystemRequirement {
		doc /* The system shall optimize energy consumption by intelligently controlling 
		       lighting, HVAC, and appliances based on occupancy patterns and environmental 
		       conditions. */
		
		subject homeAutomationSystem;
	}
	
	requirement <'HS-REQ-006'> securityRequirement : SystemRequirement {
		doc /* The system shall enhance home security through automated monitoring and control 
		       of door locks, motion sensors, and lighting based on occupancy and time of day. */
		
		subject homeAutomationSystem;
	}
	
	requirement homeAutomationMission {
		doc /* The HomeSeer home automation system shall deliver intelligent, automated control 
		       of residential environments by integrating diverse smart devices, continuously 
		       monitoring conditions, applying rule-based automation logic, and executing 
		       coordinated control actions to enhance occupant comfort, safety, energy efficiency, 
		       and overall quality of life. */
		
		assume constraint sensorsOperational {
			homeAutomationSystem.livingRoomTempSensor.dataOut->notEmpty() and
			homeAutomationSystem.hallwayMotionSensor.dataOut->notEmpty() and
			homeAutomationSystem.outdoorLightSensor.dataOut->notEmpty()
		}
		
		assume constraint devicesResponsive {
			homeAutomationSystem.livingRoomLight.controlIn->notEmpty() and
			homeAutomationSystem.mainThermostat.controlIn->notEmpty()
		}
		
		require primaryFunctionRequirement;
		require deviceIntegrationRequirement;
		require realTimeProcessingRequirement;
		require reliabilityRequirement;
		require energyOptimizationRequirement;
		require securityRequirement;
	}
}
