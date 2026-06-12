package ZincOxideNanorodSensingUnitModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Resistance :> ISQ::resistance {
        unit = SI::ohm;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def RelativeHumidity {
        :>> num : Real;
        unit = "%";
    }

    attribute def GasConcentration {
        :>> num : Real;
        unit = "ppm";
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Length :> ISQ::length {
        unit = SI::nanometre;
    }

    attribute def Count {
        :>> num : Integer;
    }

    attribute def Ratio {
        :>> num : Real;
    }

    item def AmbientGasSample {
        attribute targetGasConcentration : GasConcentration;
        attribute oxygenConcentration : Ratio;
        attribute humidity : RelativeHumidity;
        attribute temperature : Temperature;
    }

    item def BiasSignal {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
    }

    item def SensorCurrentSignal {
        attribute current : Current;
        attribute biasVoltage : Voltage;
        attribute sampleTemperature : Temperature;
    }

    item def DigitalMeasurement {
        attribute concentration : GasConcentration;
        attribute confidence : Ratio;
        attribute timestamp : TimeDuration;
        attribute sensorTemperature : Temperature;
        attribute statusCode : Integer;
    }

    item def DiagnosticEvent {
        attribute code : Integer;
        attribute severity : Integer;
        attribute occurredAt : TimeDuration;
    }

    port def GasExposurePort {
        in item sample : AmbientGasSample;
    }

    port def ElectricalBiasPort {
        in item bias : BiasSignal;
        out item currentResponse : SensorCurrentSignal;
    }

    port def DigitalDataPort {
        out item measurement : DigitalMeasurement;
        out item diagnostic : DiagnosticEvent;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrentAvailable : Current;
    }

    part def ZincOxideNanorodArray {
        attribute nanorodDiameter : Length = 60 [SI::nanometre];
        attribute nanorodLength : Length = 950 [SI::nanometre];
        attribute nanorodCount : Count = 250000;
        attribute activeAreaLength : Length = 2000000 [SI::nanometre];
        attribute activeAreaWidth : Length = 2000000 [SI::nanometre];
        attribute baselineResistanceInAir : Resistance = 1200000 [SI::ohm];
        attribute minimumDetectableConcentration : GasConcentration = 0.5 ["ppm"];
        attribute responseTimeT90 : TimeDuration = 8 [SI::second];
        attribute recoveryTimeT90 : TimeDuration = 24 [SI::second];
        attribute operatingTemperature : Temperature = 373.15 [SI::kelvin];

        port gasPort : GasExposurePort;
        port electrodePort : ElectricalBiasPort;

        state def SurfaceChemistryState {
            state clean;
            state oxygenAdsorbed;
            state targetGasReacting;
            state saturated;
            state recovering;

            initial then clean;

            transition clean_to_oxygenAdsorbed
                first clean
                then oxygenAdsorbed;

            transition oxygenAdsorbed_to_targetGasReacting
                first oxygenAdsorbed
                accept sample : AmbientGasSample
                    if sample.targetGasConcentration > 0.5 ["ppm"]
                then targetGasReacting;

            transition targetGasReacting_to_saturated
                first targetGasReacting
                accept sample : AmbientGasSample
                    if sample.targetGasConcentration > 500 ["ppm"]
                then saturated;

            transition targetGasReacting_to_recovering
                first targetGasReacting
                accept sample : AmbientGasSample
                    if sample.targetGasConcentration <= 0.5 ["ppm"]
                then recovering;

            transition saturated_to_recovering
                first saturated
                accept sample : AmbientGasSample
                    if sample.targetGasConcentration <= 0.5 ["ppm"]
                then recovering;

            transition recovering_to_oxygenAdsorbed
                first recovering
                after 24 [SI::second]
                then oxygenAdsorbed;
        }

        action def TransduceGasConcentration {
            in item sample : AmbientGasSample;
            in item bias : BiasSignal;
            out item currentResponse : SensorCurrentSignal;

            attribute sensitivity : Ratio = 0.018;
            attribute humidityCompensationSlope : Ratio = 0.004;
            attribute nominalHumidity : RelativeHumidity = 45 ["%"];
            attribute conductanceRatio : Ratio;

            bind currentResponse.biasVoltage = bias.voltage;
            bind currentResponse.sampleTemperature = sample.temperature;
        }
    }

    part def MicroHeater {
        attribute targetTemperature : Temperature = 373.15 [SI::kelvin];
        attribute temperatureTolerance : Temperature = 2 [SI::kelvin];
        attribute warmupTime : TimeDuration = 15 [SI::second];
        attribute heaterResistance : Resistance = 85 [SI::ohm];

        port power : PowerPort;

        action def RegulateTemperature {
            in attribute measuredTemperature : Temperature;
            out attribute heaterDutyCycle : Ratio;

            attribute proportionalGain : Ratio = 0.08;
            attribute maximumDutyCycle : Ratio = 1.0;
            attribute minimumDutyCycle : Ratio = 0.0;
        }

        state def HeaterStateMachine {
            state off;
            state warming;
            state regulating;
            state fault;

            initial then off;

            transition off_to_warming
                first off
                accept powerApplied
                then warming;

            transition warming_to_regulating
                first warming
                after 15 [SI::second]
                then regulating;

            transition regulating_to_fault
                first regulating
                accept overTemperature
                then fault;

            transition fault_to_off
                first fault
                accept reset
                then off;
        }
    }

    part def BiasAndReadoutCircuit {
        attribute nominalBiasVoltage : Voltage = 1.8 [SI::volt];
        attribute maximumBiasVoltage : Voltage = 3.3 [SI::volt];
        attribute currentMeasurementRange : Current = 0.002 [SI::ampere];
        attribute currentResolution : Current = 0.000000001 [SI::ampere];
        attribute transimpedanceGain : Resistance = 100000 [SI::ohm];

        port power : PowerPort;
        port sensorInterface : ElectricalBiasPort;
        port adcOutput : DigitalDataPort;

        action def ApplyBiasAndMeasureCurrent {
            out item bias : BiasSignal;
            in item currentResponse : SensorCurrentSignal;
            out item rawMeasurement : DigitalMeasurement;

            bind bias.voltage = nominalBiasVoltage;
            bind bias.currentLimit = currentMeasurementRange;
        }
    }

    part def EnvironmentalCompensator {
        attribute humidityCoefficient : Ratio = 0.004;
        attribute temperatureCoefficient : Ratio = 0.012;
        attribute referenceHumidity : RelativeHumidity = 45 ["%"];
        attribute referenceTemperature : Temperature = 373.15 [SI::kelvin];

        action def Compensate {
            in item uncompensatedMeasurement : DigitalMeasurement;
            in item sample : AmbientGasSample;
            out item compensatedMeasurement : DigitalMeasurement;

            bind compensatedMeasurement.timestamp = uncompensatedMeasurement.timestamp;
            bind compensatedMeasurement.sensorTemperature = sample.temperature;
        }
    }

    part def ConcentrationEstimator {
        attribute calibrationSlope : Ratio = 55.0;
        attribute calibrationOffset : GasConcentration = 0.0 ["ppm"];
        attribute lowerLimit : GasConcentration = 0.5 ["ppm"];
        attribute upperLimit : GasConcentration = 500 ["ppm"];
        attribute minimumConfidence : Ratio = 0.80;

        action def EstimateTargetGas {
            in item currentResponse : SensorCurrentSignal;
            in item sample : AmbientGasSample;
            out item estimatedMeasurement : DigitalMeasurement;

            attribute normalizedConductanceChange : Ratio;
            bind estimatedMeasurement.sensorTemperature = sample.temperature;
        }
    }

    part def DigitalController {
        attribute samplePeriod : TimeDuration = 1 [SI::second];
        attribute calibrationInterval : TimeDuration = 86400 [SI::second];
        attribute startupStabilizationTime : TimeDuration = 30 [SI::second];
        attribute faultCurrentThreshold : Current = 0.002 [SI::ampere];

        port dataOut : DigitalDataPort;

        action def SampleProcessReport {
            in item rawMeasurement : DigitalMeasurement;
            in item compensatedMeasurement : DigitalMeasurement;
            out item reportedMeasurement : DigitalMeasurement;
            out item diagnostic : DiagnosticEvent;

            bind reportedMeasurement.concentration = compensatedMeasurement.concentration;
            bind reportedMeasurement.confidence = compensatedMeasurement.confidence;
            bind reportedMeasurement.sensorTemperature = compensatedMeasurement.sensorTemperature;
        }

        state def ControllerStateMachine {
            state powerOff;
            state startup;
            state baselineStabilization;
            state measuring;
            state selfTest;
            state degraded;
            state fault;

            initial then powerOff;

            transition powerOff_to_startup
                first powerOff
                accept powerApplied
                then startup;

            transition startup_to_baselineStabilization
                first startup
                after 15 [SI::second]
                then baselineStabilization;

            transition baselineStabilization_to_measuring
                first baselineStabilization
                after 30 [SI::second]
                then measuring;

            transition measuring_to_selfTest
                first measuring
                after 86400 [SI::second]
                then selfTest;

            transition selfTest_to_measuring
                first selfTest
                accept selfTestPassed
                then measuring;

            transition selfTest_to_degraded
                first selfTest
                accept calibrationDriftDetected
                then degraded;

            transition degraded_to_measuring
                first degraded
                accept recalibrated
                then measuring;

            transition measuring_to_fault
                first measuring
                accept openCircuitDetected
                then fault;

            transition degraded_to_fault
                first degraded
                accept unsafeMeasurementDetected
                then fault;

            transition fault_to_startup
                first fault
                accept reset
                then startup;
        }
    }

    part def SensingUnit {
        attribute supportedTargetGas : String = "nitrogen dioxide";
        attribute measurementRangeLow : GasConcentration = 0.5 ["ppm"];
        attribute measurementRangeHigh : GasConcentration = 500 ["ppm"];
        attribute accuracyAt25ppm : GasConcentration = 2 ["ppm"];
        attribute responseTimeLimit : TimeDuration = 10 [SI::second];
        attribute recoveryTimeLimit : TimeDuration = 30 [SI::second];
        attribute operatingHumidityLow : RelativeHumidity = 5 ["%"];
        attribute operatingHumidityHigh : RelativeHumidity = 95 ["%"];
        attribute supplyVoltageNominal : Voltage = 5 [SI::volt];

        port gasIn : GasExposurePort;
        port powerIn : PowerPort;
        port measurementOut : DigitalDataPort;

        part sensor : ZincOxideNanorodArray;
        part heater : MicroHeater;
        part readout : BiasAndReadoutCircuit;
        part estimator : ConcentrationEstimator;
        part compensator : EnvironmentalCompensator;
        part controller : DigitalController;

        connect gasIn to sensor.gasPort;
        connect powerIn to heater.power;
        connect powerIn to readout.power;
        connect readout.sensorInterface to sensor.electrodePort;
        connect controller.dataOut to measurementOut;

        action def SenseTargetGas {
            in item ambientSample : AmbientGasSample;
            out item reportedMeasurement : DigitalMeasurement;
            out item diagnostic : DiagnosticEvent;

            first startHeater : heater.RegulateTemperature;
            then transduce : sensor.TransduceGasConcentration;
            then estimate : estimator.EstimateTargetGas;
            then compensate : compensator.Compensate;
            then report : controller.SampleProcessReport;

            bind transduce.sample = ambientSample;
            bind estimate.sample = ambientSample;
            bind compensate.sample = ambientSample;
            bind report.reportedMeasurement = reportedMeasurement;
            bind report.diagnostic = diagnostic;
        }
    }

    requirement def MeasurementRangeRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.measurementRangeLow <= 0.5 ["ppm"] and unit.measurementRangeHigh >= 500 ["ppm"]
        }
    }

    requirement def ResponseTimeRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.responseTimeLimit <= 10 [SI::second]
        }
    }

    requirement def RecoveryTimeRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.recoveryTimeLimit <= 30 [SI::second]
        }
    }

    requirement def AccuracyRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.accuracyAt25ppm <= 2 ["ppm"]
        }
    }

    requirement def HumidityOperatingRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.operatingHumidityLow <= 5 ["%"] and unit.operatingHumidityHigh >= 95 ["%"]
        }
    }

    requirement def ZincOxideNanorodRequirement {
        subject unit : SensingUnit;
        require constraint {
            unit.sensor.nanorodDiameter >= 20 [SI::nanometre] and
            unit.sensor.nanorodDiameter <= 120 [SI::nanometre] and
            unit.sensor.nanorodLength >= 500 [SI::nanometre]
        }
    }

    satisfy MeasurementRangeRequirement by SensingUnit;
    satisfy ResponseTimeRequirement by SensingUnit;
    satisfy RecoveryTimeRequirement by SensingUnit;
    satisfy AccuracyRequirement by SensingUnit;
    satisfy HumidityOperatingRequirement by SensingUnit;
    satisfy ZincOxideNanorodRequirement by SensingUnit;

    part deployedZnONanorodSensingUnit : SensingUnit {
        attribute supportedTargetGas = "nitrogen dioxide";
        attribute measurementRangeLow = 0.5 ["ppm"];
        attribute measurementRangeHigh = 500 ["ppm"];
        attribute accuracyAt25ppm = 2 ["ppm"];
        attribute responseTimeLimit = 10 [SI::second];
        attribute recoveryTimeLimit = 30 [SI::second];

        part redefines sensor {
            attribute nanorodDiameter = 60 [SI::nanometre];
            attribute nanorodLength = 950 [SI::nanometre];
            attribute baselineResistanceInAir = 1200000 [SI::ohm];
            attribute responseTimeT90 = 8 [SI::second];
            attribute recoveryTimeT90 = 24 [SI::second];
        }

        part redefines heater {
            attribute targetTemperature = 373.15 [SI::kelvin];
            attribute heaterResistance = 85 [SI::ohm];
        }

        part redefines readout {
            attribute nominalBiasVoltage = 1.8 [SI::volt];
            attribute currentResolution = 0.000000001 [SI::ampere];
        }
    }
}