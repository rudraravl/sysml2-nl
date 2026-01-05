package 'Turbine Power Generation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package 'Port Definitions' {
		port def FluidInletPort {
			in attribute pressure : ISQ::PressureValue;
			in attribute temperature : ISQ::ThermodynamicTemperatureValue;
			in attribute massFlow : ISQ::MassFlowRateValue;
		}
		
		port def FluidOutletPort {
			out attribute pressure : ISQ::PressureValue;
			out attribute temperature : ISQ::ThermodynamicTemperatureValue;
			out attribute massFlow : ISQ::MassFlowRateValue;
		}
		
		port def MechanicalShaftPort {
			out attribute torque : ISQ::TorqueValue;
			out attribute speed : ISQ::AngularVelocityValue;
		}
		
		port def ElectricalOutputPort {
			out attribute voltage : ISQ::ElectricPotentialValue;
			out attribute power : ISQ::PowerValue;
		}
	}
	
	package 'Component Definitions' {
		private import 'Port Definitions'::*;
		
		part def TurbineRotor {
			attribute bladeCount : Integer;
			attribute diameter : ISQ::LengthValue;
			attribute mass : ISQ::MassValue;
			attribute currentSpeed : ISQ::AngularVelocityValue;
			attribute currentTorque : ISQ::TorqueValue;
		}
		
		part def TurbineStator {
			attribute nozzleCount : Integer;
			attribute efficiency : Real;
		}
		
		part def TurbineShaft {
			attribute diameter : ISQ::LengthValue;
			attribute length : ISQ::LengthValue;
			attribute maxTorque : ISQ::TorqueValue;
		}
		
		part def Turbine {
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			port mechanicalOutput : MechanicalShaftPort;
			
			part rotor : TurbineRotor {
				attribute :>> bladeCount = 36;
				attribute :>> diameter = 2.0 [m];
				attribute :>> mass = 800.0 [kg];
			}
			
			part stator : TurbineStator {
				attribute :>> nozzleCount = 18;
				attribute :>> efficiency = 0.88;
			}
			
			part shaft : TurbineShaft {
				attribute :>> diameter = 0.3 [m];
				attribute :>> length = 3.0 [m];
			}
		}
		
		part def Generator {
			port mechanicalInput : MechanicalShaftPort {
				in attribute torque : ISQ::TorqueValue;
				in attribute speed : ISQ::AngularVelocityValue;
			}
			port electricalOutput : ElectricalOutputPort;
			
			attribute efficiency : Real = 0.95;
			attribute ratedPower : ISQ::PowerValue;
			attribute ratedVoltage : ISQ::ElectricPotentialValue;
		}
		
		part def Condenser {
			port steamInlet : FluidInletPort;
			port condensateOutlet : FluidOutletPort;
			
			attribute coolingCapacity : ISQ::PowerValue;
			attribute vacuumPressure : ISQ::PressureValue;
		}
	}
	
	package 'Behavior Definitions' {
		action def ExpandFluid {
			in inletPressure : ISQ::PressureValue;
			in inletTemperature : ISQ::ThermodynamicTemperatureValue;
			in massFlow : ISQ::MassFlowRateValue;
			out outletPressure : ISQ::PressureValue;
			out outletTemperature : ISQ::ThermodynamicTemperatureValue;
			out shaftTorque : ISQ::TorqueValue;
			out shaftSpeed : ISQ::AngularVelocityValue;
		}
		
		action def ConvertMechanicalToElectrical {
			in inputTorque : ISQ::TorqueValue;
			in inputSpeed : ISQ::AngularVelocityValue;
			out outputVoltage : ISQ::ElectricPotentialValue;
			out outputPower : ISQ::PowerValue;
		}
		
		action def CondenseSteam {
			in exhaustPressure : ISQ::PressureValue;
			in exhaustTemperature : ISQ::ThermodynamicTemperatureValue;
			in exhaustMassFlow : ISQ::MassFlowRateValue;
			out condensatePressure : ISQ::PressureValue;
			out condensateTemperature : ISQ::ThermodynamicTemperatureValue;
		}
		
		action def GenerateElectricalPower {
			in steamPressure : ISQ::PressureValue;
			in steamTemperature : ISQ::ThermodynamicTemperatureValue;
			in steamMassFlow : ISQ::MassFlowRateValue;
			out electricalPower : ISQ::PowerValue;
			out electricalVoltage : ISQ::ElectricPotentialValue;
			
			first start;
			
			then action expandSteam : ExpandFluid {
				in inletPressure = steamPressure;
				in inletTemperature = steamTemperature;
				in massFlow = steamMassFlow;
				out outletPressure;
				out outletTemperature;
				out shaftTorque;
				out shaftSpeed;
			}
			
			flow expandSteam.shaftTorque to convertPower.inputTorque;
			flow expandSteam.shaftSpeed to convertPower.inputSpeed;
			
			then action convertPower : ConvertMechanicalToElectrical {
				in inputTorque;
				in inputSpeed;
				out outputVoltage;
				out outputPower;
			}
			
			flow convertPower.outputVoltage to electricalVoltage;
			flow convertPower.outputPower to electricalPower;
			
			then action condensateExhaust : CondenseSteam {
				in exhaustPressure = expandSteam.outletPressure;
				in exhaustTemperature = expandSteam.outletTemperature;
				in exhaustMassFlow = steamMassFlow;
				out condensatePressure;
				out condensateTemperature;
			}
			
			then done;
		}
	}
	
	package 'System Assembly' {
		private import 'Component Definitions'::*;
		private import 'Behavior Definitions'::*;
		private import 'Port Definitions'::*;
		
		part def TurbineGeneratorSystem {
			doc /* A turbine-based power generation system that converts high-pressure steam 
			       into electrical energy through mechanical rotation. */
			
			port steamSupply : FluidInletPort;
			port powerOutput : ElectricalOutputPort;
			port condensateReturn : FluidOutletPort;
			
			attribute totalPowerOutput : ISQ::PowerValue;
			attribute systemEfficiency : Real;
			
			part turbine : Turbine;
			part generator : Generator {
				attribute :>> ratedPower = 500.0 [MW];
				attribute :>> ratedVoltage = 22000.0 [V];
			}
			part condenser : Condenser {
				attribute :>> coolingCapacity = 600.0 [MW];
			}
			
			connect steamSupply to turbine.fluidInlet;
			connect turbine.mechanicalOutput to generator.mechanicalInput;
			connect turbine.fluidOutlet to condenser.steamInlet;
			connect condenser.condensateOutlet to condensateReturn;
			connect generator.electricalOutput to powerOutput;
			
			perform action generatePower : GenerateElectricalPower {
				in steamPressure = steamSupply.pressure;
				in steamTemperature = steamSupply.temperature;
				in steamMassFlow = steamSupply.massFlow;
				out electricalPower;
				out electricalVoltage;
			}
			
			bind totalPowerOutput = generatePower.electricalPower;
			bind powerOutput.voltage = generatePower.electricalVoltage;
		}
		
		part turbineSystem : TurbineGeneratorSystem;
	}
	
	package 'Requirements' {
		private import ModelingMetadata::*;
		private import RiskMetadata::*;
		private import RiskLevelEnum::*;
		private import 'System Assembly'::TurbineGeneratorSystem;
		
		requirement def SystemGoal {
			doc /* High-level functional goal for the turbine power generation system. */
		}
		
		requirement def PerformanceRequirement;
		requirement def EfficiencyRequirement;
		requirement def SafetyRequirement;
		
		requirement <'R-001'> primaryFunctionReq : SystemGoal {
			doc /* The turbine generator system shall convert thermal energy from high-pressure 
			       steam into electrical energy for distribution to the power grid. */
		}
		
		requirement <'R-002'> powerOutputRequirement : PerformanceRequirement {
			subject system : TurbineGeneratorSystem;
			doc /* The system shall generate a minimum continuous electrical output of 500 MW 
			       under rated operating conditions. */
			require constraint {
				system.totalPowerOutput >= 500.0 [MW]
			}
			@StatusInfo {
				status = StatusKind::open;
				risk {
					totalRisk = medium;
					technicalRisk = low;
					scheduleRisk = low;
					costRisk = medium;
				}
				owner = "Chief Engineer";
			}
		}
		
		requirement <'R-003'> efficiencyRequirement : EfficiencyRequirement {
			subject system : TurbineGeneratorSystem;
			doc /* The overall system efficiency shall be at least 85% to ensure economical 
			       operation and fuel utilization. */
			require constraint {
				system.systemEfficiency >= 0.85
			}
			@StatusInfo {
				status = StatusKind::open;
				risk {
					totalRisk = high;
					technicalRisk = high;
					scheduleRisk = medium;
					costRisk = high;
				}
				owner = "Performance Team Lead";
			}
		}
		
		requirement <'R-004'> turbineSpeedLimit : SafetyRequirement {
			subject system : TurbineGeneratorSystem;
			doc /* The turbine rotational speed shall not exceed 3600 RPM (377 rad/s) to prevent 
			       mechanical failure and ensure safe operation. */
			require constraint {
				system.turbine.rotor.currentSpeed <= 377.0
			}
			@StatusInfo {
				status = StatusKind::open;
				risk {
					totalRisk = high;
					technicalRisk = medium;
					scheduleRisk = low;
					costRisk = low;
				}
				owner = "Safety Officer";
			}
		}
		
		requirement <'R-005'> steamPressureRequirement : PerformanceRequirement {
			subject system : TurbineGeneratorSystem;
			doc /* The system shall operate with inlet steam pressure between 10 MPa and 25 MPa 
			       to achieve optimal thermodynamic efficiency. */
			require constraint {
				system.steamSupply.pressure >= 10.0 [MPa] and
				system.steamSupply.pressure <= 25.0 [MPa]
			}
			@StatusInfo {
				status = StatusKind::open;
				risk {
					totalRisk = medium;
					technicalRisk = medium;
					scheduleRisk = low;
					costRisk = medium;
				}
				owner = "Thermal Systems Engineer";
			}
		}
		
		satisfy powerOutputRequirement by TurbineGeneratorSystem;
		satisfy efficiencyRequirement by TurbineGeneratorSystem;
		satisfy turbineSpeedLimit by TurbineGeneratorSystem;
		satisfy steamPressureRequirement by TurbineGeneratorSystem;
		
		refine primaryFunctionReq by powerOutputRequirement;
		refine primaryFunctionReq by efficiencyRequirement;
	}
}
