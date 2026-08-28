package SSMI {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def Frequency :> Real {
        unit 'GHz';
    }

    value def BrightnessTemperature :> Real {
        unit 'K';
    }

    value def Voltage :> Real {
        unit 'mV';
    }

    value def Angle :> Real {
        unit 'deg';
    }

    value def Time :> Real {
        unit 's';
    }

    value def SwathWidth :> Real {
        unit 'km';
    }

    value def WindSpeed :> Real {
        unit 'm/s';
    }

    value def SeaIceConcentration :> Real {
        unit '%';
    }

    value def WaterVapor :> Real {
        unit 'kg/m^2';
    }

    enum def PolarizationKind {
        V = 0;
        H = 1;
    }

    enum def QualityFlag {
        good = 0;
        suspect = 1;
        bad = 2;
    }

    // ===== Item Definitions =====

    item def MicrowaveRadiation {
        attribute frequency : Frequency;
        attribute polarization : PolarizationKind;
        attribute intensity : BrightnessTemperature;
    }

    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute channelId : Integer;
    }

    item def CalibratedSample {
        attribute channelId : Integer;
        attribute brightnessTemp : BrightnessTemperature;
        attribute timestamp : Time;
        attribute quality : QualityFlag;
    }

    item def ScanPosition {
        attribute scanAngle : Angle;
        attribute timestamp : Time;
    }

    item def WarmReference {
        attribute physicalTemp : BrightnessTemperature;
    }

    item def ColdReference {
        attribute physicalTemp : BrightnessTemperature := 2.7 [K];
    }

    item def CalibrationPair {
        attribute warm : WarmReference;
        attribute cold : ColdReference;
        attribute channelId : Integer;
    }

    item def SensorMeasurementData {
        attribute samples : CalibratedSample[0..*];
        attribute positions : ScanPosition[0..*];
        attribute timestamp : Time;
        attribute overallQuality : QualityFlag;
        attribute derivedWindSpeed : WindSpeed[0..*] optional;
        attribute derivedSeaIceConc : SeaIceConcentration[0..*] optional;
        attribute derivedWaterVapor : WaterVapor[0..*] optional;
    }

    // ===== Port Definitions =====

    port def MicrowaveInPort {
        in microwave : MicrowaveRadiation;
    }

    port def SignalOutPort {
        out signal : ElectricalSignal;
    }

    port def SignalInPort {
        in signal : ElectricalSignal;
    }

    port def CalibratedOutPort {
        out sample : CalibratedSample;
    }

    port def CalibratedInPort {
        in sample : CalibratedSample;
    }

    port def ScanPositionOutPort {
        out position : ScanPosition;
    }

    port def ScanPositionInPort {
        in position : ScanPosition;
    }

    port def CalibrationPort {
        out calibration : CalibrationPair;
    }

    port def CalibrationInPort {
        in calibration : CalibrationPair;
    }

    port def DataProductOutPort {
        out data : SensorMeasurementData;
    }

    // ===== Antenna Subsystem =====

    part def AntennaSubsystem {
        port microwaveIn : MicrowaveInPort;
        port signalOut : SignalOutPort;

        attribute apertureDiameter : Real = 60 [cm];
        attribute beamEfficiency : Real = 0.95;

        action def CollectRadiation {
            in radiation : MicrowaveRadiation;
            out signal : ElectricalSignal;
        }

        perform collect : CollectRadiation;

        state def AntennaBehavior {
            entry;
            state Idle;
            state Collecting {
                entry;
            }
            transition idle_to_collecting
                source Idle
                target Collecting
                when microwaveIn.microwave->notEmpty();
            transition collecting_to_idle
                source Collecting
                target Idle
                when signalOut.signal->notEmpty();
        }

        exhibit behavior : AntennaBehavior;
    }

    // ===== Scanning Mechanism =====

    part def ScanningMechanism {
        port positionOut : ScanPositionOutPort;

        attribute scanRate : Real = 31.9 [rpm];
        attribute swathWidth : SwathWidth = 1400 [km];
        attribute scanPeriod : Time = 1.9 [s];

        action def SweepScan {
            out position : ScanPosition;
        }

        perform sweep : SweepScan;

        state def ScanBehavior {
            state Stopped;
            state Scanning {
                do sweep;
            }
            transition stopped_to_scanning
                source Stopped
                target Scanning
                when true;
        }

        exhibit behavior : ScanBehavior;
    }

    // ===== Receiver Channel =====

    part def ReceiverChannel {
        port signalIn : SignalInPort;
        port signalOut : SignalOutPort;

        attribute channelId : Integer;
        attribute centerFrequency : Frequency;
        attribute polarization : PolarizationKind;
        attribute bandwidth : Frequency;
        attribute gain : Real;

        action def ConvertSignal {
            in input : ElectricalSignal;
            out output : ElectricalSignal;
        }

        perform convert : ConvertSignal;

        state def ReceiverBehavior {
            state Off;
            state WarmingUp;
            state Ready;
            state Receiving {
                do convert;
            }
            transition off_to_warming
                source Off
                target WarmingUp
                when true;
            transition warming_to_ready
                source WarmingUp
                target Ready
                when true;
            transition ready_to_receiving
                source Ready
                target Receiving
                when signalIn.signal->notEmpty();
            transition receiving_to_ready
                source Receiving
                target Ready
                when signalOut.signal->notEmpty();
        }

        exhibit behavior : ReceiverBehavior;
    }

    // ===== Calibration Subsystem =====

    part def CalibrationSubsystem {
        port calibrationOut : CalibrationPort;

        attribute warmTargetTemp : BrightnessTemperature = 300 [K];
        attribute coldTargetTemp : BrightnessTemperature = 2.7 [K];
        attribute calibrationInterval : Time = 1.9 [s];

        action def GenerateCalibration {
            out pair : CalibrationPair;
        }

        perform generate : GenerateCalibration;

        state def CalibrationBehavior {
            state Inactive;
            state Active {
                do generate;
            }
            transition inactive_to_active
                source Inactive
                target Active
                when true;
        }

        exhibit behavior : CalibrationBehavior;
    }

    // ===== Radiometer Subsystem =====

    part def RadiometerSubsystem {
        port signalIn : SignalInPort;
        port calibrationIn : CalibrationInPort;
        port calibratedOut : CalibratedOutPort;

        attribute channelId : Integer;
        attribute calibrationCoeffSlope : Real;
        attribute calibrationCoeffOffset : Real;

        action def ComputeBrightnessTemperature {
            in signal : ElectricalSignal;
            in calibration : CalibrationPair;
            out sample : CalibratedSample;
        }

        perform compute : ComputeBrightnessTemperature;

        state def RadiometerBehavior {
            state Uninitialized;
            state Calibrating;
            state Ready;
            state Measuring {
                do compute;
            }
            transition uninit_to_calib
                source Uninitialized
                target Calibrating
                when calibrationIn.calibration->notEmpty();
            transition calib_to_ready
                source Calibrating
                target Ready
                when true;
            transition ready_to_measuring
                source Ready
                target Measuring
                when signalIn.signal->notEmpty();
            transition measuring_to_ready
                source Measuring
                target Ready
                when calibratedOut.sample->notEmpty();
        }

        exhibit behavior : RadiometerBehavior;
    }

    // ===== Signal Processor =====

    part def SignalProcessor {
        port calibratedIn : CalibratedInPort[7];
        port positionIn : ScanPositionInPort;
        port dataOut : DataProductOutPort;

        attribute processingLatency : Time = 0.05 [s];

        action def AssembleDataProduct {
            in samples : CalibratedSample[0..*];
            in positions : ScanPosition[0..*];
            out data : SensorMeasurementData;
        }

        perform assemble : AssembleDataProduct;

        state def ProcessorBehavior {
            state Idle;
            state Buffering;
            state Packaging {
                do assemble;
            }
            transition idle_to_buffering
                source Idle
                target Buffering
                when calibratedIn.sample->notEmpty();
            transition buffering_to_packaging
                source Buffering
                target Packaging
                when positionIn.position->notEmpty();
            transition packaging_to_idle
                source Packaging
                target Idle
                when dataOut.data->notEmpty();
        }

        exhibit behavior : ProcessorBehavior;
    }

    // ===== SSM/I Instrument Assembly =====

    part def SSMIInstrument {
        port microwaveInput : MicrowaveInPort;
        port dataOutput : DataProductOutPort;

        part antenna : AntennaSubsystem;
        part scanner : ScanningMechanism;
        part calibration : CalibrationSubsystem;

        part receivers : ReceiverChannel[7] {
            // 19V, 19H, 22V, 37V, 37H, 85V, 85H
        }

        part radiometers : RadiometerSubsystem[7];

        part processor : SignalProcessor;

        // Define the seven receiver channels with specific frequencies
        part def Receiver19V :> ReceiverChannel {
            attribute channelId : Integer = 1;
            attribute centerFrequency : Frequency = 19.35 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::V;
            attribute bandwidth : Frequency = 0.25 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver19H :> ReceiverChannel {
            attribute channelId : Integer = 2;
            attribute centerFrequency : Frequency = 19.35 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::H;
            attribute bandwidth : Frequency = 0.25 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver22V :> ReceiverChannel {
            attribute channelId : Integer = 3;
            attribute centerFrequency : Frequency = 22.235 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::V;
            attribute bandwidth : Frequency = 0.20 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver37V :> ReceiverChannel {
            attribute channelId : Integer = 4;
            attribute centerFrequency : Frequency = 37.0 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::V;
            attribute bandwidth : Frequency = 1.0 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver37H :> ReceiverChannel {
            attribute channelId : Integer = 5;
            attribute centerFrequency : Frequency = 37.0 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::H;
            attribute bandwidth : Frequency = 1.0 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver85V :> ReceiverChannel {
            attribute channelId : Integer = 6;
            attribute centerFrequency : Frequency = 85.5 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::V;
            attribute bandwidth : Frequency = 1.2 [GHz];
            attribute gain : Real = 1.0;
        }

        part def Receiver85H :> ReceiverChannel {
            attribute channelId : Integer = 7;
            attribute centerFrequency : Frequency = 85.5 [GHz];
            attribute polarization : PolarizationKind = PolarizationKind::H;
            attribute bandwidth : Frequency = 1.2 [GHz];
            attribute gain : Real = 1.0;
        }

        // Instantiate specific receivers
        part receiver19V : Receiver19V;
        part receiver19H : Receiver19H;
        part receiver22V : Receiver22V;
        part receiver37V : Receiver37V;
        part receiver37H : Receiver37H;
        part receiver85V : Receiver85V;
        part receiver85H : Receiver85H;

        // Instantiate radiometers per channel
        part radiometer19V : RadiometerSubsystem {
            attribute channelId : Integer = 1;
        }
        part radiometer19H : RadiometerSubsystem {
            attribute channelId : Integer = 2;
        }
        part radiometer22V : RadiometerSubsystem {
            attribute channelId : Integer = 3;
        }
        part radiometer37V : RadiometerSubsystem {
            attribute channelId : Integer = 4;
        }
        part radiometer37H : RadiometerSubsystem {
            attribute channelId : Integer = 5;
        }
        part radiometer85V : RadiometerSubsystem {
            attribute channelId : Integer = 6;
        }
        part radiometer85H : RadiometerSubsystem {
            attribute channelId : Integer = 7;
        }

        // Connections: external microwave input to antenna
        connection microwaveInputToAntenna connect microwaveInput to antenna.microwaveIn;

        // Connections: antenna signal to each receiver
        connection antennaToReceiver19V connect antenna.signalOut to receiver19V.signalIn;
        connection antennaToReceiver19H connect antenna.signalOut to receiver19H.signalIn;
        connection antennaToReceiver22V connect antenna.signalOut to receiver22V.signalIn;
        connection antennaToReceiver37V connect antenna.signalOut to receiver37V.signalIn;
        connection antennaToReceiver37H connect antenna.signalOut to receiver37H.signalIn;
        connection antennaToReceiver85V connect antenna.signalOut to receiver85V.signalIn;
        connection antennaToReceiver85H connect antenna.signalOut to receiver85H.signalIn;

        // Connections: receivers to radiometers
        connection receiver19VToRadiometer connect receiver19V.signalOut to radiometer19V.signalIn;
        connection receiver19HToRadiometer connect receiver19H.signalOut to radiometer19H.signalIn;
        connection receiver22VToRadiometer connect receiver22V.signalOut to radiometer22V.signalIn;
        connection receiver37VToRadiometer connect receiver37V.signalOut to radiometer37V.signalIn;
        connection receiver37HToRadiometer connect receiver37H.signalOut to radiometer37H.signalIn;
        connection receiver85VToRadiometer connect receiver85V.signalOut to radiometer85V.signalIn;
        connection receiver85HToRadiometer connect receiver85H.signalOut to radiometer85H.signalIn;

        // Connections: calibration to each radiometer
        connection calibrationToRadiometer19V connect calibration.calibrationOut to radiometer19V.calibrationIn;
        connection calibrationToRadiometer19H connect calibration.calibrationOut to radiometer19H.calibrationIn;
        connection calibrationToRadiometer22V connect calibration.calibrationOut to radiometer22V.calibrationIn;
        connection calibrationToRadiometer37V connect calibration.calibrationOut to radiometer37V.calibrationIn;
        connection calibrationToRadiometer37H connect calibration.calibrationOut to radiometer37H.calibrationIn;
        connection calibrationToRadiometer85V connect calibration.calibrationOut to radiometer85V.calibrationIn;
        connection calibrationToRadiometer85H connect calibration.calibrationOut to radiometer85H.calibrationIn;

        // Connections: radiometers to signal processor
        connection radiometer19VToProcessor connect radiometer19V.calibratedOut to processor.calibratedIn[1];
        connection radiometer19HToProcessor connect radiometer19H.calibratedOut to processor.calibratedIn[2];
        connection radiometer22VToProcessor connect radiometer22V.calibratedOut to processor.calibratedIn[3];
        connection radiometer37VToProcessor connect radiometer37V.calibratedOut to processor.calibratedIn[4];
        connection radiometer37HToProcessor connect radiometer37H.calibratedOut to processor.calibratedIn[5];
        connection radiometer85VToProcessor connect radiometer85V.calibratedOut to processor.calibratedIn[6];
        connection radiometer85HToProcessor connect radiometer85H.calibratedOut to processor.calibratedIn[7];

        // Connection: scanner position to processor
        connection scannerToProcessor connect scanner.positionOut to processor.positionIn;

        // Connection: processor data output to external
        connection processorToOutput connect processor.dataOut to dataOutput;

        // ===== Instrument-level State Machine =====

        state def InstrumentOperation {
            state PowerOff;
            state Initialization {
                entry;
                // Initialize all subsystems
            }
            state Calibration {
                entry;
                // Perform initial calibration
            }
            state Standby {
                entry;
                // Ready but not actively sensing
            }
            state ActiveSensing {
                entry;
                // Continuously scan, receive, calibrate, and process
            }
            state DataProcessing {
                entry;
                // Package final data products
            }
            state SafeMode {
                entry;
                // Fallback state for anomalies
            }

            transition powerOff_to_init
                source PowerOff
                target Initialization
                when true;

            transition init_to_calibration
                source Initialization
                target Calibration
                when true;

            transition calibration_to_standby
                source Calibration
                target Standby
                when true;

            transition standby_to_active
                source Standby
                target ActiveSensing
                when true;

            transition active_to_processing
                source ActiveSensing
                target DataProcessing
                when true;

            transition processing_to_active
                source DataProcessing
                target ActiveSensing
                when true;

            transition any_to_safe
                source Initialization
                target SafeMode
                when false;

            transition safe_to_standby
                source SafeMode
                target Standby
                when true;
        }

        exhibit behavior : InstrumentOperation;
    }

    // ===== Requirements =====

    requirement def SwathCoverageRequirement {
        subject instrument : SSMIInstrument;
        attribute requiredSwath : SwathWidth = 1400 [km];
        require instrument.scanner.swathWidth >= requiredSwath;
    }

    requirement def ChannelCountRequirement {
        subject instrument : SSMIInstrument;
        attribute requiredChannels : Integer = 7;
        require instrument.receivers->size() == requiredChannels;
    }

    requirement def FrequencyCoverageRequirement {
        subject instrument : SSMIInstrument;
        require instrument.receiver19V.centerFrequency == 19.35 [GHz];
        require instrument.receiver19H.centerFrequency == 19.35 [GHz];
        require instrument.receiver22V.centerFrequency == 22.235 [GHz];
        require instrument.receiver37V.centerFrequency == 37.0 [GHz];
        require instrument.receiver37H.centerFrequency == 37.0 [GHz];
        require instrument.receiver85V.centerFrequency == 85.5 [GHz];
        require instrument.receiver85H.centerFrequency == 85.5 [GHz];
    }

    requirement def CalibrationAccuracyRequirement {
        subject instrument : SSMIInstrument;
        attribute maxCalibrationError : BrightnessTemperature = 1.0 [K];
        require instrument.calibration.warmTargetTemp > 290 [K];
        require instrument.calibration.coldTargetTemp < 3.0 [K];
    }

    requirement def DataProductRequirement {
        subject instrument : SSMIInstrument;
        require instrument.processor.dataOut.data->notEmpty();
        require instrument.processor.dataOut.data.timestamp > 0 [s];
    }

    requirement def OperationalSequenceRequirement {
        subject instrument : SSMIInstrument;
        require instrument->exhibitBehavior()->isKindOf(InstrumentOperation);
    }

    requirement SwathCoverage : SwathCoverageRequirement {
        subject instrument : SSMIInstrument;
    }

    requirement ChannelCount : ChannelCountRequirement {
        subject instrument : SSMIInstrument;
    }

    requirement FrequencyCoverage : FrequencyCoverageRequirement {
        subject instrument : SSMIInstrument;
    }

    requirement CalibrationAccuracy : CalibrationAccuracyRequirement {
        subject instrument : SSMIInstrument;
    }

    requirement DataProductIntegrity : DataProductRequirement {
        subject instrument : SSMIInstrument;
    }

    requirement OperationalSequence : OperationalSequenceRequirement {
        subject instrument : SSMIInstrument;
    }

    // ===== Satellite Context =====

    part def SatelliteBus {
        attribute orbitAltitude : Real = 833 [km];
        attribute orbitInclination : Angle = 98.8 [deg];

        part ssmi : SSMIInstrument;

        port def TelemetryDownlinkPort {
            out telemetry : SensorMeasurementData;
        }

        port downlink : TelemetryDownlinkPort;

        connection ssmiToDownlink connect ssmi.dataOutput to downlink;
    }

    part ssmiSatellite : SatelliteBus;

}
