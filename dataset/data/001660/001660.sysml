package 'Home Assistant System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceIdentifier :> String;
	attribute def RoomName :> String;
	attribute def AutomationRuleID :> String;
	
	enum def DeviceStatus {
		enum online;
		enum offline;
		enum error;
	}
	
	enum def OccupancyState {
		enum occupied;
		enum vacant;
	}
	
	enum def LockState {
		enum locked;
		enum unlocked;
	}
	
	enum def LightMode {
		enum off;
		enum on;
		enum dimmed;
	}
	
	enum def HVACMode {
		enum off;
		enum heating;
		enum cooling;
		enum auto;
	}
	
	attribute def BrightnessLevel :> Real;
	attribute def HumidityLevel :> Real;
	
	item def EnvironmentalConditions {
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute humidity : HumidityLevel;
		attribute lightLevel : ISQ::LuminousIntensityValue;
		attribute occupancy : OccupancyState;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def DeviceCommand {
		attribute targetDevice : DeviceIdentifier;
		attribute commandType : String;
		attribute parameters : String[*];
		attribute priority : Integer;
	}
	
	item def SystemStatus {
		attribute connectedDevices : Integer;
		attribute activeAutomations : Integer;
		attribute systemHealth : DeviceStatus;
		attribute lastUpdate : ISQ::TimeValue;
	}
	
	port def SensorDataPort {
		out environmentalData : EnvironmentalConditions;
	}
	
	port def ControlPort {
		in command : DeviceCommand;
		out acknowledgment : DeviceStatus;
	}
	
	port def UserInterfacePort {
		in userRequest : String;
		out systemResponse : SystemStatus;
	}
	
	port def NetworkPort {
		in remoteCommand : DeviceCommand;
		out telemetryData : EnvironmentalConditions;
	}
	
	part def TemperatureHumiditySensor {
		port dataOut : SensorDataPort;
		attribute sensorID : DeviceIdentifier;
		attribute location : RoomName;
		attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
		attribute currentHumidity : HumidityLevel;
		attribute samplingRate : ISQ::FrequencyValue;
	}
	
	part def OccupancySensor {
		port dataOut : SensorDataPort;
		attribute sensorID : DeviceIdentifier;
		attribute location : RoomName;
		attribute detectionRange : ISQ::LengthValue;
		attribute currentState : OccupancyState;
	}
	
	part def SmartThermostat {
		port controlIn : ControlPort;
		attribute deviceID : DeviceIdentifier;
		attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute currentMode : HVACMode;
		attribute powerConsumption : ISQ::PowerValue;
	}
	
	part def SmartLight {
		port controlIn : ControlPort;
		attribute deviceID : DeviceIdentifier;
		attribute brightness : BrightnessLevel;
		attribute mode : LightMode;
		attribute colorTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def SmartDoorLock {
		port controlIn : ControlPort;
		attribute deviceID : DeviceIdentifier;
		attribute currentState : LockState;
		attribute accessLog : String[*];
		attribute batteryLevel : Real;
	}
	
	part def AutomationController {
		attribute activeRules : AutomationRuleID[*];
		attribute ruleEvaluationInterval : ISQ::TimeValue;
		
		action def EvaluateConditions {
			in sensorData : EnvironmentalConditions[*];
			in currentTime : ISQ::TimeValue;
			in userPreferences : String[*];
			out triggeredRules : AutomationRuleID[*];
			out generatedCommands : DeviceCommand[*];
		}
		
		action def ExecuteAutomationCycle {
			in environmentalInputs : EnvironmentalConditions[*];
			in timeOfDay : ISQ::TimeValue;
			out deviceCommands : DeviceCommand[*];
			
			first start;
			then action gatherData {
				in inputs = environmentalInputs;
				out aggregatedData : EnvironmentalConditions[*];
			}
			then action evaluate : EvaluateConditions {
				in sensorData = gatherData.aggregatedData;
				in currentTime = timeOfDay;
				in userPreferences;
				out triggeredRules;
				out generatedCommands;
			}
			then decide;
				if evaluate.generatedCommands->size() > 0 then issueCommands;
				else done;
			action issueCommands {
				out commands = evaluate.generatedCommands;
			}
			then assign deviceCommands := issueCommands.commands;
			then done;
		}
	}
	
	part def CentralHub {
		attribute registeredDevices : DeviceIdentifier[*];
		attribute systemUptime : ISQ::TimeValue;
		attribute networkStatus : DeviceStatus;
		
		action def ProcessSensorInput {
			in rawSensorData : EnvironmentalConditions;
			out validatedData : EnvironmentalConditions;
			out dataQuality : Real;
		}
		
		action def RouteCommand {
			in command : DeviceCommand;
			out targetDeviceID : DeviceIdentifier;
			out routedCommand : DeviceCommand;
		}
		
		action def UpdateSystemState {
			in deviceStatuses : DeviceStatus[*];
			in automationResults : AutomationRuleID[*];
			out currentStatus : SystemStatus;
		}
	}
	
	part def UserDashboard {
		port uiPort : UserInterfacePort;
		attribute displayedRooms : RoomName[*];
		attribute refreshRate : ISQ::FrequencyValue;
		
		action def HandleUserInteraction {
			in userInput : String;
			out interpretedCommand : DeviceCommand;
			out validationResult : Boolean;
		}
		
		action def RenderStatus {
			in systemData : SystemStatus;
			in deviceStates : DeviceStatus[*];
			out displayContent : String;
		}
	}
	
	requirement def HomeAssistantRequirements {
		doc /* The Home Assistant system shall provide intelligent automation and centralized control of smart home devices. */
		
		requirement automationRequirement {
			doc /* The system shall automatically control devices based on environmental conditions, time schedules, and user-defined rules. */
		}
		
		requirement reliabilityRequirement {
			doc /* The system shall maintain 99.5% availability for core automation and control functions. */
		}
		
		requirement responsivenessRequirement {
			doc /* The system shall process sensor inputs and execute automation rules within 1 second. */
		}
		
		requirement scalabilityRequirement {
			doc /* The system shall support at least 50 connected devices across multiple rooms. */
		}
		
		requirement securityRequirement {
			doc /* All device communications and user interactions shall be authenticated and encrypted. */
		}
		
		requirement energyEfficiencyRequirement {
			doc /* The system shall optimize device operation to reduce overall energy consumption by at least 15%. */
		}
	}
	
	part def HomeAssistantSystem;
	
	part homeAssistantSystem : HomeAssistantSystem {
		part sensors {
			part livingRoomTempSensor : TemperatureHumiditySensor {
				attribute location = "Living Room";
				attribute samplingRate = 0.1[SI::Hz];
			}
			part bedroomTempSensor : TemperatureHumiditySensor {
				attribute location = "Bedroom";
				attribute samplingRate = 0.1[SI::Hz];
			}
			part entranceOccupancySensor : OccupancySensor {
				attribute location = "Entrance";
				attribute detectionRange = 5.0[SI::m];
			}
			part livingRoomOccupancySensor : OccupancySensor {
				attribute location = "Living Room";
				attribute detectionRange = 6.0[SI::m];
			}
		}
		
		part actuators {
			part mainThermostat : SmartThermostat {
				attribute targetTemperature = 294.15[SI::K];
				attribute currentMode = HVACMode::auto;
			}
			part livingRoomLight : SmartLight {
				attribute brightness = 0.8;
				attribute mode = LightMode::on;
			}
			part bedroomLight : SmartLight {
				attribute brightness = 0.5;
				attribute mode = LightMode::dimmed;
			}
			part frontDoorLock : SmartDoorLock {
				attribute currentState = LockState::locked;
				attribute batteryLevel = 0.85;
			}
		}
		
		part centralHub : CentralHub {
			attribute systemUptime = 86400.0[SI::s];
			attribute networkStatus = DeviceStatus::online;
		}
		
		part automationEngine : AutomationController {
			attribute ruleEvaluationInterval = 5.0[SI::s];
		}
		
		part userInterface : UserDashboard {
			attribute displayedRooms = ("Living Room", "Bedroom", "Entrance");
			attribute refreshRate = 1.0[SI::Hz];
		}
		
		connection sensorConnection1 connect sensors.livingRoomTempSensor.dataOut to centralHub;
		connection sensorConnection2 connect sensors.bedroomTempSensor.dataOut to centralHub;
		connection sensorConnection3 connect sensors.entranceOccupancySensor.dataOut to centralHub;
		connection sensorConnection4 connect sensors.livingRoomOccupancySensor.dataOut to centralHub;
		
		connection actuatorConnection1 connect centralHub to actuators.mainThermostat.controlIn;
		connection actuatorConnection2 connect centralHub to actuators.livingRoomLight.controlIn;
		connection actuatorConnection3 connect centralHub to actuators.bedroomLight.controlIn;
		connection actuatorConnection4 connect centralHub to actuators.frontDoorLock.controlIn;
		
		connection uiConnection connect userInterface.uiPort to centralHub;
		
		perform action orchestrateHomeAutomation {
			first start;
			then merge continuousMonitoring;
			
			then action collectEnvironmentalData {
				action readLivingRoomTemp {
					out tempData : EnvironmentalConditions;
				}
				action readBedroomTemp {
					out tempData : EnvironmentalConditions;
				}
				action readOccupancy {
					out occupancyData : EnvironmentalConditions;
				}
			}
			
			then action validateSensorData : centralHub::ProcessSensorInput {
				in rawSensorData;
				out validatedData;
				out dataQuality;
			}
			
			then action executeAutomation : automationEngine::ExecuteAutomationCycle {
				in environmentalInputs = validateSensorData.validatedData;
				in timeOfDay;
				out deviceCommands;
			}
			
			then decide;
				if executeAutomation.deviceCommands->size() > 0 then dispatchCommands;
				else checkUserActivity;
			
			action dispatchCommands {
				action routeToDevices : centralHub::RouteCommand {
					in command;
					out targetDeviceID;
					out routedCommand;
				}
			}
			then checkUserActivity;
			
			action checkUserActivity {
				accept userInteraction : String;
			}
			then decide;
				if checkUserActivity.userInteraction != null then processUserRequest;
				else updateDashboard;
			
			action processUserRequest : userInterface::HandleUserInteraction {
				in userInput = checkUserActivity.userInteraction;
				out interpretedCommand;
				out validationResult;
			}
			then action executeUserCommand : centralHub::RouteCommand {
				in command = processUserRequest.interpretedCommand;
				out targetDeviceID;
				out routedCommand;
			}
			then updateDashboard;
			
			action updateDashboard : centralHub::UpdateSystemState {
				in deviceStatuses;
				in automationResults;
				out currentStatus;
			}
			then action refreshUI : userInterface::RenderStatus {
				in systemData = updateDashboard.currentStatus;
				in deviceStates;
				out displayContent;
			}
			
			then continuousMonitoring;
		}
	}
	
	requirement systemRequirements : HomeAssistantRequirements {
		subject homeAssistantSystem;
		
		require automationRequirement;
		require reliabilityRequirement;
		require responsivenessRequirement;
		require scalabilityRequirement;
		require securityRequirement;
		require energyEfficiencyRequirement;
		
		requirement primaryFunctionRequirement {
			doc /* The Home Assistant system shall monitor environmental conditions through distributed sensors, execute intelligent automation rules, and provide centralized control of all connected smart home devices to enhance comfort, security, and energy efficiency. */
		}
	}
}
