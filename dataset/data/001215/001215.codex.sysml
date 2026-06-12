package RadarSystemSpecification {

    import ScalarValues::*;
    import SI::*;

    value def FrequencyValue {
        unit = "Hz";
    }

    value def PowerValue {
        unit = "W";
    }

    value def DistanceValue {
        unit = "m";
    }

    value def TimeValue {
        unit = "s";
    }

    value def AngleValue {
        unit = "deg";
    }

    value def VelocityValue {
        unit = "m/s";
    }

    value def GainValue {
        unit = "dB";
    }

    value def ProbabilityValue {
        unit = "1";
    }

    item def RFSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute bandwidth : FrequencyValue;
        attribute peakPower : PowerValue;
        attribute pulseWidth : TimeValue;
        attribute pulseRepetitionInterval : TimeValue;
    }

    item def EchoSignal {
        attribute receivedPower : PowerValue;
        attribute timeOfFlight : TimeValue;
        attribute dopplerShift : FrequencyValue;
        attribute azimuthAngle : AngleValue;
        attribute elevationAngle : AngleValue;
    }

    item def TargetTrack {
        attribute trackId : Integer;
        attribute range : DistanceValue;
        attribute azimuth : AngleValue;
        attribute elevation : AngleValue;
        attribute radialVelocity : VelocityValue;
        attribute confidence : ProbabilityValue;
        attribute lastUpdateTime : TimeValue;
    }

    item def RadarCommand {
        attribute requestedMode : RadarMode;
        attribute scanSectorAzimuthStart : AngleValue;
        attribute scanSectorAzimuthEnd : AngleValue;
        attribute scanSectorElevationStart : AngleValue;
        attribute scanSectorElevationEnd : AngleValue;
    }

    enum def RadarMode {
        enum idle;
        enum search;
        enum track;
        enum standby;
        enum fault;
    }

    port def PowerInputPort {
        in item electricalPower : PowerValue;
    }

    port def RFTransmitPort {
        out item transmittedSignal : RFSignal;
    }

    port def RFReceivePort {
        in item receivedEcho : EchoSignal;
    }

    port def CommandPort {
        in item command : RadarCommand;
    }

    port def TrackOutputPort {
        out item track : TargetTrack;
    }

    port def HealthPort {
        out item operatingMode : RadarMode;
    }

    part def Transmitter {
        attribute peakTransmitPower : PowerValue = 25000;
        attribute carrierFrequency : FrequencyValue = 9400000000;
        attribute pulseWidth : TimeValue = 0.000001;
        attribute pulseRepetitionInterval : TimeValue = 0.001;

        port powerIn : PowerInputPort;
        port rfOut : RFTransmitPort;

        action generatePulse {
            out item pulse : RFSignal;
            assign pulse.carrierFrequency := carrierFrequency;
            assign pulse.peakPower := peakTransmitPower;
            assign pulse.pulseWidth := pulseWidth;
            assign pulse.pulseRepetitionInterval := pulseRepetitionInterval;
            assign pulse.bandwidth := 20000000;
        }
    }

    part def Receiver {
        attribute noiseFigure : GainValue = 3.5;
        attribute minimumDetectablePower : PowerValue = 0.00000000000001;

        port rfIn : RFReceivePort;

        action amplifyAndFilterEcho {
            in item echoIn : EchoSignal;
            out item echoOut : EchoSignal;
            assign echoOut := echoIn;
        }
    }

    part def AntennaArray {
        attribute gain : GainValue = 32;
        attribute azimuthBeamwidth : AngleValue = 2.0;
        attribute elevationBeamwidth : AngleValue = 3.0;
        attribute scanAzimuthLimit : AngleValue = 120;
        attribute scanElevationLimit : AngleValue = 60;

        port transmitAperture : RFTransmitPort;
        port receiveAperture : RFReceivePort;
    }

    part def SignalProcessor {
        attribute rangeResolution : DistanceValue = 7.5;
        attribute velocityResolution : VelocityValue = 1.0;
        attribute falseAlarmProbability : ProbabilityValue = 0.000001;
        attribute detectionProbability : ProbabilityValue = 0.9;

        port echoIn : RFReceivePort;
        port trackOut : TrackOutputPort;

        action estimateTargetState {
            in item echo : EchoSignal;
            out item track : TargetTrack;
            assign track.range := echo.timeOfFlight * 149896229;
            assign track.azimuth := echo.azimuthAngle;
            assign track.elevation := echo.elevationAngle;
            assign track.radialVelocity := echo.dopplerShift * 0.0158;
            assign track.confidence := detectionProbability;
        }
    }

    part def RadarController {
        attribute mode : RadarMode = RadarMode::idle;
        attribute commandedAzimuthStart : AngleValue = -60;
        attribute commandedAzimuthEnd : AngleValue = 60;
        attribute commandedElevationStart : AngleValue = -10;
        attribute commandedElevationEnd : AngleValue = 45;

        port commandIn : CommandPort;
        port healthOut : HealthPort;

        action acceptCommand {
            in item command : RadarCommand;
            assign mode := command.requestedMode;
            assign commandedAzimuthStart := command.scanSectorAzimuthStart;
            assign commandedAzimuthEnd := command.scanSectorAzimuthEnd;
            assign commandedElevationStart := command.scanSectorElevationStart;
            assign commandedElevationEnd := command.scanSectorElevationEnd;
        }

        state operatingState {
            state Off;
            state Standby;
            state Searching;
            state Tracking;
            state Faulted;

            transition initial then Off;
            transition Off_to_Standby first Off then Standby;
            transition Standby_to_Search first Standby then Searching;
            transition Search_to_Track first Searching then Tracking;
            transition Track_to_Search first Tracking then Searching;
            transition Any_to_Fault first Off then Faulted;
            transition Fault_to_Standby first Faulted then Standby;
        }
    }

    part def OperatorInterface {
        port commandOut : CommandPort;
        port trackIn : TrackOutputPort;
        port healthIn : HealthPort;
    }

    part def RadarSystem {
        attribute primaryFunction : String =
            "Detect objects by transmitting radio-frequency energy, receiving reflected echoes, and estimating target range, bearing, elevation, and radial velocity.";

        attribute maximumInstrumentedRange : DistanceValue = 150000;
        attribute minimumDetectableRange : DistanceValue = 100;
        attribute updatePeriod : TimeValue = 1.0;
        attribute operatingFrequency : FrequencyValue = 9400000000;

        port externalPower : PowerInputPort;
        port operatorCommand : CommandPort;
        port targetTrackOutput : TrackOutputPort;
        port healthStatus : HealthPort;

        part transmitter : Transmitter;
        part receiver : Receiver;
        part antenna : AntennaArray;
        part processor : SignalProcessor;
        part controller : RadarController;
        part interface : OperatorInterface;

        connection powerFeed connect externalPower to transmitter.powerIn;
        connection transmitPath connect transmitter.rfOut to antenna.transmitAperture;
        connection receivePath connect antenna.receiveAperture to receiver.rfIn;
        connection processingPath connect receiver.rfIn to processor.echoIn;
        connection commandPath connect operatorCommand to controller.commandIn;
        connection operatorCommandPath connect interface.commandOut to controller.commandIn;
        connection trackPath connect processor.trackOut to targetTrackOutput;
        connection operatorTrackPath connect processor.trackOut to interface.trackIn;
        connection healthPath connect controller.healthOut to healthStatus;
        connection operatorHealthPath connect controller.healthOut to interface.healthIn;

        action performRadarDetection {
            in item command : RadarCommand;
            out item track : TargetTrack;

            action configureScan {
                in item scanCommand : RadarCommand;
                assign controller.mode := scanCommand.requestedMode;
            }

            action transmitWaveform {
                out item pulse : RFSignal;
                perform transmitter.generatePulse;
            }

            action receiveEcho {
                in item echo : EchoSignal;
                out item filteredEcho : EchoSignal;
                perform receiver.amplifyAndFilterEcho;
            }

            action processEcho {
                in item filteredEcho : EchoSignal;
                out item estimatedTrack : TargetTrack;
                perform processor.estimateTargetState;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject radar : RadarSystem;

        doc /* The radar system shall provide object detection and tracking by emitting RF pulses, receiving echoes, processing echo timing and Doppler content, and reporting target tracks. */

        require constraint {
            radar.maximumInstrumentedRange >= 150000
        }
    }

    requirement def DetectionPerformanceRequirement {
        subject radar : RadarSystem;

        require constraint {
            radar.processor.detectionProbability >= 0.90
        }

        require constraint {
            radar.processor.falseAlarmProbability <= 0.000001
        }
    }

    requirement def RangeResolutionRequirement {
        subject radar : RadarSystem;

        require constraint {
            radar.processor.rangeResolution <= 10
        }
    }

    requirement def ScanCoverageRequirement {
        subject radar : RadarSystem;

        require constraint {
            radar.antenna.scanAzimuthLimit >= 120
        }

        require constraint {
            radar.antenna.scanElevationLimit >= 60
        }
    }

    requirement def TrackOutputRequirement {
        subject radar : RadarSystem;

        require constraint {
            radar.updatePeriod <= 1.0
        }
    }

    requirement def RFPowerRequirement {
        subject radar : RadarSystem;

        require constraint {
            radar.transmitter.peakTransmitPower >= 25000
        }
    }

    satisfy PrimaryFunctionRequirement by RadarSystem;
    satisfy DetectionPerformanceRequirement by RadarSystem;
    satisfy RangeResolutionRequirement by RadarSystem;
    satisfy ScanCoverageRequirement by RadarSystem;
    satisfy TrackOutputRequirement by RadarSystem;
    satisfy RFPowerRequirement by RadarSystem;

}