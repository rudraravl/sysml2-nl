package ReedSwitchSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticFluxDensity :> ISQ::MagneticFluxDensityValue {
		doc /* Magnetic flux density measured in Tesla or milliTesla */
	}
	
	attribute def SwitchState {
		attribute open : Boolean;
		attribute closed : Boolean;
	}
	
	item def MagneticFieldSignal {
		attribute fluxDensity : MagneticFluxDensity;
		attribute direction : String;
	}
	
	item def ElectricalSignal {
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute continuity : Boolean;
	}
	
	port def MagneticInputPort {
		in item fieldInput : MagneticFieldSignal;
	}
	
	port def ElectricalSwitchPort {
		inout item electricalPath : ElectricalSignal;
	}
	
	part def Magnet {
		doc /* External magnet that generates magnetic field to actuate the reed switch */
		attribute fieldStrength : MagneticFluxDensity;
		attribute position : ISQ::LengthValue;
		port magneticEmission {
			out item emittedField : MagneticFieldSignal;
		}
		action def GenerateField {
			out field : MagneticFieldSignal;
			then assign field.fluxDensity := fieldStrength;
			then assign field.direction := "axial";
		}
	}
	
	part def ReedSwitch {
		doc /* Magnetically actuated switch with ferromagnetic reed contacts in sealed glass envelope */
		attribute activationThreshold : MagneticFluxDensity;
		attribute releaseThreshold : MagneticFluxDensity;
		attribute contactResistance : ISQ::ResistanceValue;
		attribute currentState : SwitchState;
		port magneticSensor : MagneticInputPort;
		port terminal1 : ElectricalSwitchPort;
		port terminal2 : ElectricalSwitchPort;
		part reedContacts[2] {
			doc /* Ferromagnetic blades that flex and make contact under magnetic field */
			attribute material : String = "Nickel-Iron alloy";
			attribute length : ISQ::LengthValue;
		}
		part glassEnvelope {
			doc /* Hermetically sealed protective housing */
			attribute inertGas : String = "Nitrogen";
		}
		perform action switchOperation;
	}
	
	part def PowerSource {
		doc /* Electrical power supply for the circuit */
		attribute supplyVoltage : ISQ::ElectricPotentialDifferenceValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		port positiveTerminal {
			out item powerOut : ElectricalSignal;
		}
		port negativeTerminal {
			out item groundRef : ElectricalSignal;
		}
	}
	
	part def Load {
		doc /* Electrical load controlled by the reed switch */
		attribute impedance : ISQ::ResistanceValue;
		attribute operatingVoltage : ISQ::ElectricPotentialDifferenceValue;
		attribute powerRating : ISQ::PowerValue;
		port loadInput {
			in item powerIn : ElectricalSignal;
		}
		action def Operate {
			in signal : ElectricalSignal;
			out operational : Boolean;
		}
	}
	
	action def DetectMagneticField {
		doc /* Sense the presence and strength of magnetic field */
		in fieldSignal : MagneticFieldSignal;
		out detectedStrength : MagneticFluxDensity;
		out fieldPresent : Boolean;
		then assign detectedStrength := fieldSignal.fluxDensity;
		then decide;
			if detectedStrength.num > 0.0 then assign fieldPresent := true;
			if detectedStrength.num <= 0.0 then assign fieldPresent := false;
	}
	
	action def ActuateReedContacts {
		doc /* Mechanically close or open reed contacts based on magnetic field strength */
		in fieldStrength : MagneticFluxDensity;
		in activationLevel : MagneticFluxDensity;
		in releaseLevel : MagneticFluxDensity;
		in currentlyClosed : Boolean;
		out contactsClosed : Boolean;
		then decide;
			if fieldStrength.num >= activationLevel.num then assign contactsClosed := true;
			if fieldStrength.num < releaseLevel.num then assign contactsClosed := false;
			if fieldStrength.num >= releaseLevel.num and fieldStrength.num < activationLevel.num then assign contactsClosed := currentlyClosed;
	}
	
	action def SwitchElectricalCircuit {
		doc /* Control electrical continuity through the switch based on contact state */
		in contactsClosed : Boolean;
		in inputPower : ElectricalSignal;
		out outputPower : ElectricalSignal;
		then decide;
			if contactsClosed then assign outputPower := inputPower;
			if not contactsClosed then assign outputPower := ElectricalSignal {
				voltage = 0.0 [V];
				current = 0.0 [A];
				continuity = false;
			};
	}
	
	action def OperateReedSwitch {
		doc /* Primary function: detect magnetic field and switch electrical circuit accordingly */
		in magneticInput : MagneticFieldSignal;
		in electricalInput : ElectricalSignal;
		in activationThreshold : MagneticFluxDensity;
		in releaseThreshold : MagneticFluxDensity;
		in priorState : Boolean;
		out electricalOutput : ElectricalSignal;
		out newState : SwitchState;
		first start;
		then action detectField : DetectMagneticField {
			in fieldSignal = magneticInput;
			out detectedStrength;
			out fieldPresent;
		}
		then action actuate : ActuateReedContacts {
			in fieldStrength = detectField.detectedStrength;
			in activationLevel = activationThreshold;
			in releaseLevel = releaseThreshold;
			in currentlyClosed = priorState;
			out contactsClosed;
		}
		then action switchCircuit : SwitchElectricalCircuit {
			in contactsClosed = actuate.contactsClosed;
			in inputPower = electricalInput;
			out outputPower;
		}
		then assign electricalOutput := switchCircuit.outputPower;
		then assign newState := SwitchState {
			open = !actuate.contactsClosed;
			closed = actuate.contactsClosed;
		}
		then done;
	}
	
	state def ReedSwitchBehavior {
		doc /* State machine governing reed switch contact behavior */
		entry; then openState;
		state openState {
			doc /* Contacts separated, no electrical continuity */
			entry assign currentState.open := true;
			entry assign currentState.closed := false;
		}
		state closedState {
			doc /* Contacts touching, electrical continuity established */
			entry assign currentState.open := false;
			entry assign currentState.closed := true;
		}
		transition openToClosedTransition
			first openState
			accept fieldApplied : MagneticFieldSignal
			if fieldApplied.fluxDensity.num >= activationThreshold.num
			then closedState;
		transition closedToOpenTransition
			first closedState
			accept fieldRemoved : MagneticFieldSignal
			if fieldRemoved.fluxDensity.num < releaseThreshold.num
			then openState;
	}
	
	part reedSwitchControlSystem {
		doc /* Complete system demonstrating reed switch operation for proximity sensing and circuit control */
		part proximityMagnet : Magnet {
			attribute :>> fieldStrength = 40.0 [T];
			attribute :>> position = 5.0 [mm];
			perform action generateMagneticField : GenerateField {
				out field;
			}
		}
		part reedSwitch : ReedSwitch {
			attribute :>> activationThreshold = 0.015 [T];
			attribute :>> releaseThreshold = 0.008 [T];
			attribute :>> contactResistance = 0.1 [Ω];
			exhibit state behavior : ReedSwitchBehavior;
			perform action switchOperation : OperateReedSwitch {
				in magneticInput;
				in electricalInput;
				in activationThreshold = reedSwitch.activationThreshold;
				in releaseThreshold = reedSwitch.releaseThreshold;
				in priorState = reedSwitch.currentState.closed;
				out electricalOutput;
				out newState;
			}
		}
		part powerSupply : PowerSource {
			attribute :>> supplyVoltage = 12.0 [V];
			attribute :>> maxCurrent = 1.0 [A];
		}
		part controlledLoad : Load {
			attribute :>> impedance = 120.0 [Ω];
			attribute :>> operatingVoltage = 12.0 [V];
			attribute :>> powerRating = 1.2 [W];
			perform action operate : Operate {
				in signal;
				out operational;
			}
		}
		connection magneticCoupling
			connect proximityMagnet.magneticEmission.emittedField to reedSwitch.magneticSensor.fieldInput;
		connection powerToSwitch
			connect powerSupply.positiveTerminal.powerOut to reedSwitch.terminal1.electricalPath;
		connection switchToLoad
			connect reedSwitch.terminal2.electricalPath to controlledLoad.loadInput.powerIn;
		connection loadToGround
			connect controlledLoad.loadInput.powerIn to powerSupply.negativeTerminal.groundRef;
	}
	
	requirement def SwitchPerformanceRequirement {
		doc /* Requirements for reed switch operational performance */
		subject switch : ReedSwitch;
		require constraint activationConsistency {
			doc /* Switch must reliably close when magnetic field exceeds activation threshold */
			switch.magneticSensor.fieldInput.fluxDensity.num >= switch.activationThreshold.num
				implies switch.currentState.closed
		}
		require constraint releaseConsistency {
			doc /* Switch must reliably open when magnetic field falls below release threshold */
			switch.magneticSensor.fieldInput.fluxDensity.num < switch.releaseThreshold.num
				implies switch.currentState.open
		}
		require constraint hysteresisMargin {
			doc /* Activation and release thresholds must provide adequate hysteresis */
			switch.activationThreshold.num > switch.releaseThreshold.num
		}
	}
	
	requirement def SystemFunctionalRequirement {
		doc /* High-level system requirement for proximity detection and load control */
		subject system : reedSwitchControlSystem;
		require performanceReq : SwitchPerformanceRequirement {
			subject switch = system.reedSwitch;
		}
		require constraint proximityDetectionFunction {
			doc /* System shall detect magnet proximity and control electrical load accordingly */
			system.proximityMagnet.fieldStrength.num >= system.reedSwitch.activationThreshold.num
				implies system.controlledLoad.loadInput.powerIn.continuity
		}
		require constraint loadIsolation {
			doc /* System shall isolate load when magnet is not in proximity */
			system.proximityMagnet.fieldStrength.num < system.reedSwitch.releaseThreshold.num
				implies not system.controlledLoad.loadInput.powerIn.continuity
		}
	}
}
