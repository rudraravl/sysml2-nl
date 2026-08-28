package Trimprob {
    import ScalarValues::*;
    
    attribute def Frequency :> Real { unit 'kHz'; }
    attribute def Power :> Real { unit 'mW'; }
    attribute def Duration :> Real { unit 'min'; }
    attribute def Percentage :> Real { unit '%'; }
    
    item def ControlSignal {
        attribute command : String;
    }
    
    item def EMWave {
        attribute frequency : Frequency;
        attribute power : Power;
    }
    
    item def TissueResponse {
        attribute frequency : Frequency;
        attribute amplitude : Real;
        attribute phase : Real;
    }
    
    item def DiagnosticResult {
        attribute anomalyScore : Percentage;
        attribute confidence : Percentage;
    }
    
    port def ControlPort { out item : ControlSignal; }
    port def WavePort { out item : EMWave; }
    port def ResponsePort { out item : TissueResponse; }
    port def ResultPort { out item : DiagnosticResult; }
    port def DisplayPort { out item : DiagnosticResult; }
    
    part def SignalGenerator {
        port in controlIn : ControlPort;
        port out waveOut : WavePort;
        attribute minFrequency : Frequency = 10;
        attribute maxFrequency : Frequency = 500;
        attribute maxPower : Power = 1;
    }
    
    part def ProbeHead {
        port in waveIn : WavePort;
        port out responseOut : ResponsePort;
    }
    
    part def ResponseAnalyzer {
        port in responseIn : ResponsePort;
        port out resultOut : ResultPort;
    }
    
    part def ControlProcessor {
        port in resultIn : ResultPort;
        port out controlOut : ControlPort;
        port out displayOut : DisplayPort;
    }
    
    part def BatteryPack {
        attribute minCapacity : Duration = 240;
    }
    
    part def DisplayScreen {
        port in displayIn : DisplayPort;
    }
    
    part def TrimprobDevice {
        part controlProcessor : ControlProcessor;
        part signalGenerator : SignalGenerator;
        part probeHead : ProbeHead;
        part responseAnalyzer : ResponseAnalyzer;
        part batteryPack : BatteryPack;
        part displayScreen : DisplayScreen;
        
        connection controlToGenerator connect controlProcessor.controlOut to signalGenerator.controlIn;
        connection generatorToProbe connect signalGenerator.waveOut to probeHead.waveIn;
        connection probeToAnalyzer connect probeHead.responseOut to responseAnalyzer.responseIn;
        connection analyzerToProcessor connect responseAnalyzer.resultOut to controlProcessor.resultIn;
        connection processorToDisplay connect controlProcessor.displayOut to displayScreen.displayIn;
        
        attribute scanDurationLimit : Duration = 2;
        
        state machine def OperationStateMachine {
            state off;
            state ready;
            state scanning {
                state sweeping;
                state analyzing;
                state displaying;
                transition sweeping to analyzing when sweepComplete;
                transition analyzing to displaying when analysisComplete;
            }
            transition off to ready when powerOn;
            transition ready to scanning when initiateScan;
            transition scanning to ready when scanComplete;
        }
    }
    
    requirement def NonInvasiveDetection {
        subject device : TrimprobDevice;
        doc /* The device shall detect pathological conditions without surgery or biopsies. */
    }
    
    requirement def FrequencySweepRange {
        subject generator : SignalGenerator;
        doc /* The device shall sweep frequencies from 10 kHz to 500 kHz. */
        constraint { generator.minFrequency == 10 and generator.maxFrequency == 500 }
    }
    
    requirement def EmissionSafetyLimit {
        subject generator : SignalGenerator;
        doc /* The device shall keep energy emissions below 1 milliwatt. */
        constraint { generator.maxPower < 1 }
    }
    
    requirement def BatteryLifeRequirement {
        subject battery : BatteryPack;
        doc /* The battery shall allow at least four hours of continuous use. */
        constraint { battery.minCapacity >= 240 }
    }
    
    requirement def ScanDurationRequirement {
        subject device : TrimprobDevice;
        doc /* The scan shall complete within about two minutes. */
        constraint { device.scanDurationLimit <= 2 }
    }
}
