package BoostGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def BoostPressureValue :> PressureValue;
    attribute def VoltageSignalValue :> Real;
    attribute def WarningThresholdValue :> PressureValue;

    item def PressureReading {
        attribute pressure : BoostPressureValue;
        attribute timestamp : TimeValue;
    }

    item def SensorVoltage {
        attribute voltage : VoltageSignalValue;
    }

    item def DisplayData {
        attribute reading : BoostPressureValue;
        attribute warningActive : Boolean;
    }

    port def PressureInputPort {
        in item pressureData : PressureReading;
    }

    port def SensorOutputPort {
        out item sensorSignal : SensorVoltage;
    }

    port def ProcessorInputPort {
        in item inputSignal : SensorVoltage;
    }

    port def ProcessorOutputPort {
        out item displayData : DisplayData;
    }

    port def DisplayInputPort {
        in item displayInfo : DisplayData;
    }

    part def IntakeManifold {
        port pressureOutput : PressureInputPort;
        attribute manifoldPressure : BoostPressureValue;
    }

    part def BoostPressureSensor {
        port pressureInput : PressureInputPort;
        port sensorOutput : SensorOutputPort;
        
        attribute sensorGain : Real;
        attribute sensorOffset : Real;

        action def MeasurePressure {
            in manifoldPressure : BoostPressureValue;
            out voltageSignal : VoltageSignalValue;

            first start;
            then assign voltageSignal := (manifoldPressure / 1.0 [Pa]) * sensorGain + sensorOffset;
            then done;
        }

        perform action measure : MeasurePressure[*] ordered;
    }

    part def SignalProcessor {
        port processorInput : ProcessorInputPort;
        port processorOutput : ProcessorOutputPort;

        attribute warningThreshold : WarningThresholdValue;
        attribute conversionFactor : Real;
        attribute filteredPressure : BoostPressureValue;

        action def ProcessSignal {
            in voltage : VoltageSignalValue;
            out data : DisplayData;

            first start;
            then action convertToPressure {
                out pressure : BoostPressureValue;
            }
            then assign convertToPressure.pressure := (voltage - 0.5) / conversionFactor * 1.0 [Pa];
            then action filterSignal {
                in rawPressure : BoostPressureValue;
                out smoothedPressure : BoostPressureValue;
            }
            then assign filterSignal.smoothedPressure := (convertToPressure.pressure + filteredPressure) / 2.0;
            then assign filteredPressure := filterSignal.smoothedPressure;
            then decide;
                if filterSignal.smoothedPressure > warningThreshold then setWarning;
                if filterSignal.smoothedPressure <= warningThreshold then clearWarning;
            action setWarning {
                out warningData : DisplayData {
                    attribute :>> reading = filterSignal.smoothedPressure;
                    attribute :>> warningActive = true;
                }
            }
            then merge complete;
            action clearWarning {
                out normalData : DisplayData {
                    attribute :>> reading = filterSignal.smoothedPressure;
                    attribute :>> warningActive = false;
                }
            }
            then complete;
            then assign data := setWarning.warningData;
            then done;
        }

        perform action process : ProcessSignal[*] ordered;
    }

    part def GaugeDisplay {
        port displayInput : DisplayInputPort;

        attribute currentReading : BoostPressureValue;
        attribute needleAngle : Real;
        attribute warningLightOn : Boolean;

        event PowerOnEvent;
        event PowerOffEvent;
        event OverboostCondition;
        event NormalCondition;

        state displayStateMachine {
            entry action initializeDisplay;

            state powerOff;
            state operational {
                state normalDisplay {
                    entry action showNormalReading;
                    do action updateNeedle;
                }
                state warningDisplay {
                    entry action activateWarningLight;
                    do action flashWarning;
                    exit action deactivateWarningLight;
                }
            }

            transition powerUp
                first powerOff
                accept PowerOnEvent
                then operational.normalDisplay;

            transition detectOverboost
                first operational.normalDisplay
                accept OverboostCondition
                then operational.warningDisplay;

            transition clearOverboost
                first operational.warningDisplay
                accept NormalCondition
                then operational.normalDisplay;

            transition powerDown
                first operational
                accept PowerOffEvent
                then powerOff;
        }

        action def InitializeDisplay;
        action def ShowNormalReading {
            in pressure : BoostPressureValue;
        }
        action def UpdateNeedle {
            in pressure : BoostPressureValue;
            out angle : Real;
        }
        action def ActivateWarningLight;
        action def FlashWarning;
        action def DeactivateWarningLight;
    }

    part def BoostGauge {
        doc /* 
            A boost gauge system that continuously monitors intake manifold pressure,
            processes the sensor data, and displays the boost level to the driver.
            The system alerts the driver when boost pressure exceeds safe thresholds.
        */

        part manifold : IntakeManifold;
        part sensor : BoostPressureSensor {
            :>> sensorGain = 2.5;
            :>> sensorOffset = 0.5;
        }
        part processor : SignalProcessor {
            :>> warningThreshold = 150000.0 [Pa];
            :>> conversionFactor = 2.5;
            :>> filteredPressure = 0.0 [Pa];
        }
        part display : GaugeDisplay;

        connection manifoldToSensor connect manifold.pressureOutput to sensor.pressureInput;
        connection sensorToProcessor connect sensor.sensorOutput to processor.processorInput;
        connection processorToDisplay connect processor.processorOutput to display.displayInput;

        action def MonitorBoostPressure {
            first start;
            then merge continuousLoop;
            then action readManifold {
                ref part :>> manifold;
                out pressure : PressureReading;
            }
            then action senseAndConvert {
                perform sensor.measure;
            }
            then action processData {
                perform processor.process;
            }
            then action updateDisplay {
                perform display.displayStateMachine;
            }
            then continuousLoop;
        }

        perform action monitoringCycle : MonitorBoostPressure;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The boost gauge shall measure boost pressure with accuracy within ±2% of full scale. */
        
        subject gauge : BoostGauge;
        
        require constraint {
            gauge.sensor.sensorGain >= 2.45 and
            gauge.sensor.sensorGain <= 2.55
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The boost gauge shall update the display within 50 milliseconds of pressure change. */
        
        subject gauge : BoostGauge;
        attribute maxUpdateTime : TimeValue = 0.05 [s];
        
        require constraint {
            maxUpdateTime <= 0.05 [s]
        }
    }

    requirement def OperatingRangeRequirement {
        doc /* The boost gauge shall measure and display boost pressure from -100 kPa to +300 kPa. */
        
        subject processor : SignalProcessor;
        
        require constraint {
            processor.conversionFactor > 0.0
        }
    }

    requirement def WarningFunctionRequirement {
        doc /* The boost gauge shall activate a warning when boost pressure exceeds 150 kPa. */
        
        subject processor : SignalProcessor;
        
        require constraint {
            processor.warningThreshold == 150000.0 [Pa]
        }
    }

    requirement boostGaugeSystemRequirements {
        doc /* 
            The boost gauge system shall accurately measure intake manifold boost pressure,
            process the sensor signal, display real-time boost levels to the driver,
            and provide visual warning when boost exceeds safe operating limits.
        */
        
        subject system : BoostGauge;
        
        require accuracyReq : MeasurementAccuracyRequirement;
        require responseReq : ResponseTimeRequirement;
        require rangeReq : OperatingRangeRequirement;
        require warningReq : WarningFunctionRequirement;
    }

    part boostGaugeSystem : BoostGauge {
        satisfy boostGaugeSystemRequirements;
    }
}
