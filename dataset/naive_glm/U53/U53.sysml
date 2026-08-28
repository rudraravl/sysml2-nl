package DapivirineRingSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type DapivirineMass :> Mass;
    value type DapivirineConcentration :> Real {
        unit ug_per_mL = (1e-6 [g]) / (1e-3 [L]);
    }
    value type ReleaseRate :> Real {
        unit mg_per_day = (1e-3 [g]) / (1 [d]);
    }
    value type DurationDays :> Duration;
    value type RingDiameter :> Length;
    value type RingCrossSection :> Length;
    value type ReservoirVolume :> Volume;
    value type PolymerPermeability :> Real {
        unit cm2_per_day = (1e-4 [m])^2 / (1 [d]);
    }

    // ---- Design constants ----
    attribute initialDose : DapivirineMass = 25 [mg];
    attribute therapeuticConcentration : DapivirineConcentration = 100 [ug/mL];
    attribute effectivePeriod : DurationDays = 28 [d];
    attribute ringOuterDiameter : RingDiameter = 56 [mm];
    attribute ringCrossSectionDiameter : RingCrossSection = 7.7 [mm];
    attribute reservoirVolume : ReservoirVolume = 200 [mm^3];
    attribute nominalReleaseRate : ReleaseRate = 0.9 [mg_per_day];
    attribute depletionThreshold : DapivirineMass = 0.5 [mg];

    // ---- Item definitions ----
    item def Dapivirine {
        attribute molarMass : Mass = 329.4 [g/mol];
        attribute antiretroviralActivity : Boolean = true;
        attribute halfLifeInTissue : Duration = 72 [h];
    }

    item def SiliconePolymer {
        attribute biocompatible : Boolean = true;
        attribute flexible : Boolean = true;
        attribute shoreHardness : Real = 35;
    }

    item def VaginalFluid {
        attribute pH : Real = 4.5;
        attribute typicalVolume : Volume = 2 [mL];
    }

    item def HIVVirus {
        attribute infectivity : Boolean = true;
        attribute targetTissue : String = "vaginal epithelium";
    }

    item def TissueAbsorbedDrug {
        item drug : Dapivirine;
        attribute concentration : DapivirineConcentration;
    }

    // ---- Port definitions ----
    port def DrugReleasePort {
        out releasedDrug : Dapivirine;
        attribute releaseRate : ReleaseRate;
    }

    port def TissueInterfacePort {
        in incomingDrug : Dapivirine;
        out absorbedDrug : TissueAbsorbedDrug;
    }

    port def InsertionInterfacePort {
        attribute inserted : Boolean;
        attribute insertionTimestamp : Time;
    }

    port def UserAdherencePort {
        attribute wearing : Boolean;
        attribute daysWorn : DurationDays;
    }

    // ---- Action definitions ----
    action def ReleaseDapivirine {
        in reservoirDose : DapivirineMass;
        in rate : ReleaseRate;
        out releasedDrug : Dapivirine;
        out remainingDose : DapivirineMass;
    }

    action def DiffuseIntoTissue {
        in drug : Dapivirine;
        in fluid : VaginalFluid;
        out absorbed : TissueAbsorbedDrug;
    }

    action def InsertRing {
        in ring : DapivirineRing;
        out inserted : Boolean = true;
    }

    action def RemoveRing {
        in ring : DapivirineRing;
        out removed : Boolean = true;
    }

    // ---- Part definitions ----
    part def SiliconeMatrix {
        attribute material : SiliconePolymer;
        attribute permeability : PolymerPermeability = 5.0e-6 [cm2_per_day];
        attribute outerDiameter : RingDiameter = ringOuterDiameter;
        attribute crossSectionDiameter : RingCrossSection = ringCrossSectionDiameter;
    }

    part def DrugReservoir {
        attribute initialDose : DapivirineMass = 25 [mg];
        attribute currentDose : DapivirineMass = initialDose;
        attribute volume : ReservoirVolume = reservoirVolume;
        item storedDrug : Dapivirine;
        constraint { currentDose >= 0 [mg] }
    }

    part def DapivirineRing {
        attribute material : SiliconePolymer;
        attribute outerDiameter : RingDiameter = ringOuterDiameter;
        attribute crossSectionDiameter : RingCrossSection = ringCrossSectionDiameter;
        attribute sterile : Boolean = true;
        attribute effectiveDuration : DurationDays = effectivePeriod;

        port releasePort : DrugReleasePort;
        port insertionInterface : InsertionInterfacePort;

        part matrix : SiliconeMatrix;
        part reservoir : DrugReservoir;

        action releaseAction : ReleaseDapivirine {
            in reservoirDose = reservoir.currentDose;
            in rate = nominalReleaseRate;
        }

        state machine lifecycle {
            entry; then Packaged;

            state Packaged {
                entry;
                attribute sterile : Boolean = true;
                attribute drugRemaining : DapivirineMass = initialDose;
                constraint { drugRemaining == initialDose }
            }

            transition from Packaged to Inserted
                when insertionInterface.inserted == true;

            state Inserted {
                entry;
                attribute drugRemaining : DapivirineMass;
                do releaseAction;
            }

            transition from Inserted to Active
                when insertionInterface.inserted == true;

            state Active {
                entry;
                do releaseAction;
                attribute drugRemaining : DapivirineMass;
                attribute daysInUse : DurationDays;
                constraint { drugRemaining > depletionThreshold }
                constraint { daysInUse <= effectivePeriod }
            }

            transition from Active to Depleted
                when Active.drugRemaining <= depletionThreshold
                or Active.daysInUse >= effectivePeriod;

            state Depleted {
                entry;
                attribute drugRemaining : DapivirineMass = 0 [mg];
                attribute depleted : Boolean = true;
            }

            transition from Depleted to Removed
                when insertionInterface.inserted == false;

            state Removed {
                entry;
                attribute disposed : Boolean = true;
                attribute sterile : Boolean = false;
            }

            transition from Removed to Packaged
                when false;
        }
    }

    part def VaginalEnvironment {
        port tissueInterface : TissueInterfacePort;
        item fluid : VaginalFluid;
        attribute localConcentration : DapivirineConcentration;
        attribute pH : Real = 4.5;
        constraint { localConcentration >= therapeuticConcentration }
    }

    part def User {
        attribute adherence : Boolean = true;
        attribute continuousWear : Boolean = true;
        port adherencePort : UserAdherencePort;
        port insertionPort : InsertionInterfacePort;

        action insert : InsertRing;
        action remove : RemoveRing;
    }

    // ---- System assembly ----
    part def HIVPreventionSystem {
        part ring : DapivirineRing;
        part environment : VaginalEnvironment;
        part user : User;

        connection ring.releasePort to environment.tissueInterface {
            item releasedDrug : Dapivirine;
        }

        connection user.insertionPort to ring.insertionInterface {
            attribute inserted : Boolean;
        }

        connection user.adherencePort to ring.insertionInterface {
            attribute wearing : Boolean;
        }

        // ---- Requirements ----
        requirement def SterilePackagingRequirement {
            subject ring : DapivirineRing;
            requirement {
                ring.sterile == true;
            }
        }

        requirement def ControlledReleaseRequirement {
            subject ring : DapivirineRing;
            requirement {
                ring.releasePort.releaseRate >= 0.5 [mg_per_day];
            }
            requirement {
                ring.releasePort.releaseRate <= 1.2 [mg_per_day];
            }
        }

        requirement def TherapeuticConcentrationRequirement {
            subject environment : VaginalEnvironment;
            requirement {
                environment.localConcentration >= therapeuticConcentration;
            }
        }

        requirement def EffectivePeriodRequirement {
            subject ring : DapivirineRing;
            requirement {
                ring.effectiveDuration == 28 [d];
            }
        }

        requirement def ContinuousAdherenceRequirement {
            subject user : User;
            requirement {
                user.adherence == true;
            }
            requirement {
                user.continuousWear == true;
            }
        }

        requirement def HIVPreventionRequirement {
            subject system : HIVPreventionSystem;
            requirement {
                system.environment.localConcentration >= therapeuticConcentration;
            }
            requirement {
                system.user.adherence == true;
            }
            requirement {
                system.ring.reservoir.currentDose >= 0 [mg];
            }
        }

        satisfy SterilePackagingRequirement by ring;
        satisfy ControlledReleaseRequirement by ring;
        satisfy TherapeuticConcentrationRequirement by environment;
        satisfy EffectivePeriodRequirement by ring;
        satisfy ContinuousAdherenceRequirement by user;
        satisfy HIVPreventionRequirement by HIVPreventionSystem;
    }
}
