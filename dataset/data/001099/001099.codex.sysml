package IncrementalEncoderModel {
    import ScalarValues::*;

    attribute def Voltage;
    attribute def Current;
    attribute def Angle;
    attribute def AngularVelocity;
    attribute def Frequency;
    attribute def Time;
    attribute def Count;
    attribute def Temperature;

    enum def DirectionKind {
        enum clockwise;
        enum counterClockwise;
        enum stationary;
        enum invalid;
    }

    enum def EncoderHealthKind {
        enum nominal;
        enum degraded;
        enum faulted;
    }

    item def SupplyPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def LightBeam {
        attribute intensity : Real;
        attribute wavelength : Real;
    }

    item def DigitalEdge {
        attribute level : Boolean;
        attribute timestamp : Time;
        attribute riseTime : Time;
    }

    item def QuadratureSample {
        attribute channelA : Boolean;
        attribute channelB : Boolean;
        attribute indexZ : Boolean;
        attribute timestamp : Time;
    }

    item def MotionEstimate {
        attribute positionCounts : Count;
        attribute mechanicalAngle : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute direction : DirectionKind;
        attribute valid : Boolean;
    }

    item def DiagnosticReport {
        attribute health : EncoderHealthKind;
        attribute missedTransitionCount : Count;
        attribute illegalStateCount : Count;
        attribute supplyVoltage : Voltage;
        attribute internalTemperature : Temperature;
    }

    port def PowerInputPort {
        in item power : SupplyPower;
    }

    port def LightPort {
        out item beam : LightBeam;
    }

    port def LightReceivePort {
        in item beam : LightBeam;
    }

    port def DigitalSignalOutPort {
        out item edge : DigitalEdge;
    }

    port def DigitalSignalInPort {
        in item edge : DigitalEdge;
    }

    port def QuadratureOutPort {
        out item sample : QuadratureSample;
    }

    port def MotionEstimateOutPort {
        out item estimate : MotionEstimate;
    }

    port def DiagnosticOutPort {
        out item report : DiagnosticReport;
    }

    port def MechanicalShaftPort {
        in attribute shaftAngle : Angle;
        in attribute shaftSpeed : AngularVelocity;
    }

    part def IncrementalEncoderSystem {
        attribute pulsesPerRevolution : Count = 2048;
        attribute countsPerRevolution : Count = 8192;
        attribute maximumShaftSpeed : AngularVelocity;
        attribute maximumOutputFrequency : Frequency;
        attribute supplyNominalVoltage : Voltage = 5.0;
        attribute operatingTemperatureMin : Temperature = -40.0;
        attribute operatingTemperatureMax : Temperature = 85.0;

        port powerIn : PowerInputPort;
        port shaftIn : MechanicalShaftPort;
        port quadratureOut : QuadratureOutPort;
        port motionOut : MotionEstimateOutPort;
        port diagnosticsOut : DiagnosticOutPort;

        part shaftCoupler : ShaftCoupler;
        part codeDisk : IncrementalCodeDisk;
        part lightSource : LightSource;
        part opticalChannelA : OpticalReadHead;
        part opticalChannelB : OpticalReadHead;
        part indexChannelZ : OpticalReadHead;
        part signalConditioner : SignalConditioner;
        part quadratureDecoder : QuadratureDecoder;
        part diagnosticMonitor : DiagnosticMonitor;

        connect shaftIn to shaftCoupler.shaftInput;
        connect shaftCoupler.diskDrive to codeDisk.rotationInput;

        connect lightSource.lightOut to opticalChannelA.lightIn;
        connect lightSource.lightOut to opticalChannelB.lightIn;
        connect lightSource.lightOut to indexChannelZ.lightIn;

        connect codeDisk.trackAWindow to opticalChannelA.modulationInput;
        connect codeDisk.trackBWindow to opticalChannelB.modulationInput;
        connect codeDisk.indexWindow to indexChannelZ.modulationInput;

        connect opticalChannelA.detectorOut to signalConditioner.channelAIn;
        connect opticalChannelB.detectorOut to signalConditioner.channelBIn;
        connect indexChannelZ.detectorOut to signalConditioner.channelZIn;

        connect signalConditioner.quadratureOut to quadratureDecoder.quadratureIn;
        connect signalConditioner.quadratureOut to quadratureOut;

        connect quadratureDecoder.motionOut to motionOut;
        connect signalConditioner.diagnosticOut to diagnosticMonitor.signalDiagnosticsIn;
        connect quadratureDecoder.diagnosticOut to diagnosticMonitor.decoderDiagnosticsIn;
        connect diagnosticMonitor.diagnosticsOut to diagnosticsOut;

        perform action encodeMotion : EncodeIncrementalMotion;
        exhibit state encoderLifecycle : EncoderLifecycle;
    }

    part def ShaftCoupler {
        attribute torsionalCompliance : Real;
        attribute maximumRunout : Real;

        port shaftInput : MechanicalShaftPort;
        port diskDrive : MechanicalShaftPort;
    }

    part def IncrementalCodeDisk {
        attribute lineCount : Count = 2048;
        attribute quadraturePhaseOffset : Angle = 90.0;
        attribute indexPulseWidth : Angle;

        port rotationInput : MechanicalShaftPort;
        port trackAWindow : LightReceivePort;
        port trackBWindow : LightReceivePort;
        port indexWindow : LightReceivePort;
    }

    part def LightSource {
        attribute forwardVoltage : Voltage;
        attribute nominalCurrent : Current;
        attribute opticalIntensity : Real;
        attribute wavelength : Real;

        port power : PowerInputPort;
        port lightOut : LightPort;
    }

    part def OpticalReadHead {
        attribute thresholdHigh : Voltage;
        attribute thresholdLow : Voltage;
        attribute responseTime : Time;

        port lightIn : LightReceivePort;
        port modulationInput : LightReceivePort;
        port detectorOut : DigitalSignalOutPort;
    }

    part def SignalConditioner {
        attribute hysteresis : Voltage;
        attribute debounceTime : Time;
        attribute outputLogicHigh : Voltage = 5.0;
        attribute outputLogicLow : Voltage = 0.0;

        port channelAIn : DigitalSignalInPort;
        port channelBIn : DigitalSignalInPort;
        port channelZIn : DigitalSignalInPort;
        port quadratureOut : QuadratureOutPort;
        port diagnosticOut : DiagnosticOutPort;

        perform action conditionSignals : ConditionOpticalSignals;
    }

    part def QuadratureDecoder {
        attribute count : Count;
        attribute lastA : Boolean;
        attribute lastB : Boolean;
        attribute direction : DirectionKind;
        attribute lastIndexPosition : Count;

        port quadratureIn : QuadratureOutPort;
        port motionOut : MotionEstimateOutPort;
        port diagnosticOut : DiagnosticOutPort;

        perform action decodeQuadrature : DecodeQuadrature;
        exhibit state decodingState : DecoderStateMachine;
    }

    part def DiagnosticMonitor {
        attribute illegalTransitionLimit : Count = 3;
        attribute undervoltageLimit : Voltage = 4.5;
        attribute overtemperatureLimit : Temperature = 85.0;

        port signalDiagnosticsIn : DiagnosticOutPort;
        port decoderDiagnosticsIn : DiagnosticOutPort;
        port diagnosticsOut : DiagnosticOutPort;
    }

    action def EncodeIncrementalMotion {
        in attribute shaftAngle : Angle;
        in attribute shaftSpeed : AngularVelocity;
        out item estimate : MotionEstimate;
        out item diagnostics : DiagnosticReport;

        action sampleOpticalTracks : SampleTracks;
        action conditionEdges : ConditionOpticalSignals;
        action decodeEdges : DecodeQuadrature;
        action publishEstimate : PublishMotionEstimate;

        first sampleOpticalTracks;
        then conditionEdges;
        then decodeEdges;
        then publishEstimate;
    }

    action def SampleTracks {
        in attribute shaftAngle : Angle;
        out item rawChannelA : DigitalEdge;
        out item rawChannelB : DigitalEdge;
        out item rawIndexZ : DigitalEdge;
    }

    action def ConditionOpticalSignals {
        in item rawChannelA : DigitalEdge;
        in item rawChannelB : DigitalEdge;
        in item rawIndexZ : DigitalEdge;
        out item sample : QuadratureSample;
        out item diagnostics : DiagnosticReport;
    }

    action def DecodeQuadrature {
        in item sample : QuadratureSample;
        out item estimate : MotionEstimate;
        out item diagnostics : DiagnosticReport;
    }

    action def PublishMotionEstimate {
        in item estimate : MotionEstimate;
        out item publishedEstimate : MotionEstimate;
    }

    state def EncoderLifecycle {
        state unpowered;
        state initializing;
        state selfTest;
        state tracking;
        state degraded;
        state faulted;

        transition initial then unpowered;
        transition powerApplied first unpowered then initializing;
        transition initializationComplete first initializing then selfTest;
        transition selfTestPassed first selfTest then tracking;
        transition signalMarginal first tracking then degraded;
        transition signalRecovered first degraded then tracking;
        transition unrecoverableFault first tracking then faulted;
        transition degradedFault first degraded then faulted;
        transition powerRemoved first tracking then unpowered;
        transition resetFromFault first faulted then initializing;
    }

    state def DecoderStateMachine {
        state awaitingFirstSample;
        state stable00;
        state stable01;
        state stable10;
        state stable11;
        state illegalTransition;

        transition initial then awaitingFirstSample;
        transition first00 first awaitingFirstSample then stable00;
        transition first01 first awaitingFirstSample then stable01;
        transition first10 first awaitingFirstSample then stable10;
        transition first11 first awaitingFirstSample then stable11;

        transition cw00to01 first stable00 then stable01;
        transition cw01to11 first stable01 then stable11;
        transition cw11to10 first stable11 then stable10;
        transition cw10to00 first stable10 then stable00;

        transition ccw00to10 first stable00 then stable10;
        transition ccw10to11 first stable10 then stable11;
        transition ccw11to01 first stable11 then stable01;
        transition ccw01to00 first stable01 then stable00;

        transition invalidFrom00 first stable00 then illegalTransition;
        transition invalidFrom01 first stable01 then illegalTransition;
        transition invalidFrom10 first stable10 then illegalTransition;
        transition invalidFrom11 first stable11 then illegalTransition;
        transition resync first illegalTransition then awaitingFirstSample;
    }

    requirement def PrimaryFunctionRequirement {
        subject encoder : IncrementalEncoderSystem;

        doc
        /* The system shall convert incremental rotary shaft motion into digital quadrature pulse signals and a derived motion estimate containing relative position, mechanical angle, angular velocity, direction, and validity. */

        require constraint {
            encoder.countsPerRevolution == encoder.pulsesPerRevolution * 4
        }
    }

    requirement def QuadraturePhaseRequirement {
        subject disk : IncrementalCodeDisk;

        doc
        /* Track B shall be spatially offset from Track A by one quarter electrical cycle to support direction detection. */

        require constraint {
            disk.quadraturePhaseOffset == 90.0
        }
    }

    requirement def IndexPulseRequirement {
        subject encoder : IncrementalEncoderSystem;

        doc
        /* The encoder shall provide one index pulse per mechanical revolution for reference alignment. */

        require constraint {
            encoder.codeDisk.lineCount == encoder.pulsesPerRevolution
        }
    }

    requirement def DiagnosticRequirement {
        subject encoder : IncrementalEncoderSystem;

        doc
        /* The encoder shall report degraded or faulted health when illegal quadrature transitions, undervoltage, or overtemperature conditions exceed configured limits. */
    }

    requirement def OutputRateRequirement {
        subject encoder : IncrementalEncoderSystem;

        doc
        /* The signal conditioner and decoder shall support the maximum quadrature edge rate produced by the configured pulse count and maximum shaft speed. */

        require constraint {
            encoder.maximumOutputFrequency >= encoder.pulsesPerRevolution * 4
        }
    }
}