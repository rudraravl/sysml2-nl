package StroboscopeSystem {
    private import ScalarValues::*;
    
    attribute def Frequency :> Real;
    attribute def Voltage :> Real;
    attribute def Power :> Real;
    attribute def TimeDuration :> Real;
    attribute def LuminousIntensity :> Real;
    
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute power : Power;
    }
    item def FrequencyCommand {
        attribute frequency : Frequency;
    }
    item def TriggerSignal {
        attribute pulse : Boolean;
    }
    item def LightFlash {
        attribute intensity : LuminousIntensity;
        attribute duration : TimeDuration;
    }
    item def LightBeam {
        attribute intensity : LuminousIntensity;
    }
    item def PowerOnEvent;
    item def PowerOffEvent;
    
    action def GenerateTrigger {
        in cmd : FrequencyCommand;
        out trigger : TriggerSignal;
    }
    action def DischargeFlash {
        in power : ElectricalPower;
        in trigger : TriggerSignal;
        out flash : LightFlash;
    }
    action def FocusBeam {
        in flash : LightFlash;
        out beam : LightBeam;
    }
    
    part def UserInterface {
        attribute isOn : Boolean = false;
        attribute currentFrequency : Frequency = 0.0;
        port freqCmdPort {
            out freqCmd : FrequencyCommand;
        }
        port powerSwitchPort {
            out powerState : Boolean;
        }
        state def UIBehavior {
            state Off;
            state On;
            transition offToOn first Off then On accept PowerOnEvent;
            transition onToOff first On then Off accept PowerOffEvent;
        }
    }
    
    part def PowerSupply {
        port extPowerPort {
            in extPower : ElectricalPower;
        }
        port powerStatePort {
            in powerState : Boolean;
        }
        port internalPowerPort {
            out internalPower : ElectricalPower;
        }
    }
    
    part def FrequencyController {
        port freqCmdPort {
            in freqCmd : FrequencyCommand;
        }
        port powerPort {
            in power : ElectricalPower;
        }
        port triggerPort {
            out trigger : TriggerSignal;
        }
        action generateTrigger : GenerateTrigger;
    }
    
    part def FlashTube {
        port powerPort {
            in power : ElectricalPower;
        }
        port triggerPort {
            in trigger : TriggerSignal;
        }
        port lightPort {
            out flash : LightFlash;
        }
        action discharge : DischargeFlash;
    }
    
    part def ReflectorAssembly {
        port lightInPort {
            in flash : LightFlash;
        }
        port lightOutPort {
            out beam : LightBeam;
        }
        action focusBeam : FocusBeam;
    }
    
    part def Stroboscope {
        port powerInPort {
            in extPower : ElectricalPower;
        }
        port lightOutPort {
            out beam : LightBeam;
        }
        part ui : UserInterface;
        part psu : PowerSupply;
        part controller : FrequencyController;
        part flashTube : FlashTube;
        part reflector : ReflectorAssembly;
        flow powerFlow of ElectricalPower
            from powerInPort.extPower to psu.extPowerPort.extPower;
        flow powerStateFlow of Boolean
            from ui.powerSwitchPort.powerState to psu.powerStatePort.powerState;
        flow internalPowerFlowCtrl of ElectricalPower
            from psu.internalPowerPort.internalPower to controller.powerPort.power;
        flow internalPowerFlowTube of ElectricalPower
            from psu.internalPowerPort.internalPower to flashTube.powerPort.power;
        flow cmdFlow of FrequencyCommand
            from ui.freqCmdPort.freqCmd to controller.freqCmdPort.freqCmd;
        flow triggerFlow of TriggerSignal
            from controller.triggerPort.trigger to flashTube.triggerPort.trigger;
        flow flashFlow of LightFlash
            from flashTube.lightPort.flash to reflector.lightInPort.flash;
        flow beamFlow of LightBeam
            from reflector.lightOutPort.beam to lightOutPort.beam;
    }
    
    occurrence def StroboscopeOperation {
        ref part ui : UserInterface;
        ref part controller : FrequencyController;
        ref part flashTube : FlashTube;
        ref part reflector : ReflectorAssembly;
        
        message freqCmdMsg of FrequencyCommand
            from ui.freqCmdPort to controller.freqCmdPort;
        then message triggerMsg of TriggerSignal
            from controller.triggerPort to flashTube.triggerPort;
        then message flashMsg of LightFlash
            from flashTube.lightPort to reflector.lightInPort;
    }
    
    requirement def StroboscopeRequirementDef {
        subject stroboscope : Stroboscope;
        doc "The stroboscope shall produce high-intensity, short-duration light flashes at a user-adjustable frequency.";
    }
    
    requirement produceLightFlashesReq : StroboscopeRequirementDef {
        doc "The stroboscope shall produce high-intensity, short-duration light flashes.";
    }
    
    requirement adjustableFrequencyReq : StroboscopeRequirementDef {
        doc "The flash frequency shall be user-adjustable and precise.";
    }
    
    part stroboscope : Stroboscope;
    
    satisfy produceLightFlashesReq by stroboscope;
    satisfy adjustableFrequencyReq by stroboscope;
}
