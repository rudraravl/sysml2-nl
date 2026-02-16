package SyringeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidVolume :> VolumeValue;
    attribute def PressureLevel :> PressureValue;
    attribute def ForceLevel :> ForceValue;
    attribute def DistanceValue :> LengthValue;
    
    enum def SyringeOperationalState {
        ready;
        drawing;
        loaded;
        injecting;
        depleted;
    }
    
    item def MedicalFluid {
        attribute volume : FluidVolume;
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
    }
    
    port def FluidInterface {
        in item fluidIn : MedicalFluid;
        out item fluidOut : MedicalFluid;
    }
    
    port def MechanicalInterface {
        in appliedForce : ForceLevel;
        out resultingDisplacement : DistanceValue;
    }
    
    part def BarrelChamber {
        attribute innerDiameter : DistanceValue;
        attribute maxCapacity : FluidVolume;
        attribute currentContent : FluidVolume;
        attribute internalPressure : PressureLevel;
        
        port fluidInterface : FluidInterface;
        
        assert constraint capacityLimit {
            currentContent <= maxCapacity
        }
    }
    
    part def PlungerAssembly {
        attribute currentPosition : DistanceValue;
        attribute sealDiameter : DistanceValue;
        attribute maxTravel : DistanceValue;
        
        port mechanicalInterface : MechanicalInterface;
        
        assert constraint travelBounds {
            currentPosition >= 0.0 [mm] and currentPosition <= maxTravel
        }
    }
    
    part def NeedleTip {
        attribute gaugeSize : Integer;
        attribute length : DistanceValue;
        attribute innerDiameter : DistanceValue;
        attribute flowResistance : Real;
        
        port inlet : FluidInterface;
        port outlet : FluidInterface;
    }
    
    part def Syringe {
        attribute nominalCapacity : FluidVolume;
        attribute operationalState : SyringeOperationalState;
        attribute totalLength : DistanceValue;
        
        part barrel : BarrelChamber {
            attribute :>> innerDiameter = 8.5 [mm];
            attribute :>> maxCapacity = 10.0 [mL];
            attribute :>> currentContent = 0.0 [mL];
            attribute :>> internalPressure = 101.325 [Pa];
        }
        
        part plunger : PlungerAssembly {
            attribute :>> currentPosition = 0.0 [mm];
            attribute :>> sealDiameter = 8.4 [mm];
            attribute :>> maxTravel = 60.0 [mm];
        }
        
        part needle : NeedleTip {
            attribute :>> gaugeSize = 22;
            attribute :>> length = 25.0 [mm];
            attribute :>> innerDiameter = 0.7 [mm];
            attribute :>> flowResistance = 1.5;
        }
        
        connection barrelToNeedle connect barrel.fluidInterface to needle.inlet;
        
        assert constraint volumePositionRelation {
            barrel.currentContent == (barrel.maxCapacity * (plunger.currentPosition / plunger.maxTravel))
        }
        
        assert constraint pressureBalance {
            barrel.internalPressure >= 101.325 [Pa]
        }
    }
    
    action def AspirateFluid {
        in targetVolume : FluidVolume;
        in withdrawalForce : ForceLevel;
        inout syringeBarrel : BarrelChamber;
        inout syringePlunger : PlungerAssembly;
        out actualVolumeDrawn : FluidVolume;
        
        doc /* Draws fluid into the barrel by retracting the plunger. */
    }
    
    action def InjectFluid {
        in targetVolume : FluidVolume;
        in injectionForce : ForceLevel;
        inout syringeBarrel : BarrelChamber;
        inout syringePlunger : PlungerAssembly;
        out actualVolumeInjected : FluidVolume;
        
        doc /* Expels fluid from the barrel by advancing the plunger. */
    }
    
    action def PurgeSyringe {
        inout syringeBarrel : BarrelChamber;
        inout syringePlunger : PlungerAssembly;
        
        doc /* Removes air bubbles and prepares syringe for use. */
    }
    
    action def PerformFluidTransfer {
        in doseVolume : FluidVolume;
        inout currentState : SyringeOperationalState;
        
        first start;
        then merge awaitCommand;
        
        then decide;
            if currentState == SyringeOperationalState::ready then aspirate;
            if currentState == SyringeOperationalState::loaded then inject;
            if currentState == SyringeOperationalState::depleted then reset;
        
        action aspirate : AspirateFluid {
            in targetVolume = doseVolume;
            in withdrawalForce = 15.0 [N];
            inout syringeBarrel;
            inout syringePlunger;
            out actualVolumeDrawn;
        }
        then updateToLoaded;
        
        action inject : InjectFluid {
            in targetVolume = doseVolume;
            in injectionForce = 20.0 [N];
            inout syringeBarrel;
            inout syringePlunger;
            out actualVolumeInjected;
        }
        then updateToDepleted;
        
        action reset : PurgeSyringe {
            inout syringeBarrel;
            inout syringePlunger;
        }
        then updateToReady;
        
        action updateToLoaded {
            assign currentState := SyringeOperationalState::loaded;
        }
        then awaitCommand;
        
        action updateToDepleted {
            assign currentState := SyringeOperationalState::depleted;
        }
        then awaitCommand;
        
        action updateToReady {
            assign currentState := SyringeOperationalState::ready;
        }
        then awaitCommand;
    }
    
    message def AspirateCommand;
    message def AspirationComplete;
    message def InjectCommand;
    message def InjectionComplete;
    message def ResetCommand;
    
    state def SyringeLifecycle {
        in attribute currentState : SyringeOperationalState;
        
        entry; then readyState;
        
        state readyState {
            entry assign currentState := SyringeOperationalState::ready;
        }
        transition readyToDrawing
            first readyState
            accept AspirateCommand
            then drawingState;
        
        state drawingState {
            entry assign currentState := SyringeOperationalState::drawing;
            do action performAspiration : AspirateFluid;
        }
        transition drawingToLoaded
            first drawingState
            accept AspirationComplete
            then loadedState;
        
        state loadedState {
            entry assign currentState := SyringeOperationalState::loaded;
        }
        transition loadedToInjecting
            first loadedState
            accept InjectCommand
            then injectingState;
        
        state injectingState {
            entry assign currentState := SyringeOperationalState::injecting;
            do action performInjection : InjectFluid;
        }
        transition injectingToDepleted
            first injectingState
            accept InjectionComplete
            then depletedState;
        
        state depletedState {
            entry assign currentState := SyringeOperationalState::depleted;
        }
        transition depletedToReady
            first depletedState
            accept ResetCommand
            then readyState;
    }
    
    requirement def FluidDeliveryAccuracy {
        doc /* The syringe shall deliver fluid volumes with high precision. */
        
        subject syringe : Syringe;
        
        require constraint deliveryTolerance {
            doc /* Delivered volume shall be within 5% of target volume. */
        }
    }
    
    requirement def CapacitySpecification {
        doc /* The syringe shall have adequate capacity for medical applications. */
        
        subject syringe : Syringe;
        
        assert constraint {
            syringe.nominalCapacity >= 5.0 [mL] and syringe.nominalCapacity <= 20.0 [mL]
        }
    }
    
    requirement def StructuralIntegrity {
        doc /* The syringe shall maintain structural integrity under operating conditions. */
        
        subject syringe : Syringe;
        
        require constraint pressureRating {
            syringe.barrel.internalPressure <= 500.0 [Pa];
        }
        
        require constraint leakPrevention {
            doc /* The plunger seal shall prevent fluid leakage during operation. */
        }
    }
    
    requirement def SterilityMaintenance {
        doc /* The syringe shall maintain sterility of fluid path. */
        
        subject syringe : Syringe;
        
        require constraint sealedPath {
            doc /* All fluid contact surfaces shall remain sealed until use. */
        }
    }
    
    requirement <'SYR-FUNC-001'> primaryFluidTransferFunction {
        doc /* The syringe system shall enable controlled aspiration and injection 
             * of precise fluid volumes through mechanical actuation of a sealed 
             * plunger-barrel mechanism with an attached needle for fluid transfer.
             */
        
        subject syringeSystem : Syringe;
        
        assume constraint initialReadyState {
            syringeSystem.operationalState == SyringeOperationalState::ready
        }
        
        assume constraint emptyInitialCondition {
            syringeSystem.barrel.currentContent == 0.0 [mL]
        }
        
        require fluidAccuracy : FluidDeliveryAccuracy {
            subject syringe = syringeSystem;
        }
        require capacitySpec : CapacitySpecification {
            subject syringe = syringeSystem;
        }
        require structuralReq : StructuralIntegrity {
            subject syringe = syringeSystem;
        }
        require sterilityReq : SterilityMaintenance {
            subject syringe = syringeSystem;
        }
    }
    
    part medicalSyringe : Syringe {
        attribute :>> nominalCapacity = 10.0 [mL];
        attribute :>> operationalState = SyringeOperationalState::ready;
        attribute :>> totalLength = 120.0 [mm];
        
        perform action fluidTransferOperation : PerformFluidTransfer {
            in doseVolume = 5.0 [mL];
            inout currentState = operationalState;
        }
        
        exhibit state lifecycle : SyringeLifecycle {
            in attribute currentState = operationalState;
        }
    }
    
    satisfy primaryFluidTransferFunction by medicalSyringe;
}
