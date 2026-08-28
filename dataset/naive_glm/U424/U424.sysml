package SurgicalTrocarSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Force :> Real { unit 'N'; }
    value def Pressure :> Real { unit 'kPa'; }
    value def FlowRate :> Real { unit 'L/min'; }
    value def Length :> Real { unit 'mm'; }
    value def Diameter :> Real {> Real { unit 'mm'; }
    value def Volume :> Real { unit 'mL'; }

    // ===== Item Types =====
    item def InsufflationGas {
        attribute molecularFormula : String = "CO2";
        attribute purity : Real = 0.999;
    }
    item def SurgicalInstrument {
        attribute instrumentDiameter : Diameter;
        attribute instrumentName : String;
    }
    item def AbdominalTissue;
    item def BodyCavity;

    // ===== Enumerations =====
    enum def ObturatorTipType { bladed; nonBladed; optical; }
    enum def SealStateKind { open; sealed; compromised; }
    enum def ValveStateKind { closed; open; regulating; }

    // ===== Interfaces =====
    interface def GasFlowInterface {
        in gas : InsufflationGas;
        in flow : FlowRate;
        in pressure : Pressure;
    }
    interface def InstrumentInterface {
        in instrument : SurgicalInstrument;
        ref instrumentDiameter : Diameter;
    }
    interface def TissueInterface {
        in tissue : AbdominalTissue;
        out penetrationForce : Force;
    }

    // ===== Ports =====
    port def GasPort :> GasFlowInterface;
    port def InstrumentPort :> InstrumentInterface;
    port def TissuePort :> TissueInterface;

    // ===== Obturator =====
    part def Obturator {
        attribute tipType : ObturatorTipType = ObturatorTipType::bladed;
        attribute length : Length = 100;
        attribute diameter : Diameter = 11;
        attribute maxInsertionForce : Force = 40.0;

        port tissuePort : TissuePort;

        attribute isInserted : Boolean = false;

        action def PierceTissue {
            in tissue : AbdominalTissue;
            out appliedForce : Force;
        }

        action pierce : PierceTissue;

        state def ObturatorBehavior {
            entry; then Ready;
            state Ready;
            transition from Ready to Inserting
                when (isInserted == true);
            state Inserting {
                entry { pierce; }
            }
            transition from Inserting to Withdrawn
                when (isInserted == false);
            state Withdrawn;
        }

        state machine obturatorStateMachine : ObturatorBehavior;
    }

    // ===== Seal Assembly =====
    part def SealAssembly {
        attribute maxInstrumentDiameter : Diameter = 12;
        attribute minInstrumentDiameter : Diameter = 5;
        attribute leakThresholdPressure : Pressure = 0.5;
        attribute currentSealState : SealStateKind = SealStateKind::open;

        port instrumentPort : InstrumentPort;

        action def ActivateSeal {
            out sealState : SealStateKind;
        }
        action def DetectLeak {
            in measuredPressure : Pressure;
            out leakDetected : Boolean;
        }
        action def ResetSeal {
            out sealState : SealStateKind;
        }

        action activate : ActivateSeal;
        action detectLeak : DetectLeak;
        action reset : ResetSeal;

        state def SealBehavior {
            entry; then Open;
            state Open {
                entry { currentSealState = SealStateKind::open; }
            }
            transition from Open to Sealed
                when (activate.sealState == SealStateKind::sealed);
            state Sealed {
                entry { currentSealState = SealStateKind::sealed; }
                do { detectLeak; }
            }
            transition from Sealed to Compromised
                when (detectLeak.leakDetected == true);
            state Compromised {
                entry { currentSealState = SealStateKind::compromised; }
            }
            transition from Compromised to Sealed
                when (reset.sealState == SealStateKind::sealed);
        }

        state machine sealStateMachine : SealBehavior;
    }

    // ===== Valve Assembly =====
    part def ValveAssembly {
        attribute targetPressure : Pressure = 1.6;
        attribute maxFlowRate : FlowRate = 40.0;
        attribute currentValveState : ValveStateKind = ValveStateKind::closed;
        attribute currentFlow : FlowRate = 0.0;
        attribute currentPressure : Pressure = 0.0;

        port gasPort : GasPort;

        action def OpenValve {
            out valveState : ValveStateKind;
        }
        action def CloseValve {
            out valveState : ValveStateKind;
        }
        action def RegulatePressure {
            in measuredPressure : Pressure;
            in target : Pressure;
            out flowCommand : FlowRate;
            out valveState : ValveStateKind;
        }

        action open : OpenValve;
        action close : CloseValve;
        action regulate : RegulatePressure;

        state def ValveBehavior {
            entry; then Closed;
            state Closed {
                entry { currentValveState = ValveStateKind::closed; currentFlow = 0.0; }
            }
            transition from Closed to Open
                when (open.valveState == ValveStateKind::open);
            state Open {
                entry { currentValveState = ValveStateKind::open; }
            }
            transition from Open to Regulating
                when (currentPressure < targetPressure);
            state Regulating {
                entry { currentValveState = ValveStateKind::regulating; }
                do { regulate; }
            }
            transition from Regulating to Open
                when (currentPressure >= targetPressure);
            transition from Open to Closed
                when (close.valveState == ValveStateKind::closed);
            transition from Regulating to Closed
                when (close.valveState == ValveStateKind::closed);
        }

        state machine valveStateMachine : ValveBehavior;
    }

    // ===== Cannula =====
    part def Cannula {
        attribute innerDiameter : Diameter = 12;
        attribute outerDiameter : Diameter = 13;
        attribute length : Length = 100;
        attribute workingChannelDiameter : Diameter = 12;

        port instrumentPort : InstrumentPort;
        port gasPort : GasPort;

        part seal : SealAssembly;
        part valve : ValveAssembly;

        connection sealInstrumentConn connect seal.instrumentPort to instrumentPort;
        connection valveGasConn connect valve.gasPort to gasPort;

        action def EstablishPort {
            in cavity : BodyCavity;
            out portEstablished : Boolean;
        }

        action establish : EstablishPort;
    }

    // ===== Trocar System (Top-Level) =====
    part def TrocarSystem {
        attribute systemDiameter : Diameter = 12;
        attribute systemLength : Length = 100;
        attribute maxInsertionForce : Force = 40.0;
        attribute isAssembled : Boolean = true;

        part obturator : Obturator;
        part cannula : Cannula;

        connection obturatorCannulaConn connect obturator.tissuePort to cannula.instrumentPort;

        action def PenetrateAbdominalWall {
            in tissue : AbdominalTissue;
            out penetrationComplete : Boolean;
        }
        action def RemoveObturator {
            out obturatorRemoved : Boolean;
        }
        action def ActivateSealAssembly {
            out sealActivated : Boolean;
        }
        action def InflateCavity {
            in gas : InsufflationGas;
            in target : Pressure;
            out pneumoperitoneumEstablished : Boolean;
        }
        action def PerformSurgery {
            in instrument : SurgicalInstrument;
            out procedureComplete : Boolean;
        }

        action penetrate : PenetrateAbdominalWall;
        action removeObturator : RemoveObturator;
        action activateSeal : ActivateSealAssembly;
        action inflate : InflateCavity;
        action performSurgery : PerformSurgery;

        state def TrocarOperationalLifecycle {
            entry; then Assembled;
            state Assembled;
            transition from Assembled to Penetrating
                when (penetrate.penetrationComplete == true);
            state Penetrating {
                entry { penetrate; }
            }
            transition from Penetrating to ObturatorRemoved
                when (removeObturator.obturatorRemoved == true);
            state ObturatorRemoved {
                entry { removeObturator; activateSeal; }
            }
            transition from ObturatorRemoved to CavityInflated
                when (inflate.pneumoperitoneumEstablished == true);
            state CavityInflated {
                entry { inflate; }
            }
            transition from CavityInflated to InSurgery
                when (performSurgery.procedureComplete == false);
            state InSurgery {
                do { performSurgery; }
            }
            transition from InSurgery to ProcedureComplete
                when (performSurgery.procedureComplete == true);
            state ProcedureComplete;
        }

        state machine trocarStateMachine : TrocarOperationalLifecycle;
    }

    // ===== Requirements =====
    requirement def InsertionForceLimit {
        subject trocar : TrocarSystem;
        requirement {
            trocar.maxInsertionForce <= 40.0
        }
    }

    requirement def InstrumentCompatibility {
        subject seal : SealAssembly;
        requirement {
            seal.minInstrumentDiameter >= 5.0 and seal.maxInstrumentDiameter <= 12.0
        }
    }

    requirement def SealIntegrity {
        subject seal : SealAssembly;
        requirement {
            seal.currentSealState == SealStateKind::sealed implies seal.leakThresholdPressure >= 0.5
        }
    }

    requirement def PneumoperitoneumMaintenance {
        subject valve : ValveAssembly;
        requirement {
            valve.targetPressure >= 1.2 and valve.targetPressure <= 2.0
        }
    }

    requirement def GasFlowCapacity {
        subject valve : ValveAssembly;
        requirement {
            valve.maxFlowRate >= 30.0
        }
    }

    requirement def ObturatorRemovability {
        subject trocar : TrocarSystem;
        requirement {
            trocar.obturator.isInserted == false implies trocar.cannula.seal.currentSealState != SealStateKind::open
        }
    }

    requirement def TrocarAssemblyRequirement {
        subject trocar : TrocarSystem;
        requirement insertionForce : InsertionForceLimit;
        requirement compatibility : InstrumentCompatibility;
        requirement integrity : SealIntegrity;
        requirement pneumoperitoneum : PneumoperitoneumMaintenance;
        requirement flowCapacity : GasFlowCapacity;
        requirement removability : ObturatorRemovability;
    }

    // ===== Instance =====
    part trocarSystemInstance : TrocarSystem {
        override systemDiameter = 12;
        override systemLength = 100;
        override maxInsertionForce = 35.0;

        part obturator {
            override tipType = ObturatorTipType::optical;
            override length = 100;
            override diameter = 11;
        }

        part cannula {
            override innerDiameter = 12;
            override outerDiameter = 13;
            override length = 100;

            part seal {
                override maxInstrumentDiameter = 12;
                override minInstrumentDiameter = 5;
                override leakThresholdPressure = 0.5;
            }

            part valve {
                override targetPressure = 1.6;
                override maxFlowRate = 40.0;
            }
        }
    }
}
