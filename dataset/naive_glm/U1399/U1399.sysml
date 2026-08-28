package HalfWaveRectifier {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types ----
    value type Voltage :> Real {
        unit 'V';
    }
    value type Current :> Real {
        unit 'A';
    }
    value type Resistance :> Real {
        unit 'ohm';
    }
    value type Frequency :> Real {
        unit 'Hz';
    }
    value type Power :> Real {
        unit 'W';
    }
    
    // ---- Item Types ----
    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }
    
    // ---- Port Definitions ----
    port def PositiveTerminal {
        out item signal : ElectricalSignal;
    }
    
    port def NegativeTerminal {
        in item signal : ElectricalSignal;
    }
    
    port def BidirectionalTerminal {
        inout item signal : ElectricalSignal;
    }
    
    // ---- Requirements ----
    requirement def RectificationRequirement {
        doc /* The system shall convert AC voltage into pulsating DC voltage. */
        attribute inputVoltageRMS : Voltage = 12.0;
        attribute inputFrequency : Frequency = 60.0;
        attribute outputVoltageRMS : Voltage;
        constraint { outputVoltageRMS == inputVoltageRMS / 1.57 }
        require {
            constraint { outputVoltageRMS > 0.0 }
        }
    }
    
    requirement def DiodeConductionRequirement {
        doc /* The diode shall conduct only when forward voltage exceeds threshold. */
        attribute forwardThreshold : Voltage = 0.7;
        attribute reverseBreakdown : Voltage = 50.0;
        constraint { forwardThreshold > 0.0 }
        constraint { reverseBreakdown > 0.0 }
    }
    
    requirement def LoadPowerRequirement {
        doc /* The load resistor shall receive pulsating DC current. */
        attribute loadResistance : Resistance = 1000.0;
        attribute maxPowerDissipation : Power = 1.0;
        constraint { loadResistance > 0.0 }
    }
    
    // ---- Part Definitions ----
    part def ACVoltageSource {
        port positiveOut : PositiveTerminal;
        port negativeOut : NegativeTerminal;
        
        attribute amplitude : Voltage = 17.0;
        attribute frequency : Frequency = 60.0;
        attribute phase : Real = 0.0;
        
        attribute currentTime : Real = 0.0;
        
        action def GenerateAC :> Action {
            out instantaneousVoltage : Voltage;
        }
        
        action generateAC : GenerateAC {
            /* v(t) = amplitude * sin(2 * pi * frequency * t + phase) */
            perform {
                instantaneousVoltage = amplitude * sin(2.0 * 3.141592653589793 * frequency * currentTime + phase);
            }
        }
        
        item signal : ElectricalSignal {
            attribute voltage = generateAC.instantaneousVoltage;
            attribute current = 0.0;
            attribute frequency = frequency;
        }
        
        flow from generateAC.instantaneousVoltage to positiveOut.signal.voltage;
    }
    
    part def RectifierDiode {
        port anode : BidirectionalTerminal;
        port cathode : BidirectionalTerminal;
        
        attribute forwardThreshold : Voltage = 0.7;
        attribute reverseBreakdown : Voltage = 50.0;
        attribute forwardResistance : Resistance = 10.0;
        attribute reverseResistance : Resistance = 1000000.0;
        attribute breakdownResistance : Resistance = 1.0;
        
        attribute forwardVoltage : Voltage;
        attribute reverseVoltage : Voltage;
        attribute diodeCurrent : Current;
        
        state machine DiodeStateMachine {
            entry; then Off;
            
            state Off;
            state ForwardBiased;
            state ReverseBiased;
            state Breakdown;
            
            transition off_to_forward
                first Off
                accept ForwardThresholdExceeded
                then ForwardBiased;
            
            transition forward_to_off
                first ForwardBiased
                accept ForwardThresholdNotMet
                then Off;
            
            transition off_to_reverse
                first Off
                accept ReverseVoltageApplied
                then ReverseBiased;
            
            transition reverse_to_off
                first ReverseBiased
                accept ReverseVoltageRemoved
                then Off;
            
            transition reverse_to_breakdown
                first ReverseBiased
                accept BreakdownVoltageExceeded
                then Breakdown;
            
            transition breakdown_to_reverse
                first Breakdown
                accept BreakdownVoltageNotExceeded
                then ReverseBiased;
            
            transition forward_to_reverse
                first ForwardBiased
                accept ReverseVoltageApplied
                then ReverseBiased;
            
            transition reverse_to_forward
                first ReverseBiased
                accept ForwardThresholdExceeded
                then ForwardBiased;
        }
        
        action def EvaluateDiode :> Action {
            in sourceVoltage : Voltage;
            out diodeCurrent : Current;
            out diodeState : String;
        }
        
        action evaluateDiode : EvaluateDiode {
            perform {
                if (sourceVoltage > forwardThreshold) {
                    diodeCurrent = (sourceVoltage - forwardThreshold) / forwardResistance;
                    diodeState = "ForwardBiased";
                } else if (sourceVoltage < -reverseBreakdown) {
                    diodeCurrent = (sourceVoltage + reverseBreakdown) / breakdownResistance;
                    diodeState = "Breakdown";
                } else if (sourceVoltage < 0.0) {
                    diodeCurrent = sourceVoltage / reverseResistance;
                    diodeState = "ReverseBiased";
                } else {
                    diodeCurrent = 0.0;
                    diodeState = "Off";
                }
            }
        }
    }
    
    part def LoadResistor {
        port positiveIn : BidirectionalTerminal;
        port negativeIn : BidirectionalTerminal;
        
        attribute resistance : Resistance = 1000.0;
        attribute loadVoltage : Voltage;
        attribute loadCurrent : Current;
        attribute powerDissipation : Power;
        
        action def CalculateLoad :> Action {
            in inputCurrent : Current;
            out loadVoltage : Voltage;
            out loadCurrent : Current;
            out power : Power;
        }
        
        action calculateLoad : CalculateLoad {
            perform {
                loadCurrent = inputCurrent;
                loadVoltage = loadCurrent * resistance;
                power = loadVoltage * loadCurrent;
            }
        }
    }
    
    // ---- System Assembly ----
    part def HalfWaveRectifierCircuit {
        requirement rectificationReq : RectificationRequirement;
        requirement diodeReq : DiodeConductionRequirement;
        requirement loadReq : LoadPowerRequirement;
        
        part source : ACVoltageSource {
            attribute amplitude = 17.0;
            attribute frequency = 60.0;
        }
        
        part diode : RectifierDiode {
            attribute forwardThreshold = 0.7;
            attribute reverseBreakdown = 50.0;
        }
        
        part load : LoadResistor {
            attribute resistance = 1000.0;
        }
        
        // Connections
        connection sourcePositiveToDiodeAnode : PositiveTerminal to BidirectionalTerminal
            from source.positiveOut to diode.anode;
        
        connection diodeCathodeToLoadPositive : BidirectionalTerminal to BidirectionalTerminal
            from diode.cathode to load.positiveIn;
        
        connection loadNegativeToSourceNegative : BidirectionalTerminal to NegativeTerminal
            from load.negativeIn to source.negativeOut;
        
        // System-level attributes
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute rectificationEfficiency : Real;
        
        action def SystemOperation :> Action {
            in sourceVoltage : Voltage;
            out outputVoltage : Voltage;
            out outputCurrent : Current;
        }
        
        action systemOperation : SystemOperation {
            perform {
                if (sourceVoltage > diode.forwardThreshold) {
                    outputCurrent = (sourceVoltage - diode.forwardThreshold) / (diode.forwardResistance + load.resistance);
                    outputVoltage = outputCurrent * load.resistance;
                } else if (sourceVoltage < -diode.reverseBreakdown) {
                    outputCurrent = (sourceVoltage + diode.reverseBreakdown) / (diode.breakdownResistance + load.resistance);
                    outputVoltage = outputCurrent * load.resistance;
                } else {
                    outputCurrent = 0.0;
                    outputVoltage = 0.0;
                }
            }
        }
        
        satisfy rectificationReq by systemOperation;
        satisfy diodeReq by diode;
        satisfy loadReq by load;
    }
}
