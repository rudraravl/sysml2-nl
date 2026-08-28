package NOxSensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    package Definitions {
        unit ppm;
        unit degC;

        attribute def NOxConcentrationValue :> ScalarValues::Real;
        attribute def TemperatureValue :> ScalarValues::Real;
        attribute def VoltageValue :> ScalarValues::Real;

        enum def ErrorCode {
            none;
            sensorFault;
            heaterFault;
            tempOutOfRange;
            signalError;
            calibrationError;
        }
        enum def CommandType {
            start;
            stop;
            calibrate;
            diagnostic;
            reset;
        }

        item def ExhaustGas {
            attribute noxConcentration: NOxConcentrationValue;
        }
        item def RawSignal {
            attribute voltage: VoltageValue;
        }
        item def FilteredSignal {
            attribute voltage: VoltageValue;
        }
        item def DigitalData {
            attribute value: Integer;
        }
        item def HeatFlow;
        item def Command {
            attribute cmd: CommandType;
        }
        item def PowerOnSignal;
        item def NOxDataPacket {
            attribute concentration: NOxConcentrationValue;
            attribute temperature: TemperatureValue;
            attribute timestamp: DateTime;
            attribute isValid: Boolean;
            attribute errorCode: ErrorCode;
        }

        attribute def PowerOn;
        attribute def StartMeasurement;
        attribute def StopMeasurement;
        attribute def RunDiagnostics;
        attribute def ResetCommand;
        attribute def StartCalibration;
        attribute def TargetTempReached;
        attribute def FaultDetected;
        attribute def CalibrationComplete;
        attribute def DiagnosticsComplete;
        attribute def InitializationComplete;

        port def ExhaustPort {
            in item gas: ExhaustGas;
        }
        port def RawSignalPort {
            out item signal: RawSignal;
        }
        port def FilteredSignalPort {
            out item signal: FilteredSignal;
        }
        port def DigitalDataPort {
            out item data: DigitalData;
        }
        port def TemperaturePort {
            out item temp: TemperatureValue;
        }
        port def HeatPort {
            out item heat: HeatFlow;
        }
        port def PowerPort {
            in item powerOn: PowerOnSignal;
        }
        port def CommandPort {
            in item cmd: Command;
        }
        port def DataOutputPort {
            out item data: NOxDataPacket;
        }

        action def Initialize;
        action def WarmUp {
            in targetTemp: TemperatureValue;
            out heat: HeatFlow;
        }
        action def GenerateRawSignal {
            in gas: ExhaustGas;
            out raw: RawSignal;
        }
        action def ProcessSignal {
            in raw: RawSignal;
            out filtered: FilteredSignal;
        }
        action def ConvertSignal {
            in analog: FilteredSignal;
            out digital: DigitalData;
        }
        action def MonitorTemp {
            out temp: TemperatureValue;
        }
        action def AssembleDataPacket {
            in digital: DigitalData;
            in temp: TemperatureValue;
            out data: NOxDataPacket;
        }
        action def Calibrate;
        action def RunDiagnostics {
            out errorCode: ErrorCode;
        }
        action def Reset;

        state def SensorStates;

        part def SensingElement {
            port exhaustIn: ExhaustPort;
            port rawSignalOut: RawSignalPort;
            port heatIn: ~HeatPort;
            attribute noxLevel: NOxConcentrationValue;
            perform action generateRawSignal: GenerateRawSignal;
        }
        part def HeatingElement {
            port heatOut: HeatPort;
            attribute targetTemp: TemperatureValue = 300 [degC];
            perform action heatUp: WarmUp;
        }
        part def TemperatureMonitor {
            port tempOut: TemperaturePort;
            attribute currentTemp: TemperatureValue;
            perform action monitorTemp: MonitorTemp;
        }
        part def SignalProcessor {
            port rawSignalIn: ~RawSignalPort;
            port filteredSignalOut: FilteredSignalPort;
            perform action processSignal: ProcessSignal;
        }
        part def ADC {
            port analogIn: ~FilteredSignalPort;
            port digitalOut: DigitalDataPort;
            perform action convertSignal: ConvertSignal;
        }
        part def NOxSensor {
            port exhaustIn: ExhaustPort;
            port dataOut: DataOutputPort;
            port controlIn: CommandPort;
            port powerIn: PowerPort;

            attribute operatingTemp: TemperatureValue = 300 [degC];
            attribute currentTemp: TemperatureValue;

            part sensingElement: SensingElement;
            part heatingElement: HeatingElement;
            part tempMonitor: TemperatureMonitor;
            part signalProcessor: SignalProcessor;
            part adc: ADC;

            perform action initialize: Initialize;
            perform action assembleData: AssembleDataPacket;
            perform action calibrate: Calibrate;
            perform action runDiagnostics: RunDiagnostics;
            perform action reset: Reset;

            exhibit state sensorStates: SensorStates {
                entry; then off;
                state off;
                accept PowerOn
                    do initialize
                    then initializing;
                state initializing {
                    do initialize;
                }
                accept InitializationComplete
                    then warmingUp;
                state warmingUp {
                    do heatingElement.heatUp;
                    do tempMonitor.monitorTemp;
                }
                accept when tempMonitor.currentTemp >= operatingTemp
                    then ready;
                state ready;
                accept StartMeasurement
                    then measuring;
                state measuring {
                    do sensingElement.generateRawSignal;
                    do signalProcessor.processSignal;
                    do adc.convertSignal;
                    do assembleData;
                }
                accept StopMeasurement
                    then ready;
                accept StartCalibration
                    then calibrating;
                state calibrating {
                    do calibrate;
                }
                accept CalibrationComplete
                    then ready;
                accept RunDiagnostics
                    then diagnostics;
                state diagnostics {
                    do runDiagnostics;
                }
                accept DiagnosticsComplete
                    then ready;
                accept FaultDetected
                    then fault;
                state fault;
                accept ResetCommand
                    do reset
                    then off;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part noxSensorUnit: NOxSensor {
            connect exhaustIn to sensingElement.exhaustIn;
            connect sensingElement.rawSignalOut to signalProcessor.rawSignalIn;
            connect signalProcessor.filteredSignalOut to adc.analogIn;
            connect heatingElement.heatOut to sensingElement.heatIn;
        }

        requirement OperatingTemperatureReq {
            doc /* The sensing element shall be maintained at 300°C ± 5°C during measurement. */
            attribute targetTemp: TemperatureValue = 300 [degC];
            attribute tolerance: TemperatureValue = 5 [degC];
        }
        requirement MeasurementAccuracyReq {
            doc /* NOx concentration measurement shall be within ±5% of actual value. */
            attribute accuracy: Real = 0.05;
        }
        requirement DataPacketReq {
            doc /* Output data packet shall include concentration, temperature, timestamp, validity, and error code. */
        }
        requirement WarmupReq {
            doc /* Sensor shall reach operating temperature before entering measuring state. */
        }

        satisfy OperatingTemperatureReq by noxSensorUnit;
        satisfy MeasurementAccuracyReq by noxSensorUnit;
        satisfy DataPacketReq by noxSensorUnit;
        satisfy WarmupReq by noxSensorUnit;
    }
}
