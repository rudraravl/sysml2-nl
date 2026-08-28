package HyalobarrierAdhesionPreventionSystem {
    import ScalarValues::*;
    import ISQ::*;

    value def Volume :> Real { unit 'mL'; }
    value def Thickness :> Real { unit 'mm'; }
    value def Duration :> Real { unit 'day'; }
    value def Viscosity :> Real { unit 'Pa*s'; }
    value def Mass :> Real { unit 'mg'; }
    value def Pressure :> Real { unit 'kPa'; }
    value def Area :> Real { unit 'cm2'; }

    item def HyaluronicAcidGel;
    item def TissueSurface;
    item def AdhesionBand;

    attribute gelViscosity : Viscosity = 5000;
    attribute effectiveThickness : Thickness = 2.0;
    attribute barrierDuration : Duration = 7.0;
    attribute deliveredVolume : Volume = 5.0;
    attribute dispensePressure : Pressure = 20.0;

    part def HyalobarrierGel {
        attribute isSterile : Boolean = true;
        attribute isBiocompatible : Boolean = true;
        attribute viscosity : Viscosity = gelViscosity;
        attribute volume : Volume = deliveredVolume;
        attribute appliedThickness : Thickness;
        attribute remainingActiveTime : Duration;
        attribute residualMass : Mass;

        port out gelOut : HyaluronicAcidGel;

        state lifecycle {
            entry; then Packaged;

            state Packaged {
                entry { volume = deliveredVolume; residualMass = 1000; }
            }

            transition Packaged to Applied
                when gelOut->transmitted;

            state Applied {
                entry { appliedThickness = effectiveThickness; remainingActiveTime = barrierDuration; }
            }

            transition Applied to ActiveBarrier
                when appliedThickness >= effectiveThickness;

            state ActiveBarrier {
                entry { remainingActiveTime = barrierDuration; }
                do {
                    while (remainingActiveTime > 0) {
                        remainingActiveTime = remainingActiveTime - 1;
                    }
                }
            }

            transition ActiveBarrier to Bioresorbing
                when remainingActiveTime <= 0;

            state Bioresorbing {
                entry { residualMass = 1000; }
                do {
                    while (residualMass > 0) {
                        residualMass = residualMass - 100;
                    }
                }
            }

            transition Bioresorbing to Absorbed
                when residualMass <= 0;

            state Absorbed {
                entry { volume = 0; appliedThickness = 0; }
            }
        }
    }

    part def Applicator {
        attribute reservoirVolume : Volume = deliveredVolume;
        attribute dispensePressure : Pressure = dispensePressure;
        attribute isSterile : Boolean = true;
        attribute dispensePrecision : Real = 0.05;

        port in gelIn : HyaluronicAcidGel;
        port out gelDispensed : HyaluronicAcidGel;
        port in applyCommand;

        state applicatorState {
            entry; then Ready;

            state Ready;

            transition Ready to Primed
                when gelIn->received;

            state Primed;

            transition Primed to Applying
                when applyCommand->received;

            state Applying {
                do {
                    while (reservoirVolume > 0) {
                        send gelDispensed;
                        reservoirVolume = reservoirVolume - 0.5;
                    }
                }
            }

            transition Applying to Empty
                when reservoirVolume <= 0;

            state Empty;
        }

        action def ApplyGel {
            in target : TissueSurface;
            in requiredVolume : Volume = deliveredVolume;
            out appliedGel : HyaluronicAcidGel;
            start { allocate requiredVolume to appliedGel; }
        }
    }

    part def Surgeon {
        port out applyCommand;
        port in visualFeedback;

        action def OperateApplicator {
            in target : TissueSurface;
            out command;
            start { send command; }
        }
    }

    part def TissueSite {
        attribute surfaceArea : Area;
        attribute isHealed : Boolean = false;
        attribute healingTime : Duration;
        attribute adhesionRisk : Boolean = true;

        port in gelReceived : HyaluronicAcidGel;

        state healing {
            entry; then Healing;

            state Healing {
                entry { healingTime = 0; }
                do {
                    while (healingTime < barrierDuration) {
                        healingTime = healingTime + 1;
                    }
                }
            }

            transition Healing to Healed
                when healingTime >= barrierDuration;

            state Healed {
                entry { isHealed = true; adhesionRisk = false; }
            }
        }
    }

    part def Patient {
        part tissueSite : TissueSite;
        attribute hasAdhesion : Boolean = false;
    }

    part def System {
        part gel : HyalobarrierGel;
        part applicator : Applicator;
        part surgeon : Surgeon;
        part patient : Patient;

        connection gelToApplicator flow HyaluronicAcidGel
            from gel.gelOut to applicator.gelIn;

        connection applicatorToTissue flow HyaluronicAcidGel
            from applicator.gelDispensed to patient.tissueSite.gelReceived;

        connection surgeonCommand
            from surgeon.applyCommand to applicator.applyCommand;
    }

    requirement def PreventAdhesion {
        subject system : System;
        objective {
            doc "The system shall prevent post-surgical adhesions between healing tissue surfaces.";
        }
    }

    requirement def BeBiocompatible {
        subject gel : HyalobarrierGel;
        objective {
            doc "The gel shall be biocompatible and safe for internal use.";
        }
    }

    requirement def DeliverPreciseVolume {
        subject applicator : Applicator;
        attribute requiredVolume : Volume = deliveredVolume;
        attribute precision : Real = 0.05;
        objective {
            doc "The applicator shall deliver a precise volume of gel to the target tissue.";
        }
    }

    requirement def CreateEffectiveBarrier {
        subject gel : HyalobarrierGel;
        attribute requiredThickness : Thickness = effectiveThickness;
        objective {
            doc "The gel shall create a barrier of effective thickness on the tissue surface.";
        }
    }

    requirement def RemainEffectiveSevenDays {
        subject gel : HyalobarrierGel;
        attribute requiredDuration : Duration = barrierDuration;
        objective {
            doc "The barrier shall remain effective for approximately seven days.";
        }
    }

    requirement def BeBioresorbable {
        subject gel : HyalobarrierGel;
        objective {
            doc "The gel shall be fully absorbed by the body without requiring a second removal procedure.";
        }
    }

    requirement def BeSterile {
        subject gel : HyalobarrierGel;
        subject applicator : Applicator;
        objective {
            doc "The gel and applicator shall be sterile prior to use.";
        }
    }

    requirement systemRequirement : PreventAdhesion {
        satisfy gel.isBiocompatible by BeBiocompatible;
        satisfy applicator.dispensePrecision by DeliverPreciseVolume;
        satisfy gel.appliedThickness by CreateEffectiveBarrier;
        satisfy gel.remainingActiveTime by RemainEffectiveSevenDays;
        satisfy gel.residualMass by BeBioresorbable;
        satisfy gel.isSterile by BeSterile;
    }
}
