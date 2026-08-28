package 'Hydraulic Plunger System' {
	private import ScalarValues::Real;
	private import ISQ::*;

	item def HydraulicFluid {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}

	port def FluidPort {
		out item fluid : HydraulicFluid;
	}

	part def PlungerHead {
		attribute area : AreaValue;
	}

	part def PlungerShaft;

	part def Seal;

	part def PlungerAssembly {
		part head : PlungerHead[1];
		part shaft : PlungerShaft[1];
		part seal : Seal[1];
		attribute appliedForce : ForceValue;
		attribute strokePosition : LengthValue;
	}

	part def Cylinder {
		port fluidOutPort : FluidPort[1];
		attribute maxStroke : LengthValue;
		attribute maxPressure : PressureValue;
		attribute chamberVolume : VolumeValue;
		item workingFluid : HydraulicFluid[1];
	}

	attribute def StartSignal;
	attribute def EndOfStrokeSignal;
	attribute def RetractSignal;
	attribute def HomeSignal;

	action def DisplaceFluid {
		in appliedForce : ForceValue;
		in headArea : AreaValue;
		out generatedPressure : PressureValue;
		out displacedVolume : VolumeValue;
	}

	action def ReturnToIdle {
		out strokePosition : LengthValue;
	}

	state def PlungerStates;

	requirement def PressureGeneration {
		subject plungerSystem : HydraulicPlungerSystem;
		attribute appliedForce : ForceValue;
		attribute headArea : AreaValue;
		attribute generatedPressure : PressureValue;
		constraint pressureEquation {
			generatedPressure == appliedForce / headArea
		}
	}

	requirement def SafetyLimits {
		subject plungerSystem : HydraulicPlungerSystem;
		attribute maxStrokeLength : LengthValue;
		attribute maxPressureLimit : PressureValue;
		attribute currentStroke : LengthValue;
		attribute currentPressure : PressureValue;
		constraint strokeLimit {
			currentStroke <= maxStrokeLength
		}
		constraint pressureLimit {
			currentPressure <= maxPressureLimit
		}
	}

	part def HydraulicPlungerSystem {
		part plunger : PlungerAssembly {
			part head : PlungerHead {
				attribute area : AreaValue = 0.005 [m^2];
			}
			part shaft : PlungerShaft;
			part seal : Seal;
			attribute appliedForce : ForceValue;
			attribute strokePosition : LengthValue = 0.0 [m];
		}

		part cylinder : Cylinder {
			port fluidOutPort : FluidPort;
			attribute maxStroke : LengthValue = 0.1 [m];
			attribute maxPressure : PressureValue = 20000000 [Pa];
			attribute chamberVolume : VolumeValue = 0.0005 [m^3];
			item workingFluid : HydraulicFluid[1] {
				attribute volume : VolumeValue = 0.0005 [m^3];
				attribute pressure : PressureValue = 0.0 [Pa];
			}
		}

		attribute currentStroke : LengthValue = plunger.strokePosition;
		attribute currentPressure : PressureValue = cylinder.workingFluid.pressure;

		port fluidOutPort : FluidPort;

		flow of fluid : HydraulicFluid
			from cylinder.fluidOutPort.fluid to fluidOutPort.fluid;

		assert pressureEquation {
			cylinder.workingFluid.pressure ==
				plunger.appliedForce / plunger.head.area
		}

		assert volumeDisplacement {
			cylinder.workingFluid.volume ==
				cylinder.chamberVolume
				- plunger.strokePosition * plunger.head.area
		}

		state plungerStates : PlungerStates {
			entry; then idle;
			state idle;
			accept StartSignal then extending;
			state extending {
				do action displaceFluid : DisplaceFluid {
					in appliedForce = plunger.appliedForce;
					in headArea = plunger.head.area;
					out generatedPressure = cylinder.workingFluid.pressure;
				}
			}
			accept EndOfStrokeSignal then extended;
			state extended;
			accept RetractSignal then retracting;
			state retracting {
				do action returnToIdle : ReturnToIdle {
					out strokePosition = plunger.strokePosition;
				}
			}
			accept HomeSignal then idle;
		}

		requirement pressureGeneration : PressureGeneration {
			subject plungerSystem = this;
			attribute appliedForce = plunger.appliedForce;
			attribute headArea = plunger.head.area;
			attribute generatedPressure = currentPressure;
		}

		requirement safetyLimits : SafetyLimits {
			subject plungerSystem = this;
			attribute maxStrokeLength = cylinder.maxStroke;
			attribute maxPressureLimit = cylinder.maxPressure;
			attribute currentStroke = currentStroke;
			attribute currentPressure = currentPressure;
		}

		satisfy pressureGeneration;
		satisfy safetyLimits;
	}

	part system : HydraulicPlungerSystem;
}
