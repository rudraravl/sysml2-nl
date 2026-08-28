package 'AC-to-DC Power Converter' {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    item def ACInput {
        attribute voltage : ElectricPotentialValue = 120 [V];
        attribute frequency : FrequencyValue = 60 [Hz];
    }
    item def DCOutput {
        attribute voltage : ElectricPotentialValue;
        attribute ripple : Real;
    }
    item def VoltageStatus {
        attribute isFault : Boolean;
    }
    item def ElectricalNode;

    part def Diode {
        port anode : ElectricalNode;
        port cathode : ElectricalNode;
    }

    part def FullWaveBridgeRectifier {
        port acPositive : ElectricalNode;
        port acNegative : ElectricalNode;
        port dcPositive : ElectricalNode;
        port dcNegative : ElectricalNode;
        part d1 : Diode;
        part d2 : Diode;
        part d3 : Diode;
        part d4 : Diode;
        connect acPositive to d1.anode;
        connect acPositive to d3.cathode;
        connect acNegative to d2.anode;
        connect acNegative to d4.cathode;
        connect d1.cathode to dcPositive;
        connect d2.cathode to dcPositive;
        connect d3.anode to dcNegative;
        connect d4.anode to dcNegative;
    }

    part def SmoothingCapacitor {
        attribute capacitance : CapacitanceValue = 0.001 [F];
        port positive : ElectricalNode;
        port negative : ElectricalNode;
    }

    part def LoadResistor {
        attribute resistance : ResistanceValue = 100 [ohm];
        port positive : ElectricalNode;
        port negative : ElectricalNode;
    }

    part def VoltageMonitor {
        attribute minSafeVoltage : ElectricPotentialValue = 11.5 [V];
        attribute maxSafeVoltage : ElectricPotentialValue = 12.5 [V];
        port sensePositive : ElectricalNode;
        port senseNegative : ElectricalNode;
        out item status : VoltageStatus;
    }

    part def ACSource {
        attribute voltage : ElectricPotentialValue = 120 [V];
        attribute frequency : FrequencyValue = 60 [Hz];
        port hot : ElectricalNode;
        port neutral : ElectricalNode;
    }

    action def WaitForPower;
    action def InitializeConverter;
    action def EnterFault;

    action def RectifyAC {
        in acHot : ElectricalNode;
        in acNeutral : ElectricalNode;
        out dcPositive : ElectricalNode;
        out dcNegative : ElectricalNode;
    }
    action def FilterDC {
        in dcPositive : ElectricalNode;
        in dcNegative : ElectricalNode;
        out smoothPositive : ElectricalNode;
        out smoothNegative : ElectricalNode;
    }
    action def SupplyLoad {
        in smoothPositive : ElectricalNode;
        in smoothNegative : ElectricalNode;
        out loadPositive : ElectricalNode;
        out loadNegative : ElectricalNode;
    }
    action def MonitorOutput {
        in sensePositive : ElectricalNode;
        in senseNegative : ElectricalNode;
        out status : VoltageStatus;
    }

    action def ConvertACtoDC {
        in sourceHot : ElectricalNode;
        in sourceNeutral : ElectricalNode;

        first start;
        then action wait : WaitForPower;
        then action initialize : InitializeConverter;
        then loop action conversion {
            action rectify : RectifyAC {
                in acHot = sourceHot;
                in acNeutral = sourceNeutral;
                out dcPositive;
                out dcNegative;
            }
            then action smoothing : FilterDC {
                in dcPositive = rectify.dcPositive;
                in dcNegative = rectify.dcNegative;
                out smoothPositive;
                out smoothNegative;
            }
            then action supply : SupplyLoad {
                in smoothPositive = smoothing.smoothPositive;
                in smoothNegative = smoothing.smoothNegative;
                out loadPositive;
                out loadNegative;
            }
            then action monitor : MonitorOutput {
                in sensePositive = supply.loadPositive;
                in senseNegative = supply.loadNegative;
                out status;
            }
        } until conversion.monitor.status.isFault == true;
        then action fault : EnterFault;
        then done;
    }

    part def ACDCConverter {
        attribute powerAvailable : Boolean;
        attribute reset : Boolean;
        attribute isFault : Boolean;
        port acHot : ElectricalNode;
        port acNeutral : ElectricalNode;
        port dcPositive : ElectricalNode;
        port dcNegative : ElectricalNode;
        out item status : VoltageStatus;

        part acSource : ACSource;
        part rectifier : FullWaveBridgeRectifier;
        part capacitor : SmoothingCapacitor;
        part load : LoadResistor;
        part monitor : VoltageMonitor;

        connect acSource.hot to acHot;
        connect acSource.neutral to acNeutral;
        connect acHot to rectifier.acPositive;
        connect acNeutral to rectifier.acNegative;
        connect rectifier.dcPositive to capacitor.positive;
        connect rectifier.dcPositive to load.positive;
        connect rectifier.dcPositive to dcPositive;
        connect rectifier.dcNegative to capacitor.negative;
        connect rectifier.dcNegative to load.negative;
        connect rectifier.dcNegative to dcNegative;
        connect load.positive to monitor.sensePositive;
        connect load.negative to monitor.senseNegative;
        connect monitor.status to status;

        state machine ConverterControl {
            state idle;
            state initializing;
            state operating;
            state fault;
            transition t1 {
                source idle;
                target initializing;
                guard powerAvailable == true;
            }
            transition t2 {
                source initializing;
                target operating;
            }
            transition t3 {
                source operating;
                target fault;
                guard monitor.status.isFault == true;
            }
            transition t4 {
                source fault;
                target idle;
                guard reset == true;
            }
        }
    }

    requirement def OutputVoltageRange {
        attribute minVoltage : ElectricPotentialValue = 11.5 [V];
        attribute maxVoltage : ElectricPotentialValue = 12.5 [V];
        constraint { dcPositive.voltage >= minVoltage and dcPositive.voltage <= maxVoltage }
    }
    requirement def RippleLimit {
        attribute maxRipple : Real = 0.05;
        constraint { DCOutput.ripple <= maxRipple }
    }
    requirement def InputSpecification {
        attribute nominalVoltage : ElectricPotentialValue = 120 [V];
        attribute nominalFrequency : FrequencyValue = 60 [Hz];
    }

    requirement outputVoltageRange : OutputVoltageRange;
    requirement rippleLimit : RippleLimit;
    requirement inputSpec : InputSpecification;

    part converter : ACDCConverter;
}
