package LoadCellSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SignalVoltage :> ISQ::ElectricPotentialDifferenceValue;
	attribute def StrainValue :> Real;
	attribute def CalibrationFactor :> Real;
	attribute def DigitalCount :> Integer;
	
	item def ElectricalSignal {
		attribute voltage : SignalVoltage;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def SignalOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def SignalInputPort {
		in item signal : ElectricalSignal;
	}
	
	port def MechanicalLoadPort {
		in attribute appliedForce : ISQ::ForceValue;
	}
	
	port def PowerInputPort {
		in attribute supplyVoltage : ISQ::ElectricPotentialDifferenceValue;
	}
	
	port def DigitalOutputPort {
		out attribute digitalValue : DigitalCount;
	}
	
	port def DigitalInputPort {
		in attribute digitalValue : DigitalCount;
	}
	
	part def StrainGauge {
		attribute nominalResistance : ISQ::ResistanceValue;
		attribute gaugeFactor : Real;
		
		in attribute appliedStrain : StrainValue;
		out attribute resistanceChange : ISQ::ResistanceValue;
		
		perform action measureStrain {
			in strain : StrainValue;
			out deltaR : ISQ::ResistanceValue;
		}
	}
	
	part def WheatstoneCircuit {
		attribute excitationVoltage : ISQ::ElectricPotentialDifferenceValue;
		attribute bridgeConfiguration : String;
		
		in attribute resistanceChange : ISQ::ResistanceValue;
		out attribute outputVoltage : SignalVoltage;
		
		perform action convertResistanceToVoltage {
			in deltaR : ISQ::ResistanceValue;
			in vExcitation : ISQ::ElectricPotentialDifferenceValue;
			out vOut : SignalVoltage;
		}
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute bandwidth : ISQ::FrequencyValue;
		
		in attribute inputVoltage : SignalVoltage;
		out attribute amplifiedVoltage : SignalVoltage;
		
		perform action amplifySignal {
			in vIn : SignalVoltage;
			in amplificationGain : Real;
			out vOut : SignalVoltage;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : ISQ::FrequencyValue;
		attribute referenceVoltage : ISQ::ElectricPotentialDifferenceValue;
		
		port analogInput : SignalInputPort;
		port digitalOutput : DigitalOutputPort;
		
		perform action convertSignal {
			in analogVoltage : SignalVoltage;
			in vRef : ISQ::ElectricPotentialDifferenceValue;
			in bits : Integer;
			out digitalCount : DigitalCount;
		}
	}
	
	part def Microcontroller {
		attribute processingFrequency : ISQ::FrequencyValue;
		attribute calibrationConstant : CalibrationFactor;
		
		port digitalInput : DigitalInputPort;
		
		out attribute forceOutput : ISQ::ForceValue;
		
		perform action processData {
			in digitalValue : DigitalCount;
			in calibration : CalibrationFactor;
			out force : ISQ::ForceValue;
		}
	}
	
	part def LoadCell {
		doc /* A load cell is a transducer that converts mechanical force into an electrical signal through strain measurement. */
		
		attribute maxCapacity : ISQ::ForceValue;
		attribute sensitivity : Real;
		attribute operatingTemperatureRange : ISQ::TemperatureValue[2];
		
		port mechanicalInput : MechanicalLoadPort;
		port powerInput : PowerInputPort;
		port signalOutput : SignalOutputPort;
		
		part strainGauges : StrainGauge[4] {
			doc /* Four strain gauges arranged in a full Wheatstone bridge configuration for temperature compensation. */
			attribute :>> nominalResistance = 350.0 [SI::Ω];
			attribute :>> gaugeFactor = 2.1;
		}
		
		part bridgeCircuit : WheatstoneCircuit {
			attribute :>> bridgeConfiguration = "Full Bridge";
		}
		
		part amplifier : SignalAmplifier {
			attribute :>> gain = 1000.0;
			attribute :>> bandwidth = 1000.0 [Hz];
		}
		
		perform action measureForce {
			first start;
			action applyLoad {
				in force : ISQ::ForceValue;
				out strain : StrainValue;
			}
			then action detectStrain {
				in strainInput : StrainValue;
				out resistanceChange : ISQ::ResistanceValue;
			}
			then action convertToVoltage {
				in deltaR : ISQ::ResistanceValue;
				out rawVoltage : SignalVoltage;
			}
			then action amplify {
				in rawVoltage : SignalVoltage;
				out finalVoltage : SignalVoltage;
			}
			then action outputSignal {
				in voltage : SignalVoltage;
			}
			then done;
		}
	}
	
	part def DataAcquisitionUnit {
		attribute samplingRate : ISQ::FrequencyValue;
		attribute adcResolution : Integer;
		
		port analogInput : SignalInputPort;
		port digitalOutput : DigitalOutputPort;
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = adcResolution;
			attribute :>> samplingRate = samplingRate;
			attribute :>> referenceVoltage = 5.0 [V];
		}
		
		perform action acquireData {
			in analogSignal : ElectricalSignal;
			out digitalValue : DigitalCount;
		}
	}
	
	part def DisplayUnit {
		attribute displayPrecision : Real;
		attribute updateRate : ISQ::FrequencyValue;
		
		in attribute forceValue : ISQ::ForceValue;
		
		perform action displayForce {
			in force : ISQ::ForceValue;
		}
	}
	
	part loadCellSystem : LoadCell {
		doc /* Complete load cell measurement system for precision force measurement and display. */
		
		attribute :>> maxCapacity = 5000.0 [N];
		attribute :>> sensitivity = 2.0;
		attribute :>> operatingTemperatureRange = (-10.0 [K], 60.0 [K]);
		
		part dataAcquisition : DataAcquisitionUnit {
			attribute :>> samplingRate = 1000.0 [Hz];
			attribute :>> adcResolution = 24;
		}
		
		part processor : Microcontroller {
			attribute :>> processingFrequency = 80.0 [MHz];
			attribute :>> calibrationConstant = 0.001;
		}
		
		part display : DisplayUnit {
			attribute :>> displayPrecision = 0.01;
			attribute :>> updateRate = 10.0 [Hz];
		}
		
		interface loadCellToDAQ connect signalOutput to dataAcquisition.analogInput;
		interface daqToProcessor connect dataAcquisition.digitalOutput to processor.digitalInput;
		
		binding forceDisplay of display.forceValue = processor.forceOutput;
		
		perform action operateSystem {
			first start;
			action measure : measureForce;
			then action acquire : dataAcquisition.acquireData {
				in analogSignal;
				out digitalValue;
			}
			then action process : processor.processData {
				in digitalValue;
				in calibration;
				out force;
			}
			then action show : display.displayForce {
				in force;
			}
			then done;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The load cell shall provide accurate force measurements within specified tolerance. */
		
		subject loadCell : LoadCell;
		
		attribute measuredForce : ISQ::ForceValue;
		attribute actualForce : ISQ::ForceValue;
		attribute maxError : ISQ::ForceValue;
		
		require constraint {
			abs(measuredForce - actualForce) <= maxError
		}
	}
	
	requirement def LinearityRequirement {
		doc /* The load cell output shall be linear with respect to applied force across its operating range. */
		
		subject loadCell : LoadCell;
		
		attribute nonlinearity : Real;
		attribute maxNonlinearity : Real;
		
		require constraint {
			nonlinearity <= maxNonlinearity
		}
	}
	
	requirement def CapacityRequirement {
		doc /* The load cell shall operate safely within its rated capacity without damage. */
		
		subject loadCell : LoadCell;
		
		attribute appliedForce : ISQ::ForceValue;
		attribute ratedCapacity : ISQ::ForceValue;
		
		require constraint {
			appliedForce <= ratedCapacity
		}
	}
	
	requirement def TemperatureStabilityRequirement {
		doc /* The load cell shall maintain accuracy across its operating temperature range. */
		
		subject loadCell : LoadCell;
		
		attribute operatingTemperature : ISQ::TemperatureValue;
		attribute minTemperature : ISQ::TemperatureValue;
		attribute maxTemperature : ISQ::TemperatureValue;
		attribute temperatureCoefficient : Real;
		
		require constraint {
			operatingTemperature >= minTemperature and operatingTemperature <= maxTemperature
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the load cell measurement system. */
		
		require accuracyReq : AccuracyRequirement {
			subject loadCell = loadCellSystem;
			attribute :>> maxError = 5.0 [N];
		}
		
		require linearityReq : LinearityRequirement {
			subject loadCell = loadCellSystem;
			attribute :>> maxNonlinearity = 0.03;
		}
		
		require capacityReq : CapacityRequirement {
			subject loadCell = loadCellSystem;
			attribute :>> appliedForce = loadCellSystem.mechanicalInput.appliedForce;
			attribute :>> ratedCapacity = loadCellSystem.maxCapacity;
		}
		
		require temperatureReq : TemperatureStabilityRequirement {
			subject loadCell = loadCellSystem;
			attribute :>> minTemperature = loadCellSystem.operatingTemperatureRange[1];
			attribute :>> maxTemperature = loadCellSystem.operatingTemperatureRange[2];
			attribute :>> temperatureCoefficient = 0.0005;
		}
	}
}
