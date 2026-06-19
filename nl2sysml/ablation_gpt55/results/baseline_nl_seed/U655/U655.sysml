package DopplerRadarHighLevelModel {
    import ScalarValues::*;

    attribute def Frequency_Hz :> Real;
    attribute def Bandwidth_Hz :> Real;
    attribute def Power_W :> Real;
    attribute def Voltage_V :> Real;
    attribute def Current_A :> Real;
    attribute def Gain_dB :> Real;
    attribute def Time_s :> Real;
    attribute def Distance_m :> Real;
    attribute def Velocity_m_per_s :> Real;
    attribute def Acceleration_m_per_s2 :> Real;
    attribute def Angle_deg :> Real;
    attribute def Temperature_C :> Real;
    attribute def Probability :> Real;
    attribute def Ratio :> Real;
    attribute def Count :> Integer;

    enum def RadarMode {
        enum off;
        enum standby;
        enum builtInTest;
        enum calibrating;
        enum search;
        enum track;
        enum fault;
    }

    enum def TrackQuality {
        enum tentative;
        enum confirmed;
        enum coasted;
        enum dropped;
    }

    item def ElectricalPower {
        attribute voltage_V : Voltage_V;
        attribute current_A : Current_A;
        attribute power_W : Power_W;
    }

    item def RadarCommand {
        attribute requestedMode : RadarMode;
        attribute dwellTime_s : Time_s;
        attribute centerAzimuth_deg : Angle_deg;
        attribute azimuthScanWidth_deg : Angle_deg;
        attribute minimumReportRange_m : Distance_m;
        attribute maximumReportRange_m : Distance_m;
    }

    item def RadarStatus {
        attribute currentMode : RadarMode;
        attribute transmitterReady : Boolean;
        attribute receiverReady : Boolean;
        attribute processorReady : Boolean;
        attribute faultPresent : Boolean;
        attribute internalTemperature_C : Temperature_C;
    }

    item def TimingPulse {
        attribute pulseRepetitionFrequency_Hz : Frequency_Hz;
        attribute pulseWidth_s : Time_s;
        attribute sequenceTime_s : Time_s;
    }

    item def RadarEmission {
        attribute carrierFrequency_Hz : Frequency_Hz;
        attribute bandwidth_Hz : Bandwidth_Hz;
        attribute pulseWidth_s : Time_s;
        attribute peakPower_W : Power_W;
        attribute antennaGain_dB : Gain_dB;
        attribute azimuthPointing_deg : Angle_deg;
        attribute elevationPointing_deg : Angle_deg;
    }

    item def RadarEcho {
        attribute carrierFrequency_Hz : Frequency_Hz;
        attribute receivedPower_W : Power_W;
        attribute timeOfFlight_s : Time_s;
        attribute dopplerShift_Hz : Frequency_Hz;
        attribute azimuthAngle_deg : Angle_deg;
        attribute elevationAngle_deg : Angle_deg;
        attribute signalToNoiseRatio_dB : Gain_dB;
    }

    item def RangeDopplerDetection {
        attribute range_m : Distance_m;
        attribute radialVelocity_m_per_s : Velocity_m_per_s;
        attribute azimuthAngle_deg : Angle_deg;
        attribute elevationAngle_deg : Angle_deg;
        attribute signalToNoiseRatio_dB : Gain_dB;
        attribute probabilityOfDetection : Probability;
        attribute falseAlarmProbability : Probability;
    }

    item def TargetTrack {
        attribute trackIdentifier : Count;
        attribute range_m : Distance_m;
        attribute radialVelocity_m_per_s : Velocity_m_per_s;
        attribute azimuthAngle_deg : Angle_deg;
        attribute elevationAngle_deg : Angle_deg;
        attribute radialAcceleration_m_per_s2 : Acceleration_m_per_s2;
        attribute quality : TrackQuality;
        attribute updateTime_s : Time_s;
    }

    item def DisplayReport {
        attribute trackIdentifier : Count;
        attribute range_m : Distance_m;
        attribute radialVelocity_m_per_s : Velocity_m_per_s;
        attribute bearing_deg : Angle_deg;
        attribute quality : TrackQuality;
    }

    port def PowerSourcePort {
        out item power : ElectricalPower;
    }

    port def PowerLoadPort {
        in item power : ElectricalPower;
    }

    port def CommandOutputPort {
        out item command : RadarCommand;
        in item status : RadarStatus;
    }

    port def CommandInputPort {
        in item command : RadarCommand;
        out item status : RadarStatus;
    }

    port def TimingOutputPort {
        out item timing : TimingPulse;
    }

    port def TimingInputPort {
        in item timing : TimingPulse;
    }

    port def EmissionOutputPort {
        out item emission : RadarEmission;
    }

    port def EmissionInputPort {
        in item emission : RadarEmission;
    }

    port def EchoOutputPort {
        out item echo : RadarEcho;
    }

    port def EchoInputPort {
        in item echo : RadarEcho;
    }

    port def DetectionOutputPort {
        out item detection : RangeDopplerDetection;
    }

    port def DetectionInputPort {
        in item detection : RangeDopplerDetection;
    }

    port def TrackOutputPort {
        out item track : TargetTrack;
    }

    port def TrackInputPort {
        in item track : TargetTrack;
    }

    port def DisplayOutputPort {
        out item report : DisplayReport;
    }

    port def DisplayInputPort {
        in item report : DisplayReport;
    }

    constraint def DopplerShiftEquation {
        in carrierFrequency_Hz : Frequency_Hz;
        in radialVelocity_m_per_s : Velocity_m_per_s;
        out dopplerShift_Hz : Frequency_Hz;
        attribute speedOfLight_m_per_s : Velocity_m_per_s = 299792458.0;
        constraint {
            dopplerShift_Hz == (2.0 * radialVelocity_m_per_s * carrierFrequency_Hz) / speedOfLight_m_per_s
        }
    }

    constraint def RangeFromRoundTripTimeEquation {
        in timeOfFlight_s : Time_s;
        out range_m : Distance_m;
        attribute speedOfLight_m_per_s : Velocity_m_per_s = 299792458.0;
        constraint {
            range_m == (speedOfLight_m_per_s * timeOfFlight_s) / 2.0
        }
    }

    action def AcceptOperatorSearchCommand {
        in item operatorCommand : RadarCommand;
        out item validatedCommand : RadarCommand;
    }

    action def GenerateLinearFmWaveform {
        in item command : RadarCommand;
        in item timing : TimingPulse;
        out item waveform : RadarEmission;
    }

    action def AmplifyRadioFrequencyWaveform {
        in item lowPowerWaveform : RadarEmission;
        out item highPowerWaveform : RadarEmission;
    }

    action def RadiateEnergy {
        in item highPowerWaveform : RadarEmission;
        out item radiatedEmission : RadarEmission;
    }

    action def CollectEchoEnergy {
        in item radiatedEmission : RadarEmission;
        out item receivedEcho : RadarEcho;
    }

    action def DownConvertAndDigitizeEcho {
        in item analogEcho : RadarEcho;
        out item digitalEcho : RadarEcho;
    }

    action def MeasureRangeAndDoppler {
        in item digitalEcho : RadarEcho;
        out item detection : RangeDopplerDetection;
    }

    action def AssociateAndFilterTracks {
        in item detection : RangeDopplerDetection;
        out item track : TargetTrack;
    }

    action def PublishDisplayReport {
        in item track : TargetTrack;
        out item report : DisplayReport;
    }

    action def DopplerSurveillanceCycle {
        in item operatorCommand : RadarCommand;
        out item displayReport : DisplayReport;

        action acceptCommand : AcceptOperatorSearchCommand;
        action generateWaveform : GenerateLinearFmWaveform;
        action amplifyWaveform : AmplifyRadioFrequencyWaveform;
        action radiateEnergy : RadiateEnergy;
        action collectEcho : CollectEchoEnergy;
        action digitizeEcho : DownConvertAndDigitizeEcho;
        action measureDetection : MeasureRangeAndDoppler;
        action updateTrack : AssociateAndFilterTracks;
        action publishReport : PublishDisplayReport;

        flow operatorCommand to acceptCommand.operatorCommand;
        flow acceptCommand.validatedCommand to generateWaveform.command;
        flow generateWaveform.waveform to amplifyWaveform.lowPowerWaveform;
        flow amplifyWaveform.highPowerWaveform to radiateEnergy.highPowerWaveform;
        flow radiateEnergy.radiatedEmission to collectEcho.radiatedEmission;
        flow collectEcho.receivedEcho to digitizeEcho.analogEcho;
        flow digitizeEcho.digitalEcho to measureDetection.digitalEcho;
        flow measureDetection.detection to updateTrack.detection;
        flow updateTrack.track to publishReport.track;
        flow publishReport.report to displayReport;
    }

    state def DopplerRadarOperatingStates {
        entry; then poweredOff;

        state poweredOff;
        state standby;
        state builtInTest;
        state calibrating;
        state searching;
        state tracking;
        state faulted;

        transition powerOn first poweredOff then standby;
        transition beginBuiltInTest first standby then builtInTest;
        transition builtInTestPassed first builtInTest then calibrating;
        transition calibrationComplete first calibrating then searching;
        transition detectionConfirmed first searching then tracking;
        transition trackLost first tracking then searching;
        transition stopRadiating first searching then standby;
        transition faultDetectedFromStandby first standby then faulted;
        transition faultDetectedFromSearch first searching then faulted;
        transition faultDetectedFromTrack first tracking then faulted;
        transition resetAfterFault first faulted then standby;
        transition powerOffFromStandby first standby then poweredOff;
    }

    part def PowerSupply {
        attribute nominalVoltage_V : Voltage_V = 28.0;
        attribute maximumPower_W : Power_W = 750.0;

        port controllerPower : PowerSourcePort;
        port timingPower : PowerSourcePort;
        port transmitterPower : PowerSourcePort;
        port receiverPower : PowerSourcePort;
        port processorPower : PowerSourcePort;
        port displayPower : PowerSourcePort;
    }

    part def TimingReference {
        attribute referenceFrequency_Hz : Frequency_Hz = 10000000.0;
        attribute nominalPulseRepetitionFrequency_Hz : Frequency_Hz = 2000.0;
        attribute timingJitter_s : Time_s = 0.000000002;

        port power : PowerLoadPort;
        port timingOut : TimingOutputPort;
    }

    part def RadarController {
        attribute commandedMode : RadarMode = RadarMode::standby;
        attribute healthPollPeriod_s : Time_s = 1.0;

        port power : PowerLoadPort;
        port operatorInput : CommandInputPort;
        port waveformControl : CommandOutputPort;
        port transmitterControl : CommandOutputPort;
        port receiverControl : CommandOutputPort;
        port processorControl : CommandOutputPort;
        port statusToOperator : CommandOutputPort;
    }

    part def WaveformGenerator {
        attribute centerFrequency_Hz : Frequency_Hz = 24125000000.0;
        attribute chirpBandwidth_Hz : Bandwidth_Hz = 150000000.0;
        attribute pulseWidth_s : Time_s = 0.00002;

        port power : PowerLoadPort;
        port control : CommandInputPort;
        port timing : TimingInputPort;
        port waveformOut : EmissionOutputPort;

        perform action generate : GenerateLinearFmWaveform;
    }

    part def RadioFrequencyTransmitter {
        attribute peakTransmitPower_W : Power_W = 500.0;
        attribute transmitGain_dB : Gain_dB = 43.0;
        attribute dutyCycle : Ratio = 0.08;

        port power : PowerLoadPort;
        port control : CommandInputPort;
        port waveformIn : EmissionInputPort;
        port amplifiedOut : EmissionOutputPort;

        perform action amplify : AmplifyRadioFrequencyWaveform;
    }

    part def TransmitReceiveDuplexer {
        attribute isolation_dB : Gain_dB = 65.0;
        attribute insertionLoss_dB : Gain_dB = 1.2;

        port transmitIn : EmissionInputPort;
        port antennaTransmitOut : EmissionOutputPort;
        port antennaReceiveIn : EchoInputPort;
        port receiverOut : EchoOutputPort;
    }

    part def PlanarArrayAntenna {
        attribute apertureGain_dB : Gain_dB = 31.0;
        attribute azimuthBeamwidth_deg : Angle_deg = 3.0;
        attribute elevationBeamwidth_deg : Angle_deg = 12.0;
        attribute mechanicalAzimuthLimit_deg : Angle_deg = 120.0;

        port transmitIn : EmissionInputPort;
        port radiatedOut : EmissionOutputPort;
        port echoIn : EchoInputPort;
        port echoOut : EchoOutputPort;

        perform action radiate : RadiateEnergy;
        perform action collect : CollectEchoEnergy;
    }

    part def RadioFrequencyReceiver {
        attribute noiseFigure_dB : Gain_dB = 4.0;
        attribute receiverGain_dB : Gain_dB = 38.0;
        attribute instantaneousBandwidth_Hz : Bandwidth_Hz = 200000000.0;

        port power : PowerLoadPort;
        port control : CommandInputPort;
        port echoIn : EchoInputPort;
        port digitizedEchoOut : EchoOutputPort;

        perform action digitize : DownConvertAndDigitizeEcho;
    }

    part def SignalProcessor {
        attribute coherentProcessingInterval_s : Time_s = 0.064;
        attribute rangeResolution_m : Distance_m = 1.0;
        attribute velocityResolution_m_per_s : Velocity_m_per_s = 0.2;
        attribute constantFalseAlarmRate : Probability = 0.000001;

        port power : PowerLoadPort;
        port control : CommandInputPort;
        port digitizedEchoIn : EchoInputPort;
        port detectionOut : DetectionOutputPort;

        perform action measure : MeasureRangeAndDoppler;
    }

    part def TrackManager {
        attribute maximumTrackCount : Count = 256;
        attribute confirmationDetectionsRequired : Count = 3;
        attribute coastTime_s : Time_s = 4.0;

        port power : PowerLoadPort;
        port detectionIn : DetectionInputPort;
        port trackOut : TrackOutputPort;

        perform action associate : AssociateAndFilterTracks;
    }

    part def OperatorInterface {
        attribute displayRefreshPeriod_s : Time_s = 0.25;

        port power : PowerLoadPort;
        port commandOut : CommandOutputPort;
        port statusIn : CommandInputPort;
        port trackDisplayIn : DisplayInputPort;

        perform action publish : PublishDisplayReport;
    }

    part def TargetEnvironment {
        attribute representativeTargetRange_m : Distance_m = 800.0;
        attribute representativeTargetRadialVelocity_m_per_s : Velocity_m_per_s = 25.0;
        attribute representativeTargetAcceleration_m_per_s2 : Acceleration_m_per_s2 = 1.5;
        attribute representativeTargetAzimuth_deg : Angle_deg = 15.0;

        port incidentEmission : EmissionInputPort;
        port reflectedEcho : EchoOutputPort;
    }

    part def DopplerRadarSystem {
        doc /* Primary high-level function: transmit coherent radio-frequency energy, receive echoes reflected by objects, measure Doppler frequency shift and round-trip delay, and produce tracks reporting target range, bearing, and radial velocity. */

        attribute carrierFrequency_Hz : Frequency_Hz = 24125000000.0;
        attribute operatingBandwidth_Hz : Bandwidth_Hz = 150000000.0;
        attribute maximumInstrumentedRange_m : Distance_m = 2500.0;
        attribute minimumDetectableRadialVelocity_m_per_s : Velocity_m_per_s = 0.5;
        attribute maximumReportableRadialVelocity_m_per_s : Velocity_m_per_s = 120.0;
        attribute nominalRangeResolution_m : Distance_m = 1.0;
        attribute nominalVelocityResolution_m_per_s : Velocity_m_per_s = 0.2;
        attribute probabilityOfDetectionAtReferenceTarget : Probability = 0.90;
        attribute falseAlarmProbabilityPerResolutionCell : Probability = 0.000001;

        port externalPowerInput : PowerLoadPort;
        port operatorCommandInput : CommandInputPort;
        port operatorDisplayOutput : DisplayOutputPort;

        part powerSupply : PowerSupply;
        part timingReference : TimingReference;
        part controller : RadarController;
        part waveformGenerator : WaveformGenerator;
        part transmitter : RadioFrequencyTransmitter;
        part duplexer : TransmitReceiveDuplexer;
        part antenna : PlanarArrayAntenna;
        part receiver : RadioFrequencyReceiver;
        part signalProcessor : SignalProcessor;
        part trackManager : TrackManager;
        part operatorInterface : OperatorInterface;
        part targetEnvironment : TargetEnvironment;

        exhibit state operatingState : DopplerRadarOperatingStates;
        perform action surveillanceCycle : DopplerSurveillanceCycle;

        connect externalPowerInput to powerSupply.controllerPower;
        connect powerSupply.controllerPower to controller.power;
        connect powerSupply.timingPower to timingReference.power;
        connect powerSupply.transmitterPower to transmitter.power;
        connect powerSupply.receiverPower to receiver.power;
        connect powerSupply.processorPower to signalProcessor.power;
        connect powerSupply.displayPower to operatorInterface.power;

        connect operatorCommandInput to controller.operatorInput;
        connect controller.waveformControl to waveformGenerator.control;
        connect controller.transmitterControl to transmitter.control;
        connect controller.receiverControl to receiver.control;
        connect controller.processorControl to signalProcessor.control;
        connect controller.statusToOperator to operatorInterface.statusIn;

        connect timingReference.timingOut to waveformGenerator.timing;
        connect waveformGenerator.waveformOut to transmitter.waveformIn;
        connect transmitter.amplifiedOut to duplexer.transmitIn;
        connect duplexer.antennaTransmitOut to antenna.transmitIn;
        connect antenna.radiatedOut to targetEnvironment.incidentEmission;
        connect targetEnvironment.reflectedEcho to antenna.echoIn;
        connect antenna.echoOut to duplexer.antennaReceiveIn;
        connect duplexer.receiverOut to receiver.echoIn;
        connect receiver.digitizedEchoOut to signalProcessor.digitizedEchoIn;
        connect signalProcessor.detectionOut to trackManager.detectionIn;
        connect trackManager.trackOut to operatorInterface.trackDisplayIn;
        connect operatorInterface.commandOut to operatorDisplayOutput;
    }

    requirement def PrimaryFunctionRequirement {
        subject radar : DopplerRadarSystem;

        doc /* The system shall perform Doppler radar surveillance by transmitting coherent RF waveforms, receiving reflected echoes, estimating range from time of flight, estimating radial velocity from Doppler shift, and reporting target tracks to an operator interface. */

        require constraint {
            radar.maximumInstrumentedRange_m >= 1500.0
        }

        require constraint {
            radar.minimumDetectableRadialVelocity_m_per_s <= 0.5
        }

        require constraint {
            radar.probabilityOfDetectionAtReferenceTarget >= 0.90
        }

        require constraint {
            radar.falseAlarmProbabilityPerResolutionCell <= 0.000001
        }
    }

    requirement def CoherentWaveformRequirement {
        subject radar : DopplerRadarSystem;

        doc /* The radar shall use a coherent waveform so that Doppler frequency shift can be measured across a coherent processing interval. */

        require constraint {
            radar.carrierFrequency_Hz > 1000000000.0
        }

        require constraint {
            radar.operatingBandwidth_Hz >= 100000000.0
        }
    }

    requirement def TrackReportRequirement {
        subject radar : DopplerRadarSystem;

        doc /* The radar shall output target tracks containing range, bearing, radial velocity, acceleration estimate, quality, and update time. */

        require constraint {
            radar.nominalRangeResolution_m <= 2.0
        }

        require constraint {
            radar.nominalVelocityResolution_m_per_s <= 0.5
        }
    }

    part dopplerRadarPrototype : DopplerRadarSystem;
}
