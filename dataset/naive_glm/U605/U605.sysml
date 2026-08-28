package ANPR_System {
    import ISQ::Distance;
    import ISQ::Time;
    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::String;

    // Value Types
    attribute def Distance_m :> Distance { unit 'm'; }
    attribute def Duration_ms :> Time { unit 'ms'; }
    attribute def Confidence :> Real;
    
    // Items
    item def Image;
    item def PlateImage :> Image;
    item def PlateText;
    item def VehicleRecord {
        attribute plateNumber : PlateText;
        attribute timestamp : String;
        attribute location : String;
        attribute confidence : Confidence;
    }

    // Ports
    port def TriggerOut { out trigger : Boolean; }
    port def TriggerIn { in trigger : Boolean; }
    port def CommandOut { out capture : Boolean; out illuminate : Boolean; }
    port def CommandIn { in capture : Boolean; in illuminate : Boolean; }
    port def ImageOut { out image : Image; }
    port def ImageIn { in image : Image; }
    port def PlateImageOut { out plateImage : PlateImage; }
    port def PlateImageIn { in plateImage : PlateImage; }
    port def TextOut { out plateText : PlateText; out confidence : Confidence; }
    port def TextIn { in plateText : PlateText; in confidence : Confidence; }
    port def RecordOut { out record : VehicleRecord; }
    port def RecordIn { in record : VehicleRecord; }

    // Requirements
    requirement def DetectionRangeReq {
        doc /* The vehicle detector must have a range of at least 50 meters. */
        attribute minRange : Distance_m = 50 [m];
        require constraint { detectorRange >= minRange }
    }
    requirement def ProcessingTimeReq {
        doc /* The entire process from image capture to recognition must be completed in under 500 milliseconds. */
        attribute maxDuration : Duration_ms = 500 [ms];
        require constraint { processingTime < maxDuration }
    }
    requirement def AccuracyReq {
        doc /* The system must be highly accurate. */
        attribute minConfidence : Confidence = 0.95;
        require constraint { ocrConfidence >= minConfidence }
    }

    // Parts
    part def VehicleDetector {
        attribute range : Distance_m = 60 [m];
        port triggerPort : TriggerOut;
        satisfy DetectionRangeReq;
    }

    part def ControlUnit {
        port triggerInPort : TriggerIn;
        port cameraCmdPort : CommandOut;
        port illuminationCmdPort : CommandOut;
        port ocrTextInPort : TextIn;
        port dbRecordOutPort : RecordOut;
        
        exhibit state def ControlBehavior {
            state Idle;
            state Processing;
            transition Idle to Processing when triggerInPort.trigger == true {
                action sendCommands {
                    cameraCmdPort.capture = true;
                    illuminationCmdPort.illuminate = true;
                }
            }
            transition Processing to Idle when ocrTextInPort.plateText != null {
                action createRecord {
                    dbRecordOutPort.record.plateNumber = ocrTextInPort.plateText;
                    dbRecordOutPort.record.confidence = ocrTextInPort.confidence;
                    dbRecordOutPort.record.timestamp = "now";
                    dbRecordOutPort.record.location = "Toll Plaza A";
                }
            }
        }
    }

    part def Camera {
        port cmdInPort : CommandIn;
        port imageOutPort : ImageOut;
        exhibit action def CaptureImage {
            in cmd : Boolean;
            out img : Image;
        }
    }

    part def IlluminationUnit {
        port cmdInPort : CommandIn;
        exhibit action def Flash {
            in cmd : Boolean;
        }
    }

    part def ImageProcessor {
        port imageInPort : ImageIn;
        port plateImageOutPort : PlateImageOut;
        
        exhibit action def ProcessImage {
            in rawImage : Image;
            out plateImg : PlateImage;
            
            action enhanceContrast {
                in img = rawImage;
                out enhancedImg : Image;
            }
            action findPlateRegion {
                in img = enhanceContrast.enhancedImg;
                out region : String; 
            }
            action cropPlate {
                in img = enhanceContrast.enhancedImg;
                in region = findPlateRegion.region;
                out croppedImg = plateImg;
            }
        }
    }

    part def OCREngine {
        port plateImageInPort : PlateImageIn;
        port textOutPort : TextOut;
        
        exhibit state def OCREngineBehavior {
            state Waiting;
            state Recognizing;
            transition Waiting to Recognizing when plateImageInPort.plateImage != null;
            transition Recognizing to Waiting {
                action segmentCharacters {
                    in img = plateImageInPort.plateImage;
                    out chars : String;
                }
                action identifyCharacters {
                    in chars = segmentCharacters.chars;
                    out text : PlateText;
                }
                action validateFormat {
                    in text = identifyCharacters.text;
                    out valid : Boolean;
                }
                action calculateConfidence {
                    in text = identifyCharacters.text;
                    out conf : Confidence;
                }
                action outputResults {
                    textOutPort.plateText = identifyCharacters.text;
                    textOutPort.confidence = calculateConfidence.conf;
                }
            }
        }
    }

    part def DatabaseManager {
        port recordInPort : RecordIn;
        exhibit action def StoreRecord {
            in rec : VehicleRecord;
        }
    }

    // System Assembly
    part def ANPRSystem {
        part detector : VehicleDetector;
        part controller : ControlUnit;
        part camera : Camera;
        part illuminator : IlluminationUnit;
        part imageProcessor : ImageProcessor;
        part ocrEngine : OCREngine;
        part dbManager : DatabaseManager;
        
        attribute processingTime : Duration_ms = 450 [ms];
        attribute ocrConfidence : Confidence = 0.98;
        
        satisfy ProcessingTimeReq;
        satisfy AccuracyReq;
        
        connection detector.triggerPort to controller.triggerInPort;
        connection controller.cameraCmdPort to camera.cmdInPort;
        connection controller.illuminationCmdPort to illuminator.cmdInPort;
        connection camera.imageOutPort to imageProcessor.imageInPort;
        connection imageProcessor.plateImageOutPort to ocrEngine.plateImageInPort;
        connection ocrEngine.textOutPort to controller.ocrTextInPort;
        connection controller.dbRecordOutPort to dbManager.recordInPort;
    }
}
