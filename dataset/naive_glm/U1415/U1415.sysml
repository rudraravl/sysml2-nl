package FluidTransportAndRegulationSystem {

	import ISQ::*;
	import ScalarValues::*;

	// ---- Value types with units ----
	value type PressureValue > Real {
		unit 'Pa';
	}
	value type FlowRateValue > Real {
		unit 'm3/s';
	}
	value type DensityValue > Real {
		unit 'kg/m3';
	}
	value type DynamicViscosityValue > Real {
		unit 'Pa.s';
	}
	value type LengthValue > Real {
		unit 'm';
	}
	value type DiameterValue > Real {
		unit 'm';
	}
	value type RoughnessValue > Real {
		unit 'm';
	}
	value type ValveOpeningValue > Real {
		unit '1'; // dimensionless fraction 0..1
	}
	value type PumpSpeedValue > Real {
		unit 'rad/s';
	}
	value type TimeValue > Real {
		unit 's';
	}
	value type AreaValue > Real {
		unit 'm2';
	}
	value type VelocityValue > Real {
		unit 'm/s';
	}
	value type ReynoldsNumberValue > Real {
		unit '1';
	}
	value type FrictionFactorValue > Real {
		unit '1';
	}

	// ---- Items ----
	item def Fluid {
		attribute density : DensityValue = 1000 [kg/m3];
		attribute viscosity : DynamicViscosityValue = 0.001 [Pa.s];
	}

	item def PressureMeasurement {
		attribute value : PressureValue;
		attribute timestamp : TimeValue;
	}

	item def FlowRateMeasurement {
		attribute value : FlowRateValue;
		attribute timestamp : TimeValue;
	}

	item def ValveCommand {
		attribute opening : ValveOpeningValue;
	}

	item def PumpCommand {
		attribute speed : PumpSpeedValue;
	}

	// ---- Ports ----
	port def FluidPort {
		in item fluid : Fluid;
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
	}

	port def PressureSignalPort {
		out item measurement : PressureMeasurement;
	}

	port def FlowSignalPort {
		out item measurement : FlowRateMeasurement;
	}

	port def ValveCommandPort {
		in item command : ValveCommand;
	}

	port def PumpCommandPort {
		in item command : PumpCommand;
	}

	// ---- Pipe characteristics shared definition ----
	part def PipeCharacteristics {
		attribute length : LengthValue;
		attribute diameter : DiameterValue;
		attribute roughness : RoughnessValue;
		attribute crossSectionalArea : AreaValue = 3.14159 * (diameter / 2) ^ 2;
	}

	// ---- Components ----
	part def MainPump {
		port inlet : FluidPort;
		port outlet : FluidPort;
		port commandIn : PumpCommandPort;
		attribute nominalSpeed : PumpSpeedValue = 314.0 [rad/s];
		attribute currentSpeed : PumpSpeedValue;
		attribute pressureRise : PressureValue;

		action def PumpOperation {
			in fluidIn : Fluid;
			in speed : PumpSpeedValue;
			out fluidOut : Fluid;
			out pressureRise : PressureValue;
		}

		perform action operate : PumpOperation {
			in fluidIn = inlet.fluid;
			in speed = currentSpeed;
			out fluidOut = outlet.fluid;
			out pressureRise = self.pressureRise;
		}

		state machine def PumpStates {
			state Off;
			state Starting;
			state Running;
			transition off_to_starting
				from Off to Starting
				when commandIn.command.received;
			transition starting_to_running
				from Starting to Running
				when currentSpeed >= nominalSpeed * 0.9;
			transition running_to_off
				from Running to Off
				when commandIn.command.speed == 0 [rad/s];
		}
	}

	part def ControlValve {
		port inlet : FluidPort;
		port outlet : FluidPort;
		port commandIn : ValveCommandPort;
		attribute opening : ValveOpeningValue = 0.5;
		attribute maxOpening : ValveOpeningValue = 1.0;
		attribute minOpening : ValveOpeningValue = 0.0;
		attribute flowCoefficient : FlowRateValue = 0.01 [m3/s];

		action def AdjustOpening {
			in command : ValveCommand;
			inout opening : ValveOpeningValue;
		}

		perform action adjust : AdjustOpening {
			in command = commandIn.command;
			inout opening = self.opening;
		}

		state machine def ValveStates {
			state Closed {
				entry assign self.opening = 0.0;
			}
			state PartiallyOpen;
			state FullyOpen {
				entry assign self.opening = 1.0;
			}
			transition closed_to_partial
				from Closed to PartiallyOpen
				when opening > 0.0;
			transition partial_increase
				from PartiallyOpen to FullyOpen
				when opening >= 1.0;
			transition partial_decrease
				from PartiallyOpen to Closed
				when opening <= 0.0;
			transition fully_to_partial
				from FullyOpen to PartiallyOpen
				when opening < 1.0;
		}
	}

	part def PressureRegulator {
		port inlet : FluidPort;
		port outlet : FluidPort;
		attribute targetPressure : PressureValue = 200000 [Pa];
		attribute regulatedPressure : PressureValue;

		action def Regulate {
			in inletPressure : PressureValue;
			in target : PressureValue;
			out outletPressure : PressureValue;
		}

		perform action regulate : Regulate {
			in inletPressure = inlet.pressure;
			in target = targetPressure;
			out outletPressure = outlet.pressure;
		}
	}

	part def FlowSensor {
		port inlet : FluidPort;
		port outlet : FluidPort;
		port pressureOut : PressureSignalPort;
		port flowOut : FlowSignalPort;
		attribute measuredPressure : PressureValue;
		attribute measuredFlowRate : FlowRateValue;
		attribute samplingPeriod : TimeValue = 0.1 [s];

		action def Sample {
			in fluidIn : Fluid;
			in inletPressure : PressureValue;
			in inletFlow : FlowRateValue;
			out pressureMeasurement : PressureMeasurement;
			out flowMeasurement : FlowRateMeasurement;
		}

		perform action sample : Sample {
			in fluidIn = inlet.fluid;
			in inletPressure = inlet.pressure;
			in inletFlow = inlet.flowRate;
			out pressureMeasurement = pressureOut.measurement;
			out flowMeasurement = flowOut.measurement;
		}
	}

	part def Pipe :> PipeCharacteristics {
		port inlet : FluidPort;
		port outlet : FluidPort;

		action def TransportFluid {
			in fluidIn : Fluid;
			in inletPressure : PressureValue;
			in inletFlow : FlowRateValue;
			in length : LengthValue;
			in diameter : DiameterValue;
			in roughness : RoughnessValue;
			out fluidOut : Fluid;
			out outletPressure : PressureValue;
			out outletFlow : FlowRateValue;
		}

		perform action transport : TransportFluid {
			in fluidIn = inlet.fluid;
			in inletPressure = inlet.pressure;
			in inletFlow = inlet.flowRate;
			in length = self.length;
			in diameter = self.diameter;
			in roughness = self.roughness;
			out fluidOut = outlet.fluid;
			out outletPressure = outlet.pressure;
			out outletFlow = outlet.flowRate;
		}
	}

	part def Controller {
		port pressureIn : PressureSignalPort;
		port flowIn : FlowSignalPort;
		port valveCmdOut : ValveCommandPort;
		port pumpCmdOut : PumpCommandPort;

		attribute targetPressure : PressureValue = 200000 [Pa];
		attribute targetFlowRate : FlowRateValue = 0.005 [m3/s];
		attribute pressureTolerance : PressureValue = 5000 [Pa];
		attribute flowTolerance : FlowRateValue = 0.0005 [m3/s];

		attribute fluidDensity : DensityValue = 1000 [kg/m3];
		attribute fluidViscosity : DynamicViscosityValue = 0.001 [Pa.s];
		attribute pipeLength : LengthValue = 10.0 [m];
		attribute pipeDiameter : DiameterValue = 0.05 [m];
		attribute pipeRoughness : RoughnessValue = 0.000045 [m];

		attribute currentValveOpening : ValveOpeningValue = 0.5;
		attribute currentPumpSpeed : PumpSpeedValue = 314.0 [rad/s];
		attribute lastPressureError : PressureValue;
		attribute lastFlowError : FlowRateValue;

		action def ComputeFluidDynamics {
			in density : DensityValue;
			in viscosity : DynamicViscosityValue;
			in length : LengthValue;
			in diameter : DiameterValue;
			in roughness : RoughnessValue;
			in flowRate : FlowRateValue;
			out velocity : VelocityValue;
			out reynoldsNumber : ReynoldsNumberValue;
			out frictionFactor : FrictionFactorValue;
			out pressureDrop : PressureValue;
		}

		action def ComputeControl {
			in measuredPressure : PressureValue;
			in measuredFlow : FlowRateValue;
			in targetPressure : PressureValue;
			in targetFlow : FlowRateValue;
			in density : DensityValue;
			in viscosity : DynamicViscosityValue;
			in length : LengthValue;
			in diameter : DiameterValue;
			in roughness : RoughnessValue;
			out valveOpening : ValveOpeningValue;
			out pumpSpeed : PumpSpeedValue;
		}

		perform action computeDynamics : ComputeFluidDynamics {
			in density = fluidDensity;
			in viscosity = fluidViscosity;
			in length = pipeLength;
			in diameter = pipeDiameter;
			in roughness = pipeRoughness;
			in flowRate = flowIn.measurement.value;
			out velocity;
			out reynoldsNumber;
			out frictionFactor;
			out pressureDrop;
		}

		perform action computeControl : ComputeControl {
			in measuredPressure = pressureIn.measurement.value;
			in measuredFlow = flowIn.measurement.value;
			in targetPressure = self.targetPressure;
			in targetFlow = self.targetFlowRate;
			in density = fluidDensity;
			in viscosity = fluidViscosity;
			in length = pipeLength;
			in diameter = pipeDiameter;
			in roughness = pipeRoughness;
			out valveOpening = currentValveOpening;
			out pumpSpeed = currentPumpSpeed;
		}

		state machine def ControlStates {
			state Idle;
			state Monitoring;
			state Adjusting;
			state Faulted;

			transition idle_to_monitoring
				from Idle to Monitoring
				when pressureIn.measurement.received and flowIn.measurement.received;

			transition monitor_to_adjust
				from Monitoring to Adjusting
				when abs(pressureIn.measurement.value - targetPressure) > pressureTolerance
				     or abs(flowIn.measurement.value - targetFlowRate) > flowTolerance;

			transition adjust_to_monitor
				from Adjusting to Monitoring
				when abs(pressureIn.measurement.value - targetPressure) <= pressureTolerance
				     and abs(flowIn.measurement.value - targetFlowRate) <= flowTolerance;

			transition any_to_faulted
				from Monitoring to Faulted
				when pressureIn.measurement.value < 0 [Pa];

			transition faulted_to_idle
				from Faulted to Idle
				when pressureIn.measurement.value >= 0 [Pa];
		}
	}

	// ---- Top-level system ----
	part FluidTransportSystem {
		part pump : MainPump {
			attribute nominalSpeed = 314.0 [rad/s];
		}
		part supplyPipe : Pipe {
			attribute length = 5.0 [m];
			attribute diameter = 0.05 [m];
			attribute roughness = 0.000045 [m];
		}
		part valve : ControlValve {
			attribute opening = 0.5;
		}
		part regulator : PressureRegulator {
			attribute targetPressure = 200000 [Pa];
		}
		part sensor : FlowSensor {
			attribute samplingPeriod = 0.1 [s];
		}
		part returnPipe : Pipe {
			attribute length = 5.0 [m];
			attribute diameter = 0.05 [m];
			attribute roughness = 0.000045 [m];
		}
		part controller : Controller {
			attribute targetPressure = 200000 [Pa];
			attribute targetFlowRate = 0.005 [m3/s];
			attribute pressureTolerance = 5000 [Pa];
			attribute flowTolerance = 0.0005 [m3/s];
			attribute fluidDensity = 1000 [kg/m3];
			attribute fluidViscosity = 0.001 [Pa.s];
			attribute pipeLength = 10.0 [m];
			attribute pipeDiameter = 0.05 [m];
			attribute pipeRoughness = 0.000045 [m];
		}

		// Fluid loop connections
		connect pump.outlet to supplyPipe.inlet;
		connect supplyPipe.outlet to valve.inlet;
		connect valve.outlet to regulator.inlet;
		connect regulator.outlet to sensor.inlet;
		connect sensor.outlet to returnPipe.inlet;
		connect returnPipe.outlet to pump.inlet;

		// Signal and command connections
		connect sensor.pressureOut to controller.pressureIn;
		connect sensor.flowOut to controller.flowIn;
		connect controller.valveCmdOut to valve.commandIn;
		connect controller.pumpCmdOut to pump.commandIn;
	}

	// ---- Requirements ----
	requirement def PressureStabilityRequirement {
		attribute targetPressure : PressureValue = 200000 [Pa];
		attribute tolerance : PressureValue = 5000 [Pa];
		subject system : FluidTransportSystem;
		require {
			abs(system.sensor.measuredPressure - targetPressure) <= tolerance;
		}
	}

	requirement def FlowRateStabilityRequirement {
		attribute targetFlowRate : FlowRateValue = 0.005 [m3/s];
		attribute tolerance : FlowRateValue = 0.0005 [m3/s];
		subject system : FluidTransportSystem;
		require {
			abs(system.sensor.measuredFlowRate - targetFlowRate) <= tolerance;
		}
	}

	requirement def DisturbanceResponseRequirement {
		attribute maxResponseTime : TimeValue = 2.0 [s];
		subject system : FluidTransportSystem;
		require {
			system.controller.ControlStates.Adjusting.entry
			to system.controller.ControlStates.Monitoring.entry
			within maxResponseTime;
		}
	}

	requirement def ClosedLoopIntegrityRequirement {
		subject system : FluidTransportSystem;
		require {
			system.pump.outlet.connectedTo(system.supplyPipe.inlet)
			and system.supplyPipe.outlet.connectedTo(system.valve.inlet)
			and system.valve.outlet.connectedTo(system.regulator.inlet)
			and system.regulator.outlet.connectedTo(system.sensor.inlet)
			and system.sensor.outlet.connectedTo(system.returnPipe.inlet)
			and system.returnPipe.outlet.connectedTo(system.pump.inlet);
		}
	}

	requirement def ValveAuthorityRequirement {
		attribute minOpening : ValveOpeningValue = 0.1;
		attribute maxOpening : ValveOpeningValue = 0.9;
		subject system : FluidTransportSystem;
		require {
			system.valve.opening >= minOpening
			and system.valve.opening <= maxOpening
			during system.controller.ControlStates.Monitoring;
		}
	}

	requirement pressureStability : PressureStabilityRequirement {
		subject = FluidTransportSystem;
	}

	requirement flowRateStability : FlowRateStabilityRequirement {
		subject = FluidTransportSystem;
	}

	requirement disturbanceResponse : DisturbanceResponseRequirement {
		subject = FluidTransportSystem;
	}

	requirement closedLoopIntegrity : ClosedLoopIntegrityRequirement {
		subject = FluidTransportSystem;
	}

	requirement valveAuthority : ValveAuthorityRequirement {
		subject = FluidTransportSystem;
	}

	// ---- Verification actions ----
	action def VerifyPressureStability {
		in system : FluidTransportSystem;
		in targetPressure : PressureValue;
		in tolerance : PressureValue;
		out pass : Boolean;
		perform {
			assign pass = abs(system.sensor.measuredPressure - targetPressure) <= tolerance;
		}
	}

	action def VerifyFlowRateStability {
		in system : FluidTransportSystem;
		in targetFlowRate : FlowRateValue;
		in tolerance : FlowRateValue;
		out pass : Boolean;
		perform {
			assign pass = abs(system.sensor.measuredFlowRate - targetFlowRate) <= tolerance;
		}
	}

	action def VerifyClosedLoop {
		in system : FluidTransportSystem;
		out pass : Boolean;
		perform {
			assign pass = true;
		}
	}

}
