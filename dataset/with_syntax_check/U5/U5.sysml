package 'Bang-Bang Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def PositionValue :> ISQ::LengthValue;
	attribute def VelocityValue :> ISQ::SpeedValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def TimeValue :> ISQ::TimeValue;

	enum def ActuatorState {
		enum fullForward;
		enum fullReverse;
		enum off;
	}

	item def TargetObject {
		attribute mass : ISQ::MassValue;
		attribute currentPosition : PositionValue;
		attribute currentVelocity : VelocityValue;
	}

	port def SensorPort {
		out item positionReading : PositionValue;
		out item velocityReading : VelocityValue;
	}

	port def ControlPort {
		in item setpoint : PositionValue;
		in item feedback : PositionValue;
		out item controlCommand : ActuatorState;
	}

	port def ActuatorPort {
		in item command : ActuatorState;
		out item outputForce : ForceValue;
	}

	action def MeasurePosition {
		in targetObj : TargetObject;
		out measuredPosition : PositionValue;
		out measuredVelocity : VelocityValue;
	}

	action def BangBangControlLogic {
		in targetPosition : PositionValue;
		in currentPosition : PositionValue;
		in deadbandTolerance : PositionValue;
		out commandSignal : ActuatorState;
	}

	action def GenerateForce {
		in commandSignal : ActuatorState;
		in maxForce : ForceValue;
		out appliedForce : ForceValue;
	}

	action def ApplyForceToTarget {
		in appliedForce : ForceValue;
		inout targetObj : TargetObject;
	}

	action def ExecuteBangBangControl {
		in targetPosition : PositionValue;
		in deadband : PositionValue;
		in maxForce : ForceValue;
		inout targetObj : TargetObject;

		first start;
		then merge controlCycle;

		then action measure : MeasurePosition {
			in targetObj = targetObj;
			out measuredPosition : PositionValue;
			out measuredVelocity : VelocityValue;
		}

		then action control : BangBangControlLogic {
			in targetPosition = targetPosition;
			in currentPosition = measure.measuredPosition;
			in deadbandTolerance = deadband;
			out commandSignal : ActuatorState;
		}

		then decide;
			if control.commandSignal == ActuatorState::fullForward then applyForward;
			if control.commandSignal == ActuatorState::fullReverse then applyReverse;
			if control.commandSignal == ActuatorState::off then stopMotion;

		action applyForward : GenerateForce {
			in commandSignal = ActuatorState::fullForward;
			in maxForce = maxForce;
			out appliedForce : ForceValue;
		}
		then action moveForward : ApplyForceToTarget {
			in appliedForce = applyForward.appliedForce;
			inout targetObj = targetObj;
		}
		then controlCycle;

		action applyReverse : GenerateForce {
			in commandSignal = ActuatorState::fullReverse;
			in maxForce = maxForce;
			out appliedForce : ForceValue;
		}
		then action moveReverse : ApplyForceToTarget {
			in appliedForce = applyReverse.appliedForce;
			inout targetObj = targetObj;
		}
		then controlCycle;

		action stopMotion : GenerateForce {
			in commandSignal = ActuatorState::off;
			in maxForce = maxForce;
			out appliedForce : ForceValue;
		}
		then done;
	}

	part def PositionSensor {
		attribute accuracy : PositionValue;
		attribute samplingRate : Real;

		port sensorOutput : SensorPort;

		perform action sensing : MeasurePosition;
	}

	part def BangBangController {
		attribute targetSetpoint : PositionValue;
		attribute deadbandWidth : PositionValue;

		port feedbackInput : SensorPort;
		port commandOutput : ControlPort;

		perform action controlAction : BangBangControlLogic;
	}

	part def LinearActuator {
		attribute maximumForce : ForceValue;
		attribute minimumForce : ForceValue;
		attribute responseTime : TimeValue;

		port controlInput : ActuatorPort;
		port forceOutput {
			out item force : ForceValue;
		}

		perform action actuate : GenerateForce;
	}

	part def RoboticManipulator {
		attribute workspaceRange : PositionValue;
		attribute maxPayload : ISQ::MassValue;

		port forceInput {
			in item force : ForceValue;
		}

		ref item target : TargetObject;

		perform action manipulate : ApplyForceToTarget;
	}

	part def BangBangRobot {
		attribute operationalRange : PositionValue;
		attribute controlPrecision : PositionValue;

		part sensor : PositionSensor {
			:>> accuracy = 0.01[mm];
			:>> samplingRate = 100.0;
		}

		part controller : BangBangController {
			:>> targetSetpoint = 150.0[mm];
			:>> deadbandWidth = 1.0[mm];
		}

		part actuator : LinearActuator {
			:>> maximumForce = 800.0[N];
			:>> minimumForce = -800.0[N];
			:>> responseTime = 0.02[s];
		}

		part manipulator : RoboticManipulator {
			:>> workspaceRange = 500.0[mm];
			:>> maxPayload = 15.0[kg];
		}

		connection sensorToController connect sensor.sensorOutput to controller.feedbackInput;
		connection controllerToActuator connect controller.commandOutput to actuator.controlInput;
		connection actuatorToManipulator connect actuator.forceOutput to manipulator.forceInput;

		perform action bangBangOperation : ExecuteBangBangControl;
	}

	state def RobotOperationStates {
		entry; then initializing;

		state initializing {
			entry action systemCheck;
		}
		accept SystemReady
		then standby;

		state standby {
			entry action awaitCommand;
		}
		accept TaskCommand
		then executing;

		state executing {
			entry action beginControl;
			do action runBangBang : ExecuteBangBangControl;
		}
		accept TargetAchieved
		then holding;
		accept TaskAbort
		then standby;

		state holding {
			entry action lockPosition;
		}
		accept ReleaseTarget
		then standby;

		accept EmergencyStop
		then emergency;

		state emergency {
			entry action safetyShutdown;
		}
		accept SystemReset
		then initializing;
	}

	package LogicalModel {
		action def PerformPrimaryTask;
		action def PositionTarget;

		part def TaskExecutionUnit;

		action performPrimaryTask : PerformPrimaryTask {
			action positionTarget : PositionTarget;
		}

		part taskExecutor : TaskExecutionUnit {
			perform performPrimaryTask.positionTarget;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part def RoboticWorkCell {
			attribute cellIdentifier : String;
			attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		}

		part roboticWorkCell : RoboticWorkCell {
			:>> cellIdentifier = "CELL-BB-01";
			:>> operatingTemperature = 298.15[K];

			part bangBangRobot : BangBangRobot {
				:>> operationalRange = 500.0[mm];
				:>> controlPrecision = 1.0[mm];

				perform performPrimaryTask.positionTarget;
			}

			item workTarget : TargetObject {
				:>> mass = 8.0[kg];
				:>> currentPosition = 0.0[mm];
				:>> currentVelocity = 0.0[mm/s];
			}
		}

		allocate taskExecutor to roboticWorkCell {
			allocate taskExecutor.positionTarget to roboticWorkCell.bangBangRobot.bangBangOperation;
		}
	}

	requirement def PositioningPrecisionRequirement {
		doc /* The bang-bang robot shall position targets within specified deadband tolerance. */

		subject robot : BangBangRobot;

		require constraint {
			robot.controlPrecision <= 2.0[mm]
		}
	}

	requirement def ForceCapabilityRequirement {
		doc /* The actuator shall provide sufficient force for target manipulation. */

		subject robot : BangBangRobot;

		require constraint {
			robot.actuator.maximumForce >= 500.0[N]
		}
	}

	requirement def PayloadCapacityRequirement {
		doc /* The manipulator shall handle targets up to specified mass. */

		subject robot : BangBangRobot;

		require constraint {
			robot.manipulator.maxPayload >= 10.0[kg]
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The actuator shall respond to control commands within acceptable time. */

		subject robot : BangBangRobot;

		require constraint {
			robot.actuator.responseTime <= 0.05[s]
		}
	}

	requirement primaryTaskRequirement : PositioningPrecisionRequirement {
		subject testRobot :> PhysicalModel::roboticWorkCell.bangBangRobot;
	}

	requirement forceRequirement : ForceCapabilityRequirement {
		subject testRobot :> PhysicalModel::roboticWorkCell.bangBangRobot;
	}

	requirement payloadRequirement : PayloadCapacityRequirement {
		subject testRobot :> PhysicalModel::roboticWorkCell.bangBangRobot;
	}

	allocation def LogicalToPhysicalMapping {
		end logical : LogicalModel::TaskExecutionUnit;
		end physical : PhysicalModel::RoboticWorkCell;
	}

	allocation systemAllocation : LogicalToPhysicalMapping
		allocate LogicalModel::taskExecutor to PhysicalModel::roboticWorkCell;

	individual def TestWorkCell :> PhysicalModel::RoboticWorkCell;
	individual def TestTarget1 :> TargetObject;
	individual def TestTarget2 :> TargetObject;

	individual testWorkCell : TestWorkCell :> PhysicalModel::roboticWorkCell {
		timeslice operationTest1 {
			perform action :>> bangBangRobot.bangBangOperation {
				in :>> targetPosition = 150.0[mm];
				in :>> deadband = 1.0[mm];
				in :>> maxForce = 800.0[N];
				inout individual :>> targetObj : TestTarget1 {
					:>> mass = 5.0[kg];
					:>> currentPosition = 0.0[mm];
					:>> currentVelocity = 0.0[mm/s];
				}
			}
		}
		then timeslice operationTest2 {
			perform action :>> bangBangRobot.bangBangOperation {
				in :>> targetPosition = 300.0[mm];
				in :>> deadband = 1.0[mm];
				in :>> maxForce = 800.0[N];
				inout individual :>> targetObj : TestTarget2 {
					:>> mass = 12.0[kg];
					:>> currentPosition = 150.0[mm];
					:>> currentVelocity = 0.0[mm/s];
				}
			}
		}
	}
}
