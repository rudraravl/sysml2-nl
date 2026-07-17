package SiphonSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    
    port def FluidPort {
        attribute height : LengthValue;
        attribute pressure : PressureValue;
    }
    
    part def UpperReservoir {
        attribute fluidLevel : LengthValue;
        attribute elevation : LengthValue;
        attribute capacity : VolumeValue;
        port outlet : FluidPort;
    }
    
    part def LowerReservoir {
        attribute fluidLevel : LengthValue;
        attribute elevation : LengthValue;
        attribute capacity : VolumeValue;
        port inlet : FluidPort;
    }
    
    part def SiphonTube {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute apexHeight : LengthValue;
        port upperEnd : FluidPort;
        port lowerEnd : FluidPort;
    }
    
    action def PrimeSiphon {
        in upperLevel : LengthValue;
        in apexHeight : LengthValue;
        out isPrimed : Boolean;
    }
    
    action def ComputeFlowRate {
        in upperHeight : LengthValue;
        in lowerHeight : LengthValue;
        in density : DensityValue;
        in tubeDiameter : LengthValue;
        out flowRate : VolumeFlowRateValue;
    }
    
    action def CheckFlowConditions {
        in upperLevel : LengthValue;
        in lowerLevel : LengthValue;
        in apexHeight : LengthValue;
        out canContinue : Boolean;
    }
    
    action def UpdateLevels {
        in flowRate : VolumeFlowRateValue;
        in timeStep : TimeValue;
        inout upperLevel : LengthValue;
        inout lowerLevel : LengthValue;
    }
    
    action def TerminateSiphon {
        out stopped : Boolean;
    }
    
    action def SiphonTransferOperation {
        first start;
        then action prime : PrimeSiphon {
            in upperLevel : LengthValue;
            in apexHeight : LengthValue;
            out isPrimed : Boolean;
        }
        then decide;
            if prime.isPrimed then flowLoop;
            else terminate;
        
        action flowLoop {
            first merge continueFlow;
            then action checkConditions : CheckFlowConditions {
                in upperLevel : LengthValue;
                in lowerLevel : LengthValue;
                in apexHeight : LengthValue;
                out canContinue : Boolean;
            }
            then decide;
                if checkConditions.canContinue then transferFluid;
                else terminate;
            
            action transferFluid {
                action computeFlow : ComputeFlowRate {
                    in upperHeight : LengthValue;
                    in lowerHeight : LengthValue;
                    in density : DensityValue;
                    in tubeDiameter : LengthValue;
                    out flowRate : VolumeFlowRateValue;
                }
                then action updateFluid : UpdateLevels {
                    in flowRate = computeFlow.flowRate;
                    in timeStep : TimeValue;
                    inout upperLevel : LengthValue;
                    inout lowerLevel : LengthValue;
                }
                then continueFlow;
            }
        }
        
        action terminate : TerminateSiphon {
            out stopped : Boolean;
        }
        then done;
    }
    
    attribute def StartPriming;
    attribute def StopTransfer;
    
    state def SiphonOperatingState {
        entry; then idle;
        
        state idle;
        
        transition idle_to_priming
            first idle
            accept StartPriming
            then priming;
        
        state priming {
            entry action initiatePrime : PrimeSiphon;
        }
        
        transition priming_to_flowing
            first priming
            if initiatePrime.isPrimed
            then flowing;
        
        transition priming_to_idle
            first priming
            if !initiatePrime.isPrimed
            then idle;
        
        state flowing {
            entry; then activeTransfer;
            state activeTransfer {
                do action transfer : UpdateLevels;
            }
        }
        
        transition flowing_to_idle_manual
            first flowing
            accept StopTransfer
            then idle;
    }
    
    part siphonSystem {
        attribute fluidType : FluidType;
        attribute gravity : AccelerationValue = 9.81 [SI::m/SI::s^2];
        attribute atmosphericPressure : PressureValue = 101325.0 [SI::Pa];
        
        part upperReservoir : UpperReservoir {
            attribute :>> fluidLevel = 5.0 [SI::m];
            attribute :>> elevation = 10.0 [SI::m];
            attribute :>> capacity = 2.0 [SI::m^3];
        }
        
        part lowerReservoir : LowerReservoir {
            attribute :>> fluidLevel = 1.0 [SI::m];
            attribute :>> elevation = 2.0 [SI::m];
            attribute :>> capacity = 3.0 [SI::m^3];
        }
        
        part tube : SiphonTube {
            attribute :>> length = 12.0 [SI::m];
            attribute :>> diameter = 0.05 [SI::m];
            attribute :>> apexHeight = 11.0 [SI::m];
        }
        
        connection upperConnection connect 
            upperReservoir.outlet to tube.upperEnd;
        
        connection lowerConnection connect 
            tube.lowerEnd to lowerReservoir.inlet;
        
        perform action transferBehavior : SiphonTransferOperation;
        
        exhibit state operatingState : SiphonOperatingState;
    }
    
    requirement def SiphonPrimaryFunction {
        doc /* The siphon system shall transfer fluid from an upper reservoir 
             to a lower reservoir using gravitational potential energy and 
             atmospheric pressure differential, without requiring external 
             mechanical pumping. */
        
        subject siphonSystem;
    }
    
    requirement def SiphonPerformance {
        doc /* The siphon system shall achieve flow rate determined by height 
             differential and fluid properties according to Torricelli's law. */
        
        subject siphonSystem;
    }
    
    requirement def SiphonSafety {
        doc /* The siphon system shall automatically cease operation when 
             physical conditions no longer support gravity-driven flow. */
        
        subject siphonSystem;
    }
    
    requirement primaryRequirement : SiphonPrimaryFunction {
        require performanceRequirement : SiphonPerformance;
        require safetyRequirement : SiphonSafety;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SiphonSystem::*;

    part testSubject = siphonSystem {
        exhibit state sm : SiphonOperatingState;
    }

    action orchestrator {
        attribute testUpperHeight : LengthValue;
        attribute testLowerHeight : LengthValue;
        attribute testDensity : DensityValue;
        attribute testTubeDiameter : LengthValue;
        action computeFlowProbe : ComputeFlowRate {
            in upperHeight = testUpperHeight;
            in lowerHeight = testLowerHeight;
            in density = testDensity;
            in tubeDiameter = testTubeDiameter;
        }
        attribute testStartPriming : StartPriming;
        attribute testStopTransfer : StopTransfer;
        action triggerStartPriming send testStartPriming to testSubject;
        action triggerStopTransfer send testStopTransfer to testSubject;
        first computeFlowProbe;
        then triggerStartPriming;
        then triggerStopTransfer;
    }
}
