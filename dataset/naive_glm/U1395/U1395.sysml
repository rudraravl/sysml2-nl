package DigitalClockSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real {
        attribute unit : String = "V";
    }
    value def Frequency :> Real {
        attribute unit : String = "Hz";
    }
    value def TimeValue :> Real {
        attribute unit : String = "s";
    }
    value def Drift :> Real {
        attribute unit : String = "s";
    }

    item def TickSignal {
        attribute timestamp : TimeValue;
    }

    item def TimeData {
        attribute hours : Integer;
        attribute minutes : Integer;
        attribute seconds : Integer;
    }

    // ===== Requirements =====
    requirement def AccuracyRequirement {
        doc "The clock shall not lose or gain more than 2 seconds over a 24-hour period.";
        attribute maxDrift : Drift = 2.0;
        subject clock : DigitalClock;
        require clock.driftOver24h <= maxDrift;
    }

    requirement def PowerStabilityRequirement {
        doc "The power supply shall provide a steady 5V output.";
        subject powerSupply : PowerSupply;
        require powerSupply.outputVoltage == 5.0;
    }

    requirement def OscillatorFrequencyRequirement {
        doc "The oscillator shall generate a 1 Hz signal.";
        subject oscillator : Oscillator;
        require oscillator.nominalFrequency == 1.0;
    }

    requirement def DisplayUpdateRequirement {
        doc "The display shall update continuously with the latest time data.";
        subject display : DisplayUnit;
        require display.updateRate >= 1.0;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out voltage : Voltage;
    }

    port def TickPort {
        out tick : TickSignal;
    }

    port def TimePort {
        out time : TimeData;
    }

    // ===== Components =====
    part def PowerSupply {
        attribute outputVoltage : Voltage = 5.0;
        port powerOut : PowerPort;
        exhibit state PowerState {
            entry;
            state On {
                entry;
                do send PowerPort.voltage = 5.0;
            }
            state Off;
            transition Off -> On when true;
        }
        satisfy PowerStabilityRequirement;
    }

    part def Oscillator {
        attribute nominalFrequency : Frequency = 1.0;
        port powerIn : PowerPort;
        port tickOut : TickPort;
        exhibit state OscillatorState {
            state Idle;
            state Running {
                do every 1.0 [s] {
                    send TickSignal{timestamp = 1.0} via tickOut;
                }
            }
            transition Idle -> Running when powerIn.voltage == 5.0;
        }
        satisfy OscillatorFrequencyRequirement;
    }

    part def TimeCounter {
        attribute hours : Integer = 0;
        attribute minutes : Integer = 0;
        attribute seconds : Integer = 0;
        port powerIn : PowerPort;
        port tickIn : TickPort;
        port timeOut : TimePort;
        action incrementTime {
            in tick : TickSignal;
            then {
                seconds += 1;
                if seconds >= 60 {
                    seconds = 0;
                    minutes += 1;
                    if minutes >= 60 {
                        minutes = 0;
                        hours += 1;
                        if hours >= 24 {
                            hours = 0;
                        }
                    }
                }
                send TimeData{hours = hours, minutes = minutes, seconds = seconds} via timeOut;
            }
        }
        exhibit state CounterState {
            state Idle;
            state Counting {
                accept tick : TickSignal via tickIn
                    then incrementTime(tick);
            }
            transition Idle -> Counting when powerIn.voltage == 5.0;
        }
    }

    part def DisplayUnit {
        attribute updateRate : Frequency = 1.0;
        attribute displayedHours : Integer = 0;
        attribute displayedMinutes : Integer = 0;
        attribute displayedSeconds : Integer = 0;
        port powerIn : PowerPort;
        port timeIn : TimePort;
        action render {
            in time : TimeData;
            then {
                displayedHours = time.hours;
                displayedMinutes = time.minutes;
                displayedSeconds = time.seconds;
            }
        }
        exhibit state DisplayState {
            state Idle;
            state Active {
                accept time : TimeData via timeIn
                    then render(time);
            }
            transition Idle -> Active when powerIn.voltage == 5.0;
        }
        satisfy DisplayUpdateRequirement;
    }

    // ===== System =====
    part def DigitalClock {
        attribute driftOver24h : Drift = 0.0;
        part powerSupply : PowerSupply {
            port powerOut;
        }
        part oscillator : Oscillator {
            port powerIn;
            port tickOut;
        }
        part timeCounter : TimeCounter {
            port powerIn;
            port tickIn;
            port timeOut;
        }
        part displayUnit : DisplayUnit {
            port powerIn;
            port timeIn;
        }
        connection powerToOscillator connect powerSupply.powerOut to oscillator.powerIn;
        connection powerToCounter connect powerSupply.powerOut to timeCounter.powerIn;
        connection powerToDisplay connect powerSupply.powerOut to displayUnit.powerIn;
        connection tickToCounter connect oscillator.tickOut to timeCounter.tickIn;
        connection timeToDisplay connect timeCounter.timeOut to displayUnit.timeIn;
        satisfy AccuracyRequirement;
    }

    // ===== Instance =====
    part digitalClock : DigitalClock;
}
