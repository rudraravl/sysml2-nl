package 'Prosorba Immunoadsorption System' {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def DurationValue :> Real;
    attribute def ConcentrationValue :> Real;

    item def WholeBlood {
        attribute volume : VolumeValue;
        attribute iggConcentration : ConcentrationValue;
    }
    item def Plasma {
        attribute volume : VolumeValue;
        attribute iggConcentration : ConcentrationValue;
    }
    item def BloodCells {
        attribute volume : VolumeValue;
    }
    item def TreatedPlasma :> Plasma;
    item def ReconstitutedBlood {
        attribute volume : VolumeValue;
        attribute iggConcentration : ConcentrationValue;
    }
    item def SalineSolution {
        attribute volume : VolumeValue;
    }
    item def ProteinA;
    item def AlarmSignal;
    item def PrimeComplete;
    item def RinseComplete;

    port def FluidPort;
    port def SignalPort;

    action def TreatBlood {
        in wholeBlood : WholeBlood;
        out reconstitutedBlood : ReconstitutedBlood;
        action separate {
            in blood : WholeBlood;
            out plasma : Plasma;
            out cells : BloodCells;
        }
        action adsorb {
            in plasma : Plasma;
            out treatedPlasma : TreatedPlasma;
        }
        action recombine {
            in cells : BloodCells;
            in treatedPlasma : TreatedPlasma;
            out reconstitutedBlood : ReconstitutedBlood;
        }
        flow from wholeBlood to separate.blood;
        flow from separate.plasma to adsorb.plasma;
        flow from separate.cells to recombine.cells;
        flow from adsorb.treatedPlasma to recombine.treatedPlasma;
        flow from recombine.reconstitutedBlood to reconstitutedBlood;
    }

    action def PrimeCircuit {
        in saline : SalineSolution;
        out primed : Boolean;
    }

    action def RinseCircuit {
        in saline : SalineSolution;
        out rinsed : Boolean;
    }

    action def MonitorSafety {
        in pressure : PressureValue;
        in flowRate : FlowRateValue;
        out alarm : AlarmSignal;
    }

    action def ReturnBlood;
    action def StopPump;
    action def ActivateAlarm;

    part def Patient {
        port bloodOut : FluidPort;
        port bloodReturn : FluidPort;
        port alarmPort : SignalPort;
        attribute bloodVolume : VolumeValue;
        attribute iggConcentration : ConcentrationValue;
    }

    part def BloodPump {
        port bloodIn : FluidPort;
        port bloodOut : FluidPort;
        port flowSignal : SignalPort;
        attribute flowRate : FlowRateValue;
        attribute targetFlowRate : FlowRateValue;
    }

    part def PlasmaSeparator {
        port bloodIn : FluidPort;
        port plasmaOut : FluidPort;
        port cellsOut : FluidPort;
        port pressureSignal : SignalPort;
    }

    part def ProsorbaColumn {
        port plasmaIn : FluidPort;
        port plasmaOut : FluidPort;
        part proteinA : ProteinA;
        attribute bindingCapacity : VolumeValue;
    }

    part def BloodRecombiner {
        port cellsIn : FluidPort;
        port plasmaIn : FluidPort;
        port bloodOut : FluidPort;
    }

    part def SafetyMonitor {
        port pressureIn : SignalPort;
        port flowIn : SignalPort;
        port alarmOut : SignalPort;
        attribute maxPressure : PressureValue;
        attribute minFlowRate : FlowRateValue;
        attribute maxFlowRate : FlowRateValue;
        attribute alarmActive : Boolean;
    }

    part def ProsorbaSystem {
        port bloodInlet : FluidPort;
        port bloodOutlet : FluidPort;
        attribute treatmentDuration : DurationValue;
        attribute targetPlasmaVolume : VolumeValue;
        attribute processedVolume : VolumeValue;
        attribute elapsedTime : DurationValue;
        attribute isPrimed : Boolean;
        attribute isRinsed : Boolean;
        attribute inFault : Boolean;
        part patient : Patient;
        part pump : BloodPump;
        part separator : PlasmaSeparator;
        part column : ProsorbaColumn;
        part recombiner : BloodRecombiner;
        part monitor : SafetyMonitor;
        connect patient.bloodOut to pump.bloodIn;
        connect pump.bloodOut to separator.bloodIn;
        connect separator.plasmaOut to column.plasmaIn;
        connect separator.cellsOut to recombiner.cellsIn;
        connect column.plasmaOut to recombiner.plasmaIn;
        connect recombiner.bloodOut to patient.bloodReturn;
        connect pump.flowSignal to monitor.flowIn;
        connect separator.pressureSignal to monitor.pressureIn;
        connect monitor.alarmOut to patient.alarmPort;
        state treatmentOperation {
            entry; then priming;
            state priming {
                do action prime : PrimeCircuit;
                transition first priming accept PrimeComplete then treating;
            }
            state treating {
                do action treat : TreatBlood;
                do action mon : MonitorSafety;
                transition first treating if processedVolume >= targetPlasmaVolume then rinsing;
                transition first treating accept alarm : AlarmSignal then fault;
            }
            state rinsing {
                do action rinse : RinseCircuit;
                transition first rinsing accept RinseComplete then complete;
            }
            state complete {
                do action returnBlood : ReturnBlood;
            }
            state fault {
                do action stopPump : StopPump;
                do action activateAlarm : ActivateAlarm;
            }
        }
        perform treatmentOperation;
    }

    requirement def AntibodyRemovalRequirement {
        doc /* The system shall remove pathogenic IgG antibodies from patient plasma using Protein A affinity binding. */
        subject system : ProsorbaSystem;
        constraint {
            system.processedVolume >= system.targetPlasmaVolume;
        }
    }

    requirement def SafetyMonitoringRequirement {
        doc /* The system shall monitor pressure and flow rate and trigger an alarm if safe limits are exceeded. */
        subject system : ProsorbaSystem;
        constraint {
            system.monitor.alarmActive == true;
        }
    }

    requirement def TreatmentCompletionRequirement {
        doc /* The system shall complete treatment when the target plasma volume has been processed or the treatment duration has elapsed. */
        subject system : ProsorbaSystem;
        constraint {
            system.processedVolume >= system.targetPlasmaVolume
                or system.elapsedTime >= system.treatmentDuration;
        }
    }

    part prosorbaSystem : ProsorbaSystem {
        attribute treatmentDuration = 60;
        attribute targetPlasmaVolume = 1000;
        attribute processedVolume = 0;
        attribute elapsedTime = 0;
        attribute isPrimed = false;
        attribute isRinsed = false;
        attribute inFault = false;
        part patient : Patient {
            attribute bloodVolume = 5000;
            attribute iggConcentration = 200;
        }
        part pump : BloodPump {
            attribute flowRate = 30;
            attribute targetFlowRate = 30;
        }
        part separator : PlasmaSeparator;
        part column : ProsorbaColumn {
            attribute bindingCapacity = 1500;
        }
        part recombiner : BloodRecombiner;
        part monitor : SafetyMonitor {
            attribute maxPressure = 200;
            attribute minFlowRate = 10;
            attribute maxFlowRate = 50;
            attribute alarmActive = false;
        }
        satisfy AntibodyRemovalRequirement;
        satisfy SafetyMonitoringRequirement;
        satisfy TreatmentCompletionRequirement;
    }
}
