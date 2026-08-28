package ResistanceThermometerSystem {
    private import SI::s;
    private import SI::A;
    private import SI::V;
    private import SI::ohm;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    attribute def StartMeasurement;
    attribute def ShutdownSignal;

    item def ExcitationCurrent {
        attribute magnitude : Real = 0.001 [A];
    }

    item def RawVoltage {
        attribute magnitude : Real;
    }

    item def ConditionedSignal {
        attribute voltage : Real;
        attribute resistance : Real;
    }

    item def TemperatureReading {
        attribute temperature : Real;
        attribute timestamp : Real;
        attribute accuracy : Real;
    }

    part def ExcitationSource {
        attribute outputCurrent : Real = 0.001 [A];
        port currentOut {
            out current : ExcitationCurrent;
        }
    }

    part def RTDSensor {
        attribute referenceResistance : Real = 100 [ohm];
        attribute alphaCoefficient : Real = 0.00385;
        attribute ambientTemperature : Real;
        attribute resistance : Real;
        port excitationIn {
            in current : ExcitationCurrent;
        }
        port voltageOut {
            out rawVoltage : RawVoltage;
        }
        constraint rtdEquation {
            resistance == referenceResistance * (1 + alphaCoefficient * ambientTemperature)
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 10.0;
        attribute noiseFloor : Real = 0.0001 [V];
        port voltageIn {
            in rawVoltage : RawVoltage;
        }
        port signalOut {
            out conditionedSignal : ConditionedSignal;
        }
    }

    part def TemperatureConverter {
        attribute referenceResistance : Real = 100 [ohm];
        attribute alphaCoefficient : Real = 0.00385;
        attribute measuredResistance : Real;
        attribute calculatedTemperature : Real;
        port signalIn {
            in conditionedSignal : ConditionedSignal;
        }
        port readingOut {
            out reading : TemperatureReading;
        }
        constraint calibrationFormula {
            calculatedTemperature == (measuredResistance - referenceResistance)
                / (alphaCoefficient * referenceResistance)
        }
    }

    part def Display {
        attribute displayedTemperature : Real;
        attribute displayedTimestamp : Real;
        attribute displayedAccuracy : Real;
        port readingIn {
            in reading : TemperatureReading;
        }
    }

    part def ResistanceThermometer {
        perform action measureTemperature[*] ordered {
            action excite {
                out current : ExcitationCurrent;
            }
            action sense {
                in current : ExcitationCurrent;
                out rawVoltage : RawVoltage;
            }
            action condition {
                in rawVoltage : RawVoltage;
                out conditionedSignal : ConditionedSignal;
            }
            action convert {
                in conditionedSignal : ConditionedSignal;
                out reading : TemperatureReading;
            }
            action display {
                in reading : TemperatureReading;
            }
            flow excite.current to sense.current;
            flow sense.rawVoltage to condition.rawVoltage;
            flow condition.conditionedSignal to convert.conditionedSignal;
            flow convert.reading to display.reading;
        }

        part excitationSource : ExcitationSource {
            perform measureTemperature.excite;
        }
        part rtdSensor : RTDSensor {
            perform measureTemperature.sense;
        }
        part signalConditioner : SignalConditioner {
            perform measureTemperature.condition;
        }
        part temperatureConverter : TemperatureConverter {
            perform measureTemperature.convert;
        }
        part display : Display {
            perform measureTemperature.display;
        }

        interface excitationInterface
            connect excitationSource.currentOut to rtdSensor.excitationIn {
            flow currentFlow of ExcitationCurrent
                from excitationSource.currentOut.current
                to rtdSensor.excitationIn.current;
        }

        interface rawVoltageInterface
            connect rtdSensor.voltageOut to signalConditioner.voltageIn {
            flow rawVoltageFlow of RawVoltage
                from rtdSensor.voltageOut.rawVoltage
                to signalConditioner.voltageIn.rawVoltage;
        }

        interface conditionedSignalInterface
            connect signalConditioner.signalOut to temperatureConverter.signalIn {
            flow conditionedSignalFlow of ConditionedSignal
                from signalConditioner.signalOut.conditionedSignal
                to temperatureConverter.signalIn.conditionedSignal;
        }

        interface readingInterface
            connect temperatureConverter.readingOut to display.readingIn {
            flow readingFlow of TemperatureReading
                from temperatureConverter.readingOut.reading
                to display.readingIn.reading;
        }

        state measurementCycle {
            entry; then idle;

            state idle;
            transition first idle
                accept startSig : StartMeasurement
                then sensing;
            transition first idle
                accept shutdownSig : ShutdownSignal
                then done;

            state sensing {
                do measureTemperature.excite;
                do measureTemperature.sense;
            }
            transition first sensing then converting;
            transition first sensing
                accept shutdownSig : ShutdownSignal
                then done;

            state converting {
                do measureTemperature.condition;
                do measureTemperature.convert;
            }
            transition first converting then displaying;
            transition first converting
                accept shutdownSig : ShutdownSignal
                then done;

            state displaying {
                do measureTemperature.display;
            }
            transition first displaying then idle;
            transition first displaying
                accept shutdownSig : ShutdownSignal
                then done;
        }
    }

    requirement def HighAccuracyRequirement {
        doc /* The thermometer shall provide temperature measurements
             with accuracy better than 0.5 degrees Celsius. */
        attribute maxError : Real = 0.5;
    }

    requirement def ResponseTimeRequirement {
        doc /* The thermometer shall complete a full measurement cycle
             within 2 seconds. */
        attribute maxResponseTime : Real = 2.0 [s];
    }

    requirement def OperatingRangeRequirement {
        doc /* The thermometer shall operate across a temperature range
             from -200 to 850 degrees Celsius. */
        attribute minTemperature : Real = -200;
        attribute maxTemperature : Real = 850;
    }

    package ThermometerRequirements {
        requirement highAccuracy : HighAccuracyRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement operatingRange : OperatingRangeRequirement;
    }

    part thermometer : ResistanceThermometer;

    satisfy ThermometerRequirements::highAccuracy by thermometer;
    satisfy ThermometerRequirements::responseTime by thermometer;
    satisfy ThermometerRequirements::operatingRange by thermometer;
}
