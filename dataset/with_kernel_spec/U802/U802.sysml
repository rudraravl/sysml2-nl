package ParticleDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Quantities::ScalarQuantityValue;

    attribute def EnergyValue :> ScalarQuantityValue;
    attribute def TimeValue :> ScalarQuantityValue;
    attribute def VoltageValue :> ScalarQuantityValue;
    attribute def LightIntensityValue :> ScalarQuantityValue;
    attribute def DigitalValue :> ScalarQuantityValue;
    attribute def EventRateValue :> ScalarQuantityValue;

    item def Particle {
        attribute energy : EnergyValue;
    }
    item def LightFlash {
        attribute intensity : LightIntensityValue;
    }
    item def ElectricalPulse {
        attribute amplitude : VoltageValue;
    }
    item def DigitalSignal {
        attribute value : DigitalValue;
    }
    item def ParticleEvent {
        attribute energy : EnergyValue;
        attribute timestamp : TimeValue;
    }

    attribute def CalibrateSignal;
    attribute def CalibrationComplete;
    attribute def StopSignal;
    attribute def StartAcquisition;
    attribute def SystemError;
    attribute def ResetSystem;

    port def ParticleOutPort {
        out particle : Particle;
    }
    port def ParticleInPort {
        in particle : Particle;
    }
    port def LightOutPort {
        out flash : LightFlash;
    }
    port def LightInPort {
        in flash : LightFlash;
    }
    port def PulseOutPort {
        out pulse : ElectricalPulse;
    }
    port def PulseInPort {
        in pulse : ElectricalPulse;
    }
    port def DigitalOutPort {
        out signal : DigitalSignal;
    }
    port def DigitalInPort {
        in signal : DigitalSignal;
    }
    port def HVOutPort {
        out voltage : VoltageValue;
    }
    port def HVInPort {
        in voltage : VoltageValue;
    }
    port def EventOutPort {
        out evt : ParticleEvent;
    }

    action def ConvertParticleToLight {
        in p : Particle;
        out f : LightFlash;
    }
    action def ConvertLightToPulse {
        in f : LightFlash;
        in hv : VoltageValue;
        out p : ElectricalPulse;
    }
    action def AmplifyPulse {
        in pIn : ElectricalPulse;
        out pOut : ElectricalPulse;
    }
    action def DigitizePulse {
        in p : ElectricalPulse;
        out d : DigitalSignal;
    }
    action def ProcessSignal {
        in d : DigitalSignal;
        out e : ParticleEvent;
    }

    action def ProcessParticleEvent {
        in particle : Particle;
        in highVoltage : VoltageValue;
        out evt : ParticleEvent;
        action scintillate : ConvertParticleToLight {
            in p = particle;
        }
        action photomultiply : ConvertLightToPulse {
            in f = scintillate.f;
            in hv = highVoltage;
        }
        action amplify : AmplifyPulse {
            in pIn = photomultiply.p;
        }
        action digitize : DigitizePulse {
            in p = amplify.pOut;
        }
        action acquire : ProcessSignal {
            in d = digitize.d;
            out e = evt;
        }
    }

    part def Scintillator {
        attribute material : String = "Sodium Iodide";
        port particleIn : ParticleInPort;
        port lightOut : LightOutPort;
        action convert : ConvertParticleToLight;
    }

    part def PhotomultiplierTube {
        attribute gain : Real = 1.0e6;
        port lightIn : LightInPort;
        port pulseOut : PulseOutPort;
        port hvIn : HVInPort;
        action convert : ConvertLightToPulse;
    }

    part def SignalAmplifier {
        attribute gain : Real = 100.0;
        port pulseIn : PulseInPort;
        port pulseOut : PulseOutPort;
        action amplify : AmplifyPulse;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 14;
        port pulseIn : PulseInPort;
        port digitalOut : DigitalOutPort;
        action digitize : DigitizePulse;
    }

    state machine def AcquisitionState {
        first start;
        then Idle;
        state Idle;
        state Calibrating;
        state Acquiring;
        state Fault;
        transition from Idle to Calibrating on CalibrateSignal;
        transition from Idle to Acquiring on StartAcquisition;
        transition from Calibrating to Acquiring on CalibrationComplete;
        transition from Calibrating to Fault on SystemError;
        transition from Acquiring to Idle on StopSignal;
        transition from Acquiring to Fault on SystemError;
        transition from Fault to Idle on ResetSystem;
    }

    part def DataAcquisitionSystem {
        attribute maxEventRate : EventRateValue = 1000000 [1/s];
        port digitalIn : DigitalInPort;
        port evtOut : EventOutPort;
        action process : ProcessSignal;
        state machine acquisitionState : AcquisitionState;
    }

    part def HVPowerSupply {
        port hvOut : HVOutPort;
        attribute outputVoltage : VoltageValue = 1500 [V];
    }

    part def CalibrationSource {
        attribute isotope : String = "Cesium-137";
        attribute activity : EventRateValue = 3.7e4 [1/s];
        port particleOut : ParticleOutPort;
    }

    part def DetectorSystem {
        part scintillator : Scintillator;
        part pmt : PhotomultiplierTube;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part daq : DataAcquisitionSystem;
        part hvSupply : HVPowerSupply;
        part calibSource : CalibrationSource;

        port particleIn : ParticleInPort;
        port evtOut : EventOutPort;

        connect particleIn to scintillator.particleIn;
        connect calibSource.particleOut to scintillator.particleIn;
        connect scintillator.lightOut to pmt.lightIn;
        connect pmt.pulseOut to amplifier.pulseIn;
        connect amplifier.pulseOut to adc.pulseIn;
        connect adc.digitalOut to daq.digitalIn;
        connect hvSupply.hvOut to pmt.hvIn;
        connect daq.evtOut to evtOut;
    }

    requirement def DetectorPerformanceRequirements {
        doc
        /*
         * Requirements for the high-precision particle detector system.
         */
        requirement detectionEfficiency {
            doc /* The system shall have a detection efficiency greater than 95%. */
            attribute efficiency : Real;
            constraint { efficiency > 0.95 }
        }
        requirement energyResolution {
            doc /* The system shall have an energy resolution better than 7% at 662 keV. */
            attribute resolution : Real;
            constraint { resolution < 0.07 }
        }
        requirement timeResolution {
            doc /* The system shall have a time resolution better than 1 nanosecond. */
            attribute resolution : TimeValue;
            constraint { resolution < 1 [ns] }
        }
        requirement eventRate {
            doc /* The system shall handle up to 1,000,000 events per second. */
            attribute maxRate : EventRateValue;
            constraint { maxRate >= 1000000 [1/s] }
        }
        requirement reliability {
            doc /* The system shall run continuously for 72 hours or more without failure. */
            attribute duration : TimeValue;
            constraint { duration >= 72 [h] }
        }
    }
}
