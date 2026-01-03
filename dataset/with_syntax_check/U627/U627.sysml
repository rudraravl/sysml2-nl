package 'CO2 Sensing Unit' {
	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import SI::*;
	private import ISQ::*;
	
	attribute def ConcentrationUnit :> DerivedUnit {
		private attribute amountPF: QuantityPowerFactor[1] {
			:>> quantity = isq.N;
			:>> exponent = 1;
		}
		private attribute volumePF: QuantityPowerFactor[1] {
			:>> quantity = isq.L ** 3;
			:>> exponent = -1;
		}
		attribute :>> quantityDimension {
			:>> quantityPowerFactors = (amountPF, volumePF);
		}
	}
	
	attribute def ConcentrationValue :> ScalarQuantityValue {
		attribute :>> num: Real;
		attribute :>> mRef: ConcentrationUnit;
	}
	
	attribute <'ppm'> 'parts per million' : ConcentrationUnit;
	
	attribute def CO2ConcentrationValue :> ConcentrationValue;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num: Real;
		attribute :>> mRef: VoltageUnit;
	}
	
	attribute def VoltageUnit :> DerivedUnit {
		private attribute lengthPF: QuantityPowerFactor[1] {
			:>> quantity = isq.L;
			:>> exponent = 2;
		}
		private attribute massPF: QuantityPowerFactor[1] {
			:>> quantity = isq.M;
			:>> exponent = 1;
		}
		private attribute durationPF: QuantityPowerFactor[1] {
			:>> quantity = isq.T;
			:>> exponent = -3;
		}
		private attribute currentPF: QuantityPowerFactor[1] {
			:>> quantity = isq.I;
			:>> exponent = -1;
		}
		attribute :>> quantityDimension {
			:>> quantityPowerFactors = (lengthPF, massPF, durationPF, currentPF);
		}
	}
	
	attribute <'V'> volt : VoltageUnit;
	
	item def AirSample {
		attribute co2Concentration: CO2ConcentrationValue;
		attribute temperature: TemperatureValue;
		attribute relativeHumidity: DimensionOneValue;
	}
	
	item def CO2Measurement {
		attribute measuredConcentration: CO2ConcentrationValue;
		attribute timestamp: Real;
		attribute sensorStatus: SensorStatus;
	}
	
	attribute def SensorStatus {
		attribute isCalibrated: Boolean;
		attribute isWarmedUp: Boolean;
		attribute errorCode: Integer;
	}
	
	port def AirSamplingPort {
		in item airSample: AirSample;
	}
	
	port def MeasurementOutputPort {
		out item measurement: CO2Measurement;
	}
	
	port def PowerInputPort {
		in attribute voltage: VoltageValue;
	}
	
	action def WarmUpSensor {
		in attribute powerVoltage: VoltageValue;
		out attribute isReady: Boolean;
	}
	
	action def CalibrateSensor {
		in attribute referenceConcentration: CO2ConcentrationValue;
		out attribute calibrationFactor: Real;
	}
	
	action def DetectCO2 {
		in item sample: AirSample;
		in attribute calibrationFactor: Real;
		out attribute rawConcentration: CO2ConcentrationValue;
	}
	
	action def CompensateEnvironmental {
		in attribute rawConcentration: CO2ConcentrationValue;
		in attribute temperature: TemperatureValue;
		in attribute humidity: DimensionOneValue;
		out attribute compensatedConcentration: CO2ConcentrationValue;
	}
	
	action def ValidateReading {
		in attribute concentration: CO2ConcentrationValue;
		out attribute isValid: Boolean;
	}
	
	action def CreateMeasurement {
		in attribute concentration: CO2ConcentrationValue;
		in attribute status: SensorStatus;
		in attribute time: Real;
		out item measurement: CO2Measurement;
	}
	
	action def MeasureCO2Concentration {
		in item airSample: AirSample;
		in attribute powerVoltage: VoltageValue;
		out item finalMeasurement: CO2Measurement;
		
		bind warmUp.powerVoltage = powerVoltage;
		
		action warmUp: WarmUpSensor {
			in powerVoltage;
			out isReady;
		}
		
		then action calibrate: CalibrateSensor {
			in referenceConcentration;
			out calibrationFactor;
		}
		
		then fork;
		
		then action detect: DetectCO2 {
			in sample;
			in calibrationFactor;
			out rawConcentration;
		}
		
		then joinNode;
		
		flow from airSample to detect.sample;
		flow from calibrate.calibrationFactor to detect.calibrationFactor;
		
		action compensate: CompensateEnvironmental {
			in rawConcentration;
			in temperature;
			in humidity;
			out compensatedConcentration;
		}
		
		then joinNode;
		
		flow from detect.rawConcentration to compensate.rawConcentration;
		flow from airSample.temperature to compensate.temperature;
		flow from airSample.relativeHumidity to compensate.humidity;
		
		join joinNode;
		
		then action validate: ValidateReading {
			in concentration;
			out isValid;
		}
		
		flow from compensate.compensatedConcentration to validate.concentration;
		
		then action createMeasurement: CreateMeasurement {
			in concentration;
			in status;
			in time;
			out measurement;
		}
		
		flow from compensate.compensatedConcentration to createMeasurement.concentration;
		
		bind createMeasurement.measurement = finalMeasurement;
	}
	
	item def WarmUpCommand;
	item def MeasureCommand;
	item def ResetCommand;
	
	state def SensorOperatingStates {
		in item airSample: AirSample;
		in attribute powerVoltage: VoltageValue;
		out item finalMeasurement: CO2Measurement;
		
		entry; then idle;
		
		state idle;
		transition idle_to_warmup
			first idle
			accept WarmUpCommand
			then warming;
		
		state warming {
			entry action warmUpAction: WarmUpSensor {
				in powerVoltage;
				out isReady;
			}
		}
		transition warming_to_ready
			first warming
			if warming.warmUpAction.isReady
			then ready;
		
		state ready;
		transition ready_to_measuring
			first ready
			accept MeasureCommand
			then measuring;
		
		state measuring {
			entry action measureAction: MeasureCO2Concentration {
				in airSample;
				in powerVoltage;
				out finalMeasurement;
			}
		}
		transition measuring_to_ready
			first measuring
			if measuring.measureAction.finalMeasurement.sensorStatus.errorCode == 0
			then ready;
		
		transition measuring_to_error
			first measuring
			if measuring.measureAction.finalMeasurement.sensorStatus.errorCode != 0
			then error;
		
		state error;
		transition error_to_idle
			first error
			accept ResetCommand
			then idle;
	}
	
	part def CarbonDioxideSensor {
		attribute sensingRange: CO2ConcentrationValue[2];
		attribute accuracy: CO2ConcentrationValue;
		attribute responseTime: DurationValue;
		attribute operatingTemperature: TemperatureValue[2];
		attribute operatingVoltage: VoltageValue[2];
		
		port airIntake: AirSamplingPort;
		port measurementOutput: MeasurementOutputPort;
		port powerInput: PowerInputPort;
		
		perform action sensing: MeasureCO2Concentration {
			in item :>> airSample = airIntake.airSample;
			in :>> powerVoltage = powerInput.voltage;
			out item :>> finalMeasurement = measurementOutput.measurement;
		}
		
		exhibit state operatingStates: SensorOperatingStates {
			in :>> airSample = airIntake.airSample;
			in :>> powerVoltage = powerInput.voltage;
			out :>> finalMeasurement = measurementOutput.measurement;
		}
	}
	
	part def SignalProcessor {
		attribute processingDelay: DurationValue;
		
		port dataInput: MeasurementOutputPort;
		port dataOutput: MeasurementOutputPort;
		
		action processSignal {
			in item rawMeasurement: CO2Measurement;
			out item processedMeasurement: CO2Measurement;
		}
	}
	
	part def PowerSupply {
		attribute outputVoltage: VoltageValue;
		attribute maxCurrent: Real;
		
		port powerOutput: PowerInputPort;
	}
	
	part def CO2SensingUnit {
		attribute unitIdentifier: String;
		attribute measurementInterval: DurationValue;
		
		part co2Sensor: CarbonDioxideSensor[1] {
			attribute :>> sensingRange = (0.0['ppm'], 5000.0['ppm']);
			attribute :>> accuracy = 50.0['ppm'];
			attribute :>> responseTime = 30.0[s];
			attribute :>> operatingTemperature = (263.15[K], 323.15[K]);
			attribute :>> operatingVoltage = (4.5[volt], 5.5[volt]);
		}
		
		part signalProcessor: SignalProcessor[1] {
			attribute :>> processingDelay = 0.1[s];
		}
		
		part powerSupply: PowerSupply[1] {
			attribute :>> outputVoltage = 5.0[volt];
			attribute :>> maxCurrent = 0.3;
		}
		
		port environmentInterface: AirSamplingPort;
		port dataInterface: MeasurementOutputPort;
		port externalPower: PowerInputPort;
		
		connect environmentInterface to co2Sensor.airIntake;
		connect co2Sensor.measurementOutput to signalProcessor.dataInput;
		connect signalProcessor.dataOutput to dataInterface;
		connect externalPower to powerSupply.powerOutput;
		connect powerSupply.powerOutput to co2Sensor.powerInput;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The CO2 sensor shall measure carbon dioxide concentration with an accuracy of ±50 ppm or ±3% of reading, whichever is greater. */
		
		subject sensor: CarbonDioxideSensor;
		
		require constraint {
			sensor.accuracy.num <= 50.0 or 
			sensor.accuracy.num <= 0.03 * sensor.sensingRange[2].num
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide a valid measurement within 30 seconds of receiving a measurement command. */
		
		subject unit: CO2SensingUnit;
		
		require constraint {
			unit.co2Sensor.responseTime.num <= 30.0
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The CO2 sensor shall operate reliably in concentrations from 0 to 5000 ppm. */
		
		subject sensor: CarbonDioxideSensor;
		
		require constraint {
			sensor.sensingRange[1].num == 0.0 and
			sensor.sensingRange[2].num >= 5000.0
		}
	}
	
	part sensingUnitInstance: CO2SensingUnit {
		attribute :>> unitIdentifier = "CO2-UNIT-001";
		attribute :>> measurementInterval = 60.0[s];
		
		satisfy accuracyReq: MeasurementAccuracyRequirement {
			subject actualSensor = co2Sensor;
		}
		
		satisfy responseReq: ResponseTimeRequirement {
			subject actualUnit = sensingUnitInstance;
		}
		
		satisfy rangeReq: OperatingRangeRequirement {
			subject actualSensor = co2Sensor;
		}
	}
	
	individual def TestAirSample :> AirSample;
	individual def TestSensingUnit :> CO2SensingUnit;
	
	individual testUnit: TestSensingUnit :> sensingUnitInstance {
		timeslice measurement1 {
			perform action :>> co2Sensor.sensing {
				in individual :>> airSample: TestAirSample {
					:>> co2Concentration = 450.0['ppm'];
					:>> temperature = 298.15[K];
					:>> relativeHumidity = 0.45[one];
				}
				in :>> powerVoltage = 5.0[volt];
			}
		}
		then timeslice measurement2 {
			perform action :>> co2Sensor.sensing {
				in individual :>> airSample: TestAirSample {
					:>> co2Concentration = 1200.0['ppm'];
					:>> temperature = 303.15[K];
					:>> relativeHumidity = 0.60[one];
				}
				in :>> powerVoltage = 5.0[volt];
			}
		}
	}
}
