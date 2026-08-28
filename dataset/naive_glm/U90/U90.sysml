package NailBraceSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type ForceValue :> Real { unit = "N"; }
    value type CurvatureValue :> Real { unit = "1/m"; }
    value type LengthValue :> Real { unit = "m"; }
    value type DurationValue :> Real { unit = "d"; }

    part def NailPlate {
        attribute curvature : CurvatureValue;
        attribute thickness : LengthValue;
    }

    port def ForceFlow {
        out item force : ForceValue;
    }

    part def AnchorHook {
        port wirePort : ~ForceFlow;
        port nailPort : ForceFlow;
        attribute position : String;
        action def attachToNail;
        action def detachFromNail;
    }

    part def BraceWire {
        port hookPort1 : ForceFlow;
        port hookPort2 : ForceFlow;
        port adjusterPort : ~ForceFlow;
        attribute material : String = "Nickel-Titanium";
        attribute currentTension : ForceValue;
        action def applyForce;
    }

    part def TensionAdjuster {
        port wirePort : ForceFlow;
        attribute maxTension : ForceValue = 0.5 [N];
        action def setTension(in desiredTension : ForceValue);
        action def modifyTension(in delta : ForceValue);
    }

    part def PatientNail :> NailPlate {
        port nailPort : ~ForceFlow;
    }

    part def NailBraceSystem {
        part leftHook : AnchorHook { :>> position = "left"; }
        part rightHook : AnchorHook { :>> position = "right"; }
        part wire : BraceWire;
        part adjuster : TensionAdjuster;
        part patientNail : PatientNail;

        connection wireToLeftHook connect wire.hookPort1 to leftHook.wirePort;
        connection wireToRightHook connect wire.hookPort2 to rightHook.wirePort;
        connection adjusterToWire connect adjuster.wirePort to wire.adjusterPort;
        connection leftHookToNail connect leftHook.nailPort to patientNail.nailPort;
        connection rightHookToNail connect rightHook.nailPort to patientNail.nailPort;

        attribute targetCurvature : CurvatureValue = 10.0 [1/m];

        action measureCurvature(in nail : PatientNail) out res : CurvatureValue;

        state def TreatmentLifecycle {
            entry action { /* Treatment Started */ }
            exit action { /* Treatment Ended */ }

            state installed {
                entry action { 
                    leftHook.attachToNail(); 
                    rightHook.attachToNail(); 
                    wire.applyForce(); 
                }
            }
            
            state activeCorrection;
            
            state monitoring {
                entry action { 
                    measureCurvature(patientNail); 
                }
            }
            
            state adjusting {
                entry action { 
                    adjuster.modifyTension(0.1 [N]); 
                }
            }
            
            state treatmentComplete {
                entry action { 
                    leftHook.detachFromNail(); 
                    rightHook.detachFromNail(); 
                }
            }
            
            state removed;
            
            transition installed -> activeCorrection;
            transition activeCorrection -> monitoring after 7 [d];
            transition monitoring -> adjusting if patientNail.curvature > targetCurvature;
            transition monitoring -> treatmentComplete if patientNail.curvature <= targetCurvature;
            transition adjusting -> activeCorrection;
            transition treatmentComplete -> removed;
        }
    }

    requirement def CorrectNailDeformity {
        subject braceSystem : NailBraceSystem;
        doc "The system shall correct nail deformities by applying a gentle, controlled mechanical force."
    }

    requirement def SafeForceLimit {
        subject braceSystem : NailBraceSystem;
        doc "The applied force shall not exceed the maximum safe force limit to prevent nail damage or excessive pain."
        require braceSystem.wire.currentTension <= 0.5 [N]
    }

    requirement def EffectiveCorrection {
        subject braceSystem : NailBraceSystem;
        doc "The system shall achieve a clinically acceptable nail shape (curvature <= targetCurvature)."
        require braceSystem.patientNail.curvature <= 10.0 [1/m]
    }

    requirement def TreatmentLifecycleRequirement {
        subject braceSystem : NailBraceSystem;
        doc "The system shall follow the defined treatment lifecycle: installed, active correction, monitoring, adjusting, treatment complete, and removed."
    }
}
