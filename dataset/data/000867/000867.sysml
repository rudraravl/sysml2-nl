package 'Drum Pumping Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		item def Fluid {
			attribute viscosity : Real;
			attribute density : Real;
			attribute temperature : Real;
		}
		
		attribute def VolumeValue :> Real;
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def PowerValue :> Real;
		attribute def SpeedValue :> Real;
		
		enum def PumpState {
			enum idle;
			enum priming;
			enum running;
			enum stopping;
			enum faulted;
		}
		
		port def FluidInPort {
			in item fluid : Fluid;
			attribute pressure : PressureValue;
		}
		
		port def FluidOutPort {
			out item fluid : Fluid;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		port def PowerInPort {
			attribute voltage : Real;
			attribute current : Real;
		}
		
		part def SourceDrum {
			port outlet : FluidOutPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid {
				attribute volume : VolumeValue;
			}
		}
		
		part def DestinationTank {
			port inlet : FluidInPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item receivedFluid : Fluid {
				attribute volume : VolumeValue;
			}
		}
		
		part def DrumRotor {
			attribute diameter : Real;
			attribute length : Real;
			attribute bladeCount : Integer;
			attribute rotationSpeed : SpeedValue;
			attribute volumePerRevolution : VolumeValue;
		}
		
		part def DriveMotor {
			port powerInput : PowerInPort;
			attribute ratedPower : PowerValue;
			attribute ratedSpeed : SpeedValue;
			attribute currentSpeed : SpeedValue;
			attribute efficiency : Real;
		}
		
		part def SuctionPipe {
			port inlet : FluidInPort;
			port outlet : FluidOutPort;
			attribute length : Real;
			attribute diameter : Real;
			attribute roughness : Real;
		}
		
		part def DischargePipe {
			port inlet : FluidInPort;
			port outlet : FluidOutPort;
			attribute length : Real;
			attribute diameter : Real;
			attribute roughness : Real;
		}
		
		part def MechanicalSeal {
			attribute sealType : String;
			attribute maxPressure : PressureValue;
			attribute maxTemperature : Real;
			attribute leakageRate : FlowRateValue;
		}
		
		part def DrumPump {
			port suctionPort : FluidInPort;
			port dischargePort : FluidOutPort;
			port powerPort : PowerInPort;
			
			attribute maxFlowRate : FlowRateValue;
			attribute maxPressure : PressureValue;
			attribute currentState : PumpState;
			attribute overallEfficiency : Real;
			
			part motor : DriveMotor {
				attribute :>> ratedPower = 2200.0;
				attribute :>> ratedSpeed = 1450.0;
				attribute :>> currentSpeed = 0.0;
				attribute :>> efficiency = 0.92;
			}
			
			part drumRotor : DrumRotor {
				attribute :>> diameter = 150.0;
				attribute :>> length = 300.0;
				attribute :>> bladeCount = 6;
				attribute :>> rotationSpeed = 0.0;
				attribute :>> volumePerRevolution = 0.75;
			}
			
			part suctionPipe : SuctionPipe {
				attribute :>> length = 1.5;
				attribute :>> diameter = 0.05;
				attribute :>> roughness = 0.0015;
			}
			
			part dischargePipe : DischargePipe {
				attribute :>> length = 2.0;
				attribute :>> diameter = 0.04;
				attribute :>> roughness = 0.0015;
			}
			
			part seal : MechanicalSeal {
				attribute :>> sealType = "Double Mechanical Seal";
				attribute :>> maxPressure = 100.0;
				attribute :>> maxTemperature = 120.0;
				attribute :>> leakageRate = 0.01;
			}
			
			bind suctionPort.fluid = suctionPipe.inlet.fluid;
			bind dischargePipe.outlet.fluid = dischargePort.fluid;
		}
		
		interface def FluidTransferInterface {
			end port supplier : FluidOutPort;
			end port consumer : FluidInPort;
		}
		
		action def PrimeSystem {
			in pumpRef : DrumPump;
			out primingSuccess : Boolean;
		}
		
		action def StartPump {
			in pumpRef : DrumPump;
			in targetSpeed : SpeedValue;
			out startSuccess : Boolean;
		}
		
		action def StopPump {
			in pumpRef : DrumPump;
			out stopSuccess : Boolean;
		}
		
		action def MonitorFlow {
			in pumpRef : DrumPump;
			out flowRate : FlowRateValue;
			out pressureDifferential : PressureValue;
		}
		
		action def DetectCavitation {
			in inletPressure : PressureValue;
			in vaporPressure : PressureValue;
			out cavitationDetected : Boolean;
		}
		
		action def CheckLevels {
			in sourceLevel : VolumeValue;
			in destLevel : VolumeValue;
			in destCapacity : VolumeValue;
			out canPump : Boolean;
		}
		
		action def OperateDrumPumpSystem {
			in sourceLevel : VolumeValue;
			in destLevel : VolumeValue;
			in destCapacity : VolumeValue;
			in targetFlowRate : FlowRateValue;
			
			first start;
			then merge checkConditions;
			
			then action checkLevels : CheckLevels {
				in sourceLevel = OperateDrumPumpSystem::sourceLevel;
				in destLevel = OperateDrumPumpSystem::destLevel;
				in destCapacity = OperateDrumPumpSystem::destCapacity;
			}
			
			then decide;
				if checkLevels.canPump then primeSystem;
				if !checkLevels.canPump then shutdown;
			
			action primeSystem : PrimeSystem;
			then startPump;
			
			action startPump : StartPump {
				in targetSpeed = 1450.0;
			}
			
			then merge monitorLoop;
			
			then action monitorFlow : MonitorFlow;
			
			then action detectCavitation : DetectCavitation {
				in inletPressure = monitorFlow.pressureDifferential;
				in vaporPressure = 2.3;
			}
			
			then decide;
				if detectCavitation.cavitationDetected then stopPump;
				if destLevel >= destCapacity * 0.95 then stopPump;
				if monitorFlow.flowRate > 0.0 then monitorLoop;
			
			action stopPump : StopPump;
			then shutdown;
			
			action shutdown;
			then done;
		}
	}
	
	package Requirements {
		private import Definitions::*;
		
		requirement def FlowRateRequirement {
			doc /*
			 * The drum pump shall deliver a minimum flow rate of 
			 * 40 liters per minute at rated operating conditions.
			 */
			subject pump : DrumPump;
			require constraint {
				pump.dischargePort.flowRate >= 40.0
			}
		}
		
		requirement def PressureRequirement {
			doc /*
			 * The drum pump shall maintain discharge pressure between
			 * 2.0 and 8.0 bar during normal operation.
			 */
			subject pump : DrumPump;
			require constraint {
				pump.dischargePort.pressure >= 2.0 and
				pump.dischargePort.pressure <= 8.0
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /*
			 * The drum pump system shall operate at a minimum
			 * overall efficiency of 75% at rated conditions.
			 */
			subject pump : DrumPump;
			require constraint {
				pump.overallEfficiency >= 0.75
			}
		}
		
		requirement def CavitationPreventionRequirement {
			doc /*
			 * The drum pump shall detect and prevent cavitation
			 * by monitoring inlet pressure and shutting down if
			 * pressure drops below vapor pressure threshold.
			 */
			subject pump : DrumPump;
		}
		
		requirement def SystemRequirements {
			subject system : DrumPumpingSystem;
			require flowReq : FlowRateRequirement;
			require pressureReq : PressureRequirement;
			require efficiencyReq : EfficiencyRequirement;
			require cavitationReq : CavitationPreventionRequirement;
		}
		
		part def DrumPumpingSystem {
			part sourceDrum : SourceDrum;
			part drumPump : DrumPump;
			part destinationTank : DestinationTank;
		}
	}
	
	package Usages {
		private import Definitions::*;
		private import Requirements::*;
		
		part drumPumpingSystem {
			part sourceDrum : SourceDrum {
				attribute :>> capacity = 1000.0;
				attribute :>> currentLevel = 800.0;
				item :>> storedFluid {
					attribute :>> volume = 800.0;
					attribute :>> viscosity = 0.001;
					attribute :>> density = 1000.0;
					attribute :>> temperature = 20.0;
				}
			}
			
			flow of transferFluid : Fluid
				from sourceDrum.outlet.fluid to drumPump.suctionPort.fluid;
			
			part drumPump : DrumPump {
				attribute :>> maxFlowRate = 50.0;
				attribute :>> maxPressure = 10.0;
				attribute :>> currentState = PumpState::idle;
				attribute :>> overallEfficiency = 0.78;
				
				perform action operation : OperateDrumPumpSystem {
					in sourceLevel = sourceDrum.currentLevel;
					in destLevel = destinationTank.currentLevel;
					in destCapacity = destinationTank.capacity;
					in targetFlowRate = drumPump.maxFlowRate;
				}
			}
			
			flow of transferFluid : Fluid
				from drumPump.dischargePort.fluid to destinationTank.inlet.fluid;
			
			part destinationTank : DestinationTank {
				attribute :>> capacity = 1200.0;
				attribute :>> currentLevel = 200.0;
				item :>> receivedFluid {
					attribute :>> volume = 200.0;
				}
			}
			
			interface pumpToSource : FluidTransferInterface connect
				supplier ::> sourceDrum.outlet to
				consumer ::> drumPump.suctionPort;
			
			interface pumpToDest : FluidTransferInterface connect
				supplier ::> drumPump.dischargePort to
				consumer ::> destinationTank.inlet;
			
			satisfy requirement systemReqs : SystemRequirements {
				subject system : DrumPumpingSystem {
					part :>> sourceDrum = drumPumpingSystem.sourceDrum;
					part :>> drumPump = drumPumpingSystem.drumPump;
					part :>> destinationTank = drumPumpingSystem.destinationTank;
				}
			}
		}
	}
}
