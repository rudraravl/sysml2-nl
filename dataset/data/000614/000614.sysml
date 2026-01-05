package FotofinderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientID :> String;
    
    attribute def ImageResolution {
        attribute width : Natural;
        attribute height : Natural;
    }
    
    attribute def Timestamp :> String;
    
    attribute def BodyRegion {
        attribute regionName : String;
        attribute orientation : String;
    }
    
    item def DermatologicalImage {
        attribute patientID : PatientID;
        attribute timestamp : Timestamp;
        attribute region : BodyRegion;
        attribute resolution : ImageResolution;
        attribute imageData : String;
    }
    
    item def ImagingSession {
        attribute sessionID : String;
        attribute patientID : PatientID;
        attribute sessionDate : Timestamp;
        attribute capturedImages : DermatologicalImage[*];
    }
    
    item def AnalysisResult {
        attribute sessionID : String;
        attribute detectedLesions : Natural;
        attribute riskAssessment : String;
    }
    
    port def ImageCapturePort {
        out image : DermatologicalImage;
    }
    
    port def ImageProcessingPort {
        in rawImage : DermatologicalImage;
        out processedImage : DermatologicalImage;
    }
    
    port def DataStoragePort {
        in session : ImagingSession;
        out retrievedSession : ImagingSession;
    }
    
    port def AnalysisPort {
        in image : DermatologicalImage;
        out result : AnalysisResult;
    }
    
    port def PowerPort {
        in power : ISQ::PowerValue;
    }
    
    action def CaptureBodyRegion {
        in region : BodyRegion;
        in patientID : PatientID;
        out capturedImage : DermatologicalImage;
    }
    
    action def ProcessImage {
        in rawImage : DermatologicalImage;
        out enhancedImage : DermatologicalImage;
    }
    
    action def AnalyzeSkin {
        in image : DermatologicalImage;
        out analysis : AnalysisResult;
    }
    
    action def StoreSession {
        in session : ImagingSession;
    }
    
    action def GenerateReport {
        in session : ImagingSession;
        in analyses : AnalysisResult[*];
        out reportPath : String;
    }
    
    part def HighResolutionCamera {
        attribute maxResolution : ImageResolution {
            attribute width = 6000;
            attribute height = 4000;
        }
        attribute sensorSize : LengthValue;
        port capturePort : ImageCapturePort;
        port powerIn : PowerPort;
        perform action capture : CaptureBodyRegion;
    }
    
    part def IlluminationUnit {
        attribute lightIntensity : ISQ::LuminousIntensityValue;
        attribute colorTemperature : ISQ::ThermodynamicTemperatureValue;
        port powerIn : PowerPort;
    }
    
    part def ImageProcessingUnit {
        attribute processingSpeed : ISQ::FrequencyValue;
        port imageInput : ImageProcessingPort;
        port powerIn : PowerPort;
        perform action process : ProcessImage;
    }
    
    part def AIAnalysisEngine {
        attribute modelVersion : String;
        attribute accuracy : Real;
        port analysisPort : AnalysisPort;
        port powerIn : PowerPort;
        perform action analyze : AnalyzeSkin;
    }
    
    part def DataStorageSystem {
        attribute storageCapacity : ISQ::MassValue;
        attribute usedCapacity : ISQ::MassValue;
        port storagePort : DataStoragePort;
        port powerIn : PowerPort;
    }
    
    part def ControlComputer {
        attribute operatingSystem : String;
        attribute memory : ISQ::MassValue;
        port powerIn : PowerPort;
    }
    
    part def UserInterface {
        attribute displaySize : LengthValue;
        attribute touchEnabled : Boolean;
        port powerIn : PowerPort;
    }
    
    state def FotofinderOperationalStates {
        entry; then idle;
        
        state idle;
        transition idle_to_initializing
            first idle
            accept SystemPowerOn
            then initializing;
        
        state initializing;
        transition initializing_to_ready
            first initializing
            then ready;
        
        state ready;
        transition ready_to_sessionStarted
            first ready
            accept StartImagingSession
            then sessionStarted;
        
        state sessionStarted;
        transition sessionStarted_to_capturing
            first sessionStarted
            then capturing;
        
        state capturing;
        transition capturing_to_processing
            first capturing
            then processing;
        
        state processing;
        transition processing_to_analyzing
            first processing
            then analyzing;
        
        state analyzing;
        transition analyzing_to_storing
            first analyzing
            then storing;
        
        state storing;
        transition storing_to_reportGeneration
            first storing
            then reportGeneration;
        
        state reportGeneration;
        transition reportGeneration_to_ready
            first reportGeneration
            then ready;
        
        transition ready_to_shutdown
            first ready
            accept SystemPowerOff
            then shutdown;
        
        state shutdown;
        transition shutdown_to_done
            first shutdown
            then done;
    }
    
    part def Fotofinder {
        doc /*
            The Fotofinder is an advanced dermatological imaging system designed for 
            comprehensive total body photography and automated skin lesion detection.
            It captures high-resolution images of the entire body surface, processes 
            them using AI-powered analysis, and stores the results for longitudinal 
            patient monitoring and early melanoma detection.
        */
        
        attribute systemID : String;
        attribute firmwareVersion : String;
        attribute calibrationDate : Timestamp;
        
        part camera : HighResolutionCamera {
            attribute maxResolution : ImageResolution {
                attribute width = 6000;
                attribute height = 4000;
            }
            attribute sensorSize = 35.0 [mm];
        }
        
        part illumination : IlluminationUnit {
            attribute lightIntensity = 1000.0 [cd];
            attribute colorTemperature = 5500.0 [K];
        }
        
        part processor : ImageProcessingUnit {
            attribute processingSpeed = 2.5 [GHz];
        }
        
        part aiEngine : AIAnalysisEngine {
            attribute modelVersion = "v3.2.1";
            attribute accuracy = 0.95;
        }
        
        part storage : DataStorageSystem {
            attribute storageCapacity = 10.0 [kg];
            attribute usedCapacity = 2.5 [kg];
        }
        
        part computer : ControlComputer {
            attribute operatingSystem = "Medical OS";
            attribute memory = 32.0 [kg];
        }
        
        part ui : UserInterface {
            attribute displaySize = 27.0 [in];
            attribute touchEnabled = true;
        }
        
        connection cameraToProcessor connect 
            camera.capturePort to processor.imageInput;
        
        connection processorToAI connect 
            processor to aiEngine.analysisPort;
        
        connection aiToStorage connect 
            aiEngine to storage.storagePort;
        
        perform action executeTotalBodyMapping : ExecuteTotalBodyMapping;
        
        exhibit state machine systemStates : FotofinderOperationalStates;
    }
    
    action def ExecuteTotalBodyMapping {
        in patientID : PatientID;
        out completedSession : ImagingSession;
        
        private attribute session : ImagingSession;
        private attribute capturedImages : DermatologicalImage[*] := ( );
        private attribute analysisResults : AnalysisResult[*] := ( );
        
        first start;
        then action initializeSession {
            assign session.sessionID := "SESSION_" + patientID;
            assign session.patientID := patientID;
        }
        
        then action captureAnteriorTorso : CaptureBodyRegion {
            in region.regionName = "Anterior Torso";
            in region.orientation = "Front";
            in patientID = patientID;
            out capturedImage;
        }
        then assign capturedImages := capturedImages->including(captureAnteriorTorso.capturedImage);
        
        then action capturePosteriorTorso : CaptureBodyRegion {
            in region.regionName = "Posterior Torso";
            in region.orientation = "Back";
            in patientID = patientID;
            out capturedImage;
        }
        then assign capturedImages := capturedImages->including(capturePosteriorTorso.capturedImage);
        
        then action captureLeftSide : CaptureBodyRegion {
            in region.regionName = "Left Side";
            in region.orientation = "Left";
            in patientID = patientID;
            out capturedImage;
        }
        then assign capturedImages := capturedImages->including(captureLeftSide.capturedImage);
        
        then action captureRightSide : CaptureBodyRegion {
            in region.regionName = "Right Side";
            in region.orientation = "Right";
            in patientID = patientID;
            out capturedImage;
        }
        then assign capturedImages := capturedImages->including(captureRightSide.capturedImage);
        
        then merge processImages;
        
        then action processAllCapturedImages {
            for capturedImage in capturedImages {
                perform action enhanceImage : ProcessImage {
                    in rawImage = capturedImage;
                    out enhancedImage;
                }
                then perform action analyzeImage : AnalyzeSkin {
                    in image = enhanceImage.enhancedImage;
                    out analysis;
                }
                then assign analysisResults := analysisResults->including(analyzeImage.analysis);
            }
        }
        
        then action finalizeSession {
            assign session.capturedImages := capturedImages;
            assign completedSession := session;
        }
        
        then action storeSessionData : StoreSession {
            in session = completedSession;
        }
        
        then action generateReport : GenerateReport {
            in session = completedSession;
            in analyses = analysisResults;
            out reportPath;
        }
        
        then done;
    }
    
    requirement def FotofinderSystemRequirements {
        doc /*
            The Fotofinder system shall provide comprehensive dermatological imaging 
            capabilities for total body photography and automated lesion detection.
        */
        
        requirement <'FR-1'> totalBodyCapture {
            doc /*
                The system shall capture high-resolution images of all major body regions 
                including anterior, posterior, left, and right views.
            */
        }
        
        requirement <'FR-2'> imageQuality {
            doc /*
                The system shall capture images with minimum resolution of 6000x4000 pixels 
                to enable detailed lesion analysis.
            */
        }
        
        requirement <'FR-3'> automatedAnalysis {
            doc /*
                The system shall automatically analyze captured images using AI algorithms 
                to detect and classify skin lesions with minimum 95% accuracy.
            */
        }
        
        requirement <'FR-4'> dataStorage {
            doc /*
                The system shall store complete imaging sessions including all captured 
                images, analysis results, and patient metadata for longitudinal tracking.
            */
        }
        
        requirement <'FR-5'> illumination {
            doc /*
                The system shall provide consistent, calibrated illumination at 5500K 
                color temperature to ensure reproducible imaging conditions.
            */
        }
        
        requirement <'NFR-1'> sessionDuration {
            doc /*
                The system shall complete a full total body mapping session including 
                capture, processing, and analysis within 10 minutes.
            */
        }
        
        requirement <'NFR-2'> storageCapacity {
            doc /*
                The system shall support storage of at least 1000 complete imaging 
                sessions with associated analysis data.
            */
        }
    }
    
    requirement fotofinderSystemRequirement : FotofinderSystemRequirements {
        subject fotofinderSystem : Fotofinder;
        
        require totalBodyCapture;
        require imageQuality;
        require automatedAnalysis;
        require dataStorage;
        require illumination;
        require sessionDuration;
        require storageCapacity;
    }
    
    part fotofinderSystem : Fotofinder {
        attribute systemID = "FF-2024-001";
        attribute firmwareVersion = "v4.5.2";
        attribute calibrationDate = "2024-01-15";
        
        perform executeTotalBodyMapping.initializeSession by computer;
        perform executeTotalBodyMapping.captureAnteriorTorso by camera;
        perform executeTotalBodyMapping.capturePosteriorTorso by camera;
        perform executeTotalBodyMapping.captureLeftSide by camera;
        perform executeTotalBodyMapping.captureRightSide by camera;
        perform executeTotalBodyMapping.processAllCapturedImages by processor;
        perform executeTotalBodyMapping.storeSessionData by storage;
        perform executeTotalBodyMapping.generateReport by computer;
    }
}
