package RainSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	comment about RainSensingUnit
	/* This model describes a rain sensing unit that measures precipitation
	 * using a capacitive rain sensor. The system detects rainfall by measuring
	 * changes in capacitance on a sensing surface and converts this to
	 * precipitation rate and accumulated rainfall depth.
	 */
	
	attribute def PrecipitationRateUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
	}
	
	attribute def PrecipitationRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PrecipitationRateUnit;
	}
	
	attribute precipitationRate : PrecipitationRateValue :> scalarQuantities;
	
	attribute def CapacitanceUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[4] ordered;
	}
	
	attribute def CapacitanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CapacitanceUnit;
	}
	
	attribute capacitance : CapacitanceValue :> scalarQuantities;
	
	attribute def VoltageUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[4] ordered;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute voltage : VoltageValue :> scalarQuantities;
	
	item def RainMeasurementData {
		attribute currentRate : PrecipitationRateValue;
		attribute accumulatedDepth : LengthValue;
		attribute timestamp : String;
		attribute status : SensorStatusType;
	}
	
	enum def SensorStatusType {
		enum Idle;
		enum Active;
		enum Calibrating;
		enum Fault;
	}
	
	item def ControlCommand {
		attribute commandType : CommandType;
		attribute parameter : Real;
	}
	
	enum def CommandType {
		enum Start;
		enum Stop;
		enum Calibrate;
		enum Reset;
		enum SetThreshold;
	}
	
	port def DataOutputPort {
		out item rainData : RainMeasurementData;
	}
	
	port def ControlInputPort {
		in item command : ControlCommand;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : VoltageValue;
		out attribute currentDraw : ElectricCurrentValue;
	}
	
	port def SensorSignalPort {
		out attribute capacitanceSignal : CapacitanceValue;
	}
	
	port def ProcessedSignalPort {
		in attribute capacitanceSignal : CapacitanceValue;
		out attribute precipitationSignal : PrecipitationRateValue;
	}
	
	part def CapacitiveRainSensor {
		attribute sensingArea : AreaValue;
		attribute baselineCapacitance : CapacitanceValue;
		attribute currentCapacitance : CapacitanceValue;
		attribute sensitivity : Real;
		
		port signalOutput : SensorSignalPort;
		port power : PowerPort;
		
		action measureCapacitance {
			out measuredCapacitance : CapacitanceValue;
		}
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFrequency : FrequencyValue;
		
		port signalInput : SensorSignalPort;
		port signalOutput : ProcessedSignalPort;
		
		action filterAndAmplify {
			in rawCapacitance : CapacitanceValue;
			out conditionedCapacitance : CapacitanceValue;
		}
	}
	
	part def CalibrationProcessor {
		attribute calibrationCoefficients : Real[3];
		attribute temperatureCompensationFactor : Real;
		
		port dataInput : ProcessedSignalPort;
		
		action convertToRate {
			in capacitanceChange : CapacitanceValue;
			in temperature : ThermodynamicTemperatureValue;
			out rate : PrecipitationRateValue;
		}
	}
	
	part def DataAccumulator {
		attribute measurementInterval : TimeValue;
		attribute totalAccumulatedDepth : LengthValue;
		attribute sampleCount : Integer;
		
		port dataOutput : DataOutputPort;
		
		action accumulateRainfall {
			in instantaneousRate : PrecipitationRateValue;
			in deltaTime : TimeValue;
			in previousDepth : LengthValue;
			out newDepth : LengthValue;
		}
		
		action generateOutput {
			in rate : PrecipitationRateValue;
			in depth : LengthValue;
			out data : RainMeasurementData;
		}
	}
	
	part def TemperatureSensor {
		attribute measurementRange : ThermodynamicTemperatureValue[2];
		
		out attribute currentTemperature : ThermodynamicTemperatureValue;
		
		action measureTemperature {
			out temperature : ThermodynamicTemperatureValue;
		}
	}
	
	connection def CapacitanceConnection {
		end source : SensorSignalPort;
		end target : SensorSignalPort;
	}
	
	connection def ProcessedDataConnection {
		end source : ProcessedSignalPort;
		end target : ProcessedSignalPort;
	}
	
	action def MeasureRainfall {
		in attribute baselineValue : CapacitanceValue;
		out attribute measuredValue : CapacitanceValue;
		out attribute deltaCapacitance : CapacitanceValue;
	}
	
	action def ConditionSignal {
		in attribute rawSignal : CapacitanceValue;
		in attribute gain : Real;
		out attribute conditionedSignal : CapacitanceValue;
	}
	
	action def CalibrateAndConvert {
		in attribute capacitanceChange : CapacitanceValue;
		in attribute calibrationFactors : Real[3];
		in attribute temperature : ThermodynamicTemperatureValue;
		out attribute precipitationRate : PrecipitationRateValue;
	}
	
	action def AccumulateDepth {
		in attribute rate : PrecipitationRateValue;
		in attribute timeInterval : TimeValue;
		in attribute previousTotal : LengthValue;
		out attribute newTotal : LengthValue;
	}
	
	action def RainSensingSequence {
		action initializeSensor {
			out initialStatus : SensorStatusType;
		}
		
		then fork;
		
		then measureRainfall : MeasureRainfall {
			in baselineValue;
			out measuredValue;
			out deltaCapacitance;
		}
		
		then conditionSignal : ConditionSignal {
			in rawSignal;
			in gain;
			out conditionedSignal;
		}
		
		flow from measureRainfall.deltaCapacitance to conditionSignal.rawSignal;
		
		then calibrateAndConvert : CalibrateAndConvert {
			in capacitanceChange;
			in calibrationFactors;
			in temperature;
			out precipitationRate;
		}
		
		flow from conditionSignal.conditionedSignal to calibrateAndConvert.capacitanceChange;
		
		then accumulateDepth : AccumulateDepth {
			in rate;
			in timeInterval;
			in previousTotal;
			out newTotal;
		}
		
		flow from calibrateAndConvert.precipitationRate to accumulateDepth.rate;
		
		join;
		then done;
	}
	
	state def RainSensorStateMachine {
		entry; 
		then powerOff;
		
		state powerOff {
			entry assign status = SensorStatusType::Idle;
		}
		
		transition powerOn
			first powerOff
			accept ControlCommand
			then initialization;
		
		state initialization {
			entry assign status = SensorStatusType::Calibrating;
			do action performInitialization {
				out initComplete : Boolean;
			}
		}
		
		transition initToStandby
			first initialization
			then standby;
		
		state standby {
			entry assign status = SensorStatusType::Idle;
		}
		
		transition standbyToMeasuring
			first standby
			accept ControlCommand
			then measuring;
		
		state measuring {
			entry assign status = SensorStatusType::Active;
			do action continuousMeasurement : RainSensingSequence;
		}
		
		transition measuringToStandby
			first measuring
			accept ControlCommand
			then standby;
		
		transition measuringToCalibration
			first measuring
			accept ControlCommand
			then calibration;
		
		state calibration {
			entry assign status = SensorStatusType::Calibrating;
			do action performCalibration {
				out calibrationComplete : Boolean;
			}
		}
		
		transition calibrationToMeasuring
			first calibration
			then measuring;
		
		state fault {
			entry assign status = SensorStatusType::Fault;
		}
		
		transition faultToStandby
			first fault
			accept ControlCommand
			then standby;
	}
	
	part def RainSensingUnit {
		attribute operatingTemperatureRange : ThermodynamicTemperatureValue[2];
		attribute measurementAccuracy : Real;
		attribute responseTime : TimeValue;
		attribute maxMeasurableRate : PrecipitationRateValue;
		
		part sensor : CapacitiveRainSensor[1] {
			attribute :>> sensitivity = 0.5;
		}
		
		part conditioner : SignalConditioner[1] {
			attribute :>> amplificationGain = 10.0;
		}
		
		part calibration : CalibrationProcessor[1] {
			attribute :>> calibrationCoefficients = (1.5, 0.08, 0.002);
			attribute :>> temperatureCompensationFactor = 0.015;
		}
		
		part accumulator : DataAccumulator[1] {
			attribute :>> sampleCount default = 0;
		}
		
		part tempSensor : TemperatureSensor[1];
		
		port dataOutput : DataOutputPort;
		port controlInput : ControlInputPort;
		port powerInput : PowerPort;
		
		connection capSignal : CapacitanceConnection
			connect sensor.signalOutput to conditioner.signalInput;
		
		connection procSignal : ProcessedDataConnection
			connect conditioner.signalOutput to calibration.dataInput;
		
		bind accumulator.dataOutput = dataOutput;
		bind sensor.power = powerInput;
		
		perform action sensingBehavior : RainSensingSequence;
		
		exhibit state sensorControl : RainSensorStateMachine;
	}
	
	requirement def AccuracyRequirement {
		doc /* The rain sensing unit shall measure precipitation rate 
		     * with an accuracy of +/- 5% over the range of 0 to 100 mm/hr. */
		
		subject unit : RainSensingUnit;
		
		require constraint {
			unit.measurementAccuracy <= 0.05
		}
	}
	
	requirement def ResponseRequirement {
		doc /* The rain sensing unit shall detect the onset of rainfall
		     * within 10 seconds of initial precipitation contact. */
		
		subject unit : RainSensingUnit;
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The rain sensing unit shall operate correctly over the
		     * temperature range of -40°C to +85°C. */
		
		subject unit : RainSensingUnit;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The rain sensing unit shall measure precipitation rates
		     * from 0 to 100 mm/hr. */
		
		subject unit : RainSensingUnit;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the rain sensing unit system. */
		
		requirement accuracyReq : AccuracyRequirement;
		requirement responseReq : ResponseRequirement;
		requirement temperatureReq : TemperatureRangeRequirement;
		requirement rangeReq : MeasurementRangeRequirement;
	}
	
	part rainSensorInstance : RainSensingUnit {
		attribute :>> measurementAccuracy = 0.04;
		
		satisfy systemRequirements by rainSensorInstance;
	}
}
