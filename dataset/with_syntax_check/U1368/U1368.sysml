package 'Xiaomi Smart Home System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def DeviceID;
	attribute def UserCommand;
	attribute def AutomationRule;

	value def TemperatureReading :> ISQ::TemperatureValue;
	value def HumidityReading :> Real;
	value def IlluminanceReading :> ISQ::IlluminanceValue;
	value def PowerLevel :> ISQ::PowerValue;

	enum def DeviceStatus {
		offline;
		idle;
		active;
		error;
	}

	enum def SecurityState {
		disarmed;
		armed_home;
		armed_away;
		triggered;
	}

	item def SensorData {
		attribute temperature : TemperatureReading;
		attribute humidity : HumidityReading;
		attribute illuminance : IlluminanceReading;
		attribute motionDetected : Boolean;
		attribute timestamp : Real;
	}

	item def ControlCommand {
		attribute deviceId : DeviceID;
		attribute action : String;
		attribute value : Real;
	}

	port def SensorPort {
		out sensorData : SensorData;
	}

	port def ActuatorPort {
		in controlCmd : ControlCommand;
	}

	port def CommunicationPort {
		in dataIn : SensorData;
		out dataOut : ControlCommand;
	}

	part def MiGateway {
		attribute gatewayId : DeviceID;
		port zigbeeComm : CommunicationPort[1..*];
		port wifiComm : CommunicationPort;

		part zigbeeRadio {
			attribute frequency : Real = 2.4e9;
			attribute range : Real = 100.0;
		}

		part wifiRadio {
			attribute ssid : String;
			attribute ipAddress : String;
		}
	}

	part def TemperatureHumiditySensor {
		attribute sensorId : DeviceID;
		attribute batteryLevel : Real;
		port dataPort : SensorPort;

		attribute currentTemp : TemperatureReading;
		attribute currentHumidity : HumidityReading;
	}

	part def MotionSensor {
		attribute sensorId : DeviceID;
		attribute batteryLevel : Real;
		attribute sensitivity : Real;
		port dataPort : SensorPort;

		attribute motionState : Boolean;
		attribute lastTriggerTime : Real;
	}

	part def DoorWindowSensor {
		attribute sensorId : DeviceID;
		attribute batteryLevel : Real;
		port dataPort : SensorPort;

		attribute isOpen : Boolean;
	}

	part def SmartBulb {
		attribute bulbId : DeviceID;
		port controlPort : ActuatorPort;

		attribute brightness : Real;
		attribute colorTemperature : Real;
		attribute powerState : Boolean;
	}

	part def SmartPlug {
		attribute plugId : DeviceID;
		port controlPort : ActuatorPort;

		attribute powerState : Boolean;
		attribute currentPower : PowerLevel;
		attribute energyConsumed : Real;
	}

	part def AirConditioner {
		attribute acId : DeviceID;
		port controlPort : ActuatorPort;

		attribute targetTemp : TemperatureReading;
		attribute mode : String;
		attribute fanSpeed : Real;
		attribute powerState : Boolean;
	}

	part def SecurityCamera {
		attribute cameraId : DeviceID;
		port controlPort : ActuatorPort;
		port videoStream : CommunicationPort;

		attribute recording : Boolean;
		attribute nightVision : Boolean;
		attribute resolution : String;
	}

	action def CollectSensorData {
		in tempData : TemperatureReading[*];
		in humidData : HumidityReading[*];
		in motionData : Boolean[*];
		out aggregatedData : SensorData[*];
	}

	action def EvaluateAutomationRules {
		in sensorData : SensorData;
		in rules : AutomationRule[*];
		out commands : ControlCommand[*];
	}

	action def ExecuteDeviceControl {
		in commands : ControlCommand[*];
		out executionStatus : Boolean[*];
	}

	state def SystemOperationStates {
		entry; then initializing;

		state initializing {
			entry assign systemMode := 'startup';
		}

		state monitoring {
			entry assign systemMode := 'active';
		}

		state evaluating;

		state controlling;

		state secured {
			entry assign systemMode := 'security_active';
		}

		state alarm {
			entry assign systemMode := 'alarm_triggered';
		}

		transition init_to_monitor
			first initializing
			accept systemReady : UserCommand
			then monitoring;

		transition monitor_to_evaluate
			first monitoring
			if dataReceived
			then evaluating;

		transition evaluate_to_control
			first evaluating
			if rulesMatched
			then controlling;

		transition control_to_monitor
			first controlling
			then monitoring;

		transition monitor_to_secured
			first monitoring
			accept armSystem : UserCommand
			then secured;

		transition secured_to_alarm
			first secured
			if intrusionDetected
			then alarm;

		transition alarm_to_monitor
			first alarm
			accept disarmSystem : UserCommand
			then monitoring;

		attribute systemMode : String;
		attribute dataReceived : Boolean;
		attribute rulesMatched : Boolean;
		attribute intrusionDetected : Boolean;
	}

	part def XiaomiSmartHomeSystem {
		part gateway : MiGateway {
			port zigbeeComm : CommunicationPort[6];
			port wifiComm;
		}

		part livingRoomTempSensor : TemperatureHumiditySensor {
			port dataPort;
		}

		part bedroomTempSensor : TemperatureHumiditySensor {
			port dataPort;
		}

		part hallwayMotionSensor : MotionSensor {
			port dataPort;
		}

		part entranceDoorSensor : DoorWindowSensor {
			port dataPort;
		}

		part livingRoomBulb : SmartBulb {
			port controlPort;
		}

		part bedroomBulb : SmartBulb {
			port controlPort;
		}

		part livingRoomPlug : SmartPlug {
			port controlPort;
		}

		part bedroomAC : AirConditioner {
			port controlPort;
		}

		part frontDoorCamera : SecurityCamera {
			port controlPort;
			port videoStream;
		}
	}

	part xiaomiSmartHomeSystem : XiaomiSmartHomeSystem {
		perform action automateHome {
			first start;
			then merge monitorLoop;

			action gatherSensorData : CollectSensorData {
				in tempData : TemperatureReading[*];
				in humidData : HumidityReading[*];
				in motionData : Boolean[*];
				out aggregatedData : SensorData[*];
			}

			then decide;
				if gatherSensorData.aggregatedData->notEmpty() then processAutomation;
				else monitorLoop;

			action processAutomation : EvaluateAutomationRules {
				in sensorData = gatherSensorData.aggregatedData->first();
				in rules : AutomationRule[*];
				out commands : ControlCommand[*];
			}

			then action applyControls : ExecuteDeviceControl {
				in commands = processAutomation.commands;
				out executionStatus : Boolean[*];
			}

			then monitorLoop;
			then done;
		}

		perform action manageClimate {
			loop {
				accept tempReading : SensorData;

				then decide;
					if tempReading.temperature > 299.0[K] then coolDown;
					if tempReading.temperature < 293.0[K] then heatUp;
					else maintain;

				action coolDown;
				then monitor;

				action heatUp;
				then monitor;

				action maintain;
				then monitor;

				merge monitor;
			}
		}

		perform action secureHome {
			first start;
			then merge checkSecurity;

			action monitorEntryPoints {
				out threatLevel : Real;
			}

			then decide;
				if monitorEntryPoints.threatLevel > 0.5 then triggerAlarm;
				else checkSecurity;

			action triggerAlarm;

			then checkSecurity;
		}
	}

	requirement def SmartHomeRequirements {
		doc /* The Xiaomi Smart Home System shall provide comprehensive home automation, environmental monitoring, and security management. */

		requirement <'REQ-SH-001'> primaryFunction {
			doc /* The system shall monitor environmental conditions using temperature, humidity, motion, and door sensors, and automatically control connected devices including lighting, climate control, and security equipment to optimize comfort, energy efficiency, and safety. */
			subject xiaomiSmartHomeSystem;
		}

		requirement <'REQ-SH-002'> environmentalMonitoring {
			doc /* The system shall continuously monitor temperature and humidity in multiple rooms with accuracy of ±0.3°C and ±3% RH respectively. */
		}

		requirement <'REQ-SH-003'> automationResponse {
			doc /* The system shall execute automation rules within 500 milliseconds of receiving sensor data. */
		}

		requirement <'REQ-SH-004'> securityMonitoring {
			doc /* The system shall detect intrusion events through motion and door sensors and trigger appropriate responses including camera recording and user notification. */
		}

		requirement <'REQ-SH-005'> deviceControl {
			doc /* The system shall control smart bulbs, plugs, air conditioners, and cameras through the central gateway using Zigbee protocol. */
		}

		requirement <'REQ-SH-006'> energyEfficiency {
			doc /* The system shall optimize energy consumption by automatically adjusting lighting and climate control based on occupancy and environmental conditions. */
		}

		requirement <'REQ-SH-007'> connectivity {
			doc /* The system shall maintain stable Zigbee connections with all devices within 100 meter range and provide WiFi connectivity for remote access. */
		}

		requirement <'REQ-SH-008'> batteryLife {
			doc /* Battery-powered sensors shall operate for minimum 12 months on single battery under normal usage conditions. */
		}
	}

	action def ManageSmartHome {
		in sensorInputs : SensorData[*];
		in userCommands : UserCommand[*];
		out deviceControls : ControlCommand[*];
		out systemState : String;

		first start;
		then merge operationCycle;

		action collectEnvironmentalData : CollectSensorData {
			in tempData : TemperatureReading[*];
			in humidData : HumidityReading[*];
			in motionData : Boolean[*];
			out aggregatedData : SensorData[*];
		}

		then action analyzeConditions : EvaluateAutomationRules {
			in sensorData = collectEnvironmentalData.aggregatedData->first();
			in rules : AutomationRule[*];
			out commands : ControlCommand[*];
		}

		then operationCycle;

		action applyDeviceControls : ExecuteDeviceControl {
			in commands = analyzeConditions.commands;
			out executionStatus : Boolean[*];
		}

		then action updateSystemState {
			in status = applyDeviceControls.executionStatus;
			out state : String;
		}

		then operationCycle;
	}
}
