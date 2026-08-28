package HydrogenSensingSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def VoltageValue :> Real { unit = V; }
    attribute def ConcentrationPPM :> Real;
    attribute def QualityScore :> Real;
    attribute def TimestampValue :> Real { unit = s; }
    attribute def TemperatureValue :> Real { unit = K; }
    attribute def ValidityFlag :> Boolean;

    item def GasSample;
    item def RawVoltageSignal {
        attribute voltage : VoltageValue;
    }
    item def ConditionedSignal {
        attribute voltage : VoltageValue;
    }
    item def DigitalReading {
        attribute value : Integer;
    }
    item def CalibrationParameters {
        attribute offset : Real := 0.0;
        attribute gain : Real := 1.0;
        attribute ageFactor : Real := 1.0;
    }
    item def TemperatureReading {
        attribute temp : TemperatureValue;
    }
    item def HydrogenMeasurement {
        attribute concentration : ConcentrationPPM;
        attribute temperature : TemperatureValue;
        attribute timestamp : TimestampValue;
        attribute valid : ValidityFlag;
        attribute quality : QualityScore;
    }

    attribute def PowerOn;
    attribute def WarmupComplete;
    attribute def StartMeasuring;
    attribute def MeasurementComplete;
    attribute def StartCalibration;
    attribute def CalibrationComplete;
    attribute def FaultDetected;
    attribute def ResetFromError;

    port def GasInPort { in item gas : GasSample; }
    port def RawSignalPort { out item raw : RawVoltageSignal; }
    port def ConditionedSignalPort { out item conditioned : ConditionedSignal; }
    port def DigitalSignalPort { out item digital : DigitalReading; }
    port def MeasurementOutPort { out item measurement : HydrogenMeasurement; }
    port def TempInPort { in item tempReading : TemperatureReading; }

    action def SenseHydrogen {
        in item gas : GasSample;
        out item raw : RawVoltageSignal;
    }
    action def ConditionSignal {
        in item raw : RawVoltageSignal;
        out item conditioned : ConditionedSignal;
    }
    action def ConvertAnalogToDigital {
        in item analog : ConditionedSignal;
        out item digital : DigitalReading;
    }
    action def ApplyCalibration {
        in item digital : DigitalReading;
        in item params : CalibrationParameters;
        out item calibrated : ConcentrationPPM;
    }
    action def CompensateForTemperature {
        in item concentration : ConcentrationPPM;
        in item temp : TemperatureReading;
        out item compensated : ConcentrationPPM;
    }
    action def ValidateResult {
        in item concentration : ConcentrationPPM;
        out item valid : ValidityFlag;
        out item quality : QualityScore;
    }
    action def PackageMeasurement {
        in item concentration : ConcentrationPPM;
        in item temp : TemperatureReading;
        in item timestamp : TimestampValue;
        in item valid : ValidityFlag;
        in item quality : QualityScore;
        out item measurement : HydrogenMeasurement;
    }
    action def ProcessMeasurement {
        in item digital : DigitalReading;
        in item params : CalibrationParameters;
        in item temp : TemperatureReading;
        in item timestamp : TimestampValue;
        out item measurement : HydrogenMeasurement;

        action applyCalib : ApplyCalibration {
            in item digital = ProcessMeasurement::digital;
            in item params = ProcessMeasurement::params;
            out item calibrated;
        }
        action compensateTemp : CompensateForTemperature {
            in item concentration = applyCalib.calibrated;
            in item temp = ProcessMeasurement::temp;
            out item compensated;
        }
        action validate : ValidateResult {
            in item concentration = compensateTemp.compensated;
            out item valid;
            out item quality;
        }
        action packageMeasurement : PackageMeasurement {
            in item concentration = compensateTemp.compensated;
            in item temp = ProcessMeasurement::temp;
            in item timestamp = ProcessMeasurement::timestamp;
            in item valid = validate.valid;
            in item quality = validate.quality;
            out item measurement = ProcessMeasurement::measurement;
        }
    }

    part def HydrogenSensorElement {
        attribute operatingTemperature : TemperatureValue := 25 [K];
        attribute targetOperatingTemp : TemperatureValue := 150 [K];
        port gasIn : GasInPort;
        port rawOut : RawSignalPort;
        perform action sense : SenseHydrogen {
            in item gas = gasIn.gas;
            out item raw;
        }
        flow from sense.raw to rawOut.raw;
    }

    part def SignalConditioningModule {
        attribute amplificationFactor : Real := 100.0;
        attribute filterCutoffHz : Real := 50.0;
        port signalIn : RawSignalPort;
        port signalOut : ConditionedSignalPort;
        perform action condition : ConditionSignal {
            in item raw = signalIn.raw;
            out item conditioned;
        }
        flow from condition.conditioned to signalOut.conditioned;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer := 16;
        attribute referenceVoltage : VoltageValue := 3.3 [V];
        port analogIn : ConditionedSignalPort;
        port digitalOut : DigitalSignalPort;
        perform action convert : ConvertAnalogToDigital {
            in item analog = analogIn.conditioned;
            out item digital;
        }
        flow from convert.digital to digitalOut.digital;
    }

    part def ProcessingModule {
        attribute calibrationParams : CalibrationParameters;
        attribute currentTimestamp : TimestampValue := 0.0 [s];
        port digitalIn : DigitalSignalPort;
        port tempIn : TempInPort;
        port measurementOut : MeasurementOutPort;
        perform action process : ProcessMeasurement {
            in item digital = digitalIn.digital;
            in item params = calibrationParams;
            in item temp = tempIn.tempReading;
            in item timestamp = currentTimestamp;
            out item measurement;
        }
        flow from process.measurement to measurementOut.measurement;
    }

    state def HydrogenSensingStates {
        entry; then warmingUp;
        state warmingUp;
        accept WarmupComplete then ready;
        state ready;
        accept StartMeasuring then measuring;
        accept StartCalibration then calibrating;
        state measuring;
        accept MeasurementComplete then ready;
        state calibrating;
        accept CalibrationComplete then ready;
        accept FaultDetected then error;
        state error;
        accept ResetFromError then warmingUp;
    }

    part def HydrogenSensingUnit {
        port ambientGas : GasInPort;
        port ambientTemp : TempInPort;
        port output : MeasurementOutPort;
        part sensorElement : HydrogenSensorElement;
        part conditioningModule : SignalConditioningModule;
        part adc : AnalogToDigitalConverter;
        part processingModule : ProcessingModule;
        connect ambientGas to sensorElement.gasIn;
        connect sensorElement.rawOut to conditioningModule.signalIn;
        connect conditioningModule.signalOut to adc.analogIn;
        connect adc.digitalOut to processingModule.digitalIn;
        connect ambientTemp to processingModule.tempIn;
        connect processingModule.measurementOut to output;
        exhibit state sensingStates : HydrogenSensingStates;
    }

    requirement def HydrogenSensingRequirement {
        subject unit : HydrogenSensingUnit;
        doc /*
         * The hydrogen sensing unit shall accurately measure hydrogen gas
         * concentration in parts per million and provide a validated
         * digital measurement output including concentration, temperature,
         * timestamp, and validity flag.
         */
    }

    requirement def WarmupRequirement {
        subject sensor : HydrogenSensorElement;
        doc /*
         * The sensor element shall enter a warmingUp state upon power-on
         * and shall only transition to ready when the operating temperature
         * reaches the target operating temperature.
         */
    }

    requirement def SignalIntegrityRequirement {
        subject conditioning : SignalConditioningModule;
        doc /*
         * The signal conditioning module shall amplify the raw sensor
         * voltage and filter electrical noise to produce a clean analog
         * signal suitable for digital conversion.
         */
    }

    requirement def CalibrationRequirement {
        subject processing : ProcessingModule;
        doc /*
         * The processing module shall apply calibration parameters to
         * compensate for sensor age and manufacturing variations, adjust
         * for ambient temperature effects, and validate the result with
         * a quality score before packaging the final measurement.
         */
    }

    requirement sensingReq : HydrogenSensingRequirement;
    requirement warmupReq : WarmupRequirement;
    requirement signalReq : SignalIntegrityRequirement;
    requirement calibReq : CalibrationRequirement;
}
