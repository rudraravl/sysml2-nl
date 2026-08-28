package DapivirineVaginalRingSystem {
    private import ScalarValues::*;
    private import SI::*;

    unit mg;
    unit ug_per_mL;

    item def Dapivirine;
    item def SiliconePolymer;
    item def InsertSignal;
    item def StartRelease;
    item def RemoveSignal;

    flow def DapivirineFlow {
        end source;
        end target;
        item : Dapivirine;
    }

    part def DrugReservoir {
        item drug : Dapivirine;
        attribute initialDose : Real = 25 [mg];
        attribute currentDose : Real = initialDose;
    }

    part def VaginalRing {
        part siliconeMatrix : SiliconePolymer;
        part reservoir : DrugReservoir;
        port releasePort;
        port insertionPort;
        port removalPort;
        attribute effectivePeriod : Real = 28 [d];

        action releaseDrug {
            out item releasedDrug : Dapivirine;
        }

        state lifecycle {
            entry; then packaged;
            state packaged;
            accept InsertSignal via insertionPort
                then inserted;
            state inserted;
            accept StartRelease
                then active;
            state active;
            accept after 28 [d]
                then depleted;
            state depleted;
            accept RemoveSignal via removalPort
                then removed;
            state removed;
        }
    }

    part def VaginalEnvironment {
        port environmentPort;
        attribute concentration : Real;
    }

    part def Tissue {
        port tissuePort;
        attribute therapeuticConcentration : Real = 1.0 [ug_per_mL];
    }

    part def User {
        attribute adherence : Boolean = true;
    }

    part def HIVPreventionSystem {
        part ring : VaginalRing;
        part environment : VaginalEnvironment;
        part tissue : Tissue;
        part user : User;

        flow releaseFlow : DapivirineFlow from ring.releasePort to environment.environmentPort;
        flow diffusionFlow : DapivirineFlow from environment.environmentPort to tissue.tissuePort;
    }

    part systemInstance : HIVPreventionSystem;

    requirement 'Continuous Release' {
        doc /* The ring shall continuously release Dapivirine for at least 28 days. */
    }

    requirement 'Therapeutic Concentration' {
        doc /* The concentration of Dapivirine in vaginal tissue shall remain above the therapeutic level. */
    }

    requirement 'User Adherence' {
        doc /* The user shall wear the ring continuously for the full 28-day cycle. */
    }

    satisfy 'Continuous Release' by systemInstance.ring;
    satisfy 'Therapeutic Concentration' by systemInstance.tissue;
    satisfy 'User Adherence' by systemInstance.user;
}
