package PondEcosystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    package Units {
        attribute def MassConcentrationUnit :> DerivedUnit {
            private attribute massPF : QuantityPowerFactor[1] { :>> quantity = isq.M; :>> exponent = 1; }
            private attribute volumePF : QuantityPowerFactor[1] { :>> quantity = isq.L; :>> exponent = -3; }
            attribute :>> quantityDimension { :>> quantityPowerFactors = (massPF, volumePF); }
        }
        attribute mg : MassUnit = 1e-6[SI::kg];
        attribute L : VolumeUnit = 1e-3[m^3];
        attribute mg_per_L : MassConcentrationUnit = mg / L;
        attribute degC : ThermodynamicTemperatureUnit = 'K';
        attribute kg_per_s : MassFlowRateUnit = 'kg' / 's';
        attribute m_per_s : SpeedUnit = 'm' / 's';
    }

    package ValueTypes {
        private import Units::*;
        attribute def VolumeValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : VolumeUnit = 'm^3';
        }
        attribute def DissolvedOxygenValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : MassConcentrationUnit = mg_per_L;
        }
        attribute def pHValue :> Real;
        attribute def TemperatureValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : ThermodynamicTemperatureUnit = degC;
        }
        attribute def NutrientLevelValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : MassConcentrationUnit = mg_per_L;
        }
        attribute def BiomassValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : MassUnit = 'kg';
        }
        attribute def MassFlowRateValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : MassFlowRateUnit = kg_per_s;
        }
        attribute def WindSpeedValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef : SpeedUnit = m_per_s;
        }
    }

    package Items {
        private import ValueTypes::*;
        item def Oxygen {
            attribute rate : MassFlowRateValue;
        }
        item def Nutrient {
            attribute concentration : NutrientLevelValue;
        }
        item def OrganicWaste {
            attribute massRate : MassFlowRateValue;
        }
        item def Biomass {
            attribute mass : BiomassValue;
        }
    }

    package Behaviors {
        private import ValueTypes::*;
        action def Photosynthesis {
            in lightIntensity : Real;
            in nutrients : NutrientLevelValue;
            out oxygenProduced : MassFlowRateValue;
            out biomassIncrease : BiomassValue;
        }
        action def Respiration {
            in oxygenAvailable : MassFlowRateValue;
            out oxygenConsumed : MassFlowRateValue;
            out wasteProduced : MassFlowRateValue;
        }
        action def Decomposition {
            in organicMatter : BiomassValue;
            out nutrientsReleased : NutrientLevelValue;
        }
        action def GasExchange {
            in windSpeed : WindSpeedValue;
            out oxygenTransfer : MassFlowRateValue;
        }
    }

    package PartDefinitions {
        private import Units::*;
        private import ValueTypes::*;
        private import Items::*;
        private import Behaviors::*;

        part def WaterBody {
            attribute volume : VolumeValue;
            attribute dissolvedOxygen : DissolvedOxygenValue;
            attribute pH : pHValue;
            attribute temperature : TemperatureValue;
            attribute nutrientLevel : NutrientLevelValue;

            port inOxygen : Oxygen;
            port outOxygen : Oxygen;
            port inNutrients : Nutrient;
            port outNutrients : Nutrient;
            port inWaste : OrganicWaste;
            port surfaceExchange : Oxygen;
        }

        part def AquaticPlants {
            attribute biomass : BiomassValue;
            attribute photosynthesisRate : MassFlowRateValue;
            attribute lightIntensity : Real;

            port outOxygen : Oxygen;
            port inNutrients : Nutrient;

            action photosynthesis : Photosynthesis {
                in lightIntensity = lightIntensity;
                in nutrients = inNutrients.concentration;
                out oxygenProduced = outOxygen.rate;
                out biomassIncrease = biomass;
            }
        }

        part def FishPopulation {
            attribute populationSize : Real;
            attribute oxygenConsumptionRate : MassFlowRateValue;
            attribute wasteProductionRate : MassFlowRateValue;

            port inOxygen : Oxygen;
            port outWaste : OrganicWaste;

            action respiration : Respiration {
                in oxygenAvailable = inOxygen.rate;
                out oxygenConsumed = oxygenConsumptionRate;
                out wasteProduced = outWaste.massRate;
            }
        }

        part def MicrobialCommunity {
            attribute decompositionRate : MassFlowRateValue;

            port inOrganicMatter : Biomass;
            port outNutrients : Nutrient;

            action decomposition : Decomposition {
                in organicMatter = inOrganicMatter.mass;
                out nutrientsReleased = outNutrients.concentration;
            }
        }

        part def SedimentLayer {
            attribute organicMatter : BiomassValue;
            attribute nutrientReservoir : NutrientLevelValue;

            port inWaste : OrganicWaste;
            port outOrganicMatter : Biomass;
            port outNutrients : Nutrient;
        }

        part def Atmosphere {
            attribute windSpeed : WindSpeedValue;

            out port surfaceExchange : Oxygen;

            action gasExchange : GasExchange {
                in windSpeed = windSpeed;
                out oxygenTransfer = surfaceExchange.rate;
            }
        }

        state def PondHealth {
            in waterDO : DissolvedOxygenValue;
            in nutrients : NutrientLevelValue;
            in ph : pHValue;
            entry; then balanced;
            state balanced;
            state hypoxic;
            state eutrophic;
            state stressed;
            transition toHypoxic : balanced -> hypoxic {
                when waterDO < 2.0[mg_per_L];
            }
            transition toEutrophic : balanced -> eutrophic {
                when nutrients > 10.0[mg_per_L];
            }
            transition toStressed : balanced -> stressed {
                when ph < 6.0 or ph > 8.5;
            }
            transition fromHypoxic : hypoxic -> balanced {
                when waterDO >= 5.0[mg_per_L];
            }
            transition fromEutrophic : eutrophic -> balanced {
                when nutrients <= 5.0[mg_per_L];
            }
            transition fromStressed : stressed -> balanced {
                when ph >= 6.5 and ph <= 8.0;
            }
        }

        part def Pond {
            part water : WaterBody;
            part plants : AquaticPlants;
            part fish : FishPopulation;
            part microbes : MicrobialCommunity;
            part sediment : SedimentLayer;
            part atmosphere : Atmosphere;

            connect plants.outOxygen to water.inOxygen;
            connect water.outOxygen to fish.inOxygen;
            connect fish.outWaste to sediment.inWaste;
            connect sediment.outOrganicMatter to microbes.inOrganicMatter;
            connect microbes.outNutrients to water.inNutrients;
            connect water.outNutrients to plants.inNutrients;
            connect atmosphere.surfaceExchange to water.surfaceExchange;

            exhibit state pondHealth : PondHealth {
                in waterDO = water.dissolvedOxygen;
                in nutrients = water.nutrientLevel;
                in ph = water.pH;
            }
        }
    }

    package Requirements {
        private import Units::*;
        private import PartDefinitions::*;
        requirement def BalancedPondRequirement {
            subject pond : Pond;
            constraint balancedDO {
                pond.water.dissolvedOxygen >= 5.0[mg_per_L];
            }
            constraint balancedpH {
                pond.water.pH >= 6.5 and pond.water.pH <= 8.0;
            }
            constraint balancedNutrients {
                pond.water.nutrientLevel <= 5.0[mg_per_L];
            }
        }
    }

    package PondSystem {
        private import PartDefinitions::*;
        private import Requirements::*;

        part myPond : Pond {
            satisfy balancedReq : BalancedPondRequirement;
        }
    }
}
