package NdYAGLaserSystem {
    import ScalarValues::*;
    
    // Value Types
    def VoltageValue :> Real { unit = 'V'; }
    def CurrentValue :> Real { unit = 'A'; }
    def PowerValue :> Real { unit = 'W'; }
    def TemperatureValue :> Real { unit = 'K'; }
    def WavelengthValue :> Real { unit = 'nm'; }
    def FlowRateValue :> Real { unit = 'L/min'; }
    
    // Item Types
    item def ElectricalPower {
        attr voltage : VoltageValue;
        attr current : CurrentValue;
    }
    
    item def PumpLight {
        attr intensity : PowerValue;
    }
    
    item def LaserBeam {
        attr power : PowerValue;
        attr wavelength : WavelengthValue = 1064;
    }
    
    item def CoolingWater {
        attr temperature : TemperatureValue;
        attr flowRate : FlowRateValue;
    }
    
    // Port Types
    port def ElectricalPort { in item : ElectricalPower; }
    port def OpticalPort { in item : PumpLight; in item : LaserBeam; }
    port def FluidPort { in item : CoolingWater; }
    
    // Components
    part def NdYAGCrystal {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        
        attr operatingTemp : TemperatureValue = 300;
    }
    
    part def XenonFlashlamp {
        port electricalIn : ElectricalPort;
        port opticalOut : OpticalPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }
    
    part def Mirror {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        attr reflectivity : Real;
    }
    
    part def QSwitch {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        attr open : Boolean;
    }
    
    part def OpticalResonator {
        port outputPort : OpticalPort;
        
        part mirror1 : Mirror;
        part mirror2 : Mirror;
        part crystal : NdYAGCrystal;
        part flashlamp : XenonFlashlamp;
        part qSwitch : QSwitch;
        
        connect flashlamp.opticalOut to crystal.opticalIn;
        connect mirror1.opticalOut to crystal.opticalIn;
        connect crystal.opticalOut to qSwitch.opticalIn;
        connect qSwitch.opticalOut to mirror2.opticalIn;
        connect mirror2.opticalOut to mirror1.opticalIn;
        connect mirror2.opticalOut to outputPort;
    }
    
    part def PowerSupply {
        port acIn : ElectricalPort;
        port dcOut : ElectricalPort;
        port controlIn : ElectricalPort;
    }
    
    part def CoolingSystem {
        port fluidOut : FluidPort;
        port fluidIn : FluidPort;
        part pump;
        part heatExchanger;
    }
    
    part def BeamDelivery {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
    }
    
    part def PowerMeter {
        port opticalIn : OpticalPort;
        port electricalOut : ElectricalPort;
        attr measuredPower : PowerValue;
    }
    
    part def LaserController {
        port powerIn : ElectricalPort;
        port controlOut : ElectricalPort;
        port feedbackIn : ElectricalPort;
        
        enum def OperatingMode { continuousWave; pulsed; qSwitched; }
        
        attr currentMode : OperatingMode;
        
        state def ControllerState;
        state def Off :> ControllerState;
        state def Initializing :> ControllerState;
        state def Standby :> ControllerState;
        state def Active :> ControllerState;
        state def Cooling :> ControllerState;
        state def Fault :> ControllerState;
        
        state machine ControllerStateMachine {
            state off : Off;
            state initializing : Initializing;
            state standby : Standby;
            state active : Active;
            state cooling : Cooling;
            state fault : Fault;
            
            transition off_to_initializing 
                first off 
                then initializing 
                accept PowerOn;
                
            transition initializing_to_standby 
                first initializing 
                then standby 
                accept InitComplete;
                
            transition standby_to_active 
                first standby 
                then active 
                accept StartLasing;
                
            transition active_to_cooling 
                first active 
                then cooling 
                accept StopLasing;
                
            transition cooling_to_standby 
                first cooling 
                then standby 
                accept CoolDownComplete;
                
            transition any_to_fault 
                first ControllerState 
                then fault 
                accept FaultDetected;
                
            transition fault_to_off 
                first fault 
                then off 
                accept Reset;
        }
    }
    
    // System Assembly
    part def NdYAGLaserSystem {
        part powerSupply : PowerSupply;
        part coolingSystem : CoolingSystem;
        part resonator : OpticalResonator;
        part beamDelivery : BeamDelivery;
        part powerMeter : PowerMeter;
        part controller : LaserController;
        
        // Electrical Connections
        connect powerSupply.dcOut to resonator.flashlamp.electricalIn;
        connect powerSupply.dcOut to controller.powerIn;
        connect controller.controlOut to powerSupply.controlIn;
        connect powerMeter.electricalOut to controller.feedbackIn;
        
        // Fluid Connections
        connect coolingSystem.fluidOut to resonator.flashlamp.fluidIn;
        connect resonator.flashlamp.fluidOut to resonator.crystal.fluidIn;
        connect resonator.crystal.fluidOut to coolingSystem.fluidIn;
        
        // Optical Connections
        connect resonator.outputPort to beamDelivery.opticalIn;
        connect beamDelivery.opticalOut to powerMeter.opticalIn;
    }
    
    // Requirements
    req def GenerateInfraredBeam {
        doc "The system shall generate a coherent infrared beam at 1064 nm."
        subject : NdYAGLaserSystem;
        objective : LaserBeam {
            attr wavelength == 1064;
        }
    }
    
    req def MaintainOperatingTemp {
        doc "The cooling system shall maintain the crystal operating temperature."
        subject : CoolingSystem;
        objective : CoolingWater {
            attr temperature <= 300;
        }
    }
    
    req def ProvideHighVoltageDC {
        doc "The power supply shall convert 220V AC to high-voltage DC."
        subject : PowerSupply;
        objective : ElectricalPower {
            attr voltage >= 1000;
        }
    }
}
