package 'Powered Exoskeleton System' {
	private import ScalarValues::*;

	package Types {
		attribute def ForceValue :> Real;
		attribute def AngleValue :> Real;
		attribute def AngularVelocityValue :> Real;
		attribute def TorqueValue :> Real;
		attribute def PowerValue :> Real;
		attribute def EnergyValue :> Real;
		attribute def TimeValue :> Real;
		attribute def MassValue :> Real;
		attribute def LengthValue :> Real;

		item def JointSensorData {
			attribute force : ForceValue;
			attribute angle : AngleValue;
			attribute angularVelocity : AngularVelocityValue;
		}
		item def MotorCommand {
			attribute torque : TorqueValue;
		}
		item def BatteryStatus {
			attribute chargeLevel : EnergyValue;
			attribute health : Real;
		}
		item def ModeCommandEvent {
			attribute targetMode : String;
		}
		item def FaultEvent {
			attribute faultType : String;
		}
	}

	package Ports {
		private import Types::*;

		port def PowerInPort {
			in power : PowerValue;
		}
		port def PowerOutPort {
			out power : PowerValue;
		}
		port def SensorDataOutPort {
			out sensorData : JointSensorData;
		}
		port def SensorDataInPort {
			in sensorData : JointSensorData;
		}
		port def MotorCommandOutPort {
			out command : MotorCommand;
		}
		port def MotorCommandInPort {
			in command : MotorCommand;
		}
		port def BatteryStatusOutPort {
			out status : BatteryStatus;
		}
		port def BatteryStatusInPort {
			in status : BatteryStatus;
		}
		port def ModeControlPort {
			in modeCommand : ModeCommandEvent;
		}
		port def FaultOutPort {
			out fault : FaultEvent;
		}
		port def FaultInPort {
			in fault : FaultEvent;
		}
	}

	package Components {
		private import Types::*;
		private import Ports::*;

		part def StructuralFrame {
			attribute material : String = "Carbon Fiber Composite";
			attribute mass : MassValue = 12.0;
		}

		part def ForceSensor {
			port dataOut : SensorDataOutPort;
		}

		part def AngleSensor {
			port dataOut : SensorDataOutPort;
		}

		part def MotorActuator {
			attribute maxTorque : TorqueValue = 80.0;
			port powerIn : PowerInPort;
			port commandIn : MotorCommandInPort;
		}

		part def JointModule {
			port sensorDataOut : SensorDataOutPort;
			port motorCommandIn : MotorCommandInPort;
			port powerIn : PowerInPort;

			part forceSensor : ForceSensor;
			part angleSensor : AngleSensor;
			part motor : MotorActuator;

			flow powerToMotor of PowerValue
				from powerIn.power to motor.powerIn.power;
			flow commandToMotor of MotorCommand
				from motorCommandIn.command to motor.commandIn.command;
			flow forceToOutput of JointSensorData
				from forceSensor.dataOut.sensorData to sensorDataOut.sensorData;
			flow angleToOutput of JointSensorData
				from angleSensor.dataOut.sensorData to sensorDataOut.sensorData;
		}

		calc def ComputeTorque {
			in userForce : ForceValue;
			in jointAngle : AngleValue;
			in assistanceGain : Real;
			in leverArm : LengthValue;
			return torque : TorqueValue = assistanceGain * userForce * leverArm;
		}

		action def SenseComputeActuate {
			in sensorData : JointSensorData;
			in assistanceGain : Real;
			in leverArm : LengthValue;
			out command : MotorCommand;

			action sense {
				in data : JointSensorData = sensorData;
				out force : ForceValue = data.force;
				out angle : AngleValue = data.angle;
			}
			then action compute {
				in force : ForceValue = sense.force;
				in angle : AngleValue = sense.angle;
				in gain : Real = assistanceGain;
				in arm : LengthValue = leverArm;
				out torque : TorqueValue = ComputeTorque(force, angle, gain, arm);
			}
			then action actuate {
				in torque : TorqueValue = compute.torque;
				out cmd : MotorCommand;
			}
			bind command = actuate.cmd;
		}

		part def ControlProcessor {
			port sensorInputs : SensorDataInPort[6];
			port motorCommands : MotorCommandOutPort[6];
			port powerIn : PowerInPort;
			port batteryStatusIn : BatteryStatusInPort;
			port modeControl : ModeControlPort;
			port faultOut : FaultOutPort;

			attribute assistanceGain : Real = 0.5;
			attribute leverArm : LengthValue = 0.3;
			attribute lowBatteryThreshold : EnergyValue = 60.0;
			attribute currentMode : String = "standby";
			attribute faultDetected : Boolean = false;

			action controlCycle {
				loop cycle {
					action readSensors {
						out sensorArray : JointSensorData[6];
					}
					then action checkSafety {
						in batteryLevel : EnergyValue;
						in threshold : EnergyValue;
						out fault : Boolean;
					}
					then if checkSafety.fault {
						action raiseFault {
							out faultEvent : FaultEvent;
						}
						then done;
					} else {
						action computeCommands {
							in sensorArray : JointSensorData[6];
							in gain : Real;
							in arm : LengthValue;
							out commandArray : MotorCommand[6];
						}
						then action writeCommands {
							in commandArray : MotorCommand[6];
						}
					}
				}
			}

			action disableMotors {
				action disable;
			}
		}

		part def BatteryPack {
			attribute capacity : EnergyValue = 600.0;
			attribute currentCharge : EnergyValue = 600.0;
			attribute powerDraw : PowerValue = 100.0;
			port powerOut : PowerOutPort;
			port statusOut : BatteryStatusOutPort;
		}
	}

	package System {
		private import Types::*;
		private import Ports::*;
		private import Components::*;

		state def ExoskeletonStates {
			in modeCommand : ModeCommandEvent;
			in fault : FaultEvent;
			state standby;
			state active;
			state emergency;

			transition standby_to_active
				from standby to active
				when modeCommand.targetMode == "active";
			transition active_to_standby
				from active to standby
				when modeCommand.targetMode == "standby";
			transition active_to_emergency
				from active to emergency
				when fault.faultType != "";
			transition standby_to_emergency
				from standby to emergency
				when fault.faultType != "";
			transition emergency_to_standby
				from emergency to standby
				when modeCommand.targetMode == "standby";
		}

		part def Exoskeleton {
			part frame : StructuralFrame;
			part hipJoint : JointModule;
			part kneeJoint : JointModule;
			part ankleJoint : JointModule;
			part shoulderJoint : JointModule;
			part elbowJoint : JointModule;
			part lumbarJoint : JointModule;
			part controlProcessor : ControlProcessor;
			part battery : BatteryPack;

			port modeControl : ModeControlPort;
			port faultIn : FaultInPort;

			flow faultFlow of FaultEvent
				from controlProcessor.faultOut.fault to faultIn.fault;

			flow powerToProcessor of PowerValue
				from battery.powerOut.power to controlProcessor.powerIn.power;
			flow powerToHip of PowerValue
				from battery.powerOut.power to hipJoint.powerIn.power;
			flow powerToKnee of PowerValue
				from battery.powerOut.power to kneeJoint.powerIn.power;
			flow powerToAnkle of PowerValue
				from battery.powerOut.power to ankleJoint.powerIn.power;
			flow powerToShoulder of PowerValue
				from battery.powerOut.power to shoulderJoint.powerIn.power;
			flow powerToElbow of PowerValue
				from battery.powerOut.power to elbowJoint.powerIn.power;
			flow powerToLumbar of PowerValue
				from battery.powerOut.power to lumbarJoint.powerIn.power;

			flow hipSensorData of JointSensorData
				from hipJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(1).sensorData;
			flow kneeSensorData of JointSensorData
				from kneeJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(2).sensorData;
			flow ankleSensorData of JointSensorData
				from ankleJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(3).sensorData;
			flow shoulderSensorData of JointSensorData
				from shoulderJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(4).sensorData;
			flow elbowSensorData of JointSensorData
				from elbowJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(5).sensorData;
			flow lumbarSensorData of JointSensorData
				from lumbarJoint.sensorDataOut.sensorData to controlProcessor.sensorInputs#(6).sensorData;

			flow hipCommand of MotorCommand
				from controlProcessor.motorCommands#(1).command to hipJoint.motorCommandIn.command;
			flow kneeCommand of MotorCommand
				from controlProcessor.motorCommands#(2).command to kneeJoint.motorCommandIn.command;
			flow ankleCommand of MotorCommand
				from controlProcessor.motorCommands#(3).command to ankleJoint.motorCommandIn.command;
			flow shoulderCommand of MotorCommand
				from controlProcessor.motorCommands#(4).command to shoulderJoint.motorCommandIn.command;
			flow elbowCommand of MotorCommand
				from controlProcessor.motorCommands#(5).command to elbowJoint.motorCommandIn.command;
			flow lumbarCommand of MotorCommand
				from controlProcessor.motorCommands#(6).command to lumbarJoint.motorCommandIn.command;

			flow batteryStatusFlow of BatteryStatus
				from battery.statusOut.status to controlProcessor.batteryStatusIn.status;

			exhibit exoStates : ExoskeletonStates {
				in modeCommand = modeControl.modeCommand;
				in fault = faultIn.fault;
			}
		}
	}

	package Requirements {
		private import Types::*;
		private import Components::*;
		private import System::*;

		requirement def AssistiveTorqueRequirement {
			text "The exoskeleton shall provide assistive torque proportional to the user's applied force at each joint, scaled by the configured assistance level.";
			attribute minAssistGain : Real = 0.1;
			attribute maxAssistGain : Real = 1.0;
		}
		requirement def ResponseTimeRequirement {
			text "The sense-compute-actuate cycle shall complete within 10 milliseconds to ensure natural and responsive assistance.";
			attribute maxCycleTime : TimeValue = 0.01;
		}
		requirement def BatteryLifeRequirement {
			text "The battery pack shall provide sufficient energy for at least 6 hours of continuous operation under normal load on a single charge.";
			attribute minDuration : TimeValue = 6.0;
		}
		requirement def SafetyTransitionRequirement {
			text "The system shall transition to emergency mode within 100 milliseconds upon detection of a safety-critical fault, such as low battery or joint malfunction.";
			attribute maxFaultResponseTime : TimeValue = 0.1;
		}
		requirement def StructuralIntegrityRequirement {
			text "The structural frame shall be constructed from carbon fiber composite or equivalent material with a total suit mass not exceeding 15 kilograms.";
			attribute maxFrameMass : MassValue = 15.0;
		}

		requirement assistTorqueReq : AssistiveTorqueRequirement;
		requirement responseTimeReq : ResponseTimeRequirement;
		requirement batteryLifeReq : BatteryLifeRequirement;
		requirement safetyTransitionReq : SafetyTransitionRequirement;
		requirement structuralIntegrityReq : StructuralIntegrityRequirement;

		satisfy assistTorqueReq by ComputeTorque;
		satisfy responseTimeReq by SenseComputeActuate;
		satisfy batteryLifeReq by BatteryPack;
		satisfy safetyTransitionReq by ExoskeletonStates;
		satisfy structuralIntegrityReq by StructuralFrame;
	}
}
