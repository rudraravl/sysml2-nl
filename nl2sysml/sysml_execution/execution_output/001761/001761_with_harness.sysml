package ClockSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TimeOfDay {
        attribute hours : Integer;
        attribute minutes : Integer;
        attribute seconds : Integer;
    }
    
    attribute def TickSignal;
    attribute def PowerCommand;
    attribute def PowerOnCommand :> PowerCommand;
    attribute def PowerOffCommand :> PowerCommand;
    
    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def PowerPort {
        in power : ElectricalPower;
    }
    
    port def TimeOutputPort {
        out currentTime : TimeOfDay;
    }
    
    part def Oscillator {
        attribute frequency : ISQ::FrequencyValue;
        port powerIn : PowerPort;
        out tickSignal : TickSignal;
        
        perform action generateTicks {
            out tick : TickSignal;
        }
    }
    
    part def TimeCounter {
        attribute storedTime : TimeOfDay;
        port powerIn : PowerPort;
        in tick : TickSignal;
        port timeOut : TimeOutputPort;
        
        perform action countTime {
            in tickInput : TickSignal;
            inout time : TimeOfDay;
            out updatedTime : TimeOfDay;
        }
    }
    
    part def DisplayUnit {
        attribute displayedTime : TimeOfDay;
        port powerIn : PowerPort;
        in timeData : TimeOfDay;
        
        perform action showTime {
            in timeValue : TimeOfDay;
        }
    }
    
    part def PowerSupply {
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        out suppliedPower : ElectricalPower;
    }
    
    action def IncrementSeconds {
        inout time : TimeOfDay;
        out newTime : TimeOfDay;
    }
    
    action def MaintainTime {
        in tickInterval : ISQ::DurationValue;
        out displayTime : TimeOfDay;
        
        private attribute currentTime : TimeOfDay {
            attribute hours = 0;
            attribute minutes = 0;
            attribute seconds = 0;
        }
        
        first start;
        then merge continueOperation;
        then action waitForTick {
            accept tick : TickSignal;
        }
        then action updateSeconds : IncrementSeconds {
            inout time = currentTime;
            out newTime;
        }
        then assign currentTime := updateSeconds.newTime;
        then action outputTime {
            assign displayTime := currentTime;
        }
        then continueOperation;
    }
    
    action def OperateClock {
        in operatingFrequency : ISQ::FrequencyValue;
        out timeDisplay : TimeOfDay;
        
        first start;
        then accept powerOn : PowerOnCommand;
        then action runClock {
            fork parallel;
            action oscillate {
                loop {
                    action generatePulse {
                        out pulse : TickSignal;
                    }
                }
            }
            action timekeeping : MaintainTime {
                in tickInterval = 1[s];
                out displayTime;
            }
            action displayUpdate {
                loop {
                    action refreshDisplay {
                        in timeValue = timekeeping.displayTime;
                    }
                }
            }
            join;
        }
        then accept powerOff : PowerOffCommand;
        then done;
    }
    
    part def Clock {
        doc /* A timekeeping device that continuously tracks and displays 
                the current time in hours, minutes, and seconds. */
        
        attribute operatingFrequency : ISQ::FrequencyValue = 1[Hz];
        
        part powerSupply : PowerSupply {
            attribute outputVoltage = 5[V];
            attribute outputCurrent = 0.5[A];
        }
        
        part oscillator : Oscillator {
            attribute frequency = operatingFrequency;
        }
        
        part counter : TimeCounter {
            attribute storedTime : TimeOfDay {
                attribute hours = 0;
                attribute minutes = 0;
                attribute seconds = 0;
            }
        }
        
        part display : DisplayUnit {
            attribute displayedTime : TimeOfDay;
        }
        
        connect powerSupply.suppliedPower to oscillator.powerIn;
        connect powerSupply.suppliedPower to counter.powerIn;
        connect powerSupply.suppliedPower to display.powerIn;
        
        connect oscillator.tickSignal to counter.tick;
        connect counter.timeOut to display.timeData;
        
        perform action operation : OperateClock {
            in operatingFrequency = Clock::operatingFrequency;
            out timeDisplay;
        }
    }
    
    part clock : Clock;
    
    requirement def TimekeepingRequirement {
        doc /* The clock system shall maintain accurate time by incrementing 
                seconds based on a stable oscillating signal. */
    }
    
    requirement def DisplayRequirement {
        doc /* The clock system shall continuously display the current time 
                in a human-readable format showing hours, minutes, and seconds. */
    }
    
    requirement def AccuracyRequirement {
        doc /* The clock system shall maintain time accuracy within 
                acceptable drift limits over a 24-hour period. */
        
        attribute maxDrift : ISQ::DurationValue = 2[s];
        attribute measurementPeriod : ISQ::DurationValue = 24[h];
    }
    
    requirement def PowerRequirement {
        doc /* The clock system shall operate continuously when supplied 
                with appropriate electrical power. */
        
        attribute requiredVoltage : ISQ::ElectricPotentialValue = 5[V];
        attribute requiredCurrent : ISQ::ElectricCurrentValue = 0.5[A];
    }
    
    requirement primaryClockFunction {
        doc /* The primary function of the clock system is to serve as 
                a reliable timekeeping device that accurately tracks and 
                displays the passage of time for users. */
        
        subject clock;
        
        require TimekeepingRequirement;
        require DisplayRequirement;
        require AccuracyRequirement;
        require PowerRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ClockSystem::*;

    action orchestrator {
        attribute testTickInterval : ISQ::DurationValue;
        action timekeepingProbe : MaintainTime {
            in tickInterval = testTickInterval;
        }
        first timekeepingProbe;
    }
}
