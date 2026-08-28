package PtosisCrutchSystem {
	import ScalarValues::*;
	import ISQ::*;
	
	// ---- Value types with units ----
	value type LengthUnit :> Real {
		unit mm;
	}
	value type ForceUnit :> Real {
		unit mN;
	}
	value type PressureUnit :> Real {
		unit kPa;
	}
	value type AngleUnit :> Real {
		unit deg;
	}
	value type MassUnit :> Real {
		unit g;
	}
	
	// ---- Item definitions ----
	item def Eyelid {
		attribute droopAmount : LengthUnit;       // measured droop of upper eyelid
		attribute elevation : LengthUnit;         // current elevation above baseline
		attribute sensitivity : PressureUnit;     // threshold for irritation
	}
	item def Pupil {
		attribute coverage : Real;                // fraction of pupil covered by eyelid (0..1)
	}
	item def LightRay;
	
	// ---- Flow definitions ----
	item flow def MechanicalContact {
		end appliedForce : ForceUnit;
		end appliedPressure : PressureUnit;
	}
	item flow def VisualAxis {
		end ray : LightRay;
	}
	
	// ---- Requirements ----
	requirement def RestoreLineOfSight {
		doc /* The device shall clear the user's field of vision by elevating the eyelid. */
		subject : PtosisCrutch;
		objective {
			require subject.supportedEye.pupil.coverage <= 0.05;
		}
	}
	
	requirement def NonSurgicalSolution {
		doc /* The device shall provide a non-surgical means of eyelid elevation. */
		subject : PtosisCrutch;
		objective {
			require subject.isSurgical == false;
		}
	}
	
	requirement def AdjustableLift {
		doc /* The crutch bar position and angle shall be precisely tunable. */
		subject : SupportAssembly;
		objective {
			require subject.adjustmentScrew.positionResolution <= 0.1 [mm];
			require subject.crutchBar.tiltRange <= 30.0 [deg];
		}
	}
	
	requirement def SafetyPressureLimit {
		doc /* Maximum pressure on eyelid shall remain below tissue-damage threshold. */
		subject : ContactPad;
		objective {
			require subject.maxAllowablePressure <= 4.0 [kPa];
		}
	}
	
	requirement def ComfortMonitoring {
		doc /* If irritation is detected, the device shall be readjustable. */
		subject : PtosisCrutch;
		objective {
			require subject.detectedIrritation implies subject.stateMachine.currentState == 'Readjustment';
		}
	}
	
	// ---- Part definitions ----
	part def EyeglassFrame {
		attribute material : String = "Titanium-Alloy";
		attribute mass : MassUnit = 12.0 [g];
		attribute bridgeWidth : LengthUnit = 18.0 [mm];
		port leftMount : MechanicalInterface;
		port rightMount : MechanicalInterface;
	}
	
	part def AdjustmentScrew {
		attribute pitch : LengthUnit = 0.5 [mm];
		attribute positionResolution : LengthUnit = 0.05 [mm];
		attribute currentTurns : Real = 0.0;
		attribute currentPosition : LengthUnit = 0.0 [mm];
		
		action def Adjust :> Action {
			in deltaTurns : Real;
		}
		perform action adjust : Adjust {
			then assign currentTurns = currentTurns + deltaTurns;
			then assign currentPosition = currentTurns * pitch;
		}
	}
	
	part def CrutchBar {
		attribute length : LengthUnit = 14.0 [mm];
		attribute width : LengthUnit = 1.2 [mm];
		attribute thickness : LengthUnit = 0.4 [mm];
		attribute tiltAngle : AngleUnit = 0.0 [deg];
		attribute tiltRange : AngleUnit = 30.0 [deg];
		attribute extension : LengthUnit = 0.0 [mm];
	}
	
	part def ContactPad {
		attribute material : String = "Medical-Grade-Silicone";
		attribute contactArea : LengthUnit = 6.0 [mm]; // effective contact length
		attribute maxAllowablePressure : PressureUnit = 4.0 [kPa];
		attribute currentPressure : PressureUnit = 0.0 [kPa];
		
		port contactSurface : MechanicalContact;
	}
	
	part def SupportAssembly {
		part crutchBar : CrutchBar;
		part contactPad : ContactPad;
		part adjustmentScrew : AdjustmentScrew;
		
		connection barToPad : MechanicalContact connect crutchBar to contactPad.contactSurface;
		
		action def TunePosition :> Action {
			in targetExtension : LengthUnit;
			in targetAngle : AngleUnit;
		}
		perform action tune : TunePosition {
			then assign crutchBar.extension = targetExtension;
			then assign crutchBar.tiltAngle = targetAngle;
		}
	}
	
	part def Eye {
		part eyelid : Eyelid;
		part pupil : Pupil;
		port ocularSurface : MechanicalContact;
		port visualAxis : VisualAxis;
	}
	
	part def PtosisCrutch {
		attribute isSurgical : Boolean = false;
		attribute detectedIrritation : Boolean = false;
		attribute requiredLiftForce : ForceUnit = 0.0 [mN];
		attribute requiredExtension : LengthUnit = 0.0 [mm];
		attribute requiredAngle : AngleUnit = 0.0 [deg];
		
		part frame : EyeglassFrame;
		part leftSupport : SupportAssembly;
		part rightSupport : SupportAssembly;
		part supportedEye : Eye;
		
		connection leftMountToSupport : MechanicalInterface connect frame.leftMount to leftSupport.adjustmentScrew;
		connection rightMountToSupport : MechanicalInterface connect frame.rightMount to rightSupport.adjustmentScrew;
		connection supportToEye : MechanicalContact connect leftSupport.contactPad.contactSurface to supportedEye.ocularSurface;
		
		// ---- Evaluation action ----
		action def EvaluateDroop :> Action {
			in measuredDroop : LengthUnit;
			in sensitivity : PressureUnit;
			out liftForce : ForceUnit;
			out extension : LengthUnit;
			out angle : AngleUnit;
		}
		
		perform action evaluate : EvaluateDroop {
			// Estimate required force based on droop and tissue stiffness
			then assign liftForce = measuredDroop * 0.8 [mN/mm];
			then assign extension = measuredDroop * 0.9;
			then assign angle = measuredDroop * 1.2 [deg/mm];
			then assign requiredLiftForce = liftForce;
			then assign requiredExtension = extension;
			then assign requiredAngle = angle;
		}
		
		// ---- Adjustment action ----
		action def ApplyAdjustment :> Action {
			in extension : LengthUnit;
			in angle : AngleUnit;
		}
		perform action applyAdjustment : ApplyAdjustment {
			then perform leftSupport.tune(targetExtension = extension, targetAngle = angle);
			then assign supportedEye.eyelid.elevation = extension;
		}
		
		// ---- Continuous support action ----
		action def ProvideSupport :> Action {
			in force : ForceUnit;
		}
		perform action support : ProvideSupport {
			then assign supportedEye.eyelid.elevation = requiredExtension;
			then assign supportedEye.pupil.coverage = 0.0;
		}
		
		// ---- Safety check action ----
		action def CheckSafety :> Action {
			out safe : Boolean;
		}
		perform action check : CheckSafety {
			then assign safe = leftSupport.contactPad.currentPressure <= leftSupport.contactPad.maxAllowablePressure;
		}
		
		// ---- State machine ----
		state machine def OperatingPhases {
			state Evaluation {
				entry then perform evaluate(measuredDroop = supportedEye.eyelid.droopAmount,
				                            sensitivity = supportedEye.eyelid.sensitivity);
				transition to Adjustment
					when requiredLiftForce > 0 [mN];
			}
			state Adjustment {
				entry then perform applyAdjustment(extension = requiredExtension, angle = requiredAngle);
				transition to ContinuousSupport
					when leftSupport.crutchBar.extension == requiredExtension;
			}
			state ContinuousSupport {
				entry then perform support(force = requiredLiftForce);
				do then perform check();
				transition to Readjustment
					when detectedIrritation == true or leftSupport.contactPad.currentPressure > leftSupport.contactPad.maxAllowablePressure;
			}
			state Readjustment {
				entry then assign detectedIrritation = false;
				then perform applyAdjustment(extension = requiredExtension * 0.9, angle = requiredAngle * 0.9);
				transition to ContinuousSupport
					when leftSupport.contactPad.currentPressure <= leftSupport.contactPad.maxAllowablePressure;
			}
		}
		
		state machine stateMachine : OperatingPhanes;
		
		// ---- Requirement satisfactions ----
		satisfy RestoreLineOfSight {
			subject = self;
		}
		satisfy NonSurgicalSolution {
			subject = self;
		}
		satisfy AdjustableLift {
			subject = leftSupport;
		}
		satisfy SafetyPressureLimit {
			subject = leftSupport.contactPad;
		}
		satisfy ComfortMonitoring {
			subject = self;
		}
	}
	
	// ---- Interface port definitions ----
	port def MechanicalInterface {
		attribute mountingDiameter : LengthUnit = 1.5 [mm];
	}
}
