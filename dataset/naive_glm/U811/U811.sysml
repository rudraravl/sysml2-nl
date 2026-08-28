package PhotoelectricSensor {
    import ScalarValues::*;
    
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Length :> Real { unit 'nm'; }
    value def LightIntensity :> Real { unit 'W/m^2'; }
    
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    item def LightBeam {
        attribute wavelength : Length;
        attribute intensity : LightIntensity;
    }
    
    item def ElectricalSignal {
        attribute voltage : Voltage;
    }
    
    item def DetectionResult {
        attribute objectDetected : Boolean;
        attribute analogVoltage : Voltage;
    }
    
    port def PowerInPort {
        in power : ElectricalPower;
    }
    
    port def EmitterOpticalPort {
        out light : LightBeam;
    }
    
    port def DetectorOpticalPort {
        in light : LightBeam;
    }
    
    port def SensorOpticalPort {
        out emittedLight : LightBeam;
        in reflectedLight : LightBeam;
    }
    
    port def SignalOutPort {
        out signal : ElectricalSignal;
    }
    
    port def SignalInPort {
        in signal : ElectricalSignal;
    }
    
    port def OutputOutPort {
        out result : DetectionResult;
    }
    
    part def LightEmitter {
        port powerIn : PowerInPort;
        port lightOut : EmitterOpticalPort;
        
        attribute wavelength : Length = 850 [nm];
        attribute emittedIntensity : LightIntensity = 1.0 [W/m^2];
        
        action emitLight {
            in power : ElectricalPower;
            out light : LightBeam;
        }
    }
    
    part def Photodetector {
        port lightIn : DetectorOpticalPort;
        port signalOut : SignalOutPort;
        
        attribute sensitivity : Real = 0.5;
        
        action detectLight {
            in light : LightBeam;
            out signal : ElectricalSignal;
        }
    }
    
    part def SignalProcessor {
        port signalIn : SignalInPort;
        port powerIn : PowerInPort;
        port outputOut : OutputOutPort;
        
        attribute threshold : Voltage = 2.5 [V];
        attribute amplifiedVoltage : Voltage;
        
        action processSignal {
            in signal : ElectricalSignal;
            out result : DetectionResult;
        }
    }
    
    part def PhotoelectricSensorUnit {
        port powerIn : PowerInPort;
        port opticalPort : SensorOpticalPort;
        port outputOut : OutputOutPort;
        
        part emitter : LightEmitter;
        part detector : Photodetector;
        part processor : SignalProcessor;
        
        connection powerToEmitter connect powerIn to emitter.powerIn;
        connection powerToProcessor connect powerIn to processor.powerIn;
        
        connection emitLight connect emitter.lightOut.light to opticalPort.emittedLight;
        connection receiveLight connect opticalPort.reflectedLight to detector.lightIn.light;
        
        connection rawSignal connect detector.signalOut to processor.signalIn;
        connection finalOutput connect processor.outputOut to outputOut;
        
        state def SensorStates {
            initial idle;
            active {
                initial detecting;
                detected;
                
                transition detecting_to_detected 
                    first detecting 
                    when outputOut.result.analogVoltage > processor.threshold 
                    then detected;
                    
                transition detected_to_detecting 
                    first detected 
                    when outputOut.result.analogVoltage <= processor.threshold 
                    then detecting;
            }
            fault;
            
            transition idle_to_active 
                first idle 
                when powerIn.power.voltage > 0 [V] 
                then active;
                
            transition active_to_fault 
                first active 
                when powerIn.power.voltage == 0 [V] 
                then fault;
        }
    }
    
    requirement def DetectObjectRequirement {
        subject sensor : PhotoelectricSensorUnit;
        requirement {
            statement "The sensor shall detect the presence of a target object by emitting a beam of light and measuring its reflection."
        }
    }
    
    requirement def OutputRequirement {
        subject sensor : PhotoelectricSensorUnit;
        requirement {
            statement "The sensor shall provide a reliable digital output (object detected/not detected) and an analog voltage level."
        }
    }
}
