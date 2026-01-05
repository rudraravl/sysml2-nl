package 'Wing System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AngleValue :> Real;
	attribute def LiftCoefficientValue :> Real;
	attribute def DragCoefficientValue :> Real;
	
	item def Airflow {
		attribute velocity : SpeedValue;
		attribute density : DensityValue;
		attribute pressure : PressureValue;
		attribute angleOfAttack : AngleValue;
	}
	
	item def AerodynamicLoad {
		attribute liftForce : ForceValue;
		attribute dragForce : ForceValue;
		attribute pitchingMoment : TorqueValue;
	}
	
	port def AirflowPort {
		in item incomingAir : Airflow;
	}
	
	port def LoadPort {
		out item structuralLoad : AerodynamicLoad;
	}
	
	part def Airfoil {
		attribute chord : LengthValue;
		attribute thickness : LengthValue;
		attribute camber : LengthValue;
		attribute maxThicknessPosition : Real;
		
		port upperSurface : AirflowPort;
		port lowerSurface : AirflowPort;
	}
	
	part def Spar {
		attribute length : LengthValue;
		attribute crossSection : AreaValue;
		attribute material : String;
		attribute yieldStrength : PressureValue;
	}
	
	part def Rib {
		attribute height : LengthValue;
		attribute thickness : LengthValue;
		attribute spacing : LengthValue;
	}
	
	part def Skin {
		attribute thickness : LengthValue;
		attribute material : String;
		attribute area : AreaValue;
	}
	
	part def ControlSurface {
		attribute deflectionAngle : AngleValue;
		attribute maxDeflection : AngleValue;
		attribute surfaceArea : AreaValue;
		attribute hingeLine : LengthValue;
	}
	
	action def SenseAirflow {
		in airstream : Airflow;
		out measuredVelocity : SpeedValue;
		out measuredPressure : PressureValue;
		out measuredDensity : DensityValue;
		out measuredAngle : AngleValue;
	}
	
	action def ComputeLiftCoefficient {
		in angleOfAttack : AngleValue;
		in reynoldsNumber : Real;
		out liftCoefficient : LiftCoefficientValue;
	}
	
	action def ComputeDragCoefficient {
		in angleOfAttack : AngleValue;
		in liftCoefficient : LiftCoefficientValue;
		out dragCoefficient : DragCoefficientValue;
	}
	
	action def CalculateLift {
		in liftCoefficient : LiftCoefficientValue;
		in dynamicPressure : PressureValue;
		in wingArea : AreaValue;
		out liftForce : ForceValue;
	}
	
	action def CalculateDrag {
		in dragCoefficient : DragCoefficientValue;
		in dynamicPressure : PressureValue;
		in wingArea : AreaValue;
		out dragForce : ForceValue;
	}
	
	action def ComputeReynoldsNumber {
		in velocity : SpeedValue;
		in density : DensityValue;
		in characteristicLength : Real;
		out reynoldsNumber : Real;
	}
	
	action def CalculateDynamicPressure {
		in density : DensityValue;
		in velocity : SpeedValue;
		out dynamicPressure : PressureValue;
	}
	
	action def GenerateAerodynamicForces {
		in incomingAirflow : Airflow;
		in planformArea : AreaValue;
		in aspectRatio : Real;
		out aerodynamicLoad : AerodynamicLoad;
		
		first start;
		then action sense : SenseAirflow {
			in airstream = incomingAirflow;
			out measuredVelocity;
			out measuredPressure;
			out measuredDensity;
			out measuredAngle;
		}
		then action computeReynolds : ComputeReynoldsNumber {
			in velocity = sense.measuredVelocity;
			in density = sense.measuredDensity;
			in characteristicLength = 2.0;
			out reynoldsNumber;
		}
		then action computeCL : ComputeLiftCoefficient {
			in angleOfAttack = sense.measuredAngle;
			in reynoldsNumber = computeReynolds.reynoldsNumber;
			out liftCoefficient;
		}
		then action computeCD : ComputeDragCoefficient {
			in angleOfAttack = sense.measuredAngle;
			in liftCoefficient = computeCL.liftCoefficient;
			out dragCoefficient;
		}
		then action calcDynamicPressure : CalculateDynamicPressure {
			in density = sense.measuredDensity;
			in velocity = sense.measuredVelocity;
			out dynamicPressure;
		}
		then action calcLift : CalculateLift {
			in liftCoefficient = computeCL.liftCoefficient;
			in dynamicPressure = calcDynamicPressure.dynamicPressure;
			in wingArea = planformArea;
			out liftForce;
		}
		then action calcDrag : CalculateDrag {
			in dragCoefficient = computeCD.dragCoefficient;
			in dynamicPressure = calcDynamicPressure.dynamicPressure;
			in wingArea = planformArea;
			out dragForce;
		}
		then assign aerodynamicLoad.liftForce := calcLift.liftForce;
		then assign aerodynamicLoad.dragForce := calcDrag.dragForce;
		then assign aerodynamicLoad.pitchingMoment := 0.0;
		then done;
	}
	
	attribute def AirflowDetectedSignal;
	attribute def ControlInputSignal;
	attribute def ControlNeutralSignal;
	attribute def CriticalAngleSignal;
	attribute def AngleRecoveredSignal;
	attribute def AirflowCeasedSignal;
	
	state def WingOperationalStates {
		entry; then idle;
		
		state idle {
			entry action initIdle {
				private attribute currentLoad : Real := 0.0;
			}
		}
		
		state generatingLift {
			entry action initGenerating {
				private attribute isActive : Boolean := true;
			}
			do action continuousLiftGeneration;
		}
		
		state maneuvering {
			entry action initManeuvering {
				private attribute controlActive : Boolean := true;
			}
			do action adjustControlSurfaces;
		}
		
		state stalled {
			entry action initStalled {
				private attribute stallWarning : Boolean := true;
			}
		}
		
		transition idleToGenerating
			first idle
			accept airflowDetected : AirflowDetectedSignal
			then generatingLift;
			
		transition generatingToManeuvering
			first generatingLift
			accept controlInput : ControlInputSignal
			then maneuvering;
			
		transition maneuveringToGenerating
			first maneuvering
			accept controlNeutral : ControlNeutralSignal
			then generatingLift;
			
		transition generatingToStalled
			first generatingLift
			accept criticalAngle : CriticalAngleSignal
			then stalled;
			
		transition stalledToGenerating
			first stalled
			accept angleRecovered : AngleRecoveredSignal
			then generatingLift;
			
		transition generatingToIdle
			first generatingLift
			accept airflowCeased : AirflowCeasedSignal
			then idle;
	}
	
	part def Wing {
		attribute span : LengthValue;
		attribute planformArea : AreaValue;
		attribute aspectRatio : Real;
		attribute sweepAngle : AngleValue;
		attribute dihedralAngle : AngleValue;
		attribute taperRatio : Real;
		
		part airfoilSections : Airfoil[*] {
			attribute spanwisePosition : LengthValue;
		}
		
		part structure {
			part frontSpar : Spar {
				attribute :>> length;
				attribute :>> material = "Aluminum 7075-T6";
			}
			part rearSpar : Spar {
				attribute :>> length;
				attribute :>> material = "Aluminum 7075-T6";
			}
			part ribs : Rib[*] {
				attribute ribCount : Integer;
			}
			part upperSkin : Skin {
				attribute :>> material = "Aluminum 2024-T3";
			}
			part lowerSkin : Skin {
				attribute :>> material = "Aluminum 2024-T3";
			}
		}
		
		part controls {
			part aileron : ControlSurface {
				attribute :>> maxDeflection = 25.0;
			}
			part flap : ControlSurface {
				attribute :>> maxDeflection = 40.0;
			}
		}
		
		port airflowInterface : AirflowPort;
		port loadInterface : LoadPort;
		
		perform action generateForces : GenerateAerodynamicForces {
			in incomingAirflow;
			in planformArea;
			in aspectRatio;
			out aerodynamicLoad;
		}
		
		exhibit state operationalState : WingOperationalStates;
	}
	
	part wingSystem : Wing {
		attribute :>> span = 12.0 [m];
		attribute :>> planformArea = 24.0 [m^2];
		attribute :>> aspectRatio = 6.0;
		attribute :>> sweepAngle = 20.0;
		attribute :>> dihedralAngle = 4.0;
		attribute :>> taperRatio = 0.6;
		
		part :>> airfoilSections[6] {
			attribute :>> chord = 2.0 [m];
			attribute :>> thickness = 0.24 [m];
			attribute :>> camber = 0.05 [m];
			attribute :>> maxThicknessPosition = 0.3;
		}
		
		part :>> structure {
			part :>> frontSpar {
				attribute :>> length = 12.0 [m];
				attribute :>> crossSection = 0.012 [m^2];
				attribute :>> yieldStrength = 500.0e6 [Pa];
			}
			part :>> rearSpar {
				attribute :>> length = 12.0 [m];
				attribute :>> crossSection = 0.010 [m^2];
				attribute :>> yieldStrength = 500.0e6 [Pa];
			}
			part :>> ribs[24] {
				attribute :>> height = 0.24 [m];
				attribute :>> thickness = 0.003 [m];
				attribute :>> spacing = 0.5 [m];
				attribute :>> ribCount = 24;
			}
			part :>> upperSkin {
				attribute :>> thickness = 0.002 [m];
				attribute :>> area = 12.0 [m^2];
			}
			part :>> lowerSkin {
				attribute :>> thickness = 0.002 [m];
				attribute :>> area = 12.0 [m^2];
			}
		}
		
		part :>> controls {
			part :>> aileron {
				attribute :>> surfaceArea = 1.8 [m^2];
				attribute :>> hingeLine = 0.75 [m];
				attribute :>> deflectionAngle = 0.0;
			}
			part :>> flap {
				attribute :>> surfaceArea = 2.4 [m^2];
				attribute :>> hingeLine = 0.65 [m];
				attribute :>> deflectionAngle = 0.0;
			}
		}
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The wing system shall generate aerodynamic lift force to support aircraft weight during flight operations. */
		
		subject wing : Wing;
		
		require constraint {
			wing.loadInterface.structuralLoad.liftForce >= 60000.0 [N]
		}
	}
	
	requirement def StructuralRequirement {
		doc /* The wing structure shall withstand maximum aerodynamic loads with a safety factor of 1.5. */
		
		subject wingStructure : Wing::structure;
		
		require constraint {
			wingStructure.frontSpar.yieldStrength >= 500.0e6 [Pa]
		}
	}
	
	requirement def ControlRequirement {
		doc /* The wing control surfaces shall provide adequate roll control authority for maneuvering. */
		
		subject controls : Wing::controls;
		
		require constraint {
			controls.aileron.maxDeflection >= 20.0
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The wing shall maintain a lift-to-drag ratio greater than 12 during cruise conditions. */
		
		subject wing : Wing;
	}
	
	requirement wingSystemRequirements {
		doc /* The wing system shall satisfy all functional, structural, and performance requirements. */
		
		require req1 : PrimaryFunctionRequirement;
		require req2 : StructuralRequirement;
		require req3 : ControlRequirement;
		require req4 : EfficiencyRequirement;
	}
}
