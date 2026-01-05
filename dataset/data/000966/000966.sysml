package 'Air Flow Meter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VolumetricFlowRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def MassFlowRate :> ISQ::MassFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : MassFlowRateUnit;
	}
	
	attribute def AirTemperature :> ISQ::ThermodynamicTemperatureValue {
		attribute :>> num : Real;
		attribute :>> mRef : ThermodynamicTemperatureUnit;
	}
	
	attribute def AirPressure :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def OutputVoltage :> ISQ::ElectricPotentialValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricPotentialUnit;
	}
	
	attribute def AirDensity :> ISQ::DensityValue {
		attribute :>> num : Real;
		attribute :>> mRef : DensityUnit;
	}
	
	item def AirStream {
		attribute volumetricFlow : VolumetricFlowRate;
		attribute massFlow : MassFlowRate;
		attribute temperature : AirTemperature;
		attribute pressure : AirPressure;
		attribute density : AirDensity;
	}
	
	item def ElectricalSignal {
		attribute voltage : OutputVoltage;
		attribute flowRateEncoded : MassFlowRate;
	}
	
	item def CalibrationParameters {
		attribute transferFunction : Real;
		attribute temperatureCompensation : Real;
		attribute pressureCompensation : Real;
	}
	
	port def AirInletPort {
		in item incomingAir : AirStream;
	}
	
	port def AirOutletPort {
		out item outgoingAir : AirStream;
	}
	
	port def SignalOutputPort {
		out item flowSignal : ElectricalSignal;
	}
	
	port def PowerSupplyPort {
		in item supplyVoltage : OutputVoltage;
	}
	
	port def SignalInputPort {
		in item flowSignal : ElectricalSignal;
	}
	
	action def SenseAirFlow {
		in airStream : AirStream;
		out rawMeasurement : Real;
	}
	
	action def MeasureTemperature {
		in airStream : AirStream;
		out temperature : AirTemperature;
	}
	
	action def MeasurePressure {
		in airStream : AirStream;
		out pressure : AirPressure;
	}
	
	action def CalculateDensity {
		in temperature : AirTemperature;
		in pressure : AirPressure;
		out density : AirDensity;
	}
	
	action def CompensateMeasurement {
		in rawMeasurement : Real;
		in temperature : AirTemperature;
		in pressure : AirPressure;
		in calibration : CalibrationParameters;
		out compensatedFlow : MassFlowRate;
	}
	
	action def ConvertToSignal {
		in massFlow : MassFlowRate;
		out signal : ElectricalSignal;
	}
	
	action def MeasureAndOutputAirFlow {
		in airIn : AirStream;
		in calibration : CalibrationParameters;
		out airOut : AirStream;
		out outputSignal : ElectricalSignal;
		
		first start;
		then action senseFlow : SenseAirFlow {
			in airStream = airIn;
			out rawMeasurement : Real;
		}
		then action measureTemp : MeasureTemperature {
			in airStream = airIn;
			out temperature : AirTemperature;
		}
		then action measurePress : MeasurePressure {
			in airStream = airIn;
			out pressure : AirPressure;
		}
		then action calcDensity : CalculateDensity {
			in temperature = measureTemp.temperature;
			in pressure = measurePress.pressure;
			out density : AirDensity;
		}
		then action compensate : CompensateMeasurement {
			in rawMeasurement = senseFlow.rawMeasurement;
			in temperature = measureTemp.temperature;
			in pressure = measurePress.pressure;
			in calibration = MeasureAndOutputAirFlow::calibration;
			out compensatedFlow : MassFlowRate;
		}
		then action convertSignal : ConvertToSignal {
			in massFlow = compensate.compensatedFlow;
			out signal : ElectricalSignal;
		}
		then done;
	}
	
	part def HotWireSensor {
		attribute heatingCurrent : Real;
		attribute coolingEffect : Real;
	}
	
	part def TemperatureSensor {
		attribute sensorResistance : Real;
	}
	
	part def PressureSensor {
		attribute diaphragmDeflection : Real;
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoff : Real;
	}
	
	part def MicroController {
		attribute processingSpeed : Real;
		attribute memorySize : Real;
	}
	
	part def AirFlowMeter {
		port airInlet : AirInletPort;
		port airOutlet : AirOutletPort;
		port signalOutput : SignalOutputPort;
		port powerSupply : PowerSupplyPort;
		
		part hotWire : HotWireSensor;
		part tempSensor : TemperatureSensor;
		part pressSensor : PressureSensor;
		part conditioner : SignalConditioner;
		part controller : MicroController;
		
		attribute calibrationData : CalibrationParameters;
		
		connect airInlet to airOutlet;
		
		perform action measureFlow : MeasureAndOutputAirFlow {
			in airIn : AirStream;
			in calibration = calibrationData;
			out airOut : AirStream;
			out outputSignal : ElectricalSignal;
		}
	}
	
	part def EngineControlUnit {
		port flowDataInput : SignalInputPort;
		
		action def ProcessFlowData {
			in flowSignal : ElectricalSignal;
			out fuelAdjustment : Real;
		}
		
		perform action processData : ProcessFlowData;
	}
	
	part def IntakeManifold {
		port airEntry : AirInletPort;
		port airExit : AirOutletPort;
	}
	
	part def AirFilterAssembly {
		port filteredAirOut : AirOutletPort;
	}
	
	part airIntakeSystem {
		part airFilter : AirFilterAssembly;
		part flowMeter : AirFlowMeter;
		part manifold : IntakeManifold;
		part ecu : EngineControlUnit;
		
		connect airFilter.filteredAirOut to flowMeter.airInlet;
		connect flowMeter.airOutlet to manifold.airEntry;
		
		connection dataLink connect flowMeter.signalOutput to ecu.flowDataInput;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The air flow meter shall continuously measure the mass of air 
		     entering the engine intake system and provide a proportional 
		     electrical signal to the engine control unit for fuel injection 
		     optimization. */
		
		subject meter : AirFlowMeter;
		
		require constraint {
			doc /* Continuous measurement and signal output during engine operation */
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The air flow meter shall measure mass air flow with an accuracy 
		     of ±2% across the full operating range of 2 to 500 kg/h. */
		
		subject meter : AirFlowMeter;
		
		require constraint {
			doc /* Accuracy within ±2% over 2-500 kg/h range */
		}
	}
	
	requirement def TemperatureCompensationRequirement {
		doc /* The air flow meter shall compensate for air temperature variations 
		     from -40°C to +120°C to maintain measurement accuracy. */
		
		subject meter : AirFlowMeter;
		
		require constraint {
			doc /* Temperature compensation across -40°C to +120°C */
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The air flow meter shall respond to flow changes with a time 
		     constant of less than 15 milliseconds. */
		
		subject meter : AirFlowMeter;
		
		require constraint {
			doc /* Response time constant < 15ms */
		}
	}
	
	requirement def SignalOutputRequirement {
		doc /* The air flow meter shall output a linear voltage signal between 
		     0.5V and 4.5V proportional to measured mass air flow. */
		
		subject meter : AirFlowMeter;
		
		require constraint {
			doc /* Linear output 0.5V to 4.5V proportional to flow */
		}
	}
	
	part verifiedFlowMeter : AirFlowMeter {
		satisfy PrimaryFunctionRequirement by measureFlow;
		satisfy MeasurementAccuracyRequirement by controller;
		satisfy TemperatureCompensationRequirement by tempSensor;
		satisfy ResponseTimeRequirement by hotWire;
		satisfy SignalOutputRequirement by conditioner;
	}
}
