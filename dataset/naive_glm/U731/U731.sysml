package IRThermometer {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;
    import MeasurementReferences::*;

    // ---------- Value Types ----------
    value def Temperature :> Real { unit 'K'; }
    value def TemperatureCelsius :> Real { unit 'degC'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Irradiance :> Real { unit 'W/m^2'; }
    value def Distance :> Real { unit 'm'; }
    value def DigitalCount :> Integer;
    value def Emissivity :> Real;
    value def GainFactor :> Real;
    value def Duration :> Real { unit 's'; }

    // ---------- Item Types ----------
    item def InfraredRadiation {
        attribute irradiance : Irradiance;
        attribute wavelength : Real { unit 'm'; }
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
    }

    item def DigitalSample {
        attribute rawValue : DigitalCount;
        attribute timestamp : Duration;
    }

    item def TemperatureReading {
        attribute value : Temperature;
        attribute mode : MeasurementMode;
        attribute timestamp : Duration;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ---------- Enumerations ----------
    enum def MeasurementMode {
        SINGLE_POINT;
        CONTINUOUS_SCAN;
        MAX_MIN_AVG;
    }

    enum def PowerState {
        OFF;
        STANDBY;
        MEASURING;
        DISPLAYING;
        SLEEP;
    }

    enum def ButtonEvent {
        PRESSED;
        RELEASED;
        LONG_PRESS;
    }

    // ---------- Port Definitions ----------
    port def IRPort {
        out item radiation : InfraredRadiation;
    }

    port def AnalogPort {
        out item signal : AnalogSignal;
    }

    port def DigitalPort {
        out item sample : DigitalSample;
    }

    port def PowerPort {
        out item power : ElectricalPower;
    }

    port def DisplayPort {
        in item reading : TemperatureReading;
    }

    port def CommandPort {
        out item command : String;
    }

    port def TriggerPort {
        out item event : ButtonEvent;
    }

    port def ModePort {
        out item event : ButtonEvent;
    }

    // ---------- Requirements ----------
    requirement def MeasurementAccuracyRequirement {
        doc /* The thermometer shall measure surface temperature within +/-2% of reading. */
        attribute accuracy : Real = 0.02;
        subject : Temperature;
        constraint { abs(value - trueValue) <= accuracy * trueValue }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The thermometer shall measure temperatures from -50 degC to 380 degC. */
        attribute minRange : TemperatureCelsius = -50;
        attribute maxRange : TemperatureCelsius = 380;
    }

    requirement def ResponseTimeRequirement {
        doc /* The thermometer shall produce a reading within 500 ms of trigger pull. */
        attribute maxResponseTime : Duration = 0.5;
    }

    requirement def BatteryLifeRequirement {
        doc /* The device shall operate for at least 12 hours in standby. */
        attribute minStandbyHours : Real = 12;
    }

    requirement def PowerManagementRequirement {
        doc /* The device shall enter sleep mode after 15 seconds of inactivity. */
        attribute inactivityTimeout : Duration = 15;
    }

    // ---------- Component Definitions ----------

    part def OpticalLens {
        doc /* Focuses infrared radiation from the target onto the thermopile sensor. */
        attribute focalLength : Distance = 0.02;
        attribute fieldOfView : Real = 12.0; // degrees
        port in IRInput;
        port out IROutput : IRPort;
        action def FocusRadiation {
            in radiation : InfraredRadiation;
            out focused : InfraredRadiation;
        }
    }

    part def ThermopileSensor {
        doc /* Converts infrared heat energy into a small electrical voltage. */
        attribute sensitivity : Real = 40.0; // V/W
        attribute coldJunctionTemp : Temperature;
        port in IRInput : IRPort;
        port out analogOut : AnalogPort;
        action def ConvertIRtoVoltage {
            in radiation : InfraredRadiation;
            out signal : AnalogSignal;
            constraint { signal.voltage == sensitivity * radiation.irradiance }
        }
    }

    part def SignalAmplifier {
        doc /* Boosts the weak thermopile signal to a usable level. */
        attribute gain : GainFactor = 1000.0;
        attribute offsetVoltage : Voltage = 0.0;
        port in analogIn : AnalogPort;
        port out analogOut : AnalogPort;
        action def Amplify {
            in input : AnalogSignal;
            out output : AnalogSignal;
            constraint { output.voltage == gain * input.voltage + offsetVoltage }
        }
    }

    part def AnalogToDigitalConverter {
        doc /* Translates amplified analog voltage into a digital value. */
        attribute resolution : Integer = 16;
        attribute referenceVoltage : Voltage = 3.3;
        port in analogIn : AnalogPort;
        port out digitalOut : DigitalPort;
        action def Convert {
            in input : AnalogSignal;
            out output : DigitalSample;
            constraint { output.rawValue == toInteger(input.voltage / referenceVoltage * (2^resolution - 1)) }
        }
    }

    part def AmbientTemperatureSensor {
        doc /* Measures the internal ambient temperature for compensation. */
        attribute ambientTemp : Temperature;
        port out ambientOut : DigitalPort;
        action def MeasureAmbient {
            out sample : DigitalSample;
        }
    }

    part def Microcontroller {
        doc /* Central processing unit that calculates final temperature. */
        attribute emissivity : Emissivity = 0.95;
        attribute calibrationOffset : Temperature = 0.0;
        attribute currentMode : MeasurementMode = MeasurementMode::SINGLE_POINT;
        port in digitalIn : DigitalPort;
        port in ambientIn : DigitalPort;
        port in triggerIn : TriggerPort;
        port in modeIn : ModePort;
        port out displayOut : DisplayPort;
        port out laserCommand : CommandPort;

        action def CalculateTemperature {
            in sample : DigitalSample;
            in ambient : DigitalSample;
            in emiss : Emissivity;
            out reading : TemperatureReading;
            attribute rawTemp : Temperature;
            attribute compensated : Temperature;
            // Stefan-Boltzmann based compensation
            constraint { reading.value == compensated + calibrationOffset }
        }

        action def ProcessMeasurement {
            in sample : DigitalSample;
            in ambient : DigitalSample;
            out reading : TemperatureReading;
            perform CalculateTemperature {
                in sample = sample;
                in ambient = ambient;
                in emiss = emissivity;
                out reading = reading;
            }
        }

        state def PowerStateMachine {
            entry; then Off;

            state Off {
                entry { /* device powered off */ }
                transition off_to_standby
                    first Off then Standby
                    accept TriggerPort::PRESSED;
            }

            state Standby {
                entry { /* ready to measure */ }
                transition standby_to_measuring
                    first Standby then Measuring
                    accept TriggerPort::PRESSED;
                transition standby_to_sleep
                    first Standby then Sleep
                    when inactivityTimer >= 15.0;
            }

            state Measuring {
                entry { /* capture IR, calculate temperature */ }
                do { ProcessMeasurement; }
                transition measuring_to_displaying
                    first Measuring then Displaying
                    when measurementComplete;
            }

            state Displaying {
                entry { /* send reading to LCD */ }
                transition displaying_to_standby
                    first Displaying then Standby
                    accept TriggerPort::RELEASED;
                transition displaying_to_measuring
                    first Displaying then Measuring
                    when currentMode == MeasurementMode::CONTINUOUS_SCAN;
            }

            state Sleep {
                entry { /* low power mode */ }
                transition sleep_to_standby
                    first Sleep then Standby
                    accept TriggerPort::PRESSED;
            }

            attribute inactivityTimer : Duration = 0.0;
            attribute measurementComplete : Boolean = false;
        }
    }

    part def LCDDisplay {
        doc /* Displays the temperature reading to the user. */
        attribute backlightEnabled : Boolean = true;
        port in displayIn : DisplayPort;
        action def Render {
            in reading : TemperatureReading;
            attribute displayedValue : TemperatureCelsius;
        }
    }

    part def LaserPointer {
        doc /* Projects a red dot onto the target for aiming. */
        attribute wavelength : Real = 0.000000650; // 650 nm
        attribute active : Boolean = false;
        port in commandIn : CommandPort;
        action def ProjectDot {
            in command : String;
        }
    }

    part def PowerSupply {
        doc /* Battery-based regulated power supply for all components. */
        attribute batteryVoltage : Voltage = 9.0;
        attribute regulatedVoltage : Voltage = 3.3;
        attribute batteryCapacity : Real = 1.5; // Ah
        attribute remainingCharge : Real = 1.5;
        port out powerOut : PowerPort;
        action def Regulate {
            out power : ElectricalPower;
            constraint { power.voltage == regulatedVoltage }
        }
    }

    part def TriggerButton {
        doc /* Main trigger button to initiate measurements. */
        port out triggerOut : TriggerPort;
        action def DetectPress {
            out event : ButtonEvent;
        }
    }

    part def ModeSelector {
        doc /* Button to switch between measurement modes. */
        port out modeOut : ModePort;
        action def CycleMode {
            out event : ButtonEvent;
        }
    }

    // ---------- Top-level System ----------
    part def InfraredThermometer {
        doc /* Handheld non-contact infrared thermometer (temperature gun). */

        satisfy MeasurementAccuracyRequirement;
        satisfy MeasurementRangeRequirement;
        satisfy ResponseTimeRequirement;
        satisfy BatteryLifeRequirement;
        satisfy PowerManagementRequirement;

        part opticalLens : OpticalLens;
        part thermopile : ThermopileSensor;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part microcontroller : Microcontroller;
        part ambientSensor : AmbientTemperatureSensor;
        part display : LCDDisplay;
        part laser : LaserPointer;
        part powerSupply : PowerSupply;
        part trigger : TriggerButton;
        part modeSelector : ModeSelector;

        // External IR input port
        port in targetIR : IRPort;

        // ---------- Connections ----------
        connection def IRFocus {
            end source : IRPort;
            end target : IRPort;
        }

        connection def AnalogLink {
            end source : AnalogPort;
            end target : AnalogPort;
        }

        connection def DigitalLink {
            end source : DigitalPort;
            end target : DigitalPort;
        }

        connection def PowerDistribution {
            end source : PowerPort;
            end target : PowerPort;
        }

        connection def DisplayLink {
            end source : DisplayPort;
            end target : DisplayPort;
        }

        connection def CommandLink {
            end source : CommandPort;
            end target : CommandPort;
        }

        connection def TriggerLink {
            end source : TriggerPort;
            end target : TriggerPort;
        }

        connection def ModeLink {
            end source : ModePort;
            end target : ModePort;
        }

        // IR path
        connection irInput : IRFocus connect targetIR to opticalLens.IRInput;
        connection irToThermopile : IRFocus connect opticalLens.IROutput to thermopile.IRInput;
        connection thermopileToAmp : AnalogLink connect thermopile.analogOut to amplifier.analogIn;
        connection ampToADC : AnalogLink connect amplifier.analogOut to adc.analogIn;
        connection adcToMCU : DigitalLink connect adc.digitalOut to microcontroller.digitalIn;
        connection ambientToMCU : DigitalLink connect ambientSensor.ambientOut to microcontroller.ambientIn;

        // Display and laser
        connection mcuToDisplay : DisplayLink connect microcontroller.displayOut to display.displayIn;
        connection mcuToLaser : CommandLink connect microcontroller.laserCommand to laser.commandIn;

        // User inputs
        connection triggerToMCU : TriggerLink connect trigger.triggerOut to microcontroller.triggerIn;
        connection modeToMCU : ModeLink connect modeSelector.modeOut to microcontroller.modeIn;

        // Power distribution
        connection powerToMCU : PowerDistribution connect powerSupply.powerOut to microcontroller;
        connection powerToAmp : PowerDistribution connect powerSupply.powerOut to amplifier;
        connection powerToADC : PowerDistribution connect powerSupply.powerOut to adc;
        connection powerToDisplay : PowerDistribution connect powerSupply.powerOut to display;
        connection powerToLaser : PowerDistribution connect powerSupply.powerOut to laser;
        connection powerToAmbient : PowerDistribution connect powerSupply.powerOut to ambientSensor;

        // ---------- System-level behavior ----------
        action def MeasurementSequence {
            doc /* Full measurement sequence from trigger pull to display. */
            in targetRadiation : InfraredRadiation;
            in ambientTemp : Temperature;
            in emiss : Emissivity;
            out finalReading : TemperatureReading;

            attribute focusedRadiation : InfraredRadiation;
            attribute rawSignal : AnalogSignal;
            attribute amplifiedSignal : AnalogSignal;
            attribute digitalSample : DigitalSample;
            attribute ambientSample : DigitalSample;

            perform focus : OpticalLens::FocusRadiation {
                in radiation = targetRadiation;
                out focused = focusedRadiation;
            }
            then perform convert : ThermopileSensor::ConvertIRtoVoltage {
                in radiation = focusedRadiation;
                out signal = rawSignal;
            }
            then perform amplify : SignalAmplifier::Amplify {
                in input = rawSignal;
                out output = amplifiedSignal;
            }
            then perform digitize : AnalogToDigitalConverter::Convert {
                in input = amplifiedSignal;
                out output = digitalSample;
            }
            then perform calculate : Microcontroller::CalculateTemperature {
                in sample = digitalSample;
                in ambient = ambientSample;
                in emiss = emiss;
                out reading = finalReading;
            }
        }

        // System state machine instance
        attribute powerState : PowerState = PowerState::OFF;
    }
}
