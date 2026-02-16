package 'Riveting Machine System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RivetDiameterValue :> ISQ::LengthValue;
    attribute def ClampingForceValue :> ISQ::ForceValue;
    attribute def HydraulicPressureValue :> ISQ::PressureValue;
    attribute def RivetingForceValue :> ISQ::ForceValue;
    attribute def CycleTimeValue :> ISQ::TimeValue;
    attribute def PositionValue :> ISQ::LengthValue;

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def EmergencyStopCommand;
    attribute def CycleCompleteSignal;
    attribute def RivetReadySignal;
    attribute def WorkpieceSecuredSignal;
    attribute def QualityPassSignal;
    attribute def QualityFailSignal;

    port def HydraulicSupplyPort {
        in commandedPressure : HydraulicPressureValue;
        out actualPressure : HydraulicPressureValue;
        out generatedForce : ClampingForceValue;
    }

    port def RivetFeedPort {
        out rivetAvailable : Boolean;
        out rivetDiameter : RivetDiameterValue;
    }

    port def WorkpiecePort {
        in workpiecePresent : Boolean;
        out workpieceClamped : Boolean;
    }

    port def ControlInterfacePort {
        in startCmd : StartCommand;
        in stopCmd : StopCommand;
        in emergencyStop : EmergencyStopCommand;
        out cycleStatus : String;
        out qualityStatus : Boolean;
    }

    part def HydraulicPowerUnit {
        port hydraulicOut : HydraulicSupplyPort;
        attribute maxPressure : HydraulicPressureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        
        perform action generateHydraulicPower {
            in targetPressure : HydraulicPressureValue;
            out outputPressure : HydraulicPressureValue;
            out outputForce : ClampingForceValue;
        }
    }

    part def RivetFeederUnit {
        port rivetOut : RivetFeedPort;
        attribute magazineCapacity : Integer;
        attribute currentCount : Integer;
        attribute feedSpeed : ISQ::SpeedValue;
        
        perform action feedRivet {
            in feedRequest : Boolean;
            out rivetDelivered : Boolean;
            out rivetSize : RivetDiameterValue;
        }
    }

    part def ClampingAssembly {
        port workpieceInterface : WorkpiecePort;
        port hydraulicIn : HydraulicSupplyPort;
        attribute clampForce : ClampingForceValue;
        attribute clampStroke : PositionValue;
        
        perform action clampWorkpiece {
            in hydraulicForce : ClampingForceValue;
            in workpieceDetected : Boolean;
            out clampingComplete : Boolean;
        }
        
        perform action releaseWorkpiece {
            out releaseComplete : Boolean;
        }
    }

    part def RivetingHeadAssembly {
        port hydraulicIn : HydraulicSupplyPort;
        attribute rivetingForce : RivetingForceValue;
        attribute headPosition : PositionValue;
        attribute formingDepth : ISQ::LengthValue;
        
        perform action formRivet {
            in rivetPresent : Boolean;
            in workpieceClamped : Boolean;
            in appliedForce : RivetingForceValue;
            out rivetFormed : Boolean;
            out formingQuality : Real;
        }
    }

    part def QualityInspectionUnit {
        attribute inspectionThreshold : Real;
        attribute defectLimit : Real;
        
        perform action inspectRivetedJoint {
            in rivetFormed : Boolean;
            in qualityMetric : Real;
            out inspectionPass : Boolean;
            out defectFound : Boolean;
        }
    }

    part def SystemController {
        port controlInterface : ControlInterfacePort;
        attribute operationMode : String;
        attribute totalCycles : Integer;
        attribute faultStatus : Boolean;
        
        perform action manageRivetingCycle;
    }

    action def LoadWorkpiece {
        in workpieceAvailable : Boolean;
        out workpieceLoaded : Boolean;
    }

    action def FeedRivetToHead {
        in rivetRequested : Boolean;
        out rivetPositioned : Boolean;
    }

    action def SecureWorkpiece {
        in clampingForce : ClampingForceValue;
        out workpieceSecured : Boolean;
    }

    action def ApplyRivetingForce {
        in rivetingForce : RivetingForceValue;
        in rivetPresent : Boolean;
        out rivetDeformed : Boolean;
    }

    action def InspectJoint {
        in jointFormed : Boolean;
        out qualityAcceptable : Boolean;
    }

    action def UnloadWorkpiece {
        in cycleComplete : Boolean;
        out workpieceRemoved : Boolean;
    }

    action def ExecuteRivetingCycle {
        in rivetDiameter : RivetDiameterValue;
        in clampingForce : ClampingForceValue;
        in rivetingForce : RivetingForceValue;
        out cycleSuccess : Boolean;
        out qualityPass : Boolean;

        first start;
        then merge cycleStart;

        then action loadWorkpiece : LoadWorkpiece {
            in workpieceAvailable : Boolean;
            out workpieceLoaded : Boolean;
        }

        then action feedRivet : FeedRivetToHead {
            in rivetRequested = loadWorkpiece.workpieceLoaded;
            out rivetPositioned : Boolean;
        }

        then action secureWorkpiece : SecureWorkpiece {
            in clampingForce = clampingForce;
            out workpieceSecured : Boolean;
        }

        then action applyRivetingForce : ApplyRivetingForce {
            in rivetingForce = rivetingForce;
            in rivetPresent = feedRivet.rivetPositioned;
            out rivetDeformed : Boolean;
        }

        then action inspectJoint : InspectJoint {
            in jointFormed = applyRivetingForce.rivetDeformed;
            out qualityAcceptable : Boolean;
        }

        then decide;
            if inspectJoint.qualityAcceptable then acceptWorkpiece;
            if !inspectJoint.qualityAcceptable then rejectWorkpiece;

        action acceptWorkpiece : UnloadWorkpiece {
            in cycleComplete = inspectJoint.qualityAcceptable;
            out workpieceRemoved : Boolean;
        }
        then assign cycleSuccess := true;
        then assign qualityPass := true;
        then cycleEnd;

        action rejectWorkpiece {
            out workpieceRejected : Boolean;
        }
        then assign cycleSuccess := false;
        then assign qualityPass := false;
        then cycleEnd;

        action cycleEnd;
        then cycleStart;
    }

    part def RivetingMachineSystem {
        port electricalSupply;
        port hydraulicSupply;
        port operatorInterface : ControlInterfacePort;

        part hydraulicUnit : HydraulicPowerUnit;
        part feeder : RivetFeederUnit;
        part clamp : ClampingAssembly;
        part rivetingHead : RivetingHeadAssembly;
        part inspector : QualityInspectionUnit;
        part controller : SystemController;

        connection hydraulicToClamp connect hydraulicUnit.hydraulicOut to clamp.hydraulicIn;
        connection hydraulicToHead connect hydraulicUnit.hydraulicOut to rivetingHead.hydraulicIn;
        connection controlToController connect operatorInterface to controller.controlInterface;
    }

    part rivetingSystem : RivetingMachineSystem {
        part redefines hydraulicUnit {
            attribute redefines maxPressure = 20000000.0[Pa];
        }
        part redefines clamp {
            attribute redefines clampForce = 25000.0[N];
        }
        part redefines rivetingHead {
            attribute redefines rivetingForce = 50000.0[N];
        }
        part redefines feeder {
            attribute redefines magazineCapacity = 500;
        }
        part redefines inspector {
            attribute redefines inspectionThreshold = 0.95;
        }

        perform action operateMachine[*] ordered references rivetingCycle;

        part redefines feeder {
            perform operateMachine.feedRivet;
        }

        part redefines clamp {
            perform operateMachine.secureWorkpiece;
        }

        part redefines rivetingHead {
            perform operateMachine.applyRivetingForce;
        }

        part redefines inspector {
            perform operateMachine.inspectJoint;
        }

        part redefines controller {
            perform operateMachine.cycleEnd;
        }
    }

    action rivetingCycle : ExecuteRivetingCycle {
        in rivetDiameter : RivetDiameterValue;
        in clampingForce : ClampingForceValue;
        in rivetingForce : RivetingForceValue;
        out cycleSuccess : Boolean;
        out qualityPass : Boolean;
    }

    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def QualityRequirement;

    requirement <'REQ-RIV-001'> rivetingForceCapability : PerformanceRequirement {
        doc /* The riveting machine shall apply a controlled riveting force 
             between 10 kN and 100 kN to permanently deform rivets with 
             diameters ranging from 3 mm to 16 mm. */

        subject rivetingMachineInstance : RivetingMachineSystem;

        require constraint {
            rivetingMachineInstance.rivetingHead.rivetingForce >= 10000.0[N] and
            rivetingMachineInstance.rivetingHead.rivetingForce <= 100000.0[N]
        }
    }

    requirement <'REQ-RIV-002'> cycleTimePerformance : PerformanceRequirement {
        doc /* The riveting machine shall complete a full riveting cycle, 
             including workpiece loading, rivet feeding, forming, inspection, 
             and unloading, in no more than 12 seconds. */

        subject rivetingMachineInstance : RivetingMachineSystem;
    }

    requirement <'REQ-RIV-003'> qualityInspection : QualityRequirement {
        doc /* The riveting machine shall inspect 100% of formed rivets and 
             automatically reject workpieces with defects or rivets that do 
             not meet quality criteria with a minimum 95% accuracy. */

        subject inspectorInstance : QualityInspectionUnit;

        require constraint {
            inspectorInstance.inspectionThreshold >= 0.95
        }
    }

    requirement <'REQ-RIV-004'> emergencyStopResponse : SafetyRequirement {
        doc /* The riveting machine shall cease all motion and retract the 
             riveting head to a safe position within 1 second of emergency 
             stop activation. */

        subject controllerInstance : SystemController;
    }

    requirement <'REQ-RIV-005'> hydraulicPressureControl : PerformanceRequirement {
        doc /* The hydraulic power unit shall maintain pressure stability 
             within ±3% of the commanded value during riveting operations 
             with a maximum operating pressure of 25 MPa. */

        subject hydraulicInstance : HydraulicPowerUnit;

        require constraint {
            hydraulicInstance.maxPressure <= 25000000.0[Pa]
        }
    }

    requirement <'REQ-RIV-006'> clampingForceRequirement : PerformanceRequirement {
        doc /* The clamping assembly shall secure workpieces with a minimum 
             clamping force of 15 kN to prevent movement during riveting. */

        subject clampInstance : ClampingAssembly;

        require constraint {
            clampInstance.clampForce >= 15000.0[N]
        }
    }

    requirement systemFunctionalRequirements {
        doc /* The riveting machine system shall join metal components by 
             permanently deforming mechanical fasteners through controlled 
             application of hydraulic force, ensuring consistent joint quality 
             through automated inspection and process control. */

        require rivetingForceCapability;
        require cycleTimePerformance;
        require qualityInspection;
        require emergencyStopResponse;
        require hydraulicPressureControl;
        require clampingForceRequirement;
    }
}
