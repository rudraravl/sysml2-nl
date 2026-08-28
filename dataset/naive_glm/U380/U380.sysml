package SengstakenBlakemoreSystem {

    import ScalarValues::*;

    unit mmHg;
    unit mL;
    unit m;
    unit mLps;
    unit kg;

    value type Pressure :> Real { unit mmHg; }
    value type Volume :> Real { unit mL; }
    value type Length :> Real { unit m; }
    value type FlowRate :> Real { unit mLps; }
    value type Mass :> Real { unit kg; }

    item def Air;
    item def Blood;
    item def GastricFluid;
    item def Saline;

    attribute def PressureLimits {
        attribute maxEsophageal : Pressure = 45 [mmHg];
        attribute maxGastric : Pressure = 60 [mmHg];
    }

    port def InflationPort {
        in item air : Air;
        out item ventedAir : Air;
        attribute commandedPressure : Pressure;
        attribute commandedVolume : Volume;
    }

    port def AspirationPort {
        out item aspirate : Blood[0..*];
        in item suctionDrive : Air;
        attribute flowRate : FlowRate;
    }

    part def Balloon {
        attribute maxVolume : Volume;
        attribute maxPressure : Pressure;
        attribute currentVolume : Volume = 0 [mL];
        attribute currentPressure : Pressure = 0 [mmHg];
        attribute isIntact : Boolean = true;
        port inflationPort : InflationPort;

        state def BalloonState {
            entry; then deflated;
            state deflated;
            transition deflated to inflating
                when inflationPort.commandedPressure > 0 [mmHg];
            state inflating;
            transition inflating to maintaining
                when currentPressure >= inflationPort.commandedPressure;
            transition inflating to faulted
                when currentPressure > maxPressure;
            state maintaining;
            transition maintaining to deflating
                when inflationPort.commandedPressure == 0 [mmHg];
            state deflating;
            transition deflating to deflated
                when currentPressure == 0 [mmHg];
            state faulted;
        }

        state machine balloonStateMachine : BalloonState;

        action def Inflate {
            in item air : Air;
            in targetPressure : Pressure;
            out updatedPressure : Pressure;
            out updatedVolume : Volume;
        }

        action def Deflate {
            out ventedAir : Air;
            out updatedPressure : Pressure;
            out updatedVolume : Volume;
        }
    }

    part def GastricBalloon :> Balloon {
        attribute maxVolume = 500 [mL];
        attribute maxPressure = 60 [mmHg];
        attribute anatomicalSite : String = "stomach";
    }

    part def EsophagealBalloon :> Balloon {
        attribute maxVolume = 200 [mL];
        attribute maxPressure = 45 [mmHg];
        attribute anatomicalSite : String = "esophagus";
    }

    part def AspirationLumen {
        attribute lumenDiameter : Length;
        attribute lumenLength : Length;
        attribute isPatent : Boolean = true;
        port aspirationPort : AspirationPort;

        action def Aspirate {
            in item sourceFluid : Blood[0..*];
            in item suctionDrive : Air;
            out item aspirate : Blood[0..*];
        }

        perform action aspirateAction : Aspirate;
    }

    part def GastricAspirationLumen :> AspirationLumen {
        attribute lumenDiameter = 0.006 [m];
        attribute lumenLength = 1.0 [m];
        attribute anatomicalSite : String = "stomach";
    }

    part def EsophagealAspirationLumen :> AspirationLumen {
        attribute lumenDiameter = 0.004 [m];
        attribute lumenLength = 0.7 [m];
        attribute anatomicalSite : String = "esophagus";
    }

    part def MainTubeBody {
        attribute length : Length = 1.0 [m];
        attribute outerDiameter : Length = 0.008 [m];
        attribute material : String = "medical-grade silicone";
        attribute isFlexible : Boolean = true;
        port proximalEnd : InflationPort;
        port distalEnd : AspirationPort;
    }

    part def ControlManifold {
        port gastricInflationPort : InflationPort;
        port esophagealInflationPort : InflationPort;
        port gastricAspirationPort : AspirationPort;
        port esophagealAspirationPort : AspirationPort;
        attribute pressureLimits : PressureLimits;
        attribute gastricPressureGauge : Pressure = 0 [mmHg];
        attribute esophagealPressureGauge : Pressure = 0 [mmHg];
    }

    part def TractionWeight {
        attribute mass : Mass = 0.5 [kg];
        attribute applied : Boolean = false;
    }

    part def PatientAnatomy {
        attribute esophagusPresent : Boolean = true;
        attribute stomachPresent : Boolean = true;
        attribute varicealBleedingActive : Boolean = true;
        port esophagealSite : InflationPort;
        port gastricSite : InflationPort;
    }

    part def SengstakenBlakemoreTube {
        attribute deviceIdentifier : String = "SB-TUBE-001";
        attribute bleedingStopped : Boolean = false;
        attribute gastricInflatedFirst : Boolean = false;

        part mainTubeBody : MainTubeBody;
        part gastricBalloon : GastricBalloon;
        part esophagealBalloon : EsophagealBalloon;
        part gastricAspirationLumen : GastricAspirationLumen;
        part esophagealAspirationLumen : EsophagealAspirationLumen;
        part controlManifold : ControlManifold;
        part tractionWeight : TractionWeight;

        connection gastricInflationConn connect controlManifold.gastricInflationPort to gastricBalloon.inflationPort;
        connection esophagealInflationConn connect controlManifold.esophagealInflationPort to esophagealBalloon.inflationPort;
        connection gastricAspirationConn connect gastricAspirationLumen.aspirationPort to controlManifold.gastricAspirationPort;
        connection esophagealAspirationConn connect esophagealAspirationLumen.aspirationPort to controlManifold.esophagealAspirationPort;
        connection gastricTamponadeConn connect gastricBalloon.inflationPort to mainTubeBody.distalEnd;
        connection esophagealTamponadeConn connect esophagealBalloon.inflationPort to mainTubeBody.proximalEnd;

        action def InsertionProcedure {
            in item tube : SengstakenBlakemoreTube;
            out attribute inserted : Boolean;
        }

        action def TamponadeProcedure {
            in item tube : SengstakenBlakemoreTube;
            out attribute tamponadeAchieved : Boolean;
        }

        perform action insertion : InsertionProcedure;
        perform action tamponade : TamponadeProcedure;

        state def TubeOperationState {
            entry; then ready;
            state ready {
                entry { gastricInflatedFirst = false; }
            }
            transition ready to gastricInflation
                when controlManifold.gastricInflationPort.commandedPressure > 0 [mmHg];
            state gastricInflation;
            transition gastricInflation to tractionApplied
                when gastricBalloon.currentPressure >= 60 [mmHg];
            state tractionApplied {
                entry { tractionWeight.applied = true; }
            }
            transition tractionApplied to esophagealInflation
                when controlManifold.esophagealInflationPort.commandedPressure > 0 [mmHg]
                and gastricInflatedFirst == true;
            state esophagealInflation;
            transition esophagealInflation to tamponadeActive
                when esophagealBalloon.currentPressure >= 45 [mmHg];
            state tamponadeActive;
            transition tamponadeActive to monitoring
                when bleedingStopped == true;
            state monitoring;
            transition monitoring to deflation
                when bleedingStopped == true;
            state deflation;
            transition deflation to ready
                when gastricBalloon.currentPressure == 0 [mmHg]
                and esophagealBalloon.currentPressure == 0 [mmHg];
        }

        state machine operationStateMachine : TubeOperationState;
    }

    requirement def TubeDimensionsRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.mainTubeBody.length == 1.0 [m] }
        constraint { tube.mainTubeBody.material == "medical-grade silicone" }
    }

    requirement def BalloonCapacityRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.gastricBalloon.maxVolume == 500 [mL] }
        constraint { tube.esophagealBalloon.maxVolume == 200 [mL] }
    }

    requirement def PressureSafetyRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.esophagealBalloon.currentPressure <= 45 [mmHg] }
        constraint { tube.gastricBalloon.currentPressure <= 60 [mmHg] }
        constraint { tube.gastricBalloon.maxPressure == 60 [mmHg] }
        constraint { tube.esophagealBalloon.maxPressure == 45 [mmHg] }
    }

    requirement def InflationOrderRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint {
            tube.esophagealBalloon.currentPressure > 0 [mmHg]
            implies tube.gastricBalloon.currentPressure > 0 [mmHg]
        }
        constraint {
            tube.tractionWeight.applied == true
            implies tube.gastricBalloon.currentPressure > 0 [mmHg]
        }
    }

    requirement def AspirationFunctionRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.gastricAspirationLumen.isPatent == true }
        constraint { tube.esophagealAspirationLumen.isPatent == true }
        constraint { tube.gastricAspirationLumen.anatomicalSite == "stomach" }
        constraint { tube.esophagealAspirationLumen.anatomicalSite == "esophagus" }
    }

    requirement def TamponadeEffectivenessRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.gastricBalloon.currentVolume <= 500 [mL] }
        constraint { tube.esophagealBalloon.currentVolume <= 200 [mL] }
        constraint { tube.gastricBalloon.isIntact == true }
        constraint { tube.esophagealBalloon.isIntact == true }
    }

    requirement def ControlManifoldRequirement {
        subject tube : SengstakenBlakemoreTube;
        constraint { tube.controlManifold.pressureLimits.maxGastric == 60 [mmHg] }
        constraint { tube.controlManifold.pressureLimits.maxEsophageal == 45 [mmHg] }
    }

    part def SengstakenBlakemoreSystemAssembly {
        part tube : SengstakenBlakemoreTube;
        part patient : PatientAnatomy;

        connection gastricTamponadeContact connect tube.gastricBalloon.inflationPort to patient.gastricSite;
        connection esophagealTamponadeContact connect tube.esophagealBalloon.inflationPort to patient.esophagealSite;

        satisfy PressureSafetyRequirement by tube;
        satisfy InflationOrderRequirement by tube;
        satisfy AspirationFunctionRequirement by tube;
        satisfy TamponadeEffectivenessRequirement by tube;
        satisfy TubeDimensionsRequirement by tube;
        satisfy BalloonCapacityRequirement by tube;
        satisfy ControlManifoldRequirement by tube;
    }

}
