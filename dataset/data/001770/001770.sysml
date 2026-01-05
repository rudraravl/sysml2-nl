package 'Electromagnetic Relay System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CoilTurns;
	attribute def ContactMaterial;
	attribute def ArmaturePosition;
	
	item def ElectricalSignal {
		attribute voltage :> ISQ::voltage;
		attribute current :> ISQ::electricCurrent;
	}
	
	item def MagneticFlux {
		attribute density :> ISQ::magneticFluxDensity;
		attribute totalFlux :> ISQ::magneticFlux;
	}
	
	item def MechanicalForce {
		attribute magnitude :> ISQ::force;
		attribute direction : String;
	}
	
	port def ControlPort {
		in item controlSignal : ElectricalSignal;
	}
	
	port def PowerPort {
		in item inputPower : ElectricalSignal;
		out item outputPower : ElectricalSignal;
	}
	
	port def MagneticCouplingPort {
		out item magneticField : MagneticFlux;
		in item mechanicalResponse : MechanicalForce;
	}
	
	part def ElectromagneticCoil {
		attribute numberOfTurns : CoilTurns;
		attribute resistance :> ISQ::resistance;
		attribute inductance :> ISQ::inductance;
		attribute corePermeability :> ISQ::permeability;
		
		port controlInput : ControlPort;
		port magneticOutput : MagneticCouplingPort;
	}
	
	part def Armature {
		attribute mass :> ISQ::mass;
		attribute position : ArmaturePosition;
		attribute springConstant : Real;
		
		port magneticInput : MagneticCouplingPort;
	}
	
	part def ContactSet {
		attribute material : ContactMaterial;
		attribute contactResistance :> ISQ::resistance;
		attribute maxCurrent :> ISQ::electricCurrent;
		attribute maxVoltage :> ISQ::voltage;
		
		port loadInput : PowerPort;
		port loadOutput : PowerPort;
	}
	
	part def ReturnSpring {
		attribute springConstant : Real;
		attribute preloadForce :> ISQ::force;
		attribute compressionLength :> ISQ::length;
	}
	
	action def GenerateMagneticField {
		in coilCurrent : ISQ::ElectricCurrentValue;
		in coilTurns : Real;
		in corePermeability : ISQ::PermeabilityValue;
		out magneticFluxDensity : ISQ::MagneticFluxDensityValue;
		out magneticForce : ISQ::ForceValue;
	}
	
	action def MoveArmature {
		in appliedForce : ISQ::ForceValue;
		in springForce : ISQ::ForceValue;
		in armatureMass : ISQ::MassValue;
		out armaturePosition : ISQ::LengthValue;
		out armatureVelocity : ISQ::SpeedValue;
	}
	
	action def SwitchContacts {
		in armaturePosition : ISQ::LengthValue;
		in thresholdPosition : ISQ::LengthValue;
		out contactState : Boolean;
	}
	
	state def RelayOperationState {
		in coilVoltage : ISQ::VoltageValue;
		in activationVoltage : ISQ::VoltageValue;
		in dropoutVoltage : ISQ::VoltageValue;
		in armaturePosition : ISQ::LengthValue;
		in closedPosition : ISQ::LengthValue;
		in openPosition : ISQ::LengthValue;
		
		entry; then deenergized;
		
		state deenergized {
			doc /* Coil is not energized, contacts are in normal position (open or closed based on relay type). */
		}
		
		transition deenergized_to_energizing
			first deenergized
			accept when coilVoltage >= activationVoltage
			then energizing;
		
		state energizing {
			doc /* Coil is energized, magnetic field is building, armature is moving. */
		}
		
		transition energizing_to_energized
			first energizing
			accept when armaturePosition >= closedPosition
			then energized;
		
		state energized {
			doc /* Coil is fully energized, armature is held in attracted position, contacts are switched. */
		}
		
		transition energized_to_releasing
			first energized
			accept when coilVoltage < dropoutVoltage
			then releasing;
		
		state releasing {
			doc /* Coil is de-energized, magnetic field is collapsing, spring returns armature. */
		}
		
		transition releasing_to_deenergized
			first releasing
			accept when armaturePosition <= openPosition
			then deenergized;
	}
	
	part def ElectromagneticRelay {
		doc /* 
		 * An electromagnetic relay is an electrically operated switch that uses an electromagnet 
		 * to mechanically operate switching contacts. When current flows through the coil, 
		 * it generates a magnetic field that attracts a movable armature, which in turn 
		 * opens or closes electrical contacts to control a separate circuit.
		 */
		
		attribute activationVoltage :> ISQ::voltage;
		attribute dropoutVoltage :> ISQ::voltage;
		attribute nominalCoilVoltage :> ISQ::voltage;
		attribute coilPower :> ISQ::power;
		attribute switchingCapacity :> ISQ::power;
		attribute operatingTime :> ISQ::time;
		attribute releaseTime :> ISQ::time;
		
		port coilControl : ControlPort;
		port commonTerminal : PowerPort;
		port normallyOpenTerminal : PowerPort;
		port normallyClosedTerminal : PowerPort;
		
		part coil : ElectromagneticCoil {
			attribute numberOfTurns = 2000;
			attribute resistance = 400.0 [SI::'Ω'];
			attribute inductance = 0.5 [SI::H];
			attribute corePermeability = 2000.0;
		}
		
		part armature : Armature {
			attribute mass = 0.005 [SI::kg];
			attribute position = "open";
			attribute springConstant = 500.0;
		}
		
		part contacts : ContactSet {
			attribute material = "Silver Alloy";
			attribute contactResistance = 0.05 [SI::'Ω'];
			attribute maxCurrent = 10.0 [SI::A];
			attribute maxVoltage = 250.0 [SI::V];
		}
		
		part spring : ReturnSpring {
			attribute springConstant = 500.0;
			attribute preloadForce = 0.5 [SI::N];
			attribute compressionLength = 0.002 [SI::m];
		}
		
		connection magneticCoupling connect coil.magneticOutput to armature.magneticInput;
		connection controlConnection connect coilControl to coil.controlInput;
		connection powerConnection connect commonTerminal to contacts.loadInput;
	}
	
	action def RelayOperationCycle {
		in controlVoltage : ISQ::VoltageValue;
		in controlCurrent : ISQ::ElectricCurrentValue;
		in coilTurns : Real;
		in coilResistance : ISQ::ResistanceValue;
		in corePermeability : ISQ::PermeabilityValue;
		in armatureMass : ISQ::MassValue;
		in springConstant : Real;
		in activationThreshold : ISQ::VoltageValue;
		in dropoutThreshold : ISQ::VoltageValue;
		out contactsClosed : Boolean;
		out magneticForceGenerated : ISQ::ForceValue;
		out armatureFinalPosition : ISQ::LengthValue;
		
		first start;
		then action generateField : GenerateMagneticField {
			in coilCurrent = RelayOperationCycle::controlCurrent;
			in coilTurns = RelayOperationCycle::coilTurns;
			in corePermeability = RelayOperationCycle::corePermeability;
			out magneticFluxDensity;
			out magneticForce;
		}
		then action moveArmature : MoveArmature {
			in appliedForce = generateField.magneticForce;
			in springForce = RelayOperationCycle::springConstant * 0.002 [SI::m];
			in armatureMass = RelayOperationCycle::armatureMass;
			out armaturePosition;
			out armatureVelocity;
		}
		then action switchContacts : SwitchContacts {
			in armaturePosition = moveArmature.armaturePosition;
			in thresholdPosition = 0.001 [SI::m];
			out contactState;
		}
		then assign contactsClosed := switchContacts.contactState;
		then assign magneticForceGenerated := generateField.magneticForce;
		then assign armatureFinalPosition := moveArmature.armaturePosition;
		then done;
	}
	
	part relaySystem : ElectromagneticRelay {
		attribute activationVoltage = 18.0 [SI::V];
		attribute dropoutVoltage = 6.0 [SI::V];
		attribute nominalCoilVoltage = 24.0 [SI::V];
		attribute coilPower = 1.44 [SI::W];
		attribute switchingCapacity = 2500.0 [SI::W];
		attribute operatingTime = 0.010 [SI::s];
		attribute releaseTime = 0.005 [SI::s];
		
		perform action operationCycle[*] ordered {
			first start;
			then merge continuousOperation;
			then action executeOperation : RelayOperationCycle {
				in controlVoltage = 24.0 [SI::V];
				in controlCurrent = 0.06 [SI::A];
				in coilTurns = 2000.0;
				in coilResistance = 400.0 [SI::'Ω'];
				in corePermeability = 2000.0;
				in armatureMass = 0.005 [SI::kg];
				in springConstant = 500.0;
				in activationThreshold = 18.0 [SI::V];
				in dropoutThreshold = 6.0 [SI::V];
				out contactsClosed;
				out magneticForceGenerated;
				out armatureFinalPosition;
			}
			then decide;
				if executeOperation.contactsClosed then maintainClosed;
				if not executeOperation.contactsClosed then continuousOperation;
			action maintainClosed;
			then continuousOperation;
		}
	}
	
	requirement def ActivationRequirement {
		doc /* The relay shall reliably activate when the coil voltage reaches the specified activation threshold. */
		subject relay : ElectromagneticRelay;
		require constraint {
			relay.activationVoltage <= relay.nominalCoilVoltage * 0.75
		}
	}
	
	requirement def ContactRatingRequirement {
		doc /* The relay contacts shall safely switch loads up to the specified current and voltage ratings. */
		subject relay : ElectromagneticRelay;
		require constraint {
			relay.contacts.maxCurrent >= 10.0 [SI::A] and
			relay.contacts.maxVoltage >= 250.0 [SI::V]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The relay shall operate within the specified time limits for both activation and release. */
		subject relay : ElectromagneticRelay;
		require constraint {
			relay.operatingTime <= 0.015 [SI::s] and
			relay.releaseTime <= 0.010 [SI::s]
		}
	}
	
	requirement def MagneticEfficiencyRequirement {
		doc /* The electromagnetic coil shall generate sufficient magnetic force to overcome spring tension with minimal power consumption. */
		subject relay : ElectromagneticRelay;
		require constraint {
			relay.coilPower <= 2.0 [SI::W]
		}
	}
	
	requirement def IsolationRequirement {
		doc /* The relay shall provide electrical isolation between the control circuit and the switched load circuit. */
		subject relay : ElectromagneticRelay;
	}
	
	requirement <'EMR-001'> electromagneticRelaySystemRequirements {
		doc /* 
		 * The electromagnetic relay system shall provide reliable, electrically-isolated switching 
		 * of electrical loads through electromagnetic actuation, meeting all performance, safety, 
		 * and operational requirements.
		 */
		subject system : ElectromagneticRelay;
		
		assume constraint controlPowerAvailable {
			doc /* A suitable DC control voltage source is available. */
		}
		
		require activation : ActivationRequirement {
			subject relay = system;
		}
		
		require contactRating : ContactRatingRequirement {
			subject relay = system;
		}
		
		require responseTime : ResponseTimeRequirement {
			subject relay = system;
		}
		
		require magneticEfficiency : MagneticEfficiencyRequirement {
			subject relay = system;
		}
		
		require isolation : IsolationRequirement {
			subject relay = system;
		}
	}
}
