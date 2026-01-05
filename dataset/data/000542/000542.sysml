package 'Bair Hugger Forced Air Warming System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> TemperatureValue;
	attribute def AirFlowRate :> VolumeFlowRateValue;
	attribute def HeaterPowerLevel :> PowerValue;
	attribute def PatientTemperature :> TemperatureValue;
	attribute def BlowerSpeed :> Real;
	attribute def FilterStatus;
	attribute def AlarmCode;
	
	value def TemperatureRange {
		attribute min : TemperatureValue;
		attribute max : TemperatureValue;
	}
	
	value def SafetyLimits {
		attribute maxAirTemp : TemperatureValue;
		attribute minAirTemp : TemperatureValue;
		attribute maxPower : PowerValue;
	}
	
	item def AmbientAir;
	item def FilteredAir;
	item def HeatedAir {
		attribute temperature : TemperatureValue;
		attribute flowRate : AirFlowRate;
	}
	item def ElectricalPower;
	
	part def AirFilter {
		port airIn;
		port airOut;
		attribute filterEfficiency : Real;
		attribute filterLife : TimeValue;
	}
	
	part def Blower {
		port powerIn;
		port airIn;
		port airOut;
		port speedControl;
		attribute currentSpeed : BlowerSpeed;
		attribute maxFlowRate : AirFlowRate;
	}
	
	part def HeatingElement {
		port powerIn;
		port airIn;
		port airOut;
		port powerControl;
		attribute currentPower : HeaterPowerLevel;
		attribute maxPower : PowerValue;
		attribute targetTemp : TemperatureSetpoint;
	}
	
	part def TemperatureSensor {
		port sensingPoint;
		port dataOut;
		attribute measuredTemp : PatientTemperature;
		attribute accuracy : TemperatureValue;
		attribute responseTime : TimeValue;
	}
	
	part def ControlModule {
		port tempSensorIn;
		port userInput;
		port heaterControl;
		port blowerControl;
		port alarmOut;
		port displayOut;
		attribute setpoint : TemperatureSetpoint;
		attribute currentMode : String;
		attribute alarmStatus : AlarmCode;
	}
	
	part def WarmingBlanket {
		port airInlet;
		attribute blanketType : String;
		attribute coverageArea : Real;
		attribute perforationPattern : String;
	}
	
	part def UserInterface {
		port controlPanel;
		port display;
		attribute selectedTemp : TemperatureSetpoint;
		attribute displayedTemp : PatientTemperature;
		attribute operatingMode : String;
	}
	
	part def PowerSupply {
		port acInput;
		port dcOutput1;
		port dcOutput2;
		port dcOutput3;
		attribute inputVoltage : ISQ::ElectricPotentialValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute powerRating : PowerValue;
	}
	
	part def SafetyMonitor {
		port tempMonitor;
		port powerMonitor;
		port systemShutdown;
		attribute overTempThreshold : TemperatureValue;
		attribute underTempThreshold : TemperatureValue;
		attribute shutdownDelay : TimeValue;
	}
	
	part def AirDeliveryHose {
		port hoseInlet;
		port hoseOutlet;
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		attribute thermalLoss : TemperatureValue;
	}
	
	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def StartWarmingSignal;
	attribute def StopWarmingSignal;
	attribute def StandbySignal;
	attribute def AlarmClearedSignal;
	
	action def MonitorPatientTemperature {
		in currentTemp : PatientTemperature;
		in targetTemp : TemperatureSetpoint;
		in hysteresis : TemperatureValue;
		out tempError : TemperatureValue;
		out needsHeating : Boolean;
	}
	
	action def AdjustHeaterPower {
		in tempError : TemperatureValue;
		in currentPower : HeaterPowerLevel;
		in maxPower : PowerValue;
		out newPower : HeaterPowerLevel;
	}
	
	action def RegulateAirFlow {
		in targetFlow : AirFlowRate;
		in currentSpeed : BlowerSpeed;
		in maxSpeed : Real;
		out newSpeed : BlowerSpeed;
	}
	
	action def CheckSafetyConditions {
		in measuredTemp : PatientTemperature;
		in airTemp : TemperatureValue;
		in powerLevel : HeaterPowerLevel;
		in safetyLimits : SafetyLimits;
		out alarmCondition : AlarmCode;
		out shutdownRequired : Boolean;
	}
	
	action def WarmPatient {
		in patientTemp : PatientTemperature;
		in targetTemp : TemperatureSetpoint;
		in flowRate : AirFlowRate;
		out heaterPower : HeaterPowerLevel;
		out blowerSpeed : BlowerSpeed;
		
		first start;
		then merge warmingLoop;
		
		then action monitor : MonitorPatientTemperature {
			in currentTemp = patientTemp;
			in targetTemp = targetTemp;
			in hysteresis = 0.5 [SI::K];
			out tempError;
			out needsHeating;
		}
		
		then action safetyCheck : CheckSafetyConditions {
			in measuredTemp = patientTemp;
			in airTemp;
			in powerLevel;
			in safetyLimits;
			out alarmCondition;
			out shutdownRequired;
		}
		
		then decide;
			if safetyCheck.shutdownRequired then emergencyStop;
			if not safetyCheck.shutdownRequired and monitor.needsHeating then adjustControls;
			if not safetyCheck.shutdownRequired and not monitor.needsHeating then maintainControls;
		
		action adjustControls {
			action adjustHeater : AdjustHeaterPower {
				in tempError = monitor.tempError;
				in currentPower;
				in maxPower = 1500.0 [SI::W];
				out newPower;
			}
			then action adjustFlow : RegulateAirFlow {
				in targetFlow = flowRate;
				in currentSpeed;
				in maxSpeed = 100.0;
				out newSpeed;
			}
		}
		then warmingLoop;
		
		action maintainControls;
		then warmingLoop;
		
		action emergencyStop;
		then done;
	}
	
	state def SystemOperatingStates {
		entry; then powerOff;
		
		state powerOff {
			entry action disableAllSystems;
		}
		
		transition powerOff_to_standby
			first powerOff
			accept powerOnEvt : PowerOnSignal
			then standby;
		
		state standby {
			entry action initializeSystems;
			do action performSelfTest;
		}
		
		transition standby_to_ready
			first standby
			then ready;
		
		state ready {
			entry action displayReadyStatus;
		}
		
		transition ready_to_warming
			first ready
			accept startWarmingEvt : StartWarmingSignal
			then warming;
		
		state warming {
			entry action beginWarmingSequence;
			do action maintainTemperature : WarmPatient;
			
			state normalOperation {
				entry action setNormalMode;
			}
			
			state temperatureAdjusting {
				entry action adjustParameters;
			}
			
			state alarmActive {
				entry action activateAlarm;
				do action monitorAlarmCondition;
			}
			
			transition normal_to_adjusting
				first normalOperation
				then temperatureAdjusting;
			
			transition adjusting_to_normal
				first temperatureAdjusting
				then normalOperation;
			
			transition to_alarm
				first normalOperation
				then alarmActive;
			
			transition alarm_to_normal
				first alarmActive
				accept alarmClearedEvt : AlarmClearedSignal
				then normalOperation;
		}
		
		transition warming_to_ready
			first warming
			accept stopWarmingEvt : StopWarmingSignal
			then ready;
		
		transition ready_to_standby
			first ready
			accept standbyEvt : StandbySignal
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept powerOffEvt : PowerOffSignal
			then powerOff;
		
		transition emergency_shutdown
			first warming
			then powerOff;
	}
	
	part bairHuggerSystem : BairHuggerWarmer {
		doc /*
		The Bair Hugger forced-air warming system prevents and treats perioperative 
		hypothermia by delivering temperature-controlled warm air through a specialized 
		disposable blanket positioned over the patient. The system continuously monitors 
		patient temperature and automatically adjusts heating power and airflow to 
		maintain normothermia throughout surgical procedures.
		*/
		
		part airFilter : AirFilter {
			attribute :>> filterEfficiency = 0.99;
			attribute :>> filterLife = 500.0 [SI::h];
		}
		
		part blower : Blower {
			attribute :>> maxFlowRate = 28.0 [SI::L/SI::s];
			attribute :>> currentSpeed = 0.0;
		}
		
		part heatingElement : HeatingElement {
			attribute :>> maxPower = 1500.0 [SI::W];
			attribute :>> targetTemp = 311.15 [SI::K];
			attribute :>> currentPower = 0.0 [SI::W];
		}
		
		part airTempSensor : TemperatureSensor {
			attribute :>> accuracy = 0.1 [SI::K];
			attribute :>> responseTime = 1.0 [SI::s];
		}
		
		part patientTempSensor : TemperatureSensor {
			attribute :>> accuracy = 0.2 [SI::K];
			attribute :>> responseTime = 5.0 [SI::s];
		}
		
		part controller : ControlModule {
			attribute :>> setpoint = 310.15 [SI::K];
			attribute :>> currentMode = "standby";
			perform action warmingControl : WarmPatient;
		}
		
		part deliveryHose : AirDeliveryHose {
			attribute :>> length = 2.5 [SI::m];
			attribute :>> diameter = 0.05 [SI::m];
			attribute :>> thermalLoss = 1.5 [SI::K];
		}
		
		part blanket : WarmingBlanket {
			attribute :>> blanketType = "upper body";
			attribute :>> coverageArea = 0.6;
			attribute :>> perforationPattern = "distributed";
		}
		
		part userPanel : UserInterface {
			attribute :>> selectedTemp = 310.15 [SI::K];
			attribute :>> operatingMode = "normal";
		}
		
		part powerSupply : PowerSupply {
			attribute :>> inputVoltage = 120.0 [SI::V];
			attribute :>> outputVoltage = 24.0 [SI::V];
			attribute :>> powerRating = 1800.0 [SI::W];
		}
		
		part safetyMonitor : SafetyMonitor {
			attribute :>> overTempThreshold = 316.15 [SI::K];
			attribute :>> underTempThreshold = 305.15 [SI::K];
			attribute :>> shutdownDelay = 2.0 [SI::s];
		}
		
		connection airPath1 connect airFilter.airOut to blower.airIn;
		connection airPath2 connect blower.airOut to heatingElement.airIn;
		connection airPath3 connect heatingElement.airOut to deliveryHose.hoseInlet;
		connection airPath4 connect deliveryHose.hoseOutlet to blanket.airInlet;
		
		connection powerToBlower connect powerSupply.dcOutput1 to blower.powerIn;
		connection powerToHeater connect powerSupply.dcOutput2 to heatingElement.powerIn;
		
		connection heaterControl connect controller.heaterControl to heatingElement.powerControl;
		connection blowerControl connect controller.blowerControl to blower.speedControl;
		
		connection airTempMonitoring connect airTempSensor.dataOut to controller.tempSensorIn;
		connection patientTempMonitoring connect patientTempSensor.dataOut to controller.tempSensorIn;
		
		connection userControl connect userPanel.controlPanel to controller.userInput;
		connection displayControl connect controller.displayOut to userPanel.display;
		
		connection safetyTempMonitor connect airTempSensor.dataOut to safetyMonitor.tempMonitor;
		connection safetyPowerMonitor connect heatingElement.powerControl to safetyMonitor.powerMonitor;
		connection safetyShutdown connect safetyMonitor.systemShutdown to controller.alarmOut;
		
		perform action systemOperation : SystemOperatingStates;
	}
	
	part def BairHuggerWarmer;
	
	requirement <'REQ-001'> maintainNormothermia {
		doc /*
		The system shall maintain patient core body temperature between 36.0 degrees C 
		and 37.5 degrees C during surgical procedures to prevent perioperative hypothermia.
		*/
		attribute tempRange : TemperatureRange {
			attribute :>> min = 309.15 [SI::K];
			attribute :>> max = 310.65 [SI::K];
		}
	}
	
	requirement <'REQ-002'> safeAirTemperature {
		doc /*
		The system shall not deliver air exceeding 43.0 degrees C at the blanket inlet 
		to prevent patient thermal injury.
		*/
		attribute maxTemp : TemperatureValue = 316.15 [SI::K];
	}
	
	requirement <'REQ-003'> adjustableAirFlow {
		doc /*
		The system shall provide adjustable air flow between 8 L/s and 28 L/s 
		to accommodate different blanket types and patient requirements.
		*/
		attribute minFlow : AirFlowRate = 8.0 [SI::L/SI::s];
		attribute maxFlow : AirFlowRate = 28.0 [SI::L/SI::s];
	}
	
	requirement <'REQ-004'> temperatureSensingAccuracy {
		doc /*
		Temperature sensing shall be accurate to within plus or minus 0.2 degrees C across the 
		operating range of 32 degrees C to 43 degrees C.
		*/
		attribute sensorAccuracy : TemperatureValue = 0.2 [SI::K];
	}
	
	requirement <'REQ-005'> automaticSafetyShutdown {
		doc /*
		The system shall automatically shut down heating within 2 seconds 
		if air temperature exceeds 43 degrees C or critical system faults are detected.
		*/
		attribute shutdownTime : TimeValue = 2.0 [SI::s];
	}
	
	requirement <'REQ-006'> continuousMonitoring {
		doc /*
		The system shall continuously monitor patient and air temperatures 
		with measurement updates at least every 5 seconds during operation.
		*/
		attribute updateInterval : TimeValue = 5.0 [SI::s];
	}
	
	requirement <'REQ-007'> filterEfficiency {
		doc /*
		The air filtration system shall remove at least 99 percent of particulates 
		larger than 0.3 microns to ensure clean air delivery.
		*/
		attribute efficiency : Real = 0.99;
	}
	
	requirement systemRequirements {
		doc /*
		Top-level requirements for the Bair Hugger forced-air warming system 
		ensuring safe and effective patient temperature management.
		*/
		require maintainNormothermia;
		require safeAirTemperature;
		require adjustableAirFlow;
		require temperatureSensingAccuracy;
		require automaticSafetyShutdown;
		require continuousMonitoring;
		require filterEfficiency;
	}
}
