package HarvestAutomationSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def CurrencyPerHour :> Real {
        unit = "USD/h";
    }

    attribute def AreaRate :> Real {
        unit = "ha/h";
    }

    attribute def MassRate :> Real {
        unit = "kg/s";
    }

    attribute def CropDensity :> Real {
        unit = "kg/m^2";
    }

    attribute def Confidence :> Real {
        unit = "1";
    }

    attribute def EnergyLevel :> Real {
        unit = "%";
    }

    attribute def Speed :> Real {
        unit = "m/s";
    }

    attribute def Distance :> Real {
        unit = "m";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    enum def CropType {
        apple;
        strawberry;
        tomato;
        lettuce;
        grape;
        grain;
    }

    enum def HarvestMode {
        survey;
        selectivePick;
        bulkHarvest;
        transport;
        returnToBase;
        standby;
    }

    enum def CropMaturity {
        immature;
        ready;
        overripe;
        damaged;
    }

    enum def BinFillState {
        empty;
        partial;
        full;
    }

    item def CropCluster {
        attribute cropType : CropType;
        attribute maturity : CropMaturity;
        attribute estimatedMass : Mass;
        attribute qualityScore : Percent;
        attribute locationX : Distance;
        attribute locationY : Distance;
    }

    item def HarvestedCropBatch {
        attribute cropType : CropType;
        attribute batchMass : Mass;
        attribute averageQuality : Percent;
        attribute damageRate : Percent;
        attribute timestamp : TimeDuration;
    }

    item def FieldMap {
        attribute mappedArea : Area;
        attribute cropDensityEstimate : CropDensity;
        attribute obstacleCount : Integer;
        attribute readyCropEstimate : Mass;
    }

    item def NavigationCommand {
        attribute targetX : Distance;
        attribute targetY : Distance;
        attribute targetSpeed : Speed;
        attribute routeConfidence : Confidence;
    }

    item def PickCommand {
        attribute cropX : Distance;
        attribute cropY : Distance;
        attribute gripForce : Force;
        attribute cutDepth : Distance;
        attribute targetMaturity : CropMaturity;
    }

    item def PowerStatus {
        attribute batteryCharge : EnergyLevel;
        attribute availableRuntime : TimeDuration;
        attribute chargingRequired : Boolean;
    }

    item def SystemAlert {
        attribute alertCode : Integer;
        attribute severity : Integer;
        attribute messageId : Integer;
        attribute requiresHumanIntervention : Boolean;
    }

    port def CropIntakePort {
        in item crop : CropCluster;
        out item harvestedBatch : HarvestedCropBatch;
    }

    port def CropDischargePort {
        out item harvestedBatch : HarvestedCropBatch;
    }

    port def PerceptionDataPort {
        out item detectedCrop : CropCluster;
        out item fieldMap : FieldMap;
    }

    port def NavigationPort {
        in item command : NavigationCommand;
        out item pose : FieldMap;
    }

    port def ManipulationPort {
        in item pickCommand : PickCommand;
        out item harvestedBatch : HarvestedCropBatch;
    }

    port def PowerPort {
        out item status : PowerStatus;
    }

    port def AlertPort {
        out item alert : SystemAlert;
    }

    port def OperatorInterfacePort {
        in item modeCommand : HarvestMode;
        out item status : SystemAlert;
        out item productionReport : HarvestedCropBatch;
    }

    action def SurveyField {
        in attribute fieldBoundaryArea : Area;
        out item fieldMap : FieldMap;
        attribute surveySpeed : Speed = 1.2 [m/s];
    }

    action def DetectReadyCrop {
        in item fieldMap : FieldMap;
        out item cropTarget : CropCluster;
        attribute minimumQualityScore : Percent = 85 [%];
        attribute detectionConfidence : Confidence;
    }

    action def NavigateToCrop {
        in item target : CropCluster;
        out item navigationCommand : NavigationCommand;
        attribute maximumSpeed : Speed = 1.5 [m/s];
        attribute minimumObstacleClearance : Distance = 0.4 [m];
    }

    action def PickCrop {
        in item target : CropCluster;
        out item cropBatch : HarvestedCropBatch;
        attribute maximumBruiseRate : Percent = 3 [%];
        attribute nominalGripForce : Force = 12 [N];
    }

    action def TransferCropToBin {
        in item cropBatch : HarvestedCropBatch;
        out item storedBatch : HarvestedCropBatch;
        attribute maximumDropHeight : Distance = 0.08 [m];
    }

    action def ReturnToDock {
        in item status : PowerStatus;
        out item alert : SystemAlert;
        attribute dockingTolerance : Distance = 0.05 [m];
    }

    part def VisionSystem {
        port perception : PerceptionDataPort;

        attribute frameRate : Frequency = 30 [Hz];
        attribute cropClassificationAccuracy : Percent = 96 [%];
        attribute maturityDetectionAccuracy : Percent = 93 [%];
        attribute depthRange : Distance = 8 [m];

        action detectCrop : DetectReadyCrop;
    }

    part def FieldMapper {
        port perception : PerceptionDataPort;

        attribute mapResolution : Distance = 0.05 [m];
        attribute maximumMappedArea : Area = 20 [ha];
        attribute localizationError : Distance = 0.03 [m];

        action survey : SurveyField;
    }

    part def AutonomousNavigation {
        port navigation : NavigationPort;
        port alert : AlertPort;

        attribute nominalSpeed : Speed = 1.0 [m/s];
        attribute maximumSpeed : Speed = 2.0 [m/s];
        attribute minimumObstacleClearance : Distance = 0.35 [m];
        attribute slopeLimit : PlaneAngle = 12 [deg];

        action navigate : NavigateToCrop;
    }

    part def RoboticHarvesterArm {
        port manipulation : ManipulationPort;
        port cropIntake : CropIntakePort;

        attribute reachRadius : Distance = 1.1 [m];
        attribute positioningAccuracy : Distance = 0.01 [m];
        attribute pickingCycleTime : TimeDuration = 4.0 [s];
        attribute maximumGripForce : Force = 30 [N];

        action pick : PickCrop;
    }

    part def EndEffector {
        port manipulation : ManipulationPort;

        attribute cutterBladeSpeed : Speed = 0.25 [m/s];
        attribute softGripCompliance : Real = 0.72;
        attribute minimumStemDiameter : Distance = 0.002 [m];
        attribute maximumStemDiameter : Distance = 0.018 [m];
    }

    part def CropStorageBin {
        port intake : CropIntakePort;
        port discharge : CropDischargePort;

        attribute capacity : Mass = 120 [kg];
        attribute currentLoad : Mass;
        attribute fillState : BinFillState;
        attribute temperature : Temperature = 8 [degC];
        attribute ventilationFlowRate : MassRate = 0.08 [kg/s];
    }

    part def PowerSubsystem {
        port power : PowerPort;
        port alert : AlertPort;

        attribute batteryCapacity : Energy = 18 [kW*h];
        attribute stateOfCharge : EnergyLevel;
        attribute minimumOperatingCharge : EnergyLevel = 20 [%];
        attribute chargingPower : Power = 6 [kW];
        attribute averageHarvestPowerDraw : Power = 3.2 [kW];
    }

    part def OperatorConsole {
        port operatorInterface : OperatorInterfacePort;

        attribute selectedMode : HarvestMode;
        attribute emergencyStopActive : Boolean = false;
        attribute targetCropType : CropType;
        attribute commandedHarvestArea : Area;
    }

    part def FleetCoordinator {
        port operatorInterface : OperatorInterfacePort;
        port alert : AlertPort;

        attribute activeRobotCount : Integer;
        attribute plannedThroughput : AreaRate = 1.5 [ha/h];
        attribute laborReplacementFactor : Real = 4.0;
    }

    part def HarvestAutomationSystem {
        doc /* Primary function: autonomously survey a cultivated field, identify mature crops, navigate to harvestable targets, remove crops with minimal damage, collect them into storage, and report harvest progress while maintaining safe operation. */

        port cropInput : CropIntakePort;
        port cropOutput : CropDischargePort;
        port operator : OperatorInterfacePort;
        port alert : AlertPort;

        part vision : VisionSystem;
        part mapper : FieldMapper;
        part navigation : AutonomousNavigation;
        part arm : RoboticHarvesterArm;
        part endEffector : EndEffector;
        part bin : CropStorageBin;
        part power : PowerSubsystem;
        part console : OperatorConsole;
        part coordinator : FleetCoordinator;

        attribute operatingMode : HarvestMode = HarvestMode::standby;
        attribute targetThroughput : AreaRate = 0.75 [ha/h];
        attribute requiredCropDamageRate : Percent = 5 [%];
        attribute minimumCropQualityAccepted : Percent = 85 [%];
        attribute harvestYieldTarget : Mass = 3000 [kg];
        attribute maximumUnattendedRuntime : TimeDuration = 28800 [s];

        connect mapper.perception to vision.perception;
        connect vision.perception to navigation.navigation;
        connect navigation.navigation to arm.manipulation;
        connect arm.manipulation to endEffector.manipulation;
        connect arm.cropIntake to bin.intake;
        connect bin.discharge to cropOutput;
        connect power.power to navigation.navigation;
        connect power.alert to alert;
        connect navigation.alert to alert;
        connect coordinator.alert to alert;
        connect console.operatorInterface to operator;
        connect coordinator.operatorInterface to operator;

        action performAutonomousHarvest {
            in attribute fieldArea : Area;
            in attribute cropType : CropType;
            out item harvestedBatch : HarvestedCropBatch;

            first start;
            then surveyField;

            action surveyField : SurveyField {
                in fieldBoundaryArea = fieldArea;
                out fieldMap;
            }

            then identifyCrop;

            action identifyCrop : DetectReadyCrop {
                in fieldMap = surveyField.fieldMap;
                out cropTarget;
            }

            then moveToCrop;

            action moveToCrop : NavigateToCrop {
                in target = identifyCrop.cropTarget;
                out navigationCommand;
            }

            then removeCrop;

            action removeCrop : PickCrop {
                in target = identifyCrop.cropTarget;
                out cropBatch;
            }

            then storeCrop;

            action storeCrop : TransferCropToBin {
                in cropBatch = removeCrop.cropBatch;
                out storedBatch;
            }

            then done;

            bind harvestedBatch = storeCrop.storedBatch;
        }

        state def HarvestController {
            state initial;
            state standby;
            state surveying;
            state selectingTarget;
            state navigating;
            state harvesting;
            state storing;
            state binFull;
            state lowPowerReturn;
            state fault;
            state complete;

            transition initial then standby;

            transition standby then surveying
                accept HarvestMode::survey;

            transition standby then selectingTarget
                accept HarvestMode::selectivePick;

            transition surveying then selectingTarget
                if mapper.survey.fieldMap.readyCropEstimate > 0 [kg];

            transition selectingTarget then navigating
                if vision.detect.detectionConfidence >= 0.90;

            transition selectingTarget then complete
                if mapper.survey.fieldMap.readyCropEstimate <= 0 [kg];

            transition navigating then harvesting
                if navigation.localizationError <= 0.05 [m];

            transition harvesting then storing
                if arm.pick.cropBatch.batchMass > 0 [kg];

            transition storing then selectingTarget
                if bin.currentLoad < bin.capacity and power.stateOfCharge > power.minimumOperatingCharge;

            transition storing then binFull
                if bin.currentLoad >= bin.capacity;

            transition binFull then standby
                accept HarvestMode::transport;

            transition storing then lowPowerReturn
                if power.stateOfCharge <= power.minimumOperatingCharge;

            transition lowPowerReturn then standby
                accept HarvestMode::standby;

            transition surveying then fault
                if mapper.localizationError > 0.25 [m];

            transition navigating then fault
                if navigation.minimumObstacleClearance < 0.1 [m];

            transition harvesting then fault
                if arm.maximumGripForce > 30 [N];

            transition fault then standby
                accept HarvestMode::standby;
        }

        state controller : HarvestController;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : HarvestAutomationSystem;

        doc /* The harvest automation system shall perform the primary function of autonomous crop harvesting by surveying the field, detecting mature crops, navigating safely, picking crops with controlled force, storing harvested batches, and reporting status to the operator. */

        require constraint {
            system.targetThroughput >= 0.5 [ha/h]
        }

        require constraint {
            system.requiredCropDamageRate <= 5 [%]
        }

        require constraint {
            system.minimumCropQualityAccepted >= 80 [%]
        }
    }

    requirement def SafeNavigationRequirement {
        subject navigation : AutonomousNavigation;

        doc /* The navigation subsystem shall maintain obstacle clearance during autonomous movement through crop rows. */

        require constraint {
            navigation.minimumObstacleClearance >= 0.35 [m]
        }

        require constraint {
            navigation.maximumSpeed <= 2.0 [m/s]
        }
    }

    requirement def CropHandlingRequirement {
        subject arm : RoboticHarvesterArm;
        subject bin : CropStorageBin;

        doc /* The crop handling components shall pick and store crops while limiting mechanical damage and preserving quality. */

        require constraint {
            arm.positioningAccuracy <= 0.015 [m]
        }

        require constraint {
            arm.pickingCycleTime <= 5.0 [s]
        }

        require constraint {
            bin.capacity >= 100 [kg]
        }
    }

    requirement def EnergyAutonomyRequirement {
        subject power : PowerSubsystem;
        subject system : HarvestAutomationSystem;

        doc /* The power subsystem shall support unattended harvesting and initiate return-to-dock behavior before the battery reaches a depleted state. */

        require constraint {
            power.batteryCapacity >= 15 [kW*h]
        }

        require constraint {
            power.minimumOperatingCharge >= 15 [%]
        }

        require constraint {
            system.maximumUnattendedRuntime >= 21600 [s]
        }
    }

    requirement def PerceptionRequirement {
        subject vision : VisionSystem;

        doc /* The perception system shall classify crop maturity accurately enough to support selective harvesting. */

        require constraint {
            vision.cropClassificationAccuracy >= 95 [%]
        }

        require constraint {
            vision.maturityDetectionAccuracy >= 90 [%]
        }

        require constraint {
            vision.depthRange >= 5 [m]
        }
    }

    satisfy PrimaryFunctionRequirement by HarvestAutomationSystem;
    satisfy SafeNavigationRequirement by AutonomousNavigation;
    satisfy CropHandlingRequirement by RoboticHarvesterArm;
    satisfy CropHandlingRequirement by CropStorageBin;
    satisfy EnergyAutonomyRequirement by PowerSubsystem;
    satisfy PerceptionRequirement by VisionSystem;
}