package DigitalInclinometer {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Angle :> Real { unit 'deg'; }
    value def Length :> Real { unit 'mm'; }
    value def Dimensionless :> Real { unit '1'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Confidence :> Real { unit '1'; min 0.0; max 1.0; }

    attribute def IPRating :> String;
    attribute def Material :> String;

    // ---------- Item Types ----------
    item def RawOpticalSignal;
    item def ConditionedAnalogSignal;
    item def DigitalPosition;
    item def CalibrationCommand {
        attribute referenceOffset : Angle;
        attribute gainFactor : Dimensionless;
    }
    item def MeasurementResult {
        attribute angle : Angle;
        attribute isLevel : Boolean;
        attribute confidence : Confidence;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ---------- Port Definitions ----------
    port def PowerPort {
        in item power : ElectricalPower;
    }
    port def CalibrationPort {
        in item command : CalibrationCommand;
    }
    port def MeasurementOutputPort {
        out item result : MeasurementResult;
    }
    port def RawSignalPort {
        out item signal : RawOpticalSignal;
    }
    port def AnalogSignalPort {
        out item signal : ConditionedAnalogSignal;
    }
    port def DigitalDataPort {
        out item data : DigitalPosition;
    }

    // ---------- Requirements ----------
    requirement def InclinometerRequirements {
        requirement MeasureAngle {
            doc "The system shall measure inclination angle with high precision."
            attribute resolution : Angle = 0.001 [deg];
            attribute accuracy : Angle = 0.01 [deg];
        }
        requirement LevelTolerance {
            doc "The system shall evaluate level status within a defined tolerance."
            attribute tolerance : Angle = 0.1 [deg];
        }
        requirement ConfidenceScoring {
            doc "The system shall generate a confidence score for each reading."
            attribute minConfidence : Confidence = 0.5;
        }
        requirement HousingProtection {
            doc "The housing shall be rugged and sealed for harsh environments."
            attribute material : Material = "anodized aluminum";
            attribute ipRating : IPRating = "IP68";
        }
        requirement PowerRegulation {
            doc "The power supply shall regulate incoming voltage to the required internal level."
            attribute inputVoltage : Voltage = 24.0 [V];
            attribute outputVoltage : Voltage = 3.3 [V];
        }
    }

    // ---------- Parts ----------
    part def BubbleVial {
        attribute length : Length = 50.0 [mm];
        attribute innerDiameter : Length = 8.0 [mm];
        attribute fluidType : String = "isopropanol";
        attribute bubbleDiameter : Length = 5.0 [mm];
        item bubblePosition : Length;
    }

    part def OpticalSensor {
        attribute resolution : Length = 0.001 [mm];
        attribute samplingRate : Frequency = 1000.0 [Hz];
        port out rawSignal : RawSignalPort;
        action def acquire {
            out signal : RawOpticalSignal;
        }
        perform acquire;
    }

    part def SignalConditioner {
        attribute gain : Dimensionless = 100.0;
        attribute cutoffFrequency : Frequency = 500.0 [Hz];
        port in rawInput : RawSignalPort;
        port out analogOutput : AnalogSignalPort;
        action def condition {
            in raw : RawOpticalSignal;
            out conditioned : ConditionedAnalogSignal;
        }
        perform condition;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : Voltage = 3.3 [V];
        port in analogInput : AnalogSignalPort;
        port out digitalOutput : DigitalDataPort;
        action def convert {
            in analog : ConditionedAnalogSignal;
            out digital : DigitalPosition;
        }
        perform convert;
    }

    part def ProcessingUnit {
        attribute vialLength : Length = 50.0 [mm];
        attribute referenceOffset : Angle = 0.0 [deg];
        attribute gainFactor : Dimensionless = 1.0;
        attribute levelTolerance : Angle = 0.1 [deg];
        port in digitalInput : DigitalDataPort;
        port in calibrationInput : CalibrationPort;
        port out measurementOutput : MeasurementOutputPort;

        action def calculateAngle {
            in position : DigitalPosition;
            in vialLength : Length;
            in referenceOffset : Angle;
            in gainFactor : Dimensionless;
            out angle : Angle;
        }
        action def evaluateLevel {
            in angle : Angle;
            in tolerance : Angle;
            out isLevel : Boolean;
        }
        action def computeConfidence {
            in signalQuality : Dimensionless;
            out confidence : Confidence;
        }
        action def assembleResult {
            in angle : Angle;
            in isLevel : Boolean;
            in confidence : Confidence;
            out result : MeasurementResult;
        }
        perform calculateAngle;
        perform evaluateLevel;
        perform computeConfidence;
        perform assembleResult;
    }

    part def PowerSupply {
        attribute inputVoltage : Voltage = 24.0 [V];
        attribute outputVoltage : Voltage = 3.3 [V];
        attribute efficiency : Dimensionless = 0.85;
        port in powerInput : PowerPort;
        port out regulatedOutput : PowerPort;
        action def regulate {
            in input : ElectricalPower;
            out output : ElectricalPower;
        }
        perform regulate;
    }

    part def HousingEnclosure {
        attribute material : Material = "anodized aluminum";
        attribute ipRating : IPRating = "IP68";
        attribute wallThickness : Length = 2.0 [mm];
    }

    part def BubbleSensorAssembly {
        part bubbleVial : BubbleVial;
        part opticalSensor : OpticalSensor;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processingUnit : ProcessingUnit;
        part powerSupply : PowerSupply;
        part housing : HousingEnclosure;

        port in externalPower : PowerPort;
        port in calibrationCommand : CalibrationPort;
        port out measurementData : MeasurementOutputPort;

        // Internal connections
        connection powerIn : ElectricalPower connect externalPower to powerSupply.powerInput;
        connection regulatedPower : ElectricalPower connect powerSupply.regulatedOutput to processingUnit.powerInput;
        connection rawSignalFlow : RawOpticalSignal connect opticalSensor.rawSignal to signalConditioner.rawInput;
        connection analogSignalFlow : ConditionedAnalogSignal connect signalConditioner.analogOutput to adc.analogInput;
        connection digitalDataFlow : DigitalPosition connect adc.digitalOutput to processingUnit.digitalInput;
        connection calibrationFlow : CalibrationCommand connect calibrationCommand to processingUnit.calibrationInput;
        connection resultFlow : MeasurementResult connect processingUnit.measurementOutput to measurementData;

        // ---------- State Machine ----------
        state def InclinometerLifecycle {
            entry action { /* initialize hardware */ }
            exit action { /* power down safely */ }

            state Off {
                entry action { /* no power applied */ }
                transition to PoweringOn
                    when externalPower.power.voltage > 0.0 [V];
            }
            state PoweringOn {
                entry action { powerSupply.regulate(); }
                transition to Calibrating
                    when powerSupply.outputVoltage == 3.3 [V];
            }
            state Calibrating {
                entry action {
                    processingUnit.referenceOffset := calibrationCommand.command.referenceOffset;
                    processingUnit.gainFactor := calibrationCommand.command.gainFactor;
                }
                transition to Ready
                    when processingUnit.referenceOffset == calibrationCommand.command.referenceOffset;
            }
            state Ready {
                entry action { /* idle, awaiting measurement trigger */ }
                transition to Measuring
                    when true; // triggered by external request
            }
            state Measuring {
                entry action {
                    opticalSensor.acquire();
                    signalConditioner.condition();
                    adc.convert();
                }
                transition to Processing
                    when adc.digitalOutput.data is delivered;
            }
            state Processing {
                entry action {
                    processingUnit.calculateAngle();
                    processingUnit.evaluateLevel();
                    processingUnit.computeConfidence();
                    processingUnit.assembleResult();
                }
                transition to Transmitting
                    when processingUnit.measurementOutput.result is produced;
            }
            state Transmitting {
                entry action {
                    measurementData.result := processingUnit.measurementOutput.result;
                }
                transition to Ready
                    when measurementData.result is delivered;
            }
            transition from Calibrating to Off
                when externalPower.power.voltage == 0.0 [V];
            transition from Ready to Off
                when externalPower.power.voltage == 0.0 [V];
            transition from Measuring to Off
                when externalPower.power.voltage == 0.0 [V];
            transition from Processing to Off
                when externalPower.power.voltage == 0.0 [V];
            transition from Transmitting to Off
                when externalPower.power.voltage == 0.0 [V];
        }

        perform InclinometerLifecycle;

        satisfy InclinometerRequirements {
            satisfy MeasureAngle by processingUnit.calculateAngle;
            satisfy LevelTolerance by processingUnit.evaluateLevel;
            satisfy ConfidenceScoring by processingUnit.computeConfidence;
            satisfy HousingProtection by housing;
            satisfy PowerRegulation by powerSupply;
        }
    }

    part def DigitalInclinometerSystem :> BubbleSensorAssembly {
        attribute deviceName : String = "High-Precision Digital Inclinometer";
        attribute manufacturer : String = "TiltSense Instruments";
        attribute serialNumber : String = "TS-DI-0001";
    }

    part digitalInclinometer : DigitalInclinometerSystem;

}
