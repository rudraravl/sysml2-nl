package MagnetoresistanceSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def MagneticFluxDensity :> Real {
        unit = "T";
    }

    attribute def ElectricalResistance :> Real {
        unit = "Ohm";
    }

    attribute def ElectricalCurrent :> Real {
        unit = "A";
    }

    attribute def ElectricalVoltage :> Real {
        unit = "V";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def Sensitivity :> Real {
        unit = "V/T";
    }

    attribute def Frequency :> Real {
        unit = "Hz";
    }

    attribute def Ratio :> Real {
        unit = "1";
    }

    item def MagneticFieldSignal {
        attribute fluxDensity : MagneticFluxDensity;
        attribute directionAngle : Real {
            unit = "deg";
        }
        attribute bandwidth : Frequency;
    }

    item def ResistanceChangeSignal {
        attribute nominalResistance : ElectricalResistance;
        attribute deltaResistance : ElectricalResistance;
        attribute magnetoresistanceRatio : Ratio;
    }

    item def ElectricalBias {
        attribute current : ElectricalCurrent;
        attribute voltage : ElectricalVoltage;
    }

    item def AnalogVoltageSignal {
        attribute voltage : ElectricalVoltage;
        attribute noiseRms : ElectricalVoltage;
        attribute bandwidth : Frequency;
    }

    item def DigitalMagneticMeasurement {
        attribute measuredFluxDensity : MagneticFluxDensity;
        attribute temperatureCompensated : Boolean;
        attribute valid : Boolean;
    }

    port def MagneticFieldPort {
        in item field : MagneticFieldSignal;
    }

    port def BiasPort {
        in item bias : ElectricalBias;
    }

    port def ResistanceSensePort {
        out item resistanceChange : ResistanceChangeSignal;
    }

    port def AnalogSignalPort {
        out item signal : AnalogVoltageSignal;
    }

    port def DigitalMeasurementPort {
        out item measurement : DigitalMagneticMeasurement;
    }

    part def MagnetoresistiveElement {
        attribute nominalResistance : ElectricalResistance = 120.0;
        attribute operatingTemperature : Temperature = 298.15;
        attribute magnetoresistanceCoefficient : Ratio = 0.035;
        attribute maxFluxDensity : MagneticFluxDensity = 0.25;

        port magneticInput : MagneticFieldPort;
        port biasInput : BiasPort;
        port resistanceOutput : ResistanceSensePort;

        action senseResistanceChange {
            in item appliedField : MagneticFieldSignal;
            in item appliedBias : ElectricalBias;
            out item resistanceChange : ResistanceChangeSignal;

            first start;
            then computeDeltaResistance;
            then publishResistanceChange;
            then done;

            action computeDeltaResistance;
            action publishResistanceChange;
        }

        state def ElementOperatingState {
            state idle;
            state biased;
            state saturated;
            state faulted;

            entry;
            first idle;

            transition idle_to_biased
                first idle
                accept ElectricalBias
                then biased;

            transition biased_to_saturated
                first biased
                if magneticInput.field.fluxDensity > maxFluxDensity
                then saturated;

            transition saturated_to_biased
                first saturated
                if magneticInput.field.fluxDensity <= maxFluxDensity
                then biased;

            transition biased_to_faulted
                first biased
                if operatingTemperature > 398.15
                then faulted;
        }
    }

    part def BiasCircuit {
        attribute targetBiasCurrent : ElectricalCurrent = 0.005;
        attribute complianceVoltage : ElectricalVoltage = 5.0;
        attribute currentTolerance : Ratio = 0.01;

        port biasOutput : BiasPort;

        action regulateBias {
            out item regulatedBias : ElectricalBias;

            first start;
            then measureCurrent;
            then adjustDriveVoltage;
            then emitBias;
            then done;

            action measureCurrent;
            action adjustDriveVoltage;
            action emitBias;
        }
    }

    part def WheatstoneBridge {
        attribute bridgeSupplyVoltage : ElectricalVoltage = 3.3;
        attribute commonModeVoltage : ElectricalVoltage = 1.65;
        attribute bridgeImbalanceGain : Ratio = 0.25;

        port resistanceInput : ResistanceSensePort;
        port analogOutput : AnalogSignalPort;

        action convertResistanceToVoltage {
            in item resistanceChange : ResistanceChangeSignal;
            out item bridgeVoltage : AnalogVoltageSignal;

            first start;
            then calculateBridgeImbalance;
            then filterBridgeOutput;
            then outputVoltage;
            then done;

            action calculateBridgeImbalance;
            action filterBridgeOutput;
            action outputVoltage;
        }
    }

    part def SignalConditioner {
        attribute instrumentationGain : Ratio = 80.0;
        attribute lowPassCutoff : Frequency = 2000.0;
        attribute offsetVoltage : ElectricalVoltage = 0.0;
        attribute outputNoiseRms : ElectricalVoltage = 0.0008;

        port rawAnalogInput : AnalogSignalPort;
        port conditionedAnalogOutput : AnalogSignalPort;

        action amplifyAndFilter {
            in item rawSignal : AnalogVoltageSignal;
            out item conditionedSignal : AnalogVoltageSignal;

            first start;
            then removeCommonMode;
            then amplifyDifferentialSignal;
            then lowPassFilter;
            then publishConditionedSignal;
            then done;

            action removeCommonMode;
            action amplifyDifferentialSignal;
            action lowPassFilter;
            action publishConditionedSignal;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature = 298.15;
        attribute accuracy : Temperature = 1.0;

        port temperatureOutput : AnalogSignalPort;

        action reportTemperature {
            out item temperatureVoltage : AnalogVoltageSignal;

            first start;
            then sampleTemperature;
            then encodeAsVoltage;
            then done;

            action sampleTemperature;
            action encodeAsVoltage;
        }
    }

    part def MeasurementProcessor {
        attribute adcResolutionBits : Integer = 16;
        attribute samplingRate : Frequency = 10000.0;
        attribute sensitivity : Sensitivity = 1.2;
        attribute zeroFieldOffset : ElectricalVoltage = 1.65;
        attribute validFluxRange : MagneticFluxDensity = 0.20;

        port conditionedSignalInput : AnalogSignalPort;
        port temperatureSignalInput : AnalogSignalPort;
        port measurementOutput : DigitalMeasurementPort;

        action estimateMagneticField {
            in item conditionedSignal : AnalogVoltageSignal;
            in item temperatureSignal : AnalogVoltageSignal;
            out item measurement : DigitalMagneticMeasurement;

            first start;
            then sampleAnalogInputs;
            then subtractZeroFieldOffset;
            then compensateTemperatureDrift;
            then calculateFluxDensity;
            then validateMeasurement;
            then publishMeasurement;
            then done;

            action sampleAnalogInputs;
            action subtractZeroFieldOffset;
            action compensateTemperatureDrift;
            action calculateFluxDensity;
            action validateMeasurement;
            action publishMeasurement;
        }

        state def ProcessorState {
            state initializing;
            state calibrating;
            state measuring;
            state invalid;
            state reporting;

            entry;
            first initializing;

            transition initialization_complete
                first initializing
                then calibrating;

            transition calibration_complete
                first calibrating
                then measuring;

            transition measurement_valid
                first measuring
                if measurementOutput.measurement.valid
                then reporting;

            transition measurement_invalid
                first measuring
                if not measurementOutput.measurement.valid
                then invalid;

            transition retry_measurement
                first invalid
                then measuring;

            transition report_complete
                first reporting
                then measuring;
        }
    }

    part def MagnetoresistanceBasedMagneticFieldSensor {
        doc
        /*
         * Primary function:
         * Detect an external magnetic field by using the magnetoresistance effect,
         * where the electrical resistance of a biased sensing element changes as
         * magnetic flux density changes. The system converts that resistance change
         * into a conditioned voltage and then into a calibrated digital magnetic
         * field measurement.
         */

        port externalMagneticField : MagneticFieldPort;
        port digitalFieldMeasurement : DigitalMeasurementPort;

        part sensingElement : MagnetoresistiveElement;
        part biasCircuit : BiasCircuit;
        part bridge : WheatstoneBridge;
        part conditioner : SignalConditioner;
        part temperatureSensor : TemperatureSensor;
        part processor : MeasurementProcessor;

        connect externalMagneticField to sensingElement.magneticInput;
        connect biasCircuit.biasOutput to sensingElement.biasInput;
        connect sensingElement.resistanceOutput to bridge.resistanceInput;
        connect bridge.analogOutput to conditioner.rawAnalogInput;
        connect conditioner.conditionedAnalogOutput to processor.conditionedSignalInput;
        connect temperatureSensor.temperatureOutput to processor.temperatureSignalInput;
        connect processor.measurementOutput to digitalFieldMeasurement;

        action performMagneticFieldMeasurement {
            in item field : MagneticFieldSignal;
            out item measurement : DigitalMagneticMeasurement;

            first start;
            then applyBias;
            then senseMagnetoresistiveChange;
            then convertToBridgeVoltage;
            then conditionVoltageSignal;
            then measureTemperature;
            then computeDigitalFieldMeasurement;
            then outputResult;
            then done;

            action applyBias;
            action senseMagnetoresistiveChange;
            action convertToBridgeVoltage;
            action conditionVoltageSignal;
            action measureTemperature;
            action computeDigitalFieldMeasurement;
            action outputResult;
        }

        state def SensorLifecycle {
            state poweredOff;
            state selfTest;
            state zeroFieldCalibration;
            state ready;
            state measuring;
            state degraded;
            state failed;

            entry;
            first poweredOff;

            transition power_on
                first poweredOff
                then selfTest;

            transition self_test_passed
                first selfTest
                then zeroFieldCalibration;

            transition calibration_complete
                first zeroFieldCalibration
                then ready;

            transition begin_measurement
                first ready
                accept MagneticFieldSignal
                then measuring;

            transition measurement_complete
                first measuring
                then ready;

            transition excessive_temperature
                first measuring
                if sensingElement.operatingTemperature > 373.15
                then degraded;

            transition temperature_normal
                first degraded
                if sensingElement.operatingTemperature <= 373.15
                then ready;

            transition unrecoverable_fault
                first selfTest
                then failed;
        }
    }

    requirement def DetectMagneticFieldRequirement {
        subject sensor : MagnetoresistanceBasedMagneticFieldSensor;

        attribute requiredRange : MagneticFluxDensity = 0.20;
        attribute requiredSensitivity : Sensitivity = 1.0;
        attribute maximumNoise : ElectricalVoltage = 0.002;
        attribute operatingTemperatureMinimum : Temperature = 253.15;
        attribute operatingTemperatureMaximum : Temperature = 373.15;

        doc
        /*
         * The magnetoresistance-based system shall detect an applied magnetic
         * field and provide a digital measurement of magnetic flux density.
         */
    }

    requirement def BiasStabilityRequirement {
        subject biasCircuit : BiasCircuit;

        attribute maximumCurrentError : Ratio = 0.01;

        doc
        /*
         * The bias circuit shall maintain magnetoresistive element current within
         * one percent of the target current during normal measurement operation.
         */
    }

    requirement def SignalConversionRequirement {
        subject bridge : WheatstoneBridge;

        attribute minimumBridgeSupplyVoltage : ElectricalVoltage = 3.0;
        attribute maximumBridgeSupplyVoltage : ElectricalVoltage = 3.6;

        doc
        /*
         * The bridge circuit shall convert resistance variation from the
         * magnetoresistive element into a differential voltage suitable for
         * amplification and filtering.
         */
    }

    requirement def TemperatureCompensationRequirement {
        subject processor : MeasurementProcessor;

        attribute compensationEnabled : Boolean = true;

        doc
        /*
         * The processor shall compensate the calculated magnetic field measurement
         * for temperature-dependent resistance and offset drift.
         */
    }

    satisfy DetectMagneticFieldRequirement by MagnetoresistanceBasedMagneticFieldSensor;
    satisfy BiasStabilityRequirement by BiasCircuit;
    satisfy SignalConversionRequirement by WheatstoneBridge;
    satisfy TemperatureCompensationRequirement by MeasurementProcessor;
}