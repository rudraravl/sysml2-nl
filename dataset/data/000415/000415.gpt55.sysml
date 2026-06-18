package XenobotBasedSystem {

    private import ScalarValues::*;

    attribute def Length_um :> Real {
        doc /* Unit: micrometer (um). */
    }

    attribute def Length_mm :> Real {
        doc /* Unit: millimeter (mm). */
    }

    attribute def Mass_ug :> Real {
        doc /* Unit: microgram (ug). */
    }

    attribute def Time_s :> Real {
        doc /* Unit: second (s). */
    }

    attribute def Time_h :> Real {
        doc /* Unit: hour (h). */
    }

    attribute def Velocity_um_per_s :> Real {
        doc /* Unit: micrometer per second (um/s). */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Unit: hertz (1/s). */
    }

    attribute def Concentration_mM :> Real {
        doc /* Unit: millimole per liter (mM). */
    }

    attribute def Concentration_particles_per_mL :> Real {
        doc /* Unit: particles per milliliter. */
    }

    attribute def Energy_uJ :> Real {
        doc /* Unit: microjoule (uJ). */
    }

    attribute def Temperature_C :> Real {
        doc /* Unit: degree Celsius. */
    }

    attribute def Force_uN :> Real {
        doc /* Unit: micronewton (uN). */
    }

    attribute def Angle_deg :> Real {
        doc /* Unit: degree. */
    }

    attribute def Count :> Integer {
        doc /* Unit: dimensionless count. */
    }

    attribute def Rate_particles_per_h :> Real {
        doc /* Unit: particles per hour. */
    }

    attribute def Fraction :> Real {
        doc /* Unit: dimensionless fraction from 0.0 to 1.0. */
    }

    attribute def pH :> Real {
        doc /* Unit: pH. */
    }

    enum def MissionMode {
        enum idle;
        enum survey;
        enum homingToGradient;
        enum collecting;
        enum aggregating;
        enum recovering;
        enum quiescentFailsafe;
    }

    enum def DebrisClass {
        enum microplasticFiber;
        enum microplasticBead;
        enum organicParticulate;
        enum mineralParticulate;
        enum unknownSuspendedParticle;
    }

    enum def BioSignalKind {
        enum calciumWave;
        enum membranePotentialShift;
        enum mechanotransductionPulse;
        enum metabolicStressSignal;
    }

    item def AqueousMedium {
        attribute temperature : Temperature_C = 22.0;
        attribute pHValue : pH = 7.2;
        attribute dissolvedGlucose : Concentration_mM = 5.0;
        attribute dissolvedOxygenFraction : Fraction = 0.85;
        attribute particleDensity : Concentration_particles_per_mL = 35.0;
    }

    item def NutrientMixture {
        attribute glucose : Concentration_mM = 5.5;
        attribute aminoAcids : Concentration_mM = 2.0;
        attribute salts : Concentration_mM = 110.0;
        attribute bufferPH : pH = 7.2;
    }

    item def WasteMetabolite {
        attribute lactate : Concentration_mM = 0.8;
        attribute carbonDioxideFraction : Fraction = 0.02;
        attribute ammonia : Concentration_mM = 0.05;
    }

    item def MicroDebrisParticle {
        attribute particleClass : DebrisClass = DebrisClass::microplasticBead;
        attribute diameter : Length_um = 40.0;
        attribute estimatedMass : Mass_ug = 0.00006;
        attribute surfaceAdhesionFactor : Fraction = 0.62;
    }

    item def DebrisAggregate {
        attribute particleCount : Count = 0;
        attribute aggregateDiameter : Length_um = 0.0;
        attribute estimatedMass : Mass_ug = 0.0;
        attribute compactionFraction : Fraction = 0.0;
    }

    item def ChemicalGradient {
        attribute attractantConcentration : Concentration_mM = 0.0;
        attribute gradientBearing : Angle_deg = 0.0;
        attribute confidence : Fraction = 0.0;
    }

    item def MechanicalStimulus {
        attribute contactForce : Force_uN = 0.0;
        attribute bearing : Angle_deg = 0.0;
        attribute duration : Time_s = 0.0;
    }

    item def BioelectricSignal {
        attribute kind : BioSignalKind = BioSignalKind::membranePotentialShift;
        attribute amplitudeFraction : Fraction = 0.0;
        attribute propagationDelay : Time_s = 0.0;
        attribute directionBias : Angle_deg = 0.0;
    }

    item def LocomotionCommand {
        attribute targetHeading : Angle_deg = 0.0;
        attribute beatFrequency : Frequency_Hz = 18.0;
        attribute dutyFraction : Fraction = 0.70;
        attribute turnBias : Fraction = 0.0;
    }

    port def AqueousExchangePort {
        inout item medium : AqueousMedium;
        in item suspendedDebris : MicroDebrisParticle;
        out item releasedWaste : WasteMetabolite;
    }

    port def NutrientIntakePort {
        in item nutrients : NutrientMixture;
    }

    port def WasteOutputPort {
        out item waste : WasteMetabolite;
    }

    port def ChemicalSensingPort {
        in item gradient : ChemicalGradient;
        out item sensorySignal : BioelectricSignal;
    }

    port def ContactSensingPort {
        in item stimulus : MechanicalStimulus;
        out item contactSignal : BioelectricSignal;
    }

    port def BioelectricCoordinationPort {
        inout item signal : BioelectricSignal;
    }

    port def LocomotionCommandPort {
        in item command : LocomotionCommand;
    }

    port def DebrisCapturePort {
        in item targetParticle : MicroDebrisParticle;
        out item aggregate : DebrisAggregate;
    }

    port def MissionStatusPort {
        out attribute currentMode : MissionMode;
        out attribute energyReserve : Energy_uJ;
        out attribute collectedParticles : Count;
    }

    action def SenseEnvironment {
        in item medium : AqueousMedium;
        in item gradient : ChemicalGradient;
        in item contact : MechanicalStimulus;
        out item chemicalSignal : BioelectricSignal;
        out item mechanicalSignal : BioelectricSignal;
    }

    action def IntegrateBioelectricSignals {
        in item chemicalSignal : BioelectricSignal;
        in item mechanicalSignal : BioelectricSignal;
        in attribute energyReserve : Energy_uJ;
        out item locomotionCommand : LocomotionCommand;
        out attribute selectedMode : MissionMode;
    }

    action def RegulateCiliaBeat {
        in item command : LocomotionCommand;
        out item coordinationSignal : BioelectricSignal;
        attribute minimumBeatFrequency : Frequency_Hz = 6.0;
        attribute nominalBeatFrequency : Frequency_Hz = 18.0;
        attribute maximumBeatFrequency : Frequency_Hz = 28.0;
    }

    action def PropelThroughWater {
        in item coordinationSignal : BioelectricSignal;
        inout item medium : AqueousMedium;
        out attribute achievedVelocity : Velocity_um_per_s;
        attribute nominalVelocity : Velocity_um_per_s = 45.0;
    }

    action def CaptureParticle {
        in item targetParticle : MicroDebrisParticle;
        in attribute adhesionReadiness : Fraction;
        out item aggregate : DebrisAggregate;
        attribute captureProbability : Fraction = 0.82;
    }

    action def CompactAggregate {
        inout item aggregate : DebrisAggregate;
        out attribute compactionFraction : Fraction;
        attribute nominalCompactionDuration : Time_s = 15.0;
    }

    action def MetabolizeNutrients {
        in item nutrients : NutrientMixture;
        out item waste : WasteMetabolite;
        out attribute producedEnergy : Energy_uJ;
        attribute conversionEfficiency : Fraction = 0.36;
    }

    action def RecoverInLowEnergyMode {
        in item nutrients : NutrientMixture;
        out attribute restoredEnergy : Energy_uJ;
        attribute recoveryDuration : Time_s = 120.0;
    }

    action def ExecutePrimaryCleanupFunction {
        in item medium : AqueousMedium;
        in item nutrients : NutrientMixture;
        in item targetParticle : MicroDebrisParticle;
        out item collectedAggregate : DebrisAggregate;
        out attribute missionMode : MissionMode;
        out attribute achievedCollectionRate : Rate_particles_per_h;

        action sense : SenseEnvironment;
        action integrate : IntegrateBioelectricSignals;
        action regulate : RegulateCiliaBeat;
        action propel : PropelThroughWater;
        action capture : CaptureParticle;
        action compact : CompactAggregate;
        action metabolize : MetabolizeNutrients;

        first sense then integrate;
        then regulate;
        then propel;
        then capture;
        then compact;
        then metabolize;
    }

    state def XenobotOperationalStateMachine {
        attribute energyReserve : Energy_uJ;
        attribute collectedParticles : Count;
        attribute localParticleDensity : Concentration_particles_per_mL;
        attribute contactForce : Force_uN;

        state dormant;
        state surveying;
        state homingToParticleGradient;
        state collectingParticle;
        state aggregatingPayload;
        state metabolicRecovery;
        state failsafeQuiescent;

        entry action initialize {
            out attribute initialMode : MissionMode = MissionMode::idle;
        }

        transition initialTransition first dormant;

        transition activateFromDormant
            from dormant
            to surveying
            when energyReserve >= 8.0;

        transition detectUsefulGradient
            from surveying
            to homingToParticleGradient
            when localParticleDensity >= 20.0;

        transition contactTargetParticle
            from homingToParticleGradient
            to collectingParticle
            when contactForce >= 0.08;

        transition particleCaptured
            from collectingParticle
            to aggregatingPayload
            when collectedParticles >= 1;

        transition resumeSurveyAfterAggregation
            from aggregatingPayload
            to surveying
            when energyReserve >= 5.0;

        transition lowEnergyRecovery
            from surveying
            to metabolicRecovery
            when energyReserve < 5.0;

        transition recovered
            from metabolicRecovery
            to surveying
            when energyReserve >= 10.0;

        transition severeEnergyDepletion
            from metabolicRecovery
            to failsafeQuiescent
            when energyReserve < 1.5;

        transition safeReactivation
            from failsafeQuiescent
            to dormant
            when energyReserve >= 6.0;
    }

    part def CiliatedEpithelialShell {
        doc /* Living outer surface derived from coordinated epithelial cells; provides protection, environmental exchange, and cilia-based propulsion. */

        attribute shellThickness : Length_um = 35.0;
        attribute surfaceCoverageFraction : Fraction = 0.93;
        attribute ciliaLength : Length_um = 14.0;
        attribute nominalCiliaBeatFrequency : Frequency_Hz = 18.0;
        attribute maximumSustainableBeatFrequency : Frequency_Hz = 28.0;

        port mediumPort : AqueousExchangePort;
        port commandIn : LocomotionCommandPort;
        port coordination : BioelectricCoordinationPort;

        perform action regulateBeat : RegulateCiliaBeat;
        perform action propel : PropelThroughWater;
    }

    part def ContractileCellPatch {
        doc /* Contractile living actuator patch that biases body curvature and assists turning, compaction, and escape from obstacles. */

        attribute patchDiameter : Length_um = 120.0;
        attribute contractionForce : Force_uN = 0.35;
        attribute contractionCycleFrequency : Frequency_Hz = 0.9;
        attribute fatigueLimitDuration : Time_s = 240.0;

        port coordination : BioelectricCoordinationPort;
        port contactSensing : ContactSensingPort;
    }

    part def ChemosensoryEpithelium {
        doc /* Cell layer that converts nutrient, oxygen, and particulate concentration gradients into bioelectric guidance signals. */

        attribute sensitivityThreshold : Concentration_particles_per_mL = 5.0;
        attribute angularResolution : Angle_deg = 22.0;
        attribute responseDelay : Time_s = 1.8;

        port chemicalIn : ChemicalSensingPort;
        port coordination : BioelectricCoordinationPort;

        perform action senseEnvironment : SenseEnvironment;
    }

    part def MechanosensoryRim {
        doc /* Peripheral contact-sensitive rim used to detect collision, particle contact, and payload pocket fill condition. */

        attribute contactThreshold : Force_uN = 0.08;
        attribute recoveryTime : Time_s = 0.4;
        attribute rimWidth : Length_um = 25.0;

        port contactIn : ContactSensingPort;
        port coordination : BioelectricCoordinationPort;
    }

    part def AdhesivePayloadPocket {
        doc /* Ventral collection pocket with mucus-like adhesion that captures and aggregates suspended particles. */

        attribute pocketMouthWidth : Length_um = 180.0;
        attribute pocketDepth : Length_um = 70.0;
        attribute adhesionReadiness : Fraction = 0.78;
        attribute maximumParticleCapacity : Count = 140;
        attribute currentParticleCount : Count = 0;
        attribute releaseThresholdAggregateDiameter : Length_um = 260.0;

        port capturePort : DebrisCapturePort;
        port coordination : BioelectricCoordinationPort;

        perform action captureParticle : CaptureParticle;
        perform action compactAggregate : CompactAggregate;
    }

    part def MetabolicCore {
        doc /* Internal living-cell energy management region that consumes dissolved nutrients and supports autonomous operation without electronics. */

        attribute storedEnergy : Energy_uJ = 14.0;
        attribute minimumOperatingEnergy : Energy_uJ = 5.0;
        attribute dormantEnergyUseRate : Energy_uJ = 0.004;
        attribute activeEnergyUseRate : Energy_uJ = 0.055;
        attribute nominalMissionDuration : Time_h = 6.0;

        port nutrientIn : NutrientIntakePort;
        port wasteOut : WasteOutputPort;
        port coordination : BioelectricCoordinationPort;

        perform action metabolize : MetabolizeNutrients;
        perform action recover : RecoverInLowEnergyMode;
    }

    part def BioelectricCoordinationNetwork {
        doc /* Distributed, non-neural coordination network using cell-to-cell membrane potential and calcium-wave signaling. */

        attribute propagationSpeed : Velocity_um_per_s = 90.0;
        attribute signalAttenuationFractionPer100um : Fraction = 0.12;
        attribute decisionLatency : Time_s = 2.5;

        port shellLink : BioelectricCoordinationPort;
        port actuatorLink : BioelectricCoordinationPort;
        port chemosensorLink : BioelectricCoordinationPort;
        port mechanosensorLink : BioelectricCoordinationPort;
        port pocketLink : BioelectricCoordinationPort;
        port metabolicLink : BioelectricCoordinationPort;

        perform action integrateSignals : IntegrateBioelectricSignals;
    }

    part def XenobotMissionStatusEmitter {
        attribute currentMode : MissionMode = MissionMode::idle;
        attribute energyReserve : Energy_uJ = 14.0;
        attribute collectedParticles : Count = 0;
        attribute collectionRate : Rate_particles_per_h = 0.0;

        port status : MissionStatusPort;
    }

    part def BioHybridXenobotCollector {
        doc /* A xenobot-based autonomous micro-biorobot whose primary high-level function is to move through an aqueous environment, locate suspended micro-debris, capture it with a living adhesive pocket, and consolidate it into aggregates for later removal. */

        attribute bodyLength : Length_um = 550.0;
        attribute bodyWidth : Length_um = 420.0;
        attribute bodyHeight : Length_um = 260.0;
        attribute wetMass : Mass_ug = 18.0;
        attribute nominalSpeed : Velocity_um_per_s = 45.0;
        attribute minimumTurnRadius : Length_um = 300.0;
        attribute operatingTemperatureMinimum : Temperature_C = 18.0;
        attribute operatingTemperatureMaximum : Temperature_C = 26.0;
        attribute designLife : Time_h = 168.0;
        attribute collectionRangeRadius : Length_mm = 12.0;
        attribute requiredCollectionRate : Rate_particles_per_h = 30.0;

        port environment : AqueousExchangePort;
        port nutrientInterface : NutrientIntakePort;
        port wasteInterface : WasteOutputPort;
        port chemicalInterface : ChemicalSensingPort;
        port contactInterface : ContactSensingPort;
        port debrisInterface : DebrisCapturePort;
        port statusInterface : MissionStatusPort;

        part shell : CiliatedEpithelialShell;
        part contractilePatch : ContractileCellPatch;
        part chemosensor : ChemosensoryEpithelium;
        part mechanosensor : MechanosensoryRim;
        part payloadPocket : AdhesivePayloadPocket;
        part metabolicCore : MetabolicCore;
        part coordinator : BioelectricCoordinationNetwork;
        part statusEmitter : XenobotMissionStatusEmitter;

        connection environmentalExchange connect environment to shell.mediumPort;
        connection nutrientSupply connect nutrientInterface to metabolicCore.nutrientIn;
        connection wasteRelease connect metabolicCore.wasteOut to wasteInterface;
        connection chemicalSensingPath connect chemicalInterface to chemosensor.chemicalIn;
        connection contactSensingPath connect contactInterface to mechanosensor.contactIn;
        connection debrisCapturePath connect debrisInterface to payloadPocket.capturePort;

        connection coordinatorToShell connect coordinator.shellLink to shell.coordination;
        connection coordinatorToActuator connect coordinator.actuatorLink to contractilePatch.coordination;
        connection coordinatorToChemosensor connect coordinator.chemosensorLink to chemosensor.coordination;
        connection coordinatorToMechanosensor connect coordinator.mechanosensorLink to mechanosensor.coordination;
        connection coordinatorToPocket connect coordinator.pocketLink to payloadPocket.coordination;
        connection coordinatorToMetabolicCore connect coordinator.metabolicLink to metabolicCore.coordination;

        connection contactToActuator connect mechanosensor.contactIn to contractilePatch.contactSensing;
        connection statusExport connect statusEmitter.status to statusInterface;

        perform action primaryCleanup : ExecutePrimaryCleanupFunction;
        exhibit state operationalStates : XenobotOperationalStateMachine;
    }

    part def AqueousCleanupMission {
        doc /* Mission context for deploying the xenobot-based collector into a small aqueous volume to reduce suspended micro-debris by autonomous aggregation. */

        attribute missionDuration : Time_h = 4.0;
        attribute treatedVolumeEquivalentLength : Length_mm = 25.0;
        attribute initialParticleDensity : Concentration_particles_per_mL = 35.0;
        attribute targetParticleDensity : Concentration_particles_per_mL = 15.0;
        attribute allowedTemperatureLow : Temperature_C = 18.0;
        attribute allowedTemperatureHigh : Temperature_C = 26.0;

        part xenobot : BioHybridXenobotCollector;

        item operatingMedium : AqueousMedium {
            attribute temperature : Temperature_C = 22.0;
            attribute pHValue : pH = 7.2;
            attribute dissolvedGlucose : Concentration_mM = 5.0;
            attribute dissolvedOxygenFraction : Fraction = 0.85;
            attribute particleDensity : Concentration_particles_per_mL = 35.0;
        }

        item suppliedNutrients : NutrientMixture {
            attribute glucose : Concentration_mM = 5.5;
            attribute aminoAcids : Concentration_mM = 2.0;
            attribute salts : Concentration_mM = 110.0;
            attribute bufferPH : pH = 7.2;
        }

        item representativeParticle : MicroDebrisParticle {
            attribute particleClass : DebrisClass = DebrisClass::microplasticBead;
            attribute diameter : Length_um = 40.0;
            attribute estimatedMass : Mass_ug = 0.00006;
            attribute surfaceAdhesionFactor : Fraction = 0.62;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide the high-level primary function of autonomous aqueous micro-debris collection by moving as a living xenobot-derived body, sensing gradients and contacts, capturing suspended particles, and consolidating them into removable aggregates. */

        subject xenobot : BioHybridXenobotCollector;

        require constraint primaryFunctionSatisfied {
            xenobot.requiredCollectionRate >= 30.0;
            xenobot.collectionRangeRadius >= 10.0;
            xenobot.designLife >= 72.0;
        }
    }

    requirement def BiocompatibleOperationRequirement {
        doc /* The xenobot-based system shall operate without synthetic electronics, batteries, or rigid artificial structures, relying on living tissue mechanics, metabolism, cilia motion, and bioelectric coordination. */

        subject xenobot : BioHybridXenobotCollector;

        require constraint livingTissueOperation {
            xenobot.wetMass <= 25.0;
            xenobot.operatingTemperatureMinimum >= 15.0;
            xenobot.operatingTemperatureMaximum <= 28.0;
        }
    }

    requirement def LocomotionRequirement {
        doc /* The collector shall propel itself through water using coordinated ciliary beating and contractile body-shape biasing. */

        subject shell : CiliatedEpithelialShell;

        require constraint locomotionPerformance {
            shell.nominalCiliaBeatFrequency >= 12.0;
            shell.maximumSustainableBeatFrequency >= 24.0;
            shell.ciliaLength >= 8.0;
        }
    }

    requirement def CaptureRequirement {
        doc /* The payload pocket shall capture suspended particles and retain them long enough to form a consolidated aggregate. */

        subject pocket : AdhesivePayloadPocket;

        require constraint capturePerformance {
            pocket.adhesionReadiness >= 0.70;
            pocket.maximumParticleCapacity >= 100;
            pocket.pocketMouthWidth >= 150.0;
        }
    }

    requirement def EnergyAutonomyRequirement {
        doc /* The metabolic core shall support at least one active mission interval through nutrient conversion and low-energy recovery. */

        subject core : MetabolicCore;

        require constraint energyAutonomy {
            core.storedEnergy >= 10.0;
            core.minimumOperatingEnergy <= 5.0;
            core.nominalMissionDuration >= 4.0;
        }
    }

    requirement def SafeQuiescenceRequirement {
        doc /* The system shall enter a quiescent failsafe state when energy reserve is insufficient for reliable locomotion or collection. */

        subject xenobot : BioHybridXenobotCollector;

        require constraint failsafeCapability {
            xenobot.metabolicCore.minimumOperatingEnergy <= 5.0;
            xenobot.metabolicCore.storedEnergy >= 1.5;
        }
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject xenobot : BioHybridXenobotCollector;
    }

    requirement biocompatibleOperation : BiocompatibleOperationRequirement {
        subject xenobot : BioHybridXenobotCollector;
    }

    requirement locomotion : LocomotionRequirement {
        subject shell : CiliatedEpithelialShell;
    }

    requirement capture : CaptureRequirement {
        subject pocket : AdhesivePayloadPocket;
    }

    requirement energyAutonomy : EnergyAutonomyRequirement {
        subject core : MetabolicCore;
    }

    requirement safeQuiescence : SafeQuiescenceRequirement {
        subject xenobot : BioHybridXenobotCollector;
    }

    satisfy primaryFunction by BioHybridXenobotCollector;
    satisfy biocompatibleOperation by BioHybridXenobotCollector;
    satisfy locomotion by CiliatedEpithelialShell;
    satisfy capture by AdhesivePayloadPocket;
    satisfy energyAutonomy by MetabolicCore;
    satisfy safeQuiescence by XenobotOperationalStateMachine;

}
