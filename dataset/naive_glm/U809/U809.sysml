package OpticalDetectionSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ===== Value Types with Units =====
    value def LightIntensity :> Real { unit "W/m²"; }
    value def Irradiance :> Real { unit "W/m²"; }
    value def Photocurrent :> Real { unit "A"; }
    value def SignalVoltage :> Real { unit "V"; }
    value def Resistance :> Real { unit "Ω"; }
    value def Capacitance :> Real { unit "F"; }
    value def Gain :> Real;
    value def SamplingRate :> Real { unit "Hz"; }
    value def TimeConstant :> Real { unit "s"; }
    value def DigitalCode :> Integer;
    value def DetectionThreshold :> LightIntensity;
    value def BitDepth :> Integer;

    // ===== Item Definitions =====
    item def Light {
        attribute intensity : LightIntensity;
    }
    item def PhotodiodeCurrentItem {
        attribute value : Photocurrent;
    }
    item def AmplifiedVoltageItem {
        attribute value : SignalVoltage;
    }
    item def DigitalSampleItem {
        attribute code : DigitalCode;
        attribute valid : Boolean;
    }
    item def DetectionEvent {
        attribute timestamp : Real;
        attribute measuredIntensity : LightIntensity;
        attribute digitalCode : DigitalCode;
    }

    // ===== Port Definitions =====
    port def OpticalInPort {
        in light : Light;
    }
    port def CurrentOutPort {
        out current : PhotodiodeCurrentItem;
    }
    port def CurrentInPort {
        in current : PhotodiodeCurrentItem;
    }
    port def VoltageOutPort {
        out voltage : AmplifiedVoltageItem;
    }
    port def VoltageInPort {
        in voltage : AmplifiedVoltageItem;
    }
    port def DigitalOutPort {
        out sample : DigitalSampleItem;
    }
    port def DigitalInPort {
        in sample : DigitalSampleItem;
    }

    // ===== Photodiode Sensor =====
    part def PhotodiodeSensor {
        attribute responsivity : Real = 0.55 [A/W];
        attribute darkCurrent : Photocurrent = 1.0e-12 [A];
        attribute responseTime : TimeConstant = 5.0e-9 [s];
        attribute activeArea : Real = 1.0e-6 [m²];
        attribute spectralRangeMin : Real = 400e-9 [m];
        attribute spectralRangeMax : Real = 1100e-9 [m];

        port opticalIn : OpticalInPort;
        port currentOut : CurrentOutPort;

        action def SenseLight {
            in incidentLight : Light;
            out generatedCurrent : PhotocurrentItem;
        }

        perform action sense : SenseLight {
            in incidentLight = opticalIn.light;
            out generatedCurrent = currentOut.current;
        }
    }

    // ===== Load Resistor =====
    part def LoadResistor {
        attribute resistance : Resistance = 50e3 [Ω];
        attribute tolerance : Real = 0.01;
        attribute maxPower : Real = 0.25 [W];

        port currentIn : CurrentInPort;
        port currentOut : CurrentOutPort;

        action def DevelopBias {
            in current : PhotocurrentCurrentItem;
            out biasCurrent : PhotocurrentItem;
        }
    }

    // ===== Transimpedance Amplifier =====
    part def TransimpedanceAmplifier {
        attribute transimpedanceGain : Resistance = 1.0e6 [Ω];
        attribute bandwidth : Real = 1.0e6 [Hz];
        attribute inputOffset : SignalVoltage = 1.0e-6 [V];
        attribute noiseDensity : Real = 5.0e-15 [A/√Hz];

        port currentIn : CurrentInPort;
        port voltageOut : VoltageOutPort;

        action def ConvertCurrentToVoltage {
            in inputCurrent : PhotocurrentItem;
            out outputVoltage : AmplifiedVoltageItem;
        }

        perform action amplify : ConvertCurrentToVoltage {
            in inputCurrent = currentIn.current;
            out outputVoltage = voltageOut.voltage;
        }
    }

    // ===== Signal Processor =====
    part def SignalProcessor {
        attribute samplingRate : SamplingRate = 100e3 [Hz];
        attribute bitDepth : BitDepth = 12;
        attribute fullScaleVoltage : SignalVoltage = 5.0 [V];
        attribute filterCutoff : Real = 50e3 [Hz];
        attribute detectionThreshold : DetectionThreshold = 1.0e-6 [W/m²];

        port voltageIn : VoltageInPort;
        port digitalOut : DigitalOutPort;

        action def FilterNoise {
            in rawVoltage : AmplifiedVoltageItem;
            out filteredVoltage : AmplifiedVoltageItem;
        }

        action def SampleAndConvert {
            in filteredVoltage : AmplifiedVoltageItem;
            out digitalCode : DigitalSampleItem;
        }

        perform action filter : FilterNoise {
            in rawVoltage = voltageIn.voltage;
            out filteredVoltage;
        }

        perform action convert : SampleAndConvert {
            in filteredVoltage = filter.filteredVoltage;
            out digitalCode = digitalOut.sample;
        }
    }

    // ===== System Controller (Behavior) =====
    part def SystemController {
        attribute detectionThreshold : DetectionThreshold = 1.0e-6 [W/m²];
        attribute recordedEvents : DetectionEvent[0..*];

        port digitalIn : DigitalInPort;

        state machine def DetectionOperation {
            entry; then Monitoring;

            state Monitoring {
                entry;
                transition monitor_to_triggered
                    first Monitoring
                    if digitalIn.sample.valid & (digitalIn.sample.code > thresholdCode)
                    then Triggered;
            }

            state Triggered {
                entry;
                do recordEvent;
                then Monitoring;
            }
        }

        perform state detection : DetectionOperation;
    }

    // ===== Top-Level System =====
    part def OpticalDetectionSystem {
        attribute systemId : String;
        attribute detectionThreshold : DetectionThreshold = 1.0e-6 [W/m²];
        attribute operational : Boolean = true;

        port externalOpticalIn : OpticalInPort;
        port eventOut : DigitalOutPort;

        part photodiode : PhotodiodeSensor {
            port opticalIn : OpticalInPort;
            port currentOut : CurrentOutPort;
        }
        part loadResistor : LoadResistor {
            port currentIn : CurrentInPort;
            port currentOut : CurrentOutPort;
        }
        part amplifier : TransimpedanceAmplifier {
            port currentIn : CurrentInPort;
            port voltageOut : VoltageOutPort;
        }
        part processor : SignalProcessor {
            port voltageIn : VoltageInPort;
            port digitalOut : DigitalOutPort;
        }
        part controller : SystemController {
            port digitalIn : DigitalInPort;
        }

        connection def LightPath {
            end source : OpticalInPort;
            end target : OpticalInPort;
        }
        connection def CurrentPath {
            end source : CurrentOutPort;
            end target : CurrentInPort;
        }
        connection def VoltagePath {
            end source : VoltageOutPort;
            end target : VoltageInPort;
        }
        connection def DigitalPath {
            end source : DigitalOutPort;
            end target : DigitalInPort;
        }

        connection lightIn : LightPath connect externalOpticalIn to photodiode.opticalIn;
        connection currentLink1 : CurrentPath connect photodiode.currentOut to loadResistor.currentIn;
        connection currentLink2 : CurrentPath connect loadResistor.currentOut to amplifier.currentIn;
        connection voltageLink : VoltagePath connect amplifier.voltageOut to processor.voltageIn;
        connection digitalLink : DigitalPath connect processor.digitalOut to controller.digitalIn;
    }

    // ===== Requirements =====
    requirement def DetectLightAboveThreshold {
        subject system : OpticalDetectionSystem;
        attribute threshold : DetectionThreshold = 1.0e-6 [W/m²];
        objective {
            doc "The system shall detect incident light whose intensity exceeds the configured detection threshold and produce a corresponding digital measurement."
        }
        require system.controller.recordedEvents->size() >= 1
            if system.photodiode.opticalIn.light.intensity > threshold;
    }

    requirement def LowDarkCurrent {
        subject sensor : PhotodiodeSensor;
        attribute maxDarkCurrent : Photocurrent = 5.0e-12 [A];
        objective {
            doc "The photodiode sensor shall exhibit a dark current no greater than the specified maximum to ensure sensitivity in low-light conditions."
        }
        require sensor.darkCurrent <= maxDarkCurrent;
    }

    requirement def FastResponseTime {
        subject sensor : PhotodiodeSensor;
        attribute maxResponseTime : TimeConstant = 1.0e-7 [s];
        objective {
            doc "The photodiode sensor shall respond to incident light changes within the specified response time."
        }
        require sensor.responseTime <= maxResponseTime;
    }

    requirement def AmplifierGainRequirement {
        subject amp : TransimpedanceAmplifier;
        attribute minGain : Resistance = 1.0e5 [Ω];
        objective {
            doc "The transimpedance amplifier shall provide sufficient gain to convert the minimum expected photocurrent into a measurable voltage."
        }
        require amp.transimpedanceGain >= minGain;
    }

    requirement def DigitalResolutionRequirement {
        subject proc : SignalProcessor;
        attribute requiredBits : BitDepth = 12;
        objective {
            doc "The signal processor shall digitize the amplified voltage into a 12-bit digital code."
        }
        require proc.bitDepth >= requiredBits;
    }

    requirement def ContinuousMonitoringRequirement {
        subject system : OpticalDetectionSystem;
        objective {
            doc "The system shall continuously monitor for incident light while operational."
        }
        require system.operational == true
            implies system.controller.detection.Monitoring.active;
    }

    // ===== Verification =====
    verification def VerifyThresholdDetection {
        subject system : OpticalDetectionSystem;
        objective {
            doc "Verify that the system records a detection event when light intensity exceeds the threshold."
        }
        return verdict : VerdictKind;
    }

    verification def VerifyDarkCurrent {
        subject sensor : PhotodiodeSensor;
        objective {
            doc "Measure the photodiode dark current and confirm it is within specification."
        }
        return verdict : VerdictKind;
    }

    verification def VerifyDigitalResolution {
        subject proc : SignalProcessor;
        objective {
            doc "Confirm the signal processor produces 12-bit digital codes across the full-scale input range."
        }
        return verdict : VerdictKind;
    }
}
