package RadiationTherapySystem {
	public import Definitions::*;

	package Definitions {
		private import ScalarValues::*;

		attribute def Length :> Real;
		attribute def TreatmentPlan;
		attribute def PlanLoaded;
		attribute def BeamOn;
		attribute def TreatmentComplete;
		attribute def EmergencyStop;
		attribute def AllLeavesVerified;

		part def Leaf {
			attribute targetPosition : Length;
			attribute currentPosition : Length;
		}
		part def LeafMotor;
		part def PositionSensor;

		part def LeafBank {
			part leaf : Leaf[80];
			part motor : LeafMotor[80];
			part sensor : PositionSensor[80];
		}

		port def CommandPort;
		port def FeedbackPort;
		port def InterlockPort;
		port def BeamPort;

		part def Controller {
			port commandOut : CommandPort;
			port feedbackIn : ~FeedbackPort;
			attribute currentPlan : TreatmentPlan;
		}

		part def MultileafCollimator {
			port controllerCommand : ~CommandPort;
			port controllerFeedback : FeedbackPort;
			part bankA : LeafBank;
			part bankB : LeafBank;
		}

		part def RadiationSource {
			port beamOut : BeamPort;
			port interlockIn : ~InterlockPort;
			attribute active : Boolean;
		}

		part def SafetyInterlock {
			port interlockOut : InterlockPort;
			attribute doorClosed : Boolean;
			attribute emergencyStop : Boolean;
			attribute allLeavesVerified : Boolean;
		}

		part def Patient {
			port beamIn : ~BeamPort;
		}

		part def TreatmentRoom {
			attribute doorClosed : Boolean;
		}

		action def LoadPlan { in plan : TreatmentPlan; }
		action def MoveLeaves { in plan : TreatmentPlan; }
		action def VerifyPositions { out verified : Boolean; }
		action def DeliverTreatment;
		action def MonitorPositions;

		state def MLCSystemStates;

		requirement def LeafAccuracyRequirement {
			subject l : Leaf;
			attribute tolerance : Length = 0.1;
		}

		requirement def SafetyInterlockRequirement {
			subject s : SafetyInterlock;
		}
	}

	package Usages {
		private import Definitions::*;

		part radiationTherapySystem {
			part controller : Controller;
			part mlc : MultileafCollimator;
			part safetyInterlock : SafetyInterlock;
			part radiationSource : RadiationSource;
			part patient : Patient;
			part treatmentRoom : TreatmentRoom;

			connect controller.commandOut to mlc.controllerCommand;
			connect mlc.controllerFeedback to controller.feedbackIn;
			connect safetyInterlock.interlockOut to radiationSource.interlockIn;
			connect radiationSource.beamOut to patient.beamIn;

			state systemStates : MLCSystemStates {
				in operatingSystem : MultileafCollimator;
				in ctrl : Controller;
				in lock : SafetyInterlock;
				in src : RadiationSource;
				in room : TreatmentRoom;

				entry; then standby;

				state standby;

				accept PlanLoaded
					then moving;

				state moving {
					entry action moveLeaves { /* ... */ }
					do action verifyPos { /* ... */ }
				}

				accept AllLeavesVerified
					if lock.doorClosed and not lock.emergencyStop
					then verifying;

				state verifying;

				accept BeamOn
					then treating;

				state treating {
					entry action deliver { /* ... */ }
					do action monitor { /* ... */ }
					exit action stopTreatment { /* ... */ }
				}

				accept TreatmentComplete then standby;

				accept EmergencyStop
					then standby;
			}
		}
	}
}
