package TemperatureSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQThermodynamics::*;

    // ---- Value Types ----

    value type TemperatureValue :> Real {
        unit 'degC';
    }

    value type VarianceValue :> Real {
        unit 'degC**2';
    }

    value type FrequencyValue :> Real {
        unit 'Hz';
    }

    value type TimeValue :> Real {
        unit 's';
    }

    value type ConfidenceValue :> Real {
        doc "Confidence level in [0.0, 1.0].";
    }

    value def GridCoordinate {
        attribute row : Integer;
        attribute col : Integer;
    }

    // ---- Item Definitions ----

    item def RawTemperatureReading {
        attribute sensorId : Integer;
        attribute coordinate : GridCoordinate;
        attribute timestamp : TimeValue;
        attribute rawValue : TemperatureValue;
        attribute valid : Boolean;
    }

    item def ProcessedTemperatureReading {
        attribute sensorId : Integer;
        attribute coordinate : GridCoordinate;
        attribute timestamp : TimeValue;
        attribute calibratedValue : TemperatureValue;
        attribute confidence : ConfidenceValue;
    }

    item def AggregatedDataPacket {
        attribute timestamp : TimeValue;
        attribute averageTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute variance : VarianceValue;
        attribute activeSensorCount : Integer;
        attribute totalSensorCount : Integer;
    }

    // ---- Port Definitions ----

    port def RawDataOutPort {
        out rawReading : RawTemperatureReading;
    }

    port def RawDataInPort {
        in rawReading : RawTemperatureReading;
    }

    port def ProcessedDataOutPort {
        out processedReading : ProcessedTemperatureReading;
    }

    port def ProcessedDataInPort {
        in processedReading : ProcessedTemperatureReading;
    }

    port def AggregatedDataOutPort {
        out dataPacket : AggregatedDataPacket;
    }

    // ---- Action Definitions ----

    action def TakeRawReading {
        out reading : RawTemperatureReading;
    }

    action def ValidateRawData {
        in raw : RawTemperatureReading;
        out validated : RawTemperatureReading;
    }

    action def ApplyCalibration {
        in raw : RawTemperatureReading;
        attribute offset : TemperatureValue;
        attribute scale : Real;
        out calibrated : ProcessedTemperatureReading;
    }

    action def FilterNoise {
        in reading : ProcessedTemperatureReading;
        out filtered : ProcessedTemperatureReading;
    }

    action def ComputeStatistics {
        in readings : ProcessedTemperatureReading[*];
        out packet : AggregatedDataPacket;
    }

    action def AttemptSelfRecovery {
        out recovered : Boolean;
    }

    // ---- State Machine: Sensor Lifecycle ----

    state def SensorLifecycle {
        entry; then standby;

        state standby {
            doc "Sensor is powered but not actively sensing.";
            entry;
        }

        transition standby_to_active
            first standby
            then active
            when sensorEnabled;

        state active {
            doc "Sensor is continuously taking raw readings.";
            do takeContinuousReadings;
            transition active_to_fault
                first active
                then fault
                when faultDetected;
            transition active_to_standby
                first active
                then standby
                when sensorDisabled;
        }

        state fault {
            doc "Sensor is in a fault state and attempting self-recovery.";
            do recoveryAction;
            transition fault_to_active
                first fault
                then active
                when recoverySuccessful;
            transition fault_to_standby
                first fault
                then standby
                when sensorReset;
        }

        action takeContinuousReadings : TakeRawReading;
        action recoveryAction : AttemptSelfRecovery;
    }

    // ---- Part Definitions ----

    part def TemperatureSensor {
        attribute sensorId : Integer;
        attribute coordinate : GridCoordinate;
        attribute calibrationOffset : TemperatureValue;
        attribute calibrationScale : Real = 1.0;
        attribute samplingRate : FrequencyValue = 100.0;

        port rawOut : RawDataOutPort;

        exhibit state SensorLifecycle;

        action takeReading : TakeRawReading {
            out reading;
        }
    }

    part def SignalProcessor {
        attribute processorId : Integer;
        attribute pairedSensorId : Integer;
        attribute noiseFilterStrength : Real = 0.5;

        port rawIn : RawDataInPort;
        port processedOut : ProcessedDataOutPort;

        action validate : ValidateRawData;
        action calibrate : ApplyCalibration;
        action filter : FilterNoise;

        flow from rawIn.rawReading to validate.raw;
        flow from validate.validated to calibrate.raw;
        flow from calibrate.calibrated to filter.reading;
        flow from filter.filtered to processedOut.processedReading;
    }

    part def DataAggregator {
        attribute outputFrequency : FrequencyValue = 10.0;
        attribute minOperationalSensors : Integer = 8;

        port processedIn : ProcessedDataInPort[16];
        port aggregatedOut : AggregatedDataOutPort;

        action computeStats : ComputeStatistics;

        flow from processedIn.processedReading to computeStats.readings;
        flow from computeStats.packet to aggregatedOut.dataPacket;
    }

    part def SensorGrid {
        part sensors : TemperatureSensor[16];

        assert gridLayoutConstraint {
            doc "Sensors are arranged in a 4x4 grid.";
            constraint { sensors.size == 16 }
        }
    }

    part def TemperatureSensingUnit {
        doc "Advanced grid-based temperature sensing unit for distributed thermal monitoring.";

        part grid : SensorGrid {
            part sensors : TemperatureSensor[16];
        }

        part processors : SignalProcessor[16];

        part aggregator : DataAggregator;

        port systemOutput : AggregatedDataOutPort;

        // One-to-one raw data connections: each sensor to its paired processor
        connection rawLinks
            connect grid.sensors.rawOut to processors.rawIn;

        // Processed data connections: all processors feed into the aggregator
        connection processedLinks
            connect processors.processedOut to aggregator.processedIn;

        // Final output connection
        connection outputLink
            connect aggregator.aggregatedOut to systemOutput;

        // Item flows
        item flow rawFlow : RawTemperatureReading
            from grid.sensors.rawOut.rawReading
            to processors.rawIn.rawReading;

        item flow processedFlow : ProcessedTemperatureReading
            from processors.processedOut.processedReading
            to aggregator.processedIn.processedReading;

        item flow aggregatedFlow : AggregatedDataPacket
            from aggregator.aggregatedOut.dataPacket
            to systemOutput.dataPacket;
    }

    // ---- Requirements ----

    requirement def ThermalMonitoringRequirement {
        doc "Base requirement for distributed thermal monitoring.";
    }

    requirement def GridLayoutRequirement :> ThermalMonitoringRequirement {
        doc "The sensor grid shall consist of 16 individual temperature sensors arranged in a 4x4 configuration.";
        subject sensingUnit : TemperatureSensingUnit;
        require sensingUnit.grid.sensors.size == 16;
    }

    requirement def OneToOneProcessingRequirement :> ThermalMonitoringRequirement {
        doc "Each sensor shall be paired with a dedicated signal processor for individual data refinement.";
        subject sensingUnit : TemperatureSensingUnit;
        require sensingUnit.processors.size == 16;
    }

    requirement def OutputFrequencyRequirement :> ThermalMonitoringRequirement {
        doc "The unit shall output aggregated data packets at a frequency of 10 Hz.";
        subject sensingUnit : TemperatureSensingUnit;
        require sensingUnit.aggregator.outputFrequency == 10.0;
    }

    requirement def FaultToleranceRequirement :> ThermalMonitoringRequirement {
        doc "The unit shall continue to produce valid aggregated output even if several sensors fail.";
        subject sensingUnit : TemperatureSensingUnit;
        require sensingUnit.aggregator.minOperationalSensors <= 8;
    }

    requirement def StatisticalOutputRequirement :> ThermalMonitoringRequirement {
        doc "The aggregated data packet shall include average, maximum, minimum, and variance of grid temperatures.";
        subject packet : AggregatedDataPacket;
        require packet.averageTemp != null
            and packet.maxTemp != null
            and packet.minTemp != null
            and packet.variance != null;
    }

    requirement def SensorLifecycleRequirement :> ThermalMonitoringRequirement {
        doc "Each sensor shall support standby, active sensing, and fault states with self-recovery capability.";
        subject sensor : TemperatureSensor;
        require sensor.sensorId >= 0;
    }

    requirement def CalibrationRequirement :> ThermalMonitoringRequirement {
        doc "Each signal processor shall apply calibration adjustments to correct for sensor inaccuracies.";
        subject processor : SignalProcessor;
        require processor.pairedSensorId >= 0;
    }

    // ---- Verification ----

    verification def GridLayoutVerification {
        subject sensingUnit : TemperatureSensingUnit;
        objective {
            doc "Verify that the sensing unit contains exactly 16 sensors in a 4x4 grid.";
        }
    }

    verification def OutputFrequencyVerification {
        subject sensingUnit : TemperatureSensingUnit;
        objective {
            doc "Verify that the aggregator outputs data at 10 Hz.";
        }
    }

    verification def FaultToleranceVerification {
        subject sensingUnit : TemperatureSensingUnit;
        objective {
            doc "Verify that the unit produces valid output with up to 8 sensor failures.";
        }
    }
}
