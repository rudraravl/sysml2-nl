package TerrestrialEcosystem {

  // ===== Units =====
  unit kg;
  unit J;
  unit W;
  unit K;
  unit m3;
  unit individuals;
  unit perDay;

  // ===== Value Types =====
  value type Mass :> Real { unit kg; }
  value type Energy :> Real { unit J; }
  value type Power :> Real { unit W; }
  value type Temperature :> Real { unit K; }
  value type Volume :> Real { unit m3; }
  value type Population :> Real { unit individuals; }
  value type Rate :> Real { unit perDay; }
  value type Ratio :> Real;

  // ===== Item Types =====
  item def SolarRadiation {
    attribute intensity : Power;
  }

  item def Water {
    attribute volume : Volume;
  }

  item def Nutrient {
    attribute mass : Mass;
  }

  item def Nitrogen :> Nutrient {}
  item def Phosphorus :> Nutrient {}

  item def OrganicMatter {
    attribute biomass : Mass;
    attribute energyContent : Energy;
  }

  item def Food :> OrganicMatter {}

  item def Waste {
    attribute mass : Mass;
    attribute nitrogenContent : Mass;
    attribute phosphorusContent : Mass;
  }

  item def DeadOrganicMatter {
    attribute biomass : Mass;
    attribute nitrogenContent : Mass;
    attribute phosphorusContent : Mass;
  }

  item def Oxygen {
    attribute volume : Volume;
  }

  item def CarbonDioxide {
    attribute volume : Volume;
  }

  // ===== Port Definitions =====
  port def SolarInputPort {
    in radiation : SolarRadiation;
  }

  port def NutrientOutputPort {
    out nutrients : Nutrient[0..*];
  }

  port def NutrientInputPort {
    in nutrients : Nutrient[0..*];
  }

  port def WaterOutputPort {
    out water : Water;
  }

  port def WaterInputPort {
    in water : Water;
  }

  port def GasExchangePort {
    in co2Absorbed : CarbonDioxide;
    out co2Released : CarbonDioxide;
    in o2Absorbed : Oxygen;
    out o2Released : Oxygen;
  }

  port def BiomassOutputPort {
    out biomass : OrganicMatter;
  }

  port def FoodInputPort {
    in food : OrganicMatter;
  }

  port def WasteOutputPort {
    out waste : Waste;
  }

  port def WasteInputPort {
    in waste : Waste;
  }

  port def DeadMatterOutputPort {
    out deadMatter : DeadOrganicMatter;
  }

  port def DeadMatterInputPort {
    in deadMatter : DeadOrganicMatter;
  }

  // ===== Action Definitions =====
  action def Photosynthesis {
    in solarRadiation : SolarRadiation;
    in water : Water;
    in nutrients : Nutrient[0..*];
    in carbonDioxide : CarbonDioxide;
    out biomass : OrganicMatter;
    out oxygen : Oxygen;
  }

  action def Respiration {
    in oxygen : Oxygen;
    in biomass : OrganicMatter;
    out carbonDioxide : CarbonDioxide;
    out energy : Energy;
    out waste : Waste;
  }

  action def Consumption {
    in food : OrganicMatter;
    out biomass : OrganicMatter;
    out energy : Energy;
    out waste : Waste;
  }

  action def Decomposition {
    in deadMatter : DeadOrganicMatter;
    in waste : Waste;
    out nitrogen : Nitrogen;
    out phosphorus : Phosphorus;
    out carbonDioxide : CarbonDioxide;
  }

  action def Transpiration {
    in water : Water;
    out waterVapor : Water;
  }

  action def Predation {
    in preyBiomass : OrganicMatter;
    out consumedBiomass : OrganicMatter;
    out waste : Waste;
  }

  // ===== Requirement Definitions =====
  requirement def EcosystemSustainabilityRequirement {
    doc "The ecosystem must sustain life by capturing solar energy, cycling nutrients, and supporting a food web.";
    subject ecosystem : TerrestrialEcosystem;
    attribute minBiomass : Mass = 1000;
    predicate { ecosystem.totalBiomass >= minBiomass }
  }

  requirement def EnergyFlowRequirement {
    doc "Energy must flow from the sun through producers to consumers at each trophic level.";
    subject ecosystem : TerrestrialEcosystem;
    attribute minProducerBiomass : Mass = 500;
    predicate { ecosystem.producers.totalBiomass >= minProducerBiomass }
  }

  requirement def NutrientCyclingRequirement {
    doc "Nutrients must be recycled through decomposition back to producers.";
    subject ecosystem : TerrestrialEcosystem;
    attribute minSoilNitrogen : Mass = 50;
    predicate { ecosystem.soil.nitrogenContent >= minSoilNitrogen }
  }

  requirement def PopulationRegulationRequirement {
    doc "Population sizes must be regulated based on resource availability, birth rates, and mortality.";
    subject ecosystem : TerrestrialEcosystem;
    attribute maxPopulationGrowthRate : Rate = 0.1;
    predicate { ecosystem.producers.growthRate <= maxPopulationGrowthRate }
  }

  requirement def GasExchangeRequirement {
    doc "The atmosphere must facilitate exchange of oxygen and carbon dioxide for photosynthesis and respiration.";
    subject ecosystem : TerrestrialEcosystem;
    attribute minO2Concentration : Real = 0.19;
    predicate { ecosystem.atmosphere.oxygenConcentration >= minO2Concentration }
  }

  // ===== Part Definitions =====

  part def Sun {
    port solarOutput : SolarInputPort;
    attribute luminosity : Power = 3.828e26;
    attribute surfaceTemperature : Temperature = 5778;

    action emitRadiation {
      out radiation : SolarRadiation;
    }
  }

  part def Producer {
    port solarIn : SolarInputPort;
    port nutrientIn : NutrientInputPort;
    port waterIn : WaterInputPort;
    port gasExchange : GasExchangePort;
    port biomassOut : BiomassOutputPort;
    port wasteOut : WasteOutputPort;
    port deadMatterOut : DeadMatterOutputPort;

    attribute population : Population;
    attribute totalBiomass : Mass;
    attribute growthRate : Rate;
    attribute mortalityRate : Rate;
    attribute photosyntheticEfficiency : Ratio = 0.02;

    action photosynthesize : Photosynthesis;
    action respire : Respiration;
    action transpire : Transpiration;

    state lifeCycle {
      state Seedling {
        entry action germinate;
        do photosynthesize;
        do respire;
        transition to Sapling;
      }
      state Sapling {
        do photosynthesize;
        do respire;
        do transpire;
        transition to Mature;
      }
      state Mature {
        do photosynthesize;
        do respire;
        do transpire;
        do action reproduce;
        transition to Senescent;
      }
      state Senescent {
        entry action senesce;
        do action die;
        transition to Dead;
      }
      state Dead {
        entry action shedBiomass;
      }
    }
  }

  part def PrimaryConsumer {
    port foodIn : FoodInputPort;
    port gasExchange : GasExchangePort;
    port biomassOut : BiomassOutputPort;
    port wasteOut : WasteOutputPort;
    port deadMatterOut : DeadMatterOutputPort;

    attribute population : Population;
    attribute totalBiomass : Mass;
    attribute birthRate : Rate;
    attribute mortalityRate : Rate;
    attribute energyReserves : Energy;
    attribute metabolicRate : Rate;

    action consume : Consumption;
    action respire : Respiration;

    state lifeCycle {
      state Juvenile {
        entry action hatch;
        do consume;
        do respire;
        transition to Adult;
      }
      state Adult {
        do consume;
        do respire;
        do action reproduce;
        transition to Elderly;
      }
      state Elderly {
        do consume;
        do respire;
        transition to Dead;
      }
      state Dead {
        entry action expire;
      }
    }
  }

  part def SecondaryConsumer {
    port foodIn : FoodInputPort;
    port gasExchange : GasExchangePort;
    port biomassOut : BiomassOutputPort;
    port wasteOut : WasteOutputPort;
    port deadMatterOut : DeadMatterOutputPort;

    attribute population : Population;
    attribute totalBiomass : Mass;
    attribute birthRate : Rate;
    attribute mortalityRate : Rate;
    attribute energyReserves : Energy;
    attribute metabolicRate : Rate;
    attribute huntingEfficiency : Ratio = 0.3;

    action hunt : Predation;
    action consume : Consumption;
    action respire : Respiration;

    state lifeCycle {
      state Juvenile {
        entry action fledge;
        do consume;
        do respire;
        transition to Adult;
      }
      state Adult {
        do hunt;
        do consume;
        do respire;
        do action reproduce;
        transition to Elderly;
      }
      state Elderly {
        do hunt;
        do consume;
        do respire;
        transition to Dead;
      }
      state Dead {
        entry action expire;
      }
    }
  }

  part def Decomposer {
    port deadMatterIn : DeadMatterInputPort;
    port wasteIn : WasteInputPort;
    port nutrientOut : NutrientOutputPort;
    port gasExchange : GasExchangePort;

    attribute population : Population;
    attribute activityLevel : Rate;
    attribute decompositionEfficiency : Ratio = 0.85;

    action decompose : Decomposition;
    action respire : Respiration;

    state activityCycle {
      state Active {
        entry action activate;
        do decompose;
        do respire;
        transition to Dormant;
      }
      state Dormant {
        entry action deactivate;
        transition to Active;
      }
    }
  }

  part def Soil {
    port nutrientOutput : NutrientOutputPort;
    port nutrientInput : NutrientInputPort;
    port waterOutput : WaterOutputPort;
    port waterInput : WaterInputPort;
    port deadMatterIn : DeadMatterInputPort;

    attribute waterContent : Volume;
    attribute nitrogenContent : Mass;
    attribute phosphorusContent : Mass;
    attribute organicContent : Mass;
    attribute porosity : Ratio = 0.5;
    attribute pH : Real = 6.5;

    action storeNutrients;
    action releaseNutrients;
    action storeWater;
    action releaseWater;
    action accumulateDeadMatter;
  }

  part def Atmosphere {
    port gasExchange : GasExchangePort;
    port waterOutput : WaterOutputPort;
    port waterInput : WaterInputPort;

    attribute oxygenConcentration : Real = 0.21;
    attribute carbonDioxideConcentration : Real = 0.04;
    attribute nitrogenConcentration : Real = 0.78;
    attribute temperature : Temperature = 288;
    attribute humidity : Ratio = 0.5;

    action circulateGases;
    action precipitate;
    action evaporate;
  }

  // ===== Ecosystem Assembly =====
  part def TerrestrialEcosystem {
    requirement sustainabilityReq : EcosystemSustainabilityRequirement;
    requirement energyFlowReq : EnergyFlowRequirement;
    requirement nutrientCyclingReq : NutrientCyclingRequirement;
    requirement populationRegReq : PopulationRegulationRequirement;
    requirement gasExchangeReq : GasExchangeRequirement;

    attribute totalBiomass : Mass;
    attribute biodiversityIndex : Ratio;
    attribute energyThroughput : Power;

    part sun : Sun {}

    part producers : Producer[0..*] {}

    part primaryConsumers : PrimaryConsumer[0..*] {}

    part secondaryConsumers : SecondaryConsumer[0..*] {}

    part decomposers : Decomposer[0..*] {}

    part soil : Soil {}

    part atmosphere : Atmosphere {}

    // Solar energy flow
    connection sun.solarOutput to producers.solarIn;

    // Food web: producers to primary consumers
    connection producers.biomassOut to primaryConsumers.foodIn;

    // Food web: primary consumers to secondary consumers
    connection primaryConsumers.biomassOut to secondaryConsumers.foodIn;

    // Waste to decomposers
    connection producers.wasteOut to decomposers.wasteIn;
    connection primaryConsumers.wasteOut to decomposers.wasteIn;
    connection secondaryConsumers.wasteOut to decomposers.wasteIn;

    // Dead matter to decomposers
    connection producers.deadMatterOut to decomposers.deadMatterIn;
    connection primaryConsumers.deadMatterOut to decomposers.deadMatterIn;
    connection secondaryConsumers.deadMatterOut to decomposers.deadMatterIn;

    // Dead matter to soil for organic accumulation
    connection producers.deadMatterOut to soil.deadMatterIn;

    // Nutrient cycling: decomposers to soil
    connection decomposers.nutrientOut to soil.nutrientInput;

    // Nutrient cycling: soil to producers
    connection soil.nutrientOutput to producers.nutrientIn;

    // Water cycling: soil to producers
    connection soil.waterOutput to producers.waterIn;

    // Water cycling: atmosphere to soil (precipitation)
    connection atmosphere.waterOutput to soil.waterInput;

    // Water cycling: soil to atmosphere (evaporation)
    connection soil.waterOutput to atmosphere.waterInput;

    // Gas exchange: producers to atmosphere
    connection producers.gasExchange to atmosphere.gasExchange;

    // Gas exchange: primary consumers to atmosphere
    connection primaryConsumers.gasExchange to atmosphere.gasExchange;

    // Gas exchange: secondary consumers to atmosphere
    connection secondaryConsumers.gasExchange to atmosphere.gasExchange;

    // Gas exchange: decomposers to atmosphere
    connection decomposers.gasExchange to atmosphere.gasExchange;

    // Ecosystem-level state machine
    state ecosystemDynamics {
      state Balanced {
        entry action initializeBalance;
        do action regulatePopulations;
        do action cycleNutrients;
        do action flowEnergy;
        do action exchangeGases;
        transition to Stressed when resourceShortage;
      }
      state Stressed {
        entry action detectStress;
        do action reducePopulations;
        do action conserveResources;
        transition to Recovering when conditionsImprove;
      }
      state Recovering {
        entry action beginRecovery;
        do action restorePopulations;
        do action rebuildNutrientReserves;
        transition to Balanced when balanceRestored;
      }
    }
  }
}
