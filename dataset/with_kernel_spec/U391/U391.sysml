package SphygmographModel {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;
    private import SequenceFunctions::*;

    attribute def Displacement :> ISQ::LengthValue;
    attribute def AngularSpeed :> ISQ::AngularVelocityValue;
    attribute def LinearSpeed :> ISQ::SpeedValue;
    attribute def RecordingDuration :> ISQ::TimeValue;

    item def PulseSignal {
        attribute displacement : Displacement;
    }

    item def AmplifiedMotion {
        attribute displacement : Displacement;
    }

    item def PaperStrip {
        attribute length : ISQ::LengthValue;
        attribute width : ISQ::LengthValue;
    }

    item def PulseChart {
        attribute timePoints : ISQ::TimeValue[*] := ( );
        attribute displacements : Displacement[*] := ( );
    }

    port def PulseMotionPort {
        out item motion : PulseSignal;
    }

    port def AmplifiedMotionPort {
        out item motion : AmplifiedMotion;
    }

    part def PulseSensor {
        out port sensorOut : PulseMotionPort;
        attribute contactPressure : ISQ::PressureValue;
    }

    part def LeverAmplifier {
        in port leverIn : PulseMotionPort;
        out port leverOut : AmplifiedMotionPort;
        attribute amplificationFactor : Real = 10.0;
    }

    part def StylusAssembly {
        in port stylusIn : AmplifiedMotionPort;
        attribute stylusPosition : Displacement;
    }

    part def RotatingDrum {
        attribute rotationSpeed : AngularSpeed = 0.1 [rad/s];
        attribute paperFeedSpeed : LinearSpeed;
        item paper : PaperStrip;
    }

    part def CalibrationScale {
        attribute timeMarkInterval : ISQ::TimeValue = 1 [s];
        attribute amplitudeMarkInterval : Displacement = 1 [mm];
    }

    action def RecordPulse {
        in drumSpeed : LinearSpeed;
        in stylusDisplacement : Displacement;
        in recordingDuration : RecordingDuration;
        in sampleRate : Real;
        out chart : PulseChart;
        private attribute stepTime : RecordingDuration := 0.01 [s];
        private attribute elapsed : RecordingDuration := 0 [s];
        private attribute currentTime : ISQ::TimeValue := 0 [s];
        while elapsed < recordingDuration {
            assign currentTime := currentTime + stepTime;
            then assign chart.timePoints := chart.timePoints->including(currentTime);
            then assign chart.displacements := chart.displacements->including(stylusDisplacement);
            then assign elapsed := elapsed + stepTime;
        }
    }

    attribute def SetupCommand;
    attribute def SensorContactSignal;
    attribute def RecordingCompleteSignal;
    attribute def ResetCommand;

    state def SphygmographStates {
        entry; then idle;
        state idle;
        transition idle_to_setup
            first idle
            accept SetupCommand
            then setup;
        state setup;
        transition setup_to_recording
            first setup
            accept SensorContactSignal
            then recording;
        state recording;
        transition recording_to_stopped
            first recording
            accept RecordingCompleteSignal
            then stopped;
        state stopped;
        transition stopped_to_idle
            first stopped
            accept ResetCommand
            then idle;
    }

    part def Sphygmograph {
        attribute recordingDuration : RecordingDuration = 30 [s];
        attribute sampleRate : Real = 100.0;
        attribute recordedChart : PulseChart;

        part sensor : PulseSensor;
        part amplifier : LeverAmplifier;
        part stylus : StylusAssembly;
        part drum : RotatingDrum;
        part scale : CalibrationScale;

        flow of PulseSignal
            from sensor.sensorOut.motion
            to amplifier.leverIn.motion;

        flow of AmplifiedMotion
            from amplifier.leverOut.motion
            to stylus.stylusIn.motion;

        state sphygmographBehavior : SphygmographStates {
            state :>> recording {
                perform action record : RecordPulse {
                    in drumSpeed = drum.paperFeedSpeed;
                    in stylusDisplacement = stylus.stylusPosition;
                    in recordingDuration = recordingDuration;
                    in sampleRate = sampleRate;
                    out chart = recordedChart;
                }
            }
        }
    }

    part sphygmographSystem : Sphygmograph;

    requirement def DetectPulse {
        subject sensor : PulseSensor;
        doc /* The pulse sensor shall detect arterial wall movements when placed on the skin over an artery. */
    }

    requirement def AmplifyMotion {
        subject amplifier : LeverAmplifier;
        doc /* The lever amplifier shall magnify pulse displacement by a factor of at least 10. */
        attribute minGain : Real = 10.0;
    }

    requirement def RecordWaveform {
        subject stylus : StylusAssembly;
        doc /* The stylus shall trace vertical displacement onto the moving paper on the drum to produce a continuous pulse waveform. */
    }

    requirement def DrumRotation {
        subject drum : RotatingDrum;
        doc /* The rotating drum shall maintain a constant angular velocity during the recording phase to ensure accurate time representation. */
    }

    requirement def ProvideCalibration {
        subject scale : CalibrationScale;
        doc /* The calibration scale shall provide reference marks for time and amplitude on the recording for accurate measurement. */
    }

    requirement detectPulseReq : DetectPulse;
    requirement amplifyMotionReq : AmplifyMotion;
    requirement recordWaveformReq : RecordWaveform;
    requirement drumRotationReq : DrumRotation;
    requirement provideCalibrationReq : ProvideCalibration;

    satisfy detectPulseReq by sphygmographSystem.sensor;
    satisfy amplifyMotionReq by sphygmographSystem.amplifier;
    satisfy recordWaveformReq by sphygmographSystem.stylus;
    satisfy drumRotationReq by sphygmographSystem.drum;
    satisfy provideCalibrationReq by sphygmographSystem.scale;
}
