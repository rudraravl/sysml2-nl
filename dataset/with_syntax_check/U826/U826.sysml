package 'Planar Hall Sensing Unit' {
	private import ScalarValues::*;
	
	attribute def MagneticFluxDensityValue {
		attribute num : Real;
		attribute mRef : MagneticFluxDensityUnit;
	}
	
	attribute def MagneticFluxDensityUnit {
		attribute name : String;
	}
	
	attribute def VoltageValue {
		attribute num : Real;
		attribute mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit {
		attribute name : String;
	}
	
	attribute def CurrentValue {
		attribute num : Real;
		attribute mRef : CurrentUnit;
	}
	
	attribute def CurrentUnit {
		attribute name : String;
	}
	
	attribute def FrequencyValue {
		attribute num : Real;
		attribute mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit {
		attribute name : String;
	}
	
	attribute def TemperatureValue {
		attribute num : Real;
		attribute mRef : TemperatureUnit;
	}
	
	attribute def TemperatureUnit {
		attribute name : String;
	}
	
	attribute def AngleValue {
		attribute num : Real;
		attribute mRef : AngleUnit;
	}
	
	attribute def AngleUnit {
		attribute name : String;
	}
	
	attribute def LengthValue {
		attribute num : Real;
		attribute mRef : LengthUnit;
	}
	
	attribute def LengthUnit {
		attribute name : String;
	}
	
	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensityValue;
		attribute orientation : AngleValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	item def DigitalData {
		attribute value : MagneticFluxDensityValue;
		attribute timestamp : Real;
		attribute quality : Real;
	}
	
	port def MagneticFieldPort {
		in item field : MagneticField;
	}
	
	port def PowerPort {
		in item power : ElectricalSignal;
	}
	
	port def AnalogSignalPort {
		out item signal : ElectricalSignal;
	}
	
	port def DigitalDataPort {
		out item data : DigitalData;
	}
	
	part def PlanarHallElement {
		attribute sensitivity : Real;
		attribute resistance : Real;
		attribute operatingTemperature : TemperatureValue;
		
		port fieldExposure : MagneticFieldPort;
		port biasInput : PowerPort;
		port hallOutput : AnalogSignalPort;
		
		part ferromagneticLayer {
			attribute thickness : LengthValue;
			attribute material : String;
			attribute magnetization : MagneticFluxDensityValue;
		}
		
		part conductiveLayer {
			attribute thickness : LengthValue;
			attribute resistivity : Real;
		}
		
		part contactPads[4] {
			attribute position : String;
			attribute resistance : Real;
		}
	}
	
	part def BiasCircuit {
		attribute biasVoltage : VoltageValue;
		attribute biasCurrent : CurrentValue;
		
		port powerIn : PowerPort;
		port biasOut : PowerPort;
		
		part currentSource {
			attribute setpoint : CurrentValue;
			attribute stability : Real;
		}
		
		part voltageRegulator {
			attribute outputVoltage : VoltageValue;
			attribute ripple : VoltageValue;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		attribute noiseLevel : VoltageValue;
		
		port analogIn : AnalogSignalPort;
		port analogOut : AnalogSignalPort;
		port powerIn : PowerPort;
		
		part differentialAmplifier {
			attribute amplificationFactor : Real;
			attribute inputImpedance : Real;
		}
		
		part lowPassFilter {
			attribute cutoffFrequency : FrequencyValue;
			attribute rolloff : Real;
		}
		
		part offsetCompensation {
			attribute offsetVoltage : VoltageValue;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Real;
		attribute samplingRate : FrequencyValue;
		attribute conversionTime : Real;
		
		port analogIn : AnalogSignalPort;
		port digitalOut : DigitalDataPort;
		port powerIn : PowerPort;
		
		part sampleAndHold {
			attribute acquisitionTime : Real;
		}
		
		part quantizer {
			attribute bits : Real;
			attribute referenceVoltage : VoltageValue;
		}
	}
	
	part def SignalProcessor {
		attribute calibrationCoefficients : Real[3];
		attribute temperatureCompensation : Boolean;
		
		port dataIn : DigitalDataPort;
		port dataOut : DigitalDataPort;
		port powerIn : PowerPort;
		
		part calibrationMemory {
			attribute capacity : Real;
		}
		
		part computationUnit {
			attribute processingSpeed : FrequencyValue;
		}
	}
	
	part def PowerSupply {
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute efficiency : Real;
		
		port powerIn : PowerPort;
		port powerOut : PowerPort;
		
		part dcConverter {
			attribute conversionRatio : Real;
		}
		
		part filterCapacitor {
			attribute capacitance : Real;
		}
	}
	
	action def DetectMagneticField {
		in field : MagneticField;
		in biasCurrent : CurrentValue;
		out hallVoltage : VoltageValue;
	}
	
	action def ConditionSignal {
		in rawVoltage : VoltageValue;
		in gain : Real;
		out conditionedVoltage : VoltageValue;
	}
	
	action def DigitizeSignal {
		in analogVoltage : VoltageValue;
		out digitalValue : Real;
	}
	
	action def ProcessData {
		in rawData : Real;
		in calibration : Real[3];
		out calibratedData : MagneticFluxDensityValue;
	}
	
	action def MeasurementSequence {
		in magneticField : MagneticField;
		out measurement : DigitalData;
		
		bind detect.field = magneticField;
		
		action detect : DetectMagneticField {
			in field;
			in biasCurrent;
			out hallVoltage;
		}
		
		flow from detect.hallVoltage to condition.rawVoltage;
		
		action condition : ConditionSignal {
			in rawVoltage;
			in gain;
			out conditionedVoltage;
		}
		
		flow from condition.conditionedVoltage to digitize.analogVoltage;
		
		action digitize : DigitizeSignal {
			in analogVoltage;
			out digitalValue;
		}
		
		flow from digitize.digitalValue to process.rawData;
		
		action process : ProcessData {
			in rawData;
			in calibration;
			out calibratedData;
		}
		
		bind process.calibratedData = measurement.value;
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initialization
			first powerOff
			accept PowerOn
			then initialization;
		
		state initialization;
		
		transition initialization_to_idle
			first initialization
			accept InitializationComplete
			then idle;
		
		state idle;
		
		transition idle_to_measuring
			first idle
			accept StartMeasurement
			then measuring;
		
		state measuring;
		
		transition measuring_to_idle
			first measuring
			accept MeasurementComplete
			then idle;
		
		transition measuring_to_fault
			first measuring
			accept SensorFault
			then fault;
		
		transition idle_to_calibration
			first idle
			accept StartCalibration
			then calibration;
		
		state calibration;
		
		transition calibration_to_idle
			first calibration
			accept CalibrationComplete
			then idle;
		
		state fault;
		
		transition fault_to_initialization
			first fault
			accept Reset
			then initialization;
		
		transition any_to_powerOff
			first powerOff, initialization, idle, measuring, calibration, fault
			accept PowerOff
			then powerOff;
	}
	
	part def PlanarHallSensingUnit {
		attribute serialNumber : String;
		attribute calibrationDate : String;
		attribute operatingRange : MagneticFluxDensityValue[2];
		
		port fieldInput : MagneticFieldPort;
		port measurementOutput : DigitalDataPort;
		port externalPower : PowerPort;
		
		part hallElement : PlanarHallElement {
			attribute :>> sensitivity = 0.85;
			attribute :>> resistance = 1000.0;
			
			part :>> ferromagneticLayer {
				attribute :>> thickness = { attribute :>> num = 50.0; attribute :>> mRef = { attribute :>> name = "nm"; } }
				attribute :>> material = "NiFe";
			}
			
			part :>> conductiveLayer {
				attribute :>> thickness = { attribute :>> num = 20.0; attribute :>> mRef = { attribute :>> name = "nm"; } }
				attribute :>> resistivity = 1.5e-7;
			}
		}
		
		part biasCircuit : BiasCircuit {
			attribute :>> biasVoltage = { attribute :>> num = 3.3; attribute :>> mRef = { attribute :>> name = "V"; } }
			attribute :>> biasCurrent = { attribute :>> num = 1.5; attribute :>> mRef = { attribute :>> name = "mA"; } }
			
			part :>> currentSource {
				attribute :>> setpoint = { attribute :>> num = 1.5; attribute :>> mRef = { attribute :>> name = "mA"; } }
				attribute :>> stability = 0.01;
			}
		}
		
		part conditioner : SignalConditioner {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = { attribute :>> num = 10000.0; attribute :>> mRef = { attribute :>> name = "Hz"; } }
			
			part :>> differentialAmplifier {
				attribute :>> amplificationFactor = 100.0;
				attribute :>> inputImpedance = 1.0e6;
			}
			
			part :>> lowPassFilter {
				attribute :>> cutoffFrequency = { attribute :>> num = 5000.0; attribute :>> mRef = { attribute :>> name = "Hz"; } }
				attribute :>> rolloff = 40.0;
			}
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16.0;
			attribute :>> samplingRate = { attribute :>> num = 20000.0; attribute :>> mRef = { attribute :>> name = "Hz"; } }
			attribute :>> conversionTime = 0.00005;
			
			part :>> quantizer {
				attribute :>> bits = 16.0;
				attribute :>> referenceVoltage = { attribute :>> num = 5.0; attribute :>> mRef = { attribute :>> name = "V"; } }
			}
		}
		
		part processor : SignalProcessor {
			attribute :>> calibrationCoefficients = (1.0, 0.0, 0.0);
			attribute :>> temperatureCompensation = true;
			
			part :>> computationUnit {
				attribute :>> processingSpeed = { attribute :>> num = 100000000.0; attribute :>> mRef = { attribute :>> name = "Hz"; } }
			}
		}
		
		part powerSupply : PowerSupply {
			attribute :>> inputVoltage = { attribute :>> num = 12.0; attribute :>> mRef = { attribute :>> name = "V"; } }
			attribute :>> outputVoltage = { attribute :>> num = 5.0; attribute :>> mRef = { attribute :>> name = "V"; } }
			attribute :>> maxCurrent = { attribute :>> num = 200.0; attribute :>> mRef = { attribute :>> name = "mA"; } }
			attribute :>> efficiency = 0.85;
		}
		
		connect externalPower to powerSupply.powerIn;
		connect powerSupply.powerOut to biasCircuit.powerIn;
		connect powerSupply.powerOut to conditioner.powerIn;
		connect powerSupply.powerOut to adc.powerIn;
		connect powerSupply.powerOut to processor.powerIn;
		
		connect fieldInput to hallElement.fieldExposure;
		connect biasCircuit.biasOut to hallElement.biasInput;
		connect hallElement.hallOutput to conditioner.analogIn;
		connect conditioner.analogOut to adc.analogIn;
		connect adc.digitalOut to processor.dataIn;
		connect processor.dataOut to measurementOutput;
		
		perform action measurementSequence : MeasurementSequence;
		exhibit state operationalState : SensorOperationalStates;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure magnetic flux density with accuracy better than 1 percent of full scale. */
		
		subject unit : PlanarHallSensingUnit;
		
		attribute actualField : Real;
		attribute fullScale : Real;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure magnetic flux density from -200 mT to +200 mT. */
		
		subject unit : PlanarHallSensingUnit;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurement output within 100 microseconds of field change. */
		
		subject unit : PlanarHallSensingUnit;
	}
	
	requirement def ResolutionRequirement {
		doc /* The sensing unit shall provide measurement resolution better than 0.1 mT. */
		
		subject unit : PlanarHallSensingUnit;
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall consume less than 150 mW during normal operation. */
		
		subject unit : PlanarHallSensingUnit;
	}
	
	requirement sensingUnitRequirements {
		doc /* Top-level requirements for the Planar Hall sensing unit system. */
		
		subject unit : PlanarHallSensingUnit;
		
		requirement accuracyReq : MeasurementAccuracyRequirement {
			subject unit = sensingUnitRequirements::unit;
			:>> actualField = 100.0;
			:>> fullScale = 200.0;
		}
		
		requirement rangeReq : MeasurementRangeRequirement {
			subject unit = sensingUnitRequirements::unit;
		}
		
		requirement responseReq : ResponseTimeRequirement {
			subject unit = sensingUnitRequirements::unit;
		}
		
		requirement resolutionReq : ResolutionRequirement {
			subject unit = sensingUnitRequirements::unit;
		}
		
		requirement powerReq : PowerConsumptionRequirement {
			subject unit = sensingUnitRequirements::unit;
		}
	}
	
	part sensingUnit : PlanarHallSensingUnit {
		attribute :>> serialNumber = "PHS-2025-001";
		attribute :>> calibrationDate = "2025-01-15";
	}
}
