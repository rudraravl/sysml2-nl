package 'Y-Set Fluid Distribution System' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	item def Fluid;
	
	attribute def FluidProperties {
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
		attribute temp : TemperatureValue;
	}
	
	attribute def SplitRatioTarget {
		attribute desiredRatio1 : Real;
		attribute desiredRatio2 : Real;
	}
	
	attribute def ValveCommand {
		attribute position : Real;
	}
	
	attribute def StartCommand;
	attribute def StartupComplete;
	attribute def ShutdownCommand;
	attribute def ShutdownComplete;
	attribute def DeviationDetected;
	attribute def BalanceRestored;
	
	action def InitializeSensors;
	action def OpenValves;
	action def VerifyFlow;
	action def MonitorRatio;
	action def CalculateAdjustments;
	action def SendValveCommands;
	action def CloseValves;
	action def FlushLines;
	
	requirement def FlowDistributionAccuracy {
		doc /* The Y-Set Fluid Distribution System shall maintain the actual split ratio within the specified tolerance of the desired split ratio during the distributing state. */
		attribute tolerance : Real = 0.02;
	}
	
	requirement def FeedbackControlLoop {
		doc /* The Flow Distribution Controller shall continuously read outlet flow sensor data and adjust valve positions to correct any deviation outside the acceptable tolerance. */
	}
	
	requirement def SafeStateTransitions {
		doc /* The system shall support Idle, Startup, Distributing (with Balanced and Adjusting substates), and Shutdown states with safe, ordered transitions between them. */
	}
	
	part def YSetJunction {
		port inletPort { in fluid : Fluid; }
		port outlet1Port { out fluid1 : Fluid; }
		port outlet2Port { out fluid2 : Fluid; }
	}
	
	part def InletFlowSensor {
		port fluidInPort { in fluid : Fluid; }
		port fluidOutPort { out fluid : Fluid; }
		port measurementOutPort { out measurement : FluidProperties; }
	}
	
	part def OutletFlowSensor {
		port fluidInPort { in fluid : Fluid; }
		port fluidOutPort { out fluid : Fluid; }
		port measurementOutPort { out measurement : FluidProperties; }
	}
	
	part def FlowControlValve {
		port fluidInPort { in fluid : Fluid; }
		port fluidOutPort { out fluid : Fluid; }
		port commandInPort { in command : ValveCommand; }
		attribute position : Real;
	}
	
	state def ControllerStateMachine {
		entry; then idle;
		
		state idle;
		accept cmd : StartCommand then startup;
		
		state startup;
		accept sc : StartupComplete then distributing;
		
		state distributing {
			state balanced {
				do MonitorRatio;
			}
			state adjusting {
				do CalculateAdjustments;
			}
			transition first balanced accept dev : DeviationDetected then adjusting;
			transition first adjusting accept br : BalanceRestored then balanced;
		}
		
		state shutdown;
		accept sc : ShutdownComplete then idle;
		
		transition first distributing accept cmd : ShutdownCommand then shutdown;
	}
	
	part def FlowDistributionController {
		port inletDataPort { in inletMeasurement : FluidProperties; }
		port outlet1DataPort { in outlet1Measurement : FluidProperties; }
		port outlet2DataPort { in outlet2Measurement : FluidProperties; }
		port targetInPort { in target : SplitRatioTarget; }
		port valve1CommandPort { out valve1Command : ValveCommand; }
		port valve2CommandPort { out valve2Command : ValveCommand; }
		port controlPort { in startCmd : StartCommand; in shutdownCmd : ShutdownCommand; }
		
		attribute tolerance : Real = 0.02;
		attribute target : SplitRatioTarget;
		
		state controllerState : ControllerStateMachine;
	}
	
	part def YSetFluidDistributionSystem {
		port systemFluidInPort { in fluid : Fluid; }
		port systemFluidOut1Port { out fluid : Fluid; }
		port systemFluidOut2Port { out fluid : Fluid; }
		port systemTargetPort { in target : SplitRatioTarget; }
		port systemControlPort { in startCmd : StartCommand; in shutdownCmd : ShutdownCommand; }
		
		part inletSensor : InletFlowSensor;
		part junction : YSetJunction;
		part valve1 : FlowControlValve;
		part valve2 : FlowControlValve;
		part outletSensor1 : OutletFlowSensor;
		part outletSensor2 : OutletFlowSensor;
		part controller : FlowDistributionController;
		
		bind systemFluidInPort = inletSensor.fluidInPort;
		flow inletSensor.fluidOutPort.fluid to junction.inletPort.fluid;
		flow junction.outlet1Port.fluid1 to valve1.fluidInPort.fluid;
		flow junction.outlet2Port.fluid2 to valve2.fluidInPort.fluid;
		flow valve1.fluidOutPort.fluid to outletSensor1.fluidInPort.fluid;
		flow valve2.fluidOutPort.fluid to outletSensor2.fluidInPort.fluid;
		bind outletSensor1.fluidOutPort = systemFluidOut1Port;
		bind outletSensor2.fluidOutPort = systemFluidOut2Port;
		
		flow inletSensor.measurementOutPort.measurement to controller.inletDataPort.inletMeasurement;
		flow outletSensor1.measurementOutPort.measurement to controller.outlet1DataPort.outlet1Measurement;
		flow outletSensor2.measurementOutPort.measurement to controller.outlet2DataPort.outlet2Measurement;
		
		bind systemTargetPort = controller.targetInPort;
		bind systemControlPort = controller.controlPort;
		
		flow controller.valve1CommandPort.valve1Command to valve1.commandInPort.command;
		flow controller.valve2CommandPort.valve2Command to valve2.commandInPort.command;
	}
	
	part ySetSystem : YSetFluidDistributionSystem;
	
	satisfy FlowDistributionAccuracy by ySetSystem;
	satisfy FeedbackControlLoop by ySetSystem;
	satisfy SafeStateTransitions by ySetSystem;
}
