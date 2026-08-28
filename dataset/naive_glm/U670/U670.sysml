package EGTGaugeSystem {
    import ScalarValues::*;

    // ===== Value Types =====

    value type Temperature :> Real;
    value type Voltage :> Real;
    value type Current :> Real;
    value type Frequency :> Real;
    value type Duration :> Real;

    // ===== Item Definitions =====

    item def ExhaustGas {
        attribute temperature : Temperature;
        attribute flowRate : Real;
    }

    item def RawThermocoupleSignal {
        attribute voltage : Voltage;
        attribute coldJunctionTemp : Temperature;
    }

    item def ConditionedSignal {
        attribute voltage : Voltage;
        attribute noiseLevel : Voltage;
        attribute isStable : Boolean = true;
    }

    item def DisplayData {
        attribute temperature : Temperature;
        attribute warningActive : Boolean;
        attribute timestamp : Integer;
    }

    item def Power12VDC {
        attribute voltage : Voltage = 12;
        attribute maxCurrent : Current = 5;
    }

    item def Power5VDC {
        attribute voltage : Voltage = 5;
        attribute maxCurrent : Current = 2;
    }

    // ===== Port Definitions =====

    port def ExhaustStreamInPort {
        in item gas : ExhaustGas;
    }

    port def RawSignalOutPort {
        out item signal : RawThermocoupleSignal;
    }

    port def RawSignalInPort {
        in item signal : RawThermocoupleSignal;
    }

    port def ConditionedSignalOutPort {
        out item signal : ConditionedSignal;
    }

    port def ConditionedSignalInPort {
        in item signal : ConditionedSignal;
    }

    port def DisplayOutPort {
        out item data : DisplayData;
    }

    port def DisplayInPort {
        in item data : DisplayData;
    }

    port def WarningControlOutPort {
        out item warningSignal : Boolean;
    }

    port def WarningControlInPort {
        in item warningSignal : Boolean;
    }

    port def Power12VInPort {
        in item power : Power12VDC;
    }

    port def Power12VPassthroughPort {
        in item power : Power12VDC;
    }

    port def Power5VOutPort {
        out item power : Power5VDC;
    }

    port def Power5VInPort {
        in item power : Power5VDC;
    }

    // ===== Action Definitions =====

    action def MeasureExhaustTemperature {
        in gas : ExhaustGas;
        out signal : RawThermocoupleSignal;
    }

    action def ConditionAndAmplify {
        in raw : RawThermocoupleSignal;
        out conditioned : ConditionedSignal;
    }

    action def ConvertToDigital {
        in signal : ConditionedSignal;
        out temperature : Temperature;
    }

    action def EvaluateSafetyThreshold {
        in temperature : Temperature;
        in limit : Temperature;
        out exceedsLimit : Boolean;
    }

    action def PrepareDisplayData {
        in temperature : Temperature;
        in warning : Boolean;
        out data : DisplayData;
    }

    action def RenderDisplay {
        in data : DisplayData;
    }

    action def RegulateVoltage {
        in input : Power12VDC;
        out output : Power5VDC;
    }

    // ===== Part Definitions =====

    part def TypeKThermocoupleSensor {
        doc /* Durable Type K thermocouple sensor placed directly in the exhaust stream. Generates a small electrical signal proportional to measured temperature. */;

        port exhaustIn : ExhaustStreamInPort;
        port rawSignalOut : RawSignalOutPort;

        attribute sensorType : String = "Type K";
        attribute maxOperatingTemp : Temperature = 1260;
        attribute responseTimeSec : Duration = 0.5;
        attribute coldJunctionCompensation : Boolean = true;
        attribute hasFault : Boolean = false;
        attribute measuredTemperature : Temperature;

        action measure : MeasureExhaustTemperature;

        state sensorOperation {
            state operational {
                entry / {
                    measure;
                    hasFault = false;
                }
                do measure;
            }
            state faulted {
                entry / {
                    hasFault = true;
                }
            }
            transition from operational to faulted when hasFault == true;
            transition from faulted to operational when hasFault == false;
        }
    }

    part def SignalConditioner {
        doc /* Cleans up, filters, and amplifies the raw thermocouple signal to create a stable and reliable input for the microcontroller. */;

        port rawSignalIn : RawSignalInPort;
        port conditionedSignalOut : ConditionedSignalOutPort;

        attribute gain : Real = 1000;
        attribute filterCutoffHz : Frequency = 50;
        attribute inputNoiseFloorV : Voltage = 0.001;
        attribute outputNoiseLevelV : Voltage = 0.01;
        attribute isFunctional : Boolean = true;

        action condition : ConditionAndAmplify;

        state conditionerOperation {
            state filtering {
                entry / condition;
                do condition;
            }
            state bypass {
                entry / {
                    gain = 1;
                    filterCutoffHz = 0;
                }
            }
            transition from filtering to bypass when isFunctional == false;
            transition from bypass to filtering when isFunctional == true;
        }
    }

    part def Microcontroller {
        doc /* Central processing unit that receives the conditioned signal, converts it to a digital temperature in degrees Celsius, and compares it against a 900 degree Celsius safety limit. */;

        port conditionedSignalIn : ConditionedSignalInPort;
        port displayOut : DisplayOutPort;
        port warningControlOut : WarningControlOutPort;
        port powerIn : Power5VInPort;

        attribute currentTemperature : Temperature;
        attribute safetyLimit : Temperature = 900;
        attribute warningActive : Boolean = false;
        attribute samplingRateHz : Frequency = 100;
        attribute updateIntervalSec : Duration = 0.01;
        attribute conversionResolution : Integer = 16;
        attribute isRunning : Boolean = true;

        action convert : ConvertToDigital;
        action checkThreshold : EvaluateSafetyThreshold;
        action formatDisplay : PrepareDisplayData;

        state mcuState {
            state monitoring {
                entry / {
                    convert;
                    checkThreshold;
                    formatDisplay;
                }
                do {
                    convert;
                    checkThreshold;
                    if (currentTemperature > safetyLimit) {
                        warningActive = true;
                    } else {
                        warningActive = false;
                    }
                    formatDisplay;
                }
            }
            state overTemperature {
                entry / {
                    warningActive = true;
                    convert;
                    checkThreshold;
                    formatDisplay;
                }
                do {
                    convert;
                    checkThreshold;
                    if (currentTemperature <= safetyLimit) {
                        warningActive = false;
                    }
                    formatDisplay;
                }
            }
            transition from monitoring to overTemperature when currentTemperature > safetyLimit;
            transition from overTemperature to monitoring when currentTemperature <= safetyLimit;
        }
    }

    part def LCDDisplay {
        doc /* Backlit LCD digital display unit that presents the current temperature reading clearly to the operator. */;

        port displayDataIn : DisplayInPort;
        port powerIn : Power5VInPort;

        attribute backlightEnabled : Boolean = true;
        attribute brightnessLevel : Real = 0.75;
        attribute displayedTemperature : Temperature;
        attribute warningIconVisible : Boolean = false;
        attribute refreshRateHz : Frequency = 10;
        attribute digitCount : Integer = 4;
        attribute isOnline : Boolean = true;

        action render : RenderDisplay;

        state displayOperation {
            state showingReading {
                entry / {
                    backlightEnabled = true;
                    render;
                }
                do render;
            }
            state showingWarning {
                entry / {
                    warningIconVisible = true;
                    backlightEnabled = true;
                    render;
                }
                do render;
            }
            transition from showingReading to showingWarning when warningIconVisible == true;
            transition from showingWarning to showingReading when warningIconVisible == false;
        }
    }

    part def RedWarningIndicator {
        doc /* Dedicated red warning indicator light that blinks when the exhaust gas temperature exceeds the safety threshold of 900 degrees Celsius. */;

        port warningControlIn : WarningControlInPort;
        port powerIn : Power5VInPort;

        attribute isLit : Boolean = false;
        attribute isBlinking : Boolean = false;
        attribute blinkRateHz : Frequency = 2;
        attribute lampColor : String = "Red";
        attribute warningCommand : Boolean = false;
        attribute isPowered : Boolean = false;

        state indicatorState {
            state lampOff {
                entry / {
                    isLit = false;
                    isBlinking = false;
                }
            }
            state lampBlinking {
                entry / {
                    isBlinking = true;
                    isLit = true;
                }
                do {
                    if (warningCommand == false) {
                        isLit = false;
                        isBlinking = false;
                    }
                }
            }
            transition from lampOff to lampBlinking when warningCommand == true;
            transition from lampBlinking to lampOff when warningCommand == false;
        }
    }

    part def PowerSupply {
        doc /* Internal power supply that takes a standard 12V DC input and converts it to the 5V needed by internal electronics. */;

        port power12VIn : Power12VInPort;
        port power5VOut : Power5VOutPort;

        attribute inputVoltageV : Voltage = 12;
        attribute outputVoltageV : Voltage = 5;
        attribute maxOutputCurrentA : Current = 2;
        attribute efficiency : Real = 0.85;
        attribute isPowered : Boolean = false;
        attribute inputPresent : Boolean = false;
        attribute regulationType : String = "Switching";
        attribute thermalProtection : Boolean = true;

        action regulate : RegulateVoltage;

        state supplyState {
            state unpowered {
                entry / {
                    isPowered = false;
                    inputPresent = false;
                }
            }
            state powered {
                entry / {
                    isPowered = true;
                    inputPresent = true;
                    regulate;
                }
                do regulate;
            }
            state thermalShutdown {
                entry / {
                    isPowered = false;
                    outputVoltageV = 0;
                }
            }
            transition from unpowered to powered when inputPresent == true;
            transition from powered to unpowered when inputPresent == false;
            transition from powered to thermalShutdown when isPowered == true && efficiency < 0.5;
            transition from thermalShutdown to powered when isPowered == false && inputPresent == true;
        }
    }

    // ===== Top-level EGT Gauge Assembly =====

    part def EGTGaugeAssembly {
        doc /* Complete digital Exhaust Gas Temperature gauge system integrating a Type K thermocouple, signal conditioner, microcontroller, LCD display, warning indicator, and power supply. */;

        part thermocouple : TypeKThermocoupleSensor;
        part signalConditioner : SignalConditioner;
        part microcontroller : Microcontroller;
        part lcdDisplay : LCDDisplay;
        part warningLight : RedWarningIndicator;
        part powerSupply : PowerSupply;

        port systemExhaustPort : ExhaustStreamInPort;
        port systemPowerPort : Power12VInPort;

        // Signal flow connections
        connect systemExhaustPort to thermocouple.exhaustIn;
        connect thermocouple.rawSignalOut to signalConditioner.rawSignalIn;
        connect signalConditioner.conditionedSignalOut to microcontroller.conditionedSignalIn;
        connect microcontroller.displayOut to lcdDisplay.displayDataIn;
        connect microcontroller.warningControlOut to warningLight.warningControlIn;

        // Power distribution connections
        connect systemPowerPort to powerSupply.power12VIn;
        connect powerSupply.power5VOut to microcontroller.powerIn;
        connect powerSupply.power5VOut to lcdDisplay.powerIn;
        connect powerSupply.power5VOut to warningLight.powerIn;
    }

    // ===== Requirements =====

    requirement def TemperatureMeasurementRequirement {
        doc /* The EGT gauge system shall continuously measure the temperature of hot exhaust gases flowing from an engine using a Type K thermocouple sensor placed directly in the exhaust stream. */;

        subject : thermocouple : TypeKThermocoupleSensor;
        attribute measurementContinuity : Boolean = true;
        attribute sensorPlacement : String = "exhaust stream";
    }

    requirement def SignalConditioningRequirement {
        doc /* The signal conditioner shall clean up, filter, and amplify the raw thermocouple signal to create a stable and reliable input for the system microcontroller. */;

        subject : signalConditioner : SignalConditioner;
        attribute minGain : Real = 100;
        attribute maxNoiseLevelV : Voltage = 0.05;
    }

    requirement def DigitalConversionRequirement {
        doc /* The microcontroller shall receive the conditioned signal and convert it into a precise digital temperature value in degrees Celsius. */;

        subject : microcontroller : Microcontroller;
        attribute outputUnit : String = "Celsius";
        attribute resolutionBits : Integer = 16;
    }

    requirement def SafetyThresholdRequirement {
        doc /* The microcontroller shall constantly compare the current exhaust gas temperature against a pre-set safety limit of 900 degrees Celsius. */;

        subject : microcontroller : Microcontroller;
        attribute safetyLimit : Temperature = 900;
        attribute comparisonContinuity : Boolean = true;
    }

    requirement def DisplayOutputRequirement {
        doc /* The processed temperature shall be sent to a backlit LCD digital display unit that presents the reading clearly to the operator. */;

        subject : lcdDisplay : LCDDisplay;
        attribute displayType : String = "Backlit LCD";
        attribute digitCount : Integer = 4;
    }

    requirement def OverTemperatureWarningRequirement {
        doc /* If the exhaust gas temperature ever exceeds the safety threshold of 900 degrees Celsius, the microcontroller shall immediately activate a dedicated red warning indicator light that blinks to provide a distinct visual alert of the potentially damaging engine condition. */;

        subject : warningLight : RedWarningIndicator;
        attribute triggerThreshold : Temperature = 900;
        attribute indicatorColor : String = "Red";
        attribute blinkMode : Boolean = true;
        attribute responseTimeSec : Duration = 0.1;
    }

    requirement def PowerSupplyRequirement {
        doc /* The internal power supply shall take a standard 12V DC input and convert it to the 5V needed by the internal electronics. */;

        subject : powerSupply : PowerSupply;
        attribute inputVoltage : Voltage = 12;
        attribute outputVoltage : Voltage = 5;
        attribute inputType : String = "DC";
    }

    requirement def SystemIntegrationRequirement {
        doc /* All components of the EGT gauge system shall be interconnected such that the exhaust gas temperature is measured, conditioned, converted, displayed, and monitored against the safety threshold in real time. */;

        subject : system : EGTGaugeAssembly;
        attribute realtimeOperation : Boolean = true;
        attribute maxLatencySec : Duration = 0.5;
    }
}
