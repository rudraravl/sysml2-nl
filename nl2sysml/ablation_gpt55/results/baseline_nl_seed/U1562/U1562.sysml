package RadioisotopeThermoelectricGeneratorSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ThermalPower :> power {
        :>> unit = W;
    }

    attribute def ElectricalPower :> power {
        :>> unit = W;
    }

    attribute def ElectricVoltage :> electricPotential {
        :>> unit = V;
    }

    attribute def ElectricCurrent :> electricCurrent {
        :>> unit = A;
    }

    attribute def Temperature :> thermodynamicTemperature {
        :>> unit = K;
    }

    attribute def MassValue :> mass {
        :>> unit = kg;
    }

    attribute def TimeValue :> time {
        :>> unit = s;
    }

    attribute def Efficiency :> ScalarValues::Real;

    attribute def Fraction :> ScalarValues::Real;

    item def RadioisotopeFuel {
        attribute isotopeName : String = "Plutonium-238 dioxide";
        attribute fuelMass : MassValue = 4.80 [kg];
        attribute halfLife : TimeValue = 2763000000 [s];
        attribute beginningOfLifeThermalPower : ThermalPower = 2000 [W];
    }

    item def DecayHeatFlow {
        attribute thermalPower : ThermalPower;
        attribute hotSideTemperature : Temperature;
        attribute containmentIntegrity : Fraction;
    }

    item def WasteHeatFlow {
        attribute rejectedThermalPower : ThermalPower;
        attribute radiatorTemperature : Temperature;
    }

    item def RawDCPowerFlow {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute power : ElectricalPower;
        attribute rippleFraction : Fraction;
    }

    item def RegulatedDCPowerFlow {
        attribute voltage : ElectricVoltage = 28 [V];
        attribute current : ElectricCurrent;
        attribute power : ElectricalPower;
        attribute rippleFraction : Fraction;
    }

    item def PowerDemand {
        attribute requestedPower : ElectricalPower;
        attribute busVoltage : ElectricVoltage = 28 [V];
    }

    item def PowerCommand {
        attribute enableGeneration : Boolean;
        attribute requestedBusVoltage : ElectricVoltage = 28 [V];
        attribute loadLimit : ElectricalPower = 120 [W];
    }

    item def GeneratorTelemetry {
        attribute deliveredPower : ElectricalPower;
        attribute hotJunctionTemperature : Temperature;
        attribute coldJunctionTemperature : Temperature;
        attribute conversionEfficiency : Efficiency;
        attribute containmentIntegrity : Fraction;
        attribute operatingNominal : Boolean;
    }

    port def HeatOutputPort {
        out item heat : DecayHeatFlow;
    }

    port def HeatInputPort {
        in item heat : DecayHeatFlow;
    }

    port def WasteHeatOutputPort {
        out item wasteHeat : WasteHeatFlow;
    }

    port def WasteHeatInputPort {
        in item wasteHeat : WasteHeatFlow;
    }

    port def RawDCPowerOutputPort {
        out item rawPower : RawDCPowerFlow;
    }

    port def RawDCPowerInputPort {
        in item rawPower : RawDCPowerFlow;
    }

    port def RegulatedDCPowerOutputPort {
        out item dcPower : RegulatedDCPowerFlow;
    }

    port def RegulatedDCPowerInputPort {
        in item demand : PowerDemand;
    }

    port def CommandInputPort {
        in item command : PowerCommand;
    }

    port def TelemetryOutputPort {
        out item telemetry : GeneratorTelemetry;
    }

    constraint def ThermalToElectricalConversion {
        in availableThermalPower : ThermalPower;
        in conversionEfficiency : Efficiency;
        in producedElectricalPower : ElectricalPower;
        constraint {
            producedElectricalPower == availableThermalPower * conversionEfficiency
        }
    }

    constraint def MinimumPrimaryPower {
        in deliveredPower : ElectricalPower;
        constraint {
            deliveredPower >= 100 [W]
        }
    }

    constraint def SafeHotJunctionTemperature {
        in hotJunctionTemperature : Temperature;
        constraint {
            hotJunctionTemperature <= 1273 [K]
        }
    }

    action def GenerateDecayHeat {
        out item heat : DecayHeatFlow;
    }

    action def ConvertDecayHeatToElectricity {
        in item heat : DecayHeatFlow;
        out item rawPower : RawDCPowerFlow;
        out item rejectedHeat : WasteHeatFlow;
    }

    action def RegulateDirectCurrentPower {
        in item rawPower : RawDCPowerFlow;
        in item command : PowerCommand;
        out item regulatedPower : RegulatedDCPowerFlow;
        out item telemetry : GeneratorTelemetry;
    }

    action def RejectWasteHeat {
        in item wasteHeat : WasteHeatFlow;
    }

    action def ProvideContinuousDCElectricalPower {
        in item command : PowerCommand;
        out item suppliedPower : RegulatedDCPowerFlow;
        out item status : GeneratorTelemetry;

        action heatGeneration : GenerateDecayHeat;
        action thermoelectricConversion : ConvertDecayHeatToElectricity;
        action powerRegulation : RegulateDirectCurrentPower;
        action heatRejection : RejectWasteHeat;

        flow heatGeneration.heat to thermoelectricConversion.heat;
        flow thermoelectricConversion.rawPower to powerRegulation.rawPower;
        flow thermoelectricConversion.rejectedHeat to heatRejection.wasteHeat;
        flow command to powerRegulation.command;
        flow powerRegulation.regulatedPower to suppliedPower;
        flow powerRegulation.telemetry to status;
    }

    event def LaunchSafetyRelease;

    event def WarmupComplete;

    event def LoadConnected;

    event def EndOfMissionPowerLow;

    event def SafeHoldCommanded;

    state def RTGOperatingStates {
        entry; then launchSafe;

        state launchSafe;
        state thermalWarmup;
        state nominalGeneration;
        state degradedGeneration;
        state safeHold;

        transition releaseAfterLaunch
            first launchSafe
            accept LaunchSafetyRelease
            then thermalWarmup;

        transition startNominalGeneration
            first thermalWarmup
            accept WarmupComplete
            then nominalGeneration;

        transition acceptLoad
            first nominalGeneration
            accept LoadConnected
            then nominalGeneration;

        transition naturalDecayToDegradedMode
            first nominalGeneration
            accept EndOfMissionPowerLow
            then degradedGeneration;

        transition commandSafeHoldFromNominal
            first nominalGeneration
            accept SafeHoldCommanded
            then safeHold;

        transition commandSafeHoldFromDegraded
            first degradedGeneration
            accept SafeHoldCommanded
            then safeHold;
    }

    part def RadioisotopeHeatSource {
        attribute fuelInventory : RadioisotopeFuel;
        attribute fuelMass : MassValue = 4.80 [kg];
        attribute beginningOfLifeThermalPower : ThermalPower = 2000 [W];
        attribute nominalThermalPower : ThermalPower = 1920 [W];
        attribute hotSurfaceTemperature : Temperature = 1125 [K];
        attribute containmentIntegrity : Fraction = 1.0;
        attribute shieldMass : MassValue = 18.0 [kg];

        port thermalOutput : HeatOutputPort;

        perform action decayHeatProduction : GenerateDecayHeat;
    }

    part def ThermoelectricModule {
        attribute hotJunctionTemperature : Temperature = 1125 [K];
        attribute coldJunctionTemperature : Temperature = 475 [K];
        attribute seebeckPairEfficiency : Efficiency = 0.065;
        attribute moduleElectricalPower : ElectricalPower = 1.30 [W];

        port heatIn : HeatInputPort;
        port rawPowerOut : RawDCPowerOutputPort;
        port wasteHeatOut : WasteHeatOutputPort;

        perform action moduleConversion : ConvertDecayHeatToElectricity;
    }

    part def ThermoelectricConverter {
        attribute conversionEfficiency : Efficiency = 0.065;
        attribute nominalRawElectricalPower : ElectricalPower = 125 [W];
        attribute nominalWasteHeatPower : ThermalPower = 1795 [W];
        attribute hotJunctionTemperature : Temperature = 1125 [K];
        attribute coldJunctionTemperature : Temperature = 475 [K];

        part module[96] : ThermoelectricModule;

        port heatInput : HeatInputPort;
        port rawElectricalOutput : RawDCPowerOutputPort;
        port wasteHeatOutput : WasteHeatOutputPort;

        perform action convertHeat : ConvertDecayHeatToElectricity;
    }

    part def HeatRejectionAssembly {
        attribute nominalRejectedThermalPower : ThermalPower = 1795 [W];
        attribute radiatorTemperature : Temperature = 475 [K];
        attribute radiatorMass : MassValue = 22.0 [kg];

        port wasteHeatInput : WasteHeatInputPort;

        perform action rejectHeat : RejectWasteHeat;
    }

    part def PowerConditioningUnit {
        attribute regulatedBusVoltage : ElectricVoltage = 28 [V];
        attribute maximumContinuousOutputPower : ElectricalPower = 125 [W];
        attribute minimumMissionOutputPower : ElectricalPower = 100 [W];
        attribute conditioningEfficiency : Efficiency = 0.96;
        attribute maximumRippleFraction : Fraction = 0.02;
        attribute electronicsMass : MassValue = 6.5 [kg];

        port rawElectricalInput : RawDCPowerInputPort;
        port regulatedElectricalOutput : RegulatedDCPowerOutputPort;
        port commandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;

        perform action regulatePower : RegulateDirectCurrentPower;
    }

    part def RadioisotopeThermoelectricGenerator {
        doc /* Primary high-level function: continuously convert heat released by radioisotope decay into regulated direct-current electrical power for an external load, with no moving mechanical conversion stage, while rejecting unused thermal energy to space. */

        attribute nominalElectricalPower : ElectricalPower = 120 [W];
        attribute beginningOfLifeElectricalPower : ElectricalPower = 125 [W];
        attribute minimumMissionElectricalPower : ElectricalPower = 100 [W];
        attribute nominalThermalPower : ThermalPower = 1920 [W];
        attribute endOfMissionThermalPower : ThermalPower = 1540 [W];
        attribute busVoltage : ElectricVoltage = 28 [V];
        attribute totalMass : MassValue = 51.3 [kg];
        attribute designLife : TimeValue = 504576000 [s];

        part heatSource : RadioisotopeHeatSource;
        part converter : ThermoelectricConverter;
        part radiator : HeatRejectionAssembly;
        part powerConditioner : PowerConditioningUnit;

        port commandInput : CommandInputPort;
        port spacecraftLoadDemand : RegulatedDCPowerInputPort;
        port spacecraftPowerOutput : RegulatedDCPowerOutputPort;
        port telemetryOutput : TelemetryOutputPort;

        connection heatSourceToConverter connect heatSource.thermalOutput to converter.heatInput;
        connection converterWasteToRadiator connect converter.wasteHeatOutput to radiator.wasteHeatInput;
        connection converterRawPowerToConditioner connect converter.rawElectricalOutput to powerConditioner.rawElectricalInput;
        connection conditionerOutputToSpacecraftBus connect powerConditioner.regulatedElectricalOutput to spacecraftPowerOutput;
        connection externalCommandToConditioner connect commandInput to powerConditioner.commandInput;
        connection conditionerTelemetryToExternalPort connect powerConditioner.telemetryOutput to telemetryOutput;

        perform action primaryFunction : ProvideContinuousDCElectricalPower;

        exhibit state operatingStates : RTGOperatingStates;

        assert constraint primaryPowerConstraint : MinimumPrimaryPower {
            in deliveredPower = minimumMissionElectricalPower;
        }

        assert constraint hotJunctionConstraint : SafeHotJunctionTemperature {
            in hotJunctionTemperature = converter.hotJunctionTemperature;
        }

        assert constraint nominalConversionConstraint : ThermalToElectricalConversion {
            in availableThermalPower = nominalThermalPower;
            in conversionEfficiency = converter.conversionEfficiency;
            in producedElectricalPower = beginningOfLifeElectricalPower;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide continuous regulated direct-current electrical power by converting radioisotope decay heat into electrical energy and delivering at least 100 W to the external load during the mission. */

        subject generator : RadioisotopeThermoelectricGenerator;

        require constraint {
            generator.minimumMissionElectricalPower >= 100 [W]
        }

        require constraint {
            generator.busVoltage == 28 [V]
        }
    }

    requirement def NoMovingConversionStageRequirement {
        doc /* The thermoelectric conversion path shall produce electrical power directly from a temperature difference without a rotating or reciprocating mechanical power stage. */

        subject generator : RadioisotopeThermoelectricGenerator;

        require constraint {
            generator.converter.conversionEfficiency >= 0.05
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The generator shall maintain thermoelectric hot-junction temperature within the safe design limit while rejecting unused heat. */

        subject generator : RadioisotopeThermoelectricGenerator;

        require constraint {
            generator.converter.hotJunctionTemperature <= 1273 [K]
        }
    }

    part deepSpaceRTG : RadioisotopeThermoelectricGenerator {
        :>> nominalElectricalPower = 120 [W];
        :>> beginningOfLifeElectricalPower = 125 [W];
        :>> minimumMissionElectricalPower = 100 [W];
        :>> nominalThermalPower = 1920 [W];
        :>> busVoltage = 28 [V];
        :>> totalMass = 51.3 [kg];
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject generator = deepSpaceRTG;
    }

    requirement noMovingConversionStage : NoMovingConversionStageRequirement {
        subject generator = deepSpaceRTG;
    }

    requirement thermalSafety : ThermalSafetyRequirement {
        subject generator = deepSpaceRTG;
    }

    satisfy primaryFunction by deepSpaceRTG;
    satisfy noMovingConversionStage by deepSpaceRTG;
    satisfy thermalSafety by deepSpaceRTG;
}
