package CarbonPasteElectrodeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = "V";
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = "A";
    }

    attribute def ElectricalResistance :> ISQ::resistance {
        unit = "Ohm";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "K";
    }

    attribute def Length :> ISQ::length {
        unit = "m";
    }

    attribute def Area :> ISQ::area {
        unit = "m^2";
    }

    attribute def Volume :> ISQ::volume {
        unit = "m^3";
    }

    attribute def MassFraction {
        :>> scalar : Real;
        unit = "1";
    }

    attribute def Concentration {
        :>> scalar : Real;
        unit = "mol/m^3";
    }

    attribute def ScanRate {
        :>> scalar : Real;
        unit = "V/s";
    }

    attribute def SignalToNoiseRatio {
        :>> scalar : Real;
        unit = "1";
    }

    item def Electron {
        attribute charge : ElectricCurrent;
    }

    item def Ion {
        attribute speciesName : String;
        attribute chargeNumber : Integer;
        attribute concentration : Concentration;
    }

    item def RedoxAnalyte {
        attribute speciesName : String;
        attribute bulkConcentration : Concentration;
        attribute formalPotential : ElectricPotential;
        attribute diffusionCoefficient {
            :>> scalar : Real;
            unit = "m^2/s";
        }
    }

    item def ElectrolyteSolution {
        attribute supportingElectrolyteName : String;
        attribute ionicStrength : Concentration;
        attribute pH : Real;
        attribute temperature : Temperature;
    }

    item def ElectrochemicalSignal {
        attribute appliedPotential : ElectricPotential;
        attribute measuredCurrent : ElectricCurrent;
        attribute sampledTime {
            :>> scalar : Real;
            unit = "s";
        }
        attribute signalToNoiseRatio : SignalToNoiseRatio;
    }

    port def ElectricalTerminalPort {
        out item electrons : Electron;
        in attribute potential : ElectricPotential;
        out attribute current : ElectricCurrent;
    }

    port def ElectrolyteInterfacePort {
        in item solution : ElectrolyteSolution;
        in item analyte : RedoxAnalyte;
        in item ions : Ion;
        out item signal : ElectrochemicalSignal;
    }

    port def MechanicalMountPort {
        in attribute insertionDepth : Length;
        out attribute exposedArea : Area;
    }

    action def PrepareCarbonPaste {
        in attribute graphiteMassFraction : MassFraction;
        in attribute binderMassFraction : MassFraction;
        in attribute modifierMassFraction : MassFraction;
        out attribute pasteHomogeneity : Real;
        out attribute effectiveConductivity {
            :>> scalar : Real;
            unit = "S/m";
        }

        first start;
        then mixGraphiteBinder;
        then incorporateModifier;
        then packElectrodeCavity;
        then polishSurface;
        then done;

        action mixGraphiteBinder;
        action incorporateModifier;
        action packElectrodeCavity;
        action polishSurface;
    }

    action def PerformVoltammetricMeasurement {
        in item sample : ElectrolyteSolution;
        in item targetAnalyte : RedoxAnalyte;
        in attribute initialPotential : ElectricPotential;
        in attribute finalPotential : ElectricPotential;
        in attribute scanRate : ScanRate;
        out item response : ElectrochemicalSignal;

        first conditionElectrodeSurface;
        then immerseInSample;
        then applyPotentialSweep;
        then collectCurrentResponse;
        then reportSignal;

        action conditionElectrodeSurface;
        action immerseInSample;
        action applyPotentialSweep;
        action collectCurrentResponse;
        action reportSignal;
    }

    state def ElectrodeOperationalState {
        entry action initializeOpenCircuit;

        state Idle;
        state Conditioning;
        state Ready;
        state Measuring;
        state RegeneratingSurface;
        state Faulted;

        transition first Idle;
        transition Idle_to_Conditioning
            first Idle
            accept prepareCommand
            then Conditioning;

        transition Conditioning_to_Ready
            first Conditioning
            accept stableBaselineDetected
            then Ready;

        transition Ready_to_Measuring
            first Ready
            accept measurementCommand
            then Measuring;

        transition Measuring_to_Ready
            first Measuring
            accept sweepComplete
            then Ready;

        transition Ready_to_RegeneratingSurface
            first Ready
            accept renewSurfaceCommand
            then RegeneratingSurface;

        transition RegeneratingSurface_to_Conditioning
            first RegeneratingSurface
            accept surfaceRenewed
            then Conditioning;

        transition Any_to_Faulted
            accept leakageDetected
            then Faulted;

        action initializeOpenCircuit;
    }

    part def ConductiveGraphitePhase {
        attribute massFraction : MassFraction = 0.70;
        attribute particleMeanDiameter : Length = 5.0e-6;
        attribute electricalConductivity {
            :>> scalar : Real;
            unit = "S/m";
        } = 1.0e4;
    }

    part def BinderPhase {
        attribute materialName : String = "mineral oil";
        attribute massFraction : MassFraction = 0.28;
        attribute viscosity {
            :>> scalar : Real;
            unit = "Pa*s";
        } = 0.12;
        attribute hydrophobicityIndex : Real = 0.85;
    }

    part def ElectrocatalyticModifier {
        attribute materialName : String = "nanostructured carbon black";
        attribute massFraction : MassFraction = 0.02;
        attribute surfaceArea {
            :>> scalar : Real;
            unit = "m^2/g";
        } = 120.0;
        attribute catalyticActivityFactor : Real = 1.6;
    }

    part def CarbonPasteComposite {
        part graphite : ConductiveGraphitePhase;
        part binder : BinderPhase;
        part modifier : ElectrocatalyticModifier;

        attribute totalPasteVolume : Volume = 8.0e-8;
        attribute effectiveConductivity {
            :>> scalar : Real;
            unit = "S/m";
        } = 750.0;
        attribute porosity : Real = 0.18;

        perform action preparation : PrepareCarbonPaste {
            graphiteMassFraction = graphite.massFraction;
            binderMassFraction = binder.massFraction;
            modifierMassFraction = modifier.massFraction;
        }
    }

    part def ElectrodeBody {
        attribute bodyMaterial : String = "chemically resistant polymer";
        attribute cavityDiameter : Length = 3.0e-3;
        attribute cavityDepth : Length = 1.0e-2;
        attribute exposedGeometricArea : Area = 7.07e-6;

        port mount : MechanicalMountPort;
    }

    part def CurrentCollector {
        attribute materialName : String = "copper";
        attribute contactResistance : ElectricalResistance = 0.8;
        attribute leadLength : Length = 0.08;

        port terminal : ElectricalTerminalPort;
    }

    part def CarbonPasteElectrode {
        part body : ElectrodeBody;
        part paste : CarbonPasteComposite;
        part collector : CurrentCollector;

        port electrical : ElectricalTerminalPort;
        port interface : ElectrolyteInterfacePort;
        port mount : MechanicalMountPort;

        attribute nominalWorkingPotentialLower : ElectricPotential = -1.0;
        attribute nominalWorkingPotentialUpper : ElectricPotential = 1.2;
        attribute baselineCurrent : ElectricCurrent = 2.0e-8;
        attribute maximumRecommendedCurrent : ElectricCurrent = 1.0e-4;
        attribute usefulSurfaceArea : Area = 7.07e-6;

        connect collector.terminal to electrical;
        connect body.mount to mount;

        exhibit state operationalState : ElectrodeOperationalState;

        perform action measurement : PerformVoltammetricMeasurement;
    }

    part def ReferenceElectrode {
        attribute electrodeType : String = "Ag/AgCl";
        attribute referencePotential : ElectricPotential = 0.197;

        port interface : ElectrolyteInterfacePort;
        port electrical : ElectricalTerminalPort;
    }

    part def CounterElectrode {
        attribute materialName : String = "platinum wire";
        attribute activeArea : Area = 2.0e-5;

        port interface : ElectrolyteInterfacePort;
        port electrical : ElectricalTerminalPort;
    }

    part def Potentiostat {
        port workingTerminal : ElectricalTerminalPort;
        port referenceTerminal : ElectricalTerminalPort;
        port counterTerminal : ElectricalTerminalPort;

        attribute commandedPotential : ElectricPotential;
        attribute measuredWorkingCurrent : ElectricCurrent;
        attribute inputImpedance : ElectricalResistance = 1.0e12;
        attribute currentResolution : ElectricCurrent = 1.0e-9;
        attribute potentialResolution : ElectricPotential = 1.0e-3;

        action controlPotential {
            in attribute targetPotential : ElectricPotential;
            out attribute achievedPotential : ElectricPotential;
        }

        action measureCurrent {
            out attribute currentSample : ElectricCurrent;
        }
    }

    part def ElectrochemicalCell {
        part workingElectrode : CarbonPasteElectrode;
        part referenceElectrode : ReferenceElectrode;
        part counterElectrode : CounterElectrode;
        part electrolyte {
            item solution : ElectrolyteSolution;
            item analyte : RedoxAnalyte;
            attribute volume : Volume = 1.0e-5;
            attribute temperature : Temperature = 298.15;
        }

        port workingLead : ElectricalTerminalPort;
        port referenceLead : ElectricalTerminalPort;
        port counterLead : ElectricalTerminalPort;

        connect workingElectrode.electrical to workingLead;
        connect referenceElectrode.electrical to referenceLead;
        connect counterElectrode.electrical to counterLead;

        connect workingElectrode.interface to referenceElectrode.interface;
        connect referenceElectrode.interface to counterElectrode.interface;
    }

    part def CarbonPasteElectrodeSystem {
        part cell : ElectrochemicalCell;
        part potentiostat : Potentiostat;

        connect potentiostat.workingTerminal to cell.workingLead;
        connect potentiostat.referenceTerminal to cell.referenceLead;
        connect potentiostat.counterTerminal to cell.counterLead;

        attribute primaryFunction : String =
            "Convert oxidation or reduction of chemical species at a renewable carbon paste surface into a measurable electrical current under controlled potential.";

        attribute typicalScanRate : ScanRate = 0.050;
        attribute targetDetectionLimit : Concentration = 1.0e-6;
        attribute requiredSignalToNoiseRatio : SignalToNoiseRatio = 3.0;

        perform action highLevelMeasurement : PerformVoltammetricMeasurement {
            initialPotential = -0.2;
            finalPotential = 0.8;
            scanRate = typicalScanRate;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : CarbonPasteElectrodeSystem;

        doc /* The system shall provide a conductive, renewable carbon paste working electrode that supports electrochemical oxidation or reduction of a target analyte and outputs a current signal correlated with analyte concentration. */

        require constraint {
            system.targetDetectionLimit <= 1.0e-6 and
            system.requiredSignalToNoiseRatio >= 3.0
        }
    }

    requirement def PotentialControlRequirement {
        subject potentiostat : Potentiostat;

        doc /* The potentiostat shall control the potential between the carbon paste working electrode and the reference electrode with millivolt-scale resolution. */

        require constraint {
            potentiostat.potentialResolution <= 1.0e-3
        }
    }

    requirement def ConductivePasteRequirement {
        subject paste : CarbonPasteComposite;

        doc /* The carbon paste shall maintain sufficient conductive graphite continuity while retaining binder content for mechanical cohesion and renewable surface polishing. */

        require constraint {
            paste.effectiveConductivity >= 100.0 and
            paste.graphite.massFraction >= 0.60 and
            paste.binder.massFraction >= 0.20
        }
    }

    requirement def MeasurementSignalRequirement {
        subject system : CarbonPasteElectrodeSystem;

        doc /* During a voltammetric measurement the system shall produce an electrochemical signal whose current response is usable for high-level qualitative or quantitative detection of the target redox analyte. */

        require constraint {
            system.cell.workingElectrode.maximumRecommendedCurrent >= 1.0e-5 and
            system.cell.workingElectrode.baselineCurrent <= 1.0e-7
        }
    }

    satisfy PrimaryFunctionRequirement by CarbonPasteElectrodeSystem;
    satisfy PotentialControlRequirement by Potentiostat;
    satisfy ConductivePasteRequirement by CarbonPasteComposite;
    satisfy MeasurementSignalRequirement by CarbonPasteElectrodeSystem;
}