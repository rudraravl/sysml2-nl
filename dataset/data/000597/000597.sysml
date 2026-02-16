package EmergencyTourniquetSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TourniquetCommand;
    attribute def WindlassRotation;
    attribute def LockStatus;
    attribute def DeployCommand;
    attribute def StrapSecured;
    attribute def ReleaseCommand;
    
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def TimeValue :> Real;
    
    item def Strap {
        attribute material : String;
        attribute width : LengthValue;
        attribute tensileStrength : ForceValue;
    }
    
    item def WindlassRod {
        attribute length : LengthValue;
        attribute rotationAngle : Real;
    }
    
    item def SecuringClip {
        attribute isLocked : Boolean;
        attribute holdingForce : ForceValue;
    }
    
    item def PressurePad {
        attribute contactArea : AreaValue;
    }
    
    port def PressureApplicationPort {
        out appliedPressure : PressureValue;
    }
    
    port def FlowMonitoringPort {
        in bloodFlowRate : FlowRateValue;
    }
    
    port def ControlPort {
        in rotationCommand : WindlassRotation;
        out tensionFeedback : ForceValue;
    }
    
    part def Limb {
        attribute circumference : LengthValue;
        attribute baselineBloodFlow : FlowRateValue;
        attribute currentBloodFlow : FlowRateValue;
        
        port flowPort : FlowMonitoringPort;
    }
    
    part def EmergencyTourniquet {
        attribute deviceId : String;
        attribute targetOcclusionPressure : PressureValue;
        attribute currentPressure : PressureValue;
        attribute applicationTime : TimeValue;
        
        part strap : Strap {
            attribute material = "High-strength nylon";
            attribute width = 38.0;
            attribute tensileStrength = 600.0;
        }
        
        part windlass : WindlassRod {
            attribute length = 150.0;
            attribute rotationAngle = 0.0;
        }
        
        part clip : SecuringClip {
            attribute isLocked = false;
            attribute holdingForce = 250.0;
        }
        
        part pad : PressurePad {
            attribute contactArea = 1500.0;
        }
        
        port pressurePort : PressureApplicationPort;
        port monitorPort : FlowMonitoringPort;
        port controlPort : ControlPort;
        
        perform action occludeBloodFlow[*] ordered references occlusionSequence;
    }
    
    action def PositionOnLimb {
        in limbCircumference : LengthValue;
        out placementHeight : LengthValue;
        out strapWrapped : Boolean;
    }
    
    action def InitialTightening {
        in strapTension : ForceValue;
        out basePressure : PressureValue;
    }
    
    action def RotateWindlass {
        in currentRotation : Real;
        in incrementalRotation : Real;
        out newRotation : Real;
        out generatedPressure : PressureValue;
    }
    
    action def CheckBloodFlow {
        in appliedPressure : PressureValue;
        out measuredFlow : FlowRateValue;
        out isOccluded : Boolean;
    }
    
    action def LockWindlass {
        in windlassPosition : Real;
        out clipEngaged : Boolean;
    }
    
    action def MarkApplicationTime {
        out timestamp : TimeValue;
    }
    
    action def OccludeArterialFlow {
        in limbCircumference : LengthValue;
        in targetPressure : PressureValue;
        out finalPressure : PressureValue;
        out occlusionAchieved : Boolean;
        out timeApplied : TimeValue;
        
        private attribute currentPressure : PressureValue;
        private attribute windlassAngle : Real := 0.0;
        
        first start;
        
        then action position : PositionOnLimb {
            in limbCircumference = OccludeArterialFlow::limbCircumference;
            out placementHeight;
            out strapWrapped;
        }
        
        then action initialTighten : InitialTightening {
            in strapTension = 40.0;
            out basePressure;
        }
        
        then assign currentPressure := initialTighten.basePressure;
        
        then merge tighteningCycle;
        
        action checkFlow : CheckBloodFlow {
            in appliedPressure = currentPressure;
            out measuredFlow;
            out isOccluded;
        }
        
        then decide;
            if not checkFlow.isOccluded then rotateMore;
            if checkFlow.isOccluded then lockDevice;
        
        action rotateMore : RotateWindlass {
            in currentRotation = windlassAngle;
            in incrementalRotation = 45.0;
            out newRotation;
            out generatedPressure;
        }
        
        then assign windlassAngle := rotateMore.newRotation;
        then assign currentPressure := rotateMore.generatedPressure;
        then tighteningCycle;
        
        action lockDevice : LockWindlass {
            in windlassPosition = windlassAngle;
            out clipEngaged;
        }
        
        then action markTime : MarkApplicationTime {
            out timestamp;
        }
        
        then assign OccludeArterialFlow::finalPressure := currentPressure;
        then assign OccludeArterialFlow::occlusionAchieved := true;
        then assign OccludeArterialFlow::timeApplied := markTime.timestamp;
        then done;
    }
    
    state def TourniquetStates {
        attribute deviceStatus : String;
        attribute appliedPressure : PressureValue;
        attribute minimumOcclusionPressure : PressureValue := 250.0;
        attribute flowDetected : Boolean;
        attribute lockEngaged : Boolean;
        
        entry; then stowed;
        
        state stowed {
            entry assign deviceStatus := "Ready for deployment";
        }
        
        transition stowed_to_positioning
            first stowed
            accept deployCmd : DeployCommand
            then positioning;
        
        state positioning {
            entry assign deviceStatus := "Positioning on limb";
        }
        
        transition positioning_to_tightening
            first positioning
            accept strapSec : StrapSecured
            then tightening;
        
        state tightening {
            entry assign deviceStatus := "Applying occlusive pressure";
        }
        
        transition tightening_to_monitoring
            first tightening
            if appliedPressure >= minimumOcclusionPressure
            then monitoring;
        
        state monitoring {
            entry assign deviceStatus := "Verifying occlusion";
        }
        
        transition monitoring_to_tightening
            first monitoring
            if flowDetected == true
            then tightening;
        
        transition monitoring_to_secured
            first monitoring
            if flowDetected == false
            then secured;
        
        state secured {
            entry assign deviceStatus := "Locked and maintaining pressure";
            entry assign lockEngaged := true;
        }
        
        transition secured_to_released
            first secured
            accept releaseCmd : ReleaseCommand
            then released;
        
        state released {
            entry assign deviceStatus := "Released";
            entry assign appliedPressure := 0.0;
        }
        
        transition released_to_stowed
            first released
            then stowed;
    }
    
    requirement def <'REQ-TQ-001'> ArterialOcclusionRequirement {
        doc /* The emergency tourniquet shall completely occlude arterial blood flow in the affected limb within 60 seconds of proper application. */
        
        subject device : EmergencyTourniquet;
        
        require constraint {
            device.applicationTime <= 60.0 and
            device.currentPressure >= 250.0
        }
    }
    
    requirement def <'REQ-TQ-002'> PressureRangeRequirement {
        doc /* The tourniquet shall apply circumferential pressure between 250 mmHg and 450 mmHg to ensure arterial occlusion without excessive tissue damage. */
        
        subject device : EmergencyTourniquet;
        
        require constraint {
            device.targetOcclusionPressure >= 250.0 and
            device.targetOcclusionPressure <= 450.0
        }
    }
    
    requirement def <'REQ-TQ-003'> WindlassSecurementRequirement {
        doc /* The windlass securing mechanism shall maintain applied tension without slippage for a minimum of 4 hours under field conditions. */
        
        subject clip : SecuringClip;
        
        require constraint {
            clip.holdingForce >= 200.0 and
            clip.isLocked == true
        }
    }
    
    requirement def <'REQ-TQ-004'> OneHandedOperationRequirement {
        doc /* The tourniquet shall be capable of complete application and securing using only one hand to accommodate self-application scenarios. */
        
        subject device : EmergencyTourniquet;
    }
    
    requirement <'REQ-TQ-MISSION'> lifeSavingMissionRequirement {
        doc /* The emergency tourniquet system shall rapidly control severe extremity hemorrhage to prevent exsanguination and preserve life in trauma situations. */
        
        assume constraint traumaticInjury {
            doc /* Assumes severe arterial bleeding from traumatic limb injury requiring immediate hemorrhage control. */
        }
        
        require occlusionReq : ArterialOcclusionRequirement;
        require pressureReq : PressureRangeRequirement;
        require securementReq : WindlassSecurementRequirement;
        require usabilityReq : OneHandedOperationRequirement;
    }
    
    part traumaScenario {
        part injuredLimb : Limb {
            attribute circumference = 300.0;
            attribute baselineBloodFlow = 800.0;
            attribute currentBloodFlow = 800.0;
        }
        
        part tourniquet : EmergencyTourniquet {
            attribute deviceId = "TQ-EMERG-2024-A1";
            attribute targetOcclusionPressure = 350.0;
            attribute currentPressure = 0.0;
            attribute applicationTime = 0.0;
            
            exhibit state operationalStates : TourniquetStates;
            
            perform action occlusionSequence : OccludeArterialFlow {
                in limbCircumference = injuredLimb.circumference;
                in targetPressure = tourniquet.targetOcclusionPressure;
                out finalPressure;
                out occlusionAchieved;
                out timeApplied;
            }
        }
        
        connection pressureApplication
            connect tourniquet.pressurePort to injuredLimb.flowPort;
        
        bind injuredLimb.currentBloodFlow = 
            if tourniquet.currentPressure >= 250.0
            then 0.0
            else injuredLimb.baselineBloodFlow * (1.0 - tourniquet.currentPressure / 250.0);
    }
}
