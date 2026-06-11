package PatientGownSystemModel {

    enum def GownSizeKind {
        enum pediatric;
        enum small;
        enum medium;
        enum large;
        enum bariatric;
    }

    enum def ClosureStateKind {
        enum open;
        enum partiallySecured;
        enum secured;
        enum released;
    }

    enum def GarmentUseStateKind {
        enum sterilePackaged;
        enum available;
        enum beingDonned;
        enum wornForCare;
        enum accessOpened;
        enum doffed;
        enum soiled;
        enum laundered;
        enum retired;
    }

    value def LengthValue {
        attribute magnitude : Real;
        attribute unit : String = "cm";
    }

    value def AreaValue {
        attribute magnitude : Real;
        attribute unit : String = "cm^2";
    }

    value def MassValue {
        attribute magnitude : Real;
        attribute unit : String = "g";
    }

    value def TemperatureValue {
        attribute magnitude : Real;
        attribute unit : String = "degC";
    }

    value def ForceValue {
        attribute magnitude : Real;
        attribute unit : String = "N";
    }

    value def PercentageValue {
        attribute magnitude : Real;
        attribute unit : String = "%";
    }

    item def PatientBodyContact {
        attribute skinAreaCovered : AreaValue;
        attribute contactPressure : ForceValue;
        attribute patientSkinTemperature : TemperatureValue;
    }

    item def ClinicalAccess {
        attribute requestedArea : String;
        attribute accessWidth : LengthValue;
        attribute accessDurationSeconds : Real;
    }

    item def ModestyCoverage {
        attribute torsoCoverage : PercentageValue;
        attribute hipCoverage : PercentageValue;
        attribute backCoverage : PercentageValue;
    }

    item def ContaminantLoad {
        attribute biologicalSoilMass : MassValue;
        attribute moisturePercent : PercentageValue;
    }

    item def LaunderingCycle {
        attribute washTemperature : TemperatureValue;
        attribute durationMinutes : Real;
        attribute disinfectantCompatible : Boolean;
    }

    port def BodyContactPort {
        in item bodyContact : PatientBodyContact;
        out item coverage : ModestyCoverage;
    }

    port def AccessPort {
        in item request : ClinicalAccess;
        out item providedAccess : ClinicalAccess;
    }

    port def ClosurePort {
        in item closureForce : ForceValue;
        out item closureState : ClosureStateKind;
    }

    port def ContaminationPort {
        in item contaminant : ContaminantLoad;
        out item launderingNeed : LaunderingCycle;
    }

    part def FabricPanel {
        attribute fabricName : String;
        attribute massPerArea : Real;
        attribute breathable : Boolean;
        attribute opaqueWhenDry : Boolean;
        attribute opaqueWhenWet : Boolean;
        attribute antimicrobialFinish : Boolean;
        attribute panelArea : AreaValue;
        port skinSide : BodyContactPort;
        port outside : ContaminationPort;
    }

    part def TieClosure {
        attribute tieLength : LengthValue;
        attribute maximumTieForce : ForceValue;
        attribute state : ClosureStateKind;
        port closureInterface : ClosurePort;
    }

    part def SnapClosure {
        attribute snapCount : Integer;
        attribute releaseForce : ForceValue;
        attribute state : ClosureStateKind;
        port closureInterface : ClosurePort;
    }

    part def NeckOpening {
        attribute circumference : LengthValue;
        attribute minimumClearance : LengthValue;
        port bodyInterface : BodyContactPort;
    }

    part def Sleeve {
        attribute sleeveLength : LengthValue;
        attribute cuffCircumference : LengthValue;
        port armContact : BodyContactPort;
        port clinicalAccess : AccessPort;
    }

    part def BackOpening {
        attribute overlapWidth : LengthValue;
        attribute accessHeight : LengthValue;
        port accessInterface : AccessPort;
        port closureInterface : ClosurePort;
    }

    part def Patient {
        attribute patientIdentifier : String;
        attribute requiresModestySupport : Boolean;
        attribute requiresRapidClinicalAccess : Boolean;
        port torso : BodyContactPort;
        port leftArm : BodyContactPort;
        port rightArm : BodyContactPort;
        port careAccess : AccessPort;
    }

    part def Caregiver {
        attribute role : String;
        port gownAccessRequest : AccessPort;
        port closureOperation : ClosurePort;
    }

    part def LaundryService {
        attribute serviceName : String;
        port soiledGownIntake : ContaminationPort;
    }

    action def DonPatientGown {
        in patient : Patient;
        in gown : PatientGown;
        out gownState : GarmentUseStateKind;

        first start;
        then orientGown;
        then placeArmsThroughSleeves;
        then positionFrontPanelOverTorso;
        then secureNeckClosure;
        then secureWaistClosure;
        then verifyCoverage;
        then done;

        action orientGown;
        action placeArmsThroughSleeves;
        action positionFrontPanelOverTorso;
        action secureNeckClosure;
        action secureWaistClosure;
        action verifyCoverage;
    }

    action def ProvideClinicalAccess {
        in gown : PatientGown;
        in accessRequest : ClinicalAccess;
        out accessProvided : ClinicalAccess;
        out gownState : GarmentUseStateKind;

        first start;
        then releaseSelectedClosure;
        then exposeRequestedCareArea;
        then maintainRemainingCoverage;
        then completeAccess;

        action releaseSelectedClosure;
        action exposeRequestedCareArea;
        action maintainRemainingCoverage;
    }

    action def DoffPatientGown {
        in patient : Patient;
        in gown : PatientGown;
        out contaminantLoad : ContaminantLoad;
        out gownState : GarmentUseStateKind;

        first start;
        then releaseClosures;
        then removeFromArmsAndTorso;
        then containSoiledFabric;
        then routeToLaundry;
        then done;

        action releaseClosures;
        action removeFromArmsAndTorso;
        action containSoiledFabric;
        action routeToLaundry;
    }

    state def PatientGownLifecycle {
        state sterilePackaged;
        state available;
        state beingDonned;
        state wornForCare;
        state accessOpened;
        state doffed;
        state soiled;
        state laundered;
        state retired;

        transition initial then sterilePackaged;
        transition sterilePackaged then available;
        transition available then beingDonned accept DonPatientGown;
        transition beingDonned then wornForCare;
        transition wornForCare then accessOpened accept ProvideClinicalAccess;
        transition accessOpened then wornForCare;
        transition wornForCare then doffed accept DoffPatientGown;
        transition doffed then soiled;
        transition soiled then laundered accept LaunderingCycle;
        transition laundered then available;
        transition soiled then retired;
        transition laundered then retired;
    }

    part def PatientGown {
        attribute size : GownSizeKind = GownSizeKind::medium;
        attribute useState : GarmentUseStateKind = GarmentUseStateKind::available;
        attribute garmentMass : MassValue;
        attribute totalFabricArea : AreaValue;
        attribute minimumTorsoCoverage : PercentageValue;
        attribute minimumHipCoverage : PercentageValue;
        attribute maximumBackOpeningOverlapLoss : LengthValue;
        attribute washableMaximumTemperature : TemperatureValue;
        attribute reusable : Boolean = true;

        part frontPanel : FabricPanel {
            attribute fabricName = "woven cotton polyester blend";
            attribute breathable = true;
            attribute opaqueWhenDry = true;
            attribute opaqueWhenWet = true;
            attribute antimicrobialFinish = false;
        }

        part leftBackPanel : FabricPanel {
            attribute fabricName = "woven cotton polyester blend";
            attribute breathable = true;
            attribute opaqueWhenDry = true;
            attribute opaqueWhenWet = true;
        }

        part rightBackPanel : FabricPanel {
            attribute fabricName = "woven cotton polyester blend";
            attribute breathable = true;
            attribute opaqueWhenDry = true;
            attribute opaqueWhenWet = true;
        }

        part leftSleeve : Sleeve;
        part rightSleeve : Sleeve;
        part neckOpening : NeckOpening;
        part backOpening : BackOpening;
        part neckTie : TieClosure;
        part waistTie : TieClosure;
        part shoulderSnap : SnapClosure;

        port patientTorsoInterface : BodyContactPort;
        port patientLeftArmInterface : BodyContactPort;
        port patientRightArmInterface : BodyContactPort;
        port caregiverAccessInterface : AccessPort;
        port caregiverClosureInterface : ClosurePort;
        port laundryInterface : ContaminationPort;

        connection torsoCoverageLink connect patientTorsoInterface to frontPanel.skinSide;
        connection leftBackCoverageLink connect patientTorsoInterface to leftBackPanel.skinSide;
        connection rightBackCoverageLink connect patientTorsoInterface to rightBackPanel.skinSide;
        connection leftArmLink connect patientLeftArmInterface to leftSleeve.armContact;
        connection rightArmLink connect patientRightArmInterface to rightSleeve.armContact;
        connection neckBodyLink connect patientTorsoInterface to neckOpening.bodyInterface;
        connection backAccessLink connect caregiverAccessInterface to backOpening.accessInterface;
        connection leftSleeveAccessLink connect caregiverAccessInterface to leftSleeve.clinicalAccess;
        connection rightSleeveAccessLink connect caregiverAccessInterface to rightSleeve.clinicalAccess;
        connection neckClosureLink connect caregiverClosureInterface to neckTie.closureInterface;
        connection waistClosureLink connect caregiverClosureInterface to waistTie.closureInterface;
        connection snapClosureLink connect caregiverClosureInterface to shoulderSnap.closureInterface;
        connection soilFrontLink connect laundryInterface to frontPanel.outside;
        connection soilLeftBackLink connect laundryInterface to leftBackPanel.outside;
        connection soilRightBackLink connect laundryInterface to rightBackPanel.outside;

        exhibit stateMachine : PatientGownLifecycle;
        perform action donning : DonPatientGown;
        perform action clinicalAccess : ProvideClinicalAccess;
        perform action doffing : DoffPatientGown;
    }

    part def PatientGownCareSystem {
        part patient : Patient;
        part gown : PatientGown {
            attribute garmentMass = MassValue { magnitude = 420.0; unit = "g"; }
            attribute totalFabricArea = AreaValue { magnitude = 11800.0; unit = "cm^2"; }
            attribute minimumTorsoCoverage = PercentageValue { magnitude = 95.0; unit = "%"; }
            attribute minimumHipCoverage = PercentageValue { magnitude = 90.0; unit = "%"; }
            attribute maximumBackOpeningOverlapLoss = LengthValue { magnitude = 8.0; unit = "cm"; }
            attribute washableMaximumTemperature = TemperatureValue { magnitude = 75.0; unit = "degC"; }
        }
        part caregiver : Caregiver {
            attribute role = "nurse";
        }
        part laundryService : LaundryService {
            attribute serviceName = "hospital textile processing";
        }

        connection patientTorsoToGown connect patient.torso to gown.patientTorsoInterface;
        connection patientLeftArmToGown connect patient.leftArm to gown.patientLeftArmInterface;
        connection patientRightArmToGown connect patient.rightArm to gown.patientRightArmInterface;
        connection caregiverAccessToGown connect caregiver.gownAccessRequest to gown.caregiverAccessInterface;
        connection caregiverClosureToGown connect caregiver.closureOperation to gown.caregiverClosureInterface;
        connection gownToLaundry connect gown.laundryInterface to laundryService.soiledGownIntake;
    }

    requirement def PrimaryFunctionRequirement {
        subject gown : PatientGown;

        require constraint {
            gown.minimumTorsoCoverage.magnitude >= 95.0 and
            gown.minimumHipCoverage.magnitude >= 90.0 and
            gown.reusable == true
        }

        doc
        /*
         The patient gown shall provide wearable body coverage for a patient during healthcare activities while allowing caregivers to rapidly open selected regions for examination, treatment, monitoring, or transfer without fully removing the garment.
        */
    }

    requirement def ModestyRequirement {
        subject gown : PatientGown;

        require constraint {
            gown.minimumTorsoCoverage.magnitude >= 95.0 and
            gown.minimumHipCoverage.magnitude >= 90.0
        }

        doc
        /*
         The gown shall preserve patient modesty by covering the torso and hips during normal worn-for-care use.
        */
    }

    requirement def ClinicalAccessRequirement {
        subject gown : PatientGown;

        require constraint {
            gown.maximumBackOpeningOverlapLoss.magnitude <= 8.0
        }

        doc
        /*
         The gown shall permit caregiver access through back, shoulder, and sleeve openings while maintaining coverage over areas not being treated.
        */
    }

    requirement def LaunderingRequirement {
        subject gown : PatientGown;

        require constraint {
            gown.washableMaximumTemperature.magnitude >= 75.0 and
            gown.reusable == true
        }

        doc
        /*
         The gown shall tolerate repeated hospital laundering and thermal disinfection cycles.
        */
    }

    requirement def ClosureUsabilityRequirement {
        subject gown : PatientGown;

        require constraint {
            gown.neckTie.maximumTieForce.magnitude <= 25.0 and
            gown.waistTie.maximumTieForce.magnitude <= 25.0
        }

        doc
        /*
         Closure elements shall be operable by a caregiver without excessive force and shall release intentionally during doffing or clinical access.
        */
    }

    satisfy PrimaryFunctionRequirement by PatientGownCareSystem::gown;
    satisfy ModestyRequirement by PatientGownCareSystem::gown;
    satisfy ClinicalAccessRequirement by PatientGownCareSystem::gown;
    satisfy LaunderingRequirement by PatientGownCareSystem::gown;
    satisfy ClosureUsabilityRequirement by PatientGownCareSystem::gown;
}