package NailClipperModel {
	private import ISQ::*;
	private import ScalarValues::*;

	unit mm;
	unit N;

	attribute def SqueezeForce;
	attribute def BladesContact;
	attribute def ReleaseForce;

	item def Nail {
		attribute thickness : LengthValue;
	}
	item def NailFragment;

	action def CutNailAction {
		in nail : Nail;
		out fragment : NailFragment;
	}

	part def PivotPin {
		port pinInterface;
		attribute yieldStrength : ForceValue;
		attribute maxAppliedForce : ForceValue;
	}

	part def Lever {
		port pivotInterface;
		port gripInterface;
	}

	part def UpperLever :> Lever;

	part def LowerLever :> Lever {
		part movingBlade : MovingBlade;
	}

	part def Blade {
		port cuttingEdge;
	}

	part def MovingBlade :> Blade;
	part def FixedBlade :> Blade;

	part def Body {
		part fixedBlade : FixedBlade;
	}

	part def NailClipper {
		attribute maxNailThickness : LengthValue = 2.0 [mm];
		attribute maxUserForce : ForceValue = 50.0 [N];

		port nailInputPort {
			in nail : Nail;
			out fragment : NailFragment;
		}

		part upperLever : UpperLever;
		part lowerLever : LowerLever;
		part pivotPin : PivotPin;
		part body : Body;

		connection pinUpper connect pivotPin.pinInterface to upperLever.pivotInterface;
		connection pinLower connect pivotPin.pinInterface to lowerLever.pivotInterface;

		state clipperBehavior : ClipperStates;
	}

	state def ClipperStates {
		entry; then open;
		state open;
		accept SqueezeForce then closing;
		state closing;
		accept BladesContact then cutting;
		state cutting {
			entry action cutNail : CutNailAction;
		}
		accept ReleaseForce then open;
	}

	part aNailClipper : NailClipper;

	requirement def CuttingPerformanceRequirement {
		subject clipper : NailClipper;
		attribute requiredMaxThickness : LengthValue = 2.0 [mm];
		attribute requiredMaxForce : ForceValue = 50.0 [N];
		require constraint {
			clipper.maxNailThickness <= requiredMaxThickness and
			clipper.maxUserForce <= requiredMaxForce
		}
	}

	requirement def PivotPinRobustnessRequirement {
		subject pin : PivotPin;
		require constraint { pin.yieldStrength > pin.maxAppliedForce }
	}

	requirement cuttingPerformance : CuttingPerformanceRequirement {
		subject clipper = aNailClipper;
	}

	requirement pivotPinRobustness : PivotPinRobustnessRequirement {
		subject pin = aNailClipper.pivotPin;
	}
}
