package InhalerSpacerSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def Pressure :> Real { unit 'Pa'; }
    value def Volume :> Real { unit 'm3'; }
    value def Mass :> Real { unit 'kg'; }
    value def MassConcentration :> Real { unit 'kg/m3'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def Velocity :> Real { unit 'm/s'; }
    value def Duration :> Real { unit 's'; }
    value def Length :> Real { unit 'm'; }
    value def Temperature :> Real { unit 'K'; }

    // ---- Item Definitions ----
    item def Air {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def Aerosol {
        attribute drugMass : Mass;
        attribute propellantMass : Mass;
        attribute particleVelocity : Velocity;
        attribute concentration : MassConcentration;
        attribute temperature : Temperature;
    }

    item def ExhaledAir :> Air {
        attribute residualDrugMass : Mass;
    }

    // ---- Port Definitions ----
    port def AerosolFlowPort {
        out item aerosol : Aerosol;
        in item returnAerosol : Aerosol;
    }

    port def AirFlowPort {
        out item air : Air;
        in item exhaled : ExhaledAir;
    }

    port def PatientAirwayPort {
        in item inhaledAerosol : Aerosol;
        out item exhaledAir : ExhaledAir;
    }

    // ---- MDI ----
    part def MeteredDoseInhaler {
        attribute canisterVolume : Volume = 0.000015 [m3];
        attribute nominalDoseMass : Mass = 0.0001 [kg];
        attribute sprayVelocity : Velocity = 60.0 [m/s];
        attribute dosesRemaining : Integer = 200;
        attribute isActuated : Boolean = false;

        port sprayPort : AerosolFlowPort;

        action def Actuate {
            out releasedAerosol : Aerosol;
        }

        exhibit state def MDIStateBehavior {
            entry; then Ready;
            state Ready;
            state Actuated;
            state Empty;
            transition Ready to Actuated when actuationTrigger;
            transition Actuated to Ready after 0.5 [s]
                if dosesRemaining > 0;
            transition Actuated to Empty after 0.5 [s]
                if dosesRemaining == 0;
        }
    }

    // ---- Spacer Chamber ----
    part def SpacerChamber {
        attribute chamberVolume : Volume = 0.00015 [m3];
        attribute currentAerosolMass : Mass;
        attribute suspensionDuration : Duration = 10.0 [s];
        attribute particleSettlingVelocity : Velocity = 0.01 [m/s];

        port inletPort : AerosolFlowPort;
        port outletPort : AerosolFlowPort;

        action def ReceiveAerosol {
            in incoming : Aerosol;
        }

        action def SlowAerosol {
            in aerosol : Aerosol;
            out slowed : Aerosol;
        }

        action def EvaporatePropellant {
            in aerosol : Aerosol;
            out refined : Aerosol;
        }

        action def HoldSuspension {
            in aerosol : Aerosol;
            out suspended : Aerosol;
        }

        exhibit state def ChamberStateBehavior {
            entry; then Empty;
            state Empty;
            state Filled;
            state Depleting;
            transition Empty to Filled when aerosolReceived;
            transition Filled to Depleting when patientInhaling;
            transition Depleting to Empty when currentAerosolMass == 0.0 [kg];
        }
    }

    // ---- One-Way Inspiratory Valve ----
    part def InspiratoryValve {
        attribute openThreshold : Pressure = 20.0 [Pa];
        attribute isOpen : Boolean = false;
        attribute pressureDifferential : Pressure;

        port chamberSide : AerosolFlowPort;
        port mouthpieceSide : AerosolFlowPort;

        action def OpenValve {
            out aerosolPassing : Aerosol;
        }

        action def CloseValve;

        exhibit state def InspiratoryValveBehavior {
            entry; then Closed;
            state Closed;
            state Open;
            transition Closed to Open when pressureDifferential > openThreshold;
            transition Open to Closed when pressureDifferential <= openThreshold;
        }
    }

    // ---- One-Way Expiratory Valve ----
    part def ExpiratoryValve {
        attribute openThreshold : Pressure = 15.0 [Pa];
        attribute isOpen : Boolean = false;
        attribute exhalationPressure : Pressure;

        port mouthpieceSide : AirFlowPort;
        port exhaustPort : AirFlowPort;

        action def OpenValve {
            out exhaledPassing : ExhaledAir;
        }

        action def CloseValve;

        exhibit state def ExpiratoryValveBehavior {
            entry; then Closed;
            state Closed;
            state Open;
            transition Closed to Open when exhalationPressure > openThreshold;
            transition Open to Closed when exhalationPressure <= openThreshold;
        }
    }

    // ---- Mouthpiece ----
    part def Mouthpiece {
        attribute sealDiameter : Length = 0.022 [m];
        attribute sealIntegrity : Boolean = true;

        port inspiratorySide : AerosolFlowPort;
        port expiratorySide : AirFlowPort;
        port patientSide : PatientAirwayPort;

        action def FormSeal;
    }

    // ---- Patient ----
    part def Patient {
        attribute inhalationPressure : Pressure;
        attribute exhalationPressure : Pressure;
        attribute breathHoldDuration : Duration = 10.0 [s];
        attribute lungDepositedMass : Mass;

        port airway : PatientAirwayPort;

        action def Inhale {
            out inhaled : Aerosol;
        }

        action def HoldBreath {
            in aerosol : Aerosol;
        }

        action def Exhale {
            out exhaled : ExhaledAir;
        }

        exhibit state def PatientBreathingBehavior {
            entry; then Resting;
            state Resting;
            state Inhaling;
            state Holding;
            state Exhaling;
            transition Resting to Inhaling when beginInhalation;
            transition Inhaling to Holding when inhalationComplete;
            transition Holding to Exhaling after breathHoldDuration;
            transition Exhaling to Resting when exhalationComplete;
        }
    }

    // ---- Environment (ambient) ----
    part def AmbientEnvironment {
        attribute pressure : Pressure = 101325.0 [Pa];
        attribute temperature : Temperature = 293.15 [K];
        port ambientPort : AirFlowPort;
    }

    // ---- System Assembly ----
    part def InhalerSpacerSystem {
        part mdi : MeteredDoseInhaler;
        part chamber : SpacerChamber;
        part inspiratoryValve : InspiratoryValve;
        part expiratoryValve : ExpiratoryValve;
        part mouthpiece : Mouthpiece;
        part patient : Patient;
        part environment : AmbientEnvironment;

        connection : Connection connect mdi.sprayPort to chamber.inletPort;
        connection : Connection connect chamber.outletPort to inspiratoryValve.chamberSide;
        connection : Connection connect inspiratoryValve.mouthpieceSide to mouthpiece.inspiratorySide;
        connection : Connection connect mouthpiece.patientSide to patient.airway;
        connection : Connection connect mouthpiece.expiratorySide to expiratoryValve.mouthpieceSide;
        connection : Connection connect expiratoryValve.exhaustPort to environment.ambientPort;

        // Item flows
        flow : Aerosol from mdi.sprayPort to chamber.inletPort;
        flow : Aerosol from chamber.outletPort to inspiratoryValve.chamberSide;
        flow : Aerosol from inspiratoryValve.mouthpieceSide to mouthpiece.inspiratorySide;
        flow : Aerosol from mouthpiece.patientSide to patient.airway;
        flow : ExhaledAir from patient.airway to mouthpiece.patientSide;
        flow : ExhaledAir from mouthpiece.expiratorySide to expiratoryValve.mouthpieceSide;
        flow : ExhaledAir from expiratoryValve.exhaustPort to environment.ambientPort;

        // Operational action sequence
        action def DeliverDoseSequence {
            action actuateMDI : MeteredDoseInhaler::Actuate;
            action fillChamber : SpacerChamber::ReceiveAerosol;
            action slowAerosol : SpacerChamber::SlowAerosol;
            action evaporate : SpacerChamber::EvaporatePropellant;
            action suspend : SpacerChamber::HoldSuspension;
            action inhale : Patient::Inhale;
            action openInspiratory : InspiratoryValve::OpenValve;
            action holdBreath : Patient::HoldBreath;
            action exhale : Patient::Exhale;
            action openExpiratory : ExpiratoryValve::OpenValve;

            succession first actuateMDI then fillChamber;
            succession fillChamber then slowAerosol;
            succession slowAerosol then evaporate;
            succession evaporate then suspend;
            succession suspend then inhale;
            succession inhale then openInspiratory;
            succession openInspiratory then holdBreath;
            succession holdBreath then exhale;
            succession exhale then openExpiratory;
        }
    }

    // ---- Requirements ----
    requirement def MedicationDeliveryEfficiency {
        subject : InhalerSpacerSystem;
        attribute minLungDepositionFraction : Real = 0.30;
        objective {
            require patient.lungDepositedMass >= minLungDepositionFraction * mdi.nominalDoseMass
        }
    }

    requirement def CoordinationRelief {
        subject : InhalerSpacerSystem;
        attribute maxActuationToInhalationDelay : Duration = 10.0 [s];
        objective {
            require chamber.suspensionDuration >= maxActuationToInhalationDelay
        }
    }

    requirement def InspiratoryValveUnidirectional {
        subject : InhalatorSpacerSystem::inspiratoryValve;
        objective {
            require inspiratoryValve.isOpen == true implies inspiratoryValve.pressureDifferential > inspiratoryValve.openThreshold
            and
            inspiratoryValve.isOpen == false implies inspiratoryValve.pressureDifferential <= inspiratoryValve.openThreshold
        }
    }

    requirement def ExpiratoryValveUnidirectional {
        subject : InhalerSpacerSystem::expiratoryValve;
        objective {
            require expiratoryValve.isOpen == true implies expiratoryValve.exhalationPressure > expiratoryValve.openThreshold
            and
            expiratoryValve.isOpen == false implies expiratoryValve.exhalationPressure <= expiratoryValve.openThreshold
        }
    }

    requirement def ExhaledAirDiversion {
        subject : InhalerSpacerSystem;
        objective {
            require expiratoryValve.isOpen == true implies inspiratoryValve.isOpen == false
        }
    }

    requirement def ChamberSuspension {
        subject : InhalerSpacerSystem::chamber;
        attribute minSuspensionDuration : Duration = 5.0 [s];
        objective {
            require chamber.suspensionDuration >= minSuspensionDuration
        }
    }

    requirement def MouthpieceSeal {
        subject : InhalerSpacerSystem::mouthpiece;
        objective {
            require mouthpiece.sealIntegrity == true
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy MedicationDeliveryEfficiency by InhalerSpacerSystem;
    satisfaction satisfy CoordinationRelief by InhalerSpacerSystem;
    satisfaction satisfy InspiratoryValveUnidirectional by InhalerSpacerSystem;
    satisfaction satisfy ExpiratoryValveUnidirectional by InhalerSpacerSystem;
    satisfaction satisfy ExhaledAirDiversion by InhalerSpacerSystem;
    satisfaction satisfy ChamberSuspension by InhalerSpacerSystem;
    satisfaction satisfy MouthpieceSeal by InhalerSpacerSystem;
}
