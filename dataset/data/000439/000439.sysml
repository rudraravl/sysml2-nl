package 'Dapivirine Ring HIV Prevention System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def DrugConcentration :> Real;
    attribute def ReleaseRate :> Real;
    
    item def Dapivirine {
        doc /* Antiretroviral microbicide compound */
        attribute molecularWeight : ISQ::MassValue;
    }
    
    item def SiliconeElastomer {
        doc /* Biocompatible polymer matrix material */
        attribute flexibility : Real;
        attribute biocompatibility : Real;
    }
    
    part def DrugReservoir {
        doc /* Reservoir containing dapivirine embedded in silicone matrix */
        attribute initialLoad : ISQ::MassValue;
        attribute currentLoad : ISQ::MassValue;
        attribute releaseRatePerDay : ISQ::MassValue;
        
        port drugOutput {
            out flow dapivirineRelease : Dapivirine;
        }
    }
    
    part def PolymerRingStructure {
        doc /* Flexible silicone ring structure */
        attribute outerDiameter : ISQ::LengthValue;
        attribute crossSectionDiameter : ISQ::LengthValue;
        attribute material : SiliconeElastomer;
    }
    
    part def VaginalEnvironment {
        doc /* Physiological vaginal environment */
        attribute fluidVolume : ISQ::VolumeValue;
        attribute pH : Real;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute drugConcentration : DrugConcentration;
        
        port tissueInterface {
            in flow dapivirineAbsorption : Dapivirine;
        }
    }
    
    part def User {
        doc /* Individual using the dapivirine ring */
        attribute adherence : Real;
        
        port vaginalCavity {
            doc /* Anatomical placement site */
        }
    }
    
    part def DapivirineVaginalRing {
        doc /* Intravaginal ring device for HIV prevention */
        
        part structure : PolymerRingStructure;
        
        part reservoir : DrugReservoir;
        
        port drugDeliveryPort {
            out flow dapivirineFlow : Dapivirine;
        }
        
        connect reservoir.drugOutput to drugDeliveryPort;
        
        state machine RingLifecycle {
            initial state Packaged;
            
            state Inserted {
                entry action startRelease;
            }
            
            state Active {
                do action continuousRelease;
            }
            
            state Depleted;
            
            state Removed;
            
            transition Packaged -> Inserted;
            transition Inserted -> Active;
            transition Active -> Active;
            transition Active -> Depleted;
            transition Active -> Removed;
            transition Depleted -> Removed;
            transition Removed -> Packaged;
        }
    }
    
    action def InsertRing {
        doc /* Insert ring into vaginal cavity */
        in ring : DapivirineVaginalRing;
        out activeRing : DapivirineVaginalRing;
    }
    
    action def ReleaseDapivirine {
        doc /* Controlled release of dapivirine from reservoir */
        in currentDrugLoad : ISQ::MassValue;
        in dailyReleaseRate : ISQ::MassValue;
        in timeElapsed : ISQ::TimeValue;
        out releasedAmount : ISQ::MassValue;
        out remainingLoad : ISQ::MassValue;
    }
    
    action def DiffuseToTissue {
        doc /* Diffusion of dapivirine through vaginal tissue */
        in releasedDrug : ISQ::MassValue;
        in fluidVolume : ISQ::VolumeValue;
        out tissueConcentration : DrugConcentration;
    }
    
    action def ProvideProtection {
        doc /* Achieve protective concentration against HIV */
        in tissueConcentration : DrugConcentration;
        in targetConcentration : DrugConcentration;
        out protectionActive : Boolean;
    }
    
    action def RemoveRing {
        doc /* Remove ring after usage period */
        in usedRing : DapivirineVaginalRing;
        in usageDuration : ISQ::TimeValue;
        out removedRing : DapivirineVaginalRing;
    }
    
    action def PreventHIVTransmission {
        doc /* Primary function: prevent HIV transmission through sustained dapivirine release */
        in user : User;
        in ring : DapivirineVaginalRing;
        in usagePeriod : ISQ::TimeValue;
        out protectionAchieved : Boolean;
        
        first start;
        
        then action insert : InsertRing {
            in ring = PreventHIVTransmission::ring;
            out activeRing;
        }
        
        then merge continuousProtection;
        
        action continuousProtection {
            private attribute dayCount : ISQ::TimeValue;
            private attribute cumulativeRelease : ISQ::MassValue;
            
            action release : ReleaseDapivirine {
                in currentDrugLoad;
                in dailyReleaseRate;
                in timeElapsed = dayCount;
                out releasedAmount;
                out remainingLoad;
            }
            
            then action diffuse : DiffuseToTissue {
                in releasedDrug = release.releasedAmount;
                in fluidVolume;
                out tissueConcentration;
            }
            
            then action protect : ProvideProtection {
                in tissueConcentration = diffuse.tissueConcentration;
                in targetConcentration;
                out protectionActive;
            }
            
            then decide;
                if dayCount < usagePeriod then continuousProtection;
                else remove;
        }
        
        action remove : RemoveRing {
            in usedRing = insert.activeRing;
            in usageDuration = usagePeriod;
            out removedRing;
        }
        
        then done;
    }
    
    part hivPreventionSystem {
        doc /* Complete dapivirine ring system for HIV prevention */
        
        part vaginalRing : DapivirineVaginalRing {
            part :>> structure {
                attribute :>> outerDiameter = 56.0[SI::mm];
                attribute :>> crossSectionDiameter = 7.7[SI::mm];
            }
            
            part :>> reservoir {
                attribute :>> initialLoad = 25.0[SI::mg];
                attribute :>> currentLoad = 25.0[SI::mg];
                attribute :>> releaseRatePerDay = 0.15[SI::mg];
            }
        }
        
        part environment : VaginalEnvironment {
            attribute :>> fluidVolume = 0.75[SI::ml];
            attribute :>> pH = 4.5;
            attribute :>> temperature = 310.15[SI::K];
            attribute :>> drugConcentration = 0.0;
        }
        
        part ringUser : User {
            attribute :>> adherence = 0.92;
        }
        
        connection drugDelivery connect 
            vaginalRing.drugDeliveryPort to environment.tissueInterface;
        
        connection ringPlacement connect 
            ringUser.vaginalCavity to environment.tissueInterface;
        
        perform action preventHIV : PreventHIVTransmission {
            in user = ringUser;
            in ring = vaginalRing;
            in usagePeriod = 28.0[SI::d];
            out protectionAchieved;
        }
    }
    
    requirement def HIVPreventionRequirement {
        doc /* Requirements for effective HIV prevention */
        
        require constraint sustainedRelease {
            doc /* Ring must provide sustained drug release for 28 days */
        }
        
        require constraint therapeuticLevel {
            doc /* Maintain therapeutic dapivirine concentration */
        }
        
        require constraint userCompliance {
            doc /* System must support high user adherence */
        }
    }
    
    requirement <'REQ-001'> systemEffectiveness : HIVPreventionRequirement {
        doc /* The dapivirine ring system shall prevent HIV transmission by providing 
             continuous controlled release of dapivirine antiretroviral drug over 28 days 
             to maintain protective concentrations in vaginal tissue */
        
        subject hivPreventionSystem;
        
        assume constraint properInsertion {
            doc /* Ring is correctly inserted and positioned in vaginal cavity */
        }
        
        assume constraint continuousWear {
            doc /* User maintains ring in place for full 28-day duration */
        }
        
        require sustainedRelease;
        require therapeuticLevel;
        require userCompliance;
    }
}
