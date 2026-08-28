package PlanarHallSensingUnit {
    import ScalarValues::*;

    // ==================== Units ====================
    unit tesla;
    unit mT = 1e-3 [tesla];
    unit uT = 1e-6 [tesla];
    unit volt;
    unit mV = 1e-3 [volt];
    unit uV = 1e-6 [volt];
    unit ampere;
    unit mA = 1e-3 [ampere];
    unit uA = 1e-6 [ampere];
    unit degC;
    unit hertz;

    // ==================== Value Types ====================
    value type MagneticFluxDensityValue :> Real { unit tesla; }
    value type VoltageValue :> Real { unit volt; }
    value type CurrentValue :> Real { unit ampere; }
    value type TemperatureValue :> Real { unit degC; }
    value type FrequencyValue :> Real { unit hertz; }
    value type DimensionlessValue :> Real { }
    value type DigitalCodeValue :> Integer { }

    // ==================== Item Definitions ====================
    item def PowerInput {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def RegulatedPower {
        attribute voltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
    }

    item def BiasCurrentItem {
        attribute magnitude : CurrentValue;
    }

    item def SensorVoltageItem {
        attribute magnitude : VoltageValue;
    }

    item def ConditionedVoltageItem {
        attribute magnitude : VoltageValue;
    }

    item def DigitalSampleItem {
        attribute code : DigitalCodeValue;
    }

    item def MeasurementResult {
        attribute fluxDensity : MagneticFluxDensityValue;
        attribute temperature : TemperatureValue;
        attribute status : String;
    }

    item def CalibrationCoefficients {
        attribute gain : DimensionlessValue;
        attribute offset : MagneticFluxDensityValue;
        attribute tempCoeff : DimensionlessValue;
        attribute referenceTemp : TemperatureValue;
    }

    item def ControlCommand {
        attribute commandType : String;
    }

    // ==================== Port Definitions ====================
    port def PowerInputPort {
        in power : PowerInput;
    }

    port def RegulatedPowerOutPort {
        out power : RegulatedPower;
    }

    port def RegulatedPowerInPort {
        in power : RegulatedPower;
    }

    port def BiasCurrentOutPort {
        out biasCurrent : BiasCurrentItem;
    }

    port def BiasCurrentInPort {
        in biasCurrent : BiasCurrentItem;
    }

    port def SensorVoltageOutPort {
        out sensorVoltage : SensorVoltageItem;
    }

    port def SensorVoltageInPort {
        in sensorVoltage : SensorVoltageItem;
    }

    port def ConditionedVoltageOutPort {
        out conditionedVoltage : ConditionedVoltageItem;
    }

    port def ConditionedVoltageInPort {
        in conditionedVoltage : ConditionedVoltageItem;
    }

    port def DigitalDataOutPort {
        out digitalData : DigitalSampleItem;
    }

    port def DigitalDataInPort {
        in digitalData : DigitalSampleItem;
    }

    port def MagneticFieldInputPort {
        in magneticFluxDensity : MagneticFluxDensityValue;
    }

    port def TemperatureInputPort {
        in temperature : TemperatureValue;
    }

    port def CommandInputPort {
        in command : ControlCommand;
    }

    port def MeasurementOutputPort {
        out measurement : MeasurementResult;
    }

    // ==================== Requirements ====================
    requirement def PlanarHallSensingUnitRequirements {
        doc /* Top-level requirements for the Planar Hall Sensing Unit. */

        attribute minMeasurableField : MagneticFluxDensityValue = 1e-6 [tesla];
        attribute maxMeasurableField : MagneticFluxDensityValue = 10e-3 [tesla];
        attribute biasCurrentNominal : CurrentValue = 1e-3 [ampere];
        attribute biasCurrentAccuracy : DimensionlessValue = 1e-3;
        attribute amplifierGain : DimensionlessValue = 100;
        attribute filterCutoff : FrequencyValue = 1000 [hertz];
        attribute adcResolution : Integer = 16;
        attribute adcSampleRate : FrequencyValue = 1000 [hertz];
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 85 [degC];
        attribute inputVoltageMin : VoltageValue = 4.5 [volt];
        attribute inputVoltageMax : VoltageValue = 5.5 [volt];
        attribute regulatedVoltage : VoltageValue = 3.3 [volt];

        requirement MeasurementRange {
            doc /* The unit shall measure magnetic flux density from 1 µT to 10 mT. */
        }

        requirement BiasStability {
            doc /* The bias circuit shall provide stable current with 0.1 percent accuracy. */
        }

        requirement SignalConditioning {
            doc /* The signal conditioner shall amplify and filter the sensor voltage. */
        }

        requirement ADConversion {
            doc /* The ADC shall have at least 16-bit resolution. */
        }

        requirement TemperatureCompensation {
            doc /* The signal processor shall compensate for temperature effects over the operating range. */
        }

        requirement StateMachineSupport {
            doc /* The unit shall support initialization, idle, active, calibration, and fault states. */
        }

        requirement PowerRegulation {
            doc /* The power supply shall regulate external input to stable internal supply. */
        }
    }

    // ==================== State Machine Definition ====================
    state def OperatingStates {
        doc /* Operating state machine for the Planar Hall Sensing Unit. */

        entry;

        transition entry to initialization;

        state initialization {
            doc /* Power-on initialization and self-test. */
            entry action {
                // Perform power-on self-test, load calibration coefficients,
                // verify all subsystems are operational.
            }
            transition to idle {
                guard selfTestPassed;
            }
            transition to fault {
                guard !selfTestPassed;
            }
        }

        state idle {
            doc /* Low-power standby mode. */
            entry action {
                // Disable active measurement, reduce power consumption,
                // wait for commands.
            }
            transition to active {
                guard measureCommandReceived;
            }
            transition to calibration {
                guard calibrationCommandReceived;
            }
        }

        state active {
            doc /* Active measurement state. */
            entry action {
                // Enable bias circuit, start continuous measurement,
                // begin signal processing chain.
            }
            do action {
                // Continuously sample, condition, convert, and process
                // magnetic field measurements.
            }
            transition to idle {
                guard stopCommandReceived;
            }
            transition to fault {
                guard errorDetected;
            }
        }

        state calibration {
            doc /* Calibration mode for applying known reference fields. */
            entry action {
                // Apply known reference magnetic field,
                // measure response, compute calibration coefficients.
            }
            transition to idle {
                guard calibrationComplete;
            }
            transition to fault {
                guard errorDetected;
            }
        }

        state fault {
            doc /* Fault handling state. */
            entry action {
                // Log fault information, disable outputs,
                // set error status.
            }
            transition to idle {
                guard faultCleared;
            }
        }
    }

    // ==================== Component Part Definitions ====================

    part def PowerSupply {
        doc /* Regulates external voltage to provide stable internal power rails. */

        attribute inputVoltageMin : VoltageValue = 4.5 [volt];
        attribute inputVoltageMax : VoltageValue = 5.5 [volt];
        attribute regulatedVoltage3V3 : VoltageValue = 3.3 [volt];
        attribute regulatedVoltage5V : VoltageValue = 5.0 [volt];
        attribute maxOutputCurrent : CurrentValue = 0.5 [ampere];
        attribute efficiency : DimensionlessValue = 0.9;

        port externalPowerIn : PowerInputPort;
        port regulated3V3Out : RegulatedPowerOutPort;
        port regulated5VOut : RegulatedPowerOutPort;

        action regulate {
            doc /* Converts external input voltage to regulated 3.3V and 5V outputs. */
        }

        action overcurrentProtection {
            doc /* Protects against overcurrent conditions. */
        }

        action thermalShutdown {
            doc /* Protects against thermal overload. */
        }
    }

    part def BiasCircuit {
        doc /* Provides stable, precise bias current for the sensing element. */

        attribute nominalCurrent : CurrentValue = 1e-3 [ampere];
        attribute accuracy : DimensionlessValue = 1e-3;
        attribute temperatureCoefficient : DimensionlessValue = 50e-6;
        attribute settlingTime : Real = 0.001;

        port powerIn : RegulatedPowerInPort;
        port biasCurrentOut : BiasCurrentOutPort;

        action generateBias {
            doc /* Generates a stable, precise bias current from regulated power. */
        }

        action stabilize {
            doc /* Ensures the bias current has settled to its nominal value. */
        }
    }

    part def PlanarHallElement {
        doc /* Core planar Hall sensor composed of thin ferromagnetic and conductive layers. */

        attribute ferromagneticMaterial : String = "Nickel-Iron";
        attribute layerThickness : Real = 50e-9;
        attribute sensitivity : DimensionlessValue = 0.05;
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 125 [degC];
        attribute biasResistance : Real = 1000;

        port biasCurrentIn : BiasCurrentInPort;
        port magneticFieldIn : MagneticFieldInputPort;
        port sensorVoltageOut : SensorVoltageOutPort;

        action generateHallVoltage {
            doc /* Generates a Hall voltage proportional to magnetic flux density and bias current. */
        }
    }

    part def SignalConditioner {
        doc /* Amplifies and filters the weak analog voltage from the sensor. */

        attribute amplifierGain : DimensionlessValue = 100;
        attribute filterCutoffFrequency : FrequencyValue = 1000 [hertz];
        attribute commonModeRejection : DimensionlessValue = 80;
        attribute inputImpedance : Real = 10000;

        port powerIn : RegulatedPowerInPort;
        port sensorVoltageIn : SensorVoltageInPort;
        port conditionedVoltageOut : ConditionedVoltageOutPort;

        action amplify {
            doc /* Differential amplifier boosts the sensor signal by the configured gain. */
        }

        action lowPassFilter {
            doc /* Removes high-frequency noise from the amplified signal. */
        }

        action conditionSignal {
            doc /* Combines amplification and filtering into a single processing step. */
        }
    }

    part def AnalogToDigitalConverter {
        doc /* High-resolution ADC converting analog signal to digital values. */

        attribute resolution : Integer = 16;
        attribute samplingRate : FrequencyValue = 1000 [hertz];
        attribute referenceVoltage : VoltageValue = 3.3 [volt];
        attribute inputRange : VoltageValue = 3.3 [volt];

        port powerIn : RegulatedPowerInPort;
        port analogInput : ConditionedVoltageInPort;
        port digitalOutput : DigitalDataOutPort;

        action convert {
            doc /* Converts analog voltage to a digital code with the specified resolution. */
        }

        action sample {
            doc /* Samples the analog input at the specified sampling rate. */
        }
    }

    part def SignalProcessor {
        doc /* Processes digital data with calibration and temperature compensation. */

        attribute calibration : CalibrationCoefficients;
        attribute processingDelay : Real = 0.001;
        attribute outputRate : FrequencyValue = 1000 [hertz];

        port powerIn : RegulatedPowerInPort;
        port digitalDataIn : DigitalDataInPort;
        port temperatureIn : TemperatureInputPort;
        port commandIn : CommandInputPort;
        port measurementOut : MeasurementOutputPort;

        action applyCalibration {
            doc /* Applies stored calibration coefficients to raw digital data. */
        }

        action temperatureCompensation {
            doc /* Compensates the measurement for temperature effects. */
        }

        action produceMeasurement {
            doc /* Produces the final measurement result with status flag. */
        }

        action processSample {
            doc /* Main processing action that chains calibration, compensation, and output. */
        }
    }

    // ==================== Top-Level Part Definition ====================

    part def PlanarHallSensingUnit {
        doc /* Complete self-contained Planar Hall Sensing Unit module for high-precision magnetic field measurement. */

        satisfy PlanarHallSensingUnitRequirements;

        // External interface ports
        port externalPowerIn : PowerInputPort;
        port magneticFieldIn : MagneticFieldInputPort;
        port temperatureIn : TemperatureInputPort;
        port commandIn : CommandInputPort;
        port measurementOut : MeasurementOutputPort;

        // State machine guard condition attributes
        attribute selfTestPassed : Boolean;
        attribute measureCommandReceived : Boolean;
        attribute stopCommandReceived : Boolean;
        attribute calibrationCommandReceived : Boolean;
        attribute calibrationComplete : Boolean;
        attribute errorDetected : Boolean;
        attribute faultCleared : Boolean;

        // Internal components
        part powerSupply : PowerSupply {
            attribute maxOutputCurrent : CurrentValue = 1.0 [ampere];
        }

        part biasCircuit : BiasCircuit {
            attribute nominalCurrent : CurrentValue = 1e-3 [ampere];
            attribute accuracy : DimensionlessValue = 1e-3;
        }

        part hallElement : PlanarHallElement {
            attribute ferromagneticMaterial : String = "Nickel-Iron";
            attribute sensitivity : DimensionlessValue = 0.05;
        }

        part signalConditioner : SignalConditioner {
            attribute amplifierGain : DimensionlessValue = 100;
            attribute filterCutoffFrequency : FrequencyValue = 1000 [hertz];
        }

        part adc : AnalogToDigitalConverter {
            attribute resolution : Integer = 16;
            attribute samplingRate : FrequencyValue = 1000 [hertz];
        }

        part signalProcessor : SignalProcessor {
            attribute calibration : CalibrationCoefficients {
                attribute gain : DimensionlessValue = 1.0e-5;
                attribute offset : MagneticFluxDensityValue = 0.0 [tesla];
                attribute tempCoeff : DimensionlessValue = -1e-3;
                attribute referenceTemp : TemperatureValue = 25 [degC];
            }
        }

        // Power supply connections
        connect externalPowerIn to powerSupply.externalPowerIn;
        connect powerSupply.regulated3V3Out to biasCircuit.powerIn;
        connect powerSupply.regulated3V3Out to signalConditioner.powerIn;
        connect powerSupply.regulated3V3Out to adc.powerIn;
        connect powerSupply.regulated3V3Out to signalProcessor.powerIn;

        // Signal processing chain connections
        connect biasCircuit.biasCurrentOut to hallElement.biasCurrentIn;
        connect magneticFieldIn to hallElement.magneticFieldIn;
        connect hallElement.sensorVoltageOut to signalConditioner.sensorVoltageIn;
        connect signalConditioner.conditionedVoltageOut to adc.analogInput;
        connect adc.digitalOutput to signalProcessor.digitalDataIn;
        connect temperatureIn to signalProcessor.temperatureIn;
        connect commandIn to signalProcessor.commandIn;
        connect signalProcessor.measurementOut to measurementOut;

        // State machine behavior
        state machine operatingBehavior : OperatingStates;
    }
}
