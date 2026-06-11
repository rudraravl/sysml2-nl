package EliseSorensenOstomyCareSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volume {
        :> scalar: Real;
        unit = "mL";
    }

    attribute def FlowRate {
        :> scalar: Real;
        unit = "mL/h";
    }

    attribute def Pressure {
        :> scalar: Real;
        unit = "kPa";
    }

    attribute def Mass {
        :> scalar: Real;
        unit = "g";
    }

    attribute def Duration {
        :> scalar: Real;
        unit = "h";
    }

    attribute def Length {
        :> scalar: Real;
        unit = "mm";
    }

    attribute def AdhesionStrength {
        :> scalar: Real;
        unit = "N/25mm";
    }

    attribute def OdorConcentration {
        :> scalar: Real;
        unit = "ppm";
    }

    enum def PouchState {
        enum sealed;
        empty;
        collecting;
        nearCapacity;
        sealedForDisposal;
        removed;
    }

    enum def SkinCondition {
        enum healthy;
        irritated;
        compromised;
    }

    item def StomaOutput {
        attribute volume: Volume;
        attribute flowRate: FlowRate;
        attribute odorLoad: OdorConcentration;
        attribute pressureAtEntry: Pressure;
    }

    item def FilteredGas {
        attribute flowRate: FlowRate;
        attribute odorConcentration: OdorConcentration;
    }

    item def UsedPouchWaste {
        attribute retainedVolume: Volume;
        attribute sealedMass: Mass;
        attribute odorConcentrationExternal: OdorConcentration;
    }

    item def SkinBarrierInterface {
        attribute apertureDiameter: Length;
        attribute adhesionStrength: AdhesionStrength;
        attribute wearDuration: Duration;
        attribute observedSkinCondition: SkinCondition;
    }

    port def StomaInletPort {
        in item output: StomaOutput;
    }

    port def GasVentPort {
        out item ventedGas: FilteredGas;
    }

    port def WasteRemovalPort {
        out item wastePackage: UsedPouchWaste;
    }

    port def SkinContactPort {
        inout item barrierInterface: SkinBarrierInterface;
    }

    action def CollectStomaOutput {
        in item incomingOutput: StomaOutput;
        inout item pouchContents: StomaOutput;
        out attribute collectedVolume: Volume;

        first start;
        then accept incomingOutput;
        then mergeOutput;

        action mergeOutput {
            out attribute collectedVolume: Volume;
        }

        then done;
    }

    action def FilterOdorGas {
        in item rawGas: FilteredGas;
        out item treatedGas: FilteredGas;

        first receiveGas;
        then passThroughCharcoalLayer;
        then releaseLowOdorGas;
    }

    action def SealForDisposal {
        in item pouchContents: StomaOutput;
        out item sealedWaste: UsedPouchWaste;

        first closeDrainOrOutlet;
        then isolateAdhesiveSurface;
        then containResidualOdor;
        then produceSealedWaste;
    }

    action def ProtectPeristomalSkin {
        inout item skinInterface: SkinBarrierInterface;

        first conformBarrierToSkin;
        then distributeAdhesiveLoad;
        then maintainDrySeal;
        then monitorWearLimit;
    }

    part def HydrocolloidSkinBarrier {
        port skinPort: SkinContactPort;

        attribute apertureDiameter: Length = 35 [mm];
        attribute nominalAdhesionStrength: AdhesionStrength = 12 [N/25mm];
        attribute maximumWearDuration: Duration = 72 [h];

        perform action protectSkin: ProtectPeristomalSkin;
    }

    part def DisposableCollectionPouch {
        port inlet: StomaInletPort;
        port vent: GasVentPort;
        port removal: WasteRemovalPort;

        attribute nominalCapacity: Volume = 600 [mL];
        attribute nearCapacityThreshold: Volume = 450 [mL];
        attribute maximumBackPressure: Pressure = 1.5 [kPa];
        attribute emptyMass: Mass = 28 [g];
        attribute externalOdorLimit: OdorConcentration = 2 [ppm];

        item contents: StomaOutput;

        perform action collectOutput: CollectStomaOutput;
        perform action sealWaste: SealForDisposal;

        state def PouchLifecycle {
            entry action initialize {
                contents.volume = 0 [mL];
            }

            state Empty;
            state Collecting;
            state NearCapacity;
            state SealedForDisposal;
            state Removed;

            transition first Empty then Collecting
                accept StomaOutput
                do collectOutput;

            transition Collecting then NearCapacity
                if contents.volume >= nearCapacityThreshold;

            transition NearCapacity then SealedForDisposal
                do sealWaste;

            transition SealedForDisposal then Removed
                accept removal.wastePackage;
        }

        exhibit state lifecycle: PouchLifecycle;
    }

    part def CharcoalOdorFilter {
        port gasIn: GasVentPort;
        port gasOut: GasVentPort;

        attribute ratedGasFlow: FlowRate = 40 [mL/h];
        attribute odorReductionEfficiency: Real = 0.95;
        attribute saturationDuration: Duration = 48 [h];

        perform action filterGas: FilterOdorGas;
    }

    part def OutletClosure {
        attribute closureSealPressure: Pressure = 3.0 [kPa];
        attribute reusableClosuresBeforeReplacement: Integer = 10;

        action closeOutlet {
            first alignOutletSleeve;
            then foldClosure;
            then pressSeal;
        }

        action openOutlet {
            first releaseSeal;
            then unfoldSleeve;
            then allowDrainage;
        }
    }

    part def SorensenInspiredOstomyPouchSystem {
        doc
        /*
         * High-level primary function:
         * Provide a discreet, disposable, skin-protective pouching system that
         * continuously collects stoma output, contains odor and leakage, and
         * allows hygienic removal or disposal by the wearer or caregiver.
         */

        port stomaInterface: StomaInletPort;
        port skinInterface: SkinContactPort;
        port gasExhaust: GasVentPort;
        port disposalExit: WasteRemovalPort;

        part skinBarrier: HydrocolloidSkinBarrier;
        part pouch: DisposableCollectionPouch;
        part odorFilter: CharcoalOdorFilter;
        part outletClosure: OutletClosure;

        connect stomaInterface to pouch.inlet;
        connect skinInterface to skinBarrier.skinPort;
        connect pouch.vent to odorFilter.gasIn;
        connect odorFilter.gasOut to gasExhaust;
        connect pouch.removal to disposalExit;

        attribute targetWearDuration: Duration = 48 [h];
        attribute maximumAllowedLeakageVolume: Volume = 1 [mL];
        attribute maximumExternalOdor: OdorConcentration = 2 [ppm];
        attribute maximumFilledMass: Mass = 700 [g];

        action operateSystem {
            first prepareSkinBarrier;
            then attachBarrierAroundStoma;
            then collectAndContainOutput;
            then ventFilteredGas;
            then removeAndSealUsedPouch;

            action prepareSkinBarrier {
                out item preparedInterface: SkinBarrierInterface;
            }

            action attachBarrierAroundStoma {
                in item preparedInterface: SkinBarrierInterface;
                do skinBarrier.protectSkin;
            }

            action collectAndContainOutput {
                do pouch.collectOutput;
            }

            action ventFilteredGas {
                do odorFilter.filterGas;
            }

            action removeAndSealUsedPouch {
                do pouch.sealWaste;
            }
        }

        state def SystemUseLifecycle {
            state Packaged;
            state PreparedForApplication;
            state AppliedToSkin;
            state InUse;
            state NeedsChange;
            state RemovedAndSealed;
            state Disposed;

            transition first Packaged then PreparedForApplication
                accept "open sterile package";

            transition PreparedForApplication then AppliedToSkin
                accept SkinBarrierInterface
                do skinBarrier.protectSkin;

            transition AppliedToSkin then InUse
                accept StomaOutput
                do pouch.collectOutput;

            transition InUse then NeedsChange
                if pouch.contents.volume >= pouch.nearCapacityThreshold;

            transition InUse then NeedsChange
                if skinBarrier.maximumWearDuration <= targetWearDuration;

            transition NeedsChange then RemovedAndSealed
                do pouch.sealWaste;

            transition RemovedAndSealed then Disposed
                accept UsedPouchWaste;
        }

        exhibit state useLifecycle: SystemUseLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: SorensenInspiredOstomyPouchSystem;

        doc
        /*
         * The system shall continuously collect stoma output into a wearable
         * disposable pouch while protecting peristomal skin, limiting odor, and
         * enabling hygienic sealed disposal.
         */

        require constraint {
            system.maximumAllowedLeakageVolume <= 1 [mL]
        }

        require constraint {
            system.maximumExternalOdor <= 2 [ppm]
        }
    }

    requirement def SkinProtectionRequirement {
        subject barrier: HydrocolloidSkinBarrier;

        doc
        /*
         * The skin barrier shall maintain adhesion and a dry seal for normal
         * wear without causing avoidable peristomal skin injury.
         */

        require constraint {
            barrier.nominalAdhesionStrength >= 10 [N/25mm]
        }

        require constraint {
            barrier.maximumWearDuration >= 48 [h]
        }
    }

    requirement def CapacityRequirement {
        subject pouch: DisposableCollectionPouch;

        doc
        /*
         * The pouch shall provide sufficient volume for routine daily output
         * while indicating a near-capacity condition before leakage risk rises.
         */

        require constraint {
            pouch.nominalCapacity >= 500 [mL]
        }

        require constraint {
            pouch.nearCapacityThreshold < pouch.nominalCapacity
        }
    }

    requirement def OdorContainmentRequirement {
        subject filter: CharcoalOdorFilter;

        doc
        /*
         * The odor filter shall reduce vented gas odor concentration during
         * normal wear.
         */

        require constraint {
            filter.odorReductionEfficiency >= 0.90
        }

        require constraint {
            filter.ratedGasFlow >= 30 [mL/h]
        }
    }

    requirement def DisposalRequirement {
        subject system: SorensenInspiredOstomyPouchSystem;

        doc
        /*
         * After removal, the used pouch shall form a sealed waste package that
         * can be handled without direct contact with stoma output.
         */

        require constraint {
            system.pouch.externalOdorLimit <= system.maximumExternalOdor
        }
    }

    satisfy PrimaryFunctionRequirement by SorensenInspiredOstomyPouchSystem;
    satisfy SkinProtectionRequirement by HydrocolloidSkinBarrier;
    satisfy CapacityRequirement by DisposableCollectionPouch;
    satisfy OdorContainmentRequirement by CharcoalOdorFilter;
    satisfy DisposalRequirement by SorensenInspiredOstomyPouchSystem;
}