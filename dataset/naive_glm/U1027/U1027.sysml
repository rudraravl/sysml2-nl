package HardwareDesignAutomationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type GateCount :> Real { unit 'gates'; }
    value type Frequency :> Real { unit 'MHz'; }
    value type Voltage :> Real { unit 'V'; }
    value type Coverage :> Real { unit '%'; }
    value type ElapsedTime :> Real { unit 's'; }
    value type PatternCount :> Integer;
    value type DefectCount :> Integer;
    value type ConfidenceLevel :> Real { unit '%'; }

    // ===== Item Types =====
    item def HDLSpecification {
        attribute language : String;
        attribute moduleCount : Integer;
        attribute lineCount : Integer;
        attribute description : String;
    }

    item def Netlist {
        attribute gateCount : GateCount;
        attribute nodeCount : Integer;
        attribute standardCellLibrary : String;
        attribute version : String;
    }

    item def VerificationResult {
        attribute isCorrect : Boolean;
        attribute coverage : Coverage;
        attribute errorCount : Integer;
        attribute timestamp : String;
    }

    item def TestPattern {
        attribute patternId : String;
        attribute inputVector : String;
        attribute expectedOutput : String;
        attribute patternCount : PatternCount;
    }

    item def TestPatternSet {
        attribute patterns : TestPattern[0..*];
        attribute totalPatterns : PatternCount;
        attribute faultCoverage : Coverage;
    }

    item def PhysicalChip {
        attribute chipId : String;
        attribute operatingVoltage : Voltage;
        attribute maxFrequency : Frequency;
        attribute packageType : String;
    }

    item def TestResult {
        attribute chipId : String;
        attribute passed : Boolean;
        attribute patternsPassed : PatternCount;
        attribute patternsFailed : PatternCount;
        attribute executionTime : ElapsedTime;
    }

    item def DiagnosticReport {
        attribute chipId : String;
        attribute defectCount : DefectCount;
        attribute suspectedLocation : String;
        attribute confidence : ConfidenceLevel;
        attribute rootCause : String;
    }

    item def FinalReport {
        attribute reportId : String;
        attribute designCertified : Boolean;
        attribute testCoverage : Coverage;
        attribute verificationCoverage : Coverage;
        attribute totalChipsTested : Integer;
        attribute totalChipsPassed : Integer;
        attribute generationDate : String;
    }

    // ===== Port Definitions =====
    port def HDLSpecPort {
        out item hdls : HDLSpecification;
    }

    port def NetlistPort {
        out item netlist : Netlist;
    }

    port def VerificationResultPort {
        out item result : VerificationResult;
    }

    port def TestPatternSetPort {
        out item patternSet : TestPatternSet;
    }

    port def TestResultPort {
        out item testResult : TestResult;
    }

    port def DiagnosticReportPort {
        out item diagReport : DiagnosticReport;
    }

    port def FinalReportPort {
        out item finalReport : FinalReport;
    }

    port def ChipPort {
        in item chip : PhysicalChip;
    }

    // ===== Parts =====
    part def LogicSynthesizer {
        attribute name : String = "LogicSynthesizer";
        attribute targetLibrary : String;
        attribute optimizationLevel : Integer;

        port hdlsIn : HDLSpecPort;
        port netlistOut : NetlistPort;

        action synthesize {
            in hdls : HDLSpecification;
            out netlist : Netlist;
        }
    }

    part def FormalVerifier {
        attribute name : String = "FormalVerifier";
        attribute proofMethod : String;
        attribute maxIterations : Integer;

        port netlistIn : NetlistPort;
        port hdlsIn : HDLSpecPort;
        port resultOut : VerificationResultPort;

        action verify {
            in netlist : Netlist;
            in hdls : HDLSpecification;
            out result : VerificationResult;
        }
    }

    part def TestPatternGenerator {
        attribute name : String = "TestPatternGenerator";
        attribute faultModel : String;
        attribute targetCoverage : Coverage;

        port netlistIn : NetlistPort;
        port patternSetOut : TestPatternSetPort;

        action generatePatterns {
            in netlist : Netlist;
            out patternSet : TestPatternSet;
        }
    }

    part def AutomaticTestEquipment {
        attribute name : String = "AutomaticTestEquipment";
        attribute maxChannels : Integer;
        attribute testVoltage : Voltage;
        attribute clockFrequency : Frequency;

        port patternSetIn : TestPatternSetPort;
        port chipIn : ChipPort;
        port testResultOut : TestResultPort;

        action applyTests {
            in patternSet : TestPatternSet;
            in chip : PhysicalChip;
            out testResult : TestResult;
        }
    }

    part def DiagnosticAnalyzer {
        attribute name : String = "DiagnosticAnalyzer";
        attribute analysisMethod : String;
        attribute resolutionDepth : Integer;

        port testResultIn : TestResultPort;
        port diagReportOut : DiagnosticReportPort;

        action diagnose {
            in testResult : TestResult;
            out diagReport : DiagnosticReport;
        }
    }

    part def ReportGenerator {
        attribute name : String = "ReportGenerator";
        attribute reportFormat : String;
        attribute includeDiagnostics : Boolean;

        port verificationResultIn : VerificationResultPort;
        port testResultIn : TestResultPort;
        port diagReportIn : DiagnosticReportPort;
        port finalReportOut : FinalReportPort;

        action compileReport {
            in verificationResult : VerificationResult;
            in testResult : TestResult;
            in diagReport : DiagnosticReport;
            out finalReport : FinalReport;
        }
    }

    // ===== Workflow Controller State Machine =====
    part def WorkflowController {
        attribute name : String = "WorkflowController";
        attribute currentDesignId : String;
        attribute totalIterations : Integer;

        port hdlsIn : HDLSpecPort;
        port finalReportOut : FinalReportPort;

        part synthesizer : LogicSynthesizer {
            attribute targetLibrary = "TSMC28nm";
            attribute optimizationLevel = 2;
        }
        part verifier : FormalVerifier {
            attribute proofMethod = "ModelChecking";
            attribute maxIterations = 1000;
        }
        part patternGenerator : TestPatternGenerator {
            attribute faultModel = "StuckAt";
            attribute targetCoverage = 98.0;
        }
        part ate : AutomaticTestEquipment {
            attribute maxChannels = 512;
            attribute testVoltage = 1.2;
            attribute clockFrequency = 500.0;
        }
        part diagnosticAnalyzer : DiagnosticAnalyzer {
            attribute analysisMethod = "FaultSimulation";
            attribute resolutionDepth = 5;
        }
        part reportGenerator : ReportGenerator {
            attribute reportFormat = "PDF";
            attribute includeDiagnostics = true;
        }

        // Connections
        connection synthesizeToVerify : NetlistPort connect synthesizer.netlistOut to verifier.netlistIn;
        connection verifyToPatternGen : NetlistPort connect verifier.netlistIn to patternGenerator.netlistIn;
        connection patternGenToATE : TestPatternSetPort connect patternGenerator.patternSetOut to ate.patternSetIn;
        connection ateToDiagnostic : TestResultPort connect ate.testResultOut to diagnosticAnalyzer.testResultIn;
        connection diagnosticToReport : DiagnosticReportPort connect diagnosticAnalyzer.diagReportOut to reportGenerator.diagReportIn;
        connection verifyToReport : VerificationResultPort connect verifier.resultOut to reportGenerator.verificationResultIn;
        connection ateToReport : TestResultPort connect ate.testResultOut to reportGenerator.testResultIn;
        connection reportToOutput : FinalReportPort connect reportGenerator.finalReportOut to finalReportOut;
        connection hdlsToSynthesizer : HDLSpecPort connect hdlsIn to synthesizer.hdlsIn;
        connection hdlsToVerifier : HDLSpecPort connect hdlsIn to verifier.hdlsIn;

        // State Machine
        state def DesignWorkflow {
            entry action { print("Workflow started for design: " + currentDesignId); }

            state idle {
                entry action { print("Idle: waiting for HDL specification input."); }
                transition to synthesizing on hdlsIn.hdls;
            }

            state synthesizing {
                entry action {
                    print("Synthesizing: translating HDL to netlist...");
                    synthesizer.synthesize(hdlsIn.hdls, synthesizer.netlistOut.netlist);
                }
                transition to verifying on synthesizer.netlistOut.netlist;
            }

            state verifying {
                entry action {
                    print("Verifying: formally checking netlist against HDL specification...");
                    verifier.verify(verifier.netlistIn.netlist, verifier.hdlsIn.hdls, verifier.resultOut.result);
                }
                transition to patternGenerating when verifier.resultOut.result.isCorrect;
                transition to failedVerification when !verifier.resultOut.result.isCorrect;
            }

            state patternGenerating {
                entry action {
                    print("Generating test patterns for manufacturing fault detection...");
                    patternGenerator.generatePatterns(patternGenerator.netlistIn.netlist, patternGenerator.patternSetOut.patternSet);
                }
                transition to physicalTesting on patternGenerator.patternSetOut.patternSet;
            }

            state physicalTesting {
                entry action {
                    print("Applying test patterns to physical chip via ATE...");
                    ate.applyTests(ate.patternSetIn.patternSet, ate.chipIn.chip, ate.testResultOut.testResult);
                }
                transition to diagnosing when !ate.testResultOut.testResult.passed;
                transition to reporting when ate.testResultOut.testResult.passed;
            }

            state diagnosing {
                entry action {
                    print("Diagnosing: analyzing test failures to locate physical defects...");
                    diagnosticAnalyzer.diagnose(diagnosticAnalyzer.testResultIn.testResult, diagnosticAnalyzer.diagReportOut.diagReport);
                }
                transition to reporting on diagnosticAnalyzer.diagReportOut.diagReport;
            }

            state reporting {
                entry action {
                    print("Compiling final certification report...");
                    reportGenerator.compileReport(
                        reportGenerator.verificationResultIn.result,
                        reportGenerator.testResultIn.testResult,
                        reportGenerator.diagReportIn.diagReport,
                        reportGenerator.finalReportOut.finalReport
                    );
                }
                transition to completed on reportGenerator.finalReportOut.finalReport;
            }

            state failedVerification {
                entry action { print("Verification failed: logical errors detected in synthesis."); }
                transition to idle;
            }

            state completed {
                entry action { print("Workflow completed: final report generated and design certified."); }
            }
        }

        state machine : DesignWorkflow;
    }

    // ===== Requirements =====
    requirement def SynthesisRequirement {
        doc { The Logic Synthesizer shall translate HDL specifications into netlists using standard logic gates. }
        attribute targetGateLibrary : String;
        attribute maxSynthesisTime : ElapsedTime;
        constraint { maxSynthesisTime <= 3600.0 }
    }

    requirement def VerificationRequirement {
        doc { The Formal Verifier shall mathematically prove netlist equivalence to the HDL specification. }
        attribute requiredCoverage : Coverage;
        constraint { requiredCoverage >= 95.0 }
    }

    requirement def TestPatternRequirement {
        doc { The Test Pattern Generator shall produce patterns achieving target fault coverage. }
        attribute targetFaultCoverage : Coverage;
        attribute minPatterns : PatternCount;
        constraint { targetFaultCoverage >= 98.0 }
        constraint { minPatterns >= 1000 }
    }

    requirement def ATERequirement {
        doc { The Automatic Test Equipment shall apply all test patterns to physical chips and record results. }
        attribute maxTestTime : ElapsedTime;
        attribute supportedVoltageRange : Voltage;
        constraint { maxTestTime <= 7200.0 }
    }

    requirement def DiagnosticRequirement {
        doc { The Diagnostic Analyzer shall identify suspected defect locations with specified confidence. }
        attribute minConfidence : ConfidenceLevel;
        constraint { minConfidence >= 90.0 }
    }

    requirement def ReportRequirement {
        doc { The Report Generator shall compile verification, testing, and diagnostic data into a final report. }
        attribute requiredTestCoverage : Coverage;
        attribute requiredVerificationCoverage : Coverage;
        constraint { requiredTestCoverage >= 98.0 }
        constraint { requiredVerificationCoverage >= 95.0 }
    }

    requirement def WorkflowRequirement {
        doc { The Workflow Controller shall guide designs through synthesis, verification, pattern generation, and physical testing in sequence. }
        attribute maxTotalTime : ElapsedTime;
        constraint { maxTotalTime <= 14400.0 }
    }

    // ===== Top-level System =====
    part def HardwareDesignAutomationSystem {
        attribute systemName : String = "IntegratedHardwareDesignAutomationSystem";
        attribute version : String = "1.0";

        part controller : WorkflowController;
        part synthesizer : LogicSynthesizer;
        part verifier : FormalVerifier;
        part patternGenerator : TestPatternGenerator;
        part ate : AutomaticTestEquipment;
        part diagnosticAnalyzer : DiagnosticAnalyzer;
        part reportGenerator : ReportGenerator;

        // System-level connections
        connection sysHdlsToController : HDLSpecPort connect controller.hdlsIn to synthesizer.hdlsIn;
        connection sysReportFromController : FinalReportPort connect controller.finalReportOut to reportGenerator.finalReportOut;

        // Requirement satisfactions
        satisfy SynthesisRequirement by synthesizer;
        satisfy VerificationRequirement by verifier;
        satisfy TestPatternRequirement by patternGenerator;
        satisfy ATERequirement by ate;
        satisfy DiagnosticRequirement by diagnosticAnalyzer;
        satisfy ReportRequirement by reportGenerator;
        satisfy WorkflowRequirement by controller;
    }
}
