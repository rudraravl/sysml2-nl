package OstomyApplianceSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Mass;
    import ISQ::Volume;
    import ISQ::Length;
    import ISQ::Pressure;
    import ISQ::Force;
    import ISQ::Duration;

    // ---- Value types with units ----
    value type MassValue :> Mass { unit "kg"; }
    value type VolumeValue :> Volume { unit "m**3"; }
    value type LengthValue :> Length { unit "m"; }
    value type PressureValue :> Pressure { unit "kPa"; }
    value type ForceValue :> Force { unit "N"; }
    value type DurationValue :> Duration { unit "d"; }
    value type Percent :> Real;

    // ---- Item definitions ----
    item def BodilyWaste;
    item def Gas;
    item def OdorMolecules;
    item def FilteredGas;

    item waste : BodilyWaste;
    item stomaGas : Gas;
    item odor : OdorMolecules;
    item filteredGas : FilteredGas;

    // ---- Requirements ----
    requirement def LeakProofSealRequirement {
        doc "The baseplate shall maintain a leak-proof seal against the skin for several days.";
        attribute minWearDuration : DurationValue = 3 [d];
        attribute minAdhesiveStrength : PressureValue = 40 [kPa];
    }

    requirement def OdorBarrierRequirement {
        doc "The pouch shall act as an effective odor barrier through multi-layered film.";
        attribute minOdorBarrierRating : Percent = 0.95;
        attribute minFilmLayers : Integer = 2;
    }

    requirement def SecureCouplingRequirement {
        doc "The coupling ring shall resist accidental detachment under normal activity.";
        attribute minPullOffResistance : ForceValue = 30 [N];
        attribute lockType : String = "twist-lock";
    }

    requirement def FilterRequirement {
        doc "The charcoal filter shall release gas slowly while neutralizing odor molecules.";
        attribute minOdorNeutralizationEfficiency : Percent = 0.90;
        attribute maxGasFlowRate : VolumeValue = 0.0002 [m**3/s];
    }

    requirement def DrainValveRequirement {
        doc "The drain valve shall allow emptying without detaching the pouch from the baseplate.";
        attribute minFlowRate : VolumeValue = 0.0003 [m**3/s];
        attribute minLeakTightness : Percent = 0.99;
    }

    requirement def DiscreetRequirement {
        doc "The system shall be lightweight and discreet under clothing.";
        attribute maxSystemMass : MassValue = 0.15 [kg];
        attribute maxProfileThickness : LengthValue = 0.012 [m];
    }

    requirement def SkinIntegrityRequirement {
        doc "The system shall protect peristomal skin integrity by minimizing adhesive removal frequency.";
    }

    // ---- Port definitions ----
    port def SkinInterfacePort {
        out item collectedWaste : BodilyWaste;
        out item emittedGas : Gas;
    }

    port def CouplingPort {
        in item wasteFlow : BodilyWaste;
        out item gasReturn : Gas;
    }

    port def DrainPort {
        out item drainedWaste : BodilyWaste;
    }

    port def FilterPort {
        in item unfilteredGas : Gas;
        in item odorMolecules : OdorMolecules;
        out item filteredGasOut : FilteredGas;
    }

    // ---- Adhesive baseplate ----
    part def AdhesiveBaseplate {
        attribute adhesiveStrength : PressureValue = 50 [kPa];
        attribute wearDuration : DurationValue = 4 [d];
        attribute centralOpeningDiameter : LengthValue = 0.04 [m];
        attribute flexibility : Percent = 0.9;
        attribute isCutToFit : Boolean = true;

        port skinSide : SkinInterfacePort;
        port pouchSide : CouplingPort;

        requirement ref leakProofReq : LeakProofSealRequirement;

        action def CutOpening {
            in targetDiameter : LengthValue;
            out cutBaseplate : AdhesiveBaseplate;
        }

        action def ApplyToSkin {
            in skinSurface;
            out sealedBaseplate : AdhesiveBaseplate;
        }

        action def MaintainSeal {
            in duration : DurationValue;
        }
    }

    // ---- Coupling ring ----
    part def CouplingRing {
        attribute lockType : String = "twist-lock";
        attribute pullOffResistance : ForceValue = 35 [N];
        attribute ringDiameter : LengthValue = 0.06 [m];
        attribute isLocked : Boolean = false;

        port baseplateSide : CouplingPort;
        port pouchSide : CouplingPort;

        requirement ref secureReq : SecureCouplingRequirement;

        action def LockPouch {
            in baseplateRing : CouplingRing;
            in pouchRing : CouplingRing;
            out lockedCoupling : CouplingRing;
        }

        action def UnlockPouch {
            in lockedCoupling : CouplingRing;
            out baseplateRing : CouplingRing;
            out pouchRing : CouplingRing;
        }
    }

    // ---- Charcoal filter ----
    part def CharcoalFilter {
        attribute gasFlowRate : VolumeValue = 0.0001 [m**3/s];
        attribute odorNeutralizationEfficiency : Percent = 0.95;
        attribute serviceLife : DurationValue = 3 [d];
        attribute isClogged : Boolean = false;

        port inlet : FilterPort;

        requirement ref filterReq : FilterRequirement;

        action def FilterGas {
            in unfiltered : Gas;
            in odorMol : OdorMolecules;
            out filtered : FilteredGas;
        }
    }

    // ---- Drain valve ----
    part def DrainValve {
        attribute valveType : String = "twist-open";
        attribute flowRate : VolumeValue = 0.0005 [m**3/s];
        attribute leakTightness : Percent = 0.995;
        attribute isOpen : Boolean = false;

        port outlet : DrainPort;

        requirement ref drainReq : DrainValveRequirement;

        action def OpenValve {
            in closedValve : DrainValve;
            out openValve : DrainValve;
        }

        action def CloseValve {
            in openValve : DrainValve;
            out closedValve : DrainValve;
        }

        action def DrainContents {
            in storedWaste : BodilyWaste;
            out drainedWaste : BodilyWaste;
        }
    }

    // ---- Collection pouch ----
    part def CollectionPouch {
        attribute capacity : VolumeValue = 0.0005 [m**3];
        attribute fillLevel : VolumeValue = 0 [m**3];
        attribute filmLayers : Integer = 3;
        attribute odorBarrierRating : Percent = 0.98;
        attribute mass : MassValue = 0.05 [kg];
        attribute isAttached : Boolean = false;

        port baseplateCoupling : CouplingPort;
        port filterConnection : FilterPort;
        port drainConnection : DrainPort;

        part filter : CharcoalFilter {
            port inlet : FilterPort;
        }

        part drain : DrainValve {
            port outlet : DrainPort;
        }

        requirement ref odorReq : OdorBarrierRequirement;
        requirement ref discreetReq : DiscreetRequirement;

        action def CollectWaste {
            in incoming : BodilyWaste;
            in gasIn : Gas;
            out storedWaste : BodilyWaste;
            out releasedGas : FilteredGas;
        }

        action def EmptyViaDrain {
            in storedWaste : BodilyWaste;
            out drainedWaste : BodilyWaste;
            out remainingWaste : BodilyWaste;
        }

        action def ReplacePouch {
            in oldPouch : CollectionPouch;
            out newPouch : CollectionPouch;
        }
    }

    // ---- Ostomy appliance system ----
    part def OstomyAppliance {
        attribute totalMass : MassValue = 0.12 [kg];
        attribute systemFillLevel : Percent = 0;
        attribute isOperational : Boolean = true;

        port stomaInterface : SkinInterfacePort;

        part baseplate : AdhesiveBaseplate {
            port skinSide : SkinInterfacePort;
            port pouchSide : CouplingPort;
        }

        part coupling : CouplingRing {
            port baseplateSide : CouplingPort;
            port pouchSide : CouplingPort;
        }

        part pouch : CollectionPouch {
            port baseplateCoupling : CouplingPort;
            port filterConnection : FilterPort;
            port drainConnection : DrainPort;

            part filter : CharcoalFilter;
            part drain : DrainValve;
        }

        connection stomaToBaseplate connect stomaInterface to baseplate.skinSide;
        connection baseplateToCoupling connect baseplate.pouchSide to coupling.baseplateSide;
        connection couplingToPouch connect coupling.pouchSide to pouch.baseplateCoupling;
        connection pouchToFilter connect pouch.filterConnection to pouch.filter.inlet;
        connection pouchToDrain connect pouch.drainConnection to pouch.drain.outlet;

        // ---- State machine ----
        state def ApplianceStates {
            entry action initialize {
                pouch.fillLevel := 0 [m**3];
                systemFillLevel := 0;
            }

            state Sealed {
                entry action enterSealed {
                    pouch.fillLevel := 0 [m**3];
                    systemFillLevel := 0;
                }
                transition to Collecting
                    when baseplate.skinSide.collectedWaste is received;
            }

            state Collecting {
                entry action enterCollecting {
                    // Begin collecting waste from stoma
                }
                do action collect {
                    in incomingWaste : BodilyWaste;
                    in incomingGas : Gas;
                    out storedWaste : BodilyWaste;
                    out releasedGas : FilteredGas;
                }
                transition to NearCapacity
                    when pouch.fillLevel >= 0.7 * pouch.capacity;
                transition to RequiresChange
                    when pouch.fillLevel >= 0.95 * pouch.capacity;
            }

            state NearCapacity {
                entry action signalNearCapacity {
                    // Signal user to empty pouch via drain valve
                }
                transition to Collecting
                    when pouch.fillLevel < 0.3 * pouch.capacity;
                transition to RequiresChange
                    when pouch.fillLevel >= 0.95 * pouch.capacity;
            }

            state RequiresChange {
                entry action signalRequiresChange {
                    // Signal user to detach and replace pouch
                }
                transition to Sealed
                    when pouch is replaced;
            }
        }

        state machine applianceState : ApplianceStates;

        requirement ref systemLeakProof : LeakProofSealRequirement;
        requirement ref systemSecure : SecureCouplingRequirement;
        requirement ref systemDiscreet : DiscreetRequirement;
        requirement ref systemSkinIntegrity : SkinIntegrityRequirement;
    }

    // ---- Patient context ----
    part def Patient {
        attribute hasStoma : Boolean = true;
        attribute stomaDiameter : LengthValue = 0.035 [m];

        port stomaPort : SkinInterfacePort;

        action def ProduceWaste {
            out producedWaste : BodilyWaste;
            out producedGas : Gas;
        }

        action def WearAppliance {
            in appliance : OstomyAppliance;
        }
    }

    part def OstomySystemContext {
        part patient : Patient;
        part appliance : OstomyAppliance;

        connection patientToAppliance connect patient.stomaPort to appliance.stomaInterface;

        requirement ref contextSkinIntegrity : SkinIntegrityRequirement;
    }

    // ---- Top-level satisfaction bindings ----
    satisfaction satisfy LeakProofSealRequirement by OstomyAppliance.baseplate;
    satisfaction satisfy SecureCouplingRequirement by OstomyAppliance.coupling;
    satisfaction satisfy OdorBarrierRequirement by OstomyAppliance.pouch;
    satisfaction satisfy FilterRequirement by OstomyAppliance.pouch.filter;
    satisfaction satisfy DrainValveRequirement by OstomyAppliance.pouch.drain;
    satisfaction satisfy DiscreetRequirement by OstomyAppliance;
    satisfaction satisfy SkinIntegrityRequirement by OstomyAppliance;
}
