package 'Lever System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def EffortArmLength :> LengthValue;
	attribute def LoadArmLength :> LengthValue;
	attribute def MechanicalAdvantage :> Real;
	
	item def ForceTransfer {
		attribute magnitude : ForceValue;
		attribute direction : String;
	}
	
	part def Fulcrum {
		attribute position : LengthValue;
		port pivotPoint {
			attribute reactionForce : ForceValue;
		}
	}
	
	part def LeverArm {
		attribute totalLength : LengthValue;
		attribute rigidity : String;
		port effortPoint {
			attribute appliedForce : ForceValue;
		}
		port loadPoint {
			attribute outputForce : ForceValue;
		}
		port pivotConnection;
	}
	
	part def LoadMass {
		attribute mass : MassValue;
		attribute weight : ForceValue;
		port forceInput;
	}
	
	part def EffortSource {
		attribute appliedForce : ForceValue;
		port forceOutput;
	}
	
	part def LeverSystem {
		attribute effortArmLength : LengthValue;
		attribute loadArmLength : LengthValue;
		attribute mechanicalAdvantage : Real;
		
		part fulcrum : Fulcrum {
			attribute position : LengthValue;
		}
		
		part arm : LeverArm {
			attribute totalLength : LengthValue;
		}
		
		part load : LoadMass {
			attribute mass : MassValue;
			attribute weight : ForceValue;
		}
		
		part effort : EffortSource {
			attribute appliedForce : ForceValue;
		}
		
		connection pivotConnect connect arm.pivotConnection to fulcrum.pivotPoint;
		connection effortConnect connect effort.forceOutput to arm.effortPoint;
		connection loadConnect connect arm.loadPoint to load.forceInput;
		
		perform action amplifyForce;
	}
	
	action def ComputeMechanicalAdvantage {
		in effortArm : LengthValue;
		in loadArm : LengthValue;
		out advantage : Real;
	}
	
	action def ComputeOutputForce {
		in inputForce : ForceValue;
		in advantage : Real;
		out outputForce : ForceValue;
	}
	
	action def ComputeDisplacements {
		in effortDisplacement : LengthValue;
		in advantage : Real;
		out loadDisplacement : LengthValue;
	}
	
	action def AmplifyForce {
		in effortForce : ForceValue;
		in effortArmLength : LengthValue;
		in loadArmLength : LengthValue;
		out loadForce : ForceValue;
		out mechanicalAdvantage : Real;
		out effortMovement : LengthValue;
		out loadMovement : LengthValue;
		
		first start;
		then action computeAdvantage : ComputeMechanicalAdvantage {
			in effortArm = effortArmLength;
			in loadArm = loadArmLength;
			out advantage : Real;
		}
		then action computeLoad : ComputeOutputForce {
			in inputForce = effortForce;
			in advantage = computeAdvantage.advantage;
			out outputForce : ForceValue;
		}
		then action computeMovement : ComputeDisplacements {
			in effortDisplacement : LengthValue;
			in advantage = computeAdvantage.advantage;
			out loadDisplacement : LengthValue;
		}
		then assign loadForce := computeLoad.outputForce;
		then assign mechanicalAdvantage := computeAdvantage.advantage;
		then assign effortMovement := computeMovement.effortDisplacement;
		then assign loadMovement := computeMovement.loadDisplacement;
		then done;
	}
	
	attribute def EffortAppliedSignal;
	attribute def EffortReleasedSignal;
	
	state def LeverOperationStates {
		entry; then atRest;
		
		state atRest {
			entry assign isActive := false;
		}
		
		transition atRest_to_applying
			first atRest
			accept effortApplied : EffortAppliedSignal
			then applying;
		
		state applying {
			entry assign isActive := true;
			do action applyForce : AmplifyForce;
		}
		
		transition applying_to_lifting
			first applying
			if outputForce > loadWeight
			then lifting;
		
		state lifting {
			do action maintainForce : AmplifyForce;
		}
		
		transition lifting_to_holding
			first lifting
			if displacement >= targetHeight
			then holding;
		
		state holding;
		
		transition holding_to_lowering
			first holding
			accept effortReleased : EffortReleasedSignal
			then lowering;
		
		state lowering;
		
		transition lowering_to_atRest
			first lowering
			if displacement <= 0.0
			then atRest;
		
		attribute isActive : Boolean;
		attribute outputForce : ForceValue;
		attribute loadWeight : ForceValue;
		attribute displacement : LengthValue;
		attribute targetHeight : LengthValue;
	}
	
	part leverSystemInstance : LeverSystem {
		attribute effortArmLength = 2.0 [SI::m];
		attribute loadArmLength = 0.5 [SI::m];
		attribute mechanicalAdvantage = 4.0;
		
		part fulcrum {
			attribute position = 0.5 [SI::m];
		}
		
		part arm {
			attribute totalLength = 2.5 [SI::m];
		}
		
		part load {
			attribute mass = 100.0 [SI::kg];
			attribute weight = 980.0 [SI::N];
		}
		
		part effort {
			attribute appliedForce = 250.0 [SI::N];
		}
		
		exhibit state operation : LeverOperationStates;
		
		perform action amplifyForce : AmplifyForce {
			in effortForce = effort.appliedForce;
			in effortArmLength = leverSystemInstance.effortArmLength;
			in loadArmLength = leverSystemInstance.loadArmLength;
			out loadForce : ForceValue;
			out mechanicalAdvantage : Real;
			out effortMovement : LengthValue;
			out loadMovement : LengthValue;
		}
	}
	
	requirement def ForceAmplificationRequirement {
		doc /* The lever system shall amplify the input effort force by the mechanical advantage ratio determined by the ratio of effort arm length to load arm length. */
		
		subject system : LeverSystem;
		
		require constraint {
			system.mechanicalAdvantage == system.effortArmLength / system.loadArmLength
		}
	}
	
	requirement def WorkConservationRequirement {
		doc /* The lever system shall conserve mechanical work such that the work input equals the work output, accounting for the inverse relationship between force and displacement. */
		
		subject system : LeverSystem;
	}
	
	requirement def StructuralIntegrityRequirement {
		doc /* The lever arm shall maintain structural integrity and rigidity under maximum applied loads without deformation or failure. */
		
		subject arm : LeverArm;
	}
	
	requirement def FulcrumStabilityRequirement {
		doc /* The fulcrum shall provide stable support and resist displacement under reaction forces generated during lever operation. */
		
		subject fulcrum : Fulcrum;
	}
	
	requirement leverSystemRequirements {
		doc /* The lever system shall provide mechanical advantage to amplify applied effort force, enabling the movement of loads greater than the effort force alone could achieve. */
		
		subject system : LeverSystem;
		
		require forceAmplification : ForceAmplificationRequirement;
		require workConservation : WorkConservationRequirement;
		require structuralIntegrity : StructuralIntegrityRequirement;
		require fulcrumStability : FulcrumStabilityRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'Lever System'::*;

    part leverSystemInstance : Fulcrum {
        exhibit state sm : LeverOperationStates;
    }

    action orchestrator {
        attribute testEffortArm : LengthValue;
        attribute testLoadArm : LengthValue;
        action actionProbe : ComputeMechanicalAdvantage {
            in effortArm = testEffortArm;
            in loadArm = testLoadArm;
        }
        first actionProbe;
    }
}
