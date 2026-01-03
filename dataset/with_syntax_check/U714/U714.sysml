package 'Hydrogen Sulfide Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def ConcentrationUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered {
			[1] {
				attribute :>> unit = SI::mol;
				attribute :>> exponent = 1.0;
			}
			[2] {
				attribute :>> unit = SI::m;
				attribute :>> exponent = -3.0;
			}
		}
	}
	
	attribute def ConcentrationValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ConcentrationUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::VoltageUnit;
	}
	
	attribute def TemperatureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::TemperatureUnit;
	}
	
	attribute def TimeValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::TimeUnit;
	}
	
	item def GasSample {
		attribute h2sConcentration : ConcentrationValue;
		attribute temperature : TemperatureValue;
		attribute humidity : Real;
		attribute pressure : Real;
	}
	
	item def SensorReading {
		attribute measuredConcentration : ConcentrationValue;
		attribute sensorVoltage : VoltageValue;
		attribute timestamp : TimeValue;
		attribute sensorTemperature : TemperatureValue;
		attribute isValid : Boolean;
	}
	
	item def AlarmSignal {
		attribute alarmLevel : Integer;
		attribute thresholdExceeded : ConcentrationValue;
		attribute alarmMessage : String;
	}
	
	port def GasInputPort {
		in item sample : GasSample;
	}
	
	port def ReadingOutputPort {
		out item reading : SensorReading;
	}
	
	port def AlarmPort {
		out item alarm : AlarmSignal;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	part def ElectrochemicalCell {
		attribute sensitivity : Real;
		attribute baselineVoltage : VoltageValue;
		attribute operatingTemp : TemperatureValue;
		
		port gasExposure : GasInputPort;
		port voltageOutput : ReadingOutputPort;
		
		action generateSignal {
			in item gasSample : GasSample;
			out attribute outputVoltage : VoltageValue;
		}
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute bandwidth : Real;
		
		action amplify {
			in attribute inputSignal : VoltageValue;
			out attribute amplifiedSignal : VoltageValue;
		}
	}
	
	part def AnalogDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : VoltageValue;
		
		action convert {
			in attribute analogInput : VoltageValue;
			out attribute digitalOutput : Integer;
		}
	}
	
	part def Microprocessor {
		attribute calibrationSlope : Real;
		attribute calibrationIntercept : Real;
		attribute lowAlarmThreshold : ConcentrationValue;
		attribute highAlarmThreshold : ConcentrationValue;
		
		action calibrate {
			in attribute rawValue : Integer;
			in attribute temperature : TemperatureValue;
			out attribute concentration : ConcentrationValue;
		}
		
		action evaluateAlarm {
			in attribute concentration : ConcentrationValue;
			out item alarmSignal : AlarmSignal;
		}
		
		action processReading {
			in attribute digitalValue : Integer;
			in attribute temp : TemperatureValue;
			out item finalReading : SensorReading;
			out item alarm : AlarmSignal;
		}
	}
	
	part def TemperatureCompensator {
		attribute compensationFactor : Real;
		
		action measureTemperature {
			out attribute temperature : TemperatureValue;
		}
		
		action compensate {
			in attribute rawConcentration : ConcentrationValue;
			in attribute temperature : TemperatureValue;
			out attribute compensatedConcentration : ConcentrationValue;
		}
	}
	
	part def PowerRegulator {
		attribute inputVoltageMin : VoltageValue;
		attribute inputVoltageMax : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
		
		action regulate {
			in attribute inputV : VoltageValue;
			out attribute regulatedV : VoltageValue;
		}
	}
	
	part def H2SSensingUnit {
		attribute sensorID : String;
		attribute measurementRangeMin : ConcentrationValue;
		attribute measurementRangeMax : ConcentrationValue;
		attribute responseTime : TimeValue;
		attribute accuracy : Real;
		attribute operatingLifetime : TimeValue;
		
		port gasIntake : GasInputPort;
		port dataOutput : ReadingOutputPort;
		port alarmOutput : AlarmPort;
		port powerInput : PowerPort;
		
		part sensingCell : ElectrochemicalCell {
			attribute :>> sensitivity = 0.45;
		}
		
		part amplifier : SignalAmplifier {
			attribute :>> gain = 150.0;
			attribute :>> bandwidth = 100.0;
		}
		
		part adc : AnalogDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
		}
		
		part processor : Microprocessor {
			attribute :>> calibrationSlope = 0.05;
			attribute :>> calibrationIntercept = 0.0;
		}
		
		part tempCompensator : TemperatureCompensator {
			attribute :>> compensationFactor = 0.02;
		}
		
		part powerReg : PowerRegulator {
			attribute :>> efficiency = 0.85;
		}
		
		connect powerInput to powerReg.regulate.inputV;
		connect gasIntake to sensingCell.gasExposure;
		
		state machine OperationalStates {
			initial state Initialization;
			state Idle;
			state Measuring;
			state Alarming;
			state Fault;
			
			transition first accept at Initialization then Idle;
			transition accept at Idle then Measuring;
			transition accept at Measuring then Idle;
			transition accept at Measuring then Alarming;
			transition accept at Alarming then Measuring;
			transition accept at Measuring then Fault;
			transition accept at Fault then Initialization;
		}
	}
	
	action def MeasurementCycle {
		in item gasSample : GasSample;
		out item sensorReading : SensorReading;
		out item alarmSignal : AlarmSignal;
		
		action exposeGas {
			in item sample : GasSample;
			out attribute rawVoltage : VoltageValue;
		}
		
		then action amplifySignal {
			in attribute inputVoltage : VoltageValue;
			out attribute amplifiedVoltage : VoltageValue;
		}
		
		then action digitizeSignal {
			in attribute analogVoltage : VoltageValue;
			out attribute digitalValue : Integer;
		}
		
		then fork;
		
		then action measureTemp {
			out attribute temperature : TemperatureValue;
		}
		
		then joinNode;
		
		then action calibrateReading {
			in attribute digitalVal : Integer;
			in attribute temperature : TemperatureValue;
			out attribute rawConcentration : ConcentrationValue;
		}
		
		then joinNode;
		
		join joinNode;
		
		then action compensateTemperature {
			in attribute rawConcentration : ConcentrationValue;
			in attribute temperature : TemperatureValue;
			out attribute compensatedConcentration : ConcentrationValue;
		}
		
		then action checkAlarms {
			in attribute concentration : ConcentrationValue;
			out item alarm : AlarmSignal;
		}
		
		then action formatOutput {
			in attribute concentration : ConcentrationValue;
			in attribute voltage : VoltageValue;
			in attribute temperature : TemperatureValue;
			in item alarm : AlarmSignal;
			out item reading : SensorReading;
		}
		
		flow from exposeGas.rawVoltage to amplifySignal.inputVoltage;
		flow from amplifySignal.amplifiedVoltage to digitizeSignal.analogVoltage;
		flow from digitizeSignal.digitalValue to calibrateReading.digitalVal;
		flow from measureTemp.temperature to calibrateReading.temperature;
		flow from calibrateReading.rawConcentration to compensateTemperature.rawConcentration;
		flow from measureTemp.temperature to compensateTemperature.temperature;
		flow from compensateTemperature.compensatedConcentration to checkAlarms.concentration;
		flow from compensateTemperature.compensatedConcentration to formatOutput.concentration;
		flow from amplifySignal.amplifiedVoltage to formatOutput.voltage;
		flow from measureTemp.temperature to formatOutput.temperature;
		flow from checkAlarms.alarm to formatOutput.alarm;
		flow from formatOutput.reading to sensorReading;
		flow from checkAlarms.alarm to alarmSignal;
	}
	
	part sensingUnit : H2SSensingUnit {
		attribute :>> sensorID = "H2S-SU-001";
		attribute :>> responseTime = 30.0[SI::s];
		attribute :>> accuracy = 0.02;
		attribute :>> operatingLifetime = 31536000.0[SI::s];
		
		perform action measurementOperation : MeasurementCycle;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The H2S sensing unit shall measure hydrogen sulfide concentrations 
		       from 0 to 500 ppm with an accuracy of ±2%. */
		
		subject unit : H2SSensingUnit;
		
		require constraint accuracyConstraint {
			unit.accuracy <= 0.02
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide a valid reading within 30 seconds 
		       of exposure to hydrogen sulfide gas. */
		
		subject unit : H2SSensingUnit;
		
		require constraint responseConstraint {
			unit.responseTime.num <= 30.0
		}
	}
	
	requirement def OperationalLifetimeRequirement {
		doc /* The sensing unit shall maintain specified performance for at least 
		       one year of continuous operation. */
		
		subject unit : H2SSensingUnit;
		
		require constraint lifetimeConstraint {
			unit.operatingLifetime.num >= 31536000.0
		}
	}
	
	requirement sensingUnitRequirements {
		subject sensingUnit;
		
		require rangeReq : MeasurementRangeRequirement;
		require responseReq : ResponseTimeRequirement;
		require lifetimeReq : OperationalLifetimeRequirement;
	}
}
