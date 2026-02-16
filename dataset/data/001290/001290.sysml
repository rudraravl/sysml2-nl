package 'TirePressureMonitoringSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureValue :> Real;
	attribute def TemperatureValue :> Real;
	
	enum def WheelPosition {
		enum frontLeft;
		enum frontRight;
		enum rearLeft;
		enum rearRight;
	}
	
	enum def AlertLevel {
		enum normal;
		enum warning;
		enum critical;
	}
	
	item def SensorData {
		attribute wheelPosition : WheelPosition;
		attribute pressureValue : PressureValue;
		attribute temperatureValue : TemperatureValue;
		attribute batteryLevel : Real;
		attribute timestamp : Real;
	}
	
	item def AlertMessage {
		attribute affectedWheel : WheelPosition;
		attribute currentPressureValue : PressureValue;
		attribute alertLevel : AlertLevel;
		attribute alertText : String;
	}
	
	port def SensorOutputPort {
		out item sensorData : SensorData;
	}
	
	port def ReceiverInputPort {
		in item sensorData : SensorData;
	}
	
	port def ControllerInputPort {
		in item receivedData : SensorData;
	}
	
	port def ControllerOutputPort {
		out item alert : AlertMessage;
	}
	
	port def DisplayInputPort {
		in item alert : AlertMessage;
	}
	
	part def TirePressureSensor {
		attribute wheelLocation : WheelPosition;
		attribute sensorId : String;
		attribute batteryVoltage : Real;
		
		port sensorOut : SensorOutputPort;
		
		action def MeasurePressure {
			out measuredPressure : PressureValue;
		}
		
		action def MeasureTemperature {
			out measuredTemp : TemperatureValue;
		}
		
		action def TransmitData {
			in pressureValue : PressureValue;
			in tempValue : TemperatureValue;
			out dataPacket : SensorData;
		}
		
		action sensorCycle {
			first start;
			then loop action continuousSensing {
				action measure : MeasurePressure {
					out measuredPressure;
				}
				then action measureTemp : MeasureTemperature {
					out measuredTemp;
				}
				then action transmit : TransmitData {
					in pressureValue = measure.measuredPressure;
					in tempValue = measureTemp.measuredTemp;
					out dataPacket;
				}
			}
		}
	}
	
	part def RFReceiver {
		attribute signalStrength : Real;
		
		port receiverIn : ReceiverInputPort;
		port receiverOut : ControllerInputPort;
		
		action def ReceiveSignal {
			in incomingData : SensorData;
			out receivedData : SensorData;
		}
		
		action def ValidateSignal {
			in dataToValidate : SensorData;
			out isValid : Boolean;
			out validatedData : SensorData;
		}
	}
	
	part def ECU {
		attribute lowPressureThreshold : PressureValue;
		attribute criticalPressureThreshold : PressureValue;
		attribute highPressureThreshold : PressureValue;
		attribute nominalPressure : PressureValue;
		
		port ecuIn : ControllerInputPort;
		port ecuOut : ControllerOutputPort;
		
		action def EvaluatePressure {
			in sensorReading : SensorData;
			out evaluationResult : AlertLevel;
		}
		
		action def GenerateAlert {
			in sensorData : SensorData;
			in level : AlertLevel;
			out alertMsg : AlertMessage;
		}
		
		state def PressureMonitoringState {
			entry; then normalOperation;
			
			state normalOperation {
				entry action monitorNormal;
			}
			
			transition normalToWarning
				first normalOperation
				accept data : SensorData
				if data.pressureValue < 28.0
				then warningState;
			
			state warningState {
				entry action issueWarning;
			}
			
			transition warningToCritical
				first warningState
				accept data : SensorData
				if data.pressureValue < 22.0
				then criticalState;
			
			state criticalState {
				entry action issueCriticalAlert;
			}
			
			transition criticalToNormal
				first criticalState
				accept data : SensorData
				if data.pressureValue >= 28.0
				then normalOperation;
			
			transition warningToNormal
				first warningState
				accept data : SensorData
				if data.pressureValue >= 28.0
				then normalOperation;
		}
		
		action monitoringProcess {
			first start;
			then merge continuousMonitoring;
			
			then action receiveData {
				in inputData : SensorData;
			}
			
			then action evaluate : EvaluatePressure {
				in sensorReading = receiveData.inputData;
				out evaluationResult;
			}
			
			then decide;
				if evaluate.evaluationResult == AlertLevel::critical then generateCritical;
				if evaluate.evaluationResult == AlertLevel::warning then generateWarning;
				if evaluate.evaluationResult == AlertLevel::normal then continuousMonitoring;
			
			action generateCritical : GenerateAlert {
				in sensorData = receiveData.inputData;
				in level = AlertLevel::critical;
				out alertMsg;
			}
			then continuousMonitoring;
			
			action generateWarning : GenerateAlert {
				in sensorData = receiveData.inputData;
				in level = AlertLevel::warning;
				out alertMsg;
			}
			then continuousMonitoring;
		}
	}
	
	part def DriverDisplay {
		attribute displayBrightness : Real;
		attribute audioEnabled : Boolean;
		
		port displayIn : DisplayInputPort;
		
		action def ShowVisualAlert {
			in alert : AlertMessage;
		}
		
		action def PlayAudioAlert {
			in alert : AlertMessage;
		}
		
		action def UpdateDisplay {
			in alertData : AlertMessage;
		}
		
		state def DisplayState {
			entry; then idle;
			
			state idle;
			
			transition idleToActive
				first idle
				accept alert : AlertMessage
				if alert.alertLevel != AlertLevel::normal
				then active;
			
			state active {
				entry action activateDisplay;
			}
			
			transition activeToIdle
				first active
				accept alert : AlertMessage
				if alert.alertLevel == AlertLevel::normal
				then idle;
		}
	}
	
	part def Tire {
		attribute position : WheelPosition;
		attribute currentPressure : PressureValue;
		attribute currentTemperature : TemperatureValue;
		attribute recommendedPressure : PressureValue;
	}
	
	part def Vehicle {
		part frontLeftTire : Tire {
			attribute :>> position = WheelPosition::frontLeft;
		}
		part frontRightTire : Tire {
			attribute :>> position = WheelPosition::frontRight;
		}
		part rearLeftTire : Tire {
			attribute :>> position = WheelPosition::rearLeft;
		}
		part rearRightTire : Tire {
			attribute :>> position = WheelPosition::rearRight;
		}
		
		part sensorFL : TirePressureSensor {
			attribute :>> wheelLocation = WheelPosition::frontLeft;
			attribute :>> sensorId = "FL-001";
		}
		part sensorFR : TirePressureSensor {
			attribute :>> wheelLocation = WheelPosition::frontRight;
			attribute :>> sensorId = "FR-002";
		}
		part sensorRL : TirePressureSensor {
			attribute :>> wheelLocation = WheelPosition::rearLeft;
			attribute :>> sensorId = "RL-003";
		}
		part sensorRR : TirePressureSensor {
			attribute :>> wheelLocation = WheelPosition::rearRight;
			attribute :>> sensorId = "RR-004";
		}
		
		part receiver : RFReceiver;
		part controller : ECU {
			attribute :>> lowPressureThreshold = 28.0;
			attribute :>> criticalPressureThreshold = 22.0;
			attribute :>> highPressureThreshold = 38.0;
			attribute :>> nominalPressure = 32.0;
		}
		part display : DriverDisplay {
			attribute :>> displayBrightness = 0.8;
			attribute :>> audioEnabled = true;
		}
		
		connection sensorFLConnection
			connect sensorFL.sensorOut.sensorData to receiver.receiverIn.sensorData;
		connection sensorFRConnection
			connect sensorFR.sensorOut.sensorData to receiver.receiverIn.sensorData;
		connection sensorRLConnection
			connect sensorRL.sensorOut.sensorData to receiver.receiverIn.sensorData;
		connection sensorRRConnection
			connect sensorRR.sensorOut.sensorData to receiver.receiverIn.sensorData;
		
		connection receiverToController
			connect receiver.receiverOut.receivedData to controller.ecuIn.receivedData;
		connection controllerToDisplay
			connect controller.ecuOut.alert to display.displayIn.alert;
	}
	
	action def MonitorAllTires {
		first start;
		then merge monitoringLoop;
		
		then action collectAllSensorData {
			out sensorReadings : SensorData[4];
		}
		
		then action processAllData {
			in readings : SensorData[4] = collectAllSensorData.sensorReadings;
			out processedData : SensorData[4];
		}
		
		then action evaluateAllPressures {
			in data : SensorData[4] = processAllData.processedData;
			out alerts : AlertMessage[0..4];
		}
		
		then decide;
			if evaluateAllPressures.alerts->notEmpty() then issueAlerts;
			if evaluateAllPressures.alerts->isEmpty() then monitoringLoop;
		
		action issueAlerts {
			in alertsToIssue : AlertMessage[0..4] = evaluateAllPressures.alerts;
		}
		then monitoringLoop;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The TPMS shall continuously monitor tire pressure in all four tires and alert the driver when pressure falls below safe thresholds. */
		
		subject tpmsVehicle : Vehicle;
		
		require constraint monitoringCapability {
			doc /* The system shall monitor all four tire pressures continuously during vehicle operation. */
		}
		
		require constraint alertCapability {
			doc /* The system shall generate visual and audible alerts when tire pressure is below threshold. */
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The TPMS sensors shall measure tire pressure with accuracy of +/- 1.0 psi. */
		
		subject sensor : TirePressureSensor;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The TPMS shall detect and alert pressure loss within 20 minutes of occurrence. */
		
		subject ecu : ECU;
	}
	
	requirement def BatteryLifeRequirement {
		doc /* The TPMS sensors shall operate for minimum 7 years on internal battery. */
		
		subject sensor : TirePressureSensor;
	}
	
	part tpmsVehicle : Vehicle {
		satisfy primaryFunctionReq : PrimaryFunctionRequirement by tpmsVehicle;
		satisfy accuracyReq : AccuracyRequirement by tpmsVehicle.sensorFL;
		satisfy responseTimeReq : ResponseTimeRequirement by tpmsVehicle.controller;
		satisfy batteryLifeReq : BatteryLifeRequirement by tpmsVehicle.sensorFL;
		
		perform action systemOperation : MonitorAllTires;
	}
}
