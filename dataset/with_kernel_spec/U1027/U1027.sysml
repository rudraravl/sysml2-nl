package 'Electronic Hardware Design Automation' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    package 'Item Definitions' {
        item def HDLDesign {
            attribute designName : String;
            attribute hdlSource : String;
        }
        item def Netlist {
            attribute gateCount : Integer;
            attribute netCount : Integer;
        }
        item def VerificationResult {
            attribute isCorrect : Boolean;
            attribute errorCount : Integer;
        }
        item def TestPatternSet {
            attribute coverage : Real;
        }
        item def PhysicalChip {
            attribute serialNumber : String;
        }
        item def TestResults {
            attribute chipSerial : String;
            attribute passed : Boolean;
            attribute failedPatterns : String[*];
        }
        item def DiagnosticReport {
            attribute defectLocation : String;
            attribute likelyCause : String;
        }
        item def FinalReport {
            attribute designName : String;
            attribute verificationPassed : Boolean;
            attribute testCoverage : Real;
            attribute overallCertified : Boolean;
        }
    }
    
    package 'Port Definitions' {
        private import 'Item Definitions'::*;
        
        port def HDLInputPort { in hdl : HDLDesign; }
        port def NetlistOutputPort { out netlist : Netlist; }
        port def NetlistInputPort { in netlist : Netlist; }
        port def VerificationOutputPort { out result : VerificationResult; }
        port def VerificationInputPort { in result : VerificationResult; }
        port def TestPatternOutputPort { out patterns : TestPatternSet; }
        port def TestPatternInputPort { in patterns : TestPatternSet; }
        port def ChipInputPort { in chip : PhysicalChip; }
        port def TestResultsOutputPort { out result : TestResults; }
        port def TestResultsInputPort { in result : TestResults; }
        port def DiagnosticOutputPort { out report : DiagnosticReport; }
        port def DiagnosticInputPort { in report : DiagnosticReport; }
        port def FinalReportOutputPort { out finalReport : FinalReport; }
    }
    
    package 'Component Definitions' {
        private import 'Port Definitions'::*;
        
        part def LogicSynthesizer {
            port hdlIn : HDLInputPort;
            port netlistOut : NetlistOutputPort;
        }
        part def FormalVerifier {
            port hdlIn : HDLInputPort;
            port netlistIn : NetlistInputPort;
            port resultOut : VerificationOutputPort;
        }
        part def TestPatternGenerator {
            port netlistIn : NetlistInputPort;
            port patternOut : TestPatternOutputPort;
        }
        part def AutomaticTestEquipment {
            port patternIn : TestPatternInputPort;
            port chipIn : ChipInputPort;
            port resultOut : TestResultsOutputPort;
        }
        part def DiagnosticAnalyzer {
            port resultIn : TestResultsInputPort;
            port reportOut : DiagnosticOutputPort;
        }
        part def ReportGenerator {
            port verificationIn : VerificationInputPort;
            port testResultIn : TestResultsInputPort;
            port diagnosticIn : DiagnosticInputPort;
            port reportOut : FinalReportOutputPort;
        }
    }
    
    package 'Requirements' {
        requirement def SynthesisRequirement {
            doc /* The synthesizer shall convert HDL into a netlist of standard logic gates. */
        }
        requirement def VerificationRequirement {
            doc /* The formal verifier shall mathematically confirm netlist matches HDL. */
        }
        requirement def TestCoverageRequirement {
            doc /* Test patterns shall achieve at least 95% fault coverage. */
            attribute minCoverage : Real = 0.95;
        }
        requirement def ATERequirement {
            doc /* ATE shall apply all test patterns to each manufactured chip. */
        }
        requirement def DiagnosticRequirement {
            doc /* The diagnostic analyzer shall localize defects to within a single functional block. */
        }
        requirement def ReportRequirement {
            doc /* Report generator shall compile verification and test data into a final report. */
        }
    }
    
    package 'Workflow Behavior' {
        private import 'Item Definitions'::*;
        
        action def Synthesize { in hdl : HDLDesign; out netlist : Netlist; }
        action def Verify { in netlist : Netlist; in hdl : HDLDesign; out result : VerificationResult; }
        action def GeneratePatterns { in netlist : Netlist; out patterns : TestPatternSet; }
        action def RunTests { in patterns : TestPatternSet; in chip : PhysicalChip; out result : TestResults; }
        action def Analyze { in result : TestResults; out report : DiagnosticReport; }
        action def CompileReport { in verification : VerificationResult; in testResult : TestResults; in diagnostic : DiagnosticReport; out finalReport : FinalReport; }
        
        state def EDAWorkflow {
            state synthesisState;
            state verificationState;
            state patternGenerationState;
            state testingState;
            state diagnosticState;
            state reportState;
            state done;
            
            first synthesisState;
            then verificationState;
            then patternGenerationState;
            then testingState;
            then reportState;
            then done;
            
            first verificationState then synthesisState;
            first testingState then diagnosticState;
            first diagnosticState then reportState;
        }
    }
    
    package 'System Assembly' {
        private import 'Component Definitions'::*;
        private import 'Requirements'::*;
        private import 'Workflow Behavior'::*;
        
        part def EDASystem {
            part synthesizer : LogicSynthesizer;
            part verifier : FormalVerifier;
            part patternGenerator : TestPatternGenerator;
            part ate : AutomaticTestEquipment;
            part diagnosticAnalyzer : DiagnosticAnalyzer;
            part reportGenerator : ReportGenerator;
            
            satisfy SynthesisRequirement by synthesizer;
            satisfy VerificationRequirement by verifier;
            satisfy TestCoverageRequirement by patternGenerator;
            satisfy ATERequirement by ate;
            satisfy DiagnosticRequirement by diagnosticAnalyzer;
            satisfy ReportRequirement by reportGenerator;
            
            connection connect synthesizer.netlistOut to verifier.netlistIn;
            connection connect synthesizer.netlistOut to patternGenerator.netlistIn;
            connection connect verifier.resultOut to reportGenerator.verificationIn;
            connection connect patternGenerator.patternOut to ate.patternIn;
            connection connect ate.resultOut to diagnosticAnalyzer.resultIn;
            connection connect ate.resultOut to reportGenerator.testResultIn;
            connection connect diagnosticAnalyzer.reportOut to reportGenerator.diagnosticIn;
        }
    }
    
    package 'System Instance' {
        private import 'System Assembly'::*;
        private import 'Workflow Behavior'::*;
        
        part edaSystemInstance : EDASystem {
            exhibit workflow : EDAWorkflow;
        }
    }
}
