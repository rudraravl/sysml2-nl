package ThermocoupleSystemModel {

    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::millivolt;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Sensitivity :> ISQ::electricPotentialPerTemperature {
        unit = SI::millivoltPerKelvin;
    }

    attribute def Percentage {
        :>> range = "0..100";
    }

    item def ThermalEnergySample {
        attribute measuredJunctionTemperature : Temperature;
        attribute ambientReferenceTemperature : Temperature;
    }

    item def ThermoelectricSignal {
        attribute seebeckVoltage : Voltage;
        attribute polarity : String;
        attribute generatedAt : TimeDuration;
    }

    item def TemperatureReading {
        attribute processTemperature : Temperature;
        attribute compensatedTemperature : Temperature;
        attribute confidence : Percentage;
        attribute timestamp : TimeDuration;
    }

    port def ThermalContactPort {
        in item thermalSample : ThermalEnergySample;
    }

    port def ElectricalSignalPort {
        out item signal : ThermoelectricSignal;
    }

    port def SignalInputPort {
        in item signal : ThermoelectricSignal;
    }

    port def ReadingOutputPort {
        out item reading : TemperatureReading;
    }

    part def MeasurementJunction {
        port thermalContact : ThermalContactPort;

        attribute junctionTemperature : Temperature;
        attribute thermalResponseTime : TimeDuration = 0.45 [SI::second];
        attribute maxServiceTemperature : Temperature = 1250 [SI::degreeCelsius];

        action absorbThermalEnergy {
            in item sample : ThermalEnergySample;
            out temperature : Temperature;

            first start;
            then updateJunctionTemperature;
            then done;

            action updateJunctionTemperature {
                temperature = sample.measuredJunctionTemperature;
            }
        }
    }

    part def ReferenceJunction {
        attribute referenceTemperature : Temperature = 25 [SI::degreeCelsius];
        attribute compensationAccuracy : Temperature = 0.8 [SI::degreeCelsius];

        action senseReferenceTemperature {
            out temperature : Temperature;

            first start;
            then readColdJunctionSensor;
            then done;

            action readColdJunctionSensor {
                temperature = referenceTemperature;
            }
        }
    }

    part def ThermocoupleWirePair {
        attribute positiveLegMaterial : String = "Chromel";
        attribute negativeLegMaterial : String = "Alumel";
        attribute typeDesignation : String = "Type K";
        attribute nominalSensitivity : Sensitivity = 0.041 [SI::millivoltPerKelvin];
        attribute insulationMaterial : String = "Mineral insulated magnesium oxide";
        attribute sheathMaterial : String = "Inconel 600";

        port signalOut : ElectricalSignalPort;

        action generateThermoelectricSignal {
            in hotTemperature : Temperature;
            in coldTemperature : Temperature;
            out item signal : ThermoelectricSignal;

            first start;
            then calculateTemperatureDifference;
            then calculateSeebeckVoltage;
            then assignPolarity;
            then done;

            attribute deltaTemperature : Temperature;
            attribute voltageMagnitude : Voltage;

            action calculateTemperatureDifference {
                deltaTemperature = hotTemperature - coldTemperature;
            }

            action calculateSeebeckVoltage {
                voltageMagnitude = nominalSensitivity * deltaTemperature;
                signal.seebeckVoltage = voltageMagnitude;
            }

            action assignPolarity {
                if deltaTemperature >= 0 [SI::degreeCelsius] {
                    signal.polarity = "positive leg higher potential";
                } else {
                    signal.polarity = "negative leg higher potential";
                }
            }
        }
    }

    part def SignalConditioner {
        port rawSignalIn : SignalInputPort;
        port readingOut : ReadingOutputPort;

        attribute inputImpedance : ISQ::resistance = 1000000 [SI::ohm];
        attribute noiseRejectionRatio : Percentage = 95;
        attribute samplingPeriod : TimeDuration = 0.1 [SI::second];
        attribute calibrationOffset : Temperature = 0.0 [SI::degreeCelsius];

        action convertVoltageToTemperature {
            in item signal : ThermoelectricSignal;
            in coldJunctionTemperature : Temperature;
            out item reading : TemperatureReading;

            first start;
            then filterSignal;
            then linearizeResponse;
            then applyColdJunctionCompensation;
            then publishReading;
            then done;

            attribute filteredVoltage : Voltage;
            attribute temperatureRise : Temperature;

            action filterSignal {
                filteredVoltage = signal.seebeckVoltage;
            }

            action linearizeResponse {
                temperatureRise = filteredVoltage / 0.041 [SI::millivoltPerKelvin];
            }

            action applyColdJunctionCompensation {
                reading.processTemperature = coldJunctionTemperature + temperatureRise + calibrationOffset;
                reading.compensatedTemperature = reading.processTemperature;
                reading.confidence = 98;
            }

            action publishReading;
        }
    }

    part def ThermocoupleProbe {
        part measurementJunction : MeasurementJunction;
        part referenceJunction : ReferenceJunction;
        part wirePair : ThermocoupleWirePair;
        part conditioner : SignalConditioner;

        port processThermalInput : ThermalContactPort;
        port temperatureOutput : ReadingOutputPort;

        connect processThermalInput to measurementJunction.thermalContact;
        connect wirePair.signalOut to conditioner.rawSignalIn;
        connect conditioner.readingOut to temperatureOutput;

        attribute operatingState : String;
        attribute latestTemperature : Temperature;
        attribute latestSignalVoltage : Voltage;

        action measureProcessTemperature {
            in item sample : ThermalEnergySample;
            out item reading : TemperatureReading;

            first receiveThermalSample;
            then senseHotJunction;
            then senseColdJunction;
            then generateSignal;
            then conditionSignal;
            then updateLatestTemperature;
            then done;

            attribute hotTemperature : Temperature;
            attribute coldTemperature : Temperature;
            item rawSignal : ThermoelectricSignal;

            action receiveThermalSample {
                send sample to measurementJunction.thermalContact.thermalSample;
            }

            action senseHotJunction {
                hotTemperature = sample.measuredJunctionTemperature;
            }

            action senseColdJunction {
                coldTemperature = referenceJunction.referenceTemperature;
            }

            action generateSignal {
                perform wirePair.generateThermoelectricSignal(
                    hotTemperature = hotTemperature,
                    coldTemperature = coldTemperature,
                    signal = rawSignal
                );
                latestSignalVoltage = rawSignal.seebeckVoltage;
            }

            action conditionSignal {
                perform conditioner.convertVoltageToTemperature(
                    signal = rawSignal,
                    coldJunctionTemperature = coldTemperature,
                    reading = reading
                );
            }

            action updateLatestTemperature {
                latestTemperature = reading.compensatedTemperature;
            }
        }

        state def ThermocoupleProbeStateMachine {
            state Off;
            state Initializing;
            state Ready;
            state Measuring;
            state Fault;

            entry action initialize {
                operatingState = "initializing";
            }

            transition first Off then Initializing;
            transition Initializing then Ready
                accept after 2 [SI::second];

            transition Ready then Measuring
                accept MeasurementRequested;

            transition Measuring then Ready
                accept MeasurementComplete;

            transition Ready then Fault
                accept OpenCircuitDetected;

            transition Measuring then Fault
                accept SignalOutOfRange;

            transition Fault then Initializing
                accept ResetCommand;
        }
    }

    part def ThermocoupleMeasurementSystem {
        part probe : ThermocoupleProbe;

        port thermalInput : ThermalContactPort;
        port measuredTemperatureOutput : ReadingOutputPort;

        connect thermalInput to probe.processThermalInput;
        connect probe.temperatureOutput to measuredTemperatureOutput;

        attribute primaryFunction : String =
            "Convert a temperature difference between a measurement junction and a reference junction into a thermoelectric voltage, compensate the reference junction, and output a temperature reading.";

        attribute measurementRangeLow : Temperature = -200 [SI::degreeCelsius];
        attribute measurementRangeHigh : Temperature = 1250 [SI::degreeCelsius];
        attribute requiredAccuracy : Temperature = 2.2 [SI::degreeCelsius];
        attribute maximumResponseTime : TimeDuration = 1.0 [SI::second];

        action performTemperatureMeasurement {
            in item processThermalSample : ThermalEnergySample;
            out item processTemperatureReading : TemperatureReading;

            first acceptSample;
            then invokeProbeMeasurement;
            then outputTemperatureReading;
            then done;

            action acceptSample {
                send processThermalSample to thermalInput.thermalSample;
            }

            action invokeProbeMeasurement {
                perform probe.measureProcessTemperature(
                    sample = processThermalSample,
                    reading = processTemperatureReading
                );
            }

            action outputTemperatureReading {
                send processTemperatureReading to measuredTemperatureOutput.reading;
            }
        }
    }

    requirement def PrimaryThermocoupleFunctionRequirement {
        doc /* The thermocouple system shall convert thermal energy at a process measurement point into an electrical thermoelectric signal and produce a compensated temperature reading. */

        subject system : ThermocoupleMeasurementSystem;

        require constraint {
            system.primaryFunction ==
            "Convert a temperature difference between a measurement junction and a reference junction into a thermoelectric voltage, compensate the reference junction, and output a temperature reading."
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The thermocouple system shall measure process temperatures from -200 degrees Celsius to 1250 degrees Celsius. */

        subject system : ThermocoupleMeasurementSystem;

        require constraint {
            system.measurementRangeLow <= -200 [SI::degreeCelsius] and
            system.measurementRangeHigh >= 1250 [SI::degreeCelsius]
        }
    }

    requirement def AccuracyRequirement {
        doc /* The thermocouple system shall provide compensated temperature readings with error not exceeding 2.2 degrees Celsius under nominal operating conditions. */

        subject system : ThermocoupleMeasurementSystem;

        require constraint {
            system.requiredAccuracy <= 2.2 [SI::degreeCelsius]
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The thermocouple system shall produce a valid compensated temperature reading within one second after thermal input sampling. */

        subject system : ThermocoupleMeasurementSystem;

        require constraint {
            system.maximumResponseTime <= 1.0 [SI::second]
        }
    }

    requirement def ColdJunctionCompensationRequirement {
        doc /* The system shall compensate the thermoelectric voltage using the measured reference junction temperature. */

        subject probe : ThermocoupleProbe;

        require constraint {
            probe.referenceJunction.compensationAccuracy <= 0.8 [SI::degreeCelsius]
        }
    }

    requirement def SignalGenerationRequirement {
        doc /* The wire pair shall generate a voltage proportional to the temperature difference between the measurement junction and the reference junction. */

        subject wirePair : ThermocoupleWirePair;

        require constraint {
            wirePair.nominalSensitivity == 0.041 [SI::millivoltPerKelvin]
        }
    }

    part thermocoupleSystem : ThermocoupleMeasurementSystem;

    satisfy PrimaryThermocoupleFunctionRequirement by thermocoupleSystem;
    satisfy MeasurementRangeRequirement by thermocoupleSystem;
    satisfy AccuracyRequirement by thermocoupleSystem;
    satisfy ResponseTimeRequirement by thermocoupleSystem;
    satisfy ColdJunctionCompensationRequirement by thermocoupleSystem.probe;
    satisfy SignalGenerationRequirement by thermocoupleSystem.probe.wirePair;
}