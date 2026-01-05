package 'Scoop Wheel Material Handling System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OperationMode;
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	
	item def BulkMaterial {
		attribute materialType : String;
		attribute density : DensityValue;
		attribute particleSize : LengthValue;
	}
	
	port def MaterialInputPort {
		in item material : BulkMaterial[*];
	}
	
	port def MaterialOutputPort {
		out item material : BulkMaterial[*];
	}
	
	port def PowerInputPort {
		in attribute power : PowerValue;
	}
	
	port def ControlSignalPort {
		in attribute startSig : StartCommand;
		in attribute stopSig : StopCommand;
		in attribute emergencyStopSig : EmergencyStop;
	}
	
	port def DriveShaftPort {
		in attribute torque : TorqueValue;
		in attribute speed : AngularVelocityValue;
	}
	
	part def ScoopBucket {
		attribute bucketCapacity : VolumeValue;
		attribute bucketAngle : PlaneAngleValue;
		attribute fillLevel : Real;
		attribute position : PlaneAngleValue;
		
		port materialEntry : MaterialInputPort;
		port materialExit : MaterialOutputPort;
	}
	
	part def RotatingWheel {
		attribute wheelDiameter : LengthValue;
		attribute rotationSpeed : AngularVelocityValue;
		attribute currentAngle : PlaneAngleValue;
		attribute numberOfBuckets : Integer;
		
		port driveConnection : DriveShaftPort;
		part buckets : ScoopBucket[12] {
			attribute bucketCapacity = 0.08 [m^3];
		}
	}
	
	part def DriveMotor {
		attribute ratedPower : PowerValue;
		attribute efficiency : Real;
		attribute outputTorque : TorqueValue;
		attribute outputSpeed : AngularVelocityValue;
		
		port powerIn : PowerInputPort;
		port shaftOut : DriveShaftPort;
	}
	
	part def FeedHopper {
		attribute hopperCapacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		attribute dischargeRate : VolumeFlowRateValue;
		
		port materialIn : MaterialInputPort;
		port materialOut : MaterialOutputPort;
	}
	
	part def DischargeChute {
		attribute chuteAngle : PlaneAngleValue;
		attribute chuteLength : LengthValue;
		attribute throughputCapacity : VolumeFlowRateValue;
		
		port materialIn : MaterialInputPort;
		port materialOut : MaterialOutputPort;
	}
	
	part def ControlUnit {
		attribute operatingMode : OperationMode;
		attribute targetSpeed : AngularVelocityValue;
		
		port commandInterface : ControlSignalPort;
		port motorControl;
	}
	
	part def ScoopWheelSystem {
		doc /* 
		Primary Function: Continuously elevate and transfer bulk materials from a lower 
		elevation to a higher elevation through the rotational motion of a wheel equipped 
		with multiple scoop buckets. The system receives material at the bottom, captures 
		it in rotating buckets, lifts it through circular motion, and discharges it at 
		the top into a collection chute for further processing or storage.
		*/
		
		attribute systemCapacity : VolumeFlowRateValue;
		attribute liftHeight : LengthValue;
		attribute operationalEfficiency : Real;
		
		port materialInput : MaterialInputPort;
		port materialOutput : MaterialOutputPort;
		port powerSupply : PowerInputPort;
		port controlPanel : ControlSignalPort;
		
		part controller : ControlUnit {
			attribute targetSpeed = 25.0;
		}
		
		part motor : DriveMotor {
			attribute ratedPower = 22.0 [kW];
			attribute efficiency = 0.92;
		}
		
		part wheel : RotatingWheel {
			attribute wheelDiameter = 4.0 [m];
			attribute numberOfBuckets = 12;
		}
		
		part inputHopper : FeedHopper {
			attribute hopperCapacity = 2.5 [m^3];
		}
		
		part outputChute : DischargeChute {
			attribute chuteAngle = 45.0;
			attribute chuteLength = 2.0 [m];
		}
		
		connect powerSupply to motor.powerIn;
		connect motor.shaftOut to wheel.driveConnection;
		connect materialInput to inputHopper.materialIn;
		connect inputHopper.materialOut to wheel.buckets.materialEntry;
		connect wheel.buckets.materialExit to outputChute.materialIn;
		connect outputChute.materialOut to materialOutput;
		connect controlPanel to controller.commandInterface;
	}
	
	action def LoadBucket {
		in bucketPosition : PlaneAngleValue;
		in availableMaterial : VolumeValue;
		in bucketCapacity : VolumeValue;
		out loadedVolume : VolumeValue;
		out fillPercentage : Real;
	}
	
	action def TransportMaterial {
		in currentPosition : PlaneAngleValue;
		in loadedVolume : VolumeValue;
		in rotationSpeed : AngularVelocityValue;
		out newPosition : PlaneAngleValue;
		out retainedVolume : VolumeValue;
	}
	
	action def DischargeBucket {
		in bucketPosition : PlaneAngleValue;
		in loadedVolume : VolumeValue;
		out dischargedVolume : VolumeValue;
		out remainingVolume : VolumeValue;
	}
	
	action def CalculateTorque {
		in power : PowerValue;
		in speed : AngularVelocityValue;
		in efficiency : Real;
		out torque : TorqueValue;
	}
	
	state def ScoopWheelOperationalStates {
		entry; then stopped;
		
		state stopped {
			entry assign wheelSpeed := 0.0;
			entry assign motorPower := 0.0;
		}
		
		transition stopped_to_starting
			first stopped
			accept StartCommand
			then starting;
		
		state starting {
			entry assign motorPower := 22.0;
			entry assign wheelSpeed := 5.0;
		}
		
		transition starting_to_accelerating
			first starting
			if wheelSpeed >= 5.0
			then accelerating;
		
		state accelerating {
			entry assign wheelSpeed := 15.0;
		}
		
		transition accelerating_to_running
			first accelerating
			if wheelSpeed >= 25.0
			then running;
		
		state running {
			entry assign wheelSpeed := 25.0;
			
			state loading {
				entry assign bucketZone := "bottom";
			}
			
			state lifting {
				entry assign bucketZone := "ascending";
			}
			
			state discharging {
				entry assign bucketZone := "top";
			}
			
			state returning {
				entry assign bucketZone := "descending";
			}
			
			transition loading_to_lifting
				first loading
				if bucketAngle > 45.0
				then lifting;
			
			transition lifting_to_discharging
				first lifting
				if bucketAngle > 135.0
				then discharging;
			
			transition discharging_to_returning
				first discharging
				if bucketAngle > 225.0
				then returning;
			
			transition returning_to_loading
				first returning
				if bucketAngle > 315.0
				then loading;
		}
		
		transition running_to_stopping
			first running
			accept StopCommand
			then stopping;
		
		transition running_to_emergency
			first running
			accept EmergencyStop
			then emergency;
		
		state stopping {
			entry assign motorPower := 5.0;
			entry assign wheelSpeed := 10.0;
		}
		
		transition stopping_to_stopped
			first stopping
			if wheelSpeed <= 1.0
			then stopped;
		
		state emergency {
			entry assign motorPower := 0.0;
			entry assign wheelSpeed := 0.0;
		}
		
		transition emergency_to_stopped
			first emergency
			if wheelSpeed == 0.0
			then stopped;
		
		attribute wheelSpeed : Real;
		attribute motorPower : Real;
		attribute bucketAngle : Real;
		attribute bucketZone : String;
	}
	
	action def OperateScoopWheel {
		in inputMaterial : BulkMaterial;
		in targetThroughput : VolumeFlowRateValue;
		in liftHeight : LengthValue;
		out outputMaterial : BulkMaterial;
		out actualThroughput : VolumeFlowRateValue;
		out energyConsumed : EnergyValue;
		
		private attribute wheelRotation := 0.0;
		private attribute totalVolumeLifted := 0.0;
		private attribute activeBucketIndex := 1;
		private attribute cycleCount := 0;
		
		first start;
		then merge operationCycle;
		
		then action calculateDriveTorque : CalculateTorque {
			in power = 22.0 [kW];
			in speed = 25.0;
			in efficiency = 0.92;
			out torque;
		}
		
		then action rotateWheel {
			assign wheelRotation := (wheelRotation + 30.0) % 360.0;
		}
		
		then decide;
			if wheelRotation >= 0.0 and wheelRotation < 90.0 then loadingZone;
			if wheelRotation >= 90.0 and wheelRotation < 180.0 then liftingZone;
			if wheelRotation >= 180.0 and wheelRotation < 270.0 then dischargingZone;
			if wheelRotation >= 270.0 and wheelRotation < 360.0 then returningZone;
		
		action loadingZone {
			action loadBucket : LoadBucket {
				in bucketPosition = wheelRotation;
				in availableMaterial = 0.1 [m^3];
				in bucketCapacity = 0.08 [m^3];
				out loadedVolume;
				out fillPercentage;
			}
		}
		then operationCycle;
		
		action liftingZone {
			action transportMaterial : TransportMaterial {
				in currentPosition = wheelRotation;
				in loadedVolume = 0.08 [m^3];
				in rotationSpeed = 25.0;
				out newPosition;
				out retainedVolume;
			}
		}
		then operationCycle;
		
		action dischargingZone {
			action dischargeBucket : DischargeBucket {
				in bucketPosition = wheelRotation;
				in loadedVolume = 0.08 [m^3];
				out dischargedVolume;
				out remainingVolume;
			}
			then assign totalVolumeLifted := totalVolumeLifted + 0.08;
			then assign cycleCount := cycleCount + 1;
		}
		then operationCycle;
		
		action returningZone {
			action returnBucket {
				assign activeBucketIndex := (activeBucketIndex % 12) + 1;
			}
		}
		then operationCycle;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'SWS-FR-001'> primaryFunction : FunctionalRequirement {
		doc /* 
		The Scoop Wheel System shall continuously elevate bulk materials from a lower 
		elevation to a higher elevation through rotational motion of bucket-equipped wheel, 
		providing reliable material handling for industrial processes.
		*/
		
		subject system : ScoopWheelSystem;
		
		require constraint {
			system.liftHeight >= 3.0 [m] and system.liftHeight <= 6.0 [m]
		}
	}
	
	requirement <'SWS-PR-001'> throughputCapacity : PerformanceRequirement {
		doc /* 
		The system shall achieve a minimum material throughput of 100 cubic meters per hour 
		during continuous operation at rated speed.
		*/
		
		subject system : ScoopWheelSystem;
	}
	
	requirement <'SWS-PR-002'> operationalEfficiency : PerformanceRequirement {
		doc /* 
		The system shall maintain an operational efficiency of at least 85% during 
		steady-state operation.
		*/
		
		subject system : ScoopWheelSystem;
		
		require constraint {
			system.operationalEfficiency >= 0.85
		}
	}
	
	requirement <'SWS-PR-003'> powerConsumption : PerformanceRequirement {
		doc /* 
		The system's power consumption shall not exceed 25 kilowatts during normal operation.
		*/
		
		subject system : ScoopWheelSystem;
		
		require constraint {
			system.motor.ratedPower <= 25.0 [kW]
		}
	}
	
	requirement <'SWS-SR-001'> emergencyShutdown : SafetyRequirement {
		doc /* 
		The system shall be capable of emergency shutdown within 10 seconds of receiving 
		an emergency stop command.
		*/
		
		subject system : ScoopWheelSystem;
	}
	
	requirement <'SWS-MISSION'> systemMission {
		doc /* 
		The Scoop Wheel System mission is to provide reliable, continuous elevation of 
		bulk materials in industrial applications with high efficiency and safety.
		*/
		
		satisfy primaryFunction;
		satisfy throughputCapacity;
		satisfy operationalEfficiency;
		assume powerConsumption;
		assume emergencyShutdown;
	}
	
	part operationalSystem : ScoopWheelSystem {
		attribute liftHeight = 4.5 [m];
		attribute operationalEfficiency = 0.88;
		
		perform action continuousOperation : OperateScoopWheel {
			in inputMaterial : BulkMaterial {
				attribute materialType = "Grain";
				attribute density = 750.0;
				attribute particleSize = 5.0 [mm];
			}
			in liftHeight = 4.5 [m];
			out outputMaterial : BulkMaterial;
			out actualThroughput : VolumeFlowRateValue;
			out energyConsumed : EnergyValue;
		}
	}
}
