package DisplacementSensingUnit {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    item def PhysicalDisplacement :> LengthValue {
        doc /* The physical movement to be measured. */
    }
    attribute def RawVoltage :> ElectricPotentialValue {
        doc /* Raw low-level analog voltage from the sensor. */
    }
    attribute def ConditionedVoltage :> ElectricPotentialValue {
        doc /* Amplified and filtered analog voltage. */
    }
    item def DisplacementReading {
        doc /* A final timestamped digital displacement measurement. */
        attribute displacement : PhysicalDisplacement;
        attribute timestamp : TimeInstantValue;
    }

    part def DisplacementSensor {
        doc /* Transduces mechanical displacement into a raw analog voltage. */
        attribute measurementRange : LengthValue = 100 [mm];
        attribute accuracy : LengthValue = 0.01 [mm];
        attribute sensitivity : Real = 0.1 {
            doc /* Volts per millimeter. */
        }
        in item physicalMovement : PhysicalDisplacement;
        out item rawSignal : RawVoltage;
        action def SenseDisplacement {
            in movement : PhysicalDisplacement;
            out voltage : RawVoltage;
        }
        perform action sense : SenseDisplacement {
            in movement = physicalMovement;
            out voltage = rawSignal;
        }
    }

    part def SignalConditioner {
        doc /* Amplifies and filters the raw analog signal. */
        attribute gain : Real = 10;
        attribute cutoffFrequency : FrequencyValue = 500 [Hz];
        in item rawSignal : RawVoltage;
        out item conditionedSignal : ConditionedVoltage;
        action def Amplify {
            in inputVoltage : RawVoltage;
            out amplifiedVoltage : RawVoltage;
        }
        action def FilterSignal {
            in inputVoltage : RawVoltage;
            out filteredVoltage : ConditionedVoltage;
        }
        perform action amplify : Amplify {
            in inputVoltage = rawSignal;
            out amplifiedVoltage;
        }
        flow amplify.amplifiedVoltage to filterSignal.inputVoltage;
        perform action filterSignal : FilterSignal {
            in inputVoltage;
            out filteredVoltage = conditionedSignal;
        }
        first amplify then filterSignal;
    }

    part def MeasurementProcessor {
        doc /* Samples the conditioned signal and produces timestamped displacement readings. */
        attribute sampleRate : FrequencyValue = 1000 [Hz];
        attribute conversionFactor : Real = 10 {
            doc /* Millimeters per Volt. */
        }
        in item conditionedSignal : ConditionedVoltage;
        out item readings : DisplacementReading [*];
        ref item localClock : Clock = Time::universalClock;
        action def Sample {
            in signal : ConditionedVoltage;
            out sampledVoltage : ConditionedVoltage;
        }
        action def Convert {
            in voltage : ConditionedVoltage;
            out displacement : PhysicalDisplacement;
        }
        action def PackageReading {
            in displacement : PhysicalDisplacement;
            in timestamp : TimeInstantValue;
            out reading : DisplacementReading;
        }
        perform action sample : Sample {
            in signal = conditionedSignal;
            out sampledVoltage;
        }
        flow sample.sampledVoltage to convert.voltage;
        perform action convert : Convert {
            in voltage;
            out displacement;
        }
        flow convert.displacement to packageReading.displacement;
        perform action packageReading : PackageReading {
            in displacement;
            in timestamp = localClock.currentTime;
            out reading :> readings;
        }
        first sample then convert;
        first convert then packageReading;
    }

    requirement def MeasurementRangeRequirement {
        doc /* The sensor must measure displacement up to 100 mm. */
        attribute maxRange : LengthValue = 100 [mm];
        subject sensor : DisplacementSensor;
        require sensor.measurementRange >= maxRange;
    }

    requirement def AccuracyRequirement {
        doc /* The sensor must achieve accuracy of 0.01 mm. */
        attribute requiredAccuracy : LengthValue = 0.01 [mm];
        subject sensor : DisplacementSensor;
        require sensor.accuracy <= requiredAccuracy;
    }

    requirement def GainRequirement {
        doc /* The signal conditioner must amplify with a gain of 10. */
        attribute requiredGain : Real = 10;
        subject conditioner : SignalConditioner;
        require conditioner.gain == requiredGain;
    }

    requirement def SamplingRateRequirement {
        doc /* The processor must sample at 1000 Hz. */
        attribute requiredSampleRate : FrequencyValue = 1000 [Hz];
        subject processor : MeasurementProcessor;
        require processor.sampleRate >= requiredSampleRate;
    }

    state machine def OperationalStates {
        doc /* Governs power and operational states of the sensing unit. */
        initial; then operational;
        state operational {
            entry; then sensing;
            state sensing;
            transition sensing to idle;
            state idle;
            transition idle to sensing;
        }
        transition operational to shutdown;
        state shutdown;
    }

    part def DisplacementSensingSystem {
        doc /* The complete modular displacement sensing unit. */
        in item physicalMovement : PhysicalDisplacement;
        out item measurementReadings : DisplacementReading [*];

        part displacementSensor : DisplacementSensor {
            in item :>> physicalMovement;
            out item :>> rawSignal;
            satisfy MeasurementRangeRequirement;
            satisfy AccuracyRequirement;
        }
        part signalConditioner : SignalConditioner {
            in item :>> rawSignal;
            out item :>> conditionedSignal;
            satisfy GainRequirement;
        }
        part measurementProcessor : MeasurementProcessor {
            in item :>> conditionedSignal;
            out item :>> readings;
            satisfy SamplingRateRequirement;
        }

        flow displacementSensor.rawSignal to signalConditioner.rawSignal;
        flow signalConditioner.conditionedSignal to measurementProcessor.conditionedSignal;
        bind measurementReadings = measurementProcessor.readings;

        state machine : OperationalStates;
    }
}
