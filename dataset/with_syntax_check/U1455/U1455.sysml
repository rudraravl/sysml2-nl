package NaturalGasEnergySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def PressureValue :> Real;
	attribute def FlowRateValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def EfficiencyValue :> Real;
	
	item def NaturalGas {
		attribute methaneContent : Real;
		attribute energyContent : EnergyValue;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute flowRate : FlowRateValue;
	}
	
	item def CompressedAir {
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute flowRate : FlowRateValue;
	}
	
	item def CombustionGas {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
	}
	
	item def ElectricalPower {
		attribute voltage : Real;
		attribute current : Real;
		attribute power : PowerValue;
	}
	
	item def ThermalEnergy {
		attribute temperature : TemperatureValue;
		attribute heatRate : PowerValue;
	}
	
	port def GasInputPort {
		in item gas : NaturalGas;
	}
	
	port def AirInputPort {
		in item air : CompressedAir;
	}
	
	port def CombustionOutputPort {
		out item combustionGas : CombustionGas;
	}
	
	port def ElectricalOutputPort {
		out item electricity : ElectricalPower;
	}
	
	port def ThermalOutputPort {
		out item heat : ThermalEnergy;
	}
	
	part def FuelSupplySystem {
		port gasOutput : ~GasInputPort;
		attribute supplyPressure : PressureValue;
		attribute supplyTemperature : TemperatureValue;
		attribute supplyFlowRate : FlowRateValue;
		
		perform action supplyFuel {
			first start;
			then action regulatePressure {
				out targetPressure : PressureValue;
			}
			then action measureFlow {
				out flowRate : FlowRateValue;
			}
			then action deliverGas {
				in pressure = regulatePressure.targetPressure;
				in flow = measureFlow.flowRate;
			}
			then done;
		}
	}
	
	part def AirIntakeSystem {
		port airOutput : ~AirInputPort;
		attribute intakePressure : PressureValue;
		attribute intakeTemperature : TemperatureValue;
		
		perform action compressAir {
			first start;
			then action drawAir {
				out ambientAir : CompressedAir;
			}
			then action compress {
				in air = drawAir.ambientAir;
				out compressedAir : CompressedAir;
			}
			then action deliverAir {
				in air = compress.compressedAir;
			}
			then done;
		}
	}
	
	part def CombustionChamber {
		port fuelInput : GasInputPort;
		port airInput : AirInputPort;
		port exhaustOutput : CombustionOutputPort;
		attribute chamberPressure : PressureValue;
		attribute chamberTemperature : TemperatureValue;
		attribute combustionEfficiency : EfficiencyValue;
		attribute fuelFlowActive : Boolean;
		attribute airFlowActive : Boolean;
		
		perform action burnFuel {
			first start;
			then action mixFuelAir {
				in fuel : NaturalGas;
				in air : CompressedAir;
				out mixture : CombustionGas;
			}
			then action ignite {
				in mixture = mixFuelAir.mixture;
				out ignitedGas : CombustionGas;
			}
			then action sustain {
				in combustion = ignite.ignitedGas;
				out exhaust : CombustionGas;
			}
			then done;
		}
	}
	
	part def GasTurbine {
		port gasInput : ~CombustionOutputPort;
		port exhaustOutput : CombustionOutputPort;
		attribute shaftPower : PowerValue;
		attribute turbineEfficiency : EfficiencyValue;
		attribute rotationalSpeed : Real;
		
		perform action extractWork {
			first start;
			then action expandGas {
				in hotGas : CombustionGas;
				out expandedGas : CombustionGas;
				out mechanicalWork : PowerValue;
			}
			then action driveShaft {
				in work = expandGas.mechanicalWork;
				out shaftOutput : PowerValue;
			}
			then action exhaustGas {
				in gas = expandGas.expandedGas;
			}
			then done;
		}
	}
	
	part def ElectricalGenerator {
		port mechanicalInput : ~Real;
		port electricalOutput : ElectricalOutputPort;
		attribute generatorEfficiency : EfficiencyValue;
		attribute outputVoltage : Real;
		attribute outputCurrent : Real;
		attribute outputPower : PowerValue;
		
		perform action generateElectricity {
			first start;
			then action convertMechanical {
				in mechanicalPower : PowerValue;
				out electricalPower : PowerValue;
			}
			then action regulateVoltage {
				in power = convertMechanical.electricalPower;
				out voltage : Real;
			}
			then action deliverPower {
				in voltage = regulateVoltage.voltage;
				out electricity : ElectricalPower;
			}
			then done;
		}
	}
	
	part def HeatRecoveryUnit {
		port exhaustInput : ~CombustionOutputPort;
		port exhaustOutput : CombustionOutputPort;
		port thermalOutput : ThermalOutputPort;
		attribute recoveredHeat : PowerValue;
		attribute recoveryEfficiency : EfficiencyValue;
		
		perform action recoverHeat {
			first start;
			then action extractHeat {
				in hotExhaust : CombustionGas;
				out cooledExhaust : CombustionGas;
				out thermalEnergy : ThermalEnergy;
			}
			then action transferHeat {
				in heat = extractHeat.thermalEnergy;
				out usableHeat : ThermalEnergy;
			}
			then action exhaustCooledGas {
				in gas = extractHeat.cooledExhaust;
			}
			then done;
		}
	}
	
	part def ControlSystem {
		attribute systemLoad : PowerValue;
		attribute fuelFlowRate : FlowRateValue;
		attribute airFlowRate : FlowRateValue;
		attribute operatingMode : String;
		
		perform action controlOperation {
			first start;
			then merge monitoring;
			
			then action monitorLoad {
				out currentLoad : PowerValue;
			}
			
			then decide;
				if monitorLoad.currentLoad < 300.0 [kW] then reducePower;
				if monitorLoad.currentLoad >= 300.0 [kW] and monitorLoad.currentLoad < 500.0 [kW] then maintainPower;
				if monitorLoad.currentLoad >= 500.0 [kW] then increasePower;
			
			action reducePower {
				in load = monitorLoad.currentLoad;
			}
			then monitoring;
			
			action maintainPower {
				in load = monitorLoad.currentLoad;
			}
			then monitoring;
			
			action increasePower {
				in load = monitorLoad.currentLoad;
			}
			then monitoring;
		}
	}
	
	part def CombinedHeatPowerPlant {
		doc /* Primary function: Convert natural gas into electrical power and useful thermal energy 
		     * through combustion-driven turbine generation with waste heat recovery, providing 
		     * efficient cogeneration for industrial and commercial applications.
		     */
		
		attribute totalElectricalOutput : PowerValue;
		attribute totalThermalOutput : PowerValue;
		attribute overallEfficiency : EfficiencyValue;
		attribute fuelConsumptionRate : FlowRateValue;
		
		part fuelSupply : FuelSupplySystem {
			attribute :>> supplyPressure = 500.0;
			attribute :>> supplyTemperature = 288.0;
			attribute :>> supplyFlowRate = 100.0;
		}
		
		part airIntake : AirIntakeSystem {
			attribute :>> intakePressure = 101.3;
			attribute :>> intakeTemperature = 288.0;
		}
		
		part combustor : CombustionChamber {
			attribute :>> chamberPressure = 1500.0;
			attribute :>> chamberTemperature = 1500.0;
			attribute :>> combustionEfficiency = 0.98;
			attribute :>> fuelFlowActive = true;
			attribute :>> airFlowActive = true;
		}
		
		part turbine : GasTurbine {
			attribute :>> shaftPower = 500.0 [kW];
			attribute :>> turbineEfficiency = 0.85;
			attribute :>> rotationalSpeed = 3600.0;
		}
		
		part generator : ElectricalGenerator {
			attribute :>> generatorEfficiency = 0.96;
			attribute :>> outputVoltage = 480.0;
			attribute :>> outputCurrent = 600.0;
			attribute :>> outputPower = 480.0 [kW];
		}
		
		part heatRecovery : HeatRecoveryUnit {
			attribute :>> recoveredHeat = 250.0 [kW];
			attribute :>> recoveryEfficiency = 0.75;
		}
		
		part controller : ControlSystem {
			attribute :>> systemLoad = 480.0 [kW];
			attribute :>> fuelFlowRate = 100.0;
			attribute :>> airFlowRate = 400.0;
			attribute :>> operatingMode = "normal";
		}
		
		connection fuelLine connect fuelSupply.gasOutput to combustor.fuelInput;
		connection airLine connect airIntake.airOutput to combustor.airInput;
		connection hotGasLine connect combustor.exhaustOutput to turbine.gasInput;
		connection exhaustLine connect turbine.exhaustOutput to heatRecovery.exhaustInput;
		
		perform action generateCombinedPower {
			first start;
			then fork;
			
			parallel action supplyFuel {
				first fuelSupply.supplyFuel;
				then done;
			}
			
			parallel action supplyAir {
				first airIntake.compressAir;
				then done;
			}
			
			then join;
			then action combust {
				first combustor.burnFuel;
				then done;
			}
			then action generatePower {
				first turbine.extractWork;
				then generator.generateElectricity;
				then done;
			}
			then action recoverWasteHeat {
				first heatRecovery.recoverHeat;
				then done;
			}
			then done;
		}
		
		assert constraint efficiencyCalculation {
			overallEfficiency == (totalElectricalOutput + totalThermalOutput) / (fuelConsumptionRate * 50.0)
		}
	}
	
	requirement <'REQ-100'> primaryEnergyConversion {
		doc /* The natural gas energy system shall convert natural gas fuel into electrical 
		     * power and thermal energy through efficient combustion and cogeneration processes.
		     */
		subject plant : CombinedHeatPowerPlant;
		
		require electricalGeneration;
		require thermalRecovery;
		require overallEfficiency;
	}
	
	requirement <'REQ-101'> electricalGeneration {
		doc /* The system shall generate electrical power with a minimum output of 400 kW.
		     */
		subject plant : CombinedHeatPowerPlant;
		
		assert constraint minimumElectricalOutput {
			plant.generator.outputPower >= 400.0 [kW]
		}
	}
	
	requirement <'REQ-102'> thermalRecovery {
		doc /* The system shall recover waste heat with a minimum thermal output of 200 kW.
		     */
		subject plant : CombinedHeatPowerPlant;
		
		assert constraint minimumThermalOutput {
			plant.heatRecovery.recoveredHeat >= 200.0 [kW]
		}
	}
	
	requirement <'REQ-103'> overallEfficiency {
		doc /* The combined heat and power system shall achieve an overall efficiency 
		     * of at least 75% based on fuel energy input.
		     */
		subject plant : CombinedHeatPowerPlant;
		
		assert constraint efficiencyTarget {
			plant.overallEfficiency >= 0.75
		}
	}
	
	requirement <'REQ-104'> combustionTemperature {
		doc /* The combustion chamber shall maintain operating temperature between 
		     * 1400 K and 1600 K for optimal efficiency and emissions control.
		     */
		subject combustor : CombinedHeatPowerPlant::combustor;
		
		assert constraint temperatureRange {
			combustor.chamberTemperature >= 1400.0 and 
			combustor.chamberTemperature <= 1600.0
		}
	}
	
	requirement <'REQ-105'> fuelPressure {
		doc /* The fuel supply system shall maintain gas pressure at 500 kPa 
		     * for consistent combustion performance.
		     */
		subject fuel : CombinedHeatPowerPlant::fuelSupply;
		
		assert constraint pressureRegulation {
			fuel.supplyPressure == 500.0
		}
	}
	
	satisfy primaryEnergyConversion by CombinedHeatPowerPlant;
}
