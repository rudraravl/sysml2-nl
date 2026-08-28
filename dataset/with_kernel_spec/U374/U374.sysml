package ScavengerRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def Distance :> Real;
    attribute def Volume :> Real;
    attribute def BatteryLevel :> Real;
    attribute def Power :> Real;

    attribute def Material;
    attribute def Metal :> Material;
    attribute def Plastic :> Material;
    attribute def Electronics :> Material;
    attribute def Waste :> Material;

    attribute def ScavengedItem {
        attribute material : Material;
        attribute distance : Distance;
    }

    attribute def ProcessedItem {
        attribute material : Material;
        attribute isValuable : Boolean;
    }

    port def DepositPort {
        out cargo : ProcessedItem[0..*];
    }

    port def ChargePort {
        in power : Power;
    }

    action def ScanEnvironment {
        out detectedItem : ScavengedItem;
        out scanDistance : Distance;
    }

    action def NavigateToTarget {
        in targetDistance : Distance;
        out arrivalStatus : Boolean;
    }

    action def GraspItem {
        in targetItem : ScavengedItem;
        out collectedItem : ScavengedItem;
    }

    action def SortMaterial {
        in rawItem : ScavengedItem;
        out valuableResource : ProcessedItem;
        out waste : ProcessedItem;
    }

    action def StoreItem {
        in item : ProcessedItem;
        out currentFill : Volume;
        out isFull : Boolean;
    }

    action def UnloadCargo {
        out cargo : ProcessedItem[0..*];
        out success : Boolean;
    }

    action def RechargeBattery {
        in power : Power;
        out chargeStatus : Boolean;
    }

    action def MonitorBattery {
        out batteryLevel : BatteryLevel;
        out isLow : Boolean;
    }

    action def ScavengerOperation {
        loop action cycle {
            action scan : ScanEnvironment {
                out detectedItem;
                out scanDistance;
            }
            then action navigate : NavigateToTarget {
                in targetDistance = scan.scanDistance;
                out arrivalStatus;
            }
            then action grasp : GraspItem {
                in targetItem = scan.detectedItem;
                out collectedItem;
            }
            then action sort : SortMaterial {
                in rawItem = grasp.collectedItem;
                out valuableResource;
                out waste;
            }
            then action store : StoreItem {
                in item = sort.valuableResource;
                out currentFill;
                out isFull;
            }
        }
    }

    part def SensorModule {
        attribute maxRange : Distance = 100;
        out attribute detectedMaterial : Material;
        out attribute detectedDistance : Distance;
        out attribute detectedItem : ScavengedItem;
        perform action scan : ScanEnvironment {
            out detectedItem;
            out scanDistance;
        }
        bind detectedItem = scan.detectedItem;
        bind detectedDistance = scan.scanDistance;
    }

    part def NavigationSystem {
        in attribute targetDistance : Distance;
        out attribute arrivalStatus : Boolean;
        perform action navigate : NavigateToTarget {
            in targetDistance;
            out arrivalStatus;
        }
    }

    part def MechanicalArm {
        attribute reach : Distance = 3;
        in attribute targetItem : ScavengedItem;
        out attribute collectedItem : ScavengedItem;
        perform action grasp : GraspItem {
            in targetItem;
            out collectedItem;
        }
    }

    part def ProcessingModule {
        in attribute rawMaterial : ScavengedItem;
        out attribute valuableResource : ProcessedItem;
        out attribute waste : ProcessedItem;
        perform action sort : SortMaterial {
            in rawItem = rawMaterial;
            out valuableResource;
            out waste;
        }
    }

    part def StorageCompartment {
        attribute capacity : Volume = 1.5;
        attribute currentVolume : Volume = 0;
        in attribute valuableResource : ProcessedItem;
        out attribute depositedMaterial : ProcessedItem;
        out attribute isFull : Boolean;
        perform action store : StoreItem {
            in item = valuableResource;
            out currentFill;
            out isFull;
        }
        bind currentVolume = store.currentFill;
        bind isFull = store.isFull;
        perform action unload : UnloadCargo {
            out cargo;
            out success;
        }
        bind depositedMaterial = unload.cargo;
    }

    part def PowerManagementSystem {
        attribute batteryLevel : BatteryLevel = 100;
        attribute lowThreshold : BatteryLevel = 20;
        in attribute charge : Power;
        out attribute currentBatteryLevel : BatteryLevel;
        out attribute isLow : Boolean;
        perform action monitor : MonitorBattery {
            out batteryLevel;
            out isLow;
        }
        bind currentBatteryLevel = monitor.batteryLevel;
        bind isLow = monitor.isLow;
        perform action recharge : RechargeBattery {
            in power = charge;
            out chargeStatus;
        }
    }

    part def DepositStation {
        in attribute depositedMaterial : ProcessedItem;
        perform action receive : UnloadCargo {
            out cargo;
            out success;
        }
    }

    part def ChargingStation {
        out attribute charge : Power;
        perform action supply : RechargeBattery {
            in power;
            out chargeStatus;
        }
    }

    part def ScavengerRobot {
        attribute id : String;
        attribute maxScanRange : Distance = 100;
        attribute armReach : Distance = 3;
        attribute storageCapacity : Volume = 1.5;

        part sensor : SensorModule;
        part navigation : NavigationSystem;
        part arm : MechanicalArm;
        part processor : ProcessingModule;
        part storage : StorageCompartment;
        part power : PowerManagementSystem;

        port depositPort : DepositPort;
        port chargePort : ChargePort;

        flow from sensor.detectedDistance to navigation.targetDistance;
        flow from sensor.detectedItem to arm.targetItem;
        flow from arm.collectedItem to processor.rawMaterial;
        flow from processor.valuableResource to storage.valuableResource;
        flow from storage.depositedMaterial to depositPort.cargo;
        flow from chargePort.power to power.charge;

        state robotStates {
            entry; then searching;
            state searching;
            transition search_collect
                first searching
                accept SigTargetFound
                then collecting;
            transition search_charge
                first searching
                accept SigBatteryLow
                then charging;
            state collecting;
            transition collect_process
                first collecting
                accept SigItemCollected
                then processing;
            state processing;
            transition process_transport
                first processing
                accept SigItemProcessed
                then transporting;
            state transporting;
            transition transport_deposit
                first transporting
                accept SigStorageFull
                then depositing;
            transition transport_charge
                first transporting
                accept SigBatteryLow
                then charging;
            state depositing;
            transition deposit_search
                first depositing
                accept SigStorageEmpty
                then searching;
            state charging;
            transition charge_search
                first charging
                accept SigBatteryFull
                then searching;
        }

        attribute def SigTargetFound;
        attribute def SigItemCollected;
        attribute def SigItemProcessed;
        attribute def SigStorageFull;
        attribute def SigStorageEmpty;
        attribute def SigBatteryLow;
        attribute def SigBatteryFull;
    }

    part def ScavengerSystem {
        part robot : ScavengerRobot;
        part depositStation : DepositStation;
        part chargingStation : ChargingStation;

        flow from robot.storage.depositedMaterial to depositStation.depositedMaterial;
        flow from chargingStation.charge to robot.power.charge;
    }

    part scavengerSystem : ScavengerSystem;

    requirement def ScanRangeRequirement {
        doc /* The sensor module shall scan surroundings up to 100 meters to detect and identify materials. */
        attribute requiredRange : Distance = 100;
    }

    requirement def ArmReachRequirement {
        doc /* The mechanical arm shall have a 3-meter reach and sufficient grasping strength. */
        attribute requiredReach : Distance = 3;
    }

    requirement def StorageCapacityRequirement {
        doc /* The internal storage compartment shall have a capacity of 1.5 cubic meters. */
        attribute requiredCapacity : Volume = 1.5;
    }

    requirement def AutonomousOperationRequirement {
        doc /* The system shall operate continuously and make intelligent decisions without direct human supervision. */
    }

    requirement def PowerManagementRequirement {
        doc /* The robot shall automatically navigate to a charging station when battery level drops below threshold. */
    }

    requirement def AutonomousUnloadingRequirement {
        doc /* When storage is full, the robot shall automatically navigate to the deposit station and unload. */
    }

    requirement scanRangeReq : ScanRangeRequirement;
    requirement armReachReq : ArmReachRequirement;
    requirement storageCapReq : StorageCapacityRequirement;
    requirement autoOpReq : AutonomousOperationRequirement;
    requirement powerMgmtReq : PowerManagementRequirement;
    requirement autoUnloadReq : AutonomousUnloadingRequirement;

    satisfy scanRangeReq by scavengerSystem.robot.sensor.maxRange;
    satisfy armReachReq by scavengerSystem.robot.arm.reach;
    satisfy storageCapReq by scavengerSystem.robot.storage.capacity;
    satisfy autoOpReq by scavengerSystem.robot.robotStates;
    satisfy powerMgmtReq by scavengerSystem.robot.robotStates;
    satisfy autoUnloadReq by scavengerSystem.robot.robotStates;
}
