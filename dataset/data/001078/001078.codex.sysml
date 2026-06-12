package HallEffectSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MagneticFluxDensity :> ISQ::magneticFluxDensity {
        unit = SI::tesla;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Ratio {
        attribute value : Real;
    }

    attribute def DigitalCount {
        attribute value : Integer;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute directionX : Real;
        attribute directionY : Real;
        attribute directionZ : Real;
    }

    item def AnalogVoltageSignal {
        attribute voltage : ElectricPotential;
        attribute sourceImpedance : Real;
        attribute bandwidth : Frequency;
    }

    item def DigitalMeasurement {
        attribute rawCount : DigitalCount;
        attribute measuredFluxDensity : MagneticFluxDensity;
        attribute uncertainty : MagneticFluxDensity;
        attribute sampleTime : Real;
        attribute valid : Boolean;
    }

    item def SupplyPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def ConfigurationCommand {
        attribute sampleRate : Frequency;
        attribute gainSetting : Integer;
        attribute offsetCompensationEnabled : Boolean;
        attribute diagnosticRequested : Boolean;
    }

    item def StatusMessage {
        attribute powered : Boolean;
        attribute calibrated : Boolean;
        attribute sensorFault : Boolean;
        attribute saturationFault : Boolean;
        attribute temperatureFault : Boolean;
    }

    port def MagneticFieldInputPort {
        in item field : MagneticField;
    }

    port def AnalogSignalPort {
        out item signal : AnalogVoltageSignal;
    }

    port def DigitalMeasurementPort {
        out item measurement : DigitalMeasurement;
    }

    port def PowerPort {
        in item power : SupplyPower;
    }

    port def CommandPort {
        in item command : ConfigurationCommand;
    }

    port def StatusPort {
        out item status : StatusMessage;
    }

    part def HallElement {
        port magneticInput : MagneticFieldInputPort;
        port hallVoltageOutput : AnalogSignalPort;

        attribute biasCurrent : ElectricCurrent = 0.010 [SI::ampere];
        attribute nominalSensitivity : Real = 0.185;
        attribute offsetVoltage : ElectricPotential = 0.002 [SI::volt];
        attribute operatingTemperature : Temperature;
        attribute maximumFluxDensity : MagneticFluxDensity = 0.150 [SI::tesla];

        action convertFieldToHallVoltage {
            in item sensedField : MagneticField;
            out item hallSignal : AnalogVoltageSignal;

            attribute effectiveFluxDensity : MagneticFluxDensity;
            attribute calculatedVoltage : ElectricPotential;

            first start;
            then computeVoltage;
            then emitSignal;
            then done;

            action computeVoltage {
                effectiveFluxDensity = sensedField.fluxDensity;
                calculatedVoltage = offsetVoltage + effectiveFluxDensity * nominalSensitivity;
            }

            action emitSignal {
                hallSignal.voltage = calculatedVoltage;
                hallSignal.sourceImpedance = 1200.0;
                hallSignal.bandwidth = 25000 [SI::hertz];
            }
        }
    }

    part def SignalConditioner {
        port rawInput : AnalogSignalPort;
        port conditionedOutput : AnalogSignalPort;

        attribute gain : Real = 4.0;
        attribute lowPassCutoff : Frequency = 1000 [SI::hertz];
        attribute outputOffset : ElectricPotential = 1.650 [SI::volt];
        attribute saturationLow : ElectricPotential = 0.050 [SI::volt];
        attribute saturationHigh : ElectricPotential = 3.250 [SI::volt];

        action conditionSignal {
            in item rawSignal : AnalogVoltageSignal;
            out item conditionedSignal : AnalogVoltageSignal;

            attribute amplifiedVoltage : ElectricPotential;

            first start;
            then amplifyAndOffset;
            then clampOutput;
            then outputSignal;
            then done;

            action amplifyAndOffset {
                amplifiedVoltage = outputOffset + gain * rawSignal.voltage;
            }

            action clampOutput {
                if amplifiedVoltage < saturationLow {
                    amplifiedVoltage = saturationLow;
                }
                if amplifiedVoltage > saturationHigh {
                    amplifiedVoltage = saturationHigh;
                }
            }

            action outputSignal {
                conditionedSignal.voltage = amplifiedVoltage;
                conditionedSignal.sourceImpedance = 50.0;
                conditionedSignal.bandwidth = lowPassCutoff;
            }
        }
    }

    part def AnalogToDigitalConverter {
        port analogInput : AnalogSignalPort;
        port digitalOutput : DigitalMeasurementPort;

        attribute referenceVoltage : ElectricPotential = 3.300 [SI::volt];
        attribute resolutionBits : Integer = 12;
        attribute conversionRate : Frequency = 2000 [SI::hertz];
        attribute quantizationStep : ElectricPotential = 0.00080586 [SI::volt];

        action sampleAndConvert {
            in item analogSignal : AnalogVoltageSignal;
            out item digitalMeasurement : DigitalMeasurement;

            attribute normalizedVoltage : Real;
            attribute convertedCount : Integer;

            first start;
            then sample;
            then quantize;
            then publish;
            then done;

            action sample {
                normalizedVoltage = analogSignal.voltage / referenceVoltage;
            }

            action quantize {
                convertedCount = round(normalizedVoltage * 4095.0);
            }

            action publish {
                digitalMeasurement.rawCount.value = convertedCount;
                digitalMeasurement.valid = true;
                digitalMeasurement.sampleTime = 0.0005;
            }
        }
    }

    part def CalibrationProcessor {
        port digitalInput : DigitalMeasurementPort;
        port calibratedOutput : DigitalMeasurementPort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        attribute zeroFieldOffsetCount : Integer = 2048;
        attribute countsPerTesla : Real = 22800.0;
        attribute temperatureCoefficient : Real = 0.0008;
        attribute calibrated : Boolean = false;
        attribute sensorFaultDetected : Boolean = false;
        attribute saturationDetected : Boolean = false;
        attribute temperatureFaultDetected : Boolean = false;
        attribute ambientTemperature : Temperature = 298.15 [SI::kelvin];

        action calibrateMeasurement {
            in item rawMeasurement : DigitalMeasurement;
            out item calibratedMeasurement : DigitalMeasurement;

            attribute correctedCount : Real;
            attribute compensatedScale : Real;
            attribute flux : MagneticFluxDensity;

            first start;
            then removeOffset;
            then compensateSensitivity;
            then computeFluxDensity;
            then validateRange;
            then emitCalibratedMeasurement;
            then done;

            action removeOffset {
                correctedCount = rawMeasurement.rawCount.value - zeroFieldOffsetCount;
            }

            action compensateSensitivity {
                compensatedScale = countsPerTesla * (1.0 - temperatureCoefficient * (ambientTemperature - 298.15 [SI::kelvin]));
            }

            action computeFluxDensity {
                flux = correctedCount / compensatedScale;
            }

            action validateRange {
                saturationDetected = rawMeasurement.rawCount.value <= 5 or rawMeasurement.rawCount.value >= 4090;
                sensorFaultDetected = rawMeasurement.valid == false;
                temperatureFaultDetected = ambientTemperature < 233.15 [SI::kelvin] or ambientTemperature > 398.15 [SI::kelvin];
            }

            action emitCalibratedMeasurement {
                calibratedMeasurement.rawCount = rawMeasurement.rawCount;
                calibratedMeasurement.measuredFluxDensity = flux;
                calibratedMeasurement.uncertainty = 0.0015 [SI::tesla];
                calibratedMeasurement.sampleTime = rawMeasurement.sampleTime;
                calibratedMeasurement.valid = not sensorFaultDetected and not saturationDetected and not temperatureFaultDetected;
            }
        }

        action publishStatus {
            out item status : StatusMessage;

            first start;
            then assignStatus;
            then done;

            action assignStatus {
                status.powered = true;
                status.calibrated = calibrated;
                status.sensorFault = sensorFaultDetected;
                status.saturationFault = saturationDetected;
                status.temperatureFault = temperatureFaultDetected;
            }
        }

        state def CalibrationStateMachine {
            state off;
            state initializing;
            state zeroing;
            state measuring;
            state diagnostic;
            state fault;

            entry action offEntry {
                calibrated = false;
            }

            transition powerApplied first off then initializing;
            transition initializationComplete first initializing then zeroing;
            transition zeroOffsetStored first zeroing then measuring {
                action setCalibrated {
                    calibrated = true;
                }
            }
            transition diagnosticRequested first measuring then diagnostic;
            transition diagnosticComplete first diagnostic then measuring;
            transition faultDetected first measuring then fault guard sensorFaultDetected or saturationDetected or temperatureFaultDetected;
            transition faultCleared first fault then initializing guard not sensorFaultDetected and not saturationDetected and not temperatureFaultDetected;
            transition powerRemoved first initializing then off;
            transition powerRemovedFromMeasuring first measuring then off;
            transition powerRemovedFromFault first fault then off;
        }
    }

    part def RegulatedPowerSupply {
        port supplyInput : PowerPort;
        port regulatedOutput : PowerPort;

        attribute inputVoltageMinimum : ElectricPotential = 4.500 [SI::volt];
        attribute inputVoltageMaximum : ElectricPotential = 5.500 [SI::volt];
        attribute regulatedVoltage : ElectricPotential = 3.300 [SI::volt];
        attribute maximumOutputCurrent : ElectricCurrent = 0.050 [SI::ampere];

        action regulatePower {
            in item inputPower : SupplyPower;
            out item outputPower : SupplyPower;

            first start;
            then verifyInput;
            then regulate;
            then done;

            action verifyInput {
                assert inputPower.voltage >= inputVoltageMinimum;
                assert inputPower.voltage <= inputVoltageMaximum;
            }

            action regulate {
                outputPower.voltage = regulatedVoltage;
                outputPower.current = inputPower.current;
            }
        }
    }

    part def HallEffectSensingUnit {
        port magneticFieldInput : MagneticFieldInputPort;
        port externalPowerInput : PowerPort;
        port commandInput : CommandPort;
        port measurementOutput : DigitalMeasurementPort;
        port statusOutput : StatusPort;

        part supply : RegulatedPowerSupply;
        part hallSensor : HallElement;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : CalibrationProcessor;

        item regulatedPower : SupplyPower;
        item hallVoltage : AnalogVoltageSignal;
        item conditionedVoltage : AnalogVoltageSignal;
        item rawDigitalMeasurement : DigitalMeasurement;
        item calibratedDigitalMeasurement : DigitalMeasurement;
        item unitStatus : StatusMessage;

        connect externalPowerInput to supply.supplyInput;
        connect supply.regulatedOutput to regulatedPower;
        connect magneticFieldInput to hallSensor.magneticInput;
        connect hallSensor.hallVoltageOutput to conditioner.rawInput;
        connect conditioner.conditionedOutput to adc.analogInput;
        connect adc.digitalOutput to processor.digitalInput;
        connect commandInput to processor.commandInput;
        connect processor.calibratedOutput to measurementOutput;
        connect processor.statusOutput to statusOutput;

        perform action senseMagneticField {
            in item field : MagneticField;
            in item inputPower : SupplyPower;
            in item command : ConfigurationCommand;
            out item measurement : DigitalMeasurement;
            out item status : StatusMessage;

            first start;
            then powerRegulation;
            then transduction;
            then signalConditioning;
            then analogDigitalConversion;
            then calibration;
            then statusPublication;
            then done;

            action powerRegulation {
                supply.regulatePower(inputPower, regulatedPower);
            }

            action transduction {
                hallSensor.convertFieldToHallVoltage(field, hallVoltage);
            }

            action signalConditioning {
                conditioner.conditionSignal(hallVoltage, conditionedVoltage);
            }

            action analogDigitalConversion {
                adc.sampleAndConvert(conditionedVoltage, rawDigitalMeasurement);
            }

            action calibration {
                processor.calibrateMeasurement(rawDigitalMeasurement, calibratedDigitalMeasurement);
                measurement = calibratedDigitalMeasurement;
            }

            action statusPublication {
                processor.publishStatus(unitStatus);
                status = unitStatus;
            }
        }
    }

    requirement def MeasureMagneticFieldRequirement {
        subject sensingUnit : HallEffectSensingUnit;

        require constraint {
            sensingUnit.measurementOutput.measurement.measuredFluxDensity >= -0.100 [SI::tesla] and
            sensingUnit.measurementOutput.measurement.measuredFluxDensity <= 0.100 [SI::tesla]
        }

        doc /* The sensing unit shall measure magnetic flux density using a Hall effect sensor over a bidirectional range of -0.100 T to +0.100 T. */
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : HallEffectSensingUnit;

        require constraint {
            sensingUnit.measurementOutput.measurement.uncertainty <= 0.002 [SI::tesla]
        }

        doc /* The sensing unit shall report calibrated magnetic flux density with total uncertainty no greater than 0.002 T under nominal operating conditions. */
    }

    requirement def SampleRateRequirement {
        subject sensingUnit : HallEffectSensingUnit;

        require constraint {
            sensingUnit.adc.conversionRate >= 1000 [SI::hertz]
        }

        doc /* The sensing unit shall sample and convert the Hall effect measurement at no less than 1000 samples per second. */
    }

    requirement def SupplyVoltageRequirement {
        subject sensingUnit : HallEffectSensingUnit;

        require constraint {
            sensingUnit.supply.inputVoltageMinimum == 4.500 [SI::volt] and
            sensingUnit.supply.inputVoltageMaximum == 5.500 [SI::volt]
        }

        doc /* The sensing unit shall operate from a nominal 5 V supply with an allowable range from 4.5 V to 5.5 V. */
    }

    requirement def DiagnosticRequirement {
        subject sensingUnit : HallEffectSensingUnit;

        require constraint {
            sensingUnit.statusOutput.status.sensorFault == true implies
            sensingUnit.measurementOutput.measurement.valid == false
        }

        doc /* The sensing unit shall indicate invalid measurement status whenever a sensor, saturation, or temperature diagnostic fault is detected. */
    }

    satisfy MeasureMagneticFieldRequirement by HallEffectSensingUnit;
    satisfy AccuracyRequirement by HallEffectSensingUnit;
    satisfy SampleRateRequirement by HallEffectSensingUnit;
    satisfy SupplyVoltageRequirement by HallEffectSensingUnit;
    satisfy DiagnosticRequirement by HallEffectSensingUnit;

    part hallEffectSensingUnit : HallEffectSensingUnit {
        attribute expectedNominalFluxDensity : MagneticFluxDensity = 0.025 [SI::tesla];
        attribute nominalInputSupplyVoltage : ElectricPotential = 5.000 [SI::volt];
        attribute nominalCurrentDraw : ElectricCurrent = 0.030 [SI::ampere];
    }
}