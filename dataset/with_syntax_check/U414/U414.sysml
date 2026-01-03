package TissueDopplerEchocardiographySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def DepthValue :> ISQ::LengthValue;
    attribute def PowerValue :> ISQ::PowerValue;

    enum def SystemMode {
        standby;
        imaging;
        frozen;
        review;
    }

    item def UltrasoundPulse {
        attribute carrierFrequency : FrequencyValue;
        attribute pulseDuration : TimeValue;
        attribute acousticPower : PowerValue;
        attribute beamDirection : Real[3];
    }

    item def EchoReturn {
        attribute receivedFrequency : FrequencyValue;
        attribute dopplerShift : FrequencyValue;
        attribute signalAmplitude : Real;
        attribute depth : DepthValue;
        attribute arrivalTime : TimeValue;
    }

    item def TissueVelocityData {
        attribute velocity : VelocityValue;
        attribute spatialLocation : DepthValue;
        attribute temporalIndex : TimeValue;
        attribute myocardialSegment : String;
    }

    item def VelocityImage {
        attribute velocityField : VelocityValue[*];
        attribute spatialResolution : DepthValue;
        attribute frameTimestamp : TimeValue;
        attribute colorScale : VelocityValue[2];
    }

    attribute def TriggerSignal;
    attribute def CalibrationData;

    port def TransmitPort {
        out pulse : UltrasoundPulse;
    }

    port def ReceivePort {
        in echo : EchoReturn;
    }

    port def VelocityDataPort {
        out velocityData : TissueVelocityData;
    }

    port def ImagePort {
        out image : VelocityImage;
    }

    port def ControlPort {
        in mode : SystemMode;
        in trigger : TriggerSignal;
    }

    part def TransducerArray {
        attribute elementCount : Integer;
        attribute centerFrequency : FrequencyValue;
        attribute bandwidth : FrequencyValue;
        attribute aperture : DepthValue;

        port txPort : TransmitPort;
        port rxPort : ReceivePort;

        perform action transmitPulse {
            in frequency : FrequencyValue;
            in power : PowerValue;
            out pulse : UltrasoundPulse;
        }

        perform action receiveEcho {
            in reflectedSignal : EchoReturn;
        }
    }

    part def BeamformingUnit {
        attribute focusDepth : DepthValue;
        attribute steeringAngle : Real;
        attribute apodizationWindow : Real[*];

        perform action formTransmitBeam {
            in elementDelays : TimeValue[*];
            out focusedPulse : UltrasoundPulse;
        }

        perform action formReceiveBeam {
            in echoArray : EchoReturn[*];
            out coherentEcho : EchoReturn;
        }
    }

    part def DopplerAnalyzer {
        attribute wallFilterFrequency : FrequencyValue;
        attribute sampleVolume : DepthValue;
        attribute angleCorrection : Real;

        perform action extractDopplerShift {
            in echo : EchoReturn;
            in referenceFrequency : FrequencyValue;
            out shift : FrequencyValue;
        }

        perform action calculateVelocity {
            in dopplerShift : FrequencyValue;
            in transmitFrequency : FrequencyValue;
            in incidenceAngle : Real;
            out tissueVelocity : VelocityValue;
        }

        perform action filterWallMotion {
            in rawVelocity : VelocityValue;
            out filteredVelocity : VelocityValue;
        }
    }

    part def SignalProcessor {
        attribute gainControl : Real;
        attribute dynamicRange : Real;
        attribute timeGainCompensation : Real[*];

        perform action amplifySignal {
            in echo : EchoReturn;
            out amplifiedEcho : EchoReturn;
        }

        perform action demodulate {
            in echo : EchoReturn;
            out baseband : EchoReturn;
        }
    }

    part def ImageGenerator {
        attribute colorMap : String;
        attribute velocityRange : VelocityValue[2];
        attribute frameRate : FrequencyValue;

        perform action mapVelocitiesToImage {
            in velocityData : TissueVelocityData[*];
            out velocityImage : VelocityImage;
        }

        perform action applyColorCoding {
            in velocities : VelocityValue[*];
            out colorMappedImage : VelocityImage;
        }
    }

    part def DisplayUnit {
        attribute screenResolution : Integer[2];
        attribute refreshRate : FrequencyValue;
        attribute brightness : Real;

        perform action renderImage {
            in image : VelocityImage;
        }

        perform action overlayAnnotations {
            in image : VelocityImage;
            in measurements : TissueVelocityData[*];
        }
    }

    part def SystemController {
        attribute operatingMode : SystemMode;
        attribute acquisitionDepth : DepthValue;
        attribute pulseRepetitionFrequency : FrequencyValue;

        perform action coordinateAcquisition {
            in mode : SystemMode;
        }

        perform action synchronizeTiming {
            in trigger : TriggerSignal;
        }
    }

    action def TransmitUltrasound {
        in frequency : FrequencyValue;
        in focusDepth : DepthValue;
        in power : PowerValue;
        out transmittedPulse : UltrasoundPulse;
    }

    action def AcquireEchoes {
        in pulse : UltrasoundPulse;
        out echoSignals : EchoReturn[*];
    }

    action def ProcessDopplerData {
        in echoes : EchoReturn[*];
        in transmitFrequency : FrequencyValue;
        out velocityData : TissueVelocityData[*];
    }

    action def GenerateVelocityImage {
        in velocityData : TissueVelocityData[*];
        out image : VelocityImage;
    }

    action def PerformTissueDopplerImaging {
        in operatingFrequency : FrequencyValue;
        in imagingDepth : DepthValue;
        in acousticPower : PowerValue;
        in prf : FrequencyValue;
        in currentMode : SystemMode;
        out velocityImages : VelocityImage[*];

        first start;
        then merge continuousImaging;

        then action transmit : TransmitUltrasound {
            in frequency = operatingFrequency;
            in focusDepth = imagingDepth;
            in power = acousticPower;
            out transmittedPulse : UltrasoundPulse;
        }

        then action acquire : AcquireEchoes {
            in pulse = transmit.transmittedPulse;
            out echoSignals : EchoReturn[*];
        }

        then action processDoppler : ProcessDopplerData {
            in echoes = acquire.echoSignals;
            in transmitFrequency = operatingFrequency;
            out velocityData : TissueVelocityData[*];
        }

        then action generateImage : GenerateVelocityImage {
            in velocityData = processDoppler.velocityData;
            out image : VelocityImage;
        }

        then decide;
            if currentMode == SystemMode::imaging then continuousImaging;
            if currentMode == SystemMode::frozen then freeze;

        action freeze;
        then done;
    }

    part def TissueDopplerEchoSystem {
        doc /*
            Tissue Doppler Echocardiography System for quantitative assessment
            of myocardial tissue motion and velocities. The system transmits
            ultrasound pulses, receives Doppler-shifted echoes from moving
            cardiac tissue, and generates color-coded velocity images for
            clinical evaluation of regional and global cardiac function.
        */

        port controlInterface : ControlPort;
        port imageOutput : ImagePort;

        part transducer : TransducerArray {
            attribute :>> elementCount = 128;
            attribute :>> centerFrequency = 3.5 [MHz];
            attribute :>> bandwidth = 1.5 [MHz];
            attribute :>> aperture = 15.0 [mm];
        }

        part beamformer : BeamformingUnit {
            attribute :>> focusDepth = 60.0 [mm];
            attribute :>> steeringAngle = 0.0;
        }

        part signalProcessor : SignalProcessor {
            attribute :>> gainControl = 50.0;
            attribute :>> dynamicRange = 60.0;
        }

        part dopplerAnalyzer : DopplerAnalyzer {
            attribute :>> wallFilterFrequency = 150.0 [Hz];
            attribute :>> sampleVolume = 5.0 [mm];
            attribute :>> angleCorrection = 0.0;
        }

        part imageGenerator : ImageGenerator {
            attribute :>> colorMap = "velocity";
            attribute :>> frameRate = 50.0 [Hz];
        }

        part displayUnit : DisplayUnit {
            attribute :>> refreshRate = 60.0 [Hz];
            attribute :>> brightness = 75.0;
        }

        part controller : SystemController {
            attribute :>> operatingMode = SystemMode::standby;
            attribute :>> acquisitionDepth = 120.0 [mm];
            attribute :>> pulseRepetitionFrequency = 2000.0 [Hz];
        }

        connection txPath connect beamformer.formTransmitBeam.focusedPulse to transducer.txPort.pulse;
        connection rxPath connect transducer.rxPort.echo to signalProcessor.amplifySignal.echo;
        connection processingPath connect signalProcessor.demodulate.baseband to dopplerAnalyzer.extractDopplerShift.echo;
        connection velocityPath connect dopplerAnalyzer.calculateVelocity.tissueVelocity to imageGenerator.mapVelocitiesToImage.velocityData;
        connection displayPath connect imageGenerator.applyColorCoding.colorMappedImage to displayUnit.renderImage.image;
        connection outputPath connect imageGenerator.applyColorCoding.colorMappedImage to imageOutput.image;

        perform action imagingSequence : PerformTissueDopplerImaging {
            in operatingFrequency = transducer.centerFrequency;
            in imagingDepth = controller.acquisitionDepth;
            in acousticPower = 50.0 [mW];
            in prf = controller.pulseRepetitionFrequency;
            in currentMode = controller.operatingMode;
            out velocityImages;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /*
            The Tissue Doppler Echocardiography System shall non-invasively
            measure and quantify myocardial tissue velocities to enable
            assessment of regional and global cardiac function.
        */

        subject system : TissueDopplerEchoSystem;

        require constraint velocityMeasurementRange {
            doc /* System shall measure tissue velocities in physiological range. */
            -0.3 [m / s] <= system.dopplerAnalyzer.calculateVelocity.tissueVelocity and
            system.dopplerAnalyzer.calculateVelocity.tissueVelocity <= 0.3 [m / s]
        }
    }

    requirement def TemporalResolutionRequirement {
        doc /*
            The system shall provide adequate temporal resolution for
            cardiac cycle analysis and timing measurements.
        */

        subject system : TissueDopplerEchoSystem;

        require constraint frameRateConstraint {
            doc /* Frame rate shall support cardiac motion analysis. */
            system.imageGenerator.frameRate >= 30.0 [Hz]
        }
    }

    requirement def WallMotionFilterRequirement {
        doc /*
            The system shall filter high-amplitude, low-frequency wall
            motion signals to isolate myocardial tissue velocities.
        */

        subject system : TissueDopplerEchoSystem;

        require constraint wallFilterConstraint {
            doc /* Wall filter shall attenuate low-frequency artifacts. */
            system.dopplerAnalyzer.wallFilterFrequency >= 50.0 [Hz] and
            system.dopplerAnalyzer.wallFilterFrequency <= 300.0 [Hz]
        }
    }

    requirement def SpatialResolutionRequirement {
        doc /*
            The system shall provide spatial resolution adequate for
            segmental myocardial analysis.
        */

        subject system : TissueDopplerEchoSystem;

        require constraint sampleVolumeConstraint {
            doc /* Sample volume shall enable regional assessment. */
            system.dopplerAnalyzer.sampleVolume >= 2.0 [mm] and
            system.dopplerAnalyzer.sampleVolume <= 10.0 [mm]
        }
    }

    requirement systemLevelRequirement {
        doc /*
            The Tissue Doppler Echocardiography System shall provide
            real-time, quantitative assessment of myocardial tissue motion
            for clinical diagnosis and monitoring of cardiac function.
        */

        require primaryFunc : PrimaryFunctionRequirement;
        require temporalRes : TemporalResolutionRequirement;
        require wallFilter : WallMotionFilterRequirement;
        require spatialRes : SpatialResolutionRequirement;
    }

    part tissueDopplerSystem : TissueDopplerEchoSystem;
}
