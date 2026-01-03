package 'Murphy Drip Intravenous Infusion System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DropRate;
    attribute def ClampPosition;
    attribute def StartInfusion;
    attribute def StopInfusion;
    attribute def AdjustRate;
    
    item def IVFluid {
        attribute volume : VolumeValue;
        attribute viscosity : Real;
    }
    
    port def FluidPort {
        attribute flowRate : ISQ::VolumetricFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    part def IVBag {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute height : LengthValue;
        port fluidOutlet : FluidPort;
    }
    
    part def SpikeAdapter {
        attribute pierced : Boolean;
        port bagConnection : FluidPort;
        port tubeConnection : FluidPort;
    }
    
    part def DripChamber {
        attribute chamberCapacity : VolumeValue;
        attribute dropFactor : Real;
        attribute observedDropsPerMinute : Real;
        attribute fluidLevel : VolumeValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    part def RollerClamp {
        attribute position : Real;
        attribute minPosition : Real := 0.0;
        attribute maxPosition : Real := 1.0;
        port tubeInlet : FluidPort;
        port tubeOutlet : FluidPort;
    }
    
    part def IVTubing {
        attribute length : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute resistance : Real;
        port proximalEnd : FluidPort;
        port distalEnd : FluidPort;
    }
    
    part def IVCatheter {
        attribute gauge : Real;
        attribute insertionSite : String;
        port connection : FluidPort;
    }
    
    action def PrimeSystem {
        in bagVolume : VolumeValue;
        out systemPrimed : Boolean;
        
        first start;
        then action openClamp {
            doc /* Open roller clamp fully to allow fluid flow */
        }
        then action fillChamber {
            doc /* Fill drip chamber to approximately half capacity */
        }
        then action purgeAir {
            doc /* Allow fluid to flow through tubing to remove air */
        }
        then action closeClamp {
            doc /* Close roller clamp to stop flow */
        }
        then assign systemPrimed := true;
        then done;
    }
    
    action def SetFlowRate {
        in targetDropsPerMinute : Real;
        in currentDropsPerMinute : Real;
        in currentClampPosition : Real;
        out adjustedClampPosition : Real;
        
        first start;
        then action observeDrops {
            doc /* Count drops in drip chamber over time interval */
        }
        then decide;
            if currentDropsPerMinute < targetDropsPerMinute then openMore;
            if currentDropsPerMinute > targetDropsPerMinute then closeMore;
            if currentDropsPerMinute == targetDropsPerMinute then maintain;
        
        action openMore {
            doc /* Increase clamp opening to increase flow */
        }
        then assign adjustedClampPosition := currentClampPosition + 0.1;
        then done;
        
        action closeMore {
            doc /* Decrease clamp opening to decrease flow */
        }
        then assign adjustedClampPosition := currentClampPosition - 0.1;
        then done;
        
        action maintain {
            doc /* Maintain current clamp position */
        }
        then assign adjustedClampPosition := currentClampPosition;
        then done;
    }
    
    action def MonitorInfusion {
        in bagVolume : VolumeValue;
        in flowRate : ISQ::VolumetricFlowRateValue;
        out remainingVolume : VolumeValue;
        out estimatedTimeRemaining : TimeValue;
        
        private attribute currentRemaining : VolumeValue := bagVolume;
        
        first start;
        then merge continuousMonitoring;
        
        then action checkVolume {
            doc /* Check current fluid volume in bag */
        }
        
        then decide;
            if currentRemaining <= 0.0 [mL] then alertEmpty;
            if currentRemaining < 100.0 [mL] then alertLow;
            if currentRemaining >= 100.0 [mL] then continueMonitoring;
        
        action alertEmpty {
            doc /* Bag is empty, infusion complete */
        }
        then assign remainingVolume := currentRemaining;
        then done;
        
        action alertLow {
            doc /* Bag volume is low, prepare replacement */
        }
        then assign remainingVolume := currentRemaining;
        then continuousMonitoring;
        
        action continueMonitoring {
            doc /* Continue normal monitoring */
        }
        then assign remainingVolume := currentRemaining;
        then continuousMonitoring;
    }
    
    action def DeliverFluid {
        in prescribedVolume : VolumeValue;
        in prescribedRate : ISQ::VolumetricFlowRateValue;
        out deliveredVolume : VolumeValue;
        
        private attribute currentRemaining : VolumeValue := prescribedVolume;
        
        first start;
        
        then action primeSystem : PrimeSystem {
            in bagVolume;
            out systemPrimed;
        }
        
        then action initiateFlow {
            doc /* Begin fluid delivery by adjusting roller clamp */
        }
        
        then merge activeDelivery;
        
        then action setRate : SetFlowRate {
            in targetDropsPerMinute;
            in currentDropsPerMinute;
            in currentClampPosition;
            out adjustedClampPosition;
        }
        
        then action monitor : MonitorInfusion {
            in bagVolume;
            in flowRate;
            out remainingVolume;
            out estimatedTimeRemaining;
        }
        
        then decide;
            if monitor.remainingVolume > 0.0 [mL] then activeDelivery;
            if monitor.remainingVolume <= 0.0 [mL] then completeInfusion;
        
        action completeInfusion {
            doc /* Infusion complete, close clamp */
        }
        then assign deliveredVolume := prescribedVolume;
        then done;
    }
    
    state def InfusionStates {
        entry; then notReady;
        
        state notReady {
            doc /* System not prepared for use */
        }
        accept StartInfusion then priming;
        
        state priming {
            doc /* Removing air from system and filling tubing */
            do action primingAction {
                in systemComponents;
                out primedStatus;
            }
        }
        then ready;
        
        state ready {
            doc /* System primed and ready to begin infusion */
        }
        accept AdjustRate then adjusting;
        accept StartInfusion then infusing;
        
        state adjusting {
            doc /* Adjusting flow rate via roller clamp */
            do action adjustFlowRate {
                in targetRate;
                in currentRate;
                out newClampPosition;
            }
        }
        then infusing;
        
        state infusing {
            doc /* Actively delivering fluid to patient */
            do action deliverFluidContinuously {
                in flowRate;
                out volumeDelivered;
            }
        }
        accept AdjustRate then adjusting;
        accept StopInfusion then stopped;
        
        state stopped {
            doc /* Infusion stopped by user or completion */
        }
        accept StartInfusion then ready;
    }
    
    part murphyDripSystem {
        doc /* Complete gravity-fed intravenous infusion system using Murphy drip principle */
        
        attribute prescribedVolume : VolumeValue;
        attribute prescribedFlowRate : ISQ::VolumetricFlowRateValue;
        attribute totalDelivered : VolumeValue;
        
        part ivBag : IVBag {
            attribute :>> capacity = 1000.0 [mL];
            attribute :>> currentVolume = 1000.0 [mL];
            attribute :>> height = 100.0 [cm];
        }
        
        part spike : SpikeAdapter {
            attribute :>> pierced = true;
        }
        
        part chamber : DripChamber {
            attribute :>> chamberCapacity = 20.0 [mL];
            attribute :>> dropFactor = 20.0;
            attribute :>> observedDropsPerMinute = 0.0;
            attribute :>> fluidLevel = 10.0 [mL];
        }
        
        part clamp : RollerClamp {
            attribute :>> position = 0.0;
        }
        
        part tubing : IVTubing {
            attribute :>> length = 180.0 [cm];
            attribute :>> innerDiameter = 3.0 [mm];
            attribute :>> resistance = 1.0;
        }
        
        part catheter : IVCatheter {
            attribute :>> gauge = 18.0;
            attribute :>> insertionSite = "peripheral vein";
        }
        
        connect ivBag.fluidOutlet to spike.bagConnection;
        connect spike.tubeConnection to chamber.inlet;
        connect chamber.outlet to tubing.proximalEnd;
        connect tubing.distalEnd to clamp.tubeInlet;
        connect clamp.tubeOutlet to catheter.connection;
        
        constraint gravityDrivenFlow {
            doc /* Flow rate is determined by gravity, tubing resistance, and clamp position */
            tubing.proximalEnd.flowRate == 
                (ivBag.height * 9.81 [m/s^2] * clamp.position) / tubing.resistance
        }
        
        constraint chamberFluidLevel {
            doc /* Drip chamber must maintain adequate fluid level to prevent air entry */
            chamber.fluidLevel >= chamber.chamberCapacity * 0.25 and
            chamber.fluidLevel <= chamber.chamberCapacity * 0.75
        }
        
        perform action deliverFluid : DeliverFluid {
            in prescribedVolume = murphyDripSystem.prescribedVolume;
            in prescribedRate = murphyDripSystem.prescribedFlowRate;
            out deliveredVolume = murphyDripSystem.totalDelivered;
        }
        
        exhibit state infusionStateMachine : InfusionStates;
    }
    
    requirement def PrimaryFunctionRequirement;
    
    requirement <'MDS-PF-001'> gravityFedFluidDelivery : PrimaryFunctionRequirement {
        doc /* The Murphy drip system shall deliver intravenous fluids to a patient 
               using gravity-driven flow, with manual flow rate control via a roller 
               clamp and visual flow verification through a transparent drip chamber. */
        
        subject systemUnderTest : murphyDripSystem;
        
        require constraint systemComponents {
            doc /* System must include all essential components */
            systemUnderTest.ivBag != null and
            systemUnderTest.chamber != null and
            systemUnderTest.clamp != null and
            systemUnderTest.tubing != null and
            systemUnderTest.catheter != null
        }
    }
    
    requirement <'MDS-FR-001'> controlledFlowRate {
        doc /* The system shall enable manual adjustment of fluid flow rate 
               through roller clamp positioning. */
        
        subject clampUnderTest : murphyDripSystem.clamp;
        
        require constraint clampAdjustability {
            clampUnderTest.position >= clampUnderTest.minPosition and
            clampUnderTest.position <= clampUnderTest.maxPosition
        }
    }
    
    requirement <'MDS-FR-002'> visualFlowMonitoring {
        doc /* The drip chamber shall provide visual indication of fluid flow 
               through observable drops. */
        
        subject chamberUnderTest : murphyDripSystem.chamber;
        
        require constraint visibleDrops {
            chamberUnderTest.observedDropsPerMinute >= 0.0
        }
    }
    
    requirement <'MDS-SR-001'> preventAirEmbolism {
        doc /* The system shall prevent air from entering the patient's bloodstream 
               by maintaining proper drip chamber fluid level. */
        
        subject chamberUnderTest : murphyDripSystem.chamber;
        
        require constraint minimumFluidLevel {
            chamberUnderTest.fluidLevel >= chamberUnderTest.chamberCapacity * 0.25
        }
    }
    
    requirement <'MDS-SR-002'> sterileFluidPath {
        doc /* The fluid path from bag to catheter shall maintain sterility 
               throughout the infusion process. */
        
        subject systemUnderTest : murphyDripSystem;
    }
    
    requirement <'MDS-OP-001'> systemPriming {
        doc /* The system shall be primed to remove all air before initiating 
               patient infusion. */
        
        subject systemUnderTest : murphyDripSystem;
        
        require constraint primingComplete {
            systemUnderTest.deliverFluid.primeSystem.systemPrimed == true
        }
    }
}
