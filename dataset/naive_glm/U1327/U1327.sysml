package BoseQCHeadphones {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types with Units ----------
    attribute def SoundPressureLevel :> Real { unit 'dB'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Charge :> Real { unit 'mAh'; }
    attribute def TimeValue :> Real { unit 's'; }
    attribute def Gain :> Real { unit '1'; }

    // ---------- Item Types ----------
    item def AmbientNoise {
        attribute level : SoundPressureLevel;
        attribute spectrum : Frequency[0..*];
    }

    item def AudioStream {
        attribute sampleRate : Frequency;
        attribute amplitude : Voltage;
    }

    item def ElectricalAudioSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }

    item def AntiNoiseSignal {
        attribute amplitude : Voltage;
        attribute phaseShift : Real; // radians, ~pi for destructive interference
    }

    item def CombinedSignal {
        attribute amplitude : Voltage;
        attribute components : String[0..*];
    }

    item def AcousticWave {
        attribute level : SoundPressureLevel;
        attribute frequency : Frequency;
    }

    item def BatteryStatus {
        attribute charge : Charge;
        attribute voltage : Voltage;
    }

    item def ControlCommand {
        attribute targetMode : OperatingModeKind;
    }

    enum def OperatingModeKind {
        Off = 0;
        Idle = 1;
        ANCOnly = 2;
        ANCMusic = 3;
        Transparency = 4;
    }

    // ---------- Port Definitions ----------
    port def AcousticIn {
        in item ambient : AmbientNoise;
    }

    port def AcousticOut {
        out item wave : AcousticWave;
    }

    port def ElectricalAudioOut {
        out item signal : ElectricalAudioSignal;
    }

    port def ElectricalAudioIn {
        in item signal : ElectricalAudioSignal;
    }

    port def AntiNoiseOut {
        out item anti : AntiNoiseSignal;
    }

    port def AudioStreamIn {
        in item stream : AudioStream;
    }

    port def PowerOut {
        out item status : BatteryStatus;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def PowerIn {
        in item status : BatteryStatus;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def ControlIn {
        in item command : ControlCommand;
    }

    // ---------- Parts ----------

    part def FeedforwardMicrophone {
        port acousticInput : AcousticIn;
        port electricalOutput : ElectricalAudioOut;
        attribute sensitivity : Gain = 0.01;
        attribute location : String = "external";

        action def CaptureAmbient {
            in ambient : AmbientNoise;
            out signal : ElectricalAudioSignal;
        }

        perform action capture : CaptureAmbient {
            in ambient = acousticInput.ambient;
            out signal = electricalOutput.signal;
        }
    }

    part def FeedbackMicrophone {
        port acousticInput : AcousticIn;
        port electricalOutput : ElectricalAudioOut;
        attribute sensitivity : Gain = 0.01;
        attribute location : String = "internal";

        action def MonitorLeakage {
            in ambient : AmbientNoise;
            out signal : ElectricalAudioSignal;
        }

        perform action monitor : MonitorLeakage {
            in ambient = acousticInput.ambient;
            out signal = electricalOutput.signal;
        }
    }

    part def BluetoothReceiver {
        port audioOut : ElectricalAudioOut;
        port powerIn : PowerIn;
        attribute supportedCodecs : String[0..*] = {"SBC", "AAC"};
        attribute connected : Boolean = false;

        action def ReceiveStream {
            out stream : ElectricalAudioSignal;
        }

        perform action receive : ReceiveStream {
            out stream = audioOut.signal;
        }
    }

    part def DSP {
        port feedforwardIn : ElectricalAudioIn;
        port feedbackIn : ElectricalAudioIn;
        port bluetoothIn : ElectricalAudioIn;
        port speakerOut : ElectricalAudioOut;
        port powerIn : PowerIn;
        port controlIn : ControlIn;

        attribute processingGain : Gain = 1.0;
        attribute latency : TimeValue = 0.00005;

        action def AnalyzeNoise {
            in ff : ElectricalAudioSignal;
            in fb : ElectricalAudioSignal;
            out anti : AntiNoiseSignal;
        }

        action def CombineSignals {
            in anti : AntiNoiseSignal;
            in music : ElectricalAudioSignal;
            in correction : ElectricalAudioSignal;
            out combined : CombinedSignal;
        }

        perform action analyze : AnalyzeNoise {
            in ff = feedforwardIn.signal;
            in fb = feedbackIn.signal;
            out anti;
        }

        perform action combine : CombineSignals {
            in anti = analyze.anti;
            in music = bluetoothIn.signal;
            in correction = feedbackIn.signal;
            out combined;
        }

        action def DriveSpeaker {
            in combined : CombinedSignal;
            out signal : ElectricalAudioSignal;
        }

        perform action drive : DriveSpeaker {
            in combined = combine.combined;
            out signal = speakerOut.signal;
        }
    }

    part def SpeakerDriver {
        port electricalInput : ElectricalAudioIn;
        port acousticOutput : AcousticOut;
        port powerIn : PowerIn;
        attribute impedance : Real = 32.0;
        attribute frequencyResponse : Frequency[0..*] = {20.0, 20000.0};

        action def Reproduce {
            in signal : ElectricalAudioSignal;
            out wave : AcousticWave;
        }

        perform action reproduce : Reproduce {
            in signal = electricalInput.signal;
            out wave = acousticOutput.wave;
        }
    }

    part def LithiumIonBattery {
        port powerOut : PowerOut;
        attribute capacity : Charge = 600.0;
        attribute nominalVoltage : Voltage = 3.7;
        attribute currentCharge : Charge = 600.0;
        attribute charging : Boolean = false;

        action def SupplyPower {
            out status : BatteryStatus;
        }

        perform action supply : SupplyPower {
            out status = powerOut.status;
        }
    }

    part def UserControls {
        port controlOut : ControlIn;
        attribute currentMode : OperatingModeKind = OperatingModeKind::Off;

        action def SelectMode {
            in mode : OperatingModeKind;
            out command : ControlCommand;
        }
    }

    part def EarCup {
        attribute side : String; // "left" or "right"
        port externalAcoustic : AcousticIn;
        port internalAcoustic : AcousticIn;
        port speakerAcoustic : AcousticOut;

        part feedforwardMic : FeedforwardMicrophone {
            port acousticInput : AcousticIn;
            port electricalOutput : ElectricalAudioOut;
        }
        part feedbackMic : FeedbackMicrophone {
            port acousticInput : AcousticIn;
            port electricalOutput : ElectricalAudioOut;
        }
        part speaker : SpeakerDriver {
            port electricalInput : ElectricalAudioIn;
            port acousticOutput : AcousticOut;
            port powerIn : PowerIn;
        }

        connection externalNoiseToFF connect externalAcoustic -> feedforwardMic.acousticInput;
        connection internalNoiseToFB connect internalAcoustic -> feedbackMic.acousticInput;
        connection speakerToOutput connect speaker.acousticOutput -> speakerAcoustic;
    }

    // ---------- Top-level System ----------
    part def BoseQuietComfortHeadphones {

        port leftExternalAcoustic : AcousticIn;
        port rightExternalAcoustic : AcousticIn;
        port leftInternalAcoustic : AcousticIn;
        port rightInternalAcoustic : AcousticIn;
        port leftSpeakerAcoustic : AcousticOut;
        port rightSpeakerAcoustic : AcousticOut;
        port bluetoothStream : AudioStreamIn;
        port userControl : ControlIn;
        port powerStatus : PowerOut;

        attribute operatingMode : OperatingModeKind = OperatingModeKind::Off;

        part leftEarCup : EarCup {
            attribute side = "left";
        }
        part rightEarCup : EarCup {
            attribute side = "right";
        }

        part bluetooth : BluetoothReceiver {
            port audioOut : ElectricalAudioOut;
            port powerIn : PowerIn;
        }

        part dsp : DSP {
            port feedforwardIn : ElectricalAudioIn;
            port feedbackIn : ElectricalAudioIn;
            port bluetoothIn : ElectricalAudioIn;
            port speakerOut : ElectricalAudioOut;
            port powerIn : PowerIn;
            port controlIn : ControlIn;
        }

        part battery : LithiumIonBattery {
            port powerOut : PowerOut;
        }

        part controls : UserControls {
            port controlOut : ControlIn;
        }

        // External acoustic connections
        connection leftExtAcoustic connect leftExternalAcoustic -> leftEarCup.externalAcoustic;
        connection rightExtAcoustic connect rightExternalAcoustic -> rightEarCup.externalAcoustic;
        connection leftIntAcoustic connect leftInternalAcoustic -> leftEarCup.internalAcoustic;
        connection rightIntAcoustic connect rightInternalAcoustic -> rightEarCup.internalAcoustic;
        connection leftSpeakerOut connect leftEarCup.speakerAcoustic -> leftSpeakerAcoustic;
        connection rightSpeakerOut connect rightEarCup.speakerAcoustic -> rightSpeakerAcoustic;

        // Bluetooth stream to receiver
        connection btStream connect bluetoothStream.stream -> bluetooth.audioOut.signal;

        // Microphone signals to DSP
        connection leftFFtoDSP connect leftEarCup.feedforwardMic.electricalOutput.signal -> dsp.feedforwardIn.signal;
        connection rightFFtoDSP connect rightEarCup.feedforwardMic.electricalOutput.signal -> dsp.feedforwardIn.signal;
        connection leftFBtoDSP connect leftEarCup.feedbackMic.electricalOutput.signal -> dsp.feedbackIn.signal;
        connection rightFBtoDSP connect rightEarCup.feedbackMic.electricalOutput.signal -> dsp.feedbackIn.signal;

        // Bluetooth audio to DSP
        connection btToDSP connect bluetooth.audioOut.signal -> dsp.bluetoothIn.signal;

        // DSP output to speakers
        connection dspToLeftSpeaker connect dsp.speakerOut.signal -> leftEarCup.speaker.electricalInput.signal;
        connection dspToRightSpeaker connect dsp.speakerOut.signal -> rightEarCup.speaker.electricalInput.signal;

        // Power distribution
        connection batteryToBluetooth connect battery.powerOut -> bluetooth.powerIn;
        connection batteryToDSP connect battery.powerOut -> dsp.powerIn;
        connection batteryToLeftSpeaker connect battery.powerOut -> leftEarCup.speaker.powerIn;
        connection batteryToRightSpeaker connect battery.powerOut -> rightEarCup.speaker.powerIn;
        connection batteryStatusOut connect battery.powerOut -> powerStatus;

        // Control
        connection userControlToDSP connect userControl.command -> dsp.controlIn.command;
        connection userControlToControls connect userControl.command -> controls.controlOut.command;

        // ---------- State Machine ----------
        state def OperatingStateMachine {
            entry action { operatingMode = OperatingModeKind::Off; }

            state Off {
                entry action { operatingMode = OperatingModeKind::Off; }
                // All subsystems unpowered
            }

            state Idle {
                entry action { operatingMode = OperatingModeKind::Idle; }
                // Powered on, no ANC, no music
            }

            state ANCOnly {
                entry action { operatingMode = OperatingModeKind::ANCOnly; }
                // ANC active, no music playback
            }

            state ANCMusic {
                entry action { operatingMode = OperatingModeKind::ANCMusic; }
                // ANC active with music playback
            }

            state Transparency {
                entry action { operatingMode = OperatingModeKind::Transparency; }
                // Microphones pass through ambient sound
            }

            transition offToIdle
                from Off to Idle
                when (userControl.command.targetMode == OperatingModeKind::Idle);

            transition idleToOff
                from Idle to Off
                when (userControl.command.targetMode == OperatingModeKind::Off);

            transition idleToANCOnly
                from Idle to ANCOnly
                when (userControl.command.targetMode == OperatingModeKind::ANCOnly);

            transition ancOnlyToIdle
                from ANCOnly to Idle
                when (userControl.command.targetMode == OperatingModeKind::Idle);

            transition ancOnlyToANCMusic
                from ANCOnly to ANCMusic
                when (userControl.command.targetMode == OperatingModeKind::ANCMusic);

            transition ancMusicToANCOnly
                from ANCMusic to ANCOnly
                when (userControl.command.targetMode == OperatingModeKind::ANCOnly);

            transition ancMusicToTransparency
                from ANCMusic to Transparency
                when (userControl.command.targetMode == OperatingModeKind::Transparency);

            transition transparencyToANCMusic
                from Transparency to ANCMusic
                when (userControl.command.targetMode == OperatingModeKind::ANCMusic);

            transition anyToOff
                from Idle, ANCOnly, ANCMusic, Transparency to Off
                when (userControl.command.targetMode == OperatingModeKind::Off);
        }

        exhibit state operatingBehavior : OperatingStateMachine;

        // ---------- Requirements ----------
        requirement def NoiseCancellationRequirement {
            doc /* The system shall actively cancel ambient environmental noise using dual-microphone technology. */
            attribute minAttenuation : SoundPressureLevel = 20.0;
            subject headphones : BoseQuietComfortHeadphones;
            require headphones.operatingMode == OperatingModeKind::ANCOnly or
                    headphones.operatingMode == OperatingModeKind::ANCMusic;
        }

        requirement def DualMicrophoneRequirement {
            doc /* Each ear cup shall contain an external feedforward microphone and an internal feedback microphone. */
            subject earCup : EarCup;
            require earCup.feedforwardMic.location == "external" and
                    earCup.feedbackMic.location == "internal";
        }

        requirement def DSPProcessingRequirement {
            doc /* The DSP shall generate an anti-noise signal that is the phase inverse of detected ambient noise. */
            subject dsp : DSP;
            require dsp.analyze.anti.phaseShift ~= 3.14159;
        }

        requirement def BluetoothAudioRequirement {
            doc /* The system shall receive desired audio streams via a wireless Bluetooth receiver. */
            subject receiver : BluetoothReceiver;
            require receiver.connected == true;
        }

        requirement def BatteryPowerRequirement {
            doc /* The entire active system shall be powered by an internal rechargeable Lithium-Ion battery. */
            subject battery : LithiumIonBattery;
            require battery.nominalVoltage >= 3.0 and battery.capacity >= 500.0;
        }

        requirement def OperatingModesRequirement {
            doc /* The system shall support Off, Idle, ANC-only, ANC with music, and Transparency operating modes. */
            subject headphones : BoseQuietComfortHeadphones;
            require headphones.operatingBehavior.Off.exists and
                    headphones.operatingBehavior.Idle.exists and
                    headphones.operatingBehavior.ANCOnly.exists and
                    headphones.operatingBehavior.ANCMusic.exists and
                    headphones.operatingBehavior.Transparency.exists;
        }

        requirement def TransparencyRequirement {
            doc /* In Transparency mode, the system shall use microphones to pass ambient sound to the listener. */
            subject headphones : BoseQuietComfortHeadphones;
            require headphones.operatingMode == OperatingModeKind::Transparency implies
                    headphones.leftEarCup.feedforwardMic.sensitivity > 0;
        }

        requirement def SpeakerFidelityRequirement {
            doc /* The speaker driver shall reproduce both music and anti-noise waves with high fidelity. */
            subject speaker : SpeakerDriver;
            require speaker.frequencyResponse->includes(20.0) and
                    speaker.frequencyResponse->includes(20000.0);
        }

        requirement def SignalCombinationRequirement {
            doc /* The DSP shall combine the anti-noise signal, music stream, and feedback correction into a single output signal. */
            subject dsp : DSP;
            require dsp.combine.combined.components->size() >= 3;
        }

        requirement def DestructiveInterferenceRequirement {
            doc /* The reproduced anti-noise wave shall physically cancel incoming environmental sound waves via destructive interference. */
            subject headphones : BoseQuietComfortHeadphones;
            require headphones.dsp.analyze.anti.phaseShift ~= 3.14159;
        }

        // Requirement satisfaction
        satisfy dualMicReq : DualMicrophoneRequirement by leftEarCup;
        satisfy dualMicReqRight : DualMicrophoneRequirement by rightEarCup;
        satisfy noiseCancelReq : NoiseCancellationRequirement by operatingBehavior;
        satisfy dspReq : DSPProcessingRequirement by dsp;
        satisfy btReq : BluetoothAudioRequirement by bluetooth;
        satisfy battReq : BatteryPowerRequirement by battery;
        satisfy modesReq : OperatingModesRequirement by operatingBehavior;
        satisfy transReq : TransparencyRequirement by operatingBehavior;
        satisfy speakerReq : SpeakerFidelityRequirement by leftEarCup.speaker;
        satisfy speakerReqRight : SpeakerFidelityRequirement by rightEarCup.speaker;
        satisfy combineReq : SignalCombinationRequirement by dsp;
        satisfy interferenceReq : DestructiveInterferenceRequirement by dsp;
    }

}
