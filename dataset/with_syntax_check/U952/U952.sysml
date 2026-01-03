package 'ZincOxideNanorodSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ConcentrationValue :> Real;
	
	item def GasAnalyte {
		attribute concentration: ConcentrationValue;
		attribute temperature: ISQ::TemperatureValue;
		attribute pressure: ISQ::PressureValue;
	}
	
	item def ElectricalSignal {
		attribute voltage: ISQ::VoltageValue;
		attribute current: ISQ::ElectricCurrentValue;
		attribute resistance: ISQ::ElectricResistanceValue;
	}
	
	item def SensorData {
		attribute measuredConcentration: ConcentrationValue;
		attribute timestamp: Real;
		attribute sensorResistance: ISQ::ElectricResistanceValue;
		attribute ambientTemperature: ISQ::TemperatureValue;
		attribute signalQuality: Real;
	}
	
	port def GasExposurePort {
		in item gasInput: GasAnalyte;
	}
	
	port def ElectricalOutputPort {
		out item electricalOutput: ElectricalSignal;
	}
	
	port def DataOutputPort {
		out item dataOutput: SensorData;
	}
	
	port def PowerInputPort {
		in item powerSupply: ISQ::VoltageValue;
	}
	
	part def ZincOxideNanorod {
		attribute baselineResistance: ISQ::ElectricResistanceValue;
		attribute currentResistance: ISQ::ElectricResistanceValue;
		attribute surfaceArea: Real;
		attribute nanorodDiameter: Real;
		attribute nanorodLength: Real;
		attribute operatingTemperature: ISQ::TemperatureValue;
		attribute sensitivityCoefficient: Real;
		
		port gasInterface: GasExposurePort;
		port electricalInterface: ElectricalOutputPort;
		port heaterPower: PowerInputPort;
	}
	
	part def SignalConditioner {
		attribute gain: Real;
		attribute offset: ISQ::VoltageValue;
		attribute filterCutoffFrequency: Real;
		attribute amplificationStages: Integer;
		
		port electricalInput: ~ElectricalOutputPort;
		port conditionedOutput: ElectricalOutputPort;
		port power: PowerInputPort;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution: Integer;
		attribute samplingRate: Real;
		attribute referenceVoltage: ISQ::VoltageValue;
		attribute conversionTime: Real;
		
		port analogInput: ~ElectricalOutputPort;
		port digitalOutput: DataOutputPort;
		port power: PowerInputPort;
	}
	
	part def Microcontroller {
		attribute processorSpeed: Real;
		attribute memorySize: Integer;
		attribute calibrationTable: Real[*];
		attribute dataBufferSize: Integer;
		
		port dataInput: ~DataOutputPort;
		port processedDataOutput: DataOutputPort;
		port powerInput: PowerInputPort;
	}
	
	part def PowerSupply {
		attribute outputVoltage: ISQ::VoltageValue;
		attribute outputCurrent: ISQ::ElectricCurrentValue;
		attribute efficiency: Real;
		attribute regulationAccuracy: Real;
		
		port powerOutput: ~PowerInputPort;
	}
	
	part def TemperatureController {
		attribute targetTemperature: ISQ::TemperatureValue;
		attribute heaterPower: Real;
		attribute controlLoopGain: Real;
		
		port sensorHeaterOutput: ~PowerInputPort;
		port power: PowerInputPort;
	}
	
	connection def GasExposureConnection {
		end sensor: GasExposurePort;
		end environment: GasExposurePort;
	}
	
	connection def ElectricalConnection {
		end source: ElectricalOutputPort;
		end sink: ~ElectricalOutputPort;
	}
	
	connection def DataConnection {
		end source: DataOutputPort;
		end sink: ~DataOutputPort;
	}
	
	connection def PowerConnection {
		end source: ~PowerInputPort;
		end sink: PowerInputPort;
	}
	
	action def ExposeToGas {
		in item gasAnalyte: GasAnalyte;
		in item sensor: ZincOxideNanorod;
		out item modifiedSensor: ZincOxideNanorod;
	}
	
	action def MeasureResistance {
		in item sensor: ZincOxideNanorod;
		out signal: ElectricalSignal;
	}
	
	action def ConditionSignal {
		in signal: ElectricalSignal;
		in gain: Real;
		in offset: ISQ::VoltageValue;
		out conditionedSignal: ElectricalSignal;
	}
	
	action def ConvertToDigital {
		in analogSignal: ElectricalSignal;
		in resolution: Integer;
		out digitalData: SensorData;
	}
	
	action def ProcessData {
		in rawData: SensorData;
		in calibrationTable: Real[*];
		out processedData: SensorData;
	}
	
	action def CalibrateReading {
		in sensorData: SensorData;
		in calibrationParameters: Real[*];
		out calibratedConcentration: ConcentrationValue;
	}
	
	action def SensingCycle {
		in item gasAnalyte: GasAnalyte;
		out item sensorData: SensorData;
		
		action expose: ExposeToGas {
			in item :>> gasAnalyte;
			in item nanorodSensor: ZincOxideNanorod;
			out item :>> modifiedSensor;
		}
		
		flow from expose.modifiedSensor to measure.sensor;
		
		action measure: MeasureResistance {
			in item sensor;
			out :>> signal;
		}
		
		flow from measure.signal to condition.signal;
		
		action condition: ConditionSignal {
			in :>> signal;
			in :>> gain = 100.0;
			in :>> offset = 0.0[SI::V];
			out :>> conditionedSignal;
		}
		
		flow from condition.conditionedSignal to convert.analogSignal;
		
		action convert: ConvertToDigital {
			in :>> analogSignal;
			in :>> resolution = 16;
			out :>> digitalData;
		}
		
		flow from convert.digitalData to process.rawData;
		
		action process: ProcessData {
			in :>> rawData;
			in :>> calibrationTable;
			out :>> processedData;
		}
		
		flow from process.processedData to calibrate.sensorData;
		
		action calibrate: CalibrateReading {
			in :>> sensorData;
			in :>> calibrationParameters;
			out :>> calibratedConcentration;
		}
		
		bind calibrate.calibratedConcentration = sensorData.measuredConcentration;
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign sensorStatus = "Ready";
		}
		
		transition idle_to_warming
			first idle
			accept WarmUpCommand
			then warming;
		
		state warming {
			entry assign sensorStatus = "Warming Up";
			do action warmUp {
				out heatingComplete: Boolean;
			}
		}
		
		transition warming_to_measuring
			first warming
			if warmUp.heatingComplete
			then measuring;
		
		state measuring {
			entry assign sensorStatus = "Measuring";
			do action performMeasurement {
				in gasInput: GasAnalyte;
				out measurementData: SensorData;
			}
		}
		
		transition measuring_to_processing
			first measuring
			accept MeasurementComplete
			then processing;
		
		state processing {
			entry assign sensorStatus = "Processing";
			do action processResults {
				in measurementData: SensorData;
				out processedResults: SensorData;
			}
		}
		
		transition processing_to_idle
			first processing
			accept ProcessingComplete
			then idle;
		
		transition any_to_error
			first idle, warming, measuring, processing
			accept ErrorDetected
			then error;
		
		state error {
			entry assign sensorStatus = "Error";
		}
		
		transition error_to_idle
			first error
			accept ResetCommand
			then idle;
		
		attribute sensorStatus: String;
	}
	
	part def ZincOxideNanorodSensingUnit {
		part znoSensor: ZincOxideNanorod[1];
		part signalConditioner: SignalConditioner[1];
		part adc: AnalogToDigitalConverter[1];
		part mcu: Microcontroller[1];
		part powerSupply: PowerSupply[1];
		part tempController: TemperatureController[1];
		
		port gasInput: GasExposurePort;
		port dataOutput: DataOutputPort;
		
		perform action sensingOperation: SensingCycle;
		exhibit state operationalState: SensorOperationalStates;
	}
	
	part sensingUnit: ZincOxideNanorodSensingUnit {
		part :>> znoSensor {
			attribute :>> baselineResistance = 10000.0[SI::Ω];
			attribute :>> surfaceArea = 2.5e-6;
			attribute :>> nanorodDiameter = 50.0e-9;
			attribute :>> nanorodLength = 500.0e-9;
			attribute :>> operatingTemperature = 573.15[SI::K];
			attribute :>> sensitivityCoefficient = 0.85;
		}
		
		part :>> signalConditioner {
			attribute :>> gain = 100.0;
			attribute :>> offset = 0.0[SI::V];
			attribute :>> filterCutoffFrequency = 1000.0;
			attribute :>> amplificationStages = 2;
		}
		
		part :>> adc {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
			attribute :>> referenceVoltage = 5.0[SI::V];
			attribute :>> conversionTime = 0.001;
		}
		
		part :>> mcu {
			attribute :>> processorSpeed = 48.0e6;
			attribute :>> memorySize = 65536;
			attribute :>> dataBufferSize = 256;
		}
		
		part :>> powerSupply {
			attribute :>> outputVoltage = 5.0[SI::V];
			attribute :>> outputCurrent = 0.5[SI::A];
			attribute :>> efficiency = 0.85;
			attribute :>> regulationAccuracy = 0.02;
		}
		
		part :>> tempController {
			attribute :>> targetTemperature = 573.15[SI::K];
			attribute :>> heaterPower = 1.5;
			attribute :>> controlLoopGain = 0.5;
		}
		
		connection gasExposure: GasExposureConnection
			connect gasInput to znoSensor.gasInterface;
		
		connection sensorToConditioner: ElectricalConnection
			connect znoSensor.electricalInterface to signalConditioner.electricalInput;
		
		connection conditionerToADC: ElectricalConnection
			connect signalConditioner.conditionedOutput to adc.analogInput;
		
		connection adcToMCU: DataConnection
			connect adc.digitalOutput to mcu.dataInput;
		
		connection mcuToOutput: DataConnection
			connect mcu.processedDataOutput to dataOutput;
		
		connection powerToMCU: PowerConnection
			connect powerSupply.powerOutput to mcu.powerInput;
		
		connection powerToConditioner: PowerConnection
			connect powerSupply.powerOutput to signalConditioner.power;
		
		connection powerToADC: PowerConnection
			connect powerSupply.powerOutput to adc.power;
		
		connection powerToTempController: PowerConnection
			connect powerSupply.powerOutput to tempController.power;
		
		connection tempControllerToSensor: PowerConnection
			connect tempController.sensorHeaterOutput to znoSensor.heaterPower;
	}
	
	requirement def SensingRequirements {
		doc /* Top-level requirements for the zinc oxide nanorod sensing unit */
		
		requirement detectionRange {
			doc /* The sensor shall detect gas concentrations from 1 ppm to 1000 ppm */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
		
		requirement responseTime {
			doc /* The sensor shall respond to gas exposure within 30 seconds */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
		
		requirement sensitivity {
			doc /* The sensor resistance shall change by at least 10% for 10 ppm gas concentration */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
		
		requirement operatingTemperature {
			doc /* The sensor shall operate at 300 degrees Celsius (573.15 K) */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
		
		requirement dataAccuracy {
			doc /* The processed data shall have accuracy within 5% of actual concentration */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
		
		requirement powerConsumption {
			doc /* The sensing unit shall consume less than 2.5 watts during operation */
			subject sensor: ZincOxideNanorodSensingUnit;
		}
	}
	
	requirement sensingRequirements: SensingRequirements {
		subject testUnit :> sensingUnit;
	}
}
