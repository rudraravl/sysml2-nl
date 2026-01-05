package 'LED Light Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def IlluminanceUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = IlluminanceUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def IlluminanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : IlluminanceUnit;
	}
	
	attribute illuminance : IlluminanceValue :> scalarQuantities;
	
	attribute def VoltageUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = VoltageUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute voltage : VoltageValue :> scalarQuantities;
	
	attribute def CurrentUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = CurrentUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CurrentUnit;
	}
	
	attribute current : CurrentValue :> scalarQuantities;
	
	attribute def ResistanceUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = ResistanceUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def ResistanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ResistanceUnit;
	}
	
	attribute resistance : ResistanceValue :> scalarQuantities;
	
	attribute def CapacitanceUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = CapacitanceUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def CapacitanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CapacitanceUnit;
	}
	
	attribute capacitance : CapacitanceValue :> scalarQuantities;
	
	enum def OperatingMode {
		enum standby;
		enum sensing;
		enum converting;
		enum transmitting;
		enum fault;
	}
	
	port def OpticalPort {
		in attribute incidentLight : IlluminanceValue;
	}
	
	port def AnalogSignalPort {
		out attribute signalVoltage : VoltageValue;
	}
	
	port def DigitalDataPort {
		out attribute digitalValue : Integer;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : VoltageValue;
		out attribute currentDraw : CurrentValue;
	}
	
	item def LightPhotons;
	item def ElectronHolePairs;
	item def AnalogSignal;
	item def DigitalData;
	
	action def PhotoelectricConversion {
		in item photons : LightPhotons;
		in lightIntensity : IlluminanceValue;
		out item carriers : ElectronHolePairs;
		out photocurrent : CurrentValue;
	}
	
	action def CurrentToVoltageConversion {
		in photocurrent : CurrentValue;
		in transimpedance : ResistanceValue;
		out outputVoltage : VoltageValue;
	}
	
	action def SignalAmplification {
		in inputVoltage : VoltageValue;
		in gainFactor : Real;
		out amplifiedVoltage : VoltageValue;
	}
	
	action def AnalogToDigitalConversion {
		in analogVoltage : VoltageValue;
		in referenceVoltage : VoltageValue;
		in resolution : Integer;
		out digitalCode : Integer;
	}
	
	action def MeasureIlluminance {
		in item incidentPhotons : LightPhotons;
		in ambientLight : IlluminanceValue;
		in biasVoltage : VoltageValue;
		in transimpedanceGain : ResistanceValue;
		in amplifierGain : Real;
		in adcReference : VoltageValue;
		in adcResolution : Integer;
		out item digitalOutput : DigitalData;
		out digitalReading : Integer;
		
		bind photoConvert.lightIntensity = ambientLight;
		
		action photoConvert : PhotoelectricConversion {
			in item photons;
			in lightIntensity;
			out item carriers;
			out photocurrent;
		}
		
		succession flow from photoConvert.photocurrent to ivConvert.photocurrent;
		
		action ivConvert : CurrentToVoltageConversion {
			in photocurrent;
			in transimpedance;
			out outputVoltage;
		}
		
		bind ivConvert.transimpedance = transimpedanceGain;
		
		succession flow from ivConvert.outputVoltage to amplify.inputVoltage;
		
		action amplify : SignalAmplification {
			in inputVoltage;
			in gainFactor;
			out amplifiedVoltage;
		}
		
		bind amplify.gainFactor = amplifierGain;
		
		succession flow from amplify.amplifiedVoltage to digitize.analogVoltage;
		
		action digitize : AnalogToDigitalConversion {
			in analogVoltage;
			in referenceVoltage;
			in resolution;
			out digitalCode;
		}
		
		bind digitize.referenceVoltage = adcReference;
		bind digitize.resolution = adcResolution;
		bind digitize.digitalCode = digitalReading;
	}
	
	part def LEDPhotodetector {
		attribute junctionArea : LengthValue;
		attribute spectralSensitivity : Real;
		attribute reverseVoltage : VoltageValue;
		attribute darkCurrent : CurrentValue;
		attribute quantumEfficiency : Real;
		
		port opticalInput : OpticalPort;
		port electricalOutput : AnalogSignalPort;
		
		attribute generatedCurrent : CurrentValue;
	}
	
	part def TransimpedanceAmplifier {
		attribute feedbackResistance : ResistanceValue;
		attribute inputBias : CurrentValue;
		attribute bandwidth : Real;
		attribute noiseVoltage : VoltageValue;
		
		port currentInput : AnalogSignalPort;
		port voltageOutput : AnalogSignalPort;
		port powerInput : PowerSupplyPort;
	}
	
	part def InstrumentationAmplifier {
		attribute voltageGain : Real;
		attribute inputImpedance : ResistanceValue;
		attribute commonModeRejection : Real;
		
		port signalInput : AnalogSignalPort;
		port amplifiedOutput : AnalogSignalPort;
		port powerInput : PowerSupplyPort;
	}
	
	part def LowPassFilter {
		attribute cutoffFrequency : Real;
		attribute filterOrder : Integer;
		attribute resistorValue : ResistanceValue;
		attribute capacitorValue : CapacitanceValue;
		
		port analogInput : AnalogSignalPort;
		port filteredOutput : AnalogSignalPort;
	}
	
	part def ADCConverter {
		attribute bitResolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : VoltageValue;
		attribute conversionTime : Real;
		
		port analogInput : AnalogSignalPort;
		port digitalOutput : DigitalDataPort;
		port powerInput : PowerSupplyPort;
	}
	
	part def SignalProcessor {
		attribute processingSpeed : Real;
		attribute memoryCapacity : Integer;
		attribute calibrationCoefficients : Real[*];
		
		port dataInput : DigitalDataPort;
		port processedOutput : DigitalDataPort;
		port powerInput : PowerSupplyPort;
		
		action calibrateReading {
			in rawValue : Integer;
			in coefficients : Real[*];
			out calibratedIlluminance : IlluminanceValue;
		}
		
		action filterNoise {
			in rawSamples : Integer[*];
			out filteredValue : Integer;
		}
	}
	
	part def LEDLightSensingUnit {
		attribute operatingMode : OperatingMode default = OperatingMode::standby;
		attribute calibrationFactor : Real default = 1.0;
		attribute measurementRange : IlluminanceValue[2];
		attribute measurementAccuracy : Real;
		attribute responseTime : Real;
		attribute operatingTemperatureRange : Real[2];
		
		part ledSensor : LEDPhotodetector[1] {
			attribute :>> junctionArea = 9.0[mm^2];
			attribute :>> spectralSensitivity = 0.48;
			attribute :>> reverseVoltage = 5.0[V];
			attribute :>> darkCurrent = 5.0e-9[A];
			attribute :>> quantumEfficiency = 0.65;
		}
		
		part tiaStage : TransimpedanceAmplifier[1] {
			attribute :>> feedbackResistance = 1.0e6[Ω];
			attribute :>> inputBias = 1.0e-12[A];
			attribute :>> bandwidth = 100000.0;
			attribute :>> noiseVoltage = 5.0e-9[V];
		}
		
		part gainStage : InstrumentationAmplifier[1] {
			attribute :>> voltageGain = 100.0;
			attribute :>> inputImpedance = 1.0e9[Ω];
			attribute :>> commonModeRejection = 120.0;
		}
		
		part antiAliasFilter : LowPassFilter[1] {
			attribute :>> cutoffFrequency = 50000.0;
			attribute :>> filterOrder = 4;
			attribute :>> resistorValue = 10.0e3[Ω];
			attribute :>> capacitorValue = 100.0e-12[F];
		}
		
		part analogDigitalConverter : ADCConverter[1] {
			attribute :>> bitResolution = 16;
			attribute :>> samplingRate = 100000.0;
			attribute :>> referenceVoltage = 5.0[V];
			attribute :>> conversionTime = 0.00001;
		}
		
		part processor : SignalProcessor[1] {
			attribute :>> processingSpeed = 100.0e6;
			attribute :>> memoryCapacity = 65536;
			attribute :>> calibrationCoefficients = (1.0, 0.05, 0.001);
		}
		
		port lightInput : OpticalPort;
		port dataOutput : DigitalDataPort;
		port powerSupply : PowerSupplyPort;
		
		connection : AnalogSignalPort
			connect ledSensor.electricalOutput to tiaStage.currentInput;
		
		connection : AnalogSignalPort
			connect tiaStage.voltageOutput to gainStage.signalInput;
		
		connection : AnalogSignalPort
			connect gainStage.amplifiedOutput to antiAliasFilter.analogInput;
		
		connection : AnalogSignalPort
			connect antiAliasFilter.filteredOutput to analogDigitalConverter.analogInput;
		
		connection : DigitalDataPort
			connect analogDigitalConverter.digitalOutput to processor.dataInput;
		
		connection : DigitalDataPort
			connect processor.processedOutput to dataOutput;
		
		connect powerSupply to tiaStage.powerInput;
		connect powerSupply to gainStage.powerInput;
		connect powerSupply to analogDigitalConverter.powerInput;
		connect powerSupply to processor.powerInput;
		
		action performSensing : MeasureIlluminance {
			in item incidentPhotons;
			in ambientLight;
			in biasVoltage;
			in transimpedanceGain;
			in amplifierGain;
			in adcReference;
			in adcResolution;
			out item digitalOutput;
			out digitalReading;
		}
		
		state operationStateMachine {
			entry; then standby;
			
			state standby {
				entry assign operatingMode = OperatingMode::standby;
			}
			
			transition standby_to_sensing
				first standby
				accept startMeasurement
				then sensing;
			
			state sensing {
				entry assign operatingMode = sensing;
				do action performSensing;
			}
			
			transition sensing_to_converting
				first sensing
				if performSensing.digitalReading >= 0
				then converting;
			
			transition sensing_to_fault
				first sensing
				if performSensing.digitalReading < 0
				then fault;
			
			state converting {
				entry assign operatingMode = converting;
				do action processor.calibrateReading;
			}
			
			transition converting_to_transmitting
				first converting
				then transmitting;
			
			state transmitting {
				entry assign operatingMode = transmitting;
			}
			
			transition transmitting_to_standby
				first transmitting
				then standby;
			
			state fault {
				entry assign operatingMode = fault;
			}
			
			transition fault_to_standby
				first fault
				accept resetSystem
				then standby;
		}
	}
	
	part sensingUnit : LEDLightSensingUnit {
		attribute :>> calibrationFactor = 0.92;
		attribute :>> measurementRange = (0.01[lx], 100000.0[lx]);
		attribute :>> measurementAccuracy = 0.02;
		attribute :>> responseTime = 0.001;
		attribute :>> operatingTemperatureRange = (-20.0, 85.0);
		
		part :>> ledSensor {
			attribute :>> junctionArea = 12.0[mm^2];
			attribute :>> spectralSensitivity = 0.55;
			attribute :>> quantumEfficiency = 0.72;
		}
		
		part :>> tiaStage {
			attribute :>> feedbackResistance = 2.2e6[Ω];
			attribute :>> bandwidth = 150000.0;
		}
		
		part :>> gainStage {
			attribute :>> voltageGain = 50.0;
		}
		
		part :>> analogDigitalConverter {
			attribute :>> bitResolution = 24;
			attribute :>> samplingRate = 200000.0;
		}
	}
	
	requirement def SensorPerformanceRequirement {
		subject sensor : LEDLightSensingUnit;
		
		doc /* The LED light sensing unit shall achieve specified performance metrics. */
		
		require accuracyConstraint {
			sensor.measurementAccuracy <= 0.05
		}
		
		require rangeConstraint {
			sensor.measurementRange[2].num >= 10000.0
		}
		
		require responseConstraint {
			sensor.responseTime <= 0.01
		}
		
		require darkCurrentConstraint {
			sensor.ledSensor.darkCurrent.num <= 50.0e-9
		}
	}
	
	requirement def OperationalRequirement {
		subject sensor : LEDLightSensingUnit;
		
		doc /* The LED light sensing unit shall operate reliably under specified conditions. */
		
		require temperatureConstraint {
			sensor.operatingTemperatureRange[1] <= -10.0 and
			sensor.operatingTemperatureRange[2] >= 70.0
		}
		
		require powerConstraint {
			sensor.powerSupply.supplyVoltage.num >= 3.0 and
			sensor.powerSupply.supplyVoltage.num <= 5.5
		}
	}
	
	requirement performanceSpec : SensorPerformanceRequirement {
		subject sensingUnit;
	}
	
	requirement operationalSpec : OperationalRequirement {
		subject sensingUnit;
	}
}
