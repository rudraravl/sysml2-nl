package ScavengerSystemModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    attribute def DetectionRange :> LengthValue;
    attribute def StorageCapacity :> VolumeValue;
    attribute def ProcessingEfficiency :> Real;
    attribute def BatteryLevel :> Real;

    enum def MaterialType {
        metal;
        plastic;
        organic;
        electronic;
        hazardous;
    }

    enum def OperationalMode {
        idle;
        searching;
        approaching;
        collecting;
        processing;
        transporting;
        depositing;
        recharging;
    }

    item def ScavengedItem {
        attribute materialType : MaterialType;
        attribute mass : MassValue;
        attribute volume : VolumeValue;
        attribute value : Real;
    }

    port def SensorDataPort {
        out detectedItems : ScavengedItem[*];
        out environmentMap : String;
    }

    port def CollectionPort {
        in targetItem : ScavengedItem;
        out collectionSuccess : Boolean;
    }

    port def ProcessingPort {
        in rawItem : ScavengedItem;
        out processedItem : ScavengedItem;
        out waste : ScavengedItem;
    }

    port def StoragePort {
        in item : ScavengedItem;
        out remainingCapacity : VolumeValue;
        out isFull : Boolean;
    }

    port def PowerPort {
        out currentCharge : BatteryLevel;
        in chargingPower : PowerValue;
    }

    part def SensorModule {
        attribute detectionRange : DetectionRange;
        attribute scanRate : Real;
        port sensorData : SensorDataPort;

        perform action scanEnvironment {
            out detectedTargets : ScavengedItem[*];
            out mapData : String;
        }
    }

    part def NavigationModule {
        attribute currentPosition : LengthValue[3];
        attribute targetPosition : LengthValue[3];
        attribute maxSpeed : SpeedValue;

        perform action navigateToTarget {
            in destination : LengthValue[3];
            out pathPlanned : Boolean;
            out arrived : Boolean;
        }
    }

    part def CollectionArm {
        attribute reachDistance : LengthValue;
        attribute graspStrength : ForceValue;
        port collectionInterface : CollectionPort;

        perform action collectItem {
            in target : ScavengedItem;
            out retrieved : ScavengedItem;
            out success : Boolean;
        }
    }

    part def ProcessingModule {
        attribute processingRate : ProcessingEfficiency;
        attribute sortingAccuracy : Real;
        port processingInterface : ProcessingPort;

        perform action processItem {
            in rawMaterial : ScavengedItem;
            out usableMaterial : ScavengedItem;
            out wasteProduct : ScavengedItem;
        }
    }

    part def StorageCompartment {
        attribute maxCapacity : StorageCapacity;
        attribute currentLoad : VolumeValue;
        attribute itemCount : Natural;
        port storageInterface : StoragePort;

        assert constraint capacityConstraint {
            currentLoad <= maxCapacity
        }
    }

    part def PowerManagementSystem {
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : BatteryLevel;
        attribute consumptionRate : PowerValue;
        port powerInterface : PowerPort;

        assert constraint chargeConstraint {
            currentCharge >= 0.0 and currentCharge <= 100.0
        }

        perform action monitorPower {
            out chargeLevel : BatteryLevel;
            out needsRecharge : Boolean;
        }
    }

    part def DepositStation {
        attribute location : LengthValue[3];
        attribute acceptedTypes : MaterialType[*];

        perform action receiveDeposit {
            in depositedItem : ScavengedItem;
            out accepted : Boolean;
        }
    }

    part def ChargingStation {
        attribute location : LengthValue[3];
        attribute chargingRate : PowerValue;

        perform action chargeScavenger {
            out powerSupplied : PowerValue;
        }
    }

    action def ScanArea {
        in searchRadius : DetectionRange;
        out foundItems : ScavengedItem[*];
    }

    action def MoveToLocation {
        in targetLocation : LengthValue[3];
        out movementComplete : Boolean;
    }

    action def RetrieveItem {
        in targetItem : ScavengedItem;
        out collectedItem : ScavengedItem;
    }

    action def SortAndProcess {
        in rawItem : ScavengedItem;
        out processedItem : ScavengedItem;
        out wasteItem : ScavengedItem;
    }

    action def TransportToDeposit {
        in depositLocation : LengthValue[3];
        out transportComplete : Boolean;
    }

    action def DepositItems {
        in items : ScavengedItem[*];
        out depositSuccess : Boolean;
    }

    action def RechargeAtStation {
        in chargingLocation : LengthValue[3];
        out fullyCharged : Boolean;
    }

    part def ScavengerRobot {
        attribute mode : OperationalMode;
        attribute totalItemsCollected : Natural;
        attribute totalMassCollected : MassValue;
        attribute batteryLevel : BatteryLevel;
        attribute storageRemaining : VolumeValue;

        part sensors : SensorModule {
            attribute :>> detectionRange : DetectionRange = 100.0 [m];
            attribute :>> scanRate = 5.0;
        }

        part navigation : NavigationModule {
            attribute :>> currentPosition : LengthValue[3];
            attribute :>> targetPosition : LengthValue[3];
            attribute :>> maxSpeed : SpeedValue = 2.0 [m/s];
        }

        part arm : CollectionArm {
            attribute :>> reachDistance : LengthValue = 3.0 [m];
            attribute :>> graspStrength : ForceValue = 200.0 [N];
        }

        part processor : ProcessingModule {
            attribute :>> processingRate = 0.90;
            attribute :>> sortingAccuracy = 0.95;
        }

        part storage : StorageCompartment {
            attribute :>> maxCapacity : StorageCapacity = 1.5 [m^3];
            attribute :>> currentLoad : VolumeValue = 0.0 [m^3];
            attribute :>> itemCount = 0;
        }

        part powerSystem : PowerManagementSystem {
            attribute :>> batteryCapacity : EnergyValue = 5000.0 [Wh];
            attribute :>> currentCharge = 100.0;
            attribute :>> consumptionRate : PowerValue = 300.0 [W];
        }

        connection sensorToArm connect sensors.sensorData to arm.collectionInterface;
        connection armToProcessor connect arm.collectionInterface to processor.processingInterface;
        connection processorToStorage connect processor.processingInterface to storage.storageInterface;

        perform action scavengingOperation {
            first start;
            then merge continueOperation;

            then action scanForItems : ScanArea {
                in searchRadius = sensors.detectionRange;
                out foundItems : ScavengedItem[*];
            }

            then decide;
                if scanForItems.foundItems->size() > 0 and 
                   storage.currentLoad < storage.maxCapacity and
                   powerSystem.currentCharge > 20.0 then proceedToCollection;
                if storage.currentLoad >= storage.maxCapacity then deliverItems;
                if powerSystem.currentCharge <= 20.0 then rechargeRobot;

            action proceedToCollection : MoveToLocation {
                in targetLocation = navigation.targetPosition;
                out movementComplete : Boolean;
            }
            then action collectTarget : RetrieveItem;
            then action processTarget : SortAndProcess {
                in rawItem = collectTarget.collectedItem;
            }
            then continueOperation;

            action deliverItems : TransportToDeposit;
            then action depositAtStation : DepositItems;
            then continueOperation;

            action rechargeRobot : RechargeAtStation;
            then continueOperation;
        }
    }

    requirement <'REQ-SCAV-100'> autonomousScavenging {
        doc /* The scavenger system shall autonomously search for, identify, 
             * collect, and process valuable materials from the environment 
             * without continuous human supervision.
             */
        subject robot : ScavengerRobot;
    }

    requirement <'REQ-SCAV-101'> detectionCapability {
        doc /* The system shall detect target items within a minimum 
             * range of 100 meters using onboard sensors.
             */
        subject robot : ScavengerRobot;
        assert constraint {
            robot.sensors.detectionRange >= 100.0 [m]
        }
    }

    requirement <'REQ-SCAV-102'> storageRequirement {
        doc /* The system shall provide storage capacity of at least 
             * 1.5 cubic meters for collected materials.
             */
        subject robot : ScavengerRobot;
        assert constraint {
            robot.storage.maxCapacity >= 1.5 [m^3]
        }
    }

    requirement <'REQ-SCAV-103'> processingAccuracy {
        doc /* The processing module shall sort and classify materials 
             * with a minimum accuracy of 90%.
             */
        subject robot : ScavengerRobot;
        assert constraint {
            robot.processor.sortingAccuracy >= 0.90
        }
    }

    requirement <'REQ-SCAV-104'> operationalEndurance {
        doc /* The system shall operate continuously for at least 
             * 10 hours on a full battery charge under normal conditions.
             */
        subject robot : ScavengerRobot;
        assert constraint {
            robot.powerSystem.batteryCapacity >= 5000.0 [Wh]
        }
    }

    requirement <'REQ-SCAV-105'> collectionEfficiency {
        doc /* The collection arm shall successfully retrieve items 
             * within its reach distance with a minimum success rate of 85%.
             */
        subject robot : ScavengerRobot;
        assert constraint {
            robot.arm.reachDistance >= 3.0 [m]
        }
    }

    part scavengerDeployment {
        part robot : ScavengerRobot {
            attribute :>> mode = OperationalMode::idle;
            attribute :>> totalItemsCollected = 0;
            attribute :>> totalMassCollected : MassValue = 0.0 [kg];
            attribute :>> batteryLevel = 100.0;
            attribute :>> storageRemaining : VolumeValue = 1.5 [m^3];
        }

        part depositStation : DepositStation {
            attribute :>> location : LengthValue[3];
            attribute :>> acceptedTypes = (
                MaterialType::metal,
                MaterialType::plastic,
                MaterialType::electronic
            );
        }

        part chargingStation : ChargingStation {
            attribute :>> location : LengthValue[3];
            attribute :>> chargingRate : PowerValue = 1000.0 [W];
        }

        connection powerLink connect 
            robot.powerSystem.powerInterface to chargingStation;
    }

    satisfy autonomousScavenging by scavengerDeployment.robot;
    satisfy detectionCapability by scavengerDeployment.robot;
    satisfy storageRequirement by scavengerDeployment.robot;
    satisfy processingAccuracy by scavengerDeployment.robot;
    satisfy operationalEndurance by scavengerDeployment.robot;
    satisfy collectionEfficiency by scavengerDeployment.robot;
}
