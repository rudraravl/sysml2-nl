package 'Wedge System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WedgeAngle :> Real;
	attribute def SplittingForce :> ForceValue;
	attribute def InputForce :> ForceValue;
	attribute def SeparationDistance :> LengthValue;
	
	item def Material {
		attribute hardness : Real;
		attribute density : DensityValue;
		attribute yieldStrength : PressureValue;
	}
	
	item def AppliedLoad {
		attribute mass : MassValue;
		attribute force : ForceValue;
		attribute velocity : SpeedValue;
	}
	
	part def WedgeGeometry {
		attribute wedgeAngle : WedgeAngle;
		attribute length : LengthValue;
		attribute thickness : LengthValue;
		attribute surfaceArea : AreaValue;
	}
	
	port def ForceInputPort {
		in attribute appliedForce : ForceValue;
	}
	
	port def ForceOutputPort {
		out attribute normalForce : ForceValue;
		out attribute lateralForce : ForceValue;
	}
	
	part def WedgeMechanism {
		attribute geometry : WedgeGeometry;
		attribute material : Material;
		
		port inputPort : ForceInputPort;
		port leftOutputPort : ForceOutputPort;
		port rightOutputPort : ForceOutputPort;
	}
	
	action def CalculateMechanicalAdvantage {
		in attribute inputForce : InputForce;
		in attribute wedgeAngle : WedgeAngle;
		out attribute outputForce : SplittingForce;
		out attribute mechanicalAdvantage : Real;
	}
	
	action def ApplyInputForce {
		in attribute force : InputForce;
		in attribute wedgeAngle : WedgeAngle;
		out attribute effectiveForce : ForceValue;
		out attribute forceDistribution : Real;
	}
	
	action def SeparateMaterial {
		in attribute targetMaterial : Material;
		in attribute splittingForce : SplittingForce;
		in attribute wedgeThickness : LengthValue;
		out attribute separationDistance : LengthValue;
		out attribute separationComplete : Boolean;
	}
	
	action def PerformWedgeOperation {
		in attribute loadForce : ForceValue;
		in attribute angle : WedgeAngle;
		in attribute targetMat : Material;
		in attribute thickness : LengthValue;
		out attribute finalSeparation : LengthValue;
		out attribute isComplete : Boolean;
		
		first start;
		then action initialize {
			out wedgePositioned : Boolean;
		}
		then action applyForce : ApplyInputForce {
			in force = loadForce;
			in wedgeAngle = angle;
			out effectiveForce;
			out forceDistribution;
		}
		then action amplify : CalculateMechanicalAdvantage {
			in inputForce = loadForce;
			in wedgeAngle = angle;
			out outputForce;
			out mechanicalAdvantage;
		}
		then action separate : SeparateMaterial {
			in targetMaterial = targetMat;
			in splittingForce = amplify.outputForce;
			in wedgeThickness = thickness;
			out separationDistance;
			out separationComplete;
		}
		then assign finalSeparation := separate.separationDistance;
		then assign isComplete := separate.separationComplete;
		then done;
	}
	
	requirement def WedgeFunctionalRequirements {
		doc /* The wedge system shall convert applied input force into amplified perpendicular splitting forces to separate materials. */
		
		requirement <'1.1'> forceAmplificationRequirement {
			doc /* The wedge shall amplify input force proportional to the wedge angle geometry. */
			subject wedgeSystem : WedgeSystem;
			require constraint {
				wedgeSystem.generatedSplittingForce > wedgeSystem.appliedLoad.force
			}
		}
		
		requirement <'1.2'> materialSeparationRequirement {
			doc /* The wedge shall separate material perpendicular to the direction of applied force. */
			subject wedgeSystem : WedgeSystem;
			assume constraint {
				wedgeSystem.targetMaterial.hardness < 95.0
			}
			require constraint {
				wedgeSystem.separationAchieved > 0.0[mm]
			}
		}
		
		requirement <'1.3'> geometricConstraintRequirement {
			doc /* The wedge angle shall be between 5 and 40 degrees for effective operation. */
			subject wedge : WedgeMechanism;
			require constraint {
				wedge.geometry.wedgeAngle >= 5.0 and wedge.geometry.wedgeAngle <= 40.0
			}
		}
		
		requirement <'1.4'> structuralIntegrityRequirement {
			doc /* The wedge material yield strength shall exceed maximum applied stress. */
			subject wedge : WedgeMechanism;
			require constraint {
				wedge.material.yieldStrength > 300.0[MPa]
			}
		}
	}
	
	part def WedgeSystem {
		doc /* 
		A wedge system is a fundamental simple machine that transforms an applied force 
		into amplified perpendicular forces through geometric advantage. The primary function 
		is to separate, split, or lift materials by converting linear input force applied 
		to the blunt end into lateral forces along the inclined surfaces. The wedge operates 
		by driving its thin edge into material, generating normal forces perpendicular to 
		the inclined surfaces that push material apart with greater magnitude than the input force.
		The mechanical advantage depends on the wedge angle: smaller angles produce greater 
		force amplification but require longer displacement.
		*/
		
		part wedge : WedgeMechanism;
		part appliedLoad : AppliedLoad;
		attribute targetMaterial : Material;
		attribute generatedSplittingForce : SplittingForce;
		attribute separationAchieved : LengthValue;
	}
	
	part wedgeSystem : WedgeSystem {
		part :>> wedge {
			:>> geometry {
				:>> wedgeAngle = 20.0;
				:>> length = 250.0[mm];
				:>> thickness = 60.0[mm];
				:>> surfaceArea = 0.015[m^2];
			}
			:>> material {
				:>> hardness = 80.0;
				:>> density = 7850.0[kg/m^3];
				:>> yieldStrength = 450.0[MPa];
			}
		}
		
		part :>> appliedLoad {
			:>> mass = 12.0[kg];
			:>> force = 600.0[N];
			:>> velocity = 2.0[m/s];
		}
		
		attribute :>> targetMaterial {
			:>> hardness = 50.0;
			:>> density = 2500.0[kg/m^3];
			:>> yieldStrength = 150.0[MPa];
		}
		
		attribute :>> generatedSplittingForce = 1800.0[N];
		attribute :>> separationAchieved = 0.0[mm];
		
		perform action operation : PerformWedgeOperation {
			in loadForce = wedgeSystem.appliedLoad.force;
			in angle = wedgeSystem.wedge.geometry.wedgeAngle;
			in targetMat = wedgeSystem.targetMaterial;
			in thickness = wedgeSystem.wedge.geometry.thickness;
			out finalSeparation;
			out isComplete;
		}
	}
	
	requirement systemRequirements : WedgeFunctionalRequirements {
		subject wedgeSystem;
	}
}
