package OsteomedBoneHealingSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def UltrasoundSignal {
        attribute frequency :> ISQ::frequency;
        attribute intensity :> ISQ::power;
    }
    
    attribute def BoneDensityReading {
        attribute density :> ISQ::massDensity;
    }

    item def TreatmentProtocol {
        attribute duration :> ISQ::time;
        attribute frequency :> ISQ::frequency;
        attribute intensity :> ISQ::power;
    }

    attribute def LoadProtocolSignal;
    attribute def SessionComplete;
    attribute def ContinueTreatment;
    attribute def TreatmentComplete;

    port def PowerPort {
        out voltage :> ISQ::electricPotential;
        out current :> ISQ::electricCurrent;
    }
    port def ControlSignalPort {
        out signal : UltrasoundSignal;
    }
    port def UltrasoundWavePort {
        out wave : UltrasoundSignal;
    }
    port def SensorDataPort {
        out reading : BoneDensityReading;
    }

    action def InitializeSystem;
    action def DeliverUltrasound {
        in duration :> ISQ::time;
        in frequency :> ISQ::frequency;
        in intensity :> ISQ::power;
    }
    action def MonitorTissueResponse {
        out density :> ISQ::massDensity;
    }
    action def RecordData {
        in density :> ISQ::massDensity;
    }
    action def AssessProgress {
        in currentDensity :> ISQ::massDensity;
        out continueTreatment : Boolean;
    }
    action def GenerateReport;

    state def TherapySessionStates {
        entry; then initializing;
        state initializing {
            entry action init : InitializeSystem;
        }
        transition init_to_treating
            first initializing
            accept LoadProtocolSignal
            then treating;
        state treating {
            entry action deliver : DeliverUltrasound;
            do action monitor : MonitorTissueResponse;
            exit action record : RecordData;
        }
        transition treating_to_assessing
            first treating
            accept SessionComplete
            then assessing;
        state assessing {
            entry action assess : AssessProgress;
        }
        transition assess_to_treating
            first assessing
            accept ContinueTreatment
            then treating;
        transition assess_to_reporting
            first assessing
            accept TreatmentComplete
            then reporting;
        state reporting {
            entry action report : GenerateReport;
        }
    }

    part def PowerManagementUnit {
        port powerOut : PowerPort;
    }
    
    part def TreatmentControlUnit {
        port powerIn : ~PowerPort;
        port controlOut : ControlSignalPort;
        port dataIn : ~SensorDataPort;
        exhibit state therapyStates : TherapySessionStates;
    }
    
    part def UltrasoundGeneratorModule {
        port powerIn : ~PowerPort;
        port controlIn : ~ControlSignalPort;
        port waveOut : UltrasoundWavePort;
    }
    
    part def TransducerAssembly {
        port waveIn : ~UltrasoundWavePort;
    }
    
    part def BoneDensitySensor {
        port dataOut : SensorDataPort;
    }

    part def ApplicatorHead {
        port waveIn : ~UltrasoundWavePort;
        port dataOut : SensorDataPort;
        
        part transducer : TransducerAssembly;
        part sensor : BoneDensitySensor;
        
        connection waveConn from waveIn to transducer.waveIn;
        connection dataConn from sensor.dataOut to dataOut;
    }

    part def OsteomedSystem {
        part pmu : PowerManagementUnit;
        part tcu : TreatmentControlUnit;
        part ugm : UltrasoundGeneratorModule;
        part applicator : ApplicatorHead;
        
        connection powerToTCU from pmu.powerOut to tcu.powerIn;
        connection powerToUGM from pmu.powerOut to ugm.powerIn;
        connection controlToUGM from tcu.controlOut to ugm.controlIn;
        connection waveToApplicator from ugm.waveOut to applicator.waveIn;
        connection dataToTCU from applicator.dataOut to tcu.dataIn;
    }

    requirement def AccelerateHealing {
        doc /* The system shall accelerate bone fracture healing using LIPUS. */
    }
    requirement def DeliverTherapy {
        doc /* The system shall deliver ultrasound at a specific frequency and intensity for a set duration. */
    }
    requirement def MonitorProgress {
        doc /* The system shall monitor bone density and assess healing rate. */
    }
    requirement def GenerateTreatmentReport {
        doc /* The system shall generate a comprehensive report detailing treatment history and outcome. */
    }

    package Requirements {
        requirement accelHealing : AccelerateHealing;
        requirement deliverTherapy : DeliverTherapy;
        requirement monitorProgress : MonitorProgress;
        requirement generateReport : GenerateTreatmentReport;
    }
}
