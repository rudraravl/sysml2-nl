package SunSensorSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def AngleValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit;
	}
	
	attribute def AngleUnit :> MeasurementUnit;
	
	attribute def IrradianceValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : IrradianceUnit;
	}
	
	attribute def IrradianceUnit :> MeasurementUnit;
	
	attribute def VoltageValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> MeasurementUnit;
	
	item def SolarRadiation {
		attribute irradiance : IrradianceValue;
		attribute incidenceAngle : AngleValue;
	}
	
	item def SensorMeasurement {
		attribute azimuthAngle : AngleValue;
		attribute elevationAngle : AngleValue;
		attribute timestamp : Real;
		attribute measurementQuality : Real;
	}
	
	item def RawSensorSignal {
		attribute quadrantVoltages : VoltageValue[4];
	}
	
	port def SolarInputPort {
		in item radiation : SolarRadiation;
	}
	
	port def MeasurementOutputPort {
		out item measurement : SensorMeasurement;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute supplyCurrent : Real;
	}
	
	port def SignalPort {
		out attribute signalVoltage : VoltageValue;
	}
	
	part def PhotodiodeElement {
		attribute elementID : String;
		attribute sensitiveArea : Real;
		attribute spectralResponse : Real;
		
		port solarIn : SolarInputPort;
		port signalOut : SignalPort;
		
		action detectRadiation {
			in item incidentLight : SolarRadiation;
			out attribute outputVoltage : VoltageValue;
			
			bind incidentLight = solarIn::radiation;
			bind outputVoltage = signalOut::signalVoltage;
		}
	}
	
	part def SignalProcessor {
		port rawSignalIn {
			in attribute inputVoltages : VoltageValue[4];
		}
		port processedSignalOut {
			out attribute outputVoltages : VoltageValue[4];
		}
		
		action amplifySignals {
			in attribute rawVoltages : VoltageValue[4];
			out attribute amplifiedVoltages : VoltageValue[4];
			
			attribute amplificationGain : Real default 15.0;
		}
		
		action filterNoise {
			in attribute noisyVoltages : VoltageValue[4];
			out attribute filteredVoltages : VoltageValue[4];
			
			attribute filterCutoff : Real default 150.0;
		}
		
		action processSignals {
			in attribute inputSignals : VoltageValue[4];
			out attribute outputSignals : VoltageValue[4];
			
			bind inputSignals = rawSignalIn::inputVoltages;
			
			action amplify : amplifySignals {
				in attribute rawVoltages = processSignals::inputSignals;
				out attribute amplifiedVoltages;
			}
			
			then action filter : filterNoise {
				in attribute noisyVoltages;
				out attribute filteredVoltages = processSignals::outputSignals;
			}
			
			flow from amplify.amplifiedVoltages to filter.noisyVoltages;
			
			bind outputSignals = processedSignalOut::outputVoltages;
		}
	}
	
	part def AngleCalculator {
		port voltageIn {
			in attribute voltages : VoltageValue[4];
		}
		port angleOut {
			out attribute azimuth : AngleValue;
			out attribute elevation : AngleValue;
		}
		
		attribute calibrationCoefficients : Real[4][2];
		
		action calculateAngles {
			in attribute quadrantReadings : VoltageValue[4];
			out attribute computedAzimuth : AngleValue;
			out attribute computedElevation : AngleValue;
			
			bind quadrantReadings = voltageIn::voltages;
			
			action computeDifferences {
				in attribute v : VoltageValue[4];
				out attribute horizontalDiff : Real;
				out attribute verticalDiff : Real;
			}
			
			then action deriveAngles {
				in attribute hDiff : Real;
				in attribute vDiff : Real;
				out attribute azimuthResult : AngleValue;
				out attribute elevationResult : AngleValue;
			}
			
			flow from computeDifferences.horizontalDiff to deriveAngles.hDiff;
			flow from computeDifferences.verticalDiff to deriveAngles.vDiff;
			
			bind deriveAngles.azimuthResult = computedAzimuth;
			bind deriveAngles.elevationResult = computedElevation;
			bind computedAzimuth = angleOut::azimuth;
			bind computedElevation = angleOut::elevation;
		}
	}
	
	part def MeasurementValidator {
		port angleIn {
			in attribute azimuthInput : AngleValue;
			in attribute elevationInput : AngleValue;
		}
		port validMeasurementOut {
			out item validatedMeasurement : SensorMeasurement;
		}
		
		attribute minimumElevation : AngleValue;
		attribute maximumElevation : AngleValue;
		attribute qualityThreshold : Real default 0.8;
		
		action validateMeasurement {
			in attribute azimuth : AngleValue;
			in attribute elevation : AngleValue;
			out item finalMeasurement : SensorMeasurement;
			
			bind azimuth = angleIn::azimuthInput;
			bind elevation = angleIn::elevationInput;
			
			action checkValidity {
				in attribute elevationValue : AngleValue;
				out attribute isValidMeasurement : Boolean;
			}
			
			then action assessQuality {
				in attribute validityFlag : Boolean;
				out attribute qualityScore : Real;
			}
			
			then action assembleMeasurement {
				in attribute azimuthAngle : AngleValue;
				in attribute elevationAngle : AngleValue;
				in attribute quality : Real;
				out item measurement : SensorMeasurement;
			}
			
			flow from checkValidity.isValidMeasurement to assessQuality.validityFlag;
			flow from assessQuality.qualityScore to assembleMeasurement.quality;
			
			bind assembleMeasurement.measurement = finalMeasurement;
			bind finalMeasurement = validMeasurementOut::validatedMeasurement;
		}
	}
	
	state def SensorStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initialization
			first powerOff
			accept PowerOnCommand
			then initialization;
		
		state initialization {
			entry action initializeSensor;
		}
		
		transition initialization_to_calibration
			first initialization
			accept InitializationComplete
			then calibration;
		
		state calibration {
			entry action calibrateSensor;
		}
		
		transition calibration_to_operational
			first calibration
			accept CalibrationComplete
			then operational;
		
		state operational {
			entry action beginMeasurement;
			do action continuousMeasure;
		}
		
		transition operational_to_powerOff
			first operational
			accept PowerOffCommand
			then powerOff;
		
		transition operational_to_fault
			first operational
			accept FaultDetected
			then fault;
		
		state fault {
			entry action recordFault;
		}
		
		transition fault_to_initialization
			first fault
			accept ResetCommand
			then initialization;
	}
	
	part def SunSensor {
		attribute sensorIdentifier : String default "SUN-SENSOR-001";
		attribute fieldOfViewAngle : AngleValue;
		attribute measurementAccuracy : AngleValue;
		attribute samplingRate : Real default 20.0;
		
		port solarInput : SolarInputPort;
		port measurementOutput : MeasurementOutputPort;
		port powerSupply : PowerSupplyPort;
		
		part photodiodeArray : PhotodiodeElement[4] {
			attribute :>> elementID = ("PD1", "PD2", "PD3", "PD4");
			attribute :>> sensitiveArea = 16.0;
			attribute :>> spectralResponse = 0.6;
		}
		
		part signalProcessor : SignalProcessor[1];
		part angleCalculator : AngleCalculator[1];
		part measurementValidator : MeasurementValidator[1];
		
		part sensorStateMachine {
			state operatingState : SensorStates;
		}
		
		connect solarInput to photodiodeArray.solarIn;
		
		connection PhotodiodeToProcessor {
			end source : PhotodiodeElement[4];
			end target : SignalProcessor[1];
		}
		connect photodiodeArray to signalProcessor via PhotodiodeToProcessor;
		
		connection ProcessorToCalculator {
			end source : SignalProcessor[1];
			end target : AngleCalculator[1];
		}
		connect signalProcessor to angleCalculator via ProcessorToCalculator;
		
		connection CalculatorToValidator {
			end source : AngleCalculator[1];
			end target : MeasurementValidator[1];
		}
		connect angleCalculator to measurementValidator via CalculatorToValidator;
		
		connection ValidatorToOutput {
			end source : MeasurementValidator[1];
			end target : MeasurementOutputPort;
		}
		connect measurementValidator to measurementOutput via ValidatorToOutput;
		
		action measureSolarPosition {
			in item incomingRadiation : SolarRadiation;
			out item sensorOutput : SensorMeasurement;
			
			bind incomingRadiation = solarInput::radiation;
			
			action captureSignals {
				in item radiation : SolarRadiation;
				out item rawSignals : RawSensorSignal;
				
				fork;
				then action pd1Detect : photodiodeArray[1]::detectRadiation {
					in item incidentLight = radiation;
					out attribute outputVoltage;
				}
				then joinNode;
				
				then action pd2Detect : photodiodeArray[2]::detectRadiation {
					in item incidentLight = radiation;
					out attribute outputVoltage;
				}
				then joinNode;
				
				then action pd3Detect : photodiodeArray[3]::detectRadiation {
					in item incidentLight = radiation;
					out attribute outputVoltage;
				}
				then joinNode;
				
				then action pd4Detect : photodiodeArray[4]::detectRadiation {
					in item incidentLight = radiation;
					out attribute outputVoltage;
				}
				then joinNode;
				
				join joinNode;
				then combineSignals;
				
				action combineSignals {
					out item signals : RawSensorSignal;
				}
				
				bind combineSignals.signals = rawSignals;
			}
			
			then action processSignals : signalProcessor::processSignals {
				in attribute inputSignals;
				out attribute outputSignals;
			}
			
			then action calculateAngles : angleCalculator::calculateAngles {
				in attribute quadrantReadings;
				out attribute computedAzimuth;
				out attribute computedElevation;
			}
			
			then action validateMeasurement : measurementValidator::validateMeasurement {
				in attribute azimuth;
				in attribute elevation;
				out item finalMeasurement;
			}
			
			flow from captureSignals.rawSignals to processSignals.inputSignals;
			flow from processSignals.outputSignals to calculateAngles.quadrantReadings;
			flow from calculateAngles.computedAzimuth to validateMeasurement.azimuth;
			flow from calculateAngles.computedElevation to validateMeasurement.elevation;
			
			bind validateMeasurement.finalMeasurement = sensorOutput;
			bind sensorOutput = measurementOutput::measurement;
		}
	}
	
	requirement def SunSensorPerformanceRequirements {
		doc /* Requirements for sun sensor sensing unit performance and functionality */
		
		requirement accuracyRequirement {
			doc /* The sun sensor shall measure solar angles with accuracy of 0.5 degrees or better */
			
			subject sensor : SunSensor;
		}
		
		requirement fieldOfViewRequirement {
			doc /* The sun sensor shall provide a field of view of at least 128 degrees */
			
			subject sensor : SunSensor;
		}
		
		requirement samplingRateRequirement {
			doc /* The sun sensor shall provide measurements at a minimum rate of 20 Hz */
			
			subject sensor : SunSensor;
		}
		
		requirement photodiodeRequirement {
			doc /* The sun sensor shall use four photodiode elements arranged in quadrant configuration */
			
			subject sensor : SunSensor;
		}
		
		requirement stateManagementRequirement {
			doc /* The sun sensor shall support initialization, calibration, operational, and fault states */
			
			subject sensor : SunSensor;
		}
	}
	
	part sensingUnit : SunSensor {
		attribute :>> sensorIdentifier = "SENSING-UNIT-SUN-001";
		attribute :>> samplingRate = 25.0;
		
		requirement performanceRequirements : SunSensorPerformanceRequirements {
			subject targetSensor = sensingUnit;
		}
	}
}
