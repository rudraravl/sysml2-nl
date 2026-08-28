package 'Fluid Transport System' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def LengthValue :> Real;
		attribute def DensityValue :> Real;
		attribute def ViscosityValue :> Real;
		
		item def Fluid {
			attribute density : DensityValue;
			attribute viscosity : ViscosityValue;
		}
		
		item def FluidMeasurement {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		item def ValveCommand {
			attribute opening : Real;
		}
		
		part def Pipe {
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute roughness : LengthValue;
			port fluidIn {
				in fluid : Fluid;
			}
			port fluidOut {
				out fluid : Fluid;
			}
		}
		
		part def Pump {
			port fluidIn {
				in fluid : Fluid;
			}
			port fluidOut {
				out fluid : Fluid;
			}
		}
		
		part def ControlValve {
			port fluidIn {
				in fluid : Fluid;
			}
			port fluidOut {
				out fluid : Fluid;
			}
			port commandIn {
				in command : ValveCommand;
			}
		}
		
		part def PressureRegulator {
			port fluidIn {
				in fluid : Fluid;
			}
			port fluidOut {
				out fluid : Fluid;
			}
		}
		
		part def FlowSensor {
			port fluidIn {
				in fluid : Fluid;
			}
			port fluidOut {
				out fluid : Fluid;
			}
			port dataOut {
				out measurement : FluidMeasurement;
			}
		}
		
		action def MonitorFluid {
			out measurement : FluidMeasurement;
		}
		
		action def CalculateAdjustment {
			in measurement : FluidMeasurement;
			in fluidProps : Fluid;
			in pipeProps : Pipe;
			out command : ValveCommand;
		}
		
		action def AdjustValve {
			in command : ValveCommand;
		}
		
		action def ControlFluid {
			in fluidProps : Fluid;
			in pipeProps : Pipe;
			in targetPressure : PressureValue;
			loop action controlLoop {
				action monitor : MonitorFluid {
					out measurement;
				}
				then action calculate : CalculateAdjustment {
					in measurement = monitor.measurement;
					in fluidProps;
					in pipeProps;
					out command;
				}
				then action adjust : AdjustValve {
					in command = calculate.command;
				}
			} until controlLoop.monitor.measurement.pressure == targetPressure;
		}
		
		part def FluidController {
			port measurementIn {
				in measurement : FluidMeasurement;
			}
			port commandOut {
				out command : ValveCommand;
			}
			perform action 'control fluid' : ControlFluid;
		}
		
		part def FluidTransportSystem {
			attribute pressureDeviation : Real;
			attribute flowRateResponseTime : Real;
			
			part fluid : Fluid;
			part supplyPipe : Pipe;
			part returnPipe : Pipe;
			part pump : Pump;
			part valve : ControlValve;
			part regulator : PressureRegulator;
			part sensor : FlowSensor;
			part controller : FluidController;
			
			flow pumpToSupply of Fluid from pump.fluidOut.fluid to supplyPipe.fluidIn.fluid;
			flow supplyToValve of Fluid from supplyPipe.fluidOut.fluid to valve.fluidIn.fluid;
			flow valveToRegulator of Fluid from valve.fluidOut.fluid to regulator.fluidIn.fluid;
			flow regulatorToSensor of Fluid from regulator.fluidOut.fluid to sensor.fluidIn.fluid;
			flow sensorToReturn of Fluid from sensor.fluidOut.fluid to returnPipe.fluidIn.fluid;
			flow returnToPump of Fluid from returnPipe.fluidOut.fluid to pump.fluidIn.fluid;
			
			flow measurementFlow of FluidMeasurement from sensor.dataOut.measurement to controller.measurementIn.measurement;
			flow commandFlow of ValveCommand from controller.commandOut.command to valve.commandIn.command;
		}
		
		requirement def PressureStability {
			doc /* The system pressure deviation shall be less than 0.05. */
		}
		
		requirement def FlowRateControl {
			doc /* The system flow rate response time shall be less than 0.1. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part system : FluidTransportSystem {
			part :>> fluid {
				attribute density = 1000;
				attribute viscosity = 0.001;
			}
			part :>> supplyPipe {
				attribute length = 10;
				attribute diameter = 0.1;
				attribute roughness = 0.0001;
			}
			part :>> returnPipe {
				attribute length = 10;
				attribute diameter = 0.1;
				attribute roughness = 0.0001;
			}
		}
		
		requirement pressureStabilityReq : PressureStability;
		requirement flowRateControlReq : FlowRateControl;
	}
}
