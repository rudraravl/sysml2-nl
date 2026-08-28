package ActinometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;
    import ISQThermodynamics::*;

    // ---- Value types with units ----
    value type UVIntensityValue :> Real {
        :>> unit = W_per_m2;
    }
    value type PhotocurrentValue :> Real {
        :>> unit = uA;
    }
    value type VoltageValue :> Real {
        :>> unit = V;
    }
    value type DigitalCountValue :> Integer;
    value type TemperatureValue :> Real {
        :>> unit = degC;
    }
    value type WavelengthValue :> Real {
        :>> unit = nm;
    }
    value type TimestampValue :> Real {
        :>> unit = s;
    }

    item UVRadiation {
        :>> wavelength : WavelengthValue;
        :>> intensity : UVIntensityValue;
    }

    item MeasurementRecord {
        :>> intensity : UVIntensityValue;
        :>> timestamp : TimestampValue;
        :>> temperature : TemperatureValue;
    }

    // ---- Port definitions ----
    port def UVRadiationPort {
        in uv : UVRadiation;
    }

    port def PhotocurrentPort {
        out current : PhotocurrentValue;
    }

    port def AnalogVoltagePort {
        out voltage : VoltageValue;
    }

    port def DigitalDataPort {
        out count : DigitalCountValue;
    }

    port def MeasurementPort {
        out record : MeasurementRecord;
    }

    port def CommandPort {
        in command : CommandSignal;
    }

    item CommandSignal {
        attribute kind : CommandKind;
    }
    enum def CommandKind {
        standby;
        calibrate;
        measure;
        reset;
    }

    // ---- Component definitions ----

    part def PhotodetectorSensor {
        attribute sensitivityMin : WavelengthValue = 280 [nm];
        attribute sensitivityMax : WavelengthValue = 400 [nm];
        attribute responsivity : Real = 0.1; // A/W nominal
        port uvIn : UVRadiationPort;
        port currentOut : PhotocurrentPort;
        attribute status : SensorStatus = SensorStatus::ok;

        enum def SensorStatus {
            ok;
            failed;
        }

        action def SenseUV {
            in uv : UVRadiation;
            out current : PhotocurrentValue;
        }

        perform SenseUV {
            if uvIn.uv.wavelength >= sensitivityMin & uvIn.uv.wavelength <= sensitivityMax {
                currentOut.current = uvIn.uv.intensity * responsivity * 1e6; // to uA
                status = SensorStatus::ok;
            } else {
                currentOut.current = 0 [uA];
                status = SensorStatus::failed;
            }
        }
    }

    part def SignalAmplifier {
        attribute gain : Real = 1000.0;
        port currentIn : PhotocurrentPort;
        port voltageOut : AnalogVoltagePort;

        action def Amplify {
            in current : PhotocurrentValue;
            out voltage : VoltageValue;
        }

        perform Amplify {
            voltageOut.voltage = currentIn.current * gain * 1e-6; // uA to A then to V
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : VoltageValue = 3.3 [V];
        port voltageIn : AnalogVoltagePort;
        port digitalOut : DigitalDataPort;

        action def Convert {
            in voltage : VoltageValue;
            out count : DigitalCountValue;
        }

        perform Convert {
            if voltageIn.voltage >= referenceVoltage {
                digitalOut.count = 2^resolutionBits - 1;
            } else if voltageIn.voltage <= 0 [V] {
                digitalOut.count = 0;
            } else {
                digitalOut.count = floor(voltageIn.voltage / referenceVoltage * (2^resolutionBits - 1));
            }
        }
    }

    part def CentralProcessingUnit {
        attribute calibrationFactor : Real = 1.0;
        attribute offset : UVIntensityValue = 0 [W/m2];
        attribute traceabilityId : String = "NIST-UV-2024-001";
        port digitalIn : DigitalDataPort;
        port measurementOut : MeasurementPort;
        port commandIn : CommandPort;
        attribute temperature : TemperatureValue = 25 [degC];
        attribute clock : TimestampValue = 0 [s];

        action def ProcessMeasurement {
            in count : DigitalCountValue;
            out record : MeasurementRecord;
        }

        perform ProcessMeasurement {
            var rawIntensity : UVIntensityValue;
            rawIntensity = (digitalIn.count / 65535.0) * 100.0 [W/m2];
            measurementOut.record.intensity = rawIntensity * calibrationFactor + offset;
            measurementOut.record.timestamp = clock;
            measurementOut.record.temperature = temperature;
        }

        action def ApplyCalibration {
            in factor : Real;
            in off : UVIntensityValue;
        }
        perform ApplyCalibration {
            calibrationFactor = factor;
            offset = off;
        }
    }

    part def DisplayAndRecordingUnit {
        port measurementIn : MeasurementPort;
        attribute storedRecords : MeasurementRecord[0..*];
        attribute displayEnabled : Boolean = true;

        action def Display {
            in record : MeasurementRecord;
        }
        action def Store {
            in record : MeasurementRecord;
        }

        perform Display {
            if displayEnabled {
                // render record on screen
            }
        }
        perform Store {
            storedRecords = storedRecords->including(measurementIn.record);
        }
    }

    // ---- Composite system ----
    part def ActinometerSystem {
        port uvInput : UVRadiationPort;
        port commandInput : CommandPort;

        part sensor : PhotodetectorSensor {
            :>> uvIn = uvInput;
        }
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part cpu : CentralProcessingUnit {
            :>> commandIn = commandInput;
        }
        part displayUnit : DisplayAndRecordingUnit;

        connection sensor.currentOut to amplifier.currentIn;
        connection amplifier.voltageOut to adc.voltageIn;
        connection adc.digitalOut to cpu.digitalIn;
        connection cpu.measurementOut to displayUnit.measurementIn;

        // ---- State machine ----
        state def ActinometerStates {
            state standby;
            state calibrating;
            state activeMeasuring;
            state error;

            entry standby {
                // idle, low power
            }
            entry calibrating {
                cpu.ApplyCalibration(1.0, 0 [W/m2]);
            }
            entry activeMeasuring {
                sensor.SenseUV();
                amplifier.Amplify();
                adc.Convert();
                cpu.ProcessMeasurement();
                displayUnit.Display();
                displayUnit.Store();
            }
            entry error {
                // halt measurement, await reset
            }

            transition standby to calibrating when commandInput.command.kind == CommandKind::calibrate;
            transition standby to activeMeasuring when commandInput.command.kind == CommandKind::measure;
            transition calibrating to standby when commandInput.command.kind == CommandKind::standby;
            transition activeMeasuring to standby when commandInput.command.kind == CommandKind::standby;
            transition activeMeasuring to error when sensor.status == PhotodetectorSensor::SensorStatus::failed;
            transition calibrating to error when sensor.status == PhotodetectorSensor::SensorStatus::failed;
            transition error to standby when commandInput.command.kind == CommandKind::reset;
        }

        exhibit ActinometerStates as stateBehavior;
    }

    // ---- Requirements ----
    requirement def UVSensitivityRequirement {
        doc /* The photodetector shall be sensitive to UV radiation in the 280–400 nm range. */
        constraint { sensor.sensitivityMin == 280 [nm] & sensor.sensitivityMax == 400 [nm] }
    }

    requirement def SignalChainRequirement {
        doc /* The system shall amplify, digitize, and process the photodetector signal. */
        constraint { amplifier.gain > 0 & adc.resolutionBits >= 12 }
    }

    requirement def CalibrationTraceabilityRequirement {
        doc /* Calibration factors shall be traceable to a recognized standard. */
        constraint { cpu.traceabilityId != "" }
    }

    requirement def MeasurementOutputRequirement {
        doc /* Each measurement record shall include intensity, timestamp, and temperature. */
        constraint { displayUnit.measurementIn.record.intensity != null
                     & displayUnit.measurementIn.record.timestamp != null
                     & displayUnit.measurementIn.record.temperature != null }
    }

    requirement def StateBehaviorRequirement {
        doc /* The actinometer shall support standby, calibrating, active measuring, and error states. */
        constraint { ActinometerStates::standby != null
                     & ActinometerStates::calibrating != null
                     & ActinometerStates::activeMeasuring != null
                     & ActinometerStates::error != null }
    }

    requirement def ErrorRecoveryRequirement {
        doc /* The system shall enter an error state on sensor failure and recover on reset command. */
        constraint { ActinometerStates::error != null }
    }

    part actinometer : ActinometerSystem {
        satisfy UVSensitivityRequirement by sensor;
        satisfy SignalChainRequirement by amplifier, adc, cpu;
        satisfy CalibrationTraceabilityRequirement by cpu;
        satisfy MeasurementOutputRequirement by displayUnit;
        satisfy StateBehaviorRequirement by stateBehavior;
        satisfy ErrorRecoveryRequirement by stateBehavior;
    }
}
