package 'Potentiometric Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PositionValue :> LengthValue;
	
	item def ElectricalSignal {
		attribute voltage : Real;
		attribute timestamp : Real;
	}
	
	item def MechanicalDisplacement {
		attribute position : PositionValue;
		attribute velocity : Real;
	}
	
	item def PositionMeasurement {
		attribute measuredPosition : PositionValue;
		attribute accuracy : PositionValue;
		attribute timestamp : Real;
	}
	
	port def MechanicalInputPort {
		in item displacement : MechanicalDisplacement;
	}
	
	port def AnalogOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def DigitalOutputPort {
		out item measurement : PositionMeasurement;
	}
	
	connection def ElectricalConnection {
		end source : AnalogOutputPort;
		end sink : AnalogOutputPort;
	}
	
	part def PotentiometricSensor {
		attribute totalResistance : Real;
		attribute supplyVoltage : Real;
		attribute totalTravel : Real;
		attribute wiperPosition : Real;
		attribute outputVoltage : Real;
		
		port mechanicalInput : MechanicalInputPort;
		port electricalOutput : AnalogOutputPort;
		
		part resistiveTrack {
			attribute resistance : Real;
			attribute length : Real;
			attribute resistancePerUnit : Real;
		}
		
		part wiper {
			attribute contactPosition : Real;
			attribute contactResistance : Real;
		}
		
		part voltageSource {
			attribute nominalVoltage : Real;
			attribute currentCapacity : Real;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute offsetVoltage : Real;
		attribute filterCutoff : Real;
		
		port analogInput : AnalogOutputPort;
		port analogOutput : AnalogOutputPort;
		
		part amplifier {
			attribute amplificationFactor : Real;
			attribute inputImpedance : Real;
			attribute bandwidth : Real;
		}
		
		part lowPassFilter {
			attribute cutoffFrequency : Real;
			attribute order : Integer;
		}
		
		part bufferStage {
			attribute outputImpedance : Real;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : Real;
		attribute conversionTime : Real;
		
		port analogInput : AnalogOutputPort;
		port digitalOutput : DigitalOutputPort;
		
		part converter {
			attribute bitDepth : Integer;
			attribute quantizationError : Real;
		}
	}
	
	part def Microcontroller {
		attribute processingSpeed : Real;
		attribute memorySize : Integer;
		
		port digitalInput : DigitalOutputPort;
		port measurementOutput : DigitalOutputPort;
		
		part processor {
			attribute clockFrequency : Real;
		}
		
		part calibrationMemory {
			attribute zeroOffset : Real;
			attribute scaleFactor : Real;
		}
	}
	
	action def SensePosition {
		in displacement : MechanicalDisplacement;
		out analogSignal : ElectricalSignal;
		
		attribute wiperPos : PositionValue;
		attribute outputVolt : Real;
	}
	
	action def ConditionSignal {
		in rawSignal : ElectricalSignal;
		out conditionedSignal : ElectricalSignal;
		
		action amplify {
			in signal : ElectricalSignal;
			out amplifiedSignal : ElectricalSignal;
		}
		
		then action filter {
			in signal : ElectricalSignal;
			out filteredSignal : ElectricalSignal;
		}
		
		flow from amplify.amplifiedSignal to filter.signal;
		bind filter.filteredSignal = conditionedSignal;
	}
	
	action def ConvertToDigital {
		in analogSignal : ElectricalSignal;
		out digitalValue : PositionMeasurement;
		
		attribute sampleValue : Real;
		attribute quantizedValue : Integer;
	}
	
	action def ProcessMeasurement {
		in rawMeasurement : PositionMeasurement;
		out calibratedMeasurement : PositionMeasurement;
		
		action applyCalibration {
			in raw : PositionMeasurement;
			out calibrated : PositionMeasurement;
		}
		
		then action validateRange {
			in measurement : PositionMeasurement;
			out validatedMeasurement : PositionMeasurement;
		}
		
		flow from applyCalibration.calibrated to validateRange.measurement;
		bind validateRange.validatedMeasurement = calibratedMeasurement;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure position with accuracy better than 0.5% of full scale range. */
		
		subject sensor : PotentiometricSensor;
		
		require constraint {
			sensor.totalResistance > 1000.0 and
			sensor.supplyVoltage >= 3.3 and
			sensor.supplyVoltage <= 12.0
		}
	}
	
	requirement def LinearityRequirement {
		doc /* The potentiometric sensor shall maintain linearity within 0.5% over the full measurement range. */
		
		subject sensor : PotentiometricSensor;
		
		require constraint {
			sensor.totalTravel > 0.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall respond to position changes within 5 milliseconds. */
		
		attribute maxResponseTime : Real = 0.005;
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* The sensing unit shall operate within temperature range of -40°C to +85°C. */
		
		attribute minTemperature : Real = -40.0;
		attribute maxTemperature : Real = 85.0;
	}
	
	item def StartMeasurement;
	item def StopMeasurement;
	item def SensorFault;
	item def ResetCommand;
	
	state def SensorOperationalStates {
		entry; then initialization;
		
		state initialization {
			entry action performSelfTest;
			entry action loadCalibration;
		}
		
		transition initialization_to_idle
			first initialization
			then idle;
		
		state idle {
			entry action enterLowPower;
		}
		
		transition idle_to_measuring
			first idle
			accept StartMeasurement
			then measuring;
		
		state measuring {
			entry action activateSensor;
			do action continuousSampling;
			
			state acquiring {
				entry action startAcquisition;
			}
			
			then state converting {
				entry action performConversion;
			}
			
			then state processing {
				entry action applyCalibration;
			}
			
			then state outputting {
				entry action transmitData;
			}
		}
		
		transition measuring_to_idle
			first measuring
			accept StopMeasurement
			then idle;
		
		state fault {
			entry action logFault;
			entry action disableOutput;
		}
		
		transition any_to_fault
			accept SensorFault
			then fault;
		
		transition fault_to_initialization
			first fault
			accept ResetCommand
			then initialization;
	}
	
	action def CalibrateSensor {
		in sensor : PotentiometricSensor;
		in referencePositions : PositionValue[2..*];
		in measuredVoltages : Real[2..*];
		out calibrationCoefficients : Real[2];
		
		action measureZeroPoint {
			in item sensorRef : PotentiometricSensor;
			out zeroVoltage : Real;
			out zeroPosition : PositionValue;
		}
		
		then action measureFullScale {
			in item sensorRef : PotentiometricSensor;
			out fullScaleVoltage : Real;
			out fullScalePosition : PositionValue;
		}
		
		then action calculateLinearFit {
			in zeroV : Real;
			in fullV : Real;
			in zeroP : PositionValue;
			in fullP : PositionValue;
			out slope : Real;
			out intercept : Real;
		}
		
		then action storeCalibration {
			in coefficients : Real[2];
		}
		
		flow from measureZeroPoint.zeroVoltage to calculateLinearFit.zeroV;
		flow from measureZeroPoint.zeroPosition to calculateLinearFit.zeroP;
		flow from measureFullScale.fullScaleVoltage to calculateLinearFit.fullV;
		flow from measureFullScale.fullScalePosition to calculateLinearFit.fullP;
	}
	
	part def SensingUnit {
		part sensor : PotentiometricSensor;
		part conditioner : SignalConditioner;
		part adc : AnalogToDigitalConverter;
		part mcu : Microcontroller;
		
		port mechanicalInput : MechanicalInputPort;
		port measurementOutput : DigitalOutputPort;
	}
	
	part sensingUnit : SensingUnit {
		part redefines sensor {
			attribute redefines totalResistance = 10000.0;
			attribute redefines supplyVoltage = 5.0;
			attribute redefines totalTravel = 100.0;
			
			part redefines resistiveTrack {
				attribute redefines resistance = 10000.0;
				attribute redefines length = 100.0;
				attribute redefines resistancePerUnit = 100.0;
			}
			
			part redefines wiper {
				attribute redefines contactResistance = 10.0;
			}
			
			part redefines voltageSource {
				attribute redefines nominalVoltage = 5.0;
				attribute redefines currentCapacity = 0.01;
			}
		}
		
		part redefines conditioner {
			attribute redefines gain = 1.0;
			attribute redefines offsetVoltage = 0.0;
			attribute redefines filterCutoff = 1000.0;
			
			part redefines amplifier {
				attribute redefines amplificationFactor = 1.0;
				attribute redefines inputImpedance = 1000000.0;
				attribute redefines bandwidth = 10000.0;
			}
			
			part redefines lowPassFilter {
				attribute redefines cutoffFrequency = 1000.0;
				attribute redefines order = 2;
			}
			
			part redefines bufferStage {
				attribute redefines outputImpedance = 50.0;
			}
		}
		
		part redefines adc {
			attribute redefines resolution = 12;
			attribute redefines samplingRate = 10000.0;
			attribute redefines referenceVoltage = 5.0;
			attribute redefines conversionTime = 0.0001;
			
			part redefines converter {
				attribute redefines bitDepth = 12;
				attribute redefines quantizationError = 0.00122;
			}
		}
		
		part redefines mcu {
			attribute redefines processingSpeed = 48000000.0;
			attribute redefines memorySize = 65536;
			
			part redefines processor {
				attribute redefines clockFrequency = 48000000.0;
			}
			
			part redefines calibrationMemory {
				attribute redefines zeroOffset = 0.0;
				attribute redefines scaleFactor = 1.0;
			}
		}
		
		connect sensor.electricalOutput to conditioner.analogInput;
		connect conditioner.analogOutput to adc.analogInput;
		connect adc.digitalOutput to mcu.digitalInput;
		connect mcu.measurementOutput to measurementOutput;
		
		perform action measurementCycle {
			action sense : SensePosition {
				in displacement;
				out analogSignal;
			}
			
			then action condition : ConditionSignal {
				in rawSignal;
				out conditionedSignal;
			}
			
			then action convert : ConvertToDigital {
				in analogSignal;
				out digitalValue;
			}
			
			then action process : ProcessMeasurement {
				in rawMeasurement;
				out calibratedMeasurement;
			}
			
			flow from sense.analogSignal to condition.rawSignal;
			flow from condition.conditionedSignal to convert.analogSignal;
			flow from convert.digitalValue to process.rawMeasurement;
		}
		
		satisfy accuracyReq : MeasurementAccuracyRequirement {
			subject testSensor :>> sensor;
		}
		
		satisfy linearityReq : LinearityRequirement {
			subject testSensor :>> sensor;
		}
		
		satisfy responseReq : ResponseTimeRequirement;
		
		satisfy temperatureReq : OperatingTemperatureRequirement;
	}
	
	individual def TestSensingUnit :> SensingUnit;
	
	individual testUnit : TestSensingUnit :> sensingUnit {
		timeslice calibrationPhase {
			perform action calibrate : CalibrateSensor {
				in item sensor;
				in referencePositions;
				in measuredVoltages;
			}
		}
		
		then timeslice operationalPhase {
			perform action :>> measurementCycle;
		}
		
		then timeslice verificationPhase {
			perform action :>> measurementCycle;
		}
	}
}
