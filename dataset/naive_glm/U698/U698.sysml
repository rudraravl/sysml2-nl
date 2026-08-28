package GolayCellDetectorSystem {
    import ScalarValues::*;
    import ISQ::Energy;
    import ISQ::Temperature;
    import ISQ::Pressure;
    import ISQ::Length;
    import ISQ::Voltage;
    
    item def InfraredRadiation;
    item def Heat;
    item def Gas;
    item def Light;
    
    port def IRInputPort { in item ir : InfraredRadiation; }
    port def HeatTransferPort { in item heat : Heat; }
    port def PressureTransferPort { in item pressure : Pressure; }
    port def DeflectionPort { in item deflection : Length; }
    port def LightSourcePort { in item light : Light; }
    port def ReflectedLightPort { in item reflectedLight : Light; }
    port def VoltageOutputPort { in item voltage : Voltage; }
    
    part def AbsorptionWindow {
        port irIn : IRInputPort;
        port heatOut : ~HeatTransferPort;
        
        action absorb {
            in ir : InfraredRadiation;
            out heat : Heat;
        }
    }
    
    part def GasChamber {
        port heatIn : HeatTransferPort;
        port pressureOut : ~PressureTransferPort;
        
        attribute gasTemperature : Temperature;
        attribute gasPressure : Pressure;
        
        action expand {
            in heat : Heat;
            out pressure : Pressure;
        }
    }
    
    part def FlexibleMembrane {
        port pressureIn : PressureTransferPort;
        port deflectionOut : ~DeflectionPort;
        port lightIn : LightSourcePort;
        port reflectedLightOut : ~ReflectedLightPort;
        
        attribute deflection : Length;
        
        action deflect {
            in pressure : Pressure;
            out deflection : Length;
        }
        
        action reflect {
            in light : Light;
            out reflectedLight : Light;
        }
    }
    
    part def OpticalReadout {
        port deflectionIn : DeflectionPort;
        port lightOut : ~LightSourcePort;
        port reflectedLightIn : ReflectedLightPort;
        port voltageOut : ~VoltageOutputPort;
        
        attribute outputVoltage : Voltage;
        
        action measure {
            in deflection : Length;
            in reflectedLight : Light;
            out voltage : Voltage;
        }
    }
    
    part def GolayCellDetector {
        port irInput : IRInputPort;
        port voltageOutput : ~VoltageOutputPort;
        
        attribute radiationPresent : Boolean;
        
        part absorptionWindow : AbsorptionWindow;
        part gasChamber : GasChamber;
        part flexibleMembrane : FlexibleMembrane;
        part opticalReadout : OpticalReadout;
        
        connection irFlow connect irInput to absorptionWindow.irIn;
        connection heatFlow connect absorptionWindow.heatOut to gasChamber.heatIn;
        connection pressureFlow connect gasChamber.pressureOut to flexibleMembrane.pressureIn;
        connection deflectionFlow connect flexibleMembrane.deflectionOut to opticalReadout.deflectionIn;
        connection lightFlow connect opticalReadout.lightOut to flexibleMembrane.lightIn;
        connection reflectedLightFlow connect flexibleMembrane.reflectedLightOut to opticalReadout.reflectedLightIn;
        connection voltageFlow connect opticalReadout.voltageOut to voltageOutput;
        
        state DetectorStates {
            state Equilibrium;
            state Detecting;
            state Recovering;
            
            transition from Equilibrium to Detecting when radiationPresent == true;
            transition from Detecting to Recovering when radiationPresent == false;
            transition from Recovering to Equilibrium when flexibleMembrane.deflection == 0;
        }
    }
    
    requirement def DetectInfraredRadiation {
        subject detector : GolayCellDetector;
        objective {
            doc "The detector shall detect infrared radiation and convert it into a measurable electrical signal."
        }
    }
}
