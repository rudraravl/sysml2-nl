package TubeStripperSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StripLength :> LengthValue;
    attribute def ClampPressure :> PressureValue;
    attribute def BladeDepth :> LengthValue;
    attribute def RotationSpeed :> Real;
    attribute def PullForce :> ForceValue;
    
    attribute def OperationStatus {
        attribute ready : Boolean;
        attribute inProgress : Boolean;
        attribute complete : Boolean;
        attribute faulted : Boolean;
    }
    
    attribute def QualityMetrics {
        attribute stripLengthAccuracy : LengthValue;
        attribute surfaceDamage : Boolean;
        attribute insulationRemovalComplete : Boolean;
    }
    
    item def InsulatedTube {
        attribute outerDiameter : LengthValue;
        attribute insulationThickness : LengthValue;
        attribute totalLength : LengthValue;
        attribute coreMaterial : String;
        attribute insulationMaterial : String;
    }
    
    item def StrippedTube :> InsulatedTube {
        attribute strippedLength : StripLength;
        attribute exposedCoreLength : LengthValue;
        attribute qualityMetrics : QualityMetrics;
    }
    
    item def RemovedInsulation {
        attribute length : LengthValue;
        attribute thickness : LengthValue;
        attribute mass : MassValue;
    }
    
    port def TubeInputPort {
        in item tubeIn : InsulatedTube;
    }
    
    port def TubeOutputPort {
        out item tubeOut : StrippedTube;
    }
    
    port def WastePort {
        out item waste : RemovedInsulation;
    }
    
    port def ControlCommandPort {
        in attribute stripLengthCommand : StripLength;
        in attribute startOperation : Boolean;
        in attribute stopOperation : Boolean;
        in attribute emergencyStop : Boolean;
    }
    
    port def StatusPort {
        out attribute operationStatus : OperationStatus;
        out attribute currentStripLength : LengthValue;
        out attribute qualityCheck : QualityMetrics;
    }
    
    port def PowerPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    action def LoadTube {
        in tube : InsulatedTube;
        out tubeLoaded : InsulatedTube;
        out loadSuccess : Boolean;
    }
    
    action def ClampTube {
        in tube : InsulatedTube;
        in pressure : ClampPressure;
        out tubeClamped : InsulatedTube;
        out clampEngaged : Boolean;
    }
    
    action def PositionBlade {
        in tube : InsulatedTube;
        in targetDepth : BladeDepth;
        out bladePositioned : Boolean;
    }
    
    action def ScoreInsulation {
        in tube : InsulatedTube;
        in depth : BladeDepth;
        in rotationSpeed : RotationSpeed;
        in stripLength : StripLength;
        out scoredTube : InsulatedTube;
        out scoringComplete : Boolean;
    }
    
    action def RemoveInsulation {
        in scoredTube : InsulatedTube;
        in pullForce : PullForce;
        out strippedTube : StrippedTube;
        out removedInsulation : RemovedInsulation;
    }
    
    action def InspectQuality {
        in strippedTube : StrippedTube;
        out qualityMetrics : QualityMetrics;
        out qualityPass : Boolean;
    }
    
    action def ReleaseTube {
        in tube : StrippedTube;
        out releasedTube : StrippedTube;
        out releaseComplete : Boolean;
    }
    
    action def EjectWaste {
        in waste : RemovedInsulation;
        out wasteEjected : Boolean;
    }
    
    action def PerformStripOperation {
        in inputTube : InsulatedTube;
        in requestedStripLength : StripLength;
        out outputTube : StrippedTube;
        out wasteOutput : RemovedInsulation;
        
        first start;
        
        then action load : LoadTube {
            in tube = inputTube;
            out tubeLoaded;
            out loadSuccess;
        }
        
        then action clamp : ClampTube {
            in tube = load.tubeLoaded;
            in pressure = 200000.0 [SI::Pa];
            out tubeClamped;
            out clampEngaged;
        }
        
        then action position : PositionBlade {
            in tube = clamp.tubeClamped;
            in targetDepth = inputTube.insulationThickness;
            out bladePositioned;
        }
        
        then action score : ScoreInsulation {
            in tube = clamp.tubeClamped;
            in depth = inputTube.insulationThickness;
            in rotationSpeed = 300.0;
            in stripLength = requestedStripLength;
            out scoredTube;
            out scoringComplete;
        }
        
        then action remove : RemoveInsulation {
            in scoredTube = score.scoredTube;
            in pullForce = 50.0 [SI::N];
            out strippedTube;
            out removedInsulation;
        }
        
        then action inspect : InspectQuality {
            in strippedTube = remove.strippedTube;
            out qualityMetrics;
            out qualityPass;
        }
        
        then action release : ReleaseTube {
            in tube = remove.strippedTube;
            out releasedTube;
            out releaseComplete;
        }
        
        then action eject : EjectWaste {
            in waste = remove.removedInsulation;
            out wasteEjected;
        }
        
        then assign outputTube := release.releasedTube;
        then assign wasteOutput := remove.removedInsulation;
        
        then done;
    }
    
    part def ClampingAssembly {
        attribute clampPressure : ClampPressure;
        attribute jawSeparation : LengthValue;
        attribute isEngaged : Boolean;
        
        action engageClamp : ClampTube;
        action releaseClamp : ReleaseTube;
    }
    
    part def RotaryCuttingHead {
        attribute bladeDepth : BladeDepth;
        attribute rotationSpeed : RotationSpeed;
        attribute bladeSharpness : Real;
        
        action positionBlade : PositionBlade;
        action performScoring : ScoreInsulation;
    }
    
    part def PullingMechanism {
        attribute pullForce : PullForce;
        attribute pullSpeed : SpeedValue;
        attribute gripStrength : ForceValue;
        
        action pullInsulation : RemoveInsulation;
    }
    
    part def QualityInspectionUnit {
        attribute measurementAccuracy : LengthValue;
        attribute visionSystemEnabled : Boolean;
        
        action performInspection : InspectQuality;
    }
    
    part def WasteCollectionBin {
        attribute capacity : VolumeValue;
        attribute currentFillLevel : VolumeValue;
        
        action collectWaste : EjectWaste;
    }
    
    part def ControllerUnit {
        attribute operatingMode : String;
        attribute stripLengthSetpoint : StripLength;
        attribute currentStatus : OperationStatus;
        
        port commandInput : ControlCommandPort;
        port statusOutput : StatusPort;
    }
    
    part def PowerSupply {
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        attribute powerRating : PowerValue;
        
        port powerOut : PowerPort;
    }
    
    part def TubeStripperSystem;
    
    part tubeStripper : TubeStripperSystem {
        doc /*
            A tube stripper system that removes insulation from the end of insulated tubes.
            The primary function is to precisely strip a specified length of insulation from
            tubes through an automated sequence of clamping, scoring, and pulling operations,
            ensuring consistent strip length, minimal damage to the core material, and
            complete removal of insulation while collecting waste material for disposal.
        */
        
        attribute maxStripLength : StripLength = 100.0 [SI::mm];
        attribute minStripLength : StripLength = 5.0 [SI::mm];
        attribute operatingClampPressure : ClampPressure = 200000.0 [SI::Pa];
        attribute operatingRotationSpeed : RotationSpeed = 300.0;
        attribute operatingPullForce : PullForce = 50.0 [SI::N];
        
        port tubeInput : TubeInputPort;
        port tubeOutput : TubeOutputPort;
        port wasteOutput : WastePort;
        port controlCommands : ControlCommandPort;
        port systemStatus : StatusPort;
        port mainPower : PowerPort;
        
        part clampingUnit : ClampingAssembly {
            attribute clampPressure = tubeStripper.operatingClampPressure;
        }
        
        part cuttingHead : RotaryCuttingHead {
            attribute rotationSpeed = tubeStripper.operatingRotationSpeed;
        }
        
        part pullingUnit : PullingMechanism {
            attribute pullForce = tubeStripper.operatingPullForce;
        }
        
        part inspectionUnit : QualityInspectionUnit {
            attribute measurementAccuracy = 0.1 [SI::mm];
        }
        
        part wasteBin : WasteCollectionBin {
            attribute capacity = 0.005 [SI::m^3];
        }
        
        part controller : ControllerUnit {
            attribute stripLengthSetpoint = controlCommands.stripLengthCommand;
        }
        
        part powerSupply : PowerSupply {
            attribute outputVoltage = 24.0 [SI::V];
            attribute powerRating = 500.0 [SI::W];
        }
        
        perform action stripOperation : PerformStripOperation {
            in inputTube = tubeInput.tubeIn;
            in requestedStripLength = controlCommands.stripLengthCommand;
            out outputTube;
            out wasteOutput;
        }
        
        action clampingUnit.engageClamp : ClampingAssembly::engageClamp;
        perform stripOperation.clamp references clampingUnit.engageClamp;
        
        action cuttingHead.positionBlade : RotaryCuttingHead::positionBlade;
        perform stripOperation.position references cuttingHead.positionBlade;
        
        action cuttingHead.performScoring : RotaryCuttingHead::performScoring;
        perform stripOperation.score references cuttingHead.performScoring;
        
        action pullingUnit.pullInsulation : PullingMechanism::pullInsulation;
        perform stripOperation.remove references pullingUnit.pullInsulation;
        
        action inspectionUnit.performInspection : QualityInspectionUnit::performInspection;
        perform stripOperation.inspect references inspectionUnit.performInspection;
        
        action clampingUnit.releaseClamp : ClampingAssembly::releaseClamp;
        perform stripOperation.release references clampingUnit.releaseClamp;
        
        action wasteBin.collectWaste : WasteCollectionBin::collectWaste;
        perform stripOperation.eject references wasteBin.collectWaste;
        
        connect powerSupply.powerOut to mainPower;
        connect controller.commandInput to controlCommands;
        connect controller.statusOutput to systemStatus;
        
        binding tubeInput.tubeIn = stripOperation.inputTube;
        binding tubeOutput.tubeOut = stripOperation.outputTube;
        binding wasteOutput.waste = stripOperation.wasteOutput;
    }
    
    requirement <'TS-REQ-001'> primaryFunctionRequirement {
        doc /*
            The tube stripper system shall remove insulation from the end of insulated tubes
            by clamping the tube, scoring the insulation circumferentially to the specified
            depth without damaging the core, and pulling the insulation off to achieve the
            commanded strip length with accuracy of ±0.5mm.
        */
        
        subject tubeStripper;
        
        require constraint stripLengthAccuracy {
            doc /* Strip length shall be within ±0.5mm of commanded length. */
        }
        
        require constraint noCoreDamage {
            doc /* Stripping operation shall not damage the tube core material. */
        }
        
        require constraint completeRemoval {
            doc /* All insulation within the strip zone shall be completely removed. */
        }
    }
    
    requirement <'TS-REQ-002'> performanceRequirement {
        doc /*
            The tube stripper shall complete a full strip cycle within 15 seconds
            for strip lengths up to 100mm on tubes with outer diameter up to 25mm.
        */
        
        subject tubeStripper;
    }
    
    requirement <'TS-REQ-003'> safetyRequirement {
        doc /*
            The tube stripper shall not engage cutting or pulling mechanisms unless
            the tube is properly clamped with minimum required pressure and shall
            immediately halt all operations upon emergency stop command.
        */
        
        subject tubeStripper;
        
        assume constraint tubeProperlyLoaded {
            doc /* Tube must be inserted to minimum depth and properly aligned. */
        }
        
        require constraint clampBeforeCut {
            doc /* Clamping must be verified before blade positioning. */
        }
        
        require constraint emergencyStopResponse {
            doc /* System shall halt within 0.5 seconds of emergency stop signal. */
        }
    }
    
    requirement <'TS-REQ-004'> qualityRequirement {
        doc /*
            The tube stripper shall inspect each stripped tube and verify strip length
            accuracy and absence of core damage before releasing the tube.
        */
        
        subject tubeStripper;
    }
}
