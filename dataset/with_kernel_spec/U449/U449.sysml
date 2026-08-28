package WartenbergWheelSystem {
	private import SI::*;
	private import ScalarValues::*;

	item def TactileStimulus {
		attribute appliedForce :> force;
	}

	part def Pin {
		attribute tipType : String;
		attribute spacing :> length;
	}

	part def Wheel {
		attribute diameter :> length;
		part pins : Pin[*];
	}

	part def Axle {
		attribute frictionCoefficient : Real;
	}

	part def Handle {
		attribute length :> length;
		attribute mass :> mass;
	}

	connection def AxleConnection {
		end handleSide : Handle[1];
		end wheelSide : Wheel[1];
	}

	port def SkinContactPort;

	part def Patient {
		attribute examinationArea :> area;
		event occurrence sensationPerceived;
		event occurrence noSensation;
	}

	state machine def ExaminationState {
		state ready;
		state positioned;
		state stimulating;
		transition from ready to positioned accept positionedOnSkin;
		transition from positioned to stimulating accept rolling;
		transition from stimulating to ready accept examinationComplete;
	}

	part def WartenbergWheel {
		attribute maxForce :> force;
		attribute totalMass :> mass;

		part handle : Handle[1];
		part axle : Axle[1];
		part wheel : Wheel[1];

		connection : AxleConnection connect handle to wheel;

		port skinContact : SkinContactPort;

		event occurrence positionedOnSkin;
		event occurrence rolling;
		event occurrence examinationComplete;

		exhibit state : ExaminationState;
	}

	action def PerformExamination {
		in device : WartenbergWheel;
		ref patient : Patient;
		action positionOnSkin;
		then action rollAcrossSkin;
		then action evaluateResponse;
	}

	requirement def SafetyForceLimit {
		subject device : WartenbergWheel;
		doc
		/*
		 * The maximum applied force shall not exceed 1.0 N to prevent skin damage.
		 */
		constraint { device.maxForce <= 1.0[N] }
	}

	requirement def BluntPinTip {
		subject pin : Pin;
		doc
		/*
		 * All pins shall have blunt tips to prevent piercing the patient's skin.
		 */
		constraint { pin.tipType == "blunt" }
	}

	requirement def PortabilityRequirement {
		subject device : WartenbergWheel;
		doc
		/*
		 * The device shall be lightweight and portable for clinical use.
		 */
		constraint { device.totalMass <= 50[g] }
	}

	requirement def WheelDiameterSpec {
		subject wheel : Wheel;
		doc
		/*
		 * The wheel diameter shall be between 20 mm and 40 mm for consistent stimulation.
		 */
		constraint { wheel.diameter >= 20[mm] and wheel.diameter <= 40[mm] }
	}

	requirement def PinCountRequirement {
		subject wheel : Wheel;
		doc
		/*
		 * The wheel shall have approximately 20 evenly-spaced pins.
		 */
	}

	requirement def HandleErgonomicsSpec {
		subject handle : Handle;
		doc
		/*
		 * The handle length shall support comfortable clinical grip.
		 */
		constraint { handle.length >= 80[mm] and handle.length <= 120[mm] }
	}

	part wartenbergWheel : WartenbergWheel {
		attribute :>> maxForce = 0.5[N];
		attribute :>> totalMass = 30[g];

		part :>> handle {
			attribute :>> length = 100[mm];
			attribute :>> mass = 15[g];
		}

		part :>> axle {
			attribute :>> frictionCoefficient = 0.05;
		}

		part :>> wheel {
			attribute :>> diameter = 30[mm];
			part :>> pins : Pin[20] {
				attribute :>> tipType = "blunt";
				attribute :>> spacing = 4.7[mm];
			}
		}
	}

	part clinicalPatient : Patient {
		attribute :>> examinationArea = 100[cm^2];
	}

	action neurologicalExam : PerformExamination {
		in :>> device = wartenbergWheel;
		ref :>> patient = clinicalPatient;
	}

	satisfy SafetyForceLimit by wartenbergWheel;
	satisfy BluntPinTip by wartenbergWheel.wheel.pins;
	satisfy PortabilityRequirement by wartenbergWheel;
	satisfy WheelDiameterSpec by wartenbergWheel.wheel;
	satisfy HandleErgonomicsSpec by wartenbergWheel.handle;
}
