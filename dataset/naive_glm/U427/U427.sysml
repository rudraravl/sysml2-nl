package TubeStrippingSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value type PressureValue :> Real { unit 'Pa'; }
    value type StripLengthValue :> Length { unit 'mm'; }
    value type InsulationThicknessValue :> Length { unit 'mm'; }
    value type CoreDiameterValue :> Length {> Diameter;} { unit 'mm'; }
    value type BladeDepthValue :> Length { unit 'mm'; }
    value type RotationSpeedValue :> Real { unit 'rpm'; }
    value type TorqueValue :> Real { unit 'N*m'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type ForceValue :> Real { unit 'N'; }
    value type ToleranceValue :> Length { unit 'mm'; }

    // ---------- Item Types ----------
    item def InsulatedTube {
        attribute coreDiameter : CoreDiameterValue;
        attribute insulationThickness : InsulationThicknessValue;
        attribute totalLength : Length;
    }
    
    item def StrippedTube {
        attribute coreDiameter : CoreDiameterValue;
        attribute exposedCoreLength : StripLengthValue;
        attribute surfaceIntegrity : Boolean; // true = no damage
    }
    
    item def InsulationSlug {
        attribute length : StripLengthValue;
        attribute thickness : InsulationThicknessValue;
    }

    // ---------- Enumerations ----------
    enum def OperationalState { ready, feeding, clamping, cutting, pulling, inspecting, releasing, ejecting, faulted; }
    enum def CommandKind { start, stop, emergencyStop; }
    enum def InspectionResult { pass, fail; }
    enum def FaultKind { overCut, underCut, slippage, bladeFault, sensorFault; }

    // ---------- Interfaces ----------
    port def ControlPort {
        attribute command : CommandKind;
        attribute targetStripLength : StripLengthValue;
        attribute insulationThicknessSetting : InsulationThicknessValue;
        in statusUpdate : StatusMessage;
    }
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def TubeInPort {
        in tube : InsulatedTube;
    }
    
    port def TubeOutPort {
        out strippedTube : StrippedTube;
    }
    
    port def WastePort {
        out insulationSlug : InsulationSlug;
    }
    
    item def StatusMessage {
        attribute state : OperationalState;
        attribute progressPercent : Real;
        attribute inspectionResult : InspectionResult;
        attribute activeFault : FaultKind;
    }

    // ---------- Requirements ----------
    requirement def TubeStrippingSystemRequirement {
        objective :> "Automated system to strip insulation from tube ends with precision";
    }
    
    requirement preciseCuttingReq : TubeStrippingSystemRequirement {
        requirement "The rotary cutting head shall score a circumferential cut matching the insulation thickness without damaging the core.";
        attribute maxCoreDamageDepth : ToleranceValue = 0.05 [mm];
    }
    
    requirement secureClampingReq : TubeStrippingSystemRequirement {
        requirement "The clamping assembly shall hold the tube with sufficient pressure to prevent slippage during cutting and pulling.";
        attribute minClampPressure : PressureValue = 50000 [Pa];
    }
    
    requirement accurateStripLengthReq : TubeStrippingSystemRequirement {
        requirement "The exposed core length shall match the desired strip length within tolerance.";
        attribute stripLengthTolerance : ToleranceValue = 0.2 [mm];
    }
    
    requirement qualityInspectionReq : TubeStrippingSystemRequirement {
        requirement "The quality inspection unit shall verify exposed core length and surface integrity.";
    }
    
    requirement safeOperationReq : TubeStrippingSystemRequirement {
        requirement "The system shall respond to an emergency stop command within 100 ms by halting all motion.";
        attribute maxEmergencyStopResponse : Time = 100 [ms];
    }
    
    requirement wasteEjectionReq : TubeStrippingSystemRequirement {
        requirement "The system shall eject removed insulation into a dedicated waste collection bin.";
    }

    // ---------- Controller State Machine ----------
    state def ControllerStateMachine {
        entry action { send StartSignal(); }
        
        state ready {
            entry action { emit StatusUpdate('ready', 0, '', ''); }
        }
        state feeding {
            entry action { emit FeedTube(); }
            on TubePresent do transition to clamping;
        }
        state clamping {
            entry action { emit EngageClamp(minClampPressure); }
            on ClampEngaged do transition to cutting;
        }
        state cutting {
            entry action { emit SetBladeDepth(insulationThicknessSetting); emit RotateBlade(); }
            on CutComplete do transition to pulling;
        }
        state pulling {
            entry action { emit GripInsulation(); emit Pull(); }
            on PullComplete do transition to inspecting;
        }
        state inspecting {
            entry action { emit Inspect(); }
            on InspectionDone(result) do transition to releasing;
        }
        state releasing {
            entry action { emit ReleaseClamp(); }
            on ClampReleased do transition to ejecting;
        }
        state ejecting {
            entry action { emit EjectInsulation(); }
            on EjectionComplete do transition to ready;
        }
        state faulted {
            entry action { emit FaultSignal(activeFault); }
            on ResetCommand do transition to ready;
        }
        
        transition ready to feeding on StartCommand;
        transition clamping to faulted on SlippageDetected;
        transition cutting to faulted on OverCutDetected;
        transition any to faulted on EmergencyStopCommand;
        transition faulted to ready on ResetCommand;
    }

    // ---------- Component Parts ----------
    part def PowerSupply {
        port powerOut : PowerPort;
        attribute outputVoltage : VoltageValue = 24 [V];
        attribute maxCurrent : CurrentValue = 30 [A];
    }
    
    part def ControllerUnit {
        port controlPorts : ControlPort[6];
        port powerIn : PowerPort;
        exhibit state machine behavior :> ControllerStateMachine;
        attribute minClampPressure : PressureValue = 50000 [Pa];
        attribute insulationThicknessSetting : InsulationThicknessValue;
        attribute activeFault : FaultKind;
        attribute targetStripLength : StripLengthValue;
    }
    
    part def ClampingAssembly {
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        attribute appliedPressure : PressureValue;
        attribute maxPressure : PressureValue = 200000 [Pa];
        action engageClamp :> Action {
            in targetPressure : PressureValue;
            out engagementComplete : Boolean;
        }
        action releaseClamp :> Action;
    }
    
    part def RotaryCuttingHead {
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        attribute bladeDepth : BladeDepthValue;
        attribute rotationSpeed : RotationSpeedValue = 1200 [rpm];
        attribute cutTorque : TorqueValue;
        
        action setBladeDepth :> Action {
            in depth : BladeDepthValue;
        }
        action rotateBlade :> Action {
            in speed : RotationSpeedValue;
        }
        action scoreCut :> Action {
            in insulationThickness : InsulationThicknessValue;
            out cutComplete : Boolean;
        }
    }
    
    part def PullingMechanism {
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        attribute pullForce : ForceValue;
        attribute maxForce : ForceValue = 500 [N];
        
        action gripInsulation :> Action;
        action pull :> Action {
            in length : StripLengthValue;
            out pullComplete : Boolean;
        }
    }
    
    part def QualityInspectionUnit {
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        attribute measuredStripLength : StripLengthValue;
        attribute measuredSurfaceIntegrity : Boolean;
        attribute lastResult : InspectionResult;
        
        action inspect :> Action {
            in tube : StrippedTube;
            out result : InspectionResult;
        }
    }
    
    part def WasteCollectionBin {
        port wasteIn : WastePort;
        attribute collectedInsulation : InsulationSlug[*];
    }
    
    part def OperatorInterface {
        port controlOut : ControlPort;
        attribute currentStatus : StatusMessage;
        attribute targetStripLength : StripLengthValue;
        attribute insulationThicknessSetting : InsulationThicknessValue;
    }

    // ---------- System ----------
    part def AutomatedTubeStrippingSystem {
        requirement preciseCuttingReq;
        requirement secureClampingReq;
        requirement accurateStripLengthReq;
        requirement qualityInspectionReq;
        requirement safeOperationReq;
        requirement wasteEjectionReq;
        
        port tubeInPort : TubeInPort;
        port tubeOutPort : TubeOutPort;
        port wasteEjectPort : WastePort;
        port operatorPort : ControlPort;
        
        part powerSupply : PowerSupply;
        part controller : ControllerUnit;
        part clampingAssembly : ClampingAssembly;
        part cuttingHead : RotaryCuttingHead;
        part pullingMechanism : PullingMechanism;
        part inspectionUnit : QualityInspectionUnit;
        part wasteBin : WasteCollectionBin;
        part operatorInterface : OperatorInterface;
        
        connection powerBus connect powerSupply.powerOut to controller.powerIn,
                                              clampingAssembly.powerIn,
                                              cuttingHead.powerIn,
                                              pullingMechanism.powerIn,
                                              inspectionUnit.powerIn;
        
        connection controlBus connect controller.controlPorts[1] to clampingAssembly.controlIn,
                                                cuttingHead.controlIn,
                                                pullingMechanism.controlIn,
                                                inspectionUnit.controlIn;
        
        connection operatorLink connect operatorInterface.controlOut to controller.controlPorts[5];
        connection wasteLink connect wasteEjectPort to wasteBin.wasteIn;
        
        flow tubeInPort.tube -> clampingAssembly;
        flow clampingAssembly -> cuttingHead;
        flow cuttingHead -> pullingMechanism;
        flow pullingMechanism -> inspectionUnit;
        flow inspectionUnit -> tubeOutPort.strippedTube;
        flow pullingMechanism.out insulation -> wasteBin;
    }
}
