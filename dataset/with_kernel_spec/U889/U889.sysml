package 'Spacecraft Attitude Control System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::ScalarQuantityValue;

	attribute def AngleValue :> ISQ::AngleValue;
	attribute def AngularRateValue :> ISQ::AngularVelocityValue;
	attribute def TorqueValue :> ISQ::TorqueValue;
	attribute def WheelSpeedValue :> ISQ::AngularVelocityValue;
	attribute def TimeValue :> ISQ::TimeValue;

	item def TargetAttitude {
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
	}

	item def MeasuredAttitude {
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
	}

	item def AttitudeError {
		attribute rollError : AngleValue;
		attribute pitchError : AngleValue;
		attribute yawError : AngleValue;
	}

	item def AngularRates {
		attribute rollRate : AngularRateValue;
		attribute pitchRate : AngularRateValue;
		attribute yawRate : AngularRateValue;
	}

	item def WheelStatus {
		attribute saturated : Boolean;
		attribute currentSpeed : WheelSpeedValue;
	}

	part def StarTracker {
		port attitudeOutPort { out measuredAttitude : MeasuredAttitude; }
	}

	part def GyroscopeUnit {
		port ratesOutPort { out angularRates : AngularRates; }
	}

	part def ReactionWheel {
		port commandPort { in torqueCommand : TorqueValue; }
		port statusPort { out wheelStatus : WheelStatus; }
		attribute currentSpeed : WheelSpeedValue;
		attribute maxSpeed : WheelSpeedValue = 600 [rad/s];
		attribute saturated : Boolean;
		assert constraint saturationConstraint {
			saturated == (currentSpeed >= maxSpeed)
		}
	}

	action def ComputeAttitudeError {
		in target : TargetAttitude;
		in measured : MeasuredAttitude;
		out error : AttitudeError;
		assert constraint {
			error.rollError == target.roll - measured.roll &
			error.pitchError == target.pitch - measured.pitch &
			error.yawError == target.yaw - measured.yaw
		}
	}

	action def ComputeWheelCommands {
		in error : AttitudeError;
		in rates : AngularRates;
		out xTorque : TorqueValue;
		out yTorque : TorqueValue;
		out zTorque : TorqueValue;
	}

	part def AttitudeControlComputer {
		port targetAttitudePort { in targetAttitude : TargetAttitude; }
		port starTrackerPort { in measuredAttitude : MeasuredAttitude; }
		port gyroPort { in angularRates : AngularRates; }
		port wheelXCommandPort { out xTorque : TorqueValue; }
		port wheelYCommandPort { out yTorque : TorqueValue; }
		port wheelZCommandPort { out zTorque : TorqueValue; }
		port wheelXStatusPort { in wheelXStatus : WheelStatus; }
		port wheelYStatusPort { in wheelYStatus : WheelStatus; }
		port wheelZStatusPort { in wheelZStatus : WheelStatus; }

		attribute targetReceived : Boolean;
		attribute wheelXSaturated : Boolean;
		attribute wheelYSaturated : Boolean;
		attribute wheelZSaturated : Boolean;

		action computeError : ComputeAttitudeError {
			in target = targetAttitudePort.targetAttitude;
			in measured = starTrackerPort.measuredAttitude;
		}
		then action computeCommands : ComputeWheelCommands {
			in error = computeError.error;
			in rates = gyroPort.angularRates;
			out xTorque = wheelXCommandPort.xTorque;
			out yTorque = wheelYCommandPort.yTorque;
			out zTorque = wheelZCommandPort.zTorque;
		}

		state machine AttitudeControlStateMachine {
			state Idle;
			state Active;
			state SaturationHandling;
			transition Idle to Active when targetReceived;
			transition Active to SaturationHandling when wheelXSaturated | wheelYSaturated | wheelZSaturated;
			transition SaturationHandling to Active when !wheelXSaturated & !wheelYSaturated & !wheelZSaturated;
		}
	}

	part def Spacecraft {
		port targetAttitudePort { in targetAttitude : TargetAttitude; }

		part attitudeControlComputer : AttitudeControlComputer;
		part starTracker : StarTracker;
		part gyroscopeUnit : GyroscopeUnit;
		part reactionWheelX : ReactionWheel;
		part reactionWheelY : ReactionWheel;
		part reactionWheelZ : ReactionWheel;

		bind targetAttitudePort = attitudeControlComputer.targetAttitudePort;

		flow starTrackerFlow of MeasuredAttitude
			from starTracker.attitudeOutPort.measuredAttitude
			to attitudeControlComputer.starTrackerPort.measuredAttitude;

		flow gyroFlow of AngularRates
			from gyroscopeUnit.ratesOutPort.angularRates
			to attitudeControlComputer.gyroPort.angularRates;

		flow wheelXCommandFlow of TorqueValue
			from attitudeControlComputer.wheelXCommandPort.xTorque
			to reactionWheelX.commandPort.torqueCommand;

		flow wheelYCommandFlow of TorqueValue
			from attitudeControlComputer.wheelYCommandPort.yTorque
			to reactionWheelY.commandPort.torqueCommand;

		flow wheelZCommandFlow of TorqueValue
			from attitudeControlComputer.wheelZCommandPort.zTorque
			to reactionWheelZ.commandPort.torqueCommand;

		flow wheelXStatusFlow of WheelStatus
			from reactionWheelX.statusPort.wheelStatus
			to attitudeControlComputer.wheelXStatusPort.wheelXStatus;

		flow wheelYStatusFlow of WheelStatus
			from reactionWheelY.statusPort.wheelStatus
			to attitudeControlComputer.wheelYStatusPort.wheelYStatus;

		flow wheelZStatusFlow of WheelStatus
			from reactionWheelZ.statusPort.wheelStatus
			to attitudeControlComputer.wheelZStatusPort.wheelZStatus;
	}

	part def GroundStation {
		port targetAttitudeOutPort { out targetAttitude : TargetAttitude; }
	}

	part groundStation : GroundStation;

	requirement def PointingAccuracy {
		attribute pointingError : AngleValue;
		constraint { pointingError <= 0.01 [deg] }
	}

	requirement def StabilizationTime {
		attribute stabilizationTime : TimeValue;
		constraint { stabilizationTime <= 30 [s] }
	}

	requirement def TorqueCapability {
		attribute maxTorque : TorqueValue;
		constraint { maxTorque >= 0.05 [N*m] }
	}

	requirement def SaturationMonitoring {
		attribute saturated : Boolean;
		attribute commandedTorque : TorqueValue;
		constraint { saturated => commandedTorque == 0 [N*m] }
	}

	requirement pointingAccuracyReq : PointingAccuracy;
	requirement stabilizationTimeReq : StabilizationTime;
	requirement torqueCapabilityReq : TorqueCapability;
	requirement saturationMonitoringReq : SaturationMonitoring;

	part spacecraftSystem : Spacecraft {
		satisfy pointingAccuracyReq by attitudeControlComputer;
		satisfy stabilizationTimeReq by attitudeControlComputer;
		satisfy torqueCapabilityReq by reactionWheelX;
		satisfy torqueCapabilityReq by reactionWheelY;
		satisfy torqueCapabilityReq by reactionWheelZ;
		satisfy saturationMonitoringReq by attitudeControlComputer;
	}

	flow targetAttitudeFlow of TargetAttitude
		from groundStation.targetAttitudeOutPort.targetAttitude
		to spacecraftSystem.targetAttitudePort.targetAttitude;
}
