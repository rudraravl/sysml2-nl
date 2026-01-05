package OmmayaReservoirSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def FluidVolume :> VolumeValue;
    attribute def FluidPressure :> PressureValue;
    attribute def FlowRate :> VolumeValue;
    attribute def DrugConcentration :> Real;

    enum def AccessState {
        sealed;
        accessed;
        delivering;
        sampling;
    }

    enum def CatheterCondition {
        patent;
        partialOcclusion;
        occluded;
    }

    item def CerebrospinalFluid {
        attribute volume : FluidVolume;
        attribute pressure : FluidPressure;
        attribute cellCount : Real;
    }

    item def TherapeuticAgent {
        attribute drugName : String;
        attribute concentration : DrugConcentration;
        attribute volume : FluidVolume;
        attribute dosage : MassValue;
    }

    port def FluidPort {
        in item fluidIn : CerebrospinalFluid[0..1];
        out item fluidOut : CerebrospinalFluid[0..1];
        in item medicationIn : TherapeuticAgent[0..1];
        out item medicationOut : TherapeuticAgent[0..1];
    }

    part def ReservoirDome {
        attribute capacity : FluidVolume;
        attribute currentVolume : FluidVolume;
        attribute wallThickness : LengthValue;
        attribute material : String = "medical-grade silicone";
        attribute compressible : Boolean = true;

        port internalPort : FluidPort;
        port catheterConnection : FluidPort;

        assert constraint volumeLimit {
            currentVolume <= capacity
        }
    }

    part def SelfSealingSeptum {
        attribute penetrationCount : Integer;
        attribute maxPenetrations : Integer = 200;
        attribute sealIntegrity : Real;
        attribute needleGauge : Real;

        port accessPort {
            in item drugDelivery : TherapeuticAgent[0..1];
            out item csfSample : CerebrospinalFluid[0..1];
        }

        assert constraint durabilityLimit {
            penetrationCount <= maxPenetrations
        }

        assert constraint integrityCheck {
            sealIntegrity >= 0.85
        }
    }

    part def VentricularCatheter {
        attribute length : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute material : String = "silicone";
        attribute condition : CatheterCondition;
        attribute flowResistance : Real;

        port proximalEnd : FluidPort;
        port distalEnd : FluidPort;

        assert constraint patencyRequirement {
            condition == CatheterCondition::patent
        }
    }

    part def LateralVentricle {
        attribute csfVolume : FluidVolume;
        attribute intracranialPressure : FluidPressure;
        attribute productionRate : FlowRate;

        port catheterInterface : FluidPort;
    }

    action def InjectMedication {
        in targetDose : TherapeuticAgent;
        in injectionVolume : FluidVolume;
        in injectionRate : FlowRate;
        out deliveredVolume : FluidVolume;
        out residualVolume : FluidVolume;

        first start;
        then action prepareAccess {
            doc /* Sterilize access site and prepare needle */
        }
        then action punctureSeptum {
            doc /* Insert non-coring needle through septum */
        }
        then action verifyPlacement {
            doc /* Confirm needle placement in reservoir */
        }
        then action deliverDrug {
            doc /* Inject medication at controlled rate */
        }
        then action withdrawNeedle {
            doc /* Remove needle allowing septum to self-seal */
        }
        then done;
    }

    action def WithdrawCSFSample {
        in sampleVolume : FluidVolume;
        out sample : CerebrospinalFluid;
        out actualVolume : FluidVolume;

        first start;
        then action prepareAccess;
        then action punctureSeptum;
        then action aspirateFluid {
            doc /* Withdraw CSF sample slowly to avoid trauma */
        }
        then action collectSample {
            doc /* Transfer CSF to sterile collection tube */
        }
        then action withdrawNeedle;
        then done;
    }

    action def MonitorSystem {
        out reservoirState : AccessState;
        out catheterStatus : CatheterCondition;
        out fluidVolume : FluidVolume;
        out pressure : FluidPressure;
    }

    action def DeliverIntrathecalTherapy {
        in medication : TherapeuticAgent;
        in treatmentVolume : FluidVolume;

        first start;
        then merge monitoringLoop;

        then action monitor : MonitorSystem {
            out state : AccessState;
            out status : CatheterCondition;
            out volume : FluidVolume;
            out icp : FluidPressure;
        }

        then decide;
            if monitor.status == CatheterCondition::patent then inject;
            else alertOcclusion;

        action inject : InjectMedication {
            in targetDose = medication;
            in injectionVolume = treatmentVolume;
        }
        then action distribute {
            doc /* Medication flows through catheter into ventricle */
        }
        then action equilibrate {
            doc /* Drug distributes through CSF circulation */
        }
        then monitoringLoop;

        action alertOcclusion {
            doc /* Alert clinician of catheter obstruction */
        }
        then done;
    }

    state def ReservoirOperationalStates {
        entry; then idle;

        state idle {
            entry assign currentState = AccessState::sealed;
        }

        transition idle_to_accessed
            first idle
            accept AccessInitiated
            then accessed;

        state accessed {
            entry assign currentState = AccessState::accessed;
        }

        transition accessed_to_delivering
            first accessed
            then delivering;

        transition accessed_to_sampling
            first accessed
            then sampling;

        state delivering {
            entry assign currentState = AccessState::delivering;
        }

        state sampling {
            entry assign currentState = AccessState::sampling;
        }

        transition delivering_to_idle
            first delivering
            accept DeliveryComplete
            then idle;

        transition sampling_to_idle
            first sampling
            accept SamplingComplete
            then idle;

        transition accessed_to_idle
            first accessed
            accept AccessTerminated
            then idle;
    }

    part def OmmayaReservoir {
        attribute systemCapacity : FluidVolume = 10.0[mL];
        attribute implantDate : String;
        attribute patientID : String;

        part dome : ReservoirDome {
            attribute :>> capacity = 10.0[mL];
            attribute :>> currentVolume : FluidVolume;
            attribute :>> wallThickness = 2.0[mm];
        }

        part septum : SelfSealingSeptum {
            attribute :>> penetrationCount = 0;
            attribute :>> sealIntegrity = 1.0;
            attribute :>> needleGauge = 25.0;
        }

        part catheter : VentricularCatheter {
            attribute :>> length = 50.0[mm];
            attribute :>> innerDiameter = 1.5[mm];
            attribute :>> outerDiameter = 2.5[mm];
            attribute :>> condition = CatheterCondition::patent;
            attribute :>> flowResistance = 0.1;
        }

        connection septumToDome
            connect septum.accessPort to dome.internalPort;

        connection domeToCatheter
            connect dome.catheterConnection to catheter.proximalEnd;

        perform action therapy : DeliverIntrathecalTherapy[*];

        exhibit state operationalStates : ReservoirOperationalStates;
    }

    part def NeurosurgicalSystem {
        part ventricle : LateralVentricle {
            attribute :>> csfVolume = 150.0[mL];
            attribute :>> intracranialPressure = 10.0[kPa];
            attribute :>> productionRate = 0.35[mL];
        }

        part reservoir : OmmayaReservoir;

        connection catheterToVentricle
            connect reservoir.catheter.distalEnd to ventricle.catheterInterface;
    }

    requirement <'REQ-001'> primaryFunction {
        doc /* The Ommaya reservoir system shall provide safe, repeatable 
             * access to the ventricular cerebrospinal fluid space for 
             * intrathecal delivery of chemotherapeutic agents and 
             * withdrawal of CSF samples for diagnostic analysis.
            */
        subject system : OmmayaReservoir;
    }

    requirement <'REQ-002'> reservoirCapacity {
        doc /* The reservoir dome shall maintain a minimum capacity of 
             * 10 mL to accommodate therapeutic volumes without overflow.
            */
        subject dome :>> OmmayaReservoir::dome;
        assert constraint {
            dome.capacity >= 10.0[mL]
        }
    }

    requirement <'REQ-003'> catheterPatency {
        doc /* The ventricular catheter shall maintain patent flow to 
             * ensure reliable bidirectional fluid transfer between 
             * reservoir and ventricle.
            */
        subject catheter :>> OmmayaReservoir::catheter;
        assert constraint {
            catheter.condition == CatheterCondition::patent
        }
    }

    requirement <'REQ-004'> septumDurability {
        doc /* The self-sealing septum shall withstand a minimum of 200 
             * needle penetrations while maintaining seal integrity 
             * above 85% to prevent CSF leakage.
            */
        subject septum :>> OmmayaReservoir::septum;
        assert constraint {
            septum.penetrationCount <= septum.maxPenetrations and
            septum.sealIntegrity >= 0.85
        }
    }

    requirement <'REQ-005'> biocompatibility {
        doc /* All implanted components shall be constructed from 
             * biocompatible materials suitable for long-term 
             * intracranial placement.
            */
        subject system : OmmayaReservoir;
    }

    requirement <'REQ-006'> pressureSafety {
        doc /* The system shall monitor intracranial pressure to 
             * prevent herniation risk during injection procedures.
            */
        subject system : NeurosurgicalSystem;
    }

    requirement <'REQ-007'> injectionRateLimit {
        doc /* Medication delivery rate shall be controlled to 
             * prevent rapid pressure elevation.
            */
    }

    part ommayaSystem : NeurosurgicalSystem {
        satisfy primaryFunction by reservoir;
        satisfy reservoirCapacity by reservoir.dome;
        satisfy catheterPatency by reservoir.catheter;
        satisfy septumDurability by reservoir.septum;
        satisfy biocompatibility by reservoir;
        satisfy pressureSafety by ommayaSystem;
    }

    perform InjectMedication {
        in targetDose = TherapeuticAgent {
            drugName = "Methotrexate";
            concentration = 1.0;
            volume = 5.0[mL];
            dosage = 12.0[mg];
        }
        in injectionVolume = 5.0[mL];
        in injectionRate = 0.3[mL];
    }

    perform WithdrawCSFSample {
        in sampleVolume = 3.0[mL];
    }
}
