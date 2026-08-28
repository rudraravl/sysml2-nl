package KarmanCannulaSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types ----
    value def PressureValue :> Real {
        unit mmHg;
    }
    
    value def VolumeValue :> Real {
        unit mL;
    }
    
    value def FlowRateValue :> Real {
        unit mL_per_min;
    }
    
    value def LengthValue :> Real {
        unit mm;
    }
    
    value def DiameterValue :> Real {
        unit mm;
    }
    
    // ---- Items ----
    item def UterineContents {
        attribute composition : String;
        attribute estimatedVolume : VolumeValue;
    }
    
    item def Air;
    
    // ---- Port Definitions ----
    port def FluidPort {
        attribute pressure : PressureValue;
        flow of Air;
        flow of UterineContents;
    }
    
    // ---- Requirements ----
    requirement def VacuumSafetyLimit {
        attribute maxVacuumPressure : PressureValue = 600 [mmHg];
        attribute minVacuumPressure : PressureValue = 200 [mmHg];
        require constraint { 
            pressure >= minVacuumPressure and pressure <= maxVacuumPressure 
        }
    }
    
    requirement def EvacuationCompleteness {
        attribute targetEvacuationVolume : VolumeValue = 50 [mL];
        require constraint { evacuatedVolume >= targetEvacuationVolume }
    }
    
    requirement def ChamberCapacityLimit {
        attribute maxChamberCapacity : VolumeValue = 250 [mL];
        require constraint { collectedVolume <= maxChamberCapacity }
    }
    
    requirement def CannulaFlexibility {
        attribute cannulaLength : LengthValue = 200 [mm];
        attribute cannulaDiameter : DiameterValue = 6 [mm];
        require constraint { cannulaDiameter <= 12 [mm] }
    }
    
    // ---- Flexible Cannula ----
    part def FlexibleCannula {
        attribute material : String = "Medical-grade plastic";
        attribute length : LengthValue = 200 [mm];
        attribute diameter : DiameterValue = 6 [mm];
        attribute flexibilityRating : Real = 0.85;
        
        port tipPort : FluidPort {
            attribute description : String = "Insertion end into uterine cavity";
        }
        port basePort : FluidPort {
            attribute description : String = "Connection end to collection chamber";
        }
        
        attribute internalPressure : PressureValue;
        flow throughCannula : FlowRateValue;
        
        satisfy CannulaFlexibility {
            attribute cannulaLength = length;
            attribute cannulaDiameter = diameter;
        }
        
        action def ConductFlow {
            in inflow : UterineContents;
            out outflow : UterineContents;
        }
        
        perform ConductFlow {
            // Flow from tip to base
        }
    }
    
    // ---- Manual Vacuum Aspirator ----
    part def ManualVacuumAspirator {
        attribute type : String = "Hand-operated syringe pump";
        attribute maxVacuumGeneration : PressureValue = 700 [mmHg];
        attribute operationalVacuum : PressureValue = 500 [mmHg];
        attribute strokeVolume : VolumeValue = 60 [mL];
        
        port aspirationPort : FluidPort {
            attribute description : String = "Connection to collection chamber";
        }
        
        attribute generatedVacuum : PressureValue;
        attribute isEngaged : Boolean = false;
        
        satisfy VacuumSafetyLimit {
            attribute pressure = generatedVacuum;
        }
        
        state defenum AspiratorStates {
            enum Idle;
            enum Priming;
            enum VacuumReady;
            enum ApplyingVacuum;
            enum Released;
        }
        
        state aspiratorStateMachine : AspiratorStates {
            entry; then Idle;
            
            transition Idle_to_Priming first Idle then Priming {
                trigger when clinicianPullsPiston == true;
            }
            
            transition Priming_to_VacuumReady first Priming then VacuumReady {
                trigger when generatedVacuum >= operationalVacuum;
            }
            
            transition VacuumReady_to_ApplyingVacuum first VacuumReady then ApplyingVacuum {
                trigger when valveOpened == true;
            }
            
            transition ApplyingVacuum_to_Released first ApplyingVacuum then Released {
                trigger when evacuationComplete == true or chamberFull == true;
            }
            
            transition Released_to_Idle first Released then Idle {
                trigger when resetRequested == true;
            }
        }
        
        action def GenerateVacuum {
            in pistonStroke : Real;
            out vacuumPressure : PressureValue;
        }
        
        perform GenerateVacuum {
            // Clinician pulls piston to create negative pressure
        }
        
        attribute clinicianPullsPiston : Boolean;
        attribute valveOpened : Boolean;
        attribute evacuationComplete : Boolean;
        attribute chamberFull : Boolean;
        attribute resetRequested : Boolean;
    }
    
    // ---- Collection Chamber ----
    part def CollectionChamber {
        attribute capacity : VolumeValue = 250 [mL];
        attribute currentVolume : VolumeValue = 0 [mL];
        attribute isSealed : Boolean = true;
        attribute measurementGraduations : VolumeValue = 5 [mL];
        
        port aspiratorConnectionPort : FluidPort {
            attribute description : String = "Connection to manual vacuum aspirator";
        }
        port cannulaConnectionPort : FluidPort {
            attribute description : String = "Connection to flexible cannula";
        }
        
        attribute internalPressure : PressureValue;
        attribute collectedContents : UterineContents[0..*];
        
        satisfy ChamberCapacityLimit {
            attribute collectedVolume = currentVolume;
        }
        
        action def CollectContents {
            in incomingContents : UterineContents;
            out measuredVolume : VolumeValue;
        }
        
        perform CollectContents {
            // Accumulate and measure uterine contents
        }
        
        attribute chamberFull : Boolean = false;
        
        constraint capacityCheck {
            currentVolume <= capacity
        }
    }
    
    // ---- Karman Cannula System ----
    part def KarmanCannulaSystem {
        part cannula : FlexibleCannula;
        part aspirator : ManualVacuumAspirator;
        part chamber : CollectionChamber;
        
        connect cannula.basePort to chamber.cannulaConnectionPort;
        connect aspirator.aspirationPort to chamber.aspiratorConnectionPort;
        
        attribute systemVacuumPressure : PressureValue;
        attribute totalEvacuatedVolume : VolumeValue = 0 [mL];
        attribute procedureActive : Boolean = false;
        attribute procedureComplete : Boolean = false;
        
        satisfy VacuumSafetyLimit {
            attribute pressure = systemVacuumPressure;
        }
        
        satisfy EvacuationCompleteness {
            attribute evacuatedVolume = totalEvacuatedVolume;
        }
        
        state defenum SystemStates {
            enum Standby;
            enum VacuumGeneration;
            enum CannulaPositioning;
            enum Aspiration;
            enum ProcedureComplete;
            enum SafetyAbort;
        }
        
        state systemStateMachine : SystemStates {
            entry; then Standby;
            
            transition Standby_to_VacuumGeneration first Standby then VacuumGeneration {
                trigger when aspirator.aspiratorStateMachine == AspiratorStates::Priming;
            }
            
            transition VacuumGeneration_to_CannulaPositioning first VacuumGeneration then CannulaPositioning {
                trigger when aspirator.aspiratorStateMachine == AspiratorStates::VacuumReady;
            }
            
            transition CannulaPositioning_to_Aspiration first CannulaPositioning then Aspiration {
                trigger when aspirator.aspiratorStateMachine == AspiratorStates::ApplyingVacuum;
            }
            
            transition Aspiration_to_ProcedureComplete first Aspiration then ProcedureComplete {
                trigger when aspirator.evacuationComplete == true;
            }
            
            transition Aspiration_to_SafetyAbort first Aspiration then SafetyAbort {
                trigger when systemVacuumPressure > 600 [mmHg] or chamber.chamberFull == true;
            }
            
            transition ProcedureComplete_to_Standby first ProcedureComplete then Standby {
                trigger when resetRequested == true;
            }
            
            transition SafetyAbort_to_Standby first SafetyAbort then Standby {
                trigger when resetRequested == true;
            }
        }
        
        action def PerformAspirationProcedure {
            in clinicianInput : Boolean;
            out evacuationResult : Boolean;
        }
        
        perform PerformAspirationProcedure {
            // 1. Clinician uses aspirator to create vacuum in sealed chamber and cannula
            // 2. Cannula positioned within uterus
            // 3. Vacuum applied, suctioning uterine contents through cannula into chamber
            // 4. Continue until evacuation complete or chamber reaches capacity
        }
        
        attribute resetRequested : Boolean;
        
        constraint vacuumSafety {
            systemVacuumPressure >= 200 [mmHg] and systemVacuumPressure <= 600 [mmHg]
        }
        
        constraint flowContinuity {
            cannula.throughCannula == chamber.currentVolume - chamber.currentVolume
        }
    }
}
