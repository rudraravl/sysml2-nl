package DigitalQuartzThermometer {

    import ScalarValues::*;
    import ISQ::*;
    import MeasurementReferences::*;

    // ---- Value Types ----

    value type FrequencyValue :> Real {
        unit 'Hz';
    }

    value type TemperatureValue :> Real {
        unit 'degC';
    }

    value type VoltageValue :> Real {
        unit 'V';
    }

    value type CurrentValue :> Real {
        unit 'A';
    }

    value type PowerValue :> Real {
        unit 'W';
    }

    value type TimeValue :> Real {
        unit 's';
    }

    value type AccuracyValue :> Real {
        unit 'degC';
    }

    value type FrequencyDataValue :> Real {
        unit 'Hz';
    }

    // ---- Item Types ----

    item def ElectronicSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : VoltageValue;
    }

    item def FrequencyMeasurement {
        attribute measuredFrequency : FrequencyDataValue;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def TemperatureReading {
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute confidence : Real;
    }

    item def CalibrationCoefficients {
        attribute c0 : Real;
        attribute c1 : Real;
        attribute c2 : Real;
        attribute c3 : Real;
    }

    item def DisplayMessage {
        attribute text : String;
        attribute temperature : TemperatureValue;
        attribute visible : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    // ---- Port Definitions ----

    port def SignalPort {
        out signal : ElectronicSignal;
    }

    port def FrequencyDataPort {
        out frequencyData : FrequencyMeasurement;
    }

    port def TemperatureDataPort {
        out temperatureData : TemperatureReading;
    }

    port def DisplayPort {
        out displayData : DisplayMessage;
    }

    port def PowerInputPort {
        in power : ElectricalPower;
    }

    port def PowerOutputPort {
        out power : ElectricalPower;
    }

    // ---- Part Definitions ----

    part def QuartzCrystalOscillator {
        attribute nominalFrequency : FrequencyValue = 28.0e6 [Hz];
        attribute temperatureCoefficient : Real = 35.0e-6;
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute powerConsumption : PowerValue = 0.5e-3 [W];

        in power : ElectricalPower via powerIn;
        out signal : ElectronicSignal via signalOut;

        port powerIn : PowerInputPort;
        port signalOut : SignalPort;

        attribute currentTemperature : TemperatureValue;

        action def generateSignal {
            in ambientTemp : TemperatureValue;
            out oscSignal : ElectronicSignal;
            
            // Frequency varies with temperature: f = f0 * (1 + alpha * (T - T0))
            perform {
                attribute deltaT : TemperatureValue = ambientTemp - 25.0 [degC];
                attribute computedFrequency : FrequencyValue = nominalFrequency * (1.0 + temperatureCoefficient * deltaT);
                oscSignal.frequency = computedFrequency;
                oscSignal.amplitude = operatingVoltage;
            }
        }

        state oscillatorBehavior {
            entry;
            do generateSignal(currentTemperature, signal);
            exit;
        }
    }

    part def FrequencyMeasurementCircuit {
        attribute measurementResolution : FrequencyValue = 0.1 [Hz];
        attribute gateTime : TimeValue = 0.1 [s];
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute powerConsumption : PowerValue = 1.0e-3 [W];

        in power : ElectricalPower via powerIn;
        in inputSignal : ElectronicSignal via signalIn;
        out frequencyData : FrequencyMeasurement via dataOut;

        port powerIn : PowerInputPort;
        port signalIn : SignalPort;
        port dataOut : FrequencyDataPort;

        action def measureFrequency {
            in inputSig : ElectronicSignal;
            out measurement : FrequencyMeasurement;
            
            perform {
                attribute countedCycles : Integer = (inputSig.frequency * gateTime) rounded;
                attribute measuredFreq : FrequencyDataValue = countedCycles / gateTime;
                measurement.measuredFrequency = measuredFreq;
                measurement.timestamp = 0.0 [s];
                measurement.valid = true;
            }
        }

        state measurementBehavior {
            entry;
            do measureFrequency(inputSignal, frequencyData);
            exit;
        }
    }

    part def MicroprocessorUnit {
        attribute clockSpeed : FrequencyValue = 8.0e6 [Hz];
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute powerConsumption : PowerValue = 2.0e-3 [W];
        attribute calibration : CalibrationCoefficients = CalibrationCoefficients{c0 = -25.0, c1 = 1.0e-6, c2 = 0.0, c3 = 0.0};
        attribute updateInterval : TimeValue = 0.5 [s];

        in power : ElectricalPower via powerIn;
        in frequencyData : FrequencyMeasurement via dataIn;
        out temperatureData : TemperatureReading via tempOut;

        port powerIn : PowerInputPort;
        port dataIn : FrequencyDataPort;
        port tempOut : TemperatureDataPort;

        action def convertFrequencyToTemperature {
            in freqData : FrequencyMeasurement;
            in coeffs : CalibrationCoefficients;
            out tempReading : TemperatureReading;
            
            perform {
                attribute deltaF : FrequencyDataValue = freqData.measuredFrequency - 28.0e6 [Hz];
                attribute computedTemp : TemperatureValue = coeffs.c0 + coeffs.c1 * deltaF + coeffs.c2 * deltaF * deltaF + coeffs.c3 * deltaF * deltaF * deltaF;
                tempReading.temperature = computedTemp;
                tempReading.timestamp = freqData.timestamp;
                tempReading.confidence = 0.99;
            }
        }

        action def processCycle {
            in freqInput : FrequencyMeasurement;
            out tempOutput : TemperatureReading;
            
            perform convertFrequencyToTemperature(freqInput, calibration, tempOutput);
        }

        state processingBehavior {
            entry;
            do processCycle(frequencyData, temperatureData);
            exit;
        }
    }

    part def LCDDisplay {
        attribute displayWidth : Integer = 16;
        attribute displayHeight : Integer = 2;
        attribute operatingVoltage : VoltageValue = 3.3 [V];
        attribute powerConsumption : PowerValue = 0.8e-3 [W];
        attribute backlightEnabled : Boolean = true;
        attribute refreshRate : FrequencyValue = 2.0 [Hz];

        in power : ElectricalPower via powerIn;
        in temperatureData : TemperatureReading via dataIn;

        port powerIn : PowerInputPort;
        port dataIn : TemperatureDataPort;

        action def updateDisplay {
            in tempData : TemperatureReading;
            
            perform {
                attribute displayText : String = "Temp: " + tempData.temperature.toString() + " C";
            }
        }

        state displayBehavior {
            entry;
            do updateDisplay(temperatureData);
            exit;
        }
    }

    part def BatteryPowerSource {
        attribute nominalVoltage : VoltageValue = 3.3 [V];
        attribute capacity : CurrentValue = 1.0 [A];
        attribute currentCharge : Real = 1.0;
        attribute maxOutputPower : PowerValue = 5.0e-3 [W];
        attribute batteryLife : TimeValue = 86400.0 [s];

        out power : ElectricalPower via powerOut;

        port powerOut : PowerOutputPort;

        action def supplyPower {
            out electricalPower : ElectricalPower;
            
            perform {
                electricalPower.voltage = nominalVoltage;
                electricalPower.current = 1.0e-3 [A];
                electricalPower.power = nominalVoltage * electricalPower.current;
            }
        }

        state powerSupplyBehavior {
            entry;
            do supplyPower(power);
            exit;
        }
    }

    // ---- Top-level Thermometer System ----

    part def DigitalQuartzThermometerSystem {

        attribute systemAccuracy : AccuracyValue = 0.01 [degC];
        attribute responseTime : TimeValue = 1.0 [s];
        attribute operatingRangeMin : TemperatureValue = -40.0 [degC];
        attribute operatingRangeMax : TemperatureValue = 85.0 [degC];
        attribute totalPowerConsumption : PowerValue = 4.3e-3 [W];

        part oscillator : QuartzCrystalOscillator {
            attribute currentTemperature : TemperatureValue = 22.0 [degC];
        }

        part frequencyCircuit : FrequencyMeasurementCircuit;
        part microprocessor : MicroprocessorUnit;
        part display : LCDDisplay;
        part battery : BatteryPowerSource;

        // Internal connections
        connection powerToOscillator connect battery.powerOut to oscillator.powerIn;
        connection powerToFreqCircuit connect battery.powerOut to frequencyCircuit.powerIn;
        connection powerToMicroprocessor connect battery.powerOut to microprocessor.powerIn;
        connection powerToDisplay connect battery.powerOut to display.powerIn;

        connection signalToFreqCircuit connect oscillator.signalOut to frequencyCircuit.signalIn;
        connection freqDataToProcessor connect frequencyCircuit.dataOut to microprocessor.dataIn;
        connection tempDataToDisplay connect microprocessor.tempOut to display.dataIn;

        // System-level state machine
        state thermometherOperation {
            attribute mode : String;

            state off {
                entry {
                    mode = "off";
                }
                do {
                    // All components in low-power standby
                }
                exit;
            }

            state operational {
                entry {
                    mode = "operational";
                }
                do {
                    // Continuous measurement cycle
                    oscillator.oscillatorBehavior;
                    frequencyCircuit.measurementBehavior;
                    microprocessor.processingBehavior;
                    display.displayBehavior;
                }
                exit;
            }

            state lowPower {
                entry {
                    mode = "low-power";
                }
                do {
                    // Reduced update rate, display backlight off
                    display.backlightEnabled = false;
                    microprocessor.updateInterval = 5.0 [s];
                }
                exit;
            }

            transition off_to_operational
                from off to operational
                when powerButtonPressed;

            transition operational_to_lowPower
                from operational to lowPower
                when batteryLevelLow;

            transition lowPower_to_operational
                from lowPower to operational
                when powerButtonPressed;

            transition operational_to_off
                from operational to off
                when powerButtonPressed;

            transition lowPower_to_off
                from lowPower to off
                when powerButtonPressed;
        }

        // System behavior action
        action def systemOperationCycle {
            in ambientTemperature : TemperatureValue;
            
            perform {
                oscillator.currentTemperature = ambientTemperature;
                oscillator.generateSignal(ambientTemperature, oscillator.signal);
                frequencyCircuit.measureFrequency(oscillator.signal, frequencyCircuit.frequencyData);
                microprocessor.convertFrequencyToTemperature(frequencyCircuit.frequencyData, microprocessor.calibration, microprocessor.temperatureData);
                display.updateDisplay(microprocessor.temperatureData);
            }
        }
    }

    // ---- Requirements ----

    package Requirements {

        requirement def TemperatureAccuracyRequirement {
            attribute requiredAccuracy : AccuracyValue = 0.05 [degC];
            attribute operatingRangeMin : TemperatureValue = -40.0 [degC];
            attribute operatingRangeMax : TemperatureValue = 85.0 [degC];
            
            doc /* The thermometer shall measure ambient temperature with an accuracy of 
                  ±0.05°C over the operating range of -40°C to +85°C. */
            
            constraint { systemAccuracy <= requiredAccuracy }
        }

        requirement def ResponseTimeRequirement {
            attribute maxResponseTime : TimeValue = 2.0 [s];
            
            doc /* The thermometer shall update the displayed temperature reading within 
                  2 seconds of a change in ambient temperature. */
            
            constraint { responseTime <= maxResponseTime }
        }

        requirement def PowerConsumptionRequirement {
            attribute maxPowerConsumption : PowerValue = 5.0e-3 [W];
            attribute minBatteryLife : TimeValue = 43200.0 [s];
            
            doc /* The thermometer shall consume no more than 5 mW in operational mode 
                  and shall operate for at least 12 hours on a single battery charge. */
            
            constraint { totalPowerConsumption <= maxPowerConsumption }
        }

        requirement def LowPowerModeRequirement {
            attribute lowPowerConsumption : PowerValue = 1.0e-3 [W];
            attribute lowPowerUpdateInterval : TimeValue = 5.0 [s];
            
            doc /* In low-power mode, the thermometer shall reduce power consumption to 
                  below 1 mW and update the display every 5 seconds. */
        }

        requirement def DisplayRequirement {
            attribute displayResolution : Real = 0.01;
            attribute minDisplayDigits : Integer = 4;
            
            doc /* The LCD display shall show temperature readings with a resolution of 
                  0.01°C and at least 4 significant digits. */
        }

        requirement def OscillatorStabilityRequirement {
            attribute frequencyStability : Real = 1.0e-6;
            attribute nominalFrequency : FrequencyValue = 28.0e6 [Hz];
            
            doc /* The quartz crystal oscillator shall have a frequency stability of 
                  at least ±1 ppm at the nominal frequency of 28 MHz. */
        }

        requirement def FrequencyMeasurementRequirement {
            attribute measurementResolution : FrequencyValue = 0.1 [Hz];
            attribute gateTime : TimeValue = 0.1 [s];
            
            doc /* The frequency measurement circuit shall measure the oscillator frequency 
                  with a resolution of 0.1 Hz using a gate time of 100 ms. */
        }

        requirement def CalibrationRequirement {
            attribute maxCalibrationError : AccuracyValue = 0.02 [degC];
            
            doc /* The microprocessor shall apply calibration coefficients to convert 
                  frequency to temperature with a maximum calibration error of 0.02°C. */
        }

        requirement def OperationalModesRequirement {
            doc /* The thermometer shall support three operational modes: off, operational, 
                  and low-power, with transitions triggered by power button presses and 
                  battery level monitoring. */
        }

        requirement def BatteryLifeRequirement {
            attribute minBatteryLife : TimeValue = 43200.0 [s];
            attribute nominalVoltage : VoltageValue = 3.3 [V];
            
            doc /* The battery power source shall provide at least 3.3V and sustain 
                  operation for a minimum of 12 hours in operational mode. */
        }

        requirement temperatureAccuracyReq : TemperatureAccuracyRequirement {
            subject system : DigitalQuartzThermometerSystem;
        }

        requirement responseTimeReq : ResponseTimeRequirement {
            subject system : DigitalQuartzThermometerSystem;
        }

        requirement powerConsumptionReq : PowerConsumptionRequirement {
            subject system : DigitalQuartzThermometerSystem;
        }

        requirement lowPowerModeReq : LowPowerModeRequirement {
            subject system : DigitalQuartzThermometerSystem;
        }

        requirement displayReq : DisplayRequirement {
            subject display : LCDDisplay;
        }

        requirement oscillatorStabilityReq : OscillatorStabilityRequirement {
            subject oscillator : QuartzCrystalOscillator;
        }

        requirement frequencyMeasurementReq : FrequencyMeasurementRequirement {
            subject frequencyCircuit : FrequencyMeasurementCircuit;
        }

        requirement calibrationReq : CalibrationRequirement {
            subject microprocessor : MicroprocessorUnit;
        }

        requirement operationalModesReq : OperationalModesRequirement {
            subject system : DigitalQuartzThermometerSystem;
        }

        requirement batteryLifeReq : BatteryLifeRequirement {
            subject battery : BatteryPowerSource;
        }
    }

    // ---- Verification ----

    package Verification {

        verification def verifyTemperatureAccuracy {
            subject system : DigitalQuartzThermometerSystem;
            objective {
                doc /* Verify that the system meets the temperature accuracy requirement 
                      across the operating range. */
            }
            method {
                perform system.systemOperationCycle(0.0 [degC]);
                perform system.systemOperationCycle(25.0 [degC]);
                perform system.systemOperationCycle(85.0 [degC]);
            }
        }

        verification def verifyResponseTime {
            subject system : DigitalQuartzThermometerSystem;
            objective {
                doc /* Verify that the system updates the display within the required 
                      response time after a temperature change. */
            }
        }

        verification def verifyPowerConsumption {
            subject system : DigitalQuartzThermometerSystem;
            objective {
                doc /* Verify that the total power consumption does not exceed the 
                      maximum allowed in operational mode. */
            }
        }

        verification def verifyLowPowerMode {
            subject system : DigitalQuartzThermometerSystem;
            objective {
                doc /* Verify that low-power mode reduces consumption and adjusts 
                      the update interval appropriately. */
            }
        }

        verification verifyAccuracy : verifyTemperatureAccuracy {
            subject system : DigitalQuartzThermometerSystem;
        }

        verification verifyResponse : verifyResponseTime {
            subject system : DigitalQuartzThermometerSystem;
        }

        verification verifyPower : verifyPowerConsumption {
            subject system : DigitalQuartzThermometerSystem;
        }

        verification verifyLowPower : verifyLowPowerMode {
            subject system : DigitalQuartzThermometerSystem;
        }
    }
}
