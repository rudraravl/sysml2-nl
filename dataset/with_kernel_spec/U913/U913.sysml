package ThermopileLaserSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		alias Power for ISQ::PowerValue;
		alias Voltage for ISQ::ElectricPotentialValue;
		alias Temperature for ISQ::TemperatureValue;
		alias Duration for ISQ::DurationValue;
		alias Frequency for ISQ::FrequencyValue;
		alias Length for ISQ::LengthValue;
		
		attribute def LaserBeam {
			power: Power;
			wavelength: Length;
		}
		
		attribute def VoltageSignal {
			voltage: Voltage;
		}
		
		attribute def DigitalSample {
			value: Integer;
			timestamp: Real;
		}
		
		attribute def PowerReading {
			power: Power;
			timestamp: Real;
			accuracy: Real;
		}
		
		attribute def CalibrationData {
			gain: Real;
			offset: Integer;
		}
		
		attribute def PowerOnSignal;
		attribute def WarmupCompleteSignal;
		attribute def MeasureRequestSignal;
		attribute def ReadingReadySignal;
		attribute def ShutdownSignal;
		
		port def OpticalInputPort {
			in beam: LaserBeam;
		}
		
		port def VoltageOutputPort {
			out signal: VoltageSignal;
		}
		
		port def VoltageInputPort {
			in signal: VoltageSignal;
		}
		
		port def DigitalOutputPort {
			out sample: DigitalSample;
		}
		
		port def DigitalInputPort {
			in sample: DigitalSample;
		}
		
		port def DataOutputPort {
			out reading: PowerReading;
		}
		
		part def ThermopileSensor {
			in port opticalInput: OpticalInputPort;
			out port voltageOutput: VoltageOutputPort;
			attribute surfaceTemperature: Temperature;
			attribute thermoelectricVoltage: Voltage;
			attribute absorptionEfficiency: Real;
			attribute thermoelectricCoefficient: Real;
			perform action generateVoltage: GenerateVoltage;
		}
		
		part def SignalAmplifier {
			in port voltageInput: VoltageInputPort;
			out port voltageOutput: VoltageOutputPort;
			attribute gainFactor: Real;
			attribute inputNoise: Voltage;
			perform action amplifySignal: AmplifySignal;
		}
		
		part def AnalogToDigitalConverter {
			in port analogInput: VoltageInputPort;
			out port digitalOutput: DigitalOutputPort;
			attribute sampleRate: Frequency;
			attribute resolution: Integer;
			attribute maxVoltage: Voltage;
			perform action convertSignal: ConvertSignal;
		}
		
		part def SignalProcessor {
			in port digitalInput: DigitalInputPort;
			out port dataOutput: DataOutputPort;
			attribute calibration: CalibrationData;
			attribute rawValue: Integer;
			attribute computedPower: Power;
			perform action computePower: ComputePower;
			perform action publishReading: PublishReading;
		}
		
		part def ThermopileUnit {
			part sensor: ThermopileSensor;
			part amplifier: SignalAmplifier;
			part adc: AnalogToDigitalConverter;
			part processor: SignalProcessor;
			in port opticalInput: OpticalInputPort;
			out port dataOutput: DataOutputPort;
			attribute minimumPower: Power;
			attribute maximumPower: Power;
			attribute requiredAccuracy: Real;
			attribute stabilizationTime: Duration;
			perform action measurementCycle: MeasurementCycle;
			exhibit state operationalStates: OperationalStates;
		}
		
		action def GenerateVoltage {
			in beam: LaserBeam;
			out voltage: VoltageSignal;
		}
		
		action def AmplifySignal {
			in inputSignal: VoltageSignal;
			in gain: Real;
			out outputSignal: VoltageSignal;
		}
		
		action def ConvertSignal {
			in analogSignal: VoltageSignal;
			in resolution: Integer;
			out digitalSample: DigitalSample;
		}
		
		action def ComputePower {
			in digitalValue: DigitalSample;
			in gainValue: Real;
			in offsetValue: Integer;
			out powerReading: PowerReading;
		}
		
		action def PublishReading {
			in reading: PowerReading;
			out publishedReading: PowerReading;
		}
		
		action def MeasurementCycle {
			in beam: LaserBeam;
			out reading: PowerReading;
		}
		
		action def ThermalStabilization;
		action def SystemCalibration;
		action def SystemShutdown;
		
		state def OperationalStates;
		
		requirement def PowerRangeRequirement {
			doc /* Measure laser power from 1 mW to 10 W */
			subject unit: ThermopileUnit;
			attribute minPower: Power;
			attribute maxPower: Power;
			require constraint {
				unit.minimumPower <= minPower and
				unit.maximumPower >= maxPower
			}
		}
		
		requirement def AccuracyRequirement {
			doc /* Measurement accuracy of ±3% */
			subject unit: ThermopileUnit;
			attribute maxError: Real;
			require constraint {
				unit.requiredAccuracy <= maxError
			}
		}
		
		requirement def ResponseTimeRequirement {
			doc /* Stable reading in under 1 second */
			subject unit: ThermopileUnit;
			attribute maxTime: Duration;
			require constraint {
				unit.stabilizationTime <= maxTime
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		action generateVoltage: GenerateVoltage;
		action amplifySignal: AmplifySignal;
		action convertSignal: ConvertSignal;
		action computePower: ComputePower;
		action publishReading: PublishReading;
		action thermalStabilization: ThermalStabilization;
		action systemCalibration: SystemCalibration;
		action systemShutdown: SystemShutdown;
		
		action measurementCycle: MeasurementCycle {
			in beam: LaserBeam;
			out reading: PowerReading;
			
			action generate: GenerateVoltage {
				in beam = measurementCycle::beam;
			}
			
			flow generate.voltage to amplify.inputSignal;
			
			action amplify: AmplifySignal {
				in gain = 1000.0;
			}
			
			flow amplify.outputSignal to convert.analogSignal;
			
			action convert: ConvertSignal {
				in resolution = 24;
			}
			
			flow convert.digitalSample to compute.digitalValue;
			
			action compute: ComputePower {
				in gainValue = 1.0;
				in offsetValue = 0;
			}
			
			flow compute.powerReading to publish.reading;
			
			action publish: PublishReading;
			
			bind reading = publish.publishedReading;
			
			first start;
			then generate;
			then amplify;
			then convert;
			then compute;
			then publish;
			then done;
		}
		
		state operationalStates: OperationalStates {
			entry action initialize;
			
			transition initialize then idle;
			
			state idle {
				entry assign unit.processor.rawValue := 0;
			}
			
			accept PowerOnSignal
				then warmup;
			
			state warmup {
				do action thermalStabilization;
				entry assign unit.sensor.surfaceTemperature := 298.15 [SI::K];
			}
			
			accept WarmupCompleteSignal
				do action systemCalibration
				then ready;
			
			state ready;
			
			transition startMeasurement
				first ready
				accept MeasureRequestSignal
				then measuring;
			
			state measuring {
				do action measurementCycle;
				
				state acquiring {
					do assign unit.sensor.thermoelectricVoltage := unit.sensor.thermoelectricVoltage;
				}
				then processing;
				
				state processing {
					do assign unit.processor.computedPower := unit.processor.computedPower;
				}
				then outputting;
				
				state outputting;
			}
			
			accept ReadingReadySignal
				then ready;
			
			accept ShutdownSignal
				do action systemShutdown
				then idle;
			
			transition emergencyShutdown
				first measuring
				accept ShutdownSignal
				do action systemShutdown
				then idle;
		}
		
		part unit: ThermopileUnit {
			:>> minimumPower = 0.001 [SI::W];
			:>> maximumPower = 10.0 [SI::W];
			:>> requiredAccuracy = 0.03;
			:>> stabilizationTime = 1.0 [SI::s];
			
			part sensor: ThermopileSensor {
				:>> surfaceTemperature = 298.15 [SI::K];
				:>> absorptionEfficiency = 0.98;
				:>> thermoelectricCoefficient = 0.00012;
			}
			
			part amplifier: SignalAmplifier {
				:>> gainFactor = 1000.0;
				:>> inputNoise = 0.000001 [SI::V];
			}
			
			part adc: AnalogToDigitalConverter {
				:>> sampleRate = 10000.0 [SI::Hz];
				:>> resolution = 24;
				:>> maxVoltage = 5.0 [SI::V];
			}
			
			part processor: SignalProcessor {
				:>> calibration.gain = 1.0;
				:>> calibration.offset = 0;
				:>> rawValue = 0;
			}
			
			bind opticalInput = sensor.opticalInput;
			connect sensor.voltageOutput to amplifier.voltageInput;
			connect amplifier.voltageOutput to adc.analogInput;
			connect adc.digitalOutput to processor.digitalInput;
			bind processor.dataOutput = dataOutput;
		}
		
		requirement powerRange: PowerRangeRequirement {
			subject unit = unit;
			:>> minPower = 0.001 [SI::W];
			:>> maxPower = 10.0 [SI::W];
		}
		
		requirement accuracy: AccuracyRequirement {
			subject unit = unit;
			:>> maxError = 0.03;
		}
		
		requirement responseTime: ResponseTimeRequirement {
			subject unit = unit;
			:>> maxTime = 1.0 [SI::s];
		}
	}
}
