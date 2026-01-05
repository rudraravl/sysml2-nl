package LawnMowerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CuttingHeightValue :> LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }
    
    attribute def BladeSpeedValue :> AngularVelocityValue {
        attribute :>> num : Real;
    }
    
    attribute def EngineRPMValue :> AngularVelocityValue {
        attribute :>> num : Real;
    }
    
    item def FuelMixture {
        attribute fuelLevel : Real;
        attribute octaneRating : Real;
    }
    
    item def GrassClippings {
        attribute volume : VolumeValue;
        attribute moisture : Real;
    }
    
    item def SafetyCommand {
        attribute emergencyStop : Boolean;
        attribute operatorPresent : Boolean;
    }
    
    port def FuelInputPort {
        in item fuel : FuelMixture;
    }
    
    port def MechanicalPowerPort {
        out attribute torque : TorqueValue;
        out attribute rotationalSpeed : AngularVelocityValue;
    }
    
    port def BladeInputPort {
        in attribute driveTorque : TorqueValue;
        in attribute driveSpeed : AngularVelocityValue;
    }
    
    port def SafetyControlPort {
        in item safetyCmd : SafetyCommand;
    }
    
    port def ClippingsDischargePort {
        out item clippings : GrassClippings;
    }
    
    part def Engine {
        attribute currentRPM : EngineRPMValue;
        attribute maxRPM : EngineRPMValue;
        attribute isRunning : Boolean;
        attribute throttlePosition : Real;
        
        port fuelInput : FuelInputPort;
        port powerOutput : MechanicalPowerPort;
    }
    
    part def CuttingDeck {
        attribute bladeSpeed : BladeSpeedValue;
        attribute cuttingHeight : CuttingHeightValue;
        attribute deckWidth : LengthValue;
        attribute bladesEngaged : Boolean;
        
        port bladeInput : BladeInputPort;
        port clippingsOutput : ClippingsDischargePort;
    }
    
    part def HeightAdjuster {
        attribute currentHeight : CuttingHeightValue;
        attribute minHeight : CuttingHeightValue;
        attribute maxHeight : CuttingHeightValue;
        attribute adjustmentIncrement : LengthValue;
    }
    
    part def SafetyInterlock {
        attribute operatorPresent : Boolean;
        attribute bladeEngageLever : Boolean;
        attribute safetyEnabled : Boolean;
        
        port safetyControl : SafetyControlPort;
    }
    
    part def CollectionBag {
        attribute capacity : VolumeValue;
        attribute currentLoad : VolumeValue;
        attribute isFull : Boolean;
        
        port clippingsInput : ~ClippingsDischargePort;
    }
    
    action def StartEngine {
        in fuelAvailable : Boolean;
        in safetyOK : Boolean;
        out engineStarted : Boolean;
    }
    
    action def EngageBlades {
        in engineRunning : Boolean;
        in safetyOK : Boolean;
        in heightSet : Boolean;
        out bladesActive : Boolean;
    }
    
    action def CutGrassStrip {
        in grassHeight : LengthValue;
        in targetHeight : CuttingHeightValue;
        in bladeSpeed : BladeSpeedValue;
        out clippingsProduced : GrassClippings;
    }
    
    action def DisengageBlades {
        in bladesActive : Boolean;
        out bladesStopped : Boolean;
    }
    
    action def ShutdownEngine {
        in engineRunning : Boolean;
        out engineStopped : Boolean;
    }
    
    action def MowLawnArea {
        in targetCuttingHeight : CuttingHeightValue;
        in areaLength : LengthValue;
        in areaWidth : LengthValue;
        out totalClippings : GrassClippings[*] := ();
        
        private attribute stripsCovered : Real := 0.0;
        private attribute totalStrips : Real;
        
        first start;
        
        then action checkSafety {
            out safetyStatus : Boolean;
        }
        
        then decide;
            if checkSafety.safetyStatus then proceedToStart;
            if not checkSafety.safetyStatus then abortMowing;
        
        action proceedToStart;
        
        then action setHeight {
            in desiredHeight = targetCuttingHeight;
            out heightAdjusted : Boolean;
        }
        
        then action startEngine : StartEngine {
            in fuelAvailable = true;
            in safetyOK = checkSafety.safetyStatus;
            out engineStarted;
        }
        
        then action engageBlades : EngageBlades {
            in engineRunning = startEngine.engineStarted;
            in safetyOK = checkSafety.safetyStatus;
            in heightSet = setHeight.heightAdjusted;
            out bladesActive;
        }
        
        then assign totalStrips := areaWidth.num / 0.5;
        
        then merge mowingLoop;
        
        then action monitorArea {
            out currentStripGrassHeight : LengthValue;
            out stripComplete : Boolean;
        }
        
        then decide;
            if monitorArea.currentStripGrassHeight > targetCuttingHeight then cutStrip;
            if monitorArea.currentStripGrassHeight <= targetCuttingHeight then advanceStrip;
        
        action cutStrip : CutGrassStrip {
            in grassHeight = monitorArea.currentStripGrassHeight;
            in targetHeight = targetCuttingHeight;
            in bladeSpeed;
            out clippingsProduced;
        }
        
        then assign totalClippings := totalClippings->including(cutStrip.clippingsProduced);
        
        then action checkBagCapacity {
            in clippings = cutStrip.clippingsProduced;
            out bagFull : Boolean;
        }
        
        then decide;
            if checkBagCapacity.bagFull then emptyBag;
            if not checkBagCapacity.bagFull then advanceStrip;
        
        action emptyBag {
            out bagEmptied : Boolean;
        }
        
        then advanceStrip;
        
        action advanceStrip {
            out stripAdvanced : Boolean;
        }
        
        then assign stripsCovered := stripsCovered + 1.0;
        
        then decide;
            if stripsCovered < totalStrips then mowingLoop;
            if stripsCovered >= totalStrips then finishMowing;
        
        action finishMowing;
        
        then action disengageBlades : DisengageBlades {
            in bladesActive = engageBlades.bladesActive;
            out bladesStopped;
        }
        
        then action shutdownEngine : ShutdownEngine {
            in engineRunning = startEngine.engineStarted;
            out engineStopped;
        }
        
        then done;
        
        action abortMowing;
        then done;
    }
    
    part def LawnMower {
        attribute targetHeight : CuttingHeightValue;
        attribute operationalState : String;
        
        part engine : Engine {
            :>> maxRPM {
                :>> num = 3600.0;
            }
            perform mowingOperation.startEngine;
        }
        
        part cuttingDeck : CuttingDeck {
            :>> deckWidth = 53.0 [SI::cm];
            perform mowingOperation.cutStrip;
        }
        
        part heightAdjuster : HeightAdjuster {
            :>> minHeight {
                :>> num = 25.0;
                :>> mRef = SI::mm;
            }
            :>> maxHeight {
                :>> num = 100.0;
                :>> mRef = SI::mm;
            }
            perform mowingOperation.setHeight;
        }
        
        part safetyInterlock : SafetyInterlock {
            perform mowingOperation.checkSafety;
        }
        
        part collectionBag : CollectionBag {
            :>> capacity = 60.0 [SI::L];
            perform mowingOperation.checkBagCapacity;
            perform mowingOperation.emptyBag;
        }
        
        connection engineToDeck connect engine.powerOutput to cuttingDeck.bladeInput;
        connection deckToBag connect cuttingDeck.clippingsOutput to collectionBag.clippingsInput;
        
        perform action mowingOperation : MowLawnArea {
            in targetCuttingHeight = targetHeight;
            in areaLength = 20.0 [SI::m];
            in areaWidth = 10.0 [SI::m];
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The lawn mower shall cut grass across a designated area to a specified uniform height. */
        
        subject mower : LawnMower;
        
        require constraint {
            mower.cuttingDeck.cuttingHeight == mower.targetHeight
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The lawn mower blades shall only operate when the operator is present and safety interlock is engaged. */
        
        subject mower : LawnMower;
        
        require constraint {
            mower.cuttingDeck.bladesEngaged implies 
                (mower.safetyInterlock.operatorPresent and mower.safetyInterlock.safetyEnabled)
        }
    }
    
    requirement def CuttingPerformanceRequirement {
        doc /* The lawn mower shall cut grass to within 5mm of the target height setting. */
        
        subject mower : LawnMower;
        
        require constraint {
            abs(mower.cuttingDeck.cuttingHeight.num - mower.targetHeight.num) <= 5.0
        }
    }
    
    requirement def OperationalRequirement {
        doc /* The lawn mower shall successfully mow a lawn area by cutting grass to operator-specified height. */
        
        subject lawnMower : LawnMower;
        
        assume constraint fuelAvailable {
            lawnMower.engine.fuelInput.fuel.fuelLevel > 0.1
        }
        
        assume constraint operatorReady {
            lawnMower.safetyInterlock.operatorPresent == true
        }
        
        require primaryFunction : PrimaryFunctionRequirement;
        require safety : SafetyRequirement;
        require performance : CuttingPerformanceRequirement;
    }
    
    part residentialLawnMower : LawnMower {
        :>> targetHeight {
            :>> num = 50.0;
            :>> mRef = SI::mm;
        }
    }
    
    requirement systemRequirement : OperationalRequirement {
        :>> lawnMower = residentialLawnMower;
    }
}
