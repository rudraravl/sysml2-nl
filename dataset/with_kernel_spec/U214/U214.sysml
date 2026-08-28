package TourniquetSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		private import ScalarValues::*;

		attribute def PressureValue :> Real;
		attribute def TensionValue :> Real;
		attribute def TimeValue :> Real;

		attribute def DeploySignal;
		attribute def StrapSecuredSignal;
		attribute def RotateWindlassSignal;
		attribute def BleedingCheckSignal;
		attribute def BleedingStoppedSignal;
		attribute def BleedingContinuesSignal;
		attribute def LockWindlassSignal;
		attribute def RemoveSignal;
		attribute def OverPressureAlert;

		item def Limb;

		part def PressurePad {
			attribute contactArea : Real;
			port pressurePort {
				out appliedPressure : PressureValue;
			}
			perform action distributeForce : DistributeForce;
		}

		part def Strap {
			attribute length : Real;
			attribute material : String = "high-strength nylon";
			port tensionPort {
				in strapTension : TensionValue;
			}
			port padInterface {
				in padPressure : PressureValue;
			}
		}

		part def Windlass {
			attribute rodLength : Real;
			attribute rotationCount : Integer = 0;
			port windlassPort {
				out windlassTension : TensionValue;
			}
			perform action rotate : RotateWindlass;
		}

		part def SecuringClip {
			attribute isLocked : Boolean = false;
			port clipPort {
				in lockCommand : LockWindlassSignal;
			}
			perform action lock : LockWindlassAction;
		}

		action def RotateWindlass {
			in currentRotation : Integer;
			out tension : TensionValue;
		}

		action def CheckBleeding {
			out bleedingStopped : Boolean;
		}

		action def PositionOnLimb;
		action def SecureStrap;
		action def LockWindlassAction;
		action def NoteApplicationTime {
			out applicationTime : TimeValue;
		}
		action def DistributeForce {
			in force : TensionValue;
			out pressure : PressureValue;
		}

		action def ApplyTourniquet {
			action positionOnLimb : PositionOnLimb;
			action secureStrap : SecureStrap;
			action rotateWindlass : RotateWindlass;
			action checkBleeding : CheckBleeding;
			action lockWindlass : LockWindlassAction;
			action noteApplicationTime : NoteApplicationTime;
		}

		state def TourniquetStates;

		part def Tourniquet {
			attribute minOcclusionPressure : PressureValue = 250;
			attribute maxSafePressure : PressureValue = 450;
			attribute isSingleUse : Boolean = true;
			attribute applicationTimeRecorded : TimeValue;
			attribute currentPressure : PressureValue;

			part strap : Strap;
			part windlass : Windlass;
			part securingClip : SecuringClip;
			part pressurePad : PressurePad;

			flow windlassTensionFlow of TensionValue
				from windlass.windlassPort.windlassTension to strap.tensionPort.strapTension;
			flow padPressureFlow of PressureValue
				from pressurePad.pressurePort.appliedPressure to strap.padInterface.padPressure;

			port deploymentPort {
				in deploy : DeploySignal;
				in strapSecured : StrapSecuredSignal;
				in rotateWindlassSig : RotateWindlassSignal;
				in bleedingCheck : BleedingCheckSignal;
				in lockWindlassSig : LockWindlassSignal;
				in remove : RemoveSignal;
				out bleedingStopped : BleedingStoppedSignal;
				out bleedingContinues : BleedingContinuesSignal;
				out overPressure : OverPressureAlert;
				out applicationTime : TimeValue;
			}

			exhibit state tourniquetStates : TourniquetStates;
			perform action applyTourniquet : ApplyTourniquet;
		}

		part def User {
			port commandPort {
				out deploy : DeploySignal;
				out strapSecured : StrapSecuredSignal;
				out rotateWindlassSig : RotateWindlassSignal;
				out bleedingCheck : BleedingCheckSignal;
				out lockWindlassSig : LockWindlassSignal;
				out remove : RemoveSignal;
				in bleedingStopped : BleedingStoppedSignal;
				in bleedingContinues : BleedingContinuesSignal;
				in overPressure : OverPressureAlert;
				in applicationTime : TimeValue;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		action 'position on limb' : PositionOnLimb;
		action 'secure strap' : SecureStrap;
		action 'rotate windlass' : RotateWindlass;
		action 'check bleeding' : CheckBleeding;
		action 'lock windlass' : LockWindlassAction;
		action 'note application time' : NoteApplicationTime;
		action 'distribute force' : DistributeForce;

		part tourniquet : Tourniquet;
		part user : User;
		part limb : Limb;

		interface userToTourniquetInterface connect user.commandPort to tourniquet.deploymentPort {
			flow deployFlow of DeploySignal
				from user.commandPort.deploy to tourniquet.deploymentPort.deploy;
			flow strapSecuredFlow of StrapSecuredSignal
				from user.commandPort.strapSecured to tourniquet.deploymentPort.strapSecured;
			flow rotateWindlassFlow of RotateWindlassSignal
				from user.commandPort.rotateWindlassSig to tourniquet.deploymentPort.rotateWindlassSig;
			flow bleedingCheckFlow of BleedingCheckSignal
				from user.commandPort.bleedingCheck to tourniquet.deploymentPort.bleedingCheck;
			flow lockWindlassFlow of LockWindlassSignal
				from user.commandPort.lockWindlassSig to tourniquet.deploymentPort.lockWindlassSig;
			flow removeFlow of RemoveSignal
				from user.commandPort.remove to tourniquet.deploymentPort.remove;
			flow bleedingStoppedFlow of BleedingStoppedSignal
				from tourniquet.deploymentPort.bleedingStopped to user.commandPort.bleedingStopped;
			flow bleedingContinuesFlow of BleedingContinuesSignal
				from tourniquet.deploymentPort.bleedingContinues to user.commandPort.bleedingContinues;
			flow overPressureFlow of OverPressureAlert
				from tourniquet.deploymentPort.overPressure to user.commandPort.overPressure;
			flow applicationTimeFlow of TimeValue
				from tourniquet.deploymentPort.applicationTime to user.commandPort.applicationTime;
		}

		state tourniquetStates : TourniquetStates parallel {
			state operationalStates {
				entry; then stowed;

				state stowed;
				accept DeploySignal
					then positioning;

				state positioning {
					entry 'position on limb';
					do 'secure strap';
				}
				accept StrapSecuredSignal
					then tightening;

				state tightening {
					do 'rotate windlass';
				}
				accept BleedingCheckSignal
					then monitoring;

				state monitoring {
					entry 'check bleeding';
				}
				accept BleedingContinuesSignal
					then tightening;
				accept BleedingStoppedSignal
					then secured;

				state secured {
					entry 'lock windlass';
					do 'note application time';
				}
				accept RemoveSignal
					then done;
			}

			state pressureStates {
				entry; then pressureIdle;

				state pressureIdle;
				accept DeploySignal
					then pressureSensing;

				state pressureSensing {
					do 'distribute force';
				}
				accept when tourniquet.currentPressure > tourniquet.maxSafePressure
					do send new OverPressureAlert() to user
					then overPressureState;

				state overPressureState;
				accept RotateWindlassSignal
					then pressureSensing;
			}
		}

		action applyTourniquet : ApplyTourniquet {
			action positionOnLimb : PositionOnLimb;
			action secureStrap : SecureStrap;
			action rotateWindlass : RotateWindlass;
			action checkBleeding : CheckBleeding;
			action lockWindlass : LockWindlassAction;
			action noteApplicationTime : NoteApplicationTime;
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def OccludeArterialFlow {
			subject tourniquet : Tourniquet;
			doc /* The tourniquet shall completely occlude arterial blood flow when properly applied to a limb. */;
		}

		requirement def PressureRangeRequirement {
			subject tourniquet : Tourniquet;
			attribute minPressure : PressureValue = 250;
			attribute maxPressure : PressureValue = 450;
			doc /* The tourniquet shall apply circumferential pressure between 250 and 450 mmHg to occlude arterial flow while minimizing tissue damage. */;
		}

		requirement def OneHandedApplication {
			subject tourniquet : Tourniquet;
			doc /* The tourniquet shall be designed for fast, intuitive, one-handed application. */;
		}

		requirement def HoldTensionRequirement {
			subject tourniquet : Tourniquet;
			doc /* The securing clip shall hold windlass tension firmly without slipping for an extended period. */;
		}

		requirement def SingleUseRequirement {
			subject tourniquet : Tourniquet;
			doc /* The tourniquet shall be a reliable, single-use, life-saving tool for first responders and individuals in emergency settings. */;
		}

		requirement def RapidDeployment {
			subject tourniquet : Tourniquet;
			doc /* The tourniquet shall be stowed and ready for rapid deployment in trauma situations. */;
		}

		requirement tourniquetRequirements {
			requirement occludeArterialFlow : OccludeArterialFlow;
			requirement pressureRange : PressureRangeRequirement;
			requirement oneHandedApplication : OneHandedApplication;
			requirement holdTension : HoldTensionRequirement;
			requirement singleUse : SingleUseRequirement;
			requirement rapidDeployment : RapidDeployment;
		}
	}
}
