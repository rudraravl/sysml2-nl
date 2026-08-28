package TRLManagementSystem {
    import ScalarValues::*;
    import SI::degC;
    import SI::W;
    import SI::h;
    import SI::g;
    import SI::V;
    import SI::m;
    
    // ---------- Value types ----------
    value type TRLLevel :> Integer {
        constraint { 1 <= self and self <= 9 };
    }
    
    value type TemperatureValue :> Real {
        unit degC;
    }
    
    value type PowerValue :> Real {
        unit W;
    }
    
    value type ReliabilityValue :> Real {
        unit percent;
        constraint { 0.0 <= self and self <= 100.0 };
    }
    
    value type EfficiencyValue :> Real {
        unit percent;
        constraint { 0.0 <= self and self <= 100.0 };
    }
    
    value type DurationValue :> Real {
        unit h;
    }
    
    value type VibrationLevel :> Real {
        unit g;
        constraint { 0.0 <= self };
    }
    
    value type EMFieldStrength :> Real {
        unit V_per_m;
        constraint { 0.0 <= self };
    }
    
    // ---------- Enumerations ----------
    enum TestVerdict {
        pending,
        pass,
        fail,
        inconclusive,
    }
    
    enum AssessmentDecisionKind {
        pending,
        advance,
        rework,
        reject,
    }
    
    enum StressKind {
        thermal,
        vibration,
        electromagnetic,
        combined,
    }
    
    // ---------- Item definitions ----------
    item def PrototypeCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute targetTRL : TRLLevel;
        attribute parameters : String;
    }
    
    item def PrototypeTelemetry {
        attribute telemetryId : String;
        attribute timestamp : String;
        attribute temperature : TemperatureValue;
        attribute powerDraw : PowerValue;
        attribute efficiency : EfficiencyValue;
        attribute reliability : ReliabilityValue;
        attribute operational : Boolean;
    }
    
    item def StressProfile {
        attribute profileId : String;
        attribute kind : StressKind;
        attribute thermalStress : TemperatureValue;
        attribute vibrationLevel : VibrationLevel;
        attribute emStress : EMFieldStrength;
        attribute duration : DurationValue;
    }
    
    item def TestResult {
        attribute resultId : String;
        attribute targetTRL : TRLLevel;
        attribute measuredTRL : TRLLevel;
        attribute verdict : TestVerdict;
        attribute collectedTelemetry : PrototypeTelemetry[0..*];
        attribute appliedStress : StressProfile;
        attribute timestamp : String;
    }
    
    item def AssessmentReport {
        attribute reportId : String;
        attribute resultRef : TestResult;
        attribute currentTRL : TRLLevel;
        attribute targetTRL : TRLLevel;
        attribute decision : AssessmentDecisionKind;
        attribute rationale : String;
        attribute timestamp : String;
    }
    
    // ---------- Port definitions ----------
    port def CommandPort {
        in item : PrototypeCommand;
    }
    
    port def TelemetryOutPort {
        out item : PrototypeTelemetry;
    }
    
    port def StressReceivePort {
        in item : StressProfile;
    }
    
    port def StressApplyPort {
        out item : StressProfile;
    }
    
    port def ResultEmitPort {
        out item : TestResult;
    }
    
    port def ResultReceivePort {
        in item : TestResult;
    }
    
    port def DecisionEmitPort {
        out item : AssessmentReport;
    }
    
    port def DecisionReceivePort {
        in item : AssessmentReport;
    }
    
    // ---------- Interface definitions ----------
    interface def ProtoCommandInterface {
        end :> src : CommandPort;
        end :> dst : CommandPort;
    }
    
    interface def TelemetryInterface {
        end :> src : TelemetryOutPort;
        end :> dst : TelemetryOutPort;
    }
    
    interface def StressInterface {
        end :> src : StressApplyPort;
        end :> dst : StressReceivePort;
    }
    
    interface def ResultInterface {
        end :> src : ResultEmitPort;
        end :> dst : ResultReceivePort;
    }
    
    interface def DecisionInterface {
        end :> src : DecisionEmitPort;
        end :> dst : DecisionReceivePort;
    }
    
    // ---------- Prototype Subsystem ----------
    part def PrototypeSubsystem {
        attribute prototypeId : String;
        attribute targetTRL : TRLLevel;
        attribute achievedTRL : TRLLevel;
        
        attribute nominalReliability : ReliabilityValue;
        attribute nominalEfficiency : EfficiencyValue;
        attribute operatingTempMin : TemperatureValue;
        attribute operatingTempMax : TemperatureValue;
        attribute nominalPowerConsumption : PowerValue;
        
        port :> cmdIn : CommandPort;
        port :> telemOut : TelemetryOutPort;
        port :> stressIn : StressReceivePort;
        port :> resultOut : ResultEmitPort;
        port :> decisionIn : DecisionReceivePort;
        
        attribute currentTelemetry : PrototypeTelemetry;
        attribute lastResult : TestResult;
        
        // Behavior: receive and execute a command
        action receiveCommand {
            in cmd : PrototypeCommand;
            return ok : Boolean;
        }
        
        // Behavior: produce telemetry
        action produceTelemetry {
            in appliedStress : StressProfile;
            return telem : PrototypeTelemetry;
        }
        
        // Behavior: compute local TRL from telemetry and stress
        action computeLocalTRL {
            in telem : PrototypeTelemetry;
            in stress : StressProfile;
            return trl : TRLLevel;
        }
        
        // Behavior: emit a TestResult
        action emitTestResult {
            in telem : PrototypeTelemetry;
            in stress : StressProfile;
            in trl : TRLLevel;
            in target : TRLLevel;
            return result : TestResult;
        }
        
        // Behavior: apply rework from decision
        action applyRework {
            in report : AssessmentReport;
        }
        
        // State machine
        state PrototypeState {
            entry;
            state Idle;
            state Executing;
            state Measuring;
            state Reporting;
            state Reworking;
            
            transition init to Idle;
            transition from Idle to Executing when cmdIn.item.received;
            transition from Executing to Measuring when stressIn.item.received;
            transition from Measuring to Reporting when currentTelemetry.completed;
            transition from Reporting to Idle when resultOut.item.sent;
            transition from Idle to Reworking when decisionIn.item.received and decisionIn.item.decision == rework;
            transition from Reworking to Idle when applyRework.completed;
        }
    }
    
    // ---------- Test Environment ----------
    part def TestEnvironment {
        attribute environmentId : String;
        attribute thermalRangeMin : TemperatureValue;
        attribute thermalRangeMax : TemperatureValue;
        attribute vibrationRange : VibrationLevel;
        attribute emRange : EMFieldStrength;
        attribute maxDuration : DurationValue;
        
        port :> cmdOut : CommandPort;
        port :> stressOut : StressApplyPort;
        port :> telemIn : TelemetryOutPort;
        port :> resultOut : ResultEmitPort;
        
        attribute activeProfile : StressProfile;
        attribute observedTelemetry : PrototypeTelemetry;
        
        // Behavior: generate a stress profile
        action generateStressProfile {
            in kind : StressKind;
            in duration : DurationValue;
            return profile : StressProfile;
        }
        
        // Behavior: apply a stress profile
        action applyStress {
            in profile : StressProfile;
        }
        
        // Behavior: send a command to prototype
        action issueCommand {
            in cmd : PrototypeCommand;
        }
        
        // Behavior: compile a test result
        action compileResult {
            in telem : PrototypeTelemetry;
            in profile : StressProfile;
            in measuredTRL : TRLLevel;
            in targetTRL : TRLLevel;
            return result : TestResult;
        }
        
        // State machine
        state EnvironmentState {
            entry;
            state Idle;
            state Preparing;
            state ApplyingStress;
            state Measuring;
            state Compiling;
            
            transition init to Idle;
            transition from Idle to Preparing when activeProfile.generated;
            transition from Preparing to ApplyingStress when cmdOut.item.accepted;
            transition from ApplyingStress to Measuring when stressOut.item.delivered;
            transition from Measuring to Compiling when telemIn.item.received;
            transition from Compiling to Idle when resultOut.item.sent;
        }
    }
    
    // ---------- Assessment Authority ----------
    part def AssessmentAuthority {
        attribute authorityName : String;
        attribute targetTRL : TRLLevel;
        attribute authorityId : String;
        
        port :> resultIn : ResultReceivePort;
        port :> decisionOut : DecisionEmitPort;
        
        attribute lastReport : AssessmentReport;
        attribute reviewCount : Integer;
        
        // Behavior: review a test result
        action reviewResult {
            in result : TestResult;
            return ok : Boolean;
        }
        
        // Behavior: compute the official TRL decision
        action makeDecision {
            in result : TestResult;
            return report : AssessmentReport;
        }
        
        // Behavior: issue the report
        action issueReport {
            in report : AssessmentReport;
        }
        
        // State machine
        state AuthorityState {
            entry;
            state Awaiting;
            state Reviewing;
            state Deciding;
            state Issuing;
            
            transition init to Awaiting;
            transition from Awaiting to Reviewing when resultIn.item.received;
            transition from Reviewing to Deciding when reviewResult.completed;
            transition from Deciding to Issuing when makeDecision.completed;
            transition from Issuing to Awaiting when decisionOut.item.sent;
        }
    }
    
    // ---------- Overall TRL Management System ----------
    part def TRLManagementSystem {
        attribute systemId : String;
        attribute systemName : String;
        attribute targetTRL : TRLLevel default 6;
        attribute achievedTRL : TRLLevel;
        attribute iterationCount : Integer;
        
        part prototype : PrototypeSubsystem;
        part environment : TestEnvironment;
        part authority : AssessmentAuthority;
        
        // Connections among the three parts
        interface : ProtoCommandInterface {
            end :> src : environment.cmdOut;
            end :> dst : prototype.cmdIn;
        }
        
        interface : TelemetryInterface {
            end :> src : prototype.telemOut;
            end :> dst : environment.telemIn;
        }
        
        interface : StressInterface {
            end :> src : environment.stressOut;
            end :> dst : prototype.stressIn;
        }
        
        interface : ResultInterface {
            end :> src : prototype.resultOut;
            end :> dst : authority.resultIn;
        }
        
        interface : DecisionInterface {
            end :> src : authority.decisionOut;
            end :> dst : prototype.decisionIn;
        }
        
        // Top-level cyclical state machine
        state SystemCycle {
            entry;
            state Setup;
            state Demonstration;
            state Assessment;
            state Rework;
            state Completed;
            
            transition init to Setup;
            transition from Setup to Demonstration when prototype.ready and environment.ready;
            transition from Demonstration to Assessment when authority.resultIn.item.received;
            transition from Assessment to Rework when authority.decisionOut.item.received and authority.decisionOut.outReport.decision == rework;
            transition from Assessment to Completed when authority.decisionOut.item.received and authority.decisionOut.outReport.decision == advance;
            transition from Assessment to Completed when authority.decisionOut.item.received and authority.decisionOut.outReport.decision == reject;
            transition from Rework to Demonstration when prototype.applyRework.completed;
        }
        
        // Action: orchestrate one cycle
        action runCycle {
            in target : TRLLevel;
        }
    }
    
    // ---------- Requirements ----------
    requirement def TRLAdvancementRequirement {
        subject proto : PrototypeSubsystem;
        attribute targetTRL : TRLLevel;
        constraint { proto.achievedTRL >= targetTRL };
        doc { Requirement: The prototype must achieve at least the target TRL. }
    }
    
    requirement def OperationalReadinessRequirement {
        subject system : TRLManagementSystem;
        attribute targetTRL : TRLLevel;
        constraint { system.targetTRL == 6 };
        constraint { system.authority.targetTRL == 6 };
        doc { Requirement: For operational integration, the system must target TRL 6. }
    }
    
    requirement def TestEnvironmentFidelityRequirement {
        subject env : TestEnvironment;
        constraint { env.thermalRangeMax >= 85.0 degC };
        constraint { env.thermalRangeMin <= -40.0 degC };
        constraint { env.vibrationRange >= 5.0 g };
        constraint { env.emRange >= 200.0 V_per_m };
        doc { Requirement: The test environment must represent the worst-case operating stresses. }
    }
    
    requirement def PrototypePerformanceRequirement {
        subject proto : PrototypeSubsystem;
        constraint { proto.nominalReliability >= 95.0 percent };
        constraint { proto.nominalEfficiency >= 80.0 percent };
        constraint { proto.operatingTempMin <= -40.0 degC };
        constraint { proto.operatingTempMax >= 85.0 degC };
        constraint { proto.nominalPowerConsumption <= 250.0 W };
        doc { Requirement: The prototype must satisfy operational performance thresholds. }
    }
    
    requirement def AssessmentAuthorityIndependenceRequirement {
        subject auth : AssessmentAuthority;
        constraint { auth.authorityName == "Technology Review Board" };
        doc { Requirement: An independent Technology Review Board must render the official decision. }
    }
    
    requirement def CycleTerminationRequirement {
        subject system : TRLManagementSystem;
        constraint { system.SystemCycle.Completed.reached implies system.achievedTRL >= system.targetTRL };
        doc { Requirement: The test-assess cycle terminates only when the achieved TRL meets or exceeds the target TRL. }
    }
    
    // ---------- Satisfactions ----------
    satisfaction {
        subject proto : PrototypeSubsystem;
        satisfy PrototypePerformanceRequirement;
    }
    
    satisfaction {
        subject env : TestEnvironment;
        satisfy TestEnvironmentFidelityRequirement;
    }
    
    satisfaction {
        subject auth : AssessmentAuthority;
        satisfy AssessmentAuthorityIndependenceRequirement;
    }
    
    satisfaction {
        subject system : TRLManagementSystem;
        satisfy OperationalReadinessRequirement;
        satisfy CycleTerminationRequirement;
    }
    
    // ---------- Configured instance ----------
    part trl6Program : TRLManagementSystem {
        attribute systemId = "TRL6-SYS-001";
        attribute systemName = "TRL6 Advancement Program";
        attribute targetTRL = 6;
        attribute achievedTRL = 4;
        attribute iterationCount = 0;
        
        part prototype : PrototypeSubsystem {
            attribute prototypeId = "PROTO-A";
            attribute targetTRL = 6;
            attribute achievedTRL = 4;
            attribute nominalReliability = 96.0 percent;
            attribute nominalEfficiency = 82.0 percent;
            attribute operatingTempMin = -45.0 degC;
            attribute operatingTempMax = 90.0 degC;
            attribute nominalPowerConsumption = 180.0 W;
        }
        
        part environment : TestEnvironment {
            attribute environmentId = "ENV-1";
            attribute thermalRangeMin = -55.0 degC;
            attribute thermalRangeMax = 125.0 degC;
            attribute vibrationRange = 10.0 g;
            attribute emRange = 500.0 V_per_m;
            attribute maxDuration = 24.0 h;
        }
        
        part authority : AssessmentAuthority {
            attribute authorityName = "Technology Review Board";
            attribute authorityId = "TRB-001";
            attribute targetTRL = 6;
            attribute reviewCount = 0;
        }
    }
}
