package 'Leaf Sensing Unit Design' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	
	comment about SensingUnit
	/* This model describes a sensing unit that measures environmental moisture
	 * content using a capacitive Leaf sensor. The system acquires raw capacitance
	 * readings, processes them through signal conditioning and calibration, and
	 * outputs moisture percentage values for monitoring plant health. */
	
	attribute def CapacitanceUnit :> SimpleUnit {
		attribute :>> longName = "picofarad";
	}
	
	attribute def CapacitanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CapacitanceUnit;
	}
	
	attribute def MoisturePercentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SimpleUnit;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def CalibrationParameters {
		attribute dryCapacitance : CapacitanceValue;
		attribute wetCapacitance : CapacitanceValue;
		attribute linearityFactor : Real;
	}
	
	item def RawSensorReading {
		attribute timestamp : String;
		attribute capacitance : CapacitanceValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def ProcessedMeasurement {
		attribute moisturePercent : MoisturePercentValue;
		attribute quality : String;
		attribute timestamp : String;
	}
	
	item def CalibrationData {
		attribute parameters : CalibrationParameters;
		attribute lastCalibrationDate : String;
		attribute validityStatus : String;
	}
	
	port def SensorDataPort {
		out item reading : RawSensorReading;
		in item configuration : String;
	}
	
	port def MeasurementOutputPort {
		out item measurement : ProcessedMeasurement;
		in item request : String;
	}
	
	port def PowerSupplyPort {
		in item voltage : ElectricPotentialValue;
		in item current : ElectricCurrentValue;
	}
	
	port def CalibrationPort {
		in item calibrationData : CalibrationData;
		out item calibrationStatus : String;
	}
	
	part def LeafSensor {
		attribute sensorId : String;
		attribute sensorType : String default "Capacitive Leaf Moisture Sensor";
		attribute operatingFrequency : FrequencyValue;
		
		port dataOutput : SensorDataPort;
		port powerInput : PowerSupplyPort;
		
		attribute minOperatingTemp : ThermodynamicTemperatureValue = 253.15[K];
		attribute maxOperatingTemp : ThermodynamicTemperatureValue = 358.15[K];
		
		attribute minMeasurement : MoisturePercentValue;
		attribute maxMeasurement : MoisturePercentValue;
		
		action acquireReading {
			out item sensorReading : RawSensorReading;
			
			action measureCapacitance {
				out item capacitance : CapacitanceValue;
			}
			then measureTemperature;
			
			action measureTemperature {
				out item temperature : ThermodynamicTemperatureValue;
			}
			then assembleReading;
			
			action assembleReading {
				in item cap : CapacitanceValue;
				in item temp : ThermodynamicTemperatureValue;
				out item reading : RawSensorReading;
			}
			
			flow from measureCapacitance.capacitance to assembleReading.cap;
			flow from measureTemperature.temperature to assembleReading.temp;
			bind assembleReading.reading = sensorReading;
		}
		
		state sensorStateMachine {
			entry; then powerUp;
			
			state powerUp {
				entry action initializeSensor {
					out item status : String;
				}
			}
			transition powerUp_to_standby
				first powerUp
				accept PowerStable
				then standby;
			
			state standby;
			transition standby_to_active
				first standby
				accept MeasurementRequested
				then active;
			
			state active {
				entry action startMeasurement;
				
				do action continuousAcquisition {
					out item reading : RawSensorReading;
				}
			}
			transition active_to_standby
				first active
				accept MeasurementComplete
				then standby;
			
			state selfTest {
				do action performDiagnostics {
					out item diagnosticResult : String;
				}
			}
			transition standby_to_selfTest
				first standby
				accept DiagnosticRequested
				then selfTest;
			transition selfTest_to_standby
				first selfTest
				accept DiagnosticComplete
				then standby;
			
			state fault;
			transition active_to_fault
				first active
				accept SensorError
				then fault;
			transition fault_to_powerUp
				first fault
				accept Reset
				then powerUp;
		}
	}
	
	part def SignalConditioner {
		attribute conditionerId : String;
		attribute filterCutoffFrequency : FrequencyValue;
		attribute amplificationGain : Real;
		
		port rawInput : ~SensorDataPort;
		port conditionedOutput : SensorDataPort;
		
		action conditionSignal {
			in item rawReading : RawSensorReading;
			out item conditionedReading : RawSensorReading;
			
			action filterNoise {
				in item input : RawSensorReading;
				out item filtered : RawSensorReading;
			}
			then amplifySignal;
			
			action amplifySignal {
				in item filtered : RawSensorReading;
				out item amplified : RawSensorReading;
			}
			then compensateTemperature;
			
			action compensateTemperature {
				in item amplified : RawSensorReading;
				out item compensated : RawSensorReading;
			}
			
			flow from filterNoise.filtered to amplifySignal.filtered;
			flow from amplifySignal.amplified to compensateTemperature.amplified;
			bind compensateTemperature.compensated = conditionedReading;
		}
	}
	
	part def DataProcessor {
		attribute processorId : String;
		attribute samplingRate : FrequencyValue;
		attribute averagingWindow : Real;
		
		port calibrationInput : CalibrationPort;
		
		action processData {
			in item conditionedReading : RawSensorReading;
			in item calibration : CalibrationParameters;
			out item measurement : ProcessedMeasurement;
			
			action extractCapacitance {
				in item reading : RawSensorReading;
				out item capacitance : CapacitanceValue;
			}
			then applyCalibration;
			
			action applyCalibration {
				in item capacitance : CapacitanceValue;
				in item params : CalibrationParameters;
				out item rawMoisture : Real;
			}
			then normalizeValue;
			
			action normalizeValue {
				in item rawMoisture : Real;
				out item moisturePercent : MoisturePercentValue;
			}
			then validateQuality;
			
			action validateQuality {
				in item moisture : MoisturePercentValue;
				out item quality : String;
			}
			then assembleMeasurement;
			
			action assembleMeasurement {
				in item moisture : MoisturePercentValue;
				in item quality : String;
				out item result : ProcessedMeasurement;
			}
			
			flow from extractCapacitance.capacitance to applyCalibration.capacitance;
			flow from applyCalibration.rawMoisture to normalizeValue.rawMoisture;
			flow from normalizeValue.moisturePercent to validateQuality.moisture;
			flow from validateQuality.quality to assembleMeasurement.quality;
			flow from normalizeValue.moisturePercent to assembleMeasurement.moisture;
			bind assembleMeasurement.result = measurement;
		}
	}
	
	part def CalibrationManager {
		attribute managerId : String;
		attribute calibrationInterval : Real;
		
		attribute defaultDryCapacitance : CapacitanceValue;
		attribute defaultWetCapacitance : CapacitanceValue;
		attribute defaultLinearityFactor : Real;
		
		port calibrationOutput : ~CalibrationPort;
		
		action performCalibration {
			in item dryReference : CapacitanceValue;
			in item wetReference : CapacitanceValue;
			out item updatedCalibration : CalibrationParameters;
			
			action measureDryPoint {
				in item reference : CapacitanceValue;
				out item dryValue : CapacitanceValue;
			}
			then measureWetPoint;
			
			action measureWetPoint {
				in item reference : CapacitanceValue;
				out item wetValue : CapacitanceValue;
			}
			then calculateLinearity;
			
			action calculateLinearity {
				in item dry : CapacitanceValue;
				in item wet : CapacitanceValue;
				out item factor : Real;
			}
			then updateParameters;
			
			action updateParameters {
				in item dry : CapacitanceValue;
				in item wet : CapacitanceValue;
				in item factor : Real;
				out item params : CalibrationParameters;
			}
			
			flow from measureDryPoint.dryValue to calculateLinearity.dry;
			flow from measureWetPoint.wetValue to calculateLinearity.wet;
			flow from measureDryPoint.dryValue to updateParameters.dry;
			flow from measureWetPoint.wetValue to updateParameters.wet;
			flow from calculateLinearity.factor to updateParameters.factor;
			bind updateParameters.params = updatedCalibration;
		}
		
		state calibrationStateMachine {
			entry; then valid;
			
			state valid {
				do action monitorValidity {
					out item status : String;
				}
			}
			transition valid_to_calibrating
				first valid
				accept CalibrationNeeded
				then calibrating;
			
			state calibrating {
				do action runCalibration {
					out item result : CalibrationParameters;
				}
			}
			transition calibrating_to_valid
				first calibrating
				accept CalibrationSuccessful
				then valid;
			transition calibrating_to_invalid
				first calibrating
				accept CalibrationFailed
				then invalid;
			
			state invalid;
			transition invalid_to_calibrating
				first invalid
				accept RetryCalibration
				then calibrating;
		}
	}
	
	part def OutputInterface {
		attribute interfaceId : String;
		attribute outputFormat : String;
		
		port measurementInput : ~MeasurementOutputPort;
		port externalOutput : MeasurementOutputPort;
		
		action formatOutput {
			in item measurement : ProcessedMeasurement;
			out item formattedOutput : ProcessedMeasurement;
			
			action validateMeasurement {
				in item input : ProcessedMeasurement;
				out item valid : Boolean;
			}
			then formatData;
			
			action formatData {
				in item measurement : ProcessedMeasurement;
				out item formatted : ProcessedMeasurement;
			}
			then transmit;
			
			action transmit {
				in item data : ProcessedMeasurement;
			}
			
			flow from formatData.formatted to transmit.data;
			bind formatData.formatted = formattedOutput;
		}
	}
	
	part def SensingUnit {
		part sensor : LeafSensor;
		part conditioner : SignalConditioner;
		part processor : DataProcessor;
		part calibrationMgr : CalibrationManager;
		part outputInterface : OutputInterface;
		
		port powerSupply : PowerSupplyPort;
		port measurementOutput : MeasurementOutputPort;
	}
	
	part sensingUnit : SensingUnit {
		part redefines sensor {
			attribute :>> sensorId = "LEAF-SENSOR-001";
		}
		
		part redefines conditioner {
			attribute :>> conditionerId = "COND-001";
			attribute :>> amplificationGain = 10.0;
		}
		
		part redefines processor {
			attribute :>> processorId = "PROC-001";
			attribute :>> averagingWindow = 5.0;
		}
		
		part redefines calibrationMgr {
			attribute :>> managerId = "CAL-MGR-001";
			attribute :>> calibrationInterval = 2592000.0;
		}
		
		part redefines outputInterface {
			attribute :>> interfaceId = "OUT-001";
			attribute :>> outputFormat = "JSON";
		}
		
		connection sensorToConditioner 
			connect sensor.dataOutput to conditioner.rawInput;
		
		connection calibrationToProcessor 
			connect calibrationMgr.calibrationOutput to processor.calibrationInput;
		
		connection outputToExternal 
			connect outputInterface.externalOutput to measurementOutput;
		
		action measurementSequence {
			action initializeSystem {
				out item initStatus : String;
			}
			then fork;
			
			then loadCalibration;
			action loadCalibration {
				out item calibration : CalibrationParameters;
			}
			then joinNode;
			
			then activateSensor;
			action activateSensor {
				out item activationCommand : String;
			}
			then joinNode;
			
			join joinNode;
			then acquireData;
			
			action acquireData {
				out item sensorReading : RawSensorReading;
			}
			then conditionData;
			
			action conditionData : SignalConditioner::conditionSignal {
				in item rawReading : RawSensorReading;
				out item conditionedReading : RawSensorReading;
			}
			then processData;
			
			action processData : DataProcessor::processData {
				in item conditionedReading : RawSensorReading;
				in item calibration : CalibrationParameters;
				out item measurement : ProcessedMeasurement;
			}
			then outputData;
			
			action outputData : OutputInterface::formatOutput {
				in item measurement : ProcessedMeasurement;
				out item formattedOutput : ProcessedMeasurement;
			}
			
			flow from loadCalibration.calibration to processData.calibration;
			flow from acquireData.sensorReading to conditionData.rawReading;
			flow from conditionData.conditionedReading to processData.conditionedReading;
			flow from processData.measurement to outputData.measurement;
		}
		
		state operationalStateMachine {
			entry; then initialization;
			
			state initialization {
				entry action systemStartup {
					out item status : String;
				}
				
				do action loadConfiguration {
					out item config : String;
				}
			}
			transition initialization_to_ready
				first initialization
				accept InitializationComplete
				then ready;
			
			state ready;
			transition ready_to_measuring
				first ready
				accept StartMeasurement
				then measuring;
			transition ready_to_calibration
				first ready
				accept CalibrationMode
				then calibration;
			
			state measuring {
				do action continuousMeasurement {
					out item result : ProcessedMeasurement;
				}
			}
			transition measuring_to_ready
				first measuring
				accept StopMeasurement
				then ready;
			transition measuring_to_error
				first measuring
				accept MeasurementFault
				then error;
			
			state calibration {
				do action calibrate : CalibrationManager::performCalibration;
			}
			transition calibration_to_ready
				first calibration
				accept CalibrationComplete
				then ready;
			
			state error {
				entry action logError {
					out item errorLog : String;
				}
			}
			transition error_to_initialization
				first error
				accept SystemReset
				then initialization;
			transition error_to_ready
				first error
				accept ErrorCleared
				then ready;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall measure moisture content with an accuracy
		     * of ±2% across the full measurement range of 0-100%. */
		
		subject unit : SensingUnit;
		
		require constraint measurementAccuracy {
			attribute maxError : Real = 2.0;
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide a valid measurement output within
		     * 500 milliseconds of receiving a measurement request. */
		
		subject unit : SensingUnit;
		
		require constraint maxResponseTime {
			attribute timeLimit : Real = 500.0;
		}
	}
	
	requirement def OperatingEnvironmentRequirement {
		doc /* The Leaf sensor shall operate reliably in ambient temperatures
		     * from -20°C to +85°C and relative humidity from 0% to 100%. */
		
		subject sensor : LeafSensor;
		
		require constraint temperatureRange {
			attribute minTemp : ThermodynamicTemperatureValue = 253.15[K];
			attribute maxTemp : ThermodynamicTemperatureValue = 358.15[K];
		}
	}
	
	requirement def CalibrationRequirement {
		doc /* The sensing unit shall maintain calibration validity for at least
		     * 30 days and support field recalibration procedures. */
		
		subject calibrationSystem : CalibrationManager;
		
		require constraint calibrationValidity {
			attribute minValidityPeriod : Real = 2592000.0;
		}
	}
	
	requirement def PowerRequirement {
		doc /* The sensing unit shall operate from a 3.3V to 5.0V DC power supply
		     * with maximum current consumption of 50mA during active measurement. */
		
		subject unit : SensingUnit;
		
		require constraint voltageRange {
			attribute minVoltage : ElectricPotentialValue = 3.3[V];
			attribute maxVoltage : ElectricPotentialValue = 5.0[V];
		}
		
		require constraint currentConsumption {
			attribute maxCurrent : ElectricCurrentValue = 0.05[A];
		}
	}
	
	requirement systemRequirements {
		requirement accuracyReq : AccuracyRequirement {
			subject actualUnit = sensingUnit;
		}
		
		requirement responseReq : ResponseTimeRequirement {
			subject actualUnit = sensingUnit;
		}
		
		requirement environmentReq : OperatingEnvironmentRequirement {
			subject actualSensor = sensingUnit.sensor;
		}
		
		requirement calibrationReq : CalibrationRequirement {
			subject actualCalibration = sensingUnit.calibrationMgr;
		}
		
		requirement powerReq : PowerRequirement {
			subject actualUnit = sensingUnit;
		}
	}
	
	dependency from sensingUnit to systemRequirements;
	dependency from sensingUnit.sensor to LeafSensor::sensorStateMachine;
	dependency from sensingUnit.calibrationMgr to CalibrationManager::calibrationStateMachine;
	dependency from sensingUnit to SensingUnit::operationalStateMachine;
}
