package DigitalThermometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def TemperatureValue :> Real;
        attribute def TimeValue :> Real;
        attribute def VoltageValue :> Real;

        item def RawSignal {
            attribute voltage : VoltageValue;
        }

        item def ElectricalPower {
            attribute voltage : VoltageValue;
        }

        port def RawSignalPort {
            out signal : RawSignal;
        }

        port def TempValuePort {
            out temp : TemperatureValue;
        }

        port def PowerPort {
            out power : ElectricalPower;
        }

        attribute def PowerOn;
        attribute def PowerOff;
        attribute def CalibrateCmd;
        attribute def CalibrationComplete;

        action def SenseTemp {
            out raw : RawSignal;
        }

        action def ProcessSignal {
            in raw : RawSignal;
            in offset : TemperatureValue;
            in scale : Real;
            out temp : TemperatureValue;
        }

        action def DisplayTemp {
            in temp : TemperatureValue;
        }

        action def Calibrate {
            out offset : TemperatureValue;
            out scale : Real;
        }

        action def MeasureLoop {
            in offset : TemperatureValue;
            in scale : Real;
            action sense : SenseTemp;
            action process : ProcessSignal {
                in raw = sense.raw;
                in offset = offset;
                in scale = scale;
            }
            action display : DisplayTemp {
                in temp = process.temp;
            }
        }

        state def ThermometerStates;

        part def TemperatureSensor {
            attribute minTemp : TemperatureValue = -40.0;
            attribute maxTemp : TemperatureValue = 100.0;
            port rawOut : RawSignalPort;
            port powerIn : ~PowerPort;
            perform action sense : SenseTemp;
        }

        part def SignalProcessor {
            attribute offset : TemperatureValue = 0.0;
            attribute scale : Real = 1.0;
            port rawIn : ~RawSignalPort;
            port tempOut : TempValuePort;
            port powerIn : ~PowerPort;
            perform action process : ProcessSignal;
            perform action calibrate : Calibrate;
        }

        part def Display {
            attribute updateInterval : TimeValue = 1.0;
            port tempIn : ~TempValuePort;
            port powerIn : ~PowerPort;
            perform action display : DisplayTemp;
        }

        part def PowerSupply {
            attribute voltage : VoltageValue = 3.3;
            port powerOut : PowerPort;
        }

        part def DigitalThermometer {
            attribute responseTime : TimeValue;
            attribute measurementAccuracy : TemperatureValue;
            part tempSensor : TemperatureSensor;
            part sigProcessor : SignalProcessor;
            part display : Display;
            part power : PowerSupply;
            exhibit state thermometerStates : ThermometerStates;
        }

        requirement def AccuracyRequirement {
            doc /* The thermometer shall measure temperature with an accuracy of ±0.5 degrees. */
            attribute maxError : TemperatureValue = 0.5;
        }

        requirement def ResponseTimeRequirement {
            doc /* The thermometer shall have a response time of less than 1 second. */
            attribute maxResponseTime : TimeValue = 1.0;
        }

        requirement def DisplayUpdateRateRequirement {
            doc /* The display shall update at least once per second. */
            attribute maxUpdateInterval : TimeValue = 1.0;
        }

        requirement def SensorRangeRequirement {
            doc /* The temperature sensor shall operate from -40°C to +100°C. */
            attribute requiredMin : TemperatureValue = -40.0;
            attribute requiredMax : TemperatureValue = 100.0;
        }
    }

    package Usages {
        private import Definitions::*;

        part digitalThermometer : DigitalThermometer {
            part :>> tempSensor {
                port :>> rawOut;
                port :>> powerIn;
            }
            part :>> sigProcessor {
                port :>> rawIn;
                port :>> tempOut;
                port :>> powerIn;
            }
            part :>> display {
                port :>> tempIn;
                port :>> powerIn;
            }
            part :>> power {
                port :>> powerOut;
            }

            interface rawConnection connect tempSensor.rawOut to sigProcessor.rawIn {
                flow rawFlow of RawSignal from tempSensor.rawOut.signal to sigProcessor.rawIn.signal;
            }

            interface tempConnection connect sigProcessor.tempOut to display.tempIn {
                flow tempFlow of TemperatureValue from sigProcessor.tempOut.temp to display.tempIn.temp;
            }

            interface powerConnection1 connect power.powerOut to tempSensor.powerIn {
                flow powerFlow1 of ElectricalPower from power.powerOut.power to tempSensor.powerIn.power;
            }

            interface powerConnection2 connect power.powerOut to sigProcessor.powerIn {
                flow powerFlow2 of ElectricalPower from power.powerOut.power to sigProcessor.powerIn.power;
            }

            interface powerConnection3 connect power.powerOut to display.powerIn {
                flow powerFlow3 of ElectricalPower from power.powerOut.power to display.powerIn.power;
            }

            state :>> thermometerStates : ThermometerStates {
                entry; then off;

                state off;
                accept PowerOn then measuring;

                state measuring {
                    do action measureLoop : MeasureLoop {
                        in offset = sigProcessor.offset;
                        in scale = sigProcessor.scale;
                    }
                }
                accept CalibrateCmd then calibration;
                accept PowerOff then off;

                state calibration {
                    do action calibrateAct : Calibrate;
                    accept CalibrationComplete then measuring;
                    accept PowerOff then off;
                }
            }
        }

        requirement accuracyReq : AccuracyRequirement;
        requirement responseTimeReq : ResponseTimeRequirement;
        requirement displayUpdateReq : DisplayUpdateRateRequirement;
        requirement sensorRangeReq : SensorRangeRequirement;

        satisfy accuracyReq by digitalThermometer;
        satisfy responseTimeReq by digitalThermometer;
        satisfy displayUpdateReq by digitalThermometer.display;
        satisfy sensorRangeReq by digitalThermometer.tempSensor;
    }
}
