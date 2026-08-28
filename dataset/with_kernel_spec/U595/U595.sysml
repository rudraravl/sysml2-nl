package BarometricAltimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def SelfTestPassedSignal;
        attribute def SelfTestFailedSignal;
        attribute def FaultDetectedSignal;
        attribute def FaultClearedSignal;
        attribute def LowAltitudeAlert;
        attribute def HighAltitudeAlert;

        item def StaticPressureReading {
            attribute value : PressureValue;
        }
        item def TemperatureReading {
            attribute value : TemperatureValue;
        }
        item def AltitudeReading {
            attribute value : LengthValue;
            attribute valid : Boolean;
        }
        item def PowerFlowItem {
            attribute value : PowerValue;
        }

        action def MeasurePressure {
            out pressure : StaticPressureReading;
        }
        action def MeasureTemperature {
            out temperature : TemperatureReading;
        }
        action def CalculateAltitude {
            in pressure : StaticPressureReading;
            in temperature : TemperatureReading;
            in barometricSetting : PressureValue;
            out altitude : AltitudeReading;
        }
        action def ValidateData {
            in altitude : AltitudeReading;
            out valid : Boolean;
        }
        action def DisplayAltitude {
            in altitude : AltitudeReading;
        }
        action def MonitorAltitude {
            in altitude : AltitudeReading;
            out alert : LowAltitudeAlert;
        }
        action def InitializeSystem;
        action def PerformSelfTest;

        action def NormalOperation {
            action measurePressure : MeasurePressure;
            action measureTemperature : MeasureTemperature;
            action calculateAltitude : CalculateAltitude;
            action validateData : ValidateData;
            action displayAltitude : DisplayAltitude;
            action monitorAltitude : MonitorAltitude;
            flow pressureFlow of StaticPressureReading from measurePressure.pressure to calculateAltitude.pressure;
            flow temperatureFlow of TemperatureReading from measureTemperature.temperature to calculateAltitude.temperature;
            flow altitudeValidateFlow of AltitudeReading from calculateAltitude.altitude to validateData.altitude;
            flow altitudeDisplayFlow of AltitudeReading from calculateAltitude.altitude to displayAltitude.altitude;
            flow altitudeWarningFlow of AltitudeReading from calculateAltitude.altitude to monitorAltitude.altitude;
        }

        part def PressureTransducer {
            port pressureDataPort {
                out pressure : StaticPressureReading;
                out temperature : TemperatureReading;
            }
            port powerPort {
                in power : PowerFlowItem;
            }
            perform action measurePressure : MeasurePressure;
            perform action measureTemperature : MeasureTemperature;
        }
        part def ComputerModule {
            attribute barometricSetting : PressureValue;
            port pressureInPort {
                in pressure : StaticPressureReading;
                in temperature : TemperatureReading;
            }
            port altitudeOutPort {
                out altitude : AltitudeReading;
            }
            port powerPort {
                in power : PowerFlowItem;
            }
            perform action calculateAltitude : CalculateAltitude;
            perform action validateData : ValidateData;
            perform action initializeSystem : InitializeSystem;
            perform action performSelfTest : PerformSelfTest;
        }
        part def IndicatorDisplay {
            port altitudeInPort {
                in altitude : AltitudeReading;
            }
            port alertInPort {
                in alert : LowAltitudeAlert;
            }
            port powerPort {
                in power : PowerFlowItem;
            }
            perform action displayAltitude : DisplayAltitude;
        }
        part def WarningSystem {
            attribute minSafeAltitude : LengthValue;
            attribute maxOperatingAltitude : LengthValue;
            port altitudeInPort {
                in altitude : AltitudeReading;
            }
            port alertPort {
                out alert : LowAltitudeAlert;
            }
            port powerPort {
                in power : PowerFlowItem;
            }
            perform action monitorAltitude : MonitorAltitude;
        }
        part def PowerSupply {
            attribute outputPower : PowerValue;
            port powerOutPort {
                out power : PowerFlowItem;
            }
        }

        part def BarometricAltimeter {
            part pressureTransducer : PressureTransducer;
            part computerModule : ComputerModule;
            part indicatorDisplay : IndicatorDisplay;
            part warningSystem : WarningSystem;
            part powerSupply : PowerSupply;

            flow pressureFlow of StaticPressureReading
                from pressureTransducer.pressureDataPort.pressure to computerModule.pressureInPort.pressure;
            flow temperatureFlow of TemperatureReading
                from pressureTransducer.pressureDataPort.temperature to computerModule.pressureInPort.temperature;
            flow altitudeDisplayFlow of AltitudeReading
                from computerModule.altitudeOutPort.altitude to indicatorDisplay.altitudeInPort.altitude;
            flow altitudeWarningFlow of AltitudeReading
                from computerModule.altitudeOutPort.altitude to warningSystem.altitudeInPort.altitude;
            flow alertFlow of LowAltitudeAlert
                from warningSystem.alertPort.alert to indicatorDisplay.alertInPort.alert;
            flow powerFlow1 of PowerFlowItem
                from powerSupply.powerOutPort.power to pressureTransducer.powerPort.power;
            flow powerFlow2 of PowerFlowItem
                from powerSupply.powerOutPort.power to computerModule.powerPort.power;
            flow powerFlow3 of PowerFlowItem
                from powerSupply.powerOutPort.power to indicatorDisplay.powerPort.power;
            flow powerFlow4 of PowerFlowItem
                from powerSupply.powerOutPort.power to warningSystem.powerPort.power;

            perform action normalOperation : NormalOperation;

            exhibit state altimeterStates {
                entry; then off;
                state off;
                accept PowerOnSignal
                    then initializing;
                state initializing {
                    entry computerModule.initializeSystem;
                    do computerModule.performSelfTest;
                }
                accept SelfTestPassedSignal
                    then normal;
                accept SelfTestFailedSignal
                    then fault;
                state normal {
                    do normalOperation;
                }
                accept FaultDetectedSignal
                    then fault;
                state fault;
                accept FaultClearedSignal
                    then normal;
                accept PowerOffSignal
                    then off;
            }
        }

        requirement def AltitudeAccuracyRequirement {
            doc /* The altimeter shall provide altitude readings accurate to within 50 meters. */
            attribute maxError : LengthValue = 50 [m];
            subject alt : BarometricAltimeter;
        }
        requirement def WarningThresholdRequirement {
            doc /* The warning system shall alert when altitude is below minimum safe altitude or above maximum operating altitude. */
            attribute minSafeAltitudeThreshold : LengthValue = 100 [m];
            attribute maxOperatingAltitudeThreshold : LengthValue = 15000 [m];
            subject ws : WarningSystem;
        }
        requirement def PowerSupplyRequirement {
            doc /* The power supply shall provide sufficient power to all components. */
            attribute requiredPower : PowerValue = 10 [W];
            subject ps : PowerSupply;
        }
        requirement def ContinuousOperationRequirement {
            doc /* The altimeter shall continuously measure, calculate, and display altitude during normal operation. */
            subject alt : BarometricAltimeter;
        }
        requirement def FaultDetectionRequirement {
            doc /* The altimeter shall enter a fault state when a problem is detected at any time. */
            subject alt : BarometricAltimeter;
        }
        requirement def SelfTestRequirement {
            doc /* Upon power-on, the altimeter shall run an initialization and self-test sequence before entering normal operation. */
            subject alt : BarometricAltimeter;
        }
    }

    package Usages {
        private import Definitions::*;

        part altimeter : BarometricAltimeter;

        requirement altimeterAccuracy : AltitudeAccuracyRequirement {
            subject alt = altimeter;
        }
        requirement warningThreshold : WarningThresholdRequirement {
            subject ws = altimeter.warningSystem;
        }
        requirement powerSupplyReq : PowerSupplyRequirement {
            subject ps = altimeter.powerSupply;
        }
        requirement continuousOperation : ContinuousOperationRequirement {
            subject alt = altimeter;
        }
        requirement faultDetection : FaultDetectionRequirement {
            subject alt = altimeter;
        }
        requirement selfTest : SelfTestRequirement {
            subject alt = altimeter;
        }
    }
}
