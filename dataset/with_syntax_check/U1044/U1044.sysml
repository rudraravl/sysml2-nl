package ElectricPowerTransmissionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;

	attribute def GridCommand;
	attribute def StartTransmission;
	attribute def StopTransmission;
	attribute def FaultDetected;
	attribute def FaultCleared;

	port def ElectricalPort {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : Real;
		attribute activePower : ISQ::PowerValue;
	}

	part def PowerPlant {
		port output : ~ElectricalPort;
		attribute generationCapacity : ISQ::PowerValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute outputFrequency : Real;
	}

	part def StepUpTransformer {
		port primarySide : ElectricalPort;
		port secondarySide : ~ElectricalPort;
		attribute primaryVoltage : ISQ::ElectricPotentialValue;
		attribute secondaryVoltage : ISQ::ElectricPotentialValue;
		attribute voltageRatio : Real;
		attribute efficiency : Real;
		assert constraint { voltageRatio == secondaryVoltage / primaryVoltage }
		assert constraint { efficiency >= 0.95 and efficiency <= 0.99 }
	}

	part def HighVoltageTransmissionLine {
		port sendingEnd : ElectricalPort;
		port receivingEnd : ~ElectricalPort;
		attribute lineLength : ISQ::LengthValue;
		attribute resistancePerKm : Real;
		attribute reactancePerKm : Real;
		attribute totalResistance : Real = resistancePerKm * (lineLength / (1 [km]));
		attribute totalReactance : Real = reactancePerKm * (lineLength / (1 [km]));
		attribute transmissionLoss : ISQ::PowerValue;
	}

	part def StepDownTransformer {
		port primarySide : ElectricalPort;
		port secondarySide : ~ElectricalPort;
		attribute primaryVoltage : ISQ::ElectricPotentialValue;
		attribute secondaryVoltage : ISQ::ElectricPotentialValue;
		attribute voltageRatio : Real;
		attribute efficiency : Real;
		assert constraint { voltageRatio == primaryVoltage / secondaryVoltage }
		assert constraint { efficiency >= 0.95 and efficiency <= 0.99 }
	}

	part def DistributionSubstation {
		port input : ElectricalPort;
		port output : ~ElectricalPort[1..*];
		attribute distributionVoltage : ISQ::ElectricPotentialValue;
		attribute totalLoad : ISQ::PowerValue;
		attribute numberOfFeeders : Integer;
	}

	part def ProtectionSystem {
		port monitoringPoint : ElectricalPort;
		attribute currentThreshold : ISQ::ElectricCurrentValue;
		attribute voltageThreshold : ISQ::ElectricPotentialValue;
		attribute responseTime : ISQ::TimeValue;
		attribute protectionStatus : ProtectionStatusKind;
	}

	enum def ProtectionStatusKind {
		normal;
		warning;
		tripped;
	}

	state def TransmissionSystemStates {
		entry; then offline;

		state offline;
		accept startCmd : StartTransmission
			then online;

		state online {
			entry; then normalOperation;

			state normalOperation;
			accept fault : FaultDetected
				then faultIsolation;

			state faultIsolation {
				do action isolateFaultedSection;
			}
			accept cleared : FaultCleared
				then normalOperation;
		}

		accept stopCmd : StopTransmission
			then offline;
	}

	action def GenerateElectricalPower {
		in fuelInput : Real;
		in targetVoltage : ISQ::ElectricPotentialValue;
		in targetFrequency : Real;
		out generatedPower : ISQ::PowerValue;
		out outputVoltage : ISQ::ElectricPotentialValue;
		out outputFrequency : Real;
	}

	action def StepUpVoltage {
		in inputPower : ISQ::PowerValue;
		in inputVoltage : ISQ::ElectricPotentialValue;
		in transformerRatio : Real;
		in transformerEfficiency : Real;
		out outputPower : ISQ::PowerValue;
		out outputVoltage : ISQ::ElectricPotentialValue;
	}

	action def TransmitPowerOverLine {
		in sendingPower : ISQ::PowerValue;
		in sendingVoltage : ISQ::ElectricPotentialValue;
		in lineResistance : Real;
		in lineReactance : Real;
		out receivingPower : ISQ::PowerValue;
		out receivingVoltage : ISQ::ElectricPotentialValue;
		out powerLoss : ISQ::PowerValue;
	}

	action def StepDownVoltage {
		in inputPower : ISQ::PowerValue;
		in inputVoltage : ISQ::ElectricPotentialValue;
		in transformerRatio : Real;
		in transformerEfficiency : Real;
		out outputPower : ISQ::PowerValue;
		out outputVoltage : ISQ::ElectricPotentialValue;
	}

	action def DistributePowerToLoads {
		in totalPower : ISQ::PowerValue;
		in distributionVoltage : ISQ::ElectricPotentialValue;
		in loadDemands : ISQ::PowerValue[*];
		out distributedPower : ISQ::PowerValue[*];
	}

	action def MonitorAndProtect {
		in monitoredVoltage : ISQ::ElectricPotentialValue;
		in monitoredCurrent : ISQ::ElectricCurrentValue;
		in voltageLimit : ISQ::ElectricPotentialValue;
		in currentLimit : ISQ::ElectricCurrentValue;
		out protectionSignal : ProtectionStatusKind;
	}

	action def TransmitElectricalPower {
		in startCmd : StartTransmission;
		in stopCmd : StopTransmission;
		in generationCapacity : ISQ::PowerValue;
		in transmissionVoltage : ISQ::ElectricPotentialValue;
		in distributionVoltage : ISQ::ElectricPotentialValue;
		out deliveredPower : ISQ::PowerValue;
		out overallEfficiency : Real;
	}

	part def TransmissionSystem {
		part powerPlant : PowerPlant;
		part stepUpTransformer : StepUpTransformer;
		part transmissionLine : HighVoltageTransmissionLine;
		part stepDownTransformer : StepDownTransformer;
		part distributionSubstation : DistributionSubstation;
		part protectionSystem : ProtectionSystem;
		attribute systemEfficiency : Real;
	}

	part transmissionSystem : TransmissionSystem {
		part :>> powerPlant {
			attribute :>> generationCapacity = 800000000 [W];
			attribute :>> outputVoltage = 22000 [V];
			attribute :>> outputFrequency = 60.0;
		}

		part :>> stepUpTransformer {
			attribute :>> primaryVoltage = 22000 [V];
			attribute :>> secondaryVoltage = 345000 [V];
			attribute :>> voltageRatio = 15.68;
			attribute :>> efficiency = 0.98;
		}

		part :>> transmissionLine {
			attribute :>> lineLength = 250000 [m];
			attribute :>> resistancePerKm = 0.04;
			attribute :>> reactancePerKm = 0.35;
			attribute :>> transmissionLoss;
		}

		part :>> stepDownTransformer {
			attribute :>> primaryVoltage = 345000 [V];
			attribute :>> secondaryVoltage = 34500 [V];
			attribute :>> voltageRatio = 10.0;
			attribute :>> efficiency = 0.98;
		}

		part :>> distributionSubstation {
			attribute :>> distributionVoltage = 34500 [V];
			attribute :>> totalLoad;
			attribute :>> numberOfFeeders = 8;
		}

		part :>> protectionSystem {
			attribute :>> currentThreshold = 2500 [A];
			attribute :>> voltageThreshold = 380000 [V];
			attribute :>> responseTime = 0.08 [s];
			attribute :>> protectionStatus = ProtectionStatusKind::normal;
		}

		connect powerPlant.output to stepUpTransformer.primarySide;
		connect stepUpTransformer.secondarySide to transmissionLine.sendingEnd;
		connect transmissionLine.receivingEnd to stepDownTransformer.primarySide;
		connect stepDownTransformer.secondarySide to distributionSubstation.input;
		bind protectionSystem.monitoringPoint = transmissionLine.receivingEnd;

		assert constraint efficiencyCalculation {
			systemEfficiency == stepUpTransformer.efficiency * stepDownTransformer.efficiency * 
				(1.0 - (transmissionLine.transmissionLoss / powerPlant.generationCapacity))
		}

		assert constraint powerBalanceConstraint {
			distributionSubstation.totalLoad <= powerPlant.generationCapacity - transmissionLine.transmissionLoss
		}

		assert constraint voltageStabilityConstraint {
			transmissionLine.sendingEnd.voltage >= 0.95 * stepUpTransformer.secondaryVoltage and
			transmissionLine.sendingEnd.voltage <= 1.05 * stepUpTransformer.secondaryVoltage
		}

		exhibit state systemState : TransmissionSystemStates;

		perform action operateTransmission : TransmitElectricalPower {
			in generationCapacity = powerPlant.generationCapacity;
			in transmissionVoltage = stepUpTransformer.secondaryVoltage;
			in distributionVoltage = distributionSubstation.distributionVoltage;
			out deliveredPower;
			out overallEfficiency;

			first start;
			then merge continuousOperation;

			action generatePower : GenerateElectricalPower {
				in fuelInput;
				in targetVoltage = powerPlant.outputVoltage;
				in targetFrequency = powerPlant.outputFrequency;
				out generatedPower;
				out outputVoltage;
				out outputFrequency;
			}

			flow generatePower.generatedPower to stepUp.inputPower;
			flow generatePower.outputVoltage to stepUp.inputVoltage;

			then action stepUp : StepUpVoltage {
				in inputPower;
				in inputVoltage;
				in transformerRatio = stepUpTransformer.voltageRatio;
				in transformerEfficiency = stepUpTransformer.efficiency;
				out outputPower;
				out outputVoltage;
			}

			flow stepUp.outputPower to transmit.sendingPower;
			flow stepUp.outputVoltage to transmit.sendingVoltage;

			then action transmit : TransmitPowerOverLine {
				in sendingPower;
				in sendingVoltage;
				in lineResistance = transmissionLine.totalResistance;
				in lineReactance = transmissionLine.totalReactance;
				out receivingPower;
				out receivingVoltage;
				out powerLoss;
			}

			flow transmit.receivingPower to stepDown.inputPower;
			flow transmit.receivingVoltage to stepDown.inputVoltage;

			then action stepDown : StepDownVoltage {
				in inputPower;
				in inputVoltage;
				in transformerRatio = stepDownTransformer.voltageRatio;
				in transformerEfficiency = stepDownTransformer.efficiency;
				out outputPower;
				out outputVoltage;
			}

			flow stepDown.outputPower to distribute.totalPower;
			flow stepDown.outputVoltage to distribute.distributionVoltage;

			then action distribute : DistributePowerToLoads {
				in totalPower;
				in distributionVoltage;
				in loadDemands;
				out distributedPower;
			}

			then action monitor : MonitorAndProtect {
				in monitoredVoltage;
				in monitoredCurrent;
				in voltageLimit = protectionSystem.voltageThreshold;
				in currentLimit = protectionSystem.currentThreshold;
				out protectionSignal;
			}

			then decide;
				if monitor.protectionSignal == ProtectionStatusKind::normal then continuousOperation;
				if monitor.protectionSignal == ProtectionStatusKind::tripped then handleFault;

			then action handleFault {
				then done;
			}

			then continuousOperation;
		}
	}

	requirement def TransmissionSystemRequirements {
		doc /* The electric power transmission system shall efficiently and reliably 
		     transfer electrical energy from generation facilities to distribution networks 
		     over long distances using high voltage transmission lines. */

		requirement systemEfficiencyRequirement {
			doc /* The overall transmission system efficiency shall be at least 90%. */
			subject system : TransmissionSystem;
			require constraint { system.systemEfficiency >= 0.90 }
		}

		requirement transmissionLossRequirement {
			doc /* Transmission line losses shall not exceed 8% of transmitted power. */
			subject line : HighVoltageTransmissionLine;
			require constraint { 
				line.transmissionLoss <= 0.08 * line.sendingEnd.activePower
			}
		}

		requirement voltageRegulationRequirement {
			doc /* Transmission voltage shall be maintained within ±5% of nominal value. */
			subject line : HighVoltageTransmissionLine;
			require constraint {
				line.sendingEnd.voltage >= 0.95 * 345000 [V] and
				line.sendingEnd.voltage <= 1.05 * 345000 [V]
			}
		}

		requirement protectionResponseRequirement {
			doc /* Protection system shall detect and isolate faults within 100 milliseconds. */
			subject protection : ProtectionSystem;
			require constraint { protection.responseTime <= 0.1 [s] }
		}

		requirement frequencyStabilityRequirement {
			doc /* System frequency shall be maintained within ±0.5 Hz of nominal 60 Hz. */
			subject port : ElectricalPort;
			require constraint {
				port.frequency >= 59.5 and port.frequency <= 60.5
			}
		}

		requirement reliabilityRequirement {
			doc /* The transmission system shall maintain 99.5% availability during normal operating conditions. */
			subject system : TransmissionSystem;
		}
	}

	requirement transmissionSystemSpec : TransmissionSystemRequirements {
		subject system = transmissionSystem;
	}
}
