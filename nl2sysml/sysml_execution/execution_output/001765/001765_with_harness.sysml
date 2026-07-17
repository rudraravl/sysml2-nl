package DiodeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageValue :> ISQ::voltage;
    attribute def CurrentValue :> ISQ::electricCurrent;
    attribute def ResistanceValue :> ISQ::resistance;
    attribute def PowerValue :> ISQ::power;
    attribute def TemperatureValue :> ISQ::temperature;
    
    attribute def ForwardVoltageThreshold :> VoltageValue;
    attribute def ReverseBreakdownVoltage :> VoltageValue;
    
    enum def DiodeOperatingState {
        off;
        forwardBiased;
        reverseBiased;
        breakdown;
    }
    
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    part def Diode {
        doc /* 
            A semiconductor device that allows current to flow primarily in one direction.
            When forward-biased (anode positive relative to cathode), it conducts current.
            When reverse-biased, it blocks current until breakdown voltage is exceeded.
        */
        
        attribute forwardVoltageThreshold : ForwardVoltageThreshold = 0.7;
        attribute reverseBreakdownVoltage : ReverseBreakdownVoltage = 50.0;
        attribute forwardResistance : ResistanceValue = 0.1;
        attribute reverseResistance : ResistanceValue = 1.0e6;
        attribute maxForwardCurrent : CurrentValue = 1.0;
        attribute operatingTemperature : TemperatureValue = 298.15;
        
        port anode : ElectricalPort;
        port cathode : ElectricalPort;
        
        attribute voltageAcross : VoltageValue = anode.voltage - cathode.voltage;
        attribute currentThrough : CurrentValue;
        attribute powerDissipation : PowerValue;
        attribute currentState : DiodeOperatingState;
        
        state diodeBehavior {
            entry; then off;
            
            state off {
                doc /* Diode is not conducting, voltage below forward threshold. */
                entry assign currentThrough := 0.0;
                entry assign currentState := DiodeOperatingState::off;
            }
            
            state forwardBiased {
                doc /* Diode is conducting current from anode to cathode. */
                entry assign currentState := DiodeOperatingState::forwardBiased;
                entry assign currentThrough := (voltageAcross - forwardVoltageThreshold) / forwardResistance;
            }
            
            state reverseBiased {
                doc /* Diode is blocking reverse current. */
                entry assign currentThrough := 0.0;
                entry assign currentState := DiodeOperatingState::reverseBiased;
            }
            
            state breakdown {
                doc /* Reverse voltage exceeded breakdown limit, conducting in reverse. */
                entry assign currentState := DiodeOperatingState::breakdown;
                entry assign currentThrough := (voltageAcross + reverseBreakdownVoltage) / reverseResistance;
            }
            
            transition offToForward
                first off
                if voltageAcross >= forwardVoltageThreshold
                then forwardBiased;
            
            transition forwardToOff
                first forwardBiased
                if voltageAcross < forwardVoltageThreshold
                then off;
            
            transition offToReverse
                first off
                if voltageAcross < 0.0
                then reverseBiased;
            
            transition reverseToOff
                first reverseBiased
                if voltageAcross >= 0.0
                then off;
            
            transition reverseToBreakdown
                first reverseBiased
                if voltageAcross <= -reverseBreakdownVoltage
                then breakdown;
            
            transition breakdownToReverse
                first breakdown
                if voltageAcross > -reverseBreakdownVoltage
                then reverseBiased;
        }
    }
    
    part def VoltageSource {
        port positive : ElectricalPort;
        port negative : ElectricalPort;
        attribute sourceVoltage : VoltageValue;
        attribute outputCurrent : CurrentValue;
    }
    
    part def LoadResistor {
        port terminal1 : ElectricalPort;
        port terminal2 : ElectricalPort;
        attribute resistance : ResistanceValue;
        attribute voltageDrop : VoltageValue;
        attribute currentFlow : CurrentValue;
    }
    
    action def DetermineCurrentFlow {
        in appliedVoltage : VoltageValue;
        in forwardThreshold : ForwardVoltageThreshold;
        in reverseBreakdown : ReverseBreakdownVoltage;
        in forwardR : ResistanceValue;
        in reverseR : ResistanceValue;
        out outputCurrent : CurrentValue;
        out operatingState : DiodeOperatingState;
    }
    
    action def CalculatePowerDissipation {
        in voltage : VoltageValue;
        in current : CurrentValue;
        out power : PowerValue;
    }
    
    part def DiodeRectifierSystem {
        doc /* 
            A system that uses a diode to convert alternating current (AC) to 
            pulsating direct current (DC) by allowing current flow in only one direction.
            The diode conducts when forward-biased and blocks when reverse-biased,
            effectively rectifying the input signal.
        */
        
        part source : VoltageSource {
            attribute :>> sourceVoltage;
        }
        
        part diode : Diode {
            attribute :>> forwardVoltageThreshold = 0.7;
            attribute :>> reverseBreakdownVoltage = 50.0;
            attribute :>> forwardResistance = 0.1;
            attribute :>> reverseResistance = 1.0e6;
            attribute :>> maxForwardCurrent = 1.0;
        }
        
        part load : LoadResistor {
            attribute :>> resistance = 100.0;
        }
        
        connect source.positive to diode.anode;
        connect diode.cathode to load.terminal1;
        connect load.terminal2 to source.negative;
        
        action performRectification : DetermineCurrentFlow {
            in appliedVoltage = diode.voltageAcross;
            in forwardThreshold = diode.forwardVoltageThreshold;
            in reverseBreakdown = diode.reverseBreakdownVoltage;
            in forwardR = diode.forwardResistance;
            in reverseR = diode.reverseResistance;
            out outputCurrent;
            out operatingState;
            
            first start;
            then merge continuousMonitoring;
            
            then decide;
                if appliedVoltage >= forwardThreshold then forwardConduction;
                if appliedVoltage < 0.0 then reverseBlocking;
                if appliedVoltage >= 0.0 then offState;
            
            action forwardConduction {
                assign outputCurrent := (appliedVoltage - forwardThreshold) / forwardR;
                then assign operatingState := DiodeOperatingState::forwardBiased;
            }
            then continuousMonitoring;
            
            action reverseBlocking {
                assign outputCurrent := 0.0;
                then assign operatingState := DiodeOperatingState::reverseBiased;
            }
            then continuousMonitoring;
            
            action offState {
                assign outputCurrent := 0.0;
                then assign operatingState := DiodeOperatingState::off;
            }
            then continuousMonitoring;
        }
        
        action calculatePower : CalculatePowerDissipation {
            in voltage = diode.voltageAcross;
            in current = diode.currentThrough;
            out power;
        }
    }
    
    requirement def UnidirectionalConductionRequirement {
        doc /* 
            The diode shall conduct current in the forward direction when the 
            anode-to-cathode voltage exceeds the forward voltage threshold.
        */
        
        subject diode : Diode;
        
        require constraint forwardConduction {
            diode.voltageAcross >= diode.forwardVoltageThreshold implies 
            diode.currentThrough > 0.0
        }
    }
    
    requirement def ReverseBlockingRequirement {
        doc /* 
            The diode shall block current in the reverse direction when the 
            reverse voltage is below the breakdown voltage.
        */
        
        subject diode : Diode;
        
        require constraint reverseBlocking {
            diode.voltageAcross < 0.0 and 
            diode.voltageAcross > -diode.reverseBreakdownVoltage implies 
            diode.currentThrough == 0.0
        }
    }
    
    requirement def ThermalProtectionRequirement {
        doc /* 
            The diode power dissipation shall not exceed the maximum rated power 
            to prevent thermal damage.
        */
        
        subject diode : Diode;
        
        attribute maxPowerRating : PowerValue = 1.0;
        
        require constraint thermalLimit {
            diode.powerDissipation <= maxPowerRating
        }
    }
    
    requirement <'DIODE-SYS-001'> diodeSystemRequirement {
        doc /* 
            The diode rectifier system shall convert alternating voltage to 
            unidirectional pulsating voltage by allowing current flow in only 
            one direction through the diode component.
        */
        
        subject system : DiodeRectifierSystem;
        
        require unidirectionalConduction : UnidirectionalConductionRequirement {
            subject diode = system.diode;
        }
        
        require reverseBlocking : ReverseBlockingRequirement {
            subject diode = system.diode;
        }
        
        require thermalProtection : ThermalProtectionRequirement {
            subject diode = system.diode;
        }
    }
    
    part diodeRectifierInstance : DiodeRectifierSystem {
        part :>> source {
            attribute :>> sourceVoltage = 12.0;
        }
        
        part :>> diode {
            attribute :>> forwardVoltageThreshold = 0.7;
            attribute :>> reverseBreakdownVoltage = 50.0;
            attribute :>> forwardResistance = 0.1;
            attribute :>> reverseResistance = 1.0e6;
            attribute :>> maxForwardCurrent = 1.0;
            attribute :>> operatingTemperature = 298.15;
        }
        
        part :>> load {
            attribute :>> resistance = 100.0;
        }
        
        satisfy diodeSystemRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import DiodeSystem::*;

    part testSubject : DiodeRectifierSystem {
    :>> appliedVoltage = testAppliedVoltage;
    :>> forwardThreshold = testForwardThreshold;
    :>> reverseBreakdown = testReverseBreakdown;
    :>> forwardR = testForwardR;
    :>> reverseR = testReverseR;
    }

    action orchestrator {
        attribute testAppliedVoltage : VoltageValue;
        attribute testForwardThreshold : ForwardVoltageThreshold;
        attribute testReverseBreakdown : ReverseBreakdownVoltage;
        attribute testForwardR : ResistanceValue;
        attribute testReverseR : ResistanceValue;
    }
}
