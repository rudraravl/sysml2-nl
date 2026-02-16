package 'MEMS Accelerometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def AccelerationValue :> ISQ::AccelerationValue;
	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def CapacitanceValue :> ISQ::CapacitanceValue;
	attribute def DisplacementValue :> ISQ::LengthValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def SpringConstantValue :> Real;
	
	item def AccelerationData {
		attribute xAxis : AccelerationValue;
		attribute yAxis : AccelerationValue;
		attribute zAxis : AccelerationValue;
		attribute timestamp : ISQ::TimeValue;
		attribute valid : Boolean;
	}
	
	item def AnalogSignal {
		attribute voltage : VoltageValue;
		attribute frequency : FrequencyValue;
	}
	
	item def DigitalData {
		attribute rawValue : Integer;
		attribute resolution : Integer;
	}
	
	item def PowerSupply {
		attribute voltage : VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def MechanicalInputPort {
		in attribute appliedAcceleration : AccelerationValue;
		out attribute displacement : DisplacementValue;
	}
	
	port def CapacitiveOutputPort {
		out attribute capacitance : CapacitanceValue;
	}
	
	port def AnalogSignalPort {
		in item analogIn : AnalogSignal;
		out item analogOut : AnalogSignal;
	}
	
	port def DigitalOutputPort {
		out item digitalData : DigitalData;
	}
	
	port def PowerInputPort {
		in item power : PowerSupply;
	}
	
	port def DataInterfacePort {
		out item accelerationData : AccelerationData;
	}
	
	part def ProofMass {
		attribute mass : MassValue;
		attribute currentDisplacement : DisplacementValue;
		port mechanicalPort : MechanicalInputPort;
	}
	
	part def SpringSuspension {
		attribute springConstant : SpringConstantValue;
		attribute dampingCoefficient : Real;
		attribute naturalFrequency : FrequencyValue;
	}
	
	part def CapacitivePlates {
		attribute nominalCapacitance : CapacitanceValue;
		attribute plateArea : ISQ::AreaValue;
		attribute gapDistance : ISQ::LengthValue;
		port capacitivePort : CapacitiveOutputPort;
	}
	
	part def SensingElement {
		port mechanicalInput : MechanicalInputPort;
		port capacitiveOutput : CapacitiveOutputPort;
		
		part proofMass : ProofMass;
		part suspension : SpringSuspension;
		part fixedPlate : CapacitivePlates;
		part movablePlate : CapacitivePlates;
		
		connect proofMass.mechanicalPort to mechanicalInput;
		connect movablePlate.capacitivePort to capacitiveOutput;
	}
	
	part def ChargeAmplifier {
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		attribute noiseFloor : VoltageValue;
		port capacitiveInput : CapacitiveOutputPort;
		port analogOutput : AnalogSignalPort;
	}
	
	part def LowPassFilter {
		attribute cutoffFrequency : FrequencyValue;
		attribute filterOrder : Integer;
		port analogInput : AnalogSignalPort;
		port analogOutput : AnalogSignalPort;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;
		port analogInput : AnalogSignalPort;
		port digitalOutput : DigitalOutputPort;
	}
	
	part def DigitalSignalProcessor {
		attribute calibrationOffsetX : AccelerationValue;
		attribute calibrationOffsetY : AccelerationValue;
		attribute calibrationOffsetZ : AccelerationValue;
		attribute scaleFactor : Real;
		port digitalInput : DigitalOutputPort;
		port dataOutput : DataInterfacePort;
	}
	
	part def VoltageRegulator {
		attribute inputVoltageRange : VoltageValue[2];
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
		port powerIn : PowerInputPort;
		port powerOut : PowerInputPort;
	}
	
	state def AccelerometerOperationalState {
		entry action initializeSystem;
		
		state powerOff;
		state initialization;
		state selfTest;
		state idle;
		state continuousMeasurement;
		state dataProcessing;
		state dataTransmission;
		state lowPowerMode;
		state errorState;
		
		transition first powerOff;
		
		transition powerUp
			first powerOff
			accept PowerOnEvent
			then initialization;
		
		transition initComplete
			first initialization
			if systemReady
			then selfTest;
		
		transition testPassed
			first selfTest
			if testSuccessful
			then idle;
		
		transition testFailed
			first selfTest
			if not testSuccessful
			then errorState;
		
		transition startMeasurement
			first idle
			accept MeasurementTrigger
			then continuousMeasurement;
		
		transition measurementComplete
			first continuousMeasurement
			then dataProcessing;
		
		transition processingComplete
			first dataProcessing
			then dataTransmission;
		
		transition transmissionComplete
			first dataTransmission
			then idle;
		
		transition enterLowPower
			first idle
			accept LowPowerCommand
			then lowPowerMode;
		
		transition exitLowPower
			first lowPowerMode
			accept WakeUpEvent
			then idle;
		
		transition errorDetected
			first continuousMeasurement
			accept ErrorEvent
			then errorState;
		
		transition errorRecovery
			first errorState
			accept ResetCommand
			then initialization;
	}
	
	action def MeasureDisplacement {
		in appliedAcceleration : AccelerationValue;
		in proofMassValue : MassValue;
		in springConstant : SpringConstantValue;
		out displacement : DisplacementValue;
	}
	
	action def ConvertDisplacementToCapacitance {
		in displacement : DisplacementValue;
		in nominalCapacitance : CapacitanceValue;
		in nominalGap : ISQ::LengthValue;
		out capacitance : CapacitanceValue;
	}
	
	action def AmplifySignal {
		in inputCapacitance : CapacitanceValue;
		in amplifierGain : Real;
		out outputVoltage : VoltageValue;
	}
	
	action def FilterSignal {
		in inputSignal : AnalogSignal;
		in cutoffFreq : FrequencyValue;
		out filteredSignal : AnalogSignal;
	}
	
	action def DigitizeSignal {
		in analogVoltage : VoltageValue;
		in adcResolution : Integer;
		in referenceVoltage : VoltageValue;
		out digitalValue : Integer;
	}
	
	action def CalibrateAndScale {
		in rawDigitalValue : Integer;
		in offset : AccelerationValue;
		in scale : Real;
		out calibratedAcceleration : AccelerationValue;
	}
	
	action def PerformSelfTest {
		out testResult : Boolean;
	}
	
	action def AccelerationMeasurementCycle {
		in externalAcceleration : AccelerationValue;
		in systemMass : MassValue;
		in systemSpringConstant : SpringConstantValue;
		in systemGain : Real;
		in systemOffset : AccelerationValue;
		in systemScale : Real;
		out finalAccelerationData : AccelerationData;
		
		first start;
		
		then action measureDisp : MeasureDisplacement {
			in appliedAcceleration = externalAcceleration;
			in proofMassValue = systemMass;
			in springConstant = systemSpringConstant;
			out displacement;
		}
		
		then action convertCap : ConvertDisplacementToCapacitance {
			in displacement = measureDisp.displacement;
			in nominalCapacitance = 10.0 [pF];
			in nominalGap = 2.0 [um];
			out capacitance;
		}
		
		then action amplify : AmplifySignal {
			in inputCapacitance = convertCap.capacitance;
			in amplifierGain = systemGain;
			out outputVoltage;
		}
		
		then action filter : FilterSignal {
			in inputSignal = AnalogSignal {
				voltage = amplify.outputVoltage;
				frequency = 1000.0 [Hz];
			};
			in cutoffFreq = 500.0 [Hz];
			out filteredSignal;
		}
		
		then action digitize : DigitizeSignal {
			in analogVoltage = filter.filteredSignal.voltage;
			in adcResolution = 16;
			in referenceVoltage = 3.3 [V];
			out digitalValue;
		}
		
		then action calibrate : CalibrateAndScale {
			in rawDigitalValue = digitize.digitalValue;
			in offset = systemOffset;
			in scale = systemScale;
			out calibratedAcceleration;
		}
		
		then assign finalAccelerationData := AccelerationData {
			xAxis = calibrate.calibratedAcceleration;
			yAxis = 0.0 [m/s^2];
			zAxis = 0.0 [m/s^2];
			timestamp = 0.0 [s];
			valid = true;
		};
		
		then done;
	}
	
	part def ThreeAxisMEMSAccelerometer {
		doc /* 
		A three-axis MEMS accelerometer system that measures linear acceleration 
		in three orthogonal directions. The system uses capacitive sensing to detect 
		displacement of suspended proof masses, converts the mechanical motion into 
		electrical signals, and provides calibrated digital acceleration data.
		*/
		
		port externalPower : PowerInputPort;
		port accelerationOutput : DataInterfacePort;
		
		part xAxisSensor : SensingElement;
		part yAxisSensor : SensingElement;
		part zAxisSensor : SensingElement;
		
		part xAxisAmplifier : ChargeAmplifier {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 1000.0 [Hz];
			attribute :>> noiseFloor = 0.001 [V];
		}
		
		part yAxisAmplifier : ChargeAmplifier {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 1000.0 [Hz];
			attribute :>> noiseFloor = 0.001 [V];
		}
		
		part zAxisAmplifier : ChargeAmplifier {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 1000.0 [Hz];
			attribute :>> noiseFloor = 0.001 [V];
		}
		
		part xAxisFilter : LowPassFilter {
			attribute :>> cutoffFrequency = 500.0 [Hz];
			attribute :>> filterOrder = 4;
		}
		
		part yAxisFilter : LowPassFilter {
			attribute :>> cutoffFrequency = 500.0 [Hz];
			attribute :>> filterOrder = 4;
		}
		
		part zAxisFilter : LowPassFilter {
			attribute :>> cutoffFrequency = 500.0 [Hz];
			attribute :>> filterOrder = 4;
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 8000.0 [Hz];
			attribute :>> referenceVoltage = 3.3 [V];
		}
		
		part dsp : DigitalSignalProcessor {
			attribute :>> calibrationOffsetX = 0.0 [m/s^2];
			attribute :>> calibrationOffsetY = 0.0 [m/s^2];
			attribute :>> calibrationOffsetZ = 0.0 [m/s^2];
			attribute :>> scaleFactor = 1.0;
		}
		
		part regulator : VoltageRegulator {
			attribute :>> inputVoltageRange = (2.5 [V], 5.5 [V]);
			attribute :>> outputVoltage = 1.8 [V];
			attribute :>> efficiency = 0.85;
		}
		
		connect xAxisSensor.capacitiveOutput to xAxisAmplifier.capacitiveInput;
		connect xAxisAmplifier.analogOutput to xAxisFilter.analogInput;
		connect xAxisFilter.analogOutput to adc.analogInput;
		
		connect yAxisSensor.capacitiveOutput to yAxisAmplifier.capacitiveInput;
		connect yAxisAmplifier.analogOutput to yAxisFilter.analogInput;
		
		connect zAxisSensor.capacitiveOutput to zAxisAmplifier.capacitiveInput;
		connect zAxisAmplifier.analogOutput to zAxisFilter.analogInput;
		
		connect adc.digitalOutput to dsp.digitalInput;
		connect dsp.dataOutput to accelerationOutput;
		
		connect externalPower to regulator.powerIn;
		
		exhibit state operationalBehavior : AccelerometerOperationalState;
		
		perform action measurementCycle[*] ordered references AccelerationMeasurementCycle;
	}
	
	part memsAccelerometer : ThreeAxisMEMSAccelerometer;
	
	requirement def MeasurementRangeRequirement {
		doc /* The accelerometer shall measure acceleration within a specified range. */
		attribute minRange : AccelerationValue;
		attribute maxRange : AccelerationValue;
	}
	
	requirement def AccuracyRequirement {
		doc /* The accelerometer shall provide measurements with specified accuracy. */
		attribute maxError : AccelerationValue;
		attribute temperatureDrift : Real;
	}
	
	requirement def BandwidthRequirement {
		doc /* The accelerometer shall operate over a specified frequency bandwidth. */
		attribute minFrequency : FrequencyValue;
		attribute maxFrequency : FrequencyValue;
	}
	
	requirement def PowerRequirement {
		doc /* The accelerometer shall operate within specified power constraints. */
		attribute maxPowerConsumption : ISQ::PowerValue;
		attribute operatingVoltageRange : VoltageValue[2];
	}
	
	requirement def NoiseRequirement {
		doc /* The accelerometer shall maintain noise below specified levels. */
		attribute maxNoiseDensity : Real;
	}
	
	requirement def EnvironmentalRequirement {
		doc /* The accelerometer shall operate within environmental limits. */
		attribute minTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute maxShockTolerance : AccelerationValue;
	}
	
	requirement <'MEMS-ACC-001'> primaryFunctionRequirement {
		doc /* 
		The MEMS accelerometer system shall measure three-axis linear acceleration 
		by detecting capacitive changes caused by proof mass displacement, and provide 
		calibrated digital acceleration data for motion sensing, vibration monitoring, 
		and inertial navigation applications.
		*/
		
		subject accelerometerSystem : ThreeAxisMEMSAccelerometer;
		
		require rangeReq : MeasurementRangeRequirement {
			attribute :>> minRange = -20.0 [m/s^2];
			attribute :>> maxRange = 20.0 [m/s^2];
		}
		
		require accuracyReq : AccuracyRequirement {
			attribute :>> maxError = 0.05 [m/s^2];
			attribute :>> temperatureDrift = 0.001;
		}
		
		require bandwidthReq : BandwidthRequirement {
			attribute :>> minFrequency = 0.0 [Hz];
			attribute :>> maxFrequency = 1000.0 [Hz];
		}
		
		require powerReq : PowerRequirement {
			attribute :>> maxPowerConsumption = 0.5 [mW];
			attribute :>> operatingVoltageRange = (2.5 [V], 5.5 [V]);
		}
		
		require noiseReq : NoiseRequirement {
			attribute :>> maxNoiseDensity = 100.0;
		}
		
		require envReq : EnvironmentalRequirement {
			attribute :>> minTemperature = 233.15 [K];
			attribute :>> maxTemperature = 358.15 [K];
			attribute :>> maxShockTolerance = 1000.0 [m/s^2];
		}
	}
}
