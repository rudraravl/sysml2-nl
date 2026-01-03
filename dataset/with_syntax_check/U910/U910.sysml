package ThermocoupleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SeebeckCoefficient :> Real;
	
	item def ThermalContact {
		attribute temperature :> ISQ::ThermodynamicTemperatureValue;
		attribute location : String;
	}
	
	item def ElectricalSignal {
		attribute voltage :> ISQ::ElectricPotentialValue;
		attribute timestamp :> ISQ::DurationValue;
	}
	
	item def TemperatureReading {
		attribute measuredTemperature :> ISQ::ThermodynamicTemperatureValue;
		attribute accuracy :> ISQ::ThermodynamicTemperatureValue;
		attribute timestamp :> ISQ::DurationValue;
	}
	
	port def ThermalSensingPort {
		in item contact : ThermalContact;
	}
	
	port def VoltageOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def DataOutputPort {
		out item reading : TemperatureReading;
	}
	
	part def ThermocoupleJunction {
		attribute junctionTemperature :> ISQ::ThermodynamicTemperatureValue;
		attribute materialA : String;
		attribute materialB : String;
		
		port thermalInterface : ThermalSensingPort;
	}
	
	part def ThermoelectricWire {
		attribute material : String;
		attribute seebeckCoefficient : SeebeckCoefficient;
		attribute length :> ISQ::LengthValue;
	}
	
	part def ColdJunctionCompensator {
		attribute referenceTemperature :> ISQ::ThermodynamicTemperatureValue;
		attribute compensationVoltage :> ISQ::ElectricPotentialValue;
		
		port voltageOutput : VoltageOutputPort;
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute inputImpedance :> ISQ::ResistanceValue;
		
		in attribute inputVoltage :> ISQ::ElectricPotentialValue;
		out attribute outputVoltage :> ISQ::ElectricPotentialValue;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate :> ISQ::FrequencyValue;
		
		in attribute analogInput :> ISQ::ElectricPotentialValue;
		out attribute digitalOutput : Real;
	}
	
	part def TemperatureCalculator {
		attribute calibrationTable : String;
		
		in attribute voltage :> ISQ::ElectricPotentialValue;
		in attribute coldJunctionTemp :> ISQ::ThermodynamicTemperatureValue;
		out attribute temperature :> ISQ::ThermodynamicTemperatureValue;
	}
	
	action def SenseHotJunctionTemperature {
		in attribute targetTemperature :> ISQ::ThermodynamicTemperatureValue;
		out attribute sensedTemperature :> ISQ::ThermodynamicTemperatureValue;
	}
	
	action def GenerateThermoelectricVoltage {
		in attribute hotJunctionTemp :> ISQ::ThermodynamicTemperatureValue;
		in attribute coldJunctionTemp :> ISQ::ThermodynamicTemperatureValue;
		in attribute seebeck : SeebeckCoefficient;
		out attribute emfVoltage :> ISQ::ElectricPotentialValue;
	}
	
	action def CompensateColdJunction {
		in attribute rawVoltage :> ISQ::ElectricPotentialValue;
		in attribute coldTemp :> ISQ::ThermodynamicTemperatureValue;
		out attribute compensatedVoltage :> ISQ::ElectricPotentialValue;
	}
	
	action def AmplifySignal {
		in attribute inputVoltage :> ISQ::ElectricPotentialValue;
		in attribute amplifierGain : Real;
		out attribute amplifiedVoltage :> ISQ::ElectricPotentialValue;
	}
	
	action def ConvertAnalogToDigital {
		in attribute analogVoltage :> ISQ::ElectricPotentialValue;
		out attribute digitalValue : Real;
	}
	
	action def CalculateTemperature {
		in attribute voltage :> ISQ::ElectricPotentialValue;
		in attribute referenceTemp :> ISQ::ThermodynamicTemperatureValue;
		out attribute finalTemperature :> ISQ::ThermodynamicTemperatureValue;
	}
	
	action def MeasureTemperature {
		in attribute targetTemp :> ISQ::ThermodynamicTemperatureValue;
		in attribute coldJunctionTemp :> ISQ::ThermodynamicTemperatureValue;
		in attribute seebeckCoeff : SeebeckCoefficient;
		in attribute gain : Real;
		out attribute temperatureReading :> ISQ::ThermodynamicTemperatureValue;
		
		private attribute sensedTemp :> ISQ::ThermodynamicTemperatureValue;
		private attribute rawEMF :> ISQ::ElectricPotentialValue;
		private attribute compensatedEMF :> ISQ::ElectricPotentialValue;
		private attribute amplifiedSignal :> ISQ::ElectricPotentialValue;
		private attribute digitalSignal : Real;
		
		first start;
		then action sense : SenseHotJunctionTemperature {
			in targetTemperature = targetTemp;
			out sensedTemperature = sensedTemp;
		}
		then action generateVoltage : GenerateThermoelectricVoltage {
			in hotJunctionTemp = sensedTemp;
			in coldJunctionTemp = coldJunctionTemp;
			in seebeck = seebeckCoeff;
			out emfVoltage = rawEMF;
		}
		then action compensate : CompensateColdJunction {
			in rawVoltage = rawEMF;
			in coldTemp = coldJunctionTemp;
			out compensatedVoltage = compensatedEMF;
		}
		then action amplify : AmplifySignal {
			in inputVoltage = compensatedEMF;
			in amplifierGain = gain;
			out amplifiedVoltage = amplifiedSignal;
		}
		then action convert : ConvertAnalogToDigital {
			in analogVoltage = amplifiedSignal;
			out digitalValue = digitalSignal;
		}
		then action calculate : CalculateTemperature {
			in voltage = compensatedEMF;
			in referenceTemp = coldJunctionTemp;
			out finalTemperature = temperatureReading;
		}
		then done;
	}
	
	state def ThermocoupleOperatingStates {
		entry; then idle;
		
		state idle;
		
		state measuring {
			entry; then sensing;
			
			state sensing;
			state converting;
			state outputting;
			
			transition sensing_to_converting
				first sensing
				then converting;
			
			transition converting_to_outputting
				first converting
				then outputting;
		}
		
		state fault;
		
		transition idle_to_measuring
			first idle
			then measuring;
		
		transition measuring_to_idle
			first measuring
			then idle;
		
		transition idle_to_fault
			first idle
			then fault;
		
		transition measuring_to_fault
			first measuring
			then fault;
		
		transition fault_to_idle
			first fault
			then idle;
	}
	
	part def Thermocouple {
		attribute thermocoupleType : String;
		attribute operatingRange :> ISQ::ThermodynamicTemperatureValue[2];
		attribute accuracy :> ISQ::ThermodynamicTemperatureValue;
		attribute responseTime :> ISQ::DurationValue;
		
		part hotJunction : ThermocoupleJunction {
			attribute :>> materialA = "Chromel";
			attribute :>> materialB = "Alumel";
		}
		
		part coldJunction : ThermocoupleJunction {
			attribute :>> materialA = "Chromel";
			attribute :>> materialB = "Alumel";
		}
		
		part positiveWire : ThermoelectricWire {
			attribute :>> material = "Chromel";
		}
		
		part negativeWire : ThermoelectricWire {
			attribute :>> material = "Alumel";
		}
		
		port measurementPoint : ThermalSensingPort;
		port voltageOut : VoltageOutputPort;
		
		connect hotJunction.thermalInterface to measurementPoint;
	}
	
	part def ThermocoupleSystem {
		doc /* A thermocouple-based temperature measurement system that converts thermal energy 
		       into electrical voltage through the Seebeck effect, compensates for cold junction 
		       temperature variations, amplifies and digitizes the signal, and calculates an 
		       accurate temperature reading for industrial process monitoring and control. */
		
		attribute systemAccuracy :> ISQ::ThermodynamicTemperatureValue;
		attribute measurementRate :> ISQ::FrequencyValue;
		attribute powerSupply :> ISQ::ElectricPotentialValue;
		
		part sensor : Thermocouple {
			attribute :>> thermocoupleType = "Type K";
		}
		
		part cjCompensator : ColdJunctionCompensator;
		
		part amplifier : SignalAmplifier {
			attribute :>> gain = 100.0;
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
		}
		
		part calculator : TemperatureCalculator {
			attribute :>> calibrationTable = "NIST ITS-90 Type K";
		}
		
		port temperatureInput : ThermalSensingPort;
		port dataOutput : DataOutputPort;
		
		connect sensor.measurementPoint to temperatureInput;
		connect sensor.voltageOut to cjCompensator.voltageOutput;
		
		perform action measurementCycle : MeasureTemperature[*] ordered;
		
		part stateMachine : ThermocoupleOperatingStates;
	}
	
	requirement def <'REQ-001'> TemperatureMeasurementRequirement {
		doc /* The thermocouple system shall accurately measure temperature across 
		       the specified operating range using the Seebeck effect. */
		
		subject system : ThermocoupleSystem;
	}
	
	requirement def <'REQ-002'> ResponseTimeRequirement {
		doc /* The thermocouple system shall respond to temperature changes within 
		       the specified response time to enable real-time monitoring. */
		
		subject system : ThermocoupleSystem;
	}
	
	requirement def <'REQ-003'> ColdJunctionCompensationRequirement {
		doc /* The system shall compensate for cold junction temperature variations 
		       to ensure measurement accuracy. */
		
		subject compensator : ColdJunctionCompensator;
	}
	
	requirement def <'REQ-004'> SignalConditioningRequirement {
		doc /* The signal conditioning subsystem shall amplify and digitize the 
		       thermoelectric voltage with sufficient resolution and gain. */
		
		subject system : ThermocoupleSystem;
	}
	
	requirement <'SYS-REQ-001'> thermocoupleSystemRequirements {
		doc /* The thermocouple system shall measure temperature by converting thermal 
		       energy into electrical voltage, compensate for environmental variations, 
		       condition and digitize the signal, and provide accurate temperature readings 
		       for industrial monitoring and control applications. */
		
		subject system : ThermocoupleSystem;
		
		require temperatureMeasurement : TemperatureMeasurementRequirement;
		require responseTime : ResponseTimeRequirement;
		require coldJunctionCompensation : ColdJunctionCompensationRequirement;
		require signalConditioning : SignalConditioningRequirement;
	}
	
	part thermocoupleSystem : ThermocoupleSystem;
}
