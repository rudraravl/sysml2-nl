package GroundPenetratingRadarSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def ElectricPower :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Voltage :> ISQ::voltage {
        unit = SI::volt;
    }

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Velocity :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def DataRate :> ScalarValues::Real {
        unit = "bit/s";
    }

    attribute def RelativePermittivity :> ScalarValues::Real;

    attribute def SignalAmplitude :> ScalarValues::Real {
        unit = "V";
    }

    attribute def SignalToNoiseRatio :> ScalarValues::Real {
        unit = "dB";
    }

    enum def OperatingMode {
        enum idle;
        enum selfTest;
        enum survey;
        enum standby;
        enum fault;
        enum shutdown;
    }

    enum def SurfaceCondition {
        enum drySoil;
        enum wetSoil;
        enum asphalt;
        enum concrete;
        enum ice;
        enum sand;
        enum clay;
    }

    item def RadarPulse {
        attribute centerFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute pulseWidth : TimeDuration;
        attribute peakPower : ElectricPower;
        attribute sequenceNumber : ScalarValues::Integer;
    }

    item def ReflectedEcho {
        attribute timeOfFlight : TimeDuration;
        attribute amplitude : SignalAmplitude;
        attribute phase : ScalarValues::Real;
        attribute estimatedDepth : Length;
        attribute snr : SignalToNoiseRatio;
    }

    item def SubsurfaceProfile {
        attribute scanStartPosition : Length;
        attribute scanEndPosition : Length;
        attribute maximumDepth : Length;
        attribute horizontalResolution : Length;
        attribute verticalResolution : Length;
        attribute dielectricEstimate : RelativePermittivity;
        attribute detectedAnomalyCount : ScalarValues::Integer;
    }

    item def PositionSample {
        attribute distanceAlongTrack : Length;
        attribute speed : Velocity;
        attribute timestamp : TimeDuration;
    }

    item def OperatorCommand {
        attribute requestedMode : OperatingMode;
        attribute requestedScanDepth : Length;
        attribute requestedPulseRate : Frequency;
    }

    item def HealthStatus {
        attribute currentMode : OperatingMode;
        attribute batteryEnergyRemaining : Energy;
        attribute electronicsTemperature : Temperature;
        attribute antennaMatched : ScalarValues::Boolean;
        attribute faultCode : ScalarValues::String;
    }

    port def PowerInputPort {
        in item suppliedVoltage : Voltage;
        in item availablePower : ElectricPower;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def StatusPort {
        out item status : HealthStatus;
    }

    port def PulseTransmitPort {
        out item pulse : RadarPulse;
    }

    port def EchoReceivePort {
        in item echo : ReflectedEcho;
    }

    port def ProfileOutputPort {
        out item profile : SubsurfaceProfile;
    }

    port def PositionPort {
        in item position : PositionSample;
    }

    part def PowerSubsystem {
        attribute nominalVoltage : Voltage = 24 [SI::volt];
        attribute maximumPower : ElectricPower = 450 [SI::watt];
        attribute storedEnergy : Energy = 1800000 [SI::joule];

        port powerIn : PowerInputPort;
        port statusOut : StatusPort;

        action def RegulatePower {
            in item inputVoltage : Voltage;
            out item regulatedVoltage : Voltage;
        }

        action def EstimateEnergyRemaining {
            out item remainingEnergy : Energy;
        }
    }

    part def TimingAndControlUnit {
        attribute clockFrequency : Frequency = 100000000 [SI::hertz];
        attribute pulseRepetitionFrequency : Frequency = 100000 [SI::hertz];
        attribute commandedScanDepth : Length = 3.0 [SI::metre];

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port positionIn : PositionPort;

        action def SchedulePulseSequence {
            in item desiredDepth : Length;
            in item position : PositionSample;
            out item pulse : RadarPulse;
        }

        state def ControllerStateMachine {
            entry action InitializeController;

            state idle;
            state selfTest;
            state survey;
            state standby;
            state fault;
            state shutdown;

            transition idle_to_selfTest
                first idle
                then selfTest
                accept OperatorCommand
                if command.requestedMode == OperatingMode::selfTest;

            transition selfTest_to_standby
                first selfTest
                then standby
                if true;

            transition standby_to_survey
                first standby
                then survey
                accept OperatorCommand
                if command.requestedMode == OperatingMode::survey;

            transition survey_to_standby
                first survey
                then standby
                accept OperatorCommand
                if command.requestedMode == OperatingMode::standby;

            transition any_to_fault
                first idle
                then fault
                if false;

            transition standby_to_shutdown
                first standby
                then shutdown
                accept OperatorCommand
                if command.requestedMode == OperatingMode::shutdown;
        }
    }

    part def PulseGenerator {
        attribute minimumFrequency : Frequency = 10000000 [SI::hertz];
        attribute maximumFrequency : Frequency = 3000000000 [SI::hertz];
        attribute nominalPulseWidth : TimeDuration = 2.0e-9 [SI::second];
        attribute peakTransmitPower : ElectricPower = 250 [SI::watt];

        port pulseOut : PulseTransmitPort;

        action def GenerateImpulse {
            in item centerFrequency : Frequency;
            in item bandwidth : Frequency;
            out item pulse : RadarPulse;
        }
    }

    part def TransmitAntenna {
        attribute centerFrequency : Frequency = 900000000 [SI::hertz];
        attribute bandwidth : Frequency = 700000000 [SI::hertz];
        attribute radiationEfficiency : ScalarValues::Real = 0.82;

        port excitationIn : PulseTransmitPort;
        port fieldOut : PulseTransmitPort;

        action def RadiatePulse {
            in item excitation : RadarPulse;
            out item radiatedPulse : RadarPulse;
        }
    }

    part def ReceiveAntenna {
        attribute centerFrequency : Frequency = 900000000 [SI::hertz];
        attribute bandwidth : Frequency = 700000000 [SI::hertz];
        attribute noiseFigure : SignalToNoiseRatio = 4.5 ["dB"];

        port echoIn : EchoReceivePort;
        port echoOut : EchoReceivePort;

        action def CaptureEcho {
            in item incidentEcho : ReflectedEcho;
            out item receivedEcho : ReflectedEcho;
        }
    }

    part def ReceiverFrontEnd {
        attribute lowNoiseGain : ScalarValues::Real = 38.0;
        attribute analogBandwidth : Frequency = 1200000000 [SI::hertz];
        attribute maximumInputAmplitude : SignalAmplitude = 2.0 [SI::volt];

        port echoIn : EchoReceivePort;
        port echoOut : EchoReceivePort;

        action def AmplifyAndFilter {
            in item rawEcho : ReflectedEcho;
            out item conditionedEcho : ReflectedEcho;
        }
    }

    part def Digitizer {
        attribute sampleRate : Frequency = 5000000000 [SI::hertz];
        attribute resolutionBits : ScalarValues::Integer = 14;
        attribute outputDataRate : DataRate = 70000000000 ["bit/s"];

        port analogEchoIn : EchoReceivePort;
        port digitalEchoOut : EchoReceivePort;

        action def SampleEcho {
            in item conditionedEcho : ReflectedEcho;
            out item sampledEcho : ReflectedEcho;
        }
    }

    part def SignalProcessor {
        attribute maximumDepth : Length = 5.0 [SI::metre];
        attribute nominalVerticalResolution : Length = 0.05 [SI::metre];
        attribute nominalHorizontalResolution : Length = 0.10 [SI::metre];
        attribute minimumDetectionSnr : SignalToNoiseRatio = 8.0 ["dB"];

        port echoIn : EchoReceivePort;
        port positionIn : PositionPort;
        port profileOut : ProfileOutputPort;

        action def RemoveBackground {
            in item sampledEcho : ReflectedEcho;
            out item correctedEcho : ReflectedEcho;
        }

        action def EstimateDepth {
            in item correctedEcho : ReflectedEcho;
            in item dielectric : RelativePermittivity;
            out item depth : Length;
        }

        action def BuildSubsurfaceProfile {
            in item correctedEcho : ReflectedEcho;
            in item position : PositionSample;
            out item profile : SubsurfaceProfile;
        }
    }

    part def OperatorInterface {
        attribute displayRefreshRate : Frequency = 60 [SI::hertz];
        attribute storageCapacity : ScalarValues::Real = 512000000000 ["byte"];

        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port profileIn : ProfileOutputPort;

        action def DisplayProfile {
            in item profile : SubsurfaceProfile;
        }

        action def RecordSurveyData {
            in item profile : SubsurfaceProfile;
            in item status : HealthStatus;
        }
    }

    part def PositioningSubsystem {
        attribute wheelEncoderResolution : Length = 0.002 [SI::metre];
        attribute maximumSurveySpeed : Velocity = 1.5 [SI::metrePerSecond];

        port positionOut : PositionPort;

        action def MeasureAlongTrackPosition {
            out item position : PositionSample;
        }
    }

    part def EnvironmentalInterface {
        attribute assumedSurface : SurfaceCondition = SurfaceCondition::drySoil;
        attribute nominalRelativePermittivity : RelativePermittivity = 6.0;
        attribute maximumSurveyDepth : Length = 5.0 [SI::metre];

        port transmittedWaveIn : PulseTransmitPort;
        port reflectedWaveOut : EchoReceivePort;

        action def PropagatePulseThroughGround {
            in item pulse : RadarPulse;
            out item echo : ReflectedEcho;
        }
    }

    action def PerformGroundPenetratingRadarSurvey {
        in item command : OperatorCommand;
        in item position : PositionSample;
        out item profile : SubsurfaceProfile;

        first start;
        then configureScan;
        then transmitPulse;
        then receiveEcho;
        then processEcho;
        then updateProfile;
        then done;

        action configureScan;
        action transmitPulse;
        action receiveEcho;
        action processEcho;
        action updateProfile;
    }

    part def GroundPenetratingRadarSystem {
        attribute systemName : ScalarValues::String = "Mobile ground-penetrating radar";
        attribute primaryFunction : ScalarValues::String =
            "Transmit short electromagnetic pulses into the ground, receive reflected energy from dielectric discontinuities, and convert the echoes into a spatial subsurface profile for detecting buried objects, layers, voids, and utilities.";
        attribute operatingMode : OperatingMode = OperatingMode::idle;
        attribute nominalSurveySpeed : Velocity = 0.8 [SI::metrePerSecond];
        attribute ratedSurveyDepth : Length = 3.0 [SI::metre];

        port externalPower : PowerInputPort;
        port operatorCommand : CommandPort;
        port operatorStatus : StatusPort;
        port subsurfaceProfile : ProfileOutputPort;

        part power : PowerSubsystem;
        part controller : TimingAndControlUnit;
        part pulseGenerator : PulseGenerator;
        part txAntenna : TransmitAntenna;
        part rxAntenna : ReceiveAntenna;
        part receiver : ReceiverFrontEnd;
        part digitizer : Digitizer;
        part processor : SignalProcessor;
        part userInterface : OperatorInterface;
        part positioning : PositioningSubsystem;
        part ground : EnvironmentalInterface;

        connect externalPower to power.powerIn;
        connect operatorCommand to controller.commandIn;
        connect controller.statusOut to operatorStatus;
        connect userInterface.commandOut to controller.commandIn;
        connect power.statusOut to userInterface.statusIn;

        connect positioning.positionOut to controller.positionIn;
        connect positioning.positionOut to processor.positionIn;

        connect pulseGenerator.pulseOut to txAntenna.excitationIn;
        connect txAntenna.fieldOut to ground.transmittedWaveIn;
        connect ground.reflectedWaveOut to rxAntenna.echoIn;
        connect rxAntenna.echoOut to receiver.echoIn;
        connect receiver.echoOut to digitizer.analogEchoIn;
        connect digitizer.digitalEchoOut to processor.echoIn;
        connect processor.profileOut to subsurfaceProfile;
        connect processor.profileOut to userInterface.profileIn;

        perform action survey : PerformGroundPenetratingRadarSurvey {
            in command = operatorCommand.command;
            in position = positioning.positionOut.position;
            out profile = subsurfaceProfile.profile;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject gpr : GroundPenetratingRadarSystem;

        doc
        /*
         The ground-penetrating radar system shall perform non-invasive subsurface sensing by transmitting electromagnetic pulses into the ground, receiving reflected echoes, estimating reflector depth from time of flight and dielectric properties, and producing a georeferenced subsurface profile.
         */

        require constraint {
            gpr.ratedSurveyDepth >= 3.0 [SI::metre]
        }
    }

    requirement def DepthPerformanceRequirement {
        subject processor : SignalProcessor;

        doc
        /*
         The signal processor shall support profile generation to at least 3 metres below the surface in nominal dry soil conditions.
         */

        require constraint {
            processor.maximumDepth >= 3.0 [SI::metre]
        }
    }

    requirement def ResolutionRequirement {
        subject processor : SignalProcessor;

        doc
        /*
         The generated subsurface profile shall provide vertical resolution of 0.10 metre or better for shallow utility detection in nominal soil.
         */

        require constraint {
            processor.nominalVerticalResolution <= 0.10 [SI::metre]
        }
    }

    requirement def SurveySpeedRequirement {
        subject positioning : PositioningSubsystem;

        doc
        /*
         The positioning subsystem shall support continuous scanning at walking speed without exceeding the radar pulse scheduling capability.
         */

        require constraint {
            positioning.maximumSurveySpeed >= 1.0 [SI::metrePerSecond]
        }
    }

    requirement def SignalQualityRequirement {
        subject processor : SignalProcessor;

        doc
        /*
         The radar shall reject detections whose echo signal-to-noise ratio is below the minimum detection threshold used for profile construction.
         */

        require constraint {
            processor.minimumDetectionSnr >= 8.0 ["dB"]
        }
    }

    requirement def PowerRequirement {
        subject power : PowerSubsystem;

        doc
        /*
         The power subsystem shall regulate portable input power and support at least 450 watts peak radar operation.
         */

        require constraint {
            power.maximumPower >= 450 [SI::watt]
        }
    }

    satisfy PrimaryFunctionRequirement by GroundPenetratingRadarSystem;
    satisfy DepthPerformanceRequirement by GroundPenetratingRadarSystem::processor;
    satisfy ResolutionRequirement by GroundPenetratingRadarSystem::processor;
    satisfy SurveySpeedRequirement by GroundPenetratingRadarSystem::positioning;
    satisfy SignalQualityRequirement by GroundPenetratingRadarSystem::processor;
    satisfy PowerRequirement by GroundPenetratingRadarSystem::power;
}