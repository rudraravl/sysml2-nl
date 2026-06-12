package LinearEncoderSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Length {
        :> ISQ::length;
        unit = SI::metre;
    }

    attribute def Velocity {
        :> ISQ::speed;
        unit = SI::metrePerSecond;
    }

    attribute def Acceleration {
        :> ISQ::acceleration;
        unit = SI::metrePerSecondSquared;
    }

    attribute def Time {
        :> ISQ::time;
        unit = SI::second;
    }

    attribute def Voltage {
        :> ISQ::electricPotential;
        unit = SI::volt;
    }

    attribute def Current {
        :> ISQ::electricCurrent;
        unit = SI::ampere;
    }

    attribute def Frequency {
        :> ISQ::frequency;
        unit = SI::hertz;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = SI::kelvin;
    }

    attribute def Resolution {
        :> Length;
    }

    enum def EncoderHealth {
        enum operational;
        enum degraded;
        enum faulted;
        enum unpowered;
    }

    enum def SignalQuality {
        enum valid;
        enum interpolated;
        enum saturated;
        enum lost;
    }

    enum def Direction {
        enum positive;
        enum negative;
        enum stationary;
    }

    item def OpticalPattern {
        attribute pitch : Length;
        attribute indexMarkSpacing : Length;
        attribute contrastRatio : Real;
    }

    item def RawQuadratureSignal {
        attribute channelAHigh : Boolean;
        attribute channelBHigh : Boolean;
        attribute indexHigh : Boolean;
        attribute amplitudeA : Voltage;
        attribute amplitudeB : Voltage;
        attribute frequency : Frequency;
        attribute quality : SignalQuality;
    }

    item def PositionSample {
        attribute absolutePosition : Length;
        attribute incrementalCount : Integer;
        attribute velocity : Velocity;
        attribute direction : Direction;
        attribute sampleTime : Time;
        attribute quality : SignalQuality;
    }

    item def DiagnosticMessage {
        attribute health : EncoderHealth;
        attribute supplyVoltage : Voltage;
        attribute sensorTemperature : Temperature;
        attribute signalQuality : SignalQuality;
        attribute errorCode : Integer;
    }

    item def PowerInput {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
    }

    item def MotionInput {
        attribute displacement : Length;
        attribute velocity : Velocity;
        attribute acceleration : Acceleration;
    }

    port def PowerPort {
        in item power : PowerInput;
    }

    port def MechanicalMeasurementPort {
        in item motion : MotionInput;
    }

    port def OpticalPatternPort {
        out item pattern : OpticalPattern;
    }

    port def RawSignalPort {
        out item rawSignal : RawQuadratureSignal;
    }

    port def PositionDataPort {
        out item position : PositionSample;
    }

    port def DiagnosticPort {
        out item diagnostic : DiagnosticMessage;
    }

    port def HostCommandPort {
        in item resetRequest : Boolean;
        in item zeroRequest : Boolean;
    }

    action def SenseScalePattern {
        in item scalePattern : OpticalPattern;
        in item carriageMotion : MotionInput;
        out item rawSignal : RawQuadratureSignal;
    }

    action def DecodeQuadrature {
        in item rawSignal : RawQuadratureSignal;
        in attribute interpolationFactor : Integer;
        out item sample : PositionSample;
    }

    action def ApplyReferenceZero {
        in item sample : PositionSample;
        in attribute zeroOffset : Length;
        out item correctedSample : PositionSample;
    }

    action def PublishPosition {
        in item correctedSample : PositionSample;
        out item positionOutput : PositionSample;
    }

    action def CheckDiagnostics {
        in item rawSignal : RawQuadratureSignal;
        in item supply : PowerInput;
        out item diagnostic : DiagnosticMessage;
    }

    state def EncoderOperatingState {
        entry action initializeElectronics;
        state unpowered;
        state selfTest;
        state ready;
        state measuring;
        state degraded;
        state fault;

        transition first unpowered;
        transition unpowered_to_selfTest
            first unpowered
            then selfTest
            accept PowerApplied;

        transition selfTest_to_ready
            first selfTest
            then ready
            accept SelfTestPassed;

        transition ready_to_measuring
            first ready
            then measuring
            accept MotionDetected;

        transition measuring_to_ready
            first measuring
            then ready
            accept MotionStopped;

        transition measuring_to_degraded
            first measuring
            then degraded
            accept LowSignalQuality;

        transition degraded_to_measuring
            first degraded
            then measuring
            accept SignalRecovered;

        transition ready_to_fault
            first ready
            then fault
            accept InternalFault;

        transition measuring_to_fault
            first measuring
            then fault
            accept InternalFault;

        transition degraded_to_fault
            first degraded
            then fault
            accept InternalFault;

        transition fault_to_selfTest
            first fault
            then selfTest
            accept ResetCommand;
    }

    part def LinearScale {
        attribute usableTravel : Length = 1.000 [SI::metre];
        attribute gratingPitch : Length = 0.000020 [SI::metre];
        attribute indexSpacing : Length = 0.050 [SI::metre];
        attribute thermalExpansionCoefficient : Real = 0.000010;
        port patternPort : OpticalPatternPort;
    }

    part def ReadHead {
        attribute sensorSupplyVoltage : Voltage = 5.0 [SI::volt];
        attribute maximumSensorCurrent : Current = 0.080 [SI::ampere];
        attribute operatingTemperatureMin : Temperature = 253.15 [SI::kelvin];
        attribute operatingTemperatureMax : Temperature = 343.15 [SI::kelvin];
        attribute nominalAirGap : Length = 0.000800 [SI::metre];
        port powerPort : PowerPort;
        port mechanicalPort : MechanicalMeasurementPort;
        port patternIn : OpticalPatternPort;
        port rawSignalPort : RawSignalPort;

        perform action sense : SenseScalePattern;
    }

    part def SignalConditioner {
        attribute minimumInputAmplitude : Voltage = 0.200 [SI::volt];
        attribute maximumInputAmplitude : Voltage = 3.300 [SI::volt];
        attribute hysteresisVoltage : Voltage = 0.050 [SI::volt];
        port rawInput : RawSignalPort;
        port conditionedOutput : RawSignalPort;
    }

    part def QuadratureDecoder {
        attribute countsPerPitch : Integer = 4;
        attribute interpolationFactor : Integer = 100;
        attribute effectiveResolution : Resolution = 0.000000050 [SI::metre];
        attribute maximumCountFrequency : Frequency = 2000000.0 [SI::hertz];
        port signalInput : RawSignalPort;
        port sampleOutput : PositionDataPort;

        perform action decode : DecodeQuadrature;
    }

    part def PositionProcessor {
        attribute zeroOffset : Length = 0.000000 [SI::metre];
        attribute travelLimitMin : Length = 0.000 [SI::metre];
        attribute travelLimitMax : Length = 1.000 [SI::metre];
        attribute updatePeriod : Time = 0.001 [SI::second];
        port decodedInput : PositionDataPort;
        port commandPort : HostCommandPort;
        port positionOutput : PositionDataPort;

        perform action zeroing : ApplyReferenceZero;
        perform action publishing : PublishPosition;
    }

    part def DiagnosticMonitor {
        attribute signalLossTimeout : Time = 0.010 [SI::second];
        attribute undervoltageThreshold : Voltage = 4.750 [SI::volt];
        attribute overvoltageThreshold : Voltage = 5.250 [SI::volt];
        attribute overTemperatureThreshold : Temperature = 353.15 [SI::kelvin];
        port powerInput : PowerPort;
        port signalInput : RawSignalPort;
        port diagnosticOutput : DiagnosticPort;

        perform action diagnostics : CheckDiagnostics;
    }

    part def MotionControllerInterface {
        attribute communicationUpdatePeriod : Time = 0.001 [SI::second];
        attribute positionLatencyBudget : Time = 0.000500 [SI::second];
        port positionInput : PositionDataPort;
        port diagnosticInput : DiagnosticPort;
        port commandOutput : HostCommandPort;
    }

    part def LinearEncoderAssembly {
        attribute primaryFunction : String =
            "Measure linear displacement of a moving carriage relative to a fixed scale and provide high-resolution digital position feedback to a host controller.";
        attribute measurementRange : Length = 1.000 [SI::metre];
        attribute specifiedAccuracy : Length = 0.000005 [SI::metre];
        attribute specifiedResolution : Resolution = 0.000000050 [SI::metre];
        attribute maximumMeasuredVelocity : Velocity = 2.000 [SI::metrePerSecond];

        port powerInput : PowerPort;
        port motionInput : MechanicalMeasurementPort;
        port positionOutput : PositionDataPort;
        port diagnosticOutput : DiagnosticPort;
        port commandInput : HostCommandPort;

        part scale : LinearScale;
        part readHead : ReadHead;
        part conditioner : SignalConditioner;
        part decoder : QuadratureDecoder;
        part processor : PositionProcessor;
        part monitor : DiagnosticMonitor;
        part hostInterface : MotionControllerInterface;

        connection scalePatternConnection
            connect scale.patternPort to readHead.patternIn;

        connection motionConnection
            connect motionInput to readHead.mechanicalPort;

        connection readHeadSignalConnection
            connect readHead.rawSignalPort to conditioner.rawInput;

        connection conditionedSignalConnection
            connect conditioner.conditionedOutput to decoder.signalInput;

        connection decodedPositionConnection
            connect decoder.sampleOutput to processor.decodedInput;

        connection processedPositionConnection
            connect processor.positionOutput to positionOutput;

        connection powerToReadHeadConnection
            connect powerInput to readHead.powerPort;

        connection powerToMonitorConnection
            connect powerInput to monitor.powerInput;

        connection diagnosticSignalConnection
            connect conditioner.conditionedOutput to monitor.signalInput;

        connection diagnosticOutputConnection
            connect monitor.diagnosticOutput to diagnosticOutput;

        connection commandConnection
            connect commandInput to processor.commandPort;

        exhibit stateMachine : EncoderOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The linear encoder shall convert relative linear motion between the scale and read head into digital position feedback for closed-loop control. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.specifiedResolution <= 0.000000050 [SI::metre]
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The encoder shall measure displacement over the full one meter travel range without wraparound or loss of index reference. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.measurementRange >= 1.000 [SI::metre]
        }
    }

    requirement def AccuracyRequirement {
        doc /* The encoder shall report linear position with maximum static error not exceeding five micrometers over the specified travel range. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.specifiedAccuracy <= 0.000005 [SI::metre]
        }
    }

    requirement def VelocityRequirement {
        doc /* The encoder shall maintain valid position output while the measured carriage velocity is up to two meters per second. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.maximumMeasuredVelocity >= 2.000 [SI::metrePerSecond]
        }
    }

    requirement def DiagnosticRequirement {
        doc /* The encoder shall report degraded or faulted health when signal quality is lost, supply voltage is outside limits, or internal temperature exceeds the specified threshold. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.monitor.signalLossTimeout <= 0.010 [SI::second]
        }
    }

    requirement def LatencyRequirement {
        doc /* The encoder shall publish corrected position samples to the host interface within the latency budget required for motion control. */
        subject encoder : LinearEncoderAssembly;
        require constraint {
            encoder.hostInterface.positionLatencyBudget <= 0.000500 [SI::second]
        }
    }

    part linearEncoderSystem : LinearEncoderAssembly;

    satisfy PrimaryFunctionRequirement by linearEncoderSystem;
    satisfy MeasurementRangeRequirement by linearEncoderSystem;
    satisfy AccuracyRequirement by linearEncoderSystem;
    satisfy VelocityRequirement by linearEncoderSystem;
    satisfy DiagnosticRequirement by linearEncoderSystem;
    satisfy LatencyRequirement by linearEncoderSystem;
}