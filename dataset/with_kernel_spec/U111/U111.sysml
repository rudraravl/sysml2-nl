package ReviventTranscatheterVentricularEnhancementSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ScalarValues::String;

    package Definitions {
        item def XRayImage;
        item def TensionSignal;
        item def DeployCommand;
        item def LockCommand;

        port def ImagingOutputPort {
            out item image : XRayImage;
        }
        port def ImagingInputPort {
            in item image : XRayImage;
        }
        port def TensionCommandPort {
            out item command : TensionSignal;
        }
        port def TensionReceivePort {
            in item command : TensionSignal;
        }
        port def DeployCommandPort {
            out item command : DeployCommand;
        }
        port def LockCommandPort {
            out item command : LockCommand;
        }

        part def MicroAnchor {
            attribute anchorId : Integer;
            attribute isEmbedded : Boolean = false;
            attribute isLocked : Boolean = false;
        }

        part def MicroAnchorPair {
            part anchor1 : MicroAnchor;
            part anchor2 : MicroAnchor;
            attribute pairId : Integer;
            attribute tensionApplied : Real;
        }

        part def MicroAnchorArray {
            part pairs : MicroAnchorPair [*];
            attribute totalPairs : Integer;
        }

        part def TensioningMechanism {
            attribute maxTension : Real;
            port tensionInput : TensionReceivePort;
            port tensionOutput : TensionCommandPort;
        }

        part def CatheterHandle {
            port tensionControl : TensionCommandPort;
            port deployControl : DeployCommandPort;
            port lockControl : LockCommandPort;
        }

        part def CatheterTube {
            attribute outerDiameter : Real;
            attribute totalLength : Real;
        }

        part def DeliveryCatheter {
            attribute catheterLength : Real;
            part handle : CatheterHandle;
            part tensioningMechanism : TensioningMechanism;
            part tube : CatheterTube;
            part anchorArray : MicroAnchorArray;
            connect handle.tensionControl to tensioningMechanism.tensionInput;
        }

        part def XRaySource {
            attribute power : Real;
        }

        part def XRayDetector {
            port imageOut : ImagingOutputPort;
        }

        part def DisplayUnit {
            port imageIn : ImagingInputPort;
            port imageOut : ImagingOutputPort;
        }

        part def FluoroscopyGuidanceSystem {
            part xraySource : XRaySource;
            part detector : XRayDetector;
            part display : DisplayUnit;
            port imagingOutput : ImagingOutputPort;
            connect detector.imageOut to display.imageIn;
            connect display.imageOut to imagingOutput;
        }

        part def Physician {
            port imageIn : ImagingInputPort;
            port tensionOut : TensionCommandPort;
            port deployOut : DeployCommandPort;
            port lockOut : LockCommandPort;
        }

        part def ScarTissue {
            attribute location : Real;
            attribute isNonFunctional : Boolean = true;
        }

        part def HealthyTissue {
            attribute contractility : Real;
        }

        part def HeartWall {
            part scarTissue : ScarTissue;
            part healthyTissue : HealthyTissue;
            attribute wallThickness : Real;
        }

        part def LeftVentricle {
            attribute endDiastolicVolume : Real;
            attribute endSystolicVolume : Real;
            attribute ejectionFraction : Real;
            attribute targetVolume : Real;
        }

        part def Heart {
            part leftVentricle : LeftVentricle;
            part heartWall : HeartWall;
        }

        part def Patient {
            attribute patientId : Integer;
            part heart : Heart;
            attribute baselineEjectionFraction : Real;
            attribute targetEjectionFraction : Real;
        }

        action def NavigateCatheterToTarget {
            in targetLocation : Real;
            in fluoroscopyImage : XRayImage;
            out catheterPosition : Real;
        }

        action def DeployAnchorPairAction {
            in scarLocation : Real;
            in anchorPair : MicroAnchorPair;
            out deployedPair : MicroAnchorPair;
        }

        action def ApplyTensionAction {
            in deployedPair : MicroAnchorPair;
            in tensionLevel : Real;
            out cinchedPair : MicroAnchorPair;
        }

        action def VerifyResultAction {
            in image : XRayImage;
            in ventricleVolume : Real;
            in ejectionFractionMeasured : Real;
            out verified : Boolean;
        }

        action def LockAnchorsAction {
            in anchorPair : MicroAnchorPair;
            out lockedPair : MicroAnchorPair;
        }

        action def WithdrawCatheterAction {
            out withdrawn : Boolean;
        }

        state machine def ProcedureStateMachine {
            state idle;
            state navigating;
            state deploying;
            state tensioning;
            state verifying;
            state locking;
            state withdrawing;
            state complete;

            transition idle -> navigating;
            transition navigating -> deploying;
            transition deploying -> tensioning;
            transition tensioning -> verifying;
            transition verifying -> locking;
            transition verifying -> deploying;
            transition locking -> withdrawing;
            transition withdrawing -> complete;
        }
    }

    package Requirements {
        requirement def SystemLevelRequirement {
            doc /* The Revivent system shall treat heart failure by reshaping the patient's damaged left ventricle. */
        }
        requirement def MinimallyInvasiveProcedureRequirement {
            doc /* The entire procedure shall be performed without open-heart surgery. */
        }
        requirement def CatheterNavigationRequirement {
            doc /* The delivery catheter shall be navigable from the femoral access site to the left ventricle under real-time fluoroscopy. */
            attribute maxNavigationTime : Real;
        }
        requirement def AnchorDeploymentRequirement {
            doc /* Micro-anchors shall be deployed in pairs on either side of scarred heart tissue. */
            attribute minPairs : Integer;
        }
        requirement def TensioningRequirement {
            doc /* The tensioning mechanism shall cinch each anchor pair to fold non-functional scar tissue inward. */
            attribute maxTension : Real;
        }
        requirement def VolumeReductionRequirement {
            doc /* The system shall reduce left ventricular end-diastolic volume and improve ejection fraction. */
            attribute targetEjectionFraction : Real;
        }
        requirement def LockingRequirement {
            doc /* All anchors shall be permanently locked in place after verification of the reshaping result. */
        }
        requirement def SafetyRequirement {
            doc /* The system shall not damage healthy heart tissue during catheter navigation, anchor deployment, or tensioning. */
        }
        requirement def VerificationRequirement {
            doc /* Each tensioning step shall be verified using fluoroscopy before proceeding. */
        }
    }

    package Usages {
        part reviventSystem {
            part deliveryCatheter : Definitions::DeliveryCatheter;
            part fluoroscopySystem : Definitions::FluoroscopyGuidanceSystem;
            part physician : Definitions::Physician;
        }

        part patient1 : Definitions::Patient {
            attribute :>> patientId : Integer = 1;
            attribute :>> baselineEjectionFraction : Real = 30;
            attribute :>> targetEjectionFraction : Real = 45;
            part :>> heart {
                part :>> leftVentricle {
                    attribute :>> endDiastolicVolume : Real = 220;
                    attribute :>> endSystolicVolume : Real = 160;
                    attribute :>> targetVolume : Real = 160;
                }
                part :>> heartWall {
                    part :>> scarTissue {
                        attribute :>> location : Real = 45;
                        attribute :>> isNonFunctional : Boolean = true;
                    }
                    part :>> healthyTissue {
                        attribute :>> contractility : Real = 0.85;
                    }
                }
            }
        }

        part procedureContext {
            ref system : reviventSystem;
            ref patient : patient1;

            connect system.fluoroscopySystem.imagingOutput to system.physician.imageIn;
            connect system.physician.tensionOut to system.deliveryCatheter.handle.tensionControl;
            connect system.physician.deployOut to system.deliveryCatheter.handle.deployControl;
            connect system.physician.lockOut to system.deliveryCatheter.handle.lockControl;

            satisfy requirement sysReq : Requirements::SystemLevelRequirement by system;
            satisfy requirement minInvReq : Requirements::MinimallyInvasiveProcedureRequirement by system;
            satisfy requirement navReq : Requirements::CatheterNavigationRequirement by system.deliveryCatheter;
            satisfy requirement anchorReq : Requirements::AnchorDeploymentRequirement by system.deliveryCatheter.anchorArray;
            satisfy requirement tensionReq : Requirements::TensioningRequirement by system.deliveryCatheter.tensioningMechanism;
            satisfy requirement volReq : Requirements::VolumeReductionRequirement by patient.heart.leftVentricle;
            satisfy requirement lockReq : Requirements::LockingRequirement by system.deliveryCatheter.anchorArray;
            satisfy requirement safetyReq : Requirements::SafetyRequirement by patient.heart.heartWall.healthyTissue;
            satisfy requirement verifyReq : Requirements::VerificationRequirement by system.fluoroscopySystem;

            perform procedure : Definitions::ProcedureStateMachine;
        }
    }
}
