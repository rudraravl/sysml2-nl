package ExtronDTPCrossPoint84 {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type EfficiencyValue :> Real { unit '%'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type LatencyValue :> Real { unit 'ms'; }
    value type TemperatureValue :> Real { unit 'degC'; }
    value type DataRateValue :> Real { unit 'Gbps'; }
    value type SoundLevelValue :> Real { unit 'dB'; }
    value type LengthValue :> Real { unit 'mm'; }
    value type TimeValue :> Real { unit 's'; }
    value type HorizontalRes :> Integer;
    value type VerticalRes :> Integer;
    value type FrameRateValue :> Real { unit 'Hz'; }

    // ===== Enumerations =====
    enum def ControlMode { manual; automatic; scheduled; }
    enum def SignalState { active; inactive; unknown; }
    enum def AudioFormatKind { mono; stereo; surround51; surround71; }
    enum def PowerState { off; standby; on; fault; }
    enum def CommandKind { switchRoute; setScaler; setAudio; queryStatus; authenticate; updateFirmware; }
    enum def ColorSpaceKind { RGB; YCbCr444; YCbCr422; }

    // ===== Item Types =====
    item def VideoSignal {
        attribute horizontalResolution : HorizontalRes;
        attribute verticalResolution : VerticalRes;
        attribute frameRate : FrameRateValue;
        attribute bitDepth : Integer;
        attribute colorSpace : ColorSpaceKind;
        attribute dataRate : DataRateValue;
        attribute signalState : SignalState;
    }

    item def AudioSignal {
        attribute format : AudioFormatKind;
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : Integer;
        attribute channels : Integer;
        attribute level : SoundLevelValue;
        attribute signalState : SignalState;
    }

    item def Command {
        attribute commandKind : CommandKind;
        attribute sourceAddress : String;
        attribute targetAddress : String;
        attribute payload : String;
        attribute timestamp : TimeValue;
        attribute authenticated : Boolean;
    }

    item def EqualizerSettings {
        attribute band1 : SoundLevelValue;
        attribute band2 : SoundLevelValue;
        attribute band3 : SoundLevelValue;
        attribute band4 : SoundLevelValue;
        attribute band5 : SoundLevelValue;
        attribute band6 : SoundLevelValue;
        attribute band7 : SoundLevelValue;
        attribute band8 : SoundLevelValue;
        attribute band9 : SoundLevelValue;
        attribute band10 : SoundLevelValue;
    }

    item def RoutingAssignment {
        attribute inputIndex : Integer;
        attribute outputIndices : Integer[*];
        attribute signalType : String;
    }

    // ===== Port Definitions =====
    port def VideoInPort {
        attribute index : Integer;
        item videoIn : VideoSignal;
    }

    port def VideoOutPort {
        attribute index : Integer;
        item videoOut : VideoSignal;
    }

    port def AudioInPort {
        attribute index : Integer;
        item audioIn : AudioSignal;
    }

    port def AudioOutPort {
        attribute index : Integer;
        item audioOut : AudioSignal;
    }

    port def ControlNetworkPort {
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute firmwareVersion : String;
        item cmdIn : Command;
        item cmdOut : Command;
    }

    port def ACInletPort {
        attribute voltage : Voltage;
        attribute frequency : FrequencyValue;
        attribute maxCurrent : Current;
    }

    port def DCOutputPort {
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
    }

    // ===== Requirements =====
    requirement def MatrixRoutingReq {
        doc /* The matrix switcher shall route any of 8 video/audio inputs to any combination of 8 outputs. */
        subject matrixUnit : MatrixSwitcher;
        attribute inputCount : Integer = 8;
        attribute outputCount : Integer = 8;
        assert matrixUnit.videoInputCount == inputCount;
        assert matrixUnit.videoOutputCount == outputCount;
    }

    requirement def ScalerLatencyReq {
        doc /* Video scaler processing latency shall not exceed 5 ms to prevent lip-sync issues. */
        subject scalerUnit : VideoScaler;
        attribute maxLatency : LatencyValue = 5.0 [ms];
        assert scalerUnit.processingLatency <= maxLatency;
    }

    requirement def ScalerUpscale4KReq {
        doc /* Each scaler shall upscale to 4K UHD resolution (3840x2160). */
        subject scalerUnit : VideoScaler;
        attribute targetHorizontal : HorizontalRes = 3840;
        attribute targetVertical : VerticalRes = 2160;
        assert scalerUnit.maxOutputHorizontal >= targetHorizontal;
        assert scalerUnit.maxOutputVertical >= targetVertical;
    }

    requirement def AudioProcessingReq {
        doc /* Audio processor shall mix sources, apply a 10-band equalizer, and process dynamic range. */
        subject audioUnit : AudioProcessor;
        assert audioUnit.equalizerBands == 10;
    }

    requirement def AudioFormatSupportReq {
        doc /* Audio processor shall handle stereo through 7.1 surround sound formats. */
        subject audioUnit : AudioProcessor;
        assert audioUnit.supportsStereo == true;
        assert audioUnit.supportsSurround71 == true;
    }

    requirement def ControlAuthReq {
        doc /* Control system shall authenticate all commands before execution. */
        subject controllerUnit : ControlSystem;
        assert controllerUnit.requiresAuthentication == true;
    }

    requirement def ControlNetworkReq {
        doc /* Control system shall have its own network connection with IP and MAC address. */
        subject controllerUnit : ControlSystem;
        assert controllerUnit.ipAddress <> "";
        assert controllerUnit.macAddress <> "";
    }

    requirement def PowerEfficiencyReq {
        doc /* Power supply shall achieve at least 88 percent efficiency. */
        subject psuUnit : PowerDistribution;
        attribute minEfficiency : EfficiencyValue = 88.0 [%];
        assert psuUnit.efficiency >= minEfficiency;
    }

    requirement def PowerOutputReq {
        doc /* Power supply shall output 12 V DC for internal electronics. */
        subject psuUnit : PowerDistribution;
        attribute nominalVoltage : Voltage = 12.0 [V];
        assert psuUnit.outputVoltage == nominalVoltage;
    }

    requirement def RackMountableReq {
        doc /* System shall be rack-mountable in a standard equipment rack. */
        subject enclosureUnit : Enclosure;
        assert enclosureUnit.rackMountable == true;
    }

    // ===== Part Definitions =====
    part def MatrixSwitcher {
        port videoInputs[8] : VideoInPort;
        port videoOutputs[8] : VideoOutPort;
        port audioInputs[8] : AudioInPort;
        port audioOutputs[8] : AudioOutPort;

        attribute videoInputCount : Integer = 8;
        attribute videoOutputCount : Integer = 8;
        attribute controlMode : ControlMode = manual;
        attribute switchingLatency : LatencyValue = 0.5 [ms];
        attribute routingAssignments : RoutingAssignment[*];
        attribute autoDetectEnabled : Boolean = true;
        attribute scheduleEnabled : Boolean = false;

        state matrixState {
            entry; then idle;
            state idle;
            transition idle -> switching when routeCommandReceived;
            state switching;
            transition switching -> routed when routingComplete;
            transition switching -> errorState when routingFailed;
            state routed;
            transition routed -> idle when idleRequested;
            state errorState;
            transition errorState -> idle when errorAcknowledged;
        }

        action routeSignal {
            in sourceIndex : Integer;
            in targetIndices : Integer[*];
            in signalType : String;
        }

        action detectSignal {
            in inputIndex : Integer;
            out detectedState : SignalState;
        }

        action updateRoutingTable {
            in assignment : RoutingAssignment;
        }
    }

    part def VideoScaler {
        port input : VideoInPort;
        port output : VideoOutPort;

        attribute supports4K : Boolean = true;
        attribute processingLatency : LatencyValue = 2.0 [ms];
        attribute maxInputHorizontal : HorizontalRes = 3840;
        attribute maxInputVertical : VerticalRes = 2160;
        attribute maxOutputHorizontal : HorizontalRes = 3840;
        attribute maxOutputVertical : VerticalRes = 2160;
        attribute scalingAlgorithms : String[*] = {"bicubic", "edgeAdaptive", "motionAdaptive"};

        state scalerState {
            entry; then passthrough;
            state passthrough;
            transition passthrough -> upscaling when resolutionMismatch;
            state upscaling;
            transition upscaling -> enhancing when upscaleComplete;
            state enhancing;
            transition enhancing -> passthrough when outputStable;
        }

        action scale {
            in inputSignal : VideoSignal;
            in targetHorizontal : HorizontalRes;
            in targetVertical : VerticalRes;
            out outputSignal : VideoSignal;
        }

        action enhance {
            in inputSignal : VideoSignal;
            out outputSignal : VideoSignal;
        }
    }

    part def AudioProcessor {
        port audioInputs[8] : AudioInPort;
        port audioOutputs[8] : AudioOutPort;

        attribute equalizerBands : Integer = 10;
        attribute supportsStereo : Boolean = true;
        attribute supportsSurround51 : Boolean = true;
        attribute supportsSurround71 : Boolean = true;
        attribute supportedFormats : AudioFormatKind[*] = {mono, stereo, surround51, surround71};
        attribute dynamicRange : SoundLevelValue = 96.0 [dB];
        attribute maxChannels : Integer = 8;
        attribute mixingEnabled : Boolean = true;
        attribute compressionEnabled : Boolean = true;

        state audioState {
            entry; then monitoring;
            state monitoring;
            transition monitoring -> mixing when multipleInputsActive;
            state mixing;
            transition mixing -> equalizing when mixComplete;
            state equalizing;
            transition equalizing -> compressing when eqApplied;
            state compressing;
            transition compressing -> monitoring when processingComplete;
        }

        action mix {
            in inputSignals : AudioSignal[*];
            out mixedSignal : AudioSignal;
        }

        action applyEqualizer {
            in inputSignal : AudioSignal;
            in settings : EqualizerSettings;
            out outputSignal : AudioSignal;
        }

        action compressDynamicRange {
            in inputSignal : AudioSignal;
            out outputSignal : AudioSignal;
        }
    }

    part def ControlSystem {
        port network : ControlNetworkPort;

        attribute ipAddress : String = "192.168.1.100";
        attribute macAddress : String = "00:05:F9:00:00:01";
        attribute firmwareVersion : String = "1.0.0";
        attribute requiresAuthentication : Boolean = true;
        attribute authenticatedClients : String[*];
        attribute commandQueue : Command[*];

        state controlState {
            entry; then listening;
            state listening;
            transition listening -> authenticating when commandReceived;
            state authenticating;
            transition authenticating -> executing when credentialsValid;
            transition authenticating -> listening when credentialsInvalid;
            state executing;
            transition executing -> listening when executionComplete;
            transition executing -> faultState when executionError;
            state faultState;
            transition faultState -> listening when faultReset;
        }

        action authenticate {
            in command : Command;
            out valid : Boolean;
        }

        action executeCommand {
            in command : Command;
        }

        action updateFirmware {
            in version : String;
        }
    }

    part def PowerDistribution {
        port acInlet : ACInletPort;
        port dcOutput : DCOutputPort;

        attribute inputVoltage : Voltage = 120.0 [V];
        attribute outputVoltage : Voltage = 12.0 [V];
        attribute efficiency : EfficiencyValue = 90.0 [%];
        attribute ratedPower : Power = 250.0 [W];
        attribute operatingTemperature : TemperatureValue = 40.0 [degC];
        attribute overvoltageProtection : Boolean = true;
        attribute overcurrentProtection : Boolean = true;
        attribute overheatingProtection : Boolean = true;

        state powerState {
            entry; then standby;
            state standby;
            transition standby -> active when powerApplied;
            state active;
            transition active -> fault when overvoltageDetected;
            transition active -> fault when overcurrentDetected;
            transition active -> fault when overheatingDetected;
            state fault;
            transition fault -> standby when faultConditionCleared;
        }

        action convertACtoDC {
            in acVoltage : Voltage;
            out dcVoltage : Voltage;
        }

        action monitorOutput {
            out voltage : Voltage;
            out current : Current;
        }
    }

    part def Enclosure {
        attribute rackMountable : Boolean = true;
        attribute rackUnits : Integer = 4;
        attribute width : LengthValue = 432.0 [mm];
        attribute depth : LengthValue = 356.0 [mm];
        attribute height : LengthValue = 178.0 [mm];
        attribute coolingFanCount : Integer = 2;
        attribute ventilationSlots : Integer = 8;
        attribute finishColor : String = "black";
    }

    // ===== System Definition =====
    part def ExtronDTPCrossPoint84 {
        attribute modelName : String = "DTP CrossPoint 84 4K";
        attribute manufacturer : String = "Extron";
        attribute productCategory : String = "Professional AV Matrix Switcher";
        attribute targetEnvironments : String[*] = {"corporate boardroom", "university lecture hall", "command center"};
        attribute maxVideoResolution : String = "4K UHD";
        attribute inputCapacity : Integer = 8;
        attribute outputCapacity : Integer = 8;

        port extVideoIn[8] : VideoInPort;
        port extVideoOut[8] : VideoOutPort;
        port extAudioIn[8] : AudioInPort;
        port extAudioOut[8] : AudioOutPort;
        port networkPort : ControlNetworkPort;
        port acInlet : ACInletPort;

        part matrix : MatrixSwitcher;
        part scaler1 : VideoScaler;
        part scaler2 : VideoScaler;
        part audioProc : AudioProcessor;
        part controller : ControlSystem;
        part psu : PowerDistribution;
        part enclosure : Enclosure;

        // External video inputs delegate to matrix
        connect extVideoIn to matrix.videoInputs;
        // External audio inputs delegate to matrix
        connect extAudioIn to matrix.audioInputs;

        // Matrix video outputs 0 and 1 routed through scalers
        connect matrix.videoOutputs[0] to scaler1.input;
        connect matrix.videoOutputs[1] to scaler2.input;
        connect scaler1.output to extVideoOut[0];
        connect scaler2.output to extVideoOut[1];

        // Matrix video outputs 2 through 7 routed directly to external
        connect matrix.videoOutputs[2] to extVideoOut[2];
        connect matrix.videoOutputs[3] to extVideoOut[3];
        connect matrix.videoOutputs[4] to extVideoOut[4];
        connect matrix.videoOutputs[5] to extVideoOut[5];
        connect matrix.videoOutputs[6] to extVideoOut[6];
        connect matrix.videoOutputs[7] to extVideoOut[7];

        // All matrix audio outputs routed through audio processor
        connect matrix.audioOutputs to audioProc.audioInputs;
        connect audioProc.audioOutputs to extAudioOut;

        // Control system network delegation
        connect networkPort to controller.network;

        // Power inlet to PSU
        connect acInlet to psu.acInlet;

        // PSU DC output powers internal components
        connect psu.dcOutput to matrix;
        connect psu.dcOutput to scaler1;
        connect psu.dcOutput to scaler2;
        connect psu.dcOutput to audioProc;
        connect psu.dcOutput to controller;

        // Requirements satisfaction
        satisfy MatrixRoutingReq by matrix;
        satisfy ScalerLatencyReq by scaler1;
        satisfy ScalerLatencyReq by scaler2;
        satisfy ScalerUpscale4KReq by scaler1;
        satisfy ScalerUpscale4KReq by scaler2;
        satisfy AudioProcessingReq by audioProc;
        satisfy AudioFormatSupportReq by audioProc;
        satisfy ControlAuthReq by controller;
        satisfy ControlNetworkReq by controller;
        satisfy PowerEfficiencyReq by psu;
        satisfy PowerOutputReq by psu;
        satisfy RackMountableReq by enclosure;

        // System-level operational state machine
        state systemOperation {
            entry; then monitoring;
            state monitoring;
            transition monitoring -> commandReceived when userCommandInitiated;
            state commandReceived;
            transition commandReceived -> authenticating when controlSystemEngaged;
            state authenticating;
            transition authenticating -> routing when authenticationSuccessful;
            transition authenticating -> monitoring when authenticationFailed;
            state routing;
            transition routing -> scaling when videoPathEstablished;
            state scaling;
            transition scaling -> audioProcessing when scalerOutputReady;
            state audioProcessing;
            transition audioProcessing -> outputActive when audioOutputReady;
            state outputActive;
            transition outputActive -> monitoring when presentationComplete;
        }
    }
}
