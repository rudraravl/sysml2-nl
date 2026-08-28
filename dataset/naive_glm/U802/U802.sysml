package ParticleDetectorSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type EnergyKeV :> Real { unit "keV"; }
    value type EnergyMeV :> Real { unit "MeV"; }
    value type TimeNs :> Real { unit "ns"; }
    value type TimeS :> Real { unit "s"; }
    value type VoltageV :> Real { unit "V"; }
    value type CurrentMicroA :> Real { unit "uA"; }
    value type RateHz :> Real { unit "Hz"; }
    value type LengthMm :> Real { unit "mm"; }
    value type Dimensionless :> Real;

    // ===== Item Definitions =====
    item def Particle {
        attribute energy : EnergyKeV;
        attribute particleType : String;
        attribute positionX : LengthMm;
        attribute positionY : LengthMm;
    }

    item def ScintillationPhoton {
        attribute wavelength : LengthMm;
        attribute count : Integer;
        attribute arrivalTime : TimeNs;
    }

    item def ElectricalPulse {
        attribute amplitude : VoltageV;
        attribute width : TimeNs;
        attribute charge : Real;
        attribute riseTime : TimeNs;
    }

    item def DigitalSample {
        attribute value : Integer;
        attribute timestamp : TimeNs;
        attribute channel : Integer;
    }

    item def ParticleEvent {
        attribute eventId : Integer;
        attribute energy : EnergyKeV;
        attribute timestamp : TimeNs;
        attribute positionX : LengthMm;
        attribute positionY : LengthMm;
        attribute quality : Dimensionless;
    }

    // ===== Port Definitions =====
    port def ParticleInPort {
        in item particle : Particle;
    }

    port def ParticleOutPort {
        out item particle : Particle;
    }

    port def LightOutPort {
        out item photons : ScintillationPhoton;
    }

    port def LightInPort {
        in item photons : ScintillationPhoton;
    }

    port def PulseOutPort {
        out item pulse : ElectricalPulse;
    }

    port def PulseInPort {
        in item pulse : ElectricalPulse;
    }

    port def DigitalOutPort {
        out item sample : DigitalSample;
    }

    port def DigitalInPort {
        in item sample : DigitalSample;
    }

    port def HVOutputPort {
        out voltage : VoltageV;
        out current : CurrentMicroA;
    }

    port def HVInputPort {
        in voltage : VoltageV;
        in current : CurrentMicroA;
    }

    // ===== Action Definitions =====
    action def Scintillate {
        in particle : Particle;
        out photons : ScintillationPhoton;
        attribute lightYield : Real = 38000;
    }

    action def PhotoMultiply {
        in photons : ScintillationPhoton;
        out pulse : ElectricalPulse;
        attribute gain : Real = 1.0e6;
    }

    action def AmplifyAndShape {
        in pulseIn : ElectricalPulse;
        out pulseOut : ElectricalPulse;
        attribute gain : Real = 100.0;
        attribute shapingTime : TimeNs = 100.0;
    }

    action def Digitize {
        in pulse : ElectricalPulse;
        out sample : DigitalSample;
        attribute resolutionBits : Integer = 14;
        attribute samplingRate : RateHz = 250.0e6;
        attribute dynamicRange : VoltageV = 2.0;
    }

    action def ReconstructEvent {
        in samples : DigitalSample[0..*];
        out event : ParticleEvent;
    }

    action def ApplyCalibration {
        in referenceEnergy : EnergyKeV;
        out calibrationFactor : Dimensionless;
    }

    // ===== Part Definitions =====
    part def Scintillator {
        attribute material : String = "Sodium Iodide (NaI:Tl)";
        attribute lightYield : Real = 38000;
        attribute decayTime : TimeNs = 230.0;
        port particleIn : ParticleInPort;
        port lightOut : LightOutPort;

        perform scintillate : Scintillate;
    }

    part def PhotomultiplierTube {
        attribute serialNumber : String;
        attribute gain : Real = 1.0e6;
        attribute operatingVoltage : VoltageV = 1000.0;
        attribute darkCurrent : CurrentMicroA = 1.0;
        port lightIn : LightInPort;
        port pulseOut : PulseOutPort;
        port hvIn : HVInputPort;

        perform photoMultiply : PhotoMultiply;
    }

    part def SignalAmplifier {
        attribute gain : Real = 100.0;
        attribute bandwidth : RateHz = 100.0e6;
        attribute noiseLevel : VoltageV = 0.001;
        port pulseIn : PulseInPort;
        port pulseOut : PulseOutPort;

        perform amplify : AmplifyAndShape;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 14;
        attribute samplingRate : RateHz = 250.0e6;
        attribute dynamicRange : VoltageV = 2.0;
        attribute channels : Integer = 1;
        port pulseIn : PulseInPort;
        port digitalOut : DigitalOutPort;

        perform digitize : Digitize;
    }

    part def DataAcquisitionSystem {
        attribute maxEventRate : RateHz = 1.0e6;
        attribute bufferDepth : Integer = 65536;
        attribute processedEvents : Integer = 0;
        port digitalIn : DigitalInPort;
        port eventOut : DigitalOutPort;

        exhibit daqStateMachine : DAQStateMachine;
    }

    part def HighVoltagePowerSupply {
        attribute outputVoltage : VoltageV = 1000.0;
        attribute outputCurrent : CurrentMicroA = 100.0;
        attribute stability : Dimensionless = 0.001;
        attribute ripple : Dimensionless = 0.0005;
        port hvOut : HVOutputPort;
    }

    part def CalibrationSource {
        attribute isotope : String = "Cesium-137";
        attribute activity : RateHz = 1.0e5;
        attribute referenceEnergy : EnergyKeV = 662.0;
        attribute halfLifeYears : Real = 30.17;
        port particleOut : ParticleOutPort;
    }

    // ===== State Machine =====
    state def DAQStateMachine {
        in sample : DigitalSample;
        attribute bufferFull : Boolean = false;
        attribute processingComplete : Boolean = false;
        attribute calibrationRequested : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute resetRequested : Boolean = false;

        entry action initialize { }

        state Idle {
            entry action clearBuffer { }
        }
        state Acquiring {
            do action collectSamples { }
        }
        state Processing {
            do action reconstruct : ReconstructEvent;
        }
        state Calibrating {
            do action applyCalibration : ApplyCalibration;
        }
        state Error {
            entry action logError { }
        }

        transition first Idle -> Acquiring when sample.value > 0;
        transition Acquiring -> Processing when bufferFull;
        transition Processing -> Acquiring when processingComplete;
        transition Acquiring -> Calibrating when calibrationRequested;
        transition Calibrating -> Idle when calibrationComplete;
        transition Idle -> Error when faultDetected;
        transition Acquiring -> Error when faultDetected;
        transition Processing -> Error when faultDetected;
        transition Error -> Idle when resetRequested;
    }

    // ===== Top-level System =====
    part def ParticleDetector {
        attribute detectionEfficiency : Dimensionless = 0.98;
        attribute energyResolution : Dimensionless = 0.07;
        attribute timeResolution : TimeNs = 1.0;
        attribute maxEventRate : RateHz = 1.0e6;
        attribute continuousOperationDuration : TimeS = 259200.0;

        part scintillator : Scintillator;
        part pmt : PhotomultiplierTube;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part daq : DataAcquisitionSystem;
        part hvps : HighVoltagePowerSupply;
        part calibration : CalibrationSource;

        connection particleToScintillator connect calibration.particleOut to scintillator.particleIn;
        connection scintillatorToPMT connect scintillator.lightOut to pmt.lightIn;
        connection pmtToAmplifier connect pmt.pulseOut to amplifier.pulseIn;
        connection amplifierToADC connect amplifier.pulseOut to adc.pulseIn;
        connection adcToDAQ connect adc.digitalOut to daq.digitalIn;
        connection hvpsToPMT connect hvps.hvOut to pmt.hvIn;
    }

    // ===== Requirements =====
    requirement def DetectionEfficiencyRequirement {
        subject detector : ParticleDetector;
        attribute minEfficiency : Dimensionless = 0.95;
        require detector.detectionEfficiency >= minEfficiency;
    }

    requirement def EnergyResolutionRequirement {
        subject detector : ParticleDetector;
        attribute maxResolution : Dimensionless = 0.10;
        require detector.energyResolution <= maxResolution;
    }

    requirement def TimeResolutionRequirement {
        subject detector : ParticleDetector;
        attribute maxTimeResolution : TimeNs = 2.0;
        require detector.timeResolution <= maxTimeResolution;
    }

    requirement def EventRateRequirement {
        subject detector : ParticleDetector;
        attribute minRate : RateHz = 1.0e6;
        require detector.maxEventRate >= minRate;
    }

    requirement def ContinuousOperationRequirement {
        subject detector : ParticleDetector;
        attribute minDuration : TimeS = 259200.0;
        require detector.continuousOperationDuration >= minDuration;
    }

    requirement def CalibrationRequirement {
        subject detector : ParticleDetector;
        attribute referenceIsotope : String = "Cesium-137";
        attribute referenceEnergy : EnergyKeV = 662.0;
        require detector.calibration.isotope == referenceIsotope;
        require detector.calibration.referenceEnergy == referenceEnergy;
    }

    requirement def HVStabilityRequirement {
        subject supply : HighVoltagePowerSupply;
        attribute maxStability : Dimensionless = 0.005;
        require supply.stability <= maxStability;
    }

    requirement def ScintillatorMaterialRequirement {
        subject scintillator : Scintillator;
        attribute requiredMaterial : String = "Sodium Iodide (NaI:Tl)";
        require scintillator.material == requiredMaterial;
    }

    // ===== Verification =====
    verification def VerifyDetectionEfficiency {
        subject detector : ParticleDetector;
        objective {
            require detector.detectionEfficiency >= 0.95;
        }
    }

    verification def VerifyEventRate {
        subject detector : ParticleDetector;
        objective {
            require detector.maxEventRate >= 1.0e6;
        }
    }

    verification def VerifyContinuousOperation {
        subject detector : ParticleDetector;
        objective {
            require detector.continuousOperationDuration >= 259200.0;
        }
    }
}
