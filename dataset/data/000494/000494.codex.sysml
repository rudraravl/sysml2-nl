package ReplogleTubeSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Pressure {
        :> scalar;
        unit = "kPa";
    }

    attribute def FlowRate {
        :> scalar;
        unit = "mL/min";
    }

    attribute def Volume {
        :> scalar;
        unit = "mL";
    }

    attribute def Length {
        :> scalar;
        unit = "cm";
    }

    attribute def Diameter {
        :> scalar;
        unit = "mm";
    }

    attribute def Time {
        :> scalar;
        unit = "s";
    }

    attribute def Fraction {
        :> scalar;
        unit = "1";
    }

    item def OralSecretion {
        attribute volume : Volume;
        attribute viscosity : Real;
        attribute contaminationRisk : Fraction;
    }

    item def Air {
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    item def SalineFlush {
        attribute volume : Volume;
        attribute concentration : Real;
    }

    item def Aspirate {
        attribute collectedVolume : Volume;
        attribute secretionFraction : Fraction;
        attribute airFraction : Fraction;
    }

    item def AlarmSignal {
        attribute priority : Integer;
        attribute message : String;
    }

    port def SuctionPort {
        out item aspirate : Aspirate;
        in attribute appliedNegativePressure : Pressure;
    }

    port def VentPort {
        in item air : Air;
    }

    port def FlushPort {
        in item flush : SalineFlush;
    }

    port def PatientInterfacePort {
        in item secretion : OralSecretion;
        out item removedSecretion : OralSecretion;
    }

    port def CollectionPort {
        in item aspirate : Aspirate;
    }

    port def ClinicalStatusPort {
        out item alarm : AlarmSignal;
        out attribute obstructionDetected : Boolean;
        out attribute suctionActive : Boolean;
    }

    action def DrainUpperEsophagealPouch {
        in item secretion : OralSecretion;
        in attribute suctionPressure : Pressure;
        out item aspirate : Aspirate;
        out attribute aspirationRiskReduced : Boolean;

        first start;
        then assessSecretion;
        then applyLowContinuousSuction;
        then entrainAirThroughVentLumen;
        then transportAspirate;
        then confirmDrainage;
        then done;

        action assessSecretion;
        action applyLowContinuousSuction;
        action entrainAirThroughVentLumen;
        action transportAspirate;
        action confirmDrainage;
    }

    action def FlushTube {
        in item flush : SalineFlush;
        out attribute patencyRestored : Boolean;

        first start;
        then instillFlush;
        then clearDistalEyelets;
        then verifyReturnFlow;
        then done;

        action instillFlush;
        action clearDistalEyelets;
        action verifyReturnFlow;
    }

    action def DetectOcclusion {
        in attribute measuredFlow : FlowRate;
        in attribute appliedPressure : Pressure;
        out attribute occluded : Boolean;

        first start;
        then compareFlowToMinimum;
        then comparePressureToExpectedRange;
        then reportStatus;
        then done;

        action compareFlowToMinimum;
        action comparePressureToExpectedRange;
        action reportStatus;
    }

    state def TubeOperationalState {
        entry action initializeMonitoring;

        state Ready;
        state Positioned;
        state Suctioning;
        state Flushing;
        state Occluded;
        state Disconnected;
        state Removed;

        transition first Ready;

        transition ReadyToPositioned
            first Ready
            then Positioned;

        transition StartSuction
            first Positioned
            then Suctioning;

        transition BeginFlush
            first Suctioning
            then Flushing;

        transition ResumeSuction
            first Flushing
            then Suctioning;

        transition DetectBlockage
            first Suctioning
            then Occluded;

        transition ClearBlockage
            first Occluded
            then Flushing;

        transition LossOfVacuum
            first Suctioning
            then Disconnected;

        transition RestoreVacuum
            first Disconnected
            then Suctioning;

        transition EndUse
            first Positioned
            then Removed;

        action initializeMonitoring;
    }

    part def ReplogleTube {
        attribute outerDiameter : Diameter = 10.0;
        attribute insertionLength : Length = 18.0;
        attribute distalEyeletCount : Integer = 4;
        attribute radiopaqueStripePresent : Boolean = true;
        attribute material : String = "medical grade PVC";
        attribute intendedPlacement : String = "upper esophageal pouch";
        attribute primaryFunction : String = "continuous drainage of oral secretions from the blind upper esophageal pouch while maintaining vented low-pressure suction to reduce aspiration risk";

        port patientEnd : PatientInterfacePort;
        port suctionConnector : SuctionPort;
        port ventConnector : VentPort;
        port flushConnector : FlushPort;
        port status : ClinicalStatusPort;

        part suctionLumen {
            attribute internalDiameter : Diameter = 2.0;
            attribute patency : Fraction = 1.0;
            port distalInlet : PatientInterfacePort;
            port proximalOutlet : SuctionPort;
        }

        part ventLumen {
            attribute internalDiameter : Diameter = 1.0;
            attribute openToAtmosphere : Boolean = true;
            port proximalVent : VentPort;
        }

        perform action drainage : DrainUpperEsophagealPouch;
        perform action flushProcedure : FlushTube;
        perform action occlusionCheck : DetectOcclusion;

        exhibit state operationalState : TubeOperationalState;
    }

    part def VacuumRegulator {
        attribute setPressure : Pressure = -8.0;
        attribute minimumPressure : Pressure = -5.0;
        attribute maximumPressure : Pressure = -12.0;
        attribute continuousMode : Boolean = true;

        port suctionOutlet : SuctionPort;
        port status : ClinicalStatusPort;
    }

    part def CollectionCanister {
        attribute maximumCapacity : Volume = 500.0;
        attribute currentVolume : Volume = 0.0;
        attribute overflowProtectionEnabled : Boolean = true;

        port inlet : CollectionPort;
        port status : ClinicalStatusPort;
    }

    part def PatientUpperEsophagealPouch {
        attribute retainedSecretionVolume : Volume = 8.0;
        attribute secretionProductionRate : FlowRate = 1.5;
        attribute aspirationRisk : Fraction = 0.8;

        port pouchInterface : PatientInterfacePort;
    }

    part def BedsideClinicalUser {
        attribute role : String = "neonatal clinician";
        attribute flushInterval : Time = 14400.0;
        attribute verifiesTubePosition : Boolean = true;
    }

    part def ReplogleDrainageSystem {
        attribute systemPurpose : String = "Provide high-level management of accumulated oral secretions in an infant with proximal esophageal obstruction by vented continuous suction through a double-lumen Replogle tube.";
        attribute targetSuctionPressure : Pressure = -8.0;
        attribute minimumDrainageFlow : FlowRate = 0.2;
        attribute maximumAllowedCanisterVolume : Volume = 450.0;

        part patientPouch : PatientUpperEsophagealPouch;
        part tube : ReplogleTube;
        part regulator : VacuumRegulator;
        part canister : CollectionCanister;
        part clinician : BedsideClinicalUser;

        connection secretionPath
            connect patientPouch.pouchInterface to tube.patientEnd;

        connection suctionPath
            connect tube.suctionConnector to regulator.suctionOutlet;

        connection canisterPath
            connect tube.suctionConnector to canister.inlet;

        connection ventPath
            connect tube.ventConnector to tube.ventLumen.proximalVent;

        connection distalDrainagePath
            connect tube.suctionLumen.distalInlet to tube.patientEnd;

        connection proximalDrainagePath
            connect tube.suctionLumen.proximalOutlet to tube.suctionConnector;

        perform action primaryDrainage : DrainUpperEsophagealPouch {
            in secretion = patientPouch.pouchInterface.secretion;
            in suctionPressure = regulator.setPressure;
        }

        perform action patencyAssessment : DetectOcclusion;

        exhibit state tubeState : TubeOperationalState;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The Replogle drainage system shall continuously remove oral secretions from the upper esophageal pouch using vented low-pressure suction to reduce pooling and aspiration risk.";

        subject system : ReplogleDrainageSystem;

        require constraint {
            system.targetSuctionPressure <= -5.0 and
            system.targetSuctionPressure >= -12.0
        }
    }

    requirement def DoubleLumenRequirement {
        doc "The tube shall provide a suction lumen for secretion removal and a separate vent lumen to admit air and prevent mucosal adherence during suction.";

        subject tube : ReplogleTube;

        require constraint {
            tube.suctionLumen.internalDiameter > tube.ventLumen.internalDiameter and
            tube.ventLumen.openToAtmosphere == true
        }
    }

    requirement def PatencyMonitoringRequirement {
        doc "The system shall identify probable occlusion when suction is applied and drainage flow falls below the minimum expected rate.";

        subject system : ReplogleDrainageSystem;

        require constraint {
            system.minimumDrainageFlow >= 0.2
        }
    }

    requirement def CollectionSafetyRequirement {
        doc "The collection canister shall provide sufficient capacity and overflow protection for captured aspirate.";

        subject canister : CollectionCanister;

        require constraint {
            canister.maximumCapacity >= 500.0 and
            canister.overflowProtectionEnabled == true
        }
    }

    requirement def PositioningRequirement {
        doc "The tube shall be configured for placement in the proximal blind esophageal pouch and shall include a radiopaque marker to support clinical position verification.";

        subject tube : ReplogleTube;

        require constraint {
            tube.radiopaqueStripePresent == true and
            tube.insertionLength > 0.0
        }
    }

    satisfy PrimaryFunctionRequirement by ReplogleDrainageSystem;
    satisfy DoubleLumenRequirement by ReplogleTube;
    satisfy PatencyMonitoringRequirement by ReplogleDrainageSystem;
    satisfy CollectionSafetyRequirement by CollectionCanister;
    satisfy PositioningRequirement by ReplogleTube;

}