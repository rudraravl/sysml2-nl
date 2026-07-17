package 'Flow Control Valve System' {
    attribute def testComplete;
    attribute def faultDetected;
    attribute def resetCommand;
    attribute def shutdownCommand;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlowRateValue :> Real;
	attribute def PressureValue :> Real;
	attribute def PositionValue :> Real;
	attribute def TemperatureValue :> Real;
	
	item def Fluid {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def ControlCommand {
		attribute targetFlowRate : FlowRateValue;
	}
	
	item def FlowMeasurement {
		attribute measuredFlow : FlowRateValue;
		attribute timestamp : Real;
	}
	
	port def FluidInletPort {
		attribute inletPressure : PressureValue;
		in item fluidStream : Fluid;
	}
	
	port def FluidOutletPort {
		attribute outletPressure : PressureValue;
		out item fluidStream : Fluid;
	}
	
	port def ControlInputPort {
		in item command : ControlCommand;
	}
	
	port def SensorOutputPort {
		out item measurement : FlowMeasurement;
	}
	
	part def ValveBody {
		attribute orificeArea : Real;
		attribute maxFlowCapacity : FlowRateValue;
		
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
	}
	
	part def Actuator {
		attribute currentPosition : PositionValue;
		attribute maxPosition : PositionValue;
		attribute minPosition : PositionValue;
		
		port controlInput : ControlInputPort;
	}
	
	part def FlowSensor {
		attribute sensorAccuracy : Real;
		attribute measuredFlowRate : FlowRateValue;
		
		port sensorOutput : SensorOutputPort;
	}
	
	part def Controller {
		attribute setpointFlowRate : FlowRateValue;
		attribute proportionalGain : Real;
		attribute integralGain : Real;
		attribute derivativeGain : Real;
		attribute errorAccumulation : Real;
		attribute previousError : Real;
		
		port feedbackInput : ~SensorOutputPort;
		port actuatorOutput : ~ControlInputPort;
	}
	
	action def MeasureFlow {
		in fluidStream : Fluid;
		out flowMeasurement : FlowMeasurement;
	}
	
	action def CalculateControlSignal {
		in setpoint : FlowRateValue;
		in measuredFlow : FlowRateValue;
		in proportionalGain : Real;
		in integralGain : Real;
		in derivativeGain : Real;
		in errorAccumulation : Real;
		in previousError : Real;
		out controlCommand : ControlCommand;
		out newErrorAccumulation : Real;
		out newPreviousError : Real;
	}
	
	action def AdjustValvePosition {
		in command : ControlCommand;
		in currentPosition : PositionValue;
		out newPosition : PositionValue;
	}
	
	action def ModulateFluidFlow {
		in valvePosition : PositionValue;
		in inletFluid : Fluid;
		out outletFluid : Fluid;
		out actualFlowRate : FlowRateValue;
	}
	
	action def RegulateFlowControl {
		in setpoint : FlowRateValue;
		out flowRate : FlowRateValue;
		out valvePosition : PositionValue;
		
		first start;
		then merge controlLoop;
		
		then action measureCurrentFlow : MeasureFlow {
			in fluidStream : Fluid;
			out flowMeasurement : FlowMeasurement;
		}
		
		then action computeControl : CalculateControlSignal {
			in setpoint = RegulateFlowControl::setpoint;
			in measuredFlow = measureCurrentFlow.flowMeasurement.measuredFlow;
			in proportionalGain : Real;
			in integralGain : Real;
			in derivativeGain : Real;
			in errorAccumulation : Real;
			in previousError : Real;
			out controlCommand : ControlCommand;
			out newErrorAccumulation : Real;
			out newPreviousError : Real;
		}
		
		then action adjustValve : AdjustValvePosition {
			in command = computeControl.controlCommand;
			in currentPosition : PositionValue;
			out newPosition : PositionValue;
		}
		
		then action modulateFlow : ModulateFluidFlow {
			in valvePosition = adjustValve.newPosition;
			in inletFluid : Fluid;
			out outletFluid : Fluid;
			out actualFlowRate : FlowRateValue;
		}
		
		then decide;
			if (modulateFlow.actualFlowRate - setpoint) > 0.5 or (setpoint - modulateFlow.actualFlowRate) > 0.5 then controlLoop;
			if (modulateFlow.actualFlowRate - setpoint) <= 0.5 and (setpoint - modulateFlow.actualFlowRate) <= 0.5 then steadyState;
		
		action steadyState;
		then controlLoop;
	}
	
	state def ValveOperationalStates {
		entry; then closed;
		
		state closed;
		
		transition closed_to_initializing
			first closed
			accept startCommand : ControlCommand
			then initializing;
		
		state initializing;
		
		transition initializing_to_regulating
			first initializing
			accept testComplete
			then regulating;
		
		state regulating;
		
		transition regulating_to_fault
			first regulating
			accept faultDetected
			then fault;
		
		state fault;
		
		transition fault_to_closed
			first fault
			accept resetCommand
			then closed;
		
		transition regulating_to_closed
			first regulating
			accept shutdownCommand
			then closed;
	}
	
	part def FlowControlValve {
		attribute setpointFlow : FlowRateValue;
		attribute toleranceBand : FlowRateValue;
		attribute operatingTemperature : TemperatureValue;
		attribute maxOperatingPressure : PressureValue;
		
		port systemInlet : FluidInletPort;
		port systemOutlet : FluidOutletPort;
		port externalControl : ControlInputPort;
		
		part valveBody : ValveBody {
			port :>> inlet = systemInlet;
			port :>> outlet = systemOutlet;
		}
		
		part actuator : Actuator {
			port :>> controlInput = externalControl;
		}
		
		part flowSensor : FlowSensor;
		
		part controller : Controller;
		
		connect controller.feedbackInput to flowSensor.sensorOutput;
		connect controller.actuatorOutput to actuator.controlInput;
		
		exhibit state operationalStates : ValveOperationalStates;
		
		perform action regulateFlow[*] ordered;
	}
	
	requirement def FlowRegulationRequirement {
		doc /* The flow control valve system shall regulate fluid flow rate to maintain 
		        the commanded setpoint within the specified tolerance band under normal 
		        operating conditions. */
		
		subject valve : FlowControlValve;
		
		require constraint flowAccuracy {
			valve.flowSensor.measuredFlowRate >= valve.setpointFlow - valve.toleranceBand and
			valve.flowSensor.measuredFlowRate <= valve.setpointFlow + valve.toleranceBand
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The flow control valve shall achieve 95% of a new setpoint flow rate 
		        within 3 seconds of receiving a setpoint change command. */
		
		subject valve : FlowControlValve;
		
		attribute maxResponseTime : Real = 3.0;
		attribute settlingPercentage : Real = 95.0;
	}
	
	requirement def PressureContainmentRequirement {
		doc /* The valve body shall safely contain fluid at pressures up to the 
		        maximum operating pressure without leakage or structural failure. */
		
		subject body : ValveBody;
		
		attribute maxAllowablePressure : PressureValue = 1500.0;
		
		require constraint pressureSafety {
			body.inlet.inletPressure <= maxAllowablePressure and
			body.outlet.outletPressure <= maxAllowablePressure
		}
	}
	
	requirement def PositionAccuracyRequirement {
		doc /* The actuator shall position the valve to within 1% of the commanded 
		        position under all operating conditions. */
		
		subject actuator : Actuator;
		
		attribute positionTolerance : Real = 1.0;
	}
	
	requirement def SystemReliabilityRequirement {
		doc /* The flow control valve system shall operate continuously for a minimum 
		        of 10000 hours between failures under normal operating conditions. */
		
		subject valve : FlowControlValve;
		
		attribute meanTimeBetweenFailures : Real = 10000.0;
	}
	
	part flowControlValveSystem : FlowControlValve {
		attribute :>> setpointFlow = 100.0;
		attribute :>> toleranceBand = 2.0;
		attribute :>> operatingTemperature = 298.15;
		attribute :>> maxOperatingPressure = 1500.0;
	}
	
	requirement flowRegulation : FlowRegulationRequirement {
		subject valve = flowControlValveSystem;
	}
	
	requirement responseTime : ResponseTimeRequirement {
		subject valve = flowControlValveSystem;
	}
	
	requirement pressureContainment : PressureContainmentRequirement {
		subject body = flowControlValveSystem.valveBody;
	}
	
	requirement positionAccuracy : PositionAccuracyRequirement {
		subject actuator = flowControlValveSystem.actuator;
	}
	
	requirement systemReliability : SystemReliabilityRequirement {
		subject valve = flowControlValveSystem;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Flow Control Valve System'::*;

    part testSubject : FlowControlValve {
        exhibit state operationalStates : ValveOperationalStates;
    }

    action orchestrator {
        item testFluidStream : Fluid {
            attribute temperature : TemperatureValue = 0.0;
            attribute pressure : PressureValue = 0.0;
        }
        action actionProbe : MeasureFlow {
            in fluidStream = testFluidStream;
        }
        first actionProbe;
    }
}
