package PneumoniaJacketSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BodyTemperature :> TemperatureValue;
	attribute def ChestExpansion :> LengthValue;
	attribute def RespirationRate :> FrequencyValue;
	attribute def ChamberPressure :> PressureValue;
	attribute def FluidTemperature :> TemperatureValue;
	attribute def BatteryCharge :> Real;
	
	item def VitalSignData {
		attribute bodyTemp : BodyTemperature;
		attribute chestExpansion : ChestExpansion;
		attribute respirationRate : RespirationRate;
		attribute timestamp : Real;
	}
	
	item def TherapyCommand {
		attribute targetPressure : ChamberPressure;
		attribute coolingRate : PowerValue;
		attribute duration : TimeValue;
	}
	
	item def AlertMessage {
		attribute severity : Integer;
		attribute description : String;
		attribute vitalData : VitalSignData;
	}
	
	port def VitalSensorPort {
		out vitalData : VitalSignData;
	}
	
	port def TherapyActuatorPort {
		in therapyCmd : TherapyCommand;
	}
	
	port def AlertPort {
		out alert : AlertMessage;
	}
	
	part def TemperatureSensor {
		port sensorOut : VitalSensorPort;
		attribute currentTemp : BodyTemperature;
		attribute sensorAccuracy : TemperatureValue;
	}
	
	part def ExpansionSensor {
		port sensorOut : VitalSensorPort;
		attribute currentExpansion : ChestExpansion;
		attribute calibrationOffset : LengthValue;
	}
	
	part def PneumaticChamber {
		port actuatorIn : TherapyActuatorPort;
		attribute currentPressure : ChamberPressure;
		attribute maxPressure : ChamberPressure;
		attribute chamberVolume : VolumeValue;
		attribute chamberID : Integer;
	}
	
	part def CoolingModule {
		port actuatorIn : TherapyActuatorPort;
		attribute fluidTemp : FluidTemperature;
		attribute flowRate : VolumeFlowRateValue;
		attribute reservoirCapacity : VolumeValue;
	}
	
	part def PowerSupply {
		attribute batteryCapacity : EnergyValue;
		attribute currentCharge : BatteryCharge;
		attribute outputVoltage : Real;
	}
	
	part def TherapyController {
		in port tempInput : VitalSensorPort;
		in port expansionInput : VitalSensorPort;
		out port pneumaticOutput : TherapyActuatorPort;
		out port coolingOutput : TherapyActuatorPort;
		out port alertOutput : AlertPort;
		
		attribute normalBodyTemp : BodyTemperature;
		attribute feverThreshold : BodyTemperature;
		attribute normalRespRate : RespirationRate;
		attribute abnormalRespRate : RespirationRate;
		attribute therapyPressure : ChamberPressure;
		attribute coolingPower : PowerValue;
	}
	
	part def Patient {
		attribute bodyTemperature : BodyTemperature;
		attribute chestCircumference : LengthValue;
		attribute respirationRate : RespirationRate;
		attribute oxygenSaturation : Real;
		attribute hasPneumonia : Boolean;
	}
	
	action def MeasureVitals {
		in patient : Patient;
		out vitals : VitalSignData;
	}
	
	action def AnalyzeVitals {
		in vitals : VitalSignData;
		in feverThreshold : BodyTemperature;
		in abnormalRespRate : RespirationRate;
		out requiresTherapy : Boolean;
		out requiresCooling : Boolean;
		out requiresAlert : Boolean;
	}
	
	action def ApplyPneumaticTherapy {
		in targetPressure : ChamberPressure;
		in duration : TimeValue;
		in chamberID : Integer;
		out therapyApplied : Boolean;
	}
	
	action def ApplyCooling {
		in coolingPower : PowerValue;
		in targetTemp : BodyTemperature;
		out coolingActive : Boolean;
	}
	
	action def GenerateAlert {
		in vitals : VitalSignData;
		in severity : Integer;
		out alert : AlertMessage;
	}
	
	action def MonitorAndTreat {
		in patient : Patient;
		in feverThreshold : BodyTemperature;
		in abnormalRespRate : RespirationRate;
		in therapyPressure : ChamberPressure;
		in coolingPower : PowerValue;
		out alertGenerated : AlertMessage;
		
		first start;
		then merge monitoringCycle;
		
		then action measureVitals : MeasureVitals {
			in patient = patient;
			out vitals : VitalSignData;
		}
		
		then action analyzeVitals : AnalyzeVitals {
			in vitals = measureVitals.vitals;
			in feverThreshold = feverThreshold;
			in abnormalRespRate = abnormalRespRate;
			out requiresTherapy : Boolean;
			out requiresCooling : Boolean;
			out requiresAlert : Boolean;
		}
		
		then decide;
			if analyzeVitals.requiresTherapy then applyTherapy;
			if analyzeVitals.requiresCooling then applyCoolingStep;
			if analyzeVitals.requiresAlert then generateAlertStep;
			if not analyzeVitals.requiresTherapy and not analyzeVitals.requiresCooling then continueMonitoringStep;
		
		action applyTherapy {
			action pneumaticTherapy : ApplyPneumaticTherapy {
				in targetPressure = therapyPressure;
				in duration = 120.0 [SI::s];
				in chamberID = 1;
				out therapyApplied : Boolean;
			}
			then merge therapyComplete;
		}
		
		action applyCoolingStep {
			action cooling : ApplyCooling {
				in coolingPower = coolingPower;
				in targetTemp = 37.0 [SI::'°C'];
				out coolingActive : Boolean;
			}
			then merge therapyComplete;
		}
		
		action generateAlertStep {
			action alert : GenerateAlert {
				in vitals = measureVitals.vitals;
				in severity = 2;
				out alert : AlertMessage;
			}
			then assign alertGenerated := alert.alert;
			then merge therapyComplete;
		}
		
		action continueMonitoringStep;
		then merge therapyComplete;
		
		merge therapyComplete;
		then monitoringCycle;
		
		action endMonitoring;
		then done;
	}
	
	state def JacketOperationalStates {
		entry; then standby;
		
		state standby {
			entry assign operationalMode = "Standby";
		}
		
		transition standby_to_monitoring
			first standby
			accept StartMonitoringCommand
			then monitoring;
		
		state monitoring {
			entry assign operationalMode = "Monitoring";
			do action continuousMonitoring : MeasureVitals;
		}
		
		transition monitoring_to_activeTherapy
			first monitoring
			if continuousMonitoring.vitals.bodyTemp > criticalTemp or 
			   continuousMonitoring.vitals.respirationRate > criticalRespRate
			then activeTherapy;
		
		state activeTherapy {
			entry assign operationalMode = "Active Therapy";
			
			state parallel therapyModes {
				state pneumaticCompression {
					do action compression : ApplyPneumaticTherapy;
				}
				state thermalRegulation {
					do action cooling : ApplyCooling;
				}
			}
		}
		
		transition activeTherapy_to_monitoring
			first activeTherapy
			if vitalsNormalized
			then monitoring;
		
		transition monitoring_to_standby
			first monitoring
			accept StopMonitoringCommand
			then standby;
		
		state emergency {
			entry assign operationalMode = "Emergency";
			do action emergencyAlert : GenerateAlert;
		}
		
		transition any_to_emergency
			first monitoring or activeTherapy
			if criticalConditionDetected
			then emergency;
		
		transition emergency_to_standby
			first emergency
			accept ResetCommand
			then standby;
		
		attribute operationalMode : String;
		attribute criticalTemp : BodyTemperature;
		attribute criticalRespRate : RespirationRate;
		attribute vitalsNormalized : Boolean;
		attribute criticalConditionDetected : Boolean;
	}
	
	part def PneumoniaJacket {
		doc /* 
		The Pneumonia Jacket is a wearable therapeutic device designed to assist in the treatment 
		of pneumonia patients, particularly pediatric cases. The system continuously monitors vital 
		signs including body temperature, chest expansion, and respiration rate. When abnormal 
		conditions are detected, it automatically applies intermittent pneumatic compression to 
		improve lung function and circulation, while providing active cooling to reduce fever. 
		The jacket integrates multiple sensors, pneumatic chambers, and a cooling system, all 
		coordinated by an intelligent controller that adapts therapy based on real-time patient data.
		*/
		
		part tempSensors : TemperatureSensor[4];
		part expansionSensors : ExpansionSensor[6];
		part pneumaticChambers : PneumaticChamber[8];
		part coolingModule : CoolingModule;
		part controller : TherapyController;
		part battery : PowerSupply;
		
		ref part treatedPatient : Patient;
		
		perform action treatmentAction : MonitorAndTreat {
			in patient = treatedPatient;
			in feverThreshold = 38.5 [SI::'°C'];
			in abnormalRespRate = 30.0 [SI::Hz];
			in therapyPressure = 40.0 [SI::Pa];
			in coolingPower = 50.0 [SI::W];
			out alertGenerated : AlertMessage;
		}
		
		perform statemachine operationalSM : JacketOperationalStates {
			criticalTemp = 39.5 [SI::'°C'];
			criticalRespRate = 40.0 [SI::Hz];
		}
		
		connection tempSensorConnection
			connect tempSensors.sensorOut to controller.tempInput;
		
		connection expansionSensorConnection
			connect expansionSensors.sensorOut to controller.expansionInput;
		
		connection pneumaticControlConnection
			connect controller.pneumaticOutput to pneumaticChambers.actuatorIn;
		
		connection coolingControlConnection
			connect controller.coolingOutput to coolingModule.actuatorIn;
	}
	
	requirement def TherapeuticEffectivenessRequirement {
		doc /* 
		The pneumonia jacket shall effectively reduce fever and improve respiratory function 
		through coordinated pneumatic compression and active cooling therapy.
		*/
		
		subject jacket : PneumoniaJacket;
		
		require constraint temperatureReduction {
			doc /* Body temperature shall be reduced by at least 1.0°C within 20 minutes of therapy initiation. */
		}
		
		require constraint respirationImprovement {
			doc /* Respiration rate shall normalize to within 20% of baseline within 30 minutes. */
		}
		
		require constraint therapyDuration {
			doc /* Each therapy cycle shall last between 2 and 5 minutes with appropriate rest periods. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* 
		The pneumonia jacket shall operate within safe limits to prevent patient harm 
		or discomfort during therapy.
		*/
		
		subject jacket : PneumoniaJacket;
		
		require constraint maxPressureLimit {
			doc /* Pneumatic chamber pressure shall not exceed 60 mmHg (8 kPa). */
			jacket.pneumaticChambers.currentPressure <= 8000.0 [SI::Pa]
		}
		
		require constraint minCoolingTemp {
			doc /* Cooling fluid temperature shall not fall below 18°C. */
			jacket.coolingModule.fluidTemp >= 18.0 [SI::'°C']
		}
		
		require constraint batteryMonitoring {
			doc /* System shall alert when battery charge falls below 20%. */
			jacket.battery.currentCharge >= 0.20
		}
	}
	
	requirement def ComfortRequirement {
		doc /* 
		The pneumonia jacket shall maintain patient comfort throughout therapy sessions.
		*/
		
		subject jacket : PneumoniaJacket;
		
		require constraint uniformPressureDistribution {
			doc /* Pressure variation across chambers shall not exceed 15%. */
		}
		
		require constraint gradualPressureChange {
			doc /* Pressure inflation and deflation rates shall not exceed 10 mmHg per second. */
		}
		
		require constraint temperatureGradient {
			doc /* Temperature differential across cooling zones shall not exceed 3°C. */
		}
	}
	
	requirement def MonitoringRequirement {
		doc /* 
		The pneumonia jacket shall continuously monitor patient vital signs with 
		appropriate accuracy and response time.
		*/
		
		subject jacket : PneumoniaJacket;
		
		require constraint temperatureAccuracy {
			doc /* Temperature measurement accuracy shall be ±0.2°C. */
		}
		
		require constraint samplingRate {
			doc /* Vital signs shall be sampled at minimum 1 Hz frequency. */
		}
		
		require constraint responseTime {
			doc /* System shall respond to abnormal vitals within 2 seconds. */
		}
	}
	
	requirement <'PJ-SYS-001'> primarySystemRequirement {
		doc /* 
		The Pneumonia Jacket System shall provide automated, continuous monitoring and 
		therapeutic intervention for pneumonia patients by integrating vital sign monitoring, 
		intermittent pneumatic compression, and active thermal regulation to reduce fever, 
		improve respiratory function, and enhance patient comfort during treatment.
		*/
		
		assume constraint patientCondition {
			doc /* Patient has confirmed pneumonia diagnosis with elevated temperature and respiratory distress. */
		}
		
		assume constraint properFitting {
			doc /* Jacket is properly fitted to patient with all sensors and chambers in correct position. */
		}
		
		require therapeuticEffectiveness : TherapeuticEffectivenessRequirement;
		require safety : SafetyRequirement;
		require comfort : ComfortRequirement;
		require monitoring : MonitoringRequirement;
	}
	
	occurrence def PneumoniaTherapySession {
		ref part patient : Patient;
		ref part jacket : PneumoniaJacket;
		
		message vitalSignsMessage of VitalSignData
			from jacket.tempSensors.sensorOut to jacket.controller.tempInput;
		
		then message expansionDataMessage of VitalSignData
			from jacket.expansionSensors.sensorOut to jacket.controller.expansionInput;
		
		then message therapyCommandMessage of therapyCmd : TherapyCommand
			from jacket.controller.pneumaticOutput to jacket.pneumaticChambers.actuatorIn;
		
		then message coolingCommandMessage of coolingCmd : TherapyCommand
			from jacket.controller.coolingOutput to jacket.coolingModule.actuatorIn;
		
		then message alertNotificationMessage of alert : AlertMessage
			from jacket.controller.alertOutput to externalMonitoringSystem;
		
		ref part externalMonitoringSystem;
	}
}
