package 'Penis Extender System' {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def TractionForceValue :> ForceValue;
        attribute def LengthAdjustmentValue :> LengthValue;
        attribute def DurationValue :> TimeValue;

        item def MedicalGradeSilicone;
        item def PaddingMaterial;

        attribute def 'Fit Command';
        attribute def 'Tension Set Signal';
        attribute def 'Start Wear Signal';
        attribute def 'Session End Signal';

        port def MechanicalMountPort {
            attribute transmittedForce : TractionForceValue;
            in item adjustmentCommand : LengthAdjustmentValue;
            out item measuredForce : TractionForceValue;
        }

        interface def MechanicalConnection {
            end end1 : MechanicalMountPort;
            end end2 : MechanicalMountPort;
        }

        part def ComfortPadding {
            attribute material : PaddingMaterial;
            attribute thickness : LengthValue;
        }

        part def BaseRing {
            attribute material : MedicalGradeSilicone;
            port rodMount1 : MechanicalMountPort;
            port rodMount2 : MechanicalMountPort;
            part padding : ComfortPadding[2];
        }

        part def TensionAdjuster {
            attribute maxAdjustment : LengthAdjustmentValue;
            port controlPort : MechanicalMountPort;
            perform action applyAdjustment {
                in item command : LengthAdjustmentValue;
                out item appliedDelta : LengthAdjustmentValue;
            }
        }

        part def ForceSensor {
            attribute measuredForce : TractionForceValue;
            port sensingPort : MechanicalMountPort;
            perform action measureForce {
                out item reading : TractionForceValue;
            }
        }

        part def ExtensionRod {
            attribute currentLength : LengthAdjustmentValue;
            port baseMount : MechanicalMountPort;
            port cradleMount : MechanicalMountPort;
            part adjuster : TensionAdjuster;
            part sensor : ForceSensor;
            perform action adjustLength {
                in item targetLength : LengthAdjustmentValue;
                out item newLength : LengthAdjustmentValue;
            }
        }

        part def GlansCradle {
            attribute material : PaddingMaterial;
            port rodMount1 : MechanicalMountPort;
            port rodMount2 : MechanicalMountPort;
            part padding : ComfortPadding[2];
        }

        state def ExtenderLifecycle;

        action def 'Fit Device';
        action def 'Apply Tension';
        action def 'Maintain Traction';
        action def 'Monitor Force';
        action def 'Remove Device';
        action def 'Adjust Rods';

        part def PenisExtender {
            attribute appliedTension : TractionForceValue;
            attribute measuredForce : TractionForceValue;
            attribute sessionDuration : DurationValue;
            attribute maxSafeForce : TractionForceValue;

            exhibit state lifecycle : ExtenderLifecycle;

            part baseRing : BaseRing;
            part rod1 : ExtensionRod;
            part rod2 : ExtensionRod;
            part glansCradle : GlansCradle;
            part comfortPads : ComfortPadding[4];

            interface : MechanicalConnection connect
                end1 ::> baseRing.rodMount1 to
                end2 ::> rod1.baseMount;
            interface : MechanicalConnection connect
                end1 ::> baseRing.rodMount2 to
                end2 ::> rod2.baseMount;
            interface : MechanicalConnection connect
                end1 ::> rod1.cradleMount to
                end2 ::> glansCradle.rodMount1;
            interface : MechanicalConnection connect
                end1 ::> rod2.cradleMount to
                end2 ::> glansCradle.rodMount2;

            satisfy safety : SafetyRequirement;
            satisfy comfort : ComfortRequirement;
            satisfy effectiveness : EffectivenessRequirement;
            satisfy biocompatibility : BiocompatibilityRequirement;
        }

        requirement def SafetyRequirement {
            subject extender : PenisExtender;
            constraint { extender.measuredForce <= extender.maxSafeForce }
        }

        requirement def ComfortRequirement {
            subject extender : PenisExtender;
        }

        requirement def EffectivenessRequirement {
            attribute minSustainedForce : TractionForceValue;
            attribute minSessionDuration : DurationValue;
            subject extender : PenisExtender;
            constraint { extender.appliedTension >= minSustainedForce and extender.sessionDuration >= minSessionDuration }
        }

        requirement def BiocompatibilityRequirement {
            subject extender : PenisExtender;
        }
    }

    package Usages {
        private import Definitions::*;

        part extender : PenisExtender {
            attribute appliedTension = 800.0 [N];
            attribute maxSafeForce = 1200.0 [N];
            attribute sessionDuration = 4.0 [h];

            part rod1 : ExtensionRod {
                attribute currentLength = 120.0 [mm];
            }

            part rod2 : ExtensionRod {
                attribute currentLength = 120.0 [mm];
            }

            part comfortPads : ComfortPadding[4] {
                attribute thickness = 3.0 [mm];
            }
        }

        action 'fit device' : 'Fit Device';
        action 'apply tension' : 'Apply Tension';
        action 'maintain traction' : 'Maintain Traction';
        action 'monitor force' : 'Monitor Force';
        action 'remove device' : 'Remove Device';
        action 'adjust rods' : 'Adjust Rods';

        state lifecycle : ExtenderLifecycle {
            entry; then idle;

            state idle;
            accept 'Fit Command'
                then fitting;

            state fitting {
                entry 'fit device';
            }
            accept 'Tension Set Signal'
                then tensioning;

            state tensioning {
                entry 'apply tension';
                do 'adjust rods';
            }
            accept 'Start Wear Signal'
                if extender.measuredForce <= extender.maxSafeForce
                then 'active wear';

            state 'active wear' {
                entry 'maintain traction';
                do 'monitor force';
            }
            accept 'Session End Signal'
                do 'remove device'
                then idle;
        }
    }
}
