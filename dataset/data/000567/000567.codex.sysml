package CausticPencilSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Millimeter :> Length;
    attribute def Gram :> Mass;
    attribute def Milligram :> Mass;
    attribute def Second :> Time;
    attribute def DegreeCelsius :> TemperatureValue;
    attribute def Percent :> ScalarValues::Real;
    attribute def pHValue :> ScalarValues::Real;

    item def BiologicalTissue {
        attribute hydrationLevel : Percent;
        attribute surfaceTemperature : DegreeCelsius;
        attribute lesionArea : Millimeter;
        attribute bleedingRate : Milligram;
        attribute tissueIntegrity : Percent;
    }

    item def ChemicalAgent {
        attribute silverNitrateConcentration : Percent;
        attribute potassiumNitrateConcentration : Percent;
        attribute availableMass : Milligram;
        attribute dissolvedFraction : Percent;
        attribute pH : pHValue;
    }

    item def Moisture {
        attribute volume : ScalarValues::Real;
        attribute sourceTemperature : DegreeCelsius;
    }

    item def ProtectiveCapStatus {
        attribute isInstalled : Boolean;
    }

    item def UserForce {
        attribute normalForce : ScalarValues::Real;
        attribute contactDuration : Second;
    }

    port def TissueContactPort {
        in item targetTissue : BiologicalTissue;
        out item releasedAgent : ChemicalAgent;
        in item moisture : Moisture;
        in item appliedForce : UserForce;
    }

    port def HandlingPort {
        in item gripForce : UserForce;
        out item capStatus : ProtectiveCapStatus;
    }

    port def StoragePort {
        in item ambientMoisture : Moisture;
        out item containmentStatus : ProtectiveCapStatus;
    }

    part def CausticPencil {
        attribute overallLength : Millimeter = 150 [mm];
        attribute applicatorTipDiameter : Millimeter = 2 [mm];
        attribute activeAgentMass : Milligram = 75 [mg];
        attribute shelfLifeRemaining : ScalarValues::Real;
        attribute isSinglePatientUse : Boolean = true;

        port tissueInterface : TissueContactPort;
        port handleInterface : HandlingPort;
        port storageInterface : StoragePort;

        part handle : Handle {
            attribute length : Millimeter = 120 [mm];
            attribute diameter : Millimeter = 7 [mm];
            attribute surfaceTextureCoefficient : ScalarValues::Real = 0.65;
        }

        part activeTip : CausticTip {
            attribute exposedLength : Millimeter = 5 [mm];
            attribute agentMass : Milligram = 75 [mg];
            attribute silverNitrateConcentration : Percent = 75;
            attribute potassiumNitrateConcentration : Percent = 25;
        }

        part protectiveCap : ProtectiveCap {
            attribute internalClearance : Millimeter = 2 [mm];
            attribute moistureBarrierEffectiveness : Percent = 95;
            attribute installed : Boolean = true;
        }

        connect handle.userGrip to handleInterface;
        connect activeTip.applicationSurface to tissueInterface;
        connect protectiveCap.storageSeal to storageInterface;

        action def RemoveCap {
            in item currentCapStatus : ProtectiveCapStatus;
            out item removedCapStatus : ProtectiveCapStatus;
            bind removedCapStatus.isInstalled = false;
        }

        action def ApplyToMoistenedTissue {
            in item tissue : BiologicalTissue;
            in item moisture : Moisture;
            in item force : UserForce;
            in item agentBeforeUse : ChemicalAgent;
            out item treatedTissue : BiologicalTissue;
            out item agentAfterUse : ChemicalAgent;

            bind treatedTissue.hydrationLevel = tissue.hydrationLevel;
            bind treatedTissue.surfaceTemperature = tissue.surfaceTemperature;
            bind treatedTissue.bleedingRate = tissue.bleedingRate * 0.25;
            bind treatedTissue.tissueIntegrity = tissue.tissueIntegrity * 0.80;
            bind agentAfterUse.availableMass = agentBeforeUse.availableMass - 5 [mg];
            bind agentAfterUse.dissolvedFraction = 60;
        }

        action def ReinstallCap {
            in item currentCapStatus : ProtectiveCapStatus;
            out item securedCapStatus : ProtectiveCapStatus;
            bind securedCapStatus.isInstalled = true;
        }

        state def CausticPencilUseStateMachine {
            state capped;
            state readyForUse;
            state chemicallyActive;
            state depleted;
            state disposed;

            entry action capped {
                send ProtectiveCapStatus { isInstalled = true; } via storageInterface.containmentStatus;
            }

            transition first capped then readyForUse
                accept RemoveCap;

            transition readyForUse then chemicallyActive
                accept ApplyToMoistenedTissue
                if activeTip.agentMass > 0 [mg];

            transition chemicallyActive then readyForUse
                if activeTip.agentMass > 5 [mg];

            transition chemicallyActive then depleted
                if activeTip.agentMass <= 5 [mg];

            transition readyForUse then capped
                accept ReinstallCap;

            transition depleted then disposed
                accept Dispose;
        }
    }

    part def Handle {
        attribute length : Millimeter;
        attribute diameter : Millimeter;
        attribute surfaceTextureCoefficient : ScalarValues::Real;
        port userGrip : HandlingPort;
    }

    part def CausticTip {
        attribute exposedLength : Millimeter;
        attribute agentMass : Milligram;
        attribute silverNitrateConcentration : Percent;
        attribute potassiumNitrateConcentration : Percent;
        attribute minimumEffectiveMoisture : Percent = 20;
        port applicationSurface : TissueContactPort;
    }

    part def ProtectiveCap {
        attribute internalClearance : Millimeter;
        attribute moistureBarrierEffectiveness : Percent;
        attribute installed : Boolean;
        port storageSeal : StoragePort;
    }

    part def User {
        attribute trainingConfirmed : Boolean;
        port handInterface : HandlingPort;
    }

    part def TreatmentSite {
        attribute lesionDiameter : Millimeter = 3 [mm];
        attribute tissueMoisture : Percent = 45;
        attribute initialBleedingRate : Milligram = 12 [mg];
        port tissueSurface : TissueContactPort;
    }

    part def ClinicalEnvironment {
        attribute ambientTemperature : DegreeCelsius = 22 [degC];
        attribute relativeHumidity : Percent = 40;
        port storageExposure : StoragePort;
    }

    part causticPencilSystem {
        part pencil : CausticPencil;
        part operator : User;
        part treatmentSite : TreatmentSite;
        part environment : ClinicalEnvironment;

        connect operator.handInterface to pencil.handleInterface;
        connect pencil.tissueInterface to treatmentSite.tissueSurface;
        connect environment.storageExposure to pencil.storageInterface;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The caustic pencil shall provide localized chemical cauterization by transferring a controlled quantity of silver nitrate compound from its active tip to moistened superficial tissue. */
        subject pencil : CausticPencil;

        require constraint {
            pencil.activeTip.silverNitrateConcentration >= 70 and
            pencil.activeTip.agentMass > 0 [mg] and
            pencil.protectiveCap.moistureBarrierEffectiveness >= 90
        }
    }

    requirement def ControlledApplicationRequirement {
        doc /* The active tip shall limit chemical delivery to the contacted tissue area during brief manual application. */
        subject pencil : CausticPencil;

        require constraint {
            pencil.applicatorTipDiameter <= 3 [mm] and
            pencil.activeTip.exposedLength <= 6 [mm]
        }
    }

    requirement def StorageProtectionRequirement {
        doc /* The protective cap shall reduce unintended activation by limiting moisture exposure during storage. */
        subject cap : ProtectiveCap;

        require constraint {
            cap.moistureBarrierEffectiveness >= 90 and
            cap.internalClearance >= 1 [mm]
        }
    }

    requirement def SingleUseSafetyRequirement {
        doc /* The caustic pencil shall be treated as a single-patient chemical applicator after tissue contact. */
        subject pencil : CausticPencil;

        require constraint {
            pencil.isSinglePatientUse == true
        }
    }

    satisfy PrimaryFunctionRequirement by causticPencilSystem.pencil;
    satisfy ControlledApplicationRequirement by causticPencilSystem.pencil;
    satisfy StorageProtectionRequirement by causticPencilSystem.pencil.protectiveCap;
    satisfy SingleUseSafetyRequirement by causticPencilSystem.pencil;
}