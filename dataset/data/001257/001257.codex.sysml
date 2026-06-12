package SonarBasedSystemModel {
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    item def AcousticWave {
        attribute centerFrequencyHz : Real;
        attribute bandwidthHz : Real;
        attribute soundPressureLevel_dBre1uPa : Real;
        attribute pulseDuration_s : Real;
        attribute propagationSpeed_m_per_s : Real = 1500.0;
    }

    item def EchoReturn {
        attribute timeOfFlight_s : Real;
        attribute receivedLevel_dBre1uPa : Real;
        attribute bearing_deg : Real;
        attribute dopplerShift_Hz : Real;
        attribute signalToNoiseRatio_dB : Real;
    }

    item def TargetTrack {
        attribute trackId : Integer;
        attribute range_m : Real;
        attribute bearing_deg : Real;
        attribute radialVelocity_m_per_s : Real;
        attribute confidence : Real;
        attribute lastUpdated_s : Real;
    }

    item def ElectricalPower {
        attribute voltage_V : Real;
        attribute current_A : Real;
        attribute frequency_Hz : Real;
    }

    item def SonarCommand {
        attribute activeModeEnabled : Boolean;
        attribute scanSectorStart_deg : Real;
        attribute scanSectorEnd_deg : Real;
        attribute pingInterval_s : Real;
        attribute requestedRange_m : Real;
    }

    item def SonarStatus {
        attribute ready : Boolean;
        attribute operatingMode : String;
        attribute healthPercent : Real;
        attribute activeTrackCount : Integer;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : SonarCommand;
    }

    port def StatusOutputPort {
        out item status : SonarStatus;
    }

    port def AcousticTransmitPort {
        out item wave : AcousticWave;
    }

    port def AcousticReceivePort {
        in item echo : EchoReturn;
    }

    port def TrackOutputPort {
        out item track : TargetTrack;
    }

    port def InternalWaveDrivePort {
        in item wave : AcousticWave;
    }

    port def InternalEchoPort {
        out item echo : EchoReturn;
    }

    action def GeneratePing {
        in attribute commandedFrequency_Hz : Real;
        in attribute commandedBandwidth_Hz : Real;
        in attribute commandedDuration_s : Real;
        out item pulse : AcousticWave;

        bind pulse.centerFrequencyHz = commandedFrequency_Hz;
        bind pulse.bandwidthHz = commandedBandwidth_Hz;
        bind pulse.pulseDuration_s = commandedDuration_s;
        bind pulse.soundPressureLevel_dBre1uPa = 215.0;
        bind pulse.propagationSpeed_m_per_s = 1500.0;
    }

    action def EstimateTargetRange {
        in item echo : EchoReturn;
        out attribute estimatedRange_m : Real;

        bind estimatedRange_m = echo.timeOfFlight_s * 1500.0 / 2.0;
    }

    action def ClassifyAndTrackTarget {
        in item echo : EchoReturn;
        in attribute estimatedRange_m : Real;
        out item track : TargetTrack;

        bind track.range_m = estimatedRange_m;
        bind track.bearing_deg = echo.bearing_deg;
        bind track.radialVelocity_m_per_s = echo.dopplerShift_Hz * 1500.0 / 2.0 / 30000.0;
        bind track.confidence = echo.signalToNoiseRatio_dB / 30.0;
        bind track.lastUpdated_s = echo.timeOfFlight_s;
    }

    state def SonarOperatingStateMachine {
        entry action InitializeSystem;
        state Off;
        state Standby;
        state ActiveSearch;
        state PassiveListen;
        state TrackHold;
        state Fault;

        transition first Off;

        transition PowerApplied
            first Off
            then Standby;

        transition BeginActiveSearch
            first Standby
            if command.activeModeEnabled
            then ActiveSearch;

        transition BeginPassiveListen
            first Standby
            if not command.activeModeEnabled
            then PassiveListen;

        transition EchoDetected
            first ActiveSearch
            if echo.signalToNoiseRatio_dB >= 12.0
            then TrackHold;

        transition TrackLost
            first TrackHold
            if track.confidence < 0.35
            then ActiveSearch;

        transition ReturnToStandby
            first ActiveSearch
            then Standby;

        transition FaultDetected
            first Standby
            then Fault;

        transition Shutdown
            first Fault
            then Off;
    }

    part def PowerConditioner {
        port powerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;

        attribute inputVoltage_V : Real = 115.0;
        attribute outputVoltage_V : Real = 48.0;
        attribute maximumOutputPower_W : Real = 2500.0;
        attribute efficiency : Real = 0.92;
    }

    part def SonarController {
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute pingInterval_s : Real = 2.0;
        attribute scanSectorStart_deg : Real = -60.0;
        attribute scanSectorEnd_deg : Real = 60.0;
        attribute maximumTracks : Integer = 64;
        attribute primaryFunction : String = "Detect underwater objects by transmitting acoustic pulses, receiving echoes, estimating range and bearing, and reporting target tracks.";

        perform stateMachine : SonarOperatingStateMachine;
    }

    part def SignalGenerator {
        port commandIn : CommandInputPort;
        port pulseOut : AcousticTransmitPort;

        attribute nominalFrequency_Hz : Real = 30000.0;
        attribute bandwidth_Hz : Real = 4000.0;
        attribute pulseDuration_s : Real = 0.025;

        perform action generatePing : GeneratePing;
    }

    part def PowerAmplifier {
        port pulseIn : InternalWaveDrivePort;
        port amplifiedPulseOut : AcousticTransmitPort;

        attribute gain_dB : Real = 38.0;
        attribute peakOutputPower_W : Real = 1800.0;
    }

    part def ProjectorArray {
        port driveIn : InternalWaveDrivePort;
        port acousticOut : AcousticTransmitPort;

        attribute elementCount : Integer = 32;
        attribute horizontalBeamwidth_deg : Real = 8.0;
        attribute verticalBeamwidth_deg : Real = 20.0;
        attribute sourceLevel_dBre1uPaAt1m : Real = 215.0;
    }

    part def HydrophoneArray {
        port acousticIn : AcousticReceivePort;
        port echoOut : InternalEchoPort;

        attribute elementCount : Integer = 64;
        attribute sensitivity_dBV_per_uPa : Real = -165.0;
        attribute selfNoise_dBre1uPa : Real = 45.0;
        attribute bearingAccuracy_deg : Real = 1.5;
    }

    part def ReceiverProcessor {
        port echoIn : AcousticReceivePort;
        port trackOut : TrackOutputPort;

        attribute minimumDetectableSNR_dB : Real = 12.0;
        attribute maximumDetectionRange_m : Real = 5000.0;
        attribute rangeResolution_m : Real = 1.5;
        attribute bearingResolution_deg : Real = 2.0;

        perform action estimateRange : EstimateTargetRange;
        perform action classifyTrack : ClassifyAndTrackTarget;
    }

    part def OperatorDisplay {
        port trackIn : TrackOutputPort;
        port statusIn : StatusOutputPort;

        attribute updateRate_Hz : Real = 2.0;
        attribute displayedRangeScale_m : Real = 6000.0;
        attribute alarmOnNewTrack : Boolean = true;
    }

    part def SonarSystem {
        port externalPower : PowerInputPort;
        port operatorCommand : CommandInputPort;
        port systemStatus : StatusOutputPort;
        port reportedTrack : TrackOutputPort;
        port transmitAcoustics : AcousticTransmitPort;
        port receiveAcoustics : AcousticReceivePort;

        part powerConditioner : PowerConditioner;
        part controller : SonarController;
        part signalGenerator : SignalGenerator;
        part amplifier : PowerAmplifier;
        part projectorArray : ProjectorArray;
        part hydrophoneArray : HydrophoneArray;
        part receiverProcessor : ReceiverProcessor;
        part operatorDisplay : OperatorDisplay;

        connect externalPower to powerConditioner.powerIn;
        connect operatorCommand to controller.commandIn;
        connect operatorCommand to signalGenerator.commandIn;
        connect controller.statusOut to systemStatus;
        connect controller.statusOut to operatorDisplay.statusIn;

        connect signalGenerator.pulseOut to amplifier.pulseIn;
        connect amplifier.amplifiedPulseOut to projectorArray.driveIn;
        connect projectorArray.acousticOut to transmitAcoustics;

        connect receiveAcoustics to hydrophoneArray.acousticIn;
        connect hydrophoneArray.echoOut to receiverProcessor.echoIn;
        connect receiverProcessor.trackOut to reportedTrack;
        connect receiverProcessor.trackOut to operatorDisplay.trackIn;

        attribute totalMass_kg : Real = 185.0;
        attribute averagePower_W : Real = 900.0;
        attribute peakPower_W : Real = 2500.0;
        attribute operatingDepth_m : Real = 300.0;
        attribute designLife_year : Real = 15.0;
    }

    requirement def PrimarySonarFunction {
        subject sonar : SonarSystem;

        doc /* The sonar system shall detect underwater objects at a high level by emitting controlled acoustic energy, receiving acoustic echoes, processing echo time-of-flight and bearing, and reporting target tracks to an operator or host platform. */

        require constraint {
            sonar.receiverProcessor.maximumDetectionRange_m >= 5000.0
        }

        require constraint {
            sonar.receiverProcessor.minimumDetectableSNR_dB <= 12.0
        }

        require constraint {
            sonar.controller.maximumTracks >= 32
        }
    }

    requirement def AcousticDetectionPerformance {
        subject sonar : SonarSystem;

        require constraint {
            sonar.receiverProcessor.rangeResolution_m <= 2.0
        }

        require constraint {
            sonar.receiverProcessor.bearingResolution_deg <= 3.0
        }

        require constraint {
            sonar.projectorArray.sourceLevel_dBre1uPaAt1m >= 210.0
        }
    }

    requirement def ElectricalPowerCompatibility {
        subject sonar : SonarSystem;

        require constraint {
            sonar.powerConditioner.inputVoltage_V == 115.0
        }

        require constraint {
            sonar.peakPower_W <= 2500.0
        }
    }

    requirement def OperatorReporting {
        subject sonar : SonarSystem;

        require constraint {
            sonar.operatorDisplay.updateRate_Hz >= 1.0
        }

        require constraint {
            sonar.operatorDisplay.displayedRangeScale_m >= sonar.receiverProcessor.maximumDetectionRange_m
        }
    }

    satisfy PrimarySonarFunction by SonarSystem;
    satisfy AcousticDetectionPerformance by SonarSystem;
    satisfy ElectricalPowerCompatibility by SonarSystem;
    satisfy OperatorReporting by SonarSystem;
}