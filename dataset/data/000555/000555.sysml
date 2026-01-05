package 'Boot System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BootSize {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }
    
    attribute def MaterialType;
    
    attribute def WearLevel {
        attribute value : Real;
    }
    
    attribute def ProtectionLevel {
        attribute waterResistance : Real;
        attribute impactResistance : Real;
        attribute thermalInsulation : Real;
    }
    
    item def Sole {
        attribute material : MaterialType;
        attribute thickness : LengthValue;
        attribute gripPattern : String;
        attribute treadDepth : LengthValue;
    }
    
    item def Upper {
        attribute material : MaterialType;
        attribute breathability : Real;
        attribute flexibility : Real;
        attribute reinforcement : Boolean;
    }
    
    item def Lining {
        attribute material : MaterialType;
        attribute comfort : Real;
        attribute moistureWicking : Real;
        attribute padding : LengthValue;
    }
    
    item def Closure {
        attribute type : String;
        attribute adjustability : Real;
        attribute securityLevel : Real;
    }
    
    item def Insole {
        attribute material : MaterialType;
        attribute cushioning : Real;
        attribute archSupport : Real;
    }
    
    port def FootInterface {
        attribute size : BootSize;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    
    port def GroundInterface {
        attribute contactArea : AreaValue;
        attribute frictionCoefficient : Real;
        attribute normalForce : ForceValue;
    }
    
    port def EnvironmentInterface {
        attribute ambientTemperature : TemperatureValue;
        attribute moisture : Real;
        attribute terrain : String;
    }
    
    part def Boot {
        attribute bootSize : BootSize;
        attribute weight : MassValue;
        attribute currentWear : WearLevel;
        attribute protection : ProtectionLevel;
        attribute inService : Boolean;
        
        part sole : Sole {
            attribute material = "Rubber Composite";
            attribute thickness = 15.0 [mm];
            attribute gripPattern = "Multi-Directional Lug";
            attribute treadDepth = 5.0 [mm];
        }
        
        part upper : Upper {
            attribute material = "Full Grain Leather";
            attribute breathability = 0.65;
            attribute flexibility = 0.6;
            attribute reinforcement = true;
        }
        
        part lining : Lining {
            attribute material = "Moisture-Wicking Synthetic";
            attribute comfort = 0.85;
            attribute moistureWicking = 0.8;
            attribute padding = 3.0 [mm];
        }
        
        part closure : Closure {
            attribute type = "Speed Lacing System";
            attribute adjustability = 0.9;
            attribute securityLevel = 0.95;
        }
        
        part insole : Insole {
            attribute material = "EVA Foam";
            attribute cushioning = 0.8;
            attribute archSupport = 0.75;
        }
        
        port footPort : FootInterface;
        port groundPort : GroundInterface;
        port envPort : EnvironmentInterface;
        
        connection footToInsole : FootToInsoleConnection connect footPort to insole;
        connection insoleToLining : InsoleToLiningConnection connect insole to lining;
        connection liningToUpper : LiningToUpperConnection connect lining to upper;
        connection upperToSole : UpperToSoleConnection connect upper to sole;
        connection soleToGround : SoleToGroundConnection connect sole to groundPort;
        connection closureToUpper : ClosureToUpperConnection connect closure to upper;
        connection upperToEnv : UpperToEnvironmentConnection connect upper to envPort;
    }
    
    connection def FootToInsoleConnection {
        end footEnd : FootInterface;
        end insoleEnd : Insole;
    }
    
    connection def InsoleToLiningConnection {
        end insoleEnd : Insole;
        end liningEnd : Lining;
    }
    
    connection def LiningToUpperConnection {
        end liningEnd : Lining;
        end upperEnd : Upper;
    }
    
    connection def UpperToSoleConnection {
        end upperEnd : Upper;
        end soleEnd : Sole;
    }
    
    connection def SoleToGroundConnection {
        end soleEnd : Sole;
        end groundEnd : GroundInterface;
    }
    
    connection def ClosureToUpperConnection {
        end closureEnd : Closure;
        end upperEnd : Upper;
    }
    
    connection def UpperToEnvironmentConnection {
        end upperEnd : Upper;
        end envEnd : EnvironmentInterface;
    }
    
    action def SecureFoot {
        in footSize : BootSize;
        in closureType : String;
        out secured : Boolean;
        out fitQuality : Real;
    }
    
    action def DistributeLoad {
        in footPressure : PressureValue;
        in footArea : AreaValue;
        in insoleCushioning : Real;
        out distributedPressure : PressureValue;
        out comfortLevel : Real;
    }
    
    action def ProvideGrip {
        in surfaceType : String;
        in appliedForce : ForceValue;
        in treadDepth : LengthValue;
        out frictionForce : ForceValue;
        out stability : Real;
    }
    
    action def ProtectFoot {
        in externalImpact : ForceValue;
        in temperature : TemperatureValue;
        in moisture : Real;
        in protectionLevel : ProtectionLevel;
        out protectionProvided : Boolean;
        out footCondition : Real;
    }
    
    action def MonitorWear {
        in usageDuration : TimeValue;
        in stressLevel : Real;
        in treadDepth : LengthValue;
        out wearLevel : WearLevel;
        out serviceableStatus : Boolean;
    }
    
    action def RegulateTemperature {
        in ambientTemp : TemperatureValue;
        in footTemp : TemperatureValue;
        in insulation : Real;
        in breathability : Real;
        out internalTemp : TemperatureValue;
        out thermalComfort : Real;
    }
    
    action def BootOperation {
        first start;
        then action secureFoot : SecureFoot {
            in footSize;
            in closureType;
            out secured;
            out fitQuality;
        }
        then merge operatingCycle;
        then action distributeLoad : DistributeLoad {
            in footPressure;
            in footArea;
            in insoleCushioning;
            out distributedPressure;
            out comfortLevel;
        }
        then action provideGrip : ProvideGrip {
            in surfaceType;
            in appliedForce;
            in treadDepth;
            out frictionForce;
            out stability;
        }
        then action protectFoot : ProtectFoot {
            in externalImpact;
            in temperature;
            in moisture;
            in protectionLevel;
            out protectionProvided;
            out footCondition;
        }
        then action regulateTemp : RegulateTemperature {
            in ambientTemp;
            in footTemp;
            in insulation;
            in breathability;
            out internalTemp;
            out thermalComfort;
        }
        then action monitorWear : MonitorWear {
            in usageDuration;
            in stressLevel;
            in treadDepth;
            out wearLevel;
            out serviceableStatus;
        }
        then decide;
            if monitorWear.wearLevel.value < 0.75 and monitorWear.serviceableStatus then operatingCycle;
            if monitorWear.wearLevel.value >= 0.75 or not monitorWear.serviceableStatus then endOperation;
        action endOperation;
        then done;
    }
    
    attribute def InspectionPassEvent;
    attribute def PutOnEvent;
    attribute def StartWalkingEvent;
    attribute def StartRunningEvent;
    attribute def SlowDownEvent;
    attribute def StopWalkingEvent;
    attribute def RemoveEvent;
    attribute def CleanedEvent;
    attribute def MaintenanceRequiredEvent;
    attribute def MaintenanceCompleteEvent;
    attribute def BeyondRepairEvent;
    attribute def WearLimitExceededEvent;
    
    state def BootLifecycle {
        state new;
        
        transition new_to_ready
            first new
            accept InspectionPassEvent
            then ready;
        
        state ready;
        
        transition ready_to_inUse
            first ready
            accept PutOnEvent
            then inUse;
        
        state inUse {
            state standing;
            
            transition standing_to_walking
                first standing
                accept StartWalkingEvent
                then walking;
            
            state walking;
            
            transition walking_to_running
                first walking
                accept StartRunningEvent
                then running;
            
            state running;
            
            transition running_to_walking
                first running
                accept SlowDownEvent
                then walking;
            
            transition walking_to_standing
                first walking
                accept StopWalkingEvent
                then standing;
        }
        
        transition inUse_to_removed
            first inUse
            accept RemoveEvent
            then removed;
        
        state removed;
        
        transition removed_to_ready
            first removed
            accept CleanedEvent
            then ready;
        
        transition removed_to_maintenance
            first removed
            accept MaintenanceRequiredEvent
            then maintenance;
        
        state maintenance;
        
        transition maintenance_to_ready
            first maintenance
            accept MaintenanceCompleteEvent
            then ready;
        
        transition maintenance_to_retired
            first maintenance
            accept BeyondRepairEvent
            then retired;
        
        transition removed_to_retired
            first removed
            accept WearLimitExceededEvent
            then retired;
        
        state retired;
    }
    
    requirement def BootRequirements {
        doc /* The boot shall provide comprehensive protection, support, comfort, and durability for the wearer's foot across varied environmental conditions and activities. */
        
        require protectionRequirement : ProtectionRequirement;
        require supportRequirement : SupportRequirement;
        require comfortRequirement : ComfortRequirement;
        require durabilityRequirement : DurabilityRequirement;
        require performanceRequirement : PerformanceRequirement;
    }
    
    requirement def ProtectionRequirement {
        doc /* The boot shall protect the foot from external impacts, water intrusion, temperature extremes, and environmental hazards. */
        
        subject boot : Boot;
        
        require constraint {
            boot.protection.waterResistance >= 0.8
        }
        
        require constraint {
            boot.protection.impactResistance >= 0.75
        }
        
        require constraint {
            boot.protection.thermalInsulation >= 0.7
        }
        
        require constraint {
            boot.upper.reinforcement == true
        }
    }
    
    requirement def SupportRequirement {
        doc /* The boot shall provide adequate structural support, load distribution, and stability for the foot during various activities. */
        
        subject boot : Boot;
        
        require constraint {
            boot.sole.thickness >= 12.0 [mm]
        }
        
        require constraint {
            boot.upper.flexibility >= 0.5 and boot.upper.flexibility <= 0.8
        }
        
        require constraint {
            boot.insole.archSupport >= 0.7
        }
        
        require constraint {
            boot.sole.treadDepth >= 4.0 [mm]
        }
    }
    
    requirement def ComfortRequirement {
        doc /* The boot shall provide comfort through proper cushioning, fit adjustment, moisture management, and temperature regulation. */
        
        subject boot : Boot;
        
        require constraint {
            boot.lining.comfort >= 0.75
        }
        
        require constraint {
            boot.lining.moistureWicking >= 0.7
        }
        
        require constraint {
            boot.closure.adjustability >= 0.85
        }
        
        require constraint {
            boot.insole.cushioning >= 0.75
        }
        
        require constraint {
            boot.upper.breathability >= 0.6
        }
    }
    
    requirement def DurabilityRequirement {
        doc /* The boot shall maintain structural integrity and functional performance throughout its expected service life under normal use conditions. */
        
        subject boot : Boot;
        
        require constraint {
            boot.currentWear.value < 0.75
        }
        
        require constraint {
            boot.sole.treadDepth >= 3.0 [mm]
        }
        
        require constraint {
            boot.weight <= 1.5 [kg]
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The boot shall deliver reliable performance in grip, stability, and protection across diverse terrain and weather conditions. */
        
        subject boot : Boot;
        
        require constraint {
            boot.closure.securityLevel >= 0.9
        }
        
        require constraint {
            boot.sole.gripPattern == "Multi-Directional Lug"
        }
    }
    
    part bootSystem : Boot {
        attribute bootSize : BootSize {
            attribute length = 295.0 [mm];
            attribute width = 105.0 [mm];
            attribute height = 210.0 [mm];
        }
        attribute weight = 1.3 [kg];
        attribute currentWear : WearLevel {
            attribute value = 0.15;
        }
        attribute protection : ProtectionLevel {
            attribute waterResistance = 0.9;
            attribute impactResistance = 0.85;
            attribute thermalInsulation = 0.8;
        }
        attribute inService = true;
        
        perform action bootOp : BootOperation;
        
        exhibit state bootState : BootLifecycle;
        
        satisfy bootReqs : BootRequirements;
    }
}
