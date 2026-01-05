package 'INTEGER Millennium House System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OccupancyMode;
    attribute def SecurityStatus;
    attribute def VentilationRate;
    attribute def IlluminanceTarget;
    
    alias Temperature for ISQ::ThermodynamicTemperatureValue;
    alias Power for ISQ::PowerValue;
    alias Energy for ISQ::EnergyValue;
    alias AirFlow for ISQ::VolumeFlowValue;
    alias Illuminance for ISQ::LuminousIntensityValue;
    alias CO2Level for Real;
    
    port def EnergyPort {
        out demand : Power;
        in supply : Power;
    }
    
    port def ThermalPort {
        out heatLoad : Power;
        in heatSupply : Power;
    }
    
    port def AirQualityPort {
        out co2Concentration : CO2Level;
        in freshAir : AirFlow;
    }
    
    port def ControlDataPort {
        in sensorData : Real;
        out controlSignal : Real;
    }
    
    part def PassiveHouseEnvelope {
        attribute uValue : Real;
        attribute thermalMass : Energy;
        attribute airtightness : Real;
        
        perform action minimizeHeatTransfer {
            in interiorTemp : Temperature;
            in exteriorTemp : Temperature;
            out heatLoss : Power;
        }
    }
    
    part def PhotovoltaicArray {
        port energyOutput : ~EnergyPort;
        attribute peakCapacity : Power;
        attribute currentEfficiency : Real;
        
        perform action generateElectricity {
            in solarIrradiance : Power;
            out electricalPower : Power;
        }
    }
    
    part def GroundSourceHeatPump {
        port thermalOutput : ~ThermalPort;
        port electricalInput : ~EnergyPort;
        attribute cop : Real;
        attribute capacity : Power;
        
        perform action provideHeating {
            in powerInput : Power;
            in groundTemperature : Temperature;
            out thermalOutput : Power;
        }
        
        perform action provideCooling {
            in powerInput : Power;
            in groundTemperature : Temperature;
            out coolingOutput : Power;
        }
    }
    
    part def MechanicalVentilationHeatRecovery {
        port airQuality : ~AirQualityPort;
        port thermalRecovery : ~ThermalPort;
        attribute heatRecoveryEfficiency : Real;
        attribute airFlowRate : AirFlow;
        
        perform action exchangeAir {
            in exhaustAirTemp : Temperature;
            in supplyAirTemp : Temperature;
            in ventilationRate : AirFlow;
            out recoveredHeat : Power;
            out freshAirSupply : AirFlow;
        }
    }
    
    part def ThermalEnergyStorage {
        port thermalInterface : ~ThermalPort;
        attribute storageCapacity : Energy;
        attribute currentCharge : Energy;
        
        perform action storeEnergy {
            in heatInput : Power;
            in duration : ISQ::DurationValue;
            out storedEnergy : Energy;
        }
        
        perform action releaseEnergy {
            in heatDemand : Power;
            out heatOutput : Power;
        }
    }
    
    part def BuildingManagementSystem {
        port controlInterface : ControlDataPort;
        attribute operatingMode : OccupancyMode;
        attribute energyBudget : Power;
        
        perform action optimizePerformance {
            in occupancyStatus : Boolean;
            in indoorTemp : Temperature;
            in outdoorTemp : Temperature;
            in co2Level : CO2Level;
            in solarGeneration : Power;
            in gridPower : Power;
            out hvacSetpoint : Temperature;
            out ventilationCommand : AirFlow;
            out lightingLevel : Illuminance;
        }
    }
    
    part def RainwaterHarvestingSystem {
        attribute tankCapacity : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        
        perform action collectRainwater {
            in rainfall : ISQ::VolumeValue;
            out harvestedWater : ISQ::VolumeValue;
        }
        
        perform action distributeWater {
            in demand : ISQ::VolumeValue;
            out suppliedWater : ISQ::VolumeValue;
        }
    }
    
    part def TripleGlazedWindows {
        attribute glazingLayers : Integer;
        attribute uValueGlazing : Real;
        attribute solarHeatGainCoefficient : Real;
        
        perform action modulateSolarGain {
            in solarRadiation : Power;
            in blindPosition : Real;
            out transmittedHeat : Power;
            out transmittedLight : Illuminance;
        }
    }
    
    part def LEDLightingSystem {
        port powerInput : ~EnergyPort;
        attribute efficacy : Real;
        attribute dimmingEnabled : Boolean;
        
        perform action provideLighting {
            in powerLevel : Power;
            in dimmingFactor : Real;
            out illuminanceOutput : Illuminance;
        }
    }
    
    part def OccupancySensorNetwork {
        perform action detectOccupancy {
            out occupiedZones : Integer;
            out totalOccupants : Integer;
            out activityLevel : Real;
        }
    }
    
    part def MillenniumHouse {
        doc /* 
            The INTEGER Millennium House is an ultra-low-energy sustainable demonstration dwelling.
            Its primary function is to provide comfortable, healthy, and secure living accommodation
            while minimizing energy consumption, carbon emissions, and environmental impact through
            integrated passive design strategies and active renewable energy systems. The house
            achieves near-zero energy operation by combining superior thermal envelope performance,
            mechanical ventilation with heat recovery, ground source heat pump heating/cooling,
            photovoltaic electricity generation, rainwater harvesting, and intelligent building
            management to optimize resource utilization and occupant comfort across all seasons.
        */
        
        attribute targetEnergyConsumption : Energy;
        attribute annualCarbonEmissions : Real;
        attribute designOccupancy : Integer;
        
        part envelope : PassiveHouseEnvelope {
            attribute :>> uValue = 0.10;
            attribute :>> thermalMass = 150000.0 [SI::kJ];
            attribute :>> airtightness = 0.6;
        }
        
        part solarPV : PhotovoltaicArray {
            port :>> energyOutput;
            attribute :>> peakCapacity = 4500.0 [SI::W];
            attribute :>> currentEfficiency = 0.19;
        }
        
        part heatPump : GroundSourceHeatPump {
            port :>> thermalOutput;
            port :>> electricalInput;
            attribute :>> cop = 4.2;
            attribute :>> capacity = 6000.0 [SI::W];
        }
        
        part mvhr : MechanicalVentilationHeatRecovery {
            port :>> airQuality;
            port :>> thermalRecovery;
            attribute :>> heatRecoveryEfficiency = 0.92;
            attribute :>> airFlowRate = 0.15 [SI::'m^3'/SI::s];
        }
        
        part thermalStore : ThermalEnergyStorage {
            port :>> thermalInterface;
            attribute :>> storageCapacity = 50000.0 [SI::kJ];
            attribute :>> currentCharge = 25000.0 [SI::kJ];
        }
        
        part bms : BuildingManagementSystem {
            port :>> controlInterface;
            attribute :>> operatingMode;
            attribute :>> energyBudget = 3000.0 [SI::W];
        }
        
        part rainwaterSystem : RainwaterHarvestingSystem {
            attribute :>> tankCapacity = 3.0 [SI::'m^3'];
            attribute :>> currentVolume = 1.5 [SI::'m^3'];
        }
        
        part windows : TripleGlazedWindows[12] {
            attribute :>> glazingLayers = 3;
            attribute :>> uValueGlazing = 0.8;
            attribute :>> solarHeatGainCoefficient = 0.5;
        }
        
        part lighting : LEDLightingSystem {
            port :>> powerInput;
            attribute :>> efficacy = 120.0;
            attribute :>> dimmingEnabled = true;
        }
        
        part occupancySensors : OccupancySensorNetwork;
        
        connection pvToHeatPump connect solarPV.energyOutput to heatPump.electricalInput;
        connection heatPumpToStore connect heatPump.thermalOutput to thermalStore.thermalInterface;
        connection mvhrToStore connect mvhr.thermalRecovery to thermalStore.thermalInterface;
        
        perform action provideSustainableLiving {
            doc /* 
                Continuously maintain optimal indoor environmental conditions while minimizing
                energy consumption through coordinated operation of passive and active systems.
            */
            
            first start;
            then merge operationalLoop;
            
            action operationalLoop {
                action monitorEnvironment {
                    out indoorTemperature : Temperature;
                    out outdoorTemperature : Temperature;
                    out co2Concentration : CO2Level;
                    out occupancyDetected : Boolean;
                    out solarPowerGenerated : Power;
                    out gridPowerAvailable : Power;
                }
                
                then action controlBuilding : bms.optimizePerformance {
                    in occupancyStatus = monitorEnvironment.occupancyDetected;
                    in indoorTemp = monitorEnvironment.indoorTemperature;
                    in outdoorTemp = monitorEnvironment.outdoorTemperature;
                    in co2Level = monitorEnvironment.co2Concentration;
                    in solarGeneration = monitorEnvironment.solarPowerGenerated;
                    in gridPower = monitorEnvironment.gridPowerAvailable;
                    out hvacSetpoint;
                    out ventilationCommand;
                    out lightingLevel;
                }
                
                then decide;
                    if controlBuilding.hvacSetpoint > controlBuilding.indoorTemp + 1.0 [SI::K] then activateHeating;
                    if controlBuilding.hvacSetpoint < controlBuilding.indoorTemp - 1.0 [SI::K] then activateCooling;
                    if controlBuilding.co2Level > 800.0 then increaseVentilation;
                    else maintainBaseline;
                
                action activateHeating : heatPump.provideHeating {
                    in powerInput;
                    in groundTemperature;
                    out thermalOutput;
                }
                then storeHeat;
                
                action activateCooling : heatPump.provideCooling {
                    in powerInput;
                    in groundTemperature;
                    out coolingOutput;
                }
                then maintainBaseline;
                
                action increaseVentilation : mvhr.exchangeAir {
                    in exhaustAirTemp;
                    in supplyAirTemp;
                    in ventilationRate = controlBuilding.ventilationCommand;
                    out recoveredHeat;
                    out freshAirSupply;
                }
                then maintainBaseline;
                
                action storeHeat : thermalStore.storeEnergy {
                    in heatInput = activateHeating.thermalOutput;
                    in duration;
                    out storedEnergy;
                }
                then maintainBaseline;
                
                action maintainBaseline;
                then operationalLoop;
            }
        }
    }
    
    requirement <'MH-REQ-001'> netZeroEnergyRequirement {
        doc /* The Millennium House shall achieve net-zero annual energy consumption. */
        subject house : MillenniumHouse;
        require constraint {
            house.targetEnergyConsumption <= 0.0 [SI::J]
        }
    }
    
    requirement <'MH-REQ-002'> thermalComfortRequirement {
        doc /* Indoor temperature shall be maintained between 19°C and 23°C during occupied periods. */
        subject house : MillenniumHouse;
        require constraint {
            house.provideSustainableLiving.operationalLoop.controlBuilding.indoorTemp >= 292.15 [SI::K] and
            house.provideSustainableLiving.operationalLoop.controlBuilding.indoorTemp <= 296.15 [SI::K]
        }
    }
    
    requirement <'MH-REQ-003'> airQualityRequirement {
        doc /* Indoor CO2 concentration shall not exceed 1000 ppm during occupied periods. */
        subject house : MillenniumHouse;
        require constraint {
            house.provideSustainableLiving.operationalLoop.controlBuilding.co2Level <= 1000.0
        }
    }
    
    requirement <'MH-REQ-004'> envelopePerformanceRequirement {
        doc /* Building envelope U-value shall not exceed 0.15 W/m²K. */
        subject envelope : PassiveHouseEnvelope;
        require constraint {
            envelope.uValue <= 0.15
        }
    }
    
    requirement <'MH-REQ-005'> renewableEnergyRequirement {
        doc /* At least 70% of energy demand shall be met by on-site renewable generation. */
        subject house : MillenniumHouse;
        assume constraint {
            house.solarPV.currentEfficiency >= 0.15
        }
        require constraint {
            house.solarPV.peakCapacity >= 0.7 * house.bms.energyBudget
        }
    }
    
    requirement <'MH-REQ-006'> heatRecoveryRequirement {
        doc /* Ventilation system shall recover at least 90% of exhaust air heat. */
        subject mvhr : MechanicalVentilationHeatRecovery;
        require constraint {
            mvhr.heatRecoveryEfficiency >= 0.90
        }
    }
    
    requirement <'MH-REQ-007'> waterConservationRequirement {
        doc /* Rainwater harvesting shall provide at least 40% of non-potable water demand. */
        subject rainwaterSystem : RainwaterHarvestingSystem;
        require constraint {
            rainwaterSystem.tankCapacity >= 2.5 [SI::'m^3']
        }
    }
    
    requirement <'MH-REQ-008'> heatPumpPerformanceRequirement {
        doc /* Ground source heat pump shall maintain coefficient of performance above 4.0. */
        subject heatPump : GroundSourceHeatPump;
        require constraint {
            heatPump.cop >= 4.0
        }
    }
    
    requirement sustainableLivingGoal {
        doc /* 
            Demonstrate integrated sustainable living with minimal environmental impact
            through coordinated passive and active building systems.
        */
        assume airQualityRequirement;
        assume thermalComfortRequirement;
        require netZeroEnergyRequirement;
        require renewableEnergyRequirement;
        require envelopePerformanceRequirement;
        require heatRecoveryRequirement;
        require waterConservationRequirement;
        require heatPumpPerformanceRequirement;
    }
}
