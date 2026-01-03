package 'MEMS Magnetic Field Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensityValue;
		attribute xComponent : Real;
		attribute yComponent : Real;
		attribute zComponent : Real;
	}

	item def AnalogSignal {
		attribute voltage : VoltageValue;
		attribute timestamp : Real;
	}

	item def DigitalData {
		attribute xValue : Real;
		attribute yValue : Real;
		attribute zValue : Real;
		attribute timestamp : Real;
		attribute valid : Boolean;
	}

	item def PowerSupply {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}

	port def MagneticFieldInputPort {
		in item field : MagneticField;
	}

	port def AnalogOutputPort {
		out item signal : AnalogSignal;
	}

	port def DigitalOutputPort {
		out item data : DigitalData;
	}

	port def PowerInputPort {
		in item power : PowerSupply;
	}

	port def I2CPort {
		inout item data : DigitalData;
		attribute clockFrequency : FrequencyValue;
	}

	connection def AnalogConnection {
		end source : AnalogOutputPort[1];
		end destination : AnalogOutputPort[1];
	}

	connection def DigitalConnection {
		end source : DigitalOutputPort[1];
		end destination : DigitalOutputPort[1];
	}

	connection def PowerConnection {
		end supply : PowerInputPort[1];
		end load : PowerInputPort[1];
	}

	connection def I2CConnection {
		end controller : I2CPort[1];
		end peripheral : I2CPort[1];
	}

	part def MEMSMagneticSensor {
		attribute sensitivity : Real;
		attribute measurementRange : MagneticFluxDensityValue;
		attribute operatingTemperature : TemperatureValue;
		attribute offset : VoltageValue;

		port fieldInput : MagneticFieldInputPort;
		port analogOut : AnalogOutputPort;
		port powerIn : PowerInputPort;
	}

	part def SignalConditioner {
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		attribute offsetVoltage : VoltageValue;

		port analogIn : AnalogOutputPort;
		port conditionedOut : AnalogOutputPort;
		port powerIn : PowerInputPort;
	}

	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;

		port analogIn : AnalogOutputPort;
		port digitalOut : DigitalOutputPort;
		port powerIn : PowerInputPort;
	}

	state def SensorStateMachine {
		entry; then idle;

		state idle {
			entry action powerDown;
		}

		transition idle_to_init
			first idle
			accept InitCommand
			then initializing;

		state initializing {
			entry action loadCalibration;
			do action selfTest;
		}

		transition init_to_ready
			first initializing
			if selfTest.passed
			then ready;

		transition init_to_error
			first initializing
			if !selfTest.passed
			then error;

		state ready {
			entry action enableSensing;
		}

		transition ready_to_measuring
			first ready
			accept StartMeasurement
			then measuring;

		state measuring {
			do action continuousMeasurement;

			state normalOperation;

			transition to_saturation
				first normalOperation
				if fieldTooStrong
				then saturation;

			state saturation {
				entry action setWarningFlag;
			}

			transition saturation_to_normal
				first saturation
				if fieldNormal
				then normalOperation;
		}

		transition measuring_to_ready
			first measuring
			accept StopMeasurement
			then ready;

		transition ready_to_idle
			first ready
			accept ShutdownCommand
			then idle;

		state error {
			entry action reportError;
		}

		transition error_to_idle
			first error
			accept ResetCommand
			then idle;
	}

	part def Microcontroller {
		attribute processingFrequency : FrequencyValue;
		attribute memorySize : Integer;

		port digitalIn : DigitalOutputPort;
		port commPort : I2CPort;
		port powerIn : PowerInputPort;

		part controlStateMachine : SensorStateMachine;
	}

	part def VoltageRegulator {
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;

		port powerIn : PowerInputPort;
		port regulatedOut : PowerInputPort;
	}

	action def SenseMagneticField {
		in item ambientField : MagneticField;
		in sensitivity : Real;
		out item analogSignal : AnalogSignal;
	}

	action def ConditionSignal {
		in item rawSignal : AnalogSignal;
		in gain : Real;
		in offset : VoltageValue;
		out item conditionedSignal : AnalogSignal;
	}

	action def ConvertToDigital {
		in item analogInput : AnalogSignal;
		in resolution : Integer;
		in referenceVoltage : VoltageValue;
		out item digitalOutput : DigitalData;
	}

	action def CalibrateData {
		in item rawData : DigitalData;
		out item calibratedData : DigitalData;
		attribute offsetCorrection : Real[3];
		attribute gainCorrection : Real[3];
	}

	action def FilterData {
		in item inputData : DigitalData;
		out item filteredData : DigitalData;
		attribute filterCoefficients : Real[5];
	}

	action def CompensateTemperature {
		in item inputData : DigitalData;
		in temperature : TemperatureValue;
		out item compensatedData : DigitalData;
		attribute temperatureCoefficient : Real;
	}

	action def ProcessData {
		in item rawData : DigitalData;
		out item processedData : DigitalData;

		action calibrate : CalibrateData {
			in item :>> rawData;
			out item calibratedData;
		}
		succession flow from calibrate.calibratedData to filter.inputData;
		action filter : FilterData {
			in item inputData;
			out item filteredData;
		}
		succession flow from filter.filteredData to compensate.inputData;
		action compensate : CompensateTemperature {
			in item inputData;
			out item compensatedData;
		}
		bind compensate.compensatedData = processedData;
	}

	action def TransmitData {
		in item sensorData : DigitalData;
		out item transmittedData : DigitalData;
		attribute protocol : String;
		attribute deviceAddress : Integer;
	}

	action def RegulateVoltage {
		in item inputPower : PowerSupply;
		out item regulatedPower : PowerSupply;
		attribute dropoutVoltage : VoltageValue;
	}

	action def MeasurementCycle {
		in item magneticField : MagneticField;
		out item digitalData : DigitalData;

		action sense : SenseMagneticField {
			in item ambientField = magneticField;
			out item analogSignal;
		}
		succession flow from sense.analogSignal to condition.rawSignal;
		action condition : ConditionSignal {
			in item rawSignal;
			out item conditionedSignal;
		}
		succession flow from condition.conditionedSignal to convert.analogInput;
		action convert : ConvertToDigital {
			in item analogInput;
			out item digitalOutput;
		}
		succession flow from convert.digitalOutput to process.rawData;
		action process : ProcessData {
			in item rawData;
			out item processedData;
		}
		bind process.processedData = digitalData;
	}

	part def MagneticFieldSensingUnit {
		attribute unitId : String;
		attribute calibrationDate : String;

		port fieldSensor : MagneticFieldInputPort;
		port dataOutput : I2CPort;
		port powerInput : PowerInputPort;

		part memsSensor : MEMSMagneticSensor;
		part conditioner : SignalConditioner;
		part adc : AnalogToDigitalConverter;
		part mcu : Microcontroller;
		part regulator : VoltageRegulator;

		connection sensorToConditioner : AnalogConnection
			connect source references memsSensor.analogOut
			to destination references conditioner.analogIn;

		connection conditionerToADC : AnalogConnection
			connect source references conditioner.conditionedOut
			to destination references adc.analogIn;

		connection adcToMCU : DigitalConnection
			connect source references adc.digitalOut
			to destination references mcu.digitalIn;

		connection mcuToOutput : I2CConnection
			connect controller references mcu.commPort
			to peripheral references dataOutput;

		connection powerToRegulator : PowerConnection
			connect supply references powerInput
			to load references regulator.powerIn;

		connection regulatorToMCU : PowerConnection
			connect supply references regulator.regulatedOut
			to load references mcu.powerIn;
	}

	part sensingUnit : MagneticFieldSensingUnit {
		attribute :>> unitId = "MEMS-MAG-001";
		attribute :>> calibrationDate = "2025-01-15";

		part :>> memsSensor {
			attribute :>> sensitivity = 0.13;
			attribute :>> measurementRange = 800.0[uT];
			attribute :>> operatingTemperature = 25.0[degC];
			attribute :>> offset = 1.65[V];
		}

		part :>> conditioner {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 10.0[kHz];
			attribute :>> offsetVoltage = 0.0[mV];
		}

		part :>> adc {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1.0[kHz];
			attribute :>> referenceVoltage = 3.3[V];
		}

		part :>> mcu {
			attribute :>> processingFrequency = 48.0[MHz];
			attribute :>> memorySize = 256;
		}

		part :>> regulator {
			attribute :>> inputVoltage = 5.0[V];
			attribute :>> outputVoltage = 3.3[V];
			attribute :>> efficiency = 0.92;
		}
	}

	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure magnetic field with specified accuracy */
		subject unit : MagneticFieldSensingUnit;
		require constraint {
			unit.memsSensor.sensitivity >= 0.1 and
			unit.memsSensor.sensitivity <= 0.2
		}
	}

	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure magnetic fields within specified range */
		subject unit : MagneticFieldSensingUnit;
		require constraint {
			unit.memsSensor.measurementRange >= 500.0[uT]
		}
	}

	requirement def OperatingTemperatureRequirement {
		doc /* The sensing unit shall operate within industrial temperature range */
		subject unit : MagneticFieldSensingUnit;
		require constraint {
			unit.memsSensor.operatingTemperature >= -40.0[degC] and
			unit.memsSensor.operatingTemperature <= 85.0[degC]
		}
	}

	requirement def DataResolutionRequirement {
		doc /* The ADC shall provide sufficient resolution for accurate measurements */
		subject unit : MagneticFieldSensingUnit;
		require constraint {
			unit.adc.resolution >= 12
		}
	}

	requirement def PowerEfficiencyRequirement {
		doc /* The voltage regulator shall maintain high efficiency */
		subject unit : MagneticFieldSensingUnit;
		require constraint {
			unit.regulator.efficiency >= 0.85
		}
	}

	requirement sensingUnitRequirements {
		doc /* Top-level requirements for the MEMS magnetic field sensing unit */
		subject testUnit : MagneticFieldSensingUnit :> sensingUnit;

		requirement accuracyReq : MeasurementAccuracyRequirement {
			subject :>> unit = testUnit;
		}

		requirement rangeReq : MeasurementRangeRequirement {
			subject :>> unit = testUnit;
		}

		requirement tempReq : OperatingTemperatureRequirement {
			subject :>> unit = testUnit;
		}

		requirement resolutionReq : DataResolutionRequirement {
			subject :>> unit = testUnit;
		}

		requirement efficiencyReq : PowerEfficiencyRequirement {
			subject :>> unit = testUnit;
		}
	}

	individual def TestMagneticField :> MagneticField;
	individual def TestSensingUnit :> MagneticFieldSensingUnit;

	individual operationalTest : TestSensingUnit :> sensingUnit {
		timeslice initialization {
			perform action :>> mcu.controlStateMachine {
				entry;
			}
		}

		then timeslice measurement1 {
			perform action measurementCycle : MeasurementCycle {
				in individual :>> magneticField : TestMagneticField {
					attribute :>> fluxDensity = 250.0[uT];
					attribute :>> xComponent = 1.0;
					attribute :>> yComponent = 0.0;
					attribute :>> zComponent = 0.0;
				}
			}
		}

		then timeslice measurement2 {
			perform action measurementCycle : MeasurementCycle {
				in individual :>> magneticField : TestMagneticField {
					attribute :>> fluxDensity = 500.0[uT];
					attribute :>> xComponent = 0.707;
					attribute :>> yComponent = 0.707;
					attribute :>> zComponent = 0.0;
				}
			}
		}
	}
}
