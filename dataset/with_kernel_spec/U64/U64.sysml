package 'Gait Belt System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		enum def MobilityLevel { independent; supervised; assisted; dependent; }
		enum def StabilityState { stable; wobbling; falling; grounded; }

		port def GripPort {
			in gripForce : Real;
		}
		port def ForcePort {
			out appliedForce : Real;
			in reactionForce : Real;
		}
		port def StabilityPort {
			out stability : StabilityState;
			out fatigueIndex : Real;
		}

		part def GaitBelt {
			attribute material : String = "Reinforced Nylon Webbing";
			attribute maxLoad : Real = 250 [SI::kg];
			attribute width : Real = 5 [SI::cm];
			port gripInterface : GripPort;
			port forceInterface : ForcePort;
			part buckle : QuickReleaseBuckle;
			part handles : GripHandle [0..2];
		}

		part def QuickReleaseBuckle {
			attribute material : String = "Metal";
			attribute type : String = "Quick-release";
		}

		part def GripHandle {
			attribute material : String = "Non-slip";
		}

		state def PatientBalanceStates {
			entry; then stable;
			state stable;
			accept 'wobble' then wobbling;
			state wobbling;
			accept 'stabilized' then stable;
			accept 'fall imminent' then falling;
			state falling;
			accept 'guided down' then grounded;
			state grounded;
			accept 'recovered' then stable;
		}

		part def Patient {
			attribute mass : Real;
			attribute mobility : MobilityLevel;
			port forceInput : ForcePort;
			port stabilityOutput : StabilityPort;
			exhibit state 'balance states' : PatientBalanceStates;
		}

		part def Caregiver {
			port gripOutput : GripPort;
			port stabilityInput : StabilityPort;
		}

		part def SupportSurface;
		part def Environment {
			part floor : SupportSurface;
			part chair : SupportSurface;
			part bed : SupportSurface;
		}

		action def AssessMobility {
			in patient : Patient;
			out level : MobilityLevel;
			out assistanceNeeded : Boolean;
		}

		action def ApplyBelt {
			in patient : Patient;
			in belt : GaitBelt;
			out clearance : Real;
		}

		action def EstablishGrip {
			in belt : GaitBelt;
			in caregiver : Caregiver;
			out gripEstablished : Boolean;
		}

		action def MonitorPatient {
			in patient : Patient;
			out stability : StabilityState;
			out fatigueIndex : Real;
		}

		action def ProvideSupport {
			in patient : Patient;
			in belt : GaitBelt;
			out liftForce : Real;
			out counterbalanceForce : Real;
		}

		action def IncreaseStabilization {
			in belt : GaitBelt;
			out stabilizingForce : Real;
		}

		action def GuideDescent {
			in patient : Patient;
			in belt : GaitBelt;
			in targetSurface : SupportSurface;
			out descentControlled : Boolean;
		}

		action def RemoveBelt {
			in patient : Patient;
			in belt : GaitBelt;
		}

		action def GaitBeltProcedure {
			in patient : Patient;
			in belt : GaitBelt;
			in caregiver : Caregiver;
			in surface : SupportSurface;

			first start;
			then action assess : AssessMobility {
				in :>> patient;
				out :>> level;
				out :>> assistanceNeeded;
			}
			then action apply : ApplyBelt {
				in :>> patient;
				in :>> belt;
				out :>> clearance;
			}
			then action grip : EstablishGrip {
				in :>> belt;
				in :>> caregiver;
				out :>> gripEstablished;
			}
			then merge supportLoop;
			then action monitor : MonitorPatient {
				in :>> patient;
				out :>> stability;
				out :>> fatigueIndex;
			}
			then action support : ProvideSupport {
				in :>> patient;
				in :>> belt;
				out :>> liftForce;
				out :>> counterbalanceForce;
			}
			then decide;
				if monitor.stability == StabilityState::wobbling then stabilize;
				if monitor.stability == StabilityState::falling then guide;
				if monitor.stability == StabilityState::stable and monitor.fatigueIndex >= 0.8 then remove;
				if monitor.stability == StabilityState::stable and monitor.fatigueIndex < 0.8 then supportLoop;
			action stabilize : IncreaseStabilization {
				in :>> belt;
				out :>> stabilizingForce;
			}
			then supportLoop;
			action guide : GuideDescent {
				in :>> patient;
				in :>> belt;
				in :>> surface;
				out :>> descentControlled;
			}
			then remove;
			action remove : RemoveBelt {
				in :>> patient;
				in :>> belt;
			}
			then done;
		}

		requirement def FallPreventionRequirement {
			doc /* The system shall prevent uncontrolled falls by guiding the patient to a safe surface when loss of balance is detected. */
		}

		requirement def ProperFitRequirement {
			doc /* The belt shall be applied with a snug fit allowing two fingers (10-20 mm) to slip underneath. */
			attribute minClearance : Real = 10 [SI::mm];
			attribute maxClearance : Real = 20 [SI::mm];
		}

		requirement def MaterialStrengthRequirement {
			doc /* The belt shall be made of reinforced nylon webbing and withstand a static load of at least 250 kg. */
			attribute minLoadCapacity : Real = 250 [SI::kg];
		}

		requirement def ErgonomicRequirement {
			doc /* The belt shall provide non-slip handles to ensure a secure grip and reduce caregiver strain. */
		}
	}

	package Usages {
		private import Definitions::*;

		part gaitBelt : GaitBelt {
			part buckle : QuickReleaseBuckle;
			part handles : GripHandle [2];
			perform action procedure : GaitBeltProcedure;
		}

		part patient : Patient {
			:>> mass = 75 [SI::kg];
			:>> mobility = MobilityLevel::assisted;
		}

		part caregiver : Caregiver;
		part environment : Environment;

		connect caregiver.gripOutput to gaitBelt.gripInterface;
		connect gaitBelt.forceInterface to patient.forceInput;
		connect patient.stabilityOutput to caregiver.stabilityInput;

		requirement fallPrevention : FallPreventionRequirement {
			subject gaitBelt;
		}
		requirement properFit : ProperFitRequirement {
			subject gaitBelt;
		}
		requirement materialStrength : MaterialStrengthRequirement {
			subject gaitBelt;
		}
		requirement ergonomic : ErgonomicRequirement {
			subject gaitBelt;
		}
	}

	package UseCases {
		private import Definitions::*;

		use case 'assess mobility' {
			subject patient : Patient;
			actor caregiver : Caregiver;
		}

		use case 'apply belt' {
			subject patient : Patient;
			subject belt : GaitBelt;
			actor caregiver : Caregiver;
		}

		use case 'establish grip' {
			subject belt : GaitBelt;
			actor caregiver : Caregiver;
		}

		use case 'transfer and stabilize' {
			subject patient : Patient;
			subject belt : GaitBelt;
			actor caregiver : Caregiver;
			actor environment : Environment;
		}

		use case 'remove belt' {
			subject patient : Patient;
			subject belt : GaitBelt;
			actor caregiver : Caregiver;
		}

		use case 'safe patient transfer' {
			subject patient : Patient;
			subject belt : GaitBelt;
			actor caregiver : Caregiver;
			actor environment : Environment;

			objective {
				doc
				/* Safely transfer a patient using the gait belt, preventing falls
				 * and minimizing injury risk to both patient and caregiver. */
			}

			first start;
			then include 'assess mobility';
			then include 'apply belt';
			then include 'establish grip';
			then include 'transfer and stabilize';
			then include 'remove belt';
			then done;
		}
	}

	package Verification {
		private import Definitions::*;
		private import Usages::*;

		individual def TestPatient :> Patient {
			:>> mass = 80 [SI::kg];
			:>> mobility = MobilityLevel::assisted;
		}

		individual def TestCaregiver :> Caregiver;

		individual def TestGaitBelt :> GaitBelt {
			:>> material = "Reinforced Nylon Webbing";
			:>> maxLoad = 250 [SI::kg];
			:>> width = 5 [SI::cm];
		}

		individual testBelt : TestGaitBelt {
			part buckle : QuickReleaseBuckle;
			part handles : GripHandle [2];
		}

		individual testPatient1 : TestPatient;
		individual testCaregiver1 : TestCaregiver;

		verification normalTransferTest : 'safe patient transfer' {
			subject patient :> testPatient1;
			subject belt :> testBelt;
			actor caregiver :> testCaregiver1;
			actor environment :> environment;
		}
	}
}
