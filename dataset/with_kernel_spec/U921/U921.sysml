package CapacitiveTouchSwitchSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def RawTouchSignal;
    attribute def FilteredSignal;
    attribute def TouchValidated;
    attribute def PowerCommand;
    attribute def StatusCommand;
    attribute def AcPower;
    attribute def LowVoltagePower;
    attribute def LoadPower;
    
    port def PowerInPort { in power : LowVoltagePower; }
    port def RawSignalOutPort { out signal : RawTouchSignal; }
    port def RawSignalInPort { in signal : RawTouchSignal; }
    port def FilteredSignalOutPort { out signal : FilteredSignal; }
    port def FilteredSignalInPort { in signal : FilteredSignal; }
    port def TouchValidatedOutPort { out signal : TouchValidated; }
    port def TouchValidatedInPort { in signal : TouchValidated; }
    port def PowerCommandOutPort { out command : PowerCommand; }
    port def PowerCommandInPort { in command : PowerCommand; }
    port def StatusCommandOutPort { out command : StatusCommand; }
    port def StatusCommandInPort { in command : StatusCommand; }
    port def AcPowerInPort { in power : AcPower; }
    port def LowVoltageOutPort { out power : LowVoltagePower; }
    port def LoadPowerOutPort { out power : LoadPower; }
    port def LoadPowerInPort { in power : LoadPower; }
    
    action def SenseTouch { out raw : RawTouchSignal; }
    action def ConditionSignal { in raw : RawTouchSignal; out filtered : FilteredSignal; }
    action def DebounceSignal { in filtered : FilteredSignal; out validated : TouchValidated; }
    action def SwitchPower { in command : PowerCommand; }
    action def IndicateStatus { in command : StatusCommand; }
    action def ConvertPower { in ac : AcPower; out dc : LowVoltagePower; }
    
    state def PowerState {
        entry; then off;
        state off;
        transition off_to_on
            first off
            accept TouchValidated
            then on;
        state on;
        transition on_to_off
            first on
            accept TouchValidated
            then off;
    }
    
    part def CapacitiveTouchSensor {
        port powerIn : PowerInPort;
        port rawOut : RawSignalOutPort;
        perform action sense : SenseTouch;
    }
    
    part def SignalConditioner {
        port powerIn : PowerInPort;
        port rawIn : RawSignalInPort;
        port filteredOut : FilteredSignalOutPort;
        perform action condition : ConditionSignal;
    }
    
    part def DebounceCircuit {
        port powerIn : PowerInPort;
        port filteredIn : FilteredSignalInPort;
        port validatedOut : TouchValidatedOutPort;
        attribute debounceTime_ms : Integer = 50;
        perform action debounce : DebounceSignal;
    }
    
    part def ControlProcessor {
        port powerIn : PowerInPort;
        port validatedIn : TouchValidatedInPort;
        port powerCmdOut : PowerCommandOutPort;
        port statusCmdOut : StatusCommandOutPort;
        exhibit state powerState : PowerState;
    }
    
    part def HighPowerSwitch {
        port acIn : AcPowerInPort;
        port cmdIn : PowerCommandInPort;
        port loadOut : LoadPowerOutPort;
        perform action switch : SwitchPower;
    }
    
    part def StatusIndicator {
        port powerIn : PowerInPort;
        port cmdIn : StatusCommandInPort;
        perform action indicate : IndicateStatus;
    }
    
    part def PowerSupply {
        port acIn : AcPowerInPort;
        port lowVoltageOut : LowVoltageOutPort;
        perform action convert : ConvertPower;
    }
    
    part def ElectricalDevice {
        port loadIn : LoadPowerInPort;
    }
    
    part def TouchSwitchSystem {
        port acIn : AcPowerInPort;
        port loadOut : LoadPowerOutPort;
        
        part supply : PowerSupply;
        part sensor : CapacitiveTouchSensor;
        part conditioner : SignalConditioner;
        part debouncer : DebounceCircuit;
        part processor : ControlProcessor;
        part highPowerSwitch : HighPowerSwitch;
        part statusIndicator : StatusIndicator;
        part device : ElectricalDevice;
        
        connect acIn to supply.acIn;
        connect supply.lowVoltageOut to sensor.powerIn;
        connect supply.lowVoltageOut to conditioner.powerIn;
        connect supply.lowVoltageOut to debouncer.powerIn;
        connect supply.lowVoltageOut to processor.powerIn;
        connect supply.lowVoltageOut to statusIndicator.powerIn;
        
        connect sensor.rawOut to conditioner.rawIn;
        connect conditioner.filteredOut to debouncer.filteredIn;
        connect debouncer.validatedOut to processor.validatedIn;
        connect processor.powerCmdOut to highPowerSwitch.cmdIn;
        connect processor.statusCmdOut to statusIndicator.cmdIn;
        
        connect acIn to highPowerSwitch.acIn;
        connect highPowerSwitch.loadOut to device.loadIn;
        connect highPowerSwitch.loadOut to loadOut;
    }
    
    requirement def DebounceTimeRequirement {
        doc /* The debounce circuit shall require a stable touch signal for at least 50 ms before registering a valid touch. */
        attribute minStableTime_ms : Integer = 50;
    }
    
    requirement def SafetyIsolationRequirement {
        doc /* The low-voltage control circuit shall be electrically isolated from the high-power load circuit. */
    }
    
    requirement def VisualFeedbackRequirement {
        doc /* The status indicator shall provide clear visual feedback of the current on/off state. */
    }
    
    requirement def TouchToggleRequirement {
        doc /* The system shall toggle power to the connected device upon each validated touch. */
    }
    
    part touchSwitch : TouchSwitchSystem;
    
    requirement req1 : DebounceTimeRequirement;
    requirement req2 : SafetyIsolationRequirement;
    requirement req3 : VisualFeedbackRequirement;
    requirement req4 : TouchToggleRequirement;
}
