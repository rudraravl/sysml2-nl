package 'Intelligent Pumping Subsystem' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	package Definitions {
		unit def LitrePerMinute;
		unit def RevolutionsPerMinute;
		unit def Kilopascal;
		unit def Litre;

		attribute def FlowRate :> Real { unit = LitrePerMinute; }
		attribute def RotationalSpeed :> Real { unit = RevolutionsPerMinute; }
		attribute def Pressure :> Real { unit = Kilopascal; }
		attribute def Volume :> Real { unit = Litre; }

		item def Fluid {
			attribute volume : Volume;
		}

		item def StartSignal;
		item def StopSignal;
		item def ResetSignal;
		item def FaultSignal;
		item def RunningSignal;
		item def StopCompleteSignal;

		item def FlowReading {
			attribute value : FlowRate;
		}
		item def PressureReading {
			attribute value : Pressure;
		}
		item def SpeedCommand {
			attribute value : RotationalSpeed;
		}
		item def TargetFlow {
			attribute value : FlowRate;
		}

		port def FluidPort {
			out item fluid : Fluid;
		}
		port def FlowSensorPort {
			out item reading : FlowReading;
		}
		port def PressureSensorPort {
			out item reading : PressureReading;
		}
		port def ControlPort {
			in item targetFlow : TargetFlow;
			out item speedCommand : SpeedCommand;
			out item fault : Boolean;
		}

		part def SourceTank {
			port fluidOutPort : FluidPort;
			attribute capacity : Volume;
			item storedFluid : Fluid;
		}

		part def DestinationTank {
			port fluidInPort : ~FluidPort;
			attribute capacity : Volume;
			attribute currentVolume : Volume;
			item storedFluid : Fluid;
		}

		part def FlowSensor {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port dataOut : FlowSensorPort;
			flow of fluid : Fluid from fluidIn.fluid to fluidOut.fluid;
		}

		part def PressureSensor {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port dataOut : PressureSensorPort;
			flow of fluid : Fluid from fluidIn.fluid to fluidOut.fluid;
		}

		part def PumpChamber {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			flow of fluid : Fluid from fluidIn.fluid to fluidOut.fluid;
		}

		part def PumpDrive {
			port speedCommandIn : ~ControlPort;
			attribute currentSpeed : RotationalSpeed;
		}

		part def PumpController {
			port inletFlowIn : ~FlowSensorPort;
			port inletPressureIn : ~PressureSensorPort;
			port outletFlowIn : ~FlowSensorPort;
			port outletPressureIn : ~PressureSensorPort;
			port controlOut : ControlPort;
			attribute desiredFlowRate : FlowRate;
			attribute maxSpeed : RotationalSpeed;
			attribute maxFlowRate : FlowRate;
		}

		part def IntelligentPump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port controlPort : ControlPort;

			attribute speedLimitMax : RotationalSpeed = 3000.0;
			attribute flowRateLimitMax : FlowRate = 150.0;
			attribute pressureIncreaseRequired : Pressure = 200.0;

			part inletFlowSensor : FlowSensor;
			part inletPressureSensor : PressureSensor;
			part pumpChamber : PumpChamber;
			part outletFlowSensor : FlowSensor;
			part outletPressureSensor : PressureSensor;
			part drive : PumpDrive;
			part controller : PumpController;

			bind fluidInPort = inletFlowSensor.fluidIn;
			flow of fluid : Fluid from inletFlowSensor.fluidOut.fluid to inletPressureSensor.fluidIn.fluid;
			flow of fluid : Fluid from inletPressureSensor.fluidOut.fluid to pumpChamber.fluidIn.fluid;
			flow of fluid : Fluid from pumpChamber.fluidOut.fluid to outletFlowSensor.fluidIn.fluid;
			flow of fluid : Fluid from outletFlowSensor.fluidOut.fluid to outletPressureSensor.fluidIn.fluid;
			bind outletPressureSensor.fluidOut = fluidOutPort;

			flow of reading : FlowReading from inletFlowSensor.dataOut.reading to controller.inletFlowIn.reading;
			flow of reading : PressureReading from inletPressureSensor.dataOut.reading to controller.inletPressureIn.reading;
			flow of reading : FlowReading from outletFlowSensor.dataOut.reading to controller.outletFlowIn.reading;
			flow of reading : PressureReading from outletPressureSensor.dataOut.reading to controller.outletPressureIn.reading;

			flow of speedCommand : SpeedCommand from controller.controlOut.speedCommand to drive.speedCommandIn.speedCommand;
			bind controlPort = controller.controlOut;
		}

		action def StartPump {
			in drive : PumpDrive;
			language "Alf"
			/*
				drive.currentSpeed = 500.0;
			*/
		}

		action def StopPump {
			in drive : PumpDrive;
			language "Alf"
			/*
				drive.currentSpeed = 0.0;
			*/
		}

		action def ShutdownPump {
			in drive : PumpDrive;
			language "Alf"
			/*
				drive.currentSpeed = 0.0;
			*/
		}

		action def RegulateFlow {
			in actualFlowRate : FlowRate;
			in targetFlowRate : FlowRate;
			in currentSpeed : RotationalSpeed;
			in maxSpeed : RotationalSpeed;
			in maxFlowRate : FlowRate;
			out speedCommand : RotationalSpeed;
			out fault : Boolean;
			language "Alf"
			/*
				error = targetFlowRate - actualFlowRate;
				correctedSpeed = currentSpeed + 10.0 * error;
				if (correctedSpeed > maxSpeed) {
					correctedSpeed = maxSpeed;
				}
				if (correctedSpeed < 0.0) {
					correctedSpeed = 0.0;
				}
				speedCommand = correctedSpeed;
				fault = (actualFlowRate > maxFlowRate);
			*/
		}

		state def PumpOperationalStates {
			in pump : IntelligentPump;

			entry; then off;

			state off;
			accept StartSignal then starting;

			state starting {
				entry action startPump : StartPump { in drive = pump.drive; }
			}
			accept RunningSignal
				if pump.outletPressureSensor.dataOut.reading.value - pump.inletPressureSensor.dataOut.reading.value >= pump.pressureIncreaseRequired
				then running;
			accept FaultSignal then faulted;

			state running {
				do action regulate : RegulateFlow {
					in actualFlowRate = pump.outletFlowSensor.dataOut.reading.value;
					in targetFlowRate = pump.controller.desiredFlowRate;
					in currentSpeed = pump.drive.currentSpeed;
					in maxSpeed = pump.speedLimitMax;
					in maxFlowRate = pump.flowRateLimitMax;
					out speedCommand = pump.drive.speedCommandIn.speedCommand;
					out fault = pump.controlPort.fault;
				}
			}
			accept StopSignal then stopping;
			accept FaultSignal then faulted;

			state stopping {
				entry action stopPump : StopPump { in drive = pump.drive; }
			}
			accept StopCompleteSignal then off;
			accept FaultSignal then faulted;

			state faulted {
				entry action shutdownPump : ShutdownPump { in drive = pump.drive; }
			}
			accept ResetSignal then off;
		}
	}

	package Usages {
		private import Definitions::*;
		part context {
			part sourceTank : SourceTank;
			part pumpUnit : IntelligentPump;
			part destinationTank : DestinationTank;

			flow of fluid : Fluid from sourceTank.fluidOutPort.fluid to pumpUnit.fluidInPort.fluid;
			flow of fluid : Fluid from pumpUnit.fluidOutPort.fluid to destinationTank.fluidInPort.fluid;

			state pumpStates : PumpOperationalStates { in pump = pumpUnit; }
		}
	}

	package Requirements {
		private import Definitions::*;
		requirement def PressureIncreaseRequirement {
			doc /* The pump shall achieve a pressure increase of at least the required value across inlet and outlet. */
			attribute requiredIncrease : Pressure = 200.0;
			subject pump : IntelligentPump;
		}

		requirement def SpeedLimitRequirement {
			doc /* The pump rotational speed shall not exceed the defined maximum speed. */
			attribute maxSpeed : RotationalSpeed = 3000.0;
			subject pump : IntelligentPump;
		}

		requirement def FlowRateLimitRequirement {
			doc /* The outlet flow rate shall not exceed the defined maximum flow rate. */
			attribute maxFlowRate : FlowRate = 150.0;
			subject pump : IntelligentPump;
		}

		requirement def FaultSafetyRequirement {
			doc /* The pump shall enter the faulted state and shut down upon detection of a fault. */
			subject pump : IntelligentPump;
		}
	}
}
