package HydraulicPumpingSubsystem {
	private import ScalarValues::*;
	
	public import Definitions::*;
	
	package Definitions {
		item def HydraulicFluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		attribute def Pressure;
		attribute def FlowRate;
		attribute def Volume;
		attribute def Temperature;
		attribute def Power;
		attribute def RotationalSpeed;
		
		port def FluidOutPort {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
			out item fluid : HydraulicFluid;
		}
		
		port def FluidInPort {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
			in item fluid : HydraulicFluid;
		}
		
		port def CaseDrainPort {
			out item leakageFluid : HydraulicFluid;
		}
		
		port def PowerInPort {
			in attribute power : Power;
			in attribute speed : RotationalSpeed;
		}
		
		interface def FluidTransferInterface {
			end port supplierPort : FluidOutPort;
			end port consumerPort : FluidInPort;
		}
		
		action def PumpFluid {
			in fluidIn : HydraulicFluid;
			in power : Power;
			out fluidOut : HydraulicFluid;
		}
		
		action def MoveFluid {
			in fluidIn : HydraulicFluid;
			out fluidOut : HydraulicFluid;
		}
		
		action def primeInlet;
		
		action def StartCommand;
		action def StopCommand;
		action def ResetCommand;
		
		state def PumpOperatingStates {
			entry; then off;
			
			state off;
			transition off_to_priming
				first off
				accept StartCommand
				then priming;
			
			state priming;
			transition priming_to_running
				first priming
				then running;
			
			state running;
			transition running_to_off
				first running
				accept StopCommand
				then off;
			
			transition running_to_fault
				first running
				then fault;
			
			state fault;
			transition fault_to_off
				first fault
				accept ResetCommand
				then off;
		}
		
		part def Reservoir {
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute minLevel : Volume;
			
			port supplyPort : FluidOutPort;
			port returnPort : ~FluidOutPort;
			
			item storedFluid : HydraulicFluid {
				attribute volume : Volume;
			}
		}
		
		part def HydraulicPump {
			attribute ratedFlowRate : FlowRate;
			attribute maxPressure : Pressure;
			attribute minInletPressure : Pressure;
			attribute displacement : Real;
			attribute efficiency : Real;
			
			port suctionPort : FluidInPort;
			port dischargePort : FluidOutPort;
			port caseDrainPort : CaseDrainPort;
			port drivePort : PowerInPort;
			
			perform action pumpFluid : PumpFluid {
				in fluidIn = suctionPort.fluid;
				in power = drivePort.power;
				out fluidOut = dischargePort.fluid;
			}
			
			exhibit state pumpStates : PumpOperatingStates;
		}
		
		part def PressureReliefValve {
			attribute crackingPressure : Pressure;
			attribute maxFlowRate : FlowRate;
			
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
		}
		
		part def HydraulicActuator {
			attribute requiredFlow : FlowRate;
			attribute requiredPressure : Pressure;
			attribute strokeLength : Real;
			
			port supplyPort : FluidInPort;
			port returnPort : FluidOutPort;
		}
		
		part def ElectricMotor {
			attribute ratedPower : Power;
			attribute operatingSpeed : RotationalSpeed;
			
			port driveOutput : PowerInPort;
		}
	}
	
	package Usages {
		public import Definitions::*;
		
		part hydraulicPumpingSubsystem {
			part reservoir : Reservoir {
				attribute redefines capacity = 100.0;
				attribute redefines currentLevel = 80.0;
				attribute redefines minLevel = 15.0;
			}
			
			part motor : ElectricMotor {
				attribute redefines ratedPower = 15.0;
				attribute redefines operatingSpeed = 1800.0;
			}
			
			part pump : HydraulicPump {
				attribute redefines ratedFlowRate = 50.0;
				attribute redefines maxPressure = 21000.0;
				attribute redefines minInletPressure = 80.0;
				attribute redefines displacement = 28.0;
				attribute redefines efficiency = 0.88;
			}
			
			part reliefValve : PressureReliefValve {
				attribute redefines crackingPressure = 21500.0;
				attribute redefines maxFlowRate = 60.0;
			}
			
			part actuator : HydraulicActuator {
				attribute redefines requiredFlow = 40.0;
				attribute redefines requiredPressure = 18000.0;
				attribute redefines strokeLength = 250.0;
			}
			
			interface reservoirToPump : FluidTransferInterface connect
				supplierPort ::> reservoir.supplyPort to
				consumerPort ::> pump.suctionPort;
			
			interface pumpToRelief : FluidTransferInterface connect
				supplierPort ::> pump.dischargePort to
				consumerPort ::> reliefValve.inletPort;
			
			interface reliefToActuator : FluidTransferInterface connect
				supplierPort ::> reliefValve.outletPort to
				consumerPort ::> actuator.supplyPort;
			
			flow of fluid : HydraulicFluid
				from reservoir.supplyPort.fluid to pump.suctionPort.fluid;
			
			flow of fluid : HydraulicFluid
				from pump.dischargePort.fluid to reliefValve.inletPort.fluid;
			
			flow of fluid : HydraulicFluid
				from reliefValve.outletPort.fluid to actuator.supplyPort.fluid;
			
			flow returnFlow of fluid : HydraulicFluid
				from actuator.returnPort.fluid to reservoir.returnPort.fluid;
			
			flow drainFlow of fluid : HydraulicFluid
				from pump.caseDrainPort.leakageFluid to reservoir.returnPort.fluid;
			
			bind motor.driveOutput.power = pump.drivePort.power;
			bind motor.driveOutput.speed = pump.drivePort.speed;
			
			perform action moveFluid : MoveFluid {
				in fluidIn = reservoir.supplyPort.fluid;
				out fluidOut = actuator.supplyPort.fluid;
			}
			
			assert constraint adequateFluidLevel {
				reservoir.currentLevel > reservoir.minLevel
			}
			
			assert constraint pumpFlowCapacity {
				pump.ratedFlowRate >= actuator.requiredFlow
			}
			
			assert constraint pumpPressureCapacity {
				pump.maxPressure >= actuator.requiredPressure
			}
			
			requirement pumpingSystemRequirement {
				doc /* The pumping subsystem shall provide adequate flow and pressure */
				
				require constraint deliverFlow {
					pump.ratedFlowRate >= 40.0
				}
				
				require constraint deliverPressure {
					pump.maxPressure >= 18000.0
				}
				
				require constraint efficiency {
					pump.efficiency >= 0.85
				}
				
				require constraint reservoirCapacity {
					reservoir.capacity >= 80.0
				}
			}
		}
	}
}
