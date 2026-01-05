package 'Abductor Wedge System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AbductionAngle :> ISQ::PlaneAngleValue;
    attribute def ContactPressure :> ISQ::PressureValue;
    attribute def SeparationDistance :> ISQ::LengthValue;
    attribute def CompressionForce :> ISQ::ForceValue;
    
    item def FoamMaterial {
        attribute density :> ISQ::MassDensityValue;
        attribute firmness : Real;
        attribute hypoallergenic : Boolean;
    }
    
    item def CoverMaterial {
        attribute waterproof : Boolean;
        attribute antimicrobial : Boolean;
    }
    
    item def PatientLeg {
        attribute mass :> ISQ::MassValue;
        attribute currentAbductionAngle :> ISQ::PlaneAngleValue;
    }
    
    port def LegContactPort {
        attribute contactForce :> ISQ::ForceValue;
        attribute contactPressure :> ISQ::PressureValue;
        attribute contactArea :> ISQ::AreaValue;
    }
    
    port def StrapAttachmentPort {
        attribute tension :> ISQ::ForceValue;
    }
    
    part def WedgeCore {
        attribute wedgeAngle :> ISQ::PlaneAngleValue;
        attribute baseWidth :> ISQ::LengthValue;
        attribute height :> ISQ::LengthValue;
        attribute depth :> ISQ::LengthValue;
        attribute coreMaterial : FoamMaterial;
        
        port medialSurface : LegContactPort;
        port lateralSurface : LegContactPort;
    }
    
    part def ProtectiveCover {
        attribute coverMaterial : CoverMaterial;
        
        port innerSurface : LegContactPort;
        port outerSurface : LegContactPort;
    }
    
    part def SecuringStrap {
        attribute strapLength :> ISQ::LengthValue;
        attribute maxTension :> ISQ::ForceValue;
        attribute adjustable : Boolean;
        
        port wedgeAttachment : StrapAttachmentPort;
        port legWrap : LegContactPort;
    }
    
    part def AbductorWedge {
        attribute targetAbductionAngle :> ISQ::PlaneAngleValue;
        attribute targetSeparation :> ISQ::LengthValue;
        attribute maxContactPressure :> ISQ::PressureValue;
        attribute totalMass :> ISQ::MassValue;
        
        part core : WedgeCore {
            attribute :>> wedgeAngle = 25.0;
            attribute :>> baseWidth = 0.20;
            attribute :>> height = 0.15;
            attribute :>> depth = 0.25;
            attribute :>> coreMaterial {
                attribute :>> density = 35.0;
                attribute :>> firmness = 0.65;
                attribute :>> hypoallergenic = true;
            }
        }
        
        part cover : ProtectiveCover {
            attribute :>> coverMaterial {
                attribute :>> waterproof = true;
                attribute :>> antimicrobial = true;
            }
        }
        
        part medialStrap : SecuringStrap {
            attribute :>> strapLength = 0.80;
            attribute :>> maxTension = 50.0;
            attribute :>> adjustable = true;
        }
        
        part lateralStrap : SecuringStrap {
            attribute :>> strapLength = 0.80;
            attribute :>> maxTension = 50.0;
            attribute :>> adjustable = true;
        }
        
        port medialLegInterface : LegContactPort;
        port lateralLegInterface : LegContactPort;
        port medialStrapAttach : StrapAttachmentPort;
        port lateralStrapAttach : StrapAttachmentPort;
        
        connect core.medialSurface to cover.innerSurface;
        connect core.lateralSurface to cover.outerSurface;
        connect cover.innerSurface to medialLegInterface;
        connect cover.outerSurface to lateralLegInterface;
        connect medialStrap.wedgeAttachment to medialStrapAttach;
        connect lateralStrap.wedgeAttachment to lateralStrapAttach;
        connect medialStrap.legWrap to medialLegInterface;
        connect lateralStrap.legWrap to lateralLegInterface;
    }
    
    action def PositionWedge {
        in targetAngle :> ISQ::PlaneAngleValue;
        in medialLeg : PatientLeg;
        in lateralLeg : PatientLeg;
        out placementDepth :> ISQ::LengthValue;
        out achievedAngle :> ISQ::PlaneAngleValue;
    }
    
    action def ApplyAbductionForce {
        in wedgeAngle :> ISQ::PlaneAngleValue;
        in legMass :> ISQ::MassValue;
        in insertionDepth :> ISQ::LengthValue;
        out resultingAngle :> ISQ::PlaneAngleValue;
        out medialForce :> ISQ::ForceValue;
        out lateralForce :> ISQ::ForceValue;
    }
    
    action def MonitorContactPressure {
        in contactArea :> ISQ::AreaValue;
        in appliedForce :> ISQ::ForceValue;
        out measuredPressure :> ISQ::PressureValue;
    }
    
    action def AdjustStrapTension {
        in currentPressure :> ISQ::PressureValue;
        in maxPressure :> ISQ::PressureValue;
        in strap : SecuringStrap;
        out newTension :> ISQ::ForceValue;
        out adjustmentNeeded : Boolean;
    }
    
    action def MaintainAbductionPosition {
        in targetAngle :> ISQ::PlaneAngleValue;
        in currentAngle :> ISQ::PlaneAngleValue;
        in stabilityThreshold : Real;
        out positionStable : Boolean;
        out correctionRequired : Boolean;
    }
    
    attribute def PlacementCommand;
    attribute def RemovalCommand;
    
    state def WedgeOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign systemStatus = "Ready for placement";
        }
        
        transition idle_to_positioning
            first idle
            accept PlacementCommand
            then positioning;
        
        state positioning {
            entry assign systemStatus = "Positioning wedge between legs";
            do action positionAction : PositionWedge;
        }
        
        transition positioning_to_applying
            first positioning
            if positionAction.achievedAngle >= positionAction.targetAngle * 0.92
            then applying;
        
        transition positioning_to_repositioning
            first positioning
            if positionAction.achievedAngle < positionAction.targetAngle * 0.92
            then repositioning;
        
        state repositioning {
            entry assign systemStatus = "Adjusting wedge position";
            do action reposition : PositionWedge;
        }
        
        transition repositioning_to_positioning
            first repositioning
            then positioning;
        
        state applying {
            entry assign systemStatus = "Applying abduction force";
            do action applyForce : ApplyAbductionForce;
            do action monitorMedial : MonitorContactPressure;
            do action monitorLateral : MonitorContactPressure;
        }
        
        transition applying_to_securing
            first applying
            if applyForce.resultingAngle >= applyForce.wedgeAngle * 0.88
            then securing;
        
        state securing {
            entry assign systemStatus = "Securing straps";
            do action adjustMedialStrap : AdjustStrapTension;
            do action adjustLateralStrap : AdjustStrapTension;
        }
        
        transition securing_to_maintaining
            first securing
            if adjustMedialStrap.adjustmentNeeded == false and adjustLateralStrap.adjustmentNeeded == false
            then maintaining;
        
        transition securing_to_adjusting
            first securing
            if adjustMedialStrap.adjustmentNeeded == true or adjustLateralStrap.adjustmentNeeded == true
            then adjusting;
        
        state maintaining {
            entry assign systemStatus = "Maintaining abduction position";
            do action maintainPosition : MaintainAbductionPosition;
            do action continuousMonitoring : MonitorContactPressure;
        }
        
        transition maintaining_to_adjusting
            first maintaining
            if maintainPosition.correctionRequired == true
            then adjusting;
        
        state adjusting {
            entry assign systemStatus = "Adjusting strap tension";
            do action correctTension : AdjustStrapTension;
        }
        
        transition adjusting_to_maintaining
            first adjusting
            if correctTension.adjustmentNeeded == false
            then maintaining;
        
        transition maintaining_to_removing
            first maintaining
            accept RemovalCommand
            then removing;
        
        state removing {
            entry assign systemStatus = "Removing wedge";
        }
        
        transition removing_to_idle
            first removing
            then idle;
        
        attribute systemStatus : String;
    }
    
    action def PerformHipAbductionTherapy {
        in medialLegPatient : PatientLeg;
        in lateralLegPatient : PatientLeg;
        in wedgeDevice : AbductorWedge;
        in therapyDuration :> ISQ::TimeValue;
        out finalAbductionAngle :> ISQ::PlaneAngleValue;
        out therapySuccessful : Boolean;
        
        first start;
        then merge beginTherapy;
        
        then action assessPatientLegs {
            in medialLeg = medialLegPatient;
            in lateralLeg = lateralLegPatient;
            out medialCurrentAngle := medialLeg.currentAbductionAngle;
            out lateralCurrentAngle := lateralLeg.currentAbductionAngle;
            out combinedMass := medialLeg.mass + lateralLeg.mass;
        }
        
        then action selectWedgeConfiguration {
            in requiredAngle = wedgeDevice.targetAbductionAngle;
            out selectedWedge := wedgeDevice;
            out configuredAngle := selectedWedge.core.wedgeAngle;
        }
        
        then action positionWedgeAction : PositionWedge {
            in targetAngle = wedgeDevice.targetAbductionAngle;
            in medialLeg = medialLegPatient;
            in lateralLeg = lateralLegPatient;
            out placementDepth;
            out achievedAngle;
        }
        
        then decide;
            if positionWedgeAction.achievedAngle >= wedgeDevice.targetAbductionAngle * 0.88 then applyTherapy;
            if positionWedgeAction.achievedAngle < wedgeDevice.targetAbductionAngle * 0.88 then repositionWedge;
        
        action repositionWedge : PositionWedge {
            in targetAngle = wedgeDevice.targetAbductionAngle;
            in medialLeg = medialLegPatient;
            in lateralLeg = lateralLegPatient;
        }
        then beginTherapy;
        
        action applyTherapy : ApplyAbductionForce {
            in wedgeAngle = selectWedgeConfiguration.configuredAngle;
            in legMass = assessPatientLegs.combinedMass;
            in insertionDepth = positionWedgeAction.placementDepth;
            out resultingAngle;
            out medialForce;
            out lateralForce;
        }
        
        then action monitorMedialPressure : MonitorContactPressure {
            in contactArea = wedgeDevice.core.baseWidth * wedgeDevice.core.depth / 2.0;
            in appliedForce = applyTherapy.medialForce;
            out measuredPressure;
        }
        
        then action monitorLateralPressure : MonitorContactPressure {
            in contactArea = wedgeDevice.core.baseWidth * wedgeDevice.core.depth / 2.0;
            in appliedForce = applyTherapy.lateralForce;
            out measuredPressure;
        }
        
        then decide;
            if monitorMedialPressure.measuredPressure > wedgeDevice.maxContactPressure or 
               monitorLateralPressure.measuredPressure > wedgeDevice.maxContactPressure 
            then adjustPressure;
            if monitorMedialPressure.measuredPressure <= wedgeDevice.maxContactPressure and 
               monitorLateralPressure.measuredPressure <= wedgeDevice.maxContactPressure 
            then securePosition;
        
        action adjustPressure {
            in excessiveMedialPressure = monitorMedialPressure.measuredPressure;
            in excessiveLateralPressure = monitorLateralPressure.measuredPressure;
            out adjustmentRequired : Boolean := true;
        }
        then beginTherapy;
        
        action securePosition : AdjustStrapTension {
            in currentPressure = monitorMedialPressure.measuredPressure;
            in maxPressure = wedgeDevice.maxContactPressure;
            in strap = wedgeDevice.medialStrap;
            out newTension;
            out adjustmentNeeded;
        }
        
        then action maintainTherapy : MaintainAbductionPosition {
            in targetAngle = wedgeDevice.targetAbductionAngle;
            in currentAngle = applyTherapy.resultingAngle;
            in stabilityThreshold = 0.92;
            out positionStable;
            out correctionRequired;
        }
        
        then decide;
            if maintainTherapy.correctionRequired == true then beginTherapy;
            if maintainTherapy.correctionRequired == false and maintainTherapy.positionStable == true then completeTherapy;
        
        action completeTherapy {
            out finalAngle := applyTherapy.resultingAngle;
            out success := (finalAngle >= wedgeDevice.targetAbductionAngle * 0.88);
        }
        
        then assign finalAbductionAngle := completeTherapy.finalAngle;
        then assign therapySuccessful := completeTherapy.success;
        then done;
    }
    
    part abductorWedgeSystem {
        part wedge : AbductorWedge {
            attribute :>> targetAbductionAngle = 25.0;
            attribute :>> targetSeparation = 0.18;
            attribute :>> maxContactPressure = 45000.0;
            attribute :>> totalMass = 0.6;
        }
        
        part medialLeg : PatientLeg {
            attribute :>> mass = 8.5;
            attribute :>> currentAbductionAngle = 5.0;
        }
        
        part lateralLeg : PatientLeg {
            attribute :>> mass = 8.5;
            attribute :>> currentAbductionAngle = 5.0;
        }
        
        connection medialLegContact : LegContactPort
            connect wedge.medialLegInterface to medialLeg;
        
        connection lateralLegContact : LegContactPort
            connect wedge.lateralLegInterface to lateralLeg;
        
        perform action hipAbductionTherapy : PerformHipAbductionTherapy {
            in medialLegPatient = medialLeg;
            in lateralLegPatient = lateralLeg;
            in wedgeDevice = wedge;
            in therapyDuration = 7200.0;
        }
        
        exhibit state operationalStates : WedgeOperationalStates;
    }
    
    requirement <'AWR-001'> primaryFunctionRequirement {
        doc /* The abductor wedge system shall position and maintain a patient's legs 
                at a specified abduction angle to prevent hip dislocation following 
                total hip arthroplasty or other orthopedic procedures requiring 
                controlled leg separation. */
        
        subject abductorWedgeSystem;
        
        require constraint abductionAngleAccuracy {
            doc /* The achieved abduction angle shall be within 12% of the target angle. */
            abductorWedgeSystem.hipAbductionTherapy.finalAbductionAngle >= 
                abductorWedgeSystem.wedge.targetAbductionAngle * 0.88
        }
    }
    
    requirement <'AWR-002'> pressureSafetyRequirement {
        doc /* The contact pressure applied to the patient's legs shall not exceed 
                safe tissue pressure limits to prevent pressure ulcers and tissue damage. */
        
        subject abductorWedgeSystem;
        
        require constraint maximumPressureLimit {
            doc /* Contact pressure shall not exceed 45 kPa at any leg interface. */
            abductorWedgeSystem.hipAbductionTherapy.monitorMedialPressure.measuredPressure <= 45000.0 and
            abductorWedgeSystem.hipAbductionTherapy.monitorLateralPressure.measuredPressure <= 45000.0
        }
    }
    
    requirement <'AWR-003'> materialSafetyRequirement {
        doc /* All materials in direct contact with the patient shall be hypoallergenic 
                and antimicrobial to minimize infection risk and allergic reactions. */
        
        subject abductorWedgeSystem.wedge;
        
        require constraint hypoallergenicMaterial {
            abductorWedgeSystem.wedge.core.coreMaterial.hypoallergenic == true
        }
        
        require constraint antimicrobialCover {
            abductorWedgeSystem.wedge.cover.coverMaterial.antimicrobial == true
        }
    }
    
    requirement <'AWR-004'> positionStabilityRequirement {
        doc /* The wedge shall maintain stable positioning throughout the therapy period 
                without requiring continuous manual readjustment by clinical staff. */
        
        subject abductorWedgeSystem;
        
        require constraint stabilityMaintenance {
            abductorWedgeSystem.hipAbductionTherapy.maintainTherapy.positionStable == true
        }
    }
    
    requirement <'AWR-005'> adjustabilityRequirement {
        doc /* The securing straps shall be adjustable to accommodate varying patient 
                anatomies and provide appropriate tension without excessive pressure. */
        
        subject abductorWedgeSystem.wedge;
        
        require constraint strapAdjustability {
            abductorWedgeSystem.wedge.medialStrap.adjustable == true and
            abductorWedgeSystem.wedge.lateralStrap.adjustable == true
        }
    }
}
