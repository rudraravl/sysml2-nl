package PumpingSubsystemModel {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def VolumeValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def PowerValue :> Real;
		attribute def TemperatureValue :> Real;
		
		enum def PumpStatus {
			enum stopped;
			enum starting;
			enum operating;
			enum stopping;
			enum faulted;
		}
		
		item def Fluid {
			attribute volume : VolumeValue;
			attribute temperature : TemperatureValue;
			attribute density : Real;
		}
		
		port def FluidPort {
			out item fluidOut : Fluid;
		}
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
		}
		
		part def SourceTank {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port outletPort : FluidPort;
			
			item storedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def DestinationTank {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port inletPort : FluidInletPort;
			
			item receivedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def BigPump {
			attribute pumpIdentifier : String;
			attribute ratedFlowRate : FlowRateValue;
			attribute maxDischargePressure : PressureValue;
			attribute motorPower : PowerValue;
			attribute operationalStatus : PumpStatus = PumpStatus::stopped;
			
			port suctionPort : FluidInletPort;
			port dischargePort : FluidPort;
			
			perform action pumpingOperation : PumpFluid;
		}
		
		action def PumpFluid {
			in fluidInput : Fluid;
			out fluidOutput : Fluid;
			attribute flowRate : FlowRateValue;
			
			first start;
			then action drawFluid {
				in sourceFluid = fluidInput;
				out drawnFluid : Fluid;
			}
			then action pressurizeFluid {
				in inputFluid = drawFluid.drawnFluid;
				out pressurizedFluid : Fluid;
			}
			then action dischargeFluid {
				in fluidToDischarge = pressurizeFluid.pressurizedFluid;
				out dischargedFluid = fluidOutput;
			}
			then done;
		}
		
		part def PumpingSubsystem {
			attribute subsystemId : String;
			port systemInlet : FluidInletPort;
			port systemOutlet : FluidPort;
		}
		
		requirement def FluidTransferRequirement {
			doc /* The pumping subsystem shall transfer fluid from source to destination. */
			subject subsystem : PumpingSubsystem;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /* The Big Pump shall achieve rated flow rate during operation. */
			subject pump : BigPump;
			attribute minimumEfficiency : Real = 0.90;
		}
		
		requirement def PressureLimitRequirement {
			doc /* The Big Pump discharge pressure shall not exceed maximum rating. */
			subject pump : BigPump;
		}
	}
	
	package Usages {
		part pumpingSubsystem : PumpingSubsystem {
			attribute :>> subsystemId = "PS-001";
			
			part sourceTank : SourceTank {
				attribute :>> capacity = 10000.0;
				attribute :>> currentLevel = 7500.0;
			}
			
			part bigPump : BigPump {
				attribute :>> pumpIdentifier = "BIGPUMP-001";
				attribute :>> ratedFlowRate = 250.0;
				attribute :>> maxDischargePressure = 200.0;
				attribute :>> motorPower = 100.0;
			}
			
			part destinationTank : DestinationTank {
				attribute :>> capacity = 12000.0;
				attribute :>> currentLevel = 2000.0;
			}
			
			flow sourceToSuction of fluid : Fluid
				from sourceTank.outletPort.fluidOut
				to bigPump.suctionPort.fluidIn;
			
			flow dischargeToDestination of fluid : Fluid
				from bigPump.dischargePort.fluidOut
				to destinationTank.inletPort.fluidIn;
			
			bind systemInlet = sourceTank.outletPort;
			bind systemOutlet = destinationTank.inletPort;
			
			satisfy transferReq : FluidTransferRequirement {
				subject :>> subsystem = pumpingSubsystem;
			}
			
			satisfy performanceReq : PumpPerformanceRequirement {
				subject :>> pump = bigPump;
			}
			
			satisfy pressureReq : PressureLimitRequirement {
				subject :>> pump = bigPump;
			}
		}
	}
}
