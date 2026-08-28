package SurgicalDrapeSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type Length :> Real { unit 'mm'; }
    value type Area :> Real { unit 'mm2'; }
    value type Volume :> Real {> VolumeUnit { unit 'mL'; } }
    value type Mass :> Real {> MassUnit { unit 'g'; } }
    value type Pressure :> Real {> PressureUnit { unit 'kPa'; } }
    value type FiltrationEfficiency :> Real { unit '%'; }
    value type FluidVolume :> Volume;
    value type TensileStrength :> Real { unit 'N'; }
    value type Temperature :> Real {> ThermodynamicTemperatureUnit { unit 'degC'; } }

    // ---- Item types ----
    item def Microorganism;
    item def BodyFluid {
        attribute volume : FluidVolume;
    }
    item def Blood :> BodyFluid;
    item def Saline :> BodyFluid;
    item def SurgicalInstrument;
    item def Contaminant :> Microorganism;

    // ---- Enumerations ----
    enum def IntegrityStatus { ok; compromised; saturated; }
    enum def DrapePhase { packaged; inspected; opened; positioned; secured; inUse; removed; disposed; }

    // ---- Requirements ----
    requirement def SterileBarrierRequirement {
        doc << "The drape shall isolate the surgical site from microbial contaminants with at least 95% filtration efficiency.">>
        attribute minFiltrationEfficiency : FiltrationEfficiency = 95.0;
        subject drape :> SurgicalDrape;
        objective {
            drape.barrierLayer.filtrationEfficiency >= minFiltrationEfficiency
        }
    }

    requirement def FluidManagementRequirement {
        doc << "The absorbent layer shall contain up to 500 mL of body fluid without strike-through.">>
        attribute maxCapacity : FluidVolume = 500 [mL];
        subject drape :> SurgicalDrape;
        objective {
            drape.absorbentLayer.capacity >= maxCapacity
        }
    }

    requirement def AdhesionRequirement {
        doc << "Adhesive strips shall maintain drape position under normal surgical handling forces.">>
        attribute minPeelStrength : Pressure = 2.0 [kPa];
        subject drape :> SurgicalDrape;
        objective {
            drape.adhesiveStrips.peelStrength >= minPeelStrength
        }
    }

    requirement def FenestrationRequirement {
        doc << "The fenestration shall provide controlled access to the surgical site and be reinforced against tearing.">>
        attribute minReinforcementStrength : TensileStrength = 50 [N];
        subject drape :> SurgicalDrape;
        objective {
            drape.fenestration.reinforcementStrength >= minReinforcementStrength
        }
    }

    requirement def LifecycleRequirement {
        doc << "The drape shall transition through defined lifecycle phases from packaging to disposal.">>
        subject drape :> SurgicalDrape;
        objective {
            drape.lifecycle.isSatisfied
        }
    }

    // ---- Part definitions ----
    part def BarrierLayer {
        attribute material : String = "non-woven polypropylene";
        attribute filtrationEfficiency : FiltrationEfficiency = 99.0;
        attribute thickness : Length = 0.25 [mm];
        attribute tensileStrength : TensileStrength = 40 [N];
        port in contaminantIn : Microorganism;
        port out contaminantBlocked : Microorganism;
        port in fluidContact : BodyFluid;
        port out fluidPassed : BodyFluid;
    }

    part def AbsorbentLayer {
        attribute material : String = "cellulose-polymer laminate";
        attribute capacity : FluidVolume = 500 [mL];
        attribute currentLoad : FluidVolume = 0 [mL];
        port in fluidIn : BodyFluid;
        port out fluidSaturated : BodyFluid;
        port out saturationAlert;
    }

    part def AdhesiveStrip {
        attribute peelStrength : Pressure = 3.0 [kPa];
        attribute length : Length = 200 [mm];
        attribute width : Length = 20 [mm];
        port in adhesionSurface;
        port out securedSignal;
    }

    part def Fenestration {
        attribute apertureArea : Area = 10000 [mm2];
        attribute reinforcementStrength : TensileStrength = 60 [N];
        attribute isReinforced : Boolean = true;
        port in instrumentAccess : SurgicalInstrument;
        port out instrumentGuided : SurgicalInstrument;
    }

    part def ReinforcementZone {
        attribute location : String;
        attribute tensileStrength : TensileStrength = 80 [N];
        attribute fluidResistance : FiltrationEfficiency = 99.5;
        port in stressIn;
        port out stressDissipated;
    }

    part def SterilePackaging {
        attribute isSealed : Boolean = true;
        attribute sterilizationMethod : String = "ethylene oxide";
        attribute expiryDate : String;
        port out drapeReleased : SurgicalDrape;
    }

    part def SurgicalDrape {
        satisfy SterileBarrierRequirement;
        satisfy FluidManagementRequirement;
        satisfy AdhesionRequirement;
        satisfy FenestrationRequirement;
        satisfy LifecycleRequirement;

        attribute totalArea : Area = 1.8e6 [mm2];
        attribute integrity : IntegrityStatus = IntegrityStatus::ok;

        part barrierLayer : BarrierLayer {
            attribute filtrationEfficiency : FiltrationEfficiency = 99.0;
        }
        part absorbentLayer : AbsorbentLayer {
            attribute capacity : FluidVolume = 500 [mL];
        }
        part adhesiveStrips : AdhesiveStrip[4];
        part fenestration : Fenestration;
        part reinforcementZones : ReinforcementZone[2] {
            attribute location : String = "high-contact";
        }
        part packaging : SterilePackaging;

        port in patientContact;
        port in surgicalSiteAccess : SurgicalInstrument;
        port out sterileFieldMaintained;
        port out integrityAlert;
        port out saturationAlert;

        // Connections between internal parts
        connection barrierToAbsorbent : barrierLayer.fluidPassed = absorbentLayer.fluidIn;
        connection absorbentToAlert : absorbentLayer.saturationAlert = saturationAlert;
        connection instrumentThroughFenestration : surgicalSiteAccess = fenestration.instrumentAccess;
        connection fenestrationOutput : fenestration.instrumentGuided = sterileFieldMaintained;

        // Lifecycle state machine
        private attribute lifecycleSatisfied : Boolean = false;

        state def LifecycleStateMachine {
            entry { lifecycleSatisfied := false; }
            state packaged {
                entry { packaging.isSealed := true; }
                on inspect to inspected;
            }
            state inspected {
                entry { /* verify seal integrity */ }
                on open to opened;
            }
            state opened {
                entry { packaging.isSealed := false; }
                on unfold to positioned;
            }
            state positioned {
                entry { /* align fenestration over surgical site */ }
                on secure to secured;
            }
            state secured {
                entry { adhesiveStrips.securedSignal; }
                on beginProcedure to inUse;
            }
            state inUse {
                entry { integrity := IntegrityStatus::ok; }
                on compromise to compromised;
                on saturate to saturated;
                on completeProcedure to removed;
            }
            state compromised {
                entry { integrity := IntegrityStatus::compromised; integrityAlert; }
                on replace to positioned;
                on completeProcedure to removed;
            }
            state saturated {
                entry { integrity := IntegrityStatus::saturated; saturationAlert; }
                on replace to positioned;
                on completeProcedure to removed;
            }
            state removed {
                entry { /* peel adhesive strips, lift drape */ }
                on dispose to disposed;
            }
            state disposed {
                entry { lifecycleSatisfied := true; }
            }
        }

        composite lifecycle : LifecycleStateMachine;

        // Action to monitor integrity during use
        action def MonitorIntegrity {
            in drapeIntegrity : IntegrityStatus;
            out alertNeeded : Boolean;
            perform {
                if drapeIntegrity == IntegrityStatus::compromised | drapeIntegrity == IntegrityStatus::saturated {
                    alertNeeded := true;
                } else {
                    alertNeeded := false;
                }
            }
        }
    }

    // ---- Top-level context ----
    part def SurgicalContext {
        part drape : SurgicalDrape;
        part patient {
            port out surgicalSite;
            port out bodyFluids : BodyFluid;
        }
        part surgicalTeam {
            port in alert;
            port out instruments : SurgicalInstrument;
        }
        part disposalUnit {
            port in disposedDrape : SurgicalDrape;
        }

        connection patientToDrape : patient.surgicalSite = drape.patientContact;
        connection fluidsToDrape : patient.bodyFluids = drape.barrierLayer.fluidContact;
        connection teamInstruments : surgicalTeam.instruments = drape.surgicalSiteAccess;
        connection drapeAlertToTeam : drape.integrityAlert = surgicalTeam.alert;
        connection drapeSaturationToTeam : drape.saturationAlert = surgicalTeam.alert;
        connection drapeToDisposal : drape = disposalUnit.disposedDrape;
    }
}
