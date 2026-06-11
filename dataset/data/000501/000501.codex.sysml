package SinusImplantSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def millimeter :> length;
    attribute def cubicMillimeter :> volume;
    attribute def degreeCelsius :> temperature;
    attribute def kilopascal :> pressure;
    attribute def newton :> force;
    attribute def day :> time;
    attribute def percent;
    attribute def pH;

    item def Airflow {
        attribute volumetricFlowRate : Real;
        attribute humidity : percent;
        attribute temperature : degreeCelsius;
    }

    item def Mucus {
        attribute viscosity : Real;
        attribute volume : cubicMillimeter;
        attribute pHValue : pH;
    }

    item def TissueLoad {
        attribute compressiveForce : newton;
        attribute contactPressure : kilopascal;
    }

    item def TherapeuticAgent {
        attribute doseMass : Real;
        attribute releaseRate : Real;
        attribute activeIngredient : String;
    }

    item def InflammatorySignal {
        attribute swellingLevel : percent;
        attribute painLevel : Integer;
        attribute infectionIndicator : Boolean;
    }

    item def ImagingReference {
        attribute radiopacityIndex : Real;
        attribute implantPositionVisible : Boolean;
    }

    port def AirPassagePort {
        out item airflow : Airflow;
        in item mucus : Mucus;
    }

    port def TissueInterfacePort {
        in item tissueLoad : TissueLoad;
        out item inflammatorySignal : InflammatorySignal;
    }

    port def DrugElutionPort {
        out item agent : TherapeuticAgent;
    }

    port def ImagingPort {
        out item reference : ImagingReference;
    }

    part def SinusCavity {
        attribute ostiumDiameter : millimeter;
        attribute mucosalThickness : millimeter;
        attribute internalPressure : kilopascal;

        port nasalOpening : AirPassagePort;
        port naturalDrainagePath : AirPassagePort;
        port mucosalWall : TissueInterfacePort;
    }

    part def SinusImplant {
        attribute outerDiameter : millimeter;
        attribute length : millimeter;
        attribute wallThickness : millimeter;
        attribute openLumenDiameter : millimeter;
        attribute porosity : percent;
        attribute degradationTime : day;
        attribute isBioabsorbable : Boolean;
        attribute materialName : String;

        port proximalAirInterface : AirPassagePort;
        port distalAirInterface : AirPassagePort;
        port mucosalContact : TissueInterfacePort;
        port medicationOutlet : DrugElutionPort;
        port radiographicMarker : ImagingPort;

        part structuralFrame {
            attribute radialSupportForce : newton;
            attribute strutWidth : millimeter;
            attribute fatigueResistanceCycles : Integer;
        }

        part lumen {
            attribute hydraulicDiameter : millimeter;
            attribute minimumOpenArea : cubicMillimeter;
        }

        part retentionFeatures {
            attribute atraumaticTipRadius : millimeter;
            attribute migrationResistanceForce : newton;
        }

        part drugReservoir {
            attribute storedDoseMass : Real;
            attribute releaseDuration : day;
            attribute elutingSurfaceArea : cubicMillimeter;
        }

        state def ImplantLifecycle {
            state packaged;
            state inserted;
            state deployed;
            state supportingDrainage;
            state resorbing;
            state absorbed;
            state removed;

            transition first packaged then inserted;
            transition first inserted then deployed;
            transition first deployed then supportingDrainage;
            transition first supportingDrainage then resorbing
                if degradationTime > 0 [day];
            transition first resorbing then absorbed;
            transition first supportingDrainage then removed
                if isBioabsorbable == false;
        }

        action maintainPatency {
            in item incomingMucus : Mucus;
            in item incomingAirflow : Airflow;
            out item outgoingMucus : Mucus;
            out item outgoingAirflow : Airflow;

            objective {
                doc /* Keep the sinus drainage pathway open by mechanically supporting the ostium and preserving a continuous lumen for air exchange and mucus clearance. */
            }
        }

        action deliverLocalTherapy {
            in item storedAgent : TherapeuticAgent;
            out item elutedAgent : TherapeuticAgent;

            objective {
                doc /* Release a controlled local therapeutic agent to reduce mucosal inflammation around the implant interface. */
            }
        }

        action distributeTissueLoad {
            in item appliedLoad : TissueLoad;
            out item interfaceResponse : InflammatorySignal;

            objective {
                doc /* Spread contact forces across atraumatic implant surfaces to maintain position while limiting localized tissue irritation. */
            }
        }
    }

    part def ClinicalOperator {
        port placementInterface : TissueInterfacePort;
        port imagingReceiver : ImagingPort;
    }

    part def PatientAnatomy {
        part maxillarySinus : SinusCavity;
        part nasalCavity : SinusCavity;
        part ethmoidRegion : SinusCavity;
    }

    part def SinusImplantSystem {
        attribute primaryFunction : String = "Maintain patency of a sinus drainage pathway to support ventilation and mucus drainage after placement.";

        part patient : PatientAnatomy;
        part implant : SinusImplant;
        part operator : ClinicalOperator;

        connect implant.proximalAirInterface to patient.nasalCavity.naturalDrainagePath;
        connect implant.distalAirInterface to patient.maxillarySinus.naturalDrainagePath;
        connect implant.mucosalContact to patient.maxillarySinus.mucosalWall;
        connect implant.medicationOutlet to implant.mucosalContact;
        connect implant.radiographicMarker to operator.imagingReceiver;

        action placeImplant {
            in part targetSinus : SinusCavity;
            in part device : SinusImplant;
            out success : Boolean;

            objective {
                doc /* Position the implant across the narrowed sinus outflow region so that its lumen aligns with the intended drainage path. */
            }
        }

        action operateInPatient {
            in item sinusAirflow : Airflow;
            in item retainedMucus : Mucus;
            out item restoredAirflow : Airflow;
            out item drainedMucus : Mucus;

            first start;
            then implant.maintainPatency;
            then implant.deliverLocalTherapy;
            then done;
        }

        state def SystemUseState {
            state preProcedure;
            state implantPlaced;
            state drainageSupported;
            state healingObserved;
            state therapyComplete;

            transition first preProcedure then implantPlaced;
            transition first implantPlaced then drainageSupported;
            transition first drainageSupported then healingObserved;
            transition first healingObserved then therapyComplete;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SinusImplantSystem;

        require constraint {
            system.primaryFunction == "Maintain patency of a sinus drainage pathway to support ventilation and mucus drainage after placement."
        }

        doc /* The system shall provide mechanical support to a sinus drainage pathway so that airflow exchange and mucus clearance are maintained at a high level. */
    }

    requirement def PatencyRequirement {
        subject implant : SinusImplant;

        require constraint {
            implant.openLumenDiameter >= 2.0 [millimeter]
        }

        doc /* The implant shall include a continuous lumen sized to preserve a drainage route through the sinus outflow region. */
    }

    requirement def TissueCompatibilityRequirement {
        subject implant : SinusImplant;

        require constraint {
            implant.retentionFeatures.atraumaticTipRadius >= 0.2 [millimeter]
        }

        doc /* The implant shall use atraumatic tissue-contacting geometry to reduce localized irritation while maintaining placement. */
    }

    requirement def LocalTherapyRequirement {
        subject implant : SinusImplant;

        require constraint {
            implant.drugReservoir.releaseDuration >= 7 [day]
        }

        doc /* The implant shall support local delivery of a therapeutic agent for early post-placement inflammation management. */
    }

    requirement def ImagingVisibilityRequirement {
        subject implant : SinusImplant;

        require constraint {
            implant.radiographicMarker.reference.implantPositionVisible == true
        }

        doc /* The implant shall provide an imaging reference that allows confirmation of position during or after placement. */
    }

    requirement def BioabsorptionRequirement {
        subject implant : SinusImplant;

        require constraint {
            implant.isBioabsorbable implies implant.degradationTime >= 30 [day]
        }

        doc /* If bioabsorbable, the implant shall retain functional support during the initial healing period before resorption. */
    }

    part sinusImplantSystem : SinusImplantSystem {
        part implant redefines implant {
            attribute outerDiameter = 4.0 [millimeter];
            attribute length = 18.0 [millimeter];
            attribute wallThickness = 0.35 [millimeter];
            attribute openLumenDiameter = 2.6 [millimeter];
            attribute porosity = 18.0 [percent];
            attribute degradationTime = 90 [day];
            attribute isBioabsorbable = true;
            attribute materialName = "bioabsorbable polymer with radiopaque marker";

            part structuralFrame redefines structuralFrame {
                attribute radialSupportForce = 0.45 [newton];
                attribute strutWidth = 0.25 [millimeter];
                attribute fatigueResistanceCycles = 100000;
            }

            part lumen redefines lumen {
                attribute hydraulicDiameter = 2.6 [millimeter];
                attribute minimumOpenArea = 5.3 [cubicMillimeter];
            }

            part retentionFeatures redefines retentionFeatures {
                attribute atraumaticTipRadius = 0.3 [millimeter];
                attribute migrationResistanceForce = 0.75 [newton];
            }

            part drugReservoir redefines drugReservoir {
                attribute storedDoseMass = 370.0;
                attribute releaseDuration = 21 [day];
                attribute elutingSurfaceArea = 62.0 [cubicMillimeter];
            }
        }

        part patient redefines patient {
            part maxillarySinus redefines maxillarySinus {
                attribute ostiumDiameter = 1.2 [millimeter];
                attribute mucosalThickness = 3.0 [millimeter];
                attribute internalPressure = 0.4 [kilopascal];
            }

            part nasalCavity redefines nasalCavity {
                attribute ostiumDiameter = 5.0 [millimeter];
                attribute mucosalThickness = 1.0 [millimeter];
                attribute internalPressure = 0.0 [kilopascal];
            }

            part ethmoidRegion redefines ethmoidRegion {
                attribute ostiumDiameter = 1.5 [millimeter];
                attribute mucosalThickness = 2.5 [millimeter];
                attribute internalPressure = 0.3 [kilopascal];
            }
        }
    }

    satisfy PrimaryFunctionRequirement by sinusImplantSystem;
    satisfy PatencyRequirement by sinusImplantSystem.implant;
    satisfy TissueCompatibilityRequirement by sinusImplantSystem.implant;
    satisfy LocalTherapyRequirement by sinusImplantSystem.implant;
    satisfy ImagingVisibilityRequirement by sinusImplantSystem.implant;
    satisfy BioabsorptionRequirement by sinusImplantSystem.implant;
}