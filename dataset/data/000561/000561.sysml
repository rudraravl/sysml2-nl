package 'Burn Recovery Bed System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint;
	attribute def PressureSetpoint;
	attribute def HumiditySetpoint;
	attribute def RotationAngle;
	attribute def AlarmLevel;
	attribute def SensorReading;
	
	enum def AlertStatus {
		nominal;
		warning;
		critical;
	}
	
	item def PatientData {
		attribute bodyMass : MassValue;
		attribute skinTemperature : ThermodynamicTemperatureValue;
		attribute contactPressure : PressureValue;
		attribute timeInPosition : DurationValue;
	}
	
	item def EnvironmentState {
		attribute surfaceTemperature : ThermodynamicTemperatureValue;
		attribute ambientHumidity : Real;
		attribute bedAngle : Real;
	}
	
	port def SensorPort {
		out temperature : ThermodynamicTemperatureValue;
		out pressure : PressureValue;
		out humidity : Real;
		out angle : Real;
	}
	
	port def ActuatorPort {
		in heatingCommand : Real;
		in coolingCommand : Real;
		in pressureCommand : Real;
		in rotationCommand : Real;
	}
	
	port def PowerPort {
		in voltage : ElectricPotentialValue;
		in current : ElectricCurrentValue;
	}
	
	port def ControlPort {
		in setpointTemp : ThermodynamicTemperatureValue;
		in setpointPressure : PressureValue;
		in setpointHumidity : Real;
		out alertStatus : AlertStatus;
	}
	
	part def TemperatureControlSystem {
		attribute currentTemp : ThermodynamicTemperatureValue;
		attribute targetTemp : ThermodynamicTemperatureValue;
		port power : PowerPort;
		port control : ActuatorPort;
		port sensing : SensorPort;
	}
	
	part def PressureReliefSystem {
		attribute currentPressure : PressureValue;
		attribute targetPressure : PressureValue;
		attribute redistributionCycle : DurationValue;
		port power : PowerPort;
		port control : ActuatorPort;
		port sensing : SensorPort;
	}
	
	part def PositioningSystem {
		attribute currentAngle : Real;
		attribute targetAngle : Real;
		attribute rotationRate : Real;
		port power : PowerPort;
		port control : ActuatorPort;
		port sensing : SensorPort;
	}
	
	part def HumidityControlSystem {
		attribute currentHumidity : Real;
		attribute targetHumidity : Real;
		port power : PowerPort;
		port control : ActuatorPort;
		port sensing : SensorPort;
	}
	
	part def MonitoringSystem {
		attribute tempReadings : ThermodynamicTemperatureValue[*];
		attribute pressureReadings : PressureValue[*];
		attribute humidityReadings : Real[*];
		attribute positionReadings : Real[*];
		port sensors : SensorPort;
		port alarms : ControlPort;
	}
	
	part def ControlUnit {
		attribute operatingMode : String;
		attribute therapyCycle : DurationValue;
		port systemControl : ControlPort;
		port actuators : ActuatorPort;
		port power : PowerPort;
	}
	
	action def MonitorVitals {
		in tempReading : ThermodynamicTemperatureValue;
		in pressureReading : PressureValue;
		in humidityReading : Real;
		out tempStatus : ThermodynamicTemperatureValue;
		out pressureStatus : PressureValue;
		out humidityStatus : Real;
		out alertLevel : AlertStatus;
	}
	
	action def RegulateTemperature {
		in targetTemp : ThermodynamicTemperatureValue;
		in currentTemp : ThermodynamicTemperatureValue;
		out heatingCmd : Real;
		out coolingCmd : Real;
	}
	
	action def ManagePressure {
		in targetPressure : PressureValue;
		in currentPressure : PressureValue;
		in timeInPosition : DurationValue;
		out pressureCmd : Real;
		out repositionNeeded : Boolean;
	}
	
	action def ControlHumidity {
		in targetHumidity : Real;
		in currentHumidity : Real;
		out humidityCmd : Real;
	}
	
	action def RepositionPatient {
		in currentAngle : Real;
		in targetAngle : Real;
		in rotationRate : Real;
		out rotationCmd : Real;
		out newAngle : Real;
	}
	
	action def AssessSkinIntegrity {
		in pressureHistory : PressureValue[*];
		in temperatureHistory : ThermodynamicTemperatureValue[*];
		in durationInPosition : DurationValue;
		out riskLevel : Real;
		out interventionRequired : Boolean;
	}
	
	action def ProvideBurnRecoveryTherapy {
		in patientData : PatientData;
		in therapyDuration : DurationValue;
		out therapyComplete : Boolean;
		
		private attribute currentTemp : ThermodynamicTemperatureValue;
		private attribute currentPressure : PressureValue;
		private attribute currentHumidity : Real;
		private attribute currentAngle : Real;
		private attribute positionTime : DurationValue;
		private attribute alertState : AlertStatus;
		
		first start;
		then merge continuousTherapy;
		
		then action monitor : MonitorVitals {
			in tempReading = currentTemp;
			in pressureReading = currentPressure;
			in humidityReading = currentHumidity;
			out tempStatus;
			out pressureStatus;
			out humidityStatus;
			out alertLevel;
		}
		
		then assign alertState := monitor.alertLevel;
		
		then decide;
			if monitor.alertLevel == AlertStatus::critical then emergencyResponse;
			if monitor.alertLevel == AlertStatus::warning then adjustTherapy;
			if monitor.alertLevel == AlertStatus::nominal then normalOperation;
		
		action emergencyResponse {
			action raiseAlarm;
			then action immediateAdjust : RegulateTemperature {
				in targetTemp : ThermodynamicTemperatureValue;
				in currentTemp = monitor.tempStatus;
				out heatingCmd;
				out coolingCmd;
			}
		}
		then normalOperation;
		
		action adjustTherapy {
			action assessSkin : AssessSkinIntegrity {
				in pressureHistory : PressureValue[*];
				in temperatureHistory : ThermodynamicTemperatureValue[*];
				in durationInPosition = positionTime;
				out riskLevel;
				out interventionRequired;
			}
			then decide;
				if assessSkin.interventionRequired then repositionAction;
				if !assessSkin.interventionRequired then normalOperation;
		}
		
		action repositionAction : RepositionPatient {
			in currentAngle = currentAngle;
			in targetAngle : Real;
			in rotationRate = 2.0;
			out rotationCmd;
			out newAngle;
		}
		then assign currentAngle := repositionAction.newAngle;
		then assign positionTime := 0.0 [SI::s];
		then normalOperation;
		
		action normalOperation {
			action tempControl : RegulateTemperature {
				in targetTemp : ThermodynamicTemperatureValue;
				in currentTemp = monitor.tempStatus;
				out heatingCmd;
				out coolingCmd;
			}
			
			action pressureControl : ManagePressure {
				in targetPressure : PressureValue;
				in currentPressure = monitor.pressureStatus;
				in timeInPosition = positionTime;
				out pressureCmd;
				out repositionNeeded;
			}
			
			action humidityControl : ControlHumidity {
				in targetHumidity : Real;
				in currentHumidity = monitor.humidityStatus;
				out humidityCmd;
			}
			
			then decide;
				if pressureControl.repositionNeeded then repositionAction;
				if !pressureControl.repositionNeeded then continuousTherapy;
		}
		
		then continuousTherapy;
		then done;
	}
	
	requirement def TherapeuticEffectiveness {
		doc /* The burn recovery bed shall provide continuous therapeutic support 
		       through integrated temperature regulation, pressure redistribution, 
		       humidity control, and automated positioning to promote healing and 
		       prevent secondary complications. */
		
		require constraint temperatureRange {
			doc /* Surface temperature shall be maintained between 30°C and 34°C 
			       with ±0.5°C accuracy to promote optimal healing conditions. */
		}
		
		require constraint pressureDistribution {
			doc /* Interface pressure shall not exceed 32 mmHg at any contact point 
			       for more than 2 hours to prevent pressure ulcers. */
		}
		
		require constraint humidityControl {
			doc /* Ambient humidity shall be maintained between 40% and 60% 
			       to prevent skin desiccation and infection. */
		}
		
		require constraint repositioningCycle {
			doc /* Automated repositioning shall occur at intervals not exceeding 
			       2 hours unless clinically contraindicated. */
		}
	}
	
	requirement def SafetyRequirements {
		doc /* The system shall operate safely without causing additional trauma, 
		       discomfort, or risk to burn patients. */
		
		require constraint emergencyStop {
			doc /* Emergency stop function shall halt all motion within 500 milliseconds 
			       and maintain life-support functions. */
		}
		
		require constraint alarmResponse {
			doc /* Critical parameter deviations shall trigger audible and visual alarms 
			       within 3 seconds of detection. */
		}
		
		require constraint powerReliability {
			doc /* Battery backup shall maintain critical therapeutic functions for 
			       minimum 60 minutes during power failure. */
		}
		
		require constraint maxRotationRate {
			doc /* Patient repositioning rate shall not exceed 5 degrees per second 
			       to prevent pain and tissue damage. */
		}
	}
	
	requirement def PrimaryMission {
		doc /* The burn recovery bed system shall facilitate optimal healing of burn 
		       injuries by providing continuous, automated therapeutic support through 
		       coordinated environmental control, pressure management, and patient 
		       positioning while ensuring safety and comfort throughout recovery. */
		
		assume constraint patientCondition {
			doc /* Patient has burn injuries requiring specialized therapeutic bed support 
			       and continuous monitoring. */
		}
		
		require therapeuticEffectiveness : TherapeuticEffectiveness;
		require safetyStandards : SafetyRequirements;
	}
	
	part def BurnRecoveryBed {
		satisfy primaryMission : PrimaryMission;
		
		port mainPower : PowerPort;
		port backupPower : PowerPort;
		
		part patient : PatientData {
			attribute :>> bodyMass = 75.0 [SI::kg];
			attribute :>> skinTemperature = 310.15 [SI::K];
			attribute :>> contactPressure = 25000.0 [SI::Pa];
			attribute :>> timeInPosition = 0.0 [SI::s];
		}
		
		part temperatureSystem : TemperatureControlSystem {
			attribute :>> currentTemp = 305.15 [SI::K];
			attribute :>> targetTemp = 303.15 [SI::K];
			
			perform action maintainTemperature {
				loop {
					action regulate : RegulateTemperature;
				}
			}
		}
		
		part pressureSystem : PressureReliefSystem {
			attribute :>> currentPressure = 28000.0 [SI::Pa];
			attribute :>> targetPressure = 20000.0 [SI::Pa];
			attribute :>> redistributionCycle = 7200.0 [SI::s];
			
			perform action managePressure {
				loop {
					action adjust : ManagePressure;
				}
			}
		}
		
		part positioningSystem : PositioningSystem {
			attribute :>> currentAngle = 0.0;
			attribute :>> targetAngle = 30.0;
			attribute :>> rotationRate = 2.0;
			
			perform action repositionPatient {
				action rotate : RepositionPatient;
			}
		}
		
		part humiditySystem : HumidityControlSystem {
			attribute :>> currentHumidity = 45.0;
			attribute :>> targetHumidity = 50.0;
			
			perform action controlHumidity {
				loop {
					action adjust : ControlHumidity;
				}
			}
		}
		
		part monitoringSystem : MonitoringSystem {
			attribute :>> tempReadings : ThermodynamicTemperatureValue[*];
			attribute :>> pressureReadings : PressureValue[*];
			attribute :>> humidityReadings : Real[*];
			attribute :>> positionReadings : Real[*];
			
			perform action continuousMonitoring {
				loop {
					action monitor : MonitorVitals;
				}
			}
		}
		
		part controlUnit : ControlUnit {
			attribute :>> operatingMode = "automatic";
			attribute :>> therapyCycle = 7200.0 [SI::s];
			
			perform action orchestrateTherapy : ProvideBurnRecoveryTherapy {
				in patientData = patient;
				in therapyDuration = therapyCycle;
				out therapyComplete;
			}
		}
		
		connect mainPower to temperatureSystem.power;
		connect mainPower to pressureSystem.power;
		connect mainPower to positioningSystem.power;
		connect mainPower to humiditySystem.power;
		connect mainPower to controlUnit.power;
		
		connect controlUnit.systemControl to monitoringSystem.alarms;
		connect controlUnit.actuators to temperatureSystem.control;
		connect controlUnit.actuators to pressureSystem.control;
		connect controlUnit.actuators to positioningSystem.control;
		connect controlUnit.actuators to humiditySystem.control;
		
		connect temperatureSystem.sensing to monitoringSystem.sensors;
		connect pressureSystem.sensing to monitoringSystem.sensors;
		connect positioningSystem.sensing to monitoringSystem.sensors;
		connect humiditySystem.sensing to monitoringSystem.sensors;
	}
}
