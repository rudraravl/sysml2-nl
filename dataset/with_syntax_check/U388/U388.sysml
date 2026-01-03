package 'EliseSorensenOstomySystem' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;
    
    doc /*
     * This model represents the Elise Sørensen Ostomy Appliance System, 
     * a medical device system inspired by the pioneering work of Danish nurse 
     * Elise Sørensen who invented the modern two-piece ostomy appliance in the 1950s.
     * 
     * The system's primary function is to provide a secure, hygienic, and 
     * user-friendly solution for collecting bodily waste from patients with 
     * stomas (surgical openings in the abdomen). The two-piece design allows 
     * the collection pouch to be changed without removing the adhesive baseplate 
     * from the skin, significantly improving patient comfort and quality of life.
     */
    
    attribute def AdhesiveStrengthValue :> ISQ::ForceValue;
    attribute def FlowRateValue :> ISQ::VolumeValue;
    attribute def FillLevelValue :> ScalarValues::Real;
    
    item def StomalEffluent {
        attribute flowRate : FlowRateValue;
        attribute viscosity : ISQ::DynamicViscosityValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    item def OdorMolecule {
        attribute concentration : ScalarValues::Real;
    }
    
    item def SkinConditionData {
        attribute pH : ScalarValues::Real;
        attribute moisture : ScalarValues::Real;
        attribute irritationLevel : ScalarValues::Real;
    }
    
    enum def ApplianceStatus {
        Sealed;
        Collecting;
        NearCapacity;
        RequiresChange;
        Compromised;
    }
    
    port def EffluentPort {
        in item effluent : StomalEffluent;
    }
    
    port def VentPort {
        out item gas : OdorMolecule;
    }
    
    port def SkinInterfacePort {
        out item skinData : SkinConditionData;
    }
    
    port def CouplingPort;
    
    part def AdhesiveBaseplate {
        doc /* 
         * The baseplate adheres to the peristomal skin and provides 
         * a stable mounting point for the collection pouch.
         */
        
        attribute adhesiveStrength : AdhesiveStrengthValue = 15.0 [SI::N];
        attribute wearTime : DurationValue = 72.0 [SI::h];
        attribute stomaOpeningDiameter : ISQ::LengthValue;
        attribute baseplateThickness : ISQ::LengthValue = 2.5 [SI::mm];
        attribute mass : ISQ::MassValue = 45.0 [SI::g];
        attribute skinContactArea : ISQ::AreaValue = 100.0 [SI::cm^2];
        
        port skinInterface : SkinInterfacePort;
        port stomaInlet : EffluentPort;
        port pouchCoupling : CouplingPort;
        
        private attribute currentWearTime : DurationValue = 0.0 [SI::h];
        private attribute sealIntegrity : ScalarValues::Real = 1.0;
    }
    
    part def CharcoalFilter {
        doc /* 
         * Filters odor molecules from gas while allowing pressure relief.
         */
        
        attribute filterCapacity : ISQ::MassValue = 8.0 [SI::g];
        attribute filterEfficiency : ScalarValues::Real = 0.98;
        attribute currentLoad : ISQ::MassValue = 0.0 [SI::g];
        
        port gasInlet : ~VentPort;
        port gasOutlet : VentPort;
    }
    
    part def CollectionPouch {
        doc /* 
         * The detachable pouch collects stomal effluent and can be 
         * changed without removing the baseplate.
         */
        
        attribute capacity : ISQ::VolumeValue = 600.0 [SI::mL];
        attribute currentVolume : ISQ::VolumeValue = 0.0 [SI::mL];
        attribute fillLevel : FillLevelValue = 0.0;
        attribute wallThickness : ISQ::LengthValue = 0.15 [SI::mm];
        attribute mass : ISQ::MassValue = 65.0 [SI::g];
        attribute odorBarrierRating : ScalarValues::Real = 0.99;
        
        port baseplateCoupling : ~CouplingPort;
        port effluentIntake : EffluentPort;
        port gasVent : ~VentPort;
        port drainOutlet;
        
        private attribute isDrainOpen : ScalarValues::Boolean = false;
        private attribute isSecurelyAttached : ScalarValues::Boolean = false;
        
        assert constraint capacityLimit {
            currentVolume <= capacity
        }
    }
    
    part def DrainValve {
        doc /* 
         * Allows controlled emptying of the pouch without removal.
         */
        
        attribute valveState : ScalarValues::Boolean = false;
        attribute flowResistance : ISQ::PressureValue = 5.0 [SI::Pa];
        
        port pouchConnection;
        port drainPort : ~EffluentPort;
    }
    
    part def CouplingRing {
        doc /* 
         * Mechanical coupling mechanism between baseplate and pouch.
         */
        
        attribute couplingStrength : ISQ::ForceValue = 25.0 [SI::N];
        attribute lockingMechanism : ScalarValues::String = "twist-lock";
        attribute engagementAngle : ScalarValues::Real = 90.0;
        
        port baseplateInterface : ~CouplingPort;
        port pouchInterface : CouplingPort;
    }
    
    part def OstomyAppliance {
        doc /* 
         * Complete two-piece ostomy appliance system.
         */
        
        attribute totalMass : ISQ::MassValue;
        attribute systemStatus : ApplianceStatus = ApplianceStatus::Sealed;
        attribute operationalTime : DurationValue = 0.0 [SI::h];
        attribute changeInterval : DurationValue = 48.0 [SI::h];
        
        part baseplate : AdhesiveBaseplate {
            attribute :>> stomaOpeningDiameter = 30.0 [SI::mm];
        }
        
        part pouch : CollectionPouch;
        
        part odorFilter : CharcoalFilter;
        
        part drainValve : DrainValve;
        
        part couplingRing : CouplingRing;
        
        connect baseplate.pouchCoupling to couplingRing.baseplateInterface;
        connect couplingRing.pouchInterface to pouch.baseplateCoupling;
        connect baseplate.stomaInlet to pouch.effluentIntake;
        connect pouch.gasVent to odorFilter.gasInlet;
        connect pouch.drainOutlet to drainValve.pouchConnection;
        
        assert constraint massLimit {
            totalMass <= 200.0 [SI::g]
        }
        
        assert constraint totalMassCalc {
            totalMass == baseplate.mass + pouch.mass + odorFilter.mass
        }
    }
    
    action def CollectEffluent {
        in appliance : OstomyAppliance;
        in inflowRate : FlowRateValue;
        in duration : DurationValue;
        inout pouch : CollectionPouch;
        
        then assign pouch.currentVolume := pouch.currentVolume + inflowRate;
    }
    
    action def MonitorFillLevel {
        in pouch : CollectionPouch;
        out fillLevel : FillLevelValue;
        out requiresChange : ScalarValues::Boolean;
    }
    
    action def ChangePouch {
        inout appliance : OstomyAppliance;
        
        first detachOldPouch;
        action detachOldPouch {
            then assign appliance.pouch.isSecurelyAttached := false;
            then assign appliance.pouch.currentVolume := 0.0 [SI::mL];
        }
        then attachNewPouch;
        action attachNewPouch {
            then assign appliance.pouch.isSecurelyAttached := true;
            then assign appliance.systemStatus := ApplianceStatus::Sealed;
        }
    }
    
    action def EmptyPouch {
        inout appliance : OstomyAppliance;
        
        first openValve;
        action openValve {
            then assign appliance.drainValve.valveState := true;
        }
        then drainContents;
        action drainContents {
            then assign appliance.pouch.currentVolume := 0.0 [SI::mL];
        }
        then closeValve;
        action closeValve {
            then assign appliance.drainValve.valveState := false;
        }
    }
    
    state def PouchOperationStates {
        in attribute fillLevel : FillLevelValue;
        in attribute isCollecting : ScalarValues::Boolean;
        in attribute warningActive : ScalarValues::Boolean;
        in attribute requiresAction : ScalarValues::Boolean;
        
        entry; then empty;
        
        state empty;
        
        transition empty_to_collecting
            first empty
            accept EffluentFlowStarted
            then collecting;
        
        state collecting;
        
        transition collecting_to_nearCapacity
            first collecting
            if fillLevel >= 0.75
            then nearCapacity;
        
        state nearCapacity;
        
        transition nearCapacity_to_full
            first nearCapacity
            if fillLevel >= 0.95
            then full;
        
        state full;
        
        transition full_to_draining
            first full
            accept DrainInitiated
            then draining;
        
        state draining;
        
        transition draining_to_empty
            first draining
            accept DrainComplete
            then empty;
        
        transition nearCapacity_to_changing
            first nearCapacity
            accept PouchChangeInitiated
            then changing;
        
        state changing;
        
        transition changing_to_empty
            first changing
            accept NewPouchAttached
            then empty;
    }
    
    action def OstomyApplianceOperation {
        in attribute inflowProfile : FlowRateValue[*];
        in attribute timeStep : DurationValue;
        in attribute maxCapacity : VolumeValue;
        out attribute volumeHistory : VolumeValue[*] := ( );
        out attribute changeEvents : ScalarValues::Boolean[*] := ( );
        
        private attribute currentVolume : VolumeValue = 0.0 [SI::mL];
        
        first start;
        then merge continueOperation;
        
        for rate in inflowProfile {
            then action collect {
                then assign currentVolume := currentVolume + rate;
            }
            
            then decide;
                if currentVolume >= maxCapacity * 0.75 then performChange;
                if currentVolume < maxCapacity * 0.75 then recordState;
            
            action performChange {
                then assign currentVolume := 0.0 [SI::mL];
                then assign volumeHistory := volumeHistory->including(currentVolume);
                then assign changeEvents := changeEvents->including(true);
            }
            then continueOperation;
            
            action recordState {
                then assign volumeHistory := volumeHistory->including(currentVolume);
                then assign changeEvents := changeEvents->including(false);
            }
            then continueOperation;
        }
    }
    
    requirement <'REQ-001'> sealIntegrityRequirement {
        doc /* 
         * The baseplate shall maintain a leak-proof seal with the 
         * peristomal skin for a minimum of 72 hours under normal conditions.
         */
        
        subject baseplate : AdhesiveBaseplate;
        
        require constraint {
            baseplate.wearTime >= 72.0 [SI::h] and
            baseplate.adhesiveStrength >= 10.0 [SI::N]
        }
    }
    
    requirement <'REQ-002'> pouchCapacityRequirement {
        doc /* 
         * The collection pouch shall have a minimum capacity of 500 mL 
         * to accommodate typical daily output.
         */
        
        subject pouch : CollectionPouch;
        
        require constraint {
            pouch.capacity >= 500.0 [SI::mL]
        }
    }
    
    requirement <'REQ-003'> odorControlRequirement {
        doc /* 
         * The system shall prevent odor escape with a minimum 
         * effectiveness of 95% under normal operating conditions.
         */
        
        subject appliance : OstomyAppliance;
        
        require constraint {
            appliance.pouch.odorBarrierRating >= 0.95 and
            appliance.odorFilter.filterEfficiency >= 0.95
        }
    }
    
    requirement <'REQ-004'> couplingStrengthRequirement {
        doc /* 
         * The coupling mechanism shall withstand a minimum separation 
         * force of 20 N to prevent accidental detachment.
         */
        
        subject coupling : CouplingRing;
        
        require constraint {
            coupling.couplingStrength >= 20.0 [SI::N]
        }
    }
    
    requirement <'REQ-005'> systemMassRequirement {
        doc /* 
         * The total mass of the appliance shall not exceed 200 g 
         * to ensure patient comfort during extended wear.
         */
        
        subject appliance : OstomyAppliance;
        
        require constraint {
            appliance.totalMass <= 200.0 [SI::g]
        }
    }
    
    requirement <'REQ-006'> biocompatibilityRequirement {
        doc /* 
         * All materials in contact with skin shall be biocompatible 
         * and hypoallergenic to minimize skin irritation.
         */
        
        subject baseplate : AdhesiveBaseplate;
    }
    
    requirement primaryMissionRequirement {
        doc /* 
         * The Elise Sørensen Ostomy Appliance System shall provide 
         * secure, hygienic collection of stomal effluent while protecting 
         * peristomal skin integrity and maintaining patient dignity and 
         * quality of life through a user-friendly two-piece design.
         */
        
        assume constraint patientCompliance {
            doc /* Patient follows proper application and maintenance procedures. */
        }
        
        require sealIntegrityRequirement;
        require pouchCapacityRequirement;
        require odorControlRequirement;
        require couplingStrengthRequirement;
        require systemMassRequirement;
        require biocompatibilityRequirement;
    }
}
