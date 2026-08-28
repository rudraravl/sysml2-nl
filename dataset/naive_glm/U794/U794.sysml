package OpticalFiberCommunicationSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // Value Types
    value type Wavelength :> Real { unit = "nm"; }
    value type Distance :> Length;
    value type DataRate :> Real { unit = "GHz"; }
    value type BitErrorRate :> Real; 
    value type RefractiveIndex :> Real;
    value type Attenuation :> Real { unit = "dB/km"; }
    value type Dispersion :> Real { unit = "ps/(nm*km)"; }
    value type Current :> Real { unit = "A"; }
    value type Voltage :> Real { unit = "V"; }
    value type Power :> Real { unit = "W"; }

    // Items
    item ElectricalDataSignal {
        attribute bitRate : DataRate;
        attribute voltage : Voltage;
        attribute bitErrorRate : BitErrorRate;
    }
    item OpticalSignal {
        attribute wavelength : Wavelength;
        attribute power : Power;
    }

    // Ports
    port def ElectricalInputPort {
        out item electricalSignal : ElectricalDataSignal;
    }
    port def ElectricalOutputPort {
        out item electricalSignal : ElectricalDataSignal;
    }
    port def OpticalOutputPort {
        out item opticalSignal : OpticalSignal;
    }
    port def OpticalInputPort {
        in item opticalSignal : OpticalSignal;
    }

    // Parts
    part def LaserDiode {
        attribute wavelength : Wavelength = 1550 [nm];
        out opticalPort : OpticalOutputPort;
        
        action def generateLight {
            out light : OpticalSignal;
        }
    }

    part def OpticalModulator {
        in electricalPort : ElectricalInputPort;
        in lightInputPort : OpticalInputPort;
        out modulatedOutputPort : OpticalOutputPort;
        
        action def modulateSignal {
            in electricalSignal : ElectricalDataSignal;
            in lightSignal : OpticalSignal;
            out modulatedLight : OpticalSignal;
        }
    }

    part def OpticalTransmitter {
        in electricalInput : ElectricalInputPort;
        out opticalOutput : OpticalOutputPort;
        
        part laserDiode : LaserDiode;
        part modulator : OpticalModulator;
        
        connection electricalToModulator connect electricalInput to modulator.electricalPort;
        connection laserToModulator connect laserDiode.opticalPort to modulator.lightInputPort;
        connection modulatorToOutput connect modulator.modulatedOutputPort to opticalOutput;
    }

    part def GlassCore {
        attribute refractiveIndex : RefractiveIndex = 1.468;
        attribute diameter : Distance = 0.000009 [m];
    }

    part def Cladding {
        attribute refractiveIndex : RefractiveIndex = 1.451;
        attribute diameter : Distance = 0.000125 [m];
    }

    part def OpticalFiber {
        in opticalInput : OpticalInputPort;
        out opticalOutput : OpticalOutputPort;
        
        attribute length : Distance = 20000 [m];
        attribute attenuation : Attenuation = 0.2 [dB/km];
        attribute dispersion : Dispersion = 17 [ps/(nm*km)];
        
        part core : GlassCore;
        part cladding : Cladding;
        
        action def propagateLight {
            in inputLight : OpticalSignal;
            out outputLight : OpticalSignal;
        }
    }

    part def Photodetector {
        in opticalInput : OpticalInputPort;
        out electricalOutput : ElectricalOutputPort;
        
        action def convertToCurrent {
            in light : OpticalSignal;
            out current : ElectricalDataSignal;
        }
    }

    part def SignalAmplifier {
        in electricalInput : ElectricalInputPort;
        out electricalOutput : ElectricalOutputPort;
        
        action def amplifySignal {
            in weakSignal : ElectricalDataSignal;
            out amplifiedSignal : ElectricalDataSignal;
        }
    }

    part def OpticalReceiver {
        in opticalInput : OpticalInputPort;
        out electricalOutput : ElectricalOutputPort;
        
        part photodetector : Photodetector;
        part amplifier : SignalAmplifier;
        
        connection opticalToPhotodetector connect opticalInput to photodetector.opticalInput;
        connection photodetectorToAmplifier connect photodetector.electricalOutput to amplifier.electricalInput;
        connection amplifierToOutput connect amplifier.electricalOutput to electricalOutput;
    }

    part def OpticalFiberCommunicationSystem {
        in systemInput : ElectricalInputPort;
        out systemOutput : ElectricalOutputPort;
        
        attribute inputBitRate : DataRate;
        attribute outputBitErrorRate : BitErrorRate;
        attribute signalQuality : Real; // 0.0 to 1.0
        attribute operationalStatus : String;
        
        part transmitter : OpticalTransmitter;
        part fiber : OpticalFiber;
        part receiver : OpticalReceiver;
        
        connection inputToTransmitter connect systemInput to transmitter.electricalInput;
        connection transmitterToFiber connect transmitter.opticalOutput to fiber.opticalInput;
        connection fiberToReceiver connect fiber.opticalOutput to receiver.opticalInput;
        connection receiverToOutput connect receiver.electricalOutput to systemOutput;
        
        state machine def SystemStates {
            initial start;
            state idle;
            state active {
                state normal;
                state degraded;
                
                transition normal_to_degraded first normal if signalQuality < 0.5 then degraded;
                transition degraded_to_normal first degraded if signalQuality >= 0.5 then normal;
            }
            
            transition idle_to_active first idle if inputBitRate > 0 then active;
            transition active_to_idle first active if inputBitRate == 0 then idle;
        }
    }

    // Requirements
    requirement def HighSpeedTransmission {
        attribute minDataRate : DataRate = 10 [GHz];
        subject system : OpticalFiberCommunicationSystem;
        require system.inputBitRate >= minDataRate;
    }

    requirement def LowErrorRate {
        attribute maxBitErrorRate : BitErrorRate = 1e-12;
        subject system : OpticalFiberCommunicationSystem;
        require system.outputBitErrorRate < maxBitErrorRate;
    }

    requirement def HarshEnvironmentReliability {
        attribute operatingTempRange : String = "-40C to +85C";
        subject system : OpticalFiberCommunicationSystem;
        require system.operationalStatus == "reliable";
    }

    requirement def SystemRequirements {
        subject system : OpticalFiberCommunicationSystem;
        require highSpeed : HighSpeedTransmission;
        require lowError : LowErrorRate;
        require reliability : HarshEnvironmentReliability;
    }
}
