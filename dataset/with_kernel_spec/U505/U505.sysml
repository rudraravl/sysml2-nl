package 'Gas Lift System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def Gas;
	item def HighPressureGas;
	item def Fluid;
	item def AeratedFluid;
	item def ProductionData {
		attribute rate : FlowRateValue;
	}
	item def ControlSignal {
		attribute pressure : PressureValue;
	}
	
	attribute def PressureValue :> Real;
	attribute def FlowRateValue :> Real;
	attribute def DepthValue :> Real;
	
	port def GasPort { inout gas : Gas; }
	port def HighPressureGasPort { inout gas : HighPressureGas; }
	port def FluidPort { inout fluid : Fluid; }
	port def AeratedFluidPort { inout fluid : AeratedFluid; }
	port def ProductionDataPort { inout data : ProductionData; }
	port def ControlSignalPort { inout signal : ControlSignal; }
	
	action def CompressGas {
		in lowPressureGas : Gas;
		in controlPressure : PressureValue;
		out highPressureGas : HighPressureGas;
	}
	
	action def InjectGas {
		in annulusGas : HighPressureGas;
		out tubingGas : HighPressureGas;
	}
	
	action def ProduceFluid {
		in injectedGas : HighPressureGas;
		in reservoirFluid : Fluid;
		out aeratedFluid : AeratedFluid;
	}
	
	action def MeasureProduction {
		in producedFluid : AeratedFluid;
		out measuredRate : FlowRateValue;
	}
	
	action def ControlFlow {
		in measuredRate : FlowRateValue;
		in targetRate : FlowRateValue;
		out compressorControl : PressureValue;
	}
	
	part def GasCompressor {
		attribute targetPressure : PressureValue;
		port gasIn : GasPort;
		port controlIn : ControlSignalPort;
		port gasOut : HighPressureGasPort;
		perform action compress : CompressGas;
	}
	
	part def Annulus {
		port gasIn : HighPressureGasPort;
		port gasOut : HighPressureGasPort;
		attribute annulusPressure : PressureValue;
	}
	
	part def GasLiftValve {
		attribute setpointPressure : PressureValue;
		attribute depth : DepthValue;
		attribute annulusPressure : PressureValue;
		port annulusIn : HighPressureGasPort;
		port tubingOut : HighPressureGasPort;
		perform action inject : InjectGas;
		exhibit state 'valve states' {
			entry; then closed;
			state closed;
			accept when annulusPressure >= setpointPressure
				then open;
			state open {
				do inject;
			}
			accept when annulusPressure < setpointPressure
				then closed;
		}
	}
	
	part def ProductionTubing {
		port gasIn : HighPressureGasPort;
		port fluidIn : FluidPort;
		port mixtureOut : AeratedFluidPort;
		perform action produce : ProduceFluid;
	}
	
	part def Reservoir {
		port fluidOut : FluidPort;
		attribute reservoirPressure : PressureValue;
	}
	
	part def SurfaceFacilities {
		port fluidIn : AeratedFluidPort;
		port rateOut : ProductionDataPort;
		perform action measure : MeasureProduction;
	}
	
	part def FlowController {
		attribute targetProductionRate : FlowRateValue;
		port rateIn : ProductionDataPort;
		port controlOut : ControlSignalPort;
		perform action control : ControlFlow;
	}
	
	requirement def TargetProductionRate {
		doc /* The system shall maintain oil production at or above the target rate by adjusting gas injection. */
		attribute targetRate : FlowRateValue;
	}
	
	requirement def LiftFluidToSurface {
		doc /* The system shall lift reservoir fluid to the surface by reducing fluid column density through gas injection. */
	}
	
	requirement def ValveSetpointControl {
		doc /* Each gas lift valve shall open automatically when annulus pressure reaches its setpoint and close when it falls below. */
		attribute setpoint : PressureValue;
	}
	
	part def GasLiftSystem {
		part compressor : GasCompressor {
			attribute targetPressure = 1500;
		}
		part annulus : Annulus;
		part valves[4] : GasLiftValve {
			attribute setpointPressure = 1000;
			attribute depth = 1000;
		}
		part tubing : ProductionTubing;
		part reservoir : Reservoir;
		part facilities : SurfaceFacilities;
		part controller : FlowController {
			attribute targetProductionRate = 2000;
		}
		
		connect compressor.gasOut to annulus.gasIn;
		connect annulus.gasOut to valves.annulusIn;
		connect valves.tubingOut to tubing.gasIn;
		connect reservoir.fluidOut to tubing.fluidIn;
		connect tubing.mixtureOut to facilities.fluidIn;
		connect facilities.rateOut to controller.rateIn;
		connect controller.controlOut to compressor.controlIn;
		
		requirement productionRequirement : TargetProductionRate {
			attribute targetRate = 2000;
		}
		requirement liftRequirement : LiftFluidToSurface;
		requirement valveRequirement : ValveSetpointControl;
		
		satisfy productionRequirement by controller;
		satisfy liftRequirement by tubing;
		satisfy valveRequirement by valves;
	}
	
	part gasLiftSystem : GasLiftSystem;
	
	occurrence def GasLiftOperation {
		ref part system :>> gasLiftSystem;
		
		message compressedGas of HighPressureGas
			from system.compressor.gasOut to system.annulus.gasIn;
		then message gasToValves of HighPressureGas
			from system.annulus.gasOut to system.valves.annulusIn;
		then message gasToTubing of HighPressureGas
			from system.valves.tubingOut to system.tubing.gasIn;
		then message reservoirFluidMsg of Fluid
			from system.reservoir.fluidOut to system.tubing.fluidIn;
		then message aeratedFluidMsg of AeratedFluid
			from system.tubing.mixtureOut to system.facilities.fluidIn;
		then message productionRateMsg of ProductionData
			from system.facilities.rateOut to system.controller.rateIn;
		then message controlCommandMsg of ControlSignal
			from system.controller.controlOut to system.compressor.controlIn;
	}
}
