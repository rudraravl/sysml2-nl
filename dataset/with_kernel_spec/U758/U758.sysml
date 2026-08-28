package 'MOSFET Power Switching System' {
    private import ScalarValues::*;

    unit volt;
    unit ampere;
    unit ohm;
    unit watt;

    value type Voltage :> Real { unit volt; }
    value type Current :> Real { unit ampere; }
    value type Resistance :> Real { unit ohm; }
    value type Power :> Real { unit watt; }

    item def Electricity {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def GateSignal {
        attribute voltage : Voltage;
    }

    item def LogicLevel {
        attribute value : Boolean;
    }

    port def PowerPort {
        out item electricity : Electricity;
    }

    port def PowerInPort {
        in item electricity : Electricity;
    }

    port def GateOutPort {
        out item gateSignal : GateSignal;
    }

    port def GateInPort {
        in item gateSignal : GateSignal;
    }

    port def LogicInPort {
        in item logicSignal : LogicLevel;
    }

    part def DCPowerSupply {
        attribute nominalVoltage : Voltage;
        attribute maxCurrent : Current;
        port positiveOut : PowerPort;
        port negativeReturn : PowerInPort;
    }

    part def ResistiveLoad {
        attribute resistance : Resistance;
        attribute maxPowerDissipation : Power;
        port loadIn : PowerInPort;
        port loadOut : PowerPort;
    }

    action def ConductionControl {
        in gateVoltage : Voltage;
        in thresholdVoltage : Voltage;
        out isConducting : Boolean;
    }

    action def DriveGate {
        in logicLevel : LogicLevel;
        out gateSignal : GateSignal;
    }

    part def NChannelMOSFET {
        attribute thresholdVoltage : Voltage;
        attribute onResistance : Resistance;
        attribute maxDrainCurrent : Current;
        attribute maxDrainSourceVoltage : Voltage;
        attribute isConducting : Boolean;
        port drain : PowerInPort;
        port source : PowerPort;
        port gate : GateInPort;

        perform action conductionControl : ConductionControl {
            in gateVoltage = gate.gateSignal.voltage;
            in thresholdVoltage = thresholdVoltage;
            out isConducting = isConducting;
        }
    }

    part def GateDriver {
        attribute controlVoltageHigh : Voltage;
        attribute controlVoltageLow : Voltage;
        port logicIn : LogicInPort;
        port gateOut : GateOutPort;

        perform action driveGate : DriveGate {
            in logicLevel = logicIn.logicSignal;
            out gateSignal = gateOut.gateSignal;
        }
    }

    requirement def SafeOperatingLimits {
        text "The system must operate within specified voltage and current limits to prevent component damage.";
        attribute maxSystemVoltage : Voltage;
        attribute maxSystemCurrent : Current;
        attribute maxDrainSourceVoltage : Voltage;
    }

    requirement def EfficientSwitching {
        text "Power loss in the on state must be minimized for high efficiency.";
        attribute maxOnResistance : Resistance;
    }

    part powerSwitchingSystem {
        part supply : DCPowerSupply {
            attribute nominalVoltage = 24 [volt];
            attribute maxCurrent = 10 [ampere];
        }

        part load : ResistiveLoad {
            attribute resistance = 10 [ohm];
            attribute maxPowerDissipation = 100 [watt];
        }

        part mosfet : NChannelMOSFET {
            attribute thresholdVoltage = 2 [volt];
            attribute onResistance = 0.1 [ohm];
            attribute maxDrainCurrent = 50 [ampere];
            attribute maxDrainSourceVoltage = 60 [volt];
        }

        part driver : GateDriver {
            attribute controlVoltageHigh = 5 [volt];
            attribute controlVoltageLow = 0 [volt];
        }

        flow of Electricity
            from supply.positiveOut.electricity to load.loadIn.electricity;

        flow of Electricity
            from load.loadOut.electricity to mosfet.drain.electricity;

        flow of Electricity
            from mosfet.source.electricity to supply.negativeReturn.electricity;

        flow of GateSignal
            from driver.gateOut.gateSignal to mosfet.gate.gateSignal;

        requirement safeOp : SafeOperatingLimits {
            attribute maxSystemVoltage = 24 [volt];
            attribute maxSystemCurrent = 10 [ampere];
            attribute maxDrainSourceVoltage = 60 [volt];
        }

        requirement efficient : EfficientSwitching {
            attribute maxOnResistance = 0.1 [ohm];
        }

        satisfy safeOp by mosfet;
        satisfy efficient by mosfet;
    }
}
