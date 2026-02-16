package 'Stretch Sensor Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	comment about StretchSensingUnit
	/* This model describes a sensing unit that measures mechanical strain and displacement
	 * using a resistive stretch sensor. The sensor's resistance changes proportionally to
	 * applied elongation, which is converted to electrical signals, digitized, and processed
	 * to provide calibrated strain and displacement measurements.
	 */
	
	attribute def ResistanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ResistanceUnit;
	}
	
	attribute def ResistanceUnit :> ScalarMeasurementReference {
		comment /* Ohm unit for electrical resistance */
	}
	
	attribute def StrainValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : StrainUnit;
	}
	
	attribute def StrainUnit :> ScalarMeasurementReference {
		comment /* Dimensionless unit representing relative deformation (delta_L / L_0) */
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> ScalarMeasurementReference {
		comment /* Volt unit for electrical potential */
	}
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CurrentUnit;
	}
	
	attribute def CurrentUnit :> ScalarMeasurementReference {
		comment /* Ampere unit for electrical current */
	}
	
	item def SensorMeasurement {
		attribute timestamp : Real;
		attribute resistance : ResistanceValue;
		attribute strain : StrainValue;
		attribute displacement : LengthValue;
		attribute voltage : VoltageValue;
		attribute isValid : Boolean;
	}
	
	item def CalibrationParameters {
		attribute baselineResistance : ResistanceValue;
		attribute gaugeFactor : Real;
		attribute originalLength : LengthValue;
		attribute maxStrain : StrainValue;
	}
	
	port def MeasurementOutputPort {
		out item measurement : SensorMeasurement;
	}
	
	port def PowerInputPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute supplyCurrent : CurrentValue;
	}
	
	port def CalibrationInputPort {
		in item calibration : CalibrationParameters;
	}
	
	port def SensorSignalPort {
		out attribute resistance : ResistanceValue;
	}
	
	port def AnalogSignalPort {
		out attribute voltage : VoltageValue;
	}
	
	port def DigitalSignalPort {
		out attribute digitalValue : Integer;
	}
	
	part def StretchSensorElement {
		attribute nominalResistance : ResistanceValue;
		attribute currentResistance : ResistanceValue;
		attribute restLength : LengthValue;
		attribute currentLength : LengthValue;
		attribute maxElongation : LengthValue;
		attribute materialGaugeFactor : Real;
		
		port signalOut : SensorSignalPort;
		
		comment about StretchSensorElement
		/* Conductive polymer or carbon-filled elastomer sensor that exhibits
		 * resistance change proportional to mechanical strain.
		 */
	}
	
	part def SignalConditioningCircuit {
		attribute bridgeVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute gain : Real;
		
		port powerIn : PowerInputPort;
		port resistanceIn : SensorSignalPort;
		port voltageOut : AnalogSignalPort;
		
		comment about SignalConditioningCircuit
		/* Wheatstone bridge configuration with instrumentation amplifier
		 * to convert resistance change to amplified voltage signal.
		 */
	}
	
	part def AnalogDigitalConverter {
		attribute resolution : Integer;
		attribute samplingFrequency : Real;
		attribute referenceVoltage : VoltageValue;
		attribute currentDigitalValue : Integer;
		
		port analogIn : AnalogSignalPort;
		port digitalOut : DigitalSignalPort;
		
		comment about AnalogDigitalConverter
		/* High-resolution ADC for converting analog voltage to digital values. */
	}
	
	part def MeasurementProcessor {
		attribute calibration : CalibrationParameters;
		attribute lastMeasurement : SensorMeasurement;
		
		port digitalIn : DigitalSignalPort;
		port calibrationPort : CalibrationInputPort;
		port measurementOut : MeasurementOutputPort;
		
		comment about MeasurementProcessor
		/* Microcontroller or DSP that processes digital values and applies
		 * calibration to compute strain and displacement.
		 */
	}
	
	connection def ResistiveConnection {
		end source : SensorSignalPort;
		end target : SensorSignalPort;
	}
	
	connection def AnalogConnection {
		end source : AnalogSignalPort;
		end target : AnalogSignalPort;
	}
	
	connection def DigitalConnection {
		end source : DigitalSignalPort;
		end target : DigitalSignalPort;
	}
	
	action def ComputeStrain {
		in attribute resistanceChange : ResistanceValue;
		in attribute baselineResistance : ResistanceValue;
		in attribute gaugeFactor : Real;
		out attribute strain : StrainValue;
		
		comment /* Strain = (deltaR / R_0) / GF where deltaR = R - R_0 */
	}
	
	action def ComputeDisplacement {
		in attribute strain : StrainValue;
		in attribute originalLength : LengthValue;
		out attribute displacement : LengthValue;
		
		comment /* Displacement = strain * originalLength */
	}
	
	action def ValidateMeasurement {
		in item measurement : SensorMeasurement;
		in attribute maxAllowedStrain : StrainValue;
		out attribute isValid : Boolean;
		
		comment /* Check if measurement is within physical limits and sensor range */
	}
	
	action def AcquireAndProcess {
		in item calibrationData : CalibrationParameters;
		out item outputMeasurement : SensorMeasurement;
		
		action acquireResistance {
			out resistance : ResistanceValue;
		}
		
		action convertToVoltage {
			in resistance : ResistanceValue;
			out voltage : VoltageValue;
		}
		
		action digitizeSignal {
			in voltage : VoltageValue;
			out digitalValue : Integer;
		}
		
		action calculateStrain : ComputeStrain {
			in resistanceChange;
			in baselineResistance;
			in gaugeFactor;
			out strain;
		}
		
		action calculateDisplacement : ComputeDisplacement {
			in strain;
			in originalLength;
			out displacement;
		}
		
		action validateResult : ValidateMeasurement {
			in measurement;
			in maxAllowedStrain;
			out isValid;
		}
		
		flow from acquireResistance.resistance to convertToVoltage.resistance;
		flow from convertToVoltage.voltage to digitizeSignal.voltage;
		flow from digitizeSignal.digitalValue to calculateStrain.resistanceChange;
		flow from calculateStrain.strain to calculateDisplacement.strain;
		
		bind calculateStrain.baselineResistance = calibrationData.baselineResistance;
		bind calculateStrain.gaugeFactor = calibrationData.gaugeFactor;
		bind calculateDisplacement.originalLength = calibrationData.originalLength;
		bind validateResult.maxAllowedStrain = calibrationData.maxStrain;
		
		bind outputMeasurement.resistance = acquireResistance.resistance;
		bind outputMeasurement.voltage = convertToVoltage.voltage;
		bind outputMeasurement.strain = calculateStrain.strain;
		bind outputMeasurement.displacement = calculateDisplacement.displacement;
		bind outputMeasurement.isValid = validateResult.isValid;
		
		first acquireResistance;
		then convertToVoltage;
		then digitizeSignal;
		then calculateStrain;
		then calculateDisplacement;
		then validateResult;
	}
	
	state def SensorOperationStates {
		entry; then powerUp;
		
		state powerUp {
			entry assign statusIndicator = 'Initializing';
		}
		
		transition powerUp_to_calibration
			first powerUp
			then calibration;
		
		state calibration {
			entry assign statusIndicator = 'Calibrating';
			do action performCalibration;
		}
		
		transition calibration_to_ready
			first calibration
			if calibrationComplete
			then ready;
		
		state ready {
			entry assign statusIndicator = 'Ready';
		}
		
		transition ready_to_measuring
			first ready
			accept MeasurementRequest
			then measuring;
		
		state measuring {
			entry assign statusIndicator = 'Measuring';
			do action continuousMeasurement : AcquireAndProcess;
		}
		
		transition measuring_to_ready
			first measuring
			accept StopMeasurement
			then ready;
		
		transition measuring_to_fault
			first measuring
			if sensorOutOfRange or electricalFault
			then fault;
		
		state fault {
			entry assign statusIndicator = 'Fault';
			do action logFault;
		}
		
		transition fault_to_powerUp
			first fault
			accept ResetCommand
			then powerUp;
	}
	
	part def StretchSensingUnit {
		attribute operatingVoltage : VoltageValue;
		attribute powerConsumption : Real;
		attribute measurementRange : LengthValue;
		attribute measurementAccuracy : Real;
		attribute statusIndicator : String;
		attribute calibrationComplete : Boolean;
		attribute sensorOutOfRange : Boolean;
		attribute electricalFault : Boolean;
		
		part sensorElement : StretchSensorElement[1] {
			attribute :>> nominalResistance = baseResistance;
			attribute :>> restLength = sensorLength;
			attribute :>> maxElongation = maxDeformation;
			attribute :>> materialGaugeFactor = gaugeFactor;
		}
		
		part conditioner : SignalConditioningCircuit[1] {
			attribute :>> bridgeVoltage = operatingVoltage;
			attribute :>> gain = amplificationGain;
		}
		
		part adc : AnalogDigitalConverter[1] {
			attribute :>> resolution = adcBits;
			attribute :>> samplingFrequency = samplingRate;
			attribute :>> referenceVoltage = adcReference;
		}
		
		part processor : MeasurementProcessor[1];
		
		port powerSupply : PowerInputPort;
		port calibrationInput : CalibrationInputPort;
		port measurementOutput : MeasurementOutputPort;
		
		private attribute baseResistance : ResistanceValue;
		private attribute sensorLength : LengthValue;
		private attribute maxDeformation : LengthValue;
		private attribute gaugeFactor : Real;
		private attribute amplificationGain : Real;
		private attribute adcBits : Integer;
		private attribute samplingRate : Real;
		private attribute adcReference : VoltageValue;
		
		connection sensorToConditioner : ResistiveConnection
			connect source references sensorElement.signalOut
			to target references conditioner.resistanceIn;
		
		connection conditionerToADC : AnalogConnection
			connect source references conditioner.voltageOut
			to target references adc.analogIn;
		
		connection adcToProcessor : DigitalConnection
			connect source references adc.digitalOut
			to target references processor.digitalIn;
		
		connect powerSupply to conditioner.powerIn;
		connect calibrationInput to processor.calibrationPort;
		connect processor.measurementOut to measurementOutput;
		
		perform action measurementBehavior : AcquireAndProcess;
		
		exhibit state operationalState : SensorOperationStates;
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall measure strain with accuracy of ±2% full scale. */
		
		subject unit : StretchSensingUnit;
		
		require constraint {
			unit.measurementAccuracy <= 0.02
		}
	}
	
	requirement def RangeRequirement {
		doc /* The sensing unit shall measure elongation up to 100% of original sensor length. */
		
		subject unit : StretchSensingUnit;
		
		require constraint {
			unit.sensorElement.maxElongation >= unit.sensorElement.restLength
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The sensing unit shall provide measurement updates at minimum 100 Hz. */
		
		subject unit : StretchSensingUnit;
		
		require constraint {
			unit.adc.samplingFrequency >= 100.0
		}
	}
	
	requirement def PowerRequirement {
		doc /* The sensing unit shall operate on 5V DC supply with power consumption below 1W. */
		
		subject unit : StretchSensingUnit;
		
		require constraint {
			unit.powerConsumption <= 1.0
		}
	}
	
	requirement def ResolutionRequirement {
		doc /* The sensing unit shall provide at least 16-bit measurement resolution. */
		
		subject unit : StretchSensingUnit;
		
		require constraint {
			unit.adc.resolution >= 16
		}
	}
	
	part sensingUnitInstance : StretchSensingUnit {
		attribute :>> operatingVoltage = supplyVoltage;
		attribute :>> powerConsumption = 0.75;
		attribute :>> measurementRange = maxRange;
		attribute :>> measurementAccuracy = 0.015;
		attribute :>> calibrationComplete = false;
		attribute :>> sensorOutOfRange = false;
		attribute :>> electricalFault = false;
		
		private attribute supplyVoltage : VoltageValue;
		private attribute maxRange : LengthValue;
		
		part :>> sensorElement {
			attribute :>> nominalResistance = nominalR;
			attribute :>> restLength = restL;
			attribute :>> maxElongation = maxElong;
			attribute :>> materialGaugeFactor = 2.1;
			
			private attribute nominalR : ResistanceValue;
			private attribute restL : LengthValue;
			private attribute maxElong : LengthValue;
		}
		
		part :>> conditioner {
			attribute :>> gain = 100.0;
		}
		
		part :>> adc {
			attribute :>> resolution = 16;
			attribute :>> samplingFrequency = 1000.0;
			attribute :>> referenceVoltage = refV;
			
			private attribute refV : VoltageValue;
		}
		
		private attribute adcBits = 16;
		private attribute samplingRate = 1000.0;
		
		satisfy AccuracyRequirement by sensingUnitInstance;
		satisfy RangeRequirement by sensingUnitInstance;
		satisfy SamplingRateRequirement by sensingUnitInstance;
		satisfy PowerRequirement by sensingUnitInstance;
		satisfy ResolutionRequirement by sensingUnitInstance;
	}
}
