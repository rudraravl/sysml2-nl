package ActinometerSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def UVWavelength :> Real;
        attribute def RadiantIntensity :> Real;
        attribute def PhotocurrentValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def TimestampValue :> Real;

        item def UVRadiation {
            attribute wavelength : UVWavelength;
            attribute intensity : RadiantIntensity;
        }

        item def MeasurementRecord {
            attribute intensity : RadiantIntensity;
            attribute timestamp : TimestampValue;
            attribute temperature : TemperatureValue;
        }

        attribute def CalibrationFactors {
            attribute offset : Real;
            attribute scale : Real;
        }

        attribute def StartCalibrationCommand;
        attribute def CalibrationCompleteSignal;
        attribute def StartMeasurementCommand;
        attribute def StopMeasurementCommand;
        attribute def SensorFailureSignal;
        attribute def ResetCommand;

        port def UVInputPort {
            in radiation : UVRadiation;
        }
        port def CurrentOutputPort {
            out current : PhotocurrentValue;
        }
        port def CurrentInputPort {
            in current : PhotocurrentValue;
        }
        port def VoltageOutputPort {
            out voltage : VoltageValue;
        }
        port def VoltageInputPort {
            in voltage : VoltageValue;
        }
        port def DigitalOutputPort {
            out rawValue : Integer;
        }
        port def DigitalInputPort {
            in rawValue : Integer;
        }
        port def TemperatureOutputPort {
            out temperature : TemperatureValue;
        }
        port def TemperatureInputPort {
            in temperature : TemperatureValue;
        }
        port def MeasurementOutputPort {
            out measurement : MeasurementRecord;
        }
        port def MeasurementInputPort {
            in measurement : MeasurementRecord;
        }

        action def GeneratePhotocurrent {
            in radiation : UVRadiation;
            out current : PhotocurrentValue;
        }
        action def AmplifyCurrent {
            in currentIn : PhotocurrentValue;
            out voltageOut : VoltageValue;
        }
        action def ConvertToDigital {
            in voltageIn : VoltageValue;
            out digitalValue : Integer;
        }
        action def SenseTemperatureAction {
            out temperature : TemperatureValue;
        }
        action def ProcessMeasurementAction {
            in rawDigital : Integer;
            in temperature : TemperatureValue;
            in calibration : CalibrationFactors;
            out measurement : MeasurementRecord;
        }
        action def CalibrateAction {
            in rawDigital : Integer;
            in temperature : TemperatureValue;
            out calibration : CalibrationFactors;
        }
        action def DisplayAndRecordAction {
            in measurement : MeasurementRecord;
        }

        part def Photodetector {
            attribute spectralRangeMin : UVWavelength;
            attribute spectralRangeMax : UVWavelength;
            attribute responsivity : Real;
            port uvIn : UVInputPort;
            port currentOut : CurrentOutputPort;
            perform action generatePhotocurrent : GeneratePhotocurrent;
        }

        part def Amplifier {
            attribute gain : Real;
            port currentIn : CurrentInputPort;
            port voltageOut : VoltageOutputPort;
            perform action amplifyCurrent : AmplifyCurrent;
        }

        part def AnalogToDigitalConverter {
            attribute resolutionBits : Integer;
            port voltageIn : VoltageInputPort;
            port digitalOut : DigitalOutputPort;
            perform action convertToDigital : ConvertToDigital;
        }

        part def TemperatureSensor {
            port tempOut : TemperatureOutputPort;
            perform action senseTemperature : SenseTemperatureAction;
        }

        part def CentralProcessingUnit {
            attribute calibration : CalibrationFactors;
            port digitalIn : DigitalInputPort;
            port tempIn : TemperatureInputPort;
            port measurementOut : MeasurementOutputPort;
            perform action processMeasurement : ProcessMeasurementAction;
            perform action calibrate : CalibrateAction;
        }

        part def DisplayAndRecordingUnit {
            port measurementIn : MeasurementInputPort;
            perform action displayAndRecord : DisplayAndRecordAction;
        }

        state def ActinometerStates {
            entry; then standby;

            state standby;
            transition standby_to_calibrating
                first standby
                accept StartCalibrationCommand
                then calibrating;
            transition standby_to_measuring
                first standby
                accept StartMeasurementCommand
                then measuring;
            transition standby_to_error
                first standby
                accept SensorFailureSignal
                then error;

            state calibrating;
            transition calibrating_to_standby
                first calibrating
                accept CalibrationCompleteSignal
                then standby;
            transition calibrating_to_error
                first calibrating
                accept SensorFailureSignal
                then error;

            state measuring;
            transition measuring_to_standby
                first measuring
                accept StopMeasurementCommand
                then standby;
            transition measuring_to_error
                first measuring
                accept SensorFailureSignal
                then error;

            state error;
            transition error_to_standby
                first error
                accept ResetCommand
                then standby;
        }

        part def ActinometerSystem {
            port uvInput : UVInputPort;

            part photodetector : Photodetector;
            part amplifier : Amplifier;
            part adc : AnalogToDigitalConverter;
            part tempSensor : TemperatureSensor;
            part cpu : CentralProcessingUnit;
            part displayUnit : DisplayAndRecordingUnit;

            connect uvInput to photodetector.uvIn;
            connect photodetector.currentOut to amplifier.currentIn;
            connect amplifier.voltageOut to adc.voltageIn;
            connect adc.digitalOut to cpu.digitalIn;
            connect tempSensor.tempOut to cpu.tempIn;
            connect cpu.measurementOut to displayUnit.measurementIn;

            exhibit state actinometerStates : ActinometerStates;
        }

        requirement def UVSpectralSensitivityRequirement {
            subject photodetector : Photodetector;
            doc /* The photodetector shall be sensitive to UV radiation in the 280 to 400 nanometer range. */
            assert constraint {
                photodetector.spectralRangeMin >= 280 and
                photodetector.spectralRangeMax <= 400
            }
        }

        requirement def CalibrationTraceabilityRequirement {
            subject cpu : CentralProcessingUnit;
            doc /* The calibration factors applied by the CPU shall be traceable to a recognized international standard. */
        }

        requirement def MeasurementAccuracyRequirement {
            subject system : ActinometerSystem;
            doc /* The system shall provide precise measurement of UV radiant intensity. */
        }

        requirement def MeasurementDataIntegrityRequirement {
            subject cpu : CentralProcessingUnit;
            doc /* Every measurement record shall include intensity, timestamp, and temperature. */
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;
        part actinometer1 : ActinometerSystem;
    }
}
