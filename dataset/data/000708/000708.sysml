package 'Neil Robertson Stretcher System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StretcherCommand;
    attribute def PatientCondition;
    attribute def EvacuationStatus;
    
    item def Patient {
        attribute bodyMass : MassValue;
        attribute isImmobilized : Boolean;
        attribute spinalInjury : Boolean;
    }
    
    part def CanvasShell {
        attribute material : String;
        attribute thickness : LengthValue;
        attribute tensileStrength : ForceValue;
    }
    
    part def WoodenSlats {
        attribute numberOfSlats : Integer;
        attribute slatLength : LengthValue;
        attribute slatWidth : LengthValue;
        attribute woodType : String;
    }
    
    part def RestraintStraps {
        attribute numberOfStraps : Integer;
        attribute strapWidth : LengthValue;
        attribute breakingStrength : ForceValue;
        attribute material : String;
    }
    
    part def LiftingBridles {
        attribute numberOfBridles : Integer;
        attribute attachmentPoints : Integer;
        attribute maxLoadRating : ForceValue;
    }
    
    port def PatientSupportInterface {
        attribute supportArea : AreaValue;
        attribute pressureDistribution : PressureValue;
    }
    
    port def LiftingInterface {
        attribute liftingForce : ForceValue;
        attribute liftingAngle : PlaneAngleValue;
    }
    
    item def NeilRobertsonStretcher {
        attribute overallLength : LengthValue;
        attribute overallWidth : LengthValue;
        attribute totalWeight : MassValue;
        attribute maxPatientCapacity : MassValue;
        
        part shell : CanvasShell {
            attribute material = "Heavy-duty canvas";
            attribute thickness = 0.003[SI::m];
            attribute tensileStrength = 3000.0[SI::N];
        }
        
        part slats : WoodenSlats {
            attribute numberOfSlats = 6;
            attribute slatLength = 1.98[SI::m];
            attribute slatWidth = 0.05[SI::m];
            attribute woodType = "Ash wood";
        }
        
        part straps : RestraintStraps {
            attribute numberOfStraps = 7;
            attribute strapWidth = 0.05[SI::m];
            attribute breakingStrength = 2200.0[SI::N];
            attribute material = "Nylon webbing";
        }
        
        part bridles : LiftingBridles {
            attribute numberOfBridles = 4;
            attribute attachmentPoints = 6;
            attribute maxLoadRating = 2500.0[SI::N];
        }
        
        port patientInterface : PatientSupportInterface;
        port liftingInterface[4] : LiftingInterface;
    }
    
    action def PositionPatientOnStretcher {
        in patient : Patient;
        in stretcher : NeilRobertsonStretcher;
        out positioned : Boolean;
    }
    
    action def ApplyBodyStraps {
        in patient : Patient;
        in numberOfStraps : Integer;
        out strapsApplied : Boolean;
    }
    
    action def SecureHeadAndNeck {
        in patient : Patient;
        out headSecured : Boolean;
    }
    
    action def VerifyImmobilization {
        in patient : Patient;
        in straps : RestraintStraps;
        out immobilizationComplete : Boolean;
    }
    
    action def AttachLiftingBridles {
        in stretcher : NeilRobertsonStretcher;
        out bridlesAttached : Boolean;
    }
    
    action def PerformVerticalLift {
        in stretcher : NeilRobertsonStretcher;
        in liftHeight : LengthValue;
        out liftComplete : Boolean;
    }
    
    action def NavigateConfinedPassage {
        in stretcher : NeilRobertsonStretcher;
        in passageWidth : LengthValue;
        out navigationComplete : Boolean;
    }
    
    action def RescueAndEvacuatePatient {
        in patient : Patient;
        in stretcher : NeilRobertsonStretcher;
        in evacuationCommand : StretcherCommand;
        out evacuationStatus : EvacuationStatus;
        
        first start;
        
        then action positionPatient : PositionPatientOnStretcher {
            in patient = RescueAndEvacuatePatient::patient;
            in stretcher = RescueAndEvacuatePatient::stretcher;
            out positioned;
        }
        
        then action applyStraps : ApplyBodyStraps {
            in patient = RescueAndEvacuatePatient::patient;
            in numberOfStraps = 7;
            out strapsApplied;
        }
        
        then action secureHead : SecureHeadAndNeck {
            in patient = RescueAndEvacuatePatient::patient;
            out headSecured;
        }
        
        then merge verificationPoint;
        
        then action verifyImmobilization : VerifyImmobilization {
            in patient = RescueAndEvacuatePatient::patient;
            in straps = stretcher.straps;
            out immobilizationComplete;
        }
        
        then decide immobilizationCheck;
            if verifyImmobilization.immobilizationComplete then attachBridles;
            if not verifyImmobilization.immobilizationComplete then verificationPoint;
        
        action attachBridles : AttachLiftingBridles {
            in stretcher = RescueAndEvacuatePatient::stretcher;
            out bridlesAttached;
        }
        
        then action performLift : PerformVerticalLift {
            in stretcher = RescueAndEvacuatePatient::stretcher;
            in liftHeight;
            out liftComplete;
        }
        
        then action navigatePassage : NavigateConfinedPassage {
            in stretcher = RescueAndEvacuatePatient::stretcher;
            in passageWidth;
            out navigationComplete;
        }
        
        then assign evacuationStatus := EvacuationStatus;
        then done;
    }
    
    state def StretcherOperationalStates {
        entry; then stowed;
        
        state stowed;
        
        transition stowed_to_deployment
            first stowed
            accept deployCommand : StretcherCommand
            then deployment;
        
        state deployment {
            entry; then positioning;
            
            state positioning;
            
            transition positioning_to_securing
                first positioning
                then securing;
            
            state securing {
                entry; then applyingStraps;
                
                state applyingStraps;
                
                transition applyingStraps_to_securingHead
                    first applyingStraps
                    then securingHead;
                
                state securingHead;
                
                transition securingHead_to_verifying
                    first securingHead
                    then verifying;
                
                state verifying;
                
                transition verifying_to_secured
                    first verifying
                    then secured;
                
                state secured;
            }
        }
        
        transition deployment_to_extraction
            first deployment.securing.secured
            then extraction;
        
        state extraction {
            entry; then attachingBridles;
            
            state attachingBridles;
            
            transition attachingBridles_to_lifting
                first attachingBridles
                then lifting;
            
            state lifting;
            
            transition lifting_to_navigating
                first lifting
                then navigating;
            
            state navigating;
            
            transition navigating_to_evacuated
                first navigating
                then evacuated;
            
            state evacuated;
        }
        
        transition extraction_to_stowed
            first extraction.evacuated
            then stowed;
    }
    
    part robertsonStretcherSystem : NeilRobertsonStretcher {
        attribute overallLength = 1.98[SI::m];
        attribute overallWidth = 0.46[SI::m];
        attribute totalWeight = 8.2[SI::kg];
        attribute maxPatientCapacity = 182.0[SI::kg];
        
        perform action evacuatePatient[*] ordered : RescueAndEvacuatePatient;
        
        exhibit state operationalStates : StretcherOperationalStates;
    }
    
    requirement def SpinalImmobilizationRequirement {
        doc /* The stretcher shall provide rigid spinal immobilization to prevent secondary injury during patient extraction and transport. */
        
        subject stretcher : NeilRobertsonStretcher;
        
        require constraint {
            stretcher.slats.numberOfSlats >= 6
        }
        
        require constraint {
            stretcher.straps.numberOfStraps >= 7
        }
    }
    
    requirement def LoadCapacityRequirement {
        doc /* The stretcher shall safely support patients with body mass up to 182 kg without structural failure. */
        
        subject stretcher : NeilRobertsonStretcher;
        
        require constraint {
            stretcher.maxPatientCapacity >= 182.0[SI::kg]
        }
        
        require constraint {
            stretcher.bridles.maxLoadRating >= 2500.0[SI::N]
        }
    }
    
    requirement def ConfinedSpaceNavigationRequirement {
        doc /* The stretcher shall enable patient evacuation through confined vertical and horizontal passages including ship hatches, industrial tanks, and narrow stairwells. */
        
        subject stretcher : NeilRobertsonStretcher;
        
        require constraint {
            stretcher.overallWidth <= 0.5[SI::m]
        }
    }
    
    requirement def VerticalExtractionRequirement {
        doc /* The stretcher shall enable safe vertical lifting and lowering operations through multiple attachment points. */
        
        subject stretcher : NeilRobertsonStretcher;
        
        require constraint {
            stretcher.bridles.attachmentPoints >= 6
        }
    }
    
    requirement def PatientRestraintRequirement {
        doc /* The stretcher shall securely restrain the patient's torso, head, neck, and limbs to prevent movement during complex extraction maneuvers. */
        
        subject stretcher : NeilRobertsonStretcher;
        
        require constraint {
            stretcher.straps.breakingStrength >= 2000.0[SI::N]
        }
    }
    
    requirement <'NRS-MISSION-001'> primaryMissionRequirement {
        doc /* The Neil Robertson Stretcher system shall safely extract and evacuate injured or incapacitated patients from confined spaces by providing rigid spinal support, complete body immobilization, and enabling vertical and horizontal transport through restricted passages. */
        
        assume constraint injuredPatientInConfinedSpace {
            doc /* An injured patient requiring spinal immobilization is located in a confined space requiring vertical or complex horizontal extraction. */
        }
        
        require spinalImmobilization : SpinalImmobilizationRequirement;
        require loadCapacity : LoadCapacityRequirement;
        require confinedSpaceNavigation : ConfinedSpaceNavigationRequirement;
        require verticalExtraction : VerticalExtractionRequirement;
        require patientRestraint : PatientRestraintRequirement;
    }
}
