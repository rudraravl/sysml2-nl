package 'ANPR System' {
    private import ISQ::*;
    private import ISQ::SI::*;
    private import ScalarValues::*;
    
    attribute def TriggerSignal;
    attribute def CaptureCommand;
    attribute def FlashCommand;
    attribute def RawImage;
    attribute def PlateImage;
    attribute def PlateNumber {
        attribute value : String;
    }
    attribute def ConfidenceScore {
        attribute value : Real;
    }
    attribute def Timestamp {
        attribute value : String;
    }
    attribute def Location {
        attribute value : String;
    }
    attribute def VehicleRecord {
        attribute plateNumber : PlateNumber;
        attribute timestamp : Timestamp;
        attribute location : Location;
        attribute confidence : ConfidenceScore;
    }
    attribute def StoreCommand;
    
    part def VehicleDetector {
        attribute minRange : LengthValue = 50 [m];
        port triggerPort {
            out signal : TriggerSignal;
        }
    }
    part def ControlUnit {
        port triggerIn {
            in signal : TriggerSignal;
        }
        port cameraCmdPort {
            out cmd : CaptureCommand;
        }
        port illumCmdPort {
            out cmd : FlashCommand;
        }
        port imageInPort {
            in image : RawImage;
        }
        port imageOutPort {
            out image : RawImage;
        }
        port plateImageInPort {
            in image : PlateImage;
        }
        port plateImageOutPort {
            out image : PlateImage;
        }
        port ocrResultInPort {
            in plateNumber : PlateNumber;
            in confidence : ConfidenceScore;
        }
        port recordOutPort {
            out record : VehicleRecord;
        }
        port dbCmdPort {
            out cmd : StoreCommand;
        }
    }
    part def Camera {
        port cmdInPort {
            in cmd : CaptureCommand;
        }
        port imageOutPort {
            out image : RawImage;
        }
    }
    part def IlluminationUnit {
        port cmdInPort {
            in cmd : FlashCommand;
        }
    }
    part def ImageProcessor {
        port imageInPort {
            in image : RawImage;
        }
        port plateImageOutPort {
            out image : PlateImage;
        }
    }
    part def OCREngine {
        port plateImageInPort {
            in image : PlateImage;
        }
        port ocrResultOutPort {
            out plateNumber : PlateNumber;
            out confidence : ConfidenceScore;
        }
    }
    part def DatabaseManager {
        port recordInPort {
            in record : VehicleRecord;
        }
        port cmdInPort {
            in cmd : StoreCommand;
        }
    }
    
    action def DetectVehicle {
        out signal : TriggerSignal;
    }
    action def CaptureImage {
        in cmd : CaptureCommand;
        out image : RawImage;
    }
    action def Illuminate {
        in cmd : FlashCommand;
    }
    action def ProcessImage {
        in image : RawImage;
        out plateImage : PlateImage;
    }
    action def RecognizePlate {
        in plateImage : PlateImage;
        out plateNumber : PlateNumber;
        out confidence : ConfidenceScore;
    }
    action def CreateRecord {
        in plateNumber : PlateNumber;
        in confidence : ConfidenceScore;
        in timestamp : Timestamp;
        in location : Location;
        out record : VehicleRecord;
    }
    action def StoreRecord {
        in record : VehicleRecord;
        in cmd : StoreCommand;
    }
    action def ANPRProcess {
        in signal : TriggerSignal;
        out record : VehicleRecord;
    }
    
    part anprSystem {
        part vehicleDetector : VehicleDetector;
        part controlUnit : ControlUnit;
        part camera : Camera;
        part illuminationUnit : IlluminationUnit;
        part imageProcessor : ImageProcessor;
        part ocrEngine : OCREngine;
        part databaseManager : DatabaseManager;
        
        connect vehicleDetector.triggerPort to controlUnit.triggerIn;
        connect controlUnit.cameraCmdPort to camera.cmdInPort;
        connect controlUnit.illumCmdPort to illuminationUnit.cmdInPort;
        connect camera.imageOutPort to controlUnit.imageInPort;
        connect controlUnit.imageOutPort to imageProcessor.imageInPort;
        connect imageProcessor.plateImageOutPort to controlUnit.plateImageInPort;
        connect controlUnit.plateImageOutPort to ocrEngine.plateImageInPort;
        connect ocrEngine.ocrResultOutPort to controlUnit.ocrResultInPort;
        connect controlUnit.recordOutPort to databaseManager.recordInPort;
        connect controlUnit.dbCmdPort to databaseManager.cmdInPort;
    }
    
    action anprProcess : ANPRProcess {
        first start;
        then action detectVehicle : DetectVehicle;
        then action captureImage : CaptureImage;
        then action illuminate : Illuminate;
        flow from captureImage.image to processImage.image;
        then action processImage : ProcessImage;
        flow from processImage.plateImage to recognizePlate.plateImage;
        then action recognizePlate : RecognizePlate;
        flow from recognizePlate.plateNumber to createRecord.plateNumber;
        flow from recognizePlate.confidence to createRecord.confidence;
        then action createRecord : CreateRecord;
        flow from createRecord.record to storeRecord.record;
        then action storeRecord : StoreRecord;
        then done;
    }
    
    requirement def ANPRPerformanceRequirement {
        doc /* The ANPR system must complete the process from image capture to recognition in under 500 milliseconds. */
        attribute maxProcessingTime : DurationValue = 500 [ms];
    }
    
    requirement def ANPRAccuracyRequirement {
        doc /* The ANPR system must maintain high accuracy in plate recognition. */
        attribute minConfidence : Real = 0.95;
    }
}
