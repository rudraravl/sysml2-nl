package TemperatureMonitoringSystem {
	import ScalarValues::*;
	import ISQ::*;
	import ISQSpaceTime::*;
	import ISQElectromagnetism::*;

	// ===== Value Types =====

	value type ResistanceValue :> Real {
		:>> unit = ISQ::ohm;
	}

	value type VoltageValue :> Real {
		:>> unit = ISQ::volt;
	}

	value type TemperatureValue :> Real {
		:>> unit = ISQ::Celsius;
	}

	value type DigitalCount :> Integer;

	value type GainValue :> Real;

	value type FrequencyValue :> Real {
		:>> unit = ISQ::hertz;
	}

	value type PowerValue :> Real {
		:>> unit = ISQ::watt;
	}

	// ===== Item Types =====

	item def RawVoltageSignal {
		attribute voltage : VoltageValue;
	}

	item def ConditionedVoltageSignal {
		attribute voltage : VoltageValue;
		attribute noiseFloor : VoltageValue;
	}

	item def DigitalSample {
		attribute count : DigitalCount;
		attribute resolutionBits : Integer;
		attribute timestamp : TimeValue;
	}

	item def TemperatureReading {
		attribute temperature : TemperatureValue;
		attribute calibrated : Boolean;
		attribute timestamp : TimeValue;
		attribute outOfRange : Boolean;
	}

	item def CalibrationData {
		attribute offset : TemperatureValue;
		attribute scale : Real;
		attribute referenceTemp : TemperatureValue;
	}

	item def PowerRail {
		attribute railVoltage : VoltageValue;
		attribute railCurrent : CurrentValue;
		attribute railName : String;
	}

	item def StatusMessage {
		attribute code : String;
		attribute severity : String;
		attribute description : String;
	}

	value type CurrentValue :> Real {
		:>> unit = ISQ::ampere;
	}

	value type TimeValue :> Real {
		:>> unit = ISQ::second;
	}

	// ===== Port Definitions =====

	port def ResistancePort {
		out attribute resistance : ResistanceValue;
	}

	port def AnalogVoltagePort {
		out attribute signal : RawVoltageSignal;
	}

	port def ConditionedVoltagePort {
		out attribute signal : ConditionedVoltageSignal;
	}

	port def DigitalDataPort {
		out attribute sample : DigitalSample;
	}

	port def TemperatureDataPort {
		out attribute reading : TemperatureReading;
		in attribute command : String;
	}

	port def PowerInputPort {
		in attribute rail : PowerRail;
	}

	port def PowerOutputPort {
		out attribute rail : PowerRail;
	}

	port def ExternalPowerPort {
		in attribute inputVoltage : VoltageValue;
		in attribute inputCurrent : CurrentValue;
	}

	port def StatusPort {
		out attribute status : StatusMessage;
	}

	// ===== Part Definitions =====

	part def NTCThermistor {
		port resistanceOut : ResistancePort;
		port powerIn : PowerInputPort;

		attribute nominalResistance : ResistanceValue = 10000 [ohm];
		attribute betaParameter : Real = 3950;
		attribute referenceTemperature : TemperatureValue = 25 [degC];
		attribute minOperatingTemp : TemperatureValue = -40 [degC];
		attribute maxOperatingTemp : TemperatureValue = 125 [degC];

		attribute currentResistance : ResistanceValue;

		private attribute currentTemp : TemperatureValue;

		action computeResistance
		{
			in temp : TemperatureValue;
			out resistance : ResistanceValue;
		}

		action UpdateResistance {
			in temp : TemperatureValue;
			then ComputeR;
		}

		action ComputeR {
			// R = R0 * exp(B * (1/T - 1/T0))
		}
	}

	part def VoltageDividerCircuit {
		port voltageOut : AnalogVoltagePort;
		port powerIn : PowerInputPort;

		part thermistor : NTCThermistor;
		part fixedResistor {
			attribute resistance : ResistanceValue = 10000 [ohm];
		}

		attribute supplyVoltage : VoltageValue = 3.3 [V];
		attribute dividerRatio : Real;

		action GenerateVoltage {
			in resistance : ResistanceValue;
			out signal : RawVoltageSignal;
		}
	}

	part def SignalConditioner {
		port analogIn : AnalogVoltagePort;
		port conditionedOut : ConditionedVoltagePort;
		port powerIn : PowerInputPort;

		attribute gain : GainValue = 2.0;
		attribute cutoffFrequency : FrequencyValue = 100 [Hz];
		attribute offsetVoltage : VoltageValue = 0 [V];

		part amplifier {
			attribute gain : GainValue = 2.0;
		}

		part lowPassFilter {
			attribute cutoff : FrequencyValue = 100 [Hz];
			attribute order : Integer = 2;
		}

		action AmplifyAndFilter {
			in rawSignal : RawVoltageSignal;
			out conditionedSignal : ConditionedVoltageSignal;
		}
	}

	part def AnalogToDigitalConverter {
		port analogIn : ConditionedVoltagePort;
		port digitalOut : DigitalDataPort;
		port powerIn : PowerInputPort;

		attribute resolutionBits : Integer = 12;
		attribute samplingRate : FrequencyValue = 1000 [Hz];
		attribute referenceVoltage : VoltageValue = 3.3 [V];
		attribute lsbValue : VoltageValue;

		action SampleAndConvert {
			in conditionedSignal : ConditionedVoltageSignal;
			out digitalSample : DigitalSample;
		}
	}

	part def Microcontroller {
		port digitalIn : DigitalDataPort;
		port tempOut : TemperatureDataPort;
		port powerIn : PowerInputPort;
		port statusOut : StatusPort;

		attribute clockFrequency : FrequencyValue = 16000000 [Hz];
		attribute calibrationData : CalibrationData;
		attribute lowerTempLimit : TemperatureValue = -40 [degC];
		attribute upperTempLimit : TemperatureValue = 125 [degC];
		attribute lastReading : TemperatureReading;

		part processor {
			attribute architecture : String = "ARM Cortex-M0+";
		}

		part memory {
			attribute flashSize : Integer = 65536;
			attribute ramSize : Integer = 8192;
		}

		action ConvertToTemperature {
			in sample : DigitalSample;
			out reading : TemperatureReading;
		}

		action ApplyCalibration {
			in reading : TemperatureReading;
			in calib : CalibrationData;
			out calibratedReading : TemperatureReading;
		}

		action CheckRange {
			in reading : TemperatureReading;
			out outOfRange : Boolean;
		}

		action ProcessSample {
			in sample : DigitalSample;
			then Convert;
			then Calibrate;
			then RangeCheck;
			then SendOutput;
		}

		action Convert {
			in sample : DigitalSample;
			out reading : TemperatureReading;
		}

		action Calibrate {
			in reading : TemperatureReading;
			out calibratedReading : TemperatureReading;
		}

		action RangeCheck {
			in reading : TemperatureReading;
			out outOfRange : Boolean;
		}

		action SendOutput {
			in reading : TemperatureReading;
		}
	}

	part def OutputInterface {
		port tempIn : TemperatureDataPort;
		port powerIn : PowerInputPort;

		part display {
			attribute type : String = "LCD";
			attribute width : Integer = 16;
			attribute height : Integer = 2;
		}

		part communicationPort {
			attribute protocol : String = "UART";
			attribute baudRate : FrequencyValue = 9600 [Hz];
		}

		action DisplayTemperature {
			in reading : TemperatureReading;
		}

		action TransmitTemperature {
			in reading : TemperatureReading;
		}

		action OutputData {
			in reading : TemperatureReading;
			then DisplayTemperature;
			then TransmitTemperature;
		}
	}

	part def PowerManagementUnit {
		port externalPowerIn : ExternalPowerPort;
		port powerOut : PowerOutputPort;
		port statusOut : StatusPort;

		attribute outputVoltage : VoltageValue = 3.3 [V];
		attribute maxOutputCurrent : CurrentValue = 2.0 [A];
		attribute efficiency : Real = 0.90;
		attribute inputVoltageRange : VoltageValue[2] = (3.0 [V], 15.0 [V]);

		part voltageRegulator {
			attribute type : String = "Buck-Boost";
			attribute nominalOutput : VoltageValue = 3.3 [V];
		}

	part powerFilter {
			attribute capacitance : Real = 100e-6;
		}

		part currentLimiter {
			attribute limit : CurrentValue = 2.0 [A];
		}

		action RegulatePower {
			in inputVoltage : VoltageValue;
			out rail : PowerRail;
		}

		action MonitorPower {
			in rail : PowerRail;
			out status : StatusMessage;
		}
	}

	// ===== State Machine =====

	state def SystemStateMachine {
		entry; then Initializing;

		state Initializing {
			entry action InitializeSystem {
				// Power on all components
				// Load calibration data
				// Configure ADC sampling rate
				// Set up microcontroller peripherals
			}
			then SelfTest;
		}

		state SelfTest {
			entry action RunSelfTest {
				// Check thermistor connectivity
				// Verify ADC conversion
				// Validate calibration data
			}

			action CheckThermistor;
			action CheckADC;
			action CheckCalibration;

			transition if selfTestPassed then Measuring;
			transition if selfTestFailed then ErrorState;
		}

		state Measuring {
			entry action StartMeasurement {
				// Read thermistor resistance
				// Generate voltage via divider
			}

			action ReadThermistor;
			action GenerateVoltage;
			action ConditionSignal;
			action SampleADC;

			transition if sampleReady then Processing;
		}

		state Processing {
			entry action ProcessData {
				// Convert digital count to temperature
				// Apply calibration
				// Check range
			}

			action ConvertTemperature;
			action ApplyCalibrationAdjustment;
			action ValidateRange;

			transition if readingValid then Outputting;
			transition if readingOutOfRange then ErrorState;
		}

		state Outputting {
			entry action SendOutput {
				// Send to display
				// Send to communication port
			}

			action DisplayReading;
			action TransmitReading;

			transition if calibrationRequested then CalibrationMode;
			transition if continuousMode then Measuring;
		}

		state CalibrationMode {
			entry action EnterCalibration {
				// Apply known reference temperature
				// Adjust offset and scale
			}

			action MeasureReference;
			action CalculateOffset;
			action StoreCalibration;

			transition if calibrationComplete then Measuring;
		}

		state ErrorState {
			entry action HandleError {
				// Log error
				// Attempt recovery
			}

			action LogError;
			action AttemptRecovery;

			transition if recoverySuccessful then Initializing;
			transition if recoveryFailed then Off;
		}

		state Off;

		attribute selfTestPassed : Boolean;
		attribute selfTestFailed : Boolean;
		attribute sampleReady : Boolean;
		attribute readingValid : Boolean;
		attribute readingOutOfRange : Boolean;
		attribute calibrationRequested : Boolean;
		attribute continuousMode : Boolean;
		attribute calibrationComplete : Boolean;
		attribute recoverySuccessful : Boolean;
		attribute recoveryFailed : Boolean;
	}

	// ===== Top-Level System =====

	part def TemperatureMonitoringSystem {
		port externalPower : ExternalPowerPort;
		port dataOutput : TemperatureDataPort;
		port systemStatus : StatusPort;

		part powerManagement : PowerManagementUnit;
		part voltageDivider : VoltageDividerCircuit;
		part signalConditioner : SignalConditioner;
		part adc : AnalogToDigitalConverter;
		part microcontroller : Microcontroller;
		part outputInterface : OutputInterface;

		// Power distribution connections
		connection powerToDivider connect powerManagement.powerOut to voltageDivider.powerIn;
		connection powerToConditioner connect powerManagement.powerOut to signalConditioner.powerIn;
		connection powerToADC connect powerManagement.powerOut to adc.powerIn;
		connection powerToMCU connect powerManagement.powerOut to microcontroller.powerIn;
		connection powerToOutput connect powerManagement.powerOut to outputInterface.powerIn;

		// Signal chain connections
		connection resistanceToDivider connect voltageDivider.thermistor.resistanceOut to voltageDivider.voltageOut;
		connection rawSignalToConditioner connect voltageDivider.voltageOut to signalConditioner.analogIn;
		connection conditionedToADC connect signalConditioner.conditionedOut to adc.analogIn;
		connection digitalToMCU connect adc.digitalOut to microcontroller.digitalIn;
		connection tempToOutput connect microcontroller.tempOut to outputInterface.tempIn;
		connection outputToExternal connect outputInterface.tempIn to dataOutput;

		// External power connection
		connection externalPowerToPMU connect externalPower to powerManagement.externalPowerIn;

		// Status connection
		connection statusToExternal connect powerManagement.statusOut to systemStatus;
		connection mcuStatusToExternal connect microcontroller.statusOut to systemStatus;

		// System behavior
		state systemBehavior : SystemStateMachine;

		attribute samplingInterval : TimeValue = 0.1 [s];
		attribute systemActive : Boolean = true;
		attribute measurementCount : Integer = 0;

		action ContinuousOperation {
			loop {
				action MeasureCycle {
					then ProcessCycle;
				}
				action ProcessCycle {
					then OutputCycle;
				}
				action OutputCycle {
					then MeasureCycle;
				}
			}
		}
	}

	// ===== Requirements =====

	requirement def TemperatureAccuracyRequirement {
		documentation
		'''
		The system shall measure ambient temperature with an accuracy of
		plus or minus 1 degree Celsius over the range of -40 to 125 degrees Celsius.
		''';
		attribute accuracy : TemperatureValue = 1 [degC];
		attribute minRange : TemperatureValue = -40 [degC];
		attribute maxRange : TemperatureValue = 125 [degC];
	}

	requirement def SamplingRateRequirement {
		documentation
		'''
		The system shall sample temperature at a minimum rate of 10 samples per second.
		''';
		attribute minSamplingRate : FrequencyValue = 10 [Hz];
	}

	requirement def PowerStabilityRequirement {
		documentation
		'''
		The power management unit shall provide a stable 3.3V output
		with less than 50mV ripple across all operating conditions.
		''';
		attribute nominalVoltage : VoltageValue = 3.3 [V];
		attribute maxRipple : VoltageValue = 0.05 [V];
	}

	requirement def OutOfRangeDetectionRequirement {
		documentation
		'''
		The system shall detect and flag temperature readings outside
		the valid operating range and transition to an error state.
		''';
		attribute lowerLimit : TemperatureValue = -40 [degC];
		attribute upperLimit : TemperatureValue = 125 [degC];
	}

	requirement def SelfTestRequirement {
		documentation
		'''
		The system shall perform a self-test upon initialization
		and report any detected faults via the status port.
		''';
		attribute selfTestTimeout : TimeValue = 5 [s];
	}

	requirement def CalibrationRequirement {
		documentation
		'''
		The system shall support a calibration mode in which
		calibration offset and scale factors can be adjusted
		using a known reference temperature.
		''';
		attribute referenceTempAccuracy : TemperatureValue = 0.1 [degC];
	}

	requirement def ContinuousOperationRequirement {
		documentation
		'''
		The system shall operate in a continuous cycle of
		measuring, processing, and outputting temperature data.
		''';
		attribute continuousMode : Boolean = true;
	}

	// ===== Requirement Satisfaction =====

	satisfy TemperatureAccuracyRequirement by TemperatureMonitoringSystem;
	satisfy SamplingRateRequirement by TemperatureMonitoringSystem::adc;
	satisfy PowerStabilityRequirement by TemperatureMonitoringSystem::powerManagement;
	satisfy OutOfRangeDetectionRequirement by TemperatureMonitoringSystem::microcontroller;
	satisfy SelfTestRequirement by TemperatureMonitoringSystem;
	satisfy CalibrationRequirement by TemperatureMonitoringSystem::microcontroller;
	satisfy ContinuousOperationRequirement by TemperatureMonitoringSystem;
}
