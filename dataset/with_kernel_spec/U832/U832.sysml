package DigitalPressureGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    public import Definitions::*;

    package Definitions {
        public import EnumDefinitions::*;
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package EnumDefinitions {
            enum def AlarmState { normal; high; low; }
            enum def CalibrationStatus { calibrated; uncalibrated; expired; }
        }

        package ItemDefinitions {
            private import EnumDefinitions::*;

            item def Fluid;
            item def RawSignal {
                attribute voltage : ElectricPotentialValue;
            }
            item def PressureReading {
                attribute value : PressureValue;
                attribute calibrationStatus : Boolean;
            }
            item def AlarmInfo {
                attribute alarmState : AlarmState;
            }
            attribute def PowerOn;
            attribute def PowerOff;
            attribute def CalibrationComplete;
        }

        package PortDefinitions {
            private import ItemDefinitions::*;

            port def FluidPort {
                in item fluid : Fluid;
            }
            port def PowerPort {
                in attribute voltage : ElectricPotentialValue;
            }
            port def RawSignalPort {
                out item rawSignal : RawSignal;
            }
            port def CorrectedPressurePort {
                out item pressureReading : PressureReading;
            }
            port def AlarmStatusPort {
                out item alarmInfo : AlarmInfo;
            }
            port def DisplayOutputPort {
                out item pressureReading : PressureReading;
                out item alarmInfo : AlarmInfo;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;

            action def MeasurePressure {
                in item fluid : Fluid;
                out item rawSignal : RawSignal;
            }
            action def ProcessSignal {
                in item rawSignal : RawSignal;
                out item pressureReading : PressureReading;
            }
            action def UpdateDisplay {
                in item pressureReading : PressureReading;
                in item alarmInfo : AlarmInfo;
            }
            action def ControlAlarm {
                in item pressureReading : PressureReading;
                out item alarmInfo : AlarmInfo;
            }
        }

        package StateDefinitions {
            state def AlarmStates;
            state def SensorStates;
            state def ProcessorStates;
        }

        package PartDefinitions {
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import StateDefinitions::*;
            private import ItemDefinitions::*;

            part def PressureSensor {
                port fluidPort : FluidPort;
                port powerPort : PowerPort;
                port rawSignalPort : RawSignalPort;
                attribute sensitivity : Real;
                attribute offset : ElectricPotentialValue;
                perform action measurePressure : MeasurePressure;
            }

            part def SignalProcessor {
                port rawSignalInPort : ~RawSignalPort;
                port pressureOutPort : CorrectedPressurePort;
                attribute calibrationFactor : Real;
                attribute zeroOffset : PressureValue;
                attribute calibrationStatus : Boolean;
                perform action processSignal : ProcessSignal;
            }

            part def DisplayUnit {
                port pressureInPort : ~CorrectedPressurePort;
                port alarmInPort : ~AlarmStatusPort;
                port displayOutPort : DisplayOutputPort;
                attribute resolution : Integer;
                attribute refreshRate : FrequencyValue;
                perform action updateDisplay : UpdateDisplay;
            }

            part def AlarmController {
                port pressureInPort : ~CorrectedPressurePort;
                port alarmOutPort : AlarmStatusPort;
                attribute highThreshold : PressureValue;
                attribute lowThreshold : PressureValue;
                attribute hysteresis : PressureValue;
                perform action controlAlarm : ControlAlarm;
                exhibit state alarmStates : AlarmStates;
            }

            part def DigitalPressureGauge {
                port fluidPort : FluidPort;
                port powerPort : PowerPort;
                port displayOutputPort : DisplayOutputPort;
                part pressureSensor : PressureSensor;
                part signalProcessor : SignalProcessor;
                part displayUnit : DisplayUnit;
                part alarmController : AlarmController;
                attribute operatingPressureMin : PressureValue;
                attribute operatingPressureMax : PressureValue;
                attribute operatingTempMin : TemperatureValue;
                attribute operatingTempMax : TemperatureValue;
            }
        }

        package RequirementDefinitions {
            requirement def MeasurementAccuracy {
                doc
                /* The gauge shall provide pressure measurements with an accuracy
                   of at most 0.5 percent of full scale. */
                attribute fullScale : PressureValue;
                attribute maxErrorPercent : Real;
            }
            requirement def ResponseTime {
                doc
                /* The response time to a step change in pressure shall be
                   less than 100 ms. */
                attribute maxResponseTime : TimeValue;
            }
            requirement def AlarmFunctionality {
                doc
                /* The alarm system shall trigger a high alarm when pressure
                   exceeds the high threshold and a low alarm when pressure
                   drops below the low threshold, with hysteresis to prevent
                   chattering. */
            }
            requirement def OperatingPressureRange {
                doc
                /* The system shall operate correctly within the specified
                   pressure range. */
                attribute minPressure : PressureValue;
                attribute maxPressure : PressureValue;
            }
            requirement def OperatingTemperatureRange {
                doc
                /* The system shall operate correctly within the specified
                   temperature range. */
                attribute minTemp : TemperatureValue;
                attribute maxTemp : TemperatureValue;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        requirement measurementAccuracyReq : MeasurementAccuracy {
            attribute fullScale = 15000000 [Pa];
            attribute maxErrorPercent = 0.5;
        }
        requirement responseTimeReq : ResponseTime {
            attribute maxResponseTime = 0.1 [s];
        }
        requirement alarmFunctionalityReq : AlarmFunctionality;
        requirement operatingPressureRangeReq : OperatingPressureRange {
            attribute minPressure = 0 [Pa];
            attribute maxPressure = 15000000 [Pa];
        }
        requirement operatingTemperatureRangeReq : OperatingTemperatureRange {
            attribute minTemp = 253.15 [K];
            attribute maxTemp = 353.15 [K];
        }

        part digitalPressureGauge : DigitalPressureGauge {
            port fluidPort : FluidPort;
            port powerPort : PowerPort;
            port displayOutputPort : DisplayOutputPort;
            attribute operatingPressureMin = 0 [Pa];
            attribute operatingPressureMax = 15000000 [Pa];
            attribute operatingTempMin = 253.15 [K];
            attribute operatingTempMax = 353.15 [K];

            part pressureSensor : PressureSensor {
                attribute sensitivity = 1.0e-6;
                attribute offset = 0 [V];
                exhibit state sensorStates : SensorStates {
                    entry action initial;
                    transition initial then off;
                    state off;
                    transition off_to_on
                        first off
                        accept PowerOn
                        then on;
                    state on;
                    transition on_to_off
                        first on
                        accept PowerOff
                        then off;
                }
            }

            part signalProcessor : SignalProcessor {
                attribute calibrationFactor = 1.0e6;
                attribute zeroOffset = 0 [Pa];
                attribute calibrationStatus = true;
                exhibit state processorStates : ProcessorStates {
                    entry action initial;
                    transition initial then uncalibrated;
                    state uncalibrated;
                    transition uncalibrated_to_calibrated
                        first uncalibrated
                        accept CalibrationComplete
                        then calibrated;
                    state calibrated;
                }
            }

            part displayUnit : DisplayUnit {
                attribute resolution = 1000;
                attribute refreshRate = 10 [Hz];
            }

            part alarmController : AlarmController {
                attribute highThreshold = 10000000 [Pa];
                attribute lowThreshold = 100000 [Pa];
                attribute hysteresis = 50000 [Pa];
                exhibit state alarmStates : AlarmStates {
                    entry action initial;
                    transition initial then normal;
                    state normal;
                    state highAlarm;
                    state lowAlarm;
                    transition normal_to_highAlarm
                        first normal
                        accept pressureReading : PressureReading via pressureInPort
                        if pressureReading.value > highThreshold
                        then highAlarm;
                    transition highAlarm_to_normal
                        first highAlarm
                        accept pressureReading : PressureReading via pressureInPort
                        if pressureReading.value < highThreshold - hysteresis
                        then normal;
                    transition normal_to_lowAlarm
                        first normal
                        accept pressureReading : PressureReading via pressureInPort
                        if pressureReading.value < lowThreshold
                        then lowAlarm;
                    transition lowAlarm_to_normal
                        first lowAlarm
                        accept pressureReading : PressureReading via pressureInPort
                        if pressureReading.value > lowThreshold + hysteresis
                        then normal;
                }
            }

            connect fluidPort to pressureSensor.fluidPort;
            connect powerPort to pressureSensor.powerPort;
            connect pressureSensor.rawSignalPort to signalProcessor.rawSignalInPort;
            connect signalProcessor.pressureOutPort to displayUnit.pressureInPort;
            connect signalProcessor.pressureOutPort to alarmController.pressureInPort;
            connect alarmController.alarmOutPort to displayUnit.alarmInPort;
            connect displayUnit.displayOutPort to displayOutputPort;

            satisfy measurementAccuracyReq;
            satisfy responseTimeReq;
            satisfy alarmFunctionalityReq;
            satisfy operatingPressureRangeReq;
            satisfy operatingTemperatureRangeReq;
        }
    }
}
