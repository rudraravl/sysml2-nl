package SpacecraftAttitudeControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AttitudeAngle {
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
	}
	
	attribute def AngularRate {
		attribute rollRate : AngularVelocityValue;
		attribute pitchRate : AngularVelocityValue;
		attribute yawRate : AngularVelocityValue;
	}
	
	attribute def TorqueVector {
		attribute xTorque : TorqueValue;
		attribute yTorque : TorqueValue;
		attribute zTorque : TorqueValue;
	}
	
	item def AttitudeCommand {
		attribute targetAttitude : AttitudeAngle;
		attribute commandTimestamp : TimeValue;
	}
	
	item def SensorMeasurement {
		attribute measuredAttitude : AttitudeAngle;
		attribute measuredRate : AngularRate;
		attribute measurementTime : TimeValue;
	}
	
	item def ActuatorCommand {
		attribute commandedTorque : TorqueVector;
		attribute actuatorMode : ActuatorModeEnum;
	}
	
	enum def ActuatorModeEnum {
		enum normalOperation;
		enum safeModeOperation;
		enum standbyMode;
	}
	
	port def AttitudeCommandPort {
		in item command : AttitudeCommand;
	}
	
	port def SensorOutputPort {
		out item measurement : SensorMeasurement;
	}
	
	port def ControlOutputPort {
		out item controlSignal : ActuatorCommand;
	}
	
	port def ActuatorInputPort {
		in item actuatorSignal : ActuatorCommand;
	}
	
	part def StarTracker {
		port sensorOut : SensorOutputPort;
		
		action def MeasureAttitude {
			out attitudeMeasurement : SensorMeasurement;
		}
		
		perform action continuousSensing {
			first start;
			then merge sensingLoop;
			action measure : MeasureAttitude;
			then sensingLoop;
		}
	}
	
	part def GyroscopeUnit {
		port rateOut : SensorOutputPort;
		
		action def MeasureAngularRate {
			out rateMeasurement : AngularRate;
		}
		
		perform action continuousMeasurement {
			first start;
			then merge measurementLoop;
			action measureRate : MeasureAngularRate;
			then measurementLoop;
		}
	}
	
	part def ReactionWheel {
		attribute wheelSpeed : AngularVelocityValue;
		attribute maxTorqueCapacity : TorqueValue;
		port actuatorIn : ActuatorInputPort;
		
		action def ApplyTorque {
			in requestedTorque : TorqueValue;
			out actualTorque : TorqueValue;
		}
		
		state wheelOperationStates {
			entry; then normalOp;
			
			state normalOp {
				do action applyTorque : ApplyTorque;
			}
			
			transition normalToSaturated
				first normalOp
				if wheelSpeed > maxTorqueCapacity * 0.9
				then saturatedOp;
			
			state saturatedOp {
				entry; then notifySaturation;
				action notifySaturation;
			}
			
			transition saturatedToNormal
				first saturatedOp
				if wheelSpeed < maxTorqueCapacity * 0.7
				then normalOp;
		}
	}
	
	part def AttitudeControlComputer {
		port cmdIn : AttitudeCommandPort;
		port sensorIn1 : SensorOutputPort;
		port sensorIn2 : SensorOutputPort;
		port ctrlOut : ControlOutputPort;
		
		attribute currentAttitude : AttitudeAngle;
		attribute desiredAttitude : AttitudeAngle;
		attribute errorAttitude : AttitudeAngle;
		attribute proportionalGain : Real;
		attribute derivativeGain : Real;
		
		action def CalculateAttitudeError {
			in desired : AttitudeAngle;
			in measured : AttitudeAngle;
			out error : AttitudeAngle;
		}
		
		action def ComputeControlTorque {
			in attitudeError : AttitudeAngle;
			in angularRate : AngularRate;
			in kp : Real;
			in kd : Real;
			out commandTorque : TorqueVector;
		}
		
		action def ControlLoop {
			first start;
			then merge loopStart;
			
			action receiveTargetCommand {
				out targetCmd : AttitudeCommand;
			}
			then action acquireSensorData {
				out sensorData : SensorMeasurement;
			}
			then action calculateError : CalculateAttitudeError {
				in desired = receiveTargetCommand.targetCmd.targetAttitude;
				in measured = acquireSensorData.sensorData.measuredAttitude;
				out error;
			}
			then action computeControl : ComputeControlTorque {
				in attitudeError = calculateError.error;
				in angularRate = acquireSensorData.sensorData.measuredRate;
				in kp = proportionalGain;
				in kd = derivativeGain;
				out commandTorque;
			}
			then action issueControlCommand {
				in torqueCommand = computeControl.commandTorque;
			}
			then loopStart;
		}
		
		perform ControlLoop;
	}
	
	part def Spacecraft {
		attribute spacecraftMass : MassValue;
		attribute inertiaMatrix : Real;
		
		part controller : AttitudeControlComputer {
			attribute :>> proportionalGain = 0.6;
			attribute :>> derivativeGain = 0.3;
		}
		
		part starSensor : StarTracker;
		part gyroscope : GyroscopeUnit;
		
		part wheelX : ReactionWheel {
			attribute :>> maxTorqueCapacity = 0.25[N*m];
		}
		part wheelY : ReactionWheel {
			attribute :>> maxTorqueCapacity = 0.25[N*m];
		}
		part wheelZ : ReactionWheel {
			attribute :>> maxTorqueCapacity = 0.25[N*m];
		}
		
		connection starToController 
			connect starSensor.sensorOut to controller.sensorIn1;
		
		connection gyroToController 
			connect gyroscope.rateOut to controller.sensorIn2;
		
		connection controllerToWheelX 
			connect controller.ctrlOut to wheelX.actuatorIn;
		
		connection controllerToWheelY 
			connect controller.ctrlOut to wheelY.actuatorIn;
		
		connection controllerToWheelZ 
			connect controller.ctrlOut to wheelZ.actuatorIn;
	}
	
	requirement def PointingAccuracyRequirement {
		doc /* The spacecraft shall maintain attitude pointing accuracy within specified limits. */
		
		subject spacecraft : Spacecraft;
		
		require constraint accuracyLimit {
			attribute maxPointingError : AngleValue;
			maxPointingError <= 0.01[deg]
		}
	}
	
	requirement def StabilizationRequirement {
		doc /* The spacecraft shall achieve stable attitude within specified settling time. */
		
		subject spacecraft : Spacecraft;
		
		require constraint settlingTime {
			attribute maxSettlingDuration : TimeValue;
			maxSettlingDuration <= 90.0[s]
		}
		
		require constraint steadyStateError {
			attribute maxSteadyError : AngleValue;
			maxSteadyError <= 0.005[deg]
		}
	}
	
	requirement def TorqueAuthorityRequirement {
		doc /* The attitude control system shall provide adequate torque authority for maneuvers. */
		
		subject spacecraft : Spacecraft;
		
		require constraint minimumTorquePerAxis {
			attribute minTorque : TorqueValue;
			minTorque >= 0.15[N*m]
		}
	}
	
	requirement <'ACS-REQ-001'> spacecraftAttitudeControlMission {
		doc /* The spacecraft attitude control system shall autonomously maintain precise three-axis 
		       orientation for mission operations including Earth observation, communication relay, and 
		       scientific instrument pointing. The system shall continuously monitor spacecraft attitude 
		       using star trackers and gyroscopes, compute control commands based on desired orientation, 
		       and command reaction wheels to apply corrective torques, ensuring stable and accurate 
		       pointing throughout all mission phases. */
		
		subject spacecraft : Spacecraft;
		
		assume constraint operationalConditions {
			doc /* System operates in low Earth orbit with typical disturbance torques from gravity gradient, 
			       atmospheric drag, and solar radiation pressure. */
		}
		
		require pointingAccuracy : PointingAccuracyRequirement {
			subject spacecraft = spacecraftAttitudeControlMission.spacecraft;
		}
		
		require stabilization : StabilizationRequirement {
			subject spacecraft = spacecraftAttitudeControlMission.spacecraft;
		}
		
		require torqueAuthority : TorqueAuthorityRequirement {
			subject spacecraft = spacecraftAttitudeControlMission.spacecraft;
		}
	}
	
	action def MaintainPreciseAttitude {
		in targetOrientation : AttitudeAngle;
		in maxAllowedError : AngleValue;
		out achievedAccuracy : AngleValue;
		
		first start;
		then merge controlCycle;
		
		action acquireTargetOrientation {
			in target : AttitudeAngle;
			out currentTarget : AttitudeAngle;
		}
		
		then action measureCurrentState {
			out currentAttitude : AttitudeAngle;
			out currentRate : AngularRate;
		}
		
		then decide;
			if achievedAccuracy > maxAllowedError then applyCorrection;
			if achievedAccuracy <= maxAllowedError then holdAttitude;
		
		action applyCorrection {
			in errorAngle : AttitudeAngle;
			in angularVelocity : AngularRate;
		}
		then controlCycle;
		
		action holdAttitude {
			in stableState : AttitudeAngle;
		}
		then controlCycle;
	}
	
	part missionSpacecraft : Spacecraft {
		attribute :>> spacecraftMass = 600.0[kg];
		attribute :>> inertiaMatrix = 120.0;
		
		perform action attitudeControlOperation : MaintainPreciseAttitude {
			in targetOrientation;
			in maxAllowedError = 0.01[deg];
			out achievedAccuracy;
		}
	}
}
