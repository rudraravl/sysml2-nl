package MammotomeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VacuumPressure :> PressureValue;
    attribute def RotationSpeed :> AngularVelocityValue;
    attribute def SampleVolume :> VolumeValue;
    attribute def InsertionDepth :> LengthValue;
    
    enum def SystemMode {
        standby;
        imaging;
        positioning;
        sampling;
        retrieving;
        fault;
    }
    
    enum def VacuumState {
        off;
        priming;
        active;
        releasing;
    }
    
    item def TissueSample {
        attribute volume : SampleVolume;
        attribute quality : Real;
        attribute timestamp : Real;
    }
    
    port def VacuumPort {
        attribute pressure : VacuumPressure;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def ControlPort {
        attribute commandSignal : Boolean;
        attribute statusSignal : Boolean;
    }
    
    port def SamplePort {
        attribute samples : TissueSample[0..*];
    }
    
    part def ImagingSubsystem {
        attribute isActive : Boolean;
        attribute targetDepth : InsertionDepth;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        action def AcquireImage {
            out targetLocation : InsertionDepth;
            out targetIdentified : Boolean;
        }
    }
    
    part def VacuumSubsystem {
        attribute currentPressure : VacuumPressure;
        attribute targetPressure : VacuumPressure;
        attribute vacState : VacuumState;
        port vacuumOut : VacuumPort;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        action def ActivateVacuum {
            in target : VacuumPressure;
            out achieved : VacuumPressure;
        }
        
        action def ReleaseVacuum {
            out released : Boolean;
        }
    }
    
    part def CutterSubsystem {
        attribute rotationSpeed : RotationSpeed;
        attribute cutterAngle : Real;
        attribute isRotating : Boolean;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        action def RotateCutter {
            in speed : RotationSpeed;
            in angle : Real;
            out ready : Boolean;
        }
        
        action def StopCutter {
            out stopped : Boolean;
        }
    }
    
    part def ProbeAssembly {
        attribute insertionDepth : InsertionDepth;
        attribute apertureAngle : Real;
        attribute samplesCollected : Integer;
        port vacuumIn : VacuumPort;
        port sampleOut : SamplePort;
        port controlIn : ControlPort;
        
        action def PositionProbe {
            in targetDepth : InsertionDepth;
            in targetAngle : Real;
            out positioned : Boolean;
        }
        
        action def AcquireTissue {
            in vacuumPressure : VacuumPressure;
            in cutterSpeed : RotationSpeed;
            out sample : TissueSample;
        }
    }
    
    part def SampleCollector {
        attribute capacity : SampleVolume;
        attribute currentLoad : SampleVolume;
        attribute sampleCount : Integer;
        port sampleIn : SamplePort;
        
        action def StoreSample {
            in sample : TissueSample;
            out stored : Boolean;
        }
    }
    
    part def ControlConsole {
        attribute currentMode : SystemMode;
        attribute targetSampleCount : Integer;
        attribute actualSampleCount : Integer;
        port imagingControl : ControlPort;
        port vacuumControl : ControlPort;
        port cutterControl : ControlPort;
        port probeControl : ControlPort;
        port userInterface : ControlPort;
    }
    
    action def InitializeSystem {
        out initialized : Boolean;
    }
    
    action def PerformImaging {
        in imagingActive : Boolean;
        out targetLocation : InsertionDepth;
        out targetConfirmed : Boolean;
    }
    
    action def InsertProbe {
        in targetDepth : InsertionDepth;
        out inserted : Boolean;
    }
    
    action def EstablishVacuum {
        in targetPressure : VacuumPressure;
        out vacuumReady : Boolean;
    }
    
    action def ActivateCutter {
        in speed : RotationSpeed;
        out cutterActive : Boolean;
    }
    
    action def CollectSample {
        in vacuumPressure : VacuumPressure;
        in cutterSpeed : RotationSpeed;
        out sample : TissueSample;
    }
    
    action def RotateAperture {
        in angle : Real;
        out rotated : Boolean;
    }
    
    action def TransferSample {
        in sample : TissueSample;
        out transferred : Boolean;
    }
    
    action def ShutdownSystems {
        out shutdown : Boolean;
    }
    
    action def PerformBiopsyProcedure {
        first start;
        
        then action initialize : InitializeSystem;
        
        then action imaging : PerformImaging {
            in imagingActive = true;
            out targetLocation : InsertionDepth;
            out targetConfirmed : Boolean;
        }
        
        then action insert : InsertProbe {
            in targetDepth = imaging.targetLocation;
            out inserted : Boolean;
        }
        
        then action establishVac : EstablishVacuum {
            in targetPressure = -65.0 [SI::kPa];
            out vacuumReady : Boolean;
        }
        
        then action activateCut : ActivateCutter {
            in speed = 120.0 ['1/min'];
            out cutterActive : Boolean;
        }
        
        then merge sampleCycle;
        
        then action collect : CollectSample {
            in vacuumPressure = establishVac.targetPressure;
            in cutterSpeed = activateCut.speed;
            out sample : TissueSample;
        }
        
        then action transfer : TransferSample {
            in sample = collect.sample;
            out transferred : Boolean;
        }
        
        then action rotate : RotateAperture {
            in angle = 30.0;
            out rotated : Boolean;
        }
        
        then decide;
            if sampleCounter < requiredSamples then sampleCycle;
            if sampleCounter >= requiredSamples then shutdown;
        
        action shutdown : ShutdownSystems;
        then done;
        
        attribute sampleCounter : Integer;
        attribute requiredSamples : Integer = 8;
    }
    
    state def BiopsyStateMachine {
        entry; then standby;
        
        state standby {
            entry assign mode = SystemMode::standby;
        }
        
        transition standby_to_imaging
            first standby
            accept StartCommand
            then imaging;
        
        state imaging {
            entry assign mode = SystemMode::imaging;
            entry do action performImaging : PerformImaging;
        }
        
        transition imaging_to_positioning
            first imaging
            if performImaging.targetConfirmed
            then positioning;
        
        state positioning {
            entry assign mode = SystemMode::positioning;
            entry do action insertProbe : InsertProbe;
        }
        
        transition positioning_to_sampling
            first positioning
            if insertProbe.inserted
            then sampling;
        
        state sampling {
            entry assign mode = SystemMode::sampling;
            entry do action collectSample : CollectSample;
        }
        
        transition sampling_to_retrieving
            first sampling
            if collectSample.sample.quality > 0.8
            then retrieving;
        
        transition sampling_to_fault
            first sampling
            if collectSample.sample.quality <= 0.8
            then fault;
        
        state retrieving {
            entry assign mode = SystemMode::retrieving;
            entry do action transferSample : TransferSample;
        }
        
        transition retrieving_to_sampling
            first retrieving
            if transferSample.transferred and needMoreSamples
            then sampling;
        
        transition retrieving_to_standby
            first retrieving
            if transferSample.transferred and not needMoreSamples
            then standby;
        
        state fault {
            entry assign mode = SystemMode::fault;
        }
        
        transition fault_to_standby
            first fault
            accept ResetCommand
            then standby;
        
        attribute mode : SystemMode;
        attribute needMoreSamples : Boolean;
    }
    
    part def Mammotome {
        attribute operatingMode : SystemMode;
        attribute totalSamplesCollected : Integer;
        attribute targetSampleCount : Integer;
        attribute maxInsertionDepth : InsertionDepth;
        
        part imaging : ImagingSubsystem {
            attribute :>> isActive;
            attribute :>> targetDepth;
        }
        
        part vacuum : VacuumSubsystem {
            attribute :>> currentPressure;
            attribute :>> targetPressure;
            attribute :>> vacState;
        }
        
        part cutter : CutterSubsystem {
            attribute :>> rotationSpeed;
            attribute :>> cutterAngle;
            attribute :>> isRotating;
        }
        
        part probe : ProbeAssembly {
            attribute :>> insertionDepth;
            attribute :>> apertureAngle;
            attribute :>> samplesCollected;
        }
        
        part collector : SampleCollector {
            attribute :>> capacity;
            attribute :>> currentLoad;
            attribute :>> sampleCount;
        }
        
        part console : ControlConsole {
            attribute :>> currentMode;
            attribute :>> targetSampleCount;
            attribute :>> actualSampleCount;
        }
        
        connection imagingCtrl connect console.imagingControl to imaging.controlIn;
        connection vacuumCtrl connect console.vacuumControl to vacuum.controlIn;
        connection cutterCtrl connect console.cutterControl to cutter.controlIn;
        connection probeCtrl connect console.probeControl to probe.controlIn;
        connection vacuumLine connect vacuum.vacuumOut to probe.vacuumIn;
        connection sampleTransfer connect probe.sampleOut to collector.sampleIn;
        
        perform action biopsyProcedure : PerformBiopsyProcedure;
        exhibit state biopsyState : BiopsyStateMachine;
    }
    
    requirement <'REQ-1000'> primaryFunction {
        doc /* The Mammotome system shall perform minimally invasive 
             * vacuum-assisted breast biopsy by acquiring multiple tissue 
             * samples through a single insertion point using image guidance.
             */
        subject device : Mammotome;
    }
    
    requirement <'REQ-1001'> imageGuidance {
        doc /* The system shall provide real-time imaging to accurately 
             * identify and target suspicious tissue regions.
             */
        subject imaging :>> Mammotome::imaging;
        assert constraint {
            imaging.isActive == true
        }
    }
    
    requirement <'REQ-1002'> vacuumAssistance {
        doc /* The system shall maintain vacuum pressure between 
             * -70 kPa and -60 kPa during tissue acquisition.
             */
        subject vacuum :>> Mammotome::vacuum;
        assert constraint {
            vacuum.currentPressure >= -70.0 [SI::kPa] and
            vacuum.currentPressure <= -60.0 [SI::kPa]
        }
    }
    
    requirement <'REQ-1003'> cutterOperation {
        doc /* The rotating cutter shall operate at controlled speed 
             * between 100 and 140 rpm to precisely excise tissue.
             */
        subject cutter :>> Mammotome::cutter;
        assert constraint {
            cutter.rotationSpeed >= 100.0 ['1/min'] and
            cutter.rotationSpeed <= 140.0 ['1/min']
        }
    }
    
    requirement <'REQ-1004'> multipleSampling {
        doc /* The system shall acquire between 6 and 12 tissue samples 
             * without requiring probe removal or reinsertion.
             */
        subject device : Mammotome;
        assert constraint {
            device.totalSamplesCollected >= 6 and
            device.totalSamplesCollected <= 12
        }
    }
    
    requirement <'REQ-1005'> sampleRetention {
        doc /* The sample collector shall retain all acquired tissue 
             * samples without loss for pathological examination.
             */
        subject collector :>> Mammotome::collector;
        assert constraint {
            collector.currentLoad <= collector.capacity
        }
    }
    
    requirement <'REQ-1006'> insertionDepthLimit {
        doc /* The probe insertion depth shall not exceed 50 mm 
             * to ensure patient safety.
             */
        subject probe :>> Mammotome::probe;
        assert constraint {
            probe.insertionDepth <= 50.0 [SI::mm]
        }
    }
    
    part mammotomeDevice : Mammotome {
        attribute :>> operatingMode = SystemMode::standby;
        attribute :>> totalSamplesCollected = 0;
        attribute :>> targetSampleCount = 8;
        attribute :>> maxInsertionDepth = 50.0 [SI::mm];
        
        part :>> imaging {
            attribute :>> isActive = false;
            attribute :>> targetDepth = 0.0 [SI::mm];
        }
        
        part :>> vacuum {
            attribute :>> currentPressure = 0.0 [SI::kPa];
            attribute :>> targetPressure = -65.0 [SI::kPa];
            attribute :>> vacState = VacuumState::off;
        }
        
        part :>> cutter {
            attribute :>> rotationSpeed = 0.0 ['1/min'];
            attribute :>> cutterAngle = 0.0;
            attribute :>> isRotating = false;
        }
        
        part :>> probe {
            attribute :>> insertionDepth = 0.0 [SI::mm];
            attribute :>> apertureAngle = 0.0;
            attribute :>> samplesCollected = 0;
        }
        
        part :>> collector {
            attribute :>> capacity = 100.0 [SI::mm^3];
            attribute :>> currentLoad = 0.0 [SI::mm^3];
            attribute :>> sampleCount = 0;
        }
        
        part :>> console {
            attribute :>> currentMode = SystemMode::standby;
            attribute :>> targetSampleCount = 8;
            attribute :>> actualSampleCount = 0;
        }
    }
    
    satisfy primaryFunction by mammotomeDevice;
    satisfy imageGuidance by mammotomeDevice.imaging;
    satisfy vacuumAssistance by mammotomeDevice.vacuum;
    satisfy cutterOperation by mammotomeDevice.cutter;
    satisfy multipleSampling by mammotomeDevice;
    satisfy sampleRetention by mammotomeDevice.collector;
    satisfy insertionDepthLimit by mammotomeDevice.probe;
}
