package 'Hydraulic Power Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def HydraulicFluid {
			attribute pressure : ISQ::Pressure;
			attribute temperature : ISQ::Temperature;
		}
		
		attribute def StartCommand;
		attribute def StopCommand;
		attribute def ResetCommand;
		attribute def OverPressureAlert;
		attribute def OverTemperatureAlert;
		attribute def InitializationComplete;
		attribute def MotorSpeedAdjustment;
		attribute def ControlSignal;
		
		port def HydraulicPort {
			inout item fluid : HydraulicFluid;
		}
		
		port def PressureSignalPort {
			out attribute pressure : ISQ::Pressure;
		}
		
		port def ControlSignalPort {
			inout attribute signal : ControlSignal;
		}
		
		port def MechanicalPort {
			out attribute torque : ISQ::Torque;
			out attribute speed : ISQ::AngularVelocity;
		}
		
		part def Reservoir {
			attribute fluidLevel : ScalarValues::Real;
			port supplyPort : HydraulicPort;
			port returnPort : HydraulicPort;
		}
		
		part def HydraulicPump {
			port inlet : HydraulicPort;
			port outlet : HydraulicPort;
			port shaftIn : ~MechanicalPort;
		}
		
		part def ElectricMotor {
			port controlIn : ~ControlSignalPort;
			port shaftOut : MechanicalPort;
		}
		
		part def PressureSensor {
			port hydraulicIn : ~HydraulicPort;
			port signalOut : PressureSignalPort;
		}
		
		part def PressureReliefValve {
			attribute maxPressure : ISQ::Pressure;
			port inlet : HydraulicPort;
			port outlet : HydraulicPort;
		}
		
		part def Accumulator {
			port fluidPort : HydraulicPort;
		}
		
		part def ControlValve {
			port inlet : HydraulicPort;
			port outlet : HydraulicPort;
			port controlIn : ~ControlSignalPort;
		}
		
		part def SystemController {
			port sensorIn : ~PressureSignalPort;
			port motorControlOut : ControlSignalPort;
			port valveControlOut : ControlSignalPort;
			
			attribute desiredPressure : ISQ::Pressure;
			attribute maxSafePressure : ISQ::Pressure;
			attribute maxTemp : ISQ::Temperature;
			
			exhibit state 'controller states' : 'Controller States';
		}
		
		part def HPU {
			part reservoir : Reservoir;
			part pump : HydraulicPump;
			part motor : ElectricMotor;
			part sensor : PressureSensor;
			part reliefValve : PressureReliefValve;
			part accumulator : Accumulator;
			part controlValve : ControlValve;
			part controller : SystemController;
			
			port hydraulicSupplyOut : HydraulicPort;
			
			exhibit state 'hpu states' : 'HPU States';
		}
		
		state def 'Controller States';
		state def 'HPU States';
		
		action def 'Perform Initialization' {
			out status : ScalarValues::Boolean;
		}
		
		action def 'Monitor Pressure' {
			in currentPressure : ISQ::Pressure;
			out adjustment : MotorSpeedAdjustment;
		}
		
		action def 'Adjust Motor Speed' {
			in adjustment : MotorSpeedAdjustment;
		}
		
		action def 'Emergency Shutdown';
	}
	
	package Usages {
		private import Definitions::*;
		
		action 'perform initialization' : 'Perform Initialization';
		action 'monitor pressure' : 'Monitor Pressure';
		action 'adjust motor speed' : 'Adjust Motor Speed';
		action 'emergency shutdown' : 'Emergency Shutdown';
		
		part hpuSystem : HPU {
			flow of fluid : HydraulicFluid
				from reservoir.supplyPort.fluid to pump.inlet.fluid;
			
			flow of fluid : HydraulicFluid
				from pump.outlet.fluid to reliefValve.inlet.fluid;
			
			flow of fluid : HydraulicFluid
				from reliefValve.inlet.fluid to accumulator.fluidPort.fluid;
			
			flow of fluid : HydraulicFluid
				from accumulator.fluidPort.fluid to controlValve.inlet.fluid;
			
			flow of fluid : HydraulicFluid
				from controlValve.outlet.fluid to hydraulicSupplyOut.fluid;
			
			flow of fluid : HydraulicFluid
				from reliefValve.outlet.fluid to reservoir.returnPort.fluid;
			
			flow of fluid : HydraulicFluid
				from accumulator.fluidPort.fluid to sensor.hydraulicIn.fluid;
			
			flow of pressure : ISQ::Pressure
				from sensor.signalOut.pressure to controller.sensorIn.pressure;
			
			flow of signal : ControlSignal
				from controller.motorControlOut.signal to motor.controlIn.signal;
			
			flow of signal : ControlSignal
				from controller.valveControlOut.signal to controlValve.controlIn.signal;
			
			connect motor.shaftOut to pump.shaftIn;
			
			state 'hpu states' : 'HPU States' {
				entry; then off;
				
				state off;
				accept StartCommand
					if reservoir.fluidLevel > 0
					then initializing;
				
				state initializing {
					entry 'perform initialization';
				}
				accept InitializationComplete
					then operating;
				
				state operating {
					do 'monitor pressure';
					do 'adjust motor speed';
				}
				accept StopCommand
					then off;
				
				accept OverPressureAlert
					then emergencyStop;
				
				accept OverTemperatureAlert
					then emergencyStop;
				
				state emergencyStop {
					entry 'emergency shutdown';
				}
				accept ResetCommand
					then off;
			}
		}
		
		state 'controller states' : 'Controller States' {
			entry; then idle;
			
			state idle;
			accept StartCommand
				then monitoring;
			
			state monitoring {
				do 'monitor pressure';
			}
			accept StopCommand
				then idle;
			
			accept OverPressureAlert
				then fault;
			
			accept OverTemperatureAlert
				then fault;
			
			state fault {
				do 'emergency shutdown';
			}
			accept ResetCommand
				then idle;
		}
		
		requirement def 'Generate Hydraulic Power' {
			doc /* The HPU shall generate and supply high-pressure hydraulic fluid to power external machinery. */
		}
		
		requirement def 'Maintain System Pressure' {
			doc /* The controller shall adjust the motor speed to maintain the desired system pressure. */
		}
		
		requirement def 'Pressure Relief Protection' {
			doc /* The relief valve shall divert excess fluid to the reservoir if pressure exceeds a safe maximum limit. */
		}
		
		requirement def 'Emergency Shutdown' {
			doc /* The controller shall trigger an emergency shutdown in case of over-pressure or over-temperature conditions. */
		}
	}
}
