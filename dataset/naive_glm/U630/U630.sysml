package RadiometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value type Length :> Real { unit "mm"; }
    value type Diameter :> Real { unit "mm"; }
    value type RadianceValue :> Real { unit "W/(m^2 sr)"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Temperature :> Real { unit "K"; }
    value type TimeStamp :> Real { unit "s"; }
    value type Uncertainty :> Real { unit "W/(m^2 sr)"; }
    value type PixelCount :> Integer { unit "1"; }
    value type QuantumEfficiency :> Real { unit "1"; }
    value type NoiseLevel :> Real { unit "e-"; }
    value type Gain :> Real { unit "V/V"; }

    item def Photon;
    item def LightFlux;
    item def RawSignal;
    item def ConditionedSignal;
    item def DigitalSample;
    item def ControlCommand {
        attribute kind: String;
        attribute parameter: Real = 0.0;
    }
    item def StatusReport {
        attribute state: String;
        attribute health: String;
    }
    item def RadianceResult {
        attribute radiance: RadianceValue;
        attribute timeStamp: TimeStamp;
        attribute uncertainty: Uncertainty;
    }

    port def OpticalInputPort {
        in item photons: Photon;
    }
    port def ControlPort {
        in item command: ControlCommand;
        out item status: StatusReport;
    }
    port def DataOutputPort {
        out item result: RadianceResult;
    }
    port def OpticalSignalPort {
        out item flux: LightFlux;
    }
    port def ElectricalSignalPort {
        out item signal: RawSignal;
    }
    port def ConditionedSignalPort {
        out item signal: ConditionedSignal;
    }
    port def DigitalDataPort {
        out item sample: DigitalSample;
    }

    requirement def MeasurementAccuracyRequirement {
        doc "The system shall measure radiance with high accuracy."
        attribute maxUncertainty: Uncertainty = 0.5 [W/(m^2 sr)];
        subject radiometer: Radiometer;
        require { radiometer.measurementUncertainty <= maxUncertainty }
    }

    requirement def DetectorPerformanceRequirement {
        doc "The detector shall exhibit high quantum efficiency and low noise."
        attribute minQuantumEfficiency: QuantumEfficiency = 0.85;
        attribute maxReadNoise: NoiseLevel = 10 [e-];
        subject detector: FocalPlaneArray;
        require { detector.quantumEfficiency >= minQuantumEfficiency }
        require { detector.readNoise <= maxReadNoise }
    }

    requirement def ApertureRequirement {
        doc "The primary mirror shall have a diameter of at least 250 mm."
        attribute primaryDiameter: Diameter = 250 [mm];
        subject primary: PrimaryMirror;
        require { primary.diameter >= primaryDiameter }
    }

    requirement def ResolutionRequirement {
        doc "The focal plane array shall provide 4096 pixels."
        attribute pixelCount: PixelCount = 4096 [1];
        subject detector: FocalPlaneArray;
        require { detector.pixelCount == pixelCount }
    }

    part def PrimaryMirror {
        attribute diameter: Diameter = 250 [mm];
        attribute focalLength: Length = 600 [mm];
        port in incomingFlux: OpticalSignalPort;
        port out reflectedFlux: OpticalSignalPort;
        action def Reflect {
            in item incoming: LightFlux;
            out item reflected: LightFlux;
        }
        satisfy ApertureRequirement;
    }

    part def SecondaryMirror {
        attribute diameter: Diameter = 75 [mm];
        attribute obstructionRatio: Real = 0.30;
        port in incomingFlux: OpticalSignalPort;
        port out reflectedFlux: OpticalSignalPort;
        action def Reflect {
            in item incoming: LightFlux;
            out item reflected: LightFlux;
        }
    }

    part def RefractiveCorrector {
        attribute lensCount: Integer = 4;
        attribute correctionBand: String = "VIS-NIR";
        port in incomingFlux: OpticalSignalPort;
        port out correctedFlux: OpticalSignalPort;
        action def Correct {
            in item incoming: LightFlux;
            out item corrected: LightFlux;
        }
    }

    part def OpticalAssembly {
        part primary: PrimaryMirror;
        part secondary: SecondaryMirror;
        part corrector: RefractiveCorrector;
        port in opticalInput: OpticalInputPort;
        port out opticalOutput: OpticalSignalPort;
        connect primary.reflectedFlux to secondary.incomingFlux;
        connect secondary.reflectedFlux to corrector.incomingFlux;
        connect corrector.correctedFlux to opticalOutput;
    }

    part def FocalPlaneArray {
        attribute pixelCount: PixelCount = 4096 [1];
        attribute quantumEfficiency: QuantumEfficiency = 0.90;
        attribute readNoise: NoiseLevel = 5 [e-];
        attribute darkCurrent: Current = 0.0000001 [A];
        attribute operatingTemperature: Temperature = 220 [K];
        port in incomingFlux: OpticalSignalPort;
        port out rawSignal: ElectricalSignalPort;
        action def Convert {
            in item flux: LightFlux;
            out item signal: RawSignal;
        }
        satisfy DetectorPerformanceRequirement;
        satisfy ResolutionRequirement;
    }

    part def SignalConditioner {
        attribute gain: Gain = 1000 [V/V];
        attribute bandwidth: Frequency = 100000 [Hz];
        attribute noiseFloor: Voltage = 0.000001 [V];
        port in rawSignal: ElectricalSignalPort;
        port out conditionedSignal: ConditionedSignalPort;
        action def AmplifyAndFilter {
            in item raw: RawSignal;
            out item conditioned: ConditionedSignal;
        }
    }

    part def DataProcessor {
        attribute calibrationCoefficients: Array(Real, 2) = (1.0, 0.0);
        attribute processingLatency: TimeStamp = 0.05 [s];
        port in conditionedSignal: ConditionedSignalPort;
        port out digitalSample: DigitalDataPort;
        port out dataOutput: DataOutputPort;
        action def ComputeRadiance {
            in item conditioned: ConditionedSignal;
            out item result: RadianceResult;
        }
    }

    part def Radiometer {
        attribute measurementUncertainty: Uncertainty = 0.3 [W/(m^2 sr)];
        attribute serialNumber: String = "RAD-2024-001";

        port in opticalInput: OpticalInputPort;
        port in controlInput: ControlPort;
        port out dataOutput: DataOutputPort;

        part optics: OpticalAssembly;
        part detector: FocalPlaneArray;
        part conditioner: SignalConditioner;
        part processor: DataProcessor;

        connect opticalInput to optics.opticalInput;
        connect optics.opticalOutput to detector.incomingFlux;
        connect detector.rawSignal to conditioner.rawSignal;
        connect conditioner.conditionedSignal to processor.conditionedSignal;
        connect processor.dataOutput to dataOutput;

        satisfy MeasurementAccuracyRequirement;

        attribute calibrationComplete: Boolean = false;
        attribute acquisitionComplete: Boolean = false;
        attribute processingComplete: Boolean = false;
        attribute calibrationError: Boolean = false;
        attribute processingError: Boolean = false;

        state def Lifecycle {
            entry; then standby;
            state standby {
                entry { controlInput.status = StatusReport { state = "standby", health = "ok" }; }
            }
            state calibrating {
                entry { controlInput.status = StatusReport { state = "calibrating", health = "ok" }; }
            }
            state acquiring {
                entry { controlInput.status = StatusReport { state = "acquiring", health = "ok" }; }
            }
            state processing {
                entry { controlInput.status = StatusReport { state = "processing", health = "ok" }; }
            }
            state fault {
                entry { controlInput.status = StatusReport { state = "fault", health = "error" }; }
            }

            transition standby to calibrating
                when controlInput.command.kind == "calibrate";
            transition calibrating to standby
                when calibrationComplete;
            transition standby to acquiring
                when controlInput.command.kind == "acquire";
            transition acquiring to processing
                when acquisitionComplete;
            transition processing to standby
                when processingComplete;
            transition calibrating to fault
                when calibrationError;
            transition processing to fault
                when processingError;
            transition fault to standby
                when controlInput.command.kind == "reset";
        }

        exhibit Lifecycle;
    }
}
