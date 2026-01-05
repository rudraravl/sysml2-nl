package StethoscopeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def AcousticFrequency :> ISQ::FrequencyValue;
	attribute def SoundPressureLevel :> ISQ::PressureValue;
	attribute def AcousticImpedance :> ISQ::MassValue;

	item def BodySound {
		attribute frequency : AcousticFrequency;
		attribute pressure : SoundPressureLevel;
		attribute sourceLocation : String;
	}

	item def AuditorySignal {
		attribute frequency : AcousticFrequency;
		attribute amplitude : SoundPressureLevel;
		attribute fidelity : Real;
	}

	port def BodyContactPort {
		in item bodySound : BodySound;
	}

	port def AcousticTransmissionPort {
		out item transmittedSound : AuditorySignal;
	}

	port def EarDeliveryPort {
		out item deliveredSound : AuditorySignal;
	}

	action def CaptureBodySound {
		in bodySoundInput : BodySound;
		out capturedSignal : AuditorySignal;
	}

	action def ConductAcousticWave {
		in inputSignal : AuditorySignal;
		out outputSignal : AuditorySignal;
	}

	action def DeliverToEar {
		in conductedSignal : AuditorySignal;
		out earSignal : AuditorySignal;
	}

	part def ChestPiece {
		doc /* Captures internal body sounds through direct contact with patient skin */
		
		port bodyContact : BodyContactPort;
		port soundOutput : AcousticTransmissionPort;

		part diaphragm {
			attribute diameter : ISQ::LengthValue;
			attribute thickness : ISQ::LengthValue;
			attribute material : String;
		}

		part bell {
			attribute depth : ISQ::LengthValue;
			attribute diameter : ISQ::LengthValue;
		}

		perform action captureSound : CaptureBodySound;
	}

	part def AcousticTubing {
		doc /* Transmits acoustic vibrations from chest piece to earpieces */
		
		attribute length : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute wallThickness : ISQ::LengthValue;

		port tubingInput : AcousticTransmissionPort;
		port tubingOutput : AcousticTransmissionPort;

		perform action conductSound : ConductAcousticWave;
	}

	part def Earpiece {
		doc /* Delivers amplified sound into clinician's ear canal */
		
		attribute angle : Real;
		attribute tipMaterial : String;

		port earInput : AcousticTransmissionPort;
		port earOutput : EarDeliveryPort;

		perform action deliverSound : DeliverToEar;
	}

	part def BinauralAssembly {
		doc /* Splits acoustic signal to both ears */
		
		port binauralInput : AcousticTransmissionPort;
		
		part leftEarpiece : Earpiece;
		part rightEarpiece : Earpiece;

		connection leftPath connect binauralInput to leftEarpiece.earInput;
		connection rightPath connect binauralInput to rightEarpiece.earInput;
	}

	attribute def PlaceOnPatientEvent;
	attribute def RemoveFromPatientEvent;

	state def StethoscopeState {
		entry; then idle;

		state idle {
			doc /* Stethoscope not in use */
		}

		state positioned {
			doc /* Chest piece positioned on patient */
			entry; then activeListening;

			state activeListening {
				doc /* Actively capturing and transmitting body sounds */
			}
		}

		transition idleToPositioned
			first idle
			accept placeEvent : PlaceOnPatientEvent
			then positioned;

		transition positionedToIdle
			first positioned
			accept removeEvent : RemoveFromPatientEvent
			then idle;
	}

	action def PerformAuscultation {
		doc /* Complete auscultation cycle from sound capture to ear delivery */
		
		in patientBodySound : BodySound;
		out leftEarOutput : AuditorySignal;
		out rightEarOutput : AuditorySignal;

		first start;
		then action capture : CaptureBodySound {
			in bodySoundInput = patientBodySound;
			out capturedSignal;
		}
		then action transmitLeft : ConductAcousticWave {
			in inputSignal = capture.capturedSignal;
			out outputSignal;
		}
		then action transmitRight : ConductAcousticWave {
			in inputSignal = capture.capturedSignal;
			out outputSignal;
		}
		then action deliverLeft : DeliverToEar {
			in conductedSignal = transmitLeft.outputSignal;
			out earSignal;
		}
		then action deliverRight : DeliverToEar {
			in conductedSignal = transmitRight.outputSignal;
			out earSignal;
		}
		then done;
	}

	part def Stethoscope {
		doc /* Medical acoustic instrument for auscultation of internal body sounds */
		
		port patientInterface : BodyContactPort;
		port clinicianLeftEar : EarDeliveryPort;
		port clinicianRightEar : EarDeliveryPort;

		part chestPiece : ChestPiece;
		part leftTubing : AcousticTubing;
		part rightTubing : AcousticTubing;
		part binaurals : BinauralAssembly;

		connection chestToLeft connect chestPiece.soundOutput to leftTubing.tubingInput;
		connection chestToRight connect chestPiece.soundOutput to rightTubing.tubingInput;
		connection leftToBinaural connect leftTubing.tubingOutput to binaurals.binauralInput;
		connection rightToBinaural connect rightTubing.tubingOutput to binaurals.binauralInput;
		connection leftToEar connect binaurals.leftEarpiece.earOutput to clinicianLeftEar;
		connection rightToEar connect binaurals.rightEarpiece.earOutput to clinicianRightEar;

		perform action auscultate[*] ordered;
		perform behavior operationalState : StethoscopeState;
	}

	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def UsabilityRequirement;

	requirement <'STETH-REQ-001'> primaryFunction : FunctionalRequirement {
		doc /* The stethoscope shall amplify and transmit internal body sounds from 
		     the patient to the clinician's ears for diagnostic auscultation of 
		     cardiovascular, respiratory, and gastrointestinal systems. */
		
		subject device : Stethoscope;

		require constraint acousticTransmission {
			doc /* Shall transmit acoustic signals with minimal distortion */
		}

		require constraint binauralDelivery {
			doc /* Shall deliver sound simultaneously to both ears */
		}
	}

	requirement <'STETH-REQ-002'> frequencyResponse : PerformanceRequirement {
		doc /* The stethoscope shall effectively transmit sounds within the 
		     clinical frequency range of 20 Hz to 2000 Hz. */
		
		subject device : Stethoscope;

		assume constraint clinicalRange {
			doc /* Body sounds of diagnostic interest fall within 20-2000 Hz */
		}
	}

	requirement <'STETH-REQ-003'> signalFidelity : PerformanceRequirement {
		doc /* The stethoscope shall maintain signal amplitude attenuation 
		     below 6 dB across the diagnostic frequency range. */
		
		subject device : Stethoscope;
	}

	requirement <'STETH-REQ-004'> comfortableUse : UsabilityRequirement {
		doc /* The stethoscope shall be comfortable for extended clinical use 
		     during patient examinations. */
		
		subject device : Stethoscope;

		require constraint ergonomicDesign {
			doc /* Earpieces shall conform to ear canal anatomy */
		}

		require constraint lightweightConstruction {
			doc /* Total mass shall not exceed 200 grams */
		}
	}

	part clinicalStethoscope : Stethoscope {
		doc /* Acoustic stethoscope for clinical diagnostic auscultation */

		satisfy primaryFunction;
		satisfy frequencyResponse;
		satisfy signalFidelity;
		satisfy comfortableUse;

		part redefines chestPiece : ChestPiece {
			part redefines diaphragm {
				attribute redefines diameter = 45.0[SI::mm];
				attribute redefines thickness = 0.2[SI::mm];
				attribute redefines material = "polyester film";
			}
			part redefines bell {
				attribute redefines depth = 15.0[SI::mm];
				attribute redefines diameter = 30.0[SI::mm];
			}
		}

		part redefines leftTubing : AcousticTubing {
			attribute redefines length = 550.0[SI::mm];
			attribute redefines innerDiameter = 4.5[SI::mm];
			attribute redefines wallThickness = 2.0[SI::mm];
		}

		part redefines rightTubing : AcousticTubing {
			attribute redefines length = 550.0[SI::mm];
			attribute redefines innerDiameter = 4.5[SI::mm];
			attribute redefines wallThickness = 2.0[SI::mm];
		}

		part redefines binaurals : BinauralAssembly {
			part redefines leftEarpiece : Earpiece {
				attribute redefines angle = 15.0;
				attribute redefines tipMaterial = "soft silicone";
			}
			part redefines rightEarpiece : Earpiece {
				attribute redefines angle = 15.0;
				attribute redefines tipMaterial = "soft silicone";
			}
		}
	}
}
