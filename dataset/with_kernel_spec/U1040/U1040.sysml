package 'Terrestrial Ecosystem Model' {
    private import ScalarValues::*;
    private import SI::kg;
    private import SI::J;
    private import SI::m;
    private import SI::L;
    
    // Item Definitions
    item def SolarEnergy {
        attribute amount: J;
    }
    item def Biomass {
        attribute mass: kg;
    }
    item def Nutrient {
        attribute mass: kg;
    }
    item def Water {
        attribute volume: L;
    }
    item def Gas {
        attribute type: String;
        attribute volume: L;
    }
    item def Waste {
        attribute mass: kg;
    }
    item def DeadOrganicMatter {
        attribute mass: kg;
    }
    
    // Port Definitions
    port def EnergyOutPort { out energy: SolarEnergy; }
    port def EnergyInPort { in energy: SolarEnergy; }
    port def BiomassOutPort { out biomass: Biomass; }
    port def BiomassInPort { in biomass: Biomass; }
    port def NutrientOutPort { out nutrient: Nutrient; }
    port def NutrientInPort { in nutrient: Nutrient; }
    port def WaterOutPort { out water: Water; }
    port def WaterInPort { in water: Water; }
    port def GasExchangePort { inout gas: Gas; }
    port def WasteOutPort { out waste: Waste; }
    port def WasteInPort { in waste: Waste; }
    port def DeadMatterOutPort { out deadMatter: DeadOrganicMatter; }
    port def DeadMatterInPort { in deadMatter: DeadOrganicMatter; }
    
    // Part Definitions
    part def Producer {
        attribute species: String;
        port energyIn: EnergyInPort;
        port waterIn: WaterInPort;
        port nutrientIn: NutrientInPort;
        port gas: GasExchangePort;
        port biomassOut: BiomassOutPort;
        
        action photosynthesis {
            in solarEnergy: SolarEnergy;
            in water: Water;
            in nutrients: Nutrient;
            out biomass: Biomass;
            out oxygen: Gas;
            in carbonDioxide: Gas;
        }
    }
    
    part def Consumer {
        attribute species: String;
        attribute dietType: String;
        port biomassIn: BiomassInPort;
        port biomassOut: BiomassOutPort;
        port gas: GasExchangePort;
        port wasteOut: WasteOutPort;
        port deadMatterOut: DeadMatterOutPort;
        
        action consume {
            in food: Biomass;
            out waste: Waste;
            out deadMatter: DeadOrganicMatter;
            out carbonDioxide: Gas;
            in oxygen: Gas;
        }
    }
    
    part def Decomposer {
        attribute species: String;
        port wasteIn: WasteInPort;
        port deadMatterIn: DeadMatterInPort;
        port nutrientOut: NutrientOutPort;
        port gas: GasExchangePort;
        
        action decompose {
            in waste: Waste;
            in deadMatter: DeadOrganicMatter;
            out nutrients: Nutrient;
            out carbonDioxide: Gas;
            in oxygen: Gas;
        }
    }
    
    part def Soil {
        port waterOut: WaterOutPort;
        port nutrientOut: NutrientOutPort;
        port waterIn: WaterInPort;
        port nutrientIn: NutrientInPort;
        
        attribute waterReservoir: L;
        attribute nutrientReservoir: kg;
    }
    
    part def Atmosphere {
        port gasExchange: GasExchangePort;
        port waterOut: WaterOutPort;
        port waterIn: WaterInPort;
        attribute co2Level: L;
        attribute o2Level: L;
    }
    
    // Requirements
    requirement def SustainLifeRequirement {
        doc /* The ecosystem must sustain life by capturing solar energy. */
    }
    requirement def CycleNutrientsRequirement {
        doc /* The ecosystem must cycle essential nutrients. */
    }
    requirement def SupportFoodWebRequirement {
        doc /* The ecosystem must support a structured food web. */
    }
    
    requirement sustainLifeReq : SustainLifeRequirement;
    requirement cycleNutrientsReq : CycleNutrientsRequirement;
    requirement supportFoodWebReq : SupportFoodWebRequirement;
    
    // Ecosystem State Machine Definition
    state machine def EcosystemState {
        state Growing;
        state Balanced;
        state Declining;
        transition from Growing to Balanced when resourceAvailability == 1.0;
        transition from Balanced to Declining when resourceAvailability < 0.5;
        transition from Declining to Growing when resourceAvailability > 0.8;
    }
    
    // Top-level Ecosystem
    part def TerrestrialEcosystem {
        attribute resourceAvailability: Real = 1.0;
        
        part sun {
            port energyOut: EnergyOutPort;
        }
        part producers: Producer[1..*];
        part primaryConsumers: Consumer[1..*] {
            :>> dietType = "Herbivore";
        }
        part secondaryConsumers: Consumer[1..*] {
            :>> dietType = "Carnivore";
        }
        part decomposers: Decomposer[1..*];
        part soil: Soil;
        part atmosphere: Atmosphere;
        
        // Connections - Energy Flow
        connect sun.energyOut to producers.energyIn;
        
        // Connections - Food Web
        connect producers.biomassOut to primaryConsumers.biomassIn;
        connect primaryConsumers.biomassOut to secondaryConsumers.biomassIn;
        
        // Connections - Waste and Dead Matter
        connect primaryConsumers.wasteOut to decomposers.wasteIn;
        connect secondaryConsumers.wasteOut to decomposers.wasteIn;
        connect primaryConsumers.deadMatterOut to decomposers.deadMatterIn;
        connect secondaryConsumers.deadMatterOut to decomposers.deadMatterIn;
        
        // Connections - Nutrient Cycling
        connect decomposers.nutrientOut to soil.nutrientIn;
        connect soil.nutrientOut to producers.nutrientIn;
        
        // Connections - Water Cycling
        connect atmosphere.waterOut to soil.waterIn;
        connect soil.waterOut to producers.waterIn;
        
        // Connections - Gas Exchange
        connect producers.gas to atmosphere.gasExchange;
        connect primaryConsumers.gas to atmosphere.gasExchange;
        connect secondaryConsumers.gas to atmosphere.gasExchange;
        connect decomposers.gas to atmosphere.gasExchange;
        
        // Ecosystem Behavior - Population Regulation
        exhibit ecosystemState : EcosystemState;
    }
    
    part ecosystem: TerrestrialEcosystem {
        satisfy sustainLifeReq;
        satisfy cycleNutrientsReq;
        satisfy supportFoodWebReq;
    }
}
