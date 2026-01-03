package 'Impedance Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def Pressure :> Real;
		
		attribute def FlowRate :> Real;
		
		attribute def Frequency :> Real;
		
		attribute def Voltage :> Real;
		
		attribute def Temperature :> Real;
		
		attribute def Volume :> Real;
		
		item def Fluid {
			attribute viscosity : Real;
			attribute density : Real;
			attribute temperature : Temperature;
		}
		
		port def FluidPort {
			attribute pressure : Pressure;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		port def PowerPort {
			in attribute voltage : Voltage;
			in attribute frequency : Frequency;
		}
		
		signal StartCommand;
		signal PrimingComplete;
		signal FlowDeviation;
		signal FlowRestored;
		signal StopCommand;
		signal EmergencyStop;
		signal Reset;
		
		part def PiezoelectricActuator {
			attribute operatingVoltage : Voltage;
			attribute operatingFrequency : Frequency;
			attribute displacement : Real;
			
			port powerPort : PowerPort;
		}
		
		part def FlexibleMembrane {
			attribute thickness : Real;
			attribute elasticModulus : Real;
			attribute maxDeflection : Real;
		}
		
		part def CheckValve {
			attribute crackingPressure : Pressure;
			attribute maxFlowRate : FlowRate;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
		}
		
		part def PumpChamber {
			attribute volume : Volume;
			attribute maxPressure : Pressure;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
		}
		
		part def ImpedancePump {
			attribute nominalFlowRate : FlowRate;
			attribute maxPressure : Pressure;
			attribute operatingFrequency : Frequency;
			
			port fluidInlet : ~FluidPort;
			port fluidOutlet : FluidPort;
			port powerInput : PowerPort;
			
			part actuator : PiezoelectricActuator {
				attribute :>> operatingVoltage = 120.0;
				attribute :>> operatingFrequency = 50.0;
			}
			
			part membrane : FlexibleMembrane {
				attribute :>> thickness = 0.001;
				attribute :>> maxDeflection = 0.005;
			}
			
			part chamber : PumpChamber {
				attribute :>> volume = 0.0001;
				attribute :>> maxPressure = 500000.0;
			}
			
			part inletValve : CheckValve {
				attribute :>> crackingPressure = 1000.0;
			}
			
			part outletValve : CheckValve {
				attribute :>> crackingPressure = 2000.0;
			}
			
			bind powerInput.voltage = actuator.powerPort.voltage;
			bind powerInput.frequency = actuator.powerPort.frequency;
			
			flow from fluidInlet.fluidOut to inletValve.inletPort.fluidIn;
			flow from inletValve.outletPort.fluidOut to chamber.inletPort.fluidIn;
			flow from chamber.outletPort.fluidOut to outletValve.inletPort.fluidIn;
			flow from outletValve.outletPort.fluidOut to fluidOutlet.fluidIn;
		}
		
		part def FluidReservoir {
			attribute capacity : Volume;
			attribute currentLevel : Real;
			
			port outletPort : FluidPort;
			
			item storedFluid : Fluid {
				attribute :>> viscosity = 0.001;
				attribute :>> density = 1000.0;
				attribute :>> temperature = 293.15;
			}
		}
		
		part def FluidReceiver {
			attribute capacity : Volume;
			attribute currentLevel : Real;
			
			port inletPort : ~FluidPort;
			
			item receivedFluid : Fluid;
		}
		
		part def PressureSensor {
			port sensingPort : ~FluidPort;
			out attribute measuredPressure : Pressure;
		}
		
		part def FlowSensor {
			port sensingPort : ~FluidPort;
			out attribute measuredFlowRate : FlowRate;
		}
		
		part def Controller {
			in attribute targetFlowRate : FlowRate;
			in attribute currentFlowRate : FlowRate;
			in attribute currentPressure : Pressure;
			
			out attribute commandVoltage : Voltage;
			out attribute commandFrequency : Frequency;
		}
		
		action def MonitorPressure {
			in attribute sensorReading : Pressure;
			out attribute pressureStatus : Boolean;
		}
		
		action def MonitorFlowRate {
			in attribute sensorReading : FlowRate;
			out attribute flowStatus : Boolean;
		}
		
		action def AdjustPumpOperation {
			in attribute currentFlow : FlowRate;
			in attribute targetFlow : FlowRate;
			out attribute newVoltage : Voltage;
			out attribute newFrequency : Frequency;
		}
		
		action def PumpingCycle {
			first start;
			then merge continuePumping;
			
			then action monitorFlow : MonitorFlowRate {
				in flowReading : FlowRate;
				out flowOk : Boolean;
			}
			
			then action monitorPressure : MonitorPressure {
				in pressureReading : Pressure;
				out pressureOk : Boolean;
			}
			
			then decide;
				if monitorFlow.flowOk & monitorPressure.pressureOk then maintainOperation;
				if !monitorFlow.flowOk | !monitorPressure.pressureOk then adjustOperation;
			
			action maintainOperation;
			then continuePumping;
			
			action adjustOperation : AdjustPumpOperation {
				in currentFlow = monitorFlow.flowReading;
				in targetFlow : FlowRate;
				out newVoltage : Voltage;
				out newFrequency : Frequency;
			}
			then continuePumping;
		}
		
		state def PumpOperatingStates {
			entry; then idle;
			
			state idle;
			accept StartCommand then priming;
			
			state priming;
			accept PrimingComplete then running;
			
			state running {
				state normalOperation;
				accept FlowDeviation then adjusting;
				
				state adjusting;
				accept FlowRestored then normalOperation;
			}
			accept StopCommand then shutdown;
			accept EmergencyStop then emergency;
			
			state shutdown;
			then idle;
			
			state emergency;
			accept Reset then idle;
		}
		
		requirement def PumpPerformanceRequirement {
			subject pump : ImpedancePump;
			
			require constraint {
				pump.nominalFlowRate >= 0.001
			}
			
			require constraint {
				pump.maxPressure >= 100000.0
			}
		}
		
		requirement def FluidCompatibilityRequirement {
			subject fluid : Fluid;
			
			require constraint {
				fluid.viscosity >= 0.0001 & fluid.viscosity <= 0.1
			}
			
			require constraint {
				fluid.temperature >= 273.15 & fluid.temperature <= 373.15
			}
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			part sourceReservoir : Definitions::FluidReservoir {
				attribute :>> capacity = 0.1;
				attribute :>> currentLevel = 0.08;
			}
			
			part impedancePump : Definitions::ImpedancePump {
				attribute :>> nominalFlowRate = 0.001;
				attribute :>> maxPressure = 500000.0;
				attribute :>> operatingFrequency = 50.0;
				
				perform action pumpingOperation : Definitions::PumpingCycle;
				
				exhibit state operatingState : Definitions::PumpOperatingStates;
			}
			
			part destinationReceiver : Definitions::FluidReceiver {
				attribute :>> capacity = 0.05;
				attribute :>> currentLevel = 0.0;
			}
			
			part pressureSensor : Definitions::PressureSensor;
			
			part flowSensor : Definitions::FlowSensor;
			
			part systemController : Definitions::Controller {
				in attribute :>> targetFlowRate = 0.001;
			}
			
			flow of fluid : Definitions::Fluid
				from sourceReservoir.outletPort.fluidOut 
				to impedancePump.fluidInlet.fluidIn;
			
			flow of fluid : Definitions::Fluid
				from impedancePump.fluidOutlet.fluidOut 
				to destinationReceiver.inletPort.fluidIn;
			
			bind pressureSensor.sensingPort.fluidOut = impedancePump.fluidOutlet.fluidOut;
			bind flowSensor.sensingPort.fluidOut = impedancePump.fluidOutlet.fluidOut;
			
			bind systemController.currentPressure = pressureSensor.measuredPressure;
			bind systemController.currentFlowRate = flowSensor.measuredFlowRate;
			
			bind systemController.commandVoltage = impedancePump.powerInput.voltage;
			bind systemController.commandFrequency = impedancePump.powerInput.frequency;
			
			requirement pumpPerformanceReq : Definitions::PumpPerformanceRequirement {
				subject pump = impedancePump;
			}
			
			requirement fluidCompatibilityReq : Definitions::FluidCompatibilityRequirement {
				subject fluid = sourceReservoir.storedFluid;
			}
			
			satisfy pumpPerformanceReq;
			satisfy fluidCompatibilityReq;
		}
	}
}
