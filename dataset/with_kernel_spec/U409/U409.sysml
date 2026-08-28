package 'Syrette Model' {
    private import ScalarValues::*;
    private import SI::*;
    
    value type DoseVolume :> Real;
    value type LengthValue :> Real;
    value type NeedleGauge :> Integer;
    value type MassPerVolume :> Real;
    
    item def Medication {
        attribute name : String;
        attribute concentration : MassPerVolume;
    }
    
    port def MedicationFlowPort {
        in item med : Medication;
        out attribute flowRate : DoseVolume;
    }
    
    port def PatientInjectionPort {
        in item med : Medication;
        in attribute deliveredVolume : DoseVolume;
    }
    
    action def RemoveCap;
    action def InsertNeedle;
    action def PressPlunger;
    action def DeliverMedication {
        in item medication : Medication;
        in attribute dose : DoseVolume;
        out attribute deliveredVolume : DoseVolume;
    }
    action def DisposeDevice;
    
    state def SyretteOperation {
        entry; then sealed;
        
        state sealed {
            doc /* Device is sterile, cap in place, ready for storage. */
            accept RemoveCap then ready;
        }
        
        state ready {
            doc /* Cap removed, needle exposed, awaiting insertion. */
            accept InsertNeedle then delivering;
        }
        
        state delivering {
            doc /* Plunger pressed, medication flowing into patient. */
            accept DeliverMedication then empty;
        }
        
        state empty {
            doc /* All medication delivered; device to be disposed. */
            accept DisposeDevice then done;
        }
        
        state done;
    }
    
    requirement def SterilityRequirement {
        doc /* The Syrette shall maintain sterility of the needle and medication until the safety cap is removed. */
        subject syrette : Syrette;
        require constraint { syrette.isSterile == true }
    }
    
    requirement def DoseAccuracyRequirement {
        doc /* The Syrette shall deliver the full pre-filled dose volume within a tolerance of ±5%. */
        subject syrette : Syrette;
        attribute targetDose : DoseVolume;
        attribute deliveredDose : DoseVolume;
        require constraint { deliveredDose >= 0.95 * targetDose and deliveredDose <= 1.05 * targetDose }
    }
    
    requirement def NeedleProtectionRequirement {
        doc /* The safety cap shall fully cover the needle to prevent accidental injury prior to use. */
        subject cap : SafetyCap;
        subject needle : Needle;
        require constraint { cap.coversNeedle == true }
    }
    
    requirement def SingleUseRequirement {
        doc /* The Syrette shall be a single-use device and shall not be reusable after medication delivery. */
        subject syrette : Syrette;
        require constraint { syrette.isSingleUse == true }
    }
    
    part def SafetyCap {
        attribute material : String = "Medical-grade plastic";
        attribute coversNeedle : Boolean;
    }
    
    part def Needle {
        attribute length : LengthValue;
        attribute gauge : NeedleGauge;
        attribute isSterile : Boolean;
        port medicationIn : MedicationFlowPort;
    }
    
    part def Barrel {
        attribute capacity : DoseVolume;
        attribute fillVolume : DoseVolume;
        item medication : Medication;
        attribute remainingVolume : DoseVolume;
        port medicationOut : MedicationFlowPort;
    }
    
    part def Plunger {
        attribute travelDistance : LengthValue;
    }
    
    part def HousingBody {
        attribute material : String = "Medical-grade plastic";
    }
    
    part def Syrette {
        attribute isSterile : Boolean;
        attribute isSingleUse : Boolean = true;
        attribute medicationName : String;
        attribute doseVolume : DoseVolume;
        
        part housingBody : HousingBody;
        part barrel : Barrel {
            :>> fillVolume = doseVolume;
            :>> remainingVolume = doseVolume;
        }
        part needle : Needle;
        part safetyCap : SafetyCap {
            :>> coversNeedle = true;
        }
        part plunger : Plunger;
        
        port injectionPort : PatientInjectionPort;
        
        connect barrel.medicationOut to needle.medicationIn;
        
        perform SyretteOperation;
        
        satisfy SterilityRequirement by self;
        satisfy DoseAccuracyRequirement by self;
        satisfy NeedleProtectionRequirement by safetyCap, needle;
        satisfy SingleUseRequirement by self;
    }
    
    part def MorphineSyrette :> Syrette {
        :>> medicationName = "Morphine";
        :>> doseVolume = 0.5 [mL];
        :>> needle : Needle {
            :>> length = 25 [mm];
            :>> gauge = 23;
            :>> isSterile = true;
        }
        :>> barrel : Barrel {
            :>> medication : Medication {
                :>> name = "Morphine Sulfate";
                :>> concentration = 10;
            }
        }
    }
    
    part def AtropineSyrette :> Syrette {
        :>> medicationName = "Atropine";
        :>> doseVolume = 0.7 [mL];
        :>> needle : Needle {
            :>> length = 35 [mm];
            :>> gauge = 21;
            :>> isSterile = true;
        }
        :>> barrel : Barrel {
            :>> medication : Medication {
                :>> name = "Atropine Sulfate";
                :>> concentration = 0.4;
            }
        }
    }
    
    part 'Field Medical Kit' {
        part morphineUnit : MorphineSyrette {
            :>> isSterile = true;
        }
        part atropineUnit : AtropineSyrette {
            :>> isSterile = true;
        }
    }
}
