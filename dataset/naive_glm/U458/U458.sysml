package YankauerSuctionSystem {
    import ScalarValues::*;
    import StateMachines::*;

    // ---- Units ----
    unit kPa;
    unit mL;
    unit mL_per_s;
    unit mm;
    unit mmHg;

    // ---- Value Types ----
    attribute def Pressure :> Real { unit mmHg; }
    attribute def VacuumLevel :> Real { unit mmHg; }
    attribute def Volume :> Real { unit mL; }
    attribute def FlowRate :> Real { unit mL_per_s; }
    attribute def Length :> Real { unit mm; }
    attribute def Diameter :> Real { unit mm; }

    // ---- Items ----
    item def AspiratedMaterial;
    item def Fluid :> AspiratedMaterial;
    item def Blood :> Fluid;
    item def IrrigationSolution :> Fluid;
    item def Debris :> AspiratedMaterial;
    item def Air;
    item def Pathogen;

    // ---- Ports ----
    port def SuctionPort {
        out item : AspiratedMaterial;
        in item : Air;
    }

    port def VacuumPort {
        out item : Air;
    }

    port def FilterPort {
        in item : AspiratedMaterial;
        out item : AspiratedMaterial;
    }

    port def CanisterPort {
        in item : AspiratedMaterial;
        out item : Air;
    }

    // ---- Components ----

    part def VacuumRegulator {
        attribute maxVacuum : VacuumLevel = 600.0;
        attribute minVacuum : VacuumLevel = 0.0;
        attribute setVacuum : VacuumLevel = 200.0;
        attribute adjustable : Boolean = true;

        port vacuumSource : VacuumPort;

        action def regulateVacuum {
            in requestedLevel : VacuumLevel;
            out deliveredLevel : VacuumLevel;
        }

        perform regulateVacuum;
    }

    part def BacterialFilter {
        attribute poreSize : Diameter = 0.2;
        attribute efficiency : Real = 0.9999;
        attribute blocked : Boolean = false;

        port inlet : FilterPort;
        port outlet : FilterPort;

        action def filterAspirate {
            in incoming : AspiratedMaterial;
            out filtered : AspiratedMaterial;
            out captured : Pathogen;
        }

        perform filterAspirate;
    }

    part def CollectionCanister {
        attribute capacity : Volume = 1200.0;
        attribute currentVolume : Volume = 0.0;
        attribute overflowProtectionActive : Boolean = false;
        attribute fullThreshold : Volume = 1100.0;

        port canisterInlet : CanisterPort;
        port canisterOutlet : VacuumPort;

        action def collectAspirate {
            in incoming : AspiratedMaterial;
            out storedVolume : Volume;
        }

        action def activateOverflowShutoff {
            in currentLevel : Volume;
            out shutoffTriggered : Boolean;
        }

        perform collectAspirate;
        perform activateOverflowShutoff;
    }

    part def SuctionTubing {
        attribute length : Length = 2000.0;
        attribute innerDiameter : Diameter = 8.0;
        attribute flexibility : Real = 0.85;
        attribute obstructed : Boolean = false;

        port tubingInlet : SuctionPort;
        port tubingOutlet : SuctionPort;

        action def conveyAspirate {
            in incoming : AspiratedMaterial;
            out outgoing : AspiratedMaterial;
        }

        perform conveyAspirate;
    }

    part def YankauerTip {
        attribute tipLength : Length = 150.0;
        attribute outerDiameter : Diameter = 12.0;
        attribute bulbousEnd : Boolean = true;
        attribute sideHoleCount : Integer = 6;
        attribute ventControlPresent : Boolean = true;
        attribute ventOpen : Boolean = false;

        port patientEnd : SuctionPort;
        port tubingEnd : SuctionPort;

        action def aspirateAtSite {
            in ambientAir : Air;
            out aspirated : AspiratedMaterial;
        }

        action def modulateVent {
            in ventCommand : Boolean;
            out ventState : Boolean;
        }

        perform aspirateAtSite;
        perform modulateVent;
    }

    // ---- System ----

    part def YankauerSuctionSystem {
        attribute systemOn : Boolean = false;
        attribute currentFlowRate : FlowRate = 0.0;
        attribute operatingVacuum : VacuumLevel = 0.0;

        port systemPatientPort : SuctionPort;

        part regulator : VacuumRegulator {
            redefines setVacuum = 180.0;
        }

        part filter : BacterialFilter;

        part canister : CollectionCanister {
            redefines capacity = 1000.0;
        }

        part tubing : SuctionTubing;

        part tip : YankauerTip;

        connection def VacuumLine {
            end source : VacuumPort;
            end target : VacuumPort;
        }

        connection def AspirateLine {
            end source : SuctionPort;
            end target : SuctionPort;
        }

        connection def FilterLine {
            end source : FilterPort;
            end target : FilterPort;
        }

        connection regulatorToFilter : FilterLine connect regulator.vacuumSource::? to filter.inlet;
        connection filterToCanister : FilterLine connect filter.outlet to canister.canisterInlet;
        connection canisterToTubing : AspirateLine connect canister.canisterOutlet::? to tubing.tubingOutlet;
        connection tubingToTip : AspirateLine connect tubing.tubingInlet to tip.tubingEnd;
        connection tipToPatient : AspirateLine connect tip.patientEnd to systemPatientPort;

        // ---- State Machine ----
        state machine SuctionSystemStates {
            state idle {
                entry action {
                    systemOn = true;
                    currentFlowRate = 0.0;
                    operatingVacuum = 0.0;
                }
            }

            state active {
                entry action {
                    operatingVacuum = regulator.setVacuum;
                    currentFlowRate = 25.0;
                }
                do action {
                    tip.aspirateAtSite();
                    tubing.conveyAspirate();
                    canister.collectAspirate();
                    filter.filterAspirate();
                    regulator.regulateVacuum();
                }
            }

            state obstructed {
                entry action {
                    currentFlowRate = 0.0;
                    tubing.obstructed = true;
                }
            }

            state canisterFull {
                entry action {
                    currentFlowRate = 0.0;
                    canister.overflowProtectionActive = true;
                }
            }

            transition init_to_idle initial to idle;

            transition idle_to_active
                from idle to active
                when (tip.ventOpen == false & systemOn == true);

            transition active_to_idle
                from active to idle
                when (tip.ventOpen == true);

            transition active_to_obstructed
                from active to obstructed
                when (tubing.obstructed == true | filter.blocked == true);

            transition active_to_canisterFull
                from active to canisterFull
                when (canister.currentVolume >= canister.fullThreshold);

            transition obstructed_to_idle
                from obstructed to idle
                when (tubing.obstructed == false & filter.blocked == false);

            transition canisterFull_to_idle
                from canisterFull to idle
                when (canister.currentVolume < canister.fullThreshold & canister.overflowProtectionActive == false);
        }

        perform SuctionSystemStates;
    }

    // ---- Requirements ----

    requirement def SuctionPerformanceRequirement {
        attribute minVacuum : VacuumLevel = 50.0;
        attribute maxVacuum : VacuumLevel = 600.0;
        attribute minFlowRate : FlowRate = 10.0;
        subject system : YankauerSuctionSystem;
        require {
            system.operatingVacuum >= minVacuum;
            system.operatingVacuum <= maxVacuum;
            system.currentFlowRate >= minFlowRate;
        }
    }

    requirement def CanisterCapacityRequirement {
        attribute minCapacity : Volume = 800.0;
        subject canister : CollectionCanister;
        require {
            canister.capacity >= minCapacity;
            canister.overflowProtectionActive == true if canister.currentVolume >= canister.fullThreshold;
        }
    }

    requirement def FilterEfficiencyRequirement {
        attribute minEfficiency : Real = 0.999;
        subject filter : BacterialFilter;
        require {
            filter.efficiency >= minEfficiency;
        }
    }

    requirement def TipSafetyRequirement {
        subject tip : YankauerTip;
        require {
            tip.bulbousEnd == true;
            tip.sideHoleCount >= 4;
            tip.ventControlPresent == true;
        }
    }

    requirement def SystemStateRequirement {
        subject system : YankauerSuctionSystem;
        require {
            system.SuctionSystemStates.active.occurrence.isStarted implies system.currentFlowRate > 0.0;
            system.SuctionSystemStates.obstructed.occurrence.isStarted implies system.currentFlowRate == 0.0;
            system.SuctionSystemStates.canisterFull.occurrence.isStarted implies system.currentFlowRate == 0.0;
        }
    }

    requirement SuctionPerformance : SuctionPerformanceRequirement;
    requirement CanisterCapacity : CanisterCapacityRequirement;
    requirement FilterEfficiency : FilterEfficiencyRequirement;
    requirement TipSafety : TipSafetyRequirement;
    requirement SystemStateBehavior : SystemStateRequirement;

    // ---- Verification ----
    verification def VerifySuctionPerformance {
        subject system : YankauerSuctionSystem;
        objective {
            verify SuctionPerformance for system;
        }
    }

    verification def VerifyCanisterCapacity {
        subject canister : CollectionCanister;
        objective {
            verify CanisterCapacity for canister;
        }
    }

    verification def VerifyFilterEfficiency {
        subject filter : BacterialFilter;
        objective {
            verify FilterEfficiency for filter;
        }
    }

    verification def VerifyTipSafety {
        subject tip : YankauerTip;
        objective {
            verify TipSafety for tip;
        }
    }
}
