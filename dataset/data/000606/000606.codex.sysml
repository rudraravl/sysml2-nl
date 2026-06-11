package FeedingTubeSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def VolumeFlowRate :> ISQ::volumeFlowRate {
        unit = L / h;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = kPa;
    }

    attribute def Volume :> ISQ::volume {
        unit = mL;
    }

    attribute def Length :> ISQ::length {
        unit = cm;
    }

    attribute def Duration :> ISQ::time {
        unit = min;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = degC;
    }

    item def NutritionalFormula {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute viscosityLevel : Integer;
        attribute caloricDensity_kcal_per_mL : Real;
    }

    item def MedicationSuspension {
        attribute volume : Volume;
        attribute dilutionVolume : Volume;
        attribute particleRiskLevel : Integer;
    }

    item def FlushWater {
        attribute volume : Volume;
        attribute temperature : Temperature;
    }

    item def GastricContent {
        attribute residualVolume : Volume;
        attribute aspirateDetected : Boolean;
    }

    item def PatientTissue {
        attribute irritationDetected : Boolean;
        attribute insertionSiteLeakage : Boolean;
    }

    port def FormulaInletPort {
        in item formula : NutritionalFormula;
        in item medication : MedicationSuspension;
        in item flush : FlushWater;
    }

    port def PatientDeliveryPort {
        out item deliveredFormula : NutritionalFormula;
        out item deliveredMedication : MedicationSuspension;
        out item deliveredFlush : FlushWater;
        in item gastricReturn : GastricContent;
    }

    port def ExternalAccessPort {
        in item formula : NutritionalFormula;
        in item medication : MedicationSuspension;
        in item flush : FlushWater;
    }

    port def InternalLumenPort {
        in item inflowFormula : NutritionalFormula;
        in item inflowMedication : MedicationSuspension;
        in item inflowFlush : FlushWater;
        out item outflowFormula : NutritionalFormula;
        out item outflowMedication : MedicationSuspension;
        out item outflowFlush : FlushWater;
    }

    part def FeedingTubeSystem {
        attribute prescribedFlowRate : VolumeFlowRate;
        attribute maxSafePressure : Pressure;
        attribute deliveredVolume : Volume;
        attribute tubePrimed : Boolean;
        attribute placementVerified : Boolean;
        attribute occlusionDetected : Boolean;
        attribute feedingEnabled : Boolean;

        port accessPort : ExternalAccessPort;
        port patientPort : PatientDeliveryPort;

        part connectorHub : EnteralConnectorHub;
        part tubeBody : FlexibleEnteralTube;
        part distalTip : DistalDeliveryTip;
        part retentionFeature : RetentionFeature;
        part placementMonitor : PlacementMonitor;
        part flowController : FlowController;
        part safetyMonitor : SafetyMonitor;

        connect accessPort to connectorHub.externalPort;
        connect connectorHub.lumenPort to tubeBody.proximalPort;
        connect tubeBody.distalPort to distalTip.lumenPort;
        connect distalTip.patientPort to patientPort;
        connect flowController.controlledPort to connectorHub.externalPort;
        connect placementMonitor.samplePort to patientPort;
        connect safetyMonitor.monitoredPort to tubeBody.proximalPort;

        perform action deliverEnteralNutrition : DeliverEnteralNutrition;
        perform action flushTube : FlushTube;
        perform action administerMedication : AdministerMedication;
        exhibit state feedingTubeOperationalStates : FeedingTubeOperationalStateMachine;
    }

    part def EnteralConnectorHub {
        attribute capClosed : Boolean;
        attribute compatibleWithEnteralOnly : Boolean = true;
        attribute leakDetected : Boolean;

        port externalPort : ExternalAccessPort;
        port lumenPort : InternalLumenPort;

        connect externalPort.formula to lumenPort.inflowFormula;
        connect externalPort.medication to lumenPort.inflowMedication;
        connect externalPort.flush to lumenPort.inflowFlush;
    }

    part def FlexibleEnteralTube {
        attribute tubeLength : Length;
        attribute innerDiameter_mm : Real;
        attribute kinkDetected : Boolean;
        attribute materialBiocompatible : Boolean = true;
        attribute radiopaqueStripePresent : Boolean = true;
        attribute internalPressure : Pressure;

        port proximalPort : InternalLumenPort;
        port distalPort : InternalLumenPort;

        connect proximalPort.inflowFormula to distalPort.outflowFormula;
        connect proximalPort.inflowMedication to distalPort.outflowMedication;
        connect proximalPort.inflowFlush to distalPort.outflowFlush;
    }

    part def DistalDeliveryTip {
        attribute sidePortsCount : Integer;
        attribute tipRounded : Boolean = true;
        attribute outletBlocked : Boolean;

        port lumenPort : InternalLumenPort;
        port patientPort : PatientDeliveryPort;

        connect lumenPort.outflowFormula to patientPort.deliveredFormula;
        connect lumenPort.outflowMedication to patientPort.deliveredMedication;
        connect lumenPort.outflowFlush to patientPort.deliveredFlush;
    }

    part def RetentionFeature {
        attribute securementApplied : Boolean;
        attribute migrationDistance : Length;
        attribute skinIrritation : Boolean;
    }

    part def PlacementMonitor {
        attribute aspiratePH : Real;
        attribute externalTubeMarking : Length;
        attribute placementConfirmed : Boolean;

        port samplePort : PatientDeliveryPort;
    }

    part def FlowController {
        attribute targetFlowRate : VolumeFlowRate;
        attribute actualFlowRate : VolumeFlowRate;
        attribute bolusModeEnabled : Boolean;
        attribute continuousModeEnabled : Boolean;

        port controlledPort : FormulaInletPort;
    }

    part def SafetyMonitor {
        attribute measuredPressure : Pressure;
        attribute pressureAlarmActive : Boolean;
        attribute occlusionAlarmActive : Boolean;
        attribute disconnectedAlarmActive : Boolean;

        port monitoredPort : InternalLumenPort;
    }

    action def DeliverEnteralNutrition {
        in item prescribedFormula : NutritionalFormula;
        in attribute requestedRate : VolumeFlowRate;
        in attribute requestedDuration : Duration;
        out attribute volumeDelivered : Volume;

        first start;
        then verifyPlacement;
        then primeLumen;
        then regulateFlow;
        then deliverFormula;
        then stopDelivery;
        then recordDelivery;
        then done;

        action verifyPlacement {
            out attribute placementAcceptable : Boolean;
        }

        action primeLumen {
            in item primingFlush : FlushWater;
            out attribute airRemoved : Boolean;
        }

        action regulateFlow {
            in attribute targetRate : VolumeFlowRate;
            out attribute stableFlow : Boolean;
        }

        action deliverFormula {
            in item formula : NutritionalFormula;
            out attribute delivered : Volume;
        }

        action stopDelivery {
            out attribute flowStopped : Boolean;
        }

        action recordDelivery {
            in attribute recordedVolume : Volume;
        }

        control start then verifyPlacement;
        control verifyPlacement then primeLumen;
        control primeLumen then regulateFlow;
        control regulateFlow then deliverFormula;
        control deliverFormula then stopDelivery;
        control stopDelivery then recordDelivery;
        control recordDelivery then done;
    }

    action def FlushTube {
        in item water : FlushWater;
        in attribute flushVolume : Volume;
        out attribute lumenCleared : Boolean;

        first start;
        then injectFlush;
        then assessResistance;
        then completeFlush;
        then done;

        action injectFlush;
        action assessResistance {
            out attribute abnormalResistance : Boolean;
        }
        action completeFlush;

        control start then injectFlush;
        control injectFlush then assessResistance;
        control assessResistance then completeFlush;
        control completeFlush then done;
    }

    action def AdministerMedication {
        in item medicationDose : MedicationSuspension;
        in item preFlush : FlushWater;
        in item postFlush : FlushWater;
        out attribute doseDelivered : Boolean;

        first start;
        then preMedicationFlush;
        then deliverMedication;
        then postMedicationFlush;
        then done;

        action preMedicationFlush;
        action deliverMedication;
        action postMedicationFlush;

        control start then preMedicationFlush;
        control preMedicationFlush then deliverMedication;
        control deliverMedication then postMedicationFlush;
        control postMedicationFlush then done;
    }

    state def FeedingTubeOperationalStateMachine {
        entry action initializeTubeStatus;

        state Unplaced;
        state PlacedUnverified;
        state Ready;
        state Feeding;
        state Flushing;
        state MedicationAdministration;
        state Alarmed;
        state Removed;

        transition first Unplaced;
        transition Unplaced_to_PlacedUnverified
            first Unplaced
            then PlacedUnverified;

        transition PlacedUnverified_to_Ready
            first PlacedUnverified
            then Ready
            guard placementVerified == true;

        transition Ready_to_Feeding
            first Ready
            then Feeding
            guard feedingEnabled == true and occlusionDetected == false;

        transition Feeding_to_Ready
            first Feeding
            then Ready
            guard deliveredVolume >= prescribedFlowRate * 1 h or feedingEnabled == false;

        transition Ready_to_Flushing
            first Ready
            then Flushing;

        transition Flushing_to_Ready
            first Flushing
            then Ready;

        transition Ready_to_MedicationAdministration
            first Ready
            then MedicationAdministration;

        transition MedicationAdministration_to_Ready
            first MedicationAdministration
            then Ready;

        transition Feeding_to_Alarmed
            first Feeding
            then Alarmed
            guard occlusionDetected == true;

        transition Flushing_to_Alarmed
            first Flushing
            then Alarmed
            guard occlusionDetected == true;

        transition Alarmed_to_Ready
            first Alarmed
            then Ready
            guard occlusionDetected == false and placementVerified == true;

        transition Ready_to_Removed
            first Ready
            then Removed;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The feeding tube system shall provide a controlled enteral pathway for delivering nutritional formula, water, and compatible medication into the patient's gastrointestinal tract while bypassing oral intake. */
        subject feedingTube : FeedingTubeSystem;

        require constraint {
            feedingTube.placementVerified == true implies feedingTube.feedingEnabled == true or feedingTube.feedingEnabled == false
        }
    }

    requirement def ControlledDeliveryRequirement {
        doc /* The system shall deliver prescribed enteral formula through the tube lumen at a controlled flow rate without exceeding the maximum safe internal pressure. */
        subject feedingTube : FeedingTubeSystem;

        require constraint {
            feedingTube.flowController.actualFlowRate <= feedingTube.flowController.targetFlowRate * 1.10 and
            feedingTube.safetyMonitor.measuredPressure <= feedingTube.maxSafePressure
        }
    }

    requirement def PlacementVerificationRequirement {
        doc /* The system shall support verification of tube placement before nutrition or medication delivery is enabled. */
        subject feedingTube : FeedingTubeSystem;

        require constraint {
            feedingTube.feedingEnabled == true implies feedingTube.placementVerified == true
        }
    }

    requirement def OcclusionDetectionRequirement {
        doc /* The system shall detect abnormal resistance or pressure indicating possible occlusion and shall transition to an alarmed state before continued delivery. */
        subject feedingTube : FeedingTubeSystem;

        require constraint {
            feedingTube.safetyMonitor.measuredPressure > feedingTube.maxSafePressure implies
            feedingTube.occlusionDetected == true
        }
    }

    requirement def EnteralCompatibilityRequirement {
        doc /* The proximal connector shall be enteral-compatible to reduce misconnections with non-enteral delivery systems. */
        subject hub : EnteralConnectorHub;

        require constraint {
            hub.compatibleWithEnteralOnly == true
        }
    }

    requirement def BiocompatibilityRequirement {
        doc /* Patient-contacting tube components shall be made from biocompatible material and shaped to minimize tissue irritation during placement and use. */
        subject tube : FlexibleEnteralTube;

        require constraint {
            tube.materialBiocompatible == true
        }
    }

    part feedingTubeSystem : FeedingTubeSystem {
        attribute prescribedFlowRate = 75 [L / h];
        attribute maxSafePressure = 40 [kPa];
        attribute deliveredVolume = 0 [mL];
        attribute tubePrimed = false;
        attribute placementVerified = false;
        attribute occlusionDetected = false;
        attribute feedingEnabled = false;

        part connectorHub {
            attribute capClosed = true;
            attribute leakDetected = false;
        }

        part tubeBody {
            attribute tubeLength = 110 [cm];
            attribute innerDiameter_mm = 3.5;
            attribute kinkDetected = false;
            attribute internalPressure = 0 [kPa];
        }

        part distalTip {
            attribute sidePortsCount = 2;
            attribute outletBlocked = false;
        }

        part retentionFeature {
            attribute securementApplied = true;
            attribute migrationDistance = 0 [cm];
            attribute skinIrritation = false;
        }

        part placementMonitor {
            attribute aspiratePH = 4.5;
            attribute externalTubeMarking = 55 [cm];
            attribute placementConfirmed = true;
        }

        part flowController {
            attribute targetFlowRate = 75 [L / h];
            attribute actualFlowRate = 0 [L / h];
            attribute bolusModeEnabled = false;
            attribute continuousModeEnabled = true;
        }

        part safetyMonitor {
            attribute measuredPressure = 0 [kPa];
            attribute pressureAlarmActive = false;
            attribute occlusionAlarmActive = false;
            attribute disconnectedAlarmActive = false;
        }
    }

    satisfy PrimaryFunctionRequirement by feedingTubeSystem;
    satisfy ControlledDeliveryRequirement by feedingTubeSystem;
    satisfy PlacementVerificationRequirement by feedingTubeSystem;
    satisfy OcclusionDetectionRequirement by feedingTubeSystem;
    satisfy EnteralCompatibilityRequirement by feedingTubeSystem.connectorHub;
    satisfy BiocompatibilityRequirement by feedingTubeSystem.tubeBody;
}