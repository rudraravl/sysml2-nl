package 'Magnetic Resonance Imaging System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientIdentifier;
    attribute def ScanProtocolType;
    attribute def ImageQualityMetric;
    
    attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
    attribute def GradientStrength :> ISQ::MagneticFluxDensityValue;
    attribute def RFFrequency :> ISQ::FrequencyValue;
    attribute def RFPower :> ISQ::PowerValue;
    attribute def SignalAmplitude :> ISQ::ElectricCurrentValue;
    
    item def RFPulseSequence {
        attribute centerFrequency : RFFrequency;
        attribute pulseDuration : ISQ::TimeValue;
        attribute powerLevel : RFPower;
        attribute flipAngle : Real;
    }
    
    item def GradientWaveform {
        attribute amplitude : GradientStrength;
        attribute axis : String;
        attribute duration : ISQ::TimeValue;
        attribute slewRate : Real;
    }
    
    item def MRSignalData {
        attribute realComponent : SignalAmplitude;
        attribute imaginaryComponent : SignalAmplitude;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def ReconstructedImage {
        attribute pixelMatrix : Real;
        attribute sliceThickness : ISQ::LengthValue;
        attribute fieldOfView : ISQ::LengthValue;
        attribute contrastWeighting : String;
    }
    
    port def MagneticFieldPort {
        out staticField : MagneticFieldStrength;
    }
    
    port def GradientControlPort {
        out xGradient : GradientWaveform;
        out yGradient : GradientWaveform;
        out zGradient : GradientWaveform;
    }
    
    port def RFTransmitPort {
        out rfPulse : RFPulseSequence;
    }
    
    port def RFReceivePort {
        in mrSignal : MRSignalData;
    }
    
    port def ImageOutputPort {
        out diagnosticImage : ReconstructedImage;
    }
    
    port def ControlInterfacePort {
        in scanProtocol : ScanProtocolType;
        out systemStatus : String;
    }
    
    part def SuperconductingMagnet {
        attribute nominalFieldStrength : MagneticFieldStrength;
        attribute homogeneity : Real;
        attribute bore_diameter : ISQ::LengthValue;
        
        port fieldOutput : MagneticFieldPort;
        
        action maintainStaticField {
            doc /* Maintain stable homogeneous magnetic field using superconducting coils */
            out field : MagneticFieldStrength;
        }
    }
    
    part def GradientCoilSystem {
        port gradientControl : GradientControlPort;
        
        part xCoil {
            attribute maxGradient : GradientStrength;
            attribute direction : String = "X";
        }
        
        part yCoil {
            attribute maxGradient : GradientStrength;
            attribute direction : String = "Y";
        }
        
        part zCoil {
            attribute maxGradient : GradientStrength;
            attribute direction : String = "Z";
        }
        
        action generateGradientField {
            in waveform : GradientWaveform;
            out appliedGradient : GradientStrength;
        }
    }
    
    part def RFTransmitSystem {
        port transmitPort : RFTransmitPort;
        
        attribute maxPower : RFPower;
        attribute resonantFrequency : RFFrequency;
        
        action transmitRFPulse {
            in pulseSequence : RFPulseSequence;
            out transmittedPulse : RFPulseSequence;
        }
    }
    
    part def RFReceiveSystem {
        port receivePort : RFReceivePort;
        
        attribute bandwidth : RFFrequency;
        attribute numberOfChannels : Integer;
        
        action detectMRSignal {
            out rawSignal : MRSignalData;
        }
    }
    
    part def SignalProcessingUnit {
        action digitizeSignal {
            in analogSignal : MRSignalData;
            out digitalSignal : MRSignalData;
        }
        
        action applyFourierTransform {
            in kSpaceData : MRSignalData;
            out imageSpace : Real;
        }
    }
    
    part def ImageReconstructionProcessor {
        port imageOutput : ImageOutputPort;
        
        action reconstructImage {
            in rawData : MRSignalData;
            in scanParameters : ScanProtocolType;
            out image : ReconstructedImage;
        }
    }
    
    part def ScanControlComputer {
        port controlInterface : ControlInterfacePort;
        
        action orchestrateScan {
            in protocol : ScanProtocolType;
            out rfTiming : ISQ::TimeValue;
            out gradientTiming : ISQ::TimeValue;
        }
    }
    
    part def PatientPositioningTable {
        attribute position : ISQ::LengthValue;
        attribute maxLoad : ISQ::MassValue;
        
        action moveToIsocenter {
            in targetPosition : ISQ::LengthValue;
        }
    }
    
    part def CryogenicCoolingSystem {
        attribute coolantTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute coolantLevel : Real;
        
        action maintainSuperconductivity {
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
    }
    
    action def ExciteNuclei {
        in rfPulse : RFPulseSequence;
        in staticField : MagneticFieldStrength;
        out excitedProtons : String;
    }
    
    action def SpatiallyEncodeSignal {
        in gradient : GradientWaveform;
        in excitedState : String;
        out encodedSignal : MRSignalData;
    }
    
    action def AcquireKSpaceData {
        in encodedSignal : MRSignalData;
        out kSpacePoint : MRSignalData;
    }
    
    action def PerformMRImagingScan {
        in patientID : PatientIdentifier;
        in scanProtocol : ScanProtocolType;
        out finalImage : ReconstructedImage;
        
        first start;
        
        then action initializeSystem {
            doc /* Verify magnetic field stability and system readiness */
        }
        
        then action positionPatient {
            in patient : PatientIdentifier = patientID;
        }
        
        then action shimMagneticField {
            doc /* Optimize field homogeneity for imaging volume */
        }
        
        then merge acquisitionLoop;
        
        then action applyRFExcitation : ExciteNuclei {
            in rfPulse : RFPulseSequence;
            in staticField : MagneticFieldStrength;
            out excitedProtons : String;
        }
        
        then action applyPhaseEncoding : SpatiallyEncodeSignal {
            in gradient : GradientWaveform;
            in excitedState : String = applyRFExcitation.excitedProtons;
            out encodedSignal : MRSignalData;
        }
        
        then action applyFrequencyEncoding : SpatiallyEncodeSignal {
            in gradient : GradientWaveform;
            in excitedState : String = applyPhaseEncoding.encodedSignal.timestamp;
            out encodedSignal : MRSignalData;
        }
        
        then action readoutSignal : AcquireKSpaceData {
            in encodedSignal : MRSignalData = applyFrequencyEncoding.encodedSignal;
            out kSpacePoint : MRSignalData;
        }
        
        then decide;
            if readoutSignal.kSpacePoint.timestamp > 0.0 then acquisitionLoop;
            else imageReconstruction;
        
        action imageReconstruction {
            in allKSpaceData : MRSignalData;
            out reconstructedImage : ReconstructedImage;
        }
        
        then action performQualityAssessment {
            in image : ReconstructedImage = imageReconstruction.reconstructedImage;
            out qualityScore : ImageQualityMetric;
            out isAcceptable : Boolean;
        }
        
        then decide;
            if performQualityAssessment.isAcceptable then finalizeImage;
            else acquisitionLoop;
        
        action finalizeImage {
            in validatedImage : ReconstructedImage = imageReconstruction.reconstructedImage;
        }
        
        flow finalizeImage.validatedImage to finalImage;
        
        then done;
    }
    
    part def MRImagingSystem {
        doc /* 
        Magnetic Resonance Imaging System
        
        Primary Function:
        Generate high-resolution cross-sectional images of internal body structures 
        by detecting nuclear magnetic resonance signals from hydrogen nuclei in tissue 
        when subjected to precisely controlled magnetic fields and radiofrequency pulses, 
        then spatially encoding and reconstructing these signals into diagnostic images 
        that reveal anatomical detail and tissue characteristics for medical diagnosis.
        */
        
        attribute systemFieldStrength : MagneticFieldStrength = 3.0;
        attribute boreSize : ISQ::LengthValue = 70.0;
        
        part mainMagnet : SuperconductingMagnet {
            attribute nominalFieldStrength : MagneticFieldStrength = systemFieldStrength;
            attribute homogeneity : Real = 0.9999;
            attribute bore_diameter : ISQ::LengthValue = boreSize;
        }
        
        part gradientSystem : GradientCoilSystem;
        part rfTransmitter : RFTransmitSystem {
            attribute resonantFrequency : RFFrequency = 127.74;
        }
        part rfReceiver : RFReceiveSystem {
            attribute numberOfChannels : Integer = 32;
        }
        part signalProcessor : SignalProcessingUnit;
        part imageReconstructor : ImageReconstructionProcessor;
        part scanController : ScanControlComputer;
        part patientTable : PatientPositioningTable {
            attribute maxLoad : ISQ::MassValue = 250.0;
        }
        part cryoSystem : CryogenicCoolingSystem {
            attribute coolantTemperature : ISQ::ThermodynamicTemperatureValue = 4.2;
        }
        
        connection magnetToCryo connect mainMagnet to cryoSystem;
        connection controlToGradients connect scanController.controlInterface to gradientSystem.gradientControl;
        connection controlToRFTx connect scanController.controlInterface to rfTransmitter.transmitPort;
        connection rfRxToProcessor connect rfReceiver.receivePort to signalProcessor;
        connection processorToReconstructor connect signalProcessor to imageReconstructor;
        connection reconstructorOutput connect imageReconstructor.imageOutput to scanController.controlInterface;
        
        perform action imagingOperation : PerformMRImagingScan {
            in patientID : PatientIdentifier;
            in scanProtocol : ScanProtocolType;
            out finalImage : ReconstructedImage;
        }
    }
    
    requirement def DiagnosticImagingCapability {
        doc /* The MRI system shall produce diagnostic quality images of internal anatomy */
        
        require constraint spatialResolution {
            doc /* Spatial resolution shall be better than 1.0 mm in-plane for standard protocols */
        }
        
        require constraint contrastResolution {
            doc /* System shall differentiate tissue types with contrast-to-noise ratio exceeding 5:1 */
        }
        
        require constraint signalToNoise {
            doc /* Signal-to-noise ratio shall exceed 100:1 for standard imaging sequences */
        }
    }
    
    requirement def MagneticFieldPerformance {
        doc /* The magnetic field system shall maintain specified characteristics */
        
        require constraint fieldStrength {
            doc /* Static field strength shall be 3.0 Tesla ± 0.01% */
        }
        
        require constraint fieldHomogeneity {
            doc /* Field homogeneity shall be better than 1 ppm over 45 cm DSV */
        }
        
        require constraint fieldStability {
            doc /* Field drift shall not exceed 0.1 ppm per hour */
        }
    }
    
    requirement def PatientSafety {
        doc /* The MRI system shall ensure patient safety during operation */
        
        require constraint rfSAR {
            doc /* Specific absorption rate shall not exceed 4.0 W/kg whole body average */
        }
        
        require constraint gradientdBdT {
            doc /* Gradient switching rate shall not exceed peripheral nerve stimulation threshold */
        }
        
        require constraint acousticNoise {
            doc /* Acoustic noise shall not exceed 99 dB(A) with hearing protection */
        }
    }
    
    requirement mriSystemRequirement {
        doc /* 
        The MRI system shall acquire nuclear magnetic resonance signals from patient anatomy,
        spatially encode these signals using magnetic field gradients, and reconstruct them
        into high-resolution diagnostic images suitable for clinical interpretation.
        */
        
        subject mriSystem : MRImagingSystem;
        
        require imagingCapability : DiagnosticImagingCapability;
        require fieldPerformance : MagneticFieldPerformance;
        require safety : PatientSafety;
    }
}
