package EffluentDecontaminationSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def VolumeFlowRate :> ISQ::volumeFlowRate;
    attribute def Pressure :> ISQ::pressure;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Concentration :> ISQ::massConcentration;
    attribute def Turbidity :> ISQ::dimensionlessRatio;
    attribute def Fraction :> ISQ::dimensionlessRatio;
    attribute def Power :> ISQ::power;
    attribute def TimeDuration :> ISQ::time;
    attribute def DoseRate :> ISQ::absorbedDoseRate;
    attribute def EnergyDose :> ISQ::absorbedDose;
    attribute def pH :> ScalarValues::Real;
    attribute def CountPerVolume :> ScalarValues::Real;

    item def RawEffluent {
        attribute flowRate : VolumeFlowRate;
        attribute temperature : Temperature;
        attribute inletPressure : Pressure;
        attribute pHValue : pH;
        attribute biologicalLoad : CountPerVolume;
        attribute suspendedSolids : Concentration;
        attribute chemicalOxygenDemand : Concentration;
    }

    item def ConditionedEffluent {
        attribute flowRate : VolumeFlowRate;
        attribute pHValue : pH;
        attribute suspendedSolids : Concentration;
        attribute oxidantResidual : Concentration;
    }

    item def DecontaminatedEffluent {
        attribute flowRate : VolumeFlowRate;
        attribute biologicalLoad : CountPerVolume;
        attribute suspendedSolids : Concentration;
        attribute chemicalOxygenDemand : Concentration;
        attribute dischargeTemperature : Temperature;
        attribute compliant : Boolean;
    }

    item def SeparatedSludge {
        attribute volumeRate : VolumeFlowRate;
        attribute solidsConcentration : Concentration;
        attribute pathogenLoad : CountPerVolume;
    }

    item def DecontaminationAgent {
        attribute concentration : Concentration;
        attribute injectionRate : VolumeFlowRate;
        attribute activeFraction : Fraction;
    }

    item def ElectricalPower {
        attribute voltage : ScalarValues::Real;
        attribute current : ScalarValues::Real;
        attribute consumedPower : Power;
    }

    item def ControlSignal {
        attribute commandValue : ScalarValues::Real;
        attribute valid : Boolean;
    }

    item def SensorReading {
        attribute measuredValue : ScalarValues::Real;
        attribute healthy : Boolean;
        attribute sampleAge : TimeDuration;
    }

    port def EffluentInletPort {
        in item effluent : RawEffluent;
    }

    port def EffluentTransferPort {
        inout item effluent : ConditionedEffluent;
    }

    port def EffluentOutletPort {
        out item effluent : DecontaminatedEffluent;
    }

    port def SludgeOutletPort {
        out item sludge : SeparatedSludge;
    }

    port def ChemicalSupplyPort {
        in item agent : DecontaminationAgent;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item feedback : SensorReading;
    }

    port def MonitoringPort {
        out item reading : SensorReading;
    }

    part def ScreeningUnit {
        port inlet : EffluentInletPort;
        port screenedOutlet : EffluentTransferPort;
        port screeningsOutlet : SludgeOutletPort;

        attribute screenAperture = 2.0 [mm];
        attribute removalEfficiency : Fraction = 0.92;
        attribute maxFlowCapacity : VolumeFlowRate = 0.050 [m^3/s];

        action screenEffluent {
            in item incoming : RawEffluent;
            out item screened : ConditionedEffluent;
            out item screenings : SeparatedSludge;

            first start;
            then removeLargeSolids;
            then verifyNoBypass;
            then done;

            action removeLargeSolids;
            action verifyNoBypass;
        }
    }

    part def EqualizationTank {
        port inlet : EffluentTransferPort;
        port outlet : EffluentTransferPort;
        port levelMonitor : MonitoringPort;

        attribute workingVolume = 12.0 [m^3];
        attribute minimumOperatingVolume = 2.0 [m^3];
        attribute maximumOperatingVolume = 14.0 [m^3];
        attribute mixingPower : Power = 1.5 [kW];
        attribute currentVolume : ISQ::volume;

        state tankState {
            entry; then Empty;

            state Empty;
            state Filling;
            state Mixed;
            state HighLevelAlarm;
            state Draining;

            transition Empty_to_Filling first Empty
                accept ControlSignal
                if currentVolume < minimumOperatingVolume
                then Filling;

            transition Filling_to_Mixed first Filling
                if currentVolume >= minimumOperatingVolume
                then Mixed;

            transition Mixed_to_HighLevelAlarm first Mixed
                if currentVolume >= maximumOperatingVolume
                then HighLevelAlarm;

            transition Mixed_to_Draining first Mixed
                accept ControlSignal
                then Draining;

            transition Draining_to_Mixed first Draining
                if currentVolume > minimumOperatingVolume
                then Mixed;

            transition Draining_to_Empty first Draining
                if currentVolume <= minimumOperatingVolume
                then Empty;
        }
    }

    part def ChemicalDosingUnit {
        port effluentIn : EffluentTransferPort;
        port effluentOut : EffluentTransferPort;
        port chemicalIn : ChemicalSupplyPort;
        port command : ControlPort;

        attribute targetOxidantResidual : Concentration = 2.0 [mg/L];
        attribute maximumInjectionRate : VolumeFlowRate = 0.00025 [m^3/s];
        attribute dosingAccuracy : Fraction = 0.05;

        action doseEffluent {
            in item incoming : ConditionedEffluent;
            in item agent : DecontaminationAgent;
            out item dosed : ConditionedEffluent;

            first calculateDose;
            then injectAgent;
            then mixContact;
            then confirmResidual;
            then done;

            action calculateDose;
            action injectAgent;
            action mixContact;
            action confirmResidual;
        }
    }

    part def pHAdjustmentUnit {
        port inlet : EffluentTransferPort;
        port outlet : EffluentTransferPort;
        port command : ControlPort;

        attribute targetMinimumPH : pH = 6.5;
        attribute targetMaximumPH : pH = 8.5;
        attribute correctionResponseTime : TimeDuration = 120 [s];

        action adjustPH {
            in item incoming : ConditionedEffluent;
            out item neutralized : ConditionedEffluent;

            first measurePH;
            then addAcidOrBase;
            then verifyRange;
            then done;

            action measurePH;
            action addAcidOrBase;
            action verifyRange;
        }
    }

    part def FiltrationModule {
        port inlet : EffluentTransferPort;
        port filtrateOutlet : EffluentTransferPort;
        port sludgeOutlet : SludgeOutletPort;
        port pressureMonitor : MonitoringPort;

        attribute nominalPoreSize = 0.2 [um];
        attribute maximumDifferentialPressure : Pressure = 250 [kPa];
        attribute solidsRemovalEfficiency : Fraction = 0.98;

        state filterState {
            entry; then Ready;

            state Ready;
            state Filtering;
            state Backwashing;
            state Fouled;
            state Isolated;

            transition Ready_to_Filtering first Ready
                accept ControlSignal
                then Filtering;

            transition Filtering_to_Backwashing first Filtering
                if pressureMonitor::reading.measuredValue > 180.0
                then Backwashing;

            transition Filtering_to_Fouled first Filtering
                if pressureMonitor::reading.measuredValue > 250.0
                then Fouled;

            transition Backwashing_to_Ready first Backwashing
                after 300 [s]
                then Ready;

            transition Fouled_to_Isolated first Fouled
                accept ControlSignal
                then Isolated;

            transition Isolated_to_Ready first Isolated
                accept ControlSignal
                then Ready;
        }
    }

    part def UVReactor {
        port inlet : EffluentTransferPort;
        port outlet : EffluentTransferPort;
        port powerIn : PowerPort;
        port intensityMonitor : MonitoringPort;

        attribute minimumUVIntensity : DoseRate = 40 [mW/cm^2];
        attribute targetDose : EnergyDose = 80 [mJ/cm^2];
        attribute lampPower : Power = 6.0 [kW];
        attribute hydraulicResidenceTime : TimeDuration = 45 [s];

        action irradiateEffluent {
            in item filtered : ConditionedEffluent;
            out item disinfected : ConditionedEffluent;

            first energizeLamps;
            then exposeFlow;
            then monitorDose;
            then validateDose;
            then done;

            action energizeLamps;
            action exposeFlow;
            action monitorDose;
            action validateDose;
        }
    }

    part def CatalyticOxidationReactor {
        port inlet : EffluentTransferPort;
        port outlet : EffluentTransferPort;
        port oxidantFeed : ChemicalSupplyPort;
        port powerIn : PowerPort;

        attribute catalystBedVolume = 1.8 [m^3];
        attribute targetCODReduction : Fraction = 0.75;
        attribute operatingTemperature : Temperature = 298.15 [K];
        attribute contactTime : TimeDuration = 600 [s];

        action oxidizeContaminants {
            in item disinfected : ConditionedEffluent;
            in item oxidant : DecontaminationAgent;
            out item oxidized : ConditionedEffluent;

            first distributeAcrossCatalyst;
            then reactOrganics;
            then quenchResidual;
            then done;

            action distributeAcrossCatalyst;
            action reactOrganics;
            action quenchResidual;
        }
    }

    part def FinalMonitoringSkid {
        port inlet : EffluentTransferPort;
        port outlet : EffluentOutletPort;
        port turbidityMonitor : MonitoringPort;
        port pathogenMonitor : MonitoringPort;
        port pHMonitor : MonitoringPort;
        port codMonitor : MonitoringPort;

        attribute maxAllowedTurbidity : Turbidity = 5.0;
        attribute maxAllowedPathogenLoad : CountPerVolume = 10.0;
        attribute maxAllowedCOD : Concentration = 50.0 [mg/L];

        action certifyEffluent {
            in item treated : ConditionedEffluent;
            out item released : DecontaminatedEffluent;

            first sampleTreatedFlow;
            then compareToLimits;
            then setComplianceFlag;
            then releaseOrDivert;
            then done;

            action sampleTreatedFlow;
            action compareToLimits;
            action setComplianceFlag;
            action releaseOrDivert;
        }
    }

    part def RecirculationPump {
        port suction : EffluentTransferPort;
        port discharge : EffluentTransferPort;
        port powerIn : PowerPort;
        port command : ControlPort;

        attribute ratedFlow : VolumeFlowRate = 0.040 [m^3/s];
        attribute ratedHead : Pressure = 300 [kPa];
        attribute motorPower : Power = 11.0 [kW];
        attribute minimumSpeedFraction : Fraction = 0.30;
        attribute maximumSpeedFraction : Fraction = 1.00;

        state pumpState {
            entry; then Stopped;

            state Stopped;
            state Starting;
            state Running;
            state Faulted;
            state LockedOut;

            transition Stopped_to_Starting first Stopped
                accept ControlSignal
                then Starting;

            transition Starting_to_Running first Starting
                after 5 [s]
                then Running;

            transition Running_to_Faulted first Running
                if command::feedback.healthy == false
                then Faulted;

            transition Faulted_to_LockedOut first Faulted
                after 10 [s]
                then LockedOut;

            transition LockedOut_to_Stopped first LockedOut
                accept ControlSignal
                then Stopped;
        }
    }

    part def ControlSystem {
        port screenControl : ControlPort;
        port tankControl : ControlPort;
        port dosingControl : ControlPort;
        port pHControl : ControlPort;
        port filterControl : ControlPort;
        port uvControl : ControlPort;
        port oxidationControl : ControlPort;
        port pumpControl : ControlPort;
        port releaseControl : ControlPort;

        attribute samplingInterval : TimeDuration = 5 [s];
        attribute emergencyShutdownDelay : TimeDuration = 2 [s];
        attribute automaticModeEnabled : Boolean = true;

        state operatingMode {
            entry; then Standby;

            state Standby;
            state Startup;
            state Treating;
            state QualityHold;
            state Maintenance;
            state EmergencyShutdown;

            transition Standby_to_Startup first Standby
                accept ControlSignal
                if automaticModeEnabled == true
                then Startup;

            transition Startup_to_Treating first Startup
                after 180 [s]
                then Treating;

            transition Treating_to_QualityHold first Treating
                if releaseControl::feedback.valid == false
                then QualityHold;

            transition QualityHold_to_Treating first QualityHold
                accept ControlSignal
                then Treating;

            transition Treating_to_Maintenance first Treating
                accept ControlSignal
                then Maintenance;

            transition Maintenance_to_Standby first Maintenance
                accept ControlSignal
                then Standby;

            transition Treating_to_EmergencyShutdown first Treating
                if screenControl::feedback.healthy == false
                then EmergencyShutdown;
        }

        action superviseTreatment {
            first readSensors;
            then computeSetpoints;
            then commandActuators;
            then evaluateCompliance;
            then done;

            action readSensors;
            action computeSetpoints;
            action commandActuators;
            action evaluateCompliance;
        }
    }

    part def EffluentDecontaminationSystem {
        port rawEffluentIn : EffluentInletPort;
        port cleanEffluentOut : EffluentOutletPort;
        port sludgeOut : SludgeOutletPort;
        port oxidantSupply : ChemicalSupplyPort;
        port neutralizationSupply : ChemicalSupplyPort;
        port electricalSupply : PowerPort;

        attribute designFlow : VolumeFlowRate = 0.035 [m^3/s];
        attribute peakFlow : VolumeFlowRate = 0.050 [m^3/s];
        attribute minimumLogReduction : ScalarValues::Real = 6.0;
        attribute maximumDischargeCOD : Concentration = 50.0 [mg/L];
        attribute primaryFunction : String = "Receive contaminated liquid effluent, remove solids, neutralize chemistry, inactivate biological contaminants, oxidize residual pollutants, verify quality, and discharge compliant decontaminated effluent while isolating sludge and unsafe flows.";

        part screen : ScreeningUnit;
        part equalizationTank : EqualizationTank;
        part dosingUnit : ChemicalDosingUnit;
        part pHUnit : pHAdjustmentUnit;
        part transferPump : RecirculationPump;
        part filter : FiltrationModule;
        part uvReactor : UVReactor;
        part oxidationReactor : CatalyticOxidationReactor;
        part finalMonitoring : FinalMonitoringSkid;
        part controller : ControlSystem;

        connect rawEffluentIn to screen.inlet;
        connect screen.screenedOutlet to equalizationTank.inlet;
        connect screen.screeningsOutlet to sludgeOut;
        connect equalizationTank.outlet to pHUnit.inlet;
        connect pHUnit.outlet to dosingUnit.effluentIn;
        connect dosingUnit.effluentOut to transferPump.suction;
        connect transferPump.discharge to filter.inlet;
        connect filter.filtrateOutlet to uvReactor.inlet;
        connect uvReactor.outlet to oxidationReactor.inlet;
        connect oxidationReactor.outlet to finalMonitoring.inlet;
        connect finalMonitoring.outlet to cleanEffluentOut;
        connect filter.sludgeOutlet to sludgeOut;

        connect oxidantSupply to dosingUnit.chemicalIn;
        connect oxidantSupply to oxidationReactor.oxidantFeed;
        connect neutralizationSupply to pHUnit.command;
        connect electricalSupply to transferPump.powerIn;
        connect electricalSupply to uvReactor.powerIn;
        connect electricalSupply to oxidationReactor.powerIn;

        connect controller.screenControl to screen.screenedOutlet;
        connect controller.tankControl to equalizationTank.levelMonitor;
        connect controller.dosingControl to dosingUnit.command;
        connect controller.pHControl to pHUnit.command;
        connect controller.filterControl to filter.pressureMonitor;
        connect controller.uvControl to uvReactor.intensityMonitor;
        connect controller.releaseControl to finalMonitoring.pathogenMonitor;

        action performEffluentDecontamination {
            in item influent : RawEffluent;
            in item oxidant : DecontaminationAgent;
            in item neutralizer : DecontaminationAgent;
            out item discharged : DecontaminatedEffluent;
            out item wasteSludge : SeparatedSludge;

            first receiveEffluent;
            then removeGrossSolids;
            then equalizeFlow;
            then neutralizePH;
            then applyChemicalDose;
            then pumpThroughFilter;
            then disinfectWithUV;
            then oxidizeResidualContaminants;
            then verifyDischargeQuality;
            then dischargeCompliantEffluent;
            then done;

            action receiveEffluent;
            action removeGrossSolids;
            action equalizeFlow;
            action neutralizePH;
            action applyChemicalDose;
            action pumpThroughFilter;
            action disinfectWithUV;
            action oxidizeResidualContaminants;
            action verifyDischargeQuality;
            action dischargeCompliantEffluent;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : EffluentDecontaminationSystem;

        doc /* The effluent decontamination system shall transform incoming contaminated liquid effluent into verified compliant discharge by screening solids, stabilizing hydraulic flow, adjusting pH, applying chemical decontamination, filtering suspended matter, irradiating biological contaminants, oxidizing residual pollutants, and monitoring final quality. */

        require constraint {
            system.designFlow <= system.peakFlow
        }
    }

    requirement def FlowCapacityRequirement {
        subject system : EffluentDecontaminationSystem;

        doc /* The system shall continuously process nominal effluent flow without hydraulic bypass of untreated effluent. */

        require constraint {
            system.designFlow <= 0.035 [m^3/s] and system.peakFlow >= 0.050 [m^3/s]
        }
    }

    requirement def BiologicalReductionRequirement {
        subject system : EffluentDecontaminationSystem;

        doc /* The system shall provide at least six-log biological contaminant reduction before release. */

        require constraint {
            system.minimumLogReduction >= 6.0
        }
    }

    requirement def DischargeQualityRequirement {
        subject system : EffluentDecontaminationSystem;

        doc /* Discharged effluent shall meet final quality limits for pH, suspended matter, biological load, and chemical oxygen demand. */

        require constraint {
            system.maximumDischargeCOD <= 50.0 [mg/L]
        }
    }

    requirement def SafeStateRequirement {
        subject controller : ControlSystem;

        doc /* The control system shall place the process in quality hold or emergency shutdown when monitored treatment performance becomes invalid or equipment health is lost. */

        require constraint {
            controller.emergencyShutdownDelay <= 2 [s]
        }
    }

    requirement def SludgeIsolationRequirement {
        subject system : EffluentDecontaminationSystem;

        doc /* Separated solids and filter backwash sludge shall be routed to the sludge outlet and shall not mix with compliant effluent discharge. */

        require constraint {
            system.screen.removalEfficiency >= 0.90 and system.filter.solidsRemovalEfficiency >= 0.98
        }
    }

    satisfy PrimaryFunctionRequirement by EffluentDecontaminationSystem;
    satisfy FlowCapacityRequirement by EffluentDecontaminationSystem;
    satisfy BiologicalReductionRequirement by EffluentDecontaminationSystem;
    satisfy DischargeQualityRequirement by EffluentDecontaminationSystem;
    satisfy SafeStateRequirement by EffluentDecontaminationSystem::controller;
    satisfy SludgeIsolationRequirement by EffluentDecontaminationSystem;

}