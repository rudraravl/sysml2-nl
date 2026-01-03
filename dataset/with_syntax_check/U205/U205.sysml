package 'Doppler Echocardiography System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def PowerValue :> ISQ::PowerValue;
    
    attribute def DopplerShift {
        attribute transmittedFrequency : FrequencyValue;
        attribute receivedFrequency : FrequencyValue;
        attribute frequencyShift : FrequencyValue;
    }
    
    attribute def BloodFlowData {
        attribute velocity : VelocityValue;
        attribute direction : Real;
        attribute turbulence : Real;
    }
    
    attribute def CardiacMeasurement {
        attribute peakVelocity : VelocityValue;
        attribute meanVelocity : VelocityValue;
        attribute pressureGradient : PressureValue;
        attribute flowVolume : Real;
    }
    
    attribute def ImageData {
        attribute spatialResolution : LengthValue;
        attribute temporalResolution : TimeValue;
        attribute imageQuality : Real;
    }
    
    attribute def ProbePosition {
        attribute angle : Real;
        attribute depth : LengthValue;
        attribute location : String;
    }
    
    item def UltrasoundWave {
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
        attribute phase : Real;
    }
    
    item def EchoSignal {
        attribute reflectedWave : UltrasoundWave;
        attribute dopplerShift : DopplerShift;
        attribute timestamp : TimeValue;
    }
    
    port def UltrasoundPort {
        out wave : UltrasoundWave;
        in echo : EchoSignal;
    }
    
    port def DataPort {
        out flowData : BloodFlowData;
        out imageData : ImageData;
        out measurement : CardiacMeasurement;
    }
    
    port def ControlPort {
        in probePosition : ProbePosition;
        in acquisitionMode : String;
    }
    
    port def SignalPort {
        in echoSignal : EchoSignal;
    }
    
    part def UltrasoundTransducer {
        port transmitPort : UltrasoundPort;
        port receivePort : UltrasoundPort;
        
        attribute operatingFrequency : FrequencyValue;
        attribute beamWidth : Real;
        attribute acousticPower : PowerValue;
    }
    
    part def DopplerProcessor {
        port signalInput : SignalPort;
        port dataOutput : DataPort;
        
        attribute processingGain : Real;
        attribute filterBandwidth : FrequencyValue;
    }
    
    part def ImageProcessor {
        port imageInput : SignalPort;
        port imageOutput : DataPort;
        
        attribute scanLineCount : Integer;
        attribute frameRate : Real;
    }
    
    part def MeasurementEngine {
        port measurementInput : DataPort;
        port measurementOutput : DataPort;
        
        attribute calibrationFactor : Real;
    }
    
    part def DisplaySystem {
        port displayInput : DataPort;
        
        attribute screenResolution : String;
        attribute colorDepth : Integer;
    }
    
    part def ControlSystem {
        port controlOutput : ControlPort;
        
        attribute currentMode : String;
        attribute probeSettings : ProbePosition;
    }
    
    action def TransmitUltrasound {
        in baseFrequency : FrequencyValue;
        in powerLevel : PowerValue;
        out wave : UltrasoundWave;
    }
    
    action def ReceiveEcho {
        in wave : UltrasoundWave;
        out echo : EchoSignal;
    }
    
    action def ComputeDopplerShift {
        in echo : EchoSignal;
        in baseFrequency : FrequencyValue;
        out shift : DopplerShift;
    }
    
    action def CalculateVelocity {
        in shift : DopplerShift;
        in probeAngle : Real;
        out velocity : VelocityValue;
    }
    
    action def GenerateImage {
        in echoSignals : EchoSignal[*];
        in flowData : BloodFlowData;
        out imageData : ImageData;
    }
    
    action def CalculatePressureGradient {
        in peakVelocity : VelocityValue;
        out pressureGradient : PressureValue;
    }
    
    action def DisplayResults {
        in imageData : ImageData;
        in measurements : CardiacMeasurement;
    }
    
    action def PerformDopplerExamination {
        in patientPosition : String;
        in examinationProtocol : String;
        out diagnosticData : CardiacMeasurement;
        out diagnosticImages : ImageData;
        
        first start;
        
        then action positionProbe {
            in position : ProbePosition;
        }
        
        then action transmit : TransmitUltrasound {
            in baseFrequency : FrequencyValue;
            in powerLevel : PowerValue;
            out ultrasoundWave : UltrasoundWave;
        }
        
        then action receive : ReceiveEcho {
            in wave = transmit.ultrasoundWave;
            out echoSignal : EchoSignal;
        }
        
        then action computeShift : ComputeDopplerShift {
            in echo = receive.echoSignal;
            in baseFrequency = transmit.baseFrequency;
            out dopplerShift : DopplerShift;
        }
        
        then action calcVelocity : CalculateVelocity {
            in shift = computeShift.dopplerShift;
            in probeAngle : Real;
            out bloodVelocity : VelocityValue;
        }
        
        then action generateImg : GenerateImage {
            in echoSignals : EchoSignal[*];
            in flowData : BloodFlowData;
            out image : ImageData;
        }
        
        then action calcGradient : CalculatePressureGradient {
            in peakVelocity = calcVelocity.bloodVelocity;
            out gradient : PressureValue;
        }
        
        then action display : DisplayResults {
            in imageData = generateImg.image;
            in measurements : CardiacMeasurement;
        }
        
        then done;
    }
    
    part def DopplerEchocardiographySystem {
        part transducer : UltrasoundTransducer;
        part dopplerProc : DopplerProcessor;
        part imageProc : ImageProcessor;
        part measureEngine : MeasurementEngine;
        part display : DisplaySystem;
        part controller : ControlSystem;
    }
    
    part dopplerEchoSystem : DopplerEchocardiographySystem {
        doc /* 
            Doppler echocardiography system for non-invasive cardiac assessment.
            Uses ultrasound waves and the Doppler effect to measure blood flow velocity
            and direction within the heart and major vessels. The system transmits
            ultrasound pulses, receives reflected echoes from moving blood cells,
            analyzes the frequency shift to calculate flow velocity, and generates
            real-time images with overlaid flow information for clinical diagnosis
            of cardiac function and valvular abnormalities.
        */
        
        part transducer : UltrasoundTransducer {
            attribute :>> operatingFrequency = 2.5 [SI::MHz];
            attribute :>> beamWidth = 15.0;
            attribute :>> acousticPower = 0.1 [SI::W];
        }
        
        part dopplerProc : DopplerProcessor {
            attribute :>> processingGain = 40.0;
            attribute :>> filterBandwidth = 5.0 [SI::kHz];
        }
        
        part imageProc : ImageProcessor {
            attribute :>> scanLineCount = 128;
            attribute :>> frameRate = 30.0;
        }
        
        part measureEngine : MeasurementEngine {
            attribute :>> calibrationFactor = 1.0;
        }
        
        part display : DisplaySystem {
            attribute :>> screenResolution = "1920x1080";
            attribute :>> colorDepth = 24;
        }
        
        part controller : ControlSystem {
            attribute :>> currentMode = "Continuous Wave Doppler";
            attribute :>> probeSettings = ProbePosition {
                angle = 60.0;
                depth = 5.0 [SI::cm];
                location = "Apical";
            };
        }
        
        connection transducerToProcessor 
            connect transducer.receivePort to dopplerProc.signalInput;
        
        connection dopplerToImage 
            connect dopplerProc.dataOutput to imageProc.imageInput;
        
        connection imageToMeasurement 
            connect imageProc.imageOutput to measureEngine.measurementInput;
        
        connection measurementToDisplay 
            connect measureEngine.measurementOutput to display.displayInput;
        
        connection controlToTransducer 
            connect controller.controlOutput to transducer;
        
        perform action performExamination : PerformDopplerExamination {
            in patientPosition = "Supine";
            in examinationProtocol = "Standard Cardiac";
            out diagnosticData : CardiacMeasurement;
            out diagnosticImages : ImageData;
        }
    }
    
    requirement def ImagingQualityRequirement {
        doc /* System shall provide adequate image quality for diagnostic assessment. */
        
        require constraint spatialResolutionConstraint {
            doc /* Spatial resolution shall be less than 1 mm for cardiac structure visualization. */
        }
        
        require constraint temporalResolutionConstraint {
            doc /* Frame rate shall be at least 30 fps to capture cardiac motion. */
        }
    }
    
    requirement def DopplerAccuracyRequirement {
        doc /* Doppler velocity measurements shall be accurate for clinical diagnosis. */
        
        require constraint velocityAccuracy {
            doc /* Velocity measurement accuracy shall be within 5% of actual flow velocity. */
        }
        
        require constraint angleCorrection {
            doc /* System shall correct for probe angle in velocity calculations using cosine correction. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* System shall operate within safe acoustic power limits. */
        
        require constraint acousticPowerLimit {
            doc /* Acoustic power output shall not exceed FDA regulatory limits for diagnostic ultrasound. */
        }
    }
    
    requirement def ClinicalUtilityRequirement {
        doc /* System shall support comprehensive cardiac functional assessment. */
        
        require constraint valveAssessment {
            doc /* System shall enable assessment of valvular stenosis and regurgitation. */
        }
        
        require constraint hemodynamicMeasurement {
            doc /* System shall calculate pressure gradients using simplified Bernoulli equation. */
        }
        
        require constraint realTimeDisplay {
            doc /* System shall display images and measurements in real-time during examination. */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Doppler echocardiography system. */
        
        require imagingQuality : ImagingQualityRequirement;
        require dopplerAccuracy : DopplerAccuracyRequirement;
        require safety : SafetyRequirement;
        require clinicalUtility : ClinicalUtilityRequirement;
        
        satisfy by dopplerEchoSystem;
    }
}
