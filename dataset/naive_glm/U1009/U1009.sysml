package CNTFET_Model {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value type Voltage :> Real;
    value type Current :> Real;
    value type CurrentDensity :> Real;
    value type Length :> Real;
    value type Diameter :> Real;
    value type Capacitance :> Real;
    value type Resistance :> Real;
    value type Frequency :> Real;
    value type ElectricField :> Real;
    value type Time :> Real;
    value type Velocity :> Real;
    value type Permittivity :> Real;
    value type ChiralityIndex :> Integer;
    value type MaterialKind :> String;

    item def Electron;

    port def ElectricalPort {
        in voltage : Voltage;
        out current : Current;
    }

    port def GatePort {
        in gateVoltage : Voltage;
    }

    interface def CurrentFlow {
        end sourceSide : ElectricalPort;
        end drainSide : ElectricalPort;
        item electrons : Electron;
        flow electrons from sourceSide to drainSide;
    }

    interface def GateFieldCoupling {
        end gateSide : GatePort;
        end channelSide : GatePort;
    }

    part def Substrate {
        attribute material : MaterialKind = "Silicon";
        attribute thickness : Length = 500e-6 [m];
        attribute thermalConductivity : Real = 149;
    }

    part def DielectricLayer {
        attribute material : MaterialKind = "HfO2";
        attribute thickness : Length = 2e-9 [m];
        attribute relativePermittivity : Permittivity = 25.0;
        attribute gateCapacitance : Capacitance = 1.0e-17 [F];
        port dielectricTop : GatePort;
        port dielectricBottom : GatePort;
    }

    part def CarbonNanotube {
        attribute chiralityN : ChiralityIndex = 19;
        attribute chiralityM : ChiralityIndex = 0;
        attribute diameter : Diameter = 1.5e-9 [m];
        attribute length : Length = 100e-9 [m];
        attribute bandgap : Voltage = 0.5 [V];
        attribute thresholdVoltage : Voltage = 0.2 [V];
        attribute maxCurrentDensity : CurrentDensity = 1.0e10;
        attribute onResistance : Resistance = 10.0e3 [Ohm];
        attribute offResistance : Resistance = 1.0e9 [Ohm];
        attribute saturationVelocity : Velocity = 4.0e5;
        attribute mobility : Real = 10000;

        port channelEndA : ElectricalPort;
        port channelEndB : ElectricalPort;
        port gateCoupling : GatePort;

        attribute channelCurrent : Current = 0.0 [A];
        attribute isConducting : Boolean = false;
        attribute overdriveVoltage : Voltage = 0.0 [V];

        action def EvaluateConduction {
            in gateVoltage : Voltage;
            in drainVoltage : Voltage;
            in threshold : Voltage;
            in onRes : Resistance;
            out current : Current;
            out conducting : Boolean;
            out overdrive : Voltage;

            if gateVoltage > threshold {
                conducting = true;
                overdrive = gateVoltage - threshold;
                current = drainVoltage / onRes;
            } else {
                conducting = false;
                overdrive = 0.0 [V];
                current = 0.0 [A];
            }
        }

        compute evaluateChannel : EvaluateConduction {
            in gateVoltage = gateCoupling.gateVoltage;
            in drainVoltage = channelEndB.voltage;
            in threshold = thresholdVoltage;
            in onRes = onResistance;
            out current = channelCurrent;
            out conducting = isConducting;
            out overdrive = overdriveVoltage;
        }

        state machine ConductionStates {
            state Off;
            state Transitioning;
            state On;

            entry Off;

            transition offToTransitioning
                first Off
                when gateCoupling.gateVoltage > thresholdVoltage
                then Transitioning;

            transition transitioningToOn
                first Transitioning
                after 1.0e-12 [s]
                then On;

            transition onToOff
                first On
                when gateCoupling.gateVoltage <= thresholdVoltage
                then Off;
        }
    }

    part def MetalContact {
        attribute material : MaterialKind = "Palladium";
        attribute contactResistance : Resistance = 1.0e3 [Ohm];
        attribute workFunction : Voltage = 5.12 [V];
        attribute width : Length = 50e-9 [m];
        port terminal : ElectricalPort;
    }

    part def GateElectrode {
        attribute material : MaterialKind = "Aluminum";
        attribute workFunction : Voltage = 4.28 [V];
        attribute width : Length = 100e-9 [m];
        port gateTerminal : GatePort;
    }

    part def CNTFET {
        attribute thresholdVoltage : Voltage = 0.2 [V];
        attribute operatingFrequency : Frequency = 100.0e9 [Hz];
        attribute supplyVoltage : Voltage = 0.5 [V];
        attribute onOffRatio : Real = 1.0e5;
        attribute powerDissipation : Real = 1.0e-6;
        attribute subthresholdSlope : Real = 60.0;

        part substrate : Substrate;
        part dielectric : DielectricLayer;
        part channel : CarbonNanotube;
        part source : MetalContact {
            redefines material = "Palladium";
        }
        part drain : MetalContact {
            redefines material = "Palladium";
        }
        part gate : GateElectrode;

        port sourcePort : ElectricalPort;
        port drainPort : ElectricalPort;
        port gatePort : GatePort;

        connection sourceToChannel connect source.terminal to channel.channelEndA;
        connection drainToChannel connect drain.terminal to channel.channelEndB;
        connection gateToChannel connect gate.gateTerminal to channel.gateCoupling;
        connection gateToDielectric connect gate.gateTerminal to dielectric.dielectricTop;
        connection dielectricToChannel connect dielectric.dielectricBottom to channel.gateCoupling;

        connection extSource connect sourcePort to source.terminal;
        connection extDrain connect drainPort to drain.terminal;
        connection extGate connect gatePort to gate.gateTerminal;

        flow electrons : Electron from sourcePort to drainPort;

        state machine DeviceOperation {
            state OffState;
            state OnState;

            entry OffState;

            transition turnOn
                first OffState
                when gatePort.gateVoltage > thresholdVoltage
                then OnState;

            transition turnOff
                first OnState
                when gatePort.gateVoltage <= thresholdVoltage
                then OffState;
        }
    }

    requirement def LowThresholdRequirement {
        subject device : CNTFET;
        require device.thresholdVoltage <= 0.3 [V];
        doc /* The CNT-FET shall operate with a low threshold voltage for low-power switching. */
    }

    requirement def HighCurrentDensityRequirement {
        subject device : CNTFET;
        require device.channel.maxCurrentDensity >= 1.0e10;
        doc /* The CNT-FET channel shall sustain extremely high current densities. */
    }

    requirement def FastSwitchingRequirement {
        subject device : CNTFET;
        require device.operatingFrequency >= 50.0e9 [Hz];
        doc /* The CNT-FET shall support high-frequency operation for ultra-fast switching. */
    }

    requirement def LowLeakageRequirement {
        subject device : CNTFET;
        require device.channel.offResistance >= 1.0e9 [Ohm];
        doc /* The CNT-FET shall exhibit minimal off-state leakage current. */
    }

    requirement def HighOnOffRatioRequirement {
        subject device : CNTFET;
        require device.onOffRatio >= 1.0e4;
        doc /* The CNT-FET shall achieve a high on/off current ratio for reliable digital logic. */
    }

    requirement def SubthresholdSlopeRequirement {
        subject device : CNTFET;
        require device.subthresholdSlope <= 70.0;
        doc /* The CNT-FET shall have a near-ideal subthreshold swing. */
    }

    requirement CNTFETPerformanceSpec
        satisfies LowThresholdRequirement,
                HighCurrentDensityRequirement,
                FastSwitchingRequirement,
                LowLeakageRequirement,
                HighOnOffRatioRequirement,
                SubthresholdSlopeRequirement {
        subject device : CNTFET;
        doc /* Top-level performance specification for the Carbon Nanotube Field-Effect Transistor. */
    }

    part cntfetInstance : CNTFET {
        attribute thresholdVoltage = 0.2 [V];
        attribute operatingFrequency = 100.0e9 [Hz];
        attribute supplyVoltage = 0.5 [V];

        part channel {
            attribute chiralityN = 19;
            attribute chiralityM = 0;
            attribute thresholdVoltage = 0.2 [V];
        }

        part dielectric {
            attribute material = "HfO2";
            attribute thickness = 2.0e-9 [m];
        }

        part source {
            attribute material = "Palladium";
        }

        part drain {
            attribute material = "Palladium";
        }

        part gate {
            attribute material = "Aluminum";
        }

        part substrate {
            attribute material = "Silicon";
        }
    }
}
