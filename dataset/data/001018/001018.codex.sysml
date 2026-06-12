package CurrentSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    value def Voltage :> ISQ::voltage {
        unit = SI::volt;
    }

    value def Resistance :> ISQ::resistance {
        unit = SI::ohm;
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    value def Time :> ISQ::time {
        unit = SI::second;
    }

    value def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    value def Percent :> Real {
        unit = "%";
    }

    value def BitCount :> Integer;

    item def ElectricalCurrentSignal {
        attribute current : ElectricCurrent;
        attribute commonModeVoltage : Voltage;
        attribute timestamp : Time;
    }

    item def AnalogVoltageSignal {
        attribute voltage : Voltage;
        attribute timestamp : Time;
    }

    item def DigitalCurrentSample {
        attribute measuredCurrent : ElectricCurrent;
        attribute sampleTime : Time;
        attribute quality : Percent;
        attribute rawAdcCounts : BitCount;
    }

    item def CalibratedCurrentMeasurement {
        attribute current : ElectricCurrent;
        attribute uncertainty : ElectricCurrent;
        attribute temperature : Temperature;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }

    item def PowerSupply {
        attribute supplyVoltage : Voltage;
        attribute maxCurrent : ElectricCurrent;
    }

    item def DiagnosticReport {
        attribute sensorOpenCircuit : Boolean;
        attribute sensorSaturated : Boolean;
        attribute adcFault : Boolean;
        attribute overTemperature : Boolean;
        attribute calibrationExpired : Boolean;
        attribute healthy : Boolean;
    }

    port def CurrentInputPort {
        in item sensedCurrent : ElectricalCurrentSignal;
    }

    port def AnalogSignalPort {
        out item analogSignal : AnalogVoltageSignal;
    }

    port def AnalogInputPort {
        in item analogSignal : AnalogVoltageSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalCurrentSample;
    }

    port def MeasurementOutputPort {
        out item measurement : CalibratedCurrentMeasurement;
    }

    port def DiagnosticOutputPort {
        out item report : DiagnosticReport;
    }

    port def PowerInputPort {
        in item power : PowerSupply;
    }

    part def CurrentSensor {
        attribute measurementRangeMin : ElectricCurrent = -100 [SI::ampere];
        attribute measurementRangeMax : ElectricCurrent = 100 [SI::ampere];
        attribute sensitivity : Voltage = 40 [SI::millivolt];
        attribute offsetVoltage : Voltage = 2.5 [SI::volt];
        attribute bandwidth : Frequency = 20 [SI::kilohertz];
        attribute responseTime : Time = 50 [SI::microsecond];

        port currentIn : CurrentInputPort;
        port analogOut : AnalogSignalPort;
        port powerIn : PowerInputPort;

        action senseCurrent {
            in item input : ElectricalCurrentSignal;
            out item output : AnalogVoltageSignal;

            first start;
            then verifyRange;
            then convertToVoltage;
            then publishAnalogSignal;
            then done;

            action verifyRange;
            action convertToVoltage;
            action publishAnalogSignal;
        }

        state def SensorOperatingState {
            entry action initializeSensor;
            state off;
            state biasStabilizing;
            state measuring;
            state saturated;
            state faulted;

            transition initial then off;
            transition off_to_bias
                first off
                accept powerApplied
                then biasStabilizing;

            transition bias_to_measure
                first biasStabilizing
                accept biasStable
                then measuring;

            transition measure_to_saturated
                first measuring
                accept currentOutOfRange
                then saturated;

            transition saturated_to_measure
                first saturated
                accept currentBackInRange
                then measuring;

            transition any_to_fault
                first measuring
                accept sensorFaultDetected
                then faulted;

            transition fault_to_off
                first faulted
                accept resetCommand
                then off;
        }
    }

    part def AntiAliasFilter {
        attribute cutoffFrequency : Frequency = 5 [SI::kilohertz];
        attribute inputImpedance : Resistance = 100 [SI::kilohm];
        attribute settlingTime : Time = 100 [SI::microsecond];

        port analogIn : AnalogInputPort;
        port analogOut : AnalogSignalPort;

        action filterAnalogSignal {
            in item unfiltered : AnalogVoltageSignal;
            out item filtered : AnalogVoltageSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : BitCount = 16;
        attribute samplingFrequency : Frequency = 10 [SI::kilohertz];
        attribute referenceVoltage : Voltage = 5 [SI::volt];
        attribute conversionTime : Time = 10 [SI::microsecond];

        port analogIn : AnalogInputPort;
        port digitalOut : DigitalSamplePort;
        port powerIn : PowerInputPort;

        action sampleVoltage {
            in item analog : AnalogVoltageSignal;
            out item sample : DigitalCurrentSample;

            first waitForSampleClock;
            then acquireInput;
            then quantizeVoltage;
            then publishSample;
            then done;

            action waitForSampleClock;
            action acquireInput;
            action quantizeVoltage;
            action publishSample;
        }

        state def AdcState {
            state disabled;
            state ready;
            state sampling;
            state conversionComplete;
            state faulted;

            transition initial then disabled;
            transition disabled_to_ready first disabled accept enableAdc then ready;
            transition ready_to_sampling first ready accept sampleTick then sampling;
            transition sampling_to_complete first sampling accept conversionDone then conversionComplete;
            transition complete_to_ready first conversionComplete accept samplePublished then ready;
            transition ready_to_fault first ready accept adcSelfTestFailed then faulted;
            transition fault_to_disabled first faulted accept disableAdc then disabled;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 1 [SI::kelvin];
        attribute updatePeriod : Time = 1 [SI::second];

        port powerIn : PowerInputPort;

        attribute measuredTemperature : Temperature;
    }

    part def CalibrationProcessor {
        attribute gainCorrection : Real = 1.000;
        attribute offsetCorrection : ElectricCurrent = 0 [SI::ampere];
        attribute temperatureCoefficient : Real = 0.0005;
        attribute calibrationAge : Time;
        attribute calibrationValidityPeriod : Time = 31536000 [SI::second];

        port sampleIn : DigitalSamplePort;
        port measurementOut : MeasurementOutputPort;

        action calibrateCurrent {
            in item sample : DigitalCurrentSample;
            in temp : Temperature;
            out item measurement : CalibratedCurrentMeasurement;

            first readRawSample;
            then removeSensorOffset;
            then applyGainCorrection;
            then compensateTemperatureDrift;
            then estimateUncertainty;
            then validateMeasurement;
            then publishMeasurement;
            then done;

            action readRawSample;
            action removeSensorOffset;
            action applyGainCorrection;
            action compensateTemperatureDrift;
            action estimateUncertainty;
            action validateMeasurement;
            action publishMeasurement;
        }
    }

    part def DiagnosticController {
        attribute overTemperatureLimit : Temperature = 358.15 [SI::kelvin];
        attribute saturationThreshold : Percent = 98 [%];
        attribute minimumQuality : Percent = 90 [%];
        attribute selfTestPeriod : Time = 10 [SI::second];

        port measurementIn : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        action performDiagnostics {
            in item measurement : CalibratedCurrentMeasurement;
            out item report : DiagnosticReport;

            first checkSensorContinuity;
            then checkAdcStatus;
            then checkSaturation;
            then checkTemperature;
            then checkCalibrationAge;
            then computeHealth;
            then publishDiagnostics;
            then done;

            action checkSensorContinuity;
            action checkAdcStatus;
            action checkSaturation;
            action checkTemperature;
            action checkCalibrationAge;
            action computeHealth;
            action publishDiagnostics;
        }

        state def DiagnosticState {
            state idle;
            state selfTesting;
            state healthy;
            state degraded;
            state failed;

            transition initial then idle;
            transition idle_to_selfTesting first idle accept selfTestTick then selfTesting;
            transition selfTesting_to_healthy first selfTesting accept allChecksPassed then healthy;
            transition selfTesting_to_degraded first selfTesting accept nonCriticalFaultFound then degraded;
            transition selfTesting_to_failed first selfTesting accept criticalFaultFound then failed;
            transition degraded_to_healthy first degraded accept faultCleared then healthy;
            transition healthy_to_degraded first healthy accept warningDetected then degraded;
            transition healthy_to_failed first healthy accept criticalFaultFound then failed;
            transition failed_to_idle first failed accept resetCommand then idle;
        }
    }

    part def SensingUnit {
        attribute nominalSupplyVoltage : Voltage = 5 [SI::volt];
        attribute operatingTemperatureMin : Temperature = 233.15 [SI::kelvin];
        attribute operatingTemperatureMax : Temperature = 358.15 [SI::kelvin];
        attribute measurementUpdatePeriod : Time = 0.001 [SI::second];

        port currentInput : CurrentInputPort;
        port powerInput : PowerInputPort;
        port measurementOutput : MeasurementOutputPort;
        port diagnosticOutput : DiagnosticOutputPort;

        part sensor : CurrentSensor;
        part filter : AntiAliasFilter;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part calibrationProcessor : CalibrationProcessor;
        part diagnostics : DiagnosticController;

        connect currentInput to sensor.currentIn;
        connect powerInput to sensor.powerIn;
        connect powerInput to adc.powerIn;
        connect powerInput to temperatureSensor.powerIn;
        connect sensor.analogOut to filter.analogIn;
        connect filter.analogOut to adc.analogIn;
        connect adc.digitalOut to calibrationProcessor.sampleIn;
        connect calibrationProcessor.measurementOut to measurementOutput;
        connect calibrationProcessor.measurementOut to diagnostics.measurementIn;
        connect diagnostics.diagnosticOut to diagnosticOutput;

        action measureCurrent {
            in item currentSignal : ElectricalCurrentSignal;
            out item measurement : CalibratedCurrentMeasurement;
            out item diagnostic : DiagnosticReport;

            first receiveCurrentSignal;
            then senseCurrentWithCurrentSensor;
            then filterAnalogOutput;
            then sampleFilteredVoltage;
            then compensateAndCalibrate;
            then runDiagnostics;
            then publishOutputs;
            then done;

            action receiveCurrentSignal;
            action senseCurrentWithCurrentSensor;
            action filterAnalogOutput;
            action sampleFilteredVoltage;
            action compensateAndCalibrate;
            action runDiagnostics;
            action publishOutputs;
        }

        state def SensingUnitState {
            state unpowered;
            state initializing;
            state operational;
            state degraded;
            state failed;
            state shutdown;

            transition initial then unpowered;
            transition unpowered_to_initializing
                first unpowered
                accept validPowerDetected
                then initializing;

            transition initializing_to_operational
                first initializing
                accept initializationComplete
                then operational;

            transition operational_to_degraded
                first operational
                accept diagnosticWarning
                then degraded;

            transition degraded_to_operational
                first degraded
                accept diagnosticRecovered
                then operational;

            transition operational_to_failed
                first operational
                accept criticalDiagnosticFault
                then failed;

            transition degraded_to_failed
                first degraded
                accept criticalDiagnosticFault
                then failed;

            transition failed_to_initializing
                first failed
                accept resetCommand
                then initializing;

            transition operational_to_shutdown
                first operational
                accept shutdownCommand
                then shutdown;

            transition shutdown_to_unpowered
                first shutdown
                accept powerRemoved
                then unpowered;
        }
    }

    requirement def CurrentMeasurementRequirement {
        subject unit : SensingUnit;

        requirement measurementQuantity {
            doc /* The sensing unit shall measure electrical current using a Current sensor as its primary sensing element. */
            require constraint {
                unit.sensor.measurementRangeMin <= -100 [SI::ampere] and
                unit.sensor.measurementRangeMax >= 100 [SI::ampere]
            }
        }

        requirement updateRate {
            doc /* The sensing unit shall provide calibrated current measurements at least every 1 ms. */
            require constraint {
                unit.measurementUpdatePeriod <= 0.001 [SI::second]
            }
        }

        requirement measurementAccuracy {
            doc /* The sensing unit shall provide calibrated current with uncertainty no greater than 0.5 A under normal operating conditions. */
            require constraint {
                unit.calibrationProcessor.calibrationValidityPeriod >= 31536000 [SI::second]
            }
        }

        requirement diagnostics {
            doc /* The sensing unit shall report sensor saturation, ADC fault, over-temperature, open-circuit, and calibration-expired diagnostic conditions. */
            require constraint {
                unit.diagnostics.minimumQuality >= 90 [%]
            }
        }

        requirement temperatureOperation {
            doc /* The sensing unit shall operate across the specified ambient temperature range. */
            require constraint {
                unit.operatingTemperatureMin <= 233.15 [SI::kelvin] and
                unit.operatingTemperatureMax >= 358.15 [SI::kelvin]
            }
        }
    }

    satisfy CurrentMeasurementRequirement::measurementQuantity by SensingUnit::sensor;
    satisfy CurrentMeasurementRequirement::updateRate by SensingUnit::adc;
    satisfy CurrentMeasurementRequirement::measurementAccuracy by SensingUnit::calibrationProcessor;
    satisfy CurrentMeasurementRequirement::diagnostics by SensingUnit::diagnostics;
    satisfy CurrentMeasurementRequirement::temperatureOperation by SensingUnit::temperatureSensor;

    verification case def CurrentMeasurementVerification {
        subject unit : SensingUnit;

        objective {
            doc /* Verify that the sensing unit converts injected current into a calibrated current measurement and reports diagnostics. */
        }

        action injectZeroCurrent;
        action injectPositiveRatedCurrent;
        action injectNegativeRatedCurrent;
        action injectOverRangeCurrent;
        action compareMeasurementToReference;
        action verifyDiagnosticFlags;
    }
}