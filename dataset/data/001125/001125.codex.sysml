package LoadCellBasedWeighingSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    unit def volt;
    unit def millivolt;
    unit def kilogram;
    unit def newton;
    unit def second;
    unit def degreeCelsius;
    unit def hertz;
    unit def percent;
    unit def bit;

    value type MassValue specializes Real {
        unit = kilogram;
    }

    value type ForceValue specializes Real {
        unit = newton;
    }

    value type VoltageValue specializes Real {
        unit = volt;
    }

    value type TemperatureValue specializes Real {
        unit = degreeCelsius;
    }

    value type SampleRateValue specializes Real {
        unit = hertz;
    }

    value type TimeValue specializes Real {
        unit = second;
    }

    value type PercentValue specializes Real {
        unit = percent;
    }

    value type ResolutionValue specializes Real {
        unit = bit;
    }

    item def MechanicalLoad {
        attribute appliedForce : ForceValue;
        attribute loadDirection : String;
    }

    item def StrainSignal {
        attribute bridgeDifferentialVoltage : VoltageValue;
        attribute excitationVoltage : VoltageValue;
        attribute sensitivity_mV_per_V : Real;
    }

    item def AmplifiedAnalogSignal {
        attribute signalVoltage : VoltageValue;
        attribute commonModeVoltage : VoltageValue;
        attribute gain : Real;
    }

    item def DigitalMeasurement {
        attribute rawAdcCount : Integer;
        attribute adcResolution : ResolutionValue;
        attribute sampleTime : TimeValue;
    }

    item def CalibratedWeight {
        attribute mass : MassValue;
        attribute netForce : ForceValue;
        attribute confidence : PercentValue;
        attribute stable : Boolean;
    }

    item def TemperatureReading {
        attribute temperature : TemperatureValue;
    }

    port def MechanicalLoadPort {
        in item load : MechanicalLoad;
    }

    port def StrainSignalPort {
        out item strainSignal : StrainSignal;
    }

    port def AnalogSignalPort {
        inout item analogSignal : AmplifiedAnalogSignal;
    }

    port def DigitalSignalPort {
        out item digitalMeasurement : DigitalMeasurement;
    }

    port def WeightDataPort {
        out item weight : CalibratedWeight;
    }

    port def TemperaturePort {
        out item temperature : TemperatureReading;
    }

    port def PowerPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrent_mA : Real;
    }

    port def UserCommandPort {
        in attribute tareRequested : Boolean;
        in attribute calibrateRequested : Boolean;
        in attribute diagnosticRequested : Boolean;
    }

    port def StatusPort {
        out attribute ready : Boolean;
        out attribute faulted : Boolean;
        out attribute faultCode : String;
    }

    interface def LoadToStrainInterface {
        end loadInput : MechanicalLoadPort;
        end strainOutput : StrainSignalPort;
    }

    interface def AnalogAcquisitionInterface {
        end analogInput : AnalogSignalPort;
        end digitalOutput : DigitalSignalPort;
    }

    interface def WeightReportingInterface {
        end measurementOutput : WeightDataPort;
        end externalConsumer : WeightDataPort;
    }

    part def LoadCell {
        attribute ratedCapacity : MassValue = 50.0 [kilogram];
        attribute ratedOutput_mV_per_V : Real = 2.0;
        attribute safeOverload : PercentValue = 150.0 [percent];
        attribute combinedError : PercentValue = 0.03 [percent];
        attribute operatingTemperatureMin : TemperatureValue = -10.0 [degreeCelsius];
        attribute operatingTemperatureMax : TemperatureValue = 40.0 [degreeCelsius];

        port mechanicalInput : MechanicalLoadPort;
        port bridgeOutput : StrainSignalPort;
        port excitationPower : PowerPort;

        action def ConvertLoadToStrainSignal {
            in item load : MechanicalLoad;
            in attribute excitationVoltage : VoltageValue;
            out item strainSignal : StrainSignal;

            attribute normalizedLoad : Real;
            attribute outputMilliVolts : Real;

            perform action {
                normalizedLoad = load.appliedForce / (ratedCapacity * 9.80665);
                outputMilliVolts = normalizedLoad * ratedOutput_mV_per_V * excitationVoltage * 1000.0;
                strainSignal.bridgeDifferentialVoltage = outputMilliVolts / 1000.0;
                strainSignal.excitationVoltage = excitationVoltage;
                strainSignal.sensitivity_mV_per_V = ratedOutput_mV_per_V;
            }
        }
    }

    part def InstrumentationAmplifier {
        attribute gain : Real = 128.0;
        attribute inputOffsetVoltage : VoltageValue = 0.000005 [volt];
        attribute bandwidth : SampleRateValue = 80.0 [hertz];

        port signalInput : StrainSignalPort;
        port amplifiedOutput : AnalogSignalPort;
        port power : PowerPort;

        action def AmplifyBridgeSignal {
            in item strainSignal : StrainSignal;
            out item analogSignal : AmplifiedAnalogSignal;

            perform action {
                analogSignal.signalVoltage = (strainSignal.bridgeDifferentialVoltage + inputOffsetVoltage) * gain;
                analogSignal.commonModeVoltage = strainSignal.excitationVoltage / 2.0;
                analogSignal.gain = gain;
            }
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : ResolutionValue = 24 [bit];
        attribute referenceVoltage : VoltageValue = 2.5 [volt];
        attribute sampleRate : SampleRateValue = 80.0 [hertz];

        port analogInput : AnalogSignalPort;
        port digitalOutput : DigitalSignalPort;
        port power : PowerPort;

        action def SampleAnalogSignal {
            in item analogSignal : AmplifiedAnalogSignal;
            out item digitalMeasurement : DigitalMeasurement;

            attribute fullScaleCounts : Integer = 16777215;

            perform action {
                digitalMeasurement.rawAdcCount = analogSignal.signalVoltage / referenceVoltage * fullScaleCounts;
                digitalMeasurement.adcResolution = resolution;
                digitalMeasurement.sampleTime = 1.0 / sampleRate;
            }
        }
    }

    part def TemperatureSensor {
        attribute accuracy : TemperatureValue = 0.5 [degreeCelsius];
        attribute updateRate : SampleRateValue = 1.0 [hertz];

        port temperatureOutput : TemperaturePort;
        port power : PowerPort;

        action def MeasureTemperature {
            out item reading : TemperatureReading;
        }
    }

    part def MeasurementProcessor {
        attribute calibrationSlope_kg_per_count : Real = 0.00000298;
        attribute calibrationOffset_kg : Real = 0.0;
        attribute tareOffset_kg : Real = 0.0;
        attribute gravity : Real = 9.80665;
        attribute stabilityWindow : MassValue = 0.005 [kilogram];
        attribute stabilityTime : TimeValue = 1.0 [second];
        attribute overloadThreshold : MassValue = 55.0 [kilogram];

        port digitalInput : DigitalSignalPort;
        port temperatureInput : TemperaturePort;
        port commandInput : UserCommandPort;
        port weightOutput : WeightDataPort;
        port statusOutput : StatusPort;

        action def ComputeWeight {
            in item digitalMeasurement : DigitalMeasurement;
            in item temperatureReading : TemperatureReading;
            out item calibratedWeight : CalibratedWeight;

            attribute grossMass : MassValue;
            attribute compensatedMass : MassValue;
            attribute thermalCorrection_kg : Real;

            perform action {
                grossMass = digitalMeasurement.rawAdcCount * calibrationSlope_kg_per_count + calibrationOffset_kg;
                thermalCorrection_kg = (temperatureReading.temperature - 20.0) * 0.0001;
                compensatedMass = grossMass - tareOffset_kg - thermalCorrection_kg;
                calibratedWeight.mass = compensatedMass;
                calibratedWeight.netForce = compensatedMass * gravity;
                calibratedWeight.confidence = 99.0;
                calibratedWeight.stable = true;
            }
        }

        action def ApplyTare {
            in item currentWeight : CalibratedWeight;

            perform action {
                tareOffset_kg = currentWeight.mass;
            }
        }

        action def ApplyCalibration {
            in attribute knownMass : MassValue;
            in item digitalMeasurement : DigitalMeasurement;

            perform action {
                calibrationSlope_kg_per_count = knownMass / digitalMeasurement.rawAdcCount;
            }
        }

        state def MeasurementProcessingStateMachine {
            entry action Initialize {
                statusOutput.ready = false;
                statusOutput.faulted = false;
                statusOutput.faultCode = "NONE";
            }

            state Initializing;
            state WaitingForStableSignal;
            state Measuring;
            state Taring;
            state Calibrating;
            state Faulted;

            transition first Initializing;
            transition Initializing_to_Waiting
                first Initializing
                then WaitingForStableSignal
                accept after 2.0 [second];

            transition Waiting_to_Measuring
                first WaitingForStableSignal
                then Measuring
                guard digitalInput.digitalMeasurement.rawAdcCount != 0;

            transition Measuring_to_Taring
                first Measuring
                then Taring
                accept commandInput.tareRequested;

            transition Taring_to_Measuring
                first Taring
                then Measuring;

            transition Measuring_to_Calibrating
                first Measuring
                then Calibrating
                accept commandInput.calibrateRequested;

            transition Calibrating_to_Measuring
                first Calibrating
                then Measuring;

            transition Measuring_to_Faulted
                first Measuring
                then Faulted
                guard weightOutput.weight.mass > overloadThreshold;

            transition Faulted_to_Initializing
                first Faulted
                then Initializing
                accept commandInput.diagnosticRequested;
        }
    }

    part def UserDisplay {
        attribute displayedMass : MassValue;
        attribute displayedStable : Boolean;
        attribute displayedFault : String;

        port weightInput : WeightDataPort;
        port statusInput : StatusPort;
        port commandOutput : UserCommandPort;

        action def UpdateDisplay {
            in item weight : CalibratedWeight;
            in attribute faulted : Boolean;
            in attribute faultCode : String;

            perform action {
                displayedMass = weight.mass;
                displayedStable = weight.stable;
                displayedFault = faultCode;
            }
        }
    }

    part def LoadCellMeasurementSystem {
        attribute primaryFunction : String =
            "Convert an externally applied mechanical load into an accurate, temperature-compensated digital weight measurement and report the result to a user or controller.";

        attribute measurementRange : MassValue = 50.0 [kilogram];
        attribute requiredAccuracy : PercentValue = 0.05 [percent];
        attribute nominalSupplyVoltage : VoltageValue = 5.0 [volt];

        part sensingElement : LoadCell;
        part amplifier : InstrumentationAmplifier;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part processor : MeasurementProcessor;
        part display : UserDisplay;

        port externalLoadInput : MechanicalLoadPort;
        port reportedWeightOutput : WeightDataPort;
        port systemPower : PowerPort;
        port userCommands : UserCommandPort;
        port systemStatus : StatusPort;

        connect externalLoadInput to sensingElement.mechanicalInput;
        connect sensingElement.bridgeOutput to amplifier.signalInput;
        connect amplifier.amplifiedOutput to adc.analogInput;
        connect adc.digitalOutput to processor.digitalInput;
        connect temperatureSensor.temperatureOutput to processor.temperatureInput;
        connect processor.weightOutput to display.weightInput;
        connect processor.weightOutput to reportedWeightOutput;
        connect userCommands to processor.commandInput;
        connect display.commandOutput to processor.commandInput;
        connect processor.statusOutput to display.statusInput;
        connect processor.statusOutput to systemStatus;

        connect systemPower to sensingElement.excitationPower;
        connect systemPower to amplifier.power;
        connect systemPower to adc.power;
        connect systemPower to temperatureSensor.power;

        action def MeasureAppliedLoad {
            in item load : MechanicalLoad;
            out item weight : CalibratedWeight;

            perform sensingElement.ConvertLoadToStrainSignal;
            perform amplifier.AmplifyBridgeSignal;
            perform adc.SampleAnalogSignal;
            perform temperatureSensor.MeasureTemperature;
            perform processor.ComputeWeight;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         The load cell based measurement system shall convert applied mechanical load
         into a calibrated digital weight value suitable for display or transmission.
        */

        subject system : LoadCellMeasurementSystem;

        require constraint {
            system.reportedWeightOutput.weight.mass >= 0.0 [kilogram] and
            system.reportedWeightOutput.weight.mass <= system.measurementRange
        }
    }

    requirement def AccuracyRequirement {
        doc
        /*
         The system shall report measured mass within the specified percentage of
         full-scale capacity under normal operating temperature and rated load.
        */

        subject system : LoadCellMeasurementSystem;

        require constraint {
            system.requiredAccuracy <= 0.05 [percent]
        }
    }

    requirement def StabilityRequirement {
        doc
        /*
         The system shall indicate a stable measurement only after the processed
         weight remains within the stability window for the configured stability time.
        */

        subject processor : MeasurementProcessor;

        require constraint {
            processor.stabilityWindow <= 0.005 [kilogram] and
            processor.stabilityTime >= 1.0 [second]
        }
    }

    requirement def OverloadProtectionRequirement {
        doc
        /*
         The system shall enter a fault state when the measured load exceeds the
         configured overload threshold.
        */

        subject processor : MeasurementProcessor;

        require constraint {
            processor.overloadThreshold <= 55.0 [kilogram]
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc
        /*
         The system shall use temperature input to compensate measurement drift
         during normal operation.
        */

        subject system : LoadCellMeasurementSystem;

        require constraint {
            system.temperatureSensor.temperatureOutput.temperature.temperature >=
                system.sensingElement.operatingTemperatureMin and
            system.temperatureSensor.temperatureOutput.temperature.temperature <=
                system.sensingElement.operatingTemperatureMax
        }
    }

    satisfy PrimaryFunctionRequirement by LoadCellMeasurementSystem;
    satisfy AccuracyRequirement by LoadCellMeasurementSystem;
    satisfy StabilityRequirement by MeasurementProcessor;
    satisfy OverloadProtectionRequirement by MeasurementProcessor;
    satisfy TemperatureCompensationRequirement by LoadCellMeasurementSystem;

}