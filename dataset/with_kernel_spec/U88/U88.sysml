package MitraClipSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import SI::mm;
    private import SI::kg;

    item def Blood;
    item def EchocardiogramImage;

    part def MitralLeaflet {
        attribute name : String;
        attribute thickness : Real;
    }

    part def MitralValve {
        part anteriorLeaflet : MitralLeaflet { :>> name = "anterior"; }
        part posteriorLeaflet : MitralLeaflet { :>> name = "posterior"; }
        attribute regurgitationSeverity : Real;
    }

    part def Heart {
        part mitralValve : MitralValve;
        attribute chamberPressure : Real;
    }

    part def ClipImplant {
        attribute material : String = "cobalt-chromium";
        attribute armLength : Real = 8.0 [mm];
        attribute mass : Real = 0.009 [kg];
        part anteriorArm;
        part posteriorArm;
        port leafletGraspPort;
        attribute isLocked : Boolean = false;
        attribute isReleased : Boolean = false;
    }

    port def ClipCommandPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def ImagePort {
        out item image : EchocardiogramImage;
    }

    part def GuideSheath {
        port proximalPort;
        port distalPort;
        attribute innerDiameter : Real = 24.0 [mm];
        attribute length : Real = 500.0 [mm];
    }

    part def SteerableDeliveryCatheter {
        port proximalPort;
        port distalPort;
        port clipCommandPort : ClipCommandPort;
        attribute length : Real = 900.0 [mm];
        attribute bendAngle : Real = 0.0;
        attribute rotationAngle : Real = 0.0;
        part clip : ClipImplant;
    }

    part def SteeringControl {
        port catheterCommandPort : ~ClipCommandPort;
        port imageInPort : ~ImagePort;
        attribute bendKnobPosition : Real = 0.0;
        attribute rotateKnobPosition : Real = 0.0;
        attribute clipOpenCommand : Boolean = false;
        attribute clipGraspCommand : Boolean = false;
        attribute clipReleaseCommand : Boolean = false;
    }

    part def Echocardiogram {
        port imageOutPort : ImagePort;
        attribute resolution : Real = 0.5 [mm];
    }

    part def Patient {
        part heart : Heart;
        part vasculature;
    }

    part def Physician;

    action def NavigateToValve {
        in part catheter : SteerableDeliveryCatheter;
        in item image : EchocardiogramImage;
        out attribute positioned : Boolean;
    }

    action def AlignClip {
        in part catheter : SteerableDeliveryCatheter;
        in item image : EchocardiogramImage;
        out attribute aligned : Boolean;
    }

    action def DeployClip {
        in part catheter : SteerableDeliveryCatheter;
        in part valve : MitralValve;
        out part deployedClip : ClipImplant;
    }

    action def WithdrawDeliverySystem {
        in part catheter : SteerableDeliveryCatheter;
        in part sheath : GuideSheath;
        out attribute withdrawn : Boolean;
    }

    action def MitraClipProcedure {
        in part patient : Patient;
        in part physician : Physician;
        in part imaging : Echocardiogram;
        out part implantedClip : ClipImplant;

        part guideSheath : GuideSheath;
        part deliveryCatheter : SteerableDeliveryCatheter;
        part steeringControl : SteeringControl;

        action navigate : NavigateToValve {
            in part catheter = deliveryCatheter;
            in item image = imaging.imageOutPort.image;
        }
        then action align : AlignClip {
            in part catheter = deliveryCatheter;
            in item image = imaging.imageOutPort.image;
        }
        then action deploy : DeployClip {
            in part catheter = deliveryCatheter;
            in part valve = patient.heart.mitralValve;
            out part deployedClip = implantedClip;
        }
        then action withdraw : WithdrawDeliverySystem {
            in part catheter = deliveryCatheter;
            in part sheath = guideSheath;
        }
    }

    state def ClipDeploymentStateMachine {
        state retracted;
        state opened;
        state grasped;
        state closedLocked;
        state deployed;

        transition openClip first retracted -> opened {
            trigger accept command : String if command == "open";
        }
        transition graspLeaflets first opened -> grasped {
            trigger accept command : String if command == "grasp";
        }
        transition closeClip first grasped -> closedLocked {
            trigger accept command : String if command == "close";
        }
        transition releaseClip first closedLocked -> deployed {
            trigger accept command : String if command == "release";
        }
    }

    part def MitraClipSystem {
        part guideSheath : GuideSheath;
        part deliveryCatheter : SteerableDeliveryCatheter;
        part steeringControl : SteeringControl;
        part echocardiogram : Echocardiogram;
        part clipImplant : ClipImplant;

        connection sheathToCatheter connect guideSheath.distalPort to deliveryCatheter.proximalPort;
        connection controlToCatheter connect steeringControl.catheterCommandPort to deliveryCatheter.clipCommandPort;
        connection imagingToControl connect echocardiogram.imageOutPort to steeringControl.imageInPort;

        state clipDeployment : ClipDeploymentStateMachine;
    }

    requirement def MitraClipFunctionalRequirement {
        subject clipImplant : ClipImplant;
        requirement ClipGraspsLeaflets {
            doc "The clip implant shall grasp both anterior and posterior mitral valve leaflets to reduce regurgitation.";
        }
        requirement ClipBiocompatible {
            doc "The clip implant shall be made of biocompatible cobalt-chromium alloy suitable for permanent implantation.";
        }
    }

    requirement def DeliverySystemRequirement {
        subject deliveryCatheter : SteerableDeliveryCatheter;
        requirement CatheterNavigability {
            doc "The steerable delivery catheter shall be navigable from the femoral vein to the mitral valve under echocardiographic guidance.";
        }
        requirement SteeringControlResponse {
            doc "The steering control handle shall provide independent bending and rotation control of the catheter tip.";
        }
        requirement ClipDeploymentSequence {
            doc "The system shall deploy the clip through the sequence: retracted, opened, grasped, closedLocked, deployed.";
        }
    }

    requirement def ImagingRequirement {
        subject echocardiogram : Echocardiogram;
        requirement RealTimeImaging {
            doc "The system shall provide real-time echocardiographic imaging during navigation and deployment.";
        }
    }

    requirement def ProcedureOutcomeRequirement {
        subject patient : Patient;
        requirement ReduceRegurgitation {
            doc "The procedure shall reduce mitral regurgitation severity as confirmed by echocardiography.";
        }
        requirement MinimallyInvasive {
            doc "The procedure shall be performed without open-heart surgery.";
        }
    }

    package SystemContext {
        part thePatient : Patient;
        part thePhysician : Physician;
        part theSystem : MitraClipSystem;
        part theImaging : Echocardiogram;

        perform action procedure : MitraClipProcedure {
            in part patient = thePatient;
            in part physician = thePhysician;
            in part imaging = theImaging;
            out part implantedClip;
        }

        requirement mitraClipFunctionalReq : MitraClipFunctionalRequirement;
        requirement deliverySystemReq : DeliverySystemRequirement;
        requirement imagingReq : ImagingRequirement;
        requirement procedureOutcomeReq : ProcedureOutcomeRequirement;

        satisfy mitraClipFunctionalReq by theSystem.clipImplant;
        satisfy deliverySystemReq by theSystem.deliveryCatheter;
        satisfy imagingReq by theSystem.echocardiogram;
        satisfy procedureOutcomeReq by thePatient;
    }
}
