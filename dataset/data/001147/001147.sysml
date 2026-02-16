package 'Microwave Radiometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BrightnessTemperature :> ThermodynamicTemperatureValue;
	attribute def RadiometricResolution :> ThermodynamicTemperatureValue;
	attribute def FrequencyBand :> FrequencyValue;
	attribute def IntegrationTime :> TimeValue;
	attribute def Bandwidth :> FrequencyValue;
	attribute def AntennaGain :> Real;
	attribute def NoiseTemperature :> ThermodynamicTemperatureValue;
	attribute def Sensitivity :> PowerValue;
	
	item def MicrowaveRadiation {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
		attribute noiseTemperature : ThermodynamicTemperatureValue;
	}
	
	item def RadiometricMeasurement {
		attribute brightnessTemperature : BrightnessTemperature;
		attribute measurementTime : TimeValue;
		attribute frequency : FrequencyBand;
		attribute uncertainty : RadiometricResolution;
	}
	
	item def CalibrationData {
		attribute hotLoadTemperature : ThermodynamicTemperatureValue;
		attribute coldLoadTemperature : ThermodynamicTemperatureValue;
		attribute gainFactor : Real;
		attribute offsetFactor : Real;
	}
	
	port def RadiationInputPort {
		in item radiation : MicrowaveRadiation;
	}
	
	port def RFSignalPort {
		inout item signal : MicrowaveRadiation;
	}
	
	port def DetectedSignalPort {
		out attribute voltage : ElectricPotentialValue;
	}
	
	port def IntegratedSignalPort {
		out attribute integratedValue : Real;
	}
	
	port def MeasurementOutputPort {
		out item measurement : RadiometricMeasurement;
	}
	
	port def CalibrationPort {
		in item calibrationSignal : MicrowaveRadiation;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def ControlPort {
		in attribute operatingMode : String;
		out attribute systemStatus : String;
	}
	
	part def AntennaSubsystem {
		doc /* Collects thermal radiation from the target scene. */
		attribute gain : AntennaGain;
		attribute beamwidth : Real;
		attribute efficiency : Real;
		attribute centerFrequency : FrequencyValue;
		port radiationInput : RadiationInputPort;
		port rfOutput : RFSignalPort;
	}
	
	part def ReceiverSubsystem {
		doc /* Amplifies and filters the received microwave signal. */
		attribute noiseTemperature : NoiseTemperature;
		attribute bandwidth : Bandwidth;
		attribute gainValue : Real;
		port rfInput : RFSignalPort;
		port amplifiedOutput : RFSignalPort;
		port powerInput : PowerSupplyPort;
	}
	
	part def DetectorSubsystem {
		doc /* Converts RF power to a proportional voltage. */
		attribute responsivity : Real;
		attribute detectionRange : PowerValue;
		port rfInput : RFSignalPort;
		port detectedOutput : DetectedSignalPort;
	}
	
	part def IntegratorSubsystem {
		doc /* Integrates the detected signal over a specified time period. */
		attribute integrationTime : IntegrationTime;
		attribute filterBandwidth : FrequencyValue;
		port signalInput : DetectedSignalPort;
		port integratedOutput : IntegratedSignalPort;
	}
	
	part def ProcessorSubsystem {
		doc /* Converts integrated voltage to calibrated brightness temperature. */
		attribute calibrationCoefficients : Real[*];
		attribute processingAlgorithm : String;
		port dataInput : IntegratedSignalPort;
		port measurementOutput : MeasurementOutputPort;
		port controlInterface : ControlPort;
	}
	
	part def CalibrationSubsystem {
		doc /* Provides reference sources for two-point calibration. */
		part hotLoad {
			attribute physicalTemperature : ThermodynamicTemperatureValue;
			port calibrationOutput : CalibrationPort;
		}
		part coldLoad {
			attribute physicalTemperature : ThermodynamicTemperatureValue;
			port calibrationOutput : CalibrationPort;
		}
	}
	
	part def MicrowaveRadiometerSystem {
		doc /* 
		A microwave radiometer system that measures the brightness temperature 
		of a target by detecting thermal radiation in the microwave spectrum.
		The system operates by collecting electromagnetic radiation, amplifying 
		and filtering the signal, detecting its power, integrating over time, 
		and converting to calibrated temperature measurements.
		*/
		
		attribute operatingFrequency : FrequencyBand = 23.8e9[Hz];
		attribute systemNoiseTemperature : NoiseTemperature = 600[K];
		attribute radiometricResolution : RadiometricResolution = 0.3[K];
		attribute integrationPeriod : IntegrationTime = 1.0[s];
		attribute measurementBandwidth : Bandwidth = 400e6[Hz];
		
		port sceneInput : RadiationInputPort;
		port dataOutput : MeasurementOutputPort;
		port powerSupply : PowerSupplyPort;
		port systemControl : ControlPort;
		
		part antenna : AntennaSubsystem {
			attribute :>> gain = 35.0;
			attribute :>> centerFrequency = operatingFrequency;
			attribute :>> beamwidth = 3.5;
			attribute :>> efficiency = 0.85;
		}
		
		part receiver : ReceiverSubsystem {
			attribute :>> noiseTemperature = 400[K];
			attribute :>> bandwidth = measurementBandwidth;
			attribute :>> gainValue = 60.0;
		}
		
		part detector : DetectorSubsystem {
			attribute :>> responsivity = 1500.0;
			attribute :>> detectionRange = 1.0e-9[W];
		}
		
		part integrator : IntegratorSubsystem {
			attribute :>> integrationTime = integrationPeriod;
			attribute :>> filterBandwidth = 1.0[Hz];
		}
		
		part processor : ProcessorSubsystem {
			attribute :>> processingAlgorithm = "Dicke Radiometer";
		}
		
		part calibration : CalibrationSubsystem {
			part :>> hotLoad {
				attribute :>> physicalTemperature = 343[K];
			}
			part :>> coldLoad {
				attribute :>> physicalTemperature = 77[K];
			}
		}
		
		connection sceneToAntenna connect sceneInput to antenna.radiationInput;
		connection antennaToReceiver connect antenna.rfOutput to receiver.rfInput;
		connection receiverToDetector connect receiver.amplifiedOutput to detector.rfInput;
		connection detectorToIntegrator connect detector.detectedOutput to integrator.signalInput;
		connection integratorToProcessor connect integrator.integratedOutput to processor.dataInput;
		connection processorToOutput connect processor.measurementOutput to dataOutput;
		connection powerToReceiver connect powerSupply to receiver.powerInput;
		connection controlToProcessor connect systemControl to processor.controlInterface;
		
		perform action measureBrightnessTemperature;
	}
	
	action def PerformCalibration {
		in attribute hotLoadTemp : ThermodynamicTemperatureValue;
		in attribute coldLoadTemp : ThermodynamicTemperatureValue;
		in attribute hotLoadVoltage : Real;
		in attribute coldLoadVoltage : Real;
		out item calibrationData : CalibrationData;
	}
	
	action def CollectRadiation {
		in item incomingRadiation : MicrowaveRadiation;
		out item collectedSignal : MicrowaveRadiation;
	}
	
	action def AmplifySignal {
		in item inputSignal : MicrowaveRadiation;
		in attribute gain : Real;
		out item amplifiedSignal : MicrowaveRadiation;
	}
	
	action def DetectPower {
		in item rfSignal : MicrowaveRadiation;
		out attribute detectedVoltage : ElectricPotentialValue;
	}
	
	action def IntegrateSignal {
		in attribute inputVoltage : ElectricPotentialValue;
		in attribute integrationTime : IntegrationTime;
		out attribute integratedValue : Real;
	}
	
	action def ConvertToTemperature {
		in attribute rawValue : Real;
		in item calibration : CalibrationData;
		out attribute brightnessTemp : BrightnessTemperature;
	}
	
	action def OutputMeasurement {
		in attribute temperature : BrightnessTemperature;
		in attribute timestamp : TimeValue;
		in attribute frequency : FrequencyBand;
		out item measurement : RadiometricMeasurement;
	}
	
	action measureBrightnessTemperature {
		doc /* 
		Primary measurement cycle that calibrates the radiometer and 
		measures the brightness temperature of the target scene.
		*/
		
		first start;
		
		then merge measurementCycle;
		
		then action calibrate : PerformCalibration {
			in hotLoadTemp = 343[K];
			in coldLoadTemp = 77[K];
			in hotLoadVoltage = 4.5;
			in coldLoadVoltage = 1.2;
			out calibrationData;
		}
		
		then action collect : CollectRadiation {
			out collectedSignal;
		}
		
		then action amplify : AmplifySignal {
			in inputSignal = collect.collectedSignal;
			in gain = 60.0;
			out amplifiedSignal;
		}
		
		then action detect : DetectPower {
			in rfSignal = amplify.amplifiedSignal;
			out detectedVoltage;
		}
		
		then action integrate : IntegrateSignal {
			in inputVoltage = detect.detectedVoltage;
			in integrationTime = 1.0[s];
			out integratedValue;
		}
		
		then action convert : ConvertToTemperature {
			in rawValue = integrate.integratedValue;
			in calibration = calibrate.calibrationData;
			out brightnessTemp;
		}
		
		then action output : OutputMeasurement {
			in temperature = convert.brightnessTemp;
			in timestamp = 0.0[s];
			in frequency = 23.8e9[Hz];
			out measurement;
		}
		
		then decide;
			if output.measurement.uncertainty <= 0.5[K] then measurementCycle;
			if output.measurement.uncertainty > 0.5[K] then recalibrate;
		
		action recalibrate {
			then merge measurementCycle;
		}
	}
	
	state def RadiometerOperationalStates {
		entry; then Initialization;
		
		state Initialization;
		state Calibrating;
		state Measuring;
		state DataProcessing;
		state Standby;
		
		transition first Initialization then Calibrating
			accept powerOn : String;
		
		transition first Calibrating then Measuring
			accept calibrationComplete : String;
		
		transition first Measuring then DataProcessing
			after 1.0[s];
		
		transition first DataProcessing then Measuring
			accept continueMeasurement : String;
		
		transition first DataProcessing then Calibrating
			after 600[s];
		
		transition first Measuring then Standby
			accept stopMeasurement : String;
		
		transition first Standby then Calibrating
			accept resumeMeasurement : String;
	}
	
	requirement <'RAD-REQ-001'> primaryFunctionRequirement {
		doc /* 
		The microwave radiometer system shall measure the brightness temperature 
		of a target scene by detecting thermal radiation in the microwave spectrum.
		*/
		
		subject radiometer : MicrowaveRadiometerSystem;
		
		require constraint measurementCapability {
			radiometer.operatingFrequency >= 1e9[Hz] and
			radiometer.operatingFrequency <= 100e9[Hz]
		}
	}
	
	requirement <'RAD-REQ-002'> radiometricResolutionRequirement {
		doc /* 
		The radiometer shall achieve a radiometric resolution better than 
		0.5 K for a 1 second integration time.
		*/
		
		subject radiometer : MicrowaveRadiometerSystem;
		
		require constraint resolutionLimit {
			radiometer.radiometricResolution <= 0.5[K]
		}
		
		require constraint integrationTimeSpec {
			radiometer.integrationPeriod == 1.0[s]
		}
	}
	
	requirement <'RAD-REQ-003'> calibrationRequirement {
		doc /* 
		The radiometer shall perform two-point calibration using hot and cold 
		reference loads with known physical temperatures.
		*/
		
		subject radiometer : MicrowaveRadiometerSystem;
		
		require constraint calibrationSourcesPresent {
			radiometer.calibration.hotLoad.physicalTemperature > 
			radiometer.calibration.coldLoad.physicalTemperature
		}
		
		require constraint calibrationTemperatureRange {
			radiometer.calibration.hotLoad.physicalTemperature >= 300[K] and
			radiometer.calibration.coldLoad.physicalTemperature <= 100[K]
		}
	}
	
	requirement <'RAD-REQ-004'> systemNoiseRequirement {
		doc /* 
		The system noise temperature shall be less than 1000 K to ensure 
		adequate measurement sensitivity.
		*/
		
		subject radiometer : MicrowaveRadiometerSystem;
		
		require constraint noiseTemperatureLimit {
			radiometer.systemNoiseTemperature < 1000[K]
		}
	}
	
	requirement <'RAD-REQ-005'> measurementAccuracyRequirement {
		doc /* 
		The radiometer shall measure brightness temperature with an absolute 
		accuracy of ±2 K over the range of 50 K to 350 K.
		*/
		
		subject radiometer : MicrowaveRadiometerSystem;
		
		require constraint accuracySpec {
			radiometer.radiometricResolution <= 2.0[K]
		}
	}
	
	requirement radiometerSystemRequirements {
		doc /* 
		Top-level requirements for the microwave radiometer system defining 
		its primary function, performance characteristics, and operational constraints.
		*/
		
		require primaryFunctionRequirement;
		require radiometricResolutionRequirement;
		require calibrationRequirement;
		require systemNoiseRequirement;
		require measurementAccuracyRequirement;
	}
}
