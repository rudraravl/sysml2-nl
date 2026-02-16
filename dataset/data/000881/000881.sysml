package 'Pumping Subsystem Model' {
	private import ScalarValues::*;
	private import SI::*;
	
	package Domain {
		attribute def Pressure {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def FlowRate {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Power {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Temperature {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Volume {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Voltage {
			attribute num : Real;
			attribute unit : String;
		}
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Temperature;
			attribute volume : Volume;
		}
	}
	
	package Definitions {
		public import Domain::*;
		
		port def FluidInPort {
			attribute inletPressure : Pressure;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutPort {
			attribute outletPressure : Pressure;
			out item fluidOut : Fluid;
		}
		
		port def ElectricalPowerPort {
			attribute voltage : Voltage;
			attribute current : Real;
			attribute powerConsumption : Power;
		}
		
		action def PumpFluid {
			in attribute inputPressure : Pressure;
			in attribute targetFlowRate : FlowRate;
			in item fluidIn : Fluid;
			out attribute outputPressure : Pressure;
			out attribute actualFlowRate : FlowRate;
			out item fluidOut : Fluid;
		}
		
		state def PumpOperatingStates {
			entry; then idle;
			
			state idle;
			state starting;
			state running;
			state stopping;
			state faulted;
			
			transition idle_to_starting
				first idle
				accept StartCommand
				then starting;
			
			transition starting_to_running
				first starting
				if primingComplete
				then running;
			
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;
			
			transition stopping_to_idle
				first stopping
				if pumpSpeed == 0.0
				then idle;
			
			transition running_to_faulted
				first running
				if overPressureDetected or overTemperatureDetected or cavitationDetected
				then faulted;
			
			transition faulted_to_idle
				first faulted
				accept ResetCommand
				if faultCleared
				then idle;
			
			attribute pumpSpeed : Real;
			attribute isPriming : Boolean;
			attribute isOperational : Boolean;
			attribute isFaulted : Boolean;
			attribute primingComplete : Boolean;
			attribute overPressureDetected : Boolean;
			attribute overTemperatureDetected : Boolean;
			attribute cavitationDetected : Boolean;
			attribute faultCleared : Boolean;
		}
		
		part def FuelPump {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			port powerPort : ElectricalPowerPort;
			
			attribute ratedFlowRate : FlowRate;
			attribute maxPressure : Pressure;
			attribute ratedPower : Power;
			attribute efficiency : Real;
			attribute currentFlowRate : FlowRate;
			attribute currentPower : Power;
			attribute operatingTemperature : Temperature;
			attribute impellerSpeed : Real;
			
			perform action pumpOperation : PumpFluid {
				in inputPressure = inletPort.inletPressure;
				in targetFlowRate = ratedFlowRate;
				in fluidIn = inletPort.fluidIn;
				out outputPressure = outletPort.outletPressure;
				out actualFlowRate = currentFlowRate;
				out fluidOut = outletPort.fluidOut;
			}
			
			exhibit state operatingState : PumpOperatingStates;
		}
		
		part def ElectricMotor {
			port powerInput : ElectricalPowerPort;
			
			attribute ratedVoltage : Voltage;
			attribute ratedPower : Power;
			attribute currentDraw : Real;
			attribute motorSpeed : Real;
			attribute torque : Real;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Pressure;
			attribute accuracy : Real;
			attribute calibrationDate : String;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : FlowRate;
			attribute accuracy : Real;
			attribute totalVolume : Volume;
		}
		
		part def TemperatureSensor {
			attribute measuredTemperature : Temperature;
			attribute accuracy : Real;
		}
		
		part def PumpController {
			port controlPower : ElectricalPowerPort;
			
			attribute setpointFlowRate : FlowRate;
			attribute controlSignal : Real;
			attribute pidGainP : Real;
			attribute pidGainI : Real;
			attribute pidGainD : Real;
			
			action def ControlPump {
				in attribute sensorFlowRate : FlowRate;
				in attribute sensorPressure : Pressure;
				in attribute sensorTemperature : Temperature;
				in attribute setpoint : FlowRate;
				out attribute controlOutput : Real;
			}
			
			perform action controlLoop : ControlPump;
		}
		
		part def SupplyTank {
			port outletPort : FluidOutPort;
			
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute minLevel : Volume;
			
			item storedFluid : Fluid;
		}
		
		part def ReceivingVessel {
			port inletPort : FluidInPort;
			
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute maxLevel : Volume;
			
			item storedFluid : Fluid;
		}
		
		part def CheckValve {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			
			attribute crackingPressure : Pressure;
			attribute isOpen : Boolean;
		}
		
		part def ReliefValve {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			
			attribute setpointPressure : Pressure;
			attribute isOpen : Boolean;
		}
		
		part def PumpingSubsystem {
			port systemInlet : FluidInPort;
			port systemOutlet : FluidOutPort;
			port mainPower : ElectricalPowerPort;
			
			part pump : FuelPump {
				attribute :>> ratedFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
				attribute :>> maxPressure {
					attribute :>> num = 600.0;
					attribute :>> unit = "kPa";
				}
				attribute :>> ratedPower {
					attribute :>> num = 1200.0;
					attribute :>> unit = "W";
				}
				attribute :>> efficiency = 0.82;
			}
			
			part motor : ElectricMotor {
				attribute :>> ratedVoltage {
					attribute :>> num = 24.0;
					attribute :>> unit = "V";
				}
				attribute :>> ratedPower {
					attribute :>> num = 1500.0;
					attribute :>> unit = "W";
				}
			}
			
			part inletPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.015;
			}
			
			part outletPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.015;
			}
			
			part flowMeter : FlowMeter {
				attribute :>> accuracy = 0.01;
			}
			
			part temperatureSensor : TemperatureSensor {
				attribute :>> accuracy = 0.5;
			}
			
			part controller : PumpController {
				attribute :>> setpointFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
				attribute :>> pidGainP = 0.5;
				attribute :>> pidGainI = 0.1;
				attribute :>> pidGainD = 0.05;
			}
			
			part inletCheckValve : CheckValve {
				attribute :>> crackingPressure {
					attribute :>> num = 5.0;
					attribute :>> unit = "kPa";
				}
			}
			
			part outletCheckValve : CheckValve {
				attribute :>> crackingPressure {
					attribute :>> num = 10.0;
					attribute :>> unit = "kPa";
				}
			}
			
			part reliefValve : ReliefValve {
				attribute :>> setpointPressure {
					attribute :>> num = 650.0;
					attribute :>> unit = "kPa";
				}
			}
			
			flow of fluid : Fluid
				from systemInlet.fluidIn to inletCheckValve.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from inletCheckValve.outletPort.fluidOut to pump.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from pump.outletPort.fluidOut to outletCheckValve.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from outletCheckValve.outletPort.fluidOut to systemOutlet.fluidOut;
			
			binding inletPressureSensor.measuredPressure = pump.inletPort.inletPressure;
			binding outletPressureSensor.measuredPressure = pump.outletPort.outletPressure;
			binding flowMeter.measuredFlowRate = pump.currentFlowRate;
			binding temperatureSensor.measuredTemperature = pump.operatingTemperature;
			
			binding pump.powerPort = motor.powerInput;
			binding motor.powerInput = mainPower;
			binding controller.controlPower = mainPower;
		}
	}
	
	package Requirements {
		public import Domain::*;
		
		requirement def FlowRateRequirement {
			attribute requiredFlowRate : FlowRate;
			doc /* The pumping subsystem shall deliver fluid at the specified flow rate. */
		}
		
		requirement def PressureRequirement {
			attribute maxOperatingPressure : Pressure;
			doc /* The pumping subsystem shall operate within the maximum pressure limit. */
		}
		
		requirement def EfficiencyRequirement {
			attribute minEfficiency : Real;
			doc /* The pumping subsystem shall maintain minimum efficiency. */
		}
		
		requirement def SafetyRequirement {
			doc /* The pumping subsystem shall include safety features for overpressure and overtemperature protection. */
		}
		
		requirement def ReliabilityRequirement {
			attribute meanTimeBetweenFailures : Real;
			doc /* The pumping subsystem shall achieve specified reliability metrics. */
		}
		
		requirement pumpingSystemRequirements {
			subject pumpingSystem : Definitions::PumpingSubsystem;
			
			require flowRateReq : FlowRateRequirement {
				attribute :>> requiredFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
			}
			
			require pressureReq : PressureRequirement {
				attribute :>> maxOperatingPressure {
					attribute :>> num = 600.0;
					attribute :>> unit = "kPa";
				}
			}
			
			require efficiencyReq : EfficiencyRequirement {
				attribute :>> minEfficiency = 0.80;
			}
			
			require safetyReq : SafetyRequirement;
			
			require reliabilityReq : ReliabilityRequirement {
				attribute :>> meanTimeBetweenFailures = 10000.0;
			}
		}
	}
	
	package Usages {
		public import Definitions::*;
		public import Requirements::*;
		
		part context : PumpingSubsystem {
			part supplyTank : SupplyTank {
				attribute :>> capacity {
					attribute :>> num = 2000.0;
					attribute :>> unit = "L";
				}
				attribute :>> currentLevel {
					attribute :>> num = 1500.0;
					attribute :>> unit = "L";
				}
				attribute :>> minLevel {
					attribute :>> num = 200.0;
					attribute :>> unit = "L";
				}
			}
			
			part receivingVessel : ReceivingVessel {
				attribute :>> capacity {
					attribute :>> num = 1000.0;
					attribute :>> unit = "L";
				}
				attribute :>> currentLevel {
					attribute :>> num = 200.0;
					attribute :>> unit = "L";
				}
				attribute :>> maxLevel {
					attribute :>> num = 950.0;
					attribute :>> unit = "L";
				}
			}
			
			flow of fluid : Fluid
				from supplyTank.outletPort.fluidOut to systemInlet.fluidIn;
			
			flow of fluid : Fluid
				from systemOutlet.fluidOut to receivingVessel.inletPort.fluidIn;
			
			satisfy pumpingSystemRequirements {
				subject pumpingSystem = context;
			}
		}
	}
}
