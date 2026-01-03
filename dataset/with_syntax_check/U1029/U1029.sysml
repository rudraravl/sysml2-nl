package DifferentialSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def RotationDirection {
		clockwise;
		counterclockwise;
	}
	
	item def TorqueTransfer {
		attribute magnitude : TorqueValue;
		attribute direction : RotationDirection;
	}
	
	item def RotationalSpeed {
		attribute value : AngularVelocityValue;
		attribute direction : RotationDirection;
	}
	
	port def TorqueInputPort {
		in item inputTorque : TorqueTransfer;
	}
	
	port def TorqueOutputPort {
		out item outputTorque : TorqueTransfer;
	}
	
	port def SpeedSensorPort {
		out item wheelSpeed : RotationalSpeed;
	}
	
	part def DifferentialGearSet {
		attribute gearRatio : Real;
		port inputPort : TorqueInputPort;
		port leftOutputPort : TorqueOutputPort;
		port rightOutputPort : TorqueOutputPort;
	}
	
	part def DriveWheel {
		attribute radius : LengthValue;
		attribute currentSpeed : AngularVelocityValue;
		port torqueInput : TorqueInputPort;
		port speedSensor : SpeedSensorPort;
	}
	
	part def Driveshaft {
		attribute length : LengthValue;
		attribute torqueCapacity : TorqueValue;
		port input : TorqueInputPort;
		port output : TorqueOutputPort;
	}
	
	attribute def StraightDrivingCommand;
	attribute def CorneringDetected;
	attribute def PowerCutoff;
	
	requirement def TorqueDistributionRequirement {
		doc /* The differential shall distribute input torque to both output shafts 
		     enabling different rotational speeds while maintaining total torque balance. */
		
		subject differential : DifferentialGearSet;
		
		require constraint equalTorqueDistribution {
			differential.leftOutputPort.outputTorque.magnitude + 
			differential.rightOutputPort.outputTorque.magnitude == 
			differential.inputPort.inputTorque.magnitude
		}
	}
	
	requirement def SpeedDifferentiationRequirement {
		doc /* The differential shall allow the left and right wheels to rotate at 
		     different speeds during cornering while receiving power. */
		
		subject differential : DifferentialGearSet;
		
		assume constraint corneringCondition {
			doc /* During cornering, outer wheel travels longer path than inner wheel. */
		}
		
		require constraint independentWheelSpeeds {
			doc /* Left and right output speeds can differ while maintaining power transfer. */
		}
	}
	
	requirement def StructuralIntegrityRequirement {
		doc /* All differential components shall withstand maximum rated torque 
		     without mechanical failure. */
		
		attribute maxTorque : TorqueValue = 500.0 [N*m];
		
		require constraint torqueWithinLimits;
	}
	
	action def ReceiveDriveTorque {
		in driveshaftTorque : TorqueTransfer;
		out inputTorque : TorqueTransfer;
	}
	
	action def SplitTorque {
		in inputTorque : TorqueTransfer;
		in leftWheelResistance : Real;
		in rightWheelResistance : Real;
		out leftTorque : TorqueTransfer;
		out rightTorque : TorqueTransfer;
	}
	
	action def TransferToWheel {
		in wheelTorque : TorqueTransfer;
		out wheelRotation : RotationalSpeed;
	}
	
	action def MonitorWheelSpeed {
		in wheelRotation : RotationalSpeed;
		out speedData : RotationalSpeed;
	}
	
	action def EqualDistribution;
	action def DifferentialDistribution;
	
	action def DistributePower {
		doc /* Primary function: Distribute rotational power from driveshaft to wheels 
		     allowing differential speeds during turns. */
		
		in driveshaftInput : TorqueTransfer;
		out leftWheelOutput : RotationalSpeed;
		out rightWheelOutput : RotationalSpeed;
		
		first start;
		
		then action receiveTorque : ReceiveDriveTorque {
			in driveshaftTorque = driveshaftInput;
			out inputTorque : TorqueTransfer;
		}
		
		flow receiveTorque.inputTorque to splitTorque.inputTorque;
		
		then action splitTorque : SplitTorque {
			in inputTorque : TorqueTransfer;
			in leftWheelResistance : Real;
			in rightWheelResistance : Real;
			out leftTorque : TorqueTransfer;
			out rightTorque : TorqueTransfer;
		}
		
		flow splitTorque.leftTorque to transferLeft.wheelTorque;
		flow splitTorque.rightTorque to transferRight.wheelTorque;
		
		then action transferLeft : TransferToWheel {
			in wheelTorque : TorqueTransfer;
			out wheelRotation : RotationalSpeed;
		}
		
		then action transferRight : TransferToWheel {
			in wheelTorque : TorqueTransfer;
			out wheelRotation : RotationalSpeed;
		}
		
		flow transferLeft.wheelRotation to monitorLeft.wheelRotation;
		flow transferRight.wheelRotation to monitorRight.wheelRotation;
		
		then action monitorLeft : MonitorWheelSpeed {
			in wheelRotation : RotationalSpeed;
			out speedData = leftWheelOutput;
		}
		
		then action monitorRight : MonitorWheelSpeed {
			in wheelRotation : RotationalSpeed;
			out speedData = rightWheelOutput;
		}
		
		then done;
	}
	
	state def DifferentialOperatingStates {
		entry; then idle;
		
		state idle {
			doc /* No torque input, gears stationary or freewheeling. */
		}
		
		transition idle_to_straightDriving
			first idle
			accept straightDrivingCommand : StraightDrivingCommand
			then straightDriving;
		
		state straightDriving {
			doc /* Equal torque to both wheels, same rotational speed. */
			entry action equalDistribution : EqualDistribution;
		}
		
		transition straightDriving_to_cornering
			first straightDriving
			accept corneringDetected : CorneringDetected
			then cornering;
		
		state cornering {
			doc /* Differential torque distribution, different wheel speeds. */
			entry action differentialDistribution : DifferentialDistribution;
			
			state leftTurn {
				doc /* Right wheel faster than left wheel. */
			}
			
			state rightTurn {
				doc /* Left wheel faster than right wheel. */
			}
		}
		
		transition cornering_to_straightDriving
			first cornering
			accept straightDrivingCommand : StraightDrivingCommand
			then straightDriving;
		
		transition toIdle
			accept powerCutoff : PowerCutoff
			then idle;
	}
	
	part differentialSystem : DifferentialGearSet {
		doc /* Complete differential assembly for automotive drivetrain. */
		
		attribute :>> gearRatio = 3.73;
		
		part inputShaft : Driveshaft {
			attribute :>> length = 0.15 [m];
			attribute :>> torqueCapacity = 600.0 [N*m];
		}
		
		part gearAssembly : DifferentialGearSet {
			attribute :>> gearRatio = 1.0;
		}
		
		part leftAxle : Driveshaft {
			attribute :>> length = 0.75 [m];
			attribute :>> torqueCapacity = 400.0 [N*m];
		}
		
		part rightAxle : Driveshaft {
			attribute :>> length = 0.75 [m];
			attribute :>> torqueCapacity = 400.0 [N*m];
		}
		
		part leftWheel : DriveWheel {
			attribute :>> radius = 0.33 [m];
			attribute :>> currentSpeed = 0.0 [rad/s];
			
			perform action rotateLeft[*] ordered;
		}
		
		part rightWheel : DriveWheel {
			attribute :>> radius = 0.33 [m];
			attribute :>> currentSpeed = 0.0 [rad/s];
			
			perform action rotateRight[*] ordered;
		}
		
		connect inputShaft.output to gearAssembly.inputPort;
		connect gearAssembly.leftOutputPort to leftAxle.input;
		connect gearAssembly.rightOutputPort to rightAxle.input;
		connect leftAxle.output to leftWheel.torqueInput;
		connect rightAxle.output to rightWheel.torqueInput;
		
		perform action distributePower : DistributePower;
		
		exhibit state operatingState : DifferentialOperatingStates;
		
		satisfy requirement torqueDistributionReq : TorqueDistributionRequirement {
			subject differential = gearAssembly;
		}
		
		satisfy requirement speedDifferentiationReq : SpeedDifferentiationRequirement {
			subject differential = gearAssembly;
		}
		
		satisfy requirement structuralIntegrityReq : StructuralIntegrityRequirement;
	}
	
	requirement vehicleDifferentialMission {
		doc /* The differential system shall enable smooth vehicle cornering by allowing 
		     wheels to rotate at different speeds while maintaining traction and power delivery. */
		
		require requirement enableCorneringReq : SpeedDifferentiationRequirement;
		require requirement maintainTractionReq : TorqueDistributionRequirement;
		require requirement ensureReliabilityReq : StructuralIntegrityRequirement;
	}
}
