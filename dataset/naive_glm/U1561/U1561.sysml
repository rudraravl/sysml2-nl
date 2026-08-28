package DSN_Ground_Station {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def Power_kW :> Real { unit 'kW'; }
    value def Frequency_GHz :> Real { unit 'GHz'; }
    value def Temperature_K :> Real { unit 'K'; }
    value def Angle_deg :> Real { unit 'deg'; }
    value def AngularRate_deg_per_s :> Real { unit 'deg/s'; }
    value def Distance_km :> Real {> 0; unit 'km'; }
    value def Velocity_km_per_s :> Real { unit 'km/s'; }
    value def SNR_dB :> Real { unit 'dB'; }
    value def Gain_dBi :> Real { unit 'dBi'; }
    value def DataRate_bps :> Integer {> 0; unit 'bps'; }
    value def Duration_s :> Real {> 0; unit 's'; }
    value def Availability_pct :> Real {> 0; <= 100; unit '%'; }

    // ===== Item Definitions =====
    item def CommandFrame {
        attribute spacecraftId : String;
        attribute sequenceNumber : Integer;
        attribute payload : String;
        attribute checksum : Integer;
    }

    item def TelemetryFrame {
        attribute spacecraftId : String;
        attribute timestamp : String;
        attribute scienceData : String;
        attribute engineeringData : String;
        attribute qualityIndicator : Integer;
    }

    item def RadioMetric {
        attribute range : Distance_km;
        attribute rangeRate : Velocity_km_per_s;
        attribute dopplerShift : Frequency_GHz;
        attribute signalLevel : SNR_dB;
    }

    item def SpacecraftEphemeris {
        attribute spacecraftId : String;
        attribute predictedAzimuth : Angle_deg;
        attribute predictedElevation : Angle_deg;
        attribute predictedRange : Distance_km;
        attribute predictedRangeRate : Velocity_km_per_s;
        attribute validUntil : String;
    }

    item def RFSignal {
        attribute carrierFrequency : Frequency_GHz;
        attribute power : Power_kW;
        attribute modulationScheme : String;
        attribute dataRate : DataRate_bps;
    }

    item def DigitizedSample {
        attribute sampleRate : DataRate_bps;
        attribute bitDepth : Integer;
        attribute iqData : String;
    }

    item def HealthStatus {
        attribute subsystemName : String;
        attribute operational : Boolean;
        attribute faultCode : Integer;
        attribute timestamp : String;
    }

    item def TrackingPassSchedule {
        attribute passId : String;
        attribute spacecraftId : String;
        attribute startTime : String;
        attribute endTime : String;
        attribute mode : String;
        attribute priority : Integer;
    }

    // ===== Port Definitions =====
    port def RFPort {
        in item rfIn : RFSignal;
        out item rfOut : RFSignal;
    }

    port def CommandPort {
        out item commands : CommandFrame;
    }

    port def TelemetryPort {
        in item telemetry : TelemetryFrame;
    }

    port def EphemerisPort {
        in item ephemeris : SpacecraftEphemeris;
    }

    port def RadioMetricPort {
        out item metrics : RadioMetric;
    }

    port def HealthPort {
        out item status : HealthStatus;
    }

    port def SchedulePort {
        out item schedule : TrackingPassSchedule;
    }

    port def DigitizedStreamPort {
        out item samples : DigitizedSample;
    }

    port def PointingCommandPort {
        out item azimuth : Angle_deg;
        out item elevation : Angle_deg;
    }

    // ===== Requirements =====
    requirement def 'HighAvailabilityRequirement' {
        doc { The ground station shall maintain high availability to support critical mission events at any time. }
        attribute minAvailability : Availability_pct = 99.0;
        subject station : DSN_Ground_Station;
        require station.measuredAvailability >= minAvailability;
    }

    requirement def 'AntennaApertureRequirement' {
        doc { The station shall use a 70-meter steerable dish antenna. }
        attribute requiredDiameter : Real = 70 { unit 'm'; }
        subject antenna : AntennaSubsystem;
        require antenna.dishDiameter == requiredDiameter;
    }

    requirement def 'TransmitterPowerRequirement' {
        doc { The transmitter shall use a 20-kilowatt klystron amplifier. }
        attribute requiredPower : Power_kW = 20;
        subject transmitter : TransmitterSubsystem;
        require transmitter.klystronOutputPower >= requiredPower;
    }

    requirement def 'ReceiverSensitivityRequirement' {
        doc { The receiver shall use a cryogenically cooled low-noise amplifier. }
        attribute maxLnaTemperature : Temperature_K = 15;
        subject receiver : ReceiverSubsystem;
        require receiver.lnaTemperature <= maxLnaTemperature;
    }

    requirement def 'TrackingAccuracyRequirement' {
        doc { The tracking subsystem shall measure spacecraft range and range rate with extreme accuracy. }
        attribute rangeUncertainty : Distance_km = 1;
        attribute rangeRateUncertainty : Velocity_km_per_s = 0.001;
        subject tracker : TrackingSubsystem;
        require tracker.rangeAccuracy <= rangeUncertainty
            and tracker.rangeRateAccuracy <= rangeRateUncertainty;
    }

    requirement def 'OperatingModeRequirement' {
        doc { The station shall support receive-only, transmit-only, and duplex operating modes. }
        subject station : DSN_Ground_Station;
        require station.supportedModes.includes('ReceiveOnly')
            and station.supportedModes.includes('TransmitOnly')
            and station.supportedModes.includes('Duplex');
    }

    // ===== Behaviors =====
    action def AcquireSpacecraftSignal {
        in ephemeris : SpacecraftEphemeris;
        out acquired : Boolean;
        out pointingAz : Angle_deg;
        out pointingEl : Angle_deg;

        start;
        action setInitialPointing {
            in predAz = ephemeris.predictedAzimuth;
            in predEl = ephemeris.predictedElevation;
            out az -> pointingAz;
            out el -> pointingEl;
        }
        action searchForCarrier {
            in az = pointingAz;
            in el = pointingEl;
            out found -> acquired;
        }
        finish;
    }

    action def ProcessTelemetry {
        in rfIn : RFSignal;
        out telemetry : TelemetryFrame;

        start;
        action digitize {
            in rf = rfIn;
            out samples : DigitizedSample;
        }
        action decode {
            in s = digitize.samples;
            out frames : TelemetryFrame[*];
        }
        action record {
            in f = decode.frames;
            out recorded -> telemetry;
        }
        finish;
    }

    state def def 'StationOperatingStateMachine' {
        entry; then Idle;

        state Idle;
        state Acquiring;
        state Tracking;
        state ReceiveOnly;
        state TransmitOnly;
        state Duplex;
        state Faulted;
        state Maintenance;

        transition from Idle to Acquiring
            when passScheduled;
        transition from Acquiring to Tracking
            when signalAcquired;
        transition from Acquiring to Faulted
            when acquisitionFailed;
        transition from Tracking to ReceiveOnly
            when modeSelected == 'ReceiveOnly';
        transition from Tracking to TransmitOnly
            when modeSelected == 'TransmitOnly';
        transition from Tracking to Duplex
            when modeSelected == 'Duplex';
        transition from ReceiveOnly to Idle
            when passComplete;
        transition from TransmitOnly to Idle
            when passComplete;
        transition from Duplex to Idle
            when passComplete;
        transition from Faulted to Maintenance
            when faultAcknowledged;
        transition from Maintenance to Idle
            when maintenanceComplete;
    }

    // ===== Subsystem Part Definitions =====
    part def AntennaSubsystem {
        attribute dishDiameter : Real = 70 { unit 'm'; };
        attribute gain : Gain_dBi = 74;
        attribute currentAzimuth : Angle_deg;
        attribute currentElevation : Angle_deg;
        attribute maxSlewRate : AngularRate_deg_per_s = 0.5;

        port rfInterface : RFPort;
        port pointingCommand : PointingCommandPort;

        action def PointAntenna {
            in targetAz : Angle_deg;
            in targetEl : Angle_deg;
            out achievedAz : Angle_deg;
            out achievedEl : Angle_deg;
        }
    }

    part def PositioningSubsystem {
        attribute azimuthPosition : Angle_deg;
        attribute elevationPosition : Angle_deg;
        attribute azimuthRate : AngularRate_deg_per_s;
        attribute elevationRate : AngularRate_deg_per_s;
        attribute servoStatus : String;

        port pointingCommand : PointingCommandPort;
        port healthOut : HealthPort;

        action def DrivePosition {
            in commandedAz : Angle_deg;
            in commandedEl : Angle_deg;
            out actualAz : Angle_deg;
            out actualEl : Angle_deg;
        }
    }

    part def TransmitterSubsystem {
        attribute klystronOutputPower : Power_kW = 20;
        attribute carrierFrequency : Frequency_GHz = 7.2;
        attribute modulationScheme : String = 'PCM/PSK/PM';
        attribute status : String;

        port rfOut : RFPort;
        port commandIn : CommandPort;
        port healthOut : HealthPort;

        action def GenerateUplink {
            in cmd : CommandFrame;
            out rf : RFSignal;
        }
    }

    part def ReceiverSubsystem {
        attribute lnaTemperature : Temperature_K = 12;
        attribute centerFrequency : Frequency_GHz = 8.4;
        attribute noiseFigure : SNR_dB;
        attribute status : String;

        port rfIn : RFPort;
        port ifOut : RFPort;
        port healthOut : HealthPort;

        action def AmplifyDownlink {
            in rf : RFSignal;
            out amplified : RFSignal;
        }
    }

    part def TrackingSubsystem {
        attribute rangeAccuracy : Distance_km = 0.5;
        attribute rangeRateAccuracy : Velocity_km_per_s = 0.0005;
        attribute lockStatus : String;
        attribute trackedSpacecraftId : String;

        port ephemerisIn : EphemerisPort;
        port rfIn : RFPort;
        port metricsOut : RadioMetricPort;
        port pointingCommand : PointingCommandPort;
        port healthOut : HealthPort;

        action def TrackSignal {
            in ephemeris : SpacecraftEphemeris;
            in rf : RFSignal;
            out metrics : RadioMetric;
            out azCorrection : Angle_deg;
            out elCorrection : Angle_deg;
        }
    }

    part def SignalProcessingSubsystem {
        attribute sampleRate : DataRate_bps = 128000000;
        attribute bitDepth : Integer = 8;
        attribute decoderStatus : String;
        attribute recorderCapacity : Real = 10 { unit 'TB'; };

        port ifIn : RFPort;
        port digitizedOut : DigitizedStreamPort;
        port telemetryOut : TelemetryPort;
        port healthOut : HealthPort;

        action def Digitize {
            in rf : RFSignal;
            out samples : DigitizedSample;
        }
        action def Decode {
            in samples : DigitizedSample;
            out frames : TelemetryFrame[*];
        }
        action def Record {
            in frames : TelemetryFrame[*];
            out recorded : TelemetryFrame;
        }
    }

    part def MonitorAndControlSubsystem {
        attribute currentMode : String;
        attribute activePassId : String;
        attribute stationHealth : HealthStatus[*];
        attribute measuredAvailability : Availability_pct = 99.5;

        port scheduleOut : SchedulePort;
        port ephemerisOut : EphemerisPort;
        port commandOut : CommandPort;
        port healthIn : HealthPort;
        port healthOut : HealthPort;

        action def SchedulePass {
            in request : TrackingPassSchedule;
            out confirmed : TrackingPassSchedule;
        }
        action def MonitorHealth {
            in statuses : HealthStatus[*];
            out aggregate : HealthStatus;
        }
        action def SelectMode {
            in requestedMode : String;
            out selectedMode : String;
        }
    }

    // ===== Top-Level Ground Station =====
    part def DSN_Ground_Station {
        attribute stationId : String = 'DSS-43';
        attribute location : String = 'Canberra, Australia';
        attribute supportedModes : String[*] = ['ReceiveOnly', 'TransmitOnly', 'Duplex'];
        attribute measuredAvailability : Availability_pct = 99.5;

        port spacecraftLink : RFPort;
        port missionDataOut : TelemetryPort;
        port commandInput : CommandPort;
        port ephemerisInput : EphemerisPort;
        port scheduleOutput : SchedulePort;
        port stationHealthOut : HealthPort;

        part antenna : AntennaSubsystem {
            attribute dishDiameter : Real = 70 { unit 'm'; };
        }
        part positioning : PositioningSubsystem;
        part transmitter : TransmitterSubsystem {
            attribute klystronOutputPower : Power_kW = 20;
        }
        part receiver : ReceiverSubsystem {
            attribute lnaTemperature : Temperature_K = 12;
        }
        part tracker : TrackingSubsystem;
        part signalProcessor : SignalProcessingSubsystem;
        part monitorControl : MonitorAndControlSubsystem;

        // Internal connections
        connection monitorControl.ephemerisOut to tracker.ephemerisIn;
        connection monitorControl.commandOut to transmitter.commandIn;
        connection monitorControl.scheduleOutput to scheduleOutput;

        connection tracker.pointingCommand to positioning.pointingCommand;
        connection positioning.pointingCommand to antenna.pointingCommand;

        connection transmitter.rfOut to antenna.rfInterface;
        connection antenna.rfInterface to receiver.rfIn;
        connection receiver.ifOut to signalProcessor.ifIn;
        connection receiver.ifOut to tracker.rfIn;

        connection tracker.metricsOut to monitorControl.healthIn;
        connection signalProcessor.telemetryOut to missionDataOut;

        connection antenna.healthOut to monitorControl.healthIn;
        connection positioning.healthOut to monitorControl.healthIn;
        connection transmitter.healthOut to monitorControl.healthIn;
        connection receiver.healthOut to monitorControl.healthIn;
        connection tracker.healthOut to monitorControl.healthIn;
        connection signalProcessor.healthOut to monitorControl.healthIn;
        connection monitorControl.healthOut to stationHealthOut;

        // External link
        connection antenna.rfInterface to spacecraftLink;

        // State machine
        exhibit state stationBehavior : StationOperatingStateMachine {
            attribute modeSelected : String;
            attribute passScheduled : Boolean;
            attribute signalAcquired : Boolean;
            attribute acquisitionFailed : Boolean;
            attribute passComplete : Boolean;
            attribute faultAcknowledged : Boolean;
            attribute maintenanceComplete : Boolean;
        }

        // Requirements satisfaction
        satisfy 'HighAvailabilityRequirement' by self;
        satisfy 'AntennaApertureRequirement' by antenna;
        satisfy 'TransmitterPowerRequirement' by transmitter;
        satisfy 'ReceiverSensitivityRequirement' by receiver;
        satisfy 'TrackingAccuracyRequirement' by tracker;
        satisfy 'OperatingModeRequirement' by self;
    }
}
