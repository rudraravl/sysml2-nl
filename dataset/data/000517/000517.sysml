package 'Vaginal Syringe System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SterilizationStatus;
    attribute def FluidType;
    
    item def MedicinalFluid {
        attribute fluidType : FluidType;
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute sterile : Boolean;
    }
    
    port def FluidInputPort {
        in item fluid : MedicinalFluid;
    }
    
    port def FluidOutputPort {
        out item fluid : MedicinalFluid;
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowValue;
    }
    
    part def Barrel {
        attribute maxCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute material : String;
        attribute graduationMarkings : Boolean;
        
        port fluidInput : FluidInputPort;
        port fluidOutput : FluidOutputPort;
        
        assert constraint volumeLimit {
            currentVolume <= maxCapacity
        }
    }
    
    part def Plunger {
        attribute position : LengthValue;
        attribute maxTravel : LengthValue;
        attribute appliedForce : ForceValue;
        attribute sealIntegrity : Boolean;
        
        assert constraint travelLimit {
            position >= 0.0[mm] and position <= maxTravel
        }
    }
    
    part def Nozzle {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
        attribute tipDesign : String;
        attribute smoothSurface : Boolean;
        
        port fluidInput : FluidInputPort;
        port fluidOutput : FluidOutputPort;
    }
    
    part def SafetyCap {
        attribute sealed : Boolean;
        attribute material : String;
        attribute tamperEvident : Boolean;
    }
    
    part def VaginalSyringeAssembly {
        attribute deviceId : String;
        attribute sterile : Boolean;
        attribute singleUse : Boolean;
        
        part barrel : Barrel {
            attribute :>> maxCapacity = 150.0[mL];
            attribute :>> currentVolume = 0.0[mL];
            attribute :>> material = "medical-grade polypropylene";
            attribute :>> graduationMarkings = true;
        }
        
        part plunger : Plunger {
            attribute :>> maxTravel = 120.0[mm];
            attribute :>> position = 0.0[mm];
            attribute :>> sealIntegrity = true;
        }
        
        part nozzle : Nozzle {
            attribute :>> diameter = 4.5[mm];
            attribute :>> length = 65.0[mm];
            attribute :>> tipDesign = "rounded atraumatic";
            attribute :>> smoothSurface = true;
        }
        
        part safetyCap : SafetyCap {
            attribute :>> sealed = true;
            attribute :>> material = "medical-grade silicone";
            attribute :>> tamperEvident = true;
        }
        
        connection barrelToNozzle connect barrel.fluidOutput to nozzle.fluidInput;
        
        perform action irrigate : PerformVaginalIrrigation;
    }
    
    action def FillBarrel {
        in fluidSource : MedicinalFluid;
        in targetVolume : VolumeValue;
        out filledBarrel : Barrel;
        out actualVolume : VolumeValue;
    }
    
    action def PositionDevice {
        in device : VaginalSyringeAssembly;
        out positioned : Boolean;
    }
    
    action def ApplyPlungerForce {
        in targetForce : ForceValue;
        in plungerPosition : LengthValue;
        out generatedPressure : PressureValue;
    }
    
    action def DispenseFluid {
        in sourcePressure : PressureValue;
        in nozzleDiameter : LengthValue;
        in targetVolume : VolumeValue;
        out flowRate : VolumeFlowValue;
        out dispensedVolume : VolumeValue;
    }
    
    action def VerifySterility {
        in components : VaginalSyringeAssembly[*];
        out sterilizationStatus : SterilizationStatus;
        out verified : Boolean;
    }
    
    attribute def PrepareCommand;
    attribute def PositionCommand;
    attribute def ResetCommand;
    
    state def SyringeOperationalStates {
        in syringe : VaginalSyringeAssembly;
        attribute currentPressure : PressureValue;
        attribute currentVolume : VolumeValue;
        attribute systemReady : Boolean;
        attribute treatmentComplete : Boolean;
        attribute targetDispenseVolume : VolumeValue;
        
        entry; then idle;
        
        state idle {
            entry assign currentPressure := 0.0[Pa];
            entry assign currentVolume := 0.0[mL];
        }
        
        transition idle_to_preparation
            first idle
            accept prepareCmd : PrepareCommand
            then preparation;
        
        state preparation {
            action verifySterility : VerifySterility;
        }
        
        transition preparation_to_filling
            first preparation
            if preparation.verifySterility.verified == true
            then filling;
        
        state filling {
            action fillBarrel : FillBarrel;
        }
        
        transition filling_to_ready
            first filling
            if filling.fillBarrel.actualVolume > 0.0[mL]
            then ready;
        
        state ready {
            entry assign systemReady := true;
        }
        
        transition ready_to_positioning
            first ready
            accept positionCmd : PositionCommand
            then positioning;
        
        state positioning {
            action positionDevice : PositionDevice;
        }
        
        transition positioning_to_dispensing
            first positioning
            if positioning.positionDevice.positioned == true
            then dispensing;
        
        state dispensing {
            action applyForce : ApplyPlungerForce;
            action dispenseFluid : DispenseFluid;
        }
        
        transition dispensing_to_complete
            first dispensing
            if dispensing.dispenseFluid.dispensedVolume >= targetDispenseVolume
            then complete;
        
        state complete {
            entry assign treatmentComplete := true;
        }
        
        transition complete_to_idle
            first complete
            accept resetCmd : ResetCommand
            then idle;
    }
    
    action def PerformVaginalIrrigation {
        in medicinalSolution : MedicinalFluid;
        in prescribedVolume : VolumeValue;
        in prescribedPressure : PressureValue;
        out treatmentComplete : Boolean;
        out deliveredVolume : VolumeValue;
        
        first start;
        
        then action verifySterility : VerifySterility {
            out verified;
        }
        
        then decide;
            if verifySterility.verified == false then abortTreatment;
            if verifySterility.verified == true then fillSyringe;
        
        action abortTreatment {
            then assign treatmentComplete := false;
        }
        then done;
        
        action fillSyringe : FillBarrel {
            in fluidSource = medicinalSolution;
            in targetVolume = prescribedVolume;
            out actualVolume;
        }
        
        then action positionDevice : PositionDevice {
            out positioned;
        }
        
        then action applyPressure : ApplyPlungerForce {
            out generatedPressure;
        }
        
        then decide;
            if applyPressure.generatedPressure <= prescribedPressure 
                then dispenseFluid;
            if applyPressure.generatedPressure > prescribedPressure 
                then adjustPressure;
        
        action adjustPressure;
        then applyPressure;
        
        action dispenseFluid : DispenseFluid {
            in sourcePressure = applyPressure.generatedPressure;
            in targetVolume = prescribedVolume;
            out dispensedVolume;
        }
        
        then action monitorDispensing;
        
        then decide;
            if dispenseFluid.dispensedVolume < prescribedVolume 
                then applyPressure;
            if dispenseFluid.dispensedVolume >= prescribedVolume 
                then completeIrrigation;
        
        action completeIrrigation {
            then assign treatmentComplete := true;
            then assign deliveredVolume := dispenseFluid.dispensedVolume;
        }
        
        then done;
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* The vaginal syringe system shall deliver medicinal or cleansing fluid 
                into the vaginal cavity in a controlled, safe, and sterile manner for 
                therapeutic irrigation, cleansing, or medication administration purposes. */
        
        subject vaginalSyringe : VaginalSyringeAssembly;
        
        require constraint deliveryControl {
            doc /* The system shall provide controlled fluid delivery with adjustable pressure 
                   and flow rate to ensure patient safety and comfort. */
        }
        
        require constraint sterileOperation {
            doc /* All fluid contact surfaces shall maintain sterility throughout operation 
                   to prevent infection. */
            vaginalSyringe.sterile == true
        }
        
        require constraint volumeAccuracy {
            doc /* The system shall deliver fluid volume within ±5% of prescribed amount 
                   as indicated by barrel graduations. */
        }
    }
    
    requirement <'REQ-002'> safetyRequirement {
        doc /* The vaginal syringe system shall prevent excessive pressure that could 
                cause tissue damage, discomfort, or injury to the patient. */
        
        subject vaginalSyringe : VaginalSyringeAssembly;
        
        require constraint pressureLimit {
            doc /* Maximum dispensing pressure shall not exceed 50 kPa to prevent 
                   tissue trauma and ensure patient safety. */
        }
        
        require constraint materialBiocompatibility {
            doc /* All patient-contact materials shall be biocompatible, non-toxic, 
                   and non-irritating per ISO 10993 standards. */
        }
        
        require constraint atraumaticDesign {
            doc /* Nozzle tip shall have smooth, rounded design to minimize risk 
                   of tissue trauma during insertion and use. */
            vaginalSyringe.nozzle.smoothSurface == true
        }
    }
    
    requirement <'REQ-003'> usabilityRequirement {
        doc /* The vaginal syringe system shall be easy to operate with clear visual 
                indication of fluid volume and intuitive single-handed operation. */
        
        subject vaginalSyringe : VaginalSyringeAssembly;
        
        require constraint ergonomicDesign {
            doc /* The device shall be operable with single-handed grip and control 
                   for ease of self-administration. */
        }
        
        require constraint volumeIndication {
            doc /* Barrel shall have clear, easy-to-read volume markings visible 
                   during filling and operation. */
            vaginalSyringe.barrel.graduationMarkings == true
        }
        
        require constraint singleUseDesign {
            doc /* Device shall be designed for single use to ensure sterility 
                   and prevent cross-contamination. */
            vaginalSyringe.singleUse == true
        }
    }
    
    requirement <'REQ-004'> packagingRequirement {
        doc /* The vaginal syringe system shall be packaged in sterile, tamper-evident 
                packaging with clear labeling and instructions for use. */
        
        subject vaginalSyringe : VaginalSyringeAssembly;
        
        require constraint tamperEvidence {
            doc /* Safety cap shall provide tamper-evident seal to ensure product 
                   integrity prior to use. */
            vaginalSyringe.safetyCap.tamperEvident == true
        }
    }
    
    requirement systemRequirements {
        doc /* Complete system requirements for vaginal syringe assembly. */
        
        subject vaginalSyringe : VaginalSyringeAssembly;
        
        require primaryFunctionRequirement;
        require safetyRequirement;
        require usabilityRequirement;
        require packagingRequirement;
    }
}
