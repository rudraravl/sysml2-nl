package HipAbductorWedgeSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def AngleDeg :> Real { unit "deg"; }
    value def PressureKPa :> Real { unit "kPa"; }
    value def ForceN :> Real { unit "N"; }
    value def LengthCm :> Real { unit "cm"; }
    value def DensityKgPerM3 :> Real { unit "kg/m^3"; }
    value def FirmnessN :> Real { unit "N"; }
    value def MassKg :> Real { unit "kg"; }
    value def DurationHr :> Real { unit "h"; }

    // ---- Item definitions ----
    item def HypoallergenicFoam {
        attribute density : DensityKgPerM3 = 35;
        attribute firmness : FirmnessN = 120;
        attribute hypoallergenic : Boolean = true;
    }

    item def AntimicrobialCoverMaterial {
        attribute waterproof : Boolean = true;
        attribute antimicrobial : Boolean = true;
        attribute nonIrritating : Boolean = true;
    }

    item def StrapMaterial {
        attribute tensileStrength : ForceN = 250;
        attribute adjustable : Boolean = true;
    }

    item def Leg {
        attribute circumference : LengthCm;
        attribute skinPressure : PressureKPa;
    }

    // ---- Port definitions ----
    port def WedgeContactPort {
        out item legContact : Leg;
        attribute contactPressure : PressureKPa;
    }

    port def StrapAnchorPort {
        in item strapForce : ForceN;
    }

    // ---- Requirements ----
    requirement def PreventHipDislocation {
        doc "The system shall maintain the patient's legs in an abducted position to prevent dislocation of the new hip joint during healing.";
        subject wedgeSystem : HipAbductorWedge;
        requirement :> abductionAngle {
            spec : AngleDeg = 25;
            constraint { spec >= 20 and spec <= 30 }
        }
    }

    requirement def MaintainSafePressure {
        doc "The system shall maintain contact pressure on the patient's legs below a safe threshold to prevent skin damage.";
        subject wedgeSystem : HipAbductorWedge;
        attribute maxSafePressure : PressureKPa = 6.0;
        constraint { wedgeSystem.measuredPressure <= maxSafePressure }
    }

    requirement def ProvideHygienicSurface {
        doc "The protective cover shall be waterproof and antimicrobial to prevent contamination.";
        subject cover : ProtectiveCover;
        constraint { cover.material.waterproof == true and cover.material.antimicrobial == true }
    }

    requirement def SecureWedgeInPlace {
        doc "The securing straps shall hold the wedge between the patient's legs without slipping during extended use.";
        subject straps : SecuringStrap[2];
        attribute minTension : ForceN = 10;
        attribute maxTension : ForceN = 80;
        constraint { for all s in straps { s.tension >= minTension and s.tension <= maxTension } }
    }

    requirement def ProvideStableSupport {
        doc "The foam core shall provide stable support with defined firmness and density for patient comfort.";
        subject core : WedgeCore;
        constraint { core.material.firmness >= 100 and core.material.density >= 30 }
    }

    // ---- Part definitions ----
    part def WedgeCore {
        attribute wedgeAngle : AngleDeg = 25;
        attribute length : LengthCm = 40;
        attribute height : LengthCm = 25;
        attribute mass : MassKg = 0.6;
        item material : HypoallergenicFoam;
        port contactLeft : WedgeContactPort;
        port contactRight : WedgeContactPort;
        port anchorLeft : StrapAnchorPort;
        port anchorRight : StrapAnchorPort;
    }

    part def ProtectiveCover {
        attribute coverThickness : LengthCm = 0.3;
        item material : AntimicrobialCoverMaterial;
        port surfaceLeft : WedgeContactPort;
        port surfaceRight : WedgeContactPort;
    }

    part def SecuringStrap {
        attribute strapLength : LengthCm = 80;
        attribute tension : ForceN;
        attribute maxTension : ForceN = 80;
        item material : StrapMaterial;
        port anchorEnd : StrapAnchorPort;
        port buckleEnd : StrapAnchorPort;
    }

    part def HipAbductorWedge {
        attribute measuredPressure : PressureKPa;
        attribute measuredAngle : AngleDeg;
        attribute usageDuration : DurationHr;

        part core : WedgeCore {
            item material : HypoallergenicFoam {
                attribute density : DensityKgPerM3 = 35;
                attribute firmness : FirmnessN = 120;
                attribute hypoallergenic : Boolean = true;
            }
        }

        part cover : ProtectiveCover {
            item material : AntimicrobialCoverMaterial {
                attribute waterproof : Boolean = true;
                attribute antimicrobial : Boolean = true;
                attribute nonIrritating : Boolean = true;
            }
        }

        part leftStrap : SecuringStrap {
            item material : StrapMaterial {
                attribute tensileStrength : ForceN = 250;
                attribute adjustable : Boolean = true;
            }
        }

        part rightStrap : SecuringStrap {
            item material : StrapMaterial {
                attribute tensileStrength : ForceN = 250;
                attribute adjustable : Boolean = true;
            }
        }

        part patientLeftLeg : Leg {
            attribute circumference : LengthCm = 45;
            attribute skinPressure : PressureKPa;
        }

        part patientRightLeg : Leg {
            attribute circumference : LengthCm = 45;
            attribute skinPressure : PressureKPa;
        }

        // Connections
        connection core.contactLeft to cover.surfaceLeft;
        connection core.contactRight to cover.surfaceRight;
        connection leftStrap.anchorEnd to core.anchorLeft;
        connection leftStrap.buckleEnd to patientLeftLeg;
        connection rightStrap.anchorEnd to core.anchorRight;
        connection rightStrap.buckleEnd to patientRightLeg;
        connection cover.surfaceLeft to patientLeftLeg;
        connection cover.surfaceRight to patientRightLeg;

        // Operation state machine
        state def OperationState {
            entry action initialize;
            state Unplaced {
                entry action prepareWedge;
                transition Unplaced to Placed
                    when { wedgePlacedBetweenLegs == true }
                    do action placeWedge;
            }
            state Placed {
                entry action positionWedge;
                transition Placed to Secured
                    when { strapsAttached == true }
                    do action attachStraps;
            }
            state Secured {
                entry action secureStraps;
                transition Secured to Adjusting
                    when { tensionAdjustmentNeeded == true }
                    do action adjustTension;
            }
            state Adjusting {
                entry action tuneTension;
                transition Adjusting to Monitoring
                    when { measuredAngle >= 20 and measuredAngle <= 30 and measuredPressure <= 6.0 }
                    do action confirmStableAngle;
            }
            state Monitoring {
                entry action monitorPosition;
                do action checkPressureAndAngle;
                transition Monitoring to Adjusting
                    when { measuredAngle < 20 or measuredAngle > 30 or measuredPressure > 6.0 }
                    do action reAdjust;
                transition Monitoring to Released
                    when { therapyComplete == true }
                    do action releaseStraps;
            }
            state Released {
                entry action removeWedge;
                transition Released to Unplaced
                    when { systemReset == true };
            }
        }

        attribute wedgePlacedBetweenLegs : Boolean;
        attribute strapsAttached : Boolean;
        attribute tensionAdjustmentNeeded : Boolean;
        attribute therapyComplete : Boolean;
        attribute systemReset : Boolean;

        exhibit state OperationState;

        // Actions
        action placeWedge {
            in leftLeg : Leg;
            in rightLeg : Leg;
            out wedge : WedgeCore;
        }

        action attachStraps {
            in leftStrap : SecuringStrap;
            in rightStrap : SecuringStrap;
            in leftLeg : Leg;
            in rightLeg : Leg;
            out attached : Boolean;
        }

        action adjustTension {
            in strap : SecuringStrap;
            in targetAngle : AngleDeg;
            out tension : ForceN;
        }

        action confirmStableAngle {
            in measuredAngle : AngleDeg;
            in measuredPressure : PressureKPa;
            out stable : Boolean;
        }

        action checkPressureAndAngle {
            in leftLeg : Leg;
            in rightLeg : Leg;
            in core : WedgeCore;
            out measuredAngle : AngleDeg;
            out measuredPressure : PressureKPa;
        }

        action releaseStraps {
            in leftStrap : SecuringStrap;
            in rightStrap : SecuringStrap;
            out released : Boolean;
        }

        // Requirement satisfactions
        satisfy PreventHipDislocation by wedgeSystem;
        satisfy MaintainSafePressure by wedgeSystem;
        satisfy ProvideHygienicSurface by cover;
        satisfy SecureWedgeInPlace by {leftStrap, rightStrap};
        satisfy ProvideStableSupport by core;
    }
}
