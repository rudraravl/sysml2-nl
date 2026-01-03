package PtosisCrutchSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def EyelidElevation :> LengthValue;
	attribute def SupportForce :> ForceValue;
	attribute def VisualFieldAngle :> Real;
	
	item def MechanicalLoad {
		attribute force : ForceValue;
		attribute contactPoint : LengthValue;
	}
	
	item def PositionCommand {
		attribute targetElevation : LengthValue;
		attribute adjustmentAngle : Real;
	}
	
	item def ComfortFeedback {
		attribute pressureLevel : ForceValue;
		attribute irritationScore : Real;
	}
	
	port def MechanicalSupportPort {
		out item supportLoad : MechanicalLoad;
	}
	
	port def AdjustmentControlPort {
		in item positionCmd : PositionCommand;
		out attribute currentPosition : LengthValue;
	}
	
	port def ComfortMonitorPort {
		in item feedback : ComfortFeedback;
	}
	
	part def EyeglassFrame {
		doc /* Spectacle frame providing mounting structure for crutch mechanism. */
		attribute frameMaterial : String;
		attribute frameWidth : LengthValue;
		attribute bridgeWidth : LengthValue;
	}
	
	part def CrutchBar {
		doc /* Adjustable support bar extending from frame to contact eyelid. */
		attribute barLength : LengthValue;
		attribute barAngle : Real;
		attribute appliedForce : ForceValue;
		
		port supportInterface : MechanicalSupportPort;
		port adjustmentInterface : AdjustmentControlPort;
	}
	
	part def ContactPad {
		doc /* Soft biocompatible pad providing gentle contact with eyelid tissue. */
		attribute padMaterial : String;
		attribute padThickness : LengthValue;
		attribute contactArea : Real;
	}
	
	part def AdjustmentScrew {
		doc /* Precision screw mechanism for fine-tuning crutch position. */
		attribute threadPitch : LengthValue;
		attribute rotationAngle : Real;
		attribute lockingTorque : Real;
	}
	
	part def Eyelid {
		doc /* Human eyelid affected by ptosis requiring mechanical support. */
		attribute naturalPosition : LengthValue;
		attribute currentElevation : LengthValue;
		attribute mass : MassValue;
		
		port contactSurface : MechanicalSupportPort;
		port comfortSensor : ComfortMonitorPort;
	}
	
	action def AssessEyelidDroop {
		doc /* Measure degree of eyelid ptosis and pupil obstruction. */
		in eyelidPosition : LengthValue;
		in pupilCenterline : LengthValue;
		out droopSeverity : LengthValue;
		out visualObstruction : Real;
		
		assign droopSeverity := pupilCenterline - eyelidPosition;
		assign visualObstruction := (droopSeverity / pupilCenterline) * 100.0;
	}
	
	action def CalculateSupportParameters {
		doc /* Determine required lift force and optimal contact position. */
		in droopSeverity : LengthValue;
		in eyelidMass : MassValue;
		out requiredLift : LengthValue;
		out supportForce : ForceValue;
		out optimalAngle : Real;
		
		assign requiredLift := droopSeverity + 1.0 [SI::mm];
		assign supportForce := (eyelidMass * 9.81 [SI::'m/s²']) + 0.3 [SI::N];
		assign optimalAngle := 35.0;
	}
	
	action def AdjustCrutchPosition {
		doc /* Modify crutch bar position to achieve target eyelid elevation. */
		in targetLift : LengthValue;
		in currentPosition : LengthValue;
		in optimalAngle : Real;
		out newPosition : LengthValue;
		out angleAdjustment : Real;
		out screwRotations : Real;
		
		assign newPosition := currentPosition + targetLift;
		assign angleAdjustment := optimalAngle;
		assign screwRotations := targetLift / 0.5 [SI::mm];
	}
	
	action def ApplyMechanicalSupport {
		doc /* Continuously provide upward force to elevate and maintain eyelid position. */
		in supportForce : ForceValue;
		in contactPosition : LengthValue;
		inout eyelidElevation : LengthValue;
		
		assign eyelidElevation := contactPosition;
	}
	
	action def MonitorPatientComfort {
		doc /* Assess comfort level and detect excessive pressure or irritation. */
		in appliedForce : ForceValue;
		in contactDuration : TimeValue;
		out comfortScore : Real;
		out pressureWarning : Boolean;
		
		decide;
			if appliedForce > 1.5 [SI::N] then assignPressureTrue;
			else assignPressureFalse;
		
		action assignPressureTrue {
			assign pressureWarning := true;
		}
		
		action assignPressureFalse {
			assign pressureWarning := false;
		}
		
		then assign comfortScore := 100.0 - (appliedForce / 0.02 [SI::N]);
	}
	
	state def CrutchOperationalStates {
		doc /* State machine governing ptosis crutch operational modes. */
		
		entry; then inactive;
		
		state inactive {
			doc /* Crutch mounted but not providing active support. */
		}
		
		transition inactive_to_evaluating
			first inactive
			accept at evaluationTriggered
			then evaluating;
		
		state evaluating {
			doc /* Assessing eyelid droop and calculating support requirements. */
			entry; do action assess : AssessEyelidDroop;
			do action calculate : CalculateSupportParameters;
		}
		
		transition evaluating_to_positioning
			first evaluating
			if calculate.requiredLift > 0.5 [SI::mm]
			then positioning;
		
		transition evaluating_to_inactive
			first evaluating
			if calculate.requiredLift <= 0.5 [SI::mm]
			then inactive;
		
		state positioning {
			doc /* Adjusting crutch bar to optimal support position. */
			do action adjust : AdjustCrutchPosition;
		}
		
		transition positioning_to_supporting
			first positioning
			then supporting;
		
		state supporting {
			doc /* Actively providing mechanical lift to eyelid. */
			do action support : ApplyMechanicalSupport;
			do action monitor : MonitorPatientComfort;
		}
		
		transition supporting_to_positioning
			first supporting
			if monitor.pressureWarning or monitor.comfortScore < 60.0
			then positioning;
		
		transition supporting_to_inactive
			first supporting
			accept at supportReleased
			then inactive;
	}
	
	action def ProvidePtosisCorrection {
		doc /* Primary system function: mechanically elevate drooping eyelid to restore unobstructed vision. */
		
		first start;
		
		then merge operationCycle;
		
		then action assessDroop : AssessEyelidDroop {
			in eyelidPosition;
			in pupilCenterline = 5.0 [SI::mm];
			out droopSeverity;
			out visualObstruction;
		}
		
		then action calculateSupport : CalculateSupportParameters {
			in droopSeverity = assessDroop.droopSeverity;
			in eyelidMass = 0.05 [SI::g];
			out requiredLift;
			out supportForce;
			out optimalAngle;
		}
		
		then decide;
			if calculateSupport.requiredLift > 0.5 [SI::mm] then adjustPosition;
			else operationCycle;
		
		action adjustPosition : AdjustCrutchPosition {
			in targetLift = calculateSupport.requiredLift;
			in currentPosition = 0.0 [SI::mm];
			in optimalAngle = calculateSupport.optimalAngle;
			out newPosition;
			out angleAdjustment;
			out screwRotations;
		}
		
		then action applySupport : ApplyMechanicalSupport {
			in supportForce = calculateSupport.supportForce;
			in contactPosition = adjustPosition.newPosition;
			inout eyelidElevation;
		}
		
		then action monitorComfort : MonitorPatientComfort {
			in appliedForce = calculateSupport.supportForce;
			in contactDuration = 3600.0 [SI::s];
			out comfortScore;
			out pressureWarning;
		}
		
		then decide;
			if monitorComfort.comfortScore >= 70.0 and not monitorComfort.pressureWarning then operationCycle;
			else adjustPosition;
		
		then operationCycle;
	}
	
	part ptosisCrutchAssembly {
		doc /* Complete ptosis crutch device providing mechanical eyelid elevation. */
		
		attribute deviceIdentifier : String;
		attribute fittingSide : String;
		
		part frame : EyeglassFrame {
			attribute frameMaterial = "titanium alloy";
			attribute frameWidth = 140.0 [SI::mm];
			attribute bridgeWidth = 18.0 [SI::mm];
		}
		
		part leftCrutch : CrutchBar {
			attribute barLength = 15.0 [SI::mm];
			attribute barAngle = 35.0;
			attribute appliedForce = 0.8 [SI::N];
		}
		
		part rightCrutch : CrutchBar {
			attribute barLength = 15.0 [SI::mm];
			attribute barAngle = 35.0;
			attribute appliedForce = 0.8 [SI::N];
		}
		
		part leftPad : ContactPad {
			attribute padMaterial = "medical-grade silicone";
			attribute padThickness = 1.5 [SI::mm];
			attribute contactArea = 12.0;
		}
		
		part rightPad : ContactPad {
			attribute padMaterial = "medical-grade silicone";
			attribute padThickness = 1.5 [SI::mm];
			attribute contactArea = 12.0;
		}
		
		part leftAdjuster : AdjustmentScrew {
			attribute threadPitch = 0.5 [SI::mm];
			attribute rotationAngle = 0.0;
			attribute lockingTorque = 0.15;
		}
		
		part rightAdjuster : AdjustmentScrew {
			attribute threadPitch = 0.5 [SI::mm];
			attribute rotationAngle = 0.0;
			attribute lockingTorque = 0.15;
		}
		
		perform action correctLeftEye[*] ordered references ProvidePtosisCorrection;
		perform action correctRightEye[*] ordered references ProvidePtosisCorrection;
		
		connection leftCrutchToPad connect leftCrutch.supportInterface to leftPad;
		connection rightCrutchToPad connect rightCrutch.supportInterface to rightPad;
		connection leftAdjusterControl connect leftAdjuster to leftCrutch.adjustmentInterface;
		connection rightAdjusterControl connect rightAdjuster to rightCrutch.adjustmentInterface;
	}
	
	part clinicalContext {
		doc /* Patient usage context for ptosis crutch system. */
		
		part device : ptosisCrutchAssembly;
		
		ref part leftEyelid : Eyelid {
			attribute naturalPosition = 2.0 [SI::mm];
			attribute currentElevation = 2.0 [SI::mm];
			attribute mass = 0.05 [SI::g];
		}
		
		ref part rightEyelid : Eyelid {
			attribute naturalPosition = 2.0 [SI::mm];
			attribute currentElevation = 2.0 [SI::mm];
			attribute mass = 0.05 [SI::g];
		}
		
		flow of MechanicalLoad from device.leftCrutch.supportInterface to leftEyelid.contactSurface;
		flow of MechanicalLoad from device.rightCrutch.supportInterface to rightEyelid.contactSurface;
		flow of ComfortFeedback from leftEyelid.comfortSensor to device.leftCrutch;
		flow of ComfortFeedback from rightEyelid.comfortSensor to device.rightCrutch;
	}
	
	requirement def FunctionalRequirement {
		doc /* Functional capability requirements for ptosis correction. */
		subject device;
	}
	
	requirement def SafetyRequirement {
		doc /* Patient safety and biocompatibility requirements. */
		subject device;
	}
	
	requirement def PerformanceRequirement {
		doc /* Performance specifications for eyelid elevation. */
		subject device;
	}
	
	requirement <'REQ-001'> eyelidElevationCapability : FunctionalRequirement {
		doc /* System shall elevate eyelid by minimum 3mm to clear pupil margin. */
		subject device = ptosisCrutchAssembly;
		
		require constraint {
			device.leftCrutch.barLength >= 10.0 [SI::mm] and
			device.rightCrutch.barLength >= 10.0 [SI::mm]
		}
	}
	
	requirement <'REQ-002'> maximumContactPressure : SafetyRequirement {
		doc /* Contact force shall not exceed 1.5N to prevent tissue damage. */
		subject device = ptosisCrutchAssembly;
		
		require constraint {
			device.leftCrutch.appliedForce <= 1.5 [SI::N] and
			device.rightCrutch.appliedForce <= 1.5 [SI::N]
		}
	}
	
	requirement <'REQ-003'> adjustmentPrecision : PerformanceRequirement {
		doc /* Position adjustment shall provide 0.5mm incremental control. */
		subject device = ptosisCrutchAssembly;
		
		require constraint {
			device.leftAdjuster.threadPitch == 0.5 [SI::mm] and
			device.rightAdjuster.threadPitch == 0.5 [SI::mm]
		}
	}
	
	requirement <'REQ-004'> biocompatibleMaterials : SafetyRequirement {
		doc /* All tissue-contact materials shall be medical-grade and hypoallergenic. */
		subject device = ptosisCrutchAssembly;
		
		require constraint {
			device.leftPad.padMaterial == "medical-grade silicone" and
			device.rightPad.padMaterial == "medical-grade silicone"
		}
	}
	
	requirement <'REQ-005'> structuralIntegrity : SafetyRequirement {
		doc /* Frame and crutch components shall withstand normal use forces without deformation. */
		subject device = ptosisCrutchAssembly;
		
		require constraint {
			device.frame.frameMaterial == "titanium alloy"
		}
	}
	
	requirement <'MISSION-001'> primaryMission : FunctionalRequirement {
		doc /* System shall mechanically elevate ptotic eyelids to restore functional vision field. */
		
		require eyelidElevationCapability;
		require maximumContactPressure;
		require adjustmentPrecision;
		require biocompatibleMaterials;
		require structuralIntegrity;
	}
}
