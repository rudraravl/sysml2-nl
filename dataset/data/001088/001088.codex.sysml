package HydrogenSulfideSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ConcentrationValue :> Real;
    attribute def MoleFraction_ppm :> ConcentrationValue {
        unit = ppm;
    }
    attribute def Temperature_C :> Real {
        unit = degC;
    }
    attribute def RelativeHumidity_percent :> Real {
        unit = percent;
    }
    attribute def Voltage_V :> Real {
        unit = V;
    }
    attribute def Current_mA :> Real {
        unit = mA;
    }
    attribute def Time_s :> Real {
        unit = s;
    }

    enum def SensorHealthKind {
        enum nominal;
        enum warmingUp;
        enum degraded;
        enum faulted;
        enum endOfLife;
    }

    enum def AlarmLevelKind {
        enum normal;
        enum advisory;
        enum warning;
        enum critical;
    }

    enum def MeasurementQualityKind {
        enum valid;
        enum suspect;
        enum invalid;
    }

    item def AmbientGasSample {
        attribute h2sConcentration : MoleFraction_ppm;
        attribute temperature : Temperature_C;
        attribute relativeHumidity : RelativeHumidity_percent;
        attribute pressure_kPa : Real;
    }

    item def H2SMeasurement {
        attribute concentration : MoleFraction_ppm;
        attribute compensatedConcentration : MoleFraction_ppm;
        attribute temperature : Temperature_C;
        attribute relativeHumidity : RelativeHumidity_percent;
        attribute quality : MeasurementQualityKind;
        attribute timestamp : Time_s;
        attribute sensorHealth : SensorHealthKind;
    }

    item def AlarmIndication {
        attribute level : AlarmLevelKind;
        attribute measuredConcentration : MoleFraction_ppm;
        attribute threshold : MoleFraction_ppm;
        attribute latched : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_mA;
    }

    item def ConfigurationData {
        attribute samplingPeriod : Time_s;
        attribute warningThreshold : MoleFraction_ppm;
        attribute criticalThreshold : MoleFraction_ppm;
        attribute calibrationOffset : MoleFraction_ppm;
        attribute calibrationSpanGain : Real;
    }

    port def GasInletPort {
        in item gas : AmbientGasSample;
    }

    port def MeasurementOutPort {
        out item measurement : H2SMeasurement;
    }

    port def AlarmOutPort {
        out item alarm : AlarmIndication;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def ConfigPort {
        in item configuration : ConfigurationData;
    }

    port def InternalSignalPort {
        out item measurement : H2SMeasurement;
    }

    action def WarmUpSensor {
        in attribute warmUpDuration : Time_s;
        out attribute health : SensorHealthKind;
    }

    action def AcquireRawH2SSignal {
        in item sample : AmbientGasSample;
        out attribute rawSignal_mV : Real;
        out attribute sensorTemperature : Temperature_C;
    }

    action def CompensateH2SReading {
        in attribute rawSignal_mV : Real;
        in attribute ambientTemperature : Temperature_C;
        in attribute ambientHumidity : RelativeHumidity_percent;
        in item configuration : ConfigurationData;
        out attribute compensatedConcentration : MoleFraction_ppm;
    }

    action def ValidateMeasurement {
        in attribute concentration : MoleFraction_ppm;
        in attribute lowerLimit : MoleFraction_ppm;
        in attribute upperLimit : MoleFraction_ppm;
        in attribute health : SensorHealthKind;
        out attribute quality : MeasurementQualityKind;
    }

    action def EvaluateAlarm {
        in item measurement : H2SMeasurement;
        in item configuration : ConfigurationData;
        out item alarm : AlarmIndication;
    }

    state def SensingUnitOperationalStates {
        entry; then initializing;

        state initializing;
        state warming;
        state measuring;
        state degradedOperation;
        state alarmActive;
        state fault;

        transition initializing_to_warming
            first initializing
            then warming;

        transition warming_to_measuring
            first warming
            if warmupComplete
            then measuring;

        transition measuring_to_alarm
            first measuring
            if h2sAboveWarningThreshold
            then alarmActive;

        transition alarm_to_measuring
            first alarmActive
            if h2sBelowWarningThreshold
            then measuring;

        transition measuring_to_degraded
            first measuring
            if sensorDriftExceeded
            then degradedOperation;

        transition degraded_to_fault
            first degradedOperation
            if measurementInvalid
            then fault;

        transition measuring_to_fault
            first measuring
            if powerInvalid or sensorOpenCircuit or sensorEndOfLife
            then fault;
    }

    part def HydrogenSulfideElectrochemicalSensor {
        port gasIn : GasInletPort;
        port powerIn : PowerPort;
        port rawMeasurementOut : InternalSignalPort;

        attribute measurementRangeMin : MoleFraction_ppm = 0.0;
        attribute measurementRangeMax : MoleFraction_ppm = 100.0;
        attribute detectionLimit : MoleFraction_ppm = 0.1;
        attribute responseTimeT90 : Time_s = 30.0;
        attribute warmUpTime : Time_s = 60.0;
        attribute expectedServiceLife_h : Real = 17520.0;
        attribute crossSensitivityCO_percent : Real = 2.0;
        attribute health : SensorHealthKind = SensorHealthKind::warmingUp;

        perform action acquireRawSignal : AcquireRawH2SSignal {
            in sample = gasIn.gas;
        }
    }

    part def TemperatureHumidityCompensator {
        port uncompensatedIn : InternalSignalPort;
        port compensatedOut : InternalSignalPort;
        port configIn : ConfigPort;

        attribute temperatureCoefficient_ppmPerDegC : Real = 0.015;
        attribute humidityCoefficient_ppmPerPercentRH : Real = 0.006;

        perform action compensateReading : CompensateH2SReading;
    }

    part def MeasurementProcessor {
        port measurementIn : InternalSignalPort;
        port measurementOut : MeasurementOutPort;
        port configIn : ConfigPort;

        attribute lowerValidLimit : MoleFraction_ppm = 0.0;
        attribute upperValidLimit : MoleFraction_ppm = 120.0;
        attribute digitalResolution : MoleFraction_ppm = 0.01;
        attribute samplingPeriod : Time_s = 1.0;

        perform action validate : ValidateMeasurement;
    }

    part def AlarmProcessor {
        port measurementIn : MeasurementOutPort;
        port alarmOut : AlarmOutPort;
        port configIn : ConfigPort;

        attribute advisoryThreshold : MoleFraction_ppm = 5.0;
        attribute warningThreshold : MoleFraction_ppm = 10.0;
        attribute criticalThreshold : MoleFraction_ppm = 15.0;
        attribute alarmHysteresis : MoleFraction_ppm = 1.0;
        attribute alarmLatchEnabled : Boolean = true;

        perform action evaluateAlarm : EvaluateAlarm;
    }

    part def PowerConditioner {
        port powerIn : PowerPort;
        port conditionedPowerOut : PowerPort;

        attribute inputVoltageMin : Voltage_V = 9.0;
        attribute inputVoltageMax : Voltage_V = 30.0;
        attribute outputVoltage : Voltage_V = 3.3;
        attribute maximumCurrent : Current_mA = 100.0;
        attribute undervoltageFault : Boolean;
    }

    part def SensingUnitController {
        port configIn : ConfigPort;
        port measurementOut : MeasurementOutPort;
        port alarmOut : AlarmOutPort;

        attribute state : SensingUnitOperationalStates;
        attribute currentHealth : SensorHealthKind;
        attribute lastValidMeasurement : MoleFraction_ppm;
        attribute uptime : Time_s;

        exhibit state sensingStates : SensingUnitOperationalStates;
    }

    part def HydrogenSulfideSensingUnit {
        port gasIn : GasInletPort;
        port powerIn : PowerPort;
        port configIn : ConfigPort;
        port measurementOut : MeasurementOutPort;
        port alarmOut : AlarmOutPort;

        attribute nominalSamplingPeriod : Time_s = 1.0;
        attribute measurementAccuracy : MoleFraction_ppm = 0.5;
        attribute operatingTemperatureMin : Temperature_C = -20.0;
        attribute operatingTemperatureMax : Temperature_C = 50.0;
        attribute operatingHumidityMin : RelativeHumidity_percent = 15.0;
        attribute operatingHumidityMax : RelativeHumidity_percent = 95.0;
        attribute ingressProtectionRating : String = "IP54";

        part powerConditioner : PowerConditioner;
        part h2sSensor : HydrogenSulfideElectrochemicalSensor;
        part compensator : TemperatureHumidityCompensator;
        part processor : MeasurementProcessor;
        part alarmProcessor : AlarmProcessor;
        part controller : SensingUnitController;

        connect powerIn to powerConditioner.powerIn;
        connect powerConditioner.conditionedPowerOut to h2sSensor.powerIn;

        connect gasIn to h2sSensor.gasIn;

        connect configIn to compensator.configIn;
        connect configIn to processor.configIn;
        connect configIn to alarmProcessor.configIn;
        connect configIn to controller.configIn;

        connect h2sSensor.rawMeasurementOut to compensator.uncompensatedIn;
        connect compensator.compensatedOut to processor.measurementIn;
        connect processor.measurementOut to measurementOut;
        connect processor.measurementOut to alarmProcessor.measurementIn;
        connect alarmProcessor.alarmOut to alarmOut;

        connect measurementOut to controller.measurementOut;
        connect alarmOut to controller.alarmOut;
    }

    requirement def H2SMeasurementRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.h2sSensor.measurementRangeMin <= 0.0 and
            unit.h2sSensor.measurementRangeMax >= 100.0
        }

        doc
        /*
         * The sensing unit shall measure hydrogen sulfide concentration
         * in ambient gas over at least 0 ppm to 100 ppm.
         */
    }

    requirement def AccuracyRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.measurementAccuracy <= 0.5
        }

        doc
        /*
         * The sensing unit shall report compensated hydrogen sulfide
         * concentration with an error not exceeding 0.5 ppm under nominal
         * operating conditions.
         */
    }

    requirement def ResponseTimeRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.h2sSensor.responseTimeT90 <= 30.0
        }

        doc
        /*
         * The sensing unit shall achieve a T90 response time of 30 seconds
         * or less for a step change in hydrogen sulfide concentration.
         */
    }

    requirement def AlarmRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.alarmProcessor.warningThreshold == 10.0 and
            unit.alarmProcessor.criticalThreshold == 15.0
        }

        doc
        /*
         * The sensing unit shall generate warning and critical alarm
         * indications when compensated hydrogen sulfide concentration reaches
         * configured threshold values.
         */
    }

    requirement def CompensationRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.operatingTemperatureMin <= -20.0 and
            unit.operatingTemperatureMax >= 50.0 and
            unit.operatingHumidityMin <= 15.0 and
            unit.operatingHumidityMax >= 95.0
        }

        doc
        /*
         * The sensing unit shall compensate hydrogen sulfide measurements for
         * ambient temperature and relative humidity throughout the specified
         * environmental operating range.
         */
    }

    requirement def HealthMonitoringRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.controller.currentHealth != SensorHealthKind::faulted implies
            unit.h2sSensor.health != SensorHealthKind::endOfLife
        }

        doc
        /*
         * The sensing unit shall monitor sensor warm-up, degradation, fault,
         * and end-of-life conditions and include sensor health in each
         * reported measurement.
         */
    }

    requirement def PowerRequirement {
        subject unit : HydrogenSulfideSensingUnit;

        require constraint {
            unit.powerConditioner.inputVoltageMin <= 9.0 and
            unit.powerConditioner.inputVoltageMax >= 30.0 and
            unit.powerConditioner.outputVoltage == 3.3
        }

        doc
        /*
         * The sensing unit shall operate from a 9 V to 30 V supply and provide
         * regulated internal power to the hydrogen sulfide sensor.
         */
    }

    satisfy H2SMeasurementRequirement by HydrogenSulfideSensingUnit::h2sSensor;
    satisfy AccuracyRequirement by HydrogenSulfideSensingUnit::processor;
    satisfy ResponseTimeRequirement by HydrogenSulfideSensingUnit::h2sSensor;
    satisfy AlarmRequirement by HydrogenSulfideSensingUnit::alarmProcessor;
    satisfy CompensationRequirement by HydrogenSulfideSensingUnit::compensator;
    satisfy HealthMonitoringRequirement by HydrogenSulfideSensingUnit::controller;
    satisfy PowerRequirement by HydrogenSulfideSensingUnit::powerConditioner;

    part h2sSensingUnit : HydrogenSulfideSensingUnit;

}