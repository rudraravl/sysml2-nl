package 'Current Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def SensorState {
		enum offline;
		enum initializing;
		enum ready;
		enum measuring;
		enum error;
	}
	
	item def CurrentMeasurement {
		attribute measuredCurrent : ISQ::ElectricCurrentValue;
		attribute timestamp : Real;
		attribute isValid : Boolean;
	}
	
	item def ElectricalSignal {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ElectricalInputPort {
		in item signal : ElectricalSignal;
	}
	
	port def MeasurementOutputPort {
		out item measurement : CurrentMeasurement;
	}
	
	port def PowerPort {
		attribute supplyVoltage : ISQ::VoltageValue;
	}
	
	part def ShuntResistor {
		attribute resistance : ISQ::ResistanceValue;
		attribute powerRating : Real;
		attribute tolerance : Real;
		port inputTerminal : ElectricalInputPort;
		port outputTerminal : ElectricalInputPort;
	}
	
	part def Amplifier {
		attribute gain : Real;
		attribute bandwidth : Real;
		attribute inputImpedance : ISQ::ResistanceValue;
		port signalInput : ElectricalInputPort;
		port signalOutput : ElectricalInputPort;
		port power : PowerPort;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : ISQ::VoltageValue;
		port analogInput : ElectricalInputPort;
		port digitalOutput : MeasurementOutputPort;
		port power : PowerPort;
	}
	
	part def Microcontroller {
		attribute processorSpeed : Real;
		attribute memorySize : Integer;
		port dataInput : MeasurementOutputPort;
		port dataOutput : MeasurementOutputPort;
		port power : PowerPort;
	}
	
	part def CurrentSensor {
		attribute sensorId : String;
		attribute measurementRange : ISQ::ElectricCurrentValue;
		attribute accuracy : Real;
		attribute currentState : SensorState default SensorState::offline;
		
		port sensingPort : ElectricalInputPort;
		port outputPort : MeasurementOutputPort;
		port powerInput : PowerPort;
		
		part shunt : ShuntResistor {
			attribute :>> resistance = 0.01[SI::Ω];
			attribute :>> powerRating = 2.0;
			attribute :>> tolerance = 0.01;
		}
		
		part amplifier : Amplifier {
			attribute :>> gain = 50.0;
			attribute :>> bandwidth = 100000.0;
			attribute :>> inputImpedance = 1000000.0[SI::Ω];
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 10000.0;
			attribute :>> referenceVoltage = 3.3[SI::V];
		}
		
		part controller : Microcontroller {
			attribute :>> processorSpeed = 48000000.0;
			attribute :>> memorySize = 65536;
		}
		
		connection shuntToAmp 
			connect shunt.outputTerminal to amplifier.signalInput;
		
		connection ampToAdc 
			connect amplifier.signalOutput to adc.analogInput;
		
		connection adcToController 
			connect adc.digitalOutput to controller.dataInput;
		
		connect sensingPort to shunt.inputTerminal;
		connect controller.dataOutput to outputPort;
		connect powerInput to amplifier.power;
		connect powerInput to adc.power;
		connect powerInput to controller.power;
	}
	
	action def InitializeSensor {
		out initSuccess : Boolean;
	}
	
	action def PerformMeasurement {
		in inputSignal : ElectricalSignal;
		out measurement : CurrentMeasurement;
	}
	
	action def ValidateMeasurement {
		in measurement : CurrentMeasurement;
		in minThreshold : ISQ::ElectricCurrentValue;
		in maxThreshold : ISQ::ElectricCurrentValue;
		out isValid : Boolean;
	}
	
	action def ProcessMeasurement {
		in rawMeasurement : CurrentMeasurement;
		out processedMeasurement : CurrentMeasurement;
	}
	
	action def SensingCycle {
		in item inputSignal : ElectricalSignal;
		out item finalMeasurement : CurrentMeasurement;
		
		first start;
		then action measure : PerformMeasurement {
			in inputSignal;
			out measurement;
		}
		then action process : ProcessMeasurement {
			in rawMeasurement = measure.measurement;
			out processedMeasurement;
		}
		then action validate : ValidateMeasurement {
			in measurement = process.processedMeasurement;
			in minThreshold;
			in maxThreshold;
			out isValid;
		}
		then decide;
			if validate.isValid then acceptMeasurement;
			if !validate.isValid then rejectMeasurement;
		action acceptMeasurement {
			bind finalMeasurement = process.processedMeasurement;
		}
		then done;
		action rejectMeasurement;
		then done;
	}
	
	state def SensorStateMachine {
		entry; then offline;
		
		state offline;
		accept at when powerApplied
		then initializing;
		
		state initializing {
			do action init : InitializeSensor;
		}
		accept at when initComplete
		if init.initSuccess then ready;
		if !init.initSuccess then error;
		
		state ready;
		accept at when startMeasurement
		then measuring;
		accept at when powerRemoved
		then offline;
		
		state measuring {
			do action cycle : SensingCycle;
		}
		accept at when measurementComplete
		then ready;
		accept at when measurementFault
		then error;
		
		state error;
		accept at when reset
		then initializing;
		accept at when powerRemoved
		then offline;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingTemperature : Real;
		attribute calibrationDate : String;
		
		part sensor : CurrentSensor {
			attribute :>> sensorId = "CS-2024-001";
			attribute :>> measurementRange = 20.0[SI::A];
			attribute :>> accuracy = 0.005;
		}
		
		part powerSupply {
			attribute outputVoltage : ISQ::VoltageValue;
			attribute maxCurrent : ISQ::ElectricCurrentValue;
			port powerOut : PowerPort;
		}
		
		part dataInterface {
			attribute communicationProtocol : String;
			attribute baudRate : Real;
			port measurementIn : MeasurementOutputPort;
		}
		
		port externalInput : ElectricalInputPort;
		port measurementOutput : MeasurementOutputPort;
		
		connection powerConnection 
			connect powerSupply.powerOut to sensor.powerInput;
		
		connection inputConnection 
			connect externalInput to sensor.sensingPort;
		
		connection dataConnection 
			connect sensor.outputPort to dataInterface.measurementIn;
		
		connection outputConnection 
			connect dataInterface.measurementIn to measurementOutput;
		
		perform action sensingOperation : SensingCycle;
		
		exhibit state sensorBehavior : SensorStateMachine;
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "SU-2024-100";
		attribute :>> operatingTemperature = 25.0;
		attribute :>> calibrationDate = "2024-01-15";
		
		part :>> sensor {
			attribute :>> accuracy = 0.003;
		}
		
		part :>> powerSupply {
			attribute :>> outputVoltage = 5.0[SI::V];
			attribute :>> maxCurrent = 1.0[SI::A];
		}
		
		part :>> dataInterface {
			attribute :>> communicationProtocol = "SPI";
			attribute :>> baudRate = 1000000.0;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The current sensor shall measure current with accuracy better than 0.5%. */
		
		subject sensor : CurrentSensor;
		
		require constraint {
			sensor.accuracy <= 0.005
		}
	}
	
	requirement def RangeRequirement {
		doc /* The current sensor shall measure currents up to 20A. */
		
		subject sensor : CurrentSensor;
		
		require constraint {
			sensor.measurementRange.num >= 20.0
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The sensing unit shall sample current at minimum 10 kHz. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.adc.samplingRate >= 10000.0
		}
	}
	
	requirement def ResolutionRequirement {
		doc /* The ADC shall provide at least 16-bit resolution. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.adc.resolution >= 16
		}
	}
	
	requirement sensingUnitRequirements {
		subject sensingUnitInstance;
		
		requirement accuracyReq : AccuracyRequirement {
			subject sensor = sensingUnitInstance.sensor;
		}
		
		requirement rangeReq : RangeRequirement {
			subject sensor = sensingUnitInstance.sensor;
		}
		
		requirement samplingReq : SamplingRateRequirement {
			subject unit = sensingUnitInstance;
		}
		
		requirement resolutionReq : ResolutionRequirement {
			subject unit = sensingUnitInstance;
		}
	}
}
