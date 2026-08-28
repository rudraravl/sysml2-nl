package 'Flow Control Valve System' {
	private import ScalarValues::*;
	private import ISQ::*;

	unit cubicMetersPerSecond;
	unit percent;
	unit pascals;

	value type FlowRateValue :> Real { unit cubicMetersPerSecond; }
	value type ValvePositionValue :> Real { unit percent; }
	value type PressureValue :> Real { unit pascals; }

	item def Fluid;
	item def TargetFlowCommand {
		attribute targetFlowRate : FlowRateValue;
	}
	item def FlowMeasurement {
		attribute actualFlowRate : FlowRateValue;
	}
	item def ValveCommand {
		attribute position : ValvePositionValue;
	}

	attribute def 'Start Signal';
	attribute def 'Fault Signal';
	attribute def 'Reset Signal';
	attribute def 'Diagnostics Passed';

	part def ValveBody {
		port inletPort { in fluidIn : Fluid; }
		port outletPort { out fluidOut : Fluid; }
		port valvePositionPort { in valvePosition : ValvePositionValue; }
		attribute maxPressure : PressureValue;
	}

	part def Actuator {
		port commandPort { in valveCommand : ValveCommand; }
		port positionPort { out valvePosition : ValvePositionValue; }
	}

	part def FlowSensor {
		port fluidInPort { in fluid : Fluid; }
		port fluidOutPort { out fluid : Fluid; }
		port measurementPort { out flowMeasurement : FlowMeasurement; }
	}

	part def Controller {
		port targetPort { in targetFlowCommand : TargetFlowCommand; }
		port measurementPort { in flowMeasurement : FlowMeasurement; }
		port commandPort { out valveCommand : ValveCommand; }
		perform action 'calculate command' : 'Calculate Valve Command';
		exhibit state 'controller states' : 'Controller States';
	}

	part def FlowControlValveSystem {
		port targetPort { in targetFlowCommand : TargetFlowCommand; }
		port inletPort { in fluidIn : Fluid; }
		port outletPort { out fluidOut : Fluid; }

		part valveBody : ValveBody;
		part actuator : Actuator;
		part flowSensor : FlowSensor;
		part controller : Controller;

		exhibit state 'system states' : 'System States';
	}

	state def 'System States' {
		state closed;
		state initializing;
		state regulating;
		state fault;

		transition initial then closed;
		transition 'closed-to-initializing'
			first closed
			accept 'Start Signal'
			then initializing;
		transition 'initializing-to-regulating'
			first initializing
			accept 'Diagnostics Passed'
			then regulating;
		transition 'regulating-to-fault'
			first regulating
			accept 'Fault Signal'
			then fault;
		transition 'initializing-to-fault'
			first initializing
			accept 'Fault Signal'
			then fault;
		transition 'fault-to-closed'
			first fault
			accept 'Reset Signal'
			then closed;
	}

	state def 'Controller States' {
		state idle;
		state active;
		transition initial then idle;
		transition 'idle-to-active'
			first idle
			accept 'TargetFlowCommand'
			then active;
	}

	action def 'Calculate Valve Command' {
		in targetFlow : FlowRateValue;
		in actualFlow : FlowRateValue;
		out command : ValvePositionValue;
	}

	requirement def 'High Pressure Safety Requirement' {
		doc /* The valve body shall safely handle high-pressure fluids without leaking or failing. */
		attribute maxPressure : PressureValue;
	}

	requirement def 'Flow Accuracy Requirement' {
		doc /* The system shall maintain the actual flow rate within the required accuracy of the target flow rate. */
		attribute requiredAccuracy : FlowRateValue;
	}

	requirement def 'Response Time Requirement' {
		doc /* The system shall respond to changes in desired flow rates within a specified time. */
		attribute maxResponseTime : Time;
	}

	requirement def 'Reliability Requirement' {
		doc /* The system shall be highly reliable for continuous operation. */
		attribute minMTBF : Time;
	}

	part flowControlValveSystem : FlowControlValveSystem {
		part valveBody : ValveBody {
			satisfy 'High Pressure Safety Requirement';
		}

		flow fluidInFlow of Fluid from inletPort.fluidIn to valveBody.inletPort.fluidIn;
		flow fluidValveToSensor of Fluid from valveBody.outletPort.fluidOut to flowSensor.fluidInPort.fluid;
		flow fluidOutFlow of Fluid from flowSensor.fluidOutPort.fluid to outletPort.fluidOut;

		flow targetFlow of TargetFlowCommand from targetPort.targetFlowCommand to controller.targetPort.targetFlowCommand;
		flow commandFlow of ValveCommand from controller.commandPort.valveCommand to actuator.commandPort.valveCommand;
		flow positionFlow of ValvePositionValue from actuator.positionPort.valvePosition to valveBody.valvePositionPort.valvePosition;
		flow measurementFlow of FlowMeasurement from flowSensor.measurementPort.flowMeasurement to controller.measurementPort.flowMeasurement;

		satisfy 'Flow Accuracy Requirement';
		satisfy 'Response Time Requirement';
		satisfy 'Reliability Requirement';
	}
}
