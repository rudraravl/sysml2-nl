package PondEcosystemSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterQualityMetrics {
        attribute dissolvedOxygen : Real;
        attribute pH : Real;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute turbidity : Real;
        attribute nitrogenLevel : Real;
        attribute phosphorusLevel : Real;
    }
    
    item def WaterVolume {
        attribute volume : VolumeValue;
        attribute quality : WaterQualityMetrics;
    }
    
    item def NutrientContent {
        attribute nitrogen : Real;
        attribute phosphorus : Real;
        attribute organicMatter : Real;
    }
    
    port def WaterInterface {
        in inflow : WaterVolume;
        out outflow : WaterVolume;
    }
    
    port def OxygenExchange {
        in oxygenInput : Real;
        out oxygenOutput : Real;
    }
    
    port def NutrientPort {
        in nutrientUptake : NutrientContent;
        out nutrientRelease : NutrientContent;
    }
    
    part def AquaticPlants {
        attribute biomass : MassValue;
        attribute growthRate : Real;
        attribute photosynthesisRate : Real;
        
        port oxygenProduction : OxygenExchange;
        port nutrientAbsorption : NutrientPort;
        
        action def PerformPhotosynthesis {
            in lightIntensity : Real;
            in co2Available : Real;
            in nutrients : NutrientContent;
            out oxygenProduced : Real;
            out biomassIncrease : MassValue;
        }
    }
    
    part def FishPopulation {
        attribute count : Integer;
        attribute totalBiomass : MassValue;
        attribute metabolicRate : Real;
        
        port oxygenConsumption : OxygenExchange;
        port wasteOutput : NutrientPort;
        
        action def Respire {
            in oxygenAvailable : Real;
            in biomass : MassValue;
            out oxygenConsumed : Real;
            out wasteProduced : NutrientContent;
        }
    }
    
    part def MicrobialCommunity {
        attribute population : Real;
        attribute decompositionRate : Real;
        
        port organicIntake : NutrientPort;
        port nutrientOutput : NutrientPort;
        
        action def DecomposeOrganicMatter {
            in organicMatter : Real;
            in oxygenPresent : Real;
            out nutrientsReleased : NutrientContent;
            out co2Released : Real;
        }
    }
    
    part def SedimentLayer {
        attribute depth : LengthValue;
        attribute organicContent : Real;
        attribute nutrientReserve : NutrientContent;
        
        port sedimentExchange : NutrientPort;
    }
    
    part def AtmosphericInterface {
        attribute windSpeed : SpeedValue;
        attribute airTemperature : ThermodynamicTemperatureValue;
        
        port gasExchange : OxygenExchange;
        
        action def FacilitateGasExchange {
            in surfaceArea : AreaValue;
            in windSpeed : SpeedValue;
            in waterOxygenLevel : Real;
            out oxygenTransfer : Real;
        }
    }
    
    part def SolarRadiation {
        attribute intensity : Real;
        attribute dailyDuration : TimeValue;
        
        action def ProvideLight {
            in timeOfDay : TimeValue;
            out lightIntensity : Real;
        }
    }
    
    state def EcosystemHealthState {
        entry; then balanced;
        
        state balanced {
            doc /* Ecosystem is in equilibrium with healthy oxygen and nutrient levels */
        }
        accept at when dissolvedOxygen < 4.0 then hypoxic;
        accept at when nitrogenLevel > 15.0 then eutrophic;
        accept at when pH < 6.0 or pH > 9.0 then stressed;
        
        state hypoxic {
            doc /* Low oxygen conditions threatening aquatic life */
            entry assign fishStress := true;
            accept at when dissolvedOxygen >= 5.0 then recovering;
        }
        
        state eutrophic {
            doc /* Excessive nutrients causing algal blooms */
            entry assign algaeBloom := true;
            accept at when nitrogenLevel <= 10.0 and phosphorusLevel <= 1.0 then recovering;
        }
        
        state stressed {
            doc /* pH imbalance affecting ecosystem */
            accept at when pH >= 6.5 and pH <= 8.5 then recovering;
        }
        
        state recovering {
            doc /* Ecosystem returning to balance */
            accept at when dissolvedOxygen >= 6.0 and nitrogenLevel <= 8.0 and pH >= 7.0 and pH <= 8.0 then balanced;
        }
    }
    
    action def RegulateEcosystemCycle {
        first start;
        then merge cycleBegin;
        
        action captureLight : SolarRadiation::ProvideLight {
            in timeOfDay;
            out lightIntensity;
        }
        
        then action plantPhotosynthesize : AquaticPlants::PerformPhotosynthesis {
            in lightIntensity = captureLight.lightIntensity;
            in co2Available;
            in nutrients;
            out oxygenProduced;
            out biomassIncrease;
        }
        
        then action fishRespire : FishPopulation::Respire {
            in oxygenAvailable = plantPhotosynthesize.oxygenProduced;
            in biomass;
            out oxygenConsumed;
            out wasteProduced;
        }
        
        then action microbesDecompose : MicrobialCommunity::DecomposeOrganicMatter {
            in organicMatter;
            in oxygenPresent = plantPhotosynthesize.oxygenProduced;
            out nutrientsReleased;
            out co2Released;
        }
        
        then action atmosphereExchange : AtmosphericInterface::FacilitateGasExchange {
            in surfaceArea;
            in windSpeed;
            in waterOxygenLevel;
            out oxygenTransfer;
        }
        
        then decide;
            if microbesDecompose.nutrientsReleased.nitrogen > 12.0 then reduceNutrientLoad;
            if plantPhotosynthesize.oxygenProduced < 3.0 then increaseOxygenation;
            if fishRespire.oxygenConsumed > 8.0 then maintainBalance;
        
        action reduceNutrientLoad {
            doc /* Initiate processes to reduce excess nutrients */
        }
        then cycleBegin;
        
        action increaseOxygenation {
            doc /* Enhance oxygen production through plant growth */
        }
        then cycleBegin;
        
        action maintainBalance {
            doc /* Continue normal ecosystem cycling */
        }
        then cycleBegin;
    }
    
    part def Pond {
        attribute surfaceArea : AreaValue;
        attribute averageDepth : LengthValue;
        attribute totalVolume : VolumeValue;
        attribute currentWaterLevel : LengthValue;
        
        part waterBody : WaterVolume {
            attribute :>> volume = pond.totalVolume;
            attribute :>> quality {
                attribute :>> dissolvedOxygen = 7.5;
                attribute :>> pH = 7.2;
                attribute :>> temperature = 293.15 [K];
                attribute :>> turbidity = 2.5;
                attribute :>> nitrogenLevel = 5.0;
                attribute :>> phosphorusLevel = 0.3;
            }
        }
        
        part sediment : SedimentLayer {
            attribute :>> depth = 0.3 [m];
            attribute :>> organicContent = 15.0;
        }
        
        part plants : AquaticPlants[10..50] {
            attribute :>> biomass = 25.0 [kg];
            attribute :>> growthRate = 0.05;
            attribute :>> photosynthesisRate = 0.8;
        }
        
        part fish : FishPopulation[1] {
            attribute :>> count = 75;
            attribute :>> totalBiomass = 50.0 [kg];
            attribute :>> metabolicRate = 0.6;
        }
        
        part microbes : MicrobialCommunity[1] {
            attribute :>> population = 1000000.0;
            attribute :>> decompositionRate = 0.4;
        }
        
        ref part atmosphere : AtmosphericInterface;
        ref part sunlight : SolarRadiation;
        
        perform action ecosystemRegulation[*] ordered references RegulateEcosystemCycle {
            in surfaceArea = pond.surfaceArea;
            in biomass = fish.totalBiomass;
        }
        
        state healthState : EcosystemHealthState {
            in dissolvedOxygen = waterBody.quality.dissolvedOxygen;
            in nitrogenLevel = waterBody.quality.nitrogenLevel;
            in phosphorusLevel = waterBody.quality.phosphorusLevel;
            in pH = waterBody.quality.pH;
        }
        
        connection plantOxygenFlow connect plants.oxygenProduction to waterBody;
        connection fishOxygenUse connect fish.oxygenConsumption to waterBody;
        connection atmosphericOxygenExchange connect atmosphere.gasExchange to waterBody;
        connection plantNutrientUptake connect waterBody to plants.nutrientAbsorption;
        connection fishWasteRelease connect fish.wasteOutput to waterBody;
        connection microbialNutrientCycle connect microbes.nutrientOutput to waterBody;
        connection sedimentNutrientExchange connect sediment.sedimentExchange to waterBody;
        connection sunlightToPond connect sunlight to plants;
    }
    
    requirement def EcosystemBalance {
        doc /* The pond ecosystem shall maintain balanced oxygen, nutrient, and pH levels to support aquatic life */
        
        subject pondSystem : Pond;
        
        require constraint oxygenBalance {
            pondSystem.waterBody.quality.dissolvedOxygen >= 5.0 and 
            pondSystem.waterBody.quality.dissolvedOxygen <= 12.0
        }
        
        require constraint pHBalance {
            pondSystem.waterBody.quality.pH >= 6.5 and 
            pondSystem.waterBody.quality.pH <= 8.5
        }
    }
    
    requirement def NutrientRegulation {
        doc /* The pond shall regulate nutrient levels to prevent eutrophication */
        
        subject pondSystem : Pond;
        
        require constraint nitrogenControl {
            pondSystem.waterBody.quality.nitrogenLevel <= 10.0
        }
        
        require constraint phosphorusControl {
            pondSystem.waterBody.quality.phosphorusLevel <= 1.0
        }
    }
    
    requirement def BiodiversityMaintenance {
        doc /* The pond shall support diverse populations of plants, fish, and microorganisms */
        
        subject pondSystem : Pond;
        
        require constraint plantDiversity {
            pondSystem.plants->size() >= 10
        }
        
        require constraint fishPopulation {
            pondSystem.fish.count >= 50
        }
        
        require constraint microbialActivity {
            pondSystem.microbes.population >= 500000.0
        }
    }
    
    requirement pondEcosystemFunction {
        doc /* The pond system shall function as a self-regulating aquatic ecosystem that maintains water quality, supports biodiversity, and cycles nutrients through biological processes */
        
        assume constraint adequateSunlight {
            doc /* Sufficient sunlight must be available for photosynthesis */
        }
        
        assume constraint temperateClimate {
            doc /* Water temperature must remain within viable range for aquatic life */
        }
        
        require ecosystemBalance : EcosystemBalance;
        require nutrientRegulation : NutrientRegulation;
        require biodiversityMaintenance : BiodiversityMaintenance;
    }
    
    part pondEcosystem : Pond {
        :>> surfaceArea = 400.0 [m^2];
        :>> averageDepth = 1.8 [m];
        :>> totalVolume = 720.0 [m^3];
        :>> currentWaterLevel = 1.8 [m];
        
        part :>> atmosphere : AtmosphericInterface {
            :>> windSpeed = 2.5 [m/s];
            :>> airTemperature = 295.15 [K];
        }
        
        part :>> sunlight : SolarRadiation {
            :>> intensity = 750.0;
            :>> dailyDuration = 14.0 [h];
        }
        
        satisfy pondEcosystemFunction by pondEcosystem;
    }
}
