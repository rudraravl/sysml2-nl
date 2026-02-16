package MedicalGownSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def ProtectionLevelEnum {
        level1 {
            doc /* Minimal risk: basic care, standard isolation, visitor cover gown */
        }
        level2 {
            doc /* Low risk: blood draw, suturing, ICU, pathology lab */
        }
        level3 {
            doc /* Moderate risk: arterial blood draw, IV insertion, emergency room */
        }
        level4 {
            doc /* High risk: long fluid-intense procedures, surgery */
        }
    }
    
    enum def GownStateEnum {
        packaged;
        donned;
        inUse;
        contaminated;
        doffed;
        disposed;
    }
    
    attribute def BarrierEfficiencyValue :> Real;
    
    item def Contaminant {
        attribute particleSize : LengthValue;
        attribute concentration : Real;
    }
    
    item def BodyFluid :> Contaminant {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
    }
    
    item def Pathogen :> Contaminant {
        attribute viralLoad : Real;
        attribute transmissionRisk : Real;
    }
    
    port def BarrierInterface {
        in contaminantExposure : Contaminant[0..*];
        out penetrationLevel : Real;
    }
    
    part def FabricLayer {
        attribute barrierEfficiency : BarrierEfficiencyValue;
        attribute thickness : LengthValue;
        attribute fluidResistance : PressureValue;
        attribute breathability : Real;
        port outerSurface : BarrierInterface;
        port innerSurface : BarrierInterface;
    }
    
    part def Sleeve {
        attribute length : LengthValue;
        attribute circumference : LengthValue;
        part fabricSection : FabricLayer {
            attribute :>> barrierEfficiency;
            attribute :>> thickness;
            port :>> outerSurface;
        }
        part cuff {
            attribute elasticTension : ForceValue;
            attribute diameter : LengthValue;
        }
    }
    
    part def TorsoPanel {
        attribute coverageArea : AreaValue;
        attribute overlapWidth : LengthValue;
        part fabricSection : FabricLayer {
            attribute :>> barrierEfficiency;
            attribute :>> fluidResistance;
            port :>> outerSurface;
        }
    }
    
    part def Closure {
        attribute tensileStrength : ForceValue;
        attribute securityLevel : Real;
    }
    
    part def TieString :> Closure {
        attribute length : LengthValue;
        attribute breakStrength : ForceValue;
    }
    
    part def MedicalGown {
        attribute protectionLevel : ProtectionLevelEnum;
        attribute totalCoverageArea : AreaValue;
        attribute totalMass : MassValue;
        attribute overallBarrierEfficiency : BarrierEfficiencyValue;
        attribute currentState : GownStateEnum;
        
        part frontPanel : TorsoPanel {
            attribute :>> coverageArea;
            attribute :>> overlapWidth;
            part :>> fabricSection {
                attribute :>> barrierEfficiency;
                attribute :>> fluidResistance;
            }
        }
        
        part backPanel : TorsoPanel {
            attribute :>> coverageArea;
            part :>> fabricSection {
                attribute :>> barrierEfficiency;
            }
        }
        
        part leftSleeve : Sleeve {
            attribute :>> length;
            part :>> fabricSection {
                attribute :>> barrierEfficiency;
            }
            part :>> cuff {
                attribute :>> elasticTension;
            }
        }
        
        part rightSleeve : Sleeve {
            attribute :>> length;
            part :>> fabricSection {
                attribute :>> barrierEfficiency;
            }
            part :>> cuff {
                attribute :>> elasticTension;
            }
        }
        
        part neckTie : TieString {
            attribute :>> length;
            attribute :>> breakStrength;
        }
        
        part waistTieLeft : TieString {
            attribute :>> length;
            attribute :>> breakStrength;
        }
        
        part waistTieRight : TieString {
            attribute :>> length;
            attribute :>> breakStrength;
        }
        
        connection leftSleeveAttachment {
            end panelEdge : frontPanel.fabricSection.outerSurface;
            end sleeveEdge : leftSleeve.fabricSection.outerSurface;
        }
        
        connection rightSleeveAttachment {
            end panelEdge : frontPanel.fabricSection.outerSurface;
            end sleeveEdge : rightSleeve.fabricSection.outerSurface;
        }
        
        assert constraint totalCoverageConstraint {
            totalCoverageArea == frontPanel.coverageArea + backPanel.coverageArea
        }
    }
    
    action def DonGown {
        in gown : MedicalGown;
        out donningComplete : Boolean;
        
        first start;
        then action unfoldGown {
            doc /* Remove gown from sterile packaging and unfold completely */
        }
        then action slideArmsIntoSleeves {
            doc /* Insert both arms through sleeve openings */
        }
        then action secureNeckClosure {
            doc /* Fasten neck tie behind neck */
        }
        then action wrapBackPanels {
            doc /* Overlap back panels to ensure full coverage */
        }
        then action tieWaistStrings {
            doc /* Secure waist ties at back, ensuring snug fit */
        }
        then action adjustCuffs {
            doc /* Position elastic cuffs at wrists */
        }
        then done;
    }
    
    action def DoffGown {
        in gown : MedicalGown;
        out doffingComplete : Boolean;
        
        first start;
        then action untieWaist {
            doc /* Release waist ties carefully */
        }
        then action untieNeck {
            doc /* Release neck tie */
        }
        then action pullAwayFromBody {
            doc /* Pull gown away from shoulders and body */
        }
        then action rollContaminatedSideInward {
            doc /* Roll gown with contaminated outer surface facing inward */
        }
        then action disposeInWasteContainer {
            doc /* Place rolled gown in appropriate biohazard waste receptacle */
        }
        then done;
    }
    
    action def ProvideBarrierProtection {
        in contaminantSource : Contaminant;
        in gown : MedicalGown;
        out protectionEffective : Boolean;
        
        first start;
        then merge continuousMonitoring;
        
        then action detectExposure {
            in exposureEvent : Contaminant;
            out exposureDetected : Boolean;
        }
        
        then decide;
            if detectExposure.exposureDetected then blockPenetration;
            if not detectExposure.exposureDetected then continuousMonitoring;
        
        action blockPenetration {
            in barrierEff = gown.overallBarrierEfficiency;
            out blocked : Boolean;
            doc /* Fabric barrier prevents contaminant from reaching wearer skin */
        }
        
        then action checkIntegrity {
            in blocked = blockPenetration.blocked;
            out integrityMaintained : Boolean;
        }
        
        then decide;
            if checkIntegrity.integrityMaintained then continuousMonitoring;
            if not checkIntegrity.integrityMaintained then signalCompromise;
        
        action signalCompromise {
            doc /* Indicate barrier failure requiring gown replacement */
        }
        
        then done;
    }
    
    state def GownLifecycle {
        in out currentState : GownStateEnum;
        
        entry; then packagedState;
        
        state packagedState {
            doc /* Gown is sterile and sealed in packaging */
            entry assign currentState = GownStateEnum::packaged;
        }
        
        transition packaged_to_donned
            first packagedState
            accept DonGown
            then donnedState;
        
        state donnedState {
            doc /* Gown is worn by healthcare worker */
            entry assign currentState = GownStateEnum::donned;
        }
        
        transition donned_to_inUse
            first donnedState
            accept at beginProcedure
            then inUseState;
        
        state inUseState {
            doc /* Gown is actively protecting during patient care */
            entry assign currentState = GownStateEnum::inUse;
            
            state cleanProtection {
                doc /* No contaminant exposure yet */
            }
            
            transition clean_to_exposed
                first cleanProtection
                accept at contaminantContact
                then exposedProtection;
            
            state exposedProtection {
                doc /* Contaminant contact occurred, barrier active */
            }
            
            transition exposed_to_contaminated
                first exposedProtection
                if barrierSaturated or barrierBreach
                then contaminatedProtection;
            
            state contaminatedProtection {
                doc /* Barrier compromised or saturated, replacement needed */
                entry assign currentState = GownStateEnum::contaminated;
            }
        }
        
        transition inUse_to_doffed
            first inUseState
            accept DoffGown
            then doffedState;
        
        state doffedState {
            doc /* Gown removed from wearer */
            entry assign currentState = GownStateEnum::doffed;
        }
        
        transition doffed_to_disposed
            first doffedState
            accept at disposalAction
            then disposedState;
        
        state disposedState {
            doc /* Gown placed in biohazard waste */
            entry assign currentState = GownStateEnum::disposed;
        }
    }
    
    part medicalGownSystem {
        part gown : MedicalGown {
            attribute :>> protectionLevel = ProtectionLevelEnum::level3;
            attribute :>> totalCoverageArea = 1.6 [SI::m^2];
            attribute :>> totalMass = 70.0 [SI::g];
            attribute :>> overallBarrierEfficiency = 0.94;
            
            part :>> frontPanel {
                attribute :>> coverageArea = 0.5 [SI::m^2];
                attribute :>> overlapWidth = 0.15 [SI::m];
                part :>> fabricSection {
                    attribute :>> barrierEfficiency = 0.96;
                    attribute :>> thickness = 0.3 [SI::mm];
                    attribute :>> fluidResistance = 22.0 [SI::kPa];
                    attribute :>> breathability = 0.75;
                }
            }
            
            part :>> backPanel {
                attribute :>> coverageArea = 0.6 [SI::m^2];
                part :>> fabricSection {
                    attribute :>> barrierEfficiency = 0.92;
                    attribute :>> thickness = 0.25 [SI::mm];
                    attribute :>> breathability = 0.80;
                }
            }
            
            part :>> leftSleeve {
                attribute :>> length = 0.58 [SI::m];
                attribute :>> circumference = 0.35 [SI::m];
                part :>> fabricSection {
                    attribute :>> barrierEfficiency = 0.94;
                    attribute :>> thickness = 0.28 [SI::mm];
                }
                part :>> cuff {
                    attribute :>> elasticTension = 2.5 [SI::N];
                    attribute :>> diameter = 0.09 [SI::m];
                }
            }
            
            part :>> rightSleeve {
                attribute :>> length = 0.58 [SI::m];
                attribute :>> circumference = 0.35 [SI::m];
                part :>> fabricSection {
                    attribute :>> barrierEfficiency = 0.94;
                    attribute :>> thickness = 0.28 [SI::mm];
                }
                part :>> cuff {
                    attribute :>> elasticTension = 2.5 [SI::N];
                    attribute :>> diameter = 0.09 [SI::m];
                }
            }
            
            part :>> neckTie {
                attribute :>> length = 0.40 [SI::m];
                attribute :>> breakStrength = 45.0 [SI::N];
                attribute :>> securityLevel = 0.85;
            }
            
            part :>> waistTieLeft {
                attribute :>> length = 0.75 [SI::m];
                attribute :>> breakStrength = 50.0 [SI::N];
                attribute :>> securityLevel = 0.90;
            }
            
            part :>> waistTieRight {
                attribute :>> length = 0.75 [SI::m];
                attribute :>> breakStrength = 50.0 [SI::N];
                attribute :>> securityLevel = 0.90;
            }
        }
        
        perform action primaryFunction : ProvideBarrierProtection {
            in contaminantSource;
            in gown = medicalGownSystem.gown;
            out protectionEffective;
        }
        
        exhibit state lifecycle : GownLifecycle {
            in out currentState = gown.currentState;
        }
    }
    
    requirement <'REQ-MG-100'> primaryFunctionRequirement {
        doc /* The medical gown system shall provide an effective protective barrier 
             * between the healthcare worker and the clinical environment, preventing 
             * transmission of fluids and pathogens during patient care activities 
             * while maintaining adequate coverage, comfort, and ease of donning/doffing.
             */
        subject gown :> medicalGownSystem.gown;
    }
    
    requirement <'REQ-MG-101'> barrierEfficiencyRequirement {
        doc /* The gown shall maintain a minimum barrier efficiency of 90% 
             * at critical protection zones (front panel and sleeves).
             */
        subject gown :> medicalGownSystem.gown;
        
        assert constraint {
            gown.frontPanel.fabricSection.barrierEfficiency >= 0.90 and
            gown.leftSleeve.fabricSection.barrierEfficiency >= 0.90 and
            gown.rightSleeve.fabricSection.barrierEfficiency >= 0.90
        }
    }
    
    requirement <'REQ-MG-102'> fluidResistanceRequirement {
        doc /* The front panel shall resist fluid penetration under pressure 
             * of at least 20 kPa to protect against splash and spray.
             */
        subject gown :> medicalGownSystem.gown;
        
        assert constraint {
            gown.frontPanel.fabricSection.fluidResistance >= 20.0 [SI::kPa]
        }
    }
    
    requirement <'REQ-MG-103'> coverageRequirement {
        doc /* The gown shall provide minimum body coverage of 1.5 m² 
             * from neck to mid-thigh and full arm coverage.
             */
        subject gown :> medicalGownSystem.gown;
        
        assert constraint {
            gown.totalCoverageArea >= 1.5 [SI::m^2] and
            gown.leftSleeve.length >= 0.55 [SI::m] and
            gown.rightSleeve.length >= 0.55 [SI::m]
        }
    }
    
    requirement <'REQ-MG-104'> closureSecurityRequirement {
        doc /* Neck and waist closures shall provide secure fastening 
             * with minimum tensile strength of 40 N.
             */
        subject gown :> medicalGownSystem.gown;
        
        assert constraint {
            gown.neckTie.breakStrength >= 40.0 [SI::N] and
            gown.waistTieLeft.breakStrength >= 40.0 [SI::N] and
            gown.waistTieRight.breakStrength >= 40.0 [SI::N]
        }
    }
    
    requirement <'REQ-MG-105'> singleUseRequirement {
        doc /* The gown shall be designed for single use with proper disposal 
             * after contamination to prevent cross-contamination.
             */
        subject gown :> medicalGownSystem.gown;
    }
    
    requirement <'REQ-MG-106'> cuffSecurityRequirement {
        doc /* Elastic cuffs shall maintain secure fit at wrists 
             * with minimum tension of 2.0 N.
             */
        subject gown :> medicalGownSystem.gown;
        
        assert constraint {
            gown.leftSleeve.cuff.elasticTension >= 2.0 [SI::N] and
            gown.rightSleeve.cuff.elasticTension >= 2.0 [SI::N]
        }
    }
    
    satisfy primaryFunctionRequirement by medicalGownSystem;
    satisfy barrierEfficiencyRequirement by medicalGownSystem.gown;
    satisfy fluidResistanceRequirement by medicalGownSystem.gown.frontPanel;
    satisfy coverageRequirement by medicalGownSystem.gown;
    satisfy closureSecurityRequirement by medicalGownSystem.gown;
    satisfy singleUseRequirement by medicalGownSystem.lifecycle;
    satisfy cuffSecurityRequirement by medicalGownSystem.gown;
}
