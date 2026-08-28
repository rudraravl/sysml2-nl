package LowDeadSpaceSyringe {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type Volume :> Real {
        unit volume[mm^3];
    }
    value type Pressure :> Real {
        unit pressure[kPa];
    }
    value type Length :> Real {
        unit length[mm];
    }
    value type Mass :> Real {
        unit mass[mg];
    }
    value type Percentage :> Real {
        unit percent[%];
    }
    value type Force :> Real {
        unit force[N];
    }

    // ---- Item types ----
    item def Medication {
        attribute concentration : Mass = 10.0 [mg/mm^3];
        attribute doseVolume : Volume;
    }
    item def AirBubble {
        attribute volume : Volume = 0.0 [mm^3];
    }
    item def FluidFlow {
        attribute flowRate : Volume = 0.0 [mm^3];
    }

    // ---- Interfaces ----
    port def FluidPort {
        out item fluidFlow : FluidFlow;
        in item medication : Medication;
    }
    port def MechanicalPort {
        in attribute appliedForce : Force;
    }
    port def TissueInterface {
        out item medication : Medication;
    }

    // ---- Component definitions ----
    part def Barrel {
        attribute material : String = "Medical-grade polypropylene";
        attribute innerDiameter : Length = 4.0 [mm];
        attribute length : Length = 60.0 [mm];
        attribute maxVolume : Volume = 0.75 [mm^3] * 1000; // ~754 mm^3
        attribute currentVolume : Volume = 0.0 [mm^3];
        port fluidPort : FluidPort;
        port plungerInterface : MechanicalPort;
    }

    part def PlungerSeal {
        attribute material : String = "Synthetic rubber";
        attribute diameter : Length = 4.0 [mm];
        attribute sealIntegrity : Boolean = true;
    }

    part def Plunger {
        part seal : PlungerSeal;
        attribute strokeLength : Length = 60.0 [mm];
        attribute currentForce : Force = 0.0 [N];
        port mechanicalPort : MechanicalPort;
    }

    part def LowDeadSpaceTip {
        attribute residualDeadSpace : Volume = 2.5 [mm^3];
        attribute standardDeadSpace : Volume = 50.0 [mm^3];
        attribute wasteReduction : Percentage = 95.0 [%];
        attribute material : String = "Medical-grade polypropylene";
        attribute internalGeometry : String = "Tapered conical with integrated needle seat";
        port barrelSide : FluidPort;
        port needleSide : FluidPort;
    }

    part def Needle {
        attribute gauge : Integer = 25;
        attribute length : Length = 25.0 [mm];
        attribute innerDiameter : Length = 0.26 [mm];
        attribute bevelAngle : Real = 12.0;
        attribute sharpness : Boolean = true;
        attribute material : String = "Stainless steel";
        port hubPort : FluidPort;
        port tissuePort : TissueInterface;
    }

    // ---- The syringe system ----
    part def LowDeadSpaceSyringe {
        attribute isSterile : Boolean = true;
        attribute isSingleUse : Boolean = true;
        attribute nominalDose : Volume = 500.0 [mm^3];
        attribute actualDeliveredDose : Volume = 0.0 [mm^3];
        attribute residualWaste : Volume = 0.0 [mm^3];

        part barrel : Barrel;
        part plunger : Plunger;
        part tip : LowDeadSpaceTip;
        part needle : Needle;

        // Connections
        connection plungerToBarrel : Plunger.mechanicalPort to Barrel.plungerInterface;
        connection barrelToTip : Barrel.fluidPort to LowDeadSpaceTip.barrelSide;
        connection tipToNeedle : LowDeadSpaceTip.needleSide to Needle.hubPort;

        // Behavior: lifecycle state machine
        behavior lifecycleStateMachine {
            state SterileIdle {
                entry attribute isSterile = true;
                attribute currentVolume = 0.0 [mm^3];
            }
            state DrawingMedication {
                attribute currentVolume : Volume;
            }
            state Primed {
                attribute currentVolume : Volume;
            }
            state ExpellingAir {
                attribute airBubbleVolume : Volume;
            }
            state ReadyForInjection {
                attribute airBubbleVolume = 0.0 [mm^3];
            }
            state Injecting {
                attribute currentForce : Force;
                attribute deliveredVolume : Volume;
            }
            state InjectionComplete {
                attribute actualDeliveredDose : Volume;
                attribute residualWaste : Volume;
            }
            state Disposed {
                attribute isSterile = false;
            }

            transition SterileIdle to DrawingMedication
                when barrel.plungerInterface.appliedForce < 0.0 [N];
            transition DrawingMedication to Primed
                when barrel.currentVolume >= nominalDose;
            transition Primed to ExpellingAir
                when barrel.currentVolume > 0.0 [mm^3];
            transition ExpellingAir to ReadyForInjection
                when AirBubble.volume == 0.0 [mm^3];
            transition ReadyForInjection to Injecting
                when plunger.mechanicalPort.appliedForce > 0.0 [N];
            transition Injecting to InjectionComplete
                when actualDeliveredDose >= nominalDose;
            transition InjectionComplete to Disposed
                when true;
        }

        // Action to compute waste reduction
        action computeWasteReduction {
            in standardWaste : Volume = 50.0 [mm^3];
            in actualWaste : Volume = tip.residualDeadSpace;
            out reduction : Percentage;
            // reduction = (standardWaste - actualWaste) / standardWaste * 100
        }
    }

    // ---- Requirements ----
    requirement def SterilityRequirement {
        subject syringe : LowDeadSpaceSyringe;
        requirement syringe.isSterile == true;
    }

    requirement def DoseAccuracyRequirement {
        subject syringe : LowDeadSpaceSyringe;
        attribute tolerance : Volume = 5.0 [mm^3];
        requirement abs(syringe.actualDeliveredDose - syringe.nominalDose) <= tolerance;
    }

    requirement def WasteReductionRequirement {
        subject syringe : LowDeadSpaceSyringe;
        attribute minReduction : Percentage = 80.0 [%];
        requirement syringe.tip.wasteReduction >= minReduction;
    }

    requirement def SingleUseRequirement {
        subject syringe : LowDeadSpaceSyringe;
        requirement syringe.isSingleUse == true;
    }

    requirement def DeadSpaceRequirement {
        subject tip : LowDeadSpaceTip;
        attribute maxDeadSpace : Volume = 5.0 [mm^3];
        requirement tip.residualDeadSpace <= maxDeadSpace;
    }

    requirement def DoseDeliveryRequirement {
        subject syringe : LowDeadSpaceSyringe;
        requirement syringe.actualDeliveredDose >= 0.95 * syringe.nominalDose;
    }

    // ---- Requirement group ----
    requirement LowDeadSpaceSyringeRequirements {
        subject syringeSystem : LowDeadSpaceSyringe;

        satisfy SterilityRequirement by syringeSystem;
        satisfy DoseAccuracyRequirement by syringeSystem;
        satisfy WasteReductionRequirement by syringeSystem;
        satisfy SingleUseRequirement by syringeSystem;
        satisfy DeadSpaceRequirement by syringeSystem.tip;
        satisfy DoseDeliveryRequirement by syringeSystem;
    }
}
