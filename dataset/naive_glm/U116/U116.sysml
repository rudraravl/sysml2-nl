package DentalSinusAugmentationSystem {
    import ISQ::Quantities::*;
    import ISQ::MeasurementUnits::*;
    
    // ============================
    // Value Types with Units
    // ============================
    value type Length :> Real { unit mm; }
    value type Diameter :> Real { unit mm; }
    value type Mass :> Real { unit mg; }
    value type Force :> Real { unit N; }
    value type Torque :> Real { unit N*m; }
    value type Duration :> Real { unit month; }
    value type Angle :> Real { unit deg; }
    value type Volume :> Real { unit mm^3; }
    value type Density :> Real { unit mg/mm^3; }
    value type Percent :> Real { unit %; }
    value type Temperature :> Real { unit degC; }
    
    attribute def ImplantLength : Length;
    attribute def ImplantDiameter : Diameter;
    attribute def InsertionTorqueValue : Torque;
    attribute def ISQScore : Percent;
    attribute def GraftVolumeValue : Volume;
    attribute def GraftMassValue : Mass;
    attribute def ResidualBoneHeight : Length;
    attribute def ResidualBoneWidth : Length;
    attribute def BoneDensityValue : Density;
    attribute def MembraneThickness : Length;
    attribute def ElevationHeight : Length;
    attribute def OsseointegrationDuration : Duration;
    attribute def HealingPeriod : Duration;
    attribute def ImplantAngleValue : Angle;
    attribute def OcclusalForce : Force;
    attribute def BodyTemperature : Temperature;
    
    // ============================
    // Item Definitions
    // ============================
    item def BoneTissue {
        attribute density : BoneDensityValue;
        attribute isVital : Boolean;
        attribute isCortical : Boolean;
    }
    
    item def TitaniumMaterial {
        attribute grade : String = "Grade-4";
        attribute tensileStrength : Force = 550;
        attribute elasticModulus : Force = 110;
    }
    
    item def GraftMaterialType {
        attribute type : String;
        attribute isAutogenous : Boolean;
        attribute isAllograft : Boolean;
        attribute isXenograft : Boolean;
        attribute isAlloplast : Boolean;
        attribute resorptionRate : Percent;
    }
    
    item def BloodSupply {
        attribute isEstablished : Boolean;
    }
    
    item def NewBone :> BoneTissue {
        attribute formationRate : Density;
    }
    
    // ============================
    // Port Definitions
    // ============================
    port def BoneImplantInterface {
        attribute contactArea : Volume;
        attribute osseointegrationLevel : Percent;
        attribute stabilityRatio : ISQScore;
    }
    
    port def GraftBoneInterface {
        attribute integrationLevel : Percent;
        attribute newBoneVolume : Volume;
    }
    
    port def GraftImplantInterface {
        attribute contactSurface : Volume;
    }
    
    port def MembraneInterface {
        attribute isElevated : Boolean;
        attribute elevationDistance : ElevationHeight;
        attribute isIntact : Boolean;
    }
    
    port def CrownInterface {
        attribute abutmentType : String;
        attribute isAttached : Boolean;
        attribute occlusalLoad : OcclusalForce;
    }
    
    // ============================
    // Requirements
    // ============================
    requirement def BiocompatibilityRequirement {
        doc "The implant fixture must be biocompatible with human tissue to prevent rejection.";
        constraint { implantFixture.material.tensileStrength >= 500 }
        constraint { implantFixture.material.grade == "Grade-4" or implantFixture.material.grade == "Grade-5" }
    }
    
    requirement def InitialStabilityRequirement {
        doc "The implant must achieve initial stability upon placement.";
        constraint { insertionTorqueValue >= 35 and insertionTorqueValue <= 50 }
        constraint { stabilityRatio >= 60 }
    }
    
    requirement def OsseointegrationRequirement {
        doc "The implant must fully integrate with bone over several months.";
        constraint { osseointegrationDuration >= 3 and osseointegrationDuration <= 6 }
        constraint { osseointegrationLevel >= 85 }
    }
    
    requirement def MasticatoryFunctionRequirement {
        doc "The system must restore masticatory (chewing) function.";
        constraint { occlusalForce >= 200 }
        constraint { crownInterface.isAttached == true }
        constraint { crownInterface.occlusalLoad >= 200 }
    }
    
    requirement def GraftVolumeRequirement {
        doc "Adequate bone graft material must fill the created space.";
        constraint { graftVolumeValue >= 300 and graftVolumeValue <= 2000 }
    }
    
    requirement def ResidualBoneRequirement {
        doc "Residual bone must be sufficient for initial implant anchoring.";
        constraint { residualBoneHeight >= 3 }
        constraint { residualBoneWidth >= 4 }
    }
    
    requirement def MembraneIntegrityRequirement {
        doc "The sinus membrane must remain intact during elevation.";
        constraint { membraneInterface.isIntact == true }
    }
    
    // ============================
    // Part Definitions - Patient Anatomy
    // ============================
    part def MaxillarySinus {
        doc "Air-filled cavity above the upper teeth.";
        attribute volume : Volume;
        attribute floorThickness : Length;
        attribute lateralWallThickness : Length;
        attribute isAirFilled : Boolean = true;
        port membraneInterface : MembraneInterface;
    }
    
    part def ResidualBone {
        doc "Remaining jawbone beneath the sinus floor.";
        attribute height : ResidualBoneHeight;
        attribute width : ResidualBoneWidth;
        attribute density : BoneDensityValue;
        attribute isCortical : Boolean;
        port implantInterface : BoneImplantInterface;
        port graftInterface : GraftBoneInterface;
    }
    
    part def SinusMembrane {
        doc "Delicate membrane lining the sinus floor.";
        attribute thickness : MembraneThickness;
        attribute isElevated : Boolean;
        attribute isIntact : Boolean = true;
        attribute elevationDistance : ElevationHeight;
        port externalInterface : MembraneInterface;
    }
    
    part def PatientAnatomy {
        doc "Patient's maxillofacial anatomy relevant to sinus augmentation.";
        part maxillarySinus : MaxillarySinus {
            attribute volume = 15000;
            attribute floorThickness = 2.0;
            attribute lateralWallThickness = 1.5;
        }
        part residualBone : ResidualBone {
            attribute height = 4.0;
            attribute width = 6.0;
            attribute density = 1.2;
            attribute isCortical = true;
        }
        part sinusMembrane : SinusMembrane {
            attribute thickness = 0.1;
            attribute isElevated = false;
        }
        
        connection sinusToBone connect maxillarySinus.membraneInterface to residualBone.graftInterface;
        connection membraneToSinus connect sinusMembrane.externalInterface to maxillarySinus.membraneInterface;
    }
    
    // ============================
    // Part Definitions - Medical Devices
    // ============================
    part def ImplantFixture {
        doc "Screw-like titanium post acting as an artificial tooth root.";
        attribute length : ImplantLength;
        attribute diameter : ImplantDiameter;
        attribute threadPitch : Length;
        attribute material : TitaniumMaterial;
        attribute surfaceTreatment : String = "SLA";
        attribute isStable : Boolean;
        attribute osseointegrationComplete : Boolean;
        
        port boneInterface : BoneImplantInterface;
        port graftInterface : GraftImplantInterface;
        port crownPort : CrownInterface;
    }
    
    part def BoneGraft {
        doc "Substance that promotes new bone growth.";
        attribute volume : GraftVolumeValue;
        attribute mass : GraftMassValue;
        attribute materialType : GraftMaterialType;
        attribute isPlaced : Boolean;
        attribute newBoneFormation : Percent;
        
        port implantInterface : GraftImplantInterface;
        port boneInterface : GraftBoneInterface;
    }
    
    part def DentalCrown {
        doc "Artificial tooth restoration attached to the implant.";
        attribute material : String = "Zirconia";
        attribute occlusalLoad : OcclusalForce;
        attribute isAttached : Boolean;
        
        port implantPort : CrownInterface;
    }
    
    // ============================
    // Part Definitions - Surgical Instruments
    // ============================
    part def SinusElevator {
        doc "Instrument for elevating the sinus membrane.";
        attribute type : String;
        attribute curvatureAngle : Angle;
        attribute isSterile : Boolean = true;
    }
    
    part def SurgicalDrill {
        doc "Drill for preparing the implant osteotomy.";
        attribute diameter : Diameter;
        attribute depth : Length;
        attribute speed : Real;
        attribute isSterile : Boolean = true;
    }
    
    part def GraftApplicator {
        doc "Instrument for placing bone graft material.";
        attribute volumeCapacity : Volume;
        attribute isSterile : Boolean = true;
    }
    
    part def ImplantDriver {
        doc "Tool for inserting the implant fixture.";
        attribute maxTorque : Torque;
        attribute isSterile : Boolean = true;
    }
    
    // ============================
    // Main System
    // ============================
    part def SinusAugmentationImplantSystem {
        doc "Dental sinus augmentation and implant system for restoring teeth in the upper jaw.";
        
        part patient : PatientAnatomy;
        part implantFixture : ImplantFixture {
            attribute length = 10.0;
            attribute diameter = 4.0;
            attribute threadPitch = 0.6;
            attribute material = TitaniumMaterial{grade = "Grade-4"; tensileStrength = 550; elasticModulus = 110;};
            attribute surfaceTreatment = "SLA";
            attribute isStable = false;
            attribute osseointegrationComplete = false;
        }
        part boneGraft : BoneGraft {
            attribute volume = 500;
            attribute mass = 600;
            attribute materialType = GraftMaterialType{type = "Allograft"; isAutogenous = false; isAllograft = true; isXenograft = false; isAlloplast = false; resorptionRate = 40;};
            attribute isPlaced = false;
            attribute newBoneFormation = 0;
        }
        part dentalCrown : DentalCrown {
            attribute material = "Zirconia";
            attribute occlusalLoad = 0;
            attribute isAttached = false;
        }
        
        // Surgical instruments
        part elevator : SinusElevator {
            attribute type = "Curette";
            attribute curvatureAngle = 45.0;
        }
        part drill : SurgicalDrill {
            attribute diameter = 4.0;
            attribute depth = 10.0;
            attribute speed = 1500;
        }
        part graftApplicator : GraftApplicator {
            attribute volumeCapacity = 100;
        }
        part implantDriver : ImplantDriver {
            attribute maxTorque = 50;
        }
        
        // Connections
        connection implantToResidualBone connect implantFixture.boneInterface to patient.residualBone.implantInterface;
        connection implantToGraft connect implantFixture.graftInterface to boneGraft.implantInterface;
        connection graftToResidualBone connect boneGraft.boneInterface to patient.residualBone.graftInterface;
        connection crownToImplant connect dentalCrown.implantPort to implantFixture.crownPort;
        
        // Requirements satisfaction
        satisfy BiocompatibilityRequirement by implantFixture;
        satisfy InitialStabilityRequirement by implantFixture;
        satisfy OsseointegrationRequirement by implantFixture;
        satisfy MasticatoryFunctionRequirement by dentalCrown;
        satisfy GraftVolumeRequirement by boneGraft;
        satisfy ResidualBoneRequirement by patient.residualBone;
        satisfy MembraneIntegrityRequirement by patient.sinusMembrane;
    }
    
    // ============================
    // Actions - Surgical Procedure
    // ============================
    action def SinusAugmentationProcedure {
        doc "The overall sinus augmentation surgical procedure.";
        
        // Pre-operative assessment
        action assessPatient {
            out residualBoneHeight : ResidualBoneHeight;
            out residualBoneWidth : ResidualBoneWidth;
            out membraneThickness : MembraneThickness;
            out graftVolumeNeeded : GraftVolumeValue;
        }
        
        // Anesthesia
        action administerAnesthesia {
            in targetArea : PatientAnatomy;
        }
        
        // Surgical access
        action createAccess {
            doc "Create osteotomy window in lateral sinus wall.";
            out accessCreated : Boolean;
        }
        
        // Membrane elevation
        action elevateMembrane {
            doc "Carefully elevate the delicate sinus membrane to create space.";
            in elevator : SinusElevator;
            in membrane : SinusMembrane;
            out elevationHeight : ElevationHeight;
            out membraneIntact : Boolean;
        }
        
        // Graft placement
        action placeGraft {
            doc "Fill the created space with bone graft material.";
            in graftMaterial : BoneGraft;
            in applicator : GraftApplicator;
            in elevationHeight : ElevationHeight;
            out graftPlaced : Boolean;
            out graftVolume : GraftVolumeValue;
        }
        
        // Osteotomy preparation
        action prepareOsteotomy {
            doc "Prepare the implant site in residual bone.";
            in drill : SurgicalDrill;
            in residualBone : ResidualBone;
            out osteotomyDepth : Length;
            out osteotomyDiameter : Diameter;
        }
        
        // Implant insertion
        action insertImplant {
            doc "Insert the implant fixture into residual bone and graft.";
            in implant : ImplantFixture;
            in driver : ImplantDriver;
            out insertionTorque : InsertionTorqueValue;
            out initialStability : ISQScore;
            out implantStable : Boolean;
        }
        
        // Wound closure
        action closeWound {
            doc "Close the surgical site.";
            out siteClosed : Boolean;
        }
        
        // Post-operative care
        action postOpCare {
            doc "Post-operative instructions and follow-up scheduling.";
            out healingPeriod : HealingPeriod;
            out followUpInterval : Duration;
        }
        
        // Control flow
        flow assessPatient.residualBoneHeight to prepareOsteotomy;
        flow assessPatient.membraneThickness to elevateMembrane;
        flow elevateMembrane.elevationHeight to placeGraft;
        flow elevateMembrane.membraneIntact to placeGraft;
        flow placeGraft.graftPlaced to insertImplant;
        flow prepareOsteotomy.osteotomyDepth to insertImplant;
        flow insertImplant.implantStable to closeWound;
        flow closeWound.siteClosed to postOpCare;
    }
    
    action def CrownPlacementProcedure {
        doc "Procedure for placing the dental crown after osseointegration.";
        
        action assessOsseointegration {
            in implant : ImplantFixture;
            out integrationLevel : Percent;
            out isReady : Boolean;
        }
        
        action placeAbutment {
            in implant : ImplantFixture;
            out abutmentType : String;
            out abutmentAttached : Boolean;
        }
        
        action fabricateCrown {
            out crown : DentalCrown;
        }
        
        action cementCrown {
            in crown : DentalCrown;
            in abutmentAttached : Boolean;
            out crownAttached : Boolean;
            out occlusalLoad : OcclusalForce;
        }
        
        flow assessOsseointegration.isReady to placeAbutment;
        flow placeAbutment.abutmentAttached to cementCrown;
    }
    
    // ============================
    // State Machine - Surgical Procedure
    // ============================
    state def SurgicalProcedureStateMachine {
        doc "State machine tracking the surgical procedure phases.";
        
        state PreOperative {
            doc "Pre-operative assessment and planning.";
            entry { /* Patient assessment and imaging */ }
            do { /* CBCT scan, treatment planning */ }
            exit { /* Surgical plan finalized */ }
        }
        
        state SurgicalAccess {
            doc "Creating surgical access to the sinus.";
            entry { /* Incision made */ }
            do { /* Lateral window preparation */ }
            exit { /* Access to sinus achieved */ }
        }
        
        state MembraneElevation {
            doc "Elevating the Schneiderian membrane.";
            entry { /* Membrane dissection begins */ }
            do { /* Careful elevation to create space */ }
            exit { /* Membrane elevated without perforation */ }
        }
        
        state GraftPlacement {
            doc "Placement of bone graft material.";
            entry { /* Graft material prepared */ }
            do { /* Filling the sub-antral space */ }
            exit { /* Graft material fully placed */ }
        }
        
        state ImplantInsertion {
            doc "Inserting the implant fixture.";
            entry { /* Osteotomy verified */ }
            do { /* Implant placed with controlled torque */ }
            exit { /* Implant stable and in position */ }
        }
        
        state WoundClosure {
            doc "Closing the surgical site.";
            entry { /* Suturing begins */ }
            do { /* Soft tissue closure */ }
            exit { /* Site fully closed */ }
        }
        
        state PostOperative {
            doc "Post-operative recovery and monitoring.";
            entry { /* Patient discharged with instructions */ }
            do { /* Regular follow-up and monitoring */ }
            exit { /* Healing confirmed */ }
        }
        
        transition from PreOperative to SurgicalAccess {
            guard { /* Surgical plan approved */ }
        }
        transition from SurgicalAccess to MembraneElevation {
            guard { /* Access window complete */ }
        }
        transition from MembraneElevation to GraftPlacement {
            guard { membraneInterface.isIntact == true }
        }
        transition from GraftPlacement to ImplantInsertion {
            guard { boneGraft.isPlaced == true }
        }
        transition from ImplantInsertion to WoundClosure {
            guard { implantFixture.isStable == true }
        }
        transition from WoundClosure to PostOperative {
            guard { /* Surgical site closed */ }
        }
    }
    
    // ============================
    // State Machine - Osseointegration
    // ============================
    state def OsseointegrationStateMachine {
        doc "Biological process of bone growing into and fusing with the implant surface.";
        
        state PrimaryStability {
            doc "Mechanical stability achieved immediately after insertion.";
            entry { /* Implant placed */ }
            do { /* Healing process begins */ }
            exit { /* Initial blood clot formation */ }
        }
        
        state PrimaryHealing {
            doc "Early healing phase with blood clot formation.";
            entry { /* Inflammatory phase */ }
            do { /* Wound healing and blood supply establishment */ }
            exit { /* Initial callus formation */ }
        }
        
        state BoneGrowthPhase {
            doc "Active bone formation around the implant.";
            entry { /* Osteoblast activity begins */ }
            do { /* New bone tissue formation on implant surface */ }
            exit { /* Progressive bone formation */ }
        }
        
        state SecondaryStability {
            doc "Biological stability from bone integration.";
            entry { /* New bone bridges forming */ }
            do { /* Mineralization of new bone */ }
            exit { /* Bone-to-implant contact established */ }
        }
        
        state FullIntegration {
            doc "Complete osseointegration achieved.";
            entry { /* ISQ > 75 */ }
            do { /* Mature bone remodeling */ }
            exit { /* Ready for prosthetic loading */ }
        }
        
        attribute osseointegrationLevel : Percent = 0;
        attribute stabilityRatio : ISQScore = 60;
        
        transition from PrimaryStability to PrimaryHealing {
            guard { /* Time elapsed: 1-2 weeks */ }
        }
        transition from PrimaryHealing to BoneGrowthPhase {
            guard { /* Time elapsed: 2-4 weeks */ }
        }
        transition from BoneGrowthPhase to SecondaryStability {
            guard { /* Time elapsed: 4-8 weeks */ }
        }
        transition from SecondaryStability to FullIntegration {
            guard { osseointegrationLevel >= 85 and stabilityRatio >= 75 }
        }
    }
    
    // ============================
    // State Machine - Implant Stability
    // ============================
    state def ImplantStabilityStateMachine {
        doc "State machine for implant stability throughout the treatment.";
        
        state Unstable {
            doc "Implant not yet placed.";
            entry { /* Pre-placement state */ }
            do { /* Implant in packaging */ }
        }
        
        state MechanicallyStable {
            doc "Initial mechanical stability from placement.";
            entry { /* Implant inserted */ }
            do { /* Primary stability maintained */ }
        }
        
        state StabilityDip {
            doc "Temporary reduction in stability during healing.";
            entry { /* Bone remodeling begins */ }
            do { /* Risk window */ }
        }
        
        state BiologicallyStable {
            doc "Stability from osseointegration.";
            entry { /* Bone integration progressing */ }
            do { /* Secondary stability developing */ }
        }
        
        state FullyStable {
            doc "Complete stability from full integration.";
            entry { /* Osseointegration complete */ }
            do { /* Ready for loading */ }
        }
        
        transition from Unstable to MechanicallyStable {
            guard { insertionTorque >= 35 }
        }
        transition from MechanicallyStable to StabilityDip {
            guard { /* 1-2 weeks post-op */ }
        }
        transition from StabilityDip to BiologicallyStable {
            guard { /* 3-4 weeks post-op */ }
        }
        transition from BiologicallyStable to FullyStable {
            guard { osseointegrationLevel >= 85 }
        }
    }
    
    // ============================
    // Top-level package configuration
    // ============================
    part def SystemConfiguration {
        part mainSystem : SinusAugmentationImplantSystem;
        
        // Perform surgical procedure
        action performSurgery : SinusAugmentationProcedure {
            in target : mainSystem.patient;
            in implant : mainSystem.implantFixture;
            in graft : mainSystem.boneGraft;
            in instruments : > { 
                mainSystem.elevator, 
                mainSystem.drill, 
                mainSystem.graftApplicator, 
                mainSystem.implantDriver 
            };
        }
        
        // Perform crown placement after osseointegration
        action performCrownPlacement : CrownPlacementProcedure {
            in implant : mainSystem.implantFixture;
            in crown : mainSystem.dentalCrown;
        }
    }
}
