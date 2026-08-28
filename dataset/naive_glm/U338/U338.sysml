package OrageneDNAKit {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value def Volume :> Real {
        unit volumeUnit[1] = SI::milliL;
    }

    value def Mass :> Real {
        unit massUnit[1] = SI::gram;
    }

    value def Temperature :> Real {
        unit tempUnit[1] = SI::degC;
    }

    value def Duration :> Real {
        unit durationUnit[1] = SI::day;
    }

    value def Concentration :> Real {
        unit concUnit[1] = SI::nano * SI::gram / (SI::micro * SI::L);
    }

    value def Length :> Real {
        unit lengthUnit[1] = SI::milli;
    }

    // ===== Item Types =====

    item def HumanSaliva {
        attribute volume : Volume;
        attribute dnaConcentration : Concentration;
        attribute microbiomeLoad : Real; // relative units
    }

    item def DNAStabilizationReagent {
        attribute volume : Volume;
        attribute pH : Real;
        attribute virucidal : Boolean = true;
        attribute bacteriostatic : Boolean = true;
    }

    item def StabilizedDNASample {
        attribute totalVolume : Volume;
        attribute dnaConcentration : Concentration;
        attribute preservationDuration : Duration;
        attribute storageTemperature : Temperature;
        attribute viralInactivation : Boolean;
        attribute bacterialGrowthInhibited : Boolean;
    }

    item def AmbientAir;

    // ===== Port Definitions =====

    port def FluidPort {
        out item flow : HumanSaliva;
        in item flow : StabilizedDNASample;
    }

    port def ReagentPort {
        out item flow : DNAStabilizationReagent;
    }

    port def MechanicalPort {
        attribute torqueApplied : Real;
        attribute sealed : Boolean;
    }

    // ===== Component Parts =====

    part def CollectionTube {
        attribute capacity : Volume = 10 [volumeUnit];
        attribute graduationMarks : Boolean = true;
        attribute material : String = "Polypropylene";
        attribute threadSpec : String = "InternalThread";

        port fluidIn : FluidPort;
        port capInterface : MechanicalPort;

        item storedSaliva : HumanSaliva[0..1];
        item storedSample : StabilizedDNASample[0..1];

        attribute currentVolume : Volume;

        action def FillTube {
            in saliva : HumanSaliva;
            update storedSaliva := saliva;
            update currentVolume := saliva.volume;
        }

        action def SealWithCap {
            in reagent : DNAStabilizationReagent;
            perform MixContents;
        }

        action def MixContents {
            in rawSaliva : HumanSaliva;
            in reagent : DNAStabilizationReagent;
            out stabilized : StabilizedDNASample;
            assign stabilized.totalVolume := rawSaliva.volume + reagent.volume;
            assign stabilized.viralInactivation := true;
            assign stabilized.bacterialGrowthInhibited := true;
            assign stabilized.storageTemperature := 25 [tempUnit];
            assign stabilized.preservationDuration := 365 [durationUnit];
            update storedSample := stabilized;
        }
    }

    part def CollectionFunnel {
        attribute material : String = "Polypropylene";
        attribute threadSpec : String = "ExternalThread";
        attribute disposable : Boolean = true;

        port funnelOutlet : FluidPort;
        port tubeInterface : MechanicalPort;

        action def GuideSaliva {
            in saliva : HumanSaliva;
            out directedSaliva : HumanSaliva;
            assign directedSaliva := saliva;
        }
    }

    part def ReagentReservoir {
        attribute reagentVolume : Volume = 2 [volumeUnit];
        attribute sealed : Boolean = true;
        attribute frangibleSeal : Boolean = true;

        port reagentOut : ReagentPort;

        item containedReagent : DNAStabilizationReagent[1] {
            attribute volume := 2 [volumeUnit];
            attribute pH := 8.0;
            attribute virucidal := true;
            attribute bacteriostatic := true;
        }

        action def ReleaseReagent {
            precondition sealed == true;
            out releasedReagent : DNAStabilizationReagent;
            assign releasedReagent := containedReagent;
            update sealed := false;
        }
    }

    part def PiercingMechanism {
        attribute integrated : Boolean = true;
        attribute actuationTorque : Real = 0.5;

        action def PierceReservoir {
            in reservoir : ReagentReservoir;
            trigger reservoir.ReleaseReagent;
        }
    }

    part def SealingCap {
        attribute material : String = "Polypropylene";
        attribute threadSpec : String = "ExternalThread";
        attribute leakProof : Boolean = true;
        attribute tamperEvident : Boolean = true;

        port capFluidPort : FluidPort;
        port capMechanicalPort : MechanicalPort;

        part reservoir : ReagentReservoir;
        part piercer : PiercingMechanism;

        action def SecureCap {
            in tube : CollectionTube;
            perform piercer.PierceReservoir(reservoir);
            perform reservoir.ReleaseReagent;
            perform tube.SealWithCap(reservoir.containedReagent);
            update capMechanicalPort.sealed := true;
        }
    }

    part def User {
        attribute trained : Boolean = false;

        action def ProvideSaliva {
            out saliva : HumanSaliva;
            assign saliva.volume := 2 [volumeUnit];
            assign saliva.dnaConcentration := 50 [concUnit];
            assign saliva.microbiomeLoad := 1.0;
        }

        action def AttachFunnel {
            in funnel : CollectionFunnel;
            in tube : CollectionTube;
        }

        action def DetachFunnel {
            in funnel : CollectionFunnel;
        }

        action def SecureCap {
            in cap : SealingCap;
            in tube : CollectionTube;
            perform cap.SecureCap(tube);
        }

        action def ShakeTube {
            in tube : CollectionTube;
            perform tube.MixContents(tube.storedSaliva, cap.reservoir.containedReagent);
        }
    }

    // ===== Integrated Kit =====

    part def OrageneKit {
        attribute kitName : String = "Oragene DNA Collection and Preservation System";
        attribute selfContained : Boolean = true;
        attribute nonInvasive : Boolean = true;
        attribute roomTemperatureStorage : Boolean = true;

        part tube : CollectionTube;
        part funnel : CollectionFunnel;
        part cap : SealingCap;
        part user : User;

        connection funnel.funnelOutlet to tube.fluidIn;
        connection funnel.tubeInterface to tube.capInterface;
        connection cap.capMechanicalPort to tube.capInterface;
        connection cap.reservoir.reagentOut to tube.fluidIn;

        // ===== State Machine =====

        state def KitLifecycle {
            entry action { /* initialize kit */ }

            state Unassembled {
                entry action { /* components separate */ }
            }

            state ReadyForCollection {
                entry action {
                    perform user.AttachFunnel(funnel, tube);
                }
            }

            state Collecting {
                entry action {
                    perform user.ProvideSaliva() -> tube.fluidIn.flow;
                    perform tube.FillTube(tube.fluidIn.flow);
                }
            }

            state FunnelRemoved {
                entry action {
                    perform user.DetachFunnel(funnel);
                }
            }

            state CapSecuring {
                entry action {
                    perform user.SecureCap(cap, tube);
                }
            }

            state Mixing {
                entry action {
                    perform user.ShakeTube(tube);
                }
            }

            state Stabilized {
                entry action {
                    assert tube.storedSample.viralInactivation == true;
                    assert tube.storedSample.bacterialGrowthInhibited == true;
                }
            }

            state SealedForStorage {
                entry action {
                    assert cap.capMechanicalPort.sealed == true;
                }
            }

            transition Unassembled -> ReadyForCollection
                when { user.trained == true };

            transition ReadyForCollection -> Collecting
                when { tube.currentVolume == 0 [volumeUnit] };

            transition Collecting -> FunnelRemoved
                when { tube.currentVolume >= 2 [volumeUnit] };

            transition FunnelRemoved -> CapSecuring
                when { cap.reservoir.sealed == true };

            transition CapSecuring -> Mixing
                when { cap.reservoir.sealed == false };

            transition Mixing -> Stabilized
                when { tube.storedSample.viralInactivation == true };

            transition Stabilized -> SealedForStorage
                when { cap.capMechanicalPort.sealed == true };
        }

        behavior kitStateMachine : KitLifecycle;
    }

    // ===== Requirements =====

    requirement def SelfCollectionRequirement {
        subject kit : OrageneKit;
        requirement {
            doc "The kit shall enable non-invasive self-collection of human saliva."
        }
        assert kit.nonInvasive == true;
    }

    requirement def VolumeRequirement {
        subject tube : CollectionTube;
        requirement {
            doc "The collection tube shall accept a minimum saliva volume of 2 mL with visible graduation marks."
        }
        assert tube.capacity >= 2 [volumeUnit];
        assert tube.graduationMarks == true;
    }

    requirement def FunnelRequirement {
        subject funnel : CollectionFunnel;
        requirement {
            doc "The funnel shall be screw-compatible with the collection tube and disposable after use."
        }
        assert funnel.threadSpec == "ExternalThread";
        assert funnel.disposable == true;
    }

    requirement def ReagentReservoirRequirement {
        subject reservoir : ReagentReservoir;
        requirement {
            doc "The sealing cap shall contain an integrated sealed reservoir holding at least 2 mL of DNA stabilization reagent."
        }
        assert reservoir.reagentVolume >= 2 [volumeUnit];
        assert reservoir.sealed == true;
    }

    requirement def CapPiercingRequirement {
        subject cap : SealingCap;
        requirement {
            doc "Securing the cap onto the tube shall automatically pierce the reservoir and release the reagent into the saliva."
        }
        assert cap.piercer.integrated == true;
    }

    requirement def StabilizationRequirement {
        subject sample : StabilizedDNASample;
        requirement {
            doc "The mixed sample shall inactivate viruses and inhibit bacterial growth."
        }
        assert sample.viralInactivation == true;
        assert sample.bacterialGrowthInhibited == true;
    }

    requirement def RoomTempStorageRequirement {
        subject sample : StabilizedDNASample;
        requirement {
            doc "The stabilized DNA shall remain viable for at least 365 days at ambient temperature (approximately 25 degC)."
        }
        assert sample.preservationDuration >= 365 [durationUnit];
        assert sample.storageTemperature <= 30 [tempUnit];
    }

    requirement def LeakProofSealRequirement {
        subject cap : SealingCap;
        requirement {
            doc "The sealed cap shall prevent contamination and leakage during transport."
        }
        assert cap.leakProof == true;
        assert cap.tamperEvident == true;
    }

    requirement collectionRequirement : SelfCollectionRequirement;
    requirement volumeRequirement : VolumeRequirement;
    requirement funnelRequirement : FunnelRequirement;
    requirement reservoirRequirement : ReagentReservoirRequirement;
    requirement piercingRequirement : CapPiercingRequirement;
    requirement stabilizationRequirement : StabilizationRequirement;
    requirement storageRequirement : RoomTempStorageRequirement;
    requirement sealRequirement : LeakProofSealRequirement;

    // ===== Verification =====

    verification def VerifyStabilization {
        subject sample : StabilizedDNASample;
        objective {
            doc "Confirm viral inactivation and bacterial growth inhibition after mixing."
        }
        assert sample.viralInactivation == true;
        assert sample.bacterialGrowthInhibited == true;
    }

    verification def VerifyRoomTempStorage {
        subject sample : StabilizedDNASample;
        objective {
            doc "Confirm DNA integrity after 365 days at 25 degC."
        }
        assert sample.preservationDuration >= 365 [durationUnit];
    }

    verification stabilizationVerification : VerifyStabilization;
    verification storageVerification : VerifyRoomTempStorage;

}
