package MOSFETSwitchingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GateVoltageLevel;
    attribute def SwitchingSpeed;
    
    enum def OperatingRegion {
        cutoff;
        linear;
        saturation;
    }
    
    enum def SwitchPosition {
        open;
        closed;
    }
    
    port def ElectricalTerminal {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    item def ElectricalPower {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute power : ISQ::PowerValue;
    }
    
    part def NMOSFET {
        doc /* N-channel Metal-Oxide-Semiconductor Field-Effect Transistor that acts as 
               a voltage-controlled switch for power management applications. */
        
        attribute thresholdVoltage : ISQ::VoltageValue;
        attribute onStateResistance : ISQ::ElectricalResistanceValue;
        attribute maxDrainSourceVoltage : ISQ::VoltageValue;
        attribute maxDrainCurrent : ISQ::ElectricCurrentValue;
        attribute maxGateSourceVoltage : ISQ::VoltageValue;
        attribute region : OperatingRegion;
        
        port gate : ElectricalTerminal {
            in attribute gateVoltage : ISQ::VoltageValue;
        }
        
        port drain : ElectricalTerminal {
            in attribute drainVoltage : ISQ::VoltageValue;
            out attribute drainCurrent : ISQ::ElectricCurrentValue;
        }
        
        port source : ElectricalTerminal {
            attribute sourceVoltage : ISQ::VoltageValue;
            out attribute sourceCurrent : ISQ::ElectricCurrentValue;
        }
        
        perform action operateTransistor;
    }
    
    part def DCPowerSupply {
        doc /* Direct current power source providing stable voltage. */
        
        attribute outputVoltage : ISQ::VoltageValue;
        attribute maxCurrent : ISQ::ElectricCurrentValue;
        
        port positive : ElectricalTerminal {
            out attribute voltage : ISQ::VoltageValue;
        }
        
        port negative : ElectricalTerminal {
            attribute voltage : ISQ::VoltageValue;
        }
    }
    
    part def ResistiveLoad {
        doc /* Electrical load represented as a resistor. */
        
        attribute resistance : ISQ::ElectricalResistanceValue;
        attribute powerRating : ISQ::PowerValue;
        
        port terminal1 : ElectricalTerminal;
        port terminal2 : ElectricalTerminal;
    }
    
    part def GateDriver {
        doc /* Circuit that provides appropriate gate voltage signal to control the MOSFET. */
        
        attribute highVoltage : ISQ::VoltageValue;
        attribute lowVoltage : ISQ::VoltageValue;
        attribute switchingFrequency : ISQ::FrequencyValue;
        
        port controlInput : ElectricalTerminal;
        port gateOutput : ElectricalTerminal {
            out attribute outputVoltage : ISQ::VoltageValue;
        }
        
        perform action generateGateSignal;
    }
    
    action def DetermineOperatingRegion {
        in gateVoltage : ISQ::VoltageValue;
        in sourceVoltage : ISQ::VoltageValue;
        in drainVoltage : ISQ::VoltageValue;
        in thresholdVoltage : ISQ::VoltageValue;
        out operatingRegion : OperatingRegion;
    }
    
    action def CalculateDrainCurrent {
        in gateSourceVoltage : ISQ::VoltageValue;
        in drainSourceVoltage : ISQ::VoltageValue;
        in thresholdVoltage : ISQ::VoltageValue;
        in onResistance : ISQ::ElectricalResistanceValue;
        in region : OperatingRegion;
        out drainCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def ControlSwitching {
        in commandSignal : ISQ::VoltageValue;
        in thresholdVoltage : ISQ::VoltageValue;
        out switchState : SwitchPosition;
        
        first start;
        then merge evaluateCommand;
        
        then action evaluate {
            in signal : ISQ::VoltageValue = commandSignal;
            in threshold : ISQ::VoltageValue = thresholdVoltage;
            out state : SwitchPosition;
        }
        
        then decide;
            if evaluate.signal >= evaluate.threshold then closeSwitch;
            if evaluate.signal < evaluate.threshold then openSwitch;
        
        action closeSwitch {
            out position : SwitchPosition = SwitchPosition::closed;
        }
        then assign switchState := closeSwitch.position;
        then evaluateCommand;
        
        action openSwitch {
            out position : SwitchPosition = SwitchPosition::open;
        }
        then assign switchState := openSwitch.position;
        then evaluateCommand;
    }
    
    part mosfetPowerSwitch {
        doc /* A MOSFET-based electronic switching system that controls electrical power delivery 
               to a load. The system's primary function is to act as a solid-state switch, enabling 
               or disabling current flow from a power supply to a load based on a control signal 
               applied to the MOSFET gate. When the gate voltage exceeds the threshold voltage, 
               the MOSFET transitions to its conductive state, allowing current to flow through 
               the drain-source channel to power the load. When the gate voltage drops below the 
               threshold, the MOSFET enters cutoff, blocking current flow and disconnecting the 
               load from the power source. This provides fast, efficient, and reliable switching 
               for applications including power management, motor control, LED drivers, and 
               digital logic circuits. */
        
        part mainSupply : DCPowerSupply {
            attribute :>> outputVoltage = 24.0;
            attribute :>> maxCurrent = 5.0;
        }
        
        part switchingTransistor : NMOSFET {
            attribute :>> thresholdVoltage = 3.0;
            attribute :>> onStateResistance = 0.05;
            attribute :>> maxDrainSourceVoltage = 60.0;
            attribute :>> maxDrainCurrent = 10.0;
            attribute :>> maxGateSourceVoltage = 20.0;
        }
        
        part electricalLoad : ResistiveLoad {
            attribute :>> resistance = 10.0;
            attribute :>> powerRating = 50.0;
        }
        
        part gateControl : GateDriver {
            attribute :>> highVoltage = 12.0;
            attribute :>> lowVoltage = 0.0;
            attribute :>> switchingFrequency = 1000.0;
            
            perform action generateGateSignal {
                out controlSignal : ISQ::VoltageValue;
            }
        }
        
        connect mainSupply.positive to electricalLoad.terminal1;
        connect electricalLoad.terminal2 to switchingTransistor.drain;
        connect switchingTransistor.source to mainSupply.negative;
        connect gateControl.gateOutput to switchingTransistor.gate;
        
        perform action switchingControl : ControlSwitching {
            in commandSignal = gateControl.gateOutput.outputVoltage;
            in thresholdVoltage = switchingTransistor.thresholdVoltage;
            out switchState;
        }
    }
    
    requirement <'MOSFET-REQ-001'> primarySwitchingFunction {
        doc /* The MOSFET system shall function as an electronic switch to control power 
               delivery to the load based on gate voltage control signals. */
        
        subject mosfetPowerSwitch;
        
        require constraint gateControlEnablesPower {
            doc /* When gate voltage exceeds threshold, the system shall enable current flow 
                   from power supply to load. */
        }
        
        require constraint gateControlDisablesPower {
            doc /* When gate voltage is below threshold, the system shall block current flow 
                   to the load. */
        }
    }
    
    requirement <'MOSFET-REQ-002'> operationalSafety {
        doc /* The MOSFET system shall operate within safe electrical limits to prevent 
               component damage. */
        
        subject mosfetPowerSwitch.switchingTransistor;
        
        require constraint drainCurrentLimit {
            doc /* Drain current shall not exceed maximum rated current. */
        }
        
        require constraint drainVoltageLimit {
            doc /* Drain-source voltage shall not exceed maximum rated voltage. */
        }
        
        require constraint gateVoltageLimit {
            doc /* Gate-source voltage shall not exceed maximum rated voltage. */
        }
    }
    
    requirement <'MOSFET-REQ-003'> switchingEfficiency {
        doc /* The MOSFET system shall minimize power dissipation during switching and 
               conduction to maximize efficiency. */
        
        subject mosfetPowerSwitch;
        
        require constraint lowOnResistance {
            doc /* On-state resistance shall be minimized to reduce conduction losses. */
        }
    }
}
