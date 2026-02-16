package MatibabuDiagnosticSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientID;
    attribute def TestID;
    attribute def Timestamp;
    
    enum def DiagnosisStatus {
        negative;
        positive;
        inconclusive;
    }
    
    enum def DeviceState {
        idle;
        ready;
        scanning;
        analyzing;
        complete;
        error;
    }
    
    enum def MalariaParasiteType {
        plasmodiumFalciparum;
        plasmodiumVivax;
        plasmodiumMalariae;
        plasmodiumOvale;
        none;
    }
    
    item def BloodSample;
    item def OpticalSignature;
    item def MagneticSignature;
    item def DiagnosticReport;
    
    attribute def Wavelength :> ISQ::LengthValue;
    
    attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
    
    attribute def TestDuration :> ISQ::DurationValue;
    
    port def OpticalSensingPort {
        out wavelength: Wavelength;
        out intensity: Real;
        in reflectedSignal: OpticalSignature;
    }
    
    port def MagneticSensingPort {
        out fieldStrength: MagneticFieldStrength;
        in magneticResponse: MagneticSignature;
    }
    
    port def DataProcessingPort {
        in opticalData: OpticalSignature;
        in magneticData: MagneticSignature;
        out diagnosisResult: DiagnosisStatus;
        out parasiteType: MalariaParasiteType;
    }
    
    port def UserInterfacePort {
        in startCommand;
        in cancelCommand;
        out deviceStatus: DeviceState;
        out testResult: DiagnosticReport;
    }
    
    port def PowerPort {
        in voltage: ISQ::VoltageValue;
        in current: ISQ::ElectricCurrentValue;
    }
    
    part def LEDEmitter {
        port powerIn: PowerPort;
        port opticalOut: OpticalSensingPort;
        
        attribute emissionWavelength: Wavelength;
        attribute powerConsumption: ISQ::PowerValue;
        
        perform action emitLight {
            in driveVoltage: ISQ::VoltageValue;
            out lightOutput: Wavelength;
        }
    }
    
    part def MagnetometerSensor {
        port powerIn: PowerPort;
        port magneticIn: ~MagneticSensingPort;
        
        attribute sensitivity: MagneticFieldStrength;
        attribute samplingRate: Real;
        
        perform action detectMagneticField {
            in fieldStrength: MagneticFieldStrength;
            out magneticSignature: MagneticSignature;
        }
    }
    
    part def PhotodetectorArray {
        port powerIn: PowerPort;
        port opticalIn: ~OpticalSensingPort;
        
        attribute pixelCount: Integer;
        attribute responseTime: TestDuration;
        
        perform action captureOpticalSignal {
            in reflectedLight: OpticalSignature;
            out signalData: OpticalSignature;
        }
    }
    
    part def SignalProcessor {
        port powerIn: PowerPort;
        port dataIn: ~DataProcessingPort;
        port dataOut: DataProcessingPort;
        
        attribute processingSpeed: Real;
        attribute algorithmVersion: String;
        
        perform action analyzeSignals {
            in opticalData: OpticalSignature;
            in magneticData: MagneticSignature;
            out diagnosis: DiagnosisStatus;
            out parasiteIdentification: MalariaParasiteType;
        }
    }
    
    part def DisplayModule {
        port powerIn: PowerPort;
        port uiPort: ~UserInterfacePort;
        
        attribute screenSize: ISQ::LengthValue;
        attribute resolution: Integer;
        
        perform action showResults {
            in report: DiagnosticReport;
            in status: DeviceState;
        }
    }
    
    part def BatteryPack {
        port powerOut: ~PowerPort;
        
        attribute capacity: ISQ::EnergyValue;
        attribute chargeLevel: Real;
        attribute outputVoltage: ISQ::VoltageValue;
        
        perform action supplyPower {
            out voltage: ISQ::VoltageValue;
            out current: ISQ::ElectricCurrentValue;
        }
    }
    
    part def SensingProbe {
        port powerIn: PowerPort;
        port opticalPort: OpticalSensingPort;
        port magneticPort: MagneticSensingPort;
        
        part ledEmitter: LEDEmitter;
        part photodetector: PhotodetectorArray;
        part magnetometer: MagnetometerSensor;
        
        connection powerToLED connect powerIn to ledEmitter.powerIn;
        connection powerToPhoto connect powerIn to photodetector.powerIn;
        connection powerToMag connect powerIn to magnetometer.powerIn;
        
        connection opticalLink connect ledEmitter.opticalOut to photodetector.opticalIn;
        connection magneticLink connect magneticPort to magnetometer.magneticIn;
    }
    
    action def InitializeSystem {
        doc /* Powers on all subsystems and performs self-diagnostics. */
        out systemReady: Boolean;
    }
    
    action def GuideProbePosition {
        doc /* Guides user to place finger on sensing probe. */
        in userInput;
        out probePositioned: Boolean;
    }
    
    action def PerformOpticalScan {
        doc /* Activates LED and captures reflected light patterns from blood cells. */
        in wavelength: Wavelength;
        out opticalSignature: OpticalSignature;
    }
    
    action def PerformMagneticScan {
        doc /* Measures magnetic properties of hemozoin crystals in parasites. */
        in fieldStrength: MagneticFieldStrength;
        out magneticSignature: MagneticSignature;
    }
    
    action def AnalyzeBiomarkers {
        doc /* Processes optical and magnetic signatures to detect malaria parasites. */
        in opticalData: OpticalSignature;
        in magneticData: MagneticSignature;
        out diagnosis: DiagnosisStatus;
        out parasiteType: MalariaParasiteType;
        out confidence: Real;
    }
    
    action def GenerateReport {
        doc /* Creates diagnostic report with test results and metadata. */
        in diagnosis: DiagnosisStatus;
        in parasiteType: MalariaParasiteType;
        in testID: TestID;
        in patientID: PatientID;
        out report: DiagnosticReport;
    }
    
    action def PresentResults {
        doc /* Displays diagnosis on screen and stores in device memory. */
        in report: DiagnosticReport;
    }
    
    action def PerformMalariaDiagnosis {
        doc /* Complete non-invasive malaria screening workflow. */
        in patientID: PatientID;
        out finalReport: DiagnosticReport;
        
        first start;
        then initialize: InitializeSystem;
        then position: GuideProbePosition;
        then merge scanningPhase;
        
        action opticalScan: PerformOpticalScan {
            in wavelength;
            out opticalSignature;
        }
        
        action magneticScan: PerformMagneticScan {
            in fieldStrength;
            out magneticSignature;
        }
        
        then scanningPhase;
        
        action analyze: AnalyzeBiomarkers {
            in opticalData = opticalScan.opticalSignature;
            in magneticData = magneticScan.magneticSignature;
            out diagnosis;
            out parasiteType;
            out confidence;
        }
        
        then analyze;
        
        action createReport: GenerateReport {
            in diagnosis = analyze.diagnosis;
            in parasiteType = analyze.parasiteType;
            in testID;
            in patientID = PerformMalariaDiagnosis::patientID;
            out report;
        }
        
        then createReport;
        flow createReport.report to finalReport;
        
        action present: PresentResults {
            in report = createReport.report;
        }
        
        then present;
        then done;
    }
    
    state def MatibabuOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign currentState = DeviceState::idle;
        }
        
        transition idleToReady
            first idle
            accept powerOn
            then ready;
        
        state ready {
            entry assign currentState = DeviceState::ready;
        }
        
        transition readyToScanning
            first ready
            accept startTest
            then scanning;
        
        state scanning {
            entry assign currentState = DeviceState::scanning;
            do action performScans: PerformMalariaDiagnosis;
        }
        
        transition scanningToAnalyzing
            first scanning
            if performScans.opticalScan.opticalSignature != null and
               performScans.magneticScan.magneticSignature != null
            then analyzing;
        
        state analyzing {
            entry assign currentState = DeviceState::analyzing;
            do action runAnalysis: AnalyzeBiomarkers;
        }
        
        transition analyzingToComplete
            first analyzing
            if runAnalysis.diagnosis != null
            then complete;
        
        transition analyzingToError
            first analyzing
            if runAnalysis.confidence < 0.7
            then error;
        
        state complete {
            entry assign currentState = DeviceState::complete;
        }
        
        transition completeToReady
            first complete
            accept acknowledgeResult
            then ready;
        
        state error {
            entry assign currentState = DeviceState::error;
        }
        
        transition errorToReady
            first error
            accept resetDevice
            then ready;
        
        transition readyToIdle
            first ready
            accept powerOff
            then idle;
    }
    
    part def MatibabuDevice {
        doc /* 
            Matibabu is a portable, non-invasive medical diagnostic device 
            designed for rapid malaria screening in resource-limited settings. 
            The system detects malaria parasites by analyzing optical and 
            magnetic properties of blood without requiring blood draws, using 
            a finger-based sensing probe that measures hemozoin biomarkers 
            characteristic of Plasmodium parasites.
        */
        
        attribute deviceID: String;
        attribute firmwareVersion: String;
        attribute batteryLevel: Real;
        attribute testsPerformed: Integer;
        attribute currentState: DeviceState;
        
        part sensingProbe: SensingProbe {
            perform diagnosisWorkflow.opticalScan;
            perform diagnosisWorkflow.magneticScan;
        }
        
        part processor: SignalProcessor {
            perform diagnosisWorkflow.analyze;
        }
        
        part display: DisplayModule {
            perform diagnosisWorkflow.present;
        }
        
        part battery: BatteryPack;
        
        connection probePower connect battery.powerOut to sensingProbe.powerIn;
        connection processorPower connect battery.powerOut to processor.powerIn;
        connection displayPower connect battery.powerOut to display.powerIn;
        
        connection opticalDataFlow connect sensingProbe.opticalPort to processor.dataIn;
        connection magneticDataFlow connect sensingProbe.magneticPort to processor.dataIn;
        connection resultsFlow connect processor.dataOut to display.uiPort;
        
        perform action diagnosisWorkflow[*] ordered references PerformMalariaDiagnosis;
        
        exhibit state operationalBehavior: MatibabuOperationalStates;
    }
    
    requirement def <'REQ-001'> NonInvasiveDetectionRequirement {
        doc /* 
            The Matibabu system shall detect malaria parasites without 
            requiring blood sample extraction, using non-invasive optical 
            and magnetic sensing techniques applied to the patient's finger.
        */
        
        subject device: MatibabuDevice;
        
        require constraint {
            device.sensingProbe != null and
            device.sensingProbe.ledEmitter != null and
            device.sensingProbe.magnetometer != null
        }
    }
    
    requirement def <'REQ-002'> RapidDiagnosisRequirement {
        doc /* 
            The system shall complete a malaria screening test and provide 
            results within 2 minutes from test initiation.
        */
        
        subject workflow: PerformMalariaDiagnosis;
        
        attribute maxDuration: TestDuration;
        
        require constraint {
            maxDuration == 2.0[min]
        }
    }
    
    requirement def <'REQ-003'> PortabilityRequirement {
        doc /* 
            The device shall be portable and battery-powered for use in 
            remote locations without reliable electrical infrastructure.
        */
        
        subject device: MatibabuDevice;
        
        attribute maxMass: ISQ::MassValue;
        attribute minBatteryLife: TestDuration;
        
        require constraint {
            device.battery != null and
            device.battery.capacity >= 50.0[J] and
            maxMass <= 1.0[kg]
        }
    }
    
    requirement def <'REQ-004'> DiagnosticAccuracyRequirement {
        doc /* 
            The system shall achieve minimum 80% sensitivity and 80% 
            specificity in detecting Plasmodium falciparum malaria.
        */
        
        subject analysis: AnalyzeBiomarkers;
        
        attribute minSensitivity: Real;
        attribute minSpecificity: Real;
        
        require constraint {
            minSensitivity >= 0.80 and
            minSpecificity >= 0.80
        }
    }
    
    requirement def <'REQ-005'> MultiParasiteDetectionRequirement {
        doc /* 
            The system shall be capable of identifying different species 
            of malaria parasites including P. falciparum, P. vivax, 
            P. malariae, and P. ovale.
        */
        
        subject analysis: AnalyzeBiomarkers;
        
        require constraint {
            analysis.parasiteType != null
        }
    }
    
    requirement primaryMissionRequirement {
        doc /* 
            The Matibabu system shall provide rapid, non-invasive, portable 
            malaria screening capability for point-of-care diagnosis in 
            resource-limited healthcare settings, enabling early detection 
            and treatment of malaria without requiring blood draws or 
            laboratory infrastructure.
        */
        
        require NonInvasiveDetectionRequirement;
        require RapidDiagnosisRequirement;
        require PortabilityRequirement;
        require DiagnosticAccuracyRequirement;
        require MultiParasiteDetectionRequirement;
    }
    
    part matibabuSystem: MatibabuDevice {
        satisfy primaryMissionRequirement;
        satisfy NonInvasiveDetectionRequirement;
        satisfy RapidDiagnosisRequirement;
        satisfy PortabilityRequirement;
        satisfy DiagnosticAccuracyRequirement;
        satisfy MultiParasiteDetectionRequirement;
    }
}
