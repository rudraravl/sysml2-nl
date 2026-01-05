package 'Variable Reluctance Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;
	
	attribute def MagneticFluxValue :> ISQ::MagneticFluxValue;
	
	attribute def VoltageAmplitudeValue :> ISQ::VoltageValue;
	
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	
	item def MagneticField {
		attribute fluxDensity: MagneticFluxValue;
	}
	
	item def AnalogSignal {
		attribute voltage: VoltageAmplitudeValue;
		attribute frequency: FrequencyValue;
	}
	
	item def DigitalSignal {
		attribute frequency: FrequencyValue;
		attribute dutyCycle: Real;
	}
	
	item def RotationalMotion {
		attribute angularVelocity: AngularVelocityValue;
		attribute numberOfTeeth: Integer;
	}
	
	port def MotionSensingPort {
		in item motion: RotationalMotion;
	}
	
	port def AnalogOutputPort {
		out item signal: AnalogSignal;
	}
	
	port def DigitalOutputPort {
		out item signal: DigitalSignal;
	}
	
	part def PermanentMagnet {
		attribute magneticStrength: MagneticFluxValue;
		out item magneticField: MagneticField;
	}
	
	part def PickupCoil {
		attribute numberOfTurns: Integer;
		attribute wireResistance: Real;
		in item changingFlux: MagneticField;
		out item inducedVoltage: AnalogSignal;
	}
	
	part def FerromagneticTarget {
		attribute numberOfTeeth: Integer;
		attribute toothPitch: ISQ::LengthValue;
		attribute airGap: ISQ::LengthValue;
		in item rotation: RotationalMotion;
		out item reluctanceVariation: MagneticFluxValue;
	}
	
	part def SignalConditioner {
		attribute amplificationGain: Real;
		attribute filterCutoffFrequency: FrequencyValue;
		in item rawSignal: AnalogSignal;
		out item conditionedSignal: DigitalSignal;
	}
	
	part def VariableReluctanceSensor {
		doc /*
		 * A variable reluctance sensor detects rotational motion by measuring
		 * changes in magnetic reluctance as ferromagnetic teeth pass near a
		 * permanent magnet and pickup coil assembly. The sensor generates an
		 * AC voltage signal whose frequency is proportional to rotational speed.
		 */
		
		port sensingInput: MotionSensingPort;
		port analogOutput: AnalogOutputPort;
		
		part magnet: PermanentMagnet[1] {
			attribute :>> magneticStrength = 0.8[SI::Wb];
		}
		
		part coil: PickupCoil[1] {
			attribute :>> numberOfTurns = 1000;
			attribute :>> wireResistance = 300.0;
		}
		
		part target: FerromagneticTarget[1] {
			attribute :>> numberOfTeeth = 60;
			attribute :>> toothPitch = 4.0[SI::mm];
			attribute :>> airGap = 0.5[SI::mm];
		}
		
		connection magneticCoupling connect magnet.magneticField to coil.changingFlux;
		connection targetInteraction connect target.reluctanceVariation to coil.changingFlux;
		connection motionInput connect sensingInput.motion to target.rotation;
		connection signalOutput connect coil.inducedVoltage to analogOutput.signal;
	}
	
	action def GenerateMagneticField {
		out item field: MagneticField;
	}
	
	action def ModulateReluctance {
		in item motion: RotationalMotion;
		in item magneticField: MagneticField;
		out item varyingFlux: MagneticFluxValue;
	}
	
	action def InduceVoltage {
		in item fluxChange: MagneticFluxValue;
		in item coilTurns: Integer;
		out item voltage: AnalogSignal;
	}
	
	action def AmplifyAndFilter {
		in item rawVoltage: AnalogSignal;
		in item gain: Real;
		out item cleanSignal: AnalogSignal;
	}
	
	action def ConvertToDigital {
		in item analogInput: AnalogSignal;
		out item digitalOutput: DigitalSignal;
	}
	
	action def SenseRotationalSpeed {
		in item rotationalInput: RotationalMotion;
		out item digitalOutput: DigitalSignal;
		
		action generateField: GenerateMagneticField {
			out item magneticField;
		}
		
		then action modulateFlux: ModulateReluctance {
			in item :>> motion = rotationalInput;
			in item :>> magneticField = generateField.magneticField;
			out item fluxVariation;
		}
		
		flow from generateField.magneticField to modulateFlux.magneticField;
		
		then action induceSignal: InduceVoltage {
			in item :>> fluxChange = modulateFlux.fluxVariation;
			in item coilTurns = 1000;
			out item rawSignal;
		}
		
		flow from modulateFlux.fluxVariation to induceSignal.fluxChange;
		
		then action amplify: AmplifyAndFilter {
			in item :>> rawVoltage = induceSignal.rawSignal;
			in item gain = 10.0;
			out item amplifiedSignal;
		}
		
		flow from induceSignal.rawSignal to amplify.rawVoltage;
		
		then action convert: ConvertToDigital {
			in item :>> analogInput = amplify.amplifiedSignal;
			out item :>> digitalOutput;
		}
		
		flow from amplify.amplifiedSignal to convert.analogInput;
		bind convert.digitalOutput = digitalOutput;
	}
	
	attribute def MotionDetected;
	attribute def MotionStopped;
	attribute def SignalAnomalyDetected;
	attribute def SystemReset;
	
	state def SensorOperatingStates {
		entry; then idle;
		
		state idle {
			doc /* Sensor is powered but no motion detected */
		}
		
		transition idleToSensing
			first idle
			accept MotionDetected
			then sensing;
		
		state sensing {
			doc /* Sensor is actively detecting rotational motion */
			entry action initializeMagneticField: GenerateMagneticField;
			do action continuousSensing: SenseRotationalSpeed;
		}
		
		transition sensingToIdle
			first sensing
			accept MotionStopped
			then idle;
		
		transition sensingToFault
			first sensing
			accept SignalAnomalyDetected
			then fault;
		
		state fault {
			doc /* Sensor has detected an anomaly or failure condition */
		}
		
		transition faultToIdle
			first fault
			accept SystemReset
			then idle;
	}
	
	part def SensingUnit {
		doc /*
		 * Complete sensing unit incorporating a variable reluctance sensor
		 * and signal conditioning circuitry for measuring rotational speed.
		 */
		
		port rotationInput: MotionSensingPort;
		port digitalOutput: DigitalOutputPort;
		
		part vrSensor: VariableReluctanceSensor[1];
		part conditioner: SignalConditioner[1] {
			attribute :>> amplificationGain = 10.0;
			attribute :>> filterCutoffFrequency = 5000.0[SI::Hz];
		}
		
		attribute measuredSpeed: AngularVelocityValue;
		attribute outputFrequency: FrequencyValue;
		
		connect rotationInput to vrSensor.sensingInput;
		connect vrSensor.analogOutput.signal to conditioner.rawSignal;
		connect conditioner.conditionedSignal to digitalOutput.signal;
		
		perform action sensingBehavior: SenseRotationalSpeed {
			in item :>> rotationalInput = rotationInput.motion;
			out item :>> digitalOutput = digitalOutput.signal;
		}
		
		exhibit state sensorState: SensorOperatingStates;
	}
	
	requirement def SensorPerformanceRequirement {
		doc /*
		 * Performance requirements for the variable reluctance sensor system.
		 */
		
		subject sensor: SensingUnit;
		
		require constraint frequencyRange {
			doc /* Sensor shall operate over frequency range 0 to 10 kHz */
			sensor.outputFrequency >= 0.0[SI::Hz] and
			sensor.outputFrequency <= 10000.0[SI::Hz]
		}
		
		require constraint speedRange {
			doc /* Sensor shall measure rotational speeds from 0 to 6000 RPM */
			sensor.measuredSpeed >= 0.0[SI::'rad/s'] and
			sensor.measuredSpeed <= 628.3[SI::'rad/s']
		}
		
		require constraint airGapTolerance {
			doc /* Sensor air gap shall be maintained between 0.3 mm and 1.0 mm */
			sensor.vrSensor.target.airGap >= 0.3[SI::mm] and
			sensor.vrSensor.target.airGap <= 1.0[SI::mm]
		}
	}
	
	requirement def SignalQualityRequirement {
		doc /*
		 * Signal quality requirements for conditioned output.
		 */
		
		subject unit: SensingUnit;
		
		require constraint minimumAmplitude {
			doc /* Conditioned signal amplitude shall exceed 2V peak-to-peak */
			true
		}
		
		require constraint signalToNoiseRatio {
			doc /* Signal-to-noise ratio shall exceed 40 dB */
			true
		}
	}
	
	requirement sensingUnitPerformance: SensorPerformanceRequirement {
		subject sensorUnderTest: SensingUnit;
	}
	
	requirement sensingUnitSignalQuality: SignalQualityRequirement {
		subject sensorUnderTest: SensingUnit;
	}
	
	part sensingUnitInstance: SensingUnit {
		satisfy sensingUnitPerformance by sensingUnitInstance;
		satisfy sensingUnitSignalQuality by sensingUnitInstance;
	}
	
	individual def TestRotation :> RotationalMotion;
	individual def TestSensingUnit :> SensingUnit;
	
	individual testUnit: TestSensingUnit :> sensingUnitInstance {
		timeslice lowSpeedTest {
			perform action :>> sensingBehavior {
				in individual :>> rotationalInput: TestRotation {
					:>> angularVelocity = 104.7[SI::'rad/s'];
					:>> numberOfTeeth = 60;
				}
			}
		}
		
		then timeslice mediumSpeedTest {
			perform action :>> sensingBehavior {
				in individual :>> rotationalInput: TestRotation {
					:>> angularVelocity = 314.2[SI::'rad/s'];
					:>> numberOfTeeth = 60;
				}
			}
		}
		
		then timeslice highSpeedTest {
			perform action :>> sensingBehavior {
				in individual :>> rotationalInput: TestRotation {
					:>> angularVelocity = 523.6[SI::'rad/s'];
					:>> numberOfTeeth = 60;
				}
			}
		}
	}
}
