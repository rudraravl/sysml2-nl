package OpticalDetectionSystem {
    import ScalarValues::*;
    
    attribute def Lux :> Real { unit "lux"; }
    attribute def Ampere :> Real { unit "A"; }
    attribute def Volt :> Real { unit "V"; }
    attribute def Ohm :> Real { unit "ohm"; }
    
    item def Light {
        attribute intensity : Lux;
    }
    
    item def ElectricCurrent {
        attribute value : Ampere;
    }
    
    item def ElectricVoltage {
        attribute value : Volt;
    }
    
    port def OpticalPort {
        item light : Light;
    }
    
    port def PowerPort {
        item voltage : ElectricVoltage;
    }
    
    port def CurrentPort {
        item current : ElectricCurrent;
    }
    
    port def VoltagePort {
        item voltage : ElectricVoltage;
    }
    
    part def PowerSupply {
        out port powerOut : PowerPort;
        attribute outputVoltage : Volt = 5;
    }
    
    part def CollectorResistor {
        in port currentIn : CurrentPort;
        out port voltageOut : VoltagePort;
        attribute resistance : Ohm = 10000;
    }
    
    part def SignalConditioner {
        in port analogIn : VoltagePort;
        out port digitalOut : VoltagePort;
        out port scaledAnalogOut : VoltagePort;
        
        action condition {
            in item rawVoltage : ElectricVoltage;
            out item digitalSignal : ElectricVoltage;
            out item scaledVoltage : ElectricVoltage;
        }
    }
    
    part def Phototransistor {
        in port opticalIn : OpticalPort;
        in port powerIn : PowerPort;
        out port currentOut : CurrentPort;
        
        attribute lightIntensity : Lux;
        attribute outputCurrent : Ampere;
        attribute maxCurrent : Ampere = 0.02;
        attribute thresholdActive : Lux = 10;
        attribute thresholdSaturated : Lux = 1000;
        
        state machine OperationMode {
            state Cutoff {
                entry { outputCurrent = 0.000001; }
            }
            state Active {
                entry { outputCurrent = lightIntensity * 0.0001; }
            }
            state Saturated {
                entry { outputCurrent = maxCurrent; }
            }
            
            transition from Cutoff to Active when lightIntensity > thresholdActive;
            transition from Active to Saturated when lightIntensity > thresholdSaturated;
            transition from Saturated to Active when lightIntensity <= thresholdSaturated;
            transition from Active to Cutoff when lightIntensity <= thresholdActive;
        }
    }
    
    part def OpticalSystem {
        part powerSupply : PowerSupply;
        part phototransistor : Phototransistor;
        part collectorResistor : CollectorResistor;
        part signalConditioner : SignalConditioner;
        
        connection powerSupply.powerOut to phototransistor.powerIn;
        connection phototransistor.currentOut to collectorResistor.currentIn;
        connection collectorResistor.voltageOut to signalConditioner.analogIn;
    }
    
    requirement def DetectAmbientLight {
        doc /* The system shall sense the level of ambient light and convert it into a measurable electrical signal. */
        subject system : OpticalSystem;
    }
    
    requirement def OperateInStates {
        doc /* The phototransistor shall operate in cutoff, active, and saturated states based on light intensity. */
        subject phototransistor : Phototransistor;
    }
    
    requirement def ConditionSignal {
        doc /* The signal conditioner shall filter noise and convert the analog voltage to a digital or scaled analog format. */
        subject signalConditioner : SignalConditioner;
    }
}
