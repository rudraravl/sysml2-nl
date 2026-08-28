package ElectronMultiplierSystem {
    import ScalarValues::*;
    import SI::*;

    value type VoltageValue :> Real = V;
    value type CurrentValue :> Real = A;
    value type PressureValue :> Real = Pa;
    value type ChargeValue :> Real = C;
    value type GainValue :> Real;

    item def Electron;

    port def ElectronInput {
        in e : Electron;
    }
    port def ElectronOutput {
        out e : Electron[1..*];
    }
    port def HVInput {
        in v : VoltageValue;
    }
    port def SignalOutput {
        out current : CurrentValue;
        out voltage : VoltageValue;
    }

    part def VacuumChamber {
        attribute internalPressure : PressureValue = 1e-5;
    }

    part def HighVoltageSupply {
        attribute outputVoltage : VoltageValue = 2000;
        port out hvOutput : HVInput;
    }

    part def Dynode {
        attribute dynodeIndex : Integer;
        attribute gain : GainValue = 4.0;
        port in electronInput : ElectronInput;
        port out electronOutput : ElectronOutput;
        port in hvInput : HVInput;

        action def SecondaryEmission {
            in incomingElectron : Electron;
            out secondaryElectrons : Electron[1..*];
        }

        state def DynodeStateMachine {
            state Idle;
            state Impact;
            state Emission;
            transition Idle to Impact;
            transition Impact to Emission;
            transition Emission to Idle;
        }
    }

    part def Anode {
        port in electronInput : ElectronInput;
        port in hvInput : HVInput;
        port out signalOutput : SignalOutput;

        action def ChargeCollection {
            in electronPulse : Electron[1..*];
            out currentOut : CurrentValue;
            out voltageOut : VoltageValue;
        }

        state def AnodeStateMachine {
            state Waiting;
            state Collecting;
            transition Waiting to Collecting;
            transition Collecting to Waiting;
        }
    }

    part def StandardElectronics {
        port in signalInput : SignalOutput;
    }

    part def ElectronMultiplier {
        part vacuumChamber : VacuumChamber;
        part powerSupply : HighVoltageSupply;
        part dynodes : Dynode[10];
        part anode : Anode;
        part electronics : StandardElectronics;

        port in systemInput : ElectronInput;
        port out systemOutput : SignalOutput;

        connection hv1 connect powerSupply.hvOutput to dynodes[1].hvInput;
        connection hv2 connect powerSupply.hvOutput to dynodes[2].hvInput;
        connection hv3 connect powerSupply.hvOutput to dynodes[3].hvInput;
        connection hv4 connect powerSupply.hvOutput to dynodes[4].hvInput;
        connection hv5 connect powerSupply.hvOutput to dynodes[5].hvInput;
        connection hv6 connect powerSupply.hvOutput to dynodes[6].hvInput;
        connection hv7 connect powerSupply.hvOutput to dynodes[7].hvInput;
        connection hv8 connect powerSupply.hvOutput to dynodes[8].hvInput;
        connection hv9 connect powerSupply.hvOutput to dynodes[9].hvInput;
        connection hv10 connect powerSupply.hvOutput to dynodes[10].hvInput;
        connection hvAnode connect powerSupply.hvOutput to anode.hvInput;

        connection eInput connect systemInput to dynodes[1].electronInput;
        connection e1to2 connect dynodes[1].electronOutput to dynodes[2].electronInput;
        connection e2to3 connect dynodes[2].electronOutput to dynodes[3].electronInput;
        connection e3to4 connect dynodes[3].electronOutput to dynodes[4].electronInput;
        connection e4to5 connect dynodes[4].electronOutput to dynodes[5].electronInput;
        connection e5to6 connect dynodes[5].electronOutput to dynodes[6].electronInput;
        connection e6to7 connect dynodes[6].electronOutput to dynodes[7].electronInput;
        connection e7to8 connect dynodes[7].electronOutput to dynodes[8].electronInput;
        connection e8to9 connect dynodes[8].electronOutput to dynodes[9].electronInput;
        connection e9to10 connect dynodes[9].electronOutput to dynodes[10].electronInput;
        connection e10toAnode connect dynodes[10].electronOutput to anode.electronInput;

        connection anodeToSysOut connect anode.signalOutput to systemOutput;
        connection sysOutToElectronics connect systemOutput to electronics.signalInput;
    }

    requirement def DetectorFunctionRequirement {
        doc "The system shall amplify a single incoming electron into a large, measurable electrical pulse.";
        subject multi : ElectronMultiplier;
        require { multi.dynodes->size() == 10 }
    }

    requirement def VacuumOperationRequirement {
        doc "The dynodes shall be housed within a high-vacuum chamber to ensure free electron travel.";
        subject chamber : VacuumChamber;
        attribute maxPressure : PressureValue = 1e-5;
        require { chamber.internalPressure <= maxPressure }
    }

    requirement def HighVoltagePowerRequirement {
        doc "The system shall be driven by a stable high-voltage power supply.";
        subject supply : HighVoltageSupply;
        attribute minVoltage : VoltageValue = 1000;
        require { supply.outputVoltage >= minVoltage }
    }

    requirement def TotalAmplificationRequirement {
        doc "The cascade of 10 dynodes shall amplify a single electron into millions of electrons.";
        subject sys : ElectronMultiplier;
        attribute minTotalGain : GainValue = 1000000;
        require { sys.dynodes[1].gain ^ 10 >= minTotalGain }
    }

    requirement def AnodeOutputRequirement {
        doc "The anode shall convert the collected charge into a distinct current and voltage signal.";
        subject anode : Anode;
        require { anode.signalOutput->notEmpty() }
    }
}
