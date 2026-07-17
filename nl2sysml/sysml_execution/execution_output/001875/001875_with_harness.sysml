package SyphonSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    
    item def Fluid {
        attribute fluidType : FluidType;
        attribute density : ISQ::DensityValue;
        attribute viscosity : Real;
    }
    
    port def FluidPort {
        attribute pressure : ISQ::PressureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        out item fluid : Fluid;
    }
    
    part def SourceReservoir {
        attribute currentVolume : ISQ::VolumeValue;
        attribute maxVolume : ISQ::VolumeValue;
        attribute surfaceHeight : ISQ::LengthValue;
        port outlet : FluidPort;
        
        assert constraint volumeCapacity {
            currentVolume <= maxVolume
        }
    }
    
    part def SyphonTube {
        attribute tubeLength : ISQ::LengthValue;
        attribute tubeDiameter : ISQ::LengthValue;
        attribute apexHeight : ISQ::LengthValue;
        attribute inletHeight : ISQ::LengthValue;
        port inlet : ~FluidPort;
        port outlet : FluidPort;
    }
    
    part def ReceivingReservoir {
        attribute currentVolume : ISQ::VolumeValue;
        attribute maxVolume : ISQ::VolumeValue;
        attribute surfaceHeight : ISQ::LengthValue;
        port inlet : ~FluidPort;
        
        assert constraint capacityLimit {
            currentVolume <= maxVolume
        }
    }
    
    connection def FluidConnection {
        end source : FluidPort;
        end destination : ~FluidPort;
    }
    
    requirement def PrimaryTransferRequirement {
        doc /* The syphon system shall transfer fluid from an elevated source 
                reservoir to a lower receiving reservoir using gravitational 
                potential energy without external power. */
        
        require constraint elevationDifference {
            doc /* Source reservoir surface must be higher than receiving reservoir surface. */
        }
        
        require constraint continuousPath {
            doc /* Tube must provide continuous fluid path from source to destination. */
        }
    }
    
    requirement def FlowInitiationRequirement {
        doc /* The syphon shall initiate flow when the tube is completely filled 
                with fluid and atmospheric pressure acts on both reservoir surfaces. */
        
        require constraint tubePriming {
            doc /* Tube must be filled with fluid to eliminate air pockets. */
        }
        
        require constraint apexSubmersion {
            doc /* Tube apex height must not exceed atmospheric pressure head for the fluid. */
        }
    }
    
    requirement def FlowContinuationRequirement {
        doc /* The syphon shall maintain flow until source is depleted or 
                receiving reservoir is full or elevation difference is eliminated. */
    }
    
    action def PrimeSyphon {
        in apexHeight : ISQ::LengthValue;
        in sourceHeight : ISQ::LengthValue;
        in fluidDensity : ISQ::DensityValue;
        out isPrimed : Boolean;
        
        doc /* Verify syphon can be primed by checking apex height against 
                atmospheric pressure head. */
        
        private attribute atmosphericPressure : ISQ::PressureValue = 101325.0 [SI::Pa];
        private attribute gravity : ISQ::AccelerationValue = 9.81 [SI::m/'s^2'];
        private attribute maxApexHeight : ISQ::LengthValue;
        
        first start;
        then assign maxApexHeight := atmosphericPressure / (fluidDensity * gravity);
        then decide;
            if (apexHeight < maxApexHeight) and (sourceHeight > apexHeight) then primingSuccess;
            else primingFailure;
        
        action primingSuccess {
            then assign isPrimed := true;
        }
        then done;
        
        action primingFailure {
            then assign isPrimed := false;
        }
        then done;
    }
    
    action def MonitorLevels {
        in sourceHeight : ISQ::LengthValue;
        in receivingHeight : ISQ::LengthValue;
        in inletHeight : ISQ::LengthValue;
        out heightDifference : ISQ::LengthValue;
        out flowPossible : Boolean;
        
        first start;
        then assign heightDifference := sourceHeight - receivingHeight;
        then decide;
            if (sourceHeight > inletHeight) and (heightDifference > 0.0 [SI::m]) then flowEnabled;
            else flowDisabled;
        
        action flowEnabled {
            then assign flowPossible := true;
        }
        then done;
        
        action flowDisabled {
            then assign flowPossible := false;
        }
        then done;
    }
    
    action def ComputeFlowRate {
        in heightDifference : ISQ::LengthValue;
        in tubeDiameter : ISQ::LengthValue;
        in tubeLength : ISQ::LengthValue;
        in fluidDensity : ISQ::DensityValue;
        in fluidViscosity : Real;
        out computedFlowRate : ISQ::VolumeFlowRateValue;
        
        doc /* Calculate flow rate using Torricelli's principle and pipe flow equations. */
        
        private attribute gravity : ISQ::AccelerationValue = 9.81 [SI::m/'s^2'];
        private attribute velocity : ISQ::SpeedValue;
        private attribute crossSectionalArea : ISQ::AreaValue;
        private attribute pi : Real = 3.14159;
        
        first start;
        then assign velocity := (2.0 * gravity * heightDifference) ** 0.5;
        then assign crossSectionalArea := pi * (tubeDiameter / 2.0) ** 2.0;
        then assign computedFlowRate := velocity * crossSectionalArea;
        then done;
    }
    
    action def UpdateVolumes {
        in flowRate : ISQ::VolumeFlowRateValue;
        in timeStep : ISQ::TimeValue;
        inout sourceVolume : ISQ::VolumeValue;
        inout receivingVolume : ISQ::VolumeValue;
        
        private attribute transferredVolume : ISQ::VolumeValue;
        
        first start;
        then assign transferredVolume := flowRate * timeStep;
        then assign sourceVolume := sourceVolume - transferredVolume;
        then assign receivingVolume := receivingVolume + transferredVolume;
        then done;
    }
    
    action def OperateSyphon {
        in initialSourceVolume : ISQ::VolumeValue;
        in initialReceivingVolume : ISQ::VolumeValue;
        in sourceMaxVolume : ISQ::VolumeValue;
        in receivingMaxVolume : ISQ::VolumeValue;
        in initialSourceHeight : ISQ::LengthValue;
        in initialReceivingHeight : ISQ::LengthValue;
        in tubeApexHeight : ISQ::LengthValue;
        in tubeInletHeight : ISQ::LengthValue;
        in tubeDiameter : ISQ::LengthValue;
        in tubeLength : ISQ::LengthValue;
        in fluidDensity : ISQ::DensityValue;
        in fluidViscosity : Real;
        
        private attribute sourceVolume : ISQ::VolumeValue := initialSourceVolume;
        private attribute receivingVolume : ISQ::VolumeValue := initialReceivingVolume;
        private attribute sourceHeight : ISQ::LengthValue := initialSourceHeight;
        private attribute receivingHeight : ISQ::LengthValue := initialReceivingHeight;
        
        first start;
        
        then action prime : PrimeSyphon {
            in apexHeight = tubeApexHeight;
            in sourceHeight = sourceHeight;
            in fluidDensity = fluidDensity;
            out isPrimed;
        }
        
        then decide;
            if prime.isPrimed then beginFlow;
            else failedStart;
        
        merge beginFlow;
        
        then action monitor : MonitorLevels {
            in sourceHeight = sourceHeight;
            in receivingHeight = receivingHeight;
            in inletHeight = tubeInletHeight;
            out heightDifference;
            out flowPossible;
        }
        
        then decide;
            if monitor.flowPossible and (receivingVolume < receivingMaxVolume) then computeFlow;
            else terminateFlow;
        
        action computeFlow : ComputeFlowRate {
            in heightDifference = monitor.heightDifference;
            in tubeDiameter = tubeDiameter;
            in tubeLength = tubeLength;
            in fluidDensity = fluidDensity;
            in fluidViscosity = fluidViscosity;
            out computedFlowRate;
        }
        
        then action update : UpdateVolumes {
            in flowRate = computeFlow.computedFlowRate;
            in timeStep = 1.0 [SI::s];
            inout sourceVolume = sourceVolume;
            inout receivingVolume = receivingVolume;
        }
        
        then beginFlow;
        
        action terminateFlow {
            doc /* Stop flow when conditions no longer support syphon action. */
        }
        then done;
        
        action failedStart {
            doc /* Syphon cannot be primed under current conditions. */
        }
        then done;
    }
    
    state def SyphonOperationState {
        entry; then idle;
        
        state idle {
            doc /* Syphon is inactive, tube may be empty or partially filled. */
        }
        
        transition idle_to_priming
            first idle
            accept StartPriming
            then priming;
        
        state priming {
            doc /* Filling tube with fluid to eliminate air and establish continuous liquid column. */
        }
        
        transition priming_to_active
            first priming
            if tubeFilled
            then active;
        
        transition priming_to_idle
            first priming
            if primingFailed
            then idle;
        
        state active {
            doc /* Fluid is flowing from source to receiving reservoir under gravity. */
            entry action transferFluid : OperateSyphon;
        }
        
        transition active_to_idle
            first active
            if sourceEmpty or receivingFull or elevationEqualized
            then idle;
    }
    
    part syphonSystem {
        doc /* A passive fluid transfer system utilizing gravitational potential 
                energy to move liquid from an elevated source to a lower destination 
                through a tube that rises above the source surface before descending. */
        
        part source : SourceReservoir {
            attribute :>> currentVolume = 200.0 [SI::L];
            attribute :>> maxVolume = 200.0 [SI::L];
            attribute :>> surfaceHeight = 3.0 [SI::m];
        }
        
        part tube : SyphonTube {
            attribute :>> tubeLength = 5.0 [SI::m];
            attribute :>> tubeDiameter = 0.015 [SI::m];
            attribute :>> apexHeight = 3.5 [SI::m];
            attribute :>> inletHeight = 2.8 [SI::m];
        }
        
        part receiver : ReceivingReservoir {
            attribute :>> currentVolume = 0.0 [SI::L];
            attribute :>> maxVolume = 250.0 [SI::L];
            attribute :>> surfaceHeight = 0.5 [SI::m];
        }
        
        connection sourceToTube : FluidConnection connect 
            source.outlet to tube.inlet;
        
        connection tubeToReceiver : FluidConnection connect 
            tube.outlet to receiver.inlet;
        
        perform action operation : OperateSyphon {
            in initialSourceVolume = source.currentVolume;
            in initialReceivingVolume = receiver.currentVolume;
            in sourceMaxVolume = source.maxVolume;
            in receivingMaxVolume = receiver.maxVolume;
            in initialSourceHeight = source.surfaceHeight;
            in initialReceivingHeight = receiver.surfaceHeight;
            in tubeApexHeight = tube.apexHeight;
            in tubeInletHeight = tube.inletHeight;
            in tubeDiameter = tube.tubeDiameter;
            in tubeLength = tube.tubeLength;
            in fluidDensity = 1000.0 [SI::kg/'m^3'];
            in fluidViscosity = 0.001;
        }
        
        exhibit state operationState : SyphonOperationState;
    }
    
    attribute def StartPriming;
    attribute tubeFilled : Boolean;
    attribute primingFailed : Boolean;
    attribute sourceEmpty : Boolean;
    attribute receivingFull : Boolean;
    attribute elevationEqualized : Boolean;
    
    satisfy syphonSystem by PrimaryTransferRequirement;
    satisfy syphonSystem.tube by FlowInitiationRequirement;
    satisfy syphonSystem.operation by FlowContinuationRequirement;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SyphonSystem::*;

    part testSubject = syphonSystem {
        exhibit state sm : SyphonOperationState;
    }

    action orchestrator {
        attribute testHeightDifference : ISQ::LengthValue;
        attribute testTubeDiameter : ISQ::LengthValue;
        attribute testTubeLength : ISQ::LengthValue;
        attribute testFluidDensity : ISQ::DensityValue;
        action computeFlowProbe : ComputeFlowRate {
            in heightDifference = testHeightDifference;
            in tubeDiameter = testTubeDiameter;
            in tubeLength = testTubeLength;
            in fluidDensity = testFluidDensity;
            in fluidViscosity = 0.0;
        }
        attribute testStartPriming : StartPriming;
        action triggerStartPriming send testStartPriming to testSubject;
        first computeFlowProbe;
        then triggerStartPriming;
    }
}
