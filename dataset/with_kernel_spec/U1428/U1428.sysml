package 'Horsepower Power Generation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def StartCommand;
	attribute def ShutdownCommand;
	
	attribute def HorsepowerValue :> PowerValue;
	attribute def EfficiencyRatio :> Real;
	attribute def RPMValue :> Real;
	
	item def FuelSupply {
		attribute flowRate : MassFlowRateValue;
		attribute energyContent : EnergyValue;
	}
	
	item def MechanicalPower {
		attribute horsepower : HorsepowerValue;
		attribute torque : TorqueValue;
		attribute rotationalSpeed : RPMValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute power : PowerValue;
	}
	
	item def CoolantFlow {
		attribute flowRate : VolumeFlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def FuelPort {
		in item fuel : FuelSupply;
	}
	
	port def MechanicalShaftPort {
		out item shaftPower : MechanicalPower;
	}
	
	port def ElectricalOutputPort {
		out item electricalOutput : ElectricalPower;
	}
	
	port def CoolingPort {
		inout item coolant : CoolantFlow;
	}
	
	port def LoadConnectionPort {
		in item powerDemand : ElectricalPower;
	}
	
	part def PrimeEngine {
		attribute ratedHorsepower : HorsepowerValue;
		attribute currentOutput : HorsepowerValue;
		attribute operatingRPM : RPMValue;
		attribute fuelEfficiency : EfficiencyRatio;
		
		port fuelInput : FuelPort;
		port mechanicalOutput : MechanicalShaftPort;
		port cooling : CoolingPort;
	}
	
	part def ElectricalGenerator {
		attribute ratedCapacity : PowerValue;
		attribute conversionEfficiency : EfficiencyRatio;
		attribute outputVoltage : ElectricPotentialValue;
		
		port mechanicalInput : MechanicalShaftPort;
		port electricalOutput : ElectricalOutputPort;
	}
	
	part def ControlModule {
		attribute targetOutput : PowerValue;
		attribute currentLoad : PowerValue;
		attribute ratedCapacity : PowerValue;
		attribute currentOutput : PowerValue;
	}
	
	state def ControlStates {
		entry; then standby;
		
		state standby;
		transition standby_to_startup first standby
			accept StartCommand
			then startup;
		
		state startup;
		transition startup_to_running first startup
			then running;
		
		state running;
		transition running_to_shutdown first running
			accept ShutdownCommand
			then shutdown;
		
		state shutdown;
		transition shutdown_to_standby first shutdown
			then standby;
	}
	
	part def CoolingSystem {
		attribute coolantCapacity : VolumeValue;
		attribute maxHeatRejection : PowerValue;
		
		port primaryCooling : CoolingPort;
	}
	
	part def LoadBank {
		attribute connectedLoad : PowerValue;
		attribute powerFactor : Real;
		
		port powerInput : LoadConnectionPort;
	}
	
	action def ConvertFuelToMechanical {
		in fuel : FuelSupply;
		in targetHorsepower : HorsepowerValue;
		out mechanicalPower : MechanicalPower;
		out wasteHeat : PowerValue;
	}
	
	action def ConvertMechanicalToElectrical {
		in mechanical : MechanicalPower;
		out electrical : ElectricalPower;
	}
	
	action def ManageCooling {
		in wasteHeat : PowerValue;
		inout coolant : CoolantFlow;
	}
	
	action def GeneratePower {
		in fuelSupply : FuelSupply;
		in demandedPower : PowerValue;
		in ratedHP : HorsepowerValue;
		out deliveredPower : ElectricalPower;
		
		first start;
		then action convertFuel : ConvertFuelToMechanical {
			in fuel = fuelSupply;
			in targetHorsepower = ratedHP;
			out mechanicalPower;
			out wasteHeat;
		}
		then fork powerAndHeat;
		then action convertToElectrical : ConvertMechanicalToElectrical {
			in mechanical = convertFuel.mechanicalPower;
			out electrical;
		}
		then join completePowerPath;
		action coolEngine : ManageCooling {
			in wasteHeat = convertFuel.wasteHeat;
			inout coolant;
		}
		then completePowerPath;
		then assign deliveredPower := convertToElectrical.electrical;
		then done;
	}
	
	part def HorsepowerGenerationSystem {
		doc /*
		A power generation system that converts chemical fuel energy into electrical power.
		The primary function is to produce controlled electrical output by first converting 
		fuel into mechanical horsepower through combustion, then converting the rotating 
		shaft power into electrical energy. The system manages fuel flow, mechanical-to-electrical 
		conversion, thermal management, and load regulation to deliver stable electrical power.
		*/
		
		attribute overallEfficiency : EfficiencyRatio;
		
		part engine : PrimeEngine;
		part generator : ElectricalGenerator;
		part controller : ControlModule;
		part cooling : CoolingSystem;
		part load : LoadBank;
		
		connection shaftCoupling
			connect engine.mechanicalOutput to generator.mechanicalInput;
		
		connection powerOutput
			connect generator.electricalOutput to load.powerInput;
		
		connection engineCooling
			connect engine.cooling to cooling.primaryCooling;
	}
	
	requirement def PowerGenerationRequirement {
		doc /* The system shall convert fuel energy into electrical power through mechanical horsepower */
		subject genset : HorsepowerGenerationSystem;
		attribute minimumHorsepower : HorsepowerValue;
		require constraint {
			genset.engine.ratedHorsepower >= minimumHorsepower
		}
	}
	
	requirement def ConversionEfficiencyRequirement {
		doc /* The system shall maintain minimum overall efficiency from fuel to electrical output */
		subject genset : HorsepowerGenerationSystem;
		attribute minimumEfficiency : EfficiencyRatio;
		require constraint {
			genset.overallEfficiency >= minimumEfficiency
		}
	}
	
	requirement def CoolingRequirement {
		doc /* The cooling system shall reject sufficient heat to maintain safe operating temperatures */
		subject genset : HorsepowerGenerationSystem;
		attribute maxOperatingTemp : ThermodynamicTemperatureValue;
		require constraint {
			genset.cooling.primaryCooling.coolant.temperature <= maxOperatingTemp
		}
	}
	
	requirement powerReq : PowerGenerationRequirement;
	requirement efficiencyReq : ConversionEfficiencyRequirement;
	requirement thermalReq : CoolingRequirement;
	
	requirement systemRequirements {
		doc /* Overall requirements for horsepower-based power generation */
		require powerReq;
		require efficiencyReq;
		require thermalReq;
	}
	
	part horsepowerGenset : HorsepowerGenerationSystem {
		attribute :>> overallEfficiency = 0.33;
		
		part :>> engine {
			attribute :>> ratedHorsepower = 500.0;
			attribute :>> currentOutput = 0.0;
			attribute :>> operatingRPM = 1800.0;
			attribute :>> fuelEfficiency = 0.35;
		}
		
		part :>> generator {
			attribute :>> ratedCapacity = 350000.0;
			attribute :>> conversionEfficiency = 0.94;
			attribute :>> outputVoltage = 480.0;
		}
		
		part :>> controller {
			attribute :>> targetOutput = 0.0;
			attribute :>> currentLoad = 0.0;
			attribute :>> ratedCapacity = 350000.0;
			attribute :>> currentOutput = 0.0;
		}
		
		part :>> cooling {
			attribute :>> coolantCapacity = 100.0;
			attribute :>> maxHeatRejection = 250000.0;
		}
		
		part :>> load {
			attribute :>> connectedLoad = 300000.0;
			attribute :>> powerFactor = 0.95;
		}
		
		perform action powerGeneration : GeneratePower {
			in fuelSupply;
			in demandedPower = load.connectedLoad;
			in ratedHP = engine.ratedHorsepower;
			out deliveredPower;
		}
		
		exhibit state controlBehavior : ControlStates;
		
		satisfy systemRequirements;
	}
}
