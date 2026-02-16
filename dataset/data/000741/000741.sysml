package 'Prosorba Immunoadsorption System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def AntibodyConcentration :> Real {
        doc /* Concentration of IgG antibodies in plasma measured in mg/dL */
    }

    attribute def AdsorptionEfficiency :> Real {
        doc /* Percentage of target antibodies removed per treatment cycle */
    }

    attribute def PlasmaVolume :> ISQ::VolumeValue {
        doc /* Volume of plasma processed during treatment */
    }

    attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue {
        doc /* Rate of blood flow through the extracorporeal circuit */
    }

    attribute def TreatmentTime :> ISQ::TimeValue {
        doc /* Duration of a single treatment session */
    }

    item def WholeBlood {
        attribute hematocrit : Real;
        attribute antibodyLevel : AntibodyConcentration;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }

    item def Plasma :> WholeBlood {
        attribute proteinContent : Real;
    }

    item def TreatedPlasma :> Plasma {
        attribute reducedAntibodyLevel : AntibodyConcentration;
    }

    item def BloodCells {
        attribute cellCount : Real;
    }

    port def BloodInPort {
        in item incomingBlood : WholeBlood;
    }

    port def BloodOutPort {
        out item outgoingBlood : WholeBlood;
    }

    port def PlasmaPort {
        in item plasma : Plasma;
        out item treatedPlasma : TreatedPlasma;
    }

    port def CellPort {
        in item cells : BloodCells;
    }

    enum def SystemState {
        offline;
        priming;
        separating;
        adsorbing;
        recombining;
        rinsing;
        complete;
        fault;
    }

    attribute def PrimeCommand;
    attribute def StartTreatment;
    attribute def StopTreatment;
    attribute def PrimeComplete;
    attribute def SeparationComplete;
    attribute def AdsorptionComplete;
    attribute def RecombinationComplete;
    attribute def VolumeTargetReached;
    attribute def FaultDetected;

    part def ProsorbaColumn {
        doc /* 
            Immunoadsorption column containing Protein A covalently bound to silica matrix.
            Selectively binds IgG antibodies and immune complexes from plasma.
        */
        attribute bindingCapacity : ISQ::MassValue {
            doc /* Maximum mass of IgG that can be bound */
        }
        attribute currentLoad : ISQ::MassValue {
            doc /* Current mass of bound antibodies */
        }
        attribute efficiency : AdsorptionEfficiency;

        port plasmaInterface : PlasmaPort;

        action adsorbAntibodies {
            in item untreatedPlasma : Plasma;
            in columnEfficiency : AdsorptionEfficiency;
            out item processedPlasma : TreatedPlasma;
            out antibodiesRemoved : ISQ::MassValue;
        }
    }

    part def PlasmaSeparator {
        doc /* Membrane-based separator that divides whole blood into plasma and cellular components */
        attribute separationRate : ISQ::VolumeFlowRateValue;
        attribute membraneArea : ISQ::AreaValue;

        port bloodInput : BloodInPort;
        port plasmaOutput {
            out item separatedPlasma : Plasma;
        }
        port cellOutput {
            out item separatedCells : BloodCells;
        }

        action separateBlood {
            in item wholeBlood : WholeBlood;
            out item plasma : Plasma;
            out item cells : BloodCells;
        }
    }

    part def BloodRecombiner {
        doc /* Recombines treated plasma with blood cells to reconstitute whole blood */
        port treatedPlasmaInput {
            in item plasma : TreatedPlasma;
        }
        port cellInput : CellPort;
        port bloodOutput : BloodOutPort;

        action recombineComponents {
            in item treatedPlasma : TreatedPlasma;
            in item cells : BloodCells;
            out item reconstitutedBlood : WholeBlood;
        }
    }

    part def BloodPump {
        doc /* Peristaltic pump providing controlled blood flow through circuit */
        attribute operatingFlowRate : BloodFlowRate;
        attribute maxFlowRate : BloodFlowRate;

        port controlInterface {
            in attribute commandedFlow : BloodFlowRate;
            out attribute actualFlow : BloodFlowRate;
        }
    }

    part def SafetyMonitor {
        doc /* Monitors critical parameters and triggers alarms for unsafe conditions */
        attribute pressureLimit : ISQ::PressureValue;
        attribute flowRateMin : BloodFlowRate;
        attribute airDetected : Boolean;

        port sensorInputs {
            in attribute pressure : ISQ::PressureValue;
            in attribute flow : BloodFlowRate;
        }
        port alarmOutput {
            out attribute alarmActive : Boolean;
            out attribute faultCondition : Boolean;
        }

        action monitorSafety {
            in currentPressure : ISQ::PressureValue;
            in currentFlow : BloodFlowRate;
            out safetyStatus : Boolean;
            out faultFlag : Boolean;
        }
    }

    action def PrimeCircuit {
        doc /* Prime the extracorporeal circuit with saline to remove air */
        in primeVolume : PlasmaVolume;
        in primeFlowRate : BloodFlowRate;
        out primingComplete : Boolean;
    }

    action def SeparatePlasmaFromBlood {
        doc /* Separate plasma from cellular blood components */
        in item patientBlood : WholeBlood;
        in separationRate : ISQ::VolumeFlowRateValue;
        out item isolatedPlasma : Plasma;
        out item isolatedCells : BloodCells;
    }

    action def RemoveAntibodies {
        doc /* Remove pathogenic IgG antibodies via Protein A affinity binding */
        in item rawPlasma : Plasma;
        in columnCapacity : AdsorptionEfficiency;
        out item cleanedPlasma : TreatedPlasma;
        out antibodyMassRemoved : ISQ::MassValue;
    }

    action def ReconstituteBlood {
        doc /* Recombine treated plasma with blood cells */
        in item processedPlasma : TreatedPlasma;
        in item bloodCells : BloodCells;
        out item returnBlood : WholeBlood;
    }

    action def PerformImmunoadsorption {
        doc /* Execute complete immunoadsorption treatment cycle */
        in targetVolume : PlasmaVolume;
        in treatmentFlowRate : BloodFlowRate;
        in sessionDuration : TreatmentTime;
        out item finalTreatedBlood : WholeBlood;
        out totalAntibodiesRemoved : ISQ::MassValue;
        out treatmentStatus : SystemState;

        private attribute processedVolume : PlasmaVolume := 0.0[SI::mL];

        first start;

        then action prime : PrimeCircuit {
            in primeVolume = 500.0[SI::mL];
            in primeFlowRate = 50.0[SI::mL/SI::min];
            out primingComplete;
        }

        then merge treatmentCycle;

        then action separate : SeparatePlasmaFromBlood {
            in patientBlood;
            in separationRate = treatmentFlowRate;
            out isolatedPlasma;
            out isolatedCells;
        }

        then action remove : RemoveAntibodies {
            in rawPlasma = separate.isolatedPlasma;
            in columnCapacity = 0.85;
            out cleanedPlasma;
            out antibodyMassRemoved;
        }

        then action reconstitute : ReconstituteBlood {
            in processedPlasma = remove.cleanedPlasma;
            in bloodCells = separate.isolatedCells;
            out returnBlood;
        }

        then assign processedVolume := processedVolume + 100.0[SI::mL];

        then decide;
            if processedVolume < targetVolume then treatmentCycle;
            if processedVolume >= targetVolume then finalize;

        action finalize {
            then assign treatmentStatus := SystemState::complete;
        }

        then done;
    }

    part def ProsorbaTherapeuticSystem {
        doc /* 
            Extracorporeal immunoadsorption system for removing pathogenic IgG antibodies
            from patient blood using Protein A affinity chromatography. Treats autoimmune
            disorders by reducing circulating immune complexes and autoantibodies.
        */

        attribute systemFlowRate : BloodFlowRate;
        attribute targetPlasmaVolume : PlasmaVolume;
        attribute sessionTime : TreatmentTime;
        attribute totalProcessedVolume : PlasmaVolume;

        port patientVenousAccess : BloodInPort;
        port patientArterialReturn : BloodOutPort;

        part column : ProsorbaColumn {
            :>> bindingCapacity = 2.5[SI::g];
            :>> efficiency = 0.85;
        }

        part separator : PlasmaSeparator {
            :>> separationRate = 100.0[SI::mL/SI::min];
            :>> membraneArea = 0.5[SI::'m^2'];
        }

        part recombiner : BloodRecombiner;

        part pump : BloodPump {
            :>> maxFlowRate = 150.0[SI::mL/SI::min];
        }

        part monitor : SafetyMonitor {
            :>> pressureLimit = 300.0[SI::kPa];
            :>> flowRateMin = 30.0[SI::mL/SI::min];
        }

        connection venousToSeparator connect patientVenousAccess to separator.bloodInput;
        connection separatorToColumn connect separator.plasmaOutput to column.plasmaInterface;
        connection columnToRecombiner connect column.plasmaInterface to recombiner.treatedPlasmaInput;
        connection separatorCellsToRecombiner connect separator.cellOutput to recombiner.cellInput;
        connection recombinerToPatient connect recombiner.bloodOutput to patientArterialReturn;
        connection pumpControl connect pump.controlInterface to monitor.sensorInputs;

        perform action treatment : PerformImmunoadsorption {
            in targetVolume = targetPlasmaVolume;
            in treatmentFlowRate = systemFlowRate;
            in sessionDuration = sessionTime;
            out finalTreatedBlood;
            out totalAntibodiesRemoved;
            out treatmentStatus;
        }

        state machine operationalControl {
            initial state Offline;

            state Priming {
                entry action { perform treatment; }
            }

            state Treating {
                entry action { assign systemFlowRate := 100.0[SI::mL/SI::min]; }
            }

            state Rinsing;

            state Complete;

            state Fault;

            transition first from Offline to Priming
                accept primeCmd : PrimeCommand;
            transition from Priming to Treating
                accept startCmd : StartTreatment;
            transition from Treating to Rinsing
                accept volumeReached : VolumeTargetReached;
            transition from Rinsing to Complete
                accept rinseComplete : RecombinationComplete;
            transition from Complete to Offline
                accept stopCmd : StopTreatment;
            transition from Treating to Fault
                accept fault : FaultDetected;
            transition from Fault to Offline
                accept stopCmd2 : StopTreatment;
        }
    }

    part prosorbaSystem : ProsorbaTherapeuticSystem {
        :>> systemFlowRate = 100.0[SI::mL/SI::min];
        :>> targetPlasmaVolume = 2000.0[SI::mL];
        :>> sessionTime = 120.0[SI::min];
    }

    requirement def TherapeuticRequirement {
        doc /* Requirements for therapeutic efficacy */
        subject system : ProsorbaTherapeuticSystem;
    }

    requirement def SafetyRequirement {
        doc /* Requirements for patient safety during treatment */
        subject system : ProsorbaTherapeuticSystem;
    }

    requirement <'REQ-001'> antibodyReductionEfficacy : TherapeuticRequirement {
        doc /* 
            The system shall reduce pathogenic IgG antibody concentration by at least 70%
            in the total processed plasma volume per treatment session.
        */
        require constraint {
            prosorbaSystem.column.efficiency >= 0.70
        }
    }

    requirement <'REQ-002'> pressureSafety : SafetyRequirement {
        doc /* 
            The system shall maintain extracorporeal circuit pressure below 300 kPa
            to prevent hemolysis and ensure patient safety.
        */
        require constraint {
            prosorbaSystem.monitor.pressureLimit <= 300.0[SI::kPa]
        }
    }

    requirement <'REQ-003'> flowRateStability : SafetyRequirement {
        doc /* 
            The system shall maintain blood flow rate within ±10% of target value
            throughout the treatment session.
        */
        require constraint {
            abs(prosorbaSystem.pump.actualFlow - prosorbaSystem.systemFlowRate) 
                <= 0.10 * prosorbaSystem.systemFlowRate
        }
    }

    requirement <'REQ-004'> treatmentVolume : TherapeuticRequirement {
        doc /* 
            The system shall process a minimum of 2000 mL of plasma per treatment
            session to achieve therapeutic benefit.
        */
        require constraint {
            prosorbaSystem.targetPlasmaVolume >= 2000.0[SI::mL]
        }
    }

    requirement systemMission {
        doc /* 
            The Prosorba Therapeutic System shall safely remove pathogenic IgG antibodies
            and immune complexes from patient blood through extracorporeal immunoadsorption,
            providing therapeutic benefit for autoimmune disorders while maintaining patient
            safety through continuous monitoring and controlled blood processing.
        */
        require antibodyReductionEfficacy;
        require pressureSafety;
        require flowRateStability;
        require treatmentVolume;
    }
}
