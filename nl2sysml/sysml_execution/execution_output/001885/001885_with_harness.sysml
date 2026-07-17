package 'Volumetric Flow Rate System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VolumetricFlowRateValue :> ISQ::VolumetricFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumetricFlowRateUnit;
	}
	
	attribute def PressureValue :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue {
		attribute :>> num : Real;
		attribute :>> mRef : ThermodynamicTemperatureUnit;
	}
	
	attribute def VolumeValue :> ISQ::VolumeValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeUnit;
	}
	
	item def Fluid {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	attribute def FlowCommand {
		attribute targetFlowRate : VolumetricFlowRateValue;
	}
	
	attribute def FlowStatus {
		attribute actualFlowRate : VolumetricFlowRateValue;
		attribute isStable : Boolean;
	}
	
	attribute def PumpStartCmd;
	attribute def PumpStopCmd;
	
	port def FluidInletPort {
		attribute inletPressure : PressureValue;
		attribute inletTemperature : TemperatureValue;
		in item fluidIn : Fluid;
	}
	
	port def FluidOutletPort {
		attribute outletPressure : PressureValue;
		attribute outletTemperature : TemperatureValue;
		out item fluidOut : Fluid;
	}
	
	port def ControlPort {
		in item flowCommand : FlowCommand;
		out item flowStatus : FlowStatus;
	}
	
	part def FlowSensor {
		port sensorInlet : FluidInletPort;
		port sensorOutlet : FluidOutletPort;
		attribute measuredFlowRate : VolumetricFlowRateValue;
		
		action measureFlow {
			in fluid : Fluid;
			out flowRate : VolumetricFlowRateValue;
		}
	}
	
	part def FlowController {
		port controlInterface : ControlPort;
		attribute setpoint : VolumetricFlowRateValue;
		attribute currentFlow : VolumetricFlowRateValue;
		
		action regulateFlow {
			in commandedRate : VolumetricFlowRateValue;
			in measuredRate : VolumetricFlowRateValue;
			out valvePosition : Real;
		}
	}
	
	part def FlowValve {
		port inletPort : FluidInletPort;
		port outletPort : FluidOutletPort;
		attribute valvePosition : Real;
		attribute maxFlowRate : VolumetricFlowRateValue;
		
		action adjustFlow {
			in position : Real;
			in incomingFluid : Fluid;
			out outgoingFluid : Fluid;
			out resultingFlowRate : VolumetricFlowRateValue;
		}
	}
	
	part def Pump {
		port suctionPort : FluidInletPort;
		port dischargePort : FluidOutletPort;
		attribute pumpSpeed : Real;
		attribute ratedFlowRate : VolumetricFlowRateValue;
		
		action generateFlow {
			in speed : Real;
			out flowRate : VolumetricFlowRateValue;
			out dischargedFluid : Fluid;
		}
	}
	
	part def FluidReservoir {
		port reservoirOutlet : FluidOutletPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
	}
	
	part def FluidReceiver {
		port receiverInlet : FluidInletPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
	}
	
	part def Pipe {
		port pipeInlet : FluidInletPort;
		port pipeOutlet : FluidOutletPort;
		attribute length : ISQ::LengthValue;
		attribute diameter : ISQ::LengthValue;
	}
	
	action def MonitorFlowRate {
		in currentRate : VolumetricFlowRateValue;
		in targetRate : VolumetricFlowRateValue;
		out status : FlowStatus;
		out flowError : Real;
	}
	
	action def AdjustValvePosition {
		in error : Real;
		out position : Real;
	}
	
	action def CalculateFlowError {
		in setpoint : VolumetricFlowRateValue;
		in measured : VolumetricFlowRateValue;
		out error : Real;
	}
	
	action def MaintainFlowRate {
		in targetRate : VolumetricFlowRateValue;
		out actualRate : VolumetricFlowRateValue;
		
		first start;
		then merge checkFlow;
		
		then action monitor : MonitorFlowRate {
			in currentRate : VolumetricFlowRateValue;
			in targetRate = MaintainFlowRate::targetRate;
			out status : FlowStatus;
			out flowError : Real;
		}
		
		then action calculateError : CalculateFlowError {
			in setpoint = targetRate;
			in measured = monitor.status.actualFlowRate;
			out error : Real;
		}
		
		then decide;
			if calculateError.error > 0.05 then adjust;
			if calculateError.error <= 0.05 then maintain;
		
		action adjust : AdjustValvePosition {
			in error = calculateError.error;
			out position : Real;
		}
		then checkFlow;
		
		action maintain {
			out stabilizedRate : VolumetricFlowRateValue;
		}
		then done;
	}
	
	action def TransferFluid {
		in sourceFluid : Fluid;
		out deliveredFluid : Fluid;
		
		action pumpFluid {
			in fluid : Fluid;
			out pumpedFluid : Fluid;
		}
		
		flow pumpFluid.pumpedFluid to regulateFluid.incomingFluid;
		
		action regulateFluid {
			in incomingFluid : Fluid;
			out regulatedFluid : Fluid;
		}
		
		flow regulateFluid.regulatedFluid to deliverFluid.fluid;
		
		action deliverFluid {
			in fluid : Fluid;
			out deliveredFluid : Fluid = TransferFluid::deliveredFluid;
		}
	}
	
	part def VolumetricFlowSystem {
		part reservoir : FluidReservoir;
		part pump : Pump;
		part supplyPipe : Pipe;
		part flowValve : FlowValve;
		part flowSensor : FlowSensor;
		part deliveryPipe : Pipe;
		part receiver : FluidReceiver;
		part flowController : FlowController;
		
		connect reservoir.reservoirOutlet to pump.suctionPort;
		connect pump.dischargePort to supplyPipe.pipeInlet;
		connect supplyPipe.pipeOutlet to flowValve.inletPort;
		connect flowValve.outletPort to flowSensor.sensorInlet;
		connect flowSensor.sensorOutlet to deliveryPipe.pipeInlet;
		connect deliveryPipe.pipeOutlet to receiver.receiverInlet;
		
		perform action maintainFlow : MaintainFlowRate {
			in targetRate = flowController.setpoint;
			out actualRate = flowSensor.measuredFlowRate;
		}
		
		perform action transferFluid : TransferFluid {
			in sourceFluid = reservoir.reservoirOutlet.fluidOut;
			out deliveredFluid = receiver.receiverInlet.fluidIn;
			
			perform pump performs transferFluid.pumpFluid;
			perform flowValve performs transferFluid.regulateFluid;
			perform deliveryPipe performs transferFluid.deliverFluid;
		}
	}
	
	requirement def FlowRateAccuracyRequirement {
		doc /* The system shall maintain the specified volumetric flow rate within ±5% tolerance. */
		
		subject system : VolumetricFlowSystem;
		
		require constraint {
			system.flowSensor.measuredFlowRate.num >= 
				system.flowController.setpoint.num * 0.95 and
			system.flowSensor.measuredFlowRate.num <= 
				system.flowController.setpoint.num * 1.05
		}
	}
	
	requirement def SystemStabilityRequirement {
		doc /* The system shall achieve stable flow conditions within 30 seconds of setpoint change. */
		
		subject system : VolumetricFlowSystem;
		
		require constraint {
			system.flowController.controlInterface.flowStatus.isStable
		}
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The system shall transfer fluid from reservoir to receiver at a controlled volumetric flow rate. */
		
		subject system : VolumetricFlowSystem;
		
		require constraint {
			system.flowSensor.measuredFlowRate.num > 0.0
		}
	}
	
	part volumetricFlowSystem : VolumetricFlowSystem {
		part :>> reservoir {
			capacity.num = 1000.0;
			capacity.mRef = SI::L;
			currentLevel.num = 800.0;
			currentLevel.mRef = SI::L;
		}
		
		part :>> pump {
			ratedFlowRate.num = 100.0;
		}
		
		part :>> flowController {
			setpoint.num = 75.0;
		}
		
		part :>> flowValve {
			maxFlowRate.num = 150.0;
		}
		
		part :>> receiver {
			capacity.num = 500.0;
			capacity.mRef = SI::L;
			currentLevel.num = 0.0;
			currentLevel.mRef = SI::L;
		}
	}
	
	requirement systemRequirements {
		requirement flowRateReq : FlowRateAccuracyRequirement {
			subject = volumetricFlowSystem;
		}
		
		requirement stabilityReq : SystemStabilityRequirement {
			subject = volumetricFlowSystem;
		}
		
		requirement primaryFunctionReq : PrimaryFunctionRequirement {
			subject = volumetricFlowSystem;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Volumetric Flow Rate System'::*;

    action orchestrator {
        action adjustProbe : AdjustValvePosition {
            in error = 0.0;
        }
        first adjustProbe;
    }
}
