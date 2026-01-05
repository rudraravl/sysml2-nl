package 'Proportional Counter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	attribute def ChargeValue :> ISQ::ElectricChargeValue;
	attribute def EnergyValue :> ISQ::EnergyValue;
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def LengthValue :> ISQ::LengthValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def TimeValue :> ISQ::TimeValue;

	item def IonizingParticle {
		attribute particleEnergy : EnergyValue;
		attribute particleType : String;
		attribute arrivalTime : TimeValue;
	}

	item def IonPair {
		attribute electronCount : Integer;
		attribute ionCount : Integer;
		attribute creationTime : TimeValue;
	}

	item def ElectricalPulse {
		attribute pulseAmplitude : VoltageValue;
		attribute totalCharge : ChargeValue;
		attribute pulseWidth : TimeValue;
	}

	item def CounterGas {
		attribute gasType : String;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
	}

	port def ParticleInputPort {
		in item particle : IonizingParticle;
	}

	port def HighVoltagePort {
		in attribute voltage : VoltageValue;
	}

	port def SignalOutputPort {
		out item pulse : ElectricalPulse;
	}

	port def GasSupplyPort {
		in item gas : CounterGas;
	}

	part def DetectorChamber {
		attribute chamberLength : LengthValue;
		attribute chamberDiameter : LengthValue;
		port particleEntry : ParticleInputPort;
		port gasSupply : GasSupplyPort;
		part fillGas : CounterGas;
	}

	part def AnodeWire {
		attribute wireRadius : LengthValue;
		attribute wireMaterial : String;
		port hvConnection : HighVoltagePort;
	}

	part def CathodeCylinder {
		attribute cylinderRadius : LengthValue;
		attribute cylinderMaterial : String;
	}

	part def HighVoltageSupply {
		attribute nominalVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute stability : Real;
		port hvOutput : HighVoltagePort;
	}

	part def ChargeAmplifier {
		attribute gain : Real;
		attribute inputCapacitance : Real;
		port pulseInput;
		port pulseOutput : SignalOutputPort;
	}

	part def PulseShaper {
		attribute shapingTime : TimeValue;
		port input;
		port output;
	}

	action def PrimaryIonization {
		in particle : IonizingParticle;
		in gas : CounterGas;
		out primaryIons : IonPair;
	}

	action def GasAmplification {
		in primaryIons : IonPair;
		in electricField : VoltageValue;
		in gasPressure : PressureValue;
		out amplifiedIons : IonPair;
	}

	action def ChargeInduction {
		in amplifiedIons : IonPair;
		in anodeCapacitance : Real;
		out inducedPulse : ElectricalPulse;
	}

	action def PulseAmplification {
		in rawPulse : ElectricalPulse;
		in amplifierGain : Real;
		out amplifiedPulse : ElectricalPulse;
	}

	action def DetectAndMeasureRadiation {
		doc /* 
			Primary detection and measurement cycle for ionizing radiation.
			Converts particle energy into proportional electrical pulse.
		*/

		first start;

		then action receiveParticle {
			in incomingParticle : IonizingParticle;
			out detectedParticle : IonizingParticle;
		}

		then action ionizationStep : PrimaryIonization {
			in particle = receiveParticle.detectedParticle;
			in gas;
			out primaryIons;
		}

		then action multiplicationStep : GasAmplification {
			in primaryIons = ionizationStep.primaryIons;
			in electricField;
			in gasPressure;
			out amplifiedIons;
		}

		then action inductionStep : ChargeInduction {
			in amplifiedIons = multiplicationStep.amplifiedIons;
			in anodeCapacitance;
			out inducedPulse;
		}

		then action amplificationStep : PulseAmplification {
			in rawPulse = inductionStep.inducedPulse;
			in amplifierGain;
			out amplifiedPulse;
		}

		then action outputPulse {
			in finalPulse = amplificationStep.amplifiedPulse;
			out measuredPulse : ElectricalPulse;
		}

		then done;
	}

	part def ProportionalCounter {
		doc /* 
			A proportional counter is a gas-filled radiation detector operating in the 
			proportional region where charge multiplication occurs. When ionizing radiation 
			enters the detector volume, it creates primary ion pairs in the fill gas. 
			These charges drift in the electric field between the cylindrical cathode and 
			central anode wire. Near the anode, the field strength becomes sufficient to 
			cause gas multiplication through avalanche processes. The resulting charge is 
			proportional to the incident particle energy, enabling both counting and 
			energy spectroscopy of ionizing radiation.
		*/

		attribute operatingVoltage : VoltageValue;
		attribute gasPressure : PressureValue;
		attribute multiplicationFactor : Real;
		attribute detectionEfficiency : Real;

		port particleInput : ParticleInputPort;
		port hvInput : HighVoltagePort;
		port signalOutput : SignalOutputPort;
		port gasInput : GasSupplyPort;

		part chamber : DetectorChamber {
			attribute :>> chamberLength = 100.0 [SI::mm];
			attribute :>> chamberDiameter = 50.0 [SI::mm];
		}

		part anode : AnodeWire {
			attribute :>> wireRadius = 0.025 [SI::mm];
			attribute :>> wireMaterial = "Tungsten";
		}

		part cathode : CathodeCylinder {
			attribute :>> cylinderRadius = 25.0 [SI::mm];
			attribute :>> cylinderMaterial = "Stainless Steel";
		}

		part hvSupply : HighVoltageSupply {
			attribute :>> nominalVoltage = 1800.0 [SI::V];
			attribute :>> maxCurrent = 0.0001 [SI::A];
			attribute :>> stability = 0.001;
		}

		part chargeAmp : ChargeAmplifier {
			attribute :>> gain = 50.0;
			attribute :>> inputCapacitance = 10.0e-12;
		}

		part shaper : PulseShaper {
			attribute :>> shapingTime = 2.0e-6 [SI::s];
		}

		connection hvConnection connect hvSupply.hvOutput to anode.hvConnection;
		connection signalPath1 connect chargeAmp.pulseOutput to shaper.input;
		connection signalPath2 connect shaper.output to signalOutput;
		connection gasConnection connect gasInput to chamber.gasSupply;
		connection particleConnection connect particleInput to chamber.particleEntry;

		perform action detectionCycle[*] ordered references DetectAndMeasureRadiation {
			in incomingParticle;
			in gas = chamber.fillGas;
			in electricField = operatingVoltage;
			in gasPressure = chamber.fillGas.pressure;
			in anodeCapacitance = chargeAmp.inputCapacitance;
			in amplifierGain = chargeAmp.gain;
			out measuredPulse;
		}
	}

	requirement def FunctionalRequirements {
		doc /* Primary functional requirements for proportional counter operation */

		require detectionCapability {
			doc /* The system shall detect ionizing radiation and produce output pulses */
		}

		require proportionalResponse {
			doc /* Output pulse amplitude shall be proportional to incident particle energy */
			attribute proportionalityTolerance : Real = 0.05;
		}

		require operatingRange {
			doc /* The detector shall operate in the proportional region */
			attribute minVoltage : VoltageValue = 1000.0 [SI::V];
			attribute maxVoltage : VoltageValue = 2500.0 [SI::V];
		}

		require multiplicationRange {
			doc /* Gas multiplication factor shall be between 10 and 10000 */
			attribute minMultiplication : Real = 10.0;
			attribute maxMultiplication : Real = 10000.0;
		}
	}

	requirement def PerformanceRequirements {
		doc /* Performance requirements for radiation detection */

		require energyResolution {
			doc /* Energy resolution shall be better than 15% FWHM at 5.9 keV */
			attribute maxResolution : Real = 0.15;
		}

		require countRate {
			doc /* Maximum count rate shall exceed 10000 counts per second */
			attribute minCountRate : Real = 10000.0;
		}

		require efficiency {
			doc /* Detection efficiency shall exceed 95% for target radiation */
			attribute minEfficiency : Real = 0.95;
		}
	}

	requirement systemRequirements {
		subject detectorSystem;

		require functionalReqs : FunctionalRequirements;
		require performanceReqs : PerformanceRequirements;

		assume constraint validGas {
			doc /* Fill gas must support proportional operation */
			detectorSystem.detector.chamber.fillGas.gasType == "P10" or
			detectorSystem.detector.chamber.fillGas.gasType == "Ar-CO2";
		}

		assume constraint validPressure {
			doc /* Gas pressure must be within operational range */
			detectorSystem.detector.chamber.fillGas.pressure >= 50000.0 [SI::Pa] and
			detectorSystem.detector.chamber.fillGas.pressure <= 200000.0 [SI::Pa];
		}
	}

	part detectorSystem {
		doc /* 
			Complete proportional counter system for detecting and measuring 
			ionizing radiation with energy discrimination and counting capability.
			The system operates by converting incident radiation energy into 
			proportional electrical pulses through controlled gas multiplication.
		*/

		part detector : ProportionalCounter {
			attribute :>> operatingVoltage = 1800.0 [SI::V];
			attribute :>> gasPressure = 101325.0 [SI::Pa];
			attribute :>> multiplicationFactor = 500.0;
			attribute :>> detectionEfficiency = 0.98;

			part :>> chamber {
				part :>> fillGas {
					attribute :>> gasType = "P10";
					attribute :>> pressure = 101325.0 [SI::Pa];
					attribute :>> temperature = 293.15 [SI::K];
				}
			}
		}

		part controlUnit {
			attribute voltageControl : VoltageValue;
			attribute monitoringActive : Boolean;
		}

		part dataAcquisition {
			attribute samplingRate : Real;
			attribute pulseHeightAnalysis : Boolean;
			attribute spectrumAccumulation : Boolean;
		}

		satisfy systemRequirements;
	}
}
