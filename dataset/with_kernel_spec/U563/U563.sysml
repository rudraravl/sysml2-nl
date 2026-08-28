package SlurryPumpingSystem {
	private import ISQ::*;
	private import ScalarValues::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Slurry {
			attribute solidContent : Real = 0.45;
		}
		item def ElectricalPower;

		port def SlurryPort {
			out item slurry : Slurry;
		}
		port def PowerPort {
			out item power : ElectricalPower;
		}
		port def ControlPort {
			out attribute command : Real;
			in attribute status : String;
		}

		attribute def StartSignal;
		attribute def RunSignal;
		attribute def StopSignal;
		attribute def StoppedSignal;
		attribute def FaultSignal;
		attribute def ResetSignal;

		part def SourceTank {
			attribute capacity :> ISQ::volume = 50 [m^3];
			port slurryOut : SlurryPort;
		}
		part def DestinationTank {
			attribute capacity :> ISQ::volume = 75 [m^3];
			port slurryIn : ~SlurryPort;
		}
		part def Piping {
			attribute length :> ISQ::length;
			attribute material : String = "Hardened Steel";
			port fluidIn : ~SlurryPort;
			port fluidOut : SlurryPort;
		}
		part def FlowMeter {
			attribute flowRate :> ISQ::volumeFlowRate;
			port fluidIn : ~SlurryPort;
			port fluidOut : SlurryPort;
		}
		part def PressureSensor {
			attribute pressure :> ISQ::pressure;
			port fluidIn : ~SlurryPort;
			port fluidOut : SlurryPort;
		}
		part def PowerSupply {
			attribute voltage :> ISQ::electricPotential = 480 [V];
			port powerOut : PowerPort;
		}
		part def MotorController {
			port powerIn : ~PowerPort;
			port powerOut : PowerPort;
			port controlOut : ControlPort;
		}
		part def SlurryPump {
			attribute maxSolidContent : Real = 0.45;
			attribute targetFlowRate :> ISQ::volumeFlowRate = 200 [m^3/h];
			port slurryIn : ~SlurryPort;
			port slurryOut : SlurryPort;
			port powerIn : ~PowerPort;
			port controlIn : ~ControlPort;
			
			exhibit state PumpStates {
				entry; then stopped;
				state stopped;
				state starting;
				state running;
				state stopping;
				state faulted;
				
				transition stopped_to_starting
					first stopped
					accept StartSignal
					then starting;
				transition starting_to_running
					first starting
					accept RunSignal
					then running;
				transition running_to_stopping
					first running
					accept StopSignal
					then stopping;
				transition stopping_to_stopped
					first stopping
					accept StoppedSignal
					then stopped;
				transition running_to_faulted
					first running
					accept FaultSignal
					then faulted;
				transition faulted_to_stopped
					first faulted
					accept ResetSignal
					then stopped;
			}
		}

		requirement def HighSolidContentHandling {
			subject pump : SlurryPump;
			doc /* The pump shall handle solid content up to 45%. */
			constraint { pump.maxSolidContent >= 0.45 }
		}
		requirement def FlowRateRequirement {
			subject pump : SlurryPump;
			doc /* The pump shall maintain a flow rate of 200 m^3/h. */
			constraint { pump.targetFlowRate >= 200 [m^3/h] }
		}
		requirement def MaintenanceIntervalRequirement {
			subject system : SlurryPump;
			attribute maintenanceInterval :> ISQ::time = 8000 [h];
			doc /* The system shall run continuously for 8000 hours between maintenance periods. */
		}
	}

	package Usages {
		part context {
			part powerSupply : PowerSupply;
			part motorController : MotorController;
			part slurryPump : SlurryPump;
			part sourceTank : SourceTank;
			part suctionPiping : Piping {
				attribute length = 15 [m];
			}
			part suctionFlowMeter : FlowMeter;
			part suctionPressureSensor : PressureSensor;
			part dischargePiping : Piping {
				attribute length = 25 [m];
			}
			part dischargeFlowMeter : FlowMeter;
			part dischargePressureSensor : PressureSensor;
			part destinationTank : DestinationTank;

			requirement req1 : HighSolidContentHandling;
			requirement req2 : FlowRateRequirement;
			requirement req3 : MaintenanceIntervalRequirement;

			flow of slurry : Slurry
				from sourceTank.slurryOut.slurry to suctionPiping.fluidIn.slurry;
			flow of slurry : Slurry
				from suctionPiping.fluidOut.slurry to suctionFlowMeter.fluidIn.slurry;
			flow of slurry : Slurry
				from suctionFlowMeter.fluidOut.slurry to suctionPressureSensor.fluidIn.slurry;
			flow of slurry : Slurry
				from suctionPressureSensor.fluidOut.slurry to slurryPump.slurryIn.slurry;
			flow of slurry : Slurry
				from slurryPump.slurryOut.slurry to dischargePressureSensor.fluidIn.slurry;
			flow of slurry : Slurry
				from dischargePressureSensor.fluidOut.slurry to dischargeFlowMeter.fluidIn.slurry;
			flow of slurry : Slurry
				from dischargeFlowMeter.fluidOut.slurry to dischargePiping.fluidIn.slurry;
			flow of slurry : Slurry
				from dischargePiping.fluidOut.slurry to destinationTank.slurryIn.slurry;

			flow of power : ElectricalPower
				from powerSupply.powerOut.power to motorController.powerIn.power;
			flow of power : ElectricalPower
				from motorController.powerOut.power to slurryPump.powerIn.power;

			connect motorController.controlOut to slurryPump.controlIn;

			satisfy req1 by slurryPump;
			satisfy req2 by slurryPump;
			satisfy req3 by slurryPump;
		}
	}
}
