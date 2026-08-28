package InhalerSpacerSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    unit mg;
    unit mL;
    unit Pa;
    unit m_per_s;

    attribute def Mass :> Real { unit = mg; }
    attribute def Volume :> Real { unit = mL; }
    attribute def Pressure :> Real { unit = Pa; }
    attribute def Velocity :> Real { unit = m_per_s; }

    item def Medication;
    item def Aerosol {
        attribute drugMass : Mass;
        attribute particleVelocity : Velocity;
    }
    item def Air;

    port def SprayPort {
        out item spray : Aerosol;
    }
    port def ChamberInletPort {
        in item aerosol : Aerosol;
    }
    port def ChamberOutletPort {
        out item suspendedAerosol : Aerosol;
        attribute pressure : Pressure;
    }
    port def MedicationPort {
        in item medication : Aerosol;
        out item medicationOut : Aerosol;
        attribute pressure : Pressure;
    }
    port def AirPort {
        in item air : Air;
        out item airOut : Air;
        attribute pressure : Pressure;
    }
    port def PatientPort {
        in item inhaledMedication : Aerosol;
        out item exhaledAir : Air;
        attribute pressure : Pressure;
    }

    action def ProcessAerosol {
        in item incoming : Aerosol;
        out item processed : Aerosol;
    }

    part def MDI {
        port sprayPort : SprayPort;
        attribute doseMass : Mass = 100 [mg];
        perform action actuate {
            out item spray : Aerosol;
        }
        flow from actuate.spray to sprayPort.spray;
    }

    part def SpacerChamber {
        port inlet : ChamberInletPort;
        port outlet : ChamberOutletPort;
        attribute volume : Volume = 150 [mL];
        perform action processAerosol : ProcessAerosol;
        flow from inlet.aerosol to processAerosol.incoming;
        flow from processAerosol.processed to outlet.suspendedAerosol;
    }

    part def OneWayValve {
        attribute isOpen : Boolean = false;
    }

    part def InspiratoryValve :> OneWayValve {
        port chamberSide : MedicationPort;
        port mouthpieceSide : MedicationPort;
        state machine {
            initial;
            state Closed;
            state Open;
            transition from initial to Closed;
            transition from Closed to Open when mouthpieceSide.pressure < chamberSide.pressure;
            transition from Open to Closed when mouthpieceSide.pressure >= chamberSide.pressure;
        }
        flow from chamberSide.medication to mouthpieceSide.medicationOut;
    }

    part def ExpiratoryValve :> OneWayValve {
        port mouthpieceSide : AirPort;
        port environmentSide : AirPort;
        state machine {
            initial;
            state Closed;
            state Open;
            transition from initial to Closed;
            transition from Closed to Open when mouthpieceSide.pressure > environmentSide.pressure;
            transition from Open to Closed when mouthpieceSide.pressure <= environmentSide.pressure;
        }
        flow from mouthpieceSide.air to environmentSide.airOut;
    }

    part def Mouthpiece {
        port medicationPort : MedicationPort;
        port patientPort : PatientPort;
        port expiratoryPort : AirPort;
        flow from medicationPort.medicationOut to patientPort.inhaledMedication;
        flow from patientPort.exhaledAir to expiratoryPort.air;
    }

    part def Patient {
        port respiratoryPort : PatientPort;
        perform action breathe {
            out attribute pressure : Pressure;
        }
    }

    part def Environment {
        port envPort : AirPort;
    }

    interface def SprayInterface {
        end source : ~SprayPort;
        end target : ChamberInletPort;
        flow from source.spray to target.aerosol;
    }
    interface def ChamberValveInterface {
        end source : ChamberOutletPort;
        end target : MedicationPort;
        flow from source.suspendedAerosol to target.medication;
    }
    interface def ValveMouthpieceInterface {
        end source : MedicationPort;
        end target : MedicationPort;
        flow from source.medicationOut to target.medication;
    }
    interface def MouthpiecePatientInterface {
        end source : PatientPort;
        end target : PatientPort;
        flow from source.inhaledMedication to target.inhaledMedication;
        flow from target.exhaledAir to source.exhaledAir;
    }
    interface def ExpiratoryInterface {
        end source : AirPort;
        end target : AirPort;
        flow from source.airOut to target.air;
    }

    part def InhalerSpacerSystem {
        part mdi : MDI;
        part chamber : SpacerChamber;
        part inspiratoryValve : InspiratoryValve;
        part expiratoryValve : ExpiratoryValve;
        part mouthpiece : Mouthpiece;
        part environment : Environment;

        interface : SprayInterface connect
            source ::> mdi.sprayPort to
            target ::> chamber.inlet;
        interface : ChamberValveInterface connect
            source ::> chamber.outlet to
            target ::> inspiratoryValve.chamberSide;
        interface : ValveMouthpieceInterface connect
            source ::> inspiratoryValve.mouthpieceSide to
            target ::> mouthpiece.medicationPort;
        interface : ExpiratoryInterface connect
            source ::> mouthpiece.expiratoryPort to
            target ::> expiratoryValve.mouthpieceSide;
        interface : ExpiratoryInterface connect
            source ::> expiratoryValve.environmentSide to
            target ::> environment.envPort;

        perform action deliverDose {
            first start;
            then action actuateMDI {
                out item aerosolCloud : Aerosol;
            }
            then action fillChamber {
                in item aerosol : Aerosol;
                out item suspendedCloud : Aerosol;
            }
            then action inhale {
                out attribute inhalationPressure : Pressure;
            }
            then action openInspiratoryValve {
                in pressure : Pressure;
                in item medication : Aerosol;
                out item drawnMedication : Aerosol;
            }
            then action holdBreath;
            then action exhale {
                out attribute exhalationPressure : Pressure;
            }
            then action openExpiratoryValve {
                in pressure : Pressure;
                out item exhaledAir : Air;
            }
            then done;

            flow from actuateMDI.aerosolCloud to fillChamber.aerosol;
            flow from fillChamber.suspendedCloud to openInspiratoryValve.medication;
            flow from inhale.inhalationPressure to openInspiratoryValve.pressure;
            flow from exhale.exhalationPressure to openExpiratoryValve.pressure;
        }
    }

    part inhalerSystem : InhalerSpacerSystem;
    part patient : Patient;

    interface : MouthpiecePatientInterface connect
        source ::> inhalerSystem.mouthpiece.patientPort to
        target ::> patient.respiratoryPort;

    requirement def CoordinationRequirement {
        subject system : InhalerSpacerSystem;
        objective {
            /* The system shall allow medication delivery without requiring simultaneous actuation and inhalation. */
        }
    }
    requirement def AerosolSlowdownRequirement {
        subject chamber : SpacerChamber;
        objective {
            /* The chamber shall reduce aerosol particle velocity to less than 2 m/s. */
        }
    }
    requirement def ValveOperationRequirement {
        subject valve : OneWayValve;
        objective {
            /* The inspiratory valve shall open only on inhalation and the expiratory valve shall open only on exhalation. */
        }
    }
    requirement def DeliveryEfficiencyRequirement {
        subject system : InhalerSpacerSystem;
        objective {
            /* The system shall deliver at least 70% of the metered dose to the patient's lungs. */
        }
    }

    requirement coordinationReq : CoordinationRequirement;
    requirement aerosolReq : AerosolSlowdownRequirement;
    requirement valveReq : ValveOperationRequirement;
    requirement efficiencyReq : DeliveryEfficiencyRequirement;
}
