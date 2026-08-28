package BootSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value type Mass :> Real { unit 'g'; }
    value type Length :> Real { unit 'mm'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Pressure :> Real { unit 'kPa'; }
    value type Force :> Real { unit 'N'; }
    value type WearPercent :> Real { unit '%'; }
    value type MoistureLevel :> Real { unit '%'; }
    value type FrictionCoefficient :> Real { unit '1'; }
    value type ShoreHardness :> Real { unit '1'; }
    
    // ===== Item Types =====
    item def ExternalImpact;
    item def Water;
    item def Moisture;
    item def Heat;
    item def Cold;
    item def Dirt;
    item def GroundSurface;
    item def Foot;
    item def Sweat;
    
    // ===== Enumerations =====
    enum def TerrainType {
        flat;
        rocky;
        muddy;
        icy;
        sandy;
        wet;
    }
    
    enum def WeatherCondition {
        dry;
        rainy;
        snowy;
        hot;
        cold;
    }
    
    // ===== Interfaces =====
    interface def FootInterface {
        in item foot : Foot;
        out item sweat : Sweat;
        out force wearerWeight : Force;
        in force pressureDistribution : Pressure;
        in temperature internalTemp : Temperature;
    }
    
    interface def GroundInterface {
        in item ground : GroundSurface;
        in force normalForce : Force;
        out force gripForce : Force;
        out frictionCoefficient friction : FrictionCoefficient;
    }
    
    interface def EnvironmentInterface {
        in item water : Water;
        in item heat : Heat;
        in item cold : Cold;
        in item dirt : Dirt;
        in item impact : ExternalImpact;
        in temperature ambientTemp : Temperature;
    }
    
    // ===== Component Definitions =====
    
    part def Sole {
        attribute material : String = "Rubber composite";
        attribute thickness : Length = 15.0;
        attribute hardness : ShoreHardness = 65.0;
        attribute treadDepth : Length = 5.0;
        attribute wearLevel : WearPercent = 0.0;
        attribute maxWear : WearPercent = 100.0;
        
        port groundPort : GroundInterface;
        
        attribute gripRating : FrictionCoefficient = 0.8;
        
        action def GripGround {
            in ground : GroundSurface;
            in normalForce : Force;
            out gripForce : Force;
        }
        
        action def AbsorbImpact {
            in impact : ExternalImpact;
            out absorbedForce : Force;
        }
        
        action def DistributePressure {
            in wearerWeight : Force;
            out pressure : Pressure;
        }
        
        perform action grip : GripGround;
        perform action absorb : AbsorbImpact;
        perform action distribute : DistributePressure;
    }
    
    part def Upper {
        attribute material : String = "Full-grain leather";
        attribute reinforced : Boolean = true;
        attribute breathabilityRating : Real = 0.7;
        attribute flexibilityRating : Real = 0.8;
        attribute wearLevel : WearPercent = 0.0;
        attribute maxWear : WearPercent = 100.0;
        
        port environmentPort : EnvironmentInterface;
        port footPort : FootInterface;
        
        action def ProtectFromImpact {
            in impact : ExternalImpact;
        }
        
        action def ResistWater {
            in water : Water;
            out resisted : Boolean;
        }
        
        action def Insulate {
            in ambientTemp : Temperature;
            out internalTemp : Temperature;
        }
        
        perform action protect : ProtectFromImpact;
        perform action resist : ResistWater;
        perform action insulate : Insulate;
    }
    
    part def Lining {
        attribute material : String = "Synthetic moisture-wicking";
        attribute padded : Boolean = true;
        attribute paddingThickness : Length = 3.0;
        attribute moistureLevel : MoistureLevel = 0.0;
        attribute maxMoisture : MoistureLevel = 100.0;
        
        port footPort : FootInterface;
        
        action def WickMoisture {
            in sweat : Sweat;
            out moisture : Moisture;
        }
        
        action def ProvidePadding {
            in wearerWeight : Force;
            out cushioning : Pressure;
        }
        
        perform action wick : WickMoisture;
        perform action pad : ProvidePadding;
    }
    
    part def Insole {
        attribute material : String = "Cushioned foam";
        attribute thickness : Length = 8.0;
        attribute archSupportRating : Real = 0.9;
        attribute cushioningRating : Real = 0.85;
        attribute compressionLevel : WearPercent = 0.0;
        attribute maxCompression : WearPercent = 100.0;
        
        port footPort : FootInterface;
        
        action def CushionFoot {
            in wearerWeight : Force;
            out cushioningPressure : Pressure;
        }
        
        action def SupportArch {
            in foot : Foot;
            out supportForce : Force;
        }
        
        perform action cushion : CushionFoot;
        perform action support : SupportArch;
    }
    
    part def LacingSystem {
        attribute type : String = "Speed-lacing";
        attribute laceMaterial : String = "High-tenacity nylon";
        attribute eyeletCount : Integer = 8;
        attribute tensionRating : Force = 120.0;
        attribute adjustmentSpeed : Real = 0.95;
        attribute wearLevel : WearPercent = 0.0;
        attribute maxWear : WearPercent = 100.0;
        
        port footPort : FootInterface;
        
        action def SecureFit {
            in foot : Foot;
            out secured : Boolean;
        }
        
        action def QuickAdjust {
            in desiredTension : Force;
            out actualTension : Force;
        }
        
        action def Release {
            out released : Boolean;
        }
        
        perform action secure : SecureFit;
        perform action adjust : QuickAdjust;
        perform action release : Release;
    }
    
    // ===== Main Boot System =====
    part def UtilityBoot {
        attribute name : String = "High-Performance Utility Boot";
        attribute totalMass : Mass = 650.0;
        attribute size : Length = 270.0;
        attribute maxServiceLife : Integer = 1000; // hours of use
        attribute usageHours : Integer = 0;
        attribute overallWear : WearPercent = 0.0;
        
        port footInterface : FootInterface;
        port groundInterface : GroundInterface;
        port environmentInterface : EnvironmentInterface;
        
        part sole : Sole;
        part upper : Upper;
        part lining : Lining;
        part insole : Insole;
        part lacingSystem : LacingSystem;
        
        // Internal connections
        connection soleToGround connect sole.groundPort to groundInterface;
        connection upperToEnvironment connect upper.environmentPort to environmentInterface;
        connection upperToFoot connect upper.footPort to footInterface;
        connection liningToFoot connect lining.footPort to upper.footPort;
        connection insoleToFoot connect insole.footPort to lining.footPort;
        connection lacingToFoot connect lacingSystem.footPort to upper.footPort;
        connection soleToUpper connect sole to upper;
        connection upperToLining connect upper to lining;
        connection liningToInsole connect lining to insole;
        
        // ===== State Machine =====
        state def BootLifecycle {
            attribute currentState : String;
            
            entry; then New;
            
            state New {
                entry action { currentState = "New"; }
                attribute readyForUse : Boolean = true;
                then InUse;
            }
            
            state InUse {
                entry action { currentState = "InUse"; }
                
                parallel substates {
                    state ActivityState {
                        entry; then Standing;
                        
                        state Standing {
                            entry action { currentState = "Standing"; }
                        }
                        state Walking {
                            entry action { currentState = "Walking"; }
                        }
                        state Running {
                            entry action { currentState = "Running"; }
                        }
                        
                        transition standing_to_walking
                            source Standing
                            target Walking
                            when (wearerWeight > 0 & activity == "walk");
                        
                        transition walking_to_running
                            source Walking
                            target Running
                            when (activity == "run");
                        
                        transition running_to_walking
                            source Running
                            target Walking
                            when (activity == "walk");
                        
                        transition walking_to_standing
                            source Walking
                            target Standing
                            when (activity == "stand");
                        
                        transition standing_to_running
                            source Standing
                            target Running
                            when (activity == "run");
                        
                        transition running_to_standing
                            source Running
                            target Standing
                            when (activity == "stand");
                    }
                    
                    state WearMonitoring {
                        entry; then Serviceable;
                        
                        state Serviceable {
                            entry action { overallWear = overallWear + 0.1; }
                        }
                        state NeedsMaintenance {
                            entry action { currentState = "NeedsMaintenance"; }
                        }
                        state Damaged {
                            entry action { currentState = "Damaged"; }
                        }
                        
                        transition serviceable_to_maintenance
                            source Serviceable
                            target NeedsMaintenance
                            when (overallWear > 50.0);
                        
                        transition maintenance_to_serviceable
                            source NeedsMaintenance
                            target Serviceable
                            when (maintenancePerformed == true);
                        
                        transition serviceable_to_damaged
                            source Serviceable
                            target Damaged
                            when (overallWear > 80.0 | damageDetected == true);
                        
                        transition damaged_to_maintenance
                            source Damaged
                            target NeedsMaintenance
                            when (repairable == true);
                    }
                }
                
                transition inUse_to_cleaning
                    source InUse
                    target Cleaning
                    when (usageComplete == true);
            }
            
            state Cleaning {
                entry action { currentState = "Cleaning"; }
                do action { 
                    lining.moistureLevel = 0.0; 
                    upper.wearLevel = upper.wearLevel + 0.05;
                }
                then InUse or Maintenance;
            }
            
            state Maintenance {
                entry action { currentState = "Maintenance"; }
                do action {
                    sole.wearLevel = sole.wearLevel - 10.0;
                    insole.compressionLevel = insole.compressionLevel - 15.0;
                    lacingSystem.wearLevel = lacingSystem.wearLevel - 5.0;
                    maintenancePerformed = true;
                }
                then InUse or Retired;
            }
            
            state Retired {
                entry action { currentState = "Retired"; }
                attribute serviceable : Boolean = false;
            }
            
            transition cleaning_to_inUse
                source Cleaning
                target InUse
                when (cleaningComplete == true & overallWear < 80.0);
            
            transition cleaning_to_maintenance
                source Cleaning
                target Maintenance
                when (overallWear > 50.0);
            
            transition maintenance_to_retired
                source Maintenance
                target Retired
                when (overallWear >= 100.0 | repairable == false);
            
            transition inUse_to_retired
                source InUse
                target Retired
                when (overallWear >= 100.0);
        }
        
        attribute activity : String = "stand";
        attribute wearerWeight : Force = 750.0;
        attribute usageComplete : Boolean = false;
        attribute cleaningComplete : Boolean = false;
        attribute maintenancePerformed : Boolean = false;
        attribute damageDetected : Boolean = false;
        attribute repairable : Boolean = true;
        
        exhibit state lifecycle : BootLifecycle;
        
        // ===== Main Actions =====
        action def ProtectFoot {
            in impact : ExternalImpact;
            in water : Water;
            in ambientTemp : Temperature;
            out protectionStatus : Boolean;
            
            perform upper.protect(impact);
            perform upper.resist(water);
            perform upper.insulate(ambientTemp);
        }
        
        action def ProvideStability {
            in ground : GroundSurface;
            in wearerWeight : Force;
            out stabilityRating : Real;
            
            perform sole.grip(ground, wearerWeight);
            perform sole.distribute(wearerWeight);
        }
        
        action def ProvideComfort {
            in foot : Foot;
            in sweat : Sweat;
            in wearerWeight : Force;
            out comfortRating : Real;
            
            perform lining.wick(sweat);
            perform lining.pad(wearerWeight);
            perform insole.cushion(wearerWeight);
            perform insole.support(foot);
        }
        
        action def SecureToFoot {
            in foot : Foot;
            in desiredTension : Force;
            out secured : Boolean;
            
            perform lacingSystem.secure(foot);
            perform lacingSystem.adjust(desiredTension);
        }
        
        action def MonitorWear {
            in usageHours : Integer;
            out wearReport : WearPercent;
            
            do action {
                sole.wearLevel = sole.wearLevel + (usageHours * 0.05);
                upper.wearLevel = upper.wearLevel + (usageHours * 0.03);
                lining.moistureLevel = lining.moistureLevel + (usageHours * 0.02);
                insole.compressionLevel = insole.compressionLevel + (usageHours * 0.04);
                lacingSystem.wearLevel = lacingSystem.wearLevel + (usageHours * 0.02);
                overallWear = (sole.wearLevel + upper.wearLevel + insole.compressionLevel + lacingSystem.wearLevel) / 4.0;
            }
        }
        
        perform action protect : ProtectFoot;
        perform action stabilize : ProvideStability;
        perform action comfort : ProvideComfort;
        perform action secure : SecureToFoot;
        perform action monitor : MonitorWear;
    }
    
    // ===== Requirements =====
    requirement def ProtectionRequirement {
        subject boot : UtilityBoot;
        objective {
            /* The boot shall protect the foot from external impacts, water, and temperature extremes. */
        }
        assume { boot.upper.reinforced == true; }
    }
    
    requirement def StabilityRequirement {
        subject boot : UtilityBoot;
        attribute minGripRating : FrictionCoefficient = 0.6;
        objective {
            /* The boot shall provide stability by gripping the ground and distributing the wearer's weight evenly. */
        }
        require { boot.sole.gripRating >= minGripRating; }
    }
    
    requirement def ComfortRequirement {
        subject boot : UtilityBoot;
        attribute maxInternalMoisture : MoistureLevel = 30.0;
        attribute minArchSupport : Real = 0.8;
        objective {
            /* The boot shall provide comfort through cushioning, arch support, and moisture management. */
        }
        require { 
            boot.insole.archSupportRating >= minArchSupport;
            boot.lining.moistureLevel <= maxInternalMoisture;
        }
    }
    
    requirement def FitRequirement {
        subject boot : UtilityBoot;
        attribute minTension : Force = 50.0;
        objective {
            /* The boot shall be secured to the foot using a speed-lacing system for quick, adjustable, and secure fit. */
        }
        require {
            boot.lacingSystem.type == "Speed-lacing";
            boot.lacingSystem.tensionRating >= minTension;
        }
    }
    
    requirement def DurabilityRequirement {
        subject boot : UtilityBoot;
        attribute minServiceLife : Integer = 800;
        objective {
            /* The boot shall be serviceable for at least the minimum service life before reaching retired state. */
        }
        require { boot.maxServiceLife >= minServiceLife; }
    }
    
    requirement def TemperatureRegulationRequirement {
        subject boot : UtilityBoot;
        attribute comfortTempMin : Temperature = 10.0;
        attribute comfortTempMax : Temperature = 35.0;
        objective {
            /* The boot shall regulate internal temperature to keep the foot comfortable across various conditions. */
        }
    }
    
    requirement def WearMonitoringRequirement {
        subject boot : UtilityBoot;
        objective {
            /* The boot system shall monitor wear and tear over time and transition to retired state when no longer serviceable. */
        }
        require { boot.overallWear <= boot.sole.maxWear; }
    }
    
    // ===== Requirement Satisfaction =====
    part bootInstance : UtilityBoot {
        satisfy ProtectionRequirement;
        satisfy StabilityRequirement;
        satisfy ComfortRequirement;
        satisfy FitRequirement;
        satisfy DurabilityRequirement;
        satisfy TemperatureRegulationRequirement;
        satisfy WearMonitoringRequirement;
    }
}
