package 'Probe Positioning System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PositionCommand;
	attribute def SystemStatus;
	attribute def CalibrationState;
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def ControlSignal {
		attribute targetPosition : ISQ::LengthValue[3];
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def FeedbackData {
		attribute measuredPosition : ISQ::LengthValue[3];
		attribute velocity : ISQ::SpeedValue[3];
		attribute accuracy : ISQ::LengthValue;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def ControlPort {
		in item command : ControlSignal;
		out item feedback : FeedbackData;
	}
	
	port def ActuatorPort {
		out item driveSignal : ControlSignal;
		in item positionFeedback : FeedbackData;
	}
	
	part def MotionController {
		port controlInterface : ControlPort;
		port actuatorInterface : ActuatorPort;
		port powerIn : PowerPort;
		
		attribute currentPosition : ISQ::LengthValue[3];
		attribute targetPosition : ISQ::LengthValue[3];
		attribute positionTolerance : ISQ::LengthValue;
		attribute controlGain : Real;
		
		perform action controlLoop;
	}
	
	part def ActuatorAssembly {
		port commandPort : ~ActuatorPort;
		port powerIn : PowerPort;
		
		part xAxisActuator : LinearActuator {
			attribute axis = 0;
		}
		part yAxisActuator : LinearActuator {
			attribute axis = 1;
		}
		part zAxisActuator : LinearActuator {
			attribute axis = 2;
		}
	}
	
	part def LinearActuator {
		attribute axis : Integer;
		attribute maxTravel : ISQ::LengthValue;
		attribute maxSpeed : ISQ::SpeedValue;
		attribute resolution : ISQ::LengthValue;
		attribute currentPosition : ISQ::LengthValue;
		
		port powerIn : PowerPort;
	}
	
	part def PositionSensor {
		attribute measurementRange : ISQ::LengthValue[3];
		attribute resolution : ISQ::LengthValue;
		attribute updateRate : ISQ::FrequencyValue;
		
		port powerIn : PowerPort;
		port dataOut : ControlPort;
		
		perform action measurePosition;
	}
	
	part def Probe {
		attribute probeType : String;
		attribute tipDiameter : ISQ::LengthValue;
		attribute mass : ISQ::MassValue;
		attribute length : ISQ::LengthValue;
	}
	
	part def PowerSupply {
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		port powerOut1 : ~PowerPort;
		port powerOut2 : ~PowerPort;
		port powerOut3 : ~PowerPort;
	}
	
	action def MeasurePosition {
		in sensorRange : ISQ::LengthValue[3];
		in resolution : ISQ::LengthValue;
		out position : ISQ::LengthValue[3];
		out accuracy : ISQ::LengthValue;
	}
	
	action def CalculateError {
		in targetPosition : ISQ::LengthValue[3];
		in currentPosition : ISQ::LengthValue[3];
		out positionError : ISQ::LengthValue[3];
		out errorMagnitude : ISQ::LengthValue;
	}
	
	action def GenerateControlSignal {
		in positionError : ISQ::LengthValue[3];
		in controlGain : Real;
		out driveCommand : ControlSignal;
	}
	
	action def MoveActuators {
		in driveCommand : ControlSignal;
		in maxSpeed : ISQ::SpeedValue;
		out newPosition : ISQ::LengthValue[3];
	}
	
	action def VerifyPosition {
		in achievedPosition : ISQ::LengthValue[3];
		in targetPosition : ISQ::LengthValue[3];
		in tolerance : ISQ::LengthValue;
		out verified : Boolean;
	}
	
	action def ControlLoop {
		in targetPosition : ISQ::LengthValue[3];
		in positionTolerance : ISQ::LengthValue;
		in controlGain : Real;
		in sensorRange : ISQ::LengthValue[3];
		in sensorResolution : ISQ::LengthValue;
		in maxSpeed : ISQ::SpeedValue;
		out finalPosition : ISQ::LengthValue[3];
		
		first start;
		then merge checkPosition;
		
		then action measure : MeasurePosition {
			in sensorRange = ControlLoop::sensorRange;
			in resolution = ControlLoop::sensorResolution;
			out position;
			out accuracy;
		}
		
		then action calculateError : CalculateError {
			in targetPosition = ControlLoop::targetPosition;
			in currentPosition = measure.position;
			out positionError;
			out errorMagnitude;
		}
		
		then decide;
			if calculateError.errorMagnitude > positionTolerance then generateControl;
			if calculateError.errorMagnitude <= positionTolerance then reachedTarget;
		
		action generateControl : GenerateControlSignal {
			in positionError = calculateError.positionError;
			in controlGain = ControlLoop::controlGain;
			out driveCommand;
		}
		then action moveActuators : MoveActuators {
			in driveCommand = generateControl.driveCommand;
			in maxSpeed = ControlLoop::maxSpeed;
			out newPosition;
		}
		then checkPosition;
		
		action reachedTarget {
			assign finalPosition := measure.position;
		}
		then done;
	}
	
	action def PositionProbe {
		in commandedPosition : ISQ::LengthValue[3];
		in tolerance : ISQ::LengthValue;
		in gain : Real;
		in range : ISQ::LengthValue[3];
		in resolution : ISQ::LengthValue;
		in speed : ISQ::SpeedValue;
		out achievedPosition : ISQ::LengthValue[3];
		out status : SystemStatus;
		
		first start;
		
		then action initialize {
			doc /* Initialize system and perform self-check */
		}
		
		then action calibrate {
			doc /* Execute calibration routine to establish reference frame */
		}
		
		then action executePositioning : ControlLoop {
			in targetPosition = commandedPosition;
			in positionTolerance = tolerance;
			in controlGain = gain;
			in sensorRange = range;
			in sensorResolution = resolution;
			in maxSpeed = speed;
			out finalPosition;
		}
		
		then action verify : VerifyPosition {
			in achievedPosition = executePositioning.finalPosition;
			in targetPosition = commandedPosition;
			in tolerance = tolerance;
			out verified;
		}
		
		then assign achievedPosition := executePositioning.finalPosition;
		then done;
	}
	
	part def ProbePositioningSystem {
		doc /*
		 * The probe positioning system precisely moves and positions a measurement probe
		 * in three-dimensional space to specified coordinates with high accuracy.
		 * It continuously monitors probe position and adjusts actuators until the target
		 * position is reached within specified tolerance, enabling precise measurement
		 * and inspection operations.
		 */
		
		attribute workspaceVolume : ISQ::VolumeValue;
		attribute positioningAccuracy : ISQ::LengthValue;
		attribute maxPositioningSpeed : ISQ::SpeedValue;
		
		part controller : MotionController {
			attribute positionTolerance = 0.001 [SI::mm];
			attribute controlGain = 1.5;
		}
		
		part actuators : ActuatorAssembly {
			part redef xAxisActuator {
				attribute maxTravel = 500.0 [SI::mm];
				attribute maxSpeed = 100.0 [SI::mm/SI::s];
				attribute resolution = 0.0001 [SI::mm];
			}
			part redef yAxisActuator {
				attribute maxTravel = 500.0 [SI::mm];
				attribute maxSpeed = 100.0 [SI::mm/SI::s];
				attribute resolution = 0.0001 [SI::mm];
			}
			part redef zAxisActuator {
				attribute maxTravel = 300.0 [SI::mm];
				attribute maxSpeed = 100.0 [SI::mm/SI::s];
				attribute resolution = 0.0001 [SI::mm];
			}
		}
		
		part sensor : PositionSensor {
			attribute measurementRange = (500.0, 500.0, 300.0) [SI::mm];
			attribute resolution = 0.0001 [SI::mm];
			attribute updateRate = 1000.0 [SI::Hz];
		}
		
		part probe : Probe {
			attribute probeType = "contact";
			attribute tipDiameter = 1.0 [SI::mm];
			attribute mass = 0.05 [SI::kg];
			attribute length = 50.0 [SI::mm];
		}
		
		part powerSupply : PowerSupply {
			attribute outputVoltage = 48.0 [SI::V];
			attribute maxCurrent = 10.0 [SI::A];
		}
		
		connect controller.actuatorInterface to actuators.commandPort;
		connect powerSupply.powerOut1 to controller.powerIn;
		connect powerSupply.powerOut2 to actuators.powerIn;
		connect powerSupply.powerOut3 to sensor.powerIn;
		
		perform action positionProbe : PositionProbe[*] ordered;
	}
	
	part probePositioningSystem : ProbePositioningSystem {
		attribute workspaceVolume = 75000000.0 [SI::mm^3];
		attribute positioningAccuracy = 0.001 [SI::mm];
		attribute maxPositioningSpeed = 100.0 [SI::mm/SI::s];
	}
	
	requirement def PositioningAccuracyRequirement {
		doc /* The system shall position the probe within specified tolerance of target position */
		
		subject system : ProbePositioningSystem;
		
		require constraint {
			system.positioningAccuracy <= 0.001 [SI::mm]
		}
	}
	
	requirement def WorkspaceRequirement {
		doc /* The system shall provide minimum workspace volume for probe movement */
		
		subject system : ProbePositioningSystem;
		
		require constraint {
			system.workspaceVolume >= 75000000.0 [SI::mm^3]
		}
	}
	
	requirement def SpeedRequirement {
		doc /* The system shall achieve minimum positioning speed */
		
		subject system : ProbePositioningSystem;
		
		require constraint {
			system.maxPositioningSpeed >= 50.0 [SI::mm/SI::s]
		}
	}
	
	requirement <'PPS-R-001'> primaryFunction {
		doc /*
		 * The primary function of the Probe Positioning System is to accurately
		 * position a measurement probe at specified three-dimensional coordinates
		 * within its workspace, enabling precise measurement and inspection operations.
		 */
		
		subject system : ProbePositioningSystem;
		
		require positioningAccuracy : PositioningAccuracyRequirement;
		require workspace : WorkspaceRequirement;
		require speed : SpeedRequirement;
	}
}
