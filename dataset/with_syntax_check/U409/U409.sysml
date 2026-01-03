package SyretteSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MedicationDose :> ISQ::VolumeValue;
    attribute def InjectionPressure :> ISQ::PressureValue;
    attribute def InjectionDepth :> ISQ::LengthValue;
    attribute def FlowRate :> Real;
    attribute def MedicationMass :> ISQ::MassValue;
    
    item def Medication {
        attribute name : String;
        attribute dose : MedicationDose;
        attribute concentration : Real;
        attribute viscosity : ISQ::DynamicViscosityValue;
    }
    
    port def MedicationFlowPort {
        out medication : Medication;
    }
    
    port def InjectionPort {
        in medication : Medication;
        out deliveredDose : MedicationDose;
    }
    
    port def PressurePort {
        in appliedPressure : InjectionPressure;
    }
    
    part def Barrel {
        attribute capacity : MedicationDose;
        attribute currentVolume : MedicationDose;
        port outletPort : MedicationFlowPort;
        item storedMedication : Medication;
    }
    
    part def Needle {
        attribute length : InjectionDepth;
        attribute gauge : Real;
        attribute isExposed : Boolean;
        port inletPort : InjectionPort;
    }
    
    part def Plunger {
        attribute position : ISQ::LengthValue;
        attribute maxStroke : ISQ::LengthValue;
        port pressurePort : PressurePort;
    }
    
    part def SafetyCap {
        attribute isRemoved : Boolean;
    }
    
    part def HousingBody {
        attribute material : String;
        attribute wallThickness : ISQ::LengthValue;
    }
    
    state def SyretteOperationalState {
        entry; then sealed;
        
        state sealed {
            doc /* Syrette is sealed with safety cap in place */
        }
        
        state ready {
            doc /* Safety cap removed, needle exposed and ready for injection */
        }
        
        state delivering {
            doc /* Medication is being actively delivered */
        }
        
        state empty {
            doc /* All medication has been delivered */
        }
        
        transition sealed_to_ready
            first sealed
            accept CapRemovedSignal
            then ready;
        
        transition ready_to_delivering
            first ready
            accept PressureAppliedSignal
            then delivering;
        
        transition delivering_to_empty
            first delivering
            accept MedicationDepletedSignal
            then empty;
        
        transition delivering_to_ready
            first delivering
            accept PressureReleasedSignal
            then ready;
    }
    
    attribute def CapRemovedSignal;
    attribute def PressureAppliedSignal;
    attribute def PressureReleasedSignal;
    attribute def MedicationDepletedSignal;
    
    action def RemoveSafetyCap {
        in cap : SafetyCap;
        out capRemoved : Boolean;
        out needleExposed : Boolean;
    }
    
    action def InsertNeedle {
        in needle : Needle;
        in targetDepth : InjectionDepth;
        out insertionDepth : InjectionDepth;
        out insertionComplete : Boolean;
    }
    
    action def ApplyPressure {
        in plunger : Plunger;
        in pressure : InjectionPressure;
        out displacement : ISQ::LengthValue;
    }
    
    action def DeliverMedication {
        in medication : Medication;
        in flowRate : FlowRate;
        in targetDose : MedicationDose;
        out deliveredDose : MedicationDose;
        out deliveryComplete : Boolean;
        
        first start;
        then assign deliveredDose := 0.0[SI::mL];
        then merge continueDelivery;
        then decide;
            if deliveredDose < targetDose then incrementDose;
            if deliveredDose >= targetDose then completeDelivery;
        action incrementDose {
            then assign deliveredDose := deliveredDose + flowRate * 0.1[SI::s];
        }
        then continueDelivery;
        action completeDelivery {
            then assign deliveryComplete := true;
        }
        then done;
    }
    
    action def AdministerInjection {
        in targetDose : MedicationDose;
        in injectionDepth : InjectionDepth;
        out administrationComplete : Boolean;
        out totalDelivered : MedicationDose;
        
        first start;
        then action removeCap : RemoveSafetyCap {
            out capRemoved;
            out needleExposed;
        }
        then action insertNeedle : InsertNeedle {
            in targetDepth = AdministerInjection::injectionDepth;
            out insertionDepth;
            out insertionComplete;
        }
        then action applyPressure : ApplyPressure {
            in pressure = 150.0[SI::kPa];
            out displacement;
        }
        then action deliverMed : DeliverMedication {
            in targetDose = AdministerInjection::targetDose;
            in flowRate = 0.5;
            out deliveredDose;
            out deliveryComplete;
        }
        then assign totalDelivered := deliverMed.deliveredDose;
        then assign administrationComplete := deliverMed.deliveryComplete;
        then done;
    }
    
    part def Syrette {
        doc /* 
            A Syrette is a single-use, pre-filled medication delivery device designed 
            for rapid emergency administration. It consists of a sealed barrel containing 
            medication, a protected needle, and a plunger mechanism. The primary function 
            is to deliver a precise dose of medication through subcutaneous or intramuscular 
            injection by applying manual pressure to the plunger after removing the safety cap.
        */
        
        attribute medicationName : String;
        attribute manufacturingDate : String;
        attribute expirationDate : String;
        attribute lotNumber : String;
        attribute sterile : Boolean;
        
        part barrel : Barrel {
            attribute capacity = 2.0[SI::mL];
            attribute currentVolume = 2.0[SI::mL];
            item storedMedication : Medication {
                attribute name = "Morphine Sulfate";
                attribute dose = 2.0[SI::mL];
                attribute concentration = 5.0;
                attribute viscosity = 0.001[SI::'Pa·s'];
            }
        }
        
        part needle : Needle {
            attribute length = 15.0[SI::mm];
            attribute gauge = 25.0;
            attribute isExposed = false;
        }
        
        part plunger : Plunger {
            attribute position = 0.0[SI::mm];
            attribute maxStroke = 30.0[SI::mm];
        }
        
        part safetyCap : SafetyCap {
            attribute isRemoved = false;
        }
        
        part housing : HousingBody {
            attribute material = "Medical Grade Plastic";
            attribute wallThickness = 1.5[SI::mm];
        }
        
        connection barrelToNeedle connect barrel.outletPort to needle.inletPort;
        connection plungerToBarrel connect plunger.pressurePort to barrel;
        
        perform action injectionSequence : AdministerInjection {
            in targetDose = barrel.storedMedication.dose;
            in injectionDepth = 10.0[SI::mm];
            out administrationComplete;
            out totalDelivered;
        }
        
        exhibit state operationalState : SyretteOperationalState;
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for Syrette operation */
        subject device : Syrette;
    }
    
    requirement def SterilityRequirement :> SafetyRequirement {
        doc /* The Syrette shall maintain sterility of medication and needle until use */
        require constraint {
            device.sterile == true and 
            device.safetyCap.isRemoved == false implies device.needle.isExposed == false
        }
    }
    
    requirement def DosageAccuracyRequirement {
        doc /* The Syrette shall deliver medication dose within ±10% of specified dose */
        subject device : Syrette;
        attribute deliveredDose : MedicationDose;
        attribute specifiedDose : MedicationDose;
        require constraint {
            deliveredDose >= 0.9 * specifiedDose and 
            deliveredDose <= 1.1 * specifiedDose
        }
    }
    
    requirement def SingleUseRequirement :> SafetyRequirement {
        doc /* The Syrette shall be designed for single use only and shall not be refillable */
    }
    
    requirement def NeedleSafetyRequirement :> SafetyRequirement {
        doc /* The needle shall remain protected until safety cap is deliberately removed */
        require constraint {
            device.safetyCap.isRemoved == false implies device.needle.isExposed == false
        }
    }
    
    requirement def ExpirationRequirement {
        doc /* The Syrette shall not be used beyond its expiration date */
        subject device : Syrette;
    }
    
    requirement syretteSystemRequirements {
        doc /* Top-level requirements for Syrette medication delivery system */
        subject device : Syrette;
        
        require sterilityReq : SterilityRequirement {
            subject device = syretteSystemRequirements::device;
        }
        require dosageReq : DosageAccuracyRequirement {
            subject device = syretteSystemRequirements::device;
        }
        require singleUseReq : SingleUseRequirement {
            subject device = syretteSystemRequirements::device;
        }
        require needleSafetyReq : NeedleSafetyRequirement {
            subject device = syretteSystemRequirements::device;
        }
        require expirationReq : ExpirationRequirement {
            subject device = syretteSystemRequirements::device;
        }
    }
    
    part morphineSyrette : Syrette {
        :>> medicationName = "Morphine Sulfate";
        :>> manufacturingDate = "2024-01-15";
        :>> expirationDate = "2026-01-15";
        :>> lotNumber = "MS-2024-A-001";
        :>> sterile = true;
        
        part redefines barrel {
            :>> capacity = 2.0[SI::mL];
            :>> currentVolume = 2.0[SI::mL];
            item redefines storedMedication {
                :>> name = "Morphine Sulfate";
                :>> dose = 2.0[SI::mL];
                :>> concentration = 5.0;
                :>> viscosity = 0.001[SI::'Pa·s'];
            }
        }
        
        part redefines needle {
            :>> length = 15.0[SI::mm];
            :>> gauge = 25.0;
        }
    }
    
    part atropineSyrette : Syrette {
        :>> medicationName = "Atropine Sulfate";
        :>> manufacturingDate = "2024-02-20";
        :>> expirationDate = "2026-02-20";
        :>> lotNumber = "AS-2024-B-002";
        :>> sterile = true;
        
        part redefines barrel {
            :>> capacity = 1.5[SI::mL];
            :>> currentVolume = 1.5[SI::mL];
            item redefines storedMedication {
                :>> name = "Atropine Sulfate";
                :>> dose = 1.5[SI::mL];
                :>> concentration = 1.33;
                :>> viscosity = 0.0009[SI::'Pa·s'];
            }
        }
        
        part redefines needle {
            :>> length = 12.0[SI::mm];
            :>> gauge = 27.0;
        }
    }
}
