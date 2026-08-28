package 'Lunar Propellant Production Plant' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		alias PowerValue for ISQ::PowerValue;
		alias MassValue for ISQ::MassValue;
		alias TemperatureValue for ISQ::TemperatureValue;

		item def Regolith {
			attribute mass : MassValue;
			attribute iceContent : Real;
		}
		item def DrySoil {
			attribute mass : MassValue;
		}
		item def WaterVapor {
			attribute mass : MassValue;
		}
		item def LiquidWater {
			attribute mass : MassValue;
		}
		item def GaseousOxygen {
			attribute mass : MassValue;
		}
		item def GaseousHydrogen {
			attribute mass : MassValue;
		}
		item def LiquidOxygen {
			attribute mass : MassValue;
			attribute temp : TemperatureValue;
		}
		item def LiquidHydrogen {
			attribute mass : MassValue;
			attribute temp : TemperatureValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def ResetCommand;
		attribute def PowerAvailable;
		attribute def PowerLow;
		attribute def InitComplete;
		attribute def ExcavationComplete;
		attribute def ExtractionComplete;
		attribute def ElectrolysisComplete;
		attribute def LiquefactionComplete;
		attribute def TankFull;
		attribute def TankNotFull;

		action def 'Generate Power' {
			out electricPower : PowerValue;
		}
		action def 'Distribute Power' {
			in electricPower : PowerValue;
			out powerToExcavation : PowerValue;
			out powerToExtraction : PowerValue;
			out powerToElectrolyzer : PowerValue;
			out powerToO2Liquefier : PowerValue;
			out powerToH2Liquefier : PowerValue;
		}
		action def 'Excavate Regolith' {
			in electricPower : PowerValue;
			out regolith : Regolith;
		}
		action def 'Extract Water' {
			in electricPower : PowerValue;
			in regolith : Regolith;
			out liquidWater : LiquidWater;
			out drySoil : DrySoil;
		}
		action def 'Electrolyze Water' {
			in electricPower : PowerValue;
			in liquidWater : LiquidWater;
			out gaseousOxygen : GaseousOxygen;
			out gaseousHydrogen : GaseousHydrogen;
		}
		action def 'Liquefy Oxygen' {
			in electricPower : PowerValue;
			in gaseousOxygen : GaseousOxygen;
			out liquidOxygen : LiquidOxygen;
		}
		action def 'Liquefy Hydrogen' {
			in electricPower : PowerValue;
			in gaseousHydrogen : GaseousHydrogen;
			out liquidHydrogen : LiquidHydrogen;
		}
		action def 'Liquefy Gases';
		action def 'Store Oxygen' {
			in liquidOxygen : LiquidOxygen;
		}
		action def 'Store Hydrogen' {
			in liquidHydrogen : LiquidHydrogen;
		}
		action def 'Store Propellants';
		action def 'Run Self Test';
		action def 'Check Tank Levels' {
			out levelO2 : MassValue;
			out levelH2 : MassValue;
		}

		part def SolarPowerArray {
			port electricPowerPort { out electricPower : PowerValue; }
			perform action generatePower : 'Generate Power';
		}
		part def PowerDistributionUnit {
			port electricPowerInPort { in electricPower : PowerValue; }
			port excavationPowerPort { out powerToExcavation : PowerValue; }
			port extractionPowerPort { out powerToExtraction : PowerValue; }
			port electrolyzerPowerPort { out powerToElectrolyzer : PowerValue; }
			port o2LiquefierPowerPort { out powerToO2Liquefier : PowerValue; }
			port h2LiquefierPowerPort { out powerToH2Liquefier : PowerValue; }
			perform action distributePower : 'Distribute Power';
		}
		part def ExcavationRobot {
			port powerInPort { in electricPower : PowerValue; }
			port regolithPort { out regolith : Regolith; }
			perform action excavateRegolith : 'Excavate Regolith';
		}
		part def ThermalExtractor {
			port powerInPort { in electricPower : PowerValue; }
			port regolithInPort { in regolith : Regolith; }
			port liquidWaterPort { out liquidWater : LiquidWater; }
			port drySoilPort { out drySoil : DrySoil; }
			perform action extractWater : 'Extract Water';
		}
		part def WaterElectrolyzer {
			port powerInPort { in electricPower : PowerValue; }
			port liquidWaterInPort { in liquidWater : LiquidWater; }
			port gaseousOxygenPort { out gaseousOxygen : GaseousOxygen; }
			port gaseousHydrogenPort { out gaseousHydrogen : GaseousHydrogen; }
			perform action electrolyzeWater : 'Electrolyze Water';
		}
		part def OxygenLiquefier {
			port powerInPort { in electricPower : PowerValue; }
			port gaseousOxygenInPort { in gaseousOxygen : GaseousOxygen; }
			port liquidOxygenPort { out liquidOxygen : LiquidOxygen; }
			attribute targetTemp : TemperatureValue = 90 [K];
			perform action liquefyOxygen : 'Liquefy Oxygen';
		}
		part def HydrogenLiquefier {
			port powerInPort { in electricPower : PowerValue; }
			port gaseousHydrogenInPort { in gaseousHydrogen : GaseousHydrogen; }
			port liquidHydrogenPort { out liquidHydrogen : LiquidHydrogen; }
			attribute targetTemp : TemperatureValue = 20 [K];
			perform action liquefyHydrogen : 'Liquefy Hydrogen';
		}
		part def OxygenStorageTank {
			port liquidOxygenInPort { in liquidOxygen : LiquidOxygen; }
			port liquidOxygenOutPort { out liquidOxygen : LiquidOxygen; }
			attribute capacity : MassValue;
			attribute currentLevel : MassValue;
			perform action storeOxygen : 'Store Oxygen';
		}
		part def HydrogenStorageTank {
			port liquidHydrogenInPort { in liquidHydrogen : LiquidHydrogen; }
			port liquidHydrogenOutPort { out liquidHydrogen : LiquidHydrogen; }
			attribute capacity : MassValue;
			attribute currentLevel : MassValue;
			perform action storeHydrogen : 'Store Hydrogen';
		}
		part def LunarPropellantPlant {
			perform action runSelfTest : 'Run Self Test';
			perform action checkTankLevels : 'Check Tank Levels';
			perform action liquefyGases : 'Liquefy Gases';
			perform action storePropellants : 'Store Propellants';
		}

		state def 'Plant States';
	}

	package Requirements {
		private import Definitions::*;

		requirement def 'ISRU Propellant Production' {
			subject plant : LunarPropellantPlant;
			requirement 'extract water from regolith' {
				doc /* The plant shall extract water ice from lunar regolith and condense it into liquid water. */
			}
			requirement 'produce liquid oxygen' {
				doc /* The plant shall electrolyze water and liquefy the resulting oxygen to a cryogenic temperature near 90 K. */
			}
			requirement 'produce liquid hydrogen' {
				doc /* The plant shall electrolyze water and liquefy the resulting hydrogen to a cryogenic temperature near 20 K. */
			}
			requirement 'solar power' {
				doc /* The plant shall be powered by a solar power array whose output is distributed by a central power distribution unit. */
			}
			requirement 'autonomous cycle' {
				doc /* The plant shall autonomously cycle through excavation, extraction, electrolysis, liquefaction, and storage states until both storage tanks are full. */
			}
		}

		requirement 'isru propellant production' : 'ISRU Propellant Production';
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		part 'lunar propellant plant' : LunarPropellantPlant {
			satisfy 'isru propellant production';

			part solarPowerArray : SolarPowerArray;
			part powerDistributionUnit : PowerDistributionUnit;
			part excavationRobot : ExcavationRobot;
			part thermalExtractor : ThermalExtractor;
			part waterElectrolyzer : WaterElectrolyzer;
			part oxygenLiquefier : OxygenLiquefier;
			part hydrogenLiquefier : HydrogenLiquefier;
			part oxygenStorageTank : OxygenStorageTank {
				attribute capacity = 5000 [kg];
				attribute currentLevel = 0 [kg];
			}
			part hydrogenStorageTank : HydrogenStorageTank {
				attribute capacity = 5000 [kg];
				attribute currentLevel = 0 [kg];
			}

			flow solarPowerFlow of PowerValue
				from solarPowerArray.electricPowerPort.electricPower
				to powerDistributionUnit.electricPowerInPort.electricPower;
			flow excavationPowerFlow of PowerValue
				from powerDistributionUnit.excavationPowerPort.powerToExcavation
				to excavationRobot.powerInPort.electricPower;
			flow extractionPowerFlow of PowerValue
				from powerDistributionUnit.extractionPowerPort.powerToExtraction
				to thermalExtractor.powerInPort.electricPower;
			flow electrolyzerPowerFlow of PowerValue
				from powerDistributionUnit.electrolyzerPowerPort.powerToElectrolyzer
				to waterElectrolyzer.powerInPort.electricPower;
			flow o2LiquefierPowerFlow of PowerValue
				from powerDistributionUnit.o2LiquefierPowerPort.powerToO2Liquefier
				to oxygenLiquefier.powerInPort.electricPower;
			flow h2LiquefierPowerFlow of PowerValue
				from powerDistributionUnit.h2LiquefierPowerPort.powerToH2Liquefier
				to hydrogenLiquefier.powerInPort.electricPower;
			flow regolithFlow of Regolith
				from excavationRobot.regolithPort.regolith
				to thermalExtractor.regolithInPort.regolith;
			flow liquidWaterFlow of LiquidWater
				from thermalExtractor.liquidWaterPort.liquidWater
				to waterElectrolyzer.liquidWaterInPort.liquidWater;
			flow gaseousOxygenFlow of GaseousOxygen
				from waterElectrolyzer.gaseousOxygenPort.gaseousOxygen
				to oxygenLiquefier.gaseousOxygenInPort.gaseousOxygen;
			flow gaseousHydrogenFlow of GaseousHydrogen
				from waterElectrolyzer.gaseousHydrogenPort.gaseousHydrogen
				to hydrogenLiquefier.gaseousHydrogenInPort.gaseousHydrogen;
			flow liquidOxygenFlow of LiquidOxygen
				from oxygenLiquefier.liquidOxygenPort.liquidOxygen
				to oxygenStorageTank.liquidOxygenInPort.liquidOxygen;
			flow liquidHydrogenFlow of LiquidHydrogen
				from hydrogenLiquefier.liquidHydrogenPort.liquidHydrogen
				to hydrogenStorageTank.liquidHydrogenInPort.liquidHydrogen;

			state plantStates : 'Plant States' {
				entry; then standby;
				state standby;
				accept PowerAvailable then initialization;
				state initialization {
					do runSelfTest;
				}
				accept InitComplete then excavation;
				state excavation {
					do excavationRobot.excavateRegolith;
				}
				accept ExcavationComplete then extraction;
				state extraction {
					do thermalExtractor.extractWater;
				}
				accept ExtractionComplete then electrolysis;
				state electrolysis {
					do waterElectrolyzer.electrolyzeWater;
				}
				accept ElectrolysisComplete then liquefaction;
				state liquefaction {
					do liquefyGases;
				}
				accept LiquefactionComplete then storage;
				state storage {
					entry checkTankLevels;
					do storePropellants;
				}
				accept TankFull then productionComplete;
				accept TankNotFull then excavation;
				state productionComplete;
				accept ResetCommand then standby;
			}
		}
	}
}
