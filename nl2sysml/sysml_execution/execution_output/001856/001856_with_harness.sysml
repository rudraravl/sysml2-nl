package ScrewSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ThreadPitch :> ISQ::LengthValue;
    attribute def ThreadAngle :> ISQ::PlaneAngleValue;
    attribute def RotationAngle :> ISQ::PlaneAngleValue;
    attribute def AxialDisplacement :> ISQ::LengthValue;
    attribute def ClampingForce :> ISQ::ForceValue;
    attribute def AppliedTorque :> ISQ::TorqueValue;
    attribute def FrictionCoefficient :> Real;
    
    part def ScrewHead {
        attribute driveType : String;
        attribute headDiameter :> ISQ::diameter;
        port torqueInput {
            in appliedTorque : AppliedTorque;
        }
    }
    
    part def ThreadedShaft {
        attribute shaftDiameter :> ISQ::diameter;
        attribute threadPitch : ThreadPitch;
        attribute threadAngle : ThreadAngle;
        attribute shaftLength :> ISQ::length;
        attribute numberOfThreads : Integer;
        
        port mechanicalInterface {
            in rotationalMotion : RotationAngle;
            out axialMotion : AxialDisplacement;
        }
    }
    
    part def ScrewTip {
        attribute tipGeometry : String;
        port loadTransfer {
            out clampingForce : ClampingForce;
        }
    }
    
    part def WorkpieceMaterial {
        attribute materialType : String;
        attribute thickness :> ISQ::length;
        attribute hardness : Real;
        port receivingInterface {
            in appliedForce : ClampingForce;
        }
    }
    
    action def ApplyTorque {
        in torque : AppliedTorque;
        out rotation : RotationAngle;
    }
    
    action def ConvertRotationToAxialMotion {
        in rotationAngle : RotationAngle;
        in pitch : ThreadPitch;
        out displacement : AxialDisplacement;
    }
    
    action def GenerateClampingForce {
        in axialDisplacement : AxialDisplacement;
        in appliedTorque : AppliedTorque;
        in frictionCoeff : FrictionCoefficient;
        out clampingForce : ClampingForce;
    }
    
    action def FastenWorkpieces {
        in inputTorque : AppliedTorque;
        out finalClampingForce : ClampingForce;
        out finalDisplacement : AxialDisplacement;
        
        first start;
        then action applyTorque : ApplyTorque {
            in torque = inputTorque;
            out rotation : RotationAngle;
        }
        then action convertMotion : ConvertRotationToAxialMotion {
            in rotationAngle = applyTorque.rotation;
            in pitch : ThreadPitch;
            out displacement : AxialDisplacement;
        }
        then action generateForce : GenerateClampingForce {
            in axialDisplacement = convertMotion.displacement;
            in appliedTorque = inputTorque;
            in frictionCoeff : FrictionCoefficient;
            out clampingForce : ClampingForce;
        }
        then assign finalClampingForce := generateForce.clampingForce;
        then assign finalDisplacement := convertMotion.displacement;
        then done;
    }
    
    state def ScrewOperationStates {
        in attribute requiredForce : ClampingForce;
        attribute currentTorque : AppliedTorque;
        attribute finalForce : ClampingForce;
        
        entry; then idle;
        
        state idle {
            entry assign currentTorque := 0.0 [N*m];
        }
        
        transition idle_to_engaging
            first idle
            accept torqueApplication : AppliedTorque
            then engaging;
        
        state engaging {
            entry assign currentTorque := torqueApplication;
            do action threadEngagement : ConvertRotationToAxialMotion;
        }
        
        transition engaging_to_tightening
            first engaging
            if threadEngagement.displacement > 0.0 [mm]
            then tightening;
        
        state tightening {
            do action applyClampingForce : GenerateClampingForce;
        }
        
        transition tightening_to_seated
            first tightening
            if applyClampingForce.clampingForce >= requiredForce
            then seated;
        
        state seated {
            entry assign finalForce := applyClampingForce.clampingForce;
        }
        
        transition seated_to_idle
            first seated
            accept torqueRemoval : AppliedTorque
            then idle;
    }
    
    part screw {
        attribute nominalDiameter :> ISQ::diameter = 6.0 [mm];
        attribute totalLength :> ISQ::length = 50.0 [mm];
        attribute materialStrength :> ISQ::pressure = 400.0 [Pa];
        
        part head : ScrewHead {
            attribute driveType = "Phillips";
            attribute headDiameter = 10.0 [mm];
        }
        
        part shaft : ThreadedShaft {
            attribute shaftDiameter = screw::nominalDiameter;
            attribute threadPitch = 1.0 [mm];
            attribute threadAngle = 60.0 [rad];
            attribute shaftLength = 45.0 [mm];
            attribute numberOfThreads = 45;
        }
        
        part tip : ScrewTip {
            attribute tipGeometry = "pointed";
        }
        
        connection headToShaft connect head.torqueInput to shaft.mechanicalInterface;
        connection shaftToTip connect shaft.mechanicalInterface to tip.loadTransfer;
        
        perform action fasteningOperation : FastenWorkpieces {
            in inputTorque : AppliedTorque;
            out finalClampingForce : ClampingForce;
            out finalDisplacement : AxialDisplacement;
        }
        
        exhibit state screwStates : ScrewOperationStates {
            in attribute requiredForce = 500.0 [N];
        }
    }
    
    part workpiece : WorkpieceMaterial {
        attribute materialType = "steel";
        attribute thickness = 10.0 [mm];
        attribute hardness = 200.0;
    }
    
    connection screwToWorkpiece connect screw.tip.loadTransfer to workpiece.receivingInterface;
    
    requirement def FasteningRequirement {
        doc /* The screw shall convert rotational torque into axial clamping force 
               to securely fasten workpieces together. */
        
        subject screwSubject;
        
        require constraint minClampingForce {
            doc /* The screw shall generate minimum clamping force based on applied torque. */
        }
        
        require constraint threadIntegrity {
            doc /* The threaded shaft shall maintain structural integrity under load. */
        }
    }
    
    requirement <'1'> primaryFasteningRequirement : FasteningRequirement {
        doc /* The screw system shall convert applied rotational torque into linear 
               axial displacement through helical thread engagement, generating sufficient 
               clamping force to securely join two or more workpieces. */
        
        subject screwSubject = screw;
        
        assume constraint torqueApplied {
            doc /* Torque is applied to the screw head. */
        }
        
        require constraint adequateClampingForce {
            doc /* The generated clamping force shall exceed the minimum required 
                   to prevent workpiece separation under operational loads. */
            screwSubject.fasteningOperation.finalClampingForce >= 500.0 [N]
        }
        
        require constraint threadEngagement {
            doc /* The screw shall achieve full thread engagement with workpiece material. */
            screwSubject.fasteningOperation.finalDisplacement >= screwSubject.shaft.threadPitch * 3.0
        }
    }
    
    requirement <'2'> mechanicalConversionRequirement {
        doc /* The screw shall efficiently convert rotational motion to linear motion 
               through its helical thread geometry. */
        
        subject shaftSubject = screw.shaft;
        
        require constraint linearDisplacementPerRevolution {
            doc /* Each complete rotation shall produce axial displacement equal to thread pitch. */
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ScrewSystem::*;

    part testSubject = screw {
        exhibit state sm : ScrewOperationStates;
    }

    action orchestrator {
        attribute testTorque : AppliedTorque;
        action actionProbe : ApplyTorque {
            in torque = testTorque;
        }
        first actionProbe;
    }
}
