package LeftAtrialAppendageOcclusionSystemModel {
    import ScalarValues::*;
    import SI::*;

    enum def ImplantLifecycleState {
        enum undeployed;
        enum positioned;
        enum expanded;
        enum sealed;
        enum released;
        enum endothelialized;
        enum retrieved;
    }

    enum def ThrombusRiskLevel {
        enum low;
        enum moderate;
        enum high;
    }

    enum def SealQuality {
        enum incomplete;
        enum acceptable;
        enum complete;
    }

    enum def DeploymentCommand {
        enum advance;
        enum retract;
        enum expand;
        enum recapture;
        enum release;
        enum verifySeal;
    }

    attribute def Diameter {
        :>> unit = "mm";
        :>> quantityKind = "length";
    }

    attribute def Length {
        :>> unit = "mm";
        :>> quantityKind = "length";
    }

    attribute def Volume {
        :>> unit = "mL";
        :>> quantityKind = "volume";
    }

    attribute def Pressure {
        :>> unit = "mmHg";
        :>> quantityKind = "pressure";
    }

    attribute def Force {
        :>> unit = "N";
        :>> quantityKind = "force";
    }

    attribute def Area {
        :>> unit = "mm^2";
        :>> quantityKind = "area";
    }

    attribute def Time {
        :>> unit = "s";
        :>> quantityKind = "time";
    }

    attribute def Percent {
        :>> unit = "%";
        :>> quantityKind = "ratio";
    }

    item def OxygenatedBlood {
        attribute pressure : Pressure;
        attribute flowRate {
            :>> unit = "mL/s";
        }
        attribute thrombusBurden : Volume;
    }

    item def Thrombus {
        attribute volume : Volume;
        attribute embolicPotential : ThrombusRiskLevel;
    }

    item def ImagingData {
        attribute ostiumDiameter : Diameter;
        attribute landingZoneDiameter : Diameter;
        attribute appendageDepth : Length;
        attribute residualLeakDiameter : Diameter;
        attribute sealQuality : SealQuality;
    }

    item def DeploymentStatus {
        attribute lifecycleState : ImplantLifecycleState;
        attribute compressionPercent : Percent;
        attribute anchoringForce : Force;
        attribute sealQuality : SealQuality;
        attribute residualLeakDiameter : Diameter;
    }

    item def ClinicianCommand {
        attribute command : DeploymentCommand;
    }

    port def BloodInterfacePort {
        in item atrialBlood : OxygenatedBlood;
        out item excludedThrombus : Thrombus;
    }

    port def TissueContactPort {
        out attribute radialForce : Force;
        in attribute tissueReactionForce : Force;
    }

    port def CatheterMechanicalPort {
        in item command : ClinicianCommand;
        out item status : DeploymentStatus;
        out attribute axialForce : Force;
    }

    port def ImagingPort {
        in item image : ImagingData;
        out item status : DeploymentStatus;
    }

    port def HemodynamicPort {
        in item atrialBlood : OxygenatedBlood;
        out item filteredAtrialBlood : OxygenatedBlood;
    }

    part def LeftAtrium {
        attribute meanPressure : Pressure = 10 [mmHg];
        attribute systolicPressure : Pressure = 15 [mmHg];

        port bloodPort : HemodynamicPort;
        part appendage : LeftAtrialAppendage;
    }

    part def LeftAtrialAppendage {
        attribute ostiumDiameter : Diameter;
        attribute landingZoneDiameter : Diameter;
        attribute depth : Length;
        attribute trabeculatedVolume : Volume;
        attribute thrombusRisk : ThrombusRiskLevel;

        port ostium : BloodInterfacePort;
        port tissueWall : TissueContactPort;
    }

    part def OccluderImplant {
        attribute nominalDiameter : Diameter;
        attribute compressedDiameter : Diameter;
        attribute expandedDiameter : Diameter;
        attribute deviceLength : Length;
        attribute occlusiveSurfaceArea : Area;
        attribute targetCompressionPercent : Percent = 15 [%];
        attribute maximumResidualLeakDiameter : Diameter = 5 [mm];

        port bloodFace : BloodInterfacePort;
        port anchorContact : TissueContactPort;
        port deliveryInterface : CatheterMechanicalPort;
        port imagingInterface : ImagingPort;

        part selfExpandingFrame {
            attribute material = "nitinol";
            attribute expandedDiameter : Diameter;
            attribute radialForce : Force;
            attribute fatigueLifeCycles;
        }

        part occlusiveMembrane {
            attribute material = "ePTFE or polyester";
            attribute poreSize {
                :>> unit = "um";
            }
            attribute coveredArea : Area;
        }

        part fixationAnchors {
            attribute count = 10;
            attribute penetrationDepth : Length;
            attribute totalRetentionForce : Force;
        }

        part proximalHub {
            attribute releaseThreadDiameter : Diameter;
            attribute compatibleWithDeliveryCable = true;
        }

        state def ImplantStateMachine {
            state undeployed;
            state positioned;
            state expanded;
            state sealed;
            state released;
            state endothelialized;
            state retrieved;

            transition first undeployed;
            transition deploy from undeployed to positioned
                accept ClinicianCommand
                if command == DeploymentCommand::advance;

            transition expand from positioned to expanded
                accept ClinicianCommand
                if command == DeploymentCommand::expand;

            transition verifyCompleteSeal from expanded to sealed
                accept ImagingData
                if sealQuality == SealQuality::complete and residualLeakDiameter <= 5 [mm];

            transition recaptureFromPositioned from positioned to retrieved
                accept ClinicianCommand
                if command == DeploymentCommand::recapture;

            transition recaptureFromExpanded from expanded to retrieved
                accept ClinicianCommand
                if command == DeploymentCommand::recapture;

            transition releaseImplant from sealed to released
                accept ClinicianCommand
                if command == DeploymentCommand::release;

            transition healing from released to endothelialized
                after 3888000 [s];
        }

        action def ExpandAgainstAppendageWall {
            in attribute constrainedDiameter : Diameter;
            in attribute landingZoneDiameter : Diameter;
            out attribute compression : Percent;
            out attribute radialForce : Force;
        }

        action def BlockAppendageOrifice {
            in item atrialBlood : OxygenatedBlood;
            in item thrombus : Thrombus;
            out item retainedThrombus : Thrombus;
            out item atrialBloodWithoutAppendageWashout : OxygenatedBlood;
        }

        action def AssessSeal {
            in item image : ImagingData;
            out item status : DeploymentStatus;
        }
    }

    part def DeliveryCatheterSystem {
        attribute outerDiameter {
            :>> unit = "Fr";
        }
        attribute workingLength : Length;
        attribute steerableCurveAngle {
            :>> unit = "deg";
        }

        port implantPort : CatheterMechanicalPort;
        port operatorPort {
            in item command : ClinicianCommand;
            out item status : DeploymentStatus;
        }

        part transseptalSheath {
            attribute innerDiameter {
                :>> unit = "Fr";
            }
            attribute tipDeflectionAngle {
                :>> unit = "deg";
            }
        }

        part deliveryCable {
            attribute tensileStrength : Force;
            attribute releaseTorque {
                :>> unit = "N*mm";
            }
        }

        part loader {
            attribute innerDiameter : Diameter;
            attribute purgeVolume : Volume;
        }

        action def PositionImplantAtOstium {
            in item command : ClinicianCommand;
            in item image : ImagingData;
            out item status : DeploymentStatus;
        }

        action def RecaptureImplant {
            in item command : ClinicianCommand;
            out item status : DeploymentStatus;
        }

        action def ReleaseImplant {
            in item command : ClinicianCommand;
            out item status : DeploymentStatus;
        }
    }

    part def ImagingAndAssessmentSubsystem {
        attribute modality = "TEE or fluoroscopy";
        attribute frameRate {
            :>> unit = "frames/s";
        }
        attribute measurementAccuracy : Diameter = 1 [mm];

        port imagingOutput : ImagingPort;

        action def MeasureAppendageGeometry {
            in item image : ImagingData;
            out attribute ostiumDiameter : Diameter;
            out attribute landingZoneDiameter : Diameter;
            out attribute appendageDepth : Length;
        }

        action def DetectResidualLeak {
            in item image : ImagingData;
            out attribute residualLeakDiameter : Diameter;
            out attribute sealQuality : SealQuality;
        }
    }

    part def ClinicalOperator {
        port commandPort {
            out item command : ClinicianCommand;
            in item status : DeploymentStatus;
        }
    }

    part def LeftAtrialAppendageOcclusionSystem {
        attribute primaryFunction = "Exclude the left atrial appendage from left atrial blood flow to reduce escape of appendage-origin thrombus into systemic circulation.";
        attribute intendedImplantState : ImplantLifecycleState = ImplantLifecycleState::released;
        attribute acceptableSeal : SealQuality = SealQuality::complete;

        part patientLeftAtrium : LeftAtrium {
            attribute meanPressure = 10 [mmHg];
        }

        part implant : OccluderImplant {
            attribute nominalDiameter = 27 [mm];
            attribute compressedDiameter = 4 [mm];
            attribute expandedDiameter = 27 [mm];
            attribute deviceLength = 22 [mm];
            attribute occlusiveSurfaceArea = 572 [mm^2];
        }

        part deliverySystem : DeliveryCatheterSystem {
            attribute outerDiameter = 14 [Fr];
            attribute workingLength = 750 [mm];
            attribute steerableCurveAngle = 180 [deg];
        }

        part imagingSubsystem : ImagingAndAssessmentSubsystem {
            attribute frameRate = 30 [frames/s];
        }

        part clinician : ClinicalOperator;

        connect patientLeftAtrium.appendage.ostium to implant.bloodFace;
        connect patientLeftAtrium.appendage.tissueWall to implant.anchorContact;
        connect deliverySystem.implantPort to implant.deliveryInterface;
        connect imagingSubsystem.imagingOutput to implant.imagingInterface;
        connect clinician.commandPort to deliverySystem.operatorPort;

        action def PerformOcclusionProcedure {
            in item preProcedureImage : ImagingData;
            in item initialCommand : ClinicianCommand;
            out item finalStatus : DeploymentStatus;

            first start;
            then measureAppendage;
            then advanceCatheter;
            then positionImplant;
            then expandImplant;
            then verifySeal;
            then releaseWhenAcceptable;
            then monitorFinalStatus;

            action measureAppendage : ImagingAndAssessmentSubsystem::MeasureAppendageGeometry;
            action advanceCatheter : DeliveryCatheterSystem::PositionImplantAtOstium;
            action positionImplant : DeliveryCatheterSystem::PositionImplantAtOstium;
            action expandImplant : OccluderImplant::ExpandAgainstAppendageWall;
            action verifySeal : OccluderImplant::AssessSeal;
            action releaseWhenAcceptable : DeliveryCatheterSystem::ReleaseImplant;
            action monitorFinalStatus : OccluderImplant::AssessSeal;
        }

        action def MaintainLongTermAppendageExclusion {
            in item atrialBlood : OxygenatedBlood;
            in item appendageThrombus : Thrombus;
            out item retainedThrombus : Thrombus;
            out item systemicBloodProtectedFromAppendageThrombus : OxygenatedBlood;

            action occludeOstium : OccluderImplant::BlockAppendageOrifice;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : LeftAtrialAppendageOcclusionSystem;

        doc /* The system shall occlude the left atrial appendage ostium so that thrombus formed within the appendage is retained and not released into left atrial circulation. */

        require constraint {
            system.implant.maximumResidualLeakDiameter <= 5 [mm]
        }
    }

    requirement def ImplantFitRequirement {
        subject implant : OccluderImplant;
        subject appendage : LeftAtrialAppendage;

        doc /* The implant expanded diameter shall be selected to create stable compression at the appendage landing zone. */

        require constraint {
            implant.expandedDiameter > appendage.landingZoneDiameter
        }

        require constraint {
            implant.targetCompressionPercent >= 8 [%] and implant.targetCompressionPercent <= 20 [%]
        }
    }

    requirement def AnchoringRequirement {
        subject implant : OccluderImplant;

        doc /* The fixation anchors shall provide retention force sufficient to resist left atrial pressure loading and catheter release forces. */

        require constraint {
            implant.fixationAnchors.totalRetentionForce >= 2.0 [N]
        }
    }

    requirement def DeliveryCompatibilityRequirement {
        subject implant : OccluderImplant;
        subject catheter : DeliveryCatheterSystem;

        doc /* The compressed implant shall fit within the delivery catheter and remain retrievable until final release. */

        require constraint {
            implant.compressedDiameter < catheter.transseptalSheath.innerDiameter
        }
    }

    requirement def SealVerificationRequirement {
        subject imaging : ImagingAndAssessmentSubsystem;
        subject implant : OccluderImplant;

        doc /* Imaging assessment shall verify implant position, compression, anchor engagement, and residual leak before release. */

        require constraint {
            imaging.measurementAccuracy <= 1 [mm]
        }

        require constraint {
            implant.maximumResidualLeakDiameter <= 5 [mm]
        }
    }

    requirement def BiocompatibleImplantRequirement {
        subject implant : OccluderImplant;

        doc /* Blood-contacting implant components shall use biocompatible materials suitable for permanent intracardiac placement. */

        require constraint {
            implant.selfExpandingFrame.material == "nitinol"
        }
    }

    requirement def LongTermExclusionRequirement {
        subject system : LeftAtrialAppendageOcclusionSystem;

        doc /* After endothelialization, the implant shall maintain mechanical stability and appendage exclusion during normal left atrial pressure cycles. */

        require constraint {
            system.implant.maximumResidualLeakDiameter <= 5 [mm]
        }
    }

    satisfy PrimaryFunctionRequirement by LeftAtrialAppendageOcclusionSystem::implant;
    satisfy ImplantFitRequirement by LeftAtrialAppendageOcclusionSystem::implant;
    satisfy AnchoringRequirement by LeftAtrialAppendageOcclusionSystem::implant.fixationAnchors;
    satisfy DeliveryCompatibilityRequirement by LeftAtrialAppendageOcclusionSystem::deliverySystem;
    satisfy SealVerificationRequirement by LeftAtrialAppendageOcclusionSystem::imagingSubsystem;
    satisfy BiocompatibleImplantRequirement by LeftAtrialAppendageOcclusionSystem::implant;
    satisfy LongTermExclusionRequirement by LeftAtrialAppendageOcclusionSystem::implant;
}