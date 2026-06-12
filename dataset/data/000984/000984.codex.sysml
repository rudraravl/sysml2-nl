package BarographSystem {
    import ScalarValues::*;
    import SI::*;

    attribute def Pressure {
        :>> unit = SI::pascal;
    }

    attribute def HectopascalPressure :> Pressure {
        :>> unit = SI::hectopascal;
    }

    attribute def Temperature {
        :>> unit = SI::kelvin;
    }

    attribute def Duration {
        :>> unit = SI::second;
    }

    attribute def AngularSpeed {
        :>> unit = SI::radianPerSecond;
    }

    attribute def LinearDisplacement {
        :>> unit = SI::millimeter;
    }

    item def AtmosphericAir {
        attribute staticPressure : HectopascalPressure;
        attribute ambientTemperature : Temperature;
    }

    item def CapsuleDeflection {
        attribute displacement : LinearDisplacement;
        attribute sourcePressure : HectopascalPressure;
    }

    item def AmplifiedPenMotion {
        attribute verticalDisplacement : LinearDisplacement;
        attribute representedPressure : HectopascalPressure;
    }

    item def TimeBaseMotion {
        attribute drumAngularSpeed : AngularSpeed;
        attribute chartPeriod : Duration;
    }

    item def BarogramTrace {
        attribute startPressure : HectopascalPressure;
        attribute currentPressure : HectopascalPressure;
        attribute elapsedTime : Duration;
        attribute traceContinuity : Boolean;
    }

    item def WindingEnergy {
        attribute storedRunTime : Duration;
    }

    port def AtmospherePort {
        in item air : AtmosphericAir;
    }

    port def MechanicalDeflectionPort {
        out item deflection : CapsuleDeflection;
    }

    port def DeflectionInputPort {
        in item deflection : CapsuleDeflection;
    }

    port def PenMotionPort {
        out item motion : AmplifiedPenMotion;
    }

    port def PenMotionInputPort {
        in item motion : AmplifiedPenMotion;
    }

    port def TimeMotionPort {
        out item timeMotion : TimeBaseMotion;
    }

    port def TimeMotionInputPort {
        in item timeMotion : TimeBaseMotion;
    }

    port def ChartRecordPort {
        out item trace : BarogramTrace;
    }

    port def WindingPort {
        in item winding : WindingEnergy;
    }

    part def AneroidCapsule {
        port atmosphere : AtmospherePort;
        port deflectionOut : MechanicalDeflectionPort;

        attribute nominalPressureRangeLow : HectopascalPressure = 940 [SI::hectopascal];
        attribute nominalPressureRangeHigh : HectopascalPressure = 1060 [SI::hectopascal];
        attribute sensitivity : Real = 0.08;

        action sensePressure {
            in item sensedAir : AtmosphericAir;
            out item capsuleDeflection : CapsuleDeflection;

            first start;
            then computeDeflection;
            then provideMotion;

            action computeDeflection {
                in item sensedAir : AtmosphericAir;
                out item capsuleDeflection : CapsuleDeflection;
            }

            action provideMotion {
                in item capsuleDeflection : CapsuleDeflection;
            }
        }
    }

    part def LinkageAmplifier {
        port deflectionIn : DeflectionInputPort;
        port penMotionOut : PenMotionPort;

        attribute amplificationRatio : Real = 12.5;
        attribute backlashLimit : LinearDisplacement = 0.05 [SI::millimeter];

        action amplifyDeflection {
            in item capsuleDeflection : CapsuleDeflection;
            out item penMotion : AmplifiedPenMotion;

            first receiveDeflection;
            then applyLeverRatio;
            then outputPenMotion;
        }
    }

    part def RecordingStylus {
        port motionIn : PenMotionInputPort;
        port chartOut : ChartRecordPort;

        attribute inkReservoirCapacity : Real = 1.2;
        attribute stylusContactForce : Real = 0.18;

        action inscribePressureTrace {
            in item penMotion : AmplifiedPenMotion;
            in item timeMotion : TimeBaseMotion;
            out item trace : BarogramTrace;

            first positionStylus;
            then maintainContact;
            then markChart;
        }
    }

    part def ChartDrum {
        port timeMotionIn : TimeMotionInputPort;
        port traceOut : ChartRecordPort;

        attribute chartRotationPeriod : Duration = 604800 [SI::second];
        attribute chartWidth : LinearDisplacement = 95 [SI::millimeter];

        action carryChart {
            in item timeMotion : TimeBaseMotion;
            out item trace : BarogramTrace;

            first holdChartPaper;
            then rotateUniformly;
            then exposeRecordingSurface;
        }
    }

    part def ClockDrive {
        port windingIn : WindingPort;
        port timeMotionOut : TimeMotionPort;

        attribute ratedRunTime : Duration = 691200 [SI::second];
        attribute nominalAngularSpeed : AngularSpeed = 0.00001039 [SI::radianPerSecond];

        action regulateTimeBase {
            in item winding : WindingEnergy;
            out item timeMotion : TimeBaseMotion;

            first acceptWindingEnergy;
            then regulateEscapement;
            then rotateDrum;
        }
    }

    part def CalibrationAdjuster {
        attribute pressureOffset : HectopascalPressure = 0 [SI::hectopascal];
        attribute spanCorrection : Real = 1.0;

        action calibrate {
            in attribute referencePressure : HectopascalPressure;
            in attribute indicatedPressure : HectopascalPressure;
            out attribute correctedOffset : HectopascalPressure;

            first compareReference;
            then setOffset;
            then verifyIndication;
        }
    }

    part def ProtectiveCase {
        attribute ventilationOpenArea : Real = 24.0;
        attribute dustProtected : Boolean = true;
        attribute transparentCoverClosed : Boolean = true;
    }

    part def Barograph {
        port ambientAtmosphere : AtmospherePort;
        port userWinding : WindingPort;
        port recordedOutput : ChartRecordPort;

        part capsule : AneroidCapsule;
        part linkage : LinkageAmplifier;
        part stylus : RecordingStylus;
        part drum : ChartDrum;
        part clock : ClockDrive;
        part calibration : CalibrationAdjuster;
        part case : ProtectiveCase;

        connect ambientAtmosphere to capsule.atmosphere;
        connect capsule.deflectionOut to linkage.deflectionIn;
        connect linkage.penMotionOut to stylus.motionIn;
        connect clock.timeMotionOut to drum.timeMotionIn;
        connect clock.timeMotionOut to stylus.timeMotion;
        connect stylus.chartOut to recordedOutput;
        connect drum.traceOut to recordedOutput;
        connect userWinding to clock.windingIn;

        action recordAtmosphericPressure {
            in item surroundingAir : AtmosphericAir;
            in item windingEnergy : WindingEnergy;
            out item pressureRecord : BarogramTrace;

            first exposeCapsuleToAtmosphere;
            then convertPressureToDeflection;
            then amplifyMechanicalMotion;
            then driveChartAtKnownRate;
            then markPressureAgainstTime;
            then provideBarogram;

            action exposeCapsuleToAtmosphere {
                in item surroundingAir : AtmosphericAir;
                out item sensedAir : AtmosphericAir;
            }

            action convertPressureToDeflection {
                in item sensedAir : AtmosphericAir;
                out item capsuleDeflection : CapsuleDeflection;
            }

            action amplifyMechanicalMotion {
                in item capsuleDeflection : CapsuleDeflection;
                out item penMotion : AmplifiedPenMotion;
            }

            action driveChartAtKnownRate {
                in item windingEnergy : WindingEnergy;
                out item timeMotion : TimeBaseMotion;
            }

            action markPressureAgainstTime {
                in item penMotion : AmplifiedPenMotion;
                in item timeMotion : TimeBaseMotion;
                out item pressureRecord : BarogramTrace;
            }

            action provideBarogram {
                in item pressureRecord : BarogramTrace;
            }
        }

        state def OperatingState {
            entry action initializeMechanism;

            state Idle;
            state Wound;
            state Recording;
            state ChartChange;
            state Calibration;
            state Fault;

            transition idleToWound
                first Idle
                accept item winding : WindingEnergy
                then Wound;

            transition woundToRecording
                first Wound
                if winding.storedRunTime > 3600 [SI::second]
                then Recording;

            transition recordingToChartChange
                first Recording
                if clock.ratedRunTime <= 0 [SI::second]
                then ChartChange;

            transition recordingToCalibration
                first Recording
                accept event calibrationRequested
                then Calibration;

            transition calibrationToRecording
                first Calibration
                if calibration.spanCorrection > 0.95 and calibration.spanCorrection < 1.05
                then Recording;

            transition anyToFault
                first Recording
                if stylus.inkReservoirCapacity <= 0.0
                then Fault;

            transition faultToIdle
                first Fault
                accept event faultCleared
                then Idle;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject barograph : Barograph;

        doc
        /* The barograph shall continuously sense ambient atmospheric pressure and produce a time-indexed graphical pressure record. */

        require constraint {
            barograph.recordedOutput.trace.traceContinuity == true
        }
    }

    requirement def PressureRangeRequirement {
        subject capsule : AneroidCapsule;

        require constraint {
            capsule.nominalPressureRangeLow <= 940 [SI::hectopascal] and
            capsule.nominalPressureRangeHigh >= 1060 [SI::hectopascal]
        }
    }

    requirement def TimeRecordingRequirement {
        subject clock : ClockDrive;

        require constraint {
            clock.ratedRunTime >= 604800 [SI::second]
        }
    }

    requirement def ChartPeriodRequirement {
        subject drum : ChartDrum;

        require constraint {
            drum.chartRotationPeriod == 604800 [SI::second]
        }
    }

    requirement def CalibrationRequirement {
        subject calibration : CalibrationAdjuster;

        require constraint {
            calibration.spanCorrection >= 0.95 and
            calibration.spanCorrection <= 1.05
        }
    }

    part fieldBarograph : Barograph {
        attribute highLevelPrimaryFunction : String =
            "Continuously records atmospheric pressure variation over time as a barogram trace.";
    }

    satisfy PrimaryFunctionRequirement by fieldBarograph;
    satisfy PressureRangeRequirement by fieldBarograph.capsule;
    satisfy TimeRecordingRequirement by fieldBarograph.clock;
    satisfy ChartPeriodRequirement by fieldBarograph.drum;
    satisfy CalibrationRequirement by fieldBarograph.calibration;
}