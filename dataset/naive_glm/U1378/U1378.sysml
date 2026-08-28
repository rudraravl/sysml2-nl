package AquariumFiltrationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def FlowRate :> Real { unit = "L/min"; }
    value def Concentration :> Real { unit = "mg/L"; }
    value def pHValue :> Real;
    value def DissolvedOxygen :> Real { unit = "mg/L"; }
    value def Power :> Real { unit = "W"; }
    value def Duration :> Real { unit = "h"; }
    value def Temperature :> Real { unit = "degC"; }
    value def Area :> Real { unit = "m^2"; }
    value def Mass :> Real { unit = "g"; }
    value def Percent :> Real;

    // ---- Item Types ----
    item def Water;
    item def ImpureWater :> Water;
    item def MechanicallyFilteredWater :> Water;
    item def BiologicallyFilteredWater :> Water;
    item def PurifiedWater :> Water;
    item def SolidWaste;
    item def DissolvedImpurity;

    // ---- Attribute Definitions ----
    attribute def WaterQuality {
        attribute ammonia : Concentration;
        attribute nitrite : Concentration;
        attribute nitrate : Concentration;
        attribute pH : pHValue;
        attribute dissolvedOxygen : DissolvedOxygen;
        attribute temperature : Temperature;
    }

    attribute def MaintenanceStatus {
        attribute operatingHours : Duration;
        attribute maintenanceRequired : Boolean;
        attribute nextMaintenance : Duration;
    }

    // ---- Port Definitions ----
    port def WaterInPort { in item water : Water; }
    port def WaterOutPort { out item water : Water; }
    port def ImpureWaterInPort { in item water : ImpureWater; }
    port def PurifiedWaterOutPort { out item water : PurifiedWater; }
    port def SolidWasteOutPort { out item waste : SolidWaste; }

    port def QualitySignalPort {
        out attribute quality : WaterQuality;
    }
    port def ControlCommandPort {
        out attribute targetFlowRate : FlowRate;
        out attribute highLoadMode : Boolean;
        out attribute maintenanceRequired : Boolean;
    }
    port def ControlFeedbackPort {
        in attribute actualFlowRate : FlowRate;
        in attribute operatingHours : Duration;
    }

    // ---- Part Definitions ----

    part def CentralWaterPump {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port feedbackOut : ControlFeedbackPort;
        port commandIn : ControlCommandPort;

        attribute ratedPower : Power = 25 [W];
        attribute maxFlowRate : FlowRate = 500 [L/min];
        attribute currentFlowRate : FlowRate = 0 [L/min];
        attribute operatingHours : Duration = 0 [h];
        attribute energyEfficient : Boolean = true;

        action def PumpOperation {
            in item impure : ImpureWater;
            in attribute targetFlow : FlowRate;
            out item pressurized : Water;
            out attribute actualFlow : FlowRate;
        }

        perform action pumpOperation : PumpOperation {
            in item impure = waterIn.water;
            in attribute targetFlow = commandIn.targetFlowRate;
            out item pressurized = waterOut.water;
            out attribute actualFlow = feedbackOut.actualFlowRate;
        }
    }

    part def MechanicalFilter {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port wasteOut : SolidWasteOutPort;

        attribute foamMediaCapacity : Percent = 100;
        attribute spongeMediaCapacity : Percent = 100;
        attribute foamMediaLoad : Percent = 0;
        attribute spongeMediaLoad : Percent = 0;

        action def MechanicalFiltration {
            in item input : ImpureWater;
            out item filtered : MechanicallyFilteredWater;
            out item waste : SolidWaste;
        }

        perform action mechanicalFiltration : MechanicalFiltration {
            in item input = waterIn.water;
            out item filtered = waterOut.water;
            out item waste = wasteOut.waste;
        }
    }

    part def BiologicalFilter {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        attribute mediaSurfaceArea : Area = 5.0;
        attribute bacteriaColonyDensity : Real = 0;
        attribute nitrificationRate : Real = 0;
        attribute ammoniaReductionEfficiency : Percent = 95;

        action def Nitrification {
            in item input : MechanicallyFilteredWater;
            out item filtered : BiologicallyFilteredWater;
        }

        perform action nitrification : Nitrification {
            in item input = waterIn.water;
            out item filtered = waterOut.water;
        }
    }

    part def ChemicalFilter {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        attribute activatedCarbonMass : Mass = 500;
        attribute carbonSaturation : Percent = 0;
        attribute adsorptionCapacity : Mass = 500;

        action def ChemicalAdsorption {
            in item input : BiologicallyFilteredWater;
            out item purified : PurifiedWater;
            out item impurities : DissolvedImpurity;
        }

        perform action chemicalAdsorption : ChemicalAdsorption {
            in item input = waterIn.water;
            out item purified = waterOut.water;
        }
    }

    part def QualitySensor {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port signalOut : QualitySignalPort;

        attribute samplingInterval : Duration = 1;
        attribute lastReading : WaterQuality;

        action def SampleWater {
            in item water : PurifiedWater;
            out attribute quality : WaterQuality;
        }

        perform action sampleWater : SampleWater {
            in item water = waterIn.water;
            out attribute quality = signalOut.quality;
        }
    }

    part def ControlModule {
        port signalIn : QualitySignalPort;
        port commandOut : ControlCommandPort;
        port feedbackIn : ControlFeedbackPort;

        attribute targetFlowRate : FlowRate = 300 [L/min];
        attribute normalFlowRate : FlowRate = 300 [L/min];
        attribute highLoadFlowRate : FlowRate = 450 [L/min];
        attribute operatingHours : Duration = 0;
        attribute maintenanceThreshold : Duration = 2000;
        attribute maintenanceRequired : Boolean = false;
        attribute highLoadMode : Boolean = false;

        attribute ammoniaThreshold : Concentration = 0.25;
        attribute nitriteThreshold : Concentration = 0.1;
        attribute nitrateThreshold : Concentration = 40;
        attribute pHMin : pHValue = 6.5;
        attribute pHMax : pHValue = 8.5;
        attribute oxygenThreshold : DissolvedOxygen = 6.0;

        action def ManageOperation {
            in attribute quality : WaterQuality;
            in attribute actualFlow : FlowRate;
            in attribute hours : Duration;
            out attribute targetFlow : FlowRate;
            out attribute highLoad : Boolean;
            out attribute maintenance : Boolean;
        }

        perform action manageOperation : ManageOperation {
            in attribute quality = signalIn.quality;
            in attribute actualFlow = feedbackIn.actualFlowRate;
            in attribute hours = feedbackIn.operatingHours;
            out attribute targetFlow = commandOut.targetFlowRate;
            out attribute highLoad = commandOut.highLoadMode;
            out attribute maintenance = commandOut.maintenanceRequired;
        }
    }

    // ---- System State Machine ----
    state def SystemOperation {
        initial state Off;
        state Startup {
            entry action { /* initialize pump ramp-up */ }
            do action { /* gradually increase flow rate to target */ }
            exit action { /* confirm flow rate stable */ }
        }
        state NormalOperation {
            do action { /* maintain target flow rate, monitor quality */ }
        }
        state HighLoadMode {
            entry action { /* increase pump flow rate */ }
            do action { /* enhanced filtration cycle */ }
            exit action { /* restore normal flow rate */ }
        }
        state MaintenanceMode {
            entry action { /* reduce flow, isolate stages */ }
            do action { /* allow media replacement and cleaning */ }
            exit action { /* reset maintenance counters */ }
        }
        state Shutdown {
            entry action { /* ramp down pump */ }
            do action { /* flush and stop */ }
            exit action { /* power off */ }
        }
        state Faulted {
            entry action { /* trigger alarm */ }
            do action { /* safe-state operation */ }
        }

        transition Off -> Startup on startCommand;
        transition Startup -> NormalOperation when pump.currentFlowRate >= controlModule.targetFlowRate;
        transition NormalOperation -> HighLoadMode when controlModule.highLoadMode;
        transition HighLoadMode -> NormalOperation when !controlModule.highLoadMode;
        transition NormalOperation -> MaintenanceMode when controlModule.maintenanceRequired;
        transition HighLoadMode -> MaintenanceMode when controlModule.maintenanceRequired;
        transition MaintenanceMode -> NormalOperation when !controlModule.maintenanceRequired;
        transition NormalOperation -> Shutdown on stopCommand;
        transition HighLoadMode -> Shutdown on stopCommand;
        transition MaintenanceMode -> Shutdown on stopCommand;
        transition Shutdown -> Off when pump.currentFlowRate == 0;
        transition NormalOperation -> Faulted when qualitySensor.signalOut.quality.ammonia > controlModule.ammoniaThreshold;
        transition Faulted -> Startup on resetCommand;
    }

    // ---- Main System ----
    part def AquariumFiltrationSystem {
        part pump : CentralWaterPump;
        part mechanicalFilter : MechanicalFilter;
        part biologicalFilter : BiologicalFilter;
        part chemicalFilter : ChemicalFilter;
        part qualitySensor : QualitySensor;
        part controlModule : ControlModule;

        port aquariumIntake : ImpureWaterInPort;
        port aquariumReturn : PurifiedWaterOutPort;
        port wasteDrain : SolidWasteOutPort;

        attribute systemPower : Power = 30;
        attribute reliabilityRating : Percent = 99;
        attribute maintenanceInterval : Duration = 2000;

        // Delegation connections (external to internal)
        connect aquariumIntake to pump.waterIn;
        connect aquariumReturn to qualitySensor.waterOut;
        connect wasteDrain to mechanicalFilter.wasteOut;

        // Internal flow connections
        connect pump.waterOut to mechanicalFilter.waterIn;
        connect mechanicalFilter.waterOut to biologicalFilter.waterIn;
        connect biologicalFilter.waterOut to chemicalFilter.waterIn;
        connect chemicalFilter.waterOut to qualitySensor.waterIn;

        // Signal connections
        connect qualitySensor.signalOut to controlModule.signalIn;
        connect controlModule.commandOut to pump.commandIn;
        connect pump.feedbackOut to controlModule.feedbackIn;

        // State machine
        exhibit state systemOperation : SystemOperation;

        // Operational logic
        assert constraint { pump.currentFlowRate <= pump.maxFlowRate }
        assert constraint { controlModule.targetFlowRate >= 100 and controlModule.targetFlowRate <= pump.maxFlowRate }
    }

    // ---- Requirements ----
    requirement def WaterCirculationRequirement {
        subject system : AquariumFiltrationSystem;
        objective "Continuously circulate aquarium water through all filtration stages.";
        require { system.pump.currentFlowRate >= 100 }
        require { system.pump.maxFlowRate >= 500 }
    }

    requirement def MechanicalFiltrationRequirement {
        subject filter : MechanicalFilter;
        objective "Remove solid waste, debris, and uneaten food using physical media.";
        require { filter.foamMediaCapacity > 0 }
        require { filter.spongeMediaCapacity > 0 }
    }

    requirement def BiologicalFiltrationRequirement {
        subject filter : BiologicalFilter;
        objective "Cultivate beneficial bacteria to perform nitrification of ammonia and nitrites.";
        require { filter.mediaSurfaceArea >= 2.0 }
        require { filter.ammoniaReductionEfficiency >= 90 }
    }

    requirement def ChemicalFiltrationRequirement {
        subject filter : ChemicalFilter;
        objective "Adsorb dissolved impurities, organic compounds, odors, and discoloration.";
        require { filter.activatedCarbonMass >= 200 }
        require { filter.carbonSaturation < 100 }
    }

    requirement def WaterQualityMonitoringRequirement {
        subject sensor : QualitySensor;
        objective "Continuously monitor ammonia, nitrite, nitrate, pH, and dissolved oxygen.";
        require { sensor.samplingInterval <= 1 }
    }

    requirement def ControlAndMaintenanceRequirement {
        subject controller : ControlModule;
        objective "Maintain target flow rate, track operating hours, and signal maintenance.";
        require { controller.maintenanceThreshold <= 2000 }
        require { controller.ammoniaThreshold <= 0.25 }
        require { controller.oxygenThreshold >= 6.0 }
    }

    requirement def EnergyEfficiencyRequirement {
        subject system : AquariumFiltrationSystem;
        objective "Operate reliably with low power consumption over long maintenance cycles.";
        require { system.systemPower <= 50 }
        require { system.reliabilityRating >= 95 }
        require { system.maintenanceInterval >= 2000 }
    }

    requirement def OperationalStatesRequirement {
        subject system : AquariumFiltrationSystem;
        objective "Support startup, shutdown, maintenance, normal, and high-load operating modes.";
        require { system.systemOperation.supports(Startup) }
        require { system.systemOperation.supports(Shutdown) }
        require { system.systemOperation.supports(MaintenanceMode) }
        require { system.systemOperation.supports(HighLoadMode) }
    }

    package FiltrationRequirements {
        requirement circulationReq : WaterCirculationRequirement;
        requirement mechanicalReq : MechanicalFiltrationRequirement;
        requirement biologicalReq : BiologicalFiltrationRequirement;
        requirement chemicalReq : ChemicalFiltrationRequirement;
        requirement monitoringReq : WaterQualityMonitoringRequirement;
        requirement controlReq : ControlAndMaintenanceRequirement;
        requirement energyReq : EnergyEfficiencyRequirement;
        requirement statesReq : OperationalStatesRequirement;
    }
}
