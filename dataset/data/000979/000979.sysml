package AttitudeControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def EulerAngles {
		attribute roll : ISQ::AngleValue;
		attribute pitch : ISQ::AngleValue;
		attribute yaw : ISQ::AngleValue;
	}
	
	attribute def AngularRates {
		attribute rollRate : ISQ::AngularVelocityValue;
		attribute pitchRate : ISQ::AngularVelocityValue;
		attribute yawRate : ISQ::AngularVelocityValue;
	}
	
	item def AttitudeMeasurement {
		attribute angles : EulerAngles;
		attribute rates : AngularRates;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def AttitudeCommand {
		attribute targetAngles : EulerAngles;
		attribute maxError : ISQ::AngleValue;
	}
	
	item def ControlTorques {
		attribute rollTorque : ISQ::MomentOfForceValue;
		attribute pitchTorque : ISQ::MomentOfForceValue;
		attribute yawTorque : ISQ::MomentOfForceValue;
	}
	
	port def AttitudeSensorPort {
		out item measurement : AttitudeMeasurement;
	}
	
	port def AttitudeCommandPort {
		in item command : AttitudeCommand;
	}
	
	port def ActuatorCommandPort {
		in item torques : ControlTorques;
	}
	
	part def InertiaMeasurementUnit {
		port sensorOutput : AttitudeSensorPort;
		attribute sampleRate : ISQ::FrequencyValue;
		attribute noiseLevel : ISQ::AngularVelocityValue;
	}
	
	part def StarTracker {
		port sensorOutput : AttitudeSensorPort;
		attribute accuracy : ISQ::AngleValue;
		attribute updateRate : ISQ::FrequencyValue;
	}
	
	part def ReactionWheel {
		port commandInput : ActuatorCommandPort;
		attribute maxTorque : ISQ::MomentOfForceValue;
		attribute maxMomentum : ISQ::AngularMomentumValue;
		attribute currentSpeed : ISQ::AngularVelocityValue;
	}
	
	part def AttitudeController {
		port commandInput : AttitudeCommandPort;
		port imuInput : AttitudeSensorPort;
		port starTrackerInput : AttitudeSensorPort;
		port actuatorOutput : ActuatorCommandPort;
		attribute proportionalGain : Real;
		attribute derivativeGain : Real;
		attribute integralGain : Real;
	}
	
	part def Spacecraft {
		attribute mass : ISQ::MassValue;
		attribute inertiaX : ISQ::MomentOfInertiaValue;
		attribute inertiaY : ISQ::MomentOfInertiaValue;
		attribute inertiaZ : ISQ::MomentOfInertiaValue;
		
		part imu : InertiaMeasurementUnit;
		part starTracker : StarTracker;
		part controller : AttitudeController;
		part wheelX : ReactionWheel;
		part wheelY : ReactionWheel;
		part wheelZ : ReactionWheel;
		
		port commandPort : AttitudeCommandPort;
		
		connection imuToController connect imu.sensorOutput to controller.imuInput;
		connection starTrackerToController connect starTracker.sensorOutput to controller.starTrackerInput;
		connection commandToController connect commandPort to controller.commandInput;
		connection controllerToWheelX connect controller.actuatorOutput to wheelX.commandInput;
		connection controllerToWheelY connect controller.actuatorOutput to wheelY.commandInput;
		connection controllerToWheelZ connect controller.actuatorOutput to wheelZ.commandInput;
	}
	
	action def EstimateAttitude {
		in imuMeasurement : AttitudeMeasurement;
		in starMeasurement : AttitudeMeasurement;
		out estimatedAttitude : AttitudeMeasurement;
		
		first start;
		then assign estimatedAttitude.angles.roll := (imuMeasurement.angles.roll + starMeasurement.angles.roll) / 2.0;
		then assign estimatedAttitude.angles.pitch := (imuMeasurement.angles.pitch + starMeasurement.angles.pitch) / 2.0;
		then assign estimatedAttitude.angles.yaw := (imuMeasurement.angles.yaw + starMeasurement.angles.yaw) / 2.0;
		then assign estimatedAttitude.rates := imuMeasurement.rates;
		then done;
	}
	
	action def ComputeControlTorques {
		in targetAttitude : AttitudeCommand;
		in currentAttitude : AttitudeMeasurement;
		in kp : Real;
		in kd : Real;
		out torques : ControlTorques;
		
		private attribute rollError : Real;
		private attribute pitchError : Real;
		private attribute yawError : Real;
		
		first start;
		then assign rollError := targetAttitude.targetAngles.roll - currentAttitude.angles.roll;
		then assign pitchError := targetAttitude.targetAngles.pitch - currentAttitude.angles.pitch;
		then assign yawError := targetAttitude.targetAngles.yaw - currentAttitude.angles.yaw;
		then assign torques.rollTorque := kp * rollError - kd * currentAttitude.rates.rollRate;
		then assign torques.pitchTorque := kp * pitchError - kd * currentAttitude.rates.pitchRate;
		then assign torques.yawTorque := kp * yawError - kd * currentAttitude.rates.yawRate;
		then done;
	}
	
	action def AttitudeControlCycle {
		in targetCommand : AttitudeCommand;
		in imuData : AttitudeMeasurement;
		in starData : AttitudeMeasurement;
		out commandTorques : ControlTorques;
		
		first start;
		then action estimation : EstimateAttitude {
			in imuMeasurement = imuData;
			in starMeasurement = starData;
			out estimatedAttitude;
		}
		then action control : ComputeControlTorques {
			in targetAttitude = targetCommand;
			in currentAttitude = estimation.estimatedAttitude;
			in kp = 1.5;
			in kd = 0.8;
			out torques;
		}
		then assign commandTorques := control.torques;
		then done;
	}
	
	action def MaintainAttitude {
		in targetCommand : AttitudeCommand;
		
		first start;
		then merge continueControl;
		
		then action acquireSensorData {
			out imuMeasurement : AttitudeMeasurement;
			out starMeasurement : AttitudeMeasurement;
		}
		
		then action controlCycle : AttitudeControlCycle {
			in targetCommand = targetCommand;
			in imuData = acquireSensorData.imuMeasurement;
			in starData = acquireSensorData.starMeasurement;
			out commandTorques;
		}
		
		then action applyTorques {
			in torques : ControlTorques = controlCycle.commandTorques;
		}
		
		then decide;
			if true then continueControl;
			else done;
	}
	
	state def AttitudeControlMode {
		entry action entryAction;
		then idle;
		
		state idle;
		accept commandReceived
		then acquiring;
		
		state acquiring;
		accept targetAchieved
		then holding;
		accept newCommand
		then acquiring;
		
		state holding;
		accept newCommand
		then acquiring;
		accept safeModeTriggered
		then safing;
		
		state safing;
		accept recoveryCommand
		then idle;
	}
	
	part attitudeControlSystem : Spacecraft {
		perform action primaryFunction[*] ordered references MaintainAttitude;
		exhibit state operationalMode : AttitudeControlMode;
	}
	
	requirement def PointingAccuracyRequirement {
		doc /* The attitude control system shall maintain spacecraft pointing accuracy within specified limits. */
		subject spacecraft : Spacecraft;
		require constraint {
			doc /* Pointing error shall be less than 0.1 degrees (3-sigma) */
		}
	}
	
	requirement def StabilityRequirement {
		doc /* The attitude control system shall stabilize spacecraft attitude within specified time. */
		subject spacecraft : Spacecraft;
		require constraint {
			doc /* Settling time shall be less than 60 seconds */
		}
	}
	
	requirement def ActuatorCapabilityRequirement {
		doc /* Reaction wheels shall provide sufficient torque for attitude control. */
		subject wheel : ReactionWheel;
		require constraint {
			doc /* Maximum torque shall be at least 0.2 Nm per axis */
		}
	}
	
	requirement <'ACS-REQ-001'> attitudeControlMission {
		doc /* The attitude control system shall autonomously maintain spacecraft orientation to support mission objectives. */
		
		assume constraint operationalEnvironment {
			doc /* Spacecraft operates in stable orbit with predictable disturbances */
		}
		
		require PointingAccuracyRequirement;
		require StabilityRequirement;
		require ActuatorCapabilityRequirement;
	}
}
