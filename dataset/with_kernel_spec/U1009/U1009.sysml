package 'CNT-FET Model' {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def Voltage :> ElectricPotentialDifferenceValue;
    attribute def Current :> ElectricCurrentValue;
    attribute def CurrentDensity :> Real;
    attribute def ChiralityVector :> String;

    port def 'Electrical Port' {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def 'Electron';

    part def 'Carbon Nanotube' {
        attribute chirality : ChiralityVector;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        port sourceEnd : 'Electrical Port';
        port drainEnd : 'Electrical Port';
    }

    part def 'Metal Contact' {
        attribute material : String;
        port terminal : 'Electrical Port';
    }

    part def 'Substrate' {
        attribute material : String;
    }

    part def 'Dielectric Layer' {
        attribute material : String;
        attribute thickness : LengthValue;
    }

    part def 'Gate Electrode' {
        attribute material : String;
        port gateTerminal : 'Electrical Port';
    }

    interface def 'Current Flow Interface' {
        end supplier : 'Electrical Port';
        end consumer : 'Electrical Port';
        flow of 'Electron' from supplier to consumer;
    }

    interface def 'Gate Control Interface' {
        end controlPort : 'Electrical Port';
        end gatePort : 'Electrical Port';
    }

    calc def 'Evaluate Switching State' {
        in V_gate : Voltage;
        in V_threshold : Voltage;
        return isOn : Boolean = V_gate > V_threshold;
    }

    part def 'CNT-FET' {
        attribute thresholdVoltage : Voltage;
        attribute gateVoltage : Voltage;
        attribute drainCurrent : Current;
        attribute currentDensity : CurrentDensity;

        part substrate : Substrate {
            attribute :>> material = "Silicon";
        }

        part channel : 'Carbon Nanotube' {
            attribute :>> chirality = "(10,0)";
        }

        part source : 'Metal Contact' {
            attribute :>> material = "Palladium";
        }

        part drain : 'Metal Contact' {
            attribute :>> material = "Palladium";
        }

        part dielectric : 'Dielectric Layer' {
            attribute :>> material = "Hafnium Dioxide";
        }

        part gate : 'Gate Electrode' {
            attribute :>> material = "Aluminum";
        }

        port extSourcePort : 'Electrical Port';
        port extDrainPort : 'Electrical Port';
        port extGatePort : 'Electrical Port';

        interface : 'Current Flow Interface' connect
            supplier ::> extSourcePort to
            consumer ::> source.terminal;

        interface : 'Current Flow Interface' connect
            supplier ::> source.terminal to
            consumer ::> channel.sourceEnd;

        interface : 'Current Flow Interface' connect
            supplier ::> channel.drainEnd to
            consumer ::> drain.terminal;

        interface : 'Current Flow Interface' connect
            supplier ::> drain.terminal to
            consumer ::> extDrainPort;

        interface : 'Gate Control Interface' connect
            controlPort ::> extGatePort to
            gatePort ::> gate.gateTerminal;

        state machine def 'Operating States' {
            state Off;
            state On;
            transition from Off to On when gateVoltage > thresholdVoltage;
            transition from On to Off when gateVoltage <= thresholdVoltage;
        }

        perform 'Operating States';
    }

    requirement def 'Low Power Operation' {
        subject device : 'CNT-FET';
        constraint { device.drainCurrent < 1e-6 }
    }

    requirement def 'Low Threshold Voltage' {
        subject device : 'CNT-FET';
        constraint { device.thresholdVoltage < 0.3 }
    }

    requirement def 'High Current Density' {
        subject device : 'CNT-FET';
        constraint { device.currentDensity > 1e7 }
    }

    part 'CNT-FET Device' : 'CNT-FET' {
        satisfy 'Low Power Operation';
        satisfy 'Low Threshold Voltage';
        satisfy 'High Current Density';
    }
}
