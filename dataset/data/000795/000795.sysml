package TourniquetSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CompressionLevel :> Real;
    attribute def BloodFlowRate :> Real;
    attribute def OcclusionStatus :> Boolean;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def LengthValue :> ISQ::LengthValue;
    
    item def BloodFlow {
        attribute flowRate : BloodFlowRate;
        attribute isOccluded : OcclusionStatus;
    }
    
    port def LimbPort {
        in item arterialFlow : BloodFlow;
        out item distalFlow : BloodFlow;
        in attribute appliedPressure : PressureValue;
    }
    
    port def ControlPort {
        in attribute tensionCommand : ForceValue;
        out attribute currentPressure : PressureValue;
        out attribute lockStatus : Boolean;
    }
    
    part def CompressionStrap {
        attribute material : String;
        attribute width : LengthValue;
        attribute maxTensionCapacity : ForceValue;
        attribute currentTension : ForceValue;
        
        port limbContact : LimbPort;
        
        action def TransmitCompression {
            in tension : ForceValue;
            in strapWidth : LengthValue;
            out pressure : PressureValue;
        }
    }
    
    part def WindlassMechanism {
        attribute rodDiameter : LengthValue;
        attribute currentRotation : Real;
        attribute tensionMultiplier : Real;
        
        action def GenerateTension {
            in rotationTurns : Real;
            in multiplier : Real;
            out tensionOutput : ForceValue;
        }
    }
    
    part def SecuringClip {
        attribute isLocked : Boolean;
        attribute lockingForce : ForceValue;
        
        state def ClipStates {
            entry; then open;
            
            state open {
                entry assign isLocked := false;
            }
            
            state engaged {
                entry assign isLocked := true;
            }
            
            transition open_to_engaged
                first open
                accept at startEngagement
                then engaged;
            
            transition engaged_to_open
                first engaged
                accept at startRelease
                then open;
        }
    }
    
    part def TimeMarker {
        attribute applicationTime : TimeValue;
        attribute recordedTime : TimeValue;
        
        action def RecordApplicationTime {
            in currentTime : TimeValue;
            out markedTime : TimeValue;
        }
    }
    
    part def Tourniquet {
        attribute targetOcclusionPressure : PressureValue;
        attribute maxSafeApplicationTime : TimeValue;
        attribute currentApplicationPressure : PressureValue;
        
        port limbInterface : LimbPort;
        port controlInterface : ControlPort;
        
        part strap : CompressionStrap {
            width = 0.038[SI::m];
            maxTensionCapacity = 500.0[SI::N];
            currentTension = 0.0[SI::N];
        }
        
        part windlass : WindlassMechanism {
            rodDiameter = 0.012[SI::m];
            currentRotation = 0.0;
            tensionMultiplier = 15.0;
        }
        
        part clip : SecuringClip {
            isLocked = false;
            lockingForce = 50.0[SI::N];
            
            state clipStateMachine : ClipStates;
        }
        
        part timer : TimeMarker;
        
        binding strap.limbContact = limbInterface;
        flow windlass.tensionOutput to strap.currentTension;
    }
    
    action def MeasureBloodFlow {
        in limbPort : LimbPort;
        out measuredFlow : BloodFlowRate;
    }
    
    action def CalculateTensionAdjustment {
        in currentFlow : BloodFlowRate;
        in targetFlow : BloodFlowRate;
        in currentTension : ForceValue;
        out adjustedTension : ForceValue;
    }
    
    action def VerifyOcclusion {
        in flowRate : BloodFlowRate;
        in threshold : BloodFlowRate;
        out isOccluded : Boolean;
    }
    
    action def LockDevice {
        out lockCommand : String;
    }
    
    action def MarkApplicationTime {
        in currentTime : TimeValue;
        out recordedTime : TimeValue;
    }
    
    action def OccludeBloodFlow {
        in targetFlowReduction : BloodFlowRate;
        in maxApplicationDuration : TimeValue;
        out achievedPressure : PressureValue;
        out totalApplicationTime : TimeValue;
        
        first start;
        then merge compressionLoop;
        
        then action measureFlow : MeasureBloodFlow {
            out currentFlowRate : BloodFlowRate;
        }
        
        then action checkOcclusion : VerifyOcclusion {
            in flowRate = measureFlow.currentFlowRate;
            in threshold = targetFlowReduction;
            out isOccluded : Boolean;
        }
        
        then decide;
            if checkOcclusion.isOccluded == false then increaseTension;
            if checkOcclusion.isOccluded == true then secureDevice;
        
        action increaseTension : CalculateTensionAdjustment {
            in currentFlow = measureFlow.currentFlowRate;
            in targetFlow = targetFlowReduction;
            in currentTension : ForceValue;
            out adjustedTension : ForceValue;
        }
        then compressionLoop;
        
        action secureDevice : LockDevice {
            out lockCommand : String;
        }
        
        then action markTime : MarkApplicationTime {
            in currentTime : TimeValue;
            out recordedTime : TimeValue;
        }
        
        then done;
    }
    
    state def TourniquetOperationalStates {
        entry; then idle;
        
        state idle;
        
        state positioning;
        
        state tightening;
        
        state secured;
        
        state released;
        
        transition idle_to_positioning
            first idle
            accept at positionStart
            then positioning;
        
        transition positioning_to_tightening
            first positioning
            accept at tightenStart
            then tightening;
        
        transition tightening_to_secured
            first tightening
            accept at secureStart
            then secured;
        
        transition secured_to_released
            first secured
            accept at releaseStart
            then released;
        
        transition released_to_idle
            first released
            then idle;
    }
    
    part tourniquetSystem : Tourniquet {
        targetOcclusionPressure = 300000.0[SI::Pa];
        maxSafeApplicationTime = 7200.0[SI::s];
        currentApplicationPressure = 0.0[SI::Pa];
        
        perform action hemorrhageControl[*] ordered;
        
        action hemorrhageControl : OccludeBloodFlow {
            in targetFlowReduction : BloodFlowRate;
            in maxApplicationDuration : TimeValue;
            out achievedPressure : PressureValue;
            out totalApplicationTime : TimeValue;
        }
        
        state operationalBehavior : TourniquetOperationalStates;
    }
    
    requirement def HemorrhageControlRequirement {
        doc /* The tourniquet system shall rapidly occlude arterial blood flow to control severe hemorrhage. */
        
        subject device : Tourniquet;
        
        require constraint flowOcclusionConstraint {
            device.limbInterface.distalFlow.flowRate <= 0.05 * device.limbInterface.arterialFlow.flowRate
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The tourniquet system shall limit tissue damage by constraining maximum application time and pressure. */
        
        subject device : Tourniquet;
        
        require constraint timeConstraint {
            device.timer.recordedTime <= device.maxSafeApplicationTime
        }
        
        require constraint pressureConstraint {
            device.currentApplicationPressure <= 450000.0[SI::Pa]
        }
    }
    
    requirement def UsabilityRequirement {
        doc /* The tourniquet system shall be operable by a single user in emergency field conditions. */
        
        subject device : Tourniquet;
    }
    
    requirement def ReliabilityRequirement {
        doc /* The tourniquet system shall maintain compression without slippage for the required duration. */
        
        subject device : Tourniquet;
        
        require constraint lockingConstraint {
            device.clip.isLocked == true
        }
    }
    
    requirement <'TRQT-SYS-001'> primaryMissionRequirement {
        doc /* The tourniquet system shall control life-threatening extremity hemorrhage by occluding blood flow through mechanical compression. */
        
        assume constraint emergencyCondition {
            doc /* Assumes severe arterial or venous bleeding requiring immediate intervention to prevent exsanguination. */
        }
        
        require HemorrhageControlRequirement;
        require SafetyRequirement;
        require UsabilityRequirement;
        require ReliabilityRequirement;
    }
}
