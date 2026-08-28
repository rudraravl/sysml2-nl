package ClinicalAcousticStethoscope {
	private import ScalarValues::*;

	attribute def Frequency :> Real;
	attribute def SoundPressureLevel :> Real;
	attribute def Mass :> Real;

	item def AcousticVibration {
		attribute frequency : Frequency;
		attribute amplitude : SoundPressureLevel;
	}
	item def BodySound :> AcousticVibration;

	part def Patient {
		out item bodySounds : BodySound;
	}

	part def Clinician {
		in item receivedSounds : BodySound;
	}

	port def AcousticInPort {
		in item sound : AcousticVibration;
	}

	port def AcousticOutPort {
		out item sound : AcousticVibration;
	}

	part def ChestPiece {
		port soundIn : AcousticInPort;
		port soundOut : AcousticOutPort;

		part diaphragm {
			attribute shape : String = "flat";
			attribute optimizedFor : String = "high-frequency";
		}
		part bell {
			attribute shape : String = "concave";
			attribute optimizedFor : String = "low-frequency";
		}

		event occurrence placedOnPatient;
		event occurrence removedFromPatient;
	}

	part def AcousticTube {
		port soundIn : AcousticInPort;
		port soundOut : AcousticOutPort;
		attribute material : String = "flexible polymer";
	}

	part def BinauralAssembly {
		port soundIn : AcousticInPort;
		port leftSoundOut : AcousticOutPort;
		port rightSoundOut : AcousticOutPort;
	}

	part def Earpiece {
		port soundIn : AcousticInPort;
		attribute material : String = "silicone";
		attribute shape : String = "angled";
	}

	state def StethoscopeBehavior {
		state idle;
		state activeListening;
		transition idle to activeListening when chestPiece.placedOnPatient;
		transition activeListening to idle when chestPiece.removedFromPatient;
	}

	part def Stethoscope {
		port patientPort : AcousticInPort;
		port clinicianPort : AcousticOutPort;

		attribute frequencyRangeMin : Frequency = 20;
		attribute frequencyRangeMax : Frequency = 2000;
		attribute totalWeight : Mass = 150;

		part chestPiece : ChestPiece;
		part tubeLeft : AcousticTube;
		part tubeRight : AcousticTube;
		part binaural : BinauralAssembly;
		part earpieceLeft : Earpiece;
		part earpieceRight : Earpiece;

		connect patientPort to chestPiece.soundIn;
		connect chestPiece.soundOut to tubeLeft.soundIn;
		connect chestPiece.soundOut to tubeRight.soundIn;
		connect tubeLeft.soundOut to binaural.soundIn;
		connect tubeRight.soundOut to binaural.soundIn;
		connect binaural.leftSoundOut to earpieceLeft.soundIn;
		connect binaural.rightSoundOut to earpieceRight.soundIn;

		exhibit state : StethoscopeBehavior;
	}

	requirement def DiagnosticFrequencyRange {
		attribute minFrequency : Frequency = 20;
		attribute maxFrequency : Frequency = 2000;
		subject stethoscope : Stethoscope;
		constraint { stethoscope.frequencyRangeMin >= minFrequency and stethoscope.frequencyRangeMax <= maxFrequency }
	}

	requirement def LightweightDesign {
		attribute maxWeight : Mass = 250;
		subject stethoscope : Stethoscope;
		constraint { stethoscope.totalWeight <= maxWeight }
	}

	requirement def AcousticSeal {
		subject earpiece : Earpiece;
		constraint { earpiece.material == "silicone" }
	}

	part stethoscopeSystem : Stethoscope {
		satisfy DiagnosticFrequencyRange;
		satisfy LightweightDesign;
		satisfy AcousticSeal by earpieceLeft;
		satisfy AcousticSeal by earpieceRight;

		ref patient : Patient;
		ref clinician : Clinician;

		flow patient.bodySounds to patientPort.sound;
		flow clinicianPort.sound to clinician.receivedSounds;
	}
}
