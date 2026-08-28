package FluidTransferSystem {
	import ScalarValues::*;
	import ISQ::*;
	import ISQ::MassPackage::*;
	import ISQ::VolumePackage::*;
	import ISQ::PressurePackage::*;
	import ISQ::TimePackage::*;

	// ---- Value Types ----
	value type PressureValue :> Real {
		unit Pa;
	}
	value type VolumeFlowRateValue :> Real {
		unit "m^3/s";
	}
	value type VolumeValue :> Real {
		unit "m^3";
	}
	value type DurationValue :> Real {
		unit s;
	}
	value type ForceValue :> Real {
		unit N;
	}

	item def Fluid {
		attribute density : Real = 1000 [kg/m^3];
		attribute viscosity : Real = 0.001 [Pa*s];
	}
	item def Water :> Fluid;
	item def CompressedAir {
		attribute pressure : PressureValue;
	}

	// ---- Port Definitions ----
	port def FluidPort {
		in item fluidIn : Fluid;
		out item fluidOut : Fluid;
		attribute flowRate : VolumeFlowRateValue;
	}
	port def AirPort {
		out item airOut : CompressedAir;
		attribute pressure : PressureValue;
	}

	// ---- Requirements ----
	requirement def MinFlowRateRequirement {
		doc /* The system shall deliver a minimum flow rate during operation. */
		attribute minFlowRate : VolumeFlowRateValue = 0.0001 ["m^3/s"];
		subject actualFlowRate : VolumeFlowRateValue;
		constraint { actualFlowRate >= minFlowRate }
	}
	requirement def MinPressureRequirement {
		doc /* The system shall achieve a minimum discharge pressure. */
		attribute minPressure : PressureValue = 50000 [Pa];
		subject actualPressure : PressureValue;
		constraint { actualPressure >= minPressure }
	}
	requirement def ReliabilityRequirement {
		doc /* The system shall operate continuously for at least two hours. */
		attribute minDuration : DurationValue = 7200 [s];
		subject operatingDuration : DurationValue;
		constraint { operatingDuration >= minDuration }
	}
	requirement def OneWayFlowRequirement {
		doc /* Check valves shall ensure fluid flows only in the intended direction. */
		subject inletValve : CheckValve;
		subject outletValve : CheckValve;
		constraint { inletValve.allowsForwardFlow == true and inletValve.allowsBackFlow == false }
		constraint { outletValve.allowsForwardFlow == true and outletValve.allowsBackFlow == false }
	}

	requirement SystemRequirements {
		requirement flowReq : MinFlowRateRequirement;
		requirement pressureReq : MinPressureRequirement;
		requirement reliabilityReq : ReliabilityRequirement;
		requirement oneWayFlowReq : OneWayFlowRequirement;
	}

	// ---- Check Valve ----
	part def CheckValve {
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		attribute allowsForwardFlow : Boolean = true;
		attribute allowsBackFlow : Boolean = false;
		attribute crackingPressure : PressureValue = 1000 [Pa];
		attribute currentPressure : PressureValue;
		attribute isOpen : Boolean;

		state def ValveBehavior {
			entry; then Closed;
			state Closed {
				entry { isOpen = false; }
				transition closed_to_open
					first Closed
					if currentPressure >= crackingPressure
					then Open;
			}
			state Open {
				entry { isOpen = true; }
				transition open_to_closed
					first Open
					if currentPressure < crackingPressure
					then Closed;
			}
		}
	}

	// ---- Source Reservoir ----
	part def SourceReservoir {
		port fluidOut : FluidPort;
		attribute fluidVolume : VolumeValue = 0.05 ["m^3"];
		attribute initialVolume : VolumeValue = 0.05 ["m^3"];
		item storedFluid : Water;

		action def SupplyFluid {
			in source : SourceReservoir;
			out fluid : Water;
			attribute suppliedVolume : VolumeValue;
		}
	}

	// ---- Destination Tank ----
	part def DestinationTank {
		port fluidIn : FluidPort;
		attribute fluidVolume : VolumeValue = 0.0 ["m^3"];
		attribute capacity : VolumeValue = 0.1 ["m^3"];
		item receivedFluid : Water;

		action def ReceiveFluid {
			in fluid : Water;
			in volume : VolumeValue;
			then { fluidVolume += volume; }
		}
	}

	// ---- Manual Bellows Unit ----
	part def ManualBellows {
		port airOut : AirPort;
		attribute maxAirPressure : PressureValue = 80000 [Pa];
		attribute currentAirPressure : PressureValue = 0 [Pa];
		attribute isCompressed : Boolean = false;
		attribute strokeVolume : VolumeValue = 0.002 ["m^3"];

		action def CompressBellows {
			in bellows : ManualBellows;
			attribute appliedForce : ForceValue;
			then {
				bellows.isCompressed = true;
				bellows.currentAirPressure = bellows.maxAirPressure;
			}
		}
		action def ExpandBellows {
			in bellows : ManualBellows;
			then {
				bellows.isCompressed = false;
				bellows.currentAirPressure = 0 [Pa];
			}
		}

		state def BellowsOperationState {
			entry; then Expanded;
			state Expanded {
				entry { isCompressed = false; currentAirPressure = 0 [Pa]; }
				transition expand_to_compress
					first Expanded
					if isCompressed == false
					then Compressed;
			}
			state Compressed {
				entry { isCompressed = true; currentAirPressure = maxAirPressure; }
				transition compress_to_expand
					first Compressed
					if isCompressed == true
					then Expanded;
			}
		}
	}

	// ---- Pressure Chamber ----
	part def PressureChamber {
		port airIn : AirPort;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		attribute chamberVolume : VolumeValue = 0.003 ["m^3"];
		attribute fluidVolume : VolumeValue = 0.0 ["m^3"];
		attribute airVolume : VolumeValue = 0.003 ["m^3"];
		attribute internalPressure : PressureValue = 101325 [Pa];
		attribute maxPressure : PressureValue = 100000 [Pa];
		item containedFluid : Water;
		item containedAir : CompressedAir;

		action def PressurizeFluid {
			in airPressure : PressureValue;
			then {
				internalPressure = airPressure;
			}
		}
	}

	// ---- Internal Supply Reservoir ----
	part def InternalSupplyReservoir {
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		attribute reservoirVolume : VolumeValue = 0.002 ["m^3"];
		attribute currentFluidVolume : VolumeValue = 0.0 ["m^3"];
		item storedFluid : Water;
	}

	// ---- Kearny Air Pump ----
	part def KearnyAirPump {
		port sourceFluidIn : FluidPort;
		port dischargeFluidOut : FluidPort;
		port airIn : AirPort;

		part pressureChamber : PressureChamber;
		part internalSupplyReservoir : InternalSupplyReservoir;
		part inletValve : CheckValve {
			attribute crackingPressure = 500 [Pa];
		}
		part outletValve : CheckValve {
			attribute crackingPressure = 2000 [Pa];
		}

		attribute cycleCount : Integer = 0;
		attribute currentPhase : String = "Idle";
		attribute measuredFlowRate : VolumeFlowRateValue = 0 ["m^3/s"];
		attribute measuredPressure : PressureValue = 101325 [Pa];
		attribute operatingTime : DurationValue = 0 [s];

		// Internal connections
		connection airConnection connect airIn to pressureChamber.airIn;
		connection fluidIntakeConnection connect sourceFluidIn to inletValve.fluidIn;
		connection inletToSupplyConnection connect inletValve.fluidOut to internalSupplyReservoir.fluidIn;
		connection supplyToChamberConnection connect internalSupplyReservoir.fluidOut to pressureChamber.fluidIn;
		connection chamberToOutletConnection connect pressureChamber.fluidOut to outletValve.fluidIn;
		connection outletToDischargeConnection connect outletValve.fluidOut to dischargeFluidOut;

		action def IntakeAction {
			in pump : KearnyAirPump;
			then {
				pump.currentPhase = "Intake";
				pump.inletValve.currentPressure = pump.pressureChamber.internalPressure;
				pump.outletValve.currentPressure = pump.pressureChamber.internalPressure;
			}
		}
		action def CompressionAction {
			in pump : KearnyAirPump;
			in airPressure : PressureValue;
			then {
				pump.currentPhase = "Compression";
				pump.pressureChamber.internalPressure = airPressure;
				pump.measuredPressure = airPressure;
			}
		}
		action def DischargeAction {
			in pump : KearnyAirPump;
			then {
				pump.currentPhase = "Discharge";
				pump.outletValve.currentPressure = pump.pressureChamber.internalPressure;
				pump.measuredFlowRate = 0.0002 ["m^3/s"];
			}
		}

		state def PumpCycleStateMachine {
			entry; then Intake;
			state Intake {
				entry { currentPhase = "Intake"; inletValve.currentPressure = pressureChamber.internalPressure; }
				transition intake_to_compression
					first Intake
					if pressureChamber.fluidVolume > 0 ["m^3"]
					then Compression;
			}
			state Compression {
				entry { currentPhase = "Compression"; pressureChamber.internalPressure = airIn.pressure; measuredPressure = pressureChamber.internalPressure; }
				transition compression_to_discharge
					first Compression
					if pressureChamber.internalPressure >= outletValve.crackingPressure
					then Discharge;
			}
			state Discharge {
				entry { currentPhase = "Discharge"; outletValve.currentPressure = pressureChamber.internalPressure; measuredFlowRate = 0.0002 ["m^3/s"]; cycleCount += 1; }
				transition discharge_to_intake
					first Discharge
					if pressureChamber.fluidVolume <= 0 ["m^3"]
					then Intake;
			}
		}
	}

	// ---- Human Operator ----
	part def HumanOperator {
		attribute name : String = "Operator";
		attribute appliedForce : ForceValue = 50 [N];
		attribute isOperating : Boolean = false;

		action def OperateBellows {
			in bellows : ManualBellows;
			in operator : HumanOperator;
			then {
				operator.isOperating = true;
				bellows.isCompressed = true;
				bellows.currentAirPressure = bellows.maxAirPressure;
			}
			then ReleaseBellows;
		}
		action def ReleaseBellows {
			in bellows : ManualBellows;
			then {
				bellows.isCompressed = false;
				bellows.currentAirPressure = 0 [Pa];
			}
		}
	}

	// ---- Top-level System ----
	part FluidTransferSystem {
		part operator : HumanOperator;
		part bellows : ManualBellows;
		part pump : KearnyAirPump;
		part source : SourceReservoir;
		part destination : DestinationTank;

		// System-level connections
		connection operatorToBellows connect operator to bellows;
		connection bellowsAirToPump connect bellows.airOut to pump.airIn;
		connection sourceToPump connect source.fluidOut to pump.sourceFluidIn;
		connection pumpToDestination connect pump.dischargeFluidOut to destination.fluidIn;

		attribute systemFlowRate : VolumeFlowRateValue = pump.measuredFlowRate;
		attribute systemPressure : PressureValue = pump.measuredPressure;
		attribute totalOperatingTime : DurationValue = pump.operatingTime;

		satisfy flowReq by systemFlowRate;
		satisfy pressureReq by systemPressure;
		satisfy reliabilityReq by totalOperatingTime;
		satisfy oneWayFlowReq by pump.inletValve, pump.outletValve;

		state def SystemOperationState {
			entry; then Idle;
			state Idle {
				entry { operator.isOperating = false; }
				transition idle_to_active
					first Idle
					if operator.isOperating == true
					then Active;
			}
			state Active {
				entry { operator.isOperating = true; }
				do { pump.PumpCycleStateMachine; }
				transition active_to_idle
					first Active
					if operator.isOperating == false
					then Idle;
			}
		}
	}
}
