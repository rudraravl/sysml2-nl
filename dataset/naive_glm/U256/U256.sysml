package InadineWoundTreatmentSystem {
    import Quantities::ISQ::*;
    import MeasurementReferences::InternationalSystemOfUnits::*;
    import ScalarValues::*;

    // ============================================================
    // Value Types (with units)
    // ============================================================
    value type ExudateVolume :> Volume {
        doc "Wound exudate volume in millilitres (mL)."
    }
    value type PovidoneIodineMass :> Mass {
        doc "Povidone-iodine mass in milligrams (mg)."
    }
    value type WearTime :> Time {
        doc "Dressing wear duration in hours (h)."
    }
    value type WoundArea :> Area {
        doc "Wound or dressing contact area in square centimetres (cm^2)."
    }
    value type ConcentrationPercent :> Real {
        doc "Mass fraction in percent (0 to 100)."
    }
    value type BacterialDensity :> Real {
        doc "Colony-forming units per square centimetre (CFU/cm^2)."
    }
    value type SaturationFraction :> Real {
        doc "Fractional saturation of the dressing (0 to 1)."
    }
    value type ExudateFlowRate :> Real {
        doc "Exudate production rate in millilitres per hour (mL/h)."
    }
    value type ReleaseRate :> Real {
        doc "Povidone-iodine release rate in milligrams per hour (mg/h)."
    }

    // ============================================================
    // Items
    // ============================================================
    item def Exudate {
        attribute volume : ExudateVolume;
        attribute composition : String = "serous fluid with proteins and cellular debris";
    }
    item def PovidoneIodine {
        attribute concentration : ConcentrationPercent = 10;
        attribute availableMass : PovidoneIodineMass;
        attribute releasedMass : PovidoneIodineMass = 0 [mg];
    }
    item def ParaffinGauze {
        attribute area : WoundArea;
        attribute adherent : Boolean = false;
        attribute paraffinCoated : Boolean = true;
    }
    item def AntimicrobialDose {
        attribute mass : PovidoneIodineMass;
    }

    // ============================================================
    // Events
    // ============================================================
    occurrence def ApplyDressingEvent {
        doc "Triggered when the dressing is applied to the wound."
    }
    occurrence def RemoveDressingEvent {
        doc "Triggered when the dressing is removed from the wound."
    }
    occurrence def DressingAppliedEvent {
        doc "Confirms the dressing has been applied and monitoring may begin."
    }
    occurrence def DressingReplacedEvent {
        doc "Confirms a new dressing has been applied after a change."
    }

    // ============================================================
    // Ports
    // ============================================================
    port def WoundContactPort {
        in exudate : Exudate;
        out releasedPovidoneIodine : PovidoneIodine;
        attribute contactArea : WoundArea;
    }
    port def DressingStatusPort {
        out absorbedVolume : ExudateVolume;
        out elapsedWearTime : WearTime;
        out releasedMass : PovidoneIodineMass;
    }
    port def MonitorReportPort {
        out saturationFraction : SaturationFraction;
        out absorbedVolume : ExudateVolume;
        out elapsedWearTime : WearTime;
        out changeNeeded : Boolean;
    }
    port def ControlCommandPort {
        in applyDressing : Boolean;
        in removeDressing : Boolean;
    }

    // ============================================================
    // Part: Wound Bed
    // ============================================================
    part def WoundBed {
        attribute woundArea : WoundArea = 50 [cm^2];
        attribute initialBacterialLoad : BacterialDensity = 1000;
        attribute currentBacterialLoad : BacterialDensity = 1000;
        attribute exudateProductionRate : ExudateFlowRate = 1 [mL/h];

        port woundInterface : ~WoundContactPort {
            attribute contactArea : WoundArea = 50 [cm^2];
        }

        action def produceExudate {
            out fluid : Exudate;
        }
        action def respondToAntimicrobial {
            in agent : PovidoneIodine;
            attribute reductionFactor : Real = 0.5;
        }

        exhibit behavior {
            take produceExudate then respondToAntimicrobial;
        }
    }

    // ============================================================
    // Part: Inadine Dressing Pad
    // ============================================================
    part def InadineDressingPad {
        attribute sterile : Boolean = true;
        attribute nonAdherent : Boolean = true;
        attribute maximumCapacity : ExudateVolume = 25 [mL];
        attribute recommendedWearTime : WearTime = 24 [h];
        attribute saturationThreshold : SaturationFraction = 0.9;
        attribute initialPovidoneIodineMass : PovidoneIodineMass = 50 [mg];
        attribute absorbedVolume : ExudateVolume = 0 [mL];
        attribute releasedMass : PovidoneIodineMass = 0 [mg];
        attribute elapsedWearTime : WearTime = 0 [h];
        attribute releaseRate : ReleaseRate = 2 [mg/h];

        part substrate : ParaffinGauze {
            attribute area : WoundArea = 50 [cm^2];
            attribute adherent : Boolean = false;
        }
        part reservoir : PovidoneIodine {
            attribute concentration : ConcentrationPercent = 10;
            attribute availableMass : PovidoneIodineMass = 50 [mg];
            attribute releasedMass : PovidoneIodineMass = 0 [mg];
        }

        port woundContact : WoundContactPort {
            attribute contactArea : WoundArea = 50 [cm^2];
        }
        port statusOut : DressingStatusPort;
        port controlCommand : ControlCommandPort;

        action def absorbExudate {
            in incomingExudate : Exudate;
        }
        action def releasePovidoneIodine {
            out released : PovidoneIodine;
        }
        action def computeSaturation {
            out saturation : SaturationFraction;
        }

        exhibit state machine lifecycle : DressingLifecycle;
    }

    // ============================================================
    // Part: Saturation Monitor
    // ============================================================
    part def SaturationMonitor {
        attribute saturationThreshold : SaturationFraction = 0.9;
        attribute maxWearTime : WearTime = 24 [h];
        attribute dressingCapacity : ExudateVolume = 25 [mL];
        attribute currentSaturation : SaturationFraction = 0;
        attribute currentAbsorbedVolume : ExudateVolume = 0 [mL];
        attribute currentWearTime : WearTime = 0 [h];
        attribute changeNeeded : Boolean = false;

        port statusIn : ~DressingStatusPort;
        port monitorReport : MonitorReportPort;

        action def updateReadings {
            in absorbedVolume : ExudateVolume;
            in wearTime : WearTime;
        }
        action def evaluateChange {
            out changeRequired : Boolean;
        }

        exhibit state machine monitoring : MonitoringBehavior;
    }

    // ============================================================
    // Part: Application Controller
    // ============================================================
    part def ApplicationController {
        attribute decisionInterval : WearTime = 1 [h];
        attribute lastDecision : Boolean = false;

        port monitorIn : ~MonitorReportPort;
        port commandOut : ~ControlCommandPort;

        action def evaluateDressingChange {
            in saturation : SaturationFraction;
            in wearTime : WearTime;
            out changeDecision : Boolean;
        }
        action def issueCommand {
            in decision : Boolean;
        }

        exhibit behavior {
            take evaluateDressingChange then issueCommand;
        }
    }

    // ============================================================
    // Top-Level System Assembly
    // ============================================================
    part def InadineWoundTreatmentSystem {
        part dressing : InadineDressingPad;
        part wound : WoundBed;
        part monitor : SaturationMonitor;
        part controller : ApplicationController;

        connect wound.woundInterface to dressing.woundContact;
        connect dressing.statusOut to monitor.statusIn;
        connect monitor.monitorReport to controller.monitorIn;
        connect controller.commandOut to dressing.controlCommand;
    }

    // ============================================================
    // State Machines
    // ============================================================
    state machine def DressingLifecycle {
        state Sterile {
            entry {
                sterile = true;
                absorbedVolume = 0 [mL];
                elapsedWearTime = 0 [h];
                releasedMass = 0 [mg];
            }
        }
        state Applied {
            entry {
                sterile = false;
            }
            do {
                elapsedWearTime = elapsedWearTime + 1 [h];
                releasedMass = releasedMass + releaseRate;
            }
        }
        state Saturated;
        state Expired;
        state Removed {
            entry {
                sterile = false;
            }
        }

        transition from Sterile to Applied on ApplyDressingEvent;
        transition from Applied to Saturated when (absorbedVolume >= maximumCapacity);
        transition from Applied to Expired when (elapsedWearTime >= recommendedWearTime);
        transition from Saturated to Removed on RemoveDressingEvent;
        transition from Expired to Removed on RemoveDressingEvent;
    }

    state machine def MonitoringBehavior {
        state Idle {
            entry {
                currentSaturation = 0;
                currentWearTime = 0 [h];
                changeNeeded = false;
            }
        }
        state Monitoring {
            do {
                currentSaturation = currentAbsorbedVolume / dressingCapacity;
                currentWearTime = currentWearTime + 1 [h];
                changeNeeded = (currentSaturation >= saturationThreshold) or (currentWearTime >= maxWearTime);
            }
        }
        state ChangeIndicated {
            entry {
                changeNeeded = true;
            }
        }

        transition from Idle to Monitoring on DressingAppliedEvent;
        transition from Monitoring to ChangeIndicated when (currentSaturation >= saturationThreshold or currentWearTime >= maxWearTime);
        transition from ChangeIndicated to Idle on DressingReplacedEvent;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def AntimicrobialProtection {
        subject dressing : InadineDressingPad;
        objective {
            doc "Provide sustained broad-spectrum antimicrobial action against bacteria on the wound bed through slow, controlled release of povidone-iodine."
        }
        assume {
            doc "The dressing is impregnated with povidone-iodine at a 10 percent mass concentration."
        }
        require {
            doc "The dressing shall sustain slow, controlled release of povidone-iodine onto the wound surface while applied."
            constraint releaseRatePositive { dressing.releaseRate > 0 [mg/h] }
            constraint releaseLimit { dressing.releasedMass <= dressing.initialPovidoneIodineMass }
            constraint broadSpectrum { dressing.releasedMass > 0 [mg] }
        }
    }

    requirement def ExudateManagement {
        subject dressing : InadineDressingPad;
        objective {
            doc "Absorb wound exudate up to the dressing maximum capacity without leakage."
        }
        require {
            doc "The absorbed exudate volume shall not exceed the maximum capacity of the dressing."
            constraint capacityLimit { dressing.absorbedVolume <= dressing.maximumCapacity }
        }
    }

    requirement def NonAdherence {
        subject dressing : InadineDressingPad;
        objective {
            doc "Ensure the dressing does not adhere to the wound bed for painless removal."
        }
        require {
            doc "The paraffin gauze substrate shall be non-adherent to the wound bed."
            constraint nonAdherentFlag { dressing.nonAdherent = true }
            constraint substrateNonAdherent { dressing.substrate.adherent = false }
        }
    }

    requirement def Sterility {
        subject dressing : InadineDressingPad;
        objective {
            doc "Maintain sterility until the dressing is applied to the patient."
        }
        require {
            doc "The dressing shall be sterile while in the Sterile lifecycle state."
            constraint sterileFlag { dressing.sterile = true }
        }
    }

    requirement def WearTimeLimit {
        subject dressing : InadineDressingPad;
        objective {
            doc "Limit the recommended maximum wear time to approximately 24 hours."
        }
        require {
            doc "The recommended maximum wear time shall be 24 hours."
            constraint maxWear { dressing.recommendedWearTime = 24 [h] }
        }
    }

    requirement def DressingChangeIndication {
        subject monitor : SaturationMonitor;
        objective {
            doc "Determine the optimal time for a dressing change based on saturation or wear time."
        }
        require {
            doc "A dressing change shall be indicated when saturation reaches 0.9 or wear time reaches 24 hours."
            constraint changeLogic {
                (monitor.currentSaturation >= monitor.saturationThreshold or monitor.currentWearTime >= monitor.maxWearTime) implies monitor.changeNeeded
            }
        }
    }

    requirement def LifecycleManagement {
        subject dressing : InadineDressingPad;
        objective {
            doc "Follow the lifecycle from Sterile to Applied to Saturated or Expired to Removed."
        }
        require {
            doc "The dressing shall exhibit the DressingLifecycle state machine with states Sterile, Applied, Saturated, Expired, and Removed."
        }
    }

    requirement def InfectionControl {
        subject dressing : InadineDressingPad;
        objective {
            doc "Reduce bacterial load on the wound bed and prevent infection in infected or at-risk wounds."
        }
        require {
            doc "The antimicrobial action shall reduce the bacterial density on the wound surface."
            constraint antimicrobialAction { dressing.releasedMass > 0 [mg] }
        }
    }

    // ============================================================
    // Verification Cases
    // ============================================================
    verification def VerifyAntimicrobialRelease {
        subject dressing : InadineDressingPad;
        objective {
            doc "Confirm sustained release of povidone-iodine over the wear period."
        }
    }

    verification def VerifySaturationMonitoring {
        subject monitor : SaturationMonitor;
        objective {
            doc "Confirm the monitor triggers a change indication when saturation reaches 0.9 or wear time reaches 24 hours."
        }
    }

    verification def VerifyNonAdherence {
        subject dressing : InadineDressingPad;
        objective {
            doc "Confirm the dressing does not adhere to the wound bed after application and removal."
        }
    }

    verification def VerifySterility {
        subject dressing : InadineDressingPad;
        objective {
            doc "Confirm the dressing remains sterile prior to application."
        }
    }
}
