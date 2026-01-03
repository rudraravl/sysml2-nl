package InadineWoundDressingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IodineConcentration :> Real {
        doc /* Concentration of povidone-iodine in percentage */
    }
    
    attribute def AbsorptionCapacity :> VolumeValue {
        doc /* Maximum volume of exudate that can be absorbed */
    }
    
    attribute def WoundArea :> AreaValue;
    attribute def ExudateVolume :> VolumeValue;
    attribute def ContactDuration :> TimeValue;
    attribute def AntimicrobialEffectiveness :> Real;
    attribute def VolumeFlowRate :> Real;
    
    item def WoundExudate {
        attribute volume : VolumeValue;
        attribute viscosity : Real;
        attribute bacterialLoad : Real;
    }
    
    item def PovidoneIodine {
        attribute concentration : IodineConcentration;
        attribute mass : MassValue;
        attribute releaseRate : Real;
    }
    
    item def ParaffinGauze {
        attribute meshSize : LengthValue;
        attribute porosity : Real;
        attribute absorptionCapacity : AbsorptionCapacity;
    }
    
    port def WoundInterfacePort {
        in item exudate : WoundExudate;
        out item iodine : PovidoneIodine;
    }
    
    attribute def ApplyDressingSignal;
    attribute def RemoveDressingSignal;
    attribute def SaturationAlertSignal;
    
    port def DressingChangePort {
        in applySignal : ApplyDressingSignal;
        in removeSignal : RemoveDressingSignal;
        out saturationSignal : SaturationAlertSignal;
    }
    
    part def InadineDressingPad {
        attribute iodineContent : IodineConcentration := 10.0;
        attribute padArea : AreaValue;
        attribute currentAbsorption : VolumeValue := 0.0 [SI::mL];
        attribute maxAbsorption : AbsorptionCapacity;
        attribute applicationTime : TimeValue := 0.0 [SI::h];
        
        port woundInterface : WoundInterfacePort;
        port changeControl : DressingChangePort;
        
        part gauzeBase : ParaffinGauze {
            attribute :>> meshSize = 1.0 [SI::mm];
            attribute :>> porosity = 0.65;
        }
        
        part iodineCompound : PovidoneIodine {
            attribute :>> concentration = 10.0;
        }
        
        action absorbExudate {
            in exudateInput : WoundExudate;
            in currentLevel : VolumeValue;
            in capacity : AbsorptionCapacity;
            out newLevel : VolumeValue;
            out isSaturated : Boolean;
        }
        
        action releaseIodine {
            in contactTime : TimeValue;
            in iodineReservoir : PovidoneIodine;
            out iodineReleased : PovidoneIodine;
            out antimicrobialActivity : Real;
        }
    }
    
    part def WoundBed {
        attribute area : WoundArea;
        attribute depth : LengthValue;
        attribute exudateProduction : VolumeFlowRate;
        attribute bacterialColonization : Real;
        attribute healingStage : String;
        
        port surface : WoundInterfacePort;
        
        action produceExudate {
            in productionRate : VolumeFlowRate;
            in duration : TimeValue;
            out exudate : WoundExudate;
        }
        
        action respondToTreatment {
            in iodineExposure : PovidoneIodine;
            in exposureDuration : TimeValue;
            out bacterialReduction : Real;
            out healingProgress : Real;
        }
    }
    
    part def SaturationMonitor {
        attribute saturationThreshold : Real := 0.85;
        attribute checkInterval : TimeValue;
        
        action monitorAbsorption {
            in currentAbsorption : VolumeValue;
            in maxCapacity : AbsorptionCapacity;
            out saturationLevel : Real;
            out alertRequired : Boolean;
        }
    }
    
    part def ApplicationController {
        attribute recommendedChangeInterval : TimeValue := 24.0 [SI::h];
        attribute currentApplicationTime : TimeValue := 0.0 [SI::h];
        
        action determineChangeNeed {
            in saturationLevel : Real;
            in applicationDuration : TimeValue;
            in maxDuration : TimeValue;
            out changeRequired : Boolean;
            out changeReason : String;
        }
    }
    
    state def DressingLifecycle {
        in applySignal : ApplyDressingSignal;
        in removeSignal : RemoveDressingSignal;
        in saturationSignal : SaturationAlertSignal;
        
        entry; then stored;
        
        state stored {
            doc /* Dressing is sterile and packaged */
            accept applySignal;
            then applied;
        }
        
        state applied {
            entry action {
                doc /* Initialize absorption and iodine release */
            }
            
            state activeTreatment;
            
            accept saturationSignal;
            then saturated;
            
            accept removeSignal;
            then removed;
        }
        
        state saturated {
            doc /* Dressing has reached absorption capacity */
            entry action {
                doc /* Signal for dressing change */
            }
            accept removeSignal;
            then removed;
        }
        
        state removed {
            doc /* Dressing has been removed from wound */
        }
    }
    
    action def ManageWoundCare {
        in attribute exudateProfile : VolumeFlowRate[*];
        in attribute dressingCapacity : AbsorptionCapacity;
        in attribute maxContactTime : TimeValue;
        in attribute samplingInterval : TimeValue;
        out attribute absorptionHistory : VolumeValue[*] := ();
        out attribute iodineReleaseHistory : Real[*] := ();
        
        private attribute totalAbsorbed : VolumeValue := 0.0 [SI::mL];
        private attribute elapsedTime : TimeValue := 0.0 [SI::h];
        
        first start;
        then merge continueTreatment;
        
        then action assessWound {
            in exudateRate : VolumeFlowRate;
            out exudateVolume : VolumeValue;
        }
        
        then action absorb {
            in exudateAmount : VolumeValue;
            in currentAbsorbed : VolumeValue;
            in capacity : AbsorptionCapacity;
            out newAbsorbed : VolumeValue;
        }
        
        then assign totalAbsorbed := absorb.newAbsorbed;
        
        then action release {
            in contactTime : TimeValue;
            out iodineActivity : Real;
        }
        
        then assign elapsedTime := elapsedTime + samplingInterval;
        then assign absorptionHistory := absorptionHistory->including(totalAbsorbed);
        then assign iodineReleaseHistory := iodineReleaseHistory->including(release.iodineActivity);
        
        then decide;
            if totalAbsorbed >= dressingCapacity then signalChange;
            if elapsedTime >= maxContactTime then signalChange;
            else continueTreatment;
        
        action signalChange {
            doc /* Alert for dressing replacement */
        }
        then done;
    }
    
    action def TreatWoundWithInadine {
        in untreatedWound : WoundBed;
        in dressingPad : InadineDressingPad;
        out treatedWound : WoundBed;
        out antimicrobialEffect : AntimicrobialEffectiveness;
        
        first start;
        
        then action applyDressing {
            in wound : WoundBed;
            in dressing : InadineDressingPad;
            out appliedSystem;
        }
        
        then action maintainContact {
            in contactDuration : TimeValue := 24.0 [SI::h];
            
            action absorbExudate {
                in exudate : WoundExudate;
                out absorbedVolume : VolumeValue;
            }
            
            flow absorbExudate.exudate to releaseAntimicrobial.trigger;
            
            action releaseAntimicrobial {
                in trigger;
                out iodineDelivered : PovidoneIodine;
            }
            
            flow releaseAntimicrobial.iodineDelivered to killBacteria.iodine;
            
            action killBacteria {
                in iodine : PovidoneIodine;
                out bacterialReduction : Real;
            }
        }
        
        then action evaluateHealing {
            in bacterialReduction : Real;
            out healingRate : Real;
        }
        
        then assign antimicrobialEffect := evaluateHealing.healingRate;
        then done;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The Inadine dressing system shall provide sustained antimicrobial protection 
            to wounds while managing exudate through absorption.
        */
        
        require constraint iodineDelivery {
            doc /* The dressing shall maintain continuous release of povidone-iodine at therapeutic levels */
        }
        
        require constraint exudateManagement {
            doc /* The dressing shall absorb wound exudate without maceration of surrounding tissue */
        }
        
        require constraint antimicrobialEfficacy {
            doc /* The dressing shall achieve minimum 99% reduction in bacterial load within 24 hours */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall maintain effective wound treatment performance */
        
        require constraint absorptionCapacity {
            doc /* The dressing shall absorb minimum 50 mL of exudate per 10x10 cm pad */
        }
        
        require constraint iodineConcentration {
            doc /* The dressing shall contain 10% povidone-iodine uniformly distributed */
        }
        
        require constraint wearTime {
            doc /* The dressing shall remain effective for up to 24 hours of continuous wear */
        }
        
        require constraint conformability {
            doc /* The dressing shall conform to wound contours without causing pressure */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall ensure patient safety during use */
        
        require constraint biocompatibility {
            doc /* All materials shall be biocompatible and non-cytotoxic */
        }
        
        require constraint iodineAllergy {
            doc /* The system shall include warnings for iodine-sensitive patients */
        }
        
        require constraint sterility {
            doc /* The dressing shall maintain sterility until application */
        }
    }
    
    part def InadineWoundTreatmentSystem;
    
    part inadineWoundTreatmentSystem : InadineWoundTreatmentSystem {
        doc /* 
            This system describes an Inadine-based wound dressing designed for the 
            management of acute and chronic wounds requiring antimicrobial protection.
            
            The primary function is to provide a dual-action therapeutic approach: 
            delivering sustained antimicrobial activity through controlled release of 
            povidone-iodine while simultaneously managing wound exudate through absorption 
            into a paraffin-impregnated gauze matrix.
            
            The system operates through continuous interaction between the dressing and 
            the wound bed. As wound exudate contacts the dressing, it activates the 
            release of povidone-iodine, which provides broad-spectrum antimicrobial 
            coverage against bacteria, fungi, and some viruses. The paraffin gauze base 
            prevents the dressing from adhering to the wound bed, facilitating atraumatic 
            removal while maintaining a moist wound healing environment.
            
            The dressing continuously absorbs exudate throughout its wear time, with 
            monitoring systems tracking saturation levels. When absorption capacity is 
            reached or the recommended wear time expires, the system signals for dressing 
            replacement to maintain optimal wound healing conditions and prevent 
            complications such as maceration or infection.
        */
        
        part dressing : InadineDressingPad {
            attribute :>> padArea = 100.0 [SI::'cm^2'];
            attribute :>> maxAbsorption = 50.0 [SI::mL];
        }
        
        part wound : WoundBed {
            attribute :>> area = 25.0 [SI::'cm^2'];
            attribute :>> depth = 2.0 [SI::mm];
            attribute :>> exudateProduction = 2.0;
        }
        
        part monitor : SaturationMonitor {
            attribute :>> checkInterval = 1.0 [SI::h];
        }
        
        part controller : ApplicationController {
            attribute :>> recommendedChangeInterval = 24.0 [SI::h];
        }
        
        port dressingInterface;
        port controlInterface;
        
        connect dressing.woundInterface to wound.surface;
        
        exhibit state lifecycle : DressingLifecycle;
        
        perform action treatmentCycle : ManageWoundCare {
            in exudateProfile = (2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0);
            in dressingCapacity = dressing.maxAbsorption;
            in maxContactTime = controller.recommendedChangeInterval;
            in samplingInterval = monitor.checkInterval;
            out absorptionHistory;
            out iodineReleaseHistory;
        }
        
        satisfy primaryFunction : PrimaryFunctionRequirement;
        satisfy performance : PerformanceRequirement;
        satisfy safety : SafetyRequirement;
    }
}
