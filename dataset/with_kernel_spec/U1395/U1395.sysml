package DigitalClockSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    alias Voltage for ElectricPotentialValue;
    alias Frequency for FrequencyValue;
    alias TimeDuration for TimeValue;

    item def Power {
        attribute voltage : Voltage := 5 [V];
    }

    item def Tick;

    item def TimeData {
        attribute hours : Integer := 0;
        attribute minutes : Integer := 0;
        attribute seconds : Integer := 0;
    }

    port def PowerOutPort {
        out power : Power;
    }

    port def PowerInPort {
        in power : Power;
    }

    port def TickOutPort {
        out tick : Tick;
    }

    port def TickInPort {
        in tick : Tick;
    }

    port def TimeOutPort {
        out time : TimeData;
    }

    port def TimeInPort {
        in time : TimeData;
    }

    part def PowerSupply {
        out port powerOut : PowerOutPort;
        attribute outputVoltage : Voltage := 5 [V];
        action generatePower {
            assign outputVoltage := 5 [V];
        }
    }

    part def Oscillator {
        in port powerIn : PowerInPort;
        out port tickOut : TickOutPort;
        attribute frequency : Frequency := 1 [Hz];
        action generateTick {
            assign frequency := 1 [Hz];
        }
    }

    part def TimeCounter {
        in port powerIn : PowerInPort;
        in port tickIn : TickInPort;
        out port timeOut : TimeOutPort;

        attribute currentTime : TimeData;

        action incrementTime {
            assign currentTime.seconds := if currentTime.seconds < 59 ? currentTime.seconds + 1 else 0;
            assign currentTime.minutes := if currentTime.seconds == 0 ? (if currentTime.minutes < 59 ? currentTime.minutes + 1 else 0) else currentTime.minutes;
            assign currentTime.hours := if currentTime.seconds == 0 ? (if currentTime.minutes == 0 ? (if currentTime.hours < 23 ? currentTime.hours + 1 else 0) else currentTime.hours) else currentTime.hours;
        }

        state def Counting {
            entry assign currentTime.hours := 0;
            then state waiting;
            accept Tick
                then incrementing;
            state incrementing {
                do perform incrementTime;
            }
            then waiting;
        }
    }

    part def DisplayUnit {
        in port powerIn : PowerInPort;
        in port timeIn : TimeInPort;

        action displayTime;

        state def Displaying {
            entry perform displayTime;
            then state active;
            accept TimeData
                then rendering;
            state rendering {
                do perform displayTime;
            }
            then active;
        }
    }

    part def DigitalClock {
        part powerSupply : PowerSupply;
        part oscillator : Oscillator;
        part timeCounter : TimeCounter;
        part displayUnit : DisplayUnit;

        connect powerSupply.powerOut to oscillator.powerIn;
        connect powerSupply.powerOut to timeCounter.powerIn;
        connect powerSupply.powerOut to displayUnit.powerIn;
        connect oscillator.tickOut to timeCounter.tickIn;
        connect timeCounter.timeOut to displayUnit.timeIn;

        state def Running {
            entry perform powerSupply.generatePower;
            then state operational;
            state operational {
                do perform oscillator.generateTick;
                do perform timeCounter.incrementTime;
                do perform displayUnit.displayTime;
            }
        }
    }

    requirement def ClockAccuracy {
        doc "The clock shall not lose or gain more than 2 seconds over a 24-hour period.";
        attribute maxDrift : TimeDuration := 2 [s];
        attribute testPeriod : TimeDuration := 24 [h];
    }

    requirement accurateClock : ClockAccuracy {
        subject clock : DigitalClock;
    }
}
