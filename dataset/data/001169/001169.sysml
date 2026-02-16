package 'OxygenSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def OxygenConcentrationValue :> RatioValue {
		attribute :>> num: Real;
		attribute :>> mRef: RatioUnit;
	}

	attribute def VoltageValue :> ElectricPotentialValue {
		attribute :>> num: Real;
		attribute :>> mRef: ElectricPotentialUnit;
	}

	attribute def TemperatureValue :> ThermodynamicTemperatureValue {
		attribute :>> num: Real;
		attribute :>> mRef: ThermodynamicTemperatureUnit;
	}

	attribute def CurrentValue :> ElectricCurrentValue {
		attribute :>> num: Real;
		attribute :>> mRef: ElectricCurrentUnit;
	}

	item def GasSample {
		attribute oxygenLevel: OxygenConcentrationValue;
		attribute temperature: TemperatureValue;
		attribute pressure: PressureValue;
	}

	item def SensorSignal {
		attribute voltage: VoltageValue;
		attribute current: CurrentValue;
		attribute timestamp: Real;
	}

	item def OxygenReading {
		attribute concentration: OxygenConcentrationValue;
		attribute confidence: Real;
		attribute timestamp: Real;
		attribute status: SensorStatus;
	}

	enum def SensorStatus {
		enum initializing;
		enum warmingUp;
		enum ready;
		enum measuring;
		enum calibrating;
		enum error;
	}

	port def GasIntakePort {
		in item sample: GasSample;
	}

	port def AnalogSignalPort {
		out item signal: SensorSignal;
	}

	port def DigitalSignalPort {
		in item signal: SensorSignal;
	}

	port def DataOutputPort {
		out item reading: OxygenReading;
	}

	port def PowerPort {
		in attribute voltage: VoltageValue;
		in attribute current: CurrentValue;
	}

	connection def SignalConnection {
		end source: AnalogSignalPort;
		end target: DigitalSignalPort;
	}

	part def SensingElement {
		attribute material: String;
		attribute surfaceArea: Real;
	}

	part def HeatingElement {
		attribute targetTemp: TemperatureValue;
		attribute currentTemp: TemperatureValue;
		attribute powerConsumption: Real;
	}

	part def SignalAmplifier {
		attribute gain: Real;
		attribute offset: VoltageValue;
	}

	part def ZirconiaOxygenSensor {
		attribute sensorID: String;
		attribute operatingTemp: TemperatureValue;
		attribute heaterPower: Real;
		attribute calibrationCoefficient: Real;
		attribute status: SensorStatus;

		port gasInlet: GasIntakePort;
		port analogOutput: AnalogSignalPort;
		port power: PowerPort;

		part sensingElement: SensingElement {
			attribute material: String = "Zirconia";
			attribute surfaceArea: Real;
		}

		part heatingElement: HeatingElement {
			attribute targetTemp: TemperatureValue;
			attribute currentTemp: TemperatureValue;
			attribute powerConsumption: Real;
		}

		part signalAmplifier: SignalAmplifier {
			attribute gain: Real = 10.0;
			attribute offset: VoltageValue;
		}

		state machine sensorLifecycle {
			entry; then initialization;

			state initialization {
				entry action assignInitStatus {
					assign status = SensorStatus::initializing;
				}
			}

			transition init_to_warmup
				first initialization
				accept PowerApplied
				then warmup;

			state warmup {
				entry action assignWarmupStatus {
					assign status = SensorStatus::warmingUp;
				}
				do action heatUp: HeatSensor {
					in targetTemp = heatingElement.targetTemp;
					out currentTemp = heatingElement.currentTemp;
				}
			}

			transition warmup_to_ready
				first warmup
				accept TemperatureStabilized
				then ready;

			state ready {
				entry action assignReadyStatus {
					assign status = SensorStatus::ready;
				}
			}

			transition ready_to_measuring
				first ready
				accept MeasurementRequest
				then measuring;

			state measuring {
				entry action assignMeasuringStatus {
					assign status = SensorStatus::measuring;
				}
				do action sense: PerformSensing;
			}

			transition measuring_to_ready
				first measuring
				accept MeasurementComplete
				then ready;

			transition ready_to_calibrating
				first ready
				accept CalibrationRequest
				then calibrating;

			state calibrating {
				entry action assignCalibratingStatus {
					assign status = SensorStatus::calibrating;
				}
				do action calibrate: PerformCalibration;
			}

			transition calibrating_to_ready
				first calibrating
				accept CalibrationComplete
				then ready;

			transition any_to_error
				first initialization
				accept FaultDetected
				then errorState;

			transition any_to_error2
				first warmup
				accept FaultDetected
				then errorState;

			transition any_to_error3
				first ready
				accept FaultDetected
				then errorState;

			transition any_to_error4
				first measuring
				accept FaultDetected
				then errorState;

			state errorState {
				entry action assignErrorStatus {
					assign status = SensorStatus::error;
				}
			}

			transition error_to_init
				first errorState
				accept SystemReset
				then initialization;
		}
	}

	part def SignalProcessor {
		attribute processorType: String;
		attribute samplingRate: Real;
		attribute resolution: Real;

		port signalInput: DigitalSignalPort;
		port dataOutput: DataOutputPort;
		port power: PowerPort;

		part adc: AnalogDigitalConverter {
			attribute bitDepth: Real = 16.0;
			attribute conversionRate: Real;
		}

		part microcontroller: Microcontroller {
			attribute clockFrequency: Real;
			attribute memorySize: Real;
		}

		part calibrationMemory: CalibrationMemory {
			attribute calibrationData: CalibrationData;
		}
	}

	part def AnalogDigitalConverter {
		attribute bitDepth: Real;
		attribute conversionRate: Real;
	}

	part def Microcontroller {
		attribute clockFrequency: Real;
		attribute memorySize: Real;
	}

	part def CalibrationMemory {
		attribute calibrationData: CalibrationData;
	}

	item def CalibrationData {
		attribute slope: Real;
		attribute intercept: Real;
		attribute referencePoints: Real[*];
		attribute lastCalibrationDate: String;
	}

	part def PowerApplied;
	part def TemperatureStabilized;
	part def MeasurementRequest;
	part def MeasurementComplete;
	part def CalibrationRequest;
	part def CalibrationComplete;
	part def FaultDetected;
	part def SystemReset;

	action def HeatSensor {
		in targetTemp: TemperatureValue;
		out currentTemp: TemperatureValue;
	}

	action def PerformSensing {
		in sample: GasSample;
		out signal: SensorSignal;
	}

	action def PerformCalibration {
		in referenceGas: GasSample;
		out calibrationData: CalibrationData;
	}

	action def ConvertSignal {
		in signal: SensorSignal;
		out digitalValue: Real;
	}

	action def CalculateConcentration {
		in digitalValue: Real;
		in calibrationData: CalibrationData;
		out concentration: OxygenConcentrationValue;
	}

	action def ValidateReading {
		in reading: OxygenReading;
		out isValid: Boolean;
	}

	action def OxygenMeasurementProcess {
		in item gasSample: GasSample;
		out item oxygenReading: OxygenReading;

		action warmupSensor: HeatSensor {
			in targetTemp;
			out currentTemp;
		}

		then action senseMeasurement: PerformSensing {
			in sample = gasSample;
			out signal;
		}

		then action convertToDigital: ConvertSignal {
			in signal = senseMeasurement.signal;
			out digitalValue;
		}

		then action computeConcentration: CalculateConcentration {
			in digitalValue = convertToDigital.digitalValue;
			in calibrationData;
			out concentration;
		}

		then action validateOutput: ValidateReading {
			in reading;
			out isValid;
		}

		flow from senseMeasurement.signal to convertToDigital.signal;
		flow from convertToDigital.digitalValue to computeConcentration.digitalValue;
		flow from computeConcentration.concentration to oxygenReading.concentration;
	}

	part def OxygenSensingUnit {
		attribute unitID: String;
		attribute installationDate: String;

		port gasInput: GasIntakePort;
		port measurementOutput: DataOutputPort;
		port mainPower: PowerPort;

		part sensor: ZirconiaOxygenSensor {
			attribute :>> sensorID = "OXY-SEN-001";
			attribute :>> operatingTemp = 923.15[K];
			attribute :>> heaterPower = 8.0;
			attribute :>> calibrationCoefficient = 0.21;

			part :>> sensingElement {
				attribute :>> material = "Zirconia";
				attribute :>> surfaceArea = 0.0001;
			}

			part :>> heatingElement {
				attribute :>> targetTemp = 923.15[K];
				attribute :>> currentTemp = 298.15[K];
				attribute :>> powerConsumption = 8.0;
			}

			part :>> signalAmplifier {
				attribute :>> gain = 10.0;
				attribute :>> offset = 0.05[V];
			}
		}

		part processor: SignalProcessor {
			attribute :>> processorType = "ARM Cortex-M7";
			attribute :>> samplingRate = 1000.0;
			attribute :>> resolution = 16.0;

			part :>> adc {
				attribute :>> bitDepth = 16.0;
				attribute :>> conversionRate = 10000.0;
			}

			part :>> microcontroller {
				attribute :>> clockFrequency = 216000000.0;
				attribute :>> memorySize = 2097152.0;
			}

			part :>> calibrationMemory {
				attribute :>> calibrationData {
					attribute :>> slope = 0.21;
					attribute :>> intercept = 0.0;
					attribute :>> lastCalibrationDate = "2025-01-01";
				}
			}
		}

		part powerModule: PowerModule {
			attribute inputVoltage: VoltageValue = 12.0[V];
			attribute outputVoltage: VoltageValue = 5.0[V];
			attribute maxCurrent: CurrentValue = 3.0[A];
		}

		connection sensorToProcessor: SignalConnection
			connect sensor.analogOutput to processor.signalInput;

		connect gasInput to sensor.gasInlet;
		connect processor.dataOutput to measurementOutput;
		connect mainPower to powerModule.powerInput;
		connect powerModule.sensorPower to sensor.power;
		connect powerModule.processorPower to processor.power;

		perform action measurementProcess: OxygenMeasurementProcess;
	}

	part def PowerModule {
		attribute inputVoltage: VoltageValue;
		attribute outputVoltage: VoltageValue;
		attribute maxCurrent: CurrentValue;

		port powerInput: PowerPort;
		port sensorPower: PowerPort;
		port processorPower: PowerPort;
	}

	requirement def AccuracyRequirement {
		doc /* The oxygen sensing unit shall measure oxygen concentration with accuracy of ±1% of reading over the range 0-100%. */

		subject unit: OxygenSensingUnit;

		require constraint {
			unit.measurementOutput.reading.concentration.num >= 0.0 and
			unit.measurementOutput.reading.concentration.num <= 1.0
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide stable oxygen reading within 3 seconds after gas exposure. */

		subject unit: OxygenSensingUnit;

		attribute maxResponseTime: Real = 3.0;
	}

	requirement def OperatingTemperatureRequirement {
		doc /* The sensor element shall operate at 650°C ± 5°C (923.15K ± 5K) for optimal ionic conductivity. */

		subject sensor: ZirconiaOxygenSensor;

		require constraint {
			abs(sensor.operatingTemp.num - 923.15) <= 5.0
		}
	}

	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure oxygen concentration from 0% to 100% (0.0 to 1.0 fraction). */

		subject unit: OxygenSensingUnit;

		require constraint {
			unit.measurementOutput.reading.concentration.num >= 0.0 and
			unit.measurementOutput.reading.concentration.num <= 1.0
		}
	}

	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall operate with total power consumption not exceeding 15W. */

		subject unit: OxygenSensingUnit;

		attribute maxPower: Real = 15.0;
	}

	part oxygenSensingUnit: OxygenSensingUnit {
		attribute :>> unitID = "OSU-2025-001";
		attribute :>> installationDate = "2025-01-15";

		satisfy AccuracyRequirement by oxygenSensingUnit;
		satisfy ResponseTimeRequirement by oxygenSensingUnit;
		satisfy OperatingTemperatureRequirement by sensor;
		satisfy MeasurementRangeRequirement by oxygenSensingUnit;
		satisfy PowerConsumptionRequirement by oxygenSensingUnit;
	}

	individual def TestGas1 :> GasSample;
	individual def TestGas2 :> GasSample;
	individual def TestUnit :> OxygenSensingUnit;

	individual testUnit: TestUnit :> oxygenSensingUnit {
		timeslice measurement1 {
			perform action :>> measurementProcess {
				in item :>> gasSample: TestGas1 {
					:>> oxygenLevel = 0.209;
					:>> temperature = 298.15[K];
					:>> pressure = 101325.0[Pa];
				}
				out item :>> oxygenReading {
					:>> concentration = 0.208;
					:>> confidence = 0.98;
					:>> timestamp = 1.5;
					:>> status = SensorStatus::measuring;
				}
			}
		}

		then timeslice measurement2 {
			perform action :>> measurementProcess {
				in item :>> gasSample: TestGas2 {
					:>> oxygenLevel = 0.15;
					:>> temperature = 310.0[K];
					:>> pressure = 101325.0[Pa];
				}
				out item :>> oxygenReading {
					:>> concentration = 0.149;
					:>> confidence = 0.97;
					:>> timestamp = 4.2;
					:>> status = SensorStatus::measuring;
				}
			}
		}
	}
}
