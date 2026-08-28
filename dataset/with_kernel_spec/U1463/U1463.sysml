package 'Pantograph Power Collection System' {
	doc
	/*
	 * Model of a pantograph power collection system for an electric rail vehicle.
	 * Collects high-voltage power (25 kV) from an overhead catenary wire
	 * and routes it to the vehicle's internal power bus.
	 */

	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;

	/* --- Signal Definitions --- */
	attribute def RaiseSignal;
	attribute def LowerSignal;
	attribute def EmergencyLowerSignal;
	attribute def ContactEstablishedSignal;
	attribute def ContactLostSignal;
	attribute def StowedSignal;

	/* --- Item Definitions --- */
	item def ElectricPower {
		attribute voltage :> ISQ::electricPotentialDifference = 25000 [V];
		attribute current :> ISQ::electricCurrent;
	}

	item def CompressedAir {
		attribute pressure :> ISQ::pressure;
	}

	/* --- Port Definitions --- */
	port def OverheadWirePort {
		out item power : ElectricPower;
		attribute wireHeight :> ISQ::length;
	}

	port def CollectorContactPort {
		in item power : ElectricPower;
		attribute contactForce :> ISQ::force;
	}

	port def PantographOutputPort {
		out item tractionPower : ElectricPower;
	}

	port def PowerBusPort {
		in item tractionPower : ElectricPower;
	}

	port def PneumaticSupplyPort {
		out item air : CompressedAir;
	}

	port def PneumaticInputPort {
		in item air : CompressedAir;
	}

	/* --- Part Definitions --- */
	part def CarbonContactStrip {
		attribute initialThickness :> ISQ::length = 10 [mm];
		attribute currentThickness :> ISQ::length;
		attribute wearLimit :> ISQ::length = 3 [mm];
	}

	part def CollectorHead {
		port contactPort : CollectorContactPort;
		port powerOutput : PantographOutputPort;
		part contactStrip : CarbonContactStrip;
		attribute headWidth :> ISQ::length;
	}

	part def LowerArm {
		attribute length :> ISQ::length;
	}

	part def UpperArm {
		attribute length :> ISQ::length;
	}

	part def PneumaticActuator {
		port airInput : PneumaticInputPort;
		attribute strokeForce :> ISQ::force;
		attribute isExtended : Boolean = false;
	}

	part def SpringAssembly {
		attribute nominalForce :> ISQ::force = 95 [N];
	}

	part def ArticulatedArm {
		part lowerArm : LowerArm;
		part upperArm : UpperArm;
		part actuator : PneumaticActuator;
		part spring : SpringAssembly;
	}

	part def Insulator {
		attribute dielectricStrength :> ISQ::electricPotentialDifference = 30000 [V];
		attribute height :> ISQ::length;
	}

	part def OverheadCatenaryWire {
		port wirePort : OverheadWirePort;
		attribute nominalVoltage :> ISQ::electricPotentialDifference = 25000 [V];
		attribute height :> ISQ::length;
	}

	part def VehiclePowerBus {
		port busPort : PowerBusPort;
	}

	part def PneumaticSupply {
		port supplyPort : PneumaticSupplyPort;
		attribute maxPressure :> ISQ::pressure;
	}

	/* --- State Machine Definition --- */
	state def PantographStates {
		entry; then stowed;

		state stowed {
			doc /* Pantograph fully retracted and locked down. */
		}

		transition stowed_to_raising
			first stowed
			accept RaiseSignal
			then raising;

		state raising {
			doc /* Pneumatic actuator extending; arms moving upward. */
		}

		transition raising_to_operational
			first raising
			accept ContactEstablishedSignal
			then operational;

		state operational {
			doc /* Fully raised; collecting power from overhead wire. */
		}

		transition operational_to_lowering
			first operational
			accept LowerSignal
			then lowering;

		state lowering {
			doc /* Arms retracting under pneumatic control. */
		}

		transition lowering_to_stowed
			first lowering
			accept StowedSignal
			then stowed;

		transition operational_to_fault
			first operational
			accept ContactLostSignal
			then fault;

		state fault {
			doc /* Contact with overhead wire lost unexpectedly. */
		}

		transition fault_to_emergencyLowering
			first fault
			accept EmergencyLowerSignal
			then emergencyLowering;

		transition operational_to_emergencyLowering
			first operational
			accept EmergencyLowerSignal
			then emergencyLowering;

		state emergencyLowering {
			doc /* Rapid emergency retraction of pantograph arms. */
		}

		transition emergencyLowering_to_stowed
			first emergencyLowering
			accept StowedSignal
			then stowed;
	}

	/* --- Pantograph Part Definition --- */
	part def Pantograph {
		port contactPort : CollectorContactPort;
		port outputPort : PantographOutputPort;

		attribute nominalVoltage :> ISQ::electricPotentialDifference = 25000 [V];
		attribute minContactForce :> ISQ::force = 70 [N];
		attribute maxContactForce :> ISQ::force = 120 [N];

		part insulator : Insulator;
		part arm : ArticulatedArm;
		part head : CollectorHead;

		connect head.contactPort to contactPort;
		connect head.powerOutput to outputPort;

		state pantographBehavior : PantographStates;
	}

	/* --- Interface Definitions --- */
	interface def WireContactInterface {
		doc /* Interface between overhead catenary wire and pantograph collector head. */
		end wire : OverheadWirePort;
		end collector : CollectorContactPort;
		flow wire.power to collector.power;
	}

	interface def PowerRoutingInterface {
		doc /* Interface routing collected power from pantograph to vehicle bus. */
		end pantographOutput : PantographOutputPort;
		end vehicleBus : PowerBusPort;
		flow pantographOutput.tractionPower to vehicleBus.tractionPower;
	}

	interface def PneumaticSupplyInterface {
		doc /* Interface for pneumatic air supply to actuator. */
		end supply : PneumaticSupplyPort;
		end actuatorInput : PneumaticInputPort;
		flow supply.air to actuatorInput.air;
	}

	/* --- Action Definitions --- */
	action def EmergencyLoweringSequence {
		in pantograph : Pantograph;
		action releaseActuatorPressure {
			doc /* Vent compressed air from pneumatic actuator. */
		}
		then action rapidlyRetractArms {
			doc /* Allow spring and gravity to rapidly lower arms. */
		}
		then action lockInStowedPosition {
			doc /* Engage mechanical lock to secure pantograph. */
		}
	}

	/* --- Requirement Definitions --- */
	requirement def ContactForceRequirement {
		doc /* The pantograph shall maintain a nominal contact force between 70 N and 120 N. */
		subject p : Pantograph;
		attribute minForce :> ISQ::force = 70 [N];
		attribute maxForce :> ISQ::force = 120 [N];
		require constraint {
			p.arm.spring.nominalForce >= minForce and
			p.arm.spring.nominalForce <= maxForce
		}
	}

	requirement def HighVoltageInsulationRequirement {
		doc /* The insulator shall prevent high-voltage leakage to the vehicle body. */
		subject p : Pantograph;
		attribute ratedVoltage :> ISQ::electricPotentialDifference = 25000 [V];
		require constraint {
			p.insulator.dielectricStrength >= ratedVoltage
		}
	}

	requirement def ContinuousPowerCollectionRequirement {
		doc /* The pantograph shall collect 25 kV power from the overhead catenary wire. */
		subject p : Pantograph;
		attribute nominalVoltage :> ISQ::electricPotentialDifference = 25000 [V];
		require constraint {
			p.nominalVoltage == nominalVoltage
		}
	}

	requirement def EmergencyLoweringTimeRequirement {
		doc /* The pantograph shall complete emergency lowering within 3 seconds. */
		attribute maxLoweringTime :> ISQ::time = 3 [s];
	}

	requirement def ContactStripWearRequirement {
		doc /* The carbon contact strip shall be replaced before wear limit is reached. */
		subject p : Pantograph;
		require constraint {
			p.head.contactStrip.currentThickness >= p.head.contactStrip.wearLimit
		}
	}

	/* --- Requirement Usages --- */
	requirement contactForceReq : ContactForceRequirement;
	requirement highVoltageInsulationReq : HighVoltageInsulationRequirement;
	requirement continuousPowerCollectionReq : ContinuousPowerCollectionRequirement;
	requirement emergencyLoweringTimeReq : EmergencyLoweringTimeRequirement;
	requirement contactStripWearReq : ContactStripWearRequirement;

	/* --- System Assembly --- */
	part pantographSystem : Pantograph {
		part overheadWire : OverheadCatenaryWire;
		part vehicleBus : VehiclePowerBus;
		part airSupply : PneumaticSupply;

		interface wireContact : WireContactInterface
			connect overheadWire.wirePort to contactPort;

		interface powerRouting : PowerRoutingInterface
			connect outputPort to vehicleBus.busPort;

		interface pneumaticFeed : PneumaticSupplyInterface
			connect airSupply.supplyPort to arm.actuator.airInput;

		satisfy contactForceReq by pantographSystem;
		satisfy highVoltageInsulationReq by pantographSystem;
		satisfy continuousPowerCollectionReq by pantographSystem;
		satisfy emergencyLoweringTimeReq by pantographSystem;
		satisfy contactStripWearReq by pantographSystem;
	}
}
