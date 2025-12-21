package 'Pulser Pumping Subsystem' {
	private import ScalarValues::Real;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		item def ElectricalPower {
			attribute voltage : Real;
			attribute current : Real;
		}
		
		port def FluidPort {
			out item fluid : Fluid;
		}
		
		port def PowerPort {
			in item power : ElectricalPower;
		}
		
		port def ControlPort {
			in attribute commandSignal : Real;
			out attribute statusSignal : Real;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}
		
		action def PrimeSystem {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}
		
		state def PulserPumpStateMachine {
			entry; then idle;
			
			state idle;
			state priming;
			state running;
			state fault;
			
			transition idle_to_priming
				first idle
				then priming;
			
			transition priming_to_running
				first priming
				then running;
			
			transition running_to_idle
				first running
				then idle;
			
			transition any_to_fault
				first idle
				then fault;
			
			transition fault_to_idle
				first fault
				then idle;
			
			state running {
				entry; then normalOperation;
				
				state normalOperation;
				state highPressure;
				state lowFlow;
				
				transition normal_to_highPressure
					first normalOperation
					then highPressure;
				
				transition highPressure_to_normal
					first highPressure
					then normalOperation;
				
				transition normal_to_lowFlow
					first normalOperation
					then lowFlow;
				
				transition lowFlow_to_normal
					first lowFlow
					then normalOperation;
			}
		}
		
		part def SupplyTank {
			port fluidOutPort : FluidPort;
			attribute capacity : Real;
			attribute currentLevel : Real;
			item storedFluid : Fluid {
				attribute volume : Real;
			}
		}
		
		part def CheckValve {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			attribute crackingPressure : Real;
		}
		
		part def PulserPump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			port powerPort : PowerPort;
			port controlPort : ControlPort;
			
			attribute strokeVolume : Real;
			attribute pulseFrequency : Real;
			attribute maxDischargePressure : Real;
			attribute efficiency : Real;
			
			part pulsationChamber {
				attribute chamberVolume : Real;
				attribute chamberPressure : Real;
			}
			
			part diaphragm {
				attribute displacement : Real;
				attribute cycleCount : Real;
			}
			
			perform action pumpOperation : PumpFluid {
				in fluidIn = inletPort.fluid;
				out fluidOut = outletPort.fluid;
			}
			
			perform action primingOperation : PrimeSystem {
				in fluidIn = inletPort.fluid;
				out fluidOut = outletPort.fluid;
			}
			
			exhibit state pumpStateMachine : PulserPumpStateMachine;
		}
		
		part def Accumulator {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			attribute capacity : Real;
			attribute preChargePressure : Real;
			item storedFluid : Fluid {
				attribute volume : Real;
			}
		}
		
		part def DischargeManifold {
			port inletPort : ~FluidPort;
			attribute outletPressure : Real;
		}
		
		part def FlowMeter {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			attribute measuredFlowRate : Real;
			attribute totalVolume : Real;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Real;
			attribute accuracy : Real;
		}
		
		part def Controller {
			port controlOutPort : ControlPort;
			port powerInPort : ~PowerPort;
			attribute setPoint : Real;
			attribute feedbackValue : Real;
			attribute outputCommand : Real;
		}
		
		part def PowerSupply {
			port powerOutPort : PowerPort;
			attribute outputVoltage : Real;
			attribute maxCurrent : Real;
			item availablePower : ElectricalPower {
				attribute voltage : Real;
				attribute current : Real;
			}
		}
		
		part def PumpingSubsystem {
			part supplyTank : SupplyTank;
			part suctionCheckValve : CheckValve;
			part pulserPump : PulserPump;
			part dischargeCheckValve : CheckValve;
			part accumulator : Accumulator;
			part flowMeter : FlowMeter;
			part dischargeManifold : DischargeManifold;
			part pressureSensor : PressureSensor;
			part controller : Controller;
			part powerSupply : PowerSupply;
		}
		
		requirement def PumpingSystemRequirements {
			subject subsystem : PumpingSubsystem;
			
			doc /* Flow rate requirement: The subsystem shall deliver fluid at minimum average flow rate of 0.5 L/s. */
			
			doc /* Pressure requirement: The subsystem shall maintain discharge pressure between 5 and 15 bar. */
			
			doc /* Reliability requirement: The pump shall operate continuously for at least 5000 hours between failures. */
			
			doc /* Efficiency requirement: The pump shall operate at minimum 70% efficiency at rated conditions. */
		}
	}
	
	package Usages {
		part pumpingSubsystem : Definitions::PumpingSubsystem {
			part supplyTank : Definitions::SupplyTank {
				attribute capacity = 200.0;
				attribute currentLevel = 150.0;
				item storedFluid {
					attribute volume = 150.0;
					attribute density = 1000.0;
					attribute viscosity = 0.001;
					attribute temperature = 20.0;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from supplyTank.fluidOutPort.fluid
				to suctionCheckValve.inletPort.fluid;
			
			part suctionCheckValve : Definitions::CheckValve {
				attribute crackingPressure = 0.1;
			}
			
			flow of fluid : Definitions::Fluid
				from suctionCheckValve.outletPort.fluid
				to pulserPump.inletPort.fluid;
			
			part pulserPump : Definitions::PulserPump {
				attribute strokeVolume = 0.005;
				attribute pulseFrequency = 100.0;
				attribute maxDischargePressure = 20.0;
				attribute efficiency = 0.75;
				
				part pulsationChamber {
					attribute chamberVolume = 0.01;
					attribute chamberPressure = 10.0;
				}
				
				part diaphragm {
					attribute displacement = 0.005;
					attribute cycleCount = 0.0;
				}
				
				perform action pumpOperation : Definitions::PumpFluid {
					in fluidIn = inletPort.fluid;
					out fluidOut = outletPort.fluid;
				}
				
				perform action primingOperation : Definitions::PrimeSystem {
					in fluidIn = inletPort.fluid;
					out fluidOut = outletPort.fluid;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from pulserPump.outletPort.fluid
				to dischargeCheckValve.inletPort.fluid;
			
			part dischargeCheckValve : Definitions::CheckValve {
				attribute crackingPressure = 0.2;
			}
			
			flow of fluid : Definitions::Fluid
				from dischargeCheckValve.outletPort.fluid
				to accumulator.inletPort.fluid;
			
			part accumulator : Definitions::Accumulator {
				attribute capacity = 5.0;
				attribute preChargePressure = 8.0;
				item storedFluid {
					attribute volume = 2.5;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from accumulator.outletPort.fluid
				to flowMeter.inletPort.fluid;
			
			part flowMeter : Definitions::FlowMeter {
				attribute measuredFlowRate = 0.5;
				attribute totalVolume = 0.0;
			}
			
			flow of fluid : Definitions::Fluid
				from flowMeter.outletPort.fluid
				to dischargeManifold.inletPort.fluid;
			
			part dischargeManifold : Definitions::DischargeManifold {
				attribute outletPressure = 10.0;
			}
			
			part pressureSensor : Definitions::PressureSensor {
				attribute measuredPressure = 10.0;
				attribute accuracy = 0.01;
			}
			
			bind pressureSensor.measuredPressure = dischargeManifold.outletPressure;
			
			part controller : Definitions::Controller {
				attribute setPoint = 10.0;
				attribute feedbackValue = pressureSensor.measuredPressure;
				attribute outputCommand = 100.0;
			}
			
			connect controller.controlOutPort to pulserPump.controlPort;
			
			part powerSupply : Definitions::PowerSupply {
				attribute outputVoltage = 24.0;
				attribute maxCurrent = 15.0;
				item availablePower {
					attribute voltage = 24.0;
					attribute current = 12.0;
				}
			}
			
			flow of power : Definitions::ElectricalPower
				from powerSupply.powerOutPort.power
				to pulserPump.powerPort.power;
			
			flow of power : Definitions::ElectricalPower
				from powerSupply.powerOutPort.power
				to controller.powerInPort.power;
			
			attribute averageFlowRate : Real = pulserPump.strokeVolume * pulserPump.pulseFrequency;
			
			assert constraint flowRateConstraint {
				averageFlowRate >= 0.5
			}
			
			assert constraint pressureConstraint {
				dischargeManifold.outletPressure >= 5.0 &
				dischargeManifold.outletPressure <= 15.0
			}
			
			assert constraint safetyConstraint {
				dischargeManifold.outletPressure <= pulserPump.maxDischargePressure
			}
			
			assert constraint efficiencyConstraint {
				pulserPump.efficiency >= 0.70
			}
		}
		
		requirement pumpingSystemReqs : Definitions::PumpingSystemRequirements {
			subject subsystem = pumpingSubsystem;
		}
	}
	
	dependency PumpingSubsystemDependencies
		from Usages::pumpingSubsystem
		to Definitions::PumpingSystemRequirements;
}
