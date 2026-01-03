package 'IRIS System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
    }

    attribute def IrisFeatures {
        attribute furrowCount : Integer;
        attribute cryptCount : Integer;
        attribute pigmentationPattern : String;
    }

    item def RawIrisImage {
        attribute pixelData : Real[*];
        attribute captureTimestamp : TimeValue;
        attribute imageQuality : Real;
    }

    item def ProcessedIrisTemplate {
        attribute templateData : String;
        attribute featureVector : Real[*];
        attribute confidenceScore : Real;
    }

    item def MatchResult {
        attribute isMatch : Boolean;
        attribute matchScore : Real;
        attribute verificationTime : TimeValue;
    }

    item def IlluminationCommand;
    item def CaptureCommand;
    item def VerificationRequest {
        attribute subjectID : String;
    }

    port def OpticalPort {
        in item illumination : PowerValue;
        out item irisImage : RawIrisImage;
    }

    port def DataPort {
        in item rawImage : RawIrisImage;
        out item template : ProcessedIrisTemplate;
    }

    port def ControlPort {
        in item captureCmd : CaptureCommand;
        in item verifyReq : VerificationRequest;
        out item result : MatchResult;
    }

    part def NIRIlluminator {
        doc /* Near-infrared illuminator for iris imaging. */
        attribute wavelength : LengthValue = 850.0 [nm];
        attribute power : PowerValue;
        
        port lightOutput {
            out attribute irLight : PowerValue;
        }
        
        perform action activateIllumination[*];
    }

    part def OpticalSystem {
        doc /* Optical assembly for iris image capture. */
        attribute focalLength : LengthValue = 50.0 [mm];
        attribute aperture : Real = 2.8;
        
        port opticalInput : OpticalPort;
        port imageOutput {
            out item capturedImage : RawIrisImage;
        }
        
        perform action focusOnIris[*];
        perform action captureIrisImage[*];
    }

    part def ImageSensor {
        doc /* High-resolution image sensor for iris capture. */
        attribute resolution : ImageResolution {
            :>> width = 1280;
            :>> height = 960;
        }
        attribute sensitivity : Real;
        
        port sensorInput {
            in item opticalSignal : PowerValue;
        }
        port imageOut : DataPort;
        
        perform action convertToDigital[*];
    }

    part def ImageProcessor {
        doc /* Processes raw iris images and extracts biometric features. */
        
        port dataIn : DataPort;
        port templateOut {
            out item biometricTemplate : ProcessedIrisTemplate;
        }
        
        perform action enhanceImage[*];
        perform action segmentIris[*];
        perform action normalizeIris[*];
        perform action extractFeatures[*];
        perform action encodeTemplate[*];
    }

    part def TemplateDatabase {
        doc /* Secure storage for iris biometric templates. */
        attribute capacity : Integer = 100000;
        attribute encryptionEnabled : Boolean = true;
        
        port templateAccess {
            in item queryTemplate : ProcessedIrisTemplate;
            out item storedTemplate : ProcessedIrisTemplate;
        }
        
        perform action storeTemplate[*];
        perform action retrieveTemplate[*];
    }

    part def MatchingEngine {
        doc /* Compares iris templates for verification or identification. */
        attribute matchThreshold : Real = 0.90;
        attribute hammingDistanceThreshold : Real = 0.32;
        
        port templateInput {
            in item liveTemplate : ProcessedIrisTemplate;
            in item referenceTemplate : ProcessedIrisTemplate;
        }
        port matchOutput : ControlPort;
        
        perform action compareTemplates[*];
        perform action calculateScore[*];
    }

    part def SystemController {
        doc /* Coordinates iris recognition workflow. */
        
        port controlInterface : ControlPort;
        
        perform action initiateCapture[*];
        perform action coordinateVerification[*];
    }

    action def ActivateNIRLight {
        in powerLevel : PowerValue;
        out illuminationActive : Boolean;
    }

    action def CaptureIrisImage {
        in illumination : PowerValue;
        out rawImage : RawIrisImage;
    }

    action def EnhanceIrisImage {
        in rawImage : RawIrisImage;
        out enhancedImage : RawIrisImage;
    }

    action def SegmentIris {
        in enhancedImage : RawIrisImage;
        out irisRegion : RawIrisImage;
    }

    action def NormalizeIris {
        in irisRegion : RawIrisImage;
        out normalizedIris : RawIrisImage;
    }

    action def ExtractIrisFeatures {
        in normalizedIris : RawIrisImage;
        out features : IrisFeatures;
    }

    action def GenerateTemplate {
        in features : IrisFeatures;
        out template : ProcessedIrisTemplate;
    }

    action def CompareIrisTemplates {
        in liveTemplate : ProcessedIrisTemplate;
        in storedTemplate : ProcessedIrisTemplate;
        out matchScore : Real;
    }

    action def DetermineMatch {
        in matchScore : Real;
        in threshold : Real;
        out isMatch : Boolean;
    }

    state def IrisRecognitionStates {
        entry; then idle;
        
        state idle;
        
        transition idle_to_illuminating
            first idle
            accept cmd : CaptureCommand
            then illuminating;
        
        state illuminating {
            entry; then activateLight;
            state activateLight;
            then done;
        }
        
        transition illuminating_to_capturing
            first illuminating
            then capturing;
        
        state capturing {
            entry; then acquireImage;
            state acquireImage;
            then done;
        }
        
        transition capturing_to_processing
            first capturing
            then processing;
        
        state processing {
            entry; then enhance;
            state enhance;
            then segment;
            state segment;
            then normalize;
            state normalize;
            then extract;
            state extract;
            then encode;
            state encode;
            then done;
        }
        
        transition processing_to_matching
            first processing
            then matching;
        
        state matching {
            entry; then retrieve;
            state retrieve;
            then compare;
            state compare;
            then evaluate;
            state evaluate;
            then done;
        }
        
        transition matching_to_complete
            first matching
            then complete;
        
        state complete;
        
        transition complete_to_idle
            first complete
            then idle;
    }

    action def PerformIrisRecognition {
        doc /* 
        Complete iris recognition workflow from capture to match decision.
        */
        
        first start;
        
        then action illuminate : ActivateNIRLight {
            in powerLevel = 0.1 [W];
            out illuminationActive;
        }
        
        then action capture : CaptureIrisImage {
            in illumination = illuminate.powerLevel;
            out rawImage;
        }
        
        then action enhance : EnhanceIrisImage {
            in rawImage = capture.rawImage;
            out enhancedImage;
        }
        
        then action segment : SegmentIris {
            in enhancedImage = enhance.enhancedImage;
            out irisRegion;
        }
        
        then action normalize : NormalizeIris {
            in irisRegion = segment.irisRegion;
            out normalizedIris;
        }
        
        then action extract : ExtractIrisFeatures {
            in normalizedIris = normalize.normalizedIris;
            out features;
        }
        
        then action generateTemplate : GenerateTemplate {
            in features = extract.features;
            out template;
        }
        
        then action retrieveStored {
            out storedTemplate : ProcessedIrisTemplate;
        }
        
        then action compare : CompareIrisTemplates {
            in liveTemplate = generateTemplate.template;
            in storedTemplate = retrieveStored.storedTemplate;
            out matchScore;
        }
        
        then action determine : DetermineMatch {
            in matchScore = compare.matchScore;
            in threshold = 0.90;
            out isMatch;
        }
        
        then done;
    }

    part def IrisRecognitionSystem {
        doc /* 
        IRIS (Iris Recognition Identification System) captures and analyzes the unique 
        patterns in the human iris to perform biometric verification and identification.
        The system illuminates the eye with near-infrared light, captures a high-resolution 
        image, processes it to extract distinctive iris features, generates a biometric 
        template, and compares it against stored templates to verify identity with high 
        accuracy and speed.
        */
        
        attribute operatingWavelength : LengthValue = 850.0 [nm];
        attribute captureResolution : ImageResolution {
            :>> width = 1280;
            :>> height = 960;
        }
        attribute verificationThreshold : Real = 0.90;
        attribute falseAcceptRate : Real = 0.00001;
        attribute falseRejectRate : Real = 0.0001;
        
        part illuminator : NIRIlluminator {
            :>> wavelength = operatingWavelength;
            :>> power = 0.1 [W];
        }
        
        part optics : OpticalSystem {
            :>> focalLength = 50.0 [mm];
            :>> aperture = 2.8;
        }
        
        part sensor : ImageSensor {
            :>> resolution = captureResolution;
        }
        
        part processor : ImageProcessor;
        
        part database : TemplateDatabase {
            :>> capacity = 100000;
            :>> encryptionEnabled = true;
        }
        
        part matcher : MatchingEngine {
            :>> matchThreshold = verificationThreshold;
        }
        
        part controller : SystemController;
        
        connect illuminator.lightOutput to optics.opticalInput;
        connect optics.imageOutput to sensor.sensorInput;
        connect sensor.imageOut to processor.dataIn;
        connect processor.templateOut to database.templateAccess;
        connect database.templateAccess to matcher.templateInput;
        connect matcher.matchOutput to controller.controlInterface;
        
        perform action recognizeIris[*] ordered references irisRecognition;
        
        exhibit state systemState : IrisRecognitionStates;
    }

    action irisRecognition : PerformIrisRecognition;

    requirement def BiometricAccuracyRequirement {
        doc /* The IRIS system shall achieve high biometric accuracy. */
        
        subject system : IrisRecognitionSystem;
        
        require constraint falseAcceptanceRate {
            doc /* False acceptance rate shall not exceed 0.001%. */
            system.falseAcceptRate <= 0.00001
        }
        
        require constraint falseRejectionRate {
            doc /* False rejection rate shall not exceed 0.01%. */
            system.falseRejectRate <= 0.0001
        }
    }

    requirement def ImageQualityRequirement {
        doc /* The system shall capture iris images of sufficient quality. */
        
        subject sensor : ImageSensor;
        
        require constraint minimumResolution {
            doc /* Image resolution shall be at least 1280x960 pixels. */
            sensor.resolution.width >= 1280 and sensor.resolution.height >= 960
        }
    }

    requirement def ProcessingSpeedRequirement {
        doc /* The system shall process iris recognition within time limits. */
        
        require constraint captureTime {
            doc /* Iris capture shall complete within 2 seconds. */
        }
        
        require constraint verificationTime {
            doc /* Template matching shall complete within 1 second. */
        }
    }

    requirement def SecurityRequirement {
        doc /* The system shall protect biometric data. */
        
        subject database : TemplateDatabase;
        
        require constraint templateEncryption {
            doc /* Biometric templates shall be encrypted. */
            database.encryptionEnabled == true
        }
        
        require constraint livenessDetection {
            doc /* System shall detect and reject presentation attacks. */
        }
    }

    requirement <'IRIS-001'> primaryFunctionRequirement {
        doc /* 
        The IRIS system shall perform automated biometric identification by capturing, 
        processing, and matching unique iris patterns to verify or identify individuals 
        with high accuracy, speed, and security.
        */
        
        subject system : IrisRecognitionSystem;
        
        assume constraint userPresence {
            doc /* User's eye is positioned within capture range. */
        }
        
        assume constraint adequateLighting {
            doc /* Ambient lighting conditions allow NIR imaging. */
        }
        
        require biometricAccuracy : BiometricAccuracyRequirement {
            :>> subject = system;
        }
        
        require imageQuality : ImageQualityRequirement {
            :>> subject = system.sensor;
        }
        
        require processingSpeed : ProcessingSpeedRequirement;
        
        require security : SecurityRequirement {
            :>> subject = system.database;
        }
    }

    part irisRecognitionSystem : IrisRecognitionSystem {
        satisfy primaryFunctionRequirement by recognizeIris;
    }
}
