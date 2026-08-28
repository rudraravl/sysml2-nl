package SurgicalFaceMaskModel {
    private import ISQ::*;
    private import SI::*;

    item def Air {
        attribute temperature :> temperature;
        attribute humidity : Real;
        attribute particleConcentration : Real;
    }

    item def AmbientAir :> Air;
    item def PurifiedAir :> Air;

    port def AirPort;
    port def SealPort;
    port def AttachmentPort;

    part def MaskLayer {
        port airIn : AirPort;
        port airOut : AirPort;
        attribute materialName : String;
        attribute filtrationEfficiency : Real;
        action filterAir;
    }

    part def OuterLayer :> MaskLayer {
        attribute :>> materialName = "Spunbond Polypropylene";
        attribute fluidResistance :> pressure;
    }

    part def MiddleLayer :> MaskLayer {
        attribute :>> materialName = "Meltblown Polypropylene";
        attribute electrostaticCharge : Real;
        attribute :>> filtrationEfficiency = 0.985;
    }

    part def InnerLayer :> MaskLayer {
        attribute :>> materialName = "Spunbond Polypropylene";
        attribute softness : Real;
    }

    part def NosePiece {
        attribute materialName : String = "Aluminum";
        port sealPoint : SealPort;
        action moldToNose;
    }

    part def EarLoop {
        attribute materialName : String = "Elastic";
        port attachPoint : AttachmentPort;
        action secureToEar;
    }

    part def SurgicalMask {
        port ambientIn : AirPort;
        port purifiedOut : AirPort;

        part outer : OuterLayer;
        part middle : MiddleLayer;
        part inner : InnerLayer;
        part nose : NosePiece;
        part leftEarLoop : EarLoop;
        part rightEarLoop : EarLoop;

        connect ambientIn to outer.airIn;
        connect outer.airOut to middle.airIn;
        connect middle.airOut to inner.airIn;
        connect inner.airOut to purifiedOut;

        attribute totalMass :> mass;
        attribute breathability :> pressure;
    }

    part def Wearer {
        port faceContact : SealPort;
        port leftEarAttach : AttachmentPort;
        port rightEarAttach : AttachmentPort;
        action inhale;
        action exhale;
    }

    state def MaskUsageState {
        initial state Unworn;
        state Worn;
        transition from Unworn to Worn;
        transition from Worn to Unworn;
    }

    part def MaskSystem {
        part mask : SurgicalMask;
        part wearer : Wearer;

        connect mask.leftEarLoop.attachPoint to wearer.leftEarAttach;
        connect mask.rightEarLoop.attachPoint to wearer.rightEarAttach;
        connect mask.nose.sealPoint to wearer.faceContact;

        perform maskUsage : MaskUsageState;
    }

    requirement def FiltrationRequirement {
        subject mask : SurgicalMask;
        attribute minEfficiency : Real = 0.98;
        attribute targetParticleSize :> length = 0.3 [um];
        constraint {
            mask.middle.filtrationEfficiency >= minEfficiency
        }
    }

    requirement def BreathabilityRequirement {
        subject mask : SurgicalMask;
        attribute maxMass :> mass = 50 [g];
        attribute maxPressureDrop :> pressure = 5 [Pa];
        constraint {
            mask.totalMass <= maxMass
        }
        constraint {
            mask.breathability <= maxPressureDrop
        }
    }

    requirement def FitRequirement {
        subject mask : SurgicalMask;
        constraint {
            mask.nose.materialName == "Aluminum"
        }
    }

    requirement filtrationReq : FiltrationRequirement;
    requirement breathabilityReq : BreathabilityRequirement;
    requirement fitReq : FitRequirement;

    part surgicalMaskInstance : SurgicalMask {
        attribute :>> totalMass = 45 [g];
        attribute :>> breathability = 3.2 [Pa];
        satisfy filtrationReq;
        satisfy breathabilityReq;
        satisfy fitReq;
    }
}
