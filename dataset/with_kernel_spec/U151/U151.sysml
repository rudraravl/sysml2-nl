package ATNAA {
    private import ScalarValues::*;
    
    attribute def Volume :> Real { unit 'mL'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Pressure :> Real { unit 'Pa'; }
    
    item def Atropine;
    item def Pralidoxime;
    item def Antidote {
        item atropine : Atropine;
        item pralidoxime : Pralidoxime;
    }
    
    item def SafetyDisengaged;
    item def DevicePressed;
    item def InjectionComplete;
    
    part def DualChamberCartridge {
        item atropine : Atropine;
        item pralidoxime : Pralidoxime;
        attribute volume : Volume = 2.0 [mL];
    }
    
    part def SpringMechanism {
        attribute compressed : Boolean = true;
        attribute force : Force;
    }
    
    part def PlungerAssembly;
    
    part def NeedleAssembly {
        port injectionPort;
    }
    
    part def PressureSensor {
        attribute pressure : Pressure;
        attribute measuredPressure : Pressure;
    }
    
    part def VisualIndicator {
        attribute status : String = "Ready";
    }
    
    part def SafetyMechanism {
        attribute engaged : Boolean = true;
    }
    
    part def MuscleTissue;
    
    port def BodyContactPort;
    
    action def DisengageSafety {
        in out safety : SafetyMechanism;
    }
    
    action def TriggerInjection {
        in safety : SafetyMechanism;
        out spring : SpringMechanism;
    }
    
    action def DrivePlunger {
        in spring : SpringMechanism;
        out plunger : PlungerAssembly;
    }
    
    action def InjectAntidote {
        in plunger : PlungerAssembly;
        in cartridge : DualChamberCartridge;
        out antidote : Antidote;
    }
    
    action def MonitorPressure {
        in pressure : Pressure;
        out doseDelivered : Boolean;
    }
    
    action def UpdateIndicator {
        in doseDelivered : Boolean;
        in out indicator : VisualIndicator;
    }
    
    action def AdministerTreatment {
        action disengage : DisengageSafety;
        then action trigger : TriggerInjection;
        then action drive : DrivePlunger;
        then action inject : InjectAntidote;
        then action monitor : MonitorPressure;
        then action update : UpdateIndicator;
    }
    
    state machine def InjectionStateMachine {
        initial state idle;
        transition idle to armed accept SafetyDisengaged;
        state armed;
        transition armed to injecting accept DevicePressed;
        state injecting;
        transition injecting to complete accept InjectionComplete;
        state complete;
    }
    
    part def ATNAA {
        attribute contact : Boolean = false;
        part safety : SafetyMechanism;
        part spring : SpringMechanism;
        part plunger : PlungerAssembly;
        part cartridge : DualChamberCartridge;
        part needle : NeedleAssembly;
        part sensor : PressureSensor;
        part indicator : VisualIndicator;
        
        port bodyContactPort : BodyContactPort;
        
        perform action administer : AdministerTreatment {
            action disengage : DisengageSafety {
                in out safety = safety;
            }
            then action trigger : TriggerInjection {
                in safety = disengage.safety;
                out spring = spring;
            }
            then action drive : DrivePlunger {
                in spring = trigger.spring;
                out plunger = plunger;
            }
            then action inject : InjectAntidote {
                in plunger = drive.plunger;
                in cartridge = cartridge;
                out antidote;
            }
            then action monitor : MonitorPressure {
                in pressure = sensor.measuredPressure;
                out doseDelivered;
            }
            then action update : UpdateIndicator {
                in doseDelivered = monitor.doseDelivered;
                in out indicator = indicator;
            }
        }
        
        state machine : InjectionStateMachine;
    }
    
    requirement def ATNAARequirement {
        doc /* The device shall automatically inject a two-drug antidote into muscle tissue. */
        subject device : ATNAA;
    }
    
    requirement def SafetyRequirement {
        doc /* The device shall include a safety mechanism to prevent accidental activation. */
        subject device : ATNAA;
    }
    
    requirement def MonitoringRequirement {
        doc /* The device shall monitor injection pressure and confirm full dose delivery. */
        subject device : ATNAA;
    }
    
    requirement def IndicatorRequirement {
        doc /* The device shall provide a visual indication upon successful administration. */
        subject device : ATNAA;
    }
    
    part atnaa : ATNAA {
        satisfy ATNAARequirement;
        satisfy SafetyRequirement;
        satisfy MonitoringRequirement;
        satisfy IndicatorRequirement;
    }
}
