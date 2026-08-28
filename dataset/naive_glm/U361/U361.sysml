package ProsorbaImmunoadsorptionSystem {
    public import ScalarValues::*;
    public import ISQ::*;
    public import ISQBase::*;
    public import ISQSpaceAndTime::*;
    public import MeasurementReferences::*;

    // ---- Value Types with Units ----
    value def FlowRate :> Real {
        :>> unit = mL_per_min;
    }
    value def PressureValue :> Real {
        :>> unit = mmHg;
    }
    value def VolumeValue :> Real {
        :>> unit = mL;
    }
    value def DurationValue :> Real {
        :>> unit = min;
    }
    value def ConcentrationValue :> Real {
        :>> unit = ug_per_mL;
    }
    value def TemperatureValue :> Real {
        :>> unit = degC;
    }

    unit mL_per_min :> VolumeFlowRateUnit {
        :>> definition = (milli*L)/min;
    }
    unit mmHg :> PressureUnit;
    unit mL :> VolumeUnit {
        :>> definition = milli*L;
    }
    unit min :> TimeUnit;
    unit ug_per_mL :> MassDensityUnit {
        :>> definition = micro*g/mL;
    }
    unit degC :> ThermodynamicTemperatureUnit;

    // ---- Item Definitions ----
    item def WholeBlood {
        attribute hematocrit : Real [0..1];
        attribute iggConcentration : ConcentrationValue;
        attribute immuneComplexLoad : ConcentrationValue;
    }
    item def Plasma {
        attribute iggConcentration : ConcentrationValue;
        attribute immuneComplexLoad : ConcentrationValue;
        attribute proteinContent : ConcentrationValue;
    }
    item def BloodCells {
        attribute hematocrit : Real [0..1];
    }
    item def PurifiedPlasma :> Plasma {
        :>> iggConcentration : ConcentrationValue;
        :>> immuneComplexLoad : ConcentrationValue;
    }
    item def ReconstitutedBlood {
        attribute hematocrit : Real [0..1];
        attribute iggConcentration : ConcentrationValue;
        attribute immuneComplexLoad : ConcentrationValue;
    }
    item def PrimingSolution {
        attribute salineConcentration : ConcentrationValue;
    }
    item def RinsingSolution {
        attribute salineConcentration : ConcentrationValue;
    }
    item def IgGAntibody;
    item def ImmuneComplex;
    item def ProteinABead {
        attribute bindingCapacity : VolumeValue;
        attribute saturation : Real [0..1];
    }

    // ---- Port Definitions ----
    port def BloodPort {
        out item wholeBlood : WholeBlood;
        in item returnedBlood : ReconstitutedBlood;
    }
    port def PlasmaFlowPort {
        out item plasma : Plasma;
        in item purifiedPlasma : PurifiedPlasma;
    }
    port def CellFlowPort {
        out item cells : BloodCells;
    }
    port def PurifiedPlasmaOutPort {
        out item purifiedPlasma : PurifiedPlasma;
    }
    port def PlasmaInPort {
        in item plasma : Plasma;
    }
    port def ControlSignalPort {
        out attribute command : String;
        in attribute feedback : String;
    }
    port def SensorSignalPort {
        out attribute pressure : PressureValue;
        out attribute flowRate : FlowRate;
        out attribute processedVolume : VolumeValue;
        out attribute alarmStatus : Boolean;
    }

    // ---- Flow Definitions ----
    flow def BloodFlow {
        end :>> source;
        end :>> target;
        item : WholeBlood;
    }
    flow def PlasmaFlow {
        end :>> source;
        end :>> target;
        item : Plasma;
    }
    flow def CellFlow {
        end :>> source;
        end :>> target;
        item : BloodCells;
    }
    flow def PurifiedPlasmaFlow {
        end :>> source;
        end :>> target;
        item : PurifiedPlasma;
    }
    flow def ReconstitutedBloodFlow {
        end :>> source;
        end :>> target;
        item : ReconstitutedBlood;
    }

    // ---- Part Definitions ----
    part def BloodPump {
        attribute nominalFlowRate : FlowRate = 30 [mL_per_min];
        attribute currentFlowRate : FlowRate;
        port out bloodOut : WholeBlood;
        port in bloodIn : WholeBlood;
        port in controlIn : ControlSignalPort;
        port out sensorOut : SensorSignalPort;
        exhibit {
            action def Pumping {
                in blood : WholeBlood;
                out pumpedBlood : WholeBlood;
                :>> pumpedBlood = blood;
            }
        }
    }

    part def PlasmaSeparator {
        attribute membranePoreSize : Real;
        attribute separationEfficiency : Real [0..1] = 0.98;
        port in bloodIn : WholeBlood;
        port out plasmaOut : Plasma;
        port out cellsOut : BloodCells;
        exhibit {
            action def Separate {
                in blood : WholeBlood;
                out plasma : Plasma;
                out cells : BloodCells;
                private attribute totalVolume : VolumeValue = blood.volume;
                :>> plasma.iggConcentration = blood.iggConcentration;
                :>> plasma.immuneComplexLoad = blood.immuneComplexLoad;
                :>> cells.hematocrit = blood.hematocrit;
            }
        }
    }

    part def ProsorbaColumn {
        attribute proteinAContent : ProteinABead;
        attribute totalBindingCapacity : VolumeValue = 200 [mL];
        attribute processedPlasmaVolume : VolumeValue = 0 [mL];
        attribute saturationLevel : Real [0..1] = 0.0;
        port in plasmaIn : Plasma;
        port out purifiedPlasmaOut : PurifiedPlasma;
        exhibit {
            action def Adsorb {
                in plasma : Plasma;
                out purified : PurifiedPlasma;
                :>> purified.iggConcentration = plasma.iggConcentration * (1 - 0.85);
                :>> purified.immuneComplexLoad = plasma.immuneComplexLoad * (1 - 0.90);
                :>> purified.proteinContent = plasma.proteinContent;
            }
        }
    }

    part def BloodRecombiner {
        attribute mixingEfficiency : Real [0..1] = 0.99;
        port in cellsIn : BloodCells;
        port in purifiedPlasmaIn : PurifiedPlasma;
        port out reconstitutedBloodOut : ReconstitutedBlood;
        exhibit {
            action def Recombine {
                in cells : BloodCells;
                in purified : PurifiedPlasma;
                out reconstituted : ReconstitutedBlood;
                :>> reconstituted.hematocrit = cells.hematocrit;
                :>> reconstituted.iggConcentration = purified.iggConcentration;
                :>> reconstituted.immuneComplexLoad = purified.immuneComplexLoad;
            }
        }
    }

    part def SafetyMonitor {
        attribute minPressure : PressureValue = 50 [mmHg];
        attribute maxPressure : PressureValue = 350 [mmHg];
        attribute minFlowRate : FlowRate = 10 [mL_per_min];
        attribute maxFlowRate : FlowRate = 50 [mL_per_min];
        attribute alarmActive : Boolean = false;
        port in sensorIn : SensorSignalPort;
        port out controlOut : ControlSignalPort;
        exhibit {
            action def MonitorParameters {
                in pressure : PressureValue;
                in flowRate : FlowRate;
                out alarm : Boolean;
                out faultTrigger : Boolean;
                if pressure < minPressure | pressure > maxPressure then {
                    :>> alarm = true;
                    :>> faultTrigger = true;
                } else if flowRate < minFlowRate | flowRate > maxFlowRate then {
                    :>> alarm = true;
                    :>> faultTrigger = true;
                } else {
                    :>> alarm = false;
                    :>> faultTrigger = false;
                }
            }
        }
    }

    part def ControlUnit {
        attribute targetPlasmaVolume : VolumeValue = 2000 [mL];
        attribute treatmentDuration : DurationValue = 120 [min];
        attribute currentPhase : String;
        port in sensorIn : SensorSignalPort;
        port out pumpControl : ControlSignalPort;
        port out monitorControl : ControlSignalPort;
        exhibit StateMachine {
            state Off;
            state Priming;
            state Treating;
            state Rinsing;
            state Completed;
            state Fault;
            transition off_to_priming first Off then Priming
                when sensorIn.processedVolume >= 0 [mL] & pumpControl.command == "start";
            transition priming_to_treating first Priming then Treating
                when sensorIn.processedVolume >= 0 [mL] & pumpControl.command == "prime_complete";
            transition treating_to_rinsing first Treating then Rinsing
                when sensorIn.processedVolume >= targetPlasmaVolume | sensorIn.alarmStatus == false & pumpControl.command == "treatment_complete";
            transition rinsing_to_completed first Rinsing then Completed
                when pumpControl.command == "rinse_complete";
            transition any_to_fault first {Off, Priming, Treating, Rinsing} then Fault
                when sensorIn.alarmStatus == true;
            transition fault_to_off first Fault then Off
                when pumpControl.command == "reset";
        }
    }

    part def Patient {
        attribute bloodVolume : VolumeValue = 5000 [mL];
        attribute initialIggConcentration : ConcentrationValue;
        port out bloodOut : WholeBlood;
        port in bloodIn : ReconstitutedBlood;
    }

    // ---- Top-level System ----
    part def ProsorbaImmunoadsorptionSystem {
        attribute systemId : String;
        attribute maxTreatmentVolume : VolumeValue = 2000 [mL];
        attribute maxTreatmentDuration : DurationValue = 180 [min];

        part patient : Patient {
            :>> initialIggConcentration = 25 [ug_per_mL];
        }

        part bloodPump : BloodPump {
            :>> nominalFlowRate = 30 [mL_per_min];
        }

        part plasmaSeparator : PlasmaSeparator {
            :>> membranePoreSize = 0.3;
        }

        part prosorbaColumn : ProsorbaColumn {
            :>> proteinAContent = ProteinABead {
                :>> bindingCapacity = 200 [mL];
                :>> saturation = 0.0;
            };
        }

        part bloodRecombiner : BloodRecombiner;

        part safetyMonitor : SafetyMonitor;

        part controlUnit : ControlUnit {
            :>> targetPlasmaVolume = 2000 [mL];
            :>> treatmentDuration = 120 [min];
        }

        // Connections
        connection patient.bloodOut to bloodPump.bloodIn;
        connection bloodPump.bloodOut to plasmaSeparator.bloodIn;
        connection plasmaSeparator.plasmaOut to prosorbaColumn.plasmaIn;
        connection plasmaSeparator.cellsOut to bloodRecombiner.cellsIn;
        connection prosorbaColumn.purifiedPlasmaOut to bloodRecombiner.purifiedPlasmaIn;
        connection bloodRecombiner.reconstitutedBloodOut to patient.bloodIn;
        connection bloodPump.sensorOut to safetyMonitor.sensorIn;
        connection safetyMonitor.controlOut to controlUnit.sensorIn;
        connection controlUnit.pumpControl to bloodPump.controlIn;
        connection controlUnit.monitorControl to safetyMonitor.controlOut;
    }

    // ---- Requirements ----
    requirement def TreatmentEfficacyRequirement {
        doc "The system shall reduce pathogenic IgG antibodies in the patient's blood by at least 80% after processing the target plasma volume.";
        attribute minReduction : Real = 0.80;
        subject system : ProsorbaImmunoadsorptionSystem;
        objective {
            require system.prosorbaColumn.saturationLevel <= 1.0 &
                system.patient.initialIggConcentration * (1 - minReduction) >= 0 [ug_per_mL];
        }
    }

    requirement def SafetyRequirement {
        doc "The system shall monitor blood pressure and flow rate continuously and enter a fault state if readings exceed safe limits.";
        attribute safePressureMin : PressureValue = 50 [mmHg];
        attribute safePressureMax : PressureValue = 350 [mmHg];
        attribute safeFlowMin : FlowRate = 10 [mL_per_min];
        attribute safeFlowMax : FlowRate = 50 [mL_per_min];
        subject monitor : SafetyMonitor;
        objective {
            require monitor.alarmActive == true
                when monitor.sensorIn.pressure < safePressureMin
                | monitor.sensorIn.pressure > safePressureMax
                | monitor.sensorIn.flowRate < safeFlowMin
                | monitor.sensorIn.flowRate > safeFlowMax;
        }
    }

    requirement def FlowControlRequirement {
        doc "The blood pump shall maintain a controlled flow rate between 10 and 50 mL/min during the treating phase.";
        subject pump : BloodPump;
        objective {
            require pump.currentFlowRate >= 10 [mL_per_min] &
                pump.currentFlowRate <= 50 [mL_per_min];
        }
    }

    requirement def PhaseRequirement {
        doc "The system shall operate through distinct phases: priming, treating, rinsing, and completion.";
        subject controller : ControlUnit;
        objective {
            require controller.currentPhase in {"Off", "Priming", "Treating", "Rinsing", "Completed", "Fault"};
        }
    }

    requirement def VolumeTargetRequirement {
        doc "The system shall process a target plasma volume of 2000 mL or run for a set duration, whichever is reached first.";
        attribute targetVolume : VolumeValue = 2000 [mL];
        attribute maxDuration : DurationValue = 180 [min];
        subject system : ProsorbaImmunoadsorptionSystem;
        objective {
            require system.prosorbaColumn.processedPlasmaVolume >= targetVolume
                | system.controlUnit.treatmentDuration >= maxDuration;
        }
    }

    requirement def RecombinationRequirement {
        doc "The blood recombiner shall mix purified plasma with separated blood cells to reconstitute whole blood with hematocrit preserved.";
        subject recombiner : BloodRecombiner;
        objective {
            require recombiner.mixingEfficiency >= 0.95;
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfyTreatmentEfficacy : TreatmentEfficacyRequirement {
        subject :>> system = ProsorbaImmunoadsorptionSystem;
    }
    satisfaction satisfySafety : SafetyRequirement {
        subject :>> monitor = ProsorbaImmunoadsorptionSystem::safetyMonitor;
    }
    satisfaction satisfyFlowControl : FlowControlRequirement {
        subject :>> pump = ProsorbaImmunoadsorptionSystem::bloodPump;
    }
    satisfaction satisfyPhase : PhaseRequirement {
        subject :>> controller = ProsorbaImmunoadsorptionSystem::controlUnit;
    }
    satisfaction satisfyVolumeTarget : VolumeTargetRequirement {
        subject :>> system = ProsorbaImmunoadsorptionSystem;
    }
    satisfaction satisfyRecombination : RecombinationRequirement {
        subject :>> recombiner = ProsorbaImmunoadsorptionSystem::bloodRecombiner;
    }
}
