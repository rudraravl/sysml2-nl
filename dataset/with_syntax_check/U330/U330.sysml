package 'Echocardiography Numerical Modeling System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def UltrasoundFrequency :> ISQ::FrequencyValue {
        attribute :>> num: Real;
        attribute :>> mRef: FrequencyUnit;
    }

    attribute def AcousticImpedance :> ScalarValues::Real;

    attribute def ReflectionCoefficient :> ScalarValues::Real;

    attribute def TissueDepth :> ISQ::LengthValue {
        attribute :>> num: Real;
        attribute :>> mRef: LengthUnit;
    }

    attribute def EchoIntensity :> ScalarValues::Real;

    attribute def PropagationVelocity :> ISQ::SpeedValue {
        attribute :>> num: Real;
        attribute :>> mRef: SpeedUnit;
    }

    attribute def Attenuation :> ScalarValues::Real;

    attribute def TimeOfFlight :> ISQ::TimeValue {
        attribute :>> num: Real;
        attribute :>> mRef: TimeUnit;
    }

    item def UltrasoundPulse {
        attribute frequency: UltrasoundFrequency;
        attribute intensity: EchoIntensity;
        attribute timestamp: TimeOfFlight;
    }

    item def TissueProperties {
        attribute impedance: AcousticImpedance;
        attribute depth: TissueDepth;
        attribute attenuationCoeff: Attenuation;
    }

    item def EchoSignal {
        attribute reflectedIntensity: EchoIntensity;
        attribute timeDelay: TimeOfFlight;
        attribute signalQuality: Real;
    }

    item def CardiacImage {
        attribute pixelData: Real[*];
        attribute resolution: LengthValue;
        attribute contrastRatio: Real;
    }

    item def VelocityField {
        attribute bloodVelocity: SpeedValue[*];
        attribute spatialCoordinates: LengthValue[*];
    }

    item def StrainTensor {
        attribute radialStrain: Real;
        attribute circumferentialStrain: Real;
        attribute longitudinalStrain: Real;
    }

    action def CalculateReflectionCoefficient {
        in impedance1: AcousticImpedance;
        in impedance2: AcousticImpedance;
        out reflectionCoeff: ReflectionCoefficient;
    }

    action def ComputeEchoIntensity {
        in incidentIntensity: EchoIntensity;
        in reflectionCoeff: ReflectionCoefficient;
        in attenuationFactor: Attenuation;
        in depth: TissueDepth;
        out echoIntensity: EchoIntensity;
    }

    action def CalculateTimeOfFlight {
        in depth: TissueDepth;
        in velocity: PropagationVelocity;
        out tof: TimeOfFlight;
    }

    action def ApplyAttenuationModel {
        in initialIntensity: EchoIntensity;
        in depth: TissueDepth;
        in attenuationCoeff: Attenuation;
        in frequency: UltrasoundFrequency;
        out attenuatedIntensity: EchoIntensity;
    }

    action def ReconstructImage {
        in echoSignals: EchoSignal[*];
        in scanGeometry: Real[*];
        out cardiacImage: CardiacImage;
    }

    action def ComputeDopplerVelocity {
        in echoSignals: EchoSignal[*];
        in transmitFrequency: UltrasoundFrequency;
        out velocityField: VelocityField;
    }

    action def CalculateMyocardialStrain {
        in velocityField: VelocityField;
        in timeInterval: TimeValue;
        out strainTensor: StrainTensor;
    }

    action def ProcessEchocardiography {
        in tissueLayerProperties: TissueProperties[*] ordered;
        in transmitFrequency: UltrasoundFrequency;
        in initialIntensity: EchoIntensity;
        in soundVelocity: PropagationVelocity;
        out reconstructedImage: CardiacImage;
        out echoProfile: EchoSignal[*] := ( );

        private attribute currentIntensity := initialIntensity;
        private attribute cumulativeDepth: TissueDepth;
        private attribute bloodImpedance: AcousticImpedance := 1.61;

        first start;
        then assign cumulativeDepth := 0.0[mm];
        then merge nextLayer;

        for tissueLayer in tissueLayerProperties {
            action computeReflection: CalculateReflectionCoefficient {
                in impedance1 = bloodImpedance;
                in impedance2 = tissueLayer.impedance;
                out reflectionCoeff;
            }

            then action applyAttenuation: ApplyAttenuationModel {
                in initialIntensity = currentIntensity;
                in depth = tissueLayer.depth;
                in attenuationCoeff = tissueLayer.attenuationCoeff;
                in frequency = transmitFrequency;
                out attenuatedIntensity;
            }

            then action calculateEcho: ComputeEchoIntensity {
                in incidentIntensity = applyAttenuation.attenuatedIntensity;
                in reflectionCoeff = computeReflection.reflectionCoeff;
                in attenuationFactor = tissueLayer.attenuationCoeff;
                in depth = tissueLayer.depth;
                out echoIntensity;
            }

            then assign cumulativeDepth := cumulativeDepth + tissueLayer.depth;

            then action computeTOF: CalculateTimeOfFlight {
                in depth = cumulativeDepth;
                in velocity = soundVelocity;
                out tof;
            }

            then action createEchoSignal {
                private attribute signal: EchoSignal {
                    attribute :>> reflectedIntensity = calculateEcho.echoIntensity;
                    attribute :>> timeDelay = computeTOF.tof;
                    attribute :>> signalQuality = calculateEcho.echoIntensity / initialIntensity;
                }
            }

            then assign echoProfile := echoProfile->SequenceFunctions::including(createEchoSignal.signal);
            then assign currentIntensity := applyAttenuation.attenuatedIntensity * (1.0 - computeReflection.reflectionCoeff);
            then assign bloodImpedance := tissueLayer.impedance;
            then nextLayer;
        }

        then action reconstruct: ReconstructImage {
            in echoSignals = echoProfile;
            in scanGeometry[*];
            out cardiacImage;
        }

        then assign reconstructedImage := reconstruct.cardiacImage;
        then done;
    }

    part def UltrasoundTransducer {
        attribute operatingFrequency: UltrasoundFrequency;
        attribute transmitPower: EchoIntensity;

        port transmitPort {
            out pulse: UltrasoundPulse;
        }

        port receivePort {
            in echo: EchoSignal;
        }
    }

    part def SignalProcessor {
        attribute processingGain: Real;
        attribute noiseThreshold: Real;

        port inputPort {
            in rawEcho: EchoSignal;
        }

        port outputPort {
            out processedEcho: EchoSignal;
        }

        perform action filterAndAmplify {
            in rawSignal: EchoSignal;
            out amplifiedSignal: EchoSignal;
        }
    }

    part def ImageReconstructor {
        attribute scanLineCount: Integer;
        attribute imageDepth: TissueDepth;

        port dataPort {
            in echoData: EchoSignal[*];
        }

        port imagePort {
            out image: CardiacImage;
        }

        perform action beamform {
            in echoSignals: EchoSignal[*];
            out beamformedData: Real[*];
        }

        perform action envelopeDetect {
            in beamformedData: Real[*];
            out envelopeData: Real[*];
        }

        perform action logCompress {
            in envelopeData: Real[*];
            out compressedData: Real[*];
        }
    }

    part def DopplerAnalyzer {
        attribute velocityRange: SpeedValue;

        port echoPort {
            in echoSignals: EchoSignal[*];
        }

        port velocityPort {
            out velocityField: VelocityField;
        }

        perform action computeVelocity: ComputeDopplerVelocity {
            in echoSignals;
            in transmitFrequency;
            out velocityField;
        }
    }

    part def StrainAnalyzer {
        attribute strainSensitivity: Real;

        port velocityPort {
            in velocityField: VelocityField;
        }

        port strainPort {
            out strainTensor: StrainTensor;
        }

        perform action computeStrain: CalculateMyocardialStrain {
            in velocityField;
            in timeInterval;
            out strainTensor;
        }
    }

    part def TissueModel {
        attribute layerCount: Integer;

        part myocardiumLayer: TissueProperties {
            attribute :>> impedance = 1.70;
            attribute :>> depth = 8.0[mm];
            attribute :>> attenuationCoeff = 0.52;
        }

        part endocardiumLayer: TissueProperties {
            attribute :>> impedance = 1.65;
            attribute :>> depth = 1.5[mm];
            attribute :>> attenuationCoeff = 0.48;
        }

        part valveLayer: TissueProperties {
            attribute :>> impedance = 1.75;
            attribute :>> depth = 2.0[mm];
            attribute :>> attenuationCoeff = 0.55;
        }

        part pericardiumLayer: TissueProperties {
            attribute :>> impedance = 1.68;
            attribute :>> depth = 1.0[mm];
            attribute :>> attenuationCoeff = 0.50;
        }
    }

    part echocardiographySystem {
        doc /*
        The echocardiography numerical modeling system simulates ultrasound wave 
        propagation through cardiac tissue layers to generate diagnostic images 
        and quantitative hemodynamic measurements. The system models acoustic 
        impedance mismatches, frequency-dependent attenuation, and Doppler velocity 
        fields to reconstruct cardiac structure and function.
        */

        attribute systemFrequency: UltrasoundFrequency = UltrasoundFrequency(num = 3.5, mRef = SI::MHz);
        attribute soundSpeed: PropagationVelocity = PropagationVelocity(num = 1540.0, mRef = SI::m/SI::s);
        attribute transmitIntensity: EchoIntensity = 100.0;

        part transducer: UltrasoundTransducer {
            attribute :>> operatingFrequency = echocardiographySystem.systemFrequency;
            attribute :>> transmitPower = echocardiographySystem.transmitIntensity;
        }

        part processor: SignalProcessor {
            attribute :>> processingGain = 40.0;
            attribute :>> noiseThreshold = 0.05;
        }

        part reconstructor: ImageReconstructor {
            attribute :>> scanLineCount = 128;
            attribute :>> imageDepth = TissueDepth(num = 15.0, mRef = SI::cm);
        }

        part dopplerAnalyzer: DopplerAnalyzer {
            attribute :>> velocityRange = SpeedValue(num = 2.0, mRef = SI::m/SI::s);
        }

        part strainAnalyzer: StrainAnalyzer {
            attribute :>> strainSensitivity = 0.01;
        }

        part heartModel: TissueModel {
            attribute :>> layerCount = 4;
        }

        connection transducerToProcessor connect 
            transducer.receivePort to processor.inputPort;

        connection processorToReconstructor connect 
            processor.outputPort to reconstructor.dataPort;

        connection processorToDoppler connect 
            processor.outputPort to dopplerAnalyzer.echoPort;

        connection dopplerToStrain connect 
            dopplerAnalyzer.velocityPort to strainAnalyzer.velocityPort;

        perform action performEchoImaging: ProcessEchocardiography {
            in tissueLayerProperties[*] = (
                heartModel.myocardiumLayer,
                heartModel.endocardiumLayer,
                heartModel.valveLayer,
                heartModel.pericardiumLayer
            );
            in transmitFrequency = systemFrequency;
            in initialIntensity = transmitIntensity;
            in soundVelocity = soundSpeed;
            out reconstructedImage;
            out echoProfile[*];
        }
    }

    requirement def ImageQualityRequirement {
        doc /*
        The echocardiography system shall produce cardiac images with 
        sufficient contrast and resolution to distinguish tissue boundaries.
        */

        subject echoSystem : echocardiographySystem;

        assume constraint {
            echoSystem.performEchoImaging.reconstructedImage.contrastRatio >= 20.0
        }

        assume constraint {
            echoSystem.performEchoImaging.reconstructedImage.resolution.num <= 0.5
        }
    }

    requirement def PenetrationDepthRequirement {
        doc /*
        The system shall achieve adequate penetration depth to image 
        all cardiac structures with measurable echo return.
        */

        subject echoSystem : echocardiographySystem;

        assume constraint {
            echoSystem.performEchoImaging.echoProfile->SequenceFunctions::size() >= 4
        }
    }

    requirement def DopplerAccuracyRequirement {
        doc /*
        The Doppler velocity measurements shall accurately represent 
        blood flow velocities within physiological ranges.
        */

        subject echoSystem : echocardiographySystem;

        assume constraint {
            echoSystem.dopplerAnalyzer.velocityRange.num >= 1.5
        }
    }

    requirement systemRequirements {
        subject echocardiographySystem;

        requirement imageQuality: ImageQualityRequirement;
        requirement penetrationDepth: PenetrationDepthRequirement;
        requirement dopplerAccuracy: DopplerAccuracyRequirement;
    }
}
