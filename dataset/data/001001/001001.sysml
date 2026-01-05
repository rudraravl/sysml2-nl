package 'Capacitive Displacement Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import UnitsAndScales::*;
	
	comment about CapacitiveDisplacementSensor
	/* This model describes a capacitive displacement sensing unit that measures
	 * linear displacement by detecting changes in capacitance between parallel plates.
	 * The sensor operates on the principle that capacitance varies inversely with
	 * the distance between the sensor probe and the target surface. The system
	 * converts this capacitance variation into a calibrated displacement measurement
	 * through signal conditioning, analog-to-digital conversion, and digital processing. */
	
	attribute def MeasurementRange {
		attribute minRange : LengthValue;
		attribute maxRange : LengthValue;
	}
	
	attribute def SensorSpecification {
		attribute sensitivity : Real;
		attribute linearity : Real;
		attribute resolution : LengthValue;
		attribute bandwidth : Real;
	}
	
	item def RawCapacitanceSignal {
		attribute capacitance : Real;
		attribute timestamp : Real;
	}
	
	item def ConditionedSignal {
		attribute voltage : Real;
		attribute timestamp : Real;
	}
	
	item def DigitalSample {
		attribute digitalCode : Integer;
		attribute timestamp : Real;
	}
	
	item def DisplacementMeasurement {
		attribute displacement : LengthValue;
		attribute timestamp : Real;
		attribute validity : Boolean;
		attribute quality : Real;
	}
	
	port def CapacitiveSensorPort {
		out item capacitanceSignal : RawCapacitanceSignal;
	}
	
	port def AnalogSignalPort {
		in item inputSignal : RawCapacitanceSignal;
		out item outputSignal : ConditionedSignal;
	}
	
	port def DigitalConversionPort {
		in item analogInput : ConditionedSignal;
		out item digitalOutput : DigitalSample;
	}
	
	port def ProcessingPort {
		in item digitalInput : DigitalSample;
		out item displacementOutput : DisplacementMeasurement;
	}
	
	port def PowerSupplyPort {
		in item supplyVoltage : Real;
		in item supplyCurrent : Real;
	}
	
	port def DataOutputPort {
		out item measurement : DisplacementMeasurement;
	}
	
	part def CapacitiveSensorProbe {
		attribute probeArea : Real;
		attribute nominalGap : LengthValue;
		attribute dielectricConstant : Real;
		
		port sensorOutput : CapacitiveSensorPort;
		port power : PowerSupplyPort;
		
		action def SenseCapacitance {
			in targetDistance : LengthValue;
			out capacitance : Real;
			
			attribute epsilon0 : Real = 8.854e-12;
			attribute effectiveArea : Real;
			attribute k : Real;
		}
		
		action sensing : SenseCapacitance;
	}
	
	part def SignalConditioningCircuit {
		attribute amplifierGain : Real;
		attribute filterCutoffFrequency : Real;
		attribute offsetVoltage : Real;
		
		port analogInput : AnalogSignalPort;
		port power : PowerSupplyPort;
		
		action def ConvertCapacitanceToVoltage {
			in capacitance : Real;
			out voltage : Real;
			
			attribute conversionFactor : Real = 1000.0;
		}
		
		action def AmplifySignal {
			in inputVoltage : Real;
			out amplifiedVoltage : Real;
			
			attribute gain : Real;
		}
		
		action def FilterSignal {
			in noisyVoltage : Real;
			out filteredVoltage : Real;
			
			attribute cutoff : Real;
		}
		
		action conditioning {
			action convert : ConvertCapacitanceToVoltage {
				in capacitance;
				out voltage;
			}
			
			succession flow from convert.voltage to amplify.inputVoltage;
			
			action amplify : AmplifySignal {
				in inputVoltage;
				out amplifiedVoltage;
			}
			
			succession flow from amplify.amplifiedVoltage to filter.noisyVoltage;
			
			action filter : FilterSignal {
				in noisyVoltage;
				out filteredVoltage;
			}
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : Real;
		
		port conversionInput : DigitalConversionPort;
		port power : PowerSupplyPort;
		
		action def Digitize {
			in analogVoltage : Real;
			out digitalValue : Integer;
			
			attribute bits : Integer;
			attribute vRef : Real;
		}
		
		action converting : Digitize;
	}
	
	part def DigitalSignalProcessor {
		attribute calibrationTable : Real[10];
		attribute temperatureCoefficient : Real;
		
		port processingInput : ProcessingPort;
		port power : PowerSupplyPort;
		
		action def ApplyCalibration {
			in rawDigital : Integer;
			out calibratedValue : Real;
			
			attribute coefficients : Real[10];
		}
		
		action def ConvertToDisplacement {
			in calibratedValue : Real;
			out displacement : LengthValue;
			
			attribute scaleFactor : Real = 0.001;
		}
		
		action def ValidateMeasurement {
			in displacement : LengthValue;
			in range : MeasurementRange;
			out isValid : Boolean;
		}
		
		action def CompensateTemperature {
			in rawDisplacement : LengthValue;
			in temperature : Real;
			out compensatedDisplacement : LengthValue;
			
			attribute tempCoeff : Real;
		}
		
		action def AssessQuality {
			in displacement : LengthValue;
			in validity : Boolean;
			out qualityMetric : Real;
		}
		
		action processing {
			action calibrate : ApplyCalibration {
				in rawDigital;
				out calibratedValue;
			}
			
			succession flow from calibrate.calibratedValue to convert.calibratedValue;
			
			action convert : ConvertToDisplacement {
				in calibratedValue;
				out displacement;
			}
			
			then fork;
			
			succession flow from convert.displacement to validate.displacement;
			
			action validate : ValidateMeasurement {
				in displacement;
				in range;
				out isValid;
			}
			
			then joinNode;
			
			succession flow from convert.displacement to compensate.rawDisplacement;
			
			action compensate : CompensateTemperature {
				in rawDisplacement;
				in temperature;
				out compensatedDisplacement;
			}
			
			then joinNode;
			
			join joinNode;
			
			then assess : AssessQuality {
				in displacement;
				in validity;
				out qualityMetric;
			}
			
			then done;
		}
	}
	
	state def SensorOperationStates {
		entry; then powerUp;
		
		state powerUp {
			entry action initializePower;
		}
		
		transition powerUp_to_selfTest
			first powerUp
			then selfTest;
		
		state selfTest {
			entry action runDiagnostics;
			do action checkSensorIntegrity;
		}
		
		transition selfTest_to_calibration
			first selfTest
			if diagnosticsPassed
			then calibration;
		
		transition selfTest_to_fault
			first selfTest
			if diagnosticsFailed
			then fault;
		
		state calibration {
			entry action loadCalibrationData;
			do action performZeroCalibration;
		}
		
		transition calibration_to_ready
			first calibration
			if calibrationComplete
			then ready;
		
		state ready {
			entry assign operationalMode = 'standby';
		}
		
		transition ready_to_measuring
			first ready
			accept StartMeasurement
			then measuring;
		
		state measuring {
			entry assign operationalMode = 'active';
			
			state continuous {
				do action continuousSampling;
			}
			
			state triggered {
				do action triggeredSampling;
			}
			
			initial -> continuous;
			
			transition continuous_to_triggered
				first continuous
				accept TriggerModeRequest
				then triggered;
			
			transition triggered_to_continuous
				first triggered
				accept ContinuousModeRequest
				then continuous;
		}
		
		transition measuring_to_ready
			first measuring
			accept StopMeasurement
			then ready;
		
		transition measuring_to_fault
			first measuring
			accept ErrorDetected
			then fault;
		
		state fault {
			entry action logFaultCondition;
			do action attemptRecovery;
		}
		
		transition fault_to_powerUp
			first fault
			accept ResetCommand
			then powerUp;
	}
	
	part def CapacitiveDisplacementSensor {
		attribute measurementRange : MeasurementRange {
			attribute :>> minRange = 0.0[mm];
			attribute :>> maxRange = 10.0[mm];
		}
		
		attribute specification : SensorSpecification {
			attribute :>> sensitivity = 100.0;
			attribute :>> linearity = 0.1;
			attribute :>> resolution = 0.0001[mm];
			attribute :>> bandwidth = 10000.0;
		}
		
		attribute operatingTemperature : Real[2] = (-40.0, 125.0);
		attribute supplyVoltage : Real = 24.0;
		attribute supplyCurrent : Real = 0.1;
		
		port powerInput : PowerSupplyPort;
		port measurementOutput : DataOutputPort;
		
		part probe : CapacitiveSensorProbe[1] {
			attribute :>> probeArea = 100.0;
			attribute :>> nominalGap = 1.0[mm];
			attribute :>> dielectricConstant = 1.0;
		}
		
		part conditioner : SignalConditioningCircuit[1] {
			attribute :>> amplifierGain = 100.0;
			attribute :>> filterCutoffFrequency = 5000.0;
			attribute :>> offsetVoltage = 0.0;
		}
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 24;
			attribute :>> samplingRate = 20000.0;
			attribute :>> referenceVoltage = 5.0;
		}
		
		part processor : DigitalSignalProcessor[1] {
			attribute :>> calibrationTable = (0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			attribute :>> temperatureCoefficient = 0.0001;
		}
		
		connection probeToConditioner
			connect probe.sensorOutput to conditioner.analogInput;
		
		connection conditionerToADC
			connect conditioner.analogInput to adc.conversionInput;
		
		connection adcToProcessor
			connect adc.conversionInput to processor.processingInput;
		
		connection processorToOutput
			connect processor.processingInput to measurementOutput;
		
		state behavior operationalBehavior : SensorOperationStates;
		
		action def PerformMeasurementCycle {
			in targetPosition : LengthValue;
			out measurement : DisplacementMeasurement;
			
			bind probe.sensing.targetDistance = targetPosition;
			
			action senseCapacitance : probe.sensing {
				in targetDistance;
				out capacitance;
			}
			
			succession flow from senseCapacitance.capacitance to conditionSignal.convert.capacitance;
			
			action conditionSignal : conditioner.conditioning;
			
			succession flow from conditionSignal.filter.filteredVoltage to digitizeSignal.analogVoltage;
			
			action digitizeSignal : adc.converting {
				in analogVoltage;
				out digitalValue;
			}
			
			succession flow from digitizeSignal.digitalValue to processSignal.calibrate.rawDigital;
			
			action processSignal : processor.processing;
			
			bind processSignal.convert.displacement = measurement.displacement;
			bind processSignal.validate.isValid = measurement.validity;
			bind processSignal.assess.qualityMetric = measurement.quality;
		}
	}
	
	part sensingUnit : CapacitiveDisplacementSensor {
		attribute :>> measurementRange {
			attribute :>> minRange = 0.0[mm];
			attribute :>> maxRange = 5.0[mm];
		}
		
		attribute :>> specification {
			attribute :>> sensitivity = 150.0;
			attribute :>> linearity = 0.05;
			attribute :>> resolution = 0.00005[mm];
			attribute :>> bandwidth = 15000.0;
		}
		
		part :>> probe {
			attribute :>> probeArea = 78.5;
			attribute :>> nominalGap = 0.5[mm];
			attribute :>> dielectricConstant = 1.0;
		}
		
		part :>> conditioner {
			attribute :>> amplifierGain = 150.0;
			attribute :>> filterCutoffFrequency = 7500.0;
			attribute :>> offsetVoltage = 2.5;
		}
		
		part :>> adc {
			attribute :>> resolution = 24;
			attribute :>> samplingRate = 30000.0;
			attribute :>> referenceVoltage = 5.0;
		}
		
		part :>> processor {
			attribute :>> calibrationTable = (0.05, 0.98, -0.002, 0.0001, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			attribute :>> temperatureCoefficient = 0.00015;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall measure displacement with specified accuracy
		     * and linearity across the full measurement range. */
		
		subject sensor : CapacitiveDisplacementSensor;
		
		require constraint {
			sensor.specification.linearity <= 0.1
		}
	}
	
	requirement def RangeRequirement {
		doc /* The sensing unit shall operate within the specified displacement range. */
		
		subject sensor : CapacitiveDisplacementSensor;
		
		require constraint {
			sensor.measurementRange.maxRange >= 5.0[mm]
		}
		
		require constraint {
			sensor.measurementRange.minRange == 0.0[mm]
		}
	}
	
	requirement def BandwidthRequirement {
		doc /* The sensing unit shall provide measurements at a minimum bandwidth. */
		
		subject sensor : CapacitiveDisplacementSensor;
		
		require constraint {
			sensor.specification.bandwidth >= 10000.0
		}
	}
	
	requirement def EnvironmentalRequirement {
		doc /* The sensing unit shall operate within specified environmental conditions. */
		
		subject sensor : CapacitiveDisplacementSensor;
		
		require constraint {
			sensor.operatingTemperature[1] <= -20.0 and
			sensor.operatingTemperature[2] >= 85.0
		}
	}
	
	requirement def PowerRequirement {
		doc /* The sensing unit shall operate within specified power supply limits. */
		
		subject sensor : CapacitiveDisplacementSensor;
		
		require constraint {
			sensor.supplyVoltage >= 12.0 and sensor.supplyVoltage <= 30.0
		}
		
		require constraint {
			sensor.supplyCurrent <= 0.2
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the capacitive displacement sensing unit. */
		
		requirement accuracyReq : AccuracyRequirement {
			subject actualSensor = sensingUnit;
		}
		
		requirement rangeReq : RangeRequirement {
			subject actualSensor = sensingUnit;
		}
		
		requirement bandwidthReq : BandwidthRequirement {
			subject actualSensor = sensingUnit;
		}
		
		requirement environmentalReq : EnvironmentalRequirement {
			subject actualSensor = sensingUnit;
		}
		
		requirement powerReq : PowerRequirement {
			subject actualSensor = sensingUnit;
		}
	}
}
