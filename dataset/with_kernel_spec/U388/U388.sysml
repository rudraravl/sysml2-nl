package 'Two-Piece Ostomy Appliance' {
	doc /* Model of a two-piece ostomy appliance system inspired by nurse Elise Sørensen. */
	private import ISQ::*;
	private import ScalarValues::*;

	flowRate = volume / time;

	attribute def WasteEntrySignal;
	attribute def NearCapacitySignal;
	attribute def CapacityThresholdSignal;
	attribute def EmptyPouchSignal;
	attribute def ReplacePouchSignal;
	attribute def OpenValveSignal;
	attribute def CloseValveSignal;
	attribute def LockSignal;
	attribute def UnlockSignal;

	port def CouplingPort;
	port def FilterPort;
	port def DrainPort;

	state def CouplingState;
	state def ValveState;
	state def ApplianceState;

	part def AdhesiveBaseplate {
		attribute adhesionStrength :> pressure;
		attribute centralOpeningDiameter :> length;
		attribute wearDuration :> time;

		part adhesiveLayer;
		part stomaOpening;

		port couplingPort : CouplingPort;

		action applyToSkin;
		action removeFromSkin;
	}

	part def CouplingRing {
		attribute isLocked : Boolean;
		attribute engagementTorque :> torque;

		port baseplateSide : CouplingPort;
		port pouchSide : CouplingPort;

		action twistLock;
		action twistUnlock;

		state couplingState : CouplingState {
			entry; then disengaged;
			state disengaged;
			accept LockSignal then engaged;
			state engaged;
			accept UnlockSignal then disengaged;
		}
	}

	part def CharcoalFilter {
		attribute gasFlowRate :> flowRate;
		attribute odorNeutralizationEfficiency : ScalarValues::Real;

		port filterPort : FilterPort;

		action ventGas;
		action neutralizeOdor;
	}

	part def DrainValve {
		attribute isOpen : Boolean;

		port drainPort : DrainPort;

		action open;
		action close;
		action drainContents;

		state valveState : ValveState {
			entry; then closed;
			state closed;
			accept OpenValveSignal then open;
			state open;
			accept CloseValveSignal then closed;
		}
	}

	part def OdorBarrierFilm {
		attribute thickness :> length;
		attribute odorBarrierRating : ScalarValues::Real;
	}

	part def CollectionPouch {
		attribute maxCapacity :> volume;
		attribute currentVolume :> volume;

		part film : OdorBarrierFilm;
		part charcoalFilter : CharcoalFilter;
		part drainValve : DrainValve;

		port couplingPort : CouplingPort;
		port filterPort : FilterPort;
		port drainPort : DrainPort;

		connect filterPort to charcoalFilter.filterPort;
		connect drainPort to drainValve.drainPort;

		action fillPouch;
		action emptyPouch;
	}

	part def OstomyAppliance {
		part baseplate : AdhesiveBaseplate;
		part couplingRing : CouplingRing;
		part pouch : CollectionPouch;

		connect baseplate.couplingPort to couplingRing.baseplateSide;
		connect couplingRing.pouchSide to pouch.couplingPort;

		state applianceState : ApplianceState {
			entry; then Sealed;
			state Sealed;
			accept WasteEntrySignal then Collecting;
			state Collecting;
			accept NearCapacitySignal then NearCapacity;
			state NearCapacity;
			accept CapacityThresholdSignal then RequiresChange;
			state RequiresChange;
			accept EmptyPouchSignal then Collecting;
			accept ReplacePouchSignal then Sealed;
		}

		action attachPouch;
		action detachPouch;
		action drainPouch;
		action replacePouch;
	}

	requirement def LeakProofSeal {
		doc /* Create a reliable, leak-proof seal around the stoma for several days. */
		subject baseplate : AdhesiveBaseplate;
	}

	requirement def SecureCoupling {
		doc /* Prevent accidental detachment while allowing intentional removal. */
		subject couplingRing : CouplingRing;
	}

	requirement def OdorControl {
		doc /* Neutralize odor molecules and prevent pouch ballooning. */
		subject pouch : CollectionPouch;
	}

	requirement def DrainConvenience {
		doc /* Allow emptying contents without detaching the baseplate. */
		subject pouch : CollectionPouch;
	}

	requirement def SkinProtection {
		doc /* Minimize skin irritation by avoiding frequent baseplate removal. */
		subject appliance : OstomyAppliance;
	}

	requirement def DiscreetWear {
		doc /* Be lightweight, secure, and discreet under clothing. */
		subject appliance : OstomyAppliance;
	}

	part appliance : OstomyAppliance;
}
