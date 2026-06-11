package BootBasedSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> Real {
        unit = "mm";
    }

    attribute def MassValue :> Real {
        unit = "kg";
    }

    attribute def ForceValue :> Real {
        unit = "N";
    }

    attribute def PressureValue :> Real {
        unit = "kPa";
    }

    attribute def TemperatureValue :> Real {
        unit = "degC";
    }

    attribute def FrictionCoefficientValue :> Real;
    attribute def MoistureRateValue :> Real {
        unit = "g_per_hour";
    }

    attribute def EnergyValue :> Real {
        unit = "J";
    }

    enum def BootUseMode {
        enum idle;
        enum donning;
        enum walking;
        enum climbing;
        enum wetExposure;
        enum doffing;
        enum maintenance;
    }

    item def FootLoad {
        attribute verticalForce : ForceValue;
        attribute shearForce : ForceValue;
        attribute contactPressure : PressureValue;
    }

    item def GroundReaction {
        attribute normalForce : ForceValue;
        attribute tractionForce : ForceValue;
        attribute frictionCoefficient : FrictionCoefficientValue;
    }

    item def Moisture {
        attribute ingressRate : MoistureRateValue;
        attribute retainedMass : MassValue;
    }

    item def ThermalCondition {
        attribute externalTemperature : TemperatureValue;
        attribute internalTemperature : TemperatureValue;
    }

    item def UserCommand {
        attribute requestedMode : BootUseMode;
    }

    item def FitStatus {
        attribute closureTension : ForceValue;
        attribute heelSlip : LengthValue;
        attribute toeClearance : LengthValue;
    }

    port def FootInterfacePort {
        in item load : FootLoad;
        out item fit : FitStatus;
        out item thermal : ThermalCondition;
    }

    port def GroundInterfacePort {
        out item reaction : GroundReaction;
        in item load : FootLoad;
    }

    port def EnvironmentPort {
        in item moisture : Moisture;
        in item thermal : ThermalCondition;
    }

    port def UserControlPort {
        in item command : UserCommand;
        out item fit : FitStatus;
    }

    part def Boot {
        attribute size : LengthValue = 285.0;
        attribute mass : MassValue = 1.35;
        attribute shaftHeight : LengthValue = 210.0;
        attribute soleThickness : LengthValue = 28.0;
        attribute waterproofResistance : PressureValue = 30.0;
        attribute ratedVerticalLoad : ForceValue = 1800.0;
        attribute minimumTractionCoefficient : FrictionCoefficientValue = 0.62;

        port footPort : FootInterfacePort;
        port groundPort : GroundInterfacePort;
        port environmentPort : EnvironmentPort;
        port userPort : UserControlPort;

        part upper {
            attribute materialName : String = "full grain leather and abrasion textile";
            attribute flexAllowance : LengthValue = 18.0;
            attribute punctureResistance : ForceValue = 950.0;
        }

        part sole {
            attribute materialName : String = "dual density rubber polyurethane";
            attribute treadDepth : LengthValue = 6.5;
            attribute heelEnergyAbsorption : EnergyValue = 32.0;
            attribute abrasionLoss : MassValue = 0.004;
        }

        part insole {
            attribute archSupportHeight : LengthValue = 18.0;
            attribute compressiveSet : LengthValue = 1.2;
            attribute removable : Boolean = true;
        }

        part toeProtection {
            attribute capMaterial : String = "composite safety toe";
            attribute impactEnergyRating : EnergyValue = 200.0;
            attribute compressionRating : ForceValue = 15000.0;
        }

        part closureSystem {
            attribute laceLength : LengthValue = 1450.0;
            attribute maximumClosureTension : ForceValue = 180.0;
            attribute numberOfEyelets : Integer = 8;
        }

        part waterproofMembrane {
            attribute vaporTransmission : MoistureRateValue = 12.0;
            attribute seamLeakThreshold : PressureValue = 25.0;
        }

        part ankleSupport {
            attribute lateralStiffness : ForceValue = 420.0;
            attribute collarPaddingThickness : LengthValue = 14.0;
        }

        connection footLoadTransfer connect footPort.load to groundPort.load;
        connection groundReactionTransfer connect groundPort.reaction to footPort.load;
        connection environmentalExposure connect environmentPort.moisture to waterproofMembrane;
        connection userAdjustment connect userPort.command to closureSystem;

        action def DistributeLoad {
            in item appliedLoad : FootLoad;
            out item distributedLoad : FootLoad;

            first start;
            then evaluateHeelAndForefootPressure;
            then reducePeakContactPressure;
            then provideDistributedLoad;
            then done;

            action evaluateHeelAndForefootPressure;
            action reducePeakContactPressure;
            action provideDistributedLoad;
        }

        action def ProvideTraction {
            in item appliedLoad : FootLoad;
            out item groundReaction : GroundReaction;

            first start;
            then deformTreadBlocks;
            then generateFriction;
            then evacuateLooseMaterial;
            then publishGroundReaction;
            then done;

            action deformTreadBlocks;
            action generateFriction;
            action evacuateLooseMaterial;
            action publishGroundReaction;
        }

        action def MaintainFit {
            in item command : UserCommand;
            out item status : FitStatus;

            first start;
            then tensionClosure;
            then stabilizeHeel;
            then verifyToeClearance;
            then reportFitStatus;
            then done;

            action tensionClosure;
            action stabilizeHeel;
            action verifyToeClearance;
            action reportFitStatus;
        }

        action def ResistEnvironment {
            in item externalMoisture : Moisture;
            in item externalThermal : ThermalCondition;
            out item internalThermal : ThermalCondition;

            first start;
            then blockLiquidIngress;
            then passWaterVapor;
            then reduceConductiveHeatLoss;
            then provideInternalCondition;
            then done;

            action blockLiquidIngress;
            action passWaterVapor;
            action reduceConductiveHeatLoss;
            action provideInternalCondition;
        }

        state def BootOperationalState {
            state unlaced;
            state fitted;
            state loadedWalking;
            state loadedClimbing;
            state wetProtection;
            state removed;
            state drying;

            entry action initializeFitStatus;

            transition first unlaced;
            transition unlaced_to_fitted
                first unlaced
                accept UserCommand
                if command.requestedMode == BootUseMode::donning
                then fitted;

            transition fitted_to_walking
                first fitted
                accept FootLoad
                if load.verticalForce > 50.0
                then loadedWalking;

            transition walking_to_climbing
                first loadedWalking
                accept UserCommand
                if command.requestedMode == BootUseMode::climbing
                then loadedClimbing;

            transition walking_to_wet
                first loadedWalking
                accept Moisture
                if moisture.ingressRate > 0.0
                then wetProtection;

            transition climbing_to_wet
                first loadedClimbing
                accept Moisture
                if moisture.ingressRate > 0.0
                then wetProtection;

            transition wet_to_walking
                first wetProtection
                accept Moisture
                if moisture.ingressRate == 0.0
                then loadedWalking;

            transition fitted_to_removed
                first fitted
                accept UserCommand
                if command.requestedMode == BootUseMode::doffing
                then removed;

            transition removed_to_drying
                first removed
                accept UserCommand
                if command.requestedMode == BootUseMode::maintenance
                then drying;

            transition drying_to_unlaced
                first drying
                accept UserCommand
                if command.requestedMode == BootUseMode::idle
                then unlaced;
        }

        perform action distributeLoad : DistributeLoad;
        perform action provideTraction : ProvideTraction;
        perform action maintainFit : MaintainFit;
        perform action resistEnvironment : ResistEnvironment;
        exhibit state bootState : BootOperationalState;
    }

    part def BootBasedPersonalSupportSystem {
        doc /* Primary function: provide a wearable interface between a human foot and the operating surface that supports body load, protects the foot, maintains fit, provides traction, and reduces environmental exposure during movement. */

        port userControl : UserControlPort;
        port footInterface : FootInterfacePort;
        port groundInterface : GroundInterfacePort;
        port environmentInterface : EnvironmentPort;

        part leftBoot : Boot {
            attribute size = 285.0;
        }

        part rightBoot : Boot {
            attribute size = 285.0;
        }

        connection leftFootInterface connect footInterface to leftBoot.footPort;
        connection rightFootInterface connect footInterface to rightBoot.footPort;
        connection leftGroundInterface connect groundInterface to leftBoot.groundPort;
        connection rightGroundInterface connect groundInterface to rightBoot.groundPort;
        connection leftEnvironmentInterface connect environmentInterface to leftBoot.environmentPort;
        connection rightEnvironmentInterface connect environmentInterface to rightBoot.environmentPort;
        connection leftUserControl connect userControl to leftBoot.userPort;
        connection rightUserControl connect userControl to rightBoot.userPort;

        action def SupportProtectedMobility {
            in item userCommand : UserCommand;
            in item userFootLoad : FootLoad;
            in item environmentMoisture : Moisture;
            in item environmentThermal : ThermalCondition;
            out item leftGroundReaction : GroundReaction;
            out item rightGroundReaction : GroundReaction;
            out item leftFit : FitStatus;
            out item rightFit : FitStatus;

            first start;
            then acceptUserFitCommand;
            then secureBothBoots;
            then receiveFootLoads;
            then distributeLoadsThroughSoles;
            then generateGroundTraction;
            then isolateFootFromMoistureAndTemperature;
            then reportSupportStatus;
            then done;

            action acceptUserFitCommand;
            action secureBothBoots;
            action receiveFootLoads;
            action distributeLoadsThroughSoles;
            action generateGroundTraction;
            action isolateFootFromMoistureAndTemperature;
            action reportSupportStatus;
        }

        perform action primaryFunction : SupportProtectedMobility;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : BootBasedPersonalSupportSystem;

        doc /* The system shall provide protected personal mobility by using paired boots to transfer user foot loads to the ground, maintain foot fit, protect against impact and compression, provide traction, and limit moisture and thermal exposure. */

        require constraint {
            system.leftBoot.ratedVerticalLoad >= 1800.0 and
            system.rightBoot.ratedVerticalLoad >= 1800.0 and
            system.leftBoot.minimumTractionCoefficient >= 0.62 and
            system.rightBoot.minimumTractionCoefficient >= 0.62
        }
    }

    requirement def FitRequirement {
        subject boot : Boot;

        doc /* Each boot shall maintain ergonomic fit during use with controlled closure tension, limited heel slip, and adequate toe clearance. */

        require constraint {
            boot.closureSystem.maximumClosureTension >= 120.0 and
            boot.insole.archSupportHeight >= 10.0 and
            boot.insole.archSupportHeight <= 25.0
        }
    }

    requirement def ProtectionRequirement {
        subject boot : Boot;

        doc /* Each boot shall protect the foot from common mechanical hazards including sole puncture, toe impact, toe compression, and heel shock. */

        require constraint {
            boot.upper.punctureResistance >= 900.0 and
            boot.toeProtection.impactEnergyRating >= 200.0 and
            boot.toeProtection.compressionRating >= 15000.0 and
            boot.sole.heelEnergyAbsorption >= 30.0
        }
    }

    requirement def EnvironmentalResistanceRequirement {
        subject boot : Boot;

        doc /* Each boot shall reduce liquid water ingress while allowing moisture vapor transmission to support comfort during extended use. */

        require constraint {
            boot.waterproofResistance >= 25.0 and
            boot.waterproofMembrane.seamLeakThreshold >= 25.0 and
            boot.waterproofMembrane.vaporTransmission >= 10.0
        }
    }

    requirement def TractionRequirement {
        subject boot : Boot;

        doc /* Each boot shall provide stable traction on representative walking and climbing surfaces. */

        require constraint {
            boot.sole.treadDepth >= 5.0 and
            boot.minimumTractionCoefficient >= 0.62
        }
    }

    part systemOfInterest : BootBasedPersonalSupportSystem;

    satisfy PrimaryFunctionRequirement by systemOfInterest;
    satisfy FitRequirement by systemOfInterest.leftBoot;
    satisfy FitRequirement by systemOfInterest.rightBoot;
    satisfy ProtectionRequirement by systemOfInterest.leftBoot;
    satisfy ProtectionRequirement by systemOfInterest.rightBoot;
    satisfy EnvironmentalResistanceRequirement by systemOfInterest.leftBoot;
    satisfy EnvironmentalResistanceRequirement by systemOfInterest.rightBoot;
    satisfy TractionRequirement by systemOfInterest.leftBoot;
    satisfy TractionRequirement by systemOfInterest.rightBoot;
}