package 'Fuel Level Sensing Unit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	private import NumericalFunctions::*;
	
	comment SystemDescription
	/* This model defines a complete fuel level sensing unit system that measures
	 * fuel quantity in a vehicle tank using a capacitive sensor. The system includes
	 * sensor hardware, signal conditioning, digital processing, and communication
	 * interfaces with comprehensive requirements and operational behaviors. */
	
	attribute def PercentageValue :> RatioValue;
	
	attribute def PercentageUnit :> MeasurementUnit;
	
	attribute picofarad : CapacitanceUnit = farad * 1.0e-12;
	
	port def AnalogSensorPort {
		attribute outputVoltage : ElectricPotentialValue;
		attribute signalQuality : PercentageValue;
	}
	
	port def DigitalOutputPort {
		attribute fuelLevelPercent : PercentageValue;
		attribute fuelVolume : VolumeValue;
		attribute sensorStatus : SensorStatusType;
		attribute timestamp : TimeValue;
	}
	
	port def PowerPort {
		attribute supplyVoltage : ElectricPotentialValue;
		attribute currentDraw : ElectricCurrentValue;
	}
	
	port def DiagnosticPort {
		attribute errorCode : Integer;
		attribute diagnosticMessage : String;
	}
	
	enumeration def SensorStatusType {
		enum operational;
		enum calibrating;
		enum fault;
		enum standby;
	}
	
	item def FuelType {
		attribute density : DensityValue;
		attribute dielectricConstant : Real;
		attribute viscosity : Real;
	}
	
	item regularGasoline : FuelType {
		attribute :>> density = 745[kg/(m^3)];
		attribute :>> dielectricConstant = 2.1;
		attribute :>> viscosity = 0.6;
	}
	
	item diesel : FuelType {
		attribute :>> density = 832[kg/(m^3)];
		attribute :>> dielectricConstant = 2.3;
		attribute :>> viscosity = 3.5;
	}
	
	part def FuelTank {
		doc /* Fuel tank with geometric and capacity specifications. */
		
		attribute tankId : String;
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute currentLevelPercent : PercentageValue;
		attribute tankHeight : LengthValue;
		attribute tankDiameter : LengthValue;
		attribute tankShape : String;
		
		ref item fuelType : FuelType;
		
		attribute levelRatio : Real = currentVolume / capacity;
		attribute computedLevelPercent : PercentageValue = levelRatio * 100.0;
		
		constraint volumeBounds {
			doc /* Current volume must be within physical tank limits. */
			currentVolume >= 0[L] and currentVolume <= capacity
		}
		
		constraint levelConsistency {
			doc /* Level percentage must match volume ratio. */
			abs(currentLevelPercent - computedLevelPercent) < 0.1
		}
	}
	
	part def CapacitiveSensingElement {
		doc /* Capacitive fuel level sensor using parallel plate capacitance principle.
		 * Capacitance varies with fuel level due to changing dielectric medium. */
		
		attribute sensorSerialNumber : String;
		attribute plateArea : AreaValue;
		attribute plateSpacing : LengthValue;
		attribute probeLength : LengthValue;
		attribute immersedDepth : LengthValue;
		attribute measuredCapacitance : CapacitanceValue;
		attribute emptyCapacitance : CapacitanceValue;
		attribute fullCapacitance : CapacitanceValue;
		attribute temperatureCoefficient : Real;
		
		ref item fuelType : FuelType;
		
		attribute immersionRatio : Real = immersedDepth / probeLength;
		attribute capacitanceFactor : Real = 1.0 + (fuelType.dielectricConstant - 1.0) * immersionRatio;
		attribute computedCapacitance : CapacitanceValue = emptyCapacitance * capacitanceFactor;
		
		constraint capacitanceRange {
			doc /* Measured capacitance must be within calibrated range. */
			measuredCapacitance >= emptyCapacitance and 
			measuredCapacitance <= fullCapacitance
		}
	}
	
	part def SignalConditioningCircuit {
		doc /* Converts capacitance variation to proportional voltage signal. */
		
		attribute inputCapacitance : CapacitanceValue;
		attribute outputVoltage : ElectricPotentialValue;
		attribute referenceVoltage : ElectricPotentialValue;
		attribute amplifierGain : Real;
		attribute filterCutoffFrequency : FrequencyValue;
		attribute noiseLevel : ElectricPotentialValue;
		attribute referenceCapacitance : CapacitanceValue;
		
		port analogOutput : AnalogSensorPort;
		port powerInput : PowerPort;
		
		attribute capacitanceRatio : Real = inputCapacitance / referenceCapacitance;
		attribute computedVoltage : ElectricPotentialValue = referenceVoltage * amplifierGain * capacitanceRatio;
		
		constraint outputRange {
			doc /* Output voltage must be within valid signal range. */
			outputVoltage >= 0.5[V] and outputVoltage <= 4.5[V]
		}
	}
	
	part def AnalogToDigitalConverter {
		doc /* Converts analog voltage to digital representation with specified resolution. */
		
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute conversionTime : DurationValue;
		attribute inputRange : ElectricPotentialValue;
		attribute digitalValue : Integer;
		
		port analogInput : AnalogSensorPort;
		port powerInput : PowerPort;
		
		attribute voltageRatio : Real = analogInput.outputVoltage / inputRange;
		attribute maxDigitalValue : Integer = 2 ** resolution;
		attribute computedDigitalValue : Real = voltageRatio * maxDigitalValue;
		
		constraint resolutionLimit {
			doc /* Digital value must not exceed resolution limit. */
			digitalValue >= 0 and digitalValue < maxDigitalValue
		}
	}
	
	part def SignalProcessor {
		doc /* Processes digital signal to compute fuel level with filtering and calibration. */
		
		attribute rawDigitalValue : Integer;
		attribute calibrationOffset : Real;
		attribute calibrationSlope : Real;
		attribute filterCoefficient : Real;
		attribute previousFilteredValue : Real;
		attribute currentFilteredValue : Real;
		attribute computedFuelLevel : PercentageValue;
		
		attribute filterTerm1 : Real = filterCoefficient * rawDigitalValue;
		attribute filterTerm2 : Real = (1.0 - filterCoefficient) * previousFilteredValue;
		attribute filteredValue : Real = filterTerm1 + filterTerm2;
		
		attribute levelValue : PercentageValue = calibrationSlope * currentFilteredValue + calibrationOffset;
		
		constraint levelBounds {
			doc /* Computed fuel level must be within 0-100% range. */
			computedFuelLevel >= 0.0 and computedFuelLevel <= 100.0
		}
	}
	
	part def FuelLevelSensor {
		doc /* Complete fuel level sensor assembly integrating sensing element,
		 * signal conditioning, ADC, and signal processing. */
		
		attribute sensorId : String;
		attribute manufacturerPartNumber : String;
		attribute calibrationDate : String;
		attribute operatingTempMin : TemperatureValue;
		attribute operatingTempMax : TemperatureValue;
		attribute accuracy : PercentageValue;
		
		part sensingElement : CapacitiveSensingElement {
			attribute :>> sensorSerialNumber = "CAP-SEN-2024-001";
			attribute :>> plateArea = 0.0015[m^2];
			attribute :>> plateSpacing = 0.003[m];
			attribute :>> probeLength = 0.5[m];
			attribute :>> emptyCapacitance = 120[picofarad];
			attribute :>> fullCapacitance = 280[picofarad];
			attribute :>> temperatureCoefficient = 0.0002;
		}
		
		part signalConditioner : SignalConditioningCircuit {
			attribute :>> referenceVoltage = 5.0[V];
			attribute :>> amplifierGain = 3.5;
			attribute :>> filterCutoffFrequency = 50[Hz];
			attribute :>> noiseLevel = 0.01[V];
			attribute :>> referenceCapacitance = 100[picofarad];
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 12;
			attribute :>> samplingRate = 20[Hz];
			attribute :>> conversionTime = 0.01[s];
			attribute :>> inputRange = 5.0[V];
		}
		
		part processor : SignalProcessor {
			attribute :>> calibrationOffset = -5.0;
			attribute :>> calibrationSlope = 0.025;
			attribute :>> filterCoefficient = 0.3;
			attribute :>> previousFilteredValue = 0.0;
		}
		
		port sensorOutput : DigitalOutputPort;
		port powerSupply : PowerPort;
		port diagnostics : DiagnosticPort;
		
		connection sensingToConditioner connect sensingElement to signalConditioner {
			bind sensingElement.measuredCapacitance = signalConditioner.inputCapacitance;
		}
		
		connection conditionerToADC connect signalConditioner.analogOutput to adc.analogInput;
		
		connection adcToProcessor connect adc to processor {
			bind adc.digitalValue = processor.rawDigitalValue;
		}
		
		connection processorToOutput connect processor to sensorOutput {
			bind processor.computedFuelLevel = sensorOutput.fuelLevelPercent;
		}
		
		connection powerToConditioner connect powerSupply to signalConditioner.powerInput;
		
		connection powerToADC connect powerSupply to adc.powerInput;
	}
	
	part def SensingUnit {
		doc /* Complete fuel level sensing unit integrating sensor with tank interface,
		 * power management, and communication capabilities. */
		
		attribute unitSerialNumber : String;
		attribute installationDate : String;
		attribute firmwareVersion : String;
		attribute lastCalibrationDate : String;
		attribute operationalHours : DurationValue;
		
		part tank : FuelTank {
			attribute :>> tankId = "TANK-001";
			attribute :>> capacity = 70[L];
			attribute :>> tankHeight = 0.5[m];
			attribute :>> tankDiameter = 0.42[m];
			attribute :>> tankShape = "cylindrical";
			attribute :>> currentVolume = 52.5[L];
		}
		
		part sensor : FuelLevelSensor {
			attribute :>> sensorId = "FLS-2024-001";
			attribute :>> manufacturerPartNumber = "FLS-CAP-500";
			attribute :>> calibrationDate = "2024-01-15";
			attribute :>> operatingTempMin = 233[K];
			attribute :>> operatingTempMax = 398[K];
			attribute :>> accuracy = 1.5;
		}
		
		port dataOutput : DigitalOutputPort;
		port powerInput : PowerPort;
		port diagnosticInterface : DiagnosticPort;
		
		attribute volumeRatio : Real = tank.currentVolume / tank.capacity;
		attribute immersionDepth : LengthValue = volumeRatio * tank.tankHeight;
		
		connection sensorToTank connect sensor to tank {
			bind sensor.sensingElement.immersedDepth = immersionDepth;
			bind sensor.sensingElement.fuelType = tank.fuelType;
		}
		
		connection sensorDataOutput connect sensor.sensorOutput to dataOutput;
		
		connection powerToSensor connect powerInput to sensor.powerSupply;
		
		connection sensorDiagnostics connect sensor.diagnostics to diagnosticInterface;
		
		constraint volumeCalculation {
			doc /* Output volume must match tank current volume. */
			dataOutput.fuelVolume == tank.currentVolume
		}
		
		constraint levelCalculation {
			doc /* Output level percent must match tank level. */
			abs(dataOutput.fuelLevelPercent - tank.currentLevelPercent) < 2.0
		}
	}
	
	action def MeasureFuelLevel {
		doc /* Action to measure current fuel level and update output. */
		
		in tankVolume : VolumeValue;
		in tankCapacity : VolumeValue;
		in sensorCapacitance : CapacitanceValue;
		out fuelLevelPercent : PercentageValue;
		out fuelVolume : VolumeValue;
		out measurementTimestamp : TimeValue;
		
		action computeLevel {
			fuelLevelPercent = (tankVolume / tankCapacity) * 100.0;
			fuelVolume = tankVolume;
		}
	}
	
	action def CalibrateSensor {
		doc /* Action to calibrate sensor using empty and full tank readings. */
		
		in emptyReading : CapacitanceValue;
		in fullReading : CapacitanceValue;
		in emptyVolume : VolumeValue;
		in fullVolume : VolumeValue;
		out calibrationSlope : Real;
		out calibrationOffset : Real;
		out calibrationSuccess : Boolean;
		
		action calculateCalibration {
			calibrationSlope = (100.0 - 0.0) / (fullReading - emptyReading);
			calibrationOffset = 0.0 - calibrationSlope * emptyReading;
			calibrationSuccess = (fullReading > emptyReading);
		}
	}
	
	action def PerformDiagnostics {
		doc /* Action to perform sensor diagnostics and fault detection. */
		
		in sensorVoltage : ElectricPotentialValue;
		in expectedVoltageMin : ElectricPotentialValue;
		in expectedVoltageMax : ElectricPotentialValue;
		out diagnosticResult : Boolean;
		out faultCode : Integer;
		
		action checkSensor {
			if (sensorVoltage < expectedVoltageMin) {
				diagnosticResult = false;
				faultCode = 101;
			} else {
				if (sensorVoltage > expectedVoltageMax) {
					diagnosticResult = false;
					faultCode = 102;
				} else {
					diagnosticResult = true;
					faultCode = 0;
				}
			}
		}
	}
	
	item def TestPassedEvent;
	item def TestFailedEvent;
	item def MeasurementRequestEvent;
	item def CalibrationRequestEvent;
	item def MeasurementCompleteEvent;
	item def SensorFaultEvent;
	item def CalibrationCompleteEvent;
	item def FaultClearedEvent;
	item def ResetCommandEvent;
	
	state def SensingUnitOperationalStates {
		doc /* State machine defining operational behavior of sensing unit. */
		
		entry; then powerOn;
		
		state powerOn {
			entry action initializeSystem;
		}
		then selfTest;
		
		state selfTest {
			entry action performSelfTest : PerformDiagnostics;
		}
		accept TestPassedEvent then initialization;
		accept TestFailedEvent then faultMode;
		
		state initialization {
			entry action loadCalibration;
			do action initSensor;
		}
		then standby;
		
		state standby {
			entry action enterLowPower;
		}
		accept MeasurementRequestEvent then measuring;
		accept CalibrationRequestEvent then calibration;
		
		state measuring {
			entry action startMeasurement;
			do action continuousMeasure : MeasureFuelLevel;
			exit action stopMeasurement;
		}
		accept MeasurementCompleteEvent then dataProcessing;
		accept SensorFaultEvent then faultMode;
		
		state dataProcessing {
			entry action processData;
			do action filterAndValidate;
		}
		then outputReady;
		
		state outputReady {
			entry action updateOutput;
			do action transmitData;
		}
		then standby;
		
		state calibration {
			entry action beginCalibration;
			do action calibrate : CalibrateSensor;
			exit action saveCalibration;
		}
		accept CalibrationCompleteEvent then standby;
		
		state faultMode {
			entry action logFault;
			do action runDiagnostics : PerformDiagnostics;
		}
		accept FaultClearedEvent then standby;
		accept ResetCommandEvent then powerOn;
	}
	
	requirement def SensorAccuracyRequirement {
		doc /* Defines accuracy requirements for fuel level measurement across operating range. */
		
		subject sensor : FuelLevelSensor;
		
		attribute maxAbsoluteError : PercentageValue;
		attribute operatingRangeMin : PercentageValue;
		attribute operatingRangeMax : PercentageValue;
		attribute actualFuelLevel : PercentageValue;
		
		require constraint accuracyConstraint {
			doc /* Sensor error must not exceed maximum absolute error. */
			abs(sensor.sensorOutput.fuelLevelPercent - actualFuelLevel) <= maxAbsoluteError
		}
	}
	
	requirement def SensorResponseRequirement {
		doc /* Defines response time requirements for sensor measurements. */
		
		subject sensor : FuelLevelSensor;
		
		attribute maxResponseTime : DurationValue;
		attribute updateRate : FrequencyValue;
		
		require constraint responseConstraint {
			doc /* Sensor must respond within maximum response time. */
			sensor.adc.conversionTime <= maxResponseTime
		}
		
		require constraint updateRateConstraint {
			doc /* Sensor must update at minimum specified rate. */
			sensor.adc.samplingRate >= updateRate
		}
	}
	
	requirement def SensorRangeRequirement {
		doc /* Defines measurement range requirements for sensor. */
		
		subject sensor : FuelLevelSensor;
		
		attribute minMeasurableLevel : PercentageValue;
		attribute maxMeasurableLevel : PercentageValue;
		
		require constraint rangeConstraint {
			doc /* Sensor must measure across full specified range. */
			sensor.sensorOutput.fuelLevelPercent >= minMeasurableLevel and
			sensor.sensorOutput.fuelLevelPercent <= maxMeasurableLevel
		}
	}
	
	requirement def SensingUnitIntegrationRequirement {
		doc /* Defines integration requirements for complete sensing unit. */
		
		subject unit : SensingUnit;
		
		attribute maxPowerConsumption : PowerValue;
		attribute operatingVoltageMin : ElectricPotentialValue;
		attribute operatingVoltageMax : ElectricPotentialValue;
		
		require constraint powerConstraint {
			doc /* Unit power consumption must not exceed maximum. */
			unit.powerInput.supplyVoltage * unit.powerInput.currentDraw <= maxPowerConsumption
		}
		
		require constraint voltageConstraint {
			doc /* Operating voltage must be within specified range. */
			unit.powerInput.supplyVoltage >= operatingVoltageMin and
			unit.powerInput.supplyVoltage <= operatingVoltageMax
		}
		
		require constraint dataValidityConstraint {
			doc /* Output data must be valid during normal operation. */
			unit.dataOutput.sensorStatus == SensorStatusType::operational implies
			unit.dataOutput.fuelLevelPercent >= 0.0 and unit.dataOutput.fuelLevelPercent <= 100.0
		}
	}
	
	requirement <'REQ-001'> sensorAccuracy : SensorAccuracyRequirement {
		doc /* Sensor must maintain ±1.5% accuracy across full operating range. */
		
		subject sensor : FuelLevelSensor;
		attribute :>> maxAbsoluteError = 1.5;
		attribute :>> operatingRangeMin = 0.0;
		attribute :>> operatingRangeMax = 100.0;
		
		assume constraint temperatureAssumption {
			doc /* Sensor operates within specified temperature range. */
			sensor.operatingTempMin >= 233[K] and
			sensor.operatingTempMax <= 398[K]
		}
	}
	
	requirement <'REQ-002'> sensorResponse : SensorResponseRequirement {
		doc /* Sensor must respond within 100ms and update at minimum 10Hz. */
		
		subject sensor : FuelLevelSensor;
		attribute :>> maxResponseTime = 0.1[s];
		attribute :>> updateRate = 10[Hz];
	}
	
	requirement <'REQ-003'> sensorRange : SensorRangeRequirement {
		doc /* Sensor must measure fuel level from 0% to 100% of tank capacity. */
		
		subject sensor : FuelLevelSensor;
		attribute :>> minMeasurableLevel = 0.0;
		attribute :>> maxMeasurableLevel = 100.0;
	}
	
	requirement <'REQ-004'> unitIntegration : SensingUnitIntegrationRequirement {
		doc /* Sensing unit must operate on 12V supply with max 2W power consumption. */
		
		subject unit : SensingUnit;
		attribute :>> maxPowerConsumption = 2[W];
		attribute :>> operatingVoltageMin = 10.5[V];
		attribute :>> operatingVoltageMax = 14.5[V];
	}
	
	requirement <'REQ-005'> systemReliability {
		doc /* Sensing unit must maintain operational reliability over service life. */
		
		subject unit : SensingUnit;
		
		require constraint reliabilityConstraint {
			doc /* Unit must operate for minimum 10000 hours without failure. */
			unit.operationalHours >= 10000[h]
		}
		
		require constraint calibrationStability {
			doc /* Calibration must remain stable for minimum 2 years. */
			unit.sensor.calibrationDate != "" and
			unit.lastCalibrationDate != ""
		}
	}
	
	part fuelSensingSystem : SensingUnit {
		doc /* Instantiated fuel sensing system for gasoline vehicle application. */
		
		attribute :>> unitSerialNumber = "FSU-2024-001";
		attribute :>> installationDate = "2024-01-20";
		attribute :>> firmwareVersion = "v2.3.1";
		attribute :>> lastCalibrationDate = "2024-01-18";
		attribute :>> operationalHours = 0[h];
		
		part :>> tank {
			ref item :>> fuelType = regularGasoline;
		}
		
		part :>> sensor {
			attribute :>> accuracy = 1.2;
		}
	}
}
