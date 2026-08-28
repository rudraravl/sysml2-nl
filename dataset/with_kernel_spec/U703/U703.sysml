package GyroscopicSensingUnit {
    private import ScalarValues::*;

    package Definitions {
        attribute def AngularRate :> Real;
        attribute def TemperatureValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def TimestampValue :> Real;

        attribute def PowerSignal;
        attribute def StartMeasurementCmd;
        attribute def StopMeasurementCmd;
        attribute def SelfTestPass;
        attribute def SelfTestFail;
        attribute def OverTempSignal;
        attribute def ResetCmd;

        item def GyroData {
            attribute xRate : AngularRate;
            attribute yRate : AngularRate;
            attribute zRate : AngularRate;
            attribute timestamp : TimestampValue;
        }

        item def DiagnosticData {
            attribute temp : TemperatureValue;
            attribute voltage : VoltageValue;
        }

        port def PowerPort {
            in power : PowerSignal;
        }
        port def CommandPort {
            in startCmd : StartMeasurementCmd;
            in stopCmd : StopMeasurementCmd;
            in resetCmd : ResetCmd;
        }
        port def DataPort {
            out gyroData : GyroData;
            out diagData : DiagnosticData;
        }
        port def AnalogSignalPort {
            out signal : Real;
        }
        port def DigitalSignalPort {
            out data : Real;
        }

        action def PerformSelfTest;
        action def Initialize;
        action def StartMeasurement;
        action def StopMeasurement;
        action def MeasureRotationRates {
            out xRate : AngularRate;
            out yRate : AngularRate;
            out zRate : AngularRate;
            out timestamp : TimestampValue;
        }
        action def ProcessData {
            in rawX : Real;
            in rawY : Real;
            in rawZ : Real;
            in rawTemp : Real;
            out gyroData : GyroData;
            out diagData : DiagnosticData;
        }
        action def MeasureAndProcess {
            do MeasureRotationRates;
            then do ProcessData;
        }
        action def HandleFault;

        state def UnitStates;

        part def CapacitiveSensor {
            port rawOut : AnalogSignalPort;
        }
        part def VibratingMass;
        part def TemperatureSensor {
            port tempOut : AnalogSignalPort;
        }

        part def GyroscopicSensor {
            part vibratingMass : VibratingMass;
            part xSensor : CapacitiveSensor;
            part ySensor : CapacitiveSensor;
            part zSensor : CapacitiveSensor;
            part tempSensor : TemperatureSensor;

            port xOut : AnalogSignalPort;
            port yOut : AnalogSignalPort;
            port zOut : AnalogSignalPort;
            port tempOut : AnalogSignalPort;

            connect xSensor.rawOut to xOut;
            connect ySensor.rawOut to yOut;
            connect zSensor.rawOut to zOut;
            connect tempSensor.tempOut to tempOut;
        }

        part def ADC {
            port rawXIn : AnalogSignalPort;
            port rawYIn : AnalogSignalPort;
            port rawZIn : AnalogSignalPort;
            port rawTempIn : AnalogSignalPort;
            port digitalOut : DigitalSignalPort;
        }

        part def DSP {
            port digitalIn : DigitalSignalPort;
            port dataOut : DataPort;
            port cmdIn : CommandPort;

            attribute calibrationX : Real;
            attribute calibrationY : Real;
            attribute calibrationZ : Real;
        }

        part def GyroscopicUnit {
            attribute maxOperatingTemperature : TemperatureValue;
            attribute nominalVoltage : VoltageValue;

            part gyroSensor : GyroscopicSensor;
            part adc : ADC;
            part dsp : DSP;

            port powerIn : PowerPort;
            port cmdIn : CommandPort;
            port dataOut : DataPort;

            perform action 'perform self test': PerformSelfTest;
            perform action initialize: Initialize;
            perform action 'start measurement': StartMeasurement;
            perform action 'stop measurement': StopMeasurement;
            perform action 'measure rotation rates': MeasureRotationRates;
            perform action 'process data': ProcessData;
            perform action 'handle fault': HandleFault;

            exhibit state 'unit states': UnitStates;

            connect cmdIn to dsp.cmdIn;
            connect dsp.dataOut to dataOut;
            connect gyroSensor.xOut to adc.rawXIn;
            connect gyroSensor.yOut to adc.rawYIn;
            connect gyroSensor.zOut to adc.rawZIn;
            connect gyroSensor.tempOut to adc.rawTempIn;
            connect adc.digitalOut to dsp.digitalIn;
        }

        requirement def MeasurementAccuracy {
            doc /* The unit shall measure rotation rates with an accuracy of +/- 0.01 rad/s. */
            subject gyroUnit : GyroscopicUnit;
            attribute maxError : AngularRate = 0.01;
        }
        requirement def FaultDetection {
            doc /* The unit shall enter a fault state if temperature exceeds maxOperatingTemperature. */
            subject gyroUnit : GyroscopicUnit;
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        action 'perform self test': PerformSelfTest;
        action initialize: Initialize;
        action 'start measurement': StartMeasurement;
        action 'stop measurement': StopMeasurement;
        action 'measure rotation rates': MeasureRotationRates;
        action 'process data': ProcessData;
        action 'handle fault': HandleFault;

        part gyroUnit : GyroscopicUnit;

        state 'unit states': UnitStates {
            ref sensingUnit : GyroscopicUnit;

            entry; then off;

            state off;
            accept PowerSignal then selfTesting;

            state selfTesting {
                entry 'perform self test';
            }
            accept SelfTestPass then ready;
            accept SelfTestFail then fault;

            state ready {
                entry initialize;
            }
            accept StartMeasurementCmd then measuring;

            state measuring {
                entry 'start measurement';
                do 'measure rotation rates';
                exit 'stop measurement';
            }
            accept StopMeasurementCmd then ready;
            accept OverTempSignal then fault;

            state fault {
                entry 'handle fault';
            }
            accept ResetCmd then ready;
        }

        requirement measurementAccuracyReq : MeasurementAccuracy {
            subject gyroUnit : GyroscopicUnit;
        }
        requirement faultDetectionReq : FaultDetection {
            subject gyroUnit : GyroscopicUnit;
        }
    }
}
