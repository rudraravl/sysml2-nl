package LunarPropellantPlant {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type MassValue :> Real { unit kg; }
    value type PowerValue :> Real { unit W; }
    value type TemperatureValue :> Real { unit K; }
    value type VolumeValue :> Real { unit m3; }
    value type MassFlowRateValue :> Real { unit kg_per_s; }
    value type EnergyValue :> Real { unit J; }
    value type TimeDurationValue :> Real { unit s; }
    value type EfficiencyValue :> Real;

    // ===== Item Definitions =====
    item def Electricity {
        attribute power : PowerValue;
    }

    item def Regolith {
        attribute mass : MassValue;
        attribute iceContentFraction : Real;
    }

    item def DryRegolith {
        attribute mass : MassValue;
    }

    item def WaterVapor {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    item def LiquidWater {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    item def GaseousOxygen {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    item def GaseousHydrogen {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    item def LiquidOxygen {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    item def LiquidHydrogen {
        attribute mass : MassValue;
        attribute temperature : TemperatureValue;
    }

    // ===== Port Definitions =====
    port def PowerOutPort {
        out electricity : Electricity;
    }

    port def PowerInPort {
        in electricity : Electricity;
    }

    port def RegolithOutPort {
        out regolith : Regolith;
    }

    port def RegolithInPort {
        in regolith : Regolith;
    }

    port def DryRegolithWastePort {
        out waste : DryRegolith;
    }

    port def LiquidWaterOutPort {
        out water : LiquidWater;
    }

    port def LiquidWaterInPort {
        in water : LiquidWater;
    }

    port def GaseousOxygenOutPort {
        out oxygen : GaseousOxygen;
    }

    port def GaseousOxygenInPort {
        in oxygen : GaseousOxygen;
    }

    port def GaseousHydrogenOutPort {
        out hydrogen : GaseousHydrogen;
    }

    port def GaseousHydrogenInPort {
        in hydrogen : GaseousHydrogen;
    }

    port def LiquidOxygenOutPort {
        out oxygen : LiquidOxygen;
    }

    port def LiquidOxygenInPort {
        in oxygen : LiquidOxygen;
    }

    port def LiquidHydrogenOutPort {
        out hydrogen : LiquidHydrogen;
    }

    port def LiquidHydrogenInPort {
        in hydrogen : LiquidHydrogen;
    }

    // ===== Component Part Definitions =====

    part def SolarPowerArray {
        doc /* Large solar array that generates electricity during the lunar day. */;
        attribute nominalPower : PowerValue = 10000;
        attribute currentPower : PowerValue;
        attribute solarIrradianceAvailable : Boolean = false;
        attribute panelArea : VolumeValue = 50;
        port powerOut : PowerOutPort;
        action generatePower {
            /* Convert incident solar radiation into electrical power */
        }
        action trackSun {
            /* Orient panels to maximize solar energy capture */
        }
    }

    part def PowerDistributionUnit {
        doc /* Central unit that allocates electrical power to each subsystem. */;
        attribute totalInputPower : PowerValue;
        attribute excavationAllocatedPower : PowerValue = 500;
        attribute extractionAllocatedPower : PowerValue = 2000;
        attribute electrolysisAllocatedPower : PowerValue = 3000;
        attribute o2LiquefierAllocatedPower : PowerValue = 2500;
        attribute h2LiquefierAllocatedPower : PowerValue = 1500;
        attribute totalAllocated : PowerValue;
        port powerIn : PowerInPort;
        port excavationPowerOut : PowerOutPort;
        port extractionPowerOut : PowerOutPort;
        port electrolysisPowerOut : PowerOutPort;
        port o2LiquefierPowerOut : PowerOutPort;
        port h2LiquefierPowerOut : PowerOutPort;
        action distributePower {
            /* Receive input power and route allocated shares to each subsystem */
        }
        action monitorPowerLoad {
            /* Continuously verify that power allocation matches subsystem demand */
        }
    }

    part def ExcavationRobot {
        doc /* Autonomous robot that digs into lunar regolith to collect ice-rich material. */;
        attribute collectionRate : MassFlowRateValue = 0.5;
        attribute regolithCollected : MassValue = 0;
        attribute iceContentFraction : Real = 0.05;
        attribute isOperational : Boolean = false;
        attribute maxPayload : MassValue = 100;
        port powerIn : PowerInPort;
        port regolithOut : RegolithOutPort;
        action excavateRegolith {
            /* Dig into lunar soil to collect ice-rich regolith */
        }
        action transportRegolith {
            /* Haul collected regolith to the thermal extractor feed hopper */
        }
        action returnToDigSite {
            /* Return to excavation site for next collection cycle */
        }
    }

    part def ThermalExtractor {
        doc /* Heats regolith to sublime water ice, then condenses vapor to liquid water. */;
        attribute heatingTemperature : TemperatureValue = 273;
        attribute condensationTemperature : TemperatureValue = 278;
        attribute extractionEfficiency : EfficiencyValue = 0.95;
        attribute waterExtracted : MassValue = 0;
        attribute isOperational : Boolean = false;
        attribute batchProcessingTime : TimeDurationValue = 600;
        port powerIn : PowerInPort;
        port regolithIn : RegolithInPort;
        port waterOut : LiquidWaterOutPort;
        port wasteOut : DryRegolithWastePort;
        action heatRegolith {
            /* Apply thermal energy to regolith until water ice sublimates */
        }
        action condenseVapor {
            /* Cool water vapor to condensation point and collect liquid water */
        }
        action discardDrySoil {
            /* Eject processed dry regolith as waste */
        }
    }

    part def WaterElectrolyzer {
        doc /* Electrolyzes liquid water into gaseous oxygen and hydrogen. */;
        attribute electrolysisRate : MassFlowRateValue = 0.1;
        attribute operatingVoltage : PowerValue = 200;
        attribute o2Produced : MassValue = 0;
        attribute h2Produced : MassValue = 0;
        attribute isOperational : Boolean = false;
        port powerIn : PowerInPort;
        port waterIn : LiquidWaterInPort;
        port o2GasOut : GaseousOxygenOutPort;
        port h2GasOut : GaseousHydrogenOutPort;
        action electrolyzeWater {
            /* Pass strong electrical current through water to split H2O into O2 and H2 */
        }
        action separateGases {
            /* Route produced gases to their respective liquefier inputs */
        }
    }

    part def OxygenLiquefier {
        doc /* Cryogenic cooler that condenses gaseous oxygen into liquid oxygen at 90 K. */;
        attribute targetTemperature : TemperatureValue = 90;
        attribute coolingRate : MassFlowRateValue = 0.08;
        attribute loxProduced : MassValue = 0;
        attribute isOperational : Boolean = false;
        attribute coolingEfficiency : EfficiencyValue = 0.85;
        port powerIn : PowerInPort;
        port o2GasIn : GaseousOxygenInPort;
        port o2LiquidOut : LiquidOxygenOutPort;
        action liquefyOxygen {
            /* Chill gaseous oxygen to 90 K (minus 183 C) until it condenses into liquid */
        }
        action maintainCryogenicTemp {
            /* Keep oxygen at or below condensation temperature during processing */
        }
    }

    part def HydrogenLiquefier {
        doc /* Cryogenic cooler that condenses gaseous hydrogen into liquid hydrogen at 20 K. */;
        attribute targetTemperature : TemperatureValue = 20;
        attribute coolingRate : MassFlowRateValue = 0.01;
        attribute lh2Produced : MassValue = 0;
        attribute isOperational : Boolean = false;
        attribute coolingEfficiency : EfficiencyValue = 0.80;
        port powerIn : PowerInPort;
        port h2GasIn : GaseousHydrogenInPort;
        port h2LiquidOut : LiquidHydrogenOutPort;
        action liquefyHydrogen {
            /* Chill gaseous hydrogen to 20 K (minus 253 C) until it condenses into liquid */
        }
        action maintainCryogenicTemp {
            /* Keep hydrogen at or below condensation temperature during processing */
        }
    }

    part def OxygenStorageTank {
        doc /* Heavily insulated tank for storing liquid oxygen at cryogenic temperatures. */;
        attribute capacity : MassValue = 8000;
        attribute currentLevel : MassValue = 0;
        attribute storedTemperature : TemperatureValue = 90;
        attribute isFull : Boolean = false;
        attribute insulationRating : EfficiencyValue = 0.999;
        attribute boilOffRate : MassFlowRateValue = 0.001;
        port liquidIn : LiquidOxygenInPort;
        action receiveLiquidOxygen {
            /* Accept incoming liquid oxygen from the liquefier */
        }
        action monitorLevel {
            /* Check fill level and update isFull status */
        }
        action maintainCryogenicStorage {
            /* Maintain insulation and monitor for boil-off losses */
        }
    }

    part def HydrogenStorageTank {
        doc /* Heavily insulated tank for storing liquid hydrogen at cryogenic temperatures. */;
        attribute capacity : MassValue = 1500;
        attribute currentLevel : MassValue = 0;
        attribute storedTemperature : TemperatureValue = 20;
        attribute isFull : Boolean = false;
        attribute insulationRating : EfficiencyValue = 0.999;
        attribute boilOffRate : MassFlowRateValue = 0.002;
        port liquidIn : LiquidHydrogenInPort;
        action receiveLiquidHydrogen {
            /* Accept incoming liquid hydrogen from the liquefier */
        }
        action monitorLevel {
            /* Check fill level and update isFull status */
        }
        action maintainCryogenicStorage {
            /* Maintain insulation and monitor for boil-off losses */
        }
    }

    // ===== Main Plant System =====

    part def LunarPropellantPlantSystem {
        doc /* Automated lunar propellant production plant performing ISRU to produce liquid oxygen and liquid hydrogen. */;

        attribute powerAvailable : Boolean = false;
        attribute selfCheckComplete : Boolean = false;
        attribute excavationComplete : Boolean = false;
        attribute extractionComplete : Boolean = false;
        attribute electrolysisComplete : Boolean = false;
        attribute liquefactionComplete : Boolean = false;
        attribute tanksFull : Boolean = false;
        attribute productionCycleCount : Integer = 0;
        attribute systemReady : Boolean = false;
        attribute totalWaterProcessed : MassValue = 0;
        attribute totalLOXProduced : MassValue = 0;
        attribute totalLH2Produced : MassValue = 0;

        part solarArray : SolarPowerArray;
        part powerUnit : PowerDistributionUnit;
        part excavator : ExcavationRobot;
        part extractor : ThermalExtractor;
        part electrolyzer : WaterElectrolyzer;
        part o2Liquefier : OxygenLiquefier;
        part h2Liquefier : HydrogenLiquefier;
        part o2Tank : OxygenStorageTank;
        part h2Tank : HydrogenStorageTank;

        // Power distribution connections
        connect solarArray.powerOut to powerUnit.powerIn;
        connect powerUnit.excavationPowerOut to excavator.powerIn;
        connect powerUnit.extractionPowerOut to extractor.powerIn;
        connect powerUnit.electrolysisPowerOut to electrolyzer.powerIn;
        connect powerUnit.o2LiquefierPowerOut to o2Liquefier.powerIn;
        connect powerUnit.h2LiquefierPowerOut to h2Liquefier.powerIn;

        // Material flow connections
        connect excavator.regolithOut to extractor.regolithIn;
        connect extractor.waterOut to electrolyzer.waterIn;
        connect electrolyzer.o2GasOut to o2Liquefier.o2GasIn;
        connect electrolyzer.h2GasOut to h2Liquefier.h2GasIn;
        connect o2Liquefier.o2LiquidOut to o2Tank.liquidIn;
        connect h2Liquefier.h2LiquidOut to h2Tank.liquidIn;

        // State machine governing the automated production cycle
        state machine productionCycle {
            transition t_initial initial to standby;

            state standby {
                entry {
                    powerAvailable = false;
                    selfCheckComplete = false;
                    systemReady = false;
                }
                do {
                    /* Monitor solar array output; await sufficient power */
                }
            }

            state initialization {
                entry {
                    selfCheckComplete = false;
                }
                do {
                    /* Run self-checks on all subsystems:
                       verify power distribution, excavation robot,
                       thermal extractor, electrolyzer, liquefiers,
                       and storage tanks are functional */
                }
                exit {
                    selfCheckComplete = true;
                    productionCycleCount = productionCycleCount + 1;
                }
            }

            state excavation {
                entry {
                    excavationComplete = false;
                    excavator.isOperational = true;
                }
                do {
                    /* Autonomous excavation robot digs into regolith
                       and collects ice-rich material for processing */
                }
                exit {
                    excavator.isOperational = false;
                    excavationComplete = true;
                }
            }

            state extraction {
                entry {
                    extractionComplete = false;
                    extractor.isOperational = true;
                }
                do {
                    /* Thermal extractor heats regolith to sublime ice,
                       condenses vapor to liquid water,
                       discards dry soil as waste */
                }
                exit {
                    extractor.isOperational = false;
                    extractionComplete = true;
                }
            }

            state electrolysis {
                entry {
                    electrolysisComplete = false;
                    electrolyzer.isOperational = true;
                }
                do {
                    /* Water electrolyzer splits H2O into
                       gaseous oxygen and gaseous hydrogen */
                }
                exit {
                    electrolyzer.isOperational = false;
                    electrolysisComplete = true;
                }
            }

            state liquefaction {
                entry {
                    liquefactionComplete = false;
                    o2Liquefier.isOperational = true;
                    h2Liquefier.isOperational = true;
                }
                do {
                    /* Oxygen liquefier cools O2 gas to 90 K;
                       Hydrogen liquefier cools H2 gas to 20 K;
                       both gases condense into cryogenic liquids */
                }
                exit {
                    o2Liquefier.isOperational = false;
                    h2Liquefier.isOperational = false;
                    liquefactionComplete = true;
                }
            }

            state storage {
                entry {
                    /* Transfer liquefied products to insulated storage tanks */
                }
                do {
                    /* Monitor tank fill levels */
                    o2Tank.isFull = (o2Tank.currentLevel >= o2Tank.capacity);
                    h2Tank.isFull = (h2Tank.currentLevel >= h2Tank.capacity);
                    tanksFull = (o2Tank.isFull && h2Tank.isFull);
                }
            }

            state productionComplete {
                entry {
                    /* All tanks are full; production halted */
                }
                do {
                    /* Maintain cryogenic storage conditions;
                       await next command for refueling operations */
                }
            }

            // State transitions
            transition from standby to initialization when powerAvailable;
            transition from initialization to excavation when selfCheckComplete;
            transition from excavation to extraction when excavationComplete;
            transition from extraction to electrolysis when extractionComplete;
            transition from electrolysis to liquefaction when electrolysisComplete;
            transition from liquefaction to storage when liquefactionComplete;
            transition from storage to productionComplete when tanksFull;
            transition from storage to excavation when !tanksFull;
            transition from productionComplete to standby when !tanksFull;
        }

        satisfy ISRUProductionRequirement;
        satisfy AutomatedProductionCycleRequirement;
        satisfy ContinuousProductionRequirement;
    }

    // ===== Requirements =====

    requirement def ISRUProductionRequirement {
        doc /* The system shall perform In-Situ Resource Utilization by extracting resources directly from the Moon to create liquid oxygen and liquid hydrogen rocket propellant. */;
        subject plant : LunarPropellantPlantSystem;
    }

    requirement def SolarPowerRequirement {
        doc /* The system shall be powered by a large solar power array that generates electricity during the lunar day. */;
        subject solarArray : SolarPowerArray;
    }

    requirement def PowerDistributionRequirement {
        doc /* A central power distribution unit shall allocate the necessary electricity to each subsystem as they operate. */;
        subject pdu : PowerDistributionUnit;
    }

    requirement def ExcavationRequirement {
        doc /* An autonomous excavation robot shall dig into the lunar regolith to collect ice-rich material. */;
        subject excavator : ExcavationRobot;
    }

    requirement def ThermalExtractionRequirement {
        doc /* A thermal extractor shall heat regolith to sublimate water ice into vapor, then condense the vapor into liquid water while discarding processed dry soil. */;
        subject extractor : ThermalExtractor;
    }

    requirement def ElectrolysisRequirement {
        doc /* A water electrolyzer shall split H2O molecules into gaseous oxygen and gaseous hydrogen using a strong electrical current. */;
        subject electrolyzer : WaterElectrolyzer;
    }

    requirement def OxygenLiquefactionRequirement {
        doc /* An oxygen liquefier shall cool gaseous oxygen to minus 183 degrees Celsius (90 K) until it condenses into liquid oxygen. */;
        subject o2Liquefier : OxygenLiquefier;
    }

    requirement def HydrogenLiquefactionRequirement {
        doc /* A hydrogen liquefier shall cool gaseous hydrogen to minus 253 degrees Celsius (20 K) until it condenses into liquid hydrogen. */;
        subject h2Liquefier : HydrogenLiquefier;
    }

    requirement def CryogenicStorageRequirement {
        doc /* Heavily insulated storage tanks shall maintain liquid oxygen and liquid hydrogen at cryogenic temperatures until they are needed for fueling rockets. */;
    }

    requirement def AutomatedProductionCycleRequirement {
        doc /* The entire production cycle shall be automated and operate through the states of Standby, Initialization, Excavation, Extraction, Electrolysis, Liquefaction, and Storage. */;
        subject plant : LunarPropellantPlantSystem;
    }

    requirement def ContinuousProductionRequirement {
        doc /* When storage tanks are not full, the system shall automatically begin a new excavation cycle. When tanks are full, the system shall enter a Production Complete state awaiting the next command. */;
        subject plant : LunarPropellantPlantSystem;
    }

    requirement def RefuelingCapabilityRequirement {
        doc /* The produced liquid oxygen and liquid hydrogen shall be suitable for use as rocket propellant, enabling spacecraft to refuel on the Moon instead of carrying all fuel from Earth. */;
    }
}
