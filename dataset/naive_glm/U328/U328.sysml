package NeilRobertsonStretcher {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def MassKg :> Mass { unit = 'kg'; }
    value def ForceN :> Force { unit = 'N'; }
    value def LengthMm :> Length { unit = 'mm'; }
    value def AngleDeg :> Real { unit = 'deg'; }
    value def DimensionlessCount :> Real;

    // ===== Items =====
    item def Patient {
        attribute weight : MassKg;
        attribute hasSuspectedSpinalInjury : Boolean;
        attribute isConscious : Boolean;
    }
    item def RescueEnvironment {
        attribute passageWidth : LengthMm;
        attribute isConfinedSpace : Boolean;
        attribute allowsVerticalHoist : Boolean;
    }

    // ===== Requirements =====
    requirement def ImmobilizationRequirement {
        doc /* The stretcher shall completely immobilize a patient, especially one with suspected spinal injuries. */
        attribute maxPatientMovement : LengthMm = 5 [mm];
        subject patient : Patient;
        require patient.hasSuspectedSpinalInjury implies immobilizationMovement <= maxPatientMovement
    }
    requirement def LoadBearingRequirement {
        doc /* The system shall support a patient weighing up to 182 kg. */
        attribute maxPatientWeight : MassKg = 182 [kg];
        subject patient : Patient;
        require patient.weight <= maxPatientWeight
    }
    requirement def StrapRestraintRequirement {
        doc /* The system shall use seven nylon webbing straps to secure the patient. */
        attribute requiredStrapCount : Integer = 7;
        require strapCount == requiredStrapCount
    }
    requirement def LiftingBridleRequirement {
        doc /* The system shall be equipped with four lifting bridles for vertical and horizontal extraction. */
        attribute requiredBridleCount : Integer = 4;
        require bridleCount == requiredBridleCount
    }
    requirement def ConfinedSpaceManeuverRequirement {
        doc /* The stretcher shall be narrow and compact to maneuver through tight passages. */
        attribute maxStretcherWidth : LengthMm = 500 [mm];
        require overallWidth <= maxStretcherWidth
    }

    // ===== Parts =====
    part def CanvasShell {
        attribute material : String = "Heavy-duty canvas";
        attribute overallWidth : LengthMm;
        attribute overallLength : LengthMm;
        port def ShellWrapPort;
        port wrapPort : ShellWrapPort;
    }
    part def WoodenSlat {
        attribute material : String = "Ash wood";
        attribute slatLength : LengthMm;
        attribute slatWidth : LengthMm;
        attribute slatThickness : LengthMm;
    }
    part def NylonWebbingStrap {
        attribute material : String = "Nylon webbing";
        attribute strapIndex : Integer;
        attribute tensileStrength : ForceN;
        attribute isFastened : Boolean = false;
        action def Fasten;
        action def Release;
    }
    part def HeadNeckRestraint {
        attribute isSecured : Boolean = false;
        attribute adjustmentAngle : AngleDeg = 0 [deg];
        action def SecureHead;
        action def ReleaseHead;
    }
    part def LiftingBridle {
        attribute bridleIndex : Integer;
        attribute safeWorkingLoad : ForceN;
        attribute isAttached : Boolean = false;
        port def BridleAttachmentPort;
        port attachmentPort : BridleAttachmentPort;
    }
    part def AttachmentPoint {
        attribute pointId : Integer;
        attribute loadRating : ForceN;
        port def PointConnectionPort;
        port connectionPort : PointConnectionPort;
    }

    // ===== Stretcher Part =====
    part def NeilRobertsonStretcher {
        attribute strapCount : Integer = 7;
        attribute bridleCount : Integer = 4;
        attribute overallWidth : LengthMm = 480 [mm];
        attribute overallLength : LengthMm = 2100 [mm];
        attribute maxLoad : MassKg = 182 [kg];
        attribute immobilizationMovement : LengthMm = 0 [mm];

        satisfy LoadBearingRequirement;
        satisfy ImmobilizationRequirement;
        satisfy StrapRestraintRequirement;
        satisfy LiftingBridleRequirement;
        satisfy ConfinedSpaceManeuverRequirement;

        part shell : CanvasShell {
            attribute overallWidth = 480 [mm];
            attribute overallLength = 2100 [mm];
        }
        part slats : WoodenSlat[12] {
            attribute slatLength = 480 [mm];
            attribute slatWidth = 100 [mm];
            attribute slatThickness = 18 [mm];
        }
        part straps : NylonWebbingStrap[7] {
            attribute tensileStrength = 5000 [N];
        }
        part headRestraint : HeadNeckRestraint;
        part bridles : LiftingBridle[4] {
            attribute safeWorkingLoad = 2500 [N];
        }
        part attachmentPoints : AttachmentPoint[8] {
            attribute loadRating = 3000 [N];
        }

        // Ports for external interaction
        port def PatientLoadingPort;
        port def LiftingPort;
        port def NavigationPort;
        port patientPort : PatientLoadingPort;
        port liftPort : LiftingPort;
        port navPort : NavigationPort;

        // Connections
        connection def BridleToAttachmentConnection {
            end bridleEnd : LiftingBridle::BridleAttachmentPort;
            end pointEnd : AttachmentPoint::PointConnectionPort;
        }
        connection bridleAttachment : BridleToAttachmentConnection[4] connect
            bridles.attachmentPort to attachmentPoints.connectionPort;

        // State Machine
        state def StretcherLifecycle {
            entry action { /* initialize */ }
            state stowed {
                entry action { /* stretcher folded and stowed */ }
                transition stowed_to_deployed
                    from stowed to deployed
                    when patientPort.isReceived
                    do action { deployStretcher(); }
            }
            state deployed {
                entry action { /* lay flat, open shell */ }
                state patientPositioned {
                    entry action { positionPatient(); }
                    transition to patientStrapped
                        when patientPort.isReceived
                        do action { wrapShell(); }
                }
                state patientStrapped {
                    entry action { /* fasten straps and head restraint */ }
                    do action {
                        for strap in straps {
                            strap.Fasten();
                        }
                        headRestraint.SecureHead();
                    }
                    transition to extraction
                        when liftPort.isReceived
                        do action { attachBridles(); }
                }
                transition deployed_to_extraction
                    from patientStrapped to extraction
                    when liftPort.isReceived;
            }
            state extraction {
                entry action { /* begin hoist */ }
                state lifted {
                    entry action { hoist(); }
                    transition to navigating
                        when navPort.isReceived;
                }
                state navigating {
                    entry action { navigateThroughConfinedSpace(); }
                    transition to evacuated
                        when navPort.isReceived;
                }
                state evacuated {
                    entry action { /* evacuation complete */ }
                }
            }
            transition extraction_complete
                from extraction to stowed
                when evacuated.isActive
                do action { resetStretcher(); }
        }

        // Behaviors
        action def DeployStretcher;
        action def PositionPatient;
        action def WrapShell;
        action def AttachBridles;
        action def Hoist;
        action def NavigateThroughConfinedSpace;
        action def ResetStretcher;

        action deployStretcher : DeployStretcher;
        action positionPatient : PositionPatient;
        action wrapShell : WrapShell;
        action attachBridles : AttachBridles;
        action hoist : Hoist;
        action navigateThroughConfinedSpace : NavigateThroughConfinedSpace;
        action resetStretcher : ResetStretcher;

        exhibit state lifecycle : StretcherLifecycle;
    }

    // ===== System Context =====
    part RescueOperation {
        part stretcher : NeilRobertsonStretcher;
        item patient : Patient {
            attribute weight = 85 [kg];
            attribute hasSuspectedSpinalInjury = true;
            attribute isConscious = false;
        }
        item environment : RescueEnvironment {
            attribute passageWidth = 600 [mm];
            attribute isConfinedSpace = true;
            attribute allowsVerticalHoist = true;
        }
        part craneOrRopeSystem {
            port def HoistPort;
            port hoistPort : HoistPort;
        }
        connection patientToStretcher
            connect patient to stretcher.patientPort;
        connection hoistToStretcher
            connect craneOrRopeSystem.hoistPort to stretcher.liftPort;
        connection environmentToStretcher
            connect environment to stretcher.navPort;
    }
}
