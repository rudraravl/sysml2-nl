package HoneywagonSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WasteType;
    attribute def LocationType;
    
    enum def ServiceMode {
        idle;
        collecting;
        transporting;
        discharging;
        waterDispensing;
        cleaning;
    }
    
    item def LiquidWaste {
        attribute wasteType : WasteType;
        attribute volume : VolumeValue;
        attribute contaminationLevel : Real;
    }
    
    item def FreshWater {
        attribute volume : VolumeValue;
        attribute purityLevel : Real;
    }
    
    port def WasteInputPort {
        in item wasteIn : LiquidWaste;
    }
    
    port def WasteOutputPort {
        out item wasteOut : LiquidWaste;
    }
    
    port def WaterOutputPort {
        out item waterOut : FreshWater;
    }
    
    port def PowerInputPort {
        in attribute power : PowerValue;
    }
    
    part def VacuumPumpSystem {
        attribute maxVacuumPressure : PressureValue;
        attribute operatingFlowRate : VolumeFlowRateValue;
        attribute isActive : Boolean;
        
        port suctionPort : WasteInputPort;
        port dischargePort : WasteOutputPort;
        port powerPort : PowerInputPort;
    }
    
    part def WasteStorageTank {
        attribute totalCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute maxOperatingPressure : PressureValue;
        
        port fillPort : WasteInputPort;
        port drainPort : WasteOutputPort;
        
        assert constraint tankCapacityLimit {
            currentLevel <= totalCapacity
        }
    }
    
    part def FreshWaterReservoir {
        attribute totalCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        
        port dispenserPort : WaterOutputPort;
        
        assert constraint waterCapacityLimit {
            currentLevel <= totalCapacity
        }
    }
    
    part def DischargeValveSystem {
        attribute isOpen : Boolean;
        attribute dischargeRate : VolumeFlowRateValue;
        
        port inletPort : WasteInputPort;
        port outletPort : WasteOutputPort;
    }
    
    part def SuctionHoseAssembly {
        attribute hoseLength : LengthValue;
        attribute hoseDiameter : LengthValue;
        attribute isDeployed : Boolean;
        
        port externalPort : WasteInputPort;
        port systemPort : WasteOutputPort;
    }
    
    part def OperatorControlStation {
        attribute operatorPresent : Boolean;
        attribute currentMode : ServiceMode;
        attribute tankLevelDisplay : Real;
    }
    
    part def ChassisAndDrivetrain {
        attribute vehicleMass : MassValue;
        attribute maxPayloadCapacity : MassValue;
        
        port enginePowerOutput : PowerInputPort;
    }
    
    action def DeployHose {
        in targetSite : LocationType;
        out hoseDeployed : Boolean;
    }
    
    action def ActivateVacuumPump {
        in targetPressure : PressureValue;
        out pumpActivated : Boolean;
    }
    
    action def CollectWaste {
        in wasteSource : LiquidWaste;
        in collectionDuration : TimeValue;
        out volumeCollected : VolumeValue;
    }
    
    action def TransportToDisposal {
        in originLocation : LocationType;
        in destinationLocation : LocationType;
        in wastePayload : VolumeValue;
    }
    
    action def DischargeWasteAtFacility {
        in wasteVolume : VolumeValue;
        in facilityLocation : LocationType;
        out dischargeComplete : Boolean;
    }
    
    action def DispenseFreshWater {
        in targetSite : LocationType;
        in waterVolume : VolumeValue;
        out waterDispensed : Boolean;
    }
    
    action def CleanAndSanitize {
        in sanitizingAgent : WasteType;
        out systemSanitized : Boolean;
    }
    
    action def ExecuteServiceCycle {
        in serviceSite : LocationType;
        in estimatedWasteVolume : VolumeValue;
        out serviceCompleted : Boolean;
        
        first start;
        then action deployHose : DeployHose {
            in targetSite = serviceSite;
            out hoseDeployed;
        }
        then action activatePump : ActivateVacuumPump {
            in targetPressure : PressureValue;
            out pumpActivated;
        }
        then action collect : CollectWaste {
            in wasteSource : LiquidWaste;
            in collectionDuration : TimeValue;
            out volumeCollected;
        }
        then action monitorLevel;
        then decide;
            if collect.volumeCollected >= estimatedWasteVolume then finishCollection;
            if collect.volumeCollected < estimatedWasteVolume then continueCollection;
        action continueCollection;
        then collect;
        action finishCollection;
        then assign serviceCompleted := true;
        then done;
    }
    
    part def Honeywagon {
        doc /* A specialized mobile sanitation vehicle designed to collect, transport, and dispose of liquid waste 
                from portable toilets, holding tanks, and temporary sanitation facilities, while also providing 
                fresh water supply services for toilet replenishment. */
        
        attribute vehicleIdentifier : String;
        attribute maximumGrossWeight : MassValue;
        attribute currentLocation : LocationType;
        
        part wasteStorageTank : WasteStorageTank {
            attribute :>> totalCapacity : VolumeValue = 3500.0 [SI::L];
            attribute :>> currentLevel : VolumeValue = 0.0 [SI::L];
            attribute :>> maxOperatingPressure : PressureValue = 55.0 [SI::kPa];
        }
        
        part freshWaterReservoir : FreshWaterReservoir {
            attribute :>> totalCapacity : VolumeValue = 600.0 [SI::L];
            attribute :>> currentLevel : VolumeValue = 600.0 [SI::L];
        }
        
        part vacuumPumpSystem : VacuumPumpSystem {
            attribute :>> maxVacuumPressure : PressureValue = 65.0 [SI::kPa];
            attribute :>> operatingFlowRate : VolumeFlowRateValue = 250.0 [SI::L / SI::min];
            attribute :>> isActive : Boolean = false;
        }
        
        part dischargeValveSystem : DischargeValveSystem {
            attribute :>> isOpen : Boolean = false;
            attribute :>> dischargeRate : VolumeFlowRateValue = 350.0 [SI::L / SI::min];
        }
        
        part suctionHoseAssembly : SuctionHoseAssembly {
            attribute :>> hoseLength : LengthValue = 18.0 [SI::m];
            attribute :>> hoseDiameter : LengthValue = 100.0 [SI::mm];
            attribute :>> isDeployed : Boolean = false;
        }
        
        part operatorControlStation : OperatorControlStation {
            attribute :>> operatorPresent : Boolean = true;
            attribute :>> currentMode : ServiceMode = ServiceMode::idle;
            attribute :>> tankLevelDisplay : Real = 0.0;
        }
        
        part chassisAndDrivetrain : ChassisAndDrivetrain {
            attribute :>> vehicleMass : MassValue = 8000.0 [SI::kg];
            attribute :>> maxPayloadCapacity : MassValue = 5000.0 [SI::kg];
        }
        
        connection hoseToVacuum connect suctionHoseAssembly.systemPort to vacuumPumpSystem.suctionPort;
        connection vacuumToTank connect vacuumPumpSystem.dischargePort to wasteStorageTank.fillPort;
        connection tankToValve connect wasteStorageTank.drainPort to dischargeValveSystem.inletPort;
        connection powerToVacuum connect chassisAndDrivetrain.enginePowerOutput to vacuumPumpSystem.powerPort;
        
        perform action serviceCycle : ExecuteServiceCycle[*] ordered;
        
        exhibit state operationalState {
            entry; then standby;
            
            state standby {
                entry assign operatorControlStation.currentMode := ServiceMode::idle;
            }
            
            state wasteCollection {
                entry assign operatorControlStation.currentMode := ServiceMode::collecting;
                do action collectWaste : CollectWaste;
            }
            
            state transit {
                entry assign operatorControlStation.currentMode := ServiceMode::transporting;
                do action transportWaste : TransportToDisposal;
            }
            
            state wasteDisposal {
                entry assign operatorControlStation.currentMode := ServiceMode::discharging;
                do action dischargeWaste : DischargeWasteAtFacility;
            }
            
            state waterService {
                entry assign operatorControlStation.currentMode := ServiceMode::waterDispensing;
                do action dispenseWater : DispenseFreshWater;
            }
            
            state maintenance {
                entry assign operatorControlStation.currentMode := ServiceMode::cleaning;
                do action sanitize : CleanAndSanitize;
            }
            
            transition standby_to_collection
                first standby
                accept ServiceRequest
                then wasteCollection;
                
            transition collection_to_transit
                first wasteCollection
                if wasteStorageTank.currentLevel >= 0.85 * wasteStorageTank.totalCapacity
                then transit;
                
            transition transit_to_disposal
                first transit
                accept ArrivalAtDisposalFacility
                then wasteDisposal;
                
            transition disposal_to_waterService
                first wasteDisposal
                if dischargeWaste.dischargeComplete
                then waterService;
                
            transition waterService_to_standby
                first waterService
                if dispenseWater.waterDispensed
                then standby;
                
            transition standby_to_maintenance
                first standby
                accept MaintenanceRequired
                then maintenance;
                
            transition maintenance_to_standby
                first maintenance
                if sanitize.systemSanitized
                then standby;
        }
    }
    
    part honeywagonUnit : Honeywagon {
        attribute :>> vehicleIdentifier = "HW-2024-001";
        attribute :>> maximumGrossWeight : MassValue = 13000.0 [SI::kg];
    }
    
    requirement def WasteCollectionRequirement {
        doc /* The honeywagon shall effectively collect liquid waste from portable sanitation facilities 
                using vacuum suction technology. */
        
        subject vehicle : Honeywagon;
        
        require constraint minimumStorageCapacity {
            vehicle.wasteStorageTank.totalCapacity >= 3000.0 [SI::L]
        }
        
        require constraint sufficientVacuumPressure {
            vehicle.vacuumPumpSystem.maxVacuumPressure >= 50.0 [SI::kPa]
        }
        
        require constraint adequateFlowRate {
            vehicle.vacuumPumpSystem.operatingFlowRate >= 200.0 [SI::L / SI::min]
        }
    }
    
    requirement def WasteTransportRequirement {
        doc /* The honeywagon shall safely transport collected waste to authorized disposal facilities 
                without leakage or spillage. */
        
        subject vehicle : Honeywagon;
        
        require constraint tankStructuralIntegrity {
            vehicle.wasteStorageTank.currentLevel <= vehicle.wasteStorageTank.totalCapacity
        }
        
        require constraint vehicleWeightCompliance {
            vehicle.maximumGrossWeight <= 15000.0 [SI::kg]
        }
    }
    
    requirement def WasteDisposalRequirement {
        doc /* The honeywagon shall efficiently discharge collected waste at approved disposal facilities. */
        
        subject vehicle : Honeywagon;
        
        require constraint dischargeFlowCapability {
            vehicle.dischargeValveSystem.dischargeRate >= 300.0 [SI::L / SI::min]
        }
    }
    
    requirement def FreshWaterServiceRequirement {
        doc /* The honeywagon shall provide fresh water for replenishing portable toilet facilities. */
        
        subject vehicle : Honeywagon;
        
        require constraint waterReservoirCapacity {
            vehicle.freshWaterReservoir.totalCapacity >= 500.0 [SI::L]
        }
    }
    
    requirement honeywagonPrimaryMission {
        doc /* The honeywagon system shall collect liquid waste from portable sanitation facilities, 
                safely transport it to disposal sites, discharge it at approved facilities, and provide 
                fresh water supply services to maintain sanitation standards at temporary or remote locations. */
        
        subject honeywagonUnit;
        
        require collectionReq : WasteCollectionRequirement {
            subject vehicle = honeywagonUnit;
        }
        
        require transportReq : WasteTransportRequirement {
            subject vehicle = honeywagonUnit;
        }
        
        require disposalReq : WasteDisposalRequirement {
            subject vehicle = honeywagonUnit;
        }
        
        require waterServiceReq : FreshWaterServiceRequirement {
            subject vehicle = honeywagonUnit;
        }
    }
}
