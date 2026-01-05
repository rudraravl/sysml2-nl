package PenisClampSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PressureLevel :> Real;
    attribute def FlowRate :> Real;

    item def UrineFlow {
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }

    item def CompressionForce {
        attribute magnitude : ISQ::ForceValue;
    }

    attribute def SafetyThreshold :> ISQ::PressureValue {
        attribute maxPressure : ISQ::PressureValue = 45000.0[SI::Pa];
    }

    port def CompressionControlPort {
        out compressionCommand : CompressionForce;
    }

    port def FlowMonitorPort {
        in urineFlow : UrineFlow;
    }

    port def SafetyPort {
        out safetyAlert : Boolean;
    }

    part def CompressionMechanism {
        attribute appliedForce : ISQ::ForceValue;
        attribute compressionLevel : PressureLevel = 0.0;
        
        port controlInput : ~CompressionControlPort;
        
        action def ApplyCompression {
            in targetForce : ISQ::ForceValue;
            out actualForce : ISQ::ForceValue;
        }
        
        action def ReleaseCompression {
            out releasedForce : ISQ::ForceValue;
        }
    }

    part def PressurePad {
        attribute contactArea : ISQ::AreaValue = 0.0005[SI::m^2];
        attribute appliedPressure : ISQ::PressureValue;
        
        action def DistributePressure {
            in force : ISQ::ForceValue;
            in area : ISQ::AreaValue;
            out pressure : ISQ::PressureValue;
        }
    }

    part def AdjustmentLever {
        attribute position : Integer = 0;
        attribute maxPositions : Integer = 6;
        
        action def IncrementPosition {
            in currentPos : Integer;
            out newPos : Integer;
        }
        
        action def DecrementPosition {
            in currentPos : Integer;
            out newPos : Integer;
        }
    }

    part def FlowSensor {
        attribute measuredFlow : ISQ::VolumeFlowRateValue;
        
        port flowOutput : FlowMonitorPort;
        
        action def MeasureFlow {
            out flowReading : ISQ::VolumeFlowRateValue;
        }
    }

    part def SafetyMonitor {
        attribute pressureThreshold : ISQ::PressureValue = 45000.0[SI::Pa];
        attribute timeThreshold : ISQ::TimeValue = 7200.0[SI::s];
        attribute currentDuration : ISQ::TimeValue = 0.0[SI::s];
        
        port safetyOutput : SafetyPort;
        
        action def CheckPressureSafety {
            in currentPressure : ISQ::PressureValue;
            in maxPressure : ISQ::PressureValue;
            out isSafe : Boolean;
        }
        
        action def CheckDurationSafety {
            in elapsed : ISQ::TimeValue;
            in maxDuration : ISQ::TimeValue;
            out isSafe : Boolean;
        }
    }

    part def PenisClamp {
        doc /* Medical device for managing male urinary incontinence through controlled external urethral compression. */
        
        attribute deviceState : String = "Idle";
        attribute currentCompressionLevel : PressureLevel = 0.0;
        
        part compressionMech : CompressionMechanism;
        part pressurePad : PressurePad;
        part adjustmentLever : AdjustmentLever;
        part flowSensor : FlowSensor;
        part safetyMonitor : SafetyMonitor;
        
        port compressionControl : CompressionControlPort;
        port flowMonitoring : ~FlowMonitorPort;
        port safetyStatus : ~SafetyPort;
        
        connect compressionMech.controlInput to compressionControl;
        connect flowSensor.flowOutput to flowMonitoring;
        connect safetyMonitor.safetyOutput to safetyStatus;
    }

    action def MonitorUrineFlow {
        in sensor : FlowSensor;
        out flowStatus : ISQ::VolumeFlowRateValue;
    }

    action def AdjustCompressionLevel {
        in desiredLevel : Integer;
        in currentLevel : Integer;
        out targetForce : ISQ::ForceValue;
    }

    action def VerifySafety {
        in pressure : ISQ::PressureValue;
        in duration : ISQ::TimeValue;
        out safetyStatus : Boolean;
    }

    action def ControlIncontinence {
        doc /* Primary action to manage urinary flow through controlled compression. */
        
        first start;
        
        then action initialize {
            out initialState : String = "Ready";
        }
        
        then merge monitoringLoop;
        
        then action measureFlow : MonitorUrineFlow {
            in sensor;
            out flowStatus;
        }
        
        then decide;
            if measureFlow.flowStatus > 5.0e-7[SI::m^3/SI::s] then applyCompression;
            if measureFlow.flowStatus <= 5.0e-7[SI::m^3/SI::s] then maintainState;
        
        action applyCompression : AdjustCompressionLevel {
            in desiredLevel = 3;
            in currentLevel = 0;
            out targetForce;
        }
        
        then action checkSafety : VerifySafety {
            in pressure = 30000.0[SI::Pa];
            in duration = 1800.0[SI::s];
            out safetyStatus;
        }
        
        then decide;
            if checkSafety.safetyStatus then monitoringLoop;
            if not checkSafety.safetyStatus then emergencyRelease;
        
        action maintainState;
        then monitoringLoop;
        
        action emergencyRelease;
        then done;
    }

    attribute def PositioningSignal;
    attribute def CompressionSignal;
    attribute def TargetPressureReached;
    attribute def ReleaseSignal;
    attribute def SafetyViolation;
    attribute def CompressionReleased;

    state def ClampOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Device is not applying compression. */
        }
        
        transition idle_to_positioning
            first idle
            accept at PositioningSignal
            then positioning;
        
        state positioning {
            doc /* User is positioning the device. */
            entry action positionDevice;
        }
        
        transition positioning_to_compressing
            first positioning
            accept at CompressionSignal
            then compressing;
        
        state compressing {
            doc /* Device is actively applying compression. */
            entry action initiateCompression;
            do action monitorPressure;
        }
        
        transition compressing_to_active
            first compressing
            accept at TargetPressureReached
            then active;
        
        state active {
            doc /* Device is maintaining target compression level. */
            do action continuousMonitoring;
        }
        
        transition active_to_releasing
            first active
            accept at ReleaseSignal
            then releasing;
        
        transition active_to_emergency
            first active
            accept at SafetyViolation
            then emergency;
        
        state releasing {
            doc /* Device is gradually releasing compression. */
            entry action gradualRelease;
        }
        
        transition releasing_to_idle
            first releasing
            accept at CompressionReleased
            then idle;
        
        state emergency {
            doc /* Emergency release due to safety concern. */
            entry action immediateRelease;
        }
        
        transition emergency_to_idle
            first emergency
            then idle;
    }

    part clampSystem : PenisClamp {
        perform action manageIncontinence : ControlIncontinence;
        exhibit state operationalBehavior : ClampOperationalStates;
    }

    requirement def SafetyRequirement {
        doc /* The device shall operate within safe pressure and duration limits to prevent tissue damage. */
        
        subject device : PenisClamp;
        
        require constraint pressureLimit {
            device.pressurePad.appliedPressure <= 45000.0[SI::Pa]
        }
        
        require constraint durationLimit {
            device.safetyMonitor.currentDuration <= 7200.0[SI::s]
        }
    }

    requirement def FunctionalRequirement {
        doc /* The device shall effectively restrict urinary flow when properly applied. */
        
        subject device : PenisClamp;
        
        require constraint compressionEffectiveness {
            device.compressionMech.appliedForce >= 2.0[SI::N]
        }
        
        require constraint flowReduction {
            device.flowSensor.measuredFlow <= 1.0e-7[SI::m^3/SI::s]
        }
    }

    requirement def UsabilityRequirement {
        doc /* The device shall be adjustable and easy to apply and remove by the user. */
        
        subject device : PenisClamp;
        
        require constraint adjustabilityRange {
            device.adjustmentLever.maxPositions >= 5
        }
    }

    requirement def ComfortRequirement {
        doc /* The device shall distribute pressure evenly to minimize discomfort. */
        
        subject device : PenisClamp;
        
        require constraint pressureDistribution {
            device.pressurePad.contactArea >= 0.0004[SI::m^2]
        }
    }

    requirement <'SYS-001'> primarySystemRequirement {
        doc /* The penis clamp system shall provide controlled, safe, and effective management 
               of male urinary incontinence through adjustable external urethral compression. */
        
        subject clampSystem;
        
        require safetyRequirement : SafetyRequirement;
        require functionalRequirement : FunctionalRequirement;
        require usabilityRequirement : UsabilityRequirement;
        require comfortRequirement : ComfortRequirement;
    }

    occurrence def TypicalUsageScenario {
        ref part user;
        ref part device : PenisClamp;
        
        message positioningCommand
            from user to device.compressionControl;
        
        then message compressionCommand
            from user to device.compressionControl;
        
        then message flowFeedback
            from device.flowMonitoring to user;
        
        then message safetyStatus
            from device.safetyStatus to user;
        
        then message releaseCommand
            from user to device.compressionControl;
    }
}
