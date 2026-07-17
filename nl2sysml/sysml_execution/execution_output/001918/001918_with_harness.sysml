package InternationalSpaceStationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CrewCount :> Integer;
    attribute def OxygenConcentration :> Real;
    attribute def CO2Concentration :> Real;
    attribute def DataRate :> Real;
    
    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }
    
    item def Atmosphere {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute oxygenLevel : OxygenConcentration;
        attribute co2Level : CO2Concentration;
    }
    
    item def ThermalFluid {
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def DataSignal {
        attribute dataRate : DataRate;
        attribute signalStrength : Real;
    }
    
    port def PowerPort {
        out item electricalPower : ElectricalPower;
    }
    
    port def AtmospherePort {
        inout item atmosphere : Atmosphere;
    }
    
    port def ThermalPort {
        inout item coolant : ThermalFluid;
    }
    
    port def DataPort {
        inout item data : DataSignal;
    }
    
    part def SolarPowerSystem {
        attribute totalPanelArea : AreaValue;
        attribute conversionEfficiency : Real;
        attribute generatedPower : PowerValue;
        
        port powerOutput : PowerPort;
        
        action generatePower {
            in solarIrradiance : PowerValue;
            out outputPower : PowerValue;
        }
    }
    
    part def EnvironmentalControlLifeSupport {
        attribute oxygenGenerationRate : VolumeFlowRateValue;
        attribute co2RemovalRate : VolumeFlowRateValue;
        attribute waterRecyclingEfficiency : Real;
        
        port powerInput : ~PowerPort;
        port atmosphereControl : AtmospherePort;
        
        action maintainAtmosphere {
            in currentO2 : OxygenConcentration;
            in currentCO2 : CO2Concentration;
            in crewSize : CrewCount;
            out regulatedO2 : OxygenConcentration;
            out regulatedCO2 : CO2Concentration;
        }
        
        action recycleWater {
            in wasteWater : MassValue;
            out potableWater : MassValue;
        }
    }
    
    part def ThermalControlSystem {
        attribute radiatorArea : AreaValue;
        attribute coolantCapacity : VolumeValue;
        attribute heatRejectionCapacity : PowerValue;
        
        port powerInput : ~PowerPort;
        port thermalLoop : ThermalPort;
        
        action regulateTemperature {
            in heatLoad : PowerValue;
            in targetTemp : ThermodynamicTemperatureValue;
            out coolantTemp : ThermodynamicTemperatureValue;
        }
    }
    
    part def HabitationModule {
        attribute volumeCapacity : VolumeValue;
        attribute crewCapacity : CrewCount;
        attribute currentCrew : CrewCount;
        
        port powerInput : ~PowerPort;
        port atmosphereInterface : ~AtmospherePort;
        port thermalInterface : ~ThermalPort;
        
        action supportCrew {
            in crewCount : CrewCount;
            in atmosphereQuality : Atmosphere;
            out crewStatus : String;
        }
    }
    
    part def ResearchLaboratory {
        attribute experimentRacks : Integer;
        attribute microgravityQuality : Real;
        
        port powerInput : ~PowerPort;
        port atmosphereInterface : ~AtmospherePort;
        port dataOutput : DataPort;
        
        action conductExperiment {
            in experimentType : String;
            in duration : TimeValue;
            in environmentalConditions : Atmosphere;
            out experimentData : DataSignal;
        }
    }
    
    part def PropulsionModule {
        attribute fuelMass : MassValue;
        attribute thrustCapacity : ForceValue;
        attribute specificImpulse : Real;
        
        port powerInput : ~PowerPort;
        port dataInput : ~DataPort;
        
        action performReboost {
            in deltaVelocity : SpeedValue;
            in currentAltitude : LengthValue;
            out newAltitude : LengthValue;
            out fuelConsumed : MassValue;
        }
    }
    
    part def CommunicationsSystem {
        attribute antennaCount : Integer;
        attribute uplinkDataRate : DataRate;
        attribute downlinkDataRate : DataRate;
        
        port powerInput : ~PowerPort;
        port internalData : DataPort;
        port groundLink : DataPort;
        
        action transmitTelemetry {
            in stationData : DataSignal;
            out groundData : DataSignal;
        }
        
        action receiveCommands {
            in groundCommands : DataSignal;
            out stationCommands : DataSignal;
        }
    }
    
    part def GuidanceNavigationControl {
        attribute attitudeAccuracy : Real;
        attribute positionAccuracy : LengthValue;
        
        port powerInput : ~PowerPort;
        port dataInterface : DataPort;
        
        action maintainAttitude {
            in targetOrientation : Real[3];
            in currentOrientation : Real[3];
            out controlCommands : Real[3];
        }
        
        action trackPosition {
            out currentAltitude : LengthValue;
            out currentVelocity : SpeedValue;
            out orbitalPosition : Real[3];
        }
    }
    
    requirement def MissionRequirement {
        doc /* Top-level requirements for ISS mission objectives */
    }
    
    requirement <'ISS-REQ-001'> sustainHumanPresence : MissionRequirement {
        doc /* The ISS shall provide continuous habitable environment for international crew */
        subject station : InternationalSpaceStation;
    }
    
    requirement <'ISS-REQ-002'> enableMicrogravityResearch : MissionRequirement {
        doc /* The ISS shall provide facilities for long-duration microgravity research */
        subject station : InternationalSpaceStation;
    }
    
    requirement <'ISS-REQ-003'> maintainOrbitalAltitude : MissionRequirement {
        doc /* The ISS shall maintain operational orbit between 330 km and 435 km altitude */
        subject station : InternationalSpaceStation;
    }
    
    requirement <'ISS-REQ-004'> provideSufficientPower : MissionRequirement {
        doc /* The ISS shall generate minimum 84 kW electrical power for all systems */
        subject station : InternationalSpaceStation;
    }
    
    requirement <'ISS-REQ-005'> maintainCommunications : MissionRequirement {
        doc /* The ISS shall maintain continuous communication capability with ground control */
        subject station : InternationalSpaceStation;
    }
    
    part def InternationalSpaceStation {
        attribute totalMass : MassValue;
        attribute currentAltitude : LengthValue;
        attribute orbitalVelocity : SpeedValue;
        attribute pressurizedVolume : VolumeValue;
        
        part solarArrays : SolarPowerSystem[8] {
            attribute redefines totalPanelArea = 2500[m^2];
            attribute redefines conversionEfficiency = 0.14;
            attribute redefines generatedPower = 84000[W];
        }
        
        part eclss : EnvironmentalControlLifeSupport {
            attribute redefines oxygenGenerationRate = 2.5[kg/('d')];
            attribute redefines co2RemovalRate = 3.0[kg/('d')];
            attribute redefines waterRecyclingEfficiency = 0.93;
        }
        
        part thermalControl : ThermalControlSystem {
            attribute redefines radiatorArea = 1400[m^2];
            attribute redefines heatRejectionCapacity = 70000[W];
        }
        
        part habitationModules : HabitationModule[3] {
            attribute redefines volumeCapacity = 388[m^3];
            attribute redefines crewCapacity = 7;
        }
        
        part laboratories : ResearchLaboratory[6] {
            attribute redefines experimentRacks = 24;
            attribute redefines microgravityQuality = 1.0e-6;
        }
        
        part propulsion : PropulsionModule {
            attribute redefines fuelMass = 860[kg];
            attribute redefines thrustCapacity = 2900[N];
        }
        
        part communications : CommunicationsSystem {
            attribute redefines antennaCount = 4;
            attribute redefines uplinkDataRate = 300;
            attribute redefines downlinkDataRate = 300;
        }
        
        part gnc : GuidanceNavigationControl {
            attribute redefines attitudeAccuracy = 0.5;
            attribute redefines positionAccuracy = 1000[m];
        }
        
        connect solarArrays.powerOutput to eclss.powerInput;
        connect solarArrays.powerOutput to thermalControl.powerInput;
        connect solarArrays.powerOutput to habitationModules.powerInput;
        connect solarArrays.powerOutput to laboratories.powerInput;
        connect solarArrays.powerOutput to propulsion.powerInput;
        connect solarArrays.powerOutput to communications.powerInput;
        connect solarArrays.powerOutput to gnc.powerInput;
        
        connect eclss.atmosphereControl to habitationModules.atmosphereInterface;
        connect eclss.atmosphereControl to laboratories.atmosphereInterface;
        
        connect thermalControl.thermalLoop to habitationModules.thermalInterface;
        
        connect laboratories.dataOutput to communications.internalData;
        connect gnc.dataInterface to communications.internalData;
        connect propulsion.dataInput to communications.internalData;
    }
    
    action def OperateStation {
        in altitude : LengthValue;
        in crewSize : CrewCount;
        out operationalStatus : String;
    }
    
    action def ConductScientificResearch {
        in researchPriorities : String[*];
        in availablePower : PowerValue;
        in crewAvailability : CrewCount;
        out researchData : DataSignal[*];
    }
    
    action def MaintainLifeSupport {
        in crewCount : CrewCount;
        in atmosphereState : Atmosphere;
        out lifeSupportStatus : String;
        out atmosphereQuality : Atmosphere;
    }
    
    action def ManageOrbit {
        in currentAltitude : LengthValue;
        in atmosphericDrag : ForceValue;
        out reboostRequired : Boolean;
    }
    
    action stationOperations {
        first start;
        then merge operationalCycle;
        
        action monitorSystems {
            out powerStatus : PowerValue;
            out atmosphereStatus : Atmosphere;
            out altitudeStatus : LengthValue;
            out thermalStatus : ThermodynamicTemperatureValue;
        }
        
        then decide;
            if monitorSystems.powerStatus < 60000.0 then adjustSolarArrays;
            if monitorSystems.atmosphereStatus.oxygenLevel < 19.5 then generateOxygen;
            if monitorSystems.atmosphereStatus.co2Level > 0.5 then scrubCO2;
            if monitorSystems.altitudeStatus < 350000.0 then planReboost;
        
        action adjustSolarArrays {
            action orientPanels {
                in sunVector : Real[3];
                out panelAngles : Real[8];
            }
        }
        then operationalCycle;
        
        action generateOxygen {
            action electrolyzeWater {
                in waterInput : MassValue;
                out oxygenOutput : VolumeValue;
                out hydrogenOutput : VolumeValue;
            }
        }
        then operationalCycle;
        
        action scrubCO2 {
            action activateScrubber {
                in co2Concentration : CO2Concentration;
                out cleanedAir : Atmosphere;
            }
        }
        then operationalCycle;
        
        action planReboost {
            action calculateManeuver {
                in currentOrbit : Real[6];
                in targetAltitude : LengthValue;
                out deltaV : SpeedValue;
                out burnDuration : TimeValue;
            }
            then action executeReboost {
                in deltaV : SpeedValue;
                in burnDuration : TimeValue;
                out newAltitude : LengthValue;
            }
        }
        then operationalCycle;
        
        action performResearch : ConductScientificResearch {
            in researchPriorities;
            in availablePower = monitorSystems.powerStatus;
            in crewAvailability = 6;
            out researchData;
        }
        then operationalCycle;
        
        action maintainEnvironment : MaintainLifeSupport {
            in crewCount = 6;
            in atmosphereState = monitorSystems.atmosphereStatus;
            out lifeSupportStatus;
            out atmosphereQuality;
        }
        then operationalCycle;
        
        action communicateWithGround {
            action transmitData {
                in scienceData : DataSignal;
                in telemetryData : DataSignal;
                out transmissionStatus : String;
            }
            then action receiveCommands {
                in uplinkCommands : DataSignal;
                out commandQueue : String[*];
            }
        }
        then operationalCycle;
        
        action manageOrbit : ManageOrbit {
            in currentAltitude = monitorSystems.altitudeStatus;
            in atmosphericDrag = 0.0001;
            out reboostRequired;
        }
        then operationalCycle;
    }
    
    part iss : InternationalSpaceStation {
        attribute redefines totalMass = 419725[kg];
        attribute redefines currentAltitude = 408000[m];
        attribute redefines orbitalVelocity = 7660[m/s];
        attribute redefines pressurizedVolume = 916[m^3];
        
        perform action stationOperations;
        
        satisfy sustainHumanPresence;
        satisfy enableMicrogravityResearch;
        satisfy maintainOrbitalAltitude;
        satisfy provideSufficientPower;
        satisfy maintainCommunications;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import InternationalSpaceStationSystem::*;

    action orchestrator {
        attribute testAvailablePower : PowerValue;
        attribute testCrewAvailability : CrewCount = 0;
        action performResearchProbe : ConductScientificResearch {
            // TODO(human): unsupported input type for researchPriorities: String[*] (type is not a primitive, enum, extracted payload def, or known value type)
            in availablePower = testAvailablePower;
            in crewAvailability = testCrewAvailability;
        }
        first performResearchProbe;
    }
}
