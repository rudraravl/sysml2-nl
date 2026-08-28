package MillimeterWaveSecurityScanner {
    package Definitions {
        unit GHz;
        unit mW;
        unit rad;
        
        attribute def Frequency;
        attribute def Power;
        attribute def Amplitude;
        attribute def PhaseShift;
        
        attribute def ScanStartSignal;
        attribute def ScanCompleteSignal;
        attribute def ProcessCompleteSignal;
        attribute def AnalysisCompleteSignal;
        attribute def DisplayCompleteSignal;
        
        item def MillimeterWaveSignal {
            attribute frequency : Frequency;
            attribute power : Power;
        }
        item def ReflectedSignal {
            attribute amplitude : Amplitude;
            attribute phaseShift : PhaseShift;
        }
        item def RawReflectionData;
        item def ScanImage;
        item def ThreatAssessment {
            attribute threatDetected : Boolean;
            attribute threatLocation : String;
        }
        
        port def WaveOutPort { out item wave : MillimeterWaveSignal; }
        port def WaveInPort { in item wave : MillimeterWaveSignal; }
        port def ReflectionOutPort { out item reflection : ReflectedSignal; }
        port def ReflectionInPort { in item reflection : ReflectedSignal; }
        port def RawDataOutPort { out item data : RawReflectionData; }
        port def RawDataInPort { in item data : RawReflectionData; }
        port def ImageOutPort { out item image : ScanImage; }
        port def ImageInPort { in item image : ScanImage; }
        port def AssessmentOutPort { out item assessment : ThreatAssessment; }
        port def AssessmentInPort { in item assessment : ThreatAssessment; }
        
        action def Transmit { out item wave : MillimeterWaveSignal; }
        action def Radiate { in item wave : MillimeterWaveSignal; out item reflection : ReflectedSignal; }
        action def Receive { in item reflection : ReflectedSignal; out item data : RawReflectionData; }
        action def Process { in item data : RawReflectionData; out item image : ScanImage; }
        action def Analyze { in item image : ScanImage; out item assessment : ThreatAssessment; }
        action def Display { in item image : ScanImage; in item assessment : ThreatAssessment; }
        
        part def Transmitter {
            port outPort : WaveOutPort;
            perform Transmit;
        }
        part def AntennaArray {
            port txPort : WaveInPort;
            port rxPort : ReflectionOutPort;
            perform Radiate;
        }
        part def Receiver {
            port inPort : ReflectionInPort;
            port outPort : RawDataOutPort;
            perform Receive;
        }
        part def SignalProcessingUnit {
            port inPort : RawDataInPort;
            port outPort : ImageOutPort;
            perform Process;
        }
        part def ThreatDetectionModule {
            port inPort : ImageInPort;
            port outPort : AssessmentOutPort;
            perform Analyze;
        }
        part def OperatorConsole {
            port inImagePort : ImageInPort;
            port inAssessmentPort : AssessmentInPort;
            perform Display;
        }
        
        state def ScannerStates {
            entry; then idle;
            state idle;
            transition idle_to_scanning
                first idle
                accept ScanStartSignal
                then scanning;
            state scanning;
            transition scanning_to_processing
                first scanning
                accept ScanCompleteSignal
                then processing;
            state processing;
            transition processing_to_analyzing
                first processing
                accept ProcessCompleteSignal
                then analyzing;
            state analyzing;
            transition analyzing_to_displaying
                first analyzing
                accept AnalysisCompleteSignal
                then displaying;
            state displaying;
            transition displaying_to_idle
                first displaying
                accept DisplayCompleteSignal
                then idle;
        }
        
        requirement def DetectConcealedObjects {
            text "The system shall detect concealed objects such as weapons or contraband hidden beneath a person's clothing without physical contact.";
        }
        requirement def EmitLowPowerMillimeterWave {
            text "The transmitter shall emit very low-power millimeter-wave signals that penetrate clothing but reflect off the skin and objects carried on the body.";
        }
        requirement def ProcessReflectionData {
            text "The signal processing unit shall process raw reflection data including amplitude and phase shift to construct a detailed three-dimensional image.";
        }
        requirement def IdentifyThreats {
            text "The threat detection module shall identify shapes and densities that do not correspond to the human body and flag them as potential threats.";
        }
        requirement def DisplayResultsToOperator {
            text "The operator console shall display the scan image and threat assessment to a security officer.";
        }
        requirement def FollowOperationalFlow {
            text "The scanner shall follow an operational flow from idle through scanning, processing, analyzing, displaying, and back to idle.";
        }
    }
    
    package Usages {
        part ScannerSystem {
            part transmitter : Definitions::Transmitter {
                satisfy Definitions::EmitLowPowerMillimeterWave;
            }
            part antennaArray : Definitions::AntennaArray;
            part receiver : Definitions::Receiver;
            part signalProcessor : Definitions::SignalProcessingUnit {
                satisfy Definitions::ProcessReflectionData;
            }
            part threatDetector : Definitions::ThreatDetectionModule {
                satisfy Definitions::IdentifyThreats;
            }
            part operatorConsole : Definitions::OperatorConsole {
                satisfy Definitions::DisplayResultsToOperator;
            }
            
            connect transmitter.outPort to antennaArray.txPort;
            connect antennaArray.rxPort to receiver.inPort;
            connect receiver.outPort to signalProcessor.inPort;
            connect signalProcessor.outPort to threatDetector.inPort;
            connect signalProcessor.outPort to operatorConsole.inImagePort;
            connect threatDetector.outPort to operatorConsole.inAssessmentPort;
            
            state scannerStates : Definitions::ScannerStates;
            
            satisfy Definitions::DetectConcealedObjects;
            satisfy Definitions::FollowOperationalFlow;
        }
    }
}
