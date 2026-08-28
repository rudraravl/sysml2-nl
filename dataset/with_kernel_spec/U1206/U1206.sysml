package 'Silicene FET Model' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    port def ElectricalPort {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    part def SiliceneChannel {
        port sourceEnd : ElectricalPort;
        port drainEnd : ElectricalPort;
        port gateEnd : ElectricalPort;
        port substrateEnd : ElectricalPort;

        attribute thickness :> ISQ::length = 0.4 [nm];
        attribute electronMobility : ScalarValues::Real;
        attribute length :> ISQ::length;
        attribute width :> ISQ::length;
    }

    part def MetalContact {
        port contactEnd : ElectricalPort;
        attribute material : String;
    }

    part def Dielectric {
        port gateSide : ElectricalPort;
        port channelSide : ElectricalPort;
        attribute thickness :> ISQ::length;
        attribute permittivity : ScalarValues::Real;
    }

    part def GateElectrode {
        port gateEnd : ElectricalPort;
        attribute material : String;
    }

    part def Substrate {
        port substrateEnd : ElectricalPort;
        attribute material : String;
        attribute thermalConductivity : ScalarValues::Real;
    }

    state machine def FETOperation {
        state Cutoff {
            doc /* No current flows from source to drain. */
        }
        state Linear {
            doc /* Current flow is proportional to source-drain voltage. */
        }
        state Saturation {
            doc /* Current flow reaches maximum constant level. */
        }
        transition toLinear : Cutoff -> Linear {
            guard { gateVoltage > thresholdVoltage }
        }
        transition toSaturation : Linear -> Saturation {
            guard { sourceDrainVoltage > (gateVoltage - thresholdVoltage) }
        }
        transition toCutoff : Linear -> Cutoff {
            guard { gateVoltage <= thresholdVoltage }
        }
        transition toLinearFromSat : Saturation -> Linear {
            guard { sourceDrainVoltage <= (gateVoltage - thresholdVoltage) }
        }
    }

    part def SiliceneFET {
        port sourcePort : ElectricalPort;
        port drainPort : ElectricalPort;
        port gatePort : ElectricalPort;

        attribute thresholdVoltage :> ISQ::electricPotential = 0.3 [V];
        attribute drainCurrent :> ISQ::electricCurrent;
        attribute gateVoltage :> ISQ::electricPotential;
        attribute sourceDrainVoltage :> ISQ::electricPotential;

        part channel : SiliceneChannel;
        part source : MetalContact;
        part drain : MetalContact;
        part dielectric : Dielectric;
        part gate : GateElectrode;
        part substrate : Substrate;

        connect sourcePort to source.contactEnd;
        connect source.contactEnd to channel.sourceEnd;
        connect channel.drainEnd to drain.contactEnd;
        connect drain.contactEnd to drainPort;
        connect gatePort to gate.gateEnd;
        connect gate.gateEnd to dielectric.gateSide;
        connect dielectric.channelSide to channel.gateEnd;
        connect channel.substrateEnd to substrate.substrateEnd;

        state machine operation : FETOperation;
    }

    requirement def SwitchingTimeRequirement {
        subject fet : SiliceneFET;
        attribute actualSwitchingTime :> ISQ::time;
        attribute requiredSwitchingTime :> ISQ::time = 1 [ps];
        require constraint { actualSwitchingTime <= requiredSwitchingTime }
    }

    requirement def PowerConsumptionRequirement {
        subject fet : SiliceneFET;
        attribute actualPower :> ISQ::power;
        attribute maxPower :> ISQ::power = 1 [uW];
        require constraint { actualPower <= maxPower }
    }

    requirement def ScalingRequirement {
        subject fet : SiliceneFET;
        attribute gateLength :> ISQ::length;
        attribute maxLength :> ISQ::length = 10 [nm];
        require constraint { gateLength <= maxLength }
    }

    part highPerfFET : SiliceneFET {
        attribute :>> thresholdVoltage = 0.25 [V];
        part :>> channel {
            attribute :>> electronMobility = 1000;
            attribute :>> length = 5 [nm];
        }
        requirement switchTime : SwitchingTimeRequirement {
            attribute :>> actualSwitchingTime = 0.8 [ps];
        }
        requirement powerCons : PowerConsumptionRequirement {
            attribute :>> actualPower = 0.5 [uW];
        }
        requirement scaling : ScalingRequirement {
            attribute :>> gateLength = 5 [nm];
        }
    }
}
