package 'Pinard Horn Fetal Auscultation System' {
	private import ScalarValues::*;
	private import Definitions::*;
	private import Usages::*;
	private import Requirements::*;

	package Definitions {
		private import ScalarValues::*;

		unit def pascal;
		unit def hertz;
		unit def metre;
		unit def bpm;
		unit def second;

		attribute def SoundPressure :> Real { unit = pascal; }
		attribute def AcousticFrequency :> Real { unit = hertz; }
		attribute def LengthMeasure :> Real { unit = metre; }
		attribute def DiameterMeasure :> Real { unit = metre; }
		attribute def HeartRateMeasure :> Real { unit = bpm; }
		attribute def DurationMeasure :> Real { unit = second; }
		attribute def AmplificationFactor :> Real;

		item def SoundWave {
			attribute pressure : SoundPressure;
			attribute frequency : AcousticFrequency;
		}
		item def FetalHeartSound :> SoundWave;
		item def AmplifiedSound :> SoundWave;

		port def FetalSoundOutPort {
			out sound : FetalHeartSound;
		}
		port def FetalSoundInPort {
			in sound : FetalHeartSound;
		}
		port def AmplifiedSoundOutPort {
			out sound : AmplifiedSound;
		}
		port def AmplifiedSoundInPort {
			in sound : AmplifiedSound;
		}

		part def FetalHeart {
			attribute nominalHeartRate : HeartRateMeasure = 140 [bpm];
			port soundPort : FetalSoundOutPort;
			perform action beat {
				out item sound : FetalHeartSound;
			}
		}

		part def Fetus {
			part heart : FetalHeart;
		}

		part def Abdomen {
			port internalPort : FetalSoundInPort;
			port externalPort : FetalSoundOutPort;
			flow fetalSoundFlow of FetalHeartSound
				from internalPort.sound to externalPort.sound;
		}

		part def Patient {
			part abdomen : Abdomen;
			part fetus : Fetus;
			flow fetusToAbdomenFlow of FetalHeartSound
				from fetus.heart.soundPort.sound to abdomen.internalPort.sound;
		}

		part def Bell {
			attribute apertureDiameter : DiameterMeasure = 0.05 [metre];
			attribute depth : LengthMeasure = 0.06 [metre];
			port soundInPort : FetalSoundInPort;
			port soundOutPort : FetalSoundOutPort;
			perform action collectSound {
				in item incoming : FetalHeartSound;
				out item outgoing : FetalHeartSound = incoming;
			}
		}

		part def ResonatingTube {
			attribute tubeLength : LengthMeasure = 0.15 [metre];
			attribute tubeDiameter : DiameterMeasure = 0.015 [metre];
			attribute amplification : AmplificationFactor = 10.0;
			port soundInPort : FetalSoundInPort;
			port soundOutPort : AmplifiedSoundOutPort;
			perform action resonate {
				in item incoming : FetalHeartSound;
				out item outgoing : AmplifiedSound;
			}
		}

		part def Earpiece {
			attribute contactDiameter : DiameterMeasure = 0.02 [metre];
			port soundInPort : AmplifiedSoundInPort;
			port soundOutPort : AmplifiedSoundOutPort;
		}

		part def PinardHorn {
			attribute isMechanical : Boolean = true;
			attribute isElectronic : Boolean = false;
			part bell : Bell;
			part resonatingTube : ResonatingTube;
			part earpiece : Earpiece;
			flow bellToTubeFlow of FetalHeartSound
				from bell.soundOutPort.sound to resonatingTube.soundInPort.sound;
			flow tubeToEarpieceFlow of AmplifiedSound
				from resonatingTube.soundOutPort.sound to earpiece.soundInPort.sound;
			perform action auscultate {
				action positionHorn;
				action locateHeartbeat;
				action adjustPosition;
				action listenAndCount;
				succession first positionHorn then locateHeartbeat;
				succession first locateHeartbeat then listenAndCount;
				succession first adjustPosition then locateHeartbeat;
			}
		}

		part def Clinician {
			port listenPort : AmplifiedSoundInPort;
			attribute detectedHeartRate : HeartRateMeasure;
			attribute isTrained : Boolean = true;
			perform action listen {
				in item sound : AmplifiedSound;
				out item detectedHeartRate : HeartRateMeasure;
			}
		}

		use case def FetalAuscultation {
			subject pinardHorn : PinardHorn;
			actor clinician : Clinician;
			actor patient : Patient;
			objective {
				/* Determine fetal heart rate through non-invasive acoustic auscultation */
			}
			include use case positionHornUC : PositionHornUC {
				subject = pinardHorn;
				actor clinician = FetalAuscultation::clinician;
				actor patient = FetalAuscultation::patient;
			}
			include use case locateHeartbeatUC : LocateHeartbeatUC {
				subject = pinardHorn;
				actor clinician = FetalAuscultation::clinician;
			}
			include use case listenAndCountUC : ListenAndCountUC {
				subject = pinardHorn;
				actor clinician = FetalAuscultation::clinician;
			}
		}

		use case def PositionHornUC {
			subject pinardHorn : PinardHorn;
			actor clinician : Clinician;
			actor patient : Patient;
			objective {
				/* Position the Pinard horn on the maternal abdomen */
			}
		}

		use case def LocateHeartbeatUC {
			subject pinardHorn : PinardHorn;
			actor clinician : Clinician;
			objective {
				/* Locate the fetal heartbeat by adjusting horn position */
			}
		}

		use case def ListenAndCountUC {
			subject pinardHorn : PinardHorn;
			actor clinician : Clinician;
			objective {
				/* Listen to and count fetal heartbeats to determine heart rate */
			}
		}

		state def AuscultationProcedure {
			event start;
			event hornPositioned;
			event soundWeak;
			event soundClear;
			event hornAdjusted;
			event beatDetected;
			event countingComplete;

			state idle;
			state positioning {
				do action placeHornOnAbdomen;
			}
			state locating {
				do action listenForHeartbeat;
			}
			state adjusting {
				do action repositionHorn;
			}
			state listening {
				do action monitorBeat;
			}
			state counting {
				do action countBeatsAndComputeRate;
			}
			state complete;

			transition from idle to positioning on start;
			transition from positioning to locating on hornPositioned;
			transition from locating to adjusting on soundWeak;
			transition from locating to listening on soundClear;
			transition from adjusting to locating on hornAdjusted;
			transition from listening to counting on beatDetected;
			transition from counting to complete on countingComplete;
		}
	}

	package Usages {
		private import Definitions::*;

		part patient_u : Patient;
		part clinician_u : Clinician;
		part pinardHorn_u : PinardHorn;

		interface abdomenToBellInterface
			connect patient_u.abdomen.externalPort to pinardHorn_u.bell.soundInPort {
			flow fetalSoundToBell of FetalHeartSound
				from patient_u.abdomen.externalPort.sound to pinardHorn_u.bell.soundInPort.sound;
		}

		interface earpieceToClinicianInterface
			connect pinardHorn_u.earpiece.soundOutPort to clinician_u.listenPort {
			flow amplifiedSoundToClinician of AmplifiedSound
				from pinardHorn_u.earpiece.soundOutPort.sound to clinician_u.listenPort.sound;
		}

		use case auscultationUC : FetalAuscultation {
			subject :>> pinardHorn :>> pinardHorn_u;
			actor :>> clinician :>> clinician_u;
			actor :>> patient :>> patient_u;
		}

		state auscultationState : AuscultationProcedure;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def AcousticAmplificationRequirement {
			subject horn : PinardHorn;
			doc /* The Pinard horn shall amplify fetal heart sounds
			       through passive acoustic resonance without external power. */
		}

		requirement def NonElectronicRequirement {
			subject horn : PinardHorn;
			doc /* The system shall be purely mechanical with no electronic components. */
		}

		requirement def SafetyRequirement {
			subject horn : PinardHorn;
			doc /* The device shall be safe for non-invasive use during pregnancy. */
		}

		requirement def AudibilityRequirement {
			subject horn : PinardHorn;
			doc /* The amplified sound at the earpiece shall be audible to the clinician. */
		}

		requirement def PositioningRequirement {
			subject horn : PinardHorn;
			actor clinician : Clinician;
			doc /* The clinician shall be able to position the bell firmly
			       against the maternal abdomen. */
		}

		requirement acousticAmpReq : AcousticAmplificationRequirement {
			subject :>> horn :>> pinardHorn_u;
		}
		requirement nonElecReq : NonElectronicRequirement {
			subject :>> horn :>> pinardHorn_u;
		}
		requirement safetyReq : SafetyRequirement {
			subject :>> horn :>> pinardHorn_u;
		}
		requirement audibilityReq : AudibilityRequirement {
			subject :>> horn :>> pinardHorn_u;
		}
		requirement positioningReq : PositioningRequirement {
			subject :>> horn :>> pinardHorn_u;
			actor :>> clinician :>> clinician_u;
		}
	}

	satisfy acousticAmpReq by pinardHorn_u.resonatingTube;
	satisfy nonElecReq by pinardHorn_u;
	satisfy safetyReq by pinardHorn_u;
	satisfy audibilityReq by pinardHorn_u.earpiece;
	satisfy positioningReq by pinardHorn_u.bell;
}
