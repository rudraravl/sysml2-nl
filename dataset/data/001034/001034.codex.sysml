package ElectrochemicalGasSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def GasConcentration :> Real {
        unit = "ppm";
    }

    attribute def GasConcentrationRate :> Real {
        unit = "ppm/s";
    }

    attribute def ElectricCurrentMicroampere :> Real {
        unit = "uA";
    }

    attribute def ElectricPotentialMillivolt :> Real {
        unit = "mV";
    }

    attribute def TemperatureCelsius :> Real {
        unit = "degC";
    }

    attribute def RelativeHumidityPercent :> Real {
        unit = "%";
    }

    attribute def TimeSecond :> Real {
        unit = "s";
    }

    attribute def SupplyVoltage :> Real {
        unit = "V";
    }

    attribute def PowerMilliwatt :> Real {
        unit = "mW";
    }

    attribute def DigitalCode :> Integer;

    attribute def DiagnosticCode :> Integer;

    enum def GasSpecies {
        enum carbonMonoxide;
        enum hydrogenSulfide;
        enum oxygen;
        enum nitrogenDioxide;
        enum sulfurDioxide;
    }

    enum def UnitHealth {
        enum initializing;
        enum warmingUp;
        enum normal;
        enum degraded;
        enum faulted;
        enum calibrationRequired;
    }

    item def AmbientGasSample {
        attribute species : GasSpecies;
        attribute concentration : GasConcentration;
        attribute temperature : TemperatureCelsius;
        attribute relativeHumidity : RelativeHumidityPercent;
        attribute pressure {
            :> SI::pressure;
            unit = "Pa";
        }
    }

    item def SensorReactionCurrent {
        attribute workingElectrodeCurrent : ElectricCurrentMicroampere;
        attribute counterElectrodeCurrent : ElectricCurrentMicroampere;
        attribute auxiliaryElectrodeCurrent : ElectricCurrentMicroampere;
        attribute cellBias : ElectricPotentialMillivolt;
    }

    item def AnalogMeasurementSignal {
        attribute transimpedanceVoltage : ElectricPotentialMillivolt;
        attribute temperatureVoltage : ElectricPotentialMillivolt;
        attribute humidityVoltage : ElectricPotentialMillivolt;
        attribute valid : Boolean;
    }

    item def GasMeasurementFrame {
        attribute measuredSpecies : GasSpecies;
        attribute concentration : GasConcentration;
        attribute compensatedConcentration : GasConcentration;
        attribute temperature : TemperatureCelsius;
        attribute relativeHumidity : RelativeHumidityPercent;
        attribute sampleAge : TimeSecond;
        attribute health : UnitHealth;
        attribute diagnostic : DiagnosticCode;
    }

    item def CalibrationParameters {
        attribute zeroOffset : GasConcentration;
        attribute spanSensitivity {
            unit = "uA/ppm";
            :> Real;
        }
        attribute temperatureCoefficient {
            unit = "ppm/degC";
            :> Real;
        }
        attribute humidityCoefficient {
            unit = "ppm/%";
            :> Real;
        }
        attribute calibrationAge {
            unit = "d";
            :> Real;
        }
    }

    item def PowerInput {
        attribute voltage : SupplyVoltage;
        attribute current {
            unit = "mA";
            :> Real;
        }
        attribute available : Boolean;
    }

    item def DigitalCommand {
        attribute requestMeasurement : Boolean;
        attribute requestCalibration : Boolean;
        attribute resetFault : Boolean;
        attribute targetSpecies : GasSpecies;
    }

    port def GasInletPort {
        in item gas : AmbientGasSample;
    }

    port def ElectrochemicalCellPort {
        in item gas : AmbientGasSample;
        out item current : SensorReactionCurrent;
    }

    port def AnalogSignalPort {
        out item analog : AnalogMeasurementSignal;
    }

    port def DigitalMeasurementPort {
        out item frame : GasMeasurementFrame;
    }

    port def PowerPort {
        in item power : PowerInput;
    }

    port def CommandPort {
        in item command : DigitalCommand;
    }

    port def DiagnosticPort {
        out item health : UnitHealth;
        out item diagnostic : DiagnosticCode;
    }

    action def GenerateElectrochemicalCurrent {
        in item gas : AmbientGasSample;
        in item calibration : CalibrationParameters;
        out item current : SensorReactionCurrent;

        attribute rawCurrent : ElectricCurrentMicroampere;
        attribute auxiliaryCorrection : ElectricCurrentMicroampere;

        satisfy requirement ElectrochemicalTransductionRequirement;
    }

    action def AmplifyAndFilterCurrent {
        in item current : SensorReactionCurrent;
        out item analog : AnalogMeasurementSignal;

        attribute transimpedanceGain {
            unit = "mV/uA";
            :> Real = 220.0;
        }
        attribute lowPassCutoffFrequency {
            unit = "Hz";
            :> Real = 2.0;
        }

        satisfy requirement AnalogSignalConditioningRequirement;
    }

    action def DigitizeMeasurement {
        in item analog : AnalogMeasurementSignal;
        out attribute adcCode : DigitalCode;

        attribute adcResolution : Integer = 16;
        attribute referenceVoltage : SupplyVoltage = 2.500;
        attribute samplingPeriod : TimeSecond = 1.0;

        satisfy requirement DigitizationRequirement;
    }

    action def CompensateGasReading {
        in attribute adcCode : DigitalCode;
        in item gas : AmbientGasSample;
        in item calibration : CalibrationParameters;
        out item frame : GasMeasurementFrame;

        attribute calculatedConcentration : GasConcentration;
        attribute compensatedConcentration : GasConcentration;

        satisfy requirement MeasurementAccuracyRequirement;
        satisfy requirement EnvironmentalCompensationRequirement;
    }

    action def ExecuteZeroCalibration {
        in item zeroGas : AmbientGasSample;
        inout item calibration : CalibrationParameters;
        out item health : UnitHealth;

        attribute zeroStabilityWindow : TimeSecond = 120.0;
        attribute acceptedZeroDrift : GasConcentration = 1.0;

        satisfy requirement CalibrationRequirement;
    }

    action def RunSelfDiagnostics {
        in item power : PowerInput;
        in item current : SensorReactionCurrent;
        in item analog : AnalogMeasurementSignal;
        out item health : UnitHealth;
        out item diagnostic : DiagnosticCode;

        attribute openCircuitThreshold : ElectricCurrentMicroampere = 0.01;
        attribute saturationVoltage : ElectricPotentialMillivolt = 2400.0;
        attribute undervoltageThreshold : SupplyVoltage = 3.000;

        satisfy requirement DiagnosticsRequirement;
    }

    part def ElectrochemicalGasSensor {
        attribute targetSpecies : GasSpecies = GasSpecies::carbonMonoxide;
        attribute measurementRangeMin : GasConcentration = 0.0;
        attribute measurementRangeMax : GasConcentration = 1000.0;
        attribute nominalSensitivity {
            unit = "uA/ppm";
            :> Real = 0.070;
        }
        attribute responseTimeT90 : TimeSecond = 30.0;
        attribute operatingTemperatureMin : TemperatureCelsius = -20.0;
        attribute operatingTemperatureMax : TemperatureCelsius = 50.0;
        attribute operatingHumidityMin : RelativeHumidityPercent = 15.0;
        attribute operatingHumidityMax : RelativeHumidityPercent = 90.0;
        attribute biasPotential : ElectricPotentialMillivolt = 0.0;
        attribute expectedServiceLife {
            unit = "month";
            :> Real = 36.0;
        }

        port inlet : GasInletPort;
        port cell : ElectrochemicalCellPort;

        action transduce : GenerateElectrochemicalCurrent;
    }

    part def GasDiffusionBarrier {
        attribute membranePoreSize {
            unit = "um";
            :> Real = 0.20;
        }
        attribute diffusionTimeConstant : TimeSecond = 4.0;
        attribute particulateFilterEfficiency {
            unit = "%";
            :> Real = 95.0;
        }

        port ambient : GasInletPort;
        port conditionedGas : GasInletPort;
    }

    part def Potentiostat {
        attribute workingElectrodeSetpoint : ElectricPotentialMillivolt = 0.0;
        attribute biasStability : ElectricPotentialMillivolt = 1.0;
        attribute maximumCellCurrent : ElectricCurrentMicroampere = 200.0;
        attribute quiescentPower : PowerMilliwatt = 8.0;

        port cellInterface : ElectrochemicalCellPort;
        port analogOut : AnalogSignalPort;
        port powerIn : PowerPort;

        action conditionSignal : AmplifyAndFilterCurrent;
    }

    part def TemperatureHumiditySensor {
        attribute temperatureAccuracy : TemperatureCelsius = 0.5;
        attribute humidityAccuracy : RelativeHumidityPercent = 3.0;
        attribute samplingPeriod : TimeSecond = 1.0;

        port analogOut : AnalogSignalPort;
        port powerIn : PowerPort;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute inputRangeMin : ElectricPotentialMillivolt = 0.0;
        attribute inputRangeMax : ElectricPotentialMillivolt = 2500.0;
        attribute sampleRate {
            unit = "Hz";
            :> Real = 1.0;
        }
        attribute integralNonlinearity {
            unit = "LSB";
            :> Real = 2.0;
        }

        port analogIn : AnalogSignalPort;
        port powerIn : PowerPort;

        action digitize : DigitizeMeasurement;
    }

    part def MeasurementProcessor {
        attribute firmwareVersion : String = "2.4.1";
        attribute measurementPeriod : TimeSecond = 1.0;
        attribute warmupTime : TimeSecond = 60.0;
        attribute faultLatchEnabled : Boolean = true;

        item calibration : CalibrationParameters {
            attribute zeroOffset = 0.0;
            attribute spanSensitivity = 0.070;
            attribute temperatureCoefficient = 0.08;
            attribute humidityCoefficient = 0.02;
            attribute calibrationAge = 0.0;
        }

        port commandIn : CommandPort;
        port measurementOut : DigitalMeasurementPort;
        port diagnosticOut : DiagnosticPort;
        port powerIn : PowerPort;

        action compensate : CompensateGasReading;
        action calibrateZero : ExecuteZeroCalibration;
        action diagnostics : RunSelfDiagnostics;

        state def ProcessorStateMachine {
            state off;
            state initializing;
            state warmup;
            state measuring;
            state calibrating;
            state degraded;
            state fault;

            transition first off;

            transition off_to_initializing
                first off
                then initializing
                accept PowerAvailable;

            transition initializing_to_warmup
                first initializing
                then warmup
                accept InitializationComplete;

            transition warmup_to_measuring
                first warmup
                then measuring
                accept WarmupTimerExpired;

            transition measuring_to_calibrating
                first measuring
                then calibrating
                accept ZeroCalibrationRequested;

            transition calibrating_to_measuring
                first calibrating
                then measuring
                accept CalibrationAccepted;

            transition measuring_to_degraded
                first measuring
                then degraded
                accept SensorDriftExceeded;

            transition degraded_to_measuring
                first degraded
                then measuring
                accept CalibrationAccepted;

            transition measuring_to_fault
                first measuring
                then fault
                accept CriticalDiagnosticFault;

            transition degraded_to_fault
                first degraded
                then fault
                accept CriticalDiagnosticFault;

            transition fault_to_initializing
                first fault
                then initializing
                accept ResetFaultCommand;
        }

        exhibit stateMachine : ProcessorStateMachine;
    }

    part def RegulatedPowerSupply {
        attribute inputVoltageMin : SupplyVoltage = 3.0;
        attribute inputVoltageMax : SupplyVoltage = 5.5;
        attribute regulatedAnalogVoltage : SupplyVoltage = 2.5;
        attribute regulatedDigitalVoltage : SupplyVoltage = 3.3;
        attribute maximumOutputPower : PowerMilliwatt = 150.0;
        attribute efficiency {
            unit = "%";
            :> Real = 88.0;
        }

        port externalPower : PowerPort;
        port analogPower : PowerPort;
        port digitalPower : PowerPort;
    }

    part def SensingUnitHousing {
        attribute ingressProtectionRating : String = "IP54";
        attribute gasPathVolume {
            unit = "cm^3";
            :> Real = 1.8;
        }
        attribute enclosureMaterial : String = "glass-filled polycarbonate";
        attribute ventArea {
            unit = "mm^2";
            :> Real = 42.0;
        }

        port ambientGas : GasInletPort;
        port internalGas : GasInletPort;
    }

    part def ElectrochemicalGasSensingUnit {
        attribute unitIdentifier : String = "EGSU-CO-1000";
        attribute targetSpecies : GasSpecies = GasSpecies::carbonMonoxide;
        attribute measurementRangeMin : GasConcentration = 0.0;
        attribute measurementRangeMax : GasConcentration = 1000.0;
        attribute accuracyWithinRange : GasConcentration = 5.0;
        attribute updatePeriod : TimeSecond = 1.0;
        attribute totalPowerNominal : PowerMilliwatt = 35.0;
        attribute operatingTemperatureMin : TemperatureCelsius = -20.0;
        attribute operatingTemperatureMax : TemperatureCelsius = 50.0;
        attribute operatingHumidityMin : RelativeHumidityPercent = 15.0;
        attribute operatingHumidityMax : RelativeHumidityPercent = 90.0;

        port gasIn : GasInletPort;
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port measurementOut : DigitalMeasurementPort;
        port diagnosticOut : DiagnosticPort;

        part housing : SensingUnitHousing;
        part diffusionBarrier : GasDiffusionBarrier;
        part electrochemicalSensor : ElectrochemicalGasSensor;
        part potentiostat : Potentiostat;
        part environmentSensor : TemperatureHumiditySensor;
        part adc : AnalogToDigitalConverter;
        part processor : MeasurementProcessor;
        part powerSupply : RegulatedPowerSupply;

        connect gasIn to housing.ambientGas;
        connect housing.internalGas to diffusionBarrier.ambient;
        connect diffusionBarrier.conditionedGas to electrochemicalSensor.inlet;
        connect electrochemicalSensor.cell to potentiostat.cellInterface;
        connect potentiostat.analogOut to adc.analogIn;
        connect environmentSensor.analogOut to adc.analogIn;
        connect adc.powerIn to powerSupply.digitalPower;
        connect potentiostat.powerIn to powerSupply.analogPower;
        connect environmentSensor.powerIn to powerSupply.digitalPower;
        connect processor.powerIn to powerSupply.digitalPower;
        connect powerIn to powerSupply.externalPower;
        connect commandIn to processor.commandIn;
        connect processor.measurementOut to measurementOut;
        connect processor.diagnosticOut to diagnosticOut;

        perform action electrochemicalSensor.transduce;
        perform action potentiostat.conditionSignal;
        perform action adc.digitize;
        perform action processor.compensate;
        perform action processor.diagnostics;
    }

    requirement def GasSensingUnitRequirement {
        subject unit : ElectrochemicalGasSensingUnit;

        require constraint {
            unit.targetSpecies == GasSpecies::carbonMonoxide
        }

        require constraint {
            unit.measurementRangeMin <= 0.0 and unit.measurementRangeMax >= 1000.0
        }

        require constraint {
            unit.updatePeriod <= 1.0
        }

        require constraint {
            unit.totalPowerNominal <= 50.0
        }
    }

    requirement def ElectrochemicalTransductionRequirement {
        subject sensor : ElectrochemicalGasSensor;

        require constraint {
            sensor.nominalSensitivity >= 0.050 and sensor.nominalSensitivity <= 0.100
        }

        require constraint {
            sensor.responseTimeT90 <= 30.0
        }

        require constraint {
            sensor.measurementRangeMax >= 1000.0
        }
    }

    requirement def AnalogSignalConditioningRequirement {
        subject potentiostat : Potentiostat;

        require constraint {
            potentiostat.biasStability <= 2.0
        }

        require constraint {
            potentiostat.maximumCellCurrent >= 100.0
        }

        require constraint {
            potentiostat.quiescentPower <= 10.0
        }
    }

    requirement def DigitizationRequirement {
        subject adc : AnalogToDigitalConverter;

        require constraint {
            adc.resolutionBits >= 16
        }

        require constraint {
            adc.sampleRate >= 1.0
        }

        require constraint {
            adc.inputRangeMax >= 2500.0
        }
    }

    requirement def MeasurementAccuracyRequirement {
        subject unit : ElectrochemicalGasSensingUnit;

        require constraint {
            unit.accuracyWithinRange <= 5.0
        }

        require constraint {
            unit.measurementRangeMax >= 1000.0
        }
    }

    requirement def EnvironmentalCompensationRequirement {
        subject unit : ElectrochemicalGasSensingUnit;

        require constraint {
            unit.operatingTemperatureMin <= -20.0
        }

        require constraint {
            unit.operatingTemperatureMax >= 50.0
        }

        require constraint {
            unit.operatingHumidityMin <= 15.0
        }

        require constraint {
            unit.operatingHumidityMax >= 90.0
        }
    }

    requirement def CalibrationRequirement {
        subject processor : MeasurementProcessor;

        require constraint {
            processor.calibration.calibrationAge <= 180.0
        }

        require constraint {
            processor.calibration.zeroOffset >= -20.0 and processor.calibration.zeroOffset <= 20.0
        }
    }

    requirement def DiagnosticsRequirement {
        subject processor : MeasurementProcessor;

        require constraint {
            processor.faultLatchEnabled == true
        }

        require constraint {
            processor.measurementPeriod <= 1.0
        }
    }

    requirement def GasPathRequirement {
        subject housing : SensingUnitHousing;

        require constraint {
            housing.gasPathVolume <= 2.5
        }

        require constraint {
            housing.ventArea >= 30.0
        }
    }

    requirement def PowerRequirement {
        subject supply : RegulatedPowerSupply;

        require constraint {
            supply.inputVoltageMin <= 3.0
        }

        require constraint {
            supply.inputVoltageMax >= 5.0
        }

        require constraint {
            supply.maximumOutputPower >= 100.0
        }
    }

    requirement unitRequirement : GasSensingUnitRequirement {
        subject unit = sensingUnit;
    }

    part sensingUnit : ElectrochemicalGasSensingUnit;

    satisfy unitRequirement by sensingUnit;
    satisfy GasPathRequirement by sensingUnit.housing;
    satisfy PowerRequirement by sensingUnit.powerSupply;
    satisfy ElectrochemicalTransductionRequirement by sensingUnit.electrochemicalSensor;
    satisfy AnalogSignalConditioningRequirement by sensingUnit.potentiostat;
    satisfy DigitizationRequirement by sensingUnit.adc;
    satisfy MeasurementAccuracyRequirement by sensingUnit;
    satisfy EnvironmentalCompensationRequirement by sensingUnit;
    satisfy CalibrationRequirement by sensingUnit.processor;
    satisfy DiagnosticsRequirement by sensingUnit.processor;
}