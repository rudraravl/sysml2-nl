package LungFluteModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def ExhaledBreath {
		attribute pressure :> ISQ::pressure;
		attribute flowRate :> ISQ::volumeFlowRate;
	}

	item def AcousticVibration {
		attribute frequency :> ISQ::frequency;
		attribute amplitude :> ISQ::pressure;
	}

	item def Mucus {
		attribute viscosity :> ISQ::dynamicViscosity;
		attribute mucusState : ScalarValues::String;
	}

	item def TherapyComplete;
	item def InhalationAttempt;
	item def Reset;

	port def BreathInPort {
		in breath : ExhaledBreath;
	}

	port def BreathOutPort {
		out breath : ExhaledBreath;
	}

	port def AcousticInPort {
		in vibration : AcousticVibration;
	}

	port def AcousticOutPort {
		out vibration : AcousticVibration;
	}

	part def Mouthpiece {
		attribute material : ScalarValues::String;
		attribute isBiocompatible : ScalarValues::Boolean = true;
		port patientEnd : BreathInPort;
		port deviceEnd : BreathOutPort;
	}

	part def ReedMechanism {
		attribute resonantFrequency :> ISQ::frequency = 18.0 [Hz];
		port airIn : BreathInPort;
		port vibrationOut : AcousticOutPort;
	}

	part def ResonanceChamber {
		attribute length :> ISQ::length;
		attribute diameter :> ISQ::length;
		port vibrationIn : AcousticInPort;
		port vibrationOut : AcousticOutPort;
	}

	part def CheckValve {
		attribute permitsInhalation : ScalarValues::Boolean = false;
		port airIn : BreathInPort;
		port airOut : BreathOutPort;
	}

	part def LungFluteDevice {
		attribute therapeuticFrequency :> ISQ::frequency = 18.0 [Hz];
		attribute requiredBackpressure :> ISQ::pressure;
	}

	part def PatientAirways {
		part mucus : Mucus;
		port acousticInput : AcousticInPort;
	}

	part def Patient {
		port airway : BreathOutPort;
		part airways : PatientAirways;
	}

	interface def BreathFlow {
		end source : BreathOutPort;
		end target : BreathInPort;
		flow source.breath to target.breath;
	}

	interface def AcousticTransfer {
		end source : AcousticOutPort;
		end target : AcousticInPort;
		flow source.vibration to target.vibration;
	}

	action def Exhale {
		out exhaledAir : ExhaledBreath;
	}

	action def FlutterReed {
		in airStream : ExhaledBreath;
		out vibration : AcousticVibration;
	}

	action def AmplifyVibration {
		in inputVibration : AcousticVibration;
		out amplifiedVibration : AcousticVibration;
	}

	action def MobilizeMucus {
		in vibration : AcousticVibration;
		in adherentMucus : Mucus;
		out mobilizedMucus : Mucus;
	}

	action def TherapySession {
		in patientExhalation : ExhaledBreath;
		out result : Mucus;

		action flutter : FlutterReed {
			in airStream = patientExhalation;
			out vibration;
		}

		action amplify : AmplifyVibration {
			in inputVibration = flutter.vibration;
			out amplifiedVibration;
		}

		action mobilize : MobilizeMucus {
			in vibration = amplify.amplifiedVibration;
			out mobilizedMucus = result;
		}

		first start;
		then flutter;
		then amplify;
		then mobilize;
		then done;
	}

	state def DeviceOperation {
		initial state Idle;
		state Exhaling;
		state TherapyActive;
		state Blocked;

		transition idleToExhaling first Idle accept exhaledAir : ExhaledBreath then Exhaling;
		transition exhalingToTherapy first Exhaling accept vibrationGenerated : AcousticVibration then TherapyActive;
		transition therapyToIdle first TherapyActive accept TherapyComplete then Idle;
		transition exhalingToBlocked first Exhaling accept InhalationAttempt then Blocked;
		transition therapyToBlocked first TherapyActive accept InhalationAttempt then Blocked;
		transition blockedToIdle first Blocked accept Reset then Idle;
	}

	requirement def GenerateTherapeuticFrequency {
		doc /* The device shall generate acoustic vibration at approximately 18 Hz. */
		subject device : LungFluteDevice;
		attribute targetFrequency :> ISQ::frequency = 18.0 [Hz];
		objective {
			device.therapeuticFrequency == targetFrequency
		}
	}

	requirement def OneWayAirflow {
		doc /* The check valve shall prevent inhalation through the device. */
		subject valve : CheckValve;
		objective {
			valve.permitsInhalation == false
		}
	}

	requirement def NoExternalPower {
		doc /* The device shall operate solely on patient exhalation without external power. */
		subject device : LungFluteDevice;
	}

	requirement def BackpressureRequirement {
		doc /* Patient exhalation shall create sufficient backpressure for effective therapy. */
		subject device : LungFluteDevice;
		attribute minBackpressure :> ISQ::pressure = 980.665 [Pa];
		objective {
			device.requiredBackpressure >= minBackpressure
		}
	}

	requirement def MucusMobilization {
		doc /* Acoustic vibration shall change mucus state from adherent to mobilized. */
		subject airways : PatientAirways;
		objective {
			airways.mucus.mucusState == "mobilized"
		}
	}

	part lungFlute : LungFluteDevice {
		attribute therapeuticFrequency = 18.0 [Hz];
		attribute requiredBackpressure = 980.665 [Pa];

		part mouthpiece : Mouthpiece {
			attribute material = "MedicalGradeSilicone";
		}

		part checkValve : CheckValve;

		part reed : ReedMechanism {
			attribute resonantFrequency = 18.0 [Hz];
		}

		part chamber : ResonanceChamber {
			attribute length = 0.25 [m];
			attribute diameter = 0.03 [m];
		}

		interface breathToValve : BreathFlow
			connect mouthpiece.deviceEnd to checkValve.airIn;
		interface valveToReed : BreathFlow
			connect checkValve.airOut to reed.airIn;
		interface reedToChamber : AcousticTransfer
			connect reed.vibrationOut to chamber.vibrationIn;

		state deviceOperation : DeviceOperation;

		satisfy GenerateTherapeuticFrequency by self;
		satisfy OneWayAirflow by checkValve;
		satisfy NoExternalPower by self;
		satisfy BackpressureRequirement by self;
	}

	part patient : Patient {
		part airways : PatientAirways {
			part mucus : Mucus {
				attribute mucusState = "adherent";
			}
		}

		satisfy MucusMobilization by airways;
	}

	interface patientToMouthpiece : BreathFlow
		connect patient.airway to lungFlute.mouthpiece.patientEnd;
	interface chamberToAirways : AcousticTransfer
		connect lungFlute.chamber.vibrationOut to patient.airways.acousticInput;
}
