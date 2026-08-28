package BoostGaugeSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def PressureValue :> Real {
        unit 'kPa';
    }
    value def VoltageValue :> Real {
        unit 'V';
    }
    value def TimeValue :> Real {
        unit 'ms';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }

    // ---- Item Definitions ----
    item def PressurizedAir {
        attribute pressure : PressureValue;
    }
    item def PressureVoltageSignal {
        attribute voltage : VoltageValue;
    }
    item def ProcessedPressureData {
        attribute pressure : PressureValue;
        attribute overboost : Boolean;
    }
    item def DisplayCommand {
        attribute pressure : PressureValue;
        attribute warningActive : Boolean;
    }

    // ---- Port Definitions ----
    port def AirPort {
        out item air : PressurizedAir;
    }
    port def VoltageOutPort {
        out item signal : PressureVoltageSignal;
    }
    port def VoltageInPort {
        in item signal : PressureVoltageSignal;
    }
    port def DataOutPort {
        out item data : ProcessedPressureData;
    }
    port def DataInPort {
        in item data : ProcessedPressureData;
    }
    port def CommandOutPort {
        out item command : DisplayCommand;
    }
    port def CommandInPort {
        in item command : DisplayCommand;
    }

    // ---- Requirements ----
    requirement def AccuracyRequirement {
        doc << "The system shall measure boost pressure with an accuracy of +/- 2 kPa.">>
        attribute maxError : PressureValue = 2;
    }
    requirement def ResponsivenessRequirement {
        doc << "The display shall update within 50 milliseconds of a pressure change.">>
        attribute maxLatency : TimeValue = 50;
    }
    requirement def OverboostWarningRequirement {
        doc << "The system shall activate a warning when pressure exceeds the safety threshold.">>
        attribute threshold : PressureValue = 250;
    }
    requirement def ReliabilityRequirement {
        doc << "The warning function shall operate reliably under all driving conditions.">>
    }

    // ---- Intake Manifold ----
    part def IntakeManifold {
        port airOut : AirPort;
        attribute nominalPressure : PressureValue = 101.3;
        attribute maxPressure : PressureValue = 300;
        action def EmitAir;
        action emitAir : EmitAir {
            out item air : PressurizedAir;
        }
    }

    // ---- Boost Pressure Sensor ----
    part def BoostPressureSensor {
        port airIn : AirPort;
        port voltageOut : VoltageOutPort;
        attribute sensitivity : Real = 0.0125; // V/kPa
        attribute offset : VoltageValue = 0.5;
        attribute minVoltage : VoltageValue = 0.5;
        attribute maxVoltage : VoltageValue = 4.5;
        action def SensePressure {
            in item air : PressurizedAir;
            out item signal : PressureVoltageSignal;
        }
        action sense : SensePressure {
            in item air : PressurizedAir;
            out item signal : PressureVoltageSignal;
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        port voltageIn : VoltageInPort;
        port dataOut : DataOutPort;
        port commandOut : CommandOutPort;
        attribute safetyThreshold : PressureValue = 250;
        attribute hysteresis : PressureValue = 10;
        attribute filterCoefficient : Real = 0.2;
        attribute currentPressure : PressureValue;
        attribute smoothedPressure : PressureValue;
        attribute overboostActive : Boolean = false;
        attribute lastUpdateTime : TimeValue = 0;
        attribute updateInterval : TimeValue = 10;

        action def ConvertVoltage {
            in item signal : PressureVoltageSignal;
            out attribute pressure : PressureValue;
        }
        action def FilterPressure {
            in attribute rawPressure : PressureValue;
            out attribute filteredPressure : PressureValue;
        }
        action def CheckThreshold {
            in attribute pressure : PressureValue;
            out attribute overboost : Boolean;
        }
        action def GenerateCommand {
            in attribute pressure : PressureValue;
            in attribute overboost : Boolean;
            out item command : DisplayCommand;
        }
        action def ProcessCycle {
            in item signal : PressureVoltageSignal;
            out item data : ProcessedPressureData;
            out item command : DisplayCommand;
        }
        action process : ProcessCycle {
            in item signal : PressureVoltageSignal;
            out item data : ProcessedPressureData;
            out item command : DisplayCommand;
        }

        state def ProcessorBehavior {
            entry action { overboostActive = false; }
            state Monitoring {
                entry action {
                    smoothedPressure = currentPressure;
                }
                do action process;
                transition Monitoring to Warning
                    when currentPressure > safetyThreshold {
                    action { overboostActive = true; }
                }
            }
            state Warning {
                do action process;
                transition Warning to Monitoring
                    when currentPressure < (safetyThreshold - hysteresis) {
                    action { overboostActive = false; }
                }
            }
        }
        exhibit state behavior : ProcessorBehavior;
    }

    // ---- Gauge Display ----
    part def GaugeDisplay {
        port dataIn : DataInPort;
        port commandIn : CommandInPort;
        attribute displayedPressure : PressureValue;
        attribute warningLightOn : Boolean = false;
        attribute backlightIntensity : Real = 0.8;
        attribute needlePosition : Real;
        attribute maxDisplayPressure : PressureValue = 300;
        attribute minDisplayPressure : PressureValue = 0;

        action def UpdateDisplay {
            in item command : DisplayCommand;
        }
        action update : UpdateDisplay {
            in item command : DisplayCommand;
        }

        state def DisplayBehavior {
            entry action { warningLightOn = false; }
            state Normal {
                entry action {
                    warningLightOn = false;
                    displayedPressure = commandIn.command.pressure;
                    needlePosition = displayedPressure / maxDisplayPressure;
                }
                do action update;
                transition Normal to WarningState
                    when commandIn.command.warningActive == true {
                    action { warningLightOn = true; }
                }
            }
            state WarningState {
                entry action {
                    warningLightOn = true;
                    displayedPressure = commandIn.command.pressure;
                }
                do action update;
                transition WarningState to Normal
                    when commandIn.command.warningActive == false {
                    action { warningLightOn = false; }
                }
            }
        }
        exhibit state behavior : DisplayBehavior;
    }

    // ---- Boost Gauge System ----
    part def BoostGaugeSystem {
        part manifold : IntakeManifold {
            port airOut redefines AirPort;
        }
        part sensor : BoostPressureSensor {
            port airIn redefines AirPort;
            port voltageOut redefines VoltageOutPort;
        }
        part processor : SignalProcessor {
            port voltageIn redefines VoltageInPort;
            port dataOut redefines DataOutPort;
            port commandOut redefines CommandOutPort;
        }
        part display : GaugeDisplay {
            port dataIn redefines DataInPort;
            port commandIn redefines CommandInPort;
        }

        connection manifoldAirToSensor connect manifold.airOut to sensor.airIn;
        connection sensorVoltageToProcessor connect sensor.voltageOut to processor.voltageIn;
        connection processorDataToDisplay connect processor.dataOut to display.dataIn;
        connection processorCommandToDisplay connect processor.commandOut to display.commandIn;

        satisfy AccuracyRequirement by processor;
        satisfy ResponsivenessRequirement by processor;
        satisfy OverboostWarningRequirement by processor;
        satisfy OverboostWarningRequirement by display;
        satisfy ReliabilityRequirement by BoostGaugeSystem;
    }
}
