package 'Archimedes Screw System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute def FlowRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def InclinationAngle :> ISQ::PlaneAngleValue {
		attribute :>> num : Real;
		attribute :>> mRef : PlaneAngleUnit;
	}
	
	attribute def WaterLevel :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}
	
	attribute def StartCommand;
	attribute def StopCommand;
	
	item def Water {
		attribute volume : VolumeValue;
		attribute elevation : LengthValue;
	}
	
	part def HelicalBlade {
		attribute pitchLength : LengthValue;
		attribute bladeThickness : LengthValue;
		attribute numberOfTurns : Real;
	}
	
	part def CylindricalShaft {
		attribute shaftDiameter : LengthValue;
		attribute shaftLength : LengthValue;
		attribute material : String;
	}
	
	part def TubularHousing {
		attribute housingDiameter : LengthValue;
		attribute housingLength : LengthValue;
		attribute wallThickness : LengthValue;
	}
	
	part def DriveMotor {
		attribute ratedPower : PowerValue;
		attribute maxSpeed : AngularVelocityValue;
		port motorOutput {
			out rotationalSpeed : RotationalSpeed;
			out torque : TorqueValue;
		}
	}
	
	part def LowerReservoir {
		attribute capacity : VolumeValue;
		attribute currentLevel : WaterLevel;
		port waterIntake {
			out item waterFlow : Water;
			out intakeLevel : WaterLevel;
		}
	}
	
	part def UpperReservoir {
		attribute capacity : VolumeValue;
		attribute currentLevel : WaterLevel;
		port waterDischarge {
			in item waterFlow : Water;
		}
	}
	
	part def ArchimedesScrewAssembly {
		attribute inclination : InclinationAngle;
		attribute efficiency : Real;
		
		part shaft : CylindricalShaft {
			attribute shaftDiameter = 0.15 [SI::m];
			attribute shaftLength = 5.0 [SI::m];
			attribute material = "steel";
		}
		
		part blade : HelicalBlade {
			attribute pitchLength = 0.8 [SI::m];
			attribute bladeThickness = 0.01 [SI::m];
			attribute numberOfTurns = 6.0;
		}
		
		part housing : TubularHousing {
			attribute housingDiameter = 0.5 [SI::m];
			attribute housingLength = 5.0 [SI::m];
			attribute wallThickness = 0.005 [SI::m];
		}
		
		port lowerEnd {
			in item waterIn : Water;
			in rotationIn : RotationalSpeed;
		}
		
		port upperEnd {
			out item waterOut : Water;
		}
	}
	
	action def RotateScrew {
		in currentSpeed : RotationalSpeed;
		in targetSpeed : RotationalSpeed;
		out actualSpeed : RotationalSpeed;
	}
	
	action def LiftWater {
		in rotationSpeed : RotationalSpeed;
		in inclinationAngle : InclinationAngle;
		in lowerLevel : WaterLevel;
		out flowRate : FlowRate;
	}
	
	action def MonitorWaterLevel {
		in reservoirLevel : WaterLevel;
		out levelStatus : Boolean;
	}
	
	action def PumpWaterContinuously {
		in screwInclination : InclinationAngle;
		in sourceLevelIn : WaterLevel;
		in targetSpeed : RotationalSpeed;
		out deliveredFlow : FlowRate;
		
		first start;
		then merge continueOperation;
		
		then action monitorSource : MonitorWaterLevel {
			in reservoirLevel = sourceLevelIn;
			out levelStatus;
		}
		
		then decide;
			if monitorSource.levelStatus then rotateScrew;
			if !monitorSource.levelStatus then stopPumping;
		
		action rotateScrew : RotateScrew {
			in currentSpeed;
			in targetSpeed;
			out actualSpeed;
		}
		
		then action liftWater : LiftWater {
			in rotationSpeed = rotateScrew.actualSpeed;
			in inclinationAngle = screwInclination;
			in lowerLevel = sourceLevelIn;
			out flowRate;
		}
		
		then assign deliveredFlow := liftWater.flowRate;
		then continueOperation;
		
		action stopPumping;
		then done;
	}
	
	part archimedesScrewSystem : ArchimedesScrewAssembly {
		attribute inclination = 30.0;
		attribute efficiency = 0.75;
		
		part motor : DriveMotor {
			attribute ratedPower = 5000.0 [SI::W];
			attribute maxSpeed = 6.283 [SI::'rad/s'];
		}
		
		part lowerBasin : LowerReservoir {
			attribute capacity = 100.0 [SI::'m^3'];
			attribute currentLevel = 2.5 [SI::m];
		}
		
		part upperBasin : UpperReservoir {
			attribute capacity = 50.0 [SI::'m^3'];
			attribute currentLevel = 1.0 [SI::m];
		}
		
		connect motor.motorOutput.rotationalSpeed to lowerEnd.rotationIn;
		connect lowerBasin.waterIntake.waterFlow to lowerEnd.waterIn;
		connect upperEnd.waterOut to upperBasin.waterDischarge.waterFlow;
		
		perform action pumpOperation : PumpWaterContinuously {
			in screwInclination = inclination;
			in sourceLevelIn = lowerBasin.currentLevel;
			in targetSpeed = motor.maxSpeed;
			out deliveredFlow;
		}
	}
	
	state def ScrewOperationStates {
		attribute rotationSpeed : Real;
		
		entry; then idle;
		
		state idle;
		accept at idle StartCommand;
		then starting;
		
		state starting;
		entry assign rotationSpeed := 0.0;
		then accelerating;
		
		state accelerating;
		do action increaseSpeed {
			assign rotationSpeed := rotationSpeed + 5.0;
		}
		if rotationSpeed >= 60.0 then operating;
		
		state operating;
		do action maintainRotation;
		do action liftWaterFlow;
		accept at operating StopCommand;
		then stopping;
		
		state stopping;
		do action decreaseSpeed {
			assign rotationSpeed := rotationSpeed - 10.0;
		}
		if rotationSpeed <= 0.0 then idle;
	}
	
	part screwController {
		exhibit state operationStateMachine : ScrewOperationStates;
	}
	
	requirement def WaterLiftingRequirement {
		doc /* The Archimedes screw system shall continuously lift water from a lower elevation 
		       to a higher elevation by rotating a helical blade within an inclined cylindrical housing. */
		
		require constraint minimumFlowRate {
			doc /* The system shall deliver a minimum flow rate of 0.1 cubic meters per second. */
		}
		
		require constraint operationalInclination {
			doc /* The screw shall operate at an inclination angle between 20 and 40 degrees from horizontal. */
		}
		
		require constraint continuousOperation {
			doc /* The system shall operate continuously as long as water is available in the lower reservoir. */
		}
	}
	
	requirement primaryFunction : WaterLiftingRequirement {
		subject archimedesScrewSystem;
		
		assume constraint waterAvailability {
			doc /* Water is available in the lower reservoir at sufficient depth for intake. */
		}
		
		assume constraint motorFunctional {
			doc /* The drive motor is operational and capable of providing required rotational speed. */
		}
	}
}
