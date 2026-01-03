package BonannoCatheterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    item def Urine {
        attribute volume : VolumeValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute specificGravity : Real;
    }
    
    item def SalineSolution {
        attribute volume : VolumeValue;
        attribute concentration : Real;
    }
    
    port def FluidInputPort {
        in item saline : SalineSolution;
    }
    
    port def FluidOutputPort {
        out item urine : Urine;
    }
    
    port def InflationPort {
        in item inflationFluid : SalineSolution;
    }
    
    attribute def BalloonVolume :> VolumeValue;
    attribute def CatheterDiameter :> LengthValue;
    attribute def CatheterLength :> LengthValue;
    
    enum def CatheterState {
        deflated;
        inflated;
        draining;
        irrigating;
        occluded;
    }
    
    part def InflatableBalloon {
        attribute currentVolume : BalloonVolume;
        attribute maxVolume : BalloonVolume = 30.0 [mL];
        attribute minVolume : BalloonVolume = 0.0 [mL];
        attribute isInflated : Boolean;
        
        port inflationPort : InflationPort;
        
        assert constraint volumeLimit {
            currentVolume >= minVolume and currentVolume <= maxVolume
        }
    }
    
    part def DrainageLumen {
        attribute innerDiameter : CatheterDiameter;
        attribute length : CatheterLength;
        attribute flowResistance : Real;
        
        port fluidOutput : FluidOutputPort;
        
        action drainUrine {
            in urineInput : Urine;
            out urineOutput : Urine;
            
            first start;
            then action checkPatency {
                out isPatent : Boolean;
            }
            then decide;
                if checkPatency.isPatent then allowDrainage;
                if not checkPatency.isPatent then blockFlow;
            action allowDrainage {
                :>> urineOutput = urineInput;
            }
            then done;
            action blockFlow;
            then done;
        }
    }
    
    part def IrrigationLumen {
        attribute innerDiameter : CatheterDiameter;
        attribute length : CatheterLength;
        
        port fluidInput : FluidInputPort;
        
        action irrigateBladder {
            in salineInput : SalineSolution;
            out salineOutput : SalineSolution;
            
            first start;
            then action deliverSaline {
                in saline = salineInput;
                out delivered : SalineSolution;
            }
            then done;
        }
    }
    
    part def CatheterTip {
        attribute numberOfEyelets : Integer = 4;
        attribute eyeletDiameter : LengthValue;
        
        action collectUrine {
            out collectedUrine : Urine;
        }
    }
    
    part def CollectionBag {
        attribute capacity : VolumeValue = 2000.0 [mL];
        attribute currentVolume : VolumeValue;
        attribute antiRefluxValve : Boolean = true;
        
        port urineInlet : FluidOutputPort;
        
        assert constraint capacityLimit {
            currentVolume <= capacity
        }
    }
    
    part def BonannoSuprapubicCatheter {
        attribute outerDiameter : CatheterDiameter = 8.0 [mm];
        attribute totalLength : CatheterLength = 300.0 [mm];
        attribute currentState : CatheterState;
        
        part balloon : InflatableBalloon {
            attribute :>> currentVolume = 20.0 [mL];
        }
        
        part drainageLumen : DrainageLumen {
            attribute :>> innerDiameter = 5.0 [mm];
            attribute :>> length = totalLength;
        }
        
        part irrigationLumen : IrrigationLumen {
            attribute :>> innerDiameter = 2.0 [mm];
            attribute :>> length = totalLength;
        }
        
        part tip : CatheterTip {
            attribute :>> eyeletDiameter = 3.0 [mm];
        }
        
        connection drainageFlow connect 
            tip.collectUrine.collectedUrine to drainageLumen.fluidOutput;
        
        state catheterStateMachine {
            entry; then insertion;
            
            state insertion;
            transition insertionToPositioning
                first insertion
                accept at insertion
                if positionedInBladder
                then positioning;
            
            state positioning;
            transition positioningToInflation
                first positioning
                accept at positioning
                if balloonInflationStarted
                then inflation;
            
            state inflation;
            transition inflationToOperational
                first inflation
                accept at inflation
                if balloon.isInflated
                then operational;
            
            state operational {
                state continuousDrainage {
                    do action performDrainage {
                        drainageLumen.drainUrine();
                    }
                }
                
                state intermittentIrrigation {
                    do action performIrrigation {
                        irrigationLumen.irrigateBladder();
                    }
                }
            }
            
            transition operationalToDeflation
                first operational
                accept at operational
                if removalRequested
                then deflation;
            
            state deflation;
            transition deflationToRemoval
                first deflation
                accept at deflation
                if not balloon.isInflated
                then removal;
            
            state removal;
            transition removalToDone
                first removal
                accept at removal
                then done;
        }
    }
    
    part bonannoCatheterSystem {
        part catheter : BonannoSuprapubicCatheter;
        
        part collectionBag : CollectionBag;
        
        connection urineCollection connect 
            catheter.drainageLumen.fluidOutput to collectionBag.urineInlet;
        
        perform action provideContinuousUrinaryDrainage {
            doc /* 
             * The Bonanno catheter system provides continuous urinary drainage
             * from the bladder through a suprapubic approach. The system uses
             * a balloon-retained catheter with dual lumens for simultaneous
             * drainage and irrigation capability.
             */
            
            first start;
            then merge continuousOperation;
            
            then action insertCatheter {
                doc /* Insert catheter through suprapubic incision into bladder */
            }
            
            then action inflateBalloon {
                doc /* Inflate retention balloon to secure catheter position */
            }
            
            then action establishDrainage {
                doc /* Connect drainage lumen to collection system */
            }
            
            then action monitorDrainage {
                out urineVolume : VolumeValue;
                out flowRate : VolumeFlowRateValue;
                out isPatent : Boolean;
            }
            
            then decide;
                if monitorDrainage.isPatent and monitorDrainage.flowRate > 0.0 [mL/s] 
                    then maintainDrainage;
                if not monitorDrainage.isPatent or monitorDrainage.flowRate == 0.0 [mL/s]
                    then performIrrigation;
            
            action maintainDrainage {
                doc /* Continue passive drainage through gravity */
            }
            then continuousOperation;
            
            action performIrrigation {
                doc /* Irrigate through irrigation lumen to clear blockage */
                in saline : SalineSolution;
            }
            then continuousOperation;
        }
    }
    
    requirement <'REQ-BC-001'> continuousUrinaryDrainage {
        doc /* 
         * The Bonanno catheter system shall provide continuous urinary drainage
         * from the bladder via a suprapubic route with minimal interruption.
         */
        subject catheterSystem :>> bonannoCatheterSystem;
        
        require balloonRetention;
        require dualLumenFunction;
    }
    
    requirement <'REQ-BC-002'> balloonRetention {
        doc /* 
         * The inflatable balloon shall maintain catheter position within the bladder
         * when inflated to the specified volume.
         */
        subject balloon :>> bonannoCatheterSystem.catheter.balloon;
        
        assert constraint {
            balloon.currentVolume >= 15.0 [mL] and 
            balloon.currentVolume <= 30.0 [mL] and
            balloon.isInflated == true
        }
    }
    
    requirement <'REQ-BC-003'> dualLumenFunction {
        doc /* 
         * The catheter shall provide independent drainage and irrigation lumens
         * for simultaneous operation when required.
         */
        subject catheter :>> bonannoCatheterSystem.catheter;
    }
    
    requirement <'REQ-BC-004'> drainagePatency {
        doc /* 
         * The drainage lumen shall maintain patency for urine flow with
         * minimal resistance.
         */
        subject drainageLumen :>> bonannoCatheterSystem.catheter.drainageLumen;
        
        assert constraint {
            drainageLumen.innerDiameter >= 4.0 [mm]
        }
    }
    
    requirement <'REQ-BC-005'> collectionCapacity {
        doc /* 
         * The collection bag shall have sufficient capacity for extended
         * drainage periods without requiring frequent emptying.
         */
        subject collectionBag :>> bonannoCatheterSystem.collectionBag;
        
        assert constraint {
            collectionBag.capacity >= 2000.0 [mL]
        }
    }
    
    satisfy continuousUrinaryDrainage by bonannoCatheterSystem;
}
