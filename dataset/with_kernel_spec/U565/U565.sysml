package 'Industrial Fluid Pumping System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package 'System Definitions' {
		item def Fluid;
		item def RotationalPower;
		
		port def FluidPort {
			out item fluid : Fluid;
		}
		
		port def PowerPort {
			out item power : RotationalPower;
		}
		
		part def SourceReservoir {
			port fluidOutPort : FluidPort;
		}
		
		part def DestinationReservoir {
			port fluidInPort : ~FluidPort;
		}
		
		part def ElectricMotor {
			port powerOutPort : PowerPort;
			attribute ratedPower : PowerValue;
			attribute efficiency : Real;
		}
		
		part def CentrifugalPump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port powerInPort : ~PowerPort;
			attribute pressureRise : PressureValue;
			attribute designFlowRate : VolumeFlowRateValue;
			attribute efficiency : Real;
		}
		
		part def PressureSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute reading : PressureValue;
		}
		
		part def FlowMeter {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute reading : VolumeFlowRateValue;
		}
		
		part def ControlValve {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute position : Real;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			in powerIn : RotationalPower;
			out fluidOut : Fluid;
		}
		
		action def MonitorPressure {
			in fluid : Fluid;
			out pressure : PressureValue;
		}
		
		action def MonitorFlowRate {
			in fluid : Fluid;
			out flowRate : VolumeFlowRateValue;
		}
		
		action def RegulateFlow {
			in fluidIn : Fluid;
			in valveOpening : Real;
			out fluidOut : Fluid;
		}
		
		attribute def StartSignal;
		attribute def RunningSignal;
		attribute def StopSignal;
		attribute def IdleSignal;
		
		state def PumpOperationalStates;
	}
	
	package 'System Usages' {
		public import 'System Definitions'::*;
		
		part pumpingSystem {
			part sourceReservoir : SourceReservoir;
			
			part motor : ElectricMotor {
				attribute :>> ratedPower = 5000 [W];
				attribute :>> efficiency = 0.92;
			}
			
			part pump : CentrifugalPump {
				attribute :>> pressureRise = 300000 [Pa];
				attribute :>> designFlowRate = 0.01;
				attribute :>> efficiency = 0.85;
				
				state pumpStates : PumpOperationalStates {
					entry; then idle;
					state idle;
					accept StartSignal then starting;
					state starting;
					accept RunningSignal then running;
					state running {
						do action pumpFluidAction : PumpFluid {
							in fluidIn = fluidInPort.fluid;
							in powerIn = powerInPort.power;
							out fluidOut = fluidOutPort.fluid;
						}
					}
					accept StopSignal then stopping;
					state stopping;
					accept IdleSignal then idle;
				}
			}
			
			part pressureSensor : PressureSensor {
				perform action monitorPressure : MonitorPressure {
					in fluid = fluidInPort.fluid;
					out pressure = reading;
				}
			}
			
			part flowMeter : FlowMeter {
				perform action monitorFlowRate : MonitorFlowRate {
					in fluid = fluidInPort.fluid;
					out flowRate = reading;
				}
			}
			
			part controlValve : ControlValve {
				attribute :>> position = 0.8;
				perform action regulateFlow : RegulateFlow {
					in fluidIn = fluidInPort.fluid;
					in valveOpening = position;
					out fluidOut = fluidOutPort.fluid;
				}
			}
			
			part destinationReservoir : DestinationReservoir;
			
			flow of fluid : Fluid
				from sourceReservoir.fluidOutPort.fluid
				to pump.fluidInPort.fluid;
			
			flow of power : RotationalPower
				from motor.powerOutPort.power
				to pump.powerInPort.power;
			
			flow of fluid : Fluid
				from pump.fluidOutPort.fluid
				to pressureSensor.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from pressureSensor.fluidOutPort.fluid
				to flowMeter.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from flowMeter.fluidOutPort.fluid
				to controlValve.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from controlValve.fluidOutPort.fluid
				to destinationReservoir.fluidInPort.fluid;
		}
	}
	
	package 'System Requirements' {
		public import 'System Definitions'::*;
		
		requirement def <'1'> FlowRateRequirement {
			doc /* The system shall deliver a fluid flow rate of at least 0.01 cubic meters per second. */
			attribute actualFlowRate : VolumeFlowRateValue;
			attribute requiredFlowRate : VolumeFlowRateValue;
			require constraint {
				actualFlowRate >= requiredFlowRate
			}
		}
		
		requirement def <'2'> PressureRequirement {
			doc /* The pump shall provide a pressure rise of at least 300000 Pa. */
			attribute actualPressureRise : PressureValue;
			attribute requiredPressureRise : PressureValue;
			require constraint {
				actualPressureRise >= requiredPressureRise
			}
		}
		
		requirement def <'3'> PowerConsumptionRequirement {
			doc /* The motor power consumption shall not exceed 5000 W. */
			attribute actualPower : PowerValue;
			attribute maxPower : PowerValue;
			require constraint {
				actualPower <= maxPower
			}
		}
		
		requirement <'1.1'> systemFlowRate : FlowRateRequirement {
			subject pump : CentrifugalPump;
			attribute :>> actualFlowRate = pump.designFlowRate;
			attribute :>> requiredFlowRate = 0.01;
		}
		
		requirement <'2.1'> systemPressure : PressureRequirement {
			subject pump : CentrifugalPump;
			attribute :>> actualPressureRise = pump.pressureRise;
			attribute :>> requiredPressureRise = 300000 [Pa];
		}
		
		requirement <'3.1'> motorPower : PowerConsumptionRequirement {
			subject motor : ElectricMotor;
			attribute :>> actualPower = motor.ratedPower;
			attribute :>> maxPower = 5000 [W];
		}
	}
}
