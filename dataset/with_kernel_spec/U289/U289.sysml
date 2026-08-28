package 'Maddox Wing System' {
	doc /* Maddox Wing clinical ophthalmic instrument for measuring phoria. */

	private import ScalarValues::*;
	private import SI::*;

	item def Light;
	item def PointLight :> Light;
	item def LineStreak :> Light;

	item def PhoriaResult {
		attribute horizontalDeviation : Real;
		attribute verticalDeviation : Real;
		attribute diagnosis : PhoriaType;
	}

	enum def PhoriaType {
		enum orthophoria;
		enum esophoria;
		enum exophoria;
		enum hyperphoria;
		enum hypophoria;
	}

	enum def RodOrientation {
		enum horizontal;
		enum vertical;
	}

	part def Eye;

	part def Patient {
		part leftEye : Eye;
		part rightEye : Eye;
		attribute reportedHorizontal : Real;
		attribute reportedVertical : Real;
	}

	part def Examiner {
		port resultIn {
			in item result : PhoriaResult;
		}
	}

	part def IlluminationSource {
		port lightOut {
			out item pointLight : PointLight;
		}
		attribute intensity : Real = 0.5;
		attribute maxSafeIntensity : Real = 1.0;
	}

	part def MaddoxRod {
		port lightIn {
			in item sourceLight : PointLight;
		}
		port streakOut {
			out item streak : LineStreak;
		}
		attribute orientation : RodOrientation = RodOrientation::horizontal;
	}

	part def CalibratedScale {
		attribute horizontalScaleMin : Real = -20;
		attribute horizontalScaleMax : Real = 20;
		attribute verticalScaleMin : Real = -20;
		attribute verticalScaleMax : Real = 20;
		attribute centerHorizontal : Real = 0;
		attribute centerVertical : Real = 0;
	}

	state def SafetyStateMachine {
		entry; then safeState;
		state safeState;
		state unsafeState;
		transition safeState to unsafeState
			when currentIntensity > maxSafeIntensity;
		transition unsafeState to safeState
			when currentIntensity <= maxSafeIntensity;
	}

	part def SafetyController {
		attribute maxSafeIntensity : Real = 1.0;
		attribute currentIntensity : Real;
		perform SafetyStateMachine;
	}

	part def MaddoxWingDevice {
		attribute viewingDistance : Real = 33;
		part illuminationSource : IlluminationSource;
		part maddoxRod : MaddoxRod;
		part scale : CalibratedScale;
		part safetyController : SafetyController;

		connect illuminationSource.lightOut to maddoxRod.lightIn;
		bind safetyController.currentIntensity = illuminationSource.intensity;
	}

	action def PresentStimuli {
		in part patient : Patient;
	}

	action def CollectPatientResponse {
		in part patient : Patient;
		out attribute horizontalDeviation : Real;
		out attribute verticalDeviation : Real;
	}

	action def QuantifyDeviation {
		in attribute horizontalDeviation : Real;
		in attribute verticalDeviation : Real;
		out attribute diagnosis : PhoriaType;
	}

	action def ConductPhoriaTest {
		in part patient : Patient;
		out attribute horizontalDeviation : Real;
		out attribute verticalDeviation : Real;
		out attribute diagnosis : PhoriaType;

		perform action present :>> PresentStimuli {
			in part :>> patient;
		}
		then perform action collect :>> CollectPatientResponse {
			in part :>> patient;
			out attribute :>> horizontalDeviation;
			out attribute :>> verticalDeviation;
		}
		then perform action quantify :>> QuantifyDeviation {
			in attribute :>> horizontalDeviation;
			in attribute :>> verticalDeviation;
			out attribute :>> diagnosis;
		}
	}

	requirement def DissociationRequirement {
		doc /* The device shall present a point of light to one eye and a perpendicular line streak to the other eye simultaneously to dissociate binocular fusion. */
	}

	requirement def SafeIlluminationRequirement {
		doc /* The illumination source intensity shall not exceed a safe level for direct patient viewing. */
		attribute maxIntensity : Real = 1.0;
	}

	requirement def MeasurementRequirement {
		doc /* The device shall include a calibrated scale graduated in prism diopters to quantify horizontal and vertical deviation. */
	}

	requirement def ViewingDistanceRequirement {
		doc /* The device shall be used at a standard near-viewing distance of 33 cm. */
		attribute standardDistance : Real = 33;
	}

	part maddoxWingSystem : MaddoxWingDevice {
		satisf DissociationRequirement;
		satisf SafeIlluminationRequirement;
		satisf MeasurementRequirement;
		satisf ViewingDistanceRequirement;
	}

	individual def ClinicalMaddoxWing :> MaddoxWingDevice;
	individual def StandardPatient :> Patient;

	individual clinicalDevice : ClinicalMaddoxWing :> maddoxWingSystem {
		:>> viewingDistance = 33;
		:>> illuminationSource.intensity = 0.4;

		timeslice esophoriaTest {
			perform action :>> ConductPhoriaTest {
				in individual :>> patient : StandardPatient {
					:>> reportedHorizontal = 6;
					:>> reportedVertical = 0;
				}
				out attribute :>> horizontalDeviation = 6;
				out attribute :>> verticalDeviation = 0;
				out attribute :>> diagnosis = PhoriaType::esophoria;
			}
		}
		then timeslice exophoriaTest {
			perform action :>> ConductPhoriaTest {
				in individual :>> patient : StandardPatient {
					:>> reportedHorizontal = -4;
					:>> reportedVertical = 0;
				}
				out attribute :>> horizontalDeviation = -4;
				out attribute :>> verticalDeviation = 0;
				out attribute :>> diagnosis = PhoriaType::exophoria;
			}
		}
		then timeslice hyperphoriaTest {
			perform action :>> ConductPhoriaTest {
				in individual :>> patient : StandardPatient {
					:>> reportedHorizontal = 0;
					:>> reportedVertical = 3;
				}
				out attribute :>> horizontalDeviation = 0;
				out attribute :>> verticalDeviation = 3;
				out attribute :>> diagnosis = PhoriaType::hyperphoria;
			}
		}
	}
}
