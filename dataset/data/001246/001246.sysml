package 'ShackHartmannWavefrontSensingSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WavelengthValue :> ISQ::LengthValue;
    attribute def WavefrontErrorValue :> ISQ::LengthValue;
    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def IntensityValue :> ISQ::PowerValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PixelCountValue :> Real;

    attribute def Position2D {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
    }

    attribute def Displacement2D {
        attribute dx : ISQ::LengthValue;
        attribute dy : ISQ::LengthValue;
    }

    attribute def ZernikeCoefficients {
        attribute piston : ISQ::LengthValue;
        attribute tiltX : AngleValue;
        attribute tiltY : AngleValue;
        attribute defocus : ISQ::LengthValue;
        attribute astigmatismX : ISQ::LengthValue;
        attribute astigmatismY : ISQ::LengthValue;
        attribute comaX : ISQ::LengthValue;
        attribute comaY : ISQ::LengthValue;
        attribute spherical : ISQ::LengthValue;
    }

    item def OpticalWavefront {
        attribute wavelength : WavelengthValue;
        attribute intensity : IntensityValue;
        attribute rmsWavefrontError : WavefrontErrorValue;
        attribute peakValleyError : WavefrontErrorValue;
    }

    item def SpotImage {
        attribute resolutionX : PixelCountValue;
        attribute resolutionY : PixelCountValue;
        attribute spotPositions : Position2D[1..*];
        attribute spotIntensities : IntensityValue[1..*];
        attribute timestamp : ISQ::TimeValue;
    }

    item def ReferenceSpotPattern {
        attribute referencePositions : Position2D[1..*];
        attribute calibrationWavelength : WavelengthValue;
    }

    item def WavefrontMap {
        attribute gridSizeX : Natural;
        attribute gridSizeY : Natural;
        attribute localSlopes : Displacement2D[1..*];
        attribute reconstructedPhase : WavefrontErrorValue[1..*];
        attribute zernikeDecomposition : ZernikeCoefficients;
        attribute rmsError : WavefrontErrorValue;
    }

    port def OpticalInputPort {
        in item wavefront : OpticalWavefront;
    }

    port def WavefrontDataPort {
        out item wavefrontData : WavefrontMap;
    }

    port def ControlPort {
        in item exposureCommand : ISQ::TimeValue;
        in item calibrationCommand : Boolean;
        out item statusData : String;
    }

    action def SplitWavefront {
        in item incomingWavefront : OpticalWavefront;
        out item subapertureBeams : OpticalWavefront[1..*];
    }

    action def FocusSubapertures {
        in item subapertureBeams : OpticalWavefront[1..*];
        out item focalSpots : SpotImage;
    }

    action def DetectSpots {
        in item focalSpots : SpotImage;
        in item exposureTime : ISQ::TimeValue;
        out item detectedImage : SpotImage;
    }

    action def ComputeDisplacements {
        in item measuredSpots : SpotImage;
        in item referencePattern : ReferenceSpotPattern;
        out item displacements : Displacement2D[1..*];
    }

    action def ReconstructWavefront {
        in item localDisplacements : Displacement2D[1..*];
        in item wavelength : WavelengthValue;
        out item wavefrontMap : WavefrontMap;
    }

    action def PerformCalibration {
        in item flatWavefront : OpticalWavefront;
        out item referencePattern : ReferenceSpotPattern;
    }

    action def MeasureWavefront {
        in item inputWavefront : OpticalWavefront;
        in item reference : ReferenceSpotPattern;
        in item exposure : ISQ::TimeValue;
        out item wavefrontMeasurement : WavefrontMap;

        bind inputWavefront = split.incomingWavefront;
        bind reference = computeDisp.referencePattern;
        bind exposure = detect.exposureTime;
        bind wavefrontMeasurement = reconstruct.wavefrontMap;

        action split : SplitWavefront {
            in incomingWavefront;
            out subapertureBeams;
        }

        succession split then focus;

        action focus : FocusSubapertures {
            in subapertureBeams;
            out focalSpots;
        }

        flow from split.subapertureBeams to focus.subapertureBeams;
        succession focus then detect;

        action detect : DetectSpots {
            in focalSpots;
            in exposureTime;
            out detectedImage;
        }

        flow from focus.focalSpots to detect.focalSpots;
        succession detect then computeDisp;

        action computeDisp : ComputeDisplacements {
            in measuredSpots;
            in referencePattern;
            out displacements;
        }

        flow from detect.detectedImage to computeDisp.measuredSpots;
        succession computeDisp then reconstruct;

        action reconstruct : ReconstructWavefront {
            in localDisplacements;
            in wavelength;
            out wavefrontMap;
        }

        flow from computeDisp.displacements to reconstruct.localDisplacements;
        bind reconstruct.wavelength = inputWavefront.wavelength;
    }

    part def LensletArray {
        attribute lensletPitch : ISQ::LengthValue;
        attribute lensletFocalLength : ISQ::LengthValue;
        attribute numberOfLensletsX : Natural;
        attribute numberOfLensletsY : Natural;
        attribute clearAperture : ISQ::LengthValue;
        attribute transmissionEfficiency : Real;

        perform SplitWavefront;
        perform FocusSubapertures;
    }

    part def CCDDetector {
        attribute pixelSize : ISQ::LengthValue;
        attribute arrayWidth : PixelCountValue;
        attribute arrayHeight : PixelCountValue;
        attribute quantumEfficiency : Real;
        attribute readoutNoise : Real;
        attribute darkCurrent : Real;
        attribute maxFrameRate : FrequencyValue;
        attribute bitDepth : Natural;

        perform DetectSpots;
    }

    part def WavefrontReconstructionProcessor {
        attribute reconstructionAlgorithm : String;
        attribute zernikeOrderMax : Natural;
        attribute processingLatency : ISQ::TimeValue;
        attribute calibrationData : ReferenceSpotPattern;

        perform ComputeDisplacements;
        perform ReconstructWavefront;
        perform PerformCalibration;
    }

    part def BeamSplitter {
        attribute splitRatio : Real;
        attribute wavelengthRange : WavelengthValue[2];
    }

    part def RelayOptics {
        attribute magnification : Real;
        attribute focalLength : ISQ::LengthValue;
        attribute apertureDiameter : ISQ::LengthValue;
    }

    connection def OpticalConnection {
        end source : OpticalInputPort[1];
        end target : OpticalInputPort[1];
    }

    connection def DataConnection {
        end source : WavefrontDataPort[1];
        end target : WavefrontDataPort[1];
    }

    state def SensorOperationalStates {
        entry; then initialization;

        state initialization {
            entry assign currentStatus = "Initializing";
        }

        transition init_to_calibration
            first initialization
            accept CalibrationRequest
            then calibration;

        state calibration {
            entry assign currentStatus = "Calibrating";
            do action calibrate : PerformCalibration;
        }

        transition calibration_to_ready
            first calibration
            accept CalibrationComplete
            then ready;

        state ready {
            entry assign currentStatus = "Ready";
        }

        transition ready_to_acquiring
            first ready
            accept MeasurementTrigger
            then acquiring;

        state acquiring {
            entry assign currentStatus = "Acquiring";
            do action acquire : DetectSpots;
        }

        transition acquiring_to_processing
            first acquiring
            accept AcquisitionComplete
            then processing;

        state processing {
            entry assign currentStatus = "Processing";
            do action process : ReconstructWavefront;
        }

        transition processing_to_outputting
            first processing
            accept ProcessingComplete
            then outputting;

        state outputting {
            entry assign currentStatus = "Outputting Data";
        }

        transition outputting_to_ready
            first outputting
            accept OutputComplete
            then ready;

        transition error_from_any
            first acquiring, processing, outputting
            accept ErrorDetected
            then errorState;

        state errorState {
            entry assign currentStatus = "Error";
        }

        transition error_to_initialization
            first errorState
            accept ResetCommand
            then initialization;

        attribute currentStatus : String;
    }

    part def ShackHartmannWavefrontSensor {
        attribute sensorIdentifier : String;
        attribute operatingWavelength : WavelengthValue;
        attribute measurementAccuracy : WavefrontErrorValue;
        attribute measurementRange : WavefrontErrorValue;
        attribute spatialResolution : ISQ::LengthValue;
        attribute temporalResolution : FrequencyValue;

        port opticalInput : OpticalInputPort;
        port dataOutput : WavefrontDataPort;
        port controlInterface : ControlPort;

        part relayOptics : RelayOptics[1] {
            attribute :>> magnification = 1.0;
            attribute :>> focalLength = 150.0[mm];
            attribute :>> apertureDiameter = 30.0[mm];
        }

        part lensletArray : LensletArray[1] {
            attribute :>> lensletPitch = 0.3[mm];
            attribute :>> lensletFocalLength = 5.2[mm];
            attribute :>> numberOfLensletsX = 32;
            attribute :>> numberOfLensletsY = 32;
            attribute :>> clearAperture = 9.6[mm];
            attribute :>> transmissionEfficiency = 0.95;
        }

        part detector : CCDDetector[1] {
            attribute :>> pixelSize = 0.0055[mm];
            attribute :>> arrayWidth = 2048;
            attribute :>> arrayHeight = 2048;
            attribute :>> quantumEfficiency = 0.85;
            attribute :>> readoutNoise = 3.5;
            attribute :>> darkCurrent = 0.01;
            attribute :>> maxFrameRate = 200.0[Hz];
            attribute :>> bitDepth = 16;
        }

        part processor : WavefrontReconstructionProcessor[1] {
            attribute :>> reconstructionAlgorithm = "Modal Zernike Reconstruction";
            attribute :>> zernikeOrderMax = 15;
            attribute :>> processingLatency = 0.005[s];
        }

        perform action measurementAction : MeasureWavefront {
            bind inputWavefront = opticalInput.wavefront;
            bind reference = processor.calibrationData;
            bind exposure = controlInterface.exposureCommand;
            bind wavefrontMeasurement = dataOutput.wavefrontData;
        }

        exhibit state operatingState : SensorOperationalStates;
    }

    part def WavefrontSensingUnit {
        attribute unitName : String;
        attribute installationLocation : String;

        port opticalIn : OpticalInputPort;
        port dataOut : WavefrontDataPort;
        port control : ControlPort;

        part sensor : ShackHartmannWavefrontSensor[1];

        connection opticalPath : OpticalConnection
            connect opticalIn to sensor.opticalInput;

        connection dataPath : DataConnection
            connect sensor.dataOutput to dataOut;
    }

    requirement def WavefrontMeasurementAccuracyRequirement {
        doc /* The sensor shall measure wavefront aberrations with RMS accuracy better than λ/20 at the operating wavelength. */

        subject sensor : ShackHartmannWavefrontSensor;

        require constraint accuracyConstraint {
            sensor.measurementAccuracy.num <= (sensor.operatingWavelength.num / 20.0)
        }
    }

    requirement def SpatialResolutionRequirement {
        doc /* The sensor shall provide spatial sampling with at least 20x20 subapertures across the pupil. */

        subject sensor : ShackHartmannWavefrontSensor;

        require constraint subapertureCountConstraint {
            (sensor.lensletArray.numberOfLensletsX >= 20) and
            (sensor.lensletArray.numberOfLensletsY >= 20)
        }
    }

    requirement def TemporalResolutionRequirement {
        doc /* The sensor shall acquire wavefront measurements at a minimum rate of 100 Hz. */

        subject sensor : ShackHartmannWavefrontSensor;

        require constraint frameRateConstraint {
            sensor.temporalResolution.num >= 100.0
        }
    }

    requirement def DynamicRangeRequirement {
        doc /* The sensor shall measure wavefront errors up to 10 wavelengths peak-to-valley. */

        subject sensor : ShackHartmannWavefrontSensor;

        require constraint dynamicRangeConstraint {
            sensor.measurementRange.num >= (10.0 * sensor.operatingWavelength.num)
        }
    }

    requirement def CalibrationRequirement {
        doc /* The sensor shall be calibrated with a known flat wavefront reference before operation. */

        subject sensor : ShackHartmannWavefrontSensor;

        require constraint calibrationDataExists {
            sensor.processor.calibrationData.referencePositions->size() > 0
        }
    }

    part sensingUnit : WavefrontSensingUnit {
        attribute :>> unitName = "SHWFS-Primary-001";
        attribute :>> installationLocation = "Optical Test Bench A";

        part :>> sensor {
            attribute :>> sensorIdentifier = "SHWFS-SN-12345";
            attribute :>> operatingWavelength = 632.8[nm];
            attribute :>> measurementAccuracy = 31.6[nm];
            attribute :>> measurementRange = 6328.0[nm];
            attribute :>> spatialResolution = 0.3[mm];
            attribute :>> temporalResolution = 150.0[Hz];
        }

        satisfy accuracyReq : WavefrontMeasurementAccuracyRequirement {
            subject testSensor :> sensor = sensingUnit.sensor;
        }

        satisfy spatialReq : SpatialResolutionRequirement {
            subject testSensor :> sensor = sensingUnit.sensor;
        }

        satisfy temporalReq : TemporalResolutionRequirement {
            subject testSensor :> sensor = sensingUnit.sensor;
        }

        satisfy dynamicReq : DynamicRangeRequirement {
            subject testSensor :> sensor = sensingUnit.sensor;
        }

        satisfy calibrationReq : CalibrationRequirement {
            subject testSensor :> sensor = sensingUnit.sensor;
        }
    }

    verification def VerifyWavefrontMeasurementAccuracy {
        subject testSensor : ShackHartmannWavefrontSensor;

        in item referenceWavefront : OpticalWavefront {
            :>> wavelength = 632.8[nm];
            :>> intensity = 1.5[mW];
            :>> rmsWavefrontError = 50.0[nm];
            :>> peakValleyError = 200.0[nm];
        }

        objective accuracyObjective {
            doc /* Verify that measured RMS wavefront error is within specified accuracy of known reference. */

            require constraint {
                abs(testSensor.measurementAction.wavefrontMeasurement.rmsError.num - 
                    referenceWavefront.rmsWavefrontError.num) <= testSensor.measurementAccuracy.num
            }
        }
    }

    verification def VerifyCalibrationProcedure {
        subject testSensor : ShackHartmannWavefrontSensor;

        in item flatWavefront : OpticalWavefront {
            :>> wavelength = 632.8[nm];
            :>> intensity = 2.0[mW];
            :>> rmsWavefrontError = 5.0[nm];
            :>> peakValleyError = 15.0[nm];
        }

        objective calibrationObjective {
            doc /* Verify that calibration produces valid reference spot pattern. */

            require constraint {
                testSensor.processor.calibrationData.referencePositions->size() == 
                (testSensor.lensletArray.numberOfLensletsX * testSensor.lensletArray.numberOfLensletsY)
            }
        }
    }

    part testConfiguration : WavefrontSensingUnit :> sensingUnit {
        perform verification verifyAccuracy : VerifyWavefrontMeasurementAccuracy {
            subject :>> testSensor = testConfiguration.sensor;
        }

        perform verification verifyCalibration : VerifyCalibrationProcedure {
            subject :>> testSensor = testConfiguration.sensor;
        }
    }
}
