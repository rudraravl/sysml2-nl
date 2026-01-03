package PumpingSubsystemWithPAT {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		attribute def FlowRate :> ISQ::volumeFlowRate {
			attribute :>> num : Real;
			attribute :>> mRef : VolumeUnit = SI::m^3 / SI::s;
		}
		
		attribute def Pressure :> ISQ::pressure {
			attribute :>> num : Real;
			attribute :>> mRef : PressureUnit = SI::Pa;
		}
		
		attribute def RotationalSpeed :> ISQ::angularVelocity {
			attribute :>> num : Real;
			attribute :>> mRef : AngularVelocityUnit = SI::rad / SI::s;
		}
		
		attribute def Power :> ISQ::power {
			attribute :>> num : Real;
			attribute :>> mRef : PowerUnit = SI::W;
		}
		
		attribute def Torque :> ISQ::torque {
			attribute :>> num : Real;
			attribute :>> mRef : TorqueUnit = SI::N * SI::m;
		}
		
		attribute def Volume :> ISQ::volume {
			attribute :>> num : Real;
			attribute :>> mRef : VolumeUnit = SI::m^3;
		}
		
		port def FluidPort {
			in attribute pressure : Pressure;
			in attribute flowRate : FlowRate;
			inout item fluid : Fluid;
		}
		
		port def MechanicalPort {
			out attribute torque : Torque;
			out attribute rotationalSpeed : RotationalSpeed;
			out attribute power : Power;
		}
		
		part def PumpAsTurbine {
			doc /* A pump operating in reverse mode as a turbine to generate mechanical power */
			
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			port mechanicalOutPort : MechanicalPort;
			
			attribute inletPressure : Pressure;
			attribute outletPressure : Pressure;
			attribute pressureDrop : Pressure;
			attribute flowRate : FlowRate;
			attribute efficiency : Real;
			attribute outputPower : Power;
			attribute outputTorque : Torque;
			attribute rotationalSpeed : RotationalSpeed;
			
			assert constraint pressureDropConstraint {
				pressureDrop.num == inletPressure.num - outletPressure.num
			}
			
			assert constraint powerGeneration {
				outputPower.num == flowRate.num * pressureDrop.num * efficiency
			}
			
			perform action generatePower {
				in fluidIn : Fluid = fluidInPort.fluid;
				in inPressure : Pressure = fluidInPort.pressure;
				in inFlow : FlowRate = fluidInPort.flowRate;
				out mechanicalPower : Power = mechanicalOutPort.power;
				out mechanicalTorque : Torque = mechanicalOutPort.torque;
				out fluidOut : Fluid = fluidOutPort.fluid;
			}
			
			exhibit state turbineStates {
				entry; then idle;
				
				state idle;
				
				state starting;
				
				state operating {
					state normalOperation;
					state highFlowOperation;
					state lowFlowOperation;
				}
				
				state stopping;
				
				state stopped;
				
				transition idle_to_starting
					first idle
					accept StartTurbineCommand
					then starting;
				
				transition starting_to_operating
					first starting
					if rotationalSpeed.num >= 100.0
					then operating;
				
				transition operating_to_stopping
					first operating
					accept StopTurbineCommand
					then stopping;
				
				transition stopping_to_stopped
					first stopping
					if rotationalSpeed.num <= 10.0
					then stopped;
				
				transition stopped_to_idle
					first stopped
					accept ResetCommand
					then idle;
				
				transition normalToHigh
					first operating.normalOperation
					if flowRate.num > 120.0
					then operating.highFlowOperation;
				
				transition normalToLow
					first operating.normalOperation
					if flowRate.num < 60.0
					then operating.lowFlowOperation;
				
				transition highToNormal
					first operating.highFlowOperation
					if flowRate.num <= 120.0
					then operating.normalOperation;
				
				transition lowToNormal
					first operating.lowFlowOperation
					if flowRate.num >= 60.0
					then operating.normalOperation;
			}
		}
		
		part def Pump {
			doc /* A conventional pump that moves fluid from low to high pressure */
			
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			port mechanicalInPort : ~MechanicalPort;
			
			attribute inletPressure : Pressure;
			attribute outletPressure : Pressure;
			attribute pressureRise : Pressure;
			attribute flowRate : FlowRate;
			attribute efficiency : Real;
			attribute requiredPower : Power;
			attribute requiredTorque : Torque;
			attribute rotationalSpeed : RotationalSpeed;
			
			assert constraint pressureRiseConstraint {
				pressureRise.num == outletPressure.num - inletPressure.num
			}
			
			assert constraint powerRequirement {
				requiredPower.num == flowRate.num * pressureRise.num / efficiency
			}
			
			perform action pumpFluid {
				in fluidIn : Fluid = fluidInPort.fluid;
				in mechanicalPower : Power = mechanicalInPort.power;
				in mechanicalTorque : Torque = mechanicalInPort.torque;
				out fluidOut : Fluid = fluidOutPort.fluid;
				out outPressure : Pressure = fluidOutPort.pressure;
				out outFlow : FlowRate = fluidOutPort.flowRate;
			}
			
			exhibit state pumpStates {
				entry; then idle;
				
				state idle;
				state starting;
				state operating {
					state normalOperation;
					state highFlowOperation;
					state lowFlowOperation;
				}
				state stopping;
				state stopped;
				
				transition idle_to_starting
					first idle
					accept StartPumpCommand
					then starting;
				
				transition starting_to_operating
					first starting
					if rotationalSpeed.num >= 100.0
					then operating;
				
				transition operating_to_stopping
					first operating
					accept StopPumpCommand
					then stopping;
				
				transition stopping_to_stopped
					first stopping
					if rotationalSpeed.num <= 10.0
					then stopped;
				
				transition stopped_to_idle
					first stopped
					accept ResetCommand
					then idle;
				
				transition normalToHigh
					first operating.normalOperation
					if flowRate.num > 150.0
					then operating.highFlowOperation;
				
				transition normalToLow
					first operating.normalOperation
					if flowRate.num < 50.0
					then operating.lowFlowOperation;
				
				transition highToNormal
					first operating.highFlowOperation
					if flowRate.num <= 150.0
					then operating.normalOperation;
				
				transition lowToNormal
					first operating.lowFlowOperation
					if flowRate.num >= 50.0
					then operating.normalOperation;
			}
		}
		
		part def MechanicalCoupling {
			doc /* Mechanical coupling between turbine and pump */
			
			port inputPort : ~MechanicalPort;
			port outputPort : MechanicalPort;
			
			attribute transmissionEfficiency : Real;
			attribute inputTorque : Torque;
			attribute outputTorque : Torque;
			attribute inputSpeed : RotationalSpeed;
			attribute outputSpeed : RotationalSpeed;
			
			assert constraint torqueTransmission {
				outputTorque.num == inputTorque.num * transmissionEfficiency
			}
			
			assert constraint speedTransmission {
				outputSpeed.num == inputSpeed.num
			}
		}
		
		part def FluidReservoir {
			doc /* Storage tank for fluid */
			
			port fluidOutPort : FluidPort;
			port fluidInPort : ~FluidPort;
			
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute outputPressure : Pressure;
			item storedFluid : Fluid;
			
			assert constraint levelConstraint {
				currentLevel.num <= capacity.num
			}
			
			assert constraint levelPositive {
				currentLevel.num >= 0.0
			}
		}
		
		part def DischargePoint {
			doc /* Final destination for pumped fluid */
			
			port fluidInPort : FluidPort;
			
			attribute requiredPressure : Pressure;
			attribute requiredFlowRate : FlowRate;
			item receivedFluid : Fluid;
		}
		
		part def PressureSensor {
			port measurementPort : ~FluidPort;
			attribute measuredPressure : Pressure;
		}
		
		part def FlowSensor {
			port measurementPort : ~FluidPort;
			attribute measuredFlowRate : FlowRate;
		}
		
		part def Controller {
			attribute targetFlowRate : FlowRate;
			attribute targetPressure : Pressure;
			attribute actualFlowRate : FlowRate;
			attribute actualPressure : Pressure;
			
			perform action controlSystem {
				in targetFlow : FlowRate;
				in targetPress : Pressure;
				in actualFlow : FlowRate;
				in actualPress : Pressure;
				out controlSignal : Real;
			}
		}
		
		requirement def PumpingSystemRequirements {
			doc /* Requirements for the pumping subsystem with PAT */
			
			requirement flowRateRequirement {
				doc /* The system shall maintain flow rate within specified range */
				subject pumpingSystem : PumpingSubsystem;
				require constraint {
					pumpingSystem.actualFlowRate.num >= 80.0 and
					pumpingSystem.actualFlowRate.num <= 200.0
				}
			}
			
			requirement pressureRequirement {
				doc /* The system shall deliver fluid at required pressure */
				subject pumpingSystem : PumpingSubsystem;
				require constraint {
					pumpingSystem.dischargePressure.num >= 500000.0
				}
			}
			
			requirement efficiencyRequirement {
				doc /* The system shall operate at minimum efficiency */
				subject pumpingSystem : PumpingSubsystem;
				require constraint {
					pumpingSystem.systemEfficiency >= 0.60
				}
			}
			
			requirement energyRecoveryRequirement {
				doc /* The turbine shall recover energy from high-pressure fluid */
				subject turbine : PumpAsTurbine;
				require constraint {
					turbine.outputPower.num >= 40000.0
				}
			}
		}
		
		part def PumpingSubsystem {
			doc /* Complete pumping subsystem using pump-as-turbine for energy recovery */
			
			attribute actualFlowRate : FlowRate;
			attribute dischargePressure : Pressure;
			attribute systemEfficiency : Real;
			attribute netPowerConsumption : Power;
			
			part turbine : PumpAsTurbine[1];
			part pump : Pump[1];
			part coupling : MechanicalCoupling[1];
			part highPressureReservoir : FluidReservoir[1];
			part lowPressureReservoir : FluidReservoir[1];
			part dischargePoint : DischargePoint[1];
			part pressureSensorTurbineIn : PressureSensor[1];
			part pressureSensorPumpOut : PressureSensor[1];
			part flowSensorPump : FlowSensor[1];
			part flowSensorTurbine : FlowSensor[1];
			part systemController : Controller[1];
			
			connection turbineFluidSupply
				connect highPressureReservoir.fluidOutPort to turbine.fluidInPort;
			
			connection turbineToLowReservoir
				connect turbine.fluidOutPort to lowPressureReservoir.fluidInPort;
			
			connection pumpFluidSupply
				connect lowPressureReservoir.fluidOutPort to pump.fluidInPort;
			
			connection pumpDischarge
				connect pump.fluidOutPort to dischargePoint.fluidInPort;
			
			connection turbineMechanicalOutput
				connect turbine.mechanicalOutPort to coupling.inputPort;
			
			connection couplingToPump
				connect coupling.outputPort to pump.mechanicalInPort;
			
			connection pressureSensingTurbine
				connect pressureSensorTurbineIn.measurementPort to turbine.fluidInPort;
			
			connection pressureSensingPump
				connect pressureSensorPumpOut.measurementPort to pump.fluidOutPort;
			
			connection flowSensingPump
				connect flowSensorPump.measurementPort to pump.fluidOutPort;
			
			connection flowSensingTurbine
				connect flowSensorTurbine.measurementPort to turbine.fluidOutPort;
			
			flow of fluid : Fluid
				from highPressureReservoir.fluidOutPort.fluid to turbine.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from turbine.fluidOutPort.fluid to lowPressureReservoir.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from lowPressureReservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
			
			flow of fluid : Fluid
				from pump.fluidOutPort.fluid to dischargePoint.fluidInPort.fluid;
			
			assert constraint systemEfficiencyCalculation {
				systemEfficiency == (pump.efficiency * turbine.efficiency * coupling.transmissionEfficiency)
			}
			
			assert constraint flowBalance {
				actualFlowRate.num == pump.flowRate.num
			}
			
			assert constraint pressureDelivery {
				dischargePressure.num == pump.outletPressure.num
			}
			
			assert constraint netPowerCalculation {
				netPowerConsumption.num == pump.requiredPower.num - turbine.outputPower.num
			}
		}
		
		action def StartTurbineCommand;
		action def StopTurbineCommand;
		action def StartPumpCommand;
		action def StopPumpCommand;
		action def ResetCommand;
	}
	
	package Usages {
		part pumpingSystemInstance : Definitions::PumpingSubsystem {
			part :>> turbine {
				attribute :>> inletPressure : Pressure = 900000.0 [SI::Pa];
				attribute :>> outletPressure : Pressure = 150000.0 [SI::Pa];
				attribute :>> pressureDrop : Pressure = 750000.0 [SI::Pa];
				attribute :>> efficiency = 0.80;
				attribute :>> flowRate : FlowRate = 0.08 [SI::m^3/SI::s];
				attribute :>> outputPower : Power = 48000.0 [SI::W];
				attribute :>> rotationalSpeed : RotationalSpeed = 157.08 [SI::rad/SI::s];
				attribute :>> outputTorque : Torque = 305.5 [SI::N*SI::m];
			}
			
			part :>> pump {
				attribute :>> inletPressure : Pressure = 100000.0 [SI::Pa];
				attribute :>> outletPressure : Pressure = 650000.0 [SI::Pa];
				attribute :>> pressureRise : Pressure = 550000.0 [SI::Pa];
				attribute :>> efficiency = 0.75;
				attribute :>> flowRate : FlowRate = 0.08 [SI::m^3/SI::s];
				attribute :>> requiredPower : Power = 58666.67 [SI::W];
				attribute :>> rotationalSpeed : RotationalSpeed = 157.08 [SI::rad/SI::s];
				attribute :>> requiredTorque : Torque = 373.5 [SI::N*SI::m];
			}
			
			part :>> coupling {
				attribute :>> transmissionEfficiency = 0.95;
				attribute :>> inputTorque : Torque = 305.5 [SI::N*SI::m];
				attribute :>> outputTorque : Torque = 290.2 [SI::N*SI::m];
				attribute :>> inputSpeed : RotationalSpeed = 157.08 [SI::rad/SI::s];
				attribute :>> outputSpeed : RotationalSpeed = 157.08 [SI::rad/SI::s];
			}
			
			part :>> highPressureReservoir {
				attribute :>> capacity : Volume = 100.0 [SI::m^3];
				attribute :>> currentLevel : Volume = 75.0 [SI::m^3];
				attribute :>> outputPressure : Pressure = 900000.0 [SI::Pa];
				item :>> storedFluid : Definitions::Fluid {
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 293.15;
				}
			}
			
			part :>> lowPressureReservoir {
				attribute :>> capacity : Volume = 80.0 [SI::m^3];
				attribute :>> currentLevel : Volume = 40.0 [SI::m^3];
				attribute :>> outputPressure : Pressure = 100000.0 [SI::Pa];
				item :>> storedFluid : Definitions::Fluid {
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 293.15;
				}
			}
			
			part :>> dischargePoint {
				attribute :>> requiredPressure : Pressure = 600000.0 [SI::Pa];
				attribute :>> requiredFlowRate : FlowRate = 0.08 [SI::m^3/SI::s];
			}
			
			part :>> systemController {
				attribute :>> targetFlowRate : FlowRate = 0.08 [SI::m^3/SI::s];
				attribute :>> targetPressure : Pressure = 650000.0 [SI::Pa];
			}
			
			attribute :>> actualFlowRate : FlowRate = 0.08 [SI::m^3/SI::s];
			attribute :>> dischargePressure : Pressure = 650000.0 [SI::Pa];
			attribute :>> systemEfficiency = 0.57;
			attribute :>> netPowerConsumption : Power = 10666.67 [SI::W];
		}
		
		requirement pumpingSystemReqs : Definitions::PumpingSystemRequirements {
			subject systemUnderTest = pumpingSystemInstance;
		}
		
		action operatePumpingSystem {
			first startTurbine;
			
			action startTurbine {
				out turbineStart : Definitions::StartTurbineCommand;
			}
			then startPump;
			
			action startPump {
				out pumpStart : Definitions::StartPumpCommand;
			}
			then monitorOperation;
			
			action monitorOperation {
				in flowRate : FlowRate = pumpingSystemInstance.actualFlowRate;
				in pressure : Pressure = pumpingSystemInstance.dischargePressure;
				in netPower : Power = pumpingSystemInstance.netPowerConsumption;
				loop;
			}
			then shutdown;
			
			action shutdown {
				out pumpStop : Definitions::StopPumpCommand;
				out turbineStop : Definitions::StopTurbineCommand;
			}
		}
	}
}
