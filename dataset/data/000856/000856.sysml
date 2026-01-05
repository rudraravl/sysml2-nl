package 'Centrifugal Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def MassPerVolumeValue :> Real;
		attribute def VolumePerTimeValue :> Real;
		
		item def Fluid {
			attribute density : MassPerVolumeValue;
			attribute viscosity : Real;
			attribute temperature : TemperatureValue;
		}
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : VolumePerTimeValue;
			out item fluid : Fluid;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : PowerValue;
		}
		
		port def MechanicalPort {
			attribute torque : TorqueValue;
			attribute rotationalSpeed : AngularVelocityValue;
		}
		
		port def SignalPort {
			out attribute signalValue : Real;
		}
		
		port def ControlPort {
			attribute commandSpeed : AngularVelocityValue;
			attribute commandPower : PowerValue;
		}
		
		part def Motor {
			port powerIn : ~PowerPort;
			port shaftOut : MechanicalPort;
			
			attribute ratedPower : PowerValue;
			attribute efficiency : Real;
			attribute speed : AngularVelocityValue;
		}
		
		part def CentrifugalPump {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port shaftIn : ~MechanicalPort;
			
			attribute impellerDiameter : LengthValue;
			attribute numberOfImpellers : Integer;
			attribute maxFlowRate : VolumePerTimeValue;
			attribute maxPressure : PressureValue;
			attribute pumpEfficiency : Real;
			
			perform action pumpFluid : PumpFluid;
		}
		
		part def PressureSensor {
			port sensing : ~FluidPort;
			port signalOut : SignalPort;
			
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
		}
		
		part def FlowSensor {
			port sensing : ~FluidPort;
			port signalOut : SignalPort;
			
			attribute measuredFlowRate : VolumePerTimeValue;
			attribute accuracy : Real;
		}
		
		part def Controller {
			port pressureSignalIn : ~SignalPort;
			port flowSignalIn : ~SignalPort;
			port controlOut : ControlPort;
			
			attribute targetPressure : PressureValue;
			attribute targetFlowRate : VolumePerTimeValue;
			
			perform action controlPump : ControlPumpAction;
		}
		
		part def Reservoir {
			port fluidOut : FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid;
		}
		
		part def DischargePoint {
			port fluidIn : ~FluidPort;
			
			attribute backPressure : PressureValue;
		}
		
		part def PipingNetwork {
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute roughness : Real;
			attribute pressureDrop : PressureValue;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			in mechanicalPower : PowerValue;
			in inletPressure : PressureValue;
			out fluidOut : Fluid;
			out outletPressure : PressureValue;
			out flowRate : VolumePerTimeValue;
			
			first start;
			then action calculateHead {
				in power = mechanicalPower;
				out pressureIncrease : PressureValue;
			}
			then action accelerateFluid {
				in fluid = fluidIn;
				in deltaP = calculateHead.pressureIncrease;
				out acceleratedFluid : Fluid;
				out resultingFlowRate : VolumePerTimeValue;
			}
			then action dischargeFluid {
				in fluid = accelerateFluid.acceleratedFluid;
				out discharged = fluidOut;
			}
			then done;
		}
		
		action def ControlPumpAction {
			in currentPressure : PressureValue;
			in currentFlowRate : VolumePerTimeValue;
			in setpointPressure : PressureValue;
			in setpointFlowRate : VolumePerTimeValue;
			out commandSpeed : AngularVelocityValue;
			
			first start;
			then action measureError {
				in measured = currentPressure;
				in setpoint = setpointPressure;
				out error : PressureValue;
			}
			then decide;
				if measureError.error > 0.0[SI::Pa] then increaseSpeed;
				if measureError.error < 0.0[SI::Pa] then decreaseSpeed;
				if measureError.error == 0.0[SI::Pa] then maintainSpeed;
			action increaseSpeed {
				out speed = commandSpeed;
			}
			then done;
			action decreaseSpeed {
				out speed = commandSpeed;
			}
			then done;
			action maintainSpeed {
				out speed = commandSpeed;
			}
			then done;
		}
		
		requirement def PumpingSystemRequirements {
			subject pumpingSystem : PumpingSubsystem;
			
			require flowRateRequirement {
				doc /* The system shall deliver a minimum flow rate of 100 liters per minute. */
				assume pumpingSystem.centrifugalPump.maxFlowRate >= 100.0;
			}
			
			require pressureRequirement {
				doc /* The system shall maintain discharge pressure between 2 and 5 bar. */
				assume pumpingSystem.dischargePressureSensor.measuredPressure >= 200000.0[SI::Pa] and
				       pumpingSystem.dischargePressureSensor.measuredPressure <= 500000.0[SI::Pa];
			}
			
			require efficiencyRequirement {
				doc /* The overall system efficiency shall be at least 70%. */
				assume pumpingSystem.centrifugalPump.pumpEfficiency >= 0.70 and
				       pumpingSystem.driveMotor.efficiency >= 0.85;
			}
			
			require reliabilityRequirement {
				doc /* The pump shall operate continuously for at least 10000 hours. */
			}
		}
		
		part def PumpingSubsystem {
			part sourceReservoir : Reservoir;
			part suctionPiping : PipingNetwork;
			part centrifugalPump : CentrifugalPump;
			part driveMotor : Motor;
			part dischargePiping : PipingNetwork;
			part dischargePressureSensor : PressureSensor;
			part flowMeter : FlowSensor;
			part systemController : Controller;
			part dischargePoint : DischargePoint;
		}
	}
	
	package Usages {
		part pumpingSubsystem : PumpingSubsystem {
			
			part :>> sourceReservoir {
				attribute :>> capacity = 1.0[SI::m^3];
				attribute :>> currentLevel = 0.8[SI::m^3];
				item :>> storedFluid : Fluid {
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 293.15[SI::K];
				}
			}
			
			part :>> suctionPiping {
				attribute :>> length = 5.0[SI::m];
				attribute :>> diameter = 0.1[SI::m];
				attribute :>> roughness = 0.0001;
				attribute :>> pressureDrop = 10000.0[SI::Pa];
			}
			
			flow of fluid : Fluid
				from sourceReservoir.fluidOut.fluid to suctionPiping.inlet.fluid;
			
			part :>> centrifugalPump {
				attribute :>> impellerDiameter = 0.25[SI::m];
				attribute :>> numberOfImpellers = 1;
				attribute :>> maxFlowRate = 0.0025;
				attribute :>> maxPressure = 600000.0[SI::Pa];
				attribute :>> pumpEfficiency = 0.75;
			}
			
			flow of fluid : Fluid
				from suctionPiping.outlet.fluid to centrifugalPump.fluidIn.fluid;
			
			part :>> driveMotor {
				attribute :>> ratedPower = 5500.0[SI::W];
				attribute :>> efficiency = 0.88;
				attribute :>> speed = 151.84[SI::rad/SI::s];
			}
			
			connect driveMotor.shaftOut to centrifugalPump.shaftIn;
			
			part :>> dischargePiping {
				attribute :>> length = 10.0[SI::m];
				attribute :>> diameter = 0.08[SI::m];
				attribute :>> roughness = 0.0001;
				attribute :>> pressureDrop = 20000.0[SI::Pa];
			}
			
			flow of fluid : Fluid
				from centrifugalPump.fluidOut.fluid to dischargePiping.inlet.fluid;
			
			part :>> dischargePressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			bind dischargePressureSensor.sensing.pressure = dischargePiping.outlet.pressure;
			bind dischargePressureSensor.sensing.flowRate = dischargePiping.outlet.flowRate;
			
			part :>> flowMeter {
				attribute :>> accuracy = 0.02;
			}
			
			bind flowMeter.sensing.flowRate = dischargePiping.outlet.flowRate;
			
			part :>> systemController {
				attribute :>> targetPressure = 350000.0[SI::Pa];
				attribute :>> targetFlowRate = 0.002;
			}
			
			connect dischargePressureSensor.signalOut to systemController.pressureSignalIn;
			connect flowMeter.signalOut to systemController.flowSignalIn;
			
			part :>> dischargePoint {
				attribute :>> backPressure = 100000.0[SI::Pa];
			}
			
			flow of fluid : Fluid
				from dischargePiping.outlet.fluid to dischargePoint.fluidIn.fluid;
			
			satisfy pumpingRequirements : PumpingSystemRequirements {
				subject pumpingSystem = pumpingSubsystem;
			}
		}
	}
}
