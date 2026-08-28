package Sphygmograph {

    import ScalarValues::*;

    // ---------- Value Types ----------
    attribute def Displacement :> Real {
        doc : "Linear displacement in millimeters.";
    }
    attribute def MicroDisplacement :> Real {
        doc : "Sub-millimeter arterial wall displacement in micrometers.";
    }
    attribute def AngularVelocity :> Real {
        doc : "Rotational speed in revolutions per minute.";
    }
    attribute def TimeValue :> Real {
        doc : "Elapsed time in seconds.";
    }
    attribute def PulseFrequency :> Real {
        doc : "Heart rate in beats per minute.";
    }
    attribute def ForceValue :> Real {
        doc : "Mechanical contact force in newtons.";
    }
    attribute def GainValue :> Real {
        doc : "Dimensionless amplification factor.";
    }
    attribute def AmplitudeValue :> Real {
        doc : "Recorded waveform amplitude in millimeters.";
    }

    // ---------- Enumeration ----------
    enum OperationalPhase {
        literal idle;
        literal setup;
        literal ready;
        literal recording;
        literal complete;
    }

    // ---------- Item Definitions ----------
    item def PulseMovement {
        attribute amplitude : MicroDisplacement;
        attribute timestamp : TimeValue;
        attribute frequency : PulseFrequency;
    }

    item def AmplifiedMotion {
        attribute amplitude : AmplitudeValue;
        attribute timestamp : TimeValue;
    }

    item def Paper {
        attribute length : Displacement;
        attribute width : Displacement;
        attribute calibrated : Boolean = false;
    }

    item def CalibrationMark {
        attribute timeOffset : TimeValue;
        attribute amplitude : AmplitudeValue;
    }

    item def PulseWaveform {
        attribute samples : Sequence[0..*] of AmplifiedMotion;
        attribute recordedAt : TimeValue;
        attribute duration : TimeValue;
    }

    // ---------- Requirements ----------
    requirement def DetectionRequirement {
        doc :
        /* The pulse sensor shall detect arterial wall displacements of the radial artery. */
        constraint { minDetect >= 0.001 and maxDetect <= 0.5 }
    }

    requirement def AmplificationRequirement {
        doc :
        /* The lever amplifier shall magnify the pulse displacement by at least a factor of 50. */
        constraint { gain >= 50 }
    }

    requirement def DrumRotationRequirement {
        doc :
        /* The rotating drum shall turn at a constant, steady speed throughout recording. */
        constraint { angularSpeed > 0 }
    }

    requirement def RecordingDurationRequirement {
        doc :
        /* The sphygmograph shall record the pulse waveform for a configurable duration. */
        constraint { recordDuration > 0 }
    }

    requirement def CalibrationRequirement {
        doc :
        /* The calibration scale shall provide reference marks for time and amplitude on the recording. */
        constraint { timeStep > 0 and amplitudeStep > 0 }
    }

    // ---------- Component Parts ----------
    part def PulseSensor {
        attribute minDetect : MicroDisplacement = 0.001;
        attribute maxDetect : MicroDisplacement = 0.5;
        attribute contactForce : ForceValue = 0.0;
        attribute inContact : Boolean = false;

        in port pulseIn : PulseMovement;
        out port motionOut : PulseMovement;

        action def DetectAction {
            in signal : PulseMovement;
            out detected : PulseMovement;
            doc :
            /* Mechanically couples the arterial wall movement to the lever system. */
        }

        perform DetectAction;
    }

    part def LeverAmplifier {
        attribute gain : GainValue = 75.0;
        attribute pivotRatio : GainValue = 75.0;
        attribute leverLength : Displacement = 100.0;

        in port motionIn : PulseMovement;
        out port amplifiedOut : AmplifiedMotion;

        action def AmplifyAction {
            in motion : PulseMovement;
            out amplified : AmplifiedMotion;
            doc :
            /* Magnifies the small pulse movement into a larger visible displacement. */
        }

        perform AmplifyAction;
    }

    part def StylusAssembly {
        attribute tipWidth : Displacement = 0.2;
        attribute positionY : AmplitudeValue = 0.0;
        attribute inkLevel : Real = 1.0;
        attribute writing : Boolean = false;

        in port motionIn : AmplifiedMotion;
        out port trace : AmplifiedMotion;

        action def WriteAction {
            in motion : AmplifiedMotion;
            out line : AmplifiedMotion;
            doc :
            /* Translates the amplified motion into vertical displacement on the paper. */
        }

        perform WriteAction;
    }

    part def RotatingDrum {
        attribute angularSpeed : AngularVelocity = 2.0;
        attribute circumference : Displacement = 157.0;
        attribute paper : Paper;
        attribute turning : Boolean = false;

        in port driveCommand : Boolean;
        out port paperMotion : Displacement;

        action def RotateAction {
            in drive : Boolean;
            out motion : Displacement;
            doc :
            /* Drives the paper-covered drum at a steady angular speed to represent time. */
        }

        perform RotateAction;
    }

    part def CalibrationScale {
        attribute timeStep : TimeValue = 0.1;
        attribute amplitudeStep : AmplitudeValue = 1.0;
        attribute marks : Sequence[0..*] of CalibrationMark;

        action def GenerateMarksAction {
            out scaleMarks : Sequence[0..*] of CalibrationMark;
            doc :
            /* Produces reference grid marks for time intervals and amplitude steps. */
        }

        perform GenerateMarksAction;
    }

    // ---------- System Assembly ----------
    part def Sphygmograph {
        attribute phase : OperationalPhase = OperationalPhase::idle;
        attribute recordDuration : TimeValue = 60.0;
        attribute elapsedTime : TimeValue = 0.0;
        attribute resetCommand : Boolean = false;

        part sensor : PulseSensor;
        part lever : LeverAmplifier;
        part stylus : StylusAssembly;
        part drum : RotatingDrum;
        part calibration : CalibrationScale;

        in port commandIn : Boolean;
        out port waveformOut : PulseWaveform;

        connector sensor.motionOut to lever.motionIn;
        connector lever.amplifiedOut to stylus.motionIn;
        connector stylus.trace to waveformOut;
        connector commandIn to drum.driveCommand;

        state def SphygmographBehavior {
            state idle {
                entry : phase = OperationalPhase::idle;
                entry : sensor.inContact = false;
                entry : drum.turning = false;
                entry : stylus.writing = false;
            }
            state setup {
                entry : phase = OperationalPhase::setup;
                doc :
                /* Operator positions the sensor on the patient and prepares paper on the drum. */
            }
            state ready {
                entry : phase = OperationalPhase::ready;
                doc :
                /* Sensor contact verified; awaiting recording command. */
            }
            state recording {
                entry : phase = OperationalPhase::recording;
                entry : drum.turning = true;
                entry : stylus.writing = true;
                do : elapsedTime = elapsedTime + 1;
                doc :
                /* Drum rotates and stylus traces the live pulse waveform onto the paper. */
            }
            state complete {
                entry : phase = OperationalPhase::complete;
                entry : drum.turning = false;
                entry : stylus.writing = false;
                doc :
                /* Recording finished; the paper holds a permanent graphical pulse waveform. */
            }

            transition idle to setup when commandIn = true;
            transition setup to ready when sensor.inContact = true;
            transition ready to recording when drum.paper.calibrated = true;
            transition recording to complete when elapsedTime >= recordDuration;
            transition complete to idle when resetCommand = true;
        }

        exhibit SphygmographBehavior;

        satisfy DetectionRequirement;
        satisfy AmplificationRequirement;
        satisfy DrumRotationRequirement;
        satisfy RecordingDurationRequirement;
        satisfy CalibrationRequirement;
    }
}
