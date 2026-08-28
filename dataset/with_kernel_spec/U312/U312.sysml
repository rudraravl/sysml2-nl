package 'Microneedle Patch System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Drug;
		
		attribute def PressureValue :> Real { unit = "Pa"; }
		attribute def VolumeValue :> Real { unit = "mL"; }
		attribute def FlowRateValue :> Real { unit = "mL/h"; }
		attribute def DoseValue :> Real { unit = "mL"; }
		attribute def DurationValue :> Real { unit = "h"; }
		
		attribute def PumpCommand;
		attribute def StartCommand :> PumpCommand;
		attribute def StopCommand :> PumpCommand;
		attribute def PenetrationConfirmed;
		attribute def DoseComplete;
		
		part def MicroneedleArray {
			attribute needleCount : Integer;
			port drugInPort {
				in drugIn : Drug;
			}
		}
		
		part def AdhesiveBacking {
			attribute wearDuration : DurationValue;
		}
		
		part def DrugReservoir {
			attribute capacity : VolumeValue;
			attribute isRefillable : Boolean = false;
			port drugOutPort {
				out drugOut : Drug;
			}
		}
		
		part def MicrofluidicPump {
			port drugInPort {
				in drugIn : Drug;
			}
			port drugOutPort {
				out drugOut : Drug;
			}
			port commandInPort {
				in command : PumpCommand;
			}
			attribute flowRate : FlowRateValue;
		}
		
		part def PressureSensor {
			port pressureOutPort {
				out pressure : PressureValue;
			}
		}
		
		part def FlowController {
			port pressureInPort {
				in pressure : PressureValue;
			}
			port commandOutPort {
				out command : PumpCommand;
			}
			attribute prescribedDose : DoseValue;
			attribute deliveredVolume : VolumeValue;
		}
		
		part def MicroneedlePatch {
			part microneedleArray : MicroneedleArray;
			part adhesiveBacking : AdhesiveBacking;
			part drugReservoir : DrugReservoir;
			part microfluidicPump : MicrofluidicPump;
			part flowController : FlowController;
			part pressureSensor : PressureSensor;
			
			flow drugFlow1 : Drug 
				from drugReservoir.drugOutPort.drugOut to microfluidicPump.drugInPort.drugIn;
			flow drugFlow2 : Drug 
				from microfluidicPump.drugOutPort.drugOut to microneedleArray.drugInPort.drugIn;
			flow pressureFlow : PressureValue 
				from pressureSensor.pressureOutPort.pressure to flowController.pressureInPort.pressure;
			flow commandFlow : PumpCommand 
				from flowController.commandOutPort.command to microfluidicPump.commandInPort.command;
		}
		
		state def 'Patch States';
		action def 'Deliver Drug';
		action def 'Monitor Volume';
		
		requirement def 'Transdermal Delivery Requirement' {
			subject patch : MicroneedlePatch;
			require { patch.flowController.deliveredVolume == patch.flowController.prescribedDose }
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part patch : MicroneedlePatch {
			exhibit state 'patch states' : 'Patch States' {
				entry; then idle;
				state idle;
				accept 'PenetrationConfirmed'
					then delivering;
				state delivering {
					entry send new StartCommand() to microfluidicPump;
					do 'Deliver Drug';
					do 'Monitor Volume';
				}
				accept 'DoseComplete'
					do send new StopCommand() to microfluidicPump
					then terminated;
				state terminated;
			}
		}
	}
}
