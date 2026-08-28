package IRIS {
    public import ScalarValues::*;
    public import ISQ::*;

    // ---- Value Types ----
    value def Wavelength :> Real { unit nm; }
    value def FocalLength :> Real { unit mm; }
    value def ResolutionWidth :> Integer;
    value def ResolutionHeight :> Integer;
    value def MatchScore :> Real { unit percent; }
    value def MatchThreshold :> Real { unit percent; }
    value def DatabaseCapacity :> Integer;
    value def TemplateSize :> Integer { unit byte; }
    value def IlluminationIntensity :> Real { unit lux; }

    // ---- Item Definitions ----
    item def RawIrisImage {
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute pixelData : String;
    }

    item def EnhancedImage {
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute qualityMetric : Real;
    }

    item def SegmentedIris {
        attribute irisRadius : Real { unit mm; }
        attribute pupilRadius : Real { unit mm; }
    }

    item def NormalizedIris {
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
    }

    item def BiometricTemplate {
        attribute templateId : String;
        attribute size : TemplateSize;
        attribute featureData : String;
    }

    item def MatchResult {
        attribute score : MatchScore;
        attribute verified : Boolean;
        attribute claimedIdentity : String;
    }

    item def CaptureCommand {
        attribute claimedIdentity : String;
    }

    item def DatabaseQuery {
        attribute identity : String;
    }

    item def DatabaseResponse {
        attribute found : Boolean;
        attribute storedTemplate : BiometricTemplate;
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        out item light : NIRLight;
    }

    item def NIRLight {
        attribute wavelength : Wavelength;
        attribute intensity : IlluminationIntensity;
    }

    port def ImagePort {
        out item image : RawIrisImage;
    }

    port def TemplatePort {
        out item template : BiometricTemplate;
    }

    port def CommandPort {
        in item command : CaptureCommand;
    }

    port def ResultPort {
        out item result : MatchResult;
    }

    port def DatabasePort {
        in item query : DatabaseQuery;
        out item response : DatabaseResponse;
    }

    // ---- Requirements ----
    requirement def IdentificationRequirement {
        doc "The IRIS system shall verify a person's identity by capturing and comparing iris patterns."
    }

    requirement def IlluminationRequirement :> IdentificationRequirement {
        subject illuminator : NIRIlluminator;
        objective {
            illuminator.wavelength == 850 [nm];
        }
        doc "The NIR illuminator shall operate at 850 nm wavelength."
    }

    requirement def CaptureResolutionRequirement :> IdentificationRequirement {
        subject sensor : ImageSensor;
        objective {
            sensor.captureWidth == 1280;
            sensor.captureHeight == 960;
        }
        doc "The image sensor shall capture at 1280x960 pixels."
    }

    requirement def DatabaseCapacityRequirement :> IdentificationRequirement {
        subject database : TemplateDatabase;
        objective {
            database.maxRecords >= 100000;
        }
        doc "The template database shall hold up to 100,000 records."
    }

    requirement def MatchingAccuracyRequirement :> IdentificationRequirement {
        subject matcher : MatchingEngine;
        objective {
            matcher.threshold >= 70 [percent];
        }
        doc "The matching engine shall use a predefined threshold for verification."
    }

    // ---- Parts ----
    part def NIRIlluminator {
        attribute wavelength : Wavelength = 850 [nm];
        attribute intensity : IlluminationIntensity = 50 [lux];
        port opticalOut : OpticalPort;
        exhibit state IlluminatorStateMachine {
            entry; then Off;
            state Off;
            state On;
            transition on_activate
                first Off
                accept ActivateIllumination
                then On;
            transition on_deactivate
                first On
                accept DeactivateIllumination
                then Off;
        }
    }

    part def OpticalSystem {
        attribute focalLength : FocalLength = 25 [mm];
        attribute aperture : Real = 2.8;
        port lightIn : OpticalPort;
        port focusedLightOut : OpticalPort;
    }

    part def ImageSensor {
        attribute captureWidth : ResolutionWidth = 1280;
        attribute captureHeight : ResolutionHeight = 960;
        port lightIn : OpticalPort;
        port imageOut : ImagePort;
        exhibit state SensorStateMachine {
            entry; then Idle;
            state Idle;
            state Capturing;
            transition start_capture
                first Idle
                accept CaptureCommand
                then Capturing;
            transition capture_done
                first Capturing
                accept CaptureComplete
                then Idle;
        }
    }

    part def ImageProcessor {
        port imageIn : ImagePort;
        port templateOut : TemplatePort;
        exhibit state ProcessingStateMachine {
            entry; then Waiting;
            state Waiting;
            state Enhancing;
            state Segmenting;
            state Normalizing;
            state Extracting;
            transition begin_processing
                first Waiting
                accept RawIrisImage
                then Enhancing;
            transition enhanced
                first Enhancing
                accept EnhancedImage
                then Segmenting;
            transition segmented
                first Segmenting
                accept SegmentedIris
                then Normalizing;
            transition normalized
                first Normalizing
                accept NormalizedIris
                then Extracting;
            transition template_created
                first Extracting
                accept BiometricTemplate
                then Waiting;
        }

        action def EnhanceImage {
            in rawImage : RawIrisImage;
            out enhanced : EnhancedImage;
        }

        action def SegmentIris {
            in enhanced : EnhancedImage;
            out segmented : SegmentedIris;
        }

        action def NormalizeIris {
            in segmented : SegmentedIris;
            out normalized : NormalizedIris;
        }

        action def ExtractFeatures {
            in normalized : NormalizedIris;
            out template : BiometricTemplate;
        }
    }

    part def MatchingEngine {
        attribute threshold : MatchThreshold = 75 [percent];
        port liveTemplateIn : TemplatePort;
        port databasePort : DatabasePort;
        port resultOut : ResultPort;
        exhibit state MatchingStateMachine {
            entry; then Ready;
            state Ready;
            state QueryingDatabase;
            state Comparing;
            state Reporting;
            transition begin_match
                first Ready
                accept BiometricTemplate
                then QueryingDatabase;
            transition db_response
                first QueryingDatabase
                accept DatabaseResponse
                then Comparing;
            transition comparison_done
                first Comparing
                accept MatchResult
                then Reporting;
            transition report_sent
                first Reporting
                accept MatchResult
                then Ready;
        }

        action def CompareTemplates {
            in liveTemplate : BiometricTemplate;
            in storedTemplate : BiometricTemplate;
            out score : MatchScore;
            out verified : Boolean;
        }
    }

    part def TemplateDatabase {
        attribute maxRecords : DatabaseCapacity = 100000;
        attribute currentRecords : DatabaseCapacity = 0;
        attribute encrypted : Boolean = true;
        port dbPort : DatabasePort;
        exhibit state DatabaseStateMachine {
            entry; then Connected;
            state Connected;
            state Querying;
            state Responding;
            transition query_received
                first Connected
                accept DatabaseQuery
                then Querying;
            transition query_processed
                first Querying
                accept DatabaseResponse
                then Responding;
            transition response_sent
                first Responding
                accept DatabaseResponse
                then Connected;
        }
    }

    part def SystemController {
        port commandIn : CommandPort;
        port resultOut : ResultPort;
        port illuminatorControl : ~OpticalPort;
        port sensorControl : ~ImagePort;
        port processorControl : ~TemplatePort;
        port matcherControl : ~ResultPort;

        exhibit state ControllerStateMachine {
            entry; then Idle;
            state Idle {
                doc "System awaits a verification command.";
            }
            state Illuminating {
                doc "NIR illuminator activated.";
            }
            state Capturing {
                doc "Image sensor captures iris image.";
            }
            state Processing {
                doc "Image processor generates biometric template.";
            }
            state Matching {
                doc "Matching engine compares live and stored templates.";
            }
            transition command_received
                first Idle
                accept CaptureCommand
                then Illuminating;
            transition illumination_complete
                first Illuminating
                accept NIRLight
                then Capturing;
            transition capture_complete
                first Capturing
                accept RawIrisImage
                then Processing;
            transition processing_complete
                first Processing
                accept BiometricTemplate
                then Matching;
            transition matching_complete
                first Matching
                accept MatchResult
                then Idle;
        }
    }

    // ---- Top-Level Assembly ----
    part def IRISSystem {
        satisfy IdentificationRequirement;

        part controller : SystemController {
            satisfy IdentificationRequirement;
        }
        part illuminator : NIRIlluminator {
            satisfy IlluminationRequirement;
        }
        part optics : OpticalSystem;
        part sensor : ImageSensor {
            satisfy CaptureResolutionRequirement;
        }
        part processor : ImageProcessor;
        part matcher : MatchingEngine {
            satisfy MatchingAccuracyRequirement;
        }
        part database : TemplateDatabase {
            satisfy DatabaseCapacityRequirement;
        }

        connection controller.illuminatorControl to illuminator.opticalOut;
        connection illuminator.opticalOut to optics.lightIn;
        connection optics.focusedLightOut to sensor.lightIn;
        connection sensor.imageOut to processor.imageIn;
        connection processor.templateOut to matcher.liveTemplateIn;
        connection matcher.databasePort to database.dbPort;
        connection matcher.resultOut to controller.resultOut;
    }
}
