package BrineProcessingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SalinityConcentration {
        attribute value : Real;
        attribute unit : String = "g/L";
    }

    item def Brine {
        attribute salinity : SalinityConcentration;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute pressure : ISQ::PressureValue;
    }

    item def ProcessedBrine :> Brine {
        assert constraint { salinity.value >= 200.0 }
    }

    item def FreshWater {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute salinity : SalinityConcentration;
        assert constraint { salinity.value <= 1.0 }
    }

    port def BrineInputPort {
        in item brineIn : Brine;
    }

    port def BrineOutputPort {
        out item brineOut : Brine;
    }

    port def WaterOutputPort {
        out item waterOut : FreshWater;
    }

    port def ConcentratePort {
        out item concentrate : ProcessedBrine;
    }

    part def FeedTank {
        port outlet : BrineOutputPort;
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        assert constraint { currentLevel <= capacity }
    }

    part def CirculationPump {
        port inlet : BrineInputPort;
        port outlet : BrineOutputPort;
        attribute flowCapacity : ISQ::VolumeFlowRateValue;
        attribute operatingPressure : ISQ::PressureValue;
        attribute powerConsumption : ISQ::PowerValue;
    }

    part def PreHeater {
        port brineIn : BrineInputPort;
        port brineOut : BrineOutputPort;
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute heatingPower : ISQ::PowerValue;
    }

    part def EvaporationUnit {
        port feedPort : BrineInputPort;
        port waterPort : WaterOutputPort;
        port concentratePort : ConcentratePort;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingPressure : ISQ::PressureValue;
        attribute evaporationRate : ISQ::VolumeFlowRateValue;
    }

    part def ConcentrateTank {
        port inlet : BrineInputPort;
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
    }

    part def ProductTank {
        port inlet : BrineInputPort;
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
    }

    part def SalinityMonitor {
        in attribute inputBrine : Brine;
        out attribute measuredSalinity : SalinityConcentration;
        out attribute qualityStatus : Boolean;
    }

    part def TemperatureController {
        in attribute targetTemp : ISQ::ThermodynamicTemperatureValue;
        in attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        out attribute controlSignal : ISQ::PowerValue;
    }

    action def MonitorBrineQuality {
        in brine : Brine;
        out salinity : SalinityConcentration;
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out acceptable : Boolean;
    }

    action def HeatBrine {
        in inputBrine : Brine;
        in targetTemp : ISQ::ThermodynamicTemperatureValue;
        in heatingPower : ISQ::PowerValue;
        out heatedBrine : Brine;
    }

    action def EvaporateWater {
        in feedBrine : Brine;
        in evaporationTemp : ISQ::ThermodynamicTemperatureValue;
        out freshWater : FreshWater;
        out concentrate : ProcessedBrine;
    }

    action def ProcessBrine {
        in rawBrine : Brine;
        in targetSalinity : SalinityConcentration;
        out producedWater : FreshWater;
        out concentratedBrine : ProcessedBrine;
        
        first start;
        then merge continueProcessing;
        
        then action monitor : MonitorBrineQuality {
            in brine = rawBrine;
            out salinity;
            out temperature;
            out acceptable;
        }
        
        then decide;
            if monitor.acceptable then heat;
            if !monitor.acceptable then adjustParameters;
        
        action heat : HeatBrine {
            in inputBrine = rawBrine;
            in targetTemp = 85.0 [SI::'°C'];
            in heatingPower = 150.0 [SI::kW];
            out heatedBrine;
        }
        then evaporate;
        
        action evaporate : EvaporateWater {
            in feedBrine = heat.heatedBrine;
            in evaporationTemp = 85.0 [SI::'°C'];
            out freshWater;
            out concentrate;
        }
        then assign producedWater := evaporate.freshWater;
        then assign concentratedBrine := evaporate.concentrate;
        then done;
        
        action adjustParameters;
        then continueProcessing;
    }

    state def BrineProcessingStates {
        entry; then standby;
        
        state standby {
            entry assign systemActive = false;
        }
        
        transition standby_to_startup
            first standby
            accept StartCommand
            then startup;
        
        state startup {
            entry assign systemActive = true;
            do action initializeSystem;
        }
        
        transition startup_to_heating
            first startup
            if systemReady
            then heating;
        
        state heating {
            do action heatFeed : HeatBrine;
        }
        
        transition heating_to_evaporating
            first heating
            if feedTemperature >= operatingTemperature
            then evaporating;
        
        state evaporating {
            do action evaporate : EvaporateWater;
            do action monitorQuality : MonitorBrineQuality;
        }
        
        transition evaporating_to_concentrating
            first evaporating
            if monitorQuality.salinity.value >= targetConcentration.value
            then concentrating;
        
        transition evaporating_to_heating
            first evaporating
            if feedTemperature < operatingTemperature
            then heating;
        
        state concentrating {
            do action collectConcentrate;
        }
        
        transition concentrating_to_evaporating
            first concentrating
            then evaporating;
        
        transition evaporating_to_shutdown
            first evaporating
            accept StopCommand
            then shutdown;
        
        state shutdown {
            entry assign systemActive = false;
            do action coolDown;
        }
        
        transition shutdown_to_standby
            first shutdown
            if systemTemperature <= 40.0
            then standby;
        
        attribute systemActive : Boolean;
        attribute systemReady : Boolean;
        attribute feedTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute targetConcentration : SalinityConcentration;
        attribute systemTemperature : Real;
    }

    requirement def <'REQ-BPS-001'> BrineConcentrationRequirement {
        doc /* The system shall concentrate input brine from 35 g/L to at least 200 g/L salinity. */
        
        subject system : BrineProcessingSystem;
        
        require constraint {
            doc /* Input brine salinity shall be between 30 and 50 g/L. */
        }
        
        require constraint {
            doc /* Output concentrate salinity shall be at least 200 g/L. */
        }
    }

    requirement def <'REQ-BPS-002'> WaterProductionRequirement {
        doc /* The system shall produce fresh water with salinity less than 1 g/L. */
        
        subject system : BrineProcessingSystem;
        
        require constraint {
            doc /* Fresh water output salinity shall not exceed 1.0 g/L. */
        }
    }

    requirement def <'REQ-BPS-003'> ThermalEfficiencyRequirement {
        doc /* The system shall maintain thermal efficiency above 70% during operation. */
        
        subject heatingSystem : PreHeater;
        
        require constraint {
            doc /* Energy consumption per liter of water produced shall not exceed 3.0 kWh/L. */
        }
    }

    requirement def <'REQ-BPS-004'> OperationalSafetyRequirement {
        doc /* The system shall operate within safe temperature and pressure limits. */
        
        subject evaporator : EvaporationUnit;
        
        require constraint {
            doc /* Operating temperature shall not exceed 95°C. */
        }
        
        require constraint {
            doc /* Operating pressure shall not exceed 100 kPa. */
        }
    }

    part def BrineProcessingSystem {
        attribute targetSalinity : SalinityConcentration;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute processingCapacity : ISQ::VolumeFlowRateValue;
        
        part feedTank : FeedTank;
        part feedPump : CirculationPump;
        part preHeater : PreHeater;
        part salinityMonitor : SalinityMonitor;
        part tempController : TemperatureController;
        part evaporator : EvaporationUnit;
        part productWaterTank : ProductTank;
        part concentrateTank : ConcentrateTank;
    }

    part brineProcessingSystem : BrineProcessingSystem {
        attribute :>> targetSalinity {
            attribute :>> value = 220.0;
        }
        
        attribute :>> operatingTemperature = 85.0 [SI::'°C'];
        attribute :>> processingCapacity = 500.0 [SI::L/SI::h];
        
        part :>> feedTank {
            attribute :>> capacity = 10000.0 [SI::L];
            attribute :>> currentLevel = 7500.0 [SI::L];
        }
        
        part :>> feedPump {
            attribute :>> flowCapacity = 600.0 [SI::L/SI::h];
            attribute :>> operatingPressure = 80.0 [SI::kPa];
            attribute :>> powerConsumption = 5.0 [SI::kW];
        }
        
        part :>> preHeater {
            attribute :>> targetTemperature = 85.0 [SI::'°C'];
            attribute :>> heatingPower = 150.0 [SI::kW];
        }
        
        part :>> evaporator {
            attribute :>> operatingTemperature = 85.0 [SI::'°C'];
            attribute :>> operatingPressure = 75.0 [SI::kPa];
            attribute :>> evaporationRate = 300.0 [SI::L/SI::h];
        }
        
        part :>> productWaterTank {
            attribute :>> capacity = 5000.0 [SI::L];
            attribute :>> currentLevel = 1200.0 [SI::L];
        }
        
        part :>> concentrateTank {
            attribute :>> capacity = 3000.0 [SI::L];
            attribute :>> currentLevel = 800.0 [SI::L];
        }
        
        connect feedTank.outlet to feedPump.inlet;
        connect feedPump.outlet to preHeater.brineIn;
        connect preHeater.brineOut to evaporator.feedPort;
        connect evaporator.waterPort to productWaterTank.inlet;
        connect evaporator.concentratePort to concentrateTank.inlet;
        
        perform action processingOperation : ProcessBrine {
            in rawBrine;
            in targetSalinity = brineProcessingSystem.targetSalinity;
            out producedWater;
            out concentratedBrine;
        }
        
        exhibit state operationalStateMachine : BrineProcessingStates {
            attribute :>> operatingTemperature = brineProcessingSystem.operatingTemperature;
            attribute :>> targetConcentration = brineProcessingSystem.targetSalinity;
        }
        
        satisfy BrineConcentrationRequirement;
        satisfy WaterProductionRequirement;
        satisfy ThermalEfficiencyRequirement;
        satisfy OperationalSafetyRequirement;
    }
}
