package 'Piezoelectric Accelerometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VibrationEvent;
	attribute def CalibrationCommand;
	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	
	value def AccelerationMeasurement {
		attribute magnitude : Real;
		attribute unit : String default "m/s^2";
	}
	
	value def ElectricCharge {
		attribute magnitude : Real;
		attribute unit : String default "pC";
	}
	
	value def AnalogVoltage {
		attribute magnitude : Real;
		attribute unit : String default "mV";
	}
	
	value def DigitalSignal {
		attribute value : Integer;
		attribute timestamp : Real;
	}
	
	port def MechanicalInputPort {
		in acceleration : AccelerationMeasurement;
	}
	
	port def ChargeOutputPort {
		out charge : ElectricCharge;
	}
	
	port def VoltageInputPort {
		in voltage : AnalogVoltage;
	}
	
	port def VoltageOutputPort {
		out voltage : AnalogVoltage;
	}
	
	port def DigitalOutputPort {
		out signal : DigitalSignal;
	}
	
	port def PowerSupplyPort {
		in supplyVoltage : Real;
	}
	
	part def PiezoelectricCrystal {
		doc /* 
		Converts mechanical stress from acceleration into proportional electric charge 
		through the piezoelectric effect.
		*/
		attribute sensitivity : Real;
		attribute resonantFrequency : Real;
		attribute mass : Real;
		
		port mechanicalInput : MechanicalInputPort;
		port chargeOutput : ChargeOutputPort;
	}
	
	part def ChargeAmplifier {
		doc /* 
		Converts the high-impedance charge signal from the piezoelectric crystal 
		into a low-impedance voltage signal suitable for further processing.
		*/
		attribute gain : Real;
		attribute inputImpedance : Real;
		attribute outputImpedance : Real;
		
		port chargeInput : ChargeOutputPort;
		port voltageOutput : VoltageOutputPort;
		port power : PowerSupplyPort;
	}
	
	part def SignalFilter {
		doc /* 
		Removes unwanted frequency components and noise from the voltage signal 
		to improve measurement accuracy.
		*/
		attribute lowCutoffFrequency : Real;
		attribute highCutoffFrequency : Real;
		attribute filterOrder : Integer;
		
		port voltageInput : VoltageInputPort;
		port voltageOutput : VoltageOutputPort;
		port power : PowerSupplyPort;
	}
	
	part def AnalogToDigitalConverter {
		doc /* 
		Converts the conditioned analog voltage signal into a digital representation 
		for processing and transmission.
		*/
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : Real;
		
		port analogInput : VoltageInputPort;
		port digitalOutput : DigitalOutputPort;
		port power : PowerSupplyPort;
	}
	
	part def SignalProcessor {
		doc /* 
		Applies calibration, scaling, and compensation algorithms to produce 
		accurate acceleration measurements.
		*/
		attribute calibrationFactor : Real;
		attribute temperatureCompensation : Real;
		attribute offsetCorrection : Real;
		
		port digitalInput : DigitalOutputPort;
		port measurementOutput : DigitalOutputPort;
		port power : PowerSupplyPort;
	}
	
	part def MountingBase {
		doc /* 
		Provides mechanical coupling between the measured structure and the 
		piezoelectric sensing element.
		*/
		attribute material : String;
		attribute mountingType : String;
		attribute stiffness : Real;
		
		port mechanicalInterface : MechanicalInputPort;
	}
	
	action def GenerateCharge {
		in appliedAcceleration : AccelerationMeasurement;
		in crystalSensitivity : Real;
		in crystalMass : Real;
		out generatedCharge : ElectricCharge;
	}
	
	action def AmplifyCharge {
		in inputCharge : ElectricCharge;
		in amplifierGain : Real;
		out outputVoltage : AnalogVoltage;
	}
	
	action def FilterSignal {
		in rawVoltage : AnalogVoltage;
		in lowCutoff : Real;
		in highCutoff : Real;
		out filteredVoltage : AnalogVoltage;
	}
	
	action def ConvertToDigital {
		in analogVoltage : AnalogVoltage;
		in adcResolution : Integer;
		in samplingRate : Real;
		out digitalValue : DigitalSignal;
	}
	
	action def ProcessSignal {
		in rawDigital : DigitalSignal;
		in calibration : Real;
		in offset : Real;
		out calibratedAcceleration : AccelerationMeasurement;
	}
	
	action def MeasureAcceleration {
		doc /* 
		Primary function: Converts mechanical acceleration into a calibrated 
		digital measurement through a sequence of signal transformations.
		*/
		in inputAcceleration : AccelerationMeasurement;
		out outputMeasurement : AccelerationMeasurement;
		
		first start;
		
		then action generateCharge : GenerateCharge {
			in appliedAcceleration = inputAcceleration;
			in crystalSensitivity = 10.0;
			in crystalMass = 0.001;
			out generatedCharge;
		}
		
		flow generateCharge.generatedCharge to amplifyCharge.inputCharge;
		
		then action amplifyCharge : AmplifyCharge {
			in inputCharge;
			in amplifierGain = 1000.0;
			out outputVoltage;
		}
		
		flow amplifyCharge.outputVoltage to filterSignal.rawVoltage;
		
		then action filterSignal : FilterSignal {
			in rawVoltage;
			in lowCutoff = 1.0;
			in highCutoff = 10000.0;
			out filteredVoltage;
		}
		
		flow filterSignal.filteredVoltage to convertToDigital.analogVoltage;
		
		then action convertToDigital : ConvertToDigital {
			in analogVoltage;
			in adcResolution = 16;
			in samplingRate = 50000.0;
			out digitalValue;
		}
		
		flow convertToDigital.digitalValue to processSignal.rawDigital;
		
		then action processSignal : ProcessSignal {
			in rawDigital;
			in calibration = 0.98;
			in offset = 0.02;
			out calibratedAcceleration;
		}
		
		then assign outputMeasurement := processSignal.calibratedAcceleration;
		then done;
	}
	
	state def AccelerometerOperationalStates {
		doc /* 
		Defines the operational modes of the accelerometer system throughout 
		its lifecycle.
		*/
		
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOffToInit
			first powerOff
			accept powerOn : PowerOnSignal
			then initialization;
		
		state initialization;
		
		transition initToIdle
			first initialization
			then idle;
		
		state idle;
		
		transition idleToMeasuring
			first idle
			accept startMeasurement : VibrationEvent
			then measuring;
		
		transition idleToCalibration
			first idle
			accept calibrate : CalibrationCommand
			then calibration;
		
		state calibration;
		
		transition calibrationToIdle
			first calibration
			then idle;
		
		state measuring;
		
		transition measuringToIdle
			first measuring
			accept stopMeasurement
			then idle;
		
		transition measuringToAlert
			first measuring
			accept highVibration : VibrationEvent
			then alert;
		
		state alert;
		
		transition alertToMeasuring
			first alert
			then measuring;
	}
	
	part accelerometerSystem : PiezoelectricAccelerometer {
		doc /* 
		A piezoelectric accelerometer system that measures mechanical vibrations 
		and accelerations by converting them into calibrated digital signals. 
		The system operates continuously to monitor dynamic motion in industrial 
		machinery, automotive applications, and structural health monitoring.
		*/
		
		perform action measureAcceleration : MeasureAcceleration;
		
		exhibit state operationalStates : AccelerometerOperationalStates;
		
		part mountingBase : MountingBase {
			attribute :>> material = "Titanium";
			attribute :>> mountingType = "Stud Mount";
			attribute :>> stiffness = 1000000.0;
		}
		
		part sensingElement : PiezoelectricCrystal {
			attribute :>> sensitivity = 10.0;
			attribute :>> resonantFrequency = 25000.0;
			attribute :>> mass = 0.001;
			perform measureAcceleration.generateCharge;
		}
		
		part chargeAmp : ChargeAmplifier {
			attribute :>> gain = 1000.0;
			attribute :>> inputImpedance = 1.0e12;
			attribute :>> outputImpedance = 100.0;
			perform measureAcceleration.amplifyCharge;
		}
		
		part signalFilter : SignalFilter {
			attribute :>> lowCutoffFrequency = 1.0;
			attribute :>> highCutoffFrequency = 10000.0;
			attribute :>> filterOrder = 4;
			perform measureAcceleration.filterSignal;
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 50000.0;
			attribute :>> referenceVoltage = 5.0;
			perform measureAcceleration.convertToDigital;
		}
		
		part processor : SignalProcessor {
			attribute :>> calibrationFactor = 0.98;
			attribute :>> temperatureCompensation = 0.001;
			attribute :>> offsetCorrection = 0.02;
			perform measureAcceleration.processSignal;
		}
		
		connection mechanicalCoupling connect mountingBase.mechanicalInterface to sensingElement.mechanicalInput;
		connection chargeTransfer connect sensingElement.chargeOutput to chargeAmp.chargeInput;
		connection voltageTransfer connect chargeAmp.voltageOutput to signalFilter.voltageInput;
		connection filteredSignal connect signalFilter.voltageOutput to adc.analogInput;
		connection digitalData connect adc.digitalOutput to processor.digitalInput;
	}
	
	part def PiezoelectricAccelerometer :> accelerometerSystem;
	
	requirement <'REQ-001'> primaryFunctionRequirement {
		doc /* 
		The piezoelectric accelerometer system shall measure mechanical acceleration 
		and vibration by converting mechanical stress into electrical signals, 
		processing them through signal conditioning stages, and outputting calibrated 
		digital measurements suitable for monitoring and analysis applications.
		*/
		subject accelerometerSystem;
	}
	
	requirement <'REQ-002'> measurementRangeRequirement {
		doc /* 
		The accelerometer shall measure accelerations from 0.001 g to 100 g 
		with linear response throughout the specified range.
		*/
		subject accelerometerSystem;
		require constraint {
			doc /* Measurement range: 0.001 g to 100 g */
		}
	}
	
	requirement <'REQ-003'> frequencyResponseRequirement {
		doc /* 
		The accelerometer shall accurately measure vibrations over a frequency 
		range from 1 Hz to 10 kHz with less than ±3 dB deviation.
		*/
		subject accelerometerSystem.signalFilter;
	}
	
	requirement <'REQ-004'> accuracyRequirement {
		doc /* 
		The accelerometer shall provide measurement accuracy of ±1% of full scale 
		over the operating temperature range.
		*/
		subject accelerometerSystem.processor;
	}
	
	requirement <'REQ-005'> temperatureStabilityRequirement {
		doc /* 
		The accelerometer shall maintain specified performance over a temperature 
		range of -40°C to +125°C.
		*/
		subject accelerometerSystem;
	}
	
	requirement <'REQ-006'> resolutionRequirement {
		doc /* 
		The accelerometer shall provide a minimum resolution of 0.0001 g 
		to detect small vibrations.
		*/
		subject accelerometerSystem.adc;
	}
	
	requirement systemRequirements {
		doc /* 
		Top-level requirements for the piezoelectric accelerometer system 
		encompassing functional, performance, and environmental specifications.
		*/
		require primaryFunctionRequirement;
		require measurementRangeRequirement;
		require frequencyResponseRequirement;
		require accuracyRequirement;
		require temperatureStabilityRequirement;
		require resolutionRequirement;
	}
}
