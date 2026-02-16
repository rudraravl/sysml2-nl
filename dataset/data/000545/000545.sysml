package BedpanSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def VolumeCapacity :> VolumeValue;
    attribute def FluidLevel :> VolumeValue;
    attribute def SurfaceArea :> AreaValue;
    attribute def ContainmentIntegrity :> Real;
    
    enum def BedpanMaterial {
        stainlessSteel;
        medicalGradePlastic;
        disposablePulp;
    }
    
    enum def SanitationState {
        sterile;
        clean;
        inUse;
        contaminated;
        underSanitation;
    }
    
    item def BodilyWaste {
        attribute volume : VolumeCapacity;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def SanitizingAgent {
        attribute concentration : Real;
        attribute volume : VolumeCapacity;
        attribute effectiveTemperature : ThermodynamicTemperatureValue;
    }
    
    port def WasteReceptacle {
        in item waste : BodilyWaste;
    }
    
    port def DisposalInterface {
        out item waste : BodilyWaste;
    }
    
    port def SanitationInterface {
        in item sanitizer : SanitizingAgent;
    }
    
    part def BedpanBasin {
        attribute capacity : VolumeCapacity;
        attribute currentLevel : FluidLevel;
        attribute material : BedpanMaterial;
        attribute surfaceArea : SurfaceArea;
        attribute sealIntegrity : ContainmentIntegrity;
        
        part contourSurface {
            attribute ergonomicRadius : LengthValue;
            attribute rimThickness : LengthValue;
        }
        
        part baseStructure {
            attribute stability : Real;
            attribute loadCapacity : MassValue;
        }
        
        port wasteIntake : WasteReceptacle;
        port drainPort : DisposalInterface;
    }
    
    part def HandleAssembly {
        attribute gripDiameter : LengthValue;
        attribute handleLength : LengthValue;
        attribute loadRating : ForceValue;
        
        part gripSurface {
            attribute textureCoefficient : Real;
        }
    }
    
    part def LevelIndicator {
        attribute threshold : VolumeCapacity;
        attribute currentReading : FluidLevel;
        
        action def MonitorLevel {
            out level : FluidLevel;
            out isFull : Boolean;
        }
    }
    
    part def SanitationSystem {
        attribute cycleTemperature : ThermodynamicTemperatureValue;
        attribute cycleDuration : TimeValue;
        
        part washChamber {
            attribute sprayPressure : PressureValue;
        }
        
        part disinfectionUnit {
            attribute uvIntensity : Real;
        }
        
        port sanitizerInput : SanitationInterface;
        
        action def ExecuteSanitationCycle {
            in bedpan : BedpanBasin;
            in agent : SanitizingAgent;
            out sanitizedBedpan : BedpanBasin;
        }
    }
    
    part def StorageRack {
        attribute rackCapacity : Real;
        attribute availableSlots : Real;
        
        action def StoreBedpan {
            in bedpan : BedpanBasin;
        }
        
        action def RetrieveBedpan {
            out bedpan : BedpanBasin;
        }
    }
    
    part def BedpanUnit {
        attribute unitMass : MassValue;
        attribute maxCapacity : VolumeCapacity;
        attribute sanitationStatus : SanitationState;
        
        part basin : BedpanBasin {
            attribute :>> capacity = 2.5 [L];
            attribute :>> material = BedpanMaterial::stainlessSteel;
            attribute :>> sealIntegrity = 1.0;
            
            part :>> contourSurface {
                attribute :>> ergonomicRadius = 12.0 [cm];
                attribute :>> rimThickness = 0.3 [cm];
            }
            
            part :>> baseStructure {
                attribute :>> stability = 0.95;
                attribute :>> loadCapacity = 5.0 [kg];
            }
        }
        
        part handle : HandleAssembly {
            attribute :>> gripDiameter = 3.0 [cm];
            attribute :>> handleLength = 15.0 [cm];
            attribute :>> loadRating = 50.0 [N];
            
            part :>> gripSurface {
                attribute :>> textureCoefficient = 0.85;
            }
        }
        
        part levelSensor : LevelIndicator {
            attribute :>> threshold = 2.3 [L];
        }
    }
    
    state def BedpanLifecycle {
        in bedpanUnit : BedpanUnit;
        
        entry; then sterileState;
        
        state sterileState;
        
        transition sterile_to_clean
            first sterileState
            accept StorageRemoval
            then cleanState;
        
        state cleanState;
        
        transition clean_to_inUse
            first cleanState
            accept PatientUse
            then inUseState;
        
        state inUseState;
        
        transition inUse_to_contaminated
            first inUseState
            accept UseCompleted
            then contaminatedState;
        
        state contaminatedState;
        
        transition contaminated_to_sanitation
            first contaminatedState
            accept TransferToSanitation
            then underSanitationState;
        
        state underSanitationState;
        
        transition sanitation_to_sterile
            first underSanitationState
            accept SanitationComplete
            then sterileState;
    }
    
    action def CollectWaste {
        in bedpan : BedpanUnit;
        in waste : BodilyWaste;
        out updatedBedpan : BedpanUnit;
    }
    
    action def TransportToDisposal {
        in bedpan : BedpanUnit;
        out location : String;
    }
    
    action def EmptyBedpan {
        in bedpan : BedpanUnit;
        out waste : BodilyWaste;
        out emptyBedpan : BedpanUnit;
    }
    
    action def SanitizeBedpan {
        in bedpan : BedpanUnit;
        in sanitizer : SanitizingAgent;
        out cleanBedpan : BedpanUnit;
    }
    
    action def InspectSanitation {
        in bedpan : BedpanUnit;
        out passesInspection : Boolean;
    }
    
    action def BedpanOperationalCycle {
        first start;
        then merge readyForPatient;
        
        action provideBedpan {
            out bedpan : BedpanUnit;
        }
        then collectWaste : CollectWaste {
            in bedpan = provideBedpan.bedpan;
        }
        
        then monitorCapacity : collectWaste.bedpan.levelSensor.MonitorLevel;
        
        then decide;
            if monitorCapacity.isFull then proceedToDisposal;
            if !monitorCapacity.isFull then collectWaste;
        
        action proceedToDisposal;
        then transportToDisposal : TransportToDisposal {
            in bedpan = collectWaste.updatedBedpan;
        }
        
        then emptyBedpan : EmptyBedpan {
            in bedpan = transportToDisposal.bedpan;
        }
        
        then sanitizeBedpan : SanitizeBedpan {
            in bedpan = emptyBedpan.emptyBedpan;
        }
        
        then inspectSanitation : InspectSanitation {
            in bedpan = sanitizeBedpan.cleanBedpan;
        }
        
        then decideInspection;
            if inspectSanitation.passesInspection then storeBedpan;
            if !inspectSanitation.passesInspection then sanitizeBedpan;
        
        action storeBedpan {
            in bedpan = inspectSanitation.bedpan;
        }
        then readyForPatient;
        
        then done;
    }
    
    part bedpanManagementSystem {
        attribute totalInventory : Real;
        attribute cleanInventory : Real;
        attribute inUseCount : Real;
        
        part inventory {
            part bedpans : BedpanUnit[15..30];
        }
        
        part sanitationFacility : SanitationSystem {
            attribute :>> cycleTemperature = 353.15 [K];
            attribute :>> cycleDuration = 600.0 [s];
            
            part :>> washChamber {
                attribute :>> sprayPressure = 300.0 [kPa];
            }
            
            part :>> disinfectionUnit {
                attribute :>> uvIntensity = 0.95;
            }
        }
        
        part storage : StorageRack {
            attribute :>> rackCapacity = 30.0;
        }
        
        part wasteDisposal {
            attribute disposalCapacity : VolumeCapacity = 100.0 [L];
        }
        
        perform action operationalCycle[*] ordered references BedpanOperationalCycle;
    }
    
    requirement <'REQ-BP-001'> primaryFunction {
        doc /* The bedpan system shall provide a safe, hygienic, and dignified 
             * means for bedridden or mobility-impaired patients to eliminate 
             * bodily waste without leaving their bed, while preventing 
             * contamination and maintaining patient comfort.
             */
        subject system :>> bedpanManagementSystem;
    }
    
    requirement <'REQ-BP-002'> containmentRequirement {
        doc /* The bedpan shall contain bodily waste without leakage or spillage 
             * during normal use and transport to disposal.
             */
        subject bedpan :>> bedpanManagementSystem.inventory.bedpans;
        
        assert constraint {
            bedpan.basin.sealIntegrity >= 0.99
        }
    }
    
    requirement <'REQ-BP-003'> capacityRequirement {
        doc /* Each bedpan unit shall have sufficient capacity to accommodate 
             * typical waste volumes without overflow.
             */
        subject bedpan :>> bedpanManagementSystem.inventory.bedpans;
        
        assert constraint {
            bedpan.basin.capacity >= 2.0 [L]
        }
    }
    
    requirement <'REQ-BP-004'> sanitationRequirement {
        doc /* All bedpans shall undergo thorough sanitation between patient uses 
             * to eliminate pathogens and prevent cross-contamination.
             */
        subject system :>> bedpanManagementSystem;
        
        assert constraint {
            system.sanitationFacility.cycleTemperature >= 343.15 [K] and
            system.sanitationFacility.cycleDuration >= 300.0 [s]
        }
    }
    
    requirement <'REQ-BP-005'> inventoryRequirement {
        doc /* The system shall maintain adequate clean bedpan inventory to ensure 
             * availability for patient needs at all times.
             */
        subject system :>> bedpanManagementSystem;
        
        assert constraint {
            system.cleanInventory >= 0.4 * system.totalInventory
        }
    }
    
    requirement <'REQ-BP-006'> ergonomicRequirement {
        doc /* Bedpans shall be designed with contoured surfaces and smooth rims 
             * to maximize patient comfort and minimize pressure points.
             */
        subject bedpan :>> bedpanManagementSystem.inventory.bedpans;
        
        assert constraint {
            bedpan.basin.contourSurface.ergonomicRadius >= 10.0 [cm] and
            bedpan.basin.contourSurface.rimThickness <= 0.5 [cm]
        }
    }
    
    requirement <'REQ-BP-007'> materialSafetyRequirement {
        doc /* Bedpans shall be constructed from non-porous, autoclavable materials 
             * that resist bacterial colonization and chemical degradation.
             */
        subject bedpan :>> bedpanManagementSystem.inventory.bedpans;
        
        assert constraint {
            bedpan.basin.material == BedpanMaterial::stainlessSteel or
            bedpan.basin.material == BedpanMaterial::medicalGradePlastic
        }
    }
    
    requirement <'REQ-BP-008'> handlingRequirement {
        doc /* Bedpan handles shall provide secure grip and support adequate load 
             * during transport while minimizing caregiver strain.
             */
        subject bedpan :>> bedpanManagementSystem.inventory.bedpans;
        
        assert constraint {
            bedpan.handle.loadRating >= 40.0 [N] and
            bedpan.handle.gripSurface.textureCoefficient >= 0.75
        }
    }
    
    constraint def VolumeContainmentConstraint {
        in currentLevel : FluidLevel;
        in maxCapacity : VolumeCapacity;
        currentLevel <= maxCapacity
    }
    
    constraint def MassLimitConstraint {
        in unitMass : MassValue;
        in maxMass : MassValue;
        unitMass <= maxMass
    }
    
    part bedpanImplementation : BedpanUnit {
        attribute :>> unitMass = 0.65 [kg];
        attribute :>> maxCapacity = 2.5 [L];
        attribute :>> sanitationStatus = SanitationState::sterile;
        
        assert constraint volumeLimit : VolumeContainmentConstraint {
            in currentLevel = basin.currentLevel;
            in maxCapacity = basin.capacity;
        }
        
        assert constraint massLimit : MassLimitConstraint {
            in unitMass = unitMass;
            in maxMass = 1.0 [kg];
        }
    }
    
    satisfy primaryFunction by bedpanManagementSystem;
    satisfy containmentRequirement by bedpanImplementation;
    satisfy capacityRequirement by bedpanImplementation;
    satisfy sanitationRequirement by bedpanManagementSystem.sanitationFacility;
    satisfy inventoryRequirement by bedpanManagementSystem;
    satisfy ergonomicRequirement by bedpanImplementation;
    satisfy materialSafetyRequirement by bedpanImplementation;
    satisfy handlingRequirement by bedpanImplementation;
}
