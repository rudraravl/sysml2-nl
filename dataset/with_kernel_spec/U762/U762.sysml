package MagneticCompassSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;
	private import ScalarValues::String;

	attribute def HeadingAngleValue :> Real {
		doc
		/*
		 * Heading angle in degrees measured clockwise from North (0 to 360).
		 */
		assert constraint validRange { self >= 0.0 and self <= 360.0 }
	}

	attribute def DeclinationAngleValue :> Real {
		doc
		/*
		 * Magnetic declination angle in degrees (positive = east, negative = west).
		 */
		assert constraint validRange { self >= -180.0 and self <= 180.0 }
	}

	attribute def AngularVelocityValue :> Real {
		doc
		/*
		 * Angular velocity in degrees per second.
		 */
	}

	attribute def MagneticFluxDensityValue :> Real {
		doc
		/*
		 * Magnetic flux density value expressed in microtesla.
		 */
	}

	attribute def ViscosityValue :> Real {
		doc
		/*
		 * Dynamic viscosity of the damping fluid expressed in pascal-seconds.
		 */
		assert constraint positiveViscosity { self > 0.0 }
	}

	attribute def FrictionCoefficientValue :> Real {
		doc
		/*
		 * Dimensionless coefficient of friction of the pivot assembly.
		 */
		assert constraint positiveFriction { self >= 0.0 }
	}

	item def EarthMagneticField {
		doc
		/*
		 * Representation of the Earth's magnetic field at a local point.
		 */
		attribute fluxDensity : MagneticFluxDensityValue [1];
		attribute fieldDirection : HeadingAngleValue [1];
		attribute declination : DeclinationAngleValue [1];
	}

	item def HeadingReading {
		doc
		/*
		 * A heading reading produced by the compass, containing both magnetic and true heading.
		 */
		attribute magneticHeading : HeadingAngleValue [1];
		attribute trueHeading : HeadingAngleValue [1];
		attribute isStable : Boolean [1];
	}

	port def MagneticFieldSensingPort {
		doc
		/*
		 * Port through which the compass receives Earth's magnetic field data.
		 */
		in item sensedField : EarthMagneticField [0..*];
	}

	port def HeadingOutputPort {
		doc
		/*
		 * Port through which the compass provides heading readings.
		 */
		out item heading : HeadingReading [0..*];
	}

	part def MagnetizedNeedle {
		doc
		/*
		 * A lightweight, freely rotating magnetized needle that aligns with the local magnetic field.
		 */
		attribute magneticMoment : Real [1];
		attribute momentOfInertia : Real [1];
		attribute currentHeading : HeadingAngleValue [1] default 0;
		attribute angularVelocity : AngularVelocityValue [1] default 0;
	}

	part def PivotAssembly {
		doc
		/*
		 * Low-friction pivot assembly on which the magnetized needle is mounted.
		 */
		attribute frictionCoefficient : FrictionCoefficientValue [1] default 0.001;
		part needle : MagnetizedNeedle [1];
	}

	part def DampingMedium {
		doc
		/*
		 * A viscous fluid surrounding the needle to reduce oscillations and aid settling.
		 */
		attribute viscosity : ViscosityValue [1] default 1.0;
		attribute dampingCoefficient : Real [1] default 0.5;
	}

	part def CompassRose {
		doc
		/*
		 * A circular dial marked with cardinal directions and intermediate graduations.
		 */
		attribute cardinalMarks : String [1] default "N, E, S, W";
		attribute graduationCount : Integer [1] default 360;
	}

	part def LubberLine {
		doc
		/*
		 * A fixed reference mark on the housing indicating the forward direction of the compass.
		 */
		attribute fixedBearing : HeadingAngleValue [1] default 0;
	}

	part def ProtectiveHousing {
		doc
		/*
		 * Sealed, waterproof protective housing enclosing internal components, with a clear viewing window.
		 */
		attribute isSealed : Boolean [1] default true;
		attribute isWaterproof : Boolean [1] default true;
		attribute hasViewingWindow : Boolean [1] default true;
	}

	connection def NeedlePivotMount {
		doc
		/*
		 * Connection mounting the magnetized needle onto the pivot assembly.
		 */
		end pivot : PivotAssembly;
		end needle : MagnetizedNeedle;
	}

	connection def FluidImmersion {
		doc
		/*
		 * Connection submerging the needle in the damping medium.
		 */
		end medium : DampingMedium;
		end needle : MagnetizedNeedle;
	}

	connection def RoseHousingMount {
		doc
		/*
		 * Connection fixing the compass rose to the protective housing.
		 */
		end housing : ProtectiveHousing;
		end rose : CompassRose;
	}

	connection def LubberLineHousingMount {
		doc
		/*
		 * Connection fixing the lubber line to the protective housing.
		 */
		end housing : ProtectiveHousing;
		end line : LubberLine;
	}

	state machine def CompassOperatingStates {
		doc
		/*
		 * State machine governing the operational states of the magnetic compass.
		 */
		in needleAngularVelocity : AngularVelocityValue;
		in disturbance : Boolean;

		state seeking;
		state stabilizing;
		state steady;

		transition from seeking to stabilizing when needleAngularVelocity < 10.0;
		transition from stabilizing to steady when needleAngularVelocity < 0.01;
		transition from steady to seeking when disturbance;
		transition from stabilizing to seeking when disturbance;
	}

	part def MagneticCompass {
		doc
		/*
		 * A physical magnetic compass system for navigation and orientation.
		 * It continuously determines directional heading by sensing the Earth's magnetic field.
		 */

		port magneticFieldInput : MagneticFieldSensingPort [1];
		port headingOutput : HeadingOutputPort [1];

		part housing : ProtectiveHousing [1] {
			part compassRose : CompassRose [1];
			part lubberLine : LubberLine [1];
		}

		part pivotAssembly : PivotAssembly [1];
		part dampingMedium : DampingMedium [1];

		connection needleMount : NeedlePivotMount
			connect pivotAssembly to pivotAssembly.needle;
		connection fluidImmersion : FluidImmersion
			connect dampingMedium to pivotAssembly.needle;
		connection roseMount : RoseHousingMount
			connect housing to housing.compassRose;
		connection lubberMount : LubberLineHousingMount
			connect housing to housing.lubberLine;

		attribute localDeclination : DeclinationAngleValue [1] default 0;
		attribute disturbanceDetected : Boolean [1] default false;

		exhibit compassStates : CompassOperatingStates {
			in needleAngularVelocity = pivotAssembly.needle.angularVelocity;
			in disturbance = disturbanceDetected;
		}

		perform action determineHeading {
			doc
			/*
			 * Determine directional heading by sensing the Earth's magnetic field,
			 * reading the needle bearing, and applying declination correction.
			 */

			action senseMagneticField {
				doc
				/*
				 * Sense the Earth's magnetic field direction.
				 */
				in item sensedField : EarthMagneticField [0..*];
				out attribute fieldDirection : HeadingAngleValue [1];
			}
			then action readBearing {
				doc
				/*
				 * Read the bearing from the needle relative to the lubber line.
				 */
				in attribute fieldDirection : HeadingAngleValue [1];
				in attribute needleHeading : HeadingAngleValue [1];
				in attribute lubberBearing : HeadingAngleValue [1];
				out attribute magneticHeading : HeadingAngleValue [1];
			}
			then action applyDeclinationCorrection {
				doc
				/*
				 * Apply declination correction to obtain true heading.
				 */
				in attribute magneticHeading : HeadingAngleValue [1];
				in attribute declination : DeclinationAngleValue [1];
				out attribute trueHeading : HeadingAngleValue [1];
			}
			then action produceReading {
				doc
				/*
				 * Assemble the final heading reading.
				 */
				in attribute magneticHeading : HeadingAngleValue [1];
				in attribute trueHeading : HeadingAngleValue [1];
				out item reading : HeadingReading [1];
			}
		}

		assert constraint dampingFluidPresent {
			dampingMedium.viscosity > 0.0
		}

		assert constraint needleMagnetised {
			pivotAssembly.needle.magneticMoment > 0.0
		}
	}

	requirement def ContinuousHeadingRequirement {
		doc
		/*
		 * The compass shall continuously determine directional heading by sensing the Earth's magnetic field.
		 */
		subject compass : MagneticCompass;
		objective {
			compass.pivotAssembly.needle.magneticMoment > 0.0
		}
	}

	requirement def NeedleAlignmentRequirement {
		doc
		/*
		 * The magnetized needle shall be freely rotating and align with the local magnetic field lines.
		 */
		subject needle : MagnetizedNeedle;
		objective {
			needle.magneticMoment > 0.0
		}
	}

	requirement def PivotLowFrictionRequirement {
		doc
		/*
		 * The pivot assembly shall have low friction to allow free needle rotation.
		 */
		subject pivot : PivotAssembly;
		objective {
			pivot.frictionCoefficient < 0.01
		}
	}

	requirement def DampingSettlingRequirement {
		doc
		/*
		 * The damping medium shall reduce needle oscillations to achieve steady state.
		 */
		subject damping : DampingMedium;
		objective {
			damping.dampingCoefficient > 0.0
		}
	}

	requirement def HousingProtectionRequirement {
		doc
		/*
		 * The protective housing shall be sealed, waterproof, and feature a clear viewing window.
		 */
		subject housing : ProtectiveHousing;
		objective {
			housing.isSealed and housing.isWaterproof and housing.hasViewingWindow
		}
	}

	requirement def DeclinationCompensationRequirement {
		doc
		/*
		 * The compass shall account for local magnetic declination to provide true heading.
		 */
		subject compass : MagneticCompass;
		objective {
			compass.localDeclination >= -180.0 and compass.localDeclination <= 180.0
		}
	}

	requirement def StateTransitionRequirement {
		doc
		/*
		 * The compass shall transition through seeking, stabilizing, and steady operational states.
		 */
		subject compass : MagneticCompass;
		objective {
			compass.pivotAssembly.needle.magneticMoment > 0.0
		}
	}

	requirement def CompassRoseGraduationRequirement {
		doc
		/*
		 * The compass rose shall display cardinal directions and intermediate graduations.
		 */
		subject rose : CompassRose;
		objective {
			rose.graduationCount >= 360
		}
	}

	requirement continuousHeadingReq : ContinuousHeadingRequirement;
	requirement needleAlignmentReq : NeedleAlignmentRequirement;
	requirement pivotLowFrictionReq : PivotLowFrictionRequirement;
	requirement dampingSettlingReq : DampingSettlingRequirement;
	requirement housingProtectionReq : HousingProtectionRequirement;
	requirement stateTransitionReq : StateTransitionRequirement;
	requirement declinationCompensationReq : DeclinationCompensationRequirement;
	requirement compassRoseGraduationReq : CompassRoseGraduationRequirement;

	part navigationCompass : MagneticCompass {
		doc
		/*
		 * A usage of the magnetic compass in a navigation context, satisfying all defined requirements.
		 */
		satisfy continuousHeadingReq;
		satisfy needleAlignmentReq;
		satisfy pivotLowFrictionReq;
		satisfy dampingSettlingReq;
		satisfy housingProtectionReq;
		satisfy stateTransitionReq;
		satisfy declinationCompensationReq;
		satisfy compassRoseGraduationReq;
	}
}
