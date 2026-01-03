package 'Functional Magnetic Resonance Imaging System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
     * This model describes a Functional Magnetic Resonance Imaging (fMRI) system
     * designed to non-invasively measure and map brain activity by detecting
     * changes in blood oxygenation levels (BOLD signal). The system operates by
     * generating a strong static magnetic field, applying precisely controlled
     * gradient fields for spatial encoding, transmitting radiofrequency pulses
     * to excite hydrogen nuclei, and detecting the resulting magnetic resonance
     * signals. These signals are processed to reconstruct functional images that
     * reveal which brain regions are active during specific tasks or at rest.
     */
    
    attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
    attribute def GradientStrength :> ISQ::MagneticFluxDensityValue;
    attribute def RFFrequency :> ISQ::FrequencyValue;
    attribute def RFPower :> ISQ::PowerValue;
    
    attribute def BOLDSignal {
        attribute oxygenatedHemoglobin : Real;
        attribute deoxygenatedHemoglobin : Real;
        attribute signalIntensity : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    attribute def VoxelResolution {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }
    
    attribute def ScanProtocol {
        attribute repetitionTime : ISQ::TimeValue;
        attribute echoTime : ISQ::TimeValue;
        attribute flipAngle : Real;
        attribute numberOfSlices : Integer;
        attribute matrixSize : Integer;
    }
    
    item def RFPulseSequence {
        attribute frequency : RFFrequency;
        attribute amplitude : Real;
        attribute duration : ISQ::TimeValue;
        attribute phaseOffset : Real;
    }
    
    item def GradientWaveform {
        attribute xGradient : GradientStrength;
        attribute yGradient : GradientStrength;
        attribute zGradient : GradientStrength;
        attribute duration : ISQ::TimeValue;
    }
    
    item def MRSignal {
        attribute realComponent : Real;
        attribute imaginaryComponent : Real;
        attribute frequency : RFFrequency;
        attribute acquisitionTime : ISQ::TimeValue;
    }
    
    item def KSpaceData {
        attribute phaseEncodingSteps : Integer;
        attribute frequencyEncodingPoints : Integer;
    }
    
    item def AnatomicalImage {
        attribute voxelResolution : VoxelResolution;
        attribute contrastToNoiseRatio : Real;
    }
    
    item def FunctionalImage {
        attribute boldContrast : BOLDSignal;
    }
    
    port def MagnetPort {
        out staticField : MagneticFieldStrength;
    }
    
    port def GradientPort {
        in gradientCommand : GradientWaveform;
        out appliedGradient : GradientWaveform;
    }
    
    port def RFTransmitPort {
        in pulseSequence : RFPulseSequence;
        out transmittedPulse : RFPulseSequence;
    }
    
    port def RFReceivePort {
        in mrSignal : MRSignal;
        out amplifiedSignal : MRSignal;
    }
    
    port def DataAcquisitionPort {
        in rawSignal : MRSignal;
        out kSpaceData : KSpaceData;
    }
    
    port def ReconstructionPort {
        in kSpaceData : KSpaceData;
        out anatomicalImage : AnatomicalImage;
    }
    
    port def AnalysisPort {
        in imageData : AnatomicalImage;
        out functionalImage : FunctionalImage;
    }
    
    port def PatientPort {
        in patientID : String;
        in scanProtocol : ScanProtocol;
        out scanStatus : String;
    }
    
    part def SuperconductingMagnet {
        attribute fieldStrength : MagneticFieldStrength;
        attribute homogeneity : Real;
        attribute bore_diameter : ISQ::LengthValue;
        port magnetOutput : MagnetPort;
    }
    
    part def GradientCoilSystem {
        attribute maxGradientStrength : GradientStrength;
        attribute slewRate : Real;
        attribute linearity : Real;
        port gradientControl : GradientPort;
    }
    
    part def RFTransmitCoil {
        attribute coilType : String;
        attribute numberOfChannels : Integer;
        attribute powerRating : RFPower;
        port transmitInterface : RFTransmitPort;
    }
    
    part def RFReceiveCoil {
        attribute coilType : String;
        attribute numberOfChannels : Integer;
        attribute sensitivity : Real;
        port receiveInterface : RFReceivePort;
    }
    
    part def RFAmplifier {
        attribute gain : Real;
        attribute bandwidth : RFFrequency;
        attribute maxPower : RFPower;
    }
    
    part def SignalDigitizer {
        attribute samplingRate : RFFrequency;
        attribute resolution : Integer;
        attribute numberOfChannels : Integer;
        port dataOutput : DataAcquisitionPort;
    }
    
    part def ImageReconstructor {
        attribute reconstructionAlgorithm : String;
        attribute parallelImagingFactor : Integer;
        port reconstructionInterface : ReconstructionPort;
    }
    
    part def FunctionalAnalysisEngine {
        attribute analysisMethod : String;
        attribute statisticalThreshold : Real;
        port analysisInterface : AnalysisPort;
    }
    
    part def PatientTable {
        attribute maxLoad : ISQ::MassValue;
        attribute positionAccuracy : ISQ::LengthValue;
        attribute travelRange : ISQ::LengthValue;
        port patientInterface : PatientPort;
    }
    
    part def ControlConsole {
        attribute processorSpeed : RFFrequency;
        attribute memoryCapacity : Real;
        attribute displayResolution : Integer;
    }
    
    part def ShimCoilSystem {
        attribute numberOfChannels : Integer;
        attribute maxCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def GenerateStaticField {
        in targetFieldStrength : MagneticFieldStrength;
        out stableField : MagneticFieldStrength;
    }
    
    action def ApplyShimming {
        out shimCurrents : ISQ::ElectricCurrentValue;
    }
    
    action def GenerateGradientWaveform {
        in slicePosition : Integer;
        in phaseEncodingStep : Integer;
        in frequencyEncodingDirection : Integer;
        out gradientWaveform : GradientWaveform;
    }
    
    action def TransmitRFPulse {
        in pulseSequence : RFPulseSequence;
        in targetFlipAngle : Real;
        out deliveredPulse : RFPulseSequence;
    }
    
    action def ReceiveMRSignal {
        in receiveDuration : ISQ::TimeValue;
        out rawSignal : MRSignal;
    }
    
    action def DigitizeSignal {
        in analogSignal : MRSignal;
        in samplingRate : RFFrequency;
        out digitalData : KSpaceData;
    }
    
    action def PerformFourierTransform {
        in kSpaceData : KSpaceData;
        out imageData : AnatomicalImage;
    }
    
    action def DetectBOLDSignal {
        in imageData : AnatomicalImage;
        out boldSignal : BOLDSignal;
    }
    
    action def PerformStatisticalAnalysis {
        in boldSignal : BOLDSignal;
        out statisticalValue : Real;
    }
    
    action def GenerateFunctionalMap {
        in statisticalValue : Real;
        in threshold : Real;
        out functionalImage : FunctionalImage;
    }
    
    action def AcquireSingleVolume {
        in protocol : ScanProtocol;
        in sliceNumber : Integer;
        out volumeData : KSpaceData;
        
        first start;
        then action generateGradient : GenerateGradientWaveform {
            in slicePosition = sliceNumber;
            in phaseEncodingStep = 1;
            in frequencyEncodingDirection = 1;
            out gradientWaveform;
        }
        then action transmitPulse : TransmitRFPulse {
            in pulseSequence;
            in targetFlipAngle = protocol.flipAngle;
            out deliveredPulse;
        }
        then action receiveSignal : ReceiveMRSignal {
            in receiveDuration = protocol.echoTime;
            out rawSignal;
        }
        then action digitize : DigitizeSignal {
            in analogSignal = receiveSignal.rawSignal;
            in samplingRate;
            out digitalData;
        }
        then assign volumeData := digitize.digitalData;
        then done;
    }
    
    action def PerformFunctionalScan {
        in scanProtocol : ScanProtocol;
        in numberOfVolumes : Integer;
        out functionalImage : FunctionalImage;
        
        private attribute currentVolume : Integer := 0;
        private attribute currentSlice : Integer := 0;
        private attribute volumeData : KSpaceData;
        private attribute imageData : AnatomicalImage;
        private attribute boldSignal : BOLDSignal;
        private attribute statisticalValue : Real;
        
        first start;
        then action prepareSystem {
            action generateField : GenerateStaticField {
                in targetFieldStrength;
                out stableField;
            }
            then action shimField : ApplyShimming {
                out shimCurrents;
            }
        }
        then merge acquisitionLoop;
        
        action acquisitionLoop {
            then decide;
                if currentVolume < numberOfVolumes then acquireData;
                if currentVolume >= numberOfVolumes then processFunctional;
            
            action acquireData {
                then decide;
                    if currentSlice < scanProtocol.numberOfSlices then acquireSlice;
                    if currentSlice >= scanProtocol.numberOfSlices then nextVolume;
                
                action acquireSlice {
                    action acquireVolume : AcquireSingleVolume {
                        in protocol = scanProtocol;
                        in sliceNumber = currentSlice;
                        out volumeData;
                    }
                    then assign currentSlice := currentSlice + 1;
                    then acquisitionLoop;
                }
                
                action nextVolume {
                    action reconstructVolume : PerformFourierTransform {
                        in kSpaceData = volumeData;
                        out imageData;
                    }
                    then assign currentVolume := currentVolume + 1;
                    then assign currentSlice := 0;
                    then acquisitionLoop;
                }
            }
        }
        
        action processFunctional {
            action detectBOLD : DetectBOLDSignal {
                in imageData;
                out boldSignal;
            }
            then action analyzeStatistics : PerformStatisticalAnalysis {
                in boldSignal = detectBOLD.boldSignal;
                out statisticalValue;
            }
            then action generateMap : GenerateFunctionalMap {
                in statisticalValue = analyzeStatistics.statisticalValue;
                in threshold = 0.05;
                out functionalImage;
            }
        }
        then done;
    }
    
    state machine def SystemOperationalStates {
        initial state PowerOff;
        state Standby;
        state Shimming;
        state Scanning;
        state Processing;
        state Complete;
        
        transition from PowerOff to Standby 
            accept powerOn;
        
        transition from Standby to Shimming 
            accept startScan;
        
        transition from Shimming to Scanning 
            accept shimmingComplete;
        
        transition from Scanning to Processing 
            accept acquisitionComplete;
        
        transition from Processing to Complete 
            accept processingComplete;
        
        transition from Complete to Standby 
            accept reset;
        
        transition from Standby to PowerOff 
            accept shutdown;
        
        state Scanning {
            entry perform action acquireData;
            do action monitorSignalQuality;
        }
        
        state Processing {
            entry perform action reconstructImages;
            do action analyzeFunctionalData;
        }
    }
    
    part def FMRIScanner;
    
    part fmriScanner : FMRIScanner {
        attribute systemFieldStrength : MagneticFieldStrength = 3.0;
        
        part magnet : SuperconductingMagnet {
            attribute fieldStrength = fmriScanner.systemFieldStrength;
            attribute homogeneity = 0.000001;
            attribute bore_diameter = 0.6;
        }
        
        part shimCoils : ShimCoilSystem {
            attribute numberOfChannels = 24;
            attribute maxCurrent = 10.0;
        }
        
        part gradients : GradientCoilSystem {
            attribute maxGradientStrength = 40.0;
            attribute slewRate = 200.0;
            attribute linearity = 0.95;
        }
        
        part rfAmplifier : RFAmplifier {
            attribute gain = 60.0;
            attribute bandwidth = 500000.0;
            attribute maxPower = 15000.0;
        }
        
        part transmitCoil : RFTransmitCoil {
            attribute coilType = "body coil";
            attribute numberOfChannels = 1;
            attribute powerRating = 15000.0;
        }
        
        part receiveCoil : RFReceiveCoil {
            attribute coilType = "32-channel head coil";
            attribute numberOfChannels = 32;
            attribute sensitivity = 0.98;
        }
        
        part digitizer : SignalDigitizer {
            attribute samplingRate = 1000000.0;
            attribute resolution = 16;
            attribute numberOfChannels = 32;
        }
        
        part reconstructor : ImageReconstructor {
            attribute reconstructionAlgorithm = "SENSE";
            attribute parallelImagingFactor = 2;
        }
        
        part analyzer : FunctionalAnalysisEngine {
            attribute analysisMethod = "General Linear Model";
            attribute statisticalThreshold = 0.05;
        }
        
        part table : PatientTable {
            attribute maxLoad = 200.0;
            attribute positionAccuracy = 0.1;
            attribute travelRange = 1.5;
        }
        
        part console : ControlConsole {
            attribute processorSpeed = 3000000000.0;
            attribute memoryCapacity = 128.0;
            attribute displayResolution = 3840;
        }
        
        connect magnet.magnetOutput to gradients.gradientControl;
        connect rfAmplifier to transmitCoil.transmitInterface;
        connect transmitCoil.transmitInterface to receiveCoil.receiveInterface;
        connect receiveCoil.receiveInterface to digitizer.dataOutput;
        connect digitizer.dataOutput to reconstructor.reconstructionInterface;
        connect reconstructor.reconstructionInterface to analyzer.analysisInterface;
        
        perform action functionalScan[*] ordered;
        exhibit state machine systemStates;
    }
    
    requirement def ImagingPerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def FunctionalRequirement;
    
    requirement <'REQ-001'> spatialResolution : ImagingPerformanceRequirement {
        doc /* 
         * The fMRI system shall achieve isotropic spatial resolution of 3mm or better
         * to enable precise localization of brain activity.
         */
        subject scanner : FMRIScanner;
        
        require constraint {
            scanner.reconstructor.reconstructionInterface.anatomicalImage.voxelResolution.x <= 3.0 and
            scanner.reconstructor.reconstructionInterface.anatomicalImage.voxelResolution.y <= 3.0 and
            scanner.reconstructor.reconstructionInterface.anatomicalImage.voxelResolution.z <= 3.0
        }
    }
    
    requirement <'REQ-002'> temporalResolution : ImagingPerformanceRequirement {
        doc /* 
         * The system shall acquire whole-brain volumes with temporal resolution of 2 seconds
         * or better to capture dynamic brain activity.
         */
        subject scanner : FMRIScanner;
    }
    
    requirement <'REQ-003'> signalToNoiseRatio : ImagingPerformanceRequirement {
        doc /* 
         * The system shall maintain a signal-to-noise ratio of at least 100:1 in functional
         * images to ensure reliable detection of BOLD signal changes.
         */
        subject scanner : FMRIScanner;
        
        require constraint {
            scanner.reconstructor.reconstructionInterface.anatomicalImage.contrastToNoiseRatio >= 100.0
        }
    }
    
    requirement <'REQ-004'> boldSensitivity : FunctionalRequirement {
        doc /* 
         * The system shall detect BOLD signal changes of 1% or greater with statistical
         * significance (p < 0.05) to identify active brain regions.
         */
        subject scanner : FMRIScanner;
        
        require constraint {
            scanner.analyzer.statisticalThreshold <= 0.05
        }
    }
    
    requirement <'REQ-005'> fieldStrength : ImagingPerformanceRequirement {
        doc /* 
         * The main magnetic field shall operate at 3.0 Tesla with homogeneity better than
         * 1 ppm over the imaging volume to ensure uniform image quality.
         */
        subject scanner : FMRIScanner;
        
        require constraint {
            scanner.magnet.fieldStrength == 3.0 and
            scanner.magnet.homogeneity <= 0.000001
        }
    }
    
    requirement <'REQ-006'> patientSafety : SafetyRequirement {
        doc /* 
         * The system shall limit specific absorption rate (SAR) to prevent tissue heating
         * and ensure patient safety during RF transmission.
         */
        subject scanner : FMRIScanner;
        
        assume constraint {
            scanner.transmitCoil.powerRating <= 15000.0
        }
    }
    
    requirement <'REQ-007'> primaryMission : FunctionalRequirement {
        doc /* 
         * The fMRI system shall non-invasively measure and map brain activity by detecting
         * blood oxygenation level dependent (BOLD) signal changes with sufficient spatial
         * and temporal resolution to support neuroscience research and clinical applications.
         */
        subject scanner : FMRIScanner;
        
        require spatialResolution;
        require temporalResolution;
        require signalToNoiseRatio;
        require boldSensitivity;
        require fieldStrength;
        require patientSafety;
    }
}
