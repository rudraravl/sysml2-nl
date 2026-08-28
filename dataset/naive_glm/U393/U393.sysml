package SpicaSplintSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit deg;
    unit N;
    unit Pa;
    unit mm;
    unit g;
    unit K;

    // ===== Value Types =====
    value type AngleDeg > Real { unit deg; }
    value type ForceN > Real { unit N; }
    value type PressurePa > Real { unit Pa; }
    value type LengthMm > Real { unit mm; }
    value type MassG > Real { unit g; }
    value type TempK > Real { unit K; }
    value type Fraction > Real;

    // ===== Items =====
    item Moisture;
    item Heat;
    item Sweat;

    // ===== Enumerations =====
    enum HealingStatus { notHealed, partiallyHealed, healed; }
    enum ComfortLevel { uncomfortable, acceptable, comfortable; }
    enum FitQuality { poor, adequate, good; }

    // ===== Requirements =====
    requirement def ImmobilizationRequirement {
        doc /* The splint shall immobilize the thumb and wrist in therapeutic positions to facilitate healing. */
        subject splint : SpicaSplint;
        objective {
            doc /* Thumb abduction and wrist extension angles shall be maintained within clinical tolerance. */
        }
    }

    requirement def ThumbPositionRequirement :> ImmobilizationRequirement {
        doc /* The thumb component shall position the thumb at a specific abduction angle from the palm. */
        attribute thumbAbductionAngle : AngleDeg = 30 [deg];
        attribute tolerance : AngleDeg = 5 [deg];
        constraint { thumbAbductionAngle >= 25 [deg] and thumbAbductionAngle <= 35 [deg]; }
    }

    requirement def WristPositionRequirement :> ImmobilizationRequirement {
        doc /* The wrist component shall hold the wrist in a slightly extended position. */
        attribute wristExtensionAngle : AngleDeg = 15 [deg];
        attribute tolerance : AngleDeg = 3 [deg];
        constraint { wristExtensionAngle >= 12 [deg] and wristExtensionAngle <= 18 [deg]; }
    }

    requirement def ComfortRequirement {
        doc /* The padding layer shall distribute pressure evenly to avoid pressure sores. */
        subject padding : PaddingLayer;
        attribute maxPressure : PressurePa = 4000 [Pa];
        constraint { /* Interface pressure shall not exceed maxPressure. */ }
    }

    requirement def MoistureWickingRequirement {
        doc /* The padding layer shall wick moisture away from the skin. */
        subject padding : PaddingLayer;
        attribute minWickingCoefficient : Fraction = 0.5;
        constraint { wickingCoefficient >= minWickingCoefficient; }
    }

    requirement def FasteningRequirement {
        doc /* The splint shall be secured with four adjustable fastening straps. */
        subject straps : FasteningStrap[4];
        attribute strapCount : Integer = 4;
        attribute maxTension : ForceN = 25 [N];
        constraint { strapCount == 4; }
    }

    requirement def AdjustabilityRequirement {
        doc /* Straps shall be tightened or loosened to accommodate changes in swelling throughout healing. */
        subject straps : FasteningStrap[4];
    }

    requirement def LightweightRequirement {
        doc /* The outer shell shall be rigid and lightweight, made from a thermoplastic composite. */
        subject shell : OuterShell;
        attribute maxShellMass : MassG = 200 [g];
        attribute minRigidity : Fraction = 0.9;
        constraint { shellMass <= maxShellMass; }
        constraint { rigidity >= minRigidity; }
    }

    requirement def CirculationMonitoringRequirement {
        doc /* The patient's circulation and comfort shall be monitored while the splint is applied. */
        subject splint : SpicaSplint;
        attribute minCirculation : Fraction = 0.7;
        constraint { /* Circulation shall remain above minCirculation; otherwise straps shall be adjusted. */ }
    }

    // ===== Port Definitions =====
    port def LimbInterface {
        in attribute limbCircumference : LengthMm;
        out item moisture : Moisture;
        out item heat : Heat;
        out attribute swelling : Fraction;
        out attribute circulation : Fraction;
    }

    port def ShellPaddingInterface {
        out item heat : Heat;
        out item moisture : Moisture;
    }

    port def StrapAnchorPort {
        in attribute tension : ForceN;
    }

    // ===== Part Definitions =====
    part def OuterShell {
        attribute materialName : String = "ThermoplasticComposite";
        attribute shellThickness : LengthMm = 3 [mm];
        attribute rigidity : Fraction = 0.95;
        attribute ventilationHoles : Integer = 12;
        attribute shellMass : MassG = 180 [g];

        port limbFacing : LimbInterface;
        port paddingFacing : ShellPaddingInterface;
        port strapAnchorA : StrapAnchorPort;
        port strapAnchorB : StrapAnchorPort;
        port strapAnchorC : StrapAnchorPort;
        port strapAnchorD : StrapAnchorPort;

        exhibit state def ShellState {
            entry; then stable;
            state stable;
            accept moisture : Moisture via paddingFacing;
            then stable;
        }
    }

    part def PaddingLayer {
        attribute materialName : String = "ClosedCellFoam";
        attribute paddingThickness : LengthMm = 5 [mm];
        attribute porosity : Fraction = 0.3;
        attribute wickingCoefficient : Fraction = 0.8;
        attribute paddingMass : MassG = 40 [g];

        port skinFacing : LimbInterface;
        port shellFacing : ShellPaddingInterface;

        exhibit state def PaddingState {
            entry; then wicking;
            state wicking;
            accept moisture : Moisture via skinFacing;
            then distributing;
            state distributing {
                entry action distributePressure;
            }
            transition distributing then wicking;
        }
    }

    part def ThumbComponent {
        attribute abductionAngle : AngleDeg = 30 [deg];
        attribute componentLength : LengthMm = 70 [mm];
        attribute componentMass : MassG = 15 [g];

        port limbContact : LimbInterface;
        port shellMount : ShellPaddingInterface;

        constraint { abductionAngle >= 25 [deg] and abductionAngle <= 35 [deg]; }
    }

    part def WristComponent {
        attribute extensionAngle : AngleDeg = 15 [deg];
        attribute componentLength : LengthMm = 120 [mm];
        attribute componentMass : MassG = 20 [g];

        port limbContact : LimbInterface;
        port shellMount : ShellPaddingInterface;

        constraint { extensionAngle >= 12 [deg] and extensionAngle <= 18 [deg]; }
    }

    part def FasteningStrap {
        attribute identifier : String;
        attribute strapWidth : LengthMm = 25 [mm];
        attribute strapLength : LengthMm = 300 [mm];
        attribute currentTension : ForceN = 10 [N];
        attribute maxTension : ForceN = 25 [N];
        attribute adjustable : Boolean = true;

        port anchorEnd : StrapAnchorPort;
        port freeEnd : StrapAnchorPort;

        exhibit state def StrapState {
            entry; then secured;
            state secured;
            transition secured then loosened
                when currentTension > maxTension;
            state loosened {
                entry action reduceTension;
            }
            transition loosened then secured;
        }
    }

    part def PatientLimb {
        attribute thumbCircumference : LengthMm = 60 [mm];
        attribute wristCircumference : LengthMm = 170 [mm];
        attribute currentSwelling : Fraction = 0.3;
        attribute circulation : Fraction = 0.9;
        attribute comfort : ComfortLevel = comfortable;
        attribute healingStatus : HealingStatus = notHealed;

        port splintInterface : LimbInterface;

        exhibit state def LimbHealingState {
            entry; then injured;
            state injured;
            transition injured then healing
                when currentSwelling < 0.2;
            state healing;
            transition healing then healed
                when circulation > 0.95 and currentSwelling < 0.1;
            state healed;
        }
    }

    // ===== Action Definitions =====
    action def FitSplint {
        in limb : PatientLimb;
        out thumbAngle : AngleDeg = 30 [deg];
        out wristAngle : AngleDeg = 15 [deg];
        out fitQuality : FitQuality;
    }

    action def EvaluateFit {
        in limb : PatientLimb;
        out fitQuality : FitQuality;
    }

    action def ApplyImmobilization {
        out thumbAngle : AngleDeg = 30 [deg];
        out wristAngle : AngleDeg = 15 [deg];
    }

    action def MaintainPosition {
        in thumbAngle : AngleDeg;
        in wristAngle : AngleDeg;
    }

    action def MonitorCirculation {
        in limb : PatientLimb;
        out circulation : Fraction;
    }

    action def MonitorComfort {
        in limb : PatientLimb;
        out comfort : ComfortLevel;
    }

    action def AdjustStraps {
        in swelling : Fraction;
        out newTension : ForceN;
    }

    action def RedistributePressure {
        out pressure : PressurePa;
    }

    action def RemoveSplint;

    // ===== Main System Part =====
    part def SpicaSplint {
        attribute deviceMass : MassG = 250 [g];
        attribute deviceLength : LengthMm = 220 [mm];
        attribute deviceWidth : LengthMm = 90 [mm];

        attribute currentFitQuality : FitQuality = poor;
        attribute currentCirculation : Fraction = 0.9;
        attribute currentComfort : ComfortLevel = comfortable;
        attribute healingComplete : Boolean = false;

        part outerShell : OuterShell;
        part padding : PaddingLayer;
        part thumbSupport : ThumbComponent;
        part wristSupport : WristComponent;
        part strap1 : FasteningStrap { attribute identifier = "proximal_wrist"; }
        part strap2 : FasteningStrap { attribute identifier = "distal_wrist"; }
        part strap3 : FasteningStrap { attribute identifier = "thumb_base"; }
        part strap4 : FasteningStrap { attribute identifier = "forearm"; }

        port patientInterface : LimbInterface;

        satisfy ThumbPositionRequirement by thumbSupport;
        satisfy WristPositionRequirement by wristSupport;
        satisfy ComfortRequirement by padding;
        satisfy MoistureWickingRequirement by padding;
        satisfy FasteningRequirement by strap1;
        satisfy AdjustabilityRequirement by strap1;
        satisfy LightweightRequirement by outerShell;
        satisfy CirculationMonitoringRequirement by self;

        connection padToShell connect padding.shellFacing to outerShell.paddingFacing;
        connection thumbToShell connect thumbSupport.shellMount to outerShell.paddingFacing;
        connection wristToShell connect wristSupport.shellMount to outerShell.paddingFacing;

        connection strap1Conn connect strap1.anchorEnd to outerShell.strapAnchorA;
        connection strap2Conn connect strap2.anchorEnd to outerShell.strapAnchorB;
        connection strap3Conn connect strap3.anchorEnd to outerShell.strapAnchorC;
        connection strap4Conn connect strap4.anchorEnd to outerShell.strapAnchorD;

        connection limbToPadding connect patientInterface to padding.skinFacing;
        connection padToThumb connect padding.skinFacing to thumbSupport.limbContact;
        connection padToWrist connect padding.skinFacing to wristSupport.limbContact;

        exhibit state def ClinicalLifecycle {
            entry; then Fitting;

            state Fitting {
                entry action fit : FitSplint;
                do action evaluate : EvaluateFit;
                transition Fitting then Immobilizing
                    when currentFitQuality == good;
            }

            state Immobilizing {
                entry action apply : ApplyImmobilization;
                do action maintain : MaintainPosition;
                transition Immobilizing then Monitoring;
            }

            state Monitoring {
                do action monCirc : MonitorCirculation;
                do action monComf : MonitorComfort;
                transition Monitoring then Adjusting
                    when currentCirculation < 0.7 or currentComfort == uncomfortable;
                transition Monitoring then Removed
                    when healingComplete;
            }

            state Adjusting {
                entry action adjust : AdjustStraps;
                do action redistribute : RedistributePressure;
                transition Adjusting then Monitoring;
            }

            state Removed {
                entry action remove : RemoveSplint;
            }
        }
    }

    // ===== Top-level Usage =====
    part spicaSplintInstance : SpicaSplint;
    part patient : PatientLimb;

    connection patientToSplint connect patient.splintInterface to spicaSplintInstance.patientInterface;
}
