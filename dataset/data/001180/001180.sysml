package PhotodiodeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def LightIntensityValue :> Real;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def ResponsivityValue :> Real;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def ResistanceValue :> Real;
    attribute def CapacitanceValue :> Real;

    item def OpticalSignal {
        attribute intensity : LightIntensityValue;
        attribute wavelength : ISQ::LengthValue;
    }

    item def ElectricalSignal {
        attribute current : CurrentValue;
        attribute voltage : VoltageValue;
    }

    port def OpticalInputPort {
        in item light : OpticalSignal;
    }

    port def ElectricalOutputPort {
        out item signal : ElectricalSignal;
    }

    part def Photodiode {
        attribute responsivity : ResponsivityValue = 0.6;
        attribute darkCurrent : CurrentValue = 1.0e-9 [SI::A];
        attribute reverseVoltage : VoltageValue = 5.0 [SI::V];
        attribute responseTime : TimeValue = 10.0e-9 [SI::s];
        attribute junctionCapacitance : CapacitanceValue = 5.0e-12;

        port opticalIn : OpticalInputPort;
        port electricalOut : ElectricalOutputPort;

        constraint def PhotocurrentGeneration {
            in lightIntensity : LightIntensityValue;
            in responsivityValue : ResponsivityValue;
            in darkCurrentValue : CurrentValue;
            out photocurrent : CurrentValue;
            photocurrent == responsivityValue * lightIntensity + darkCurrentValue
        }

        assert constraint photocurrentConstraint : PhotocurrentGeneration {
            in lightIntensity = opticalIn.light.intensity;
            in responsivityValue = responsivity;
            in darkCurrentValue = darkCurrent;
            out photocurrent = electricalOut.signal.current;
        }

        perform action convertLightToElectricity {
            in lightInput :> opticalIn.light;
            out electricalOutput :> electricalOut.signal;

            first start;
            then action absorbPhotons {
                in photons = lightInput;
                out carrierPairs : Real;
            }
            then action generateCurrent {
                in carriers = absorbPhotons.carrierPairs;
                out current = electricalOutput.current;
            }
            then action establishVoltage {
                in currentValue = generateCurrent.current;
                out voltage = electricalOutput.voltage;
            }
            then done;
        }
    }

    part def LoadResistor {
        attribute resistance : ResistanceValue = 10000.0;
        port input : ElectricalOutputPort;
        port output : ElectricalOutputPort;

        assert constraint ohmsLaw {
            output.signal.voltage == input.signal.current * resistance
        }
    }

    part def TransimpedanceAmplifier {
        attribute feedbackResistance : ResistanceValue = 1.0e6;
        attribute gain : Real = 1.0e6;
        attribute bandwidth : Real = 1.0e6;

        port currentIn : ElectricalOutputPort;
        port voltageOut : ElectricalOutputPort;

        assert constraint amplification {
            voltageOut.signal.voltage == currentIn.signal.current * feedbackResistance
        }

        perform action amplifySignal {
            in inputCurrent :> currentIn.signal.current;
            out outputVoltage :> voltageOut.signal.voltage;

            first start;
            then action convertCurrentToVoltage {
                in current = inputCurrent;
                out voltage = outputVoltage;
            }
            then done;
        }
    }

    part def SignalProcessor {
        attribute samplingRate : Real = 100000.0;
        attribute resolution : Real = 12.0;

        port analogIn : ElectricalOutputPort;

        perform action processSignal {
            in analogSignal :> analogIn.signal;
            out digitalValue : Real;

            first start;
            then action filterNoise {
                in rawSignal = analogSignal;
                out filteredSignal : ElectricalSignal;
            }
            then action sampleAndHold {
                in signal = filterNoise.filteredSignal;
                out sampledValue : VoltageValue;
            }
            then action quantize {
                in sample = sampleAndHold.sampledValue;
                out quantized = digitalValue;
            }
            then done;
        }
    }

    part def OpticalDetectionSystem {
        attribute detectionThreshold : LightIntensityValue = 100.0;
        attribute operatingTemperature : ISQ::TemperatureValue = 298.15 [SI::K];
        attribute maxInputIntensity : LightIntensityValue = 10000.0;

        part sensor : Photodiode {
            attribute :>> responsivity = 0.65;
            attribute :>> darkCurrent = 5.0e-10 [SI::A];
            attribute :>> reverseVoltage = 5.0 [SI::V];
            attribute :>> responseTime = 8.0e-9 [SI::s];
        }

        part load : LoadResistor {
            attribute :>> resistance = 10000.0;
        }

        part amplifier : TransimpedanceAmplifier {
            attribute :>> feedbackResistance = 1.0e6;
            attribute :>> gain = 1.0e6;
            attribute :>> bandwidth = 1.0e6;
        }

        part processor : SignalProcessor {
            attribute :>> samplingRate = 100000.0;
            attribute :>> resolution = 12.0;
        }

        port opticalInput : OpticalInputPort;

        connection sensorInput connect opticalInput to sensor.opticalIn;
        connection sensorToLoad connect sensor.electricalOut to load.input;
        connection loadToAmplifier connect load.output to amplifier.currentIn;
        connection amplifierToProcessor connect amplifier.voltageOut to processor.analogIn;

        perform action detectAndMeasureLight {
            first start;
            then merge continuousOperation;
            then action sense : sensor.convertLightToElectricity;
            then action amplify : amplifier.amplifySignal;
            then action process : processor.processSignal;
            then decide;
                if process.digitalValue > detectionThreshold then recordMeasurement;
                if process.digitalValue <= detectionThreshold then continuousOperation;
            action recordMeasurement {
                out measurement : Real;
            }
            then continuousOperation;
        }
    }

    requirement <'REQ-001'> primaryFunction {
        doc /* The optical detection system shall convert incident optical signals
             * into measurable electrical signals for detection, measurement, and
             * analysis applications.
             */
        subject system : OpticalDetectionSystem;
    }

    requirement <'REQ-002'> responsivityRequirement {
        doc /* The photodiode shall have a responsivity of at least 0.5 A/W
             * to ensure adequate sensitivity to incident light.
             */
        subject photodiode :>> OpticalDetectionSystem::sensor;
        assert constraint {
            photodiode.responsivity >= 0.5
        }
    }

    requirement <'REQ-003'> responseTimeRequirement {
        doc /* The photodiode response time shall be less than 20 nanoseconds
             * to enable high-speed detection applications.
             */
        subject photodiode :>> OpticalDetectionSystem::sensor;
        assert constraint {
            photodiode.responseTime < 20.0e-9 [SI::s]
        }
    }

    requirement <'REQ-004'> darkCurrentRequirement {
        doc /* The photodiode dark current shall be less than 1 nanoampere
             * to minimize noise in low-light conditions.
             */
        subject photodiode :>> OpticalDetectionSystem::sensor;
        assert constraint {
            photodiode.darkCurrent < 1.0e-9 [SI::A]
        }
    }

    requirement <'REQ-005'> amplificationRequirement {
        doc /* The transimpedance amplifier shall provide a minimum gain of 1e5
             * to ensure adequate signal strength for processing.
             */
        subject amplifier :>> OpticalDetectionSystem::amplifier;
        assert constraint {
            amplifier.gain >= 1.0e5
        }
    }

    requirement <'REQ-006'> processingResolutionRequirement {
        doc /* The signal processor shall have a resolution of at least 10 bits
             * to provide sufficient measurement precision.
             */
        subject processor :>> OpticalDetectionSystem::processor;
        assert constraint {
            processor.resolution >= 10.0
        }
    }

    requirement <'REQ-007'> detectionThresholdRequirement {
        doc /* The system shall detect optical signals with intensity above
             * the configured detection threshold.
             */
        subject system : OpticalDetectionSystem;
        assert constraint {
            system.opticalInput.light.intensity > system.detectionThreshold implies
            system.sensor.electricalOut.signal.current > system.sensor.darkCurrent
        }
    }

    part detectionSystemInstance : OpticalDetectionSystem {
        attribute :>> detectionThreshold = 50.0;
        attribute :>> operatingTemperature = 298.15 [SI::K];
        attribute :>> maxInputIntensity = 10000.0;
    }

    satisfy primaryFunction by detectionSystemInstance;
    satisfy responsivityRequirement by detectionSystemInstance.sensor;
    satisfy responseTimeRequirement by detectionSystemInstance.sensor;
    satisfy darkCurrentRequirement by detectionSystemInstance.sensor;
    satisfy amplificationRequirement by detectionSystemInstance.amplifier;
    satisfy processingResolutionRequirement by detectionSystemInstance.processor;
    satisfy detectionThresholdRequirement by detectionSystemInstance;
}
