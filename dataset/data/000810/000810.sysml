package 'Ultrasound Computer Tomography System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def UltrasoundFrequency :> FrequencyValue;
    attribute def AcousticPressure :> PressureValue;
    attribute def ImageResolution :> LengthValue;
    attribute def ScanAngle :> PlaneAngleValue;
    attribute def SignalAmplitude :> Real;
    
    attribute def ScanParameters {
        attribute transmitFrequency : UltrasoundFrequency;
        attribute transmitPower : PowerValue;
        attribute numberOfProjections : Integer;
        attribute angularIncrement : ScanAngle;
        attribute samplingRate : FrequencyValue;
    }
    
    item def RawEchoData {
        attribute timestamp : TimeValue;
        attribute amplitude : SignalAmplitude;
        attribute projectionAngle : ScanAngle;
    }
    
    item def ProjectionDataSet {
        attribute projections : RawEchoData[*];
        attribute acquisitionComplete : Boolean;
    }
    
    item def TomographicImage {
        attribute imageMatrix : Real[512][512];
        attribute spatialResolution : ImageResolution;
        attribute contrastRatio : Real;
    }
    
    item def ScanCommand;
    item def SystemStatus;
    
    port def AcousticPort {
        out transmitWave : AcousticPressure;
        in receiveEcho : AcousticPressure;
    }
    
    port def DataFlowPort {
        out rawData : RawEchoData;
    }
    
    port def ImagePort {
        out image : TomographicImage;
    }
    
    port def ControlPort {
        in command : ScanCommand;
        out status : SystemStatus;
    }
    
    part def TransducerRing {
        attribute elementCount : Integer;
        attribute ringDiameter : LengthValue;
        attribute operatingFrequency : UltrasoundFrequency;
        
        port acousticInterface : AcousticPort[*];
        port dataOutput : DataFlowPort;
    }
    
    part def RotationalGantry {
        attribute currentAngle : ScanAngle;
        attribute rotationSpeed : AngularVelocityValue;
        attribute positionAccuracy : PlaneAngleValue;
        
        port mechanicalControl;
    }
    
    part def SignalProcessingUnit {
        attribute filterBandwidth : FrequencyValue;
        attribute dynamicRange : Real;
        attribute processingLatency : TimeValue;
        
        port dataInput : DataFlowPort;
        port dataOutput : DataFlowPort;
    }
    
    part def ReconstructionProcessor {
        attribute algorithmType : String;
        attribute matrixSize : Integer;
        attribute reconstructionTime : TimeValue;
        
        port projectionInput : DataFlowPort;
        port imageOutput : ImagePort;
    }
    
    part def AcquisitionController {
        attribute scanProtocol : ScanParameters;
        attribute systemState : String;
        
        port controlInterface : ControlPort;
        port gantryControl;
        port transducerControl;
    }
    
    part def ImagingWorkstation {
        attribute displayResolution : ImageResolution;
        attribute storageCapacity : Real;
        
        port imageDisplay : ImagePort;
        port userInterface : ControlPort;
    }
    
    part def CouplingMediumTank {
        attribute fluidType : String;
        attribute temperature : TemperatureValue;
        attribute acousticImpedance : Real;
    }
    
    part def PatientPositioningTable {
        attribute tableHeight : LengthValue;
        attribute maxLoad : MassValue;
        
        port positionControl;
    }
    
    action def TransmitUltrasoundPulse {
        in frequency : UltrasoundFrequency;
        in power : PowerValue;
        in angle : ScanAngle;
        out acousticWave : AcousticPressure;
    }
    
    action def ReceiveEchoSignal {
        in acousticWave : AcousticPressure;
        in samplingWindow : TimeValue;
        out echoData : RawEchoData;
    }
    
    action def FilterAndAmplify {
        in rawSignal : RawEchoData;
        in filterParams : Real;
        out processedSignal : RawEchoData;
    }
    
    action def RotateGantryToAngle {
        in targetAngle : ScanAngle;
        out achievedAngle : ScanAngle;
    }
    
    action def ReconstructTomographicSlice {
        in projectionSet : ProjectionDataSet;
        in reconstructionAlgorithm : String;
        out tomographicSlice : TomographicImage;
    }
    
    action def DisplayReconstructedImage {
        in image : TomographicImage;
        in displaySettings : Real;
    }
    
    action def PerformUCTScan {
        in scanParams : ScanParameters;
        out finalImage : TomographicImage;
        
        first start;
        
        then merge acquireNextProjection;
        
        private attribute currentProjectionAngle : ScanAngle := 0.0;
        private attribute projectionCounter : Integer := 0;
        private attribute collectedProjections : RawEchoData[*] := ();
        
        then action rotateGantry : RotateGantryToAngle {
            in targetAngle = currentProjectionAngle;
            out achievedAngle;
        }
        
        then action transmitPulse : TransmitUltrasoundPulse {
            in frequency = scanParams.transmitFrequency;
            in power = scanParams.transmitPower;
            in angle = rotateGantry.achievedAngle;
            out acousticWave;
        }
        
        then action receiveEcho : ReceiveEchoSignal {
            in acousticWave = transmitPulse.acousticWave;
            in samplingWindow = 0.001;
            out echoData;
        }
        
        then action processSignal : FilterAndAmplify {
            in rawSignal = receiveEcho.echoData;
            in filterParams = 1.0;
            out processedSignal;
        }
        
        then assign collectedProjections := collectedProjections->including(processSignal.processedSignal);
        then assign projectionCounter := projectionCounter + 1;
        then assign currentProjectionAngle := currentProjectionAngle + scanParams.angularIncrement;
        
        then decide;
            if projectionCounter < scanParams.numberOfProjections then acquireNextProjection;
            if projectionCounter >= scanParams.numberOfProjections then reconstructImage;
        
        action reconstructImage : ReconstructTomographicSlice {
            in projectionSet : ProjectionDataSet {
                attribute :>> projections = collectedProjections;
                attribute :>> acquisitionComplete = true;
            }
            in reconstructionAlgorithm = "FilteredBackProjection";
            out tomographicSlice;
        }
        
        then action displayImage : DisplayReconstructedImage {
            in image = reconstructImage.tomographicSlice;
            in displaySettings = 1.0;
        }
        
        then assign finalImage := reconstructImage.tomographicSlice;
        then done;
    }
    
    state def UCTSystemStateMachine {
        entry; then idle;
        
        state idle;
        accept ScanCommand;
        then initializing;
        
        state initializing;
        then ready;
        
        state ready;
        accept ScanCommand;
        then scanning;
        
        state scanning;
        then reconstructing;
        
        state reconstructing;
        then displayingResults;
        
        state displayingResults;
        then ready;
    }
    
    part def UCTSystem {
        attribute operatingFrequency : UltrasoundFrequency;
        attribute maxAcousticPower : PowerValue;
        attribute targetResolution : ImageResolution;
    }
    
    part uctSystem : UCTSystem {
        doc /* 
            Ultrasound Computer Tomography System for non-invasive 
            volumetric imaging of soft tissue structures.
        */
        
        attribute :>> operatingFrequency : UltrasoundFrequency = 2.5;
        attribute :>> maxAcousticPower : PowerValue = 100.0;
        attribute :>> targetResolution : ImageResolution = 0.5;
        
        perform action scanSequence[*] ordered references PerformUCTScan;
        
        part transducerArray : TransducerRing {
            attribute :>> elementCount = 256;
            attribute :>> ringDiameter = 300.0;
            attribute :>> operatingFrequency = uctSystem.operatingFrequency;
            
            perform scanSequence.transmitPulse;
            perform scanSequence.receiveEcho;
        }
        
        part gantry : RotationalGantry {
            attribute :>> rotationSpeed = 30.0;
            attribute :>> positionAccuracy = 0.1;
            
            perform scanSequence.rotateGantry;
        }
        
        part signalProcessor : SignalProcessingUnit {
            attribute :>> filterBandwidth = 5.0;
            attribute :>> dynamicRange = 80.0;
            attribute :>> processingLatency = 0.001;
            
            perform scanSequence.processSignal;
        }
        
        part reconstructor : ReconstructionProcessor {
            attribute :>> algorithmType = "FilteredBackProjection";
            attribute :>> matrixSize = 512;
            attribute :>> reconstructionTime = 2.0;
            
            perform scanSequence.reconstructImage;
        }
        
        part controller : AcquisitionController {
            attribute :>> systemState = "Ready";
        }
        
        part workstation : ImagingWorkstation {
            attribute :>> displayResolution = 0.1;
            attribute :>> storageCapacity = 1000.0;
            
            perform scanSequence.displayImage;
        }
        
        part couplingTank : CouplingMediumTank {
            attribute :>> fluidType = "DegassedWater";
            attribute :>> temperature = 310.0;
            attribute :>> acousticImpedance = 1.5;
        }
        
        part patientTable : PatientPositioningTable {
            attribute :>> tableHeight = 800.0;
            attribute :>> maxLoad = 200.0;
        }
        
        connect transducerArray.dataOutput to signalProcessor.dataInput;
        connect signalProcessor.dataOutput to reconstructor.projectionInput;
        connect reconstructor.imageOutput to workstation.imageDisplay;
        connect controller.controlInterface to workstation.userInterface;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The system shall acquire ultrasound projection data from multiple 
            angles around the subject and reconstruct cross-sectional tomographic 
            images of internal tissue structures.
        */
    }
    
    requirement def ImageQualityRequirement {
        doc /* 
            The system shall produce tomographic images with specified 
            spatial resolution and contrast characteristics.
        */
        
        attribute requiredResolution : ImageResolution;
        attribute minimumContrast : Real;
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The system shall operate within safe acoustic power limits 
            for patient exposure during scanning procedures.
        */
        
        attribute maxPowerLimit : PowerValue;
        attribute maxExposureDuration : TimeValue;
    }
    
    requirement def ScanPerformanceRequirement {
        doc /* 
            The system shall complete a full tomographic scan acquisition 
            within specified time constraints.
        */
        
        attribute maxScanTime : TimeValue;
        attribute minProjectionCount : Integer;
    }
    
    requirement <'UCT-FUNC-001'> primaryFunction : PrimaryFunctionRequirement {
        doc /* 
            The UCT system shall transmit ultrasound waves through tissue, 
            collect echo data from 360 degrees around the subject, and 
            reconstruct volumetric images using tomographic algorithms.
        */
        
        subject uctSystem;
        satisfy by uctSystem.scanSequence;
    }
    
    requirement <'UCT-PERF-001'> imageQuality : ImageQualityRequirement {
        doc /* 
            Reconstructed images shall achieve spatial resolution of 0.5mm 
            or better with minimum contrast ratio of 10:1.
        */
        
        attribute :>> requiredResolution = 0.5;
        attribute :>> minimumContrast = 10.0;
        
        subject uctSystem;
    }
    
    requirement <'UCT-SAFE-001'> patientSafety : SafetyRequirement {
        doc /* 
            Acoustic power shall not exceed 100W and total exposure 
            duration shall be limited to 300 seconds per scan.
        */
        
        attribute :>> maxPowerLimit = 100.0;
        attribute :>> maxExposureDuration = 300.0;
        
        subject uctSystem;
    }
    
    requirement <'UCT-PERF-002'> scanEfficiency : ScanPerformanceRequirement {
        doc /* 
            Complete tomographic scan with minimum 180 projections 
            shall be acquired in less than 5 minutes.
        */
        
        attribute :>> maxScanTime = 300.0;
        attribute :>> minProjectionCount = 180;
        
        subject uctSystem;
    }
}
