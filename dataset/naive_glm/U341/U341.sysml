package OstomyApplianceSystem {
    import ScalarValues::*;

    // ---- Unit definitions ----
    unit g;
    unit mL;
    unit min;
    unit h;
    unit kPa;
    unit N;
    unit cm2;
    unit ppm;
    unit percent;
    unit g_per_min = g / min;
    unit N_per_cm2 = N / cm2;

    // ---- Value type definitions ----
    value def Volume :> Real { unit mL; }
    value def FlowRate :> Real { unit g_per_min; }
    value def WearTime :> Real { unit h; }
    value def Adhesion :> Real { unit N_per_cm2; }
    value def PressureValue :> Real { unit kPa; }
    value def OdorLevel :> Real { unit ppm; }
    value def FillPercent :> Real { unit percent; }

    // ---- Item definitions ----
    item def Effluent {
        attribute volume : Volume;
        attribute viscosity : Real;
        attribute pH : Real;
    }

    item def FlatusGas {
        attribute volume : Volume;
        attribute odorConcentration : OdorLevel;
        attribute internalPressure : PressureValue;
    }

    item def FilteredGas {
        attribute volume : Volume;
        attribute odorConcentration : OdorLevel;
    }

    item def ActivatedCarbon {
        attribute porosity : Real;
        attribute absorptionEfficiency : Real;
        attribute remainingCapacity : Real;
    }

    item def HydrocolloidMaterial {
        attribute adhesionStrength : Adhesion;
        attribute waterResistanceRating : Real;
        attribute biocompatibilityIndex : Real;
        attribute thickness : Real;
    }

    item def OdorBarrierFilm {
        attribute opacity : Real;
        attribute odorPermeability : Real;
        attribute tensileStrength : Real;
    }

    // ---- Port definitions ----
    port def StomaPort {
        out effluentFlow : Effluent;
        out gasFlow : FlatusGas;
    }

    port def PouchInletPort {
        in effluentIn : Effluent;
        in gasIn : FlatusGas;
    }

    port def BarrierOutletPort {
        out effluentOut : Effluent;
        out gasOut : FlatusGas;
    }

    port def VentPort {
        out ventedGas : FilteredGas;
    }

    port def DrainPort {
        out drainedEffluent : Effluent;
    }

    // ---- Requirement definitions ----
    requirement def LeakProofSealRequirement {
        doc "The skin barrier shall maintain a leak-proof seal around the stoma.";
        subject barrier : SkinBarrier;
        requirement sealStrength {
            barrier.adhesionStrength >= 5.0 [N_per_cm2];
        }
        requirement sealIntegrity {
            barrier.sealIntegrity >= 0.9;
        }
    }

    requirement def OdorControlRequirement {
        doc "The odor filter shall neutralize odor from vented gas.";
        subject filter : OdorFilter;
        requirement maxOutputOdor {
            filter.outputOdorLevel <= 10.0 [ppm];
        }
    }

    requirement def WearTimeRequirement {
        doc "The skin barrier shall maintain adhesion for at least 72 hours.";
        subject barrier : SkinBarrier;
        requirement minWearTime {
            barrier.maxWearTime >= 72.0 [h];
        }
    }

    requirement def SkinProtectionRequirement {
        doc "The skin barrier shall protect peristomal skin from waste contact.";
        subject barrier : SkinBarrier;
        requirement waterResistance {
            barrier.material.waterResistanceRating >= 0.9;
        }
        requirement biocompatibility {
            barrier.material.biocompatibilityIndex >= 0.95;
        }
    }

    requirement def DiscretionRequirement {
        doc "The collection pouch shall be opaque for user privacy.";
        subject pouch : CollectionPouch;
        requirement opacityLevel {
            pouch.film.opacity >= 0.95;
        }
        requirement odorBarrier {
            pouch.film.odorPermeability <= 0.02;
        }
    }

    requirement def CapacityRequirement {
        doc "The collection pouch shall have sufficient capacity for daily use.";
        subject pouch : CollectionPouch;
        requirement minCapacity {
            pouch.capacity >= 300.0 [mL];
        }
    }

    requirement def DrainabilityRequirement {
        doc "The pouch shall be drainable without removing the skin barrier.";
        subject pouch : CollectionPouch;
        requirement drainable {
            pouch.isDrainable == true;
        }
    }

    // ---- Part definitions ----
    part def SkinBarrier {
        port stomaFacing : StomaPort;
        port pouchFacing : BarrierOutletPort;

        attribute material : HydrocolloidMaterial;
        attribute adhesionStrength : Adhesion := 6.5 [N_per_cm2];
        attribute maxWearTime : WearTime := 72.0 [h];
        attribute currentWearTime : WearTime := 0.0 [h];
        attribute sealIntegrity : Real := 1.0;
        attribute isApplied : Boolean := false;

        action def DirectWasteFlow {
            in stomaEffluent : Effluent;
            in stomaGas : FlatusGas;
            out pouchEffluent : Effluent;
            out pouchGas : FlatusGas;
        }

        action def DegradeAdhesion {
            in elapsed : WearTime;
            out updatedIntegrity : Real;
        }

        action def ApplyBarrier {
            out applied : Boolean;
        }

        action def RemoveBarrier {
            out removed : Boolean;
        }

        perform action directFlow : DirectWasteFlow;
        perform action degrade : DegradeAdhesion;
        perform action apply : ApplyBarrier;
        perform action remove : RemoveBarrier;
    }

    part def OdorFilter {
        port ventPort : VentPort;

        attribute carbon : ActivatedCarbon;
        attribute absorptionEfficiency : Real := 0.95;
        attribute outputOdorLevel : OdorLevel := 5.0 [ppm];
        attribute remainingLife : Real := 1.0;
        attribute maxGasFlowRate : FlowRate := 2.0 [g_per_min];

        action def FilterGas {
            in rawGas : FlatusGas;
            out cleanGas : FilteredGas;
        }

        perform action filter : FilterGas;
    }

    part def CollectionPouch {
        port barrierFacing : PouchInletPort;
        port drainPort : DrainPort;

        attribute film : OdorBarrierFilm;
        attribute capacity : Volume := 400.0 [mL];
        attribute currentFill : Volume := 0.0 [mL];
        attribute fillLevel : FillPercent := 0.0 [percent];
        attribute isDrainable : Boolean := true;
        attribute isFull : Boolean := false;
        attribute internalPressure : PressureValue := 101.3 [kPa];

        part odorFilter : OdorFilter;

        action def CollectWaste {
            in incomingEffluent : Effluent;
            in incomingGas : FlatusGas;
            out updatedFill : FillPercent;
        }

        action def EmptyPouch {
            in currentVolume : Volume;
            out drainedEffluent : Effluent;
            out newFill : FillPercent;
        }

        action def VentGas {
            in internalGas : FlatusGas;
            out ventedGas : FilteredGas;
        }

        action def MonitorFillLevel {
            in currentVolume : Volume;
            out level : FillPercent;
            out full : Boolean;
        }

        perform action collect : CollectWaste;
        perform action empty : EmptyPouch;
        perform action vent : VentGas;
        perform action monitor : MonitorFillLevel;
    }

    part def Stoma {
        port output : StomaPort;

        attribute outputRate : FlowRate := 5.0 [g_per_min];
        attribute gasOutputRate : FlowRate := 0.5 [g_per_min];
    }

    part def User {
        attribute wearTimePreference : WearTime := 72.0 [h];
        attribute comfortRating : Real := 0.8;

        action def MonitorPouchLevel {
            in fillLevel : FillPercent;
            out needsEmptying : Boolean;
        }

        action def EmptyPouchAction {
            out success : Boolean;
        }

        action def ReplaceSystem {
            out replaced : Boolean;
        }

        perform action monitor : MonitorPouchLevel;
        perform action emptyPouch : EmptyPouchAction;
        perform action replace : ReplaceSystem;
    }

    // ---- Top-level system ----
    part def OstomyApplianceSystem {
        part stoma : Stoma;
        part skinBarrier : SkinBarrier;
        part collectionPouch : CollectionPouch;
        part user : User;

        // Connections
        connection stomaToBarrier connect stoma.output to skinBarrier.stomaFacing {
            item effluentFlow : Effluent;
            item gasFlow : FlatusGas;
        }

        connection barrierToPouch connect skinBarrier.pouchFacing to collectionPouch.barrierFacing {
            item effluentOut : Effluent;
            item gasOut : FlatusGas;
        }

        connection pouchInternalVent connect collectionPouch to collectionPouch.odorFilter {
            item internalGas : FlatusGas;
        }

        connection filterVentToEnvironment connect collectionPouch.odorFilter.ventPort to collectionPouch.drainPort {
            item ventedGas : FilteredGas;
        }

        // Requirement satisfactions
        satisfy leakProofReq : LeakProofSealRequirement by skinBarrier;
        satisfy wearTimeReq : WearTimeRequirement by skinBarrier;
        satisfy skinProtReq : SkinProtectionRequirement by skinBarrier;
        satisfy odorReq : OdorControlRequirement by collectionPouch.odorFilter;
        satisfy discretionReq : DiscretionRequirement by collectionPouch;
        satisfy capacityReq : CapacityRequirement by collectionPouch;
        satisfy drainReq : DrainabilityRequirement by collectionPouch;

        // Operational lifecycle state machine
        state def OperationalLifecycle {
            entry action initialize {
                skinBarrier.isApplied := true;
                skinBarrier.sealIntegrity := 1.0;
                skinBarrier.currentWearTime := 0.0 [h];
                collectionPouch.currentFill := 0.0 [mL];
                collectionPouch.fillLevel := 0.0 [percent];
                collectionPouch.isFull := false;
            }

            state Applied {
                entry action applyBarrier {
                    skinBarrier.isApplied := true;
                    skinBarrier.sealIntegrity := 1.0;
                }
                doc "Skin barrier is applied to the peristomal skin.";
            }

            state Collecting {
                do action collectWaste {
                    skinBarrier.directFlow();
                    collectionPouch.collect();
                    collectionPouch.monitor();
                }
                doc "System is actively collecting waste and gas from the stoma.";
            }

            state Full {
                entry action markFull {
                    collectionPouch.isFull := true;
                }
                doc "Pouch has reached capacity threshold and needs emptying.";
            }

            state Emptying {
                do action emptyPouch {
                    collectionPouch.empty();
                    collectionPouch.isFull := false;
                }
                doc "User empties the drainable pouch without removing the barrier.";
            }

            state Degrading {
                do action degradeBarrier {
                    skinBarrier.degrade(skinBarrier.maxWearTime);
                }
                doc "Skin barrier adhesive is degrading after intended wear time.";
            }

            state Removed {
                entry action removeSystem {
                    skinBarrier.isApplied := false;
                    skinBarrier.sealIntegrity := 0.0;
                }
                doc "Entire appliance is removed and will be replaced.";
            }

            transition initial to Applied;
            transition Applied to Collecting when skinBarrier.sealIntegrity >= 0.9;
            transition Collecting to Full when collectionPouch.fillLevel >= 80.0 [percent];
            transition Full to Emptying when collectionPouch.isDrainable == true;
            transition Emptying to Collecting when collectionPouch.fillLevel <= 10.0 [percent];
            transition Collecting to Degrading when skinBarrier.currentWearTime >= skinBarrier.maxWearTime;
            transition Degrading to Removed when skinBarrier.sealIntegrity < 0.5;
            transition Removed to Applied when user.replace.replaced == true;
        }

        perform state lifecycle : OperationalLifecycle;
    }
}
