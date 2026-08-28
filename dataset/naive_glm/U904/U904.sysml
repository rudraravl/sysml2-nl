package DigitalTachometerSystem {
    import ScalarValues::*;
    import SI::*;
    import Time::*;

    value type RPM :> Real { unit "rev/min"; }
    value type PulseCount :> Integer;
    value type CalibrationFactor :> Real { unit "pulse/rev"; }
    value type TimeWindow :> Real { unit "s"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Frequency :> Real { unit "Hz"; }
    value type PowerState :> String;

    item def PulseSignal {
        attribute pulseCount : PulseCount;
        attribute timestamp : TimeWindow;
    }

    item def RPMReading {
        attribute value : RPM;
        attribute timestamp : TimeWindow;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    requirement def AccuracyRequirement {
        doc "The displayed RPM shall be within +/- 1% of the actual shaft RPM under steady-state conditions.";
        attribute maxErrorPercent : Real = 1.0;
        constraint { abs(displayedRPM - actualRPM) <= 0.01 * actualRPM }
    }

    requirement def ResponsivenessRequirement {
        doc "The display shall reflect a change in shaft speed within 200 ms of the change occurring.";
        attribute maxLatency : TimeWindow = 0.2 [s];
        constraint { latency <= maxLatency }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall operate continuously for at least 10000 hours without a critical failure.";
        attribute minMTBF : TimeWindow = 10000 [h];
    }

    requirement def RedlineRequirement {
        doc "The system shall enter a warning state and alert the user when the shaft speed exceeds the configured redline.";
        attribute redline : RPM = 7000 [rev/min];
    }

    requirement def PowerRequirement {
        doc "All components shall be powered from a single electrical source with nominal voltage 12 V.";
        attribute nominalVoltage : Voltage = 12.0 [V];
    }

    part def RotatingShaft {
        attribute angularSpeed : RPM;
        attribute maxSafeSpeed : RPM = 7000 [rev/min];
        port mechanicalInterface;
    }

    part def MagneticSensor {
        attribute calibrationFactor : CalibrationFactor = 1.0 [pulse/rev];
        attribute supplyVoltage : Voltage = 12.0 [V];
        attribute operatingCurrent : Current = 0.05 [A];
        attribute pulseAccumulator : PulseCount = 0;

        in port powerIn : ElectricalPower;
        in port shaftCoupling;
        out port pulseOut : PulseSignal;

        action def SenseRotation {
            in shaft : RotatingShaft;
            in calFactor : CalibrationFactor;
            out signal : PulseSignal;
            perform {
                emit pulseOut;
            }
        }

        perform SenseRotation;
    }

    part def SignalProcessor {
        attribute samplingWindow : TimeWindow = 0.1 [s];
        attribute calibrationFactor : CalibrationFactor = 1.0 [pulse/rev];
        attribute supplyVoltage : Voltage = 5.0 [V];
        attribute operatingCurrent : Current = 0.1 [A];
        attribute computedRPM : RPM = 0 [rev/min];
        attribute lastUpdateLatency : TimeWindow = 0 [s];

        in port powerIn : ElectricalPower;
        in port pulseIn : PulseSignal;
        out port rpmOut : RPMReading;

        action def ComputeRPM {
            in pulseSignal : PulseSignal;
            in window : TimeWindow;
            in calFactor : CalibrationFactor;
            out reading : RPMReading;
            private attribute countedPulses : PulseCount;
            private attribute pulseFrequency : Frequency;
            perform {
                countedPulses := pulseSignal.pulseCount;
                pulseFrequency := countedPulses / window;
                reading.value := (pulseFrequency / calFactor) * 60.0;
                reading.timestamp := pulseSignal.timestamp;
            }
        }

        perform ComputeRPM;
    }

    part def DigitalDisplay {
        attribute redline : RPM = 7000 [rev/min];
        attribute supplyVoltage : Voltage = 5.0 [V];
        attribute operatingCurrent : Current = 0.2 [A];
        attribute displayedRPM : RPM = 0 [rev/min];
        attribute powerOn : Boolean = false;
        attribute warningActive : Boolean = false;

        in port powerIn : ElectricalPower;
        in port rpmIn : RPMReading;

        action def RenderDisplay {
            in reading : RPMReading;
            in redlineLimit : RPM;
            perform {
                displayedRPM := reading.value;
                if displayedRPM >= redlineLimit {
                    warningActive := true;
                } else {
                    warningActive := false;
                }
            }
        }

        state machine DisplayStateMachine {
            entry; then Off;

            state Off {
                entry { displayedRPM := 0 [rev/min]; warningActive := false; }
            }
            state Idle {
                entry { displayedRPM := 0 [rev/min]; warningActive := false; }
            }
            state Active {
                entry { perform RenderDisplay; }
            }
            state Warning {
                entry { warningActive := true; perform RenderDisplay; }
            }

            transition Off_to_Idle
                first Off
                if (powerOn)
                then Idle;

            transition Idle_to_Active
                first Idle
                if (displayedRPM > 0 [rev/min])
                then Active;

            transition Active_to_Idle
                first Active
                if (displayedRPM == 0 [rev/min])
                then Idle;

            transition Active_to_Warning
                first Active
                if (displayedRPM >= redline)
                then Warning;

            transition Warning_to_Active
                first Warning
                if (displayedRPM < redline)
                then Active;

            transition Idle_to_Off
                first Idle
                if (not powerOn)
                then Off;

            transition Active_to_Off
                first Active
                if (not powerOn)
                then Off;

            transition Warning_to_Off
                first Warning
                if (not powerOn)
                then Off;
        }

        perform DisplayStateMachine;
    }

    part def PowerSource {
        attribute nominalVoltage : Voltage = 12.0 [V];
        attribute maxCurrent : Current = 5.0 [A];
        attribute outputState : PowerState = "on";
        out port powerOut : ElectricalPower;

        action def SupplyPower {
            out power : ElectricalPower;
            perform {
                power.voltage := nominalVoltage;
                power.current := maxCurrent;
            }
        }

        perform SupplyPower;
    }

    part def TachometerSystem {
        attribute systemRedline : RPM = 7000 [rev/min];
        attribute actualRPM : RPM = 0 [rev/min];
        attribute latency : TimeWindow = 0 [s];

        requirement accuracyReq : AccuracyRequirement;
        requirement responsivenessReq : ResponsivenessRequirement;
        requirement reliabilityReq : ReliabilityRequirement;
        requirement redlineReq : RedlineRequirement;
        requirement powerReq : PowerRequirement;

        part shaft : RotatingShaft {
            redefines attribute maxSafeSpeed = systemRedline;
        }

        part sensor : MagneticSensor {
            redefines attribute calibrationFactor = 1.0 [pulse/rev];
        }

        part processor : SignalProcessor {
            redefines attribute samplingWindow = 0.1 [s];
            redefines attribute calibrationFactor = sensor.calibrationFactor;
        }

        part display : DigitalDisplay {
            redefines attribute redline = systemRedline;
        }

        part power : PowerSource;

        connect shaft.mechanicalInterface to sensor.shaftCoupling;
        connect sensor.pulseOut to processor.pulseIn;
        connect processor.rpmOut to display.rpmIn;
        connect power.powerOut to sensor.powerIn;
        connect power.powerOut to processor.powerIn;
        connect power.powerOut to display.powerIn;

        item flow PulseSignal from sensor.pulseOut to processor.pulseIn;
        item flow RPMReading from processor.rpmOut to display.rpmIn;
        item flow ElectricalPower from power.powerOut to sensor.powerIn;
        item flow ElectricalPower from power.powerOut to processor.powerIn;
        item flow ElectricalPower from power.powerOut to display.powerIn;

        satisfy accuracyReq by display;
        satisfy responsivenessReq by processor;
        satisfy reliabilityReq by TachometerSystem;
        satisfy redlineReq by display;
        satisfy powerReq by power;
    }
}
