package EndobronchialValveSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type PressureValue :> Real { unit 'Pa'; }
    value type VolumeValue :> Real { unit 'm^3'; }
    value type FlowRateValue :> Real { unit 'm^3/s'; }
    value type LengthValue :> Real { unit 'm'; }
    value type ForceValue :> Real { unit 'N'; }
    value type DiameterValue :> Real { unit 'm'; }
    value type PercentageValue :> Real { unit '%'; }

    // ---- Enumerations ----
    enum def BreathingPhase { INHALATION; EXHALATION; }
    enum def ValveState { OPEN; CLOSED; }
    enum def PlacementStatus { UNPLACED; DEPLOYED; ANCHORED; MIGRATED; }

    // ---- Item Types ----
    item def Air {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    item def Secretions {
        attribute viscosity : Real;
    }

    item def Airflow {
        attribute flowRate : FlowRateValue;
        attribute direction : String;
    }

    // ---- Port Definitions ----
    port def BronchialAirwayPort {
        in item airIn : Air;
        out item airOut : Air;
        out item secretionsOut : Secretions;
    }

    port def DistalLungPort {
        in item trappedAir : Air;
        out item releasedAir : Air;
        out item releasedSecretions : Secretions;
    }

    port def BronchialWallInterfacePort {
        attribute contactForce : ForceValue;
        attribute frictionCoefficient : Real;
    }

    // ---- Part Definitions: Components ----
    part def ValveBody {
        attribute material : String;
        attribute biocompatible : Boolean;
        attribute length : LengthValue;
        attribute outerDiameter : DiameterValue;
        attribute innerDiameter : DiameterValue;

        port proximalEnd : BronchialAirwayPort;
        port distalEnd : DistalLungPort;
    }

    part def FlexibleMembrane {
        attribute material : String;
        attribute flexibility : Real;
        attribute sealIntegrity : Boolean;
        attribute maxOpeningPressure : PressureValue;
        attribute currentState : ValveState;
        attribute thickness : LengthValue;

        port airflowPort : BronchialAirwayPort;
    }

    part def AnchoringMechanism {
        attribute material : String;
        attribute expansionForce : ForceValue;
        attribute deployedDiameter : DiameterValue;
        attribute compressedDiameter : DiameterValue;
        attribute selfExpanding : Boolean;
        attribute stabilityFactor : Real;
        attribute placementStatus : PlacementStatus;

        port wallInterface : BronchialWallInterfacePort;
    }

    // ---- Part Definition: Endobronchial Valve ----
    part def EndobronchialValve {
        part body : ValveBody {
            attribute material = "Nitinol";
            attribute biocompatible = true;
            attribute length = 0.008 [m];
            attribute outerDiameter = 0.005 [m];
            attribute innerDiameter = 0.004 [m];
        }

        part membrane : FlexibleMembrane {
            attribute material = "Medical-grade Silicone";
            attribute flexibility = 0.85;
            attribute sealIntegrity = true;
            attribute maxOpeningPressure = 500.0 [Pa];
            attribute currentState = ValveState::CLOSED;
            attribute thickness = 0.0002 [m];
        }

        part anchor : AnchoringMechanism {
            attribute material = "Nitinol";
            attribute expansionForce = 2.5 [N];
            attribute deployedDiameter = 0.006 [m];
            attribute compressedDiameter = 0.002 [m];
            attribute selfExpanding = true;
            attribute stabilityFactor = 0.95;
            attribute placementStatus = PlacementStatus::UNPLACED;
        }

        port proximalAirway : BronchialAirwayPort;
        port distalLung : DistalLungPort;

        connection body.proximalEnd connect proximalAirway;
        connection body.distalEnd connect distalLung;
        connection membrane.airflowPort connect body.proximalEnd;

        // ---- State Machine: Valve Operation ----
        state def ValveOperation {
            entry action initializeValve {
                membrane.currentState = ValveState::CLOSED;
            }

            state Closed {
                entry action sealMembrane {
                    membrane.sealIntegrity = true;
                    membrane.currentState = ValveState::CLOSED;
                }
                // During inhalation, valve remains closed to block air entry
            }

            state Open {
                entry action openMembrane {
                    membrane.sealIntegrity = false;
                    membrane.currentState = ValveState::OPEN;
                }
                // During exhalation, valve opens to release trapped air and secretions
            }

            transition from Closed to Open
                when distalLung.trappedAir.pressure > membrane.maxOpeningPressure;

            transition from Open to Closed
                when distalLung.trappedAir.pressure <= membrane.maxOpeningPressure;
        }

        exhibit ValveOperation;
    }

    // ---- Part Definition: Patient Breathing Cycle ----
    part def PatientBreathingCycle {
        attribute currentPhase : BreathingPhase;
        attribute respiratoryRate : Real;
        attribute inhalationPressure : PressureValue;
        attribute exhalationPressure : PressureValue;

        port airwayPort : BronchialAirwayPort;
        port lungSegmentPort : DistalLungPort;

        // ---- State Machine: Breathing Cycle ----
        state def BreathingCycle {
            state Inhalation {
                entry action inhale {
                    currentPhase = BreathingPhase::INHALATION;
                    inhalationPressure = 1200.0 [Pa];
                }
            }

            state Exhalation {
                entry action exhale {
                    currentPhase = BreathingPhase::EXHALATION;
                    exhalationPressure = 600.0 [Pa];
                }
            }

            transition from Inhalation to Exhalation
                when inhalationPressure <= 0.0 [Pa];

            transition from Exhalation to Inhalation
                when exhalationPressure <= 0.0 [Pa];
        }

        exhibit BreakingCycle;
    }

    // ---- Part Definition: Diseased Lung Segment ----
    part def DiseasedLungSegment {
        attribute initialVolume : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute trappedAirPressure : PressureValue;
        attribute hyperinflationLevel : Real;
        attribute secretionAccumulation : VolumeValue;

        port valveInterface : DistalLungPort;

        action def DeflateSegment {
            in currentVolume : VolumeValue;
            out reducedVolume : VolumeValue;
        }
    }

    // ---- Part Definition: Healthy Lung Portion ----
    part def HealthyLungPortion {
        attribute functionalCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute ventilationEfficiency : Real;

        port airwayPort : BronchialAirwayPort;
    }

    // ---- Part Definition: Diaphragm ----
    part def Diaphragm {
        attribute restingPosition : LengthValue;
        attribute displacement : LengthValue;
        attribute pressureOnDiaphragm : PressureValue;
        attribute contractility : Real;
    }

    // ---- Action Definitions: Therapeutic Process ----
    action def PerformTherapy {
        in valve : EndobronchialValve;
        in breathingCycle : PatientBreathingCycle;
        in diseasedSegment : DiseasedLungSegment;
        in healthyLung : HealthyLungPortion;
        in diaphragm : Diaphragm;

        action regulateAirflow {
            // One-way valve operation synchronized with breathing cycle
            // Exhalation: membrane opens, trapped air and secretions escape
            // Inhalation: membrane closes, complete seal blocks air entry
        }

        action reduceLungVolume {
            // Progressively deflate targeted diseased lung segment
        }

        action alleviateDiaphragmPressure {
            // Reduce pressure on diaphragm by decreasing lung volume
        }

        action improveBreathingCapacity {
            // Allow healthier parts of lung to function more effectively
        }

        flow from regulateAirflow to reduceLungVolume;
        flow from reduceLungVolume to alleviateDiaphragmPressure;
        flow from alleviateDiaphragmPressure to improveBreathingCapacity;
    }

    // ---- Part Definition: Complete System ----
    part def EndobronchialValveSystem {
        part valve : EndobronchialValve;
        part patientBreathing : PatientBreathingCycle {
            attribute currentPhase = BreathingPhase::INHALATION;
            attribute respiratoryRate = 16.0;
            attribute inhalationPressure = 1200.0 [Pa];
            attribute exhalationPressure = 600.0 [Pa];
        }
        part diseasedSegment : DiseasedLungSegment {
            attribute initialVolume = 0.0008 [m^3];
            attribute currentVolume = 0.0008 [m^3];
            attribute trappedAirPressure = 300.0 [Pa];
            attribute hyperinflationLevel = 0.75;
            attribute secretionAccumulation = 0.00002 [m^3];
        }
        part healthyLung : HealthyLungPortion {
            attribute functionalCapacity = 0.0035 [m^3];
            attribute currentVolume = 0.0025 [m^3];
            attribute ventilationEfficiency = 0.60;
        }
        part diaphragm : Diaphragm {
            attribute restingPosition = 0.12 [m];
            attribute displacement = 0.015 [m];
            attribute pressureOnDiaphragm = 800.0 [Pa];
            attribute contractility = 0.55;
        }

        // ---- Connections ----
        connection patientBreathing.airwayPort connect healthyLung.airwayPort;
        connection patientBreathing.lungSegmentPort connect diseasedSegment.valveInterface;
        connection valve.distalLung connect diseasedSegment.valveInterface;
        connection valve.proximalAirway connect patientBreathing.airwayPort;

        perform PerformTherapy;
    }

    // ---- Requirements ----
    requirement def BiocompatibilityRequirement {
        doc /* The valve body, membrane, and anchoring mechanism must be constructed from biocompatible materials suitable for long-term implantation in the human airway. */
        attribute maxCytotoxicityGrade : Integer = 0;
        attribute maxSensitizationGrade : Integer = 0;
        attribute maxIrritationGrade : Integer = 0;
        constraint { valve.body.biocompatible == true }
        constraint { valve.membrane.material == "Medical-grade Silicone" }
        constraint { valve.anchor.material == "Nitinol" }
    }

    requirement def StructuralStabilityRequirement {
        doc /* The anchoring mechanism must maintain structural stability within the bronchial airway under respiratory forces and secretions flow. */
        attribute minStabilityFactor : Real = 0.90;
        attribute minExpansionForce : ForceValue = 1.5 [N];
        attribute maxMigrationRate : Real = 0.01;
        constraint { valve.anchor.stabilityFactor >= minStabilityFactor }
        constraint { valve.anchor.expansionForce >= minExpansionForce }
        constraint { valve.anchor.selfExpanding == true }
        constraint { valve.anchor.placementStatus == PlacementStatus::ANCHORED }
    }

    requirement def LungVolumeReductionRequirement {
        doc /* The system must achieve significant lung volume reduction in the targeted diseased segment to alleviate hyperinflation. */
        attribute minVolumeReductionPercent : Real = 30.0;
        attribute targetVolumeReduction : VolumeValue = 0.0003 [m^3];
        constraint {
            (diseasedSegment.initialVolume - diseasedSegment.currentVolume) >= targetVolumeReduction
        }
    }

    requirement def OneWayValveFunctionRequirement {
        doc /* The valve must allow air and secretions to escape during exhalation and block air entry during inhalation. */
        constraint {
            (patientBreathing.currentPhase == BreathingPhase::EXHALATION) implies
            (valve.membrane.currentState == ValveState::OPEN)
        }
        constraint {
            (patientBreathing.currentPhase == BreathingPhase::INHALATION) implies
            (valve.membrane.currentState == ValveState::CLOSED)
        }
    }

    requirement def SealIntegrityRequirement {
        doc /* The valve must create a complete seal during inhalation to prevent re-inflation of the targeted lung segment. */
        attribute minSealIntegrity : Boolean = true;
        constraint { valve.membrane.sealIntegrity == true }
    }

    requirement def DiaphragmReliefRequirement {
        doc /* The system must alleviate pressure on the diaphragm by reducing hyperinflation in the diseased lung segment. */
        attribute maxDiaphragmPressure : PressureValue = 500.0 [Pa];
        attribute minContractilityImprovement : Real = 0.10;
        constraint { diaphragm.pressureOnDiaphragm <= maxDiaphragmPressure }
    }

    requirement def HealthyLungImprovementRequirement {
        doc /* The system must allow healthier parts of the lung to function more effectively after volume reduction. */
        attribute minVentilationEfficiency : Real = 0.75;
        constraint { healthyLung.ventilationEfficiency >= minVentilationEfficiency }
    }

    requirement EndobronchialValveSystemRequirement {
        doc /* The Endobronchial Valve System shall treat severe emphysema by reducing air-trapping (hyperinflation) in diseased portions of the lung through one-way valve regulation. */
        subject valveSystem : EndobronchialValveSystem;

        requirement biocompatibility : BiocompatibilityRequirement;
        requirement structuralStability : StructuralStabilityRequirement;
        requirement volumeReduction : LungVolumeReductionRequirement;
        requirement oneWayFunction : OneWayValveFunctionRequirement;
        requirement sealIntegrity : SealIntegrityRequirement;
        requirement diaphragmRelief : DiaphragmReliefRequirement;
        requirement healthyLungImprovement : HealthyLungImprovementRequirement;
    }
}
