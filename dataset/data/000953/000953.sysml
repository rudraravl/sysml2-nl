package VillageLevelOperationAndMaintenance {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ServiceStatus {
        attribute operational : Boolean;
    }
    
    attribute def MaintenanceLevel {
        attribute level : String;
    }
    
    attribute def AlertSeverity {
        attribute severity : String;
    }
    
    value def VolumeValue :> ISQ::volume {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeUnit;
    }
    
    value def VolumeFlowValue :> ISQ::volumeFlowRate {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeFlowRateUnit;
    }
    
    value def PowerValue :> ISQ::power {
        attribute :>> num : Real;
        attribute :>> mRef : PowerUnit;
    }
    
    value def EnergyValue :> ISQ::energy {
        attribute :>> num : Real;
        attribute :>> mRef : EnergyUnit;
    }
    
    value def LengthValue :> ISQ::length {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }
    
    item def PotableWater {
        attribute flowRate : VolumeFlowValue;
        attribute quality : Real;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
    }
    
    item def MaintenanceAlert {
        attribute severity : AlertSeverity;
        attribute component : String;
        attribute description : String;
    }
    
    port def WaterSupplyPort {
        out item water : PotableWater;
    }
    
    port def WaterIntakePort {
        in item water : PotableWater;
    }
    
    port def PowerSupplyPort {
        out item power : ElectricalPower;
    }
    
    port def PowerIntakePort {
        in item power : ElectricalPower;
    }
    
    port def AlertPort {
        out item alert : MaintenanceAlert;
    }
    
    part def WaterSupplySystem {
        attribute totalCapacity : VolumeValue;
        attribute currentOutput : VolumeFlowValue;
        attribute operationalStatus : ServiceStatus;
        
        port waterOutput : WaterSupplyPort;
        port alertOutput : AlertPort;
        
        part well {
            attribute depth : LengthValue;
            attribute waterLevel : LengthValue;
            attribute rechargeRate : VolumeFlowValue;
        }
        
        part handPump {
            attribute pumpCapacity : VolumeFlowValue;
            attribute wearLevel : Real;
            attribute lastMaintenance : String;
        }
        
        part storageTank {
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
            attribute fillLevel : Real;
        }
    }
    
    part def PowerGenerationSystem {
        attribute generationCapacity : PowerValue;
        attribute currentOutput : PowerValue;
        attribute fuelLevel : Real;
        attribute operationalStatus : ServiceStatus;
        
        port powerOutput : PowerSupplyPort;
        port alertOutput : AlertPort;
        
        part solarPanels {
            attribute panelCount : Integer;
            attribute totalCapacity : PowerValue;
            attribute efficiency : Real;
        }
        
        part batteryBank {
            attribute capacity : EnergyValue;
            attribute chargeLevel : Real;
            attribute cycleCount : Integer;
        }
        
        part dieselGenerator {
            attribute ratedPower : PowerValue;
            attribute fuelCapacity : VolumeValue;
            attribute runningHours : Real;
        }
    }
    
    part def HealthClinic {
        attribute patientCapacity : Integer;
        attribute dailyPatients : Integer;
        attribute operatingHours : Real;
        
        port waterIntake : WaterIntakePort;
        port powerIntake : PowerIntakePort;
        
        part medicalEquipment {
            attribute powerRequirement : PowerValue;
            attribute operationalStatus : ServiceStatus;
        }
        
        part sanitationFacilities {
            attribute waterRequirement : VolumeFlowValue;
        }
    }
    
    part def CommunityCenter {
        attribute capacity : Integer;
        attribute dailyUsers : Integer;
        
        port waterIntake : WaterIntakePort;
        port powerIntake : PowerIntakePort;
        
        part lighting {
            attribute powerConsumption : PowerValue;
        }
        
        part communicationEquipment {
            attribute powerRequirement : PowerValue;
        }
    }
    
    part def MaintenanceTeam {
        attribute teamSize : Integer;
        attribute skillLevel : String;
        attribute toolInventory : Integer;
        attribute sparePartsStock : Integer;
        
        part technicians[*] {
            attribute specialization : String;
            attribute experienceYears : Real;
        }
        
        part toolKit {
            attribute toolCount : Integer;
            attribute condition : MaintenanceLevel;
        }
    }
    
    part def MonitoringStation {
        attribute sensorCount : Integer;
        attribute dataCollectionInterval : Real;
        
        port alertInput : AlertPort;
        
        part sensors[*] {
            attribute sensorType : String;
            attribute calibrationDate : String;
            attribute accuracy : Real;
        }
        
        part dataLogger {
            attribute storageCapacity : Real;
            attribute batteryLife : Real;
        }
    }
    
    action def MonitorInfrastructure {
        in waterSystem : WaterSupplySystem;
        in powerSystem : PowerGenerationSystem;
        out waterStatus : ServiceStatus;
        out powerStatus : ServiceStatus;
        out alerts : MaintenanceAlert[*];
    }
    
    action def DispatchMaintenance {
        in alerts : MaintenanceAlert[*];
        in team : MaintenanceTeam;
        out assignedTasks : String[*];
        out priority : Integer;
    }
    
    action def PerformMaintenance {
        in component : String;
        in team : MaintenanceTeam;
        out maintenanceComplete : Boolean;
        out componentStatus : ServiceStatus;
    }
    
    action def SupplyWater {
        in waterSystem : WaterSupplySystem;
        in demand : VolumeFlowValue;
        out waterDelivered : PotableWater;
    }
    
    action def SupplyPower {
        in powerSystem : PowerGenerationSystem;
        in demand : PowerValue;
        out powerDelivered : ElectricalPower;
    }
    
    connection def WaterConnection {
        end supplier : WaterSupplyPort;
        end consumer : WaterIntakePort;
    }
    
    connection def PowerConnection {
        end supplier : PowerSupplyPort;
        end consumer : PowerIntakePort;
    }
    
    connection def AlertConnection {
        end source : AlertPort;
        end monitor : AlertPort;
    }
    
    part villageSystem {
        part waterSupply : WaterSupplySystem {
            attribute :>> totalCapacity = VolumeValue(100.0, SI::m3);
            attribute :>> currentOutput = VolumeFlowValue(3.0, SI::L_per_s);
            
            part :>> well {
                attribute :>> depth = LengthValue(50.0, SI::m);
                attribute :>> waterLevel = LengthValue(35.0, SI::m);
                attribute :>> rechargeRate = VolumeFlowValue(0.5, SI::L_per_s);
            }
            
            part :>> handPump {
                attribute :>> pumpCapacity = VolumeFlowValue(1.5, SI::L_per_s);
                attribute :>> wearLevel = 25.0;
                attribute :>> lastMaintenance = "2024-01-15";
            }
            
            part :>> storageTank {
                attribute :>> capacity = VolumeValue(20.0, SI::m3);
                attribute :>> currentVolume = VolumeValue(15.0, SI::m3);
                attribute :>> fillLevel = 75.0;
            }
        }
        
        part powerGeneration : PowerGenerationSystem {
            attribute :>> generationCapacity = PowerValue(75000.0, SI::W);
            attribute :>> currentOutput = PowerValue(55000.0, SI::W);
            attribute :>> fuelLevel = 80.0;
            
            part :>> solarPanels {
                attribute :>> panelCount = 50;
                attribute :>> totalCapacity = PowerValue(25000.0, SI::W);
                attribute :>> efficiency = 0.18;
            }
            
            part :>> batteryBank {
                attribute :>> capacity = EnergyValue(200000.0, SI::J);
                attribute :>> chargeLevel = 70.0;
                attribute :>> cycleCount = 450;
            }
            
            part :>> dieselGenerator {
                attribute :>> ratedPower = PowerValue(50000.0, SI::W);
                attribute :>> fuelCapacity = VolumeValue(500.0, SI::L);
                attribute :>> runningHours = 2500.0;
            }
        }
        
        part clinic : HealthClinic {
            attribute :>> patientCapacity = 50;
            attribute :>> dailyPatients = 30;
            attribute :>> operatingHours = 12.0;
            
            part :>> medicalEquipment {
                attribute :>> powerRequirement = PowerValue(15000.0, SI::W);
            }
            
            part :>> sanitationFacilities {
                attribute :>> waterRequirement = VolumeFlowValue(0.5, SI::L_per_s);
            }
        }
        
        part communityCenter : CommunityCenter {
            attribute :>> capacity = 200;
            attribute :>> dailyUsers = 150;
            
            part :>> lighting {
                attribute :>> powerConsumption = PowerValue(5000.0, SI::W);
            }
            
            part :>> communicationEquipment {
                attribute :>> powerRequirement = PowerValue(2000.0, SI::W);
            }
        }
        
        part maintenanceTeam : MaintenanceTeam {
            attribute :>> teamSize = 6;
            attribute :>> skillLevel = "intermediate";
            attribute :>> toolInventory = 150;
            attribute :>> sparePartsStock = 75;
            
            part :>> toolKit {
                attribute :>> toolCount = 150;
            }
        }
        
        part monitoringStation : MonitoringStation {
            attribute :>> sensorCount = 12;
            attribute :>> dataCollectionInterval = 300.0;
            
            part :>> dataLogger {
                attribute :>> storageCapacity = 1000000.0;
                attribute :>> batteryLife = 72.0;
            }
        }
        
        connection waterToClinic : WaterConnection
            connect waterSupply.waterOutput to clinic.waterIntake;
        
        connection waterToCommunity : WaterConnection
            connect waterSupply.waterOutput to communityCenter.waterIntake;
        
        connection powerToClinic : PowerConnection
            connect powerGeneration.powerOutput to clinic.powerIntake;
        
        connection powerToCommunity : PowerConnection
            connect powerGeneration.powerOutput to communityCenter.powerIntake;
        
        connection waterAlerts : AlertConnection
            connect waterSupply.alertOutput to monitoringStation.alertInput;
        
        connection powerAlerts : AlertConnection
            connect powerGeneration.alertOutput to monitoringStation.alertInput;
        
        action villageOperationCycle {
            first start;
            then merge continuousOperation;
            
            action monitorSystems : MonitorInfrastructure {
                in waterSystem;
                in powerSystem;
                out waterStatus : ServiceStatus;
                out powerStatus : ServiceStatus;
                out systemAlerts : MaintenanceAlert[*];
            }
            
            then decide;
                if monitorSystems.systemAlerts->notEmpty() then handleMaintenance;
                else provideServices;
            
            action handleMaintenance {
                first dispatchTeam;
                
                action dispatchTeam : DispatchMaintenance {
                    in alerts;
                    in team;
                    out assignedTasks : String[*];
                    out priority : Integer;
                }
                
                then executeRepairs;
                
                action executeRepairs : PerformMaintenance {
                    in component;
                    in team;
                    out maintenanceComplete : Boolean;
                    out componentStatus : ServiceStatus;
                }
            }
            then continuousOperation;
            
            action provideServices {
                first supplyWaterService;
                
                action supplyWaterService : SupplyWater {
                    in waterSystem;
                    in demand;
                    out waterDelivered : PotableWater;
                }
                
                then supplyPowerService;
                
                action supplyPowerService : SupplyPower {
                    in powerSystem;
                    in demand;
                    out powerDelivered : ElectricalPower;
                }
            }
            then continuousOperation;
        }
        
        perform villageOperationCycle;
    }
    
    requirement <'VLOM-REQ-001'> primaryFunction {
        doc /* The village-level operation and maintenance system shall 
             * provide continuous, reliable water supply and electrical 
             * power to essential village facilities including health 
             * clinic and community center, while maintaining infrastructure 
             * through proactive monitoring and responsive maintenance.
             */
        subject system : villageSystem;
        
        require waterSupplyReliability;
        require powerSupplyReliability;
        require maintenanceCapability;
        require monitoringCapability;
    }
    
    requirement <'VLOM-REQ-002'> waterSupplyReliability {
        doc /* The water supply system shall maintain minimum flow rate 
             * of 2.0 liters per second to meet village demand.
             */
        subject waterSystem :>> villageSystem.waterSupply;
        
        assert constraint {
            waterSystem.currentOutput.num >= 2.0
        }
    }
    
    requirement <'VLOM-REQ-003'> powerSupplyReliability {
        doc /* The power generation system shall maintain minimum output 
             * of 40 kW to support essential facilities.
             */
        subject powerSystem :>> villageSystem.powerGeneration;
        
        assert constraint {
            powerSystem.currentOutput.num >= 40000.0
        }
    }
    
    requirement <'VLOM-REQ-004'> maintenanceCapability {
        doc /* A trained maintenance team of at least 4 technicians 
             * shall be available for routine and emergency repairs.
             */
        subject team :>> villageSystem.maintenanceTeam;
        
        assert constraint {
            team.teamSize >= 4 and team.toolInventory >= 100
        }
    }
    
    requirement <'VLOM-REQ-005'> monitoringCapability {
        doc /* The monitoring station shall continuously track system 
             * performance with data collection at intervals not 
             * exceeding 5 minutes.
             */
        subject station :>> villageSystem.monitoringStation;
        
        assert constraint {
            station.dataCollectionInterval <= 300.0
        }
    }
    
    requirement <'VLOM-REQ-006'> waterStorageCapacity {
        doc /* Water storage tank shall maintain minimum capacity of 
             * 15 cubic meters for emergency supply.
             */
        subject tank :>> villageSystem.waterSupply.storageTank;
        
        assert constraint {
            tank.capacity.num >= 15.0
        }
    }
    
    requirement <'VLOM-REQ-007'> powerBackupCapacity {
        doc /* Battery bank shall maintain charge level above 50% to 
             * ensure backup power availability.
             */
        subject battery :>> villageSystem.powerGeneration.batteryBank;
        
        assert constraint {
            battery.chargeLevel >= 50.0
        }
    }
    
    satisfy primaryFunction by villageSystem;
    satisfy waterSupplyReliability by villageSystem.waterSupply;
    satisfy powerSupplyReliability by villageSystem.powerGeneration;
    satisfy maintenanceCapability by villageSystem.maintenanceTeam;
    satisfy monitoringCapability by villageSystem.monitoringStation;
}
