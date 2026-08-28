package 'Patient Transfer Board System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	private import ISQ::*;
	private import SI::*;

	package 'Definitions' {
		part def TransferBoard {
			attribute length: LengthValue;
			attribute width: LengthValue;
			attribute thickness: LengthValue;
			attribute maxWeightCapacity: MassValue;
			attribute topFrictionCoefficient: Real;
			attribute bottomFrictionCoefficient: Real;
			port topSurfacePort: SurfacePort;
			port bottomSurfacePort: SurfacePort;
		}

		part def SupportSurface {
			attribute surfaceFriction: Real;
			attribute surfaceHeight: LengthValue;
			port surfacePort: SurfacePort;
		}

		part def Bed specializes SupportSurface;
		part def Stretcher specializes SupportSurface;

		part def Patient {
			attribute weight: MassValue;
			attribute patientName: String;
		}

		part def Caregiver;

		port def SurfacePort {
			attribute frictionCoefficient: Real;
		}

		interface def BoardToSurfaceInterface {
			end boardSurface: SurfacePort;
			end supportSurface: SurfacePort;
		}

		attribute def PositionBoardSignal;
		attribute def SecureBoardSignal;
		attribute def VerifyWeightSignal;
		attribute def WeightOkSignal;
		attribute def WeightExceededSignal;
		attribute def CompleteTransferSignal;
		attribute def RemoveBoardSignal;

		action def PositionBoard;
		action def SecureBoard;
		action def VerifyWeight {
			in patientWeight: MassValue;
			in boardCapacity: MassValue;
			out weightVerified: Boolean;
		}
		action def SlidePatient;
		action def RemoveBoard;

		action def TransferProcess {
			action positionBoard: PositionBoard;
			action secureBoard: SecureBoard;
			action verifyWeight: VerifyWeight;
			action slidePatient: SlidePatient;
			action removeBoard: RemoveBoard;
			first positionBoard;
			then secureBoard;
			then verifyWeight;
			then slidePatient;
			then removeBoard;
		}

		state def TransferProcessStates {
			entry; then idle;
			state idle;
			transition idle_to_positioning
				first idle
				accept PositionBoardSignal
				then positioning;
			state positioning;
			transition positioning_to_secured
				first positioning
				accept SecureBoardSignal
				then secured;
			state secured;
			transition secured_to_verifying
				first secured
				accept VerifyWeightSignal
				then verifying;
			state verifying;
			transition verifying_to_transferring
				first verifying
				accept WeightOkSignal
				then transferring;
			transition verifying_to_secured
				first verifying
				accept WeightExceededSignal
				then secured;
			state transferring;
			transition transferring_to_removing
				first transferring
				accept CompleteTransferSignal
				then removing;
			state removing;
			transition removing_to_idle
				first removing
				accept RemoveBoardSignal
				then idle;
		}
	}

	public import 'Definitions'::*;

	package 'Requirements' {
		public import 'Definitions'::*;

		requirement def WeightLimitRequirement {
			doc /* The patient's weight shall be less than or equal to the board's maximum weight capacity. */
			subject board : TransferBoard;
			attribute patientWeight : MassValue;
			attribute boardCapacity : MassValue;
			require constraint {
				patientWeight <= boardCapacity
			}
		}

		requirement def SurfaceFrictionRequirement {
			doc /* The board's top surface friction coefficient shall be lower than the bottom surface friction coefficient. */
			subject board : TransferBoard;
			require constraint {
				board.topFrictionCoefficient < board.bottomFrictionCoefficient
			}
		}

		requirement def TransferSequenceRequirement {
			doc /* The transfer process shall follow the sequence: idle, positioning, secured, verifying, transferring, removing, and back to idle. */
			subject process : TransferProcessStates;
		}

		requirement def BoardDimensionRequirement {
			doc /* The board shall have a length sufficient to bridge the gap between two support surfaces. */
			subject board : TransferBoard;
			attribute minLength : LengthValue = 150 [cm];
			require constraint {
				board.length >= minLength
			}
		}
	}

	package 'Usages' {
		public import 'Definitions'::*;
		public import 'Requirements'::*;

		part transferSystem {
			part board : TransferBoard {
				attribute :>> length = 180 [cm];
				attribute :>> width = 40 [cm];
				attribute :>> thickness = 2 [cm];
				attribute :>> maxWeightCapacity = 200 [kg];
				attribute :>> topFrictionCoefficient = 0.05;
				attribute :>> bottomFrictionCoefficient = 0.8;
			}

			part originBed : Bed {
				attribute :>> surfaceFriction = 0.5;
				attribute :>> surfaceHeight = 75 [cm];
			}

			part destinationStretcher : Stretcher {
				attribute :>> surfaceFriction = 0.5;
				attribute :>> surfaceHeight = 75 [cm];
			}

			part patient : Patient {
				attribute :>> weight = 85 [kg];
				attribute :>> patientName = "Patient A";
			}

			part caregiver : Caregiver;

			interface boardToOrigin : BoardToSurfaceInterface
				connect board.bottomSurfacePort to originBed.surfacePort;

			interface boardToDestination : BoardToSurfaceInterface
				connect board.bottomSurfacePort to destinationStretcher.surfacePort;

			perform action transferProcess : TransferProcess;

			state transferStateMachine : TransferProcessStates;
		}

		requirement weightCheck : WeightLimitRequirement {
			subject board :>> transferSystem.board;
			attribute :>> patientWeight = transferSystem.patient.weight;
			attribute :>> boardCapacity = transferSystem.board.maxWeightCapacity;
		}

		requirement boardSurfaceDesign : SurfaceFrictionRequirement {
			subject board :>> transferSystem.board;
		}

		requirement transferLifecycle : TransferSequenceRequirement {
			subject process :>> transferSystem.transferStateMachine;
		}

		requirement boardSize : BoardDimensionRequirement {
			subject board :>> transferSystem.board;
		}
	}
}
