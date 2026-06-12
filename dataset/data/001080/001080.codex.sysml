package HeartbeatSensingUnitModel {
    import ScalarValues::*;
    import SI::*;

    attribute def BeatsPerMinute :> Real {
        doc "Heart rate measured in beats per minute.";
    }

    attribute def Millivolt :> Real;
    attribute def Millisecond :> Real;
    attribute def Percent :> Real;
    attribute def Celsius :> Real;
    attribute def Volt :> Real;
    attribute def Milliampere :> Real;

    enum def SensorMode {
        enum idle;
        enum acquiring;
        enum validating;
        enum reporting;
        enum faulted;
    }

    item def BioelectricPulseSignal {
        attribute amplitude : Millivolt;
        attribute samplePeriod : Millisecond;
        attribute signalQuality : Percent;
    }

    item def HeartbeatMeasurement {
        attribute heartRate : BeatsPerMinute;
        attribute confidence : Percent;
        attribute timestamp : Millisecond;
        attribute valid : Boolean;
    }

    item def PowerSupply {
        attribute voltage : Volt;
        attribute currentLimit : Milliampere;
    }

    port def PowerPort {
        in item power : PowerSupply;
    }

    port def HeartbeatSignalPort {
        out item pulseSignal : BioelectricPulseSignal;
    }

    port def MeasurementPort {
        out item measurement : HeartbeatMeasurement;
    }

    port def DiagnosticPort {
        out item mode : SensorMode;
        out item faultCode : String;
    }

    part def HeartbeatSensor {
        attribute operatingTemperature : Celsius;
        attribute minimumDetectableAmplitude : Millivolt = 0.25;
        attribute nominalSamplePeriod : Millisecond = 4.0;

        port powerIn : PowerPort;
        port signalOut : HeartbeatSignalPort;
    }

    part def SignalConditioner {
        attribute gain : Real = 40.0;
        attribute lowPassCutoffHz : Real = 30.0;
        attribute highPassCutoffHz : Real = 0.5;

        port rawSignalIn : HeartbeatSignalPort;
        port conditionedSignalOut : HeartbeatSignalPort;
    }

    part def HeartbeatProcessor {
        attribute minimumValidRate : BeatsPerMinute = 30.0;
        attribute maximumValidRate : BeatsPerMinute = 220.0;
        attribute requiredConfidence : Percent = 85.0;

        port conditionedSignalIn : HeartbeatSignalPort;
        port measurementOut : MeasurementPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def SensingUnit {
        attribute unitId : String = "HeartbeatSensingUnit-001";
        attribute measurementRangeLow : BeatsPerMinute = 30.0;
        attribute measurementRangeHigh : BeatsPerMinute = 220.0;
        attribute maximumLatency : Millisecond = 1000.0;

        port powerInput : PowerPort;
        port heartbeatOutput : MeasurementPort;
        port diagnostics : DiagnosticPort;

        part sensor : HeartbeatSensor;
        part conditioner : SignalConditioner;
        part processor : HeartbeatProcessor;

        connect powerInput to sensor.powerIn;
        connect sensor.signalOut to conditioner.rawSignalIn;
        connect conditioner.conditionedSignalOut to processor.conditionedSignalIn;
        connect processor.measurementOut to heartbeatOutput;
        connect processor.diagnosticOut to diagnostics;
    }

    action def AcquireHeartbeatSignal {
        in item power : PowerSupply;
        out item rawSignal : BioelectricPulseSignal;

        constraint sufficientVoltage {
            power.voltage >= 3.0 and power.voltage <= 5.5
        }
    }

    action def ConditionHeartbeatSignal {
        in item rawSignal : BioelectricPulseSignal;
        out item filteredSignal : BioelectricPulseSignal;

        constraint improvedQuality {
            filteredSignal.signalQuality >= rawSignal.signalQuality
        }
    }

    action def CalculateHeartRate {
        in item filteredSignal : BioelectricPulseSignal;
        out item measurement : HeartbeatMeasurement;

        constraint validMeasurementRange {
            measurement.heartRate >= 30.0 and measurement.heartRate <= 220.0
        }
    }

    action def ReportMeasurement {
        in item measurement : HeartbeatMeasurement;
        out item transmittedMeasurement : HeartbeatMeasurement;

        constraint preserveValue {
            transmittedMeasurement.heartRate == measurement.heartRate and
            transmittedMeasurement.valid == measurement.valid
        }
    }

    state def HeartbeatSensingLifecycle {
        entry action initialize;

        state Off;
        state SelfTest;
        state Idle;
        state Acquiring;
        state Processing;
        state Reporting;
        state Fault;

        transition initial then Off;

        transition Off_to_SelfTest
            first Off
            accept PowerSupply
            then SelfTest;

        transition SelfTest_to_Idle
            first SelfTest
            if selfTestPassed == true
            then Idle;

        transition SelfTest_to_Fault
            first SelfTest
            if selfTestPassed == false
            then Fault;

        transition Idle_to_Acquiring
            first Idle
            accept startMeasurement
            then Acquiring;

        transition Acquiring_to_Processing
            first Acquiring
            if signalDetected == true
            then Processing;

        transition Acquiring_to_Fault
            first Acquiring
            if signalTimeout == true
            then Fault;

        transition Processing_to_Reporting
            first Processing
            if measurementValid == true
            then Reporting;

        transition Processing_to_Acquiring
            first Processing
            if measurementValid == false
            then Acquiring;

        transition Reporting_to_Idle
            first Reporting
            after 1000 ms
            then Idle;

        transition Fault_to_SelfTest
            first Fault
            accept reset
            then SelfTest;
    }

    requirement def HeartbeatMeasurementRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.measurementRangeLow <= 30.0 and
            sensingUnit.measurementRangeHigh >= 220.0
        }

        doc "The sensing unit shall measure heartbeat rate over the adult and elevated-exertion operating range."
    }

    requirement def SensorUseRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.sensor.minimumDetectableAmplitude <= 0.25
        }

        doc "The sensing unit shall measure the relevant physiological quantity using a Heartbeat sensor."
    }

    requirement def LatencyRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.maximumLatency <= 1000.0
        }

        doc "The sensing unit shall produce a valid heartbeat measurement within one second of signal acquisition."
    }

    requirement def ConfidenceRequirement {
        subject processor : HeartbeatProcessor;

        require constraint {
            processor.requiredConfidence >= 85.0
        }

        doc "The processor shall report heartbeat measurements with at least 85 percent confidence when signal quality is sufficient."
    }

    requirement def PowerRequirement {
        subject sensor : HeartbeatSensor;

        require constraint {
            sensor.powerIn.power.voltage >= 3.0 and
            sensor.powerIn.power.voltage <= 5.5
        }

        doc "The Heartbeat sensor shall operate from a regulated low-voltage supply."
    }

    satisfy HeartbeatMeasurementRequirement by SensingUnit;
    satisfy SensorUseRequirement by SensingUnit.sensor;
    satisfy LatencyRequirement by SensingUnit.processor;
    satisfy ConfidenceRequirement by SensingUnit.processor;
    satisfy PowerRequirement by SensingUnit.sensor;
}