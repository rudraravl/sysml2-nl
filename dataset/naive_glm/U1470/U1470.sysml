package PondEcosystem {
    import ScalarValues::*;

    // ===== Units =====
    unit cubicMetre;
    unit milligramPerLitre;
    unit degreeCelsius;
    unit metrePerSecond;
    unit kilogram;
    unit squareMetre;
    unit metre;
    unit milligramPerLitrePerHour;

    // ===== Value Types =====
    value def Volume :> Real { unit cubicMetre; }
    value def Concentration :> Real { unit milligramPerLitre; }
    value def Temperature :> Real { unit degreeCelsius; }
    value def pHValue :> Real;
    value def WindSpeed :> Real { unit metrePerSecond; }
    value def Mass :> Real { unit kilogram; }
    value def Area :> Real { unit squareMetre; }
    value def Length :> Real { unit metre; }
    value def Rate :> Real { unit milligramPerLitrePerHour; }

    // ===== Item Definitions =====
    item def Oxygen;
    item def CarbonDioxide;
    item def Sunlight;
    item def Biomass;
    item def OrganicWaste;
    item def Nitrogen;
    item def Phosphorus;

    item def Nutrient {
        item nitrogen : Nitrogen;
        item phosphorus : Phosphorus;
    }

    // ===== Port Definitions =====
    port def OxygenOutPort { out item oxygen : Oxygen; }
    port def OxygenInPort { in item oxygen : Oxygen; }
    port def NutrientOutPort { out item nutrient : Nutrient; }
    port def NutrientInPort { in item nutrient : Nutrient; }
    port def WasteOutPort { out item waste : OrganicWaste; }
    port def WasteInPort { in item waste : OrganicWaste; }
    port def BiomassOutPort { out item biomass : Biomass; }
    port def BiomassInPort { in item biomass : Biomass; }
    port def SunlightInPort { in item sunlight : Sunlight; }
    port def SunlightOutPort { out item sunlight : Sunlight; }
    port def GasExchangePort {
        inout item oxygen : Oxygen;
        inout item carbonDioxide : CarbonDioxide;
    }

    // ===== Action Definitions =====
    action def Photosynthesis {
        in item sunlight : Sunlight;
        in item nitrogen : Nitrogen;
        in item phosphorus : Phosphorus;
        out item oxygen : Oxygen;
        out item biomass : Biomass;
        attribute rate : Rate;
    }

    action def Respiration {
        in item oxygen : Oxygen;
        in item biomass : Biomass;
        out item waste : OrganicWaste;
        out item carbonDioxide : CarbonDioxide;
        attribute rate : Rate;
    }

    action def Decomposition {
        in item waste : OrganicWaste;
        out item nitrogen : Nitrogen;
        out item phosphorus : Phosphorus;
        attribute rate : Rate;
    }

    action def GasExchange {
        in windSpeed : WindSpeed;
        in surfaceArea : Area;
        inout item oxygen : Oxygen;
        inout item carbonDioxide : CarbonDioxide;
        attribute transferRate : Rate;
    }

    action def NutrientRelease {
        in item waste : OrganicWaste;
        out item nitrogen : Nitrogen;
        out item phosphorus : Phosphorus;
        attribute releaseRate : Rate;
    }

    // ===== Part Definitions =====
    part def WaterBody {
        attribute volume : Volume;
        attribute dissolvedOxygen : Concentration;
        attribute pH : pHValue;
        attribute temperature : Temperature;
        attribute nitrogenLevel : Concentration;
        attribute phosphorusLevel : Concentration;

        port oxygenIn : OxygenInPort;
        port oxygenOut : OxygenOutPort;
        port nutrientIn : NutrientInPort;
        port nutrientOut : NutrientOutPort;
        port wasteIn : WasteInPort;
        port gasExchange : GasExchangePort;
        port sunlightOut : SunlightOutPort;

        action def UpdateQuality {
            in deltaOxygen : Concentration;
            in deltaNitrogen : Concentration;
            in deltaPhosphorus : Concentration;
            out updatedOxygen : Concentration;
            out updatedNitrogen : Concentration;
            out updatedPhosphorus : Concentration;
        }
    }

    part def AquaticPlants {
        attribute totalBiomass : Mass;
        attribute photosynthesisRate : Rate;
        attribute speciesCount : Integer;

        port sunlightIn : SunlightInPort;
        port oxygenOut : OxygenOutPort;
        port nutrientIn : NutrientInPort;
        port biomassOut : BiomassOutPort;

        action photosynthesize : Photosynthesis;
    }

    part def FishPopulation {
        attribute populationCount : Integer;
        attribute averageMass : Mass;
        attribute respirationRate : Rate;

        port oxygenIn : OxygenInPort;
        port wasteOut : WasteOutPort;
        port biomassIn : BiomassInPort;

        action respire : Respiration;
    }

    part def MicrobialCommunity {
        attribute populationDensity : Real;
        attribute decompositionRate : Rate;

        port wasteIn : WasteInPort;
        port nutrientOut : NutrientOutPort;

        action decompose : Decomposition;
    }

    part def SedimentLayer {
        attribute thickness : Length;
        attribute organicContent : Mass;
        attribute nitrogenReservoir : Concentration;
        attribute phosphorusReservoir : Concentration;

        port wasteIn : WasteInPort;
        port nutrientOut : NutrientOutPort;

        action releaseNutrients : NutrientRelease;
    }

    part def AtmosphereInterface {
        attribute windSpeed : WindSpeed;
        attribute surfaceArea : Area;
        attribute atmosphericOxygen : Concentration;

        port gasExchange : GasExchangePort;

        action exchangeGases : GasExchange;
    }

    // ===== State Machine Definition =====
    state def PondHealth {
        attribute dissolvedOxygen : Concentration;
        attribute pH : pHValue;
        attribute nutrientLevel : Concentration;

        state balanced {
            doc /* All life thrives; oxygen, nutrients, and pH are within optimal ranges. */
        }

        state hypoxic {
            doc /* Dissolved oxygen is too low to support aquatic life. */
        }

        state eutrophic {
            doc /* Excessive nutrients lead to algae blooms and oxygen depletion. */
        }

        state stressed {
            doc /* pH is outside the acceptable range, stressing organisms. */
        }

        transition balanced_to_hypoxic
            first balanced then hypoxic
            when dissolvedOxygen < 3.0;

        transition balanced_to_eutrophic
            first balanced then eutrophic
            when nutrientLevel > 10.0;

        transition balanced_to_stressed
            first balanced then stressed
            when pH < 6.5 or pH > 8.5;

        transition hypoxic_to_balanced
            first hypoxic then balanced
            when dissolvedOxygen > 6.0;

        transition eutrophic_to_balanced
            first eutrophic then balanced
            when nutrientLevel < 5.0;

        transition stressed_to_balanced
            first stressed then balanced
            when pH >= 6.5 and pH <= 8.5;

        transition hypoxic_to_eutrophic
            first hypoxic then eutrophic
            when nutrientLevel > 10.0;

        transition eutrophic_to_hypoxic
            first eutrophic then hypoxic
            when dissolvedOxygen < 2.0;

        transition stressed_to_hypoxic
            first stressed then hypoxic
            when dissolvedOxygen < 3.0;
    }

    // ===== Connection Definitions =====
    connection def OxygenFlowConnection {
        end supplier : OxygenOutPort;
        end consumer : OxygenInPort;
    }

    connection def NutrientFlowConnection {
        end supplier : NutrientOutPort;
        end consumer : NutrientInPort;
    }

    connection def WasteFlowConnection {
        end supplier : WasteOutPort;
        end consumer : WasteInPort;
    }

    connection def BiomassFlowConnection {
        end supplier : BiomassOutPort;
        end consumer : BiomassInPort;
    }

    connection def SunlightFlowConnection {
        end supplier : SunlightOutPort;
        end consumer : SunlightInPort;
    }

    connection def GasExchangeConnection {
        end side1 : GasExchangePort;
        end side2 : GasExchangePort;
    }

    // ===== Main Pond System =====
    part def Pond {
        attribute name : String;
        attribute volume : Volume;
        attribute surfaceArea : Area;
        attribute maxDepth : Length;

        part waterBody : WaterBody;
        part plants : AquaticPlants;
        part fish : FishPopulation;
        part microbes : MicrobialCommunity;
        part sediment : SedimentLayer;
        part atmosphere : AtmosphereInterface;

        state health : PondHealth;

        connection sunlightToPlants : SunlightFlowConnection
            connect waterBody.sunlightOut to plants.sunlightIn;

        connection plantsOxygenToWater : OxygenFlowConnection
            connect plants.oxygenOut to waterBody.oxygenIn;

        connection waterNutrientsToPlants : NutrientFlowConnection
            connect waterBody.nutrientOut to plants.nutrientIn;

        connection plantsBiomassToFish : BiomassFlowConnection
            connect plants.biomassOut to fish.biomassIn;

        connection waterOxygenToFish : OxygenFlowConnection
            connect waterBody.oxygenOut to fish.oxygenIn;

        connection fishWasteToMicrobes : WasteFlowConnection
            connect fish.wasteOut to microbes.wasteIn;

        connection fishWasteToSediment : WasteFlowConnection
            connect fish.wasteOut to sediment.wasteIn;

        connection microbesNutrientsToWater : NutrientFlowConnection
            connect microbes.nutrientOut to waterBody.nutrientIn;

        connection sedimentNutrientsToWater : NutrientFlowConnection
            connect sediment.nutrientOut to waterBody.nutrientIn;

        connection gasExchangeWithAtmosphere : GasExchangeConnection
            connect waterBody.gasExchange to atmosphere.gasExchange;
    }

    // ===== Requirements =====
    requirement def PondEcosystemRequirement {
        doc /* The pond ecosystem shall function as a self-regulating aquatic environment. */
        subject pond : Pond;

        requirement WaterQualityRequirement {
            doc /* The water body shall maintain quality metrics within life-supporting ranges. */
            subject waterBody : WaterBody;

            requirement DissolvedOxygenRequirement {
                doc /* Dissolved oxygen shall remain above 5 mg/L for balanced conditions. */
                constraint { waterBody.dissolvedOxygen >= 5.0 }
            }

            requirement pHRangeRequirement {
                doc /* pH shall remain between 6.5 and 8.5. */
                constraint { waterBody.pH >= 6.5 and waterBody.pH <= 8.5 }
            }

            requirement TemperatureRangeRequirement {
                doc /* Water temperature shall remain between 4 and 30 degrees Celsius. */
                constraint { waterBody.temperature >= 4.0 and waterBody.temperature <= 30.0 }
            }

            requirement NutrientLevelRequirement {
                doc /* Nutrient levels shall remain below eutrophic thresholds. */
                constraint { waterBody.nitrogenLevel < 10.0 and waterBody.phosphorusLevel < 10.0 }
            }
        }

        requirement OxygenCycleRequirement {
            doc /* Aquatic plants shall produce oxygen via photosynthesis to replenish dissolved oxygen. */
            subject plants : AquaticPlants;
            constraint { plants.photosynthesisRate > 0.0 }
        }

        requirement NutrientCycleRequirement {
            doc /* Microbial decomposition shall recycle nitrogen and phosphorus from organic waste. */
            subject microbes : MicrobialCommunity;
            constraint { microbes.decompositionRate > 0.0 }
        }

        requirement SedimentReservoirRequirement {
            doc /* The sediment layer shall serve as a reservoir for organic matter and nutrients. */
            subject sediment : SedimentLayer;
            constraint { sediment.thickness > 0.0 and sediment.organicContent >= 0.0 }
        }

        requirement GasExchangeRequirement {
            doc /* The atmosphere interface shall replenish oxygen based on wind speed. */
            subject atmosphere : AtmosphereInterface;
            constraint { atmosphere.windSpeed >= 0.0 }
        }

        requirement HealthStateRequirement {
            doc /* The pond shall maintain a balanced health state under normal conditions. */
            subject pond : Pond;
            constraint { pond.waterBody.dissolvedOxygen >= 5.0 and pond.waterBody.pH >= 6.5 and pond.waterBody.pH <= 8.5 }
        }

        requirement RecoveryRequirement {
            doc /* The pond shall have natural pathways to recover from degraded states to balanced. */
            subject pond : Pond;
            constraint { pond.waterBody.dissolvedOxygen >= 0.0 }
        }
    }
}
