package MitraClipTranscatheterMitralValveRepairSystem {

    import ScalarValues::*;

    package ValueTypes {
        import ScalarValues::*;

        unit mm;
        unit deg;
        unit N;
        unit mmHg;
        unit mg;
        unit s;
        unit L_per_min;
        unit degC;
        unit pct;
        unit mL;
        unit Hz;

        value type LengthValue :> Real {
            unit mm;
        }
        value type DiameterValue :> Real {
            unit mm;
        }
        value type AngleValue :> Real {
            unit deg;
        }
        value type ForceValue :> Real {
            unit N;
        }
        value type PressureValue :> Real {
            unit mmHg;
        }
        value type FlowRateValue :> Real {
            unit L_per_min;
        }
        value type MassValue :> Real {
            unit mg;
        }
        value type DurationValue :> Real {
            unit s;
        }
        value type TemperatureValue :> Real {
            unit degC;
        }
        value type PercentageValue :> Real {
            unit pct;
        }
        value type VolumeValue :> Real {
            unit mL;
        }
        value type FrequencyValue :> Real {
            unit Hz;
        }
    }

    package Items {
        item def CobaltChromiumAlloy;
        item def Blood;
        item def MitralLeafletTissue;
        item def BiocompatiblePolymer;
        item def RadiopaqueMarker;
        item def StainlessSteel;
        item def SutureMaterial;
    }

    package Enums {
        import ScalarValues::*;

        enum def ClipControlCommand {
            OPEN;
            GRASP;
            CLOSE;
            LOCK;
            RELEASE;
        }

        enum def SteeringCommand {
            BEND;
            ROTATE;
            ADVANCE;
            RETRACT;
            NEUTRAL;
        }

        enum def ImagingMode {
            TRANSESOPHAGEAL_ECHO;
            INTRACARDIAC_ECHO;
            FLUOROSCOPY;
        }

        enum def ClipStatus {
            RETRACTED;
            OPENED;
            GRASPING;
            CLOSED_LOCKED;
            DEPLOYED;
        }

        enum def ProcedurePhase {
            PREPARATION;
            VASCULAR_ACCESS;
            NAVIGATION;
            CLIP_DEPLOYMENT;
            ASSESSMENT;
            WITHDRAWAL;
        }
    }

    package Signals {
        signal def CatheterAdvanced;
        signal def AlignmentAchieved;
        signal def OpenCommandIssued;
        signal def GraspCommandIssued;
        signal def CloseCommandIssued;
        signal def ReleaseCommandIssued;
        signal def WithdrawalComplete;
        signal def RegurgitationConfirmed;
    }

    package Requirements {
        requirement def TreatMitralRegurgitation {
            doc /* The system shall enable treatment of mitral regurgitation through minimally invasive transcatheter repair of the mitral valve. */;
        }

        requirement def MinimallyInvasiveProcedure {
            doc /* The procedure shall be performed percutaneously via femoral venous access without open-heart surgery. */;
        }

        requirement def LeafletGraspingRequirement {
            doc /* The clip implant shall grasp both the anterior and posterior leaflets of the mitral valve, pulling them together to create a more effective seal and reduce backward flow of blood. */;
        }

        requirement def NavigationRequirement {
            doc /* The steerable delivery catheter shall be navigable from the femoral vein through the vascular system, across the chambers of the heart, to the mitral valve. */;
        }

        requirement def SteeringControlRequirement {
            doc /* The steering control handle shall provide knobs for bending and rotating the catheter tip, and controls to open, grasp, close, and release the clip. */;
        }

        requirement def ImagingGuidanceRequirement {
            doc /* The procedure shall be performed under live echocardiographic imaging for real-time visualization of cardiac structures and device position. */;
        }

        requirement def ClipDeploymentRequirement {
            doc /* The clip shall deploy through a defined sequence of states: retracted, opened, grasping, closed and locked, and released from the delivery catheter. */;
        }

        requirement def BiocompatibilityRequirement {
            doc /* The clip implant shall be fabricated from cobalt-chromium alloy and shall be biocompatible for permanent implantation in the human body. */;
        }

        requirement def RegurgitationReductionRequirement {
            doc /* The deployed clip shall reduce mitral regurgitation as confirmed by echocardiographic assessment prior to system withdrawal. */;
        }

        requirement def SystemWithdrawalRequirement {
            doc /* After successful clip deployment and confirmation of regurgitation reduction, the delivery system shall be withdrawable from the patient, leaving only the clip implant in place. */;
        }
    }

    package PortDefs {
        import ValueTypes::*;
        import Items::*;
        import Enums::*;

        port def VascularAccessPort {
            in item blood : Blood;
            out item blood : Blood;
        }

        port def SheathLumenPort {
            doc /* Internal lumen port of the guide sheath through which the delivery catheter passes. */;
        }

        port def CatheterOuterPort {
            doc /* Outer surface port of the delivery catheter that interfaces with the sheath lumen. */;
        }

        port def ClipMountPort {
            in actuationForce : ForceValue;
            in actuationAngle : AngleValue;
            out clipStatus : ClipStatus;
        }

        port def ControlInterfacePort {
            out steeringCommand : SteeringCommand;
            out clipControlCommand : ClipControlCommand;
            in catheterFeedback : AngleValue;
        }

        port def ImagingOutputPort {
            out imagingData : String;
            out imagingMode : ImagingMode;
        }

        port def LeafletInterfacePort {
            in item leaflet : MitralLeafletTissue;
            in graspingForce : ForceValue;
        }
    }

    package ConnectionDefs {
        import PortDefs::*;

        connection def CatheterThroughSheathConnection {
            end catheterPort : CatheterOuterPort;
            end sheathPort : SheathLumenPort;
        }

        connection def HandleToCatheterConnection {
            end handlePort : ControlInterfacePort;
            end catheterPort : ControlInterfacePort;
        }

        connection def ClipToCatheterConnection {
            end clipPort : ClipMountPort;
            end catheterPort : ClipMountPort;
        }

        connection def SheathToVeinConnection {
            end sheathPort : VascularAccessPort;
            end veinPort : VascularAccessPort;
        }

        connection def ClipToLeafletConnection {
            end clipPort : LeafletInterfacePort;
            end leafletPort : LeafletInterfacePort;
        }

        connection def ImagingConnection {
            end probePort : ImagingOutputPort;
            end displayPort : ImagingOutputPort;
        }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Enums::*;
        import PortDefs::*;
        import ConnectionDefs::*;
        import Signals::*;

        part def ClipArm {
            doc /* Individual grasping arm of the clip implant, designed to capture a mitral valve leaflet. */;
            attribute armLength : LengthValue = 8;
            attribute armAngle : AngleValue = 0;
            attribute armThickness : LengthValue = 1;
            item armMaterial : CobaltChromiumAlloy;
            item radiopaqueMarker : RadiopaqueMarker;
            port leafletInterface : LeafletInterfacePort;
        }

        part def ClipBody {
            doc /* Central body of the clip implant connecting the arms and the locking mechanism. */;
            item bodyMaterial : CobaltChromiumAlloy;
            attribute bodyWidth : LengthValue = 6;
            attribute bodyLength : LengthValue = 15;
        }

        part def LockingMechanism {
            doc /* Mechanism that secures the clip in its final closed position after leaflet grasping. */;
            attribute isLocked : Boolean = false;
            attribute lockingForce : ForceValue = 2.0;
        }

        part def ClipMountingInterface {
            doc /* Interface by which the clip attaches to the delivery catheter tip for transit and deployment. */;
            port mountPort : ClipMountPort;
        }

        part def ClipImplant {
            doc /* Permanent clip implant made of cobalt-chromium alloy that grasps and approximates the mitral valve leaflets to reduce regurgitation. */;

            attribute totalMass : MassValue = 500;
            attribute clipWidth : LengthValue = 6;
            attribute clipLength : LengthValue = 15;
            item clipMaterial : CobaltChromiumAlloy;
            attribute currentStatus : ClipStatus = ClipStatus::RETRACTED;

            part anteriorArm : ClipArm {
                doc /* Arm designed to grasp the anterior leaflet of the mitral valve. */;
            }
            part posteriorArm : ClipArm {
                doc /* Arm designed to grasp the posterior leaflet of the mitral valve. */;
            }
            part clipBody : ClipBody;
            part lockingMechanism : LockingMechanism;
            part mountingInterface : ClipMountingInterface;

            state deployment {
                doc /* State machine governing the deployment sequence of the clip implant. */;

                state RetractedInCatheter {
                    doc /* Clip is retracted inside the delivery catheter for safe transit to the heart. */;
                    entry /* Clip arms are closed and protected within the catheter tip. */;
                }
                state NavigatingToValve {
                    doc /* Clip is being navigated through the vasculature and heart chambers toward the mitral valve. */;
                    entry /* Catheter is being steered across the interatrial septum. */;
                }
                state AlignedAtValve {
                    doc /* Clip is positioned and aligned at the mitral valve leaflets. */;
                    entry /* Catheter tip is oriented perpendicular to the line of coaptation. */;
                }
                state OpenedForCapture {
                    doc /* Clip arms are opened to prepare for leaflet capture. */;
                    entry /* Both arms are extended to their maximum open position. */;
                }
                state GraspingLeaflets {
                    doc /* Clip arms are grasping the anterior and posterior leaflets. */;
                    entry /* Arms are brought toward the leaflets to capture tissue between the arm and the clip body. */;
                }
                state ClosedAndLocked {
                    doc /* Clip is closed with leaflets captured and the locking mechanism is engaged. */;
                    entry /* Clip is locked in its final configuration with leaflets approximated. */;
                }
                state Deployed {
                    doc /* Clip has been released from the delivery catheter and remains on the mitral valve. */;
                    entry /* Clip is free-standing on the mitral valve. */;
                }
                state SystemWithdrawn {
                    doc /* Delivery system has been withdrawn from the patient body. */;
                    entry /* Only the clip implant remains in the patient. */;
                }

                transition RetractedInCatheter to NavigatingToValve
                    accept CatheterAdvanced;
                transition NavigatingToValve to AlignedAtValve
                    accept AlignmentAchieved;
                transition AlignedAtValve to OpenedForCapture
                    accept OpenCommandIssued;
                transition OpenedForCapture to GraspingLeaflets
                    accept GraspCommandIssued;
                transition GraspingLeaflets to ClosedAndLocked
                    accept CloseCommandIssued;
                transition ClosedAndLocked to Deployed
                    accept ReleaseCommandIssued;
                transition Deployed to SystemWithdrawn
                    accept WithdrawalComplete;
            }
        }

        part def GuideSheath {
            doc /* Sheath inserted into a major vein, usually in the leg, to create a stable pathway into the vascular system. */;

            attribute sheathLength : LengthValue = 90;
            attribute sheathOuterDiameter : DiameterValue = 24;
            attribute sheathInnerDiameter : DiameterValue = 20;
            item sheathMaterial : BiocompatiblePolymer;
            item radiopaqueMarker : RadiopaqueMarker;

            port proximalPort : SheathLumenPort {
                doc /* Proximal end of the sheath lumen accessible from outside the body. */;
            }
            port distalPort : SheathLumenPort {
                doc /* Distal end of the sheath lumen positioned in the vascular system. */;
            }
            port vascularAccess : VascularAccessPort;
        }

        part def CatheterProximalEnd {
            doc /* Proximal end of the delivery catheter connecting to the steering control handle. */;
            port handleInterface : ControlInterfacePort;
        }

        part def CatheterDistalTip {
            doc /* Distal tip of the delivery catheter that holds the clip implant during navigation and deployment. */;
            attribute tipBendAngle : AngleValue = 0;
            attribute tipRotation : AngleValue = 0;
            port clipMount : ClipMountPort;
        }

        part def SteerableSegment {
            doc /* Flexible segment of the delivery catheter that can be bent and rotated by the steering handle. */;
            attribute segmentLength : LengthValue = 10;
            attribute maxBendAngle : AngleValue = 90;
            attribute maxBendRadius : LengthValue = 25;
        }

        part def SteerableDeliveryCatheter {
            doc /* Long, flexible catheter that holds the clip at its tip and is navigated through blood vessels and heart chambers to the mitral valve. */;

            attribute catheterLength : LengthValue = 100;
            attribute catheterOuterDiameter : DiameterValue = 20;
            attribute catheterInnerDiameter : DiameterValue = 16;
            item catheterMaterial : BiocompatiblePolymer;
            attribute currentBendAngle : AngleValue = 0;
            attribute currentRotation : AngleValue = 0;

            part proximalEnd : CatheterProximalEnd;
            part distalTip : CatheterDistalTip;
            part steerableSegment : SteerableSegment;

            port sheathInterface : CatheterOuterPort;
        }

        part def ControlKnob {
            doc /* Individual control knob on the steering handle for bending or rotating the catheter. */;
            attribute knobRange : AngleValue;
            attribute currentAngle : AngleValue = 0;
            port controlOutput : ControlInterfacePort;
        }

        part def ClipControl {
            doc /* Control mechanism on the steering handle for commanding clip operations. */;
            attribute command : ClipControlCommand;
            port controlOutput : ControlInterfacePort;
        }

        part def SteeringControlHandle {
            doc /* External handle with knobs for bending and rotating the catheter tip, and controls for opening, grasping, closing, and releasing the clip. */;

            attribute handleLength : LengthValue = 30;
            item handleMaterial : StainlessSteel;

            part bendKnob : ControlKnob {
                doc /* Knob for bending the catheter tip to achieve the correct orientation. */;
                :>> knobRange = 90;
            }
            part rotateKnob : ControlKnob {
                doc /* Knob for rotating the catheter tip. */;
                :>> knobRange = 360;
            }
            part clipOpenControl : ClipControl {
                doc /* Control to command the clip to open and prepare for leaflet capture. */;
                :>> command = ClipControlCommand::OPEN;
            }
            part clipGraspControl : ClipControl {
                doc /* Control to command the clip arms to grasp the valve leaflets. */;
                :>> command = ClipControlCommand::GRASP;
            }
            part clipCloseControl : ClipControl {
                doc /* Control to command the clip to close and lock into its final position. */;
                :>> command = ClipControlCommand::CLOSE;
            }
            part clipReleaseControl : ClipControl {
                doc /* Control to command the clip to be released from the delivery system. */;
                :>> command = ClipControlCommand::RELEASE;
            }

            port catheterConnection : ControlInterfacePort;
        }

        part def ImagingProbe {
            doc /* Ultrasound probe for acquiring cardiac images during the procedure. */;
            attribute probeFrequency : FrequencyValue = 5;
            port imagingOutput : ImagingOutputPort;
        }

        part def ImagingDisplay {
            doc /* Display for showing real-time echocardiographic images of the heart and device. */;
            attribute screenSize : LengthValue = 43;
            port imagingInput : ImagingOutputPort;
        }

        part def ImagingSystem {
            doc /* Echocardiographic imaging system for live visualization of cardiac structures and the device in real time. */;

            attribute imagingMode : ImagingMode = ImagingMode::TRANSESOPHAGEAL_ECHO;
            attribute frameRate : FrequencyValue = 30;

            part probe : ImagingProbe;
            part display : ImagingDisplay;

            connect probe.imagingOutput to display.imagingInput;
        }

        part def DeliverySystem {
            doc /* Complete delivery system consisting of guide sheath, steerable delivery catheter, steering control handle, and clip implant. */;

            part guideSheath : GuideSheath;
            part deliveryCatheter : SteerableDeliveryCatheter;
            part steeringHandle : SteeringControlHandle;
            part clipImplant : ClipImplant;

            connect deliveryCatheter.sheathInterface to guideSheath.distalPort;
            connect steeringHandle.catheterConnection to deliveryCatheter.proximalEnd.handleInterface;
            connect clipImplant.mountingInterface.mountPort to deliveryCatheter.distalTip.clipMount;
        }
    }

    package Anatomy {
        import ValueTypes::*;
        import Items::*;
        import PortDefs::*;

        part def Vein {
            doc /* A vein in the patient vascular system. */;
            attribute diameter : DiameterValue;
            attribute length : LengthValue;
            port bloodFlow : VascularAccessPort;
        }

        part def VascularSystem {
            doc /* The patient vascular system providing the pathway from the leg to the heart. */;

            part femoralVein : Vein {
                doc /* Femoral vein in the leg, the usual entry point for the guide sheath. */;
                :>> diameter = 12;
                :>> length = 20;
            }
            part inferiorVenaCava : Vein {
                doc /* Inferior vena cava carrying blood from the lower body to the right atrium. */;
                :>> diameter = 20;
                :>> length = 70;
            }
        }

        part def HeartChamber {
            doc /* A chamber of the heart. */;
            attribute bloodVolume : VolumeValue;
            port bloodFlow : VascularAccessPort;
        }

        part def MitralLeaflet {
            doc /* A leaflet of the mitral valve, either anterior or posterior. */;
            item tissue : MitralLeafletTissue;
            attribute leafletLength : LengthValue;
            attribute leafletThickness : LengthValue;
            port leafletInterface : LeafletInterfacePort;
        }

        part def MitralValve {
            doc /* The mitral valve with anterior and posterior leaflets that normally prevent backward flow of blood from the left atrium to the left ventricle. */;

            part anteriorLeaflet : MitralLeaflet {
                doc /* Anterior leaflet of the mitral valve. */;
                :>> leafletLength = 25;
                :>> leafletThickness = 3;
            }
            part posteriorLeaflet : MitralLeaflet {
                doc /* Posterior leaflet of the mitral valve. */;
                :>> leafletLength = 15;
                :>> leafletThickness = 3;
            }
            attribute regurgitantFraction : PercentageValue = 50;
            attribute coaptationDepth : LengthValue = 5;
            port inflow : VascularAccessPort;
            port outflow : VascularAccessPort;
        }

        part def Septum {
            doc /* Interatrial septum of the heart, crossed by the catheter during the procedure. */;
            attribute thickness : LengthValue = 4;
        }

        part def Heart {
            doc /* The patient heart containing chambers, the mitral valve, and the interatrial septum. */;

            part rightAtrium : HeartChamber {
                :>> bloodVolume = 100;
            }
            part leftAtrium : HeartChamber {
                :>> bloodVolume = 100;
            }
            part leftVentricle : HeartChamber {
                :>> bloodVolume = 120;
            }
            part mitralValve : MitralValve;
            part interatrialSeptum : Septum;
        }

        part def Patient {
            doc /* The patient undergoing the MitraClip transcatheter mitral valve repair procedure. */;

            attribute patientId : String;
            attribute bodyTemperature : TemperatureValue = 37;

            part vascularSystem : VascularSystem;
            part heart : Heart;
        }
    }

    package Procedure {
        import ValueTypes::*;
        import Components::*;
        import Anatomy::*;
        import Enums::*;
        import Signals::*;
        import Requirements::*;

        action def InsertGuideSheath {
            doc /* Insert the guide sheath into the femoral vein to create a stable pathway into the vascular system. */;
            in patient : Patient;
            in guideSheath : GuideSheath;
        }

        action def AdvanceDeliveryCatheter {
            doc /* Advance the delivery catheter through the guide sheath into the vascular system. */;
            in guideSheath : GuideSheath;
            in deliveryCatheter : SteerableDeliveryCatheter;
        }

        action def NavigateToMitralValve {
            doc /* Navigate the catheter across the interatrial septum and through the heart chambers to the mitral valve. */;
            in deliveryCatheter : SteerableDeliveryCatheter;
            in steeringHandle : SteeringControlHandle;
            in heart : Heart;
            in imagingSystem : ImagingSystem;
        }

        action def AlignClipWithLeaflets {
            doc /* Align the clip with the mitral valve leaflets using steering knobs and imaging guidance. */;
            in clip : ClipImplant;
            in mitralValve : MitralValve;
            in imagingSystem : ImagingSystem;
            in steeringHandle : SteeringControlHandle;
        }

        action def DeployClip {
            doc /* Deploy the clip through its state sequence: open, grasp, close and lock, and release from the delivery catheter. */;
            in clip : ClipImplant;
            in steeringHandle : SteeringControlHandle;
            in mitralValve : MitralValve;
        }

        action def ConfirmRegurgitationReduction {
            doc /* Confirm reduction in mitral regurgitation via echocardiographic assessment. */;
            in imagingSystem : ImagingSystem;
            in mitralValve : MitralValve;
            out regurgitantFraction : PercentageValue;
        }

        action def WithdrawDeliverySystem {
            doc /* Withdraw the delivery system from the patient body, leaving only the clip implant behind. */;
            in deliverySystem : DeliverySystem;
            in patient : Patient;
        }

        action def PerformMitraClipProcedure {
            doc /* Complete MitraClip transcatheter mitral valve repair procedure from vascular access through system withdrawal. */;

            in patient : Patient;
            in deliverySystem : DeliverySystem;
            in imagingSystem : ImagingSystem;

            attribute procedurePhase : ProcedurePhase = ProcedurePhase::PREPARATION;
            attribute procedureDuration : DurationValue;

            action insertGuideSheath : InsertGuideSheath;
            action advanceDeliveryCatheter : AdvanceDeliveryCatheter;
            action navigateToMitralValve : NavigateToMitralValve;
            action alignClipWithLeaflets : AlignClipWithLeaflets;
            action deployClip : DeployClip;
            action confirmRegurgitationReduction : ConfirmRegurgitationReduction;
            action withdrawDeliverySystem : WithdrawDeliverySystem;

            first insertGuideSheath;
            then advanceDeliveryCatheter;
            then navigateToMitralValve;
            then alignClipWithLeaflets;
            then deployClip;
            then confirmRegurgitationReduction;
            then withdrawDeliverySystem;

            satisfy TreatMitralRegurgitation;
            satisfy MinimallyInvasiveProcedure;
            satisfy LeafletGraspingRequirement;
            satisfy NavigationRequirement;
            satisfy SteeringControlRequirement;
            satisfy ImagingGuidanceRequirement;
            satisfy ClipDeploymentRequirement;
            satisfy BiocompatibilityRequirement;
            satisfy RegurgitationReductionRequirement;
            satisfy SystemWithdrawalRequirement;
        }
    }

    package System {
        import Components::*;
        import Anatomy::*;
        import Procedure::*;
        import ConnectionDefs::*;
        import PortDefs::*;

        part def MitraClipSystem {
            doc /* Top-level MitraClip Transcatheter Mitral Valve Repair System assembling the patient, delivery system, and imaging system. */;

            part patient : Patient;
            part deliverySystem : DeliverySystem;
            part imagingSystem : ImagingSystem;

            connect deliverySystem.guideSheath.vascularAccess to patient.vascularSystem.femoralVein.bloodFlow;
            connect deliverySystem.clipImplant.anteriorArm.leafletInterface to patient.heart.mitralValve.anteriorLeaflet.leafletInterface;
            connect deliverySystem.clipImplant.posteriorArm.leafletInterface to patient.heart.mitralValve.posteriorLeaflet.leafletInterface;

            action procedure : PerformMitraClipProcedure;
        }
    }
}
