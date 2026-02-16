package PenisExtenderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TensionForce :> ForceValue;
    attribute def ExtensionLength :> LengthValue;
    attribute def WearDuration :> TimeValue;
    attribute def PressureLevel :> PressureValue;
    
    item def BiocompatibleMaterial {
        attribute materialType : String;
        attribute certified : Boolean;
    }
    
    item def TensionCommand {
        attribute targetForce : TensionForce;
        attribute incrementalStep : Boolean;
    }
    
    item def StatusFeedback {
        attribute currentExtension : ExtensionLength;
        attribute appliedForce : TensionForce;
        attribute comfortLevel : Real;
    }
    
    part def BaseRing {
        attribute innerDiameter : ExtensionLength;
        attribute material : BiocompatibleMaterial;
        port anchorPoint;
        port tissueInterface;
    }
    
    part def ExtensionRod {
        attribute currentLength : ExtensionLength;
        attribute minLength : ExtensionLength;
        attribute maxLength : ExtensionLength;
        port proximalEnd;
        port distalEnd;
    }
    
    part def GlansCradle {
        attribute material : BiocompatibleMaterial;
        attribute paddingThickness : ExtensionLength;
        port supportSurface;
        port rodAttachment;
    }
    
    part def TensionAdjuster {
        attribute tensionLevel : TensionForce;
        attribute locked : Boolean;
        port adjustmentInterface;
        port mechanicalOutput;
    }
    
    part def ComfortPadding {
        attribute thickness : ExtensionLength;
        attribute material : BiocompatibleMaterial;
        port contactSurface;
    }
    
    part def ForceSensor {
        attribute measuredTension : TensionForce;
        port sensingPoint;
    }
    
    action def InitializeDevice {
        in baseSize : ExtensionLength;
        out deviceReady : Boolean;
    }
    
    action def AdjustExtension {
        in currentExtension : ExtensionLength;
        in targetExtension : ExtensionLength;
        in maxForce : TensionForce;
        out newExtension : ExtensionLength;
        out appliedForce : TensionForce;
    }
    
    action def MonitorSafety {
        in appliedForce : TensionForce;
        in wearTime : WearDuration;
        in tissuePressure : PressureLevel;
        out safetyStatus : Boolean;
    }
    
    action def ApplyControlledTraction {
        in initialExtension : ExtensionLength;
        in targetExtension : ExtensionLength;
        in maxTension : TensionForce;
        in sessionDuration : WearDuration;
        out achievedExtension : ExtensionLength;
        
        private attribute currentExtension : ExtensionLength := initialExtension;
        private attribute currentTension : TensionForce := 0.0;
        private attribute elapsedTime : WearDuration := 0.0;
        
        first start;
        then merge monitoringLoop;
        
        then action checkSafety : MonitorSafety {
            in appliedForce = currentExtension;
            in wearTime = elapsedTime;
            in tissuePressure = 15.0;
            out safetyStatus;
        }
        
        then decide;
            if checkSafety.safetyStatus then increaseExtension;
            else abort;
        
        action increaseExtension : AdjustExtension {
            in currentExtension;
            in targetExtension;
            in maxForce = maxTension;
            out newExtension;
            out appliedForce;
        }
        then assign currentExtension := increaseExtension.newExtension;
        then assign currentTension := increaseExtension.appliedForce;
        then decide;
            if currentExtension < targetExtension then monitoringLoop;
            else maintainTension;
        
        action maintainTension {
        }
        then assign achievedExtension := currentExtension;
        then done;
        
        action abort {
            doc /* Emergency stop if safety limits exceeded */
        }
        then done;
    }
    
    state def DeviceLifecycle {
        attribute deviceActive : Boolean;
        
        entry; then idle;
        
        state idle {
            entry assign deviceActive := false;
        }
        
        state fitting {
            entry assign deviceActive := true;
        }
        
        state tensioning;
        
        state activeWear;
        
        state removal {
            entry assign deviceActive := false;
        }
        
        transition idle_to_fitting
            first idle
            then fitting;
        
        transition fitting_to_tensioning
            first fitting
            then tensioning;
        
        transition tensioning_to_active
            first tensioning
            then activeWear;
        
        transition activeWear_to_removal
            first activeWear
            then removal;
        
        transition removal_to_idle
            first removal
            then idle;
    }
    
    part def ExtenderDevice {
        part baseRing : BaseRing {
            attribute :>> innerDiameter = 38.0;
            attribute :>> material = BiocompatibleMaterial {
                materialType = "Medical Grade Silicone";
                certified = true;
            }
        }
        
        part leftRod : ExtensionRod {
            attribute :>> minLength = 60.0;
            attribute :>> maxLength = 180.0;
            attribute :>> currentLength = 60.0;
        }
        
        part rightRod : ExtensionRod {
            attribute :>> minLength = 60.0;
            attribute :>> maxLength = 180.0;
            attribute :>> currentLength = 60.0;
        }
        
        part cradle : GlansCradle {
            attribute :>> paddingThickness = 4.0;
            attribute :>> material = BiocompatibleMaterial {
                materialType = "Medical Grade Silicone";
                certified = true;
            }
        }
        
        part leftAdjuster : TensionAdjuster {
            attribute :>> tensionLevel = 8.0;
            attribute :>> locked = false;
        }
        
        part rightAdjuster : TensionAdjuster {
            attribute :>> tensionLevel = 8.0;
            attribute :>> locked = false;
        }
        
        part comfortPad1 : ComfortPadding {
            attribute :>> thickness = 3.0;
        }
        
        part comfortPad2 : ComfortPadding {
            attribute :>> thickness = 3.0;
        }
        
        part comfortPad3 : ComfortPadding {
            attribute :>> thickness = 3.0;
        }
        
        part comfortPad4 : ComfortPadding {
            attribute :>> thickness = 3.0;
        }
        
        part forceSensor : ForceSensor;
        
        connect baseRing.anchorPoint to leftRod.proximalEnd;
        connect baseRing.anchorPoint to rightRod.proximalEnd;
        connect leftRod.distalEnd to cradle.rodAttachment;
        connect rightRod.distalEnd to cradle.rodAttachment;
        connect leftAdjuster.mechanicalOutput to leftRod.proximalEnd;
        connect rightAdjuster.mechanicalOutput to rightRod.proximalEnd;
        connect forceSensor.sensingPoint to leftRod.distalEnd;
        
        perform action operateDevice : ApplyControlledTraction {
            in initialExtension = 60.0;
            in targetExtension = 140.0;
            in maxTension = 12.0;
            in sessionDuration = 6.0;
            out achievedExtension;
        }
    }
    
    requirement def SafetyRequirement;
    requirement def EffectivenessRequirement;
    requirement def ComfortRequirement;
    requirement def MaterialRequirement;
    
    requirement <'REQ-001'> safeTensionLimit : SafetyRequirement {
        doc /* The device shall limit applied tension forces to physiologically safe levels 
                not exceeding 15 Newtons to prevent tissue damage or discomfort. */
        
        subject device : ExtenderDevice;
        
        require constraint {
            device.forceSensor.measuredTension <= 15.0
        }
    }
    
    requirement <'REQ-002'> gradualExtension : EffectivenessRequirement {
        doc /* The device shall provide controlled, incremental extension capability 
                with adjustment steps between 1mm and 5mm to enable gradual tissue adaptation. */
        
        subject device : ExtenderDevice;
        
        require constraint {
            device.leftRod.maxLength - device.leftRod.minLength >= 100.0
        }
    }
    
    requirement <'REQ-003'> wearComfort : ComfortRequirement {
        doc /* The device shall incorporate adequate padding and ergonomic design 
                to enable extended wear sessions of 4-8 hours with minimal discomfort. */
        
        subject device : ExtenderDevice;
        
        require constraint {
            device.comfortPad1.thickness >= 2.0 and
            device.comfortPad2.thickness >= 2.0 and
            device.comfortPad3.thickness >= 2.0
        }
    }
    
    requirement <'REQ-004'> biocompatibleMaterials : MaterialRequirement {
        doc /* All tissue-contact surfaces shall use certified biocompatible materials 
                to prevent allergic reactions and ensure safe prolonged skin contact. */
        
        subject device : ExtenderDevice;
        
        require constraint {
            device.baseRing.material.certified and
            device.cradle.material.certified
        }
    }
    
    requirement <'REQ-005'> primaryFunction {
        doc /* The penis extender system shall apply sustained, controlled mechanical traction 
                to penile tissue through an adjustable extension mechanism, promoting gradual 
                tissue expansion over extended wear periods for therapeutic or enhancement purposes. 
                The system achieves this by anchoring at the base, applying gentle longitudinal 
                tension via adjustable rods, and distributing force through padded contact surfaces 
                while maintaining user safety and comfort throughout multi-hour wear sessions. */
        
        assume constraint userCompliance {
            doc /* User follows recommended wear schedule and adjustment protocols */
        }
        
        assume constraint properFitting {
            doc /* Device is correctly sized and fitted to user anatomy */
        }
        
        require safeTensionLimit;
        require gradualExtension;
        require wearComfort;
        require biocompatibleMaterials;
    }
}
