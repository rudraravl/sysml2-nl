package PowerSwitchingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Resistance :> Real { unit 'Ohm'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def DutyCycle :> Real { unit '%'; }
    attribute def Temperature :> Real { unit 'degC'; }

    // ===== Item Types =====
    item def ElectricalEnergy;
    item def ControlSignal {
        attribute voltage : Voltage;
        attribute active : Boolean;
    }

    // ===== Port Definitions =====
    port def ElectricalPort {
        attribute voltage : Voltage;
        out item energy : ElectricalEnergy;
    }

    port def GatePort {
        in item signal : ControlSignal;
    }

    port def SourcePort {
        attribute voltage : Voltage;
        in item energy : ElectricalEnergy;
    }

    port def DrainPort {
        attribute voltage : Voltage;
        out item energy : ElectricalEnergy;
    }

    // ===== Requirements =====
    requirement def SwitchingRequirement {
        subject :> PowerSwitchingSystem;
        objective {
            doc "The system shall control power flow from the DC source to the load using the MOSFET as a switch.";
            constraint { subject.mosfet.state == 'On' implies subject.load.powered == true }
            constraint { subject.mosfet.state == 'Off' implies subject.load.powered == false }
        }
    }

    requirement def SafetyRequirement {
        subject :> PowerSwitchingSystem;
        attribute maxVoltage : Voltage = 24.0;
        attribute maxCurrent : Current = 10.0;
        attribute maxTemperature : Temperature = 125.0;
        objective {
            doc "The system shall operate within specified voltage, current, and temperature limits.";
            constraint { subject.dcSupply.outputVoltage <= maxVoltage }
            constraint { subject.load.current <= maxCurrent }
            constraint { subject.mosfet.temperature <= maxTemperature }
        }
    }

    requirement def EfficiencyRequirement {
        subject :> PowerSwitchingSystem;
        attribute minEfficiency : Real = 0.95;
        objective {
            doc "The system shall minimize power loss when the switch is in the on state.";
            constraint { subject.mosfet.state == 'On' implies (subject.load.power / subject.dcSupply.outputPower) >= minEfficiency }
        }
    }

    // ===== Components =====

    part def DCPowerSupply {
        attribute outputVoltage : Voltage = 12.0;
        attribute maxOutputCurrent : Current = 10.0;
        attribute outputPower : Power;
        attribute enabled : Boolean = true;

        port positive : ElectricalPort;
        port negative : ElectricalPort;

        action def GeneratePower {
            in v : Voltage;
            out energy : ElectricalEnergy;
        }

        perform action generate : GeneratePower {
            in v = outputVoltage;
            out energy = positive.energy;
        }

        satisfy SafetyRequirement by outputVoltage;
    }

    part def NChannelMOSFET {
        attribute gateThresholdVoltage : Voltage = 2.0;
        attribute onStateResistance : Resistance = 0.01;
        attribute maxDrainCurrent : Current = 20.0;
        attribute maxDrainSourceVoltage : Voltage = 60.0;
        attribute temperature : Temperature = 25.0;
        attribute state : String = "Off";

        port gate : GatePort;
        port drain : DrainPort;
        port source : SourcePort;

        state def MOSFETState {
            entry action;
            exit action;
            do action;
        }

        state machine MOSFETStateMachine {
            state Off {
                entry { state = "Off"; }
                do { drain.energy = null; }
            }
            state On {
                entry { state = "On"; }
                do { drain.energy = source.energy; }
            }
            transition On -> Off
                when gate.signal.voltage < gateThresholdVoltage
                guard gate.signal.active == false;
            transition Off -> On
                when gate.signal.voltage >= gateThresholdVoltage
                guard gate.signal.active == true;
        }

        exhibit state machine behavior : MOSFETStateMachine;

        satisfy SafetyRequirement by maxDrainSourceVoltage;
    }

    part def GateDriver {
        attribute controlVoltageHigh : Voltage = 5.0;
        attribute controlVoltageLow : Voltage = 0.0;
        attribute switchingFrequency : Frequency = 1000.0;
        attribute dutyCycle : DutyCycle = 50.0;
        attribute enabled : Boolean = true;

        port output : ElectricalPort;
        port ground : ElectricalPort;

        action def DriveGate {
            in active : Boolean;
            out signal : ControlSignal;
        }

        perform action drive : DriveGate {
            in active = enabled;
            out signal;
        }

        state def DriverState;
        state machine GateDriverStateMachine {
            state Idle {
                entry { output.voltage = controlVoltageLow; }
            }
            state Driving {
                entry { output.voltage = controlVoltageHigh; }
            }
            transition Idle -> Driving when enabled == true;
            transition Driving -> Idle when enabled == false;
        }

        exhibit state machine driverBehavior : GateDriverStateMachine;
    }

    part def ResistiveLoad {
        attribute resistance : Resistance = 10.0;
        attribute current : Current;
        attribute power : Power;
        attribute powered : Boolean = false;
        attribute maxPower : Power = 50.0;

        port positive : ElectricalPort;
        port negative : ElectricalPort;

        action def ConsumePower {
            in energy : ElectricalEnergy;
            out current : Current;
            out power : Power;
        }

        perform action consume : ConsumePower {
            in energy = positive.energy;
            out current;
            out power;
        }

        state def LoadState;
        state machine LoadStateMachine {
            state Unpowered {
                entry { powered = false; current = 0.0; power = 0.0; }
            }
            state Powered {
                entry { powered = true; }
                do {
                    current = positive.voltage / resistance;
                    power = positive.voltage * current;
                }
            }
            transition Unpowered -> Powered when positive.energy != null;
            transition Powered -> Unpowered when positive.energy == null;
        }

        exhibit state machine loadBehavior : LoadStateMachine;

        satisfy SafetyRequirement by maxPower;
    }

    // ===== System Assembly =====
    part def PowerSwitchingSystem {
        attribute systemVoltage : Voltage;
        attribute systemCurrent : Current;
        attribute systemEfficiency : Real;

        part dcSupply : DCPowerSupply {
            attribute outputVoltage = 12.0;
        }
        part mosfet : NChannelMOSFET {
            attribute gateThresholdVoltage = 2.0;
            attribute onStateResistance = 0.01;
        }
        part gateDriver : GateDriver {
            attribute controlVoltageHigh = 5.0;
            attribute switchingFrequency = 1000.0;
            attribute dutyCycle = 50.0;
        }
        part load : ResistiveLoad {
            attribute resistance = 10.0;
        }

        // Connections
        connection dcPositiveToLoad : ElectricalPort connect dcSupply.positive to load.positive;
        connection loadToDrain : ElectricalPort connect load.negative to mosfet.drain;
        connection mosfetToGround : ElectricalPort connect mosfet.source to dcSupply.negative;
        connection gateSignal : GatePort connect gateDriver.output to mosfet.gate;
        connection commonGround : ElectricalPort connect gateDriver.ground to dcSupply.negative;

        // Requirements satisfaction
        satisfy SwitchingRequirement;
        satisfy SafetyRequirement;
        satisfy EfficiencyRequirement;

        action def SystemOperation {
            in enable : Boolean;
            out loadPowered : Boolean;
        }

        perform action operate : SystemOperation {
            in enable;
            out loadPowered = load.powered;
        }
    }

    // ===== Verification =====
    verification def VerifySwitching {
        subject :> PowerSwitchingSystem;
        objective {
            doc "Verify the MOSFET switches the load on and off correctly.";
        }
        action {
            subject.gateDriver.enabled = true;
            assert subject.load.powered == true;
            subject.gateDriver.enabled = false;
            assert subject.load.powered == false;
        }
    }

    verification def VerifySafety {
        subject :> PowerSwitchingSystem;
        objective {
            doc "Verify the system operates within safe limits.";
        }
        action {
            assert subject.dcSupply.outputVoltage <= 24.0;
            assert subject.load.current <= 10.0;
            assert subject.mosfet.temperature <= 125.0;
        }
    }

    verification def VerifyEfficiency {
        subject :> PowerSwitchingSystem;
        objective {
            doc "Verify the system efficiency meets the minimum threshold.";
        }
        action {
            subject.gateDriver.enabled = true;
            assert (subject.load.power / subject.dcSupply.outputPower) >= 0.95;
        }
    }
}
