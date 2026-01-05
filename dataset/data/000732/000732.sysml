package PessaryMechanicalSupportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ProlapseStage {
        attribute severity : Integer;
    }
    
    attribute def ComfortRating {
        attribute score : Real;
    }
    
    attribute def SupportForce :> ISQ::ForceValue;
    attribute def ContactPressure :> ISQ::PressureValue;
    attribute def Displacement :> ISQ::LengthValue;
    
    item def PelvicOrgan {
        attribute normalPosition : ISQ::LengthValue;
        attribute currentPosition : ISQ::LengthValue;
        attribute organMass : ISQ::MassValue;
    }
    
    item def VaginalTissue {
        attribute elasticity : Real;
        attribute sensitivity : Real;
    }
    
    port def SupportInterface {
        out appliedForce : SupportForce;
        in organLoad : ISQ::ForceValue;
        out contactPressure : ContactPressure;
    }
    
    port def TissueInterface {
        in contactForce : SupportForce;
        out tissueResponse : VaginalTissue;
    }
    
    part def PessaryDevice {
        attribute deviceDiameter : ISQ::LengthValue;
        attribute deviceThickness : ISQ::LengthValue;
        attribute materialStiffness : Real;
        attribute surfaceArea : ISQ::AreaValue;
        
        port organSupportPort : SupportInterface;
        port tissueContactPort : TissueInterface;
        
        state operationalLifecycle {
            entry; then notInserted;
            
            state notInserted;
            
            transition insertionTransition
                first notInserted
                accept insertionCommand
                then inserted;
            
            state inserted {
                entry; then providingSupport;
                
                state providingSupport;
            }
            
            transition removalTransition
                first inserted
                accept removalCommand
                then notInserted;
        }
    }
    
    part def Bladder :> PelvicOrgan {
        attribute fillLevel : ISQ::VolumeValue;
    }
    
    part def Uterus :> PelvicOrgan;
    
    part def PelvicFloorMuscles {
        attribute muscleStrength : ISQ::ForceValue;
        attribute muscleTone : Real;
        
        port muscularSupport {
            out residualSupport : ISQ::ForceValue;
        }
    }
    
    action def EvaluateProlapseCondition {
        in prolapseStage : ProlapseStage;
        in organDisplacement : Displacement;
        out supportRequired : Boolean;
        out targetElevation : ISQ::LengthValue;
    }
    
    action def InsertDevice {
        in device : PessaryDevice;
        in tissue : VaginalTissue;
        out insertionSuccess : Boolean;
        out initialComfort : ComfortRating;
    }
    
    action def ApplyMechanicalSupport {
        in organWeight : ISQ::ForceValue;
        in deviceStiffness : Real;
        in contactArea : ISQ::AreaValue;
        out elevationForce : SupportForce;
        out organElevation : Displacement;
    }
    
    action def DistributePressure {
        in totalForce : SupportForce;
        in distributionArea : ISQ::AreaValue;
        out resultingPressure : ContactPressure;
        out tissueStrain : Real;
    }
    
    action def MaintainStability {
        in vaginalTension : ISQ::ForceValue;
        in deviceFriction : Real;
        in patientActivity : Real;
        out positionStable : Boolean;
        out migrationRisk : Real;
    }
    
    action def AssessComfort {
        in wearTime : ISQ::TimeValue;
        in tissueCondition : VaginalTissue;
        in pressureLevel : ContactPressure;
        out comfortLevel : ComfortRating;
        out adverseEffects : Boolean;
    }
    
    action def ProvidePelvicOrganSupport {
        in initialProlapseStage : ProlapseStage;
        in affectedOrgans : PelvicOrgan[1..*];
        out supportAchieved : Boolean;
        out finalOrganPosition : Displacement;
        
        first start;
        then action evaluate : EvaluateProlapseCondition {
            in prolapseStage = initialProlapseStage;
            in organDisplacement;
            out supportRequired;
            out targetElevation;
        }
        then decide;
            if evaluate.supportRequired then proceedWithInsertion;
            if not evaluate.supportRequired then skipIntervention;
        
        action proceedWithInsertion : InsertDevice {
            in device;
            in tissue;
            out insertionSuccess;
            out initialComfort;
        }
        then merge beginSupport;
        
        action skipIntervention;
        then done;
        
        merge beginSupport;
        then action applySupport : ApplyMechanicalSupport {
            in organWeight;
            in deviceStiffness;
            in contactArea;
            out elevationForce;
            out organElevation;
        }
        then action distributePressure : DistributePressure {
            in totalForce = applySupport.elevationForce;
            in distributionArea;
            out resultingPressure;
            out tissueStrain;
        }
        then action maintainStability : MaintainStability {
            in vaginalTension;
            in deviceFriction;
            in patientActivity;
            out positionStable;
            out migrationRisk;
        }
        then action assessComfort : AssessComfort {
            in wearTime;
            in tissueCondition;
            in pressureLevel = distributePressure.resultingPressure;
            out comfortLevel;
            out adverseEffects;
        }
        then decide;
            if assessComfort.comfortLevel.score >= 7.0 and maintainStability.positionStable and not assessComfort.adverseEffects 
                then beginSupport;
            if assessComfort.comfortLevel.score < 7.0 or not maintainStability.positionStable or assessComfort.adverseEffects 
                then done;
    }
    
    connection def OrganSupportConnection {
        end deviceEnd : PessaryDevice[1];
        end organEnd : PelvicOrgan[1..*];
    }
    
    connection def TissueContactConnection {
        end deviceEnd : PessaryDevice[1];
        end tissueEnd : VaginalTissue[1];
    }
    
    part pessaryMechanicalSupportSystem {
        part ringPessary : PessaryDevice {
            attribute :>> deviceDiameter = 70.0 [SI::mm];
            attribute :>> deviceThickness = 10.0 [SI::mm];
            attribute :>> materialStiffness = 0.8;
            attribute :>> surfaceArea = 0.0006 [SI::m^2];
        }
        
        part bladder : Bladder {
            attribute :>> normalPosition = 0.0 [SI::mm];
            attribute :>> currentPosition = -25.0 [SI::mm];
            attribute :>> organMass = 50.0 [SI::g];
            attribute :>> fillLevel = 300.0 [SI::ml];
        }
        
        part uterus : Uterus {
            attribute :>> normalPosition = 0.0 [SI::mm];
            attribute :>> currentPosition = -30.0 [SI::mm];
            attribute :>> organMass = 80.0 [SI::g];
        }
        
        part pelvicFloor : PelvicFloorMuscles {
            attribute :>> muscleStrength = 12.0 [SI::N];
            attribute :>> muscleTone = 0.5;
        }
        
        part vaginalWall : VaginalTissue {
            attribute :>> elasticity = 0.75;
            attribute :>> sensitivity = 0.6;
        }
        
        connection organSupport : OrganSupportConnection connect
            ringPessary to (bladder, uterus);
        
        connection tissueContact : TissueContactConnection connect
            ringPessary to vaginalWall;
        
        perform action supportFunction : ProvidePelvicOrganSupport {
            in initialProlapseStage;
            in affectedOrgans = (bladder, uterus);
            out supportAchieved;
            out finalOrganPosition;
        }
    }
    
    requirement def PessarySystemRequirement;
    
    requirement <'PSS-001'> primarySupportFunction : PessarySystemRequirement {
        doc /* The pessary system shall provide continuous mechanical support to prolapsed 
               pelvic organs by elevating and maintaining them in their anatomically correct 
               position through controlled force distribution. */
        
        subject system : pessaryMechanicalSupportSystem;
        
        assume constraint prolapseConditionExists {
            initialProlapseStage.severity >= 2 and initialProlapseStage.severity <= 4
        }
        
        require constraint adequateElevation {
            finalOrganPosition >= 20.0 [SI::mm]
        }
    }
    
    requirement <'PSS-002'> pressureSafetyRequirement : PessarySystemRequirement {
        doc /* The pessary shall distribute contact pressure uniformly to prevent tissue 
               damage, maintaining pressure below physiological safety thresholds. */
        
        subject device : PessaryDevice;
        
        require constraint safePressureLimit {
            device.organSupportPort.contactPressure < 45.0 [SI::kPa]
        }
    }
    
    requirement <'PSS-003'> comfortRequirement : PessarySystemRequirement {
        doc /* The pessary system shall maintain patient comfort at acceptable levels 
               during normal daily activities for extended wear periods. */
        
        subject system : pessaryMechanicalSupportSystem;
        
        require constraint minimumComfort {
            comfortLevel.score >= 7.0
        }
    }
    
    requirement <'PSS-004'> stabilityRequirement : PessarySystemRequirement {
        doc /* The pessary shall remain securely positioned during typical physical 
               activities with minimal risk of migration or expulsion. */
        
        subject device : PessaryDevice;
        
        require constraint positionRetention {
            positionStable = true and migrationRisk < 0.2
        }
    }
    
    requirement <'PSS-MAIN'> pessarySystemMainRequirement : PessarySystemRequirement {
        doc /* The pessary mechanical support system shall restore and maintain pelvic 
               organ position in patients with pelvic organ prolapse by providing 
               continuous, comfortable, and safe mechanical support. */
        
        subject system : pessaryMechanicalSupportSystem;
        
        require primarySupportFunction;
        require pressureSafetyRequirement;
        require comfortRequirement;
        require stabilityRequirement;
    }
}
