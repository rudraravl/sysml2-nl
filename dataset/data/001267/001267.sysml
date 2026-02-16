package StructuredLight3DScanner {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    enum def PatternType {
        grayCode;
        phaseShift;
        binaryCode;
        sinusoidal;
    }

    enum def ScanState {
        idle;
        calibrating;
        projecting;
        capturing;
        processing;
        complete;
        error;
    }

    attribute def Resolution {
        attribute width : Integer;
        attribute height : Integer;
    }

    attribute def ScanVolume {
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute depth : LengthValue;
    }

    item def LightPattern {
        attribute patternType : PatternType;
        attribute intensity : Real;
        attribute frequency : FrequencyValue;
    }

    item def CapturedImage {
        attribute resolution : Resolution;
        attribute timestamp : TimeValue;
        attribute exposureTime : TimeValue;
    }

    item def PointCloud {
        attribute numberOfPoints : Integer;
        attribute accuracy : LengthValue;
        attribute timestamp : TimeValue;
    }

    port def OpticalOutputPort {
        out projectedPattern : LightPattern;
    }

    port def OpticalInputPort {
        in reflectedPattern : LightPattern;
    }

    port def DataOutputPort {
        out pointCloudData : PointCloud;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    part def Projector {
        attribute power : PowerValue;
        attribute resolution : Resolution;
        port opticalOut : OpticalOutputPort;
        
        perform action projectPattern {
            in patternType : PatternType;
            out pattern : LightPattern;
            
            first start;
            then action generatePattern {
                in pType : PatternType = patternType;
                out p : LightPattern;
            }
            then done;
        }
    }

    part def Camera {
        attribute resolution : Resolution;
        attribute frameRate : FrequencyValue;
        attribute sensitivity : Real;
        port opticalIn : OpticalInputPort;
        
        perform action captureImage {
            in reflectedLight : LightPattern;
            out image : CapturedImage;
            
            first start;
            then action acquire {
                in rLight : LightPattern = reflectedLight;
                out img : CapturedImage;
            }
            then done;
        }
    }

    part def ProcessingUnit {
        attribute computePower : Real;
        attribute memoryCapacity : Real;
        
        perform action triangulate {
            in leftImage : CapturedImage;
            in rightImage : CapturedImage;
            in projectionData : LightPattern;
            out cloud : PointCloud;
            
            first start;
            then action decodePattern {
                in lImg : CapturedImage = leftImage;
                in rImg : CapturedImage = rightImage;
            }
            then action computeDepth {
                in pData : LightPattern = projectionData;
            }
            then action generatePoints {
                out c : PointCloud;
            }
            then done;
        }
        
        perform action calibrate {
            in calibrationPattern : LightPattern;
            out calibrationMatrix : Real;
            
            first start;
            then action computeIntrinsics;
            then action computeExtrinsics;
            then action optimizeParameters {
                out cMatrix : Real;
            }
            then done;
        }
    }

    part def StructuredLightScanner {
        attribute scanResolution : Resolution {
            attribute :>> width = 1920;
            attribute :>> height = 1080;
        }
        attribute depthAccuracy : LengthValue = 0.0005 [m];
        attribute scanVolume : ScanVolume {
            attribute :>> width = 0.3 [m];
            attribute :>> height = 0.3 [m];
            attribute :>> depth = 0.5 [m];
        }
        attribute baselineDistance : LengthValue = 0.15 [m];
        attribute workingDistance : LengthValue = 0.8 [m];
        
        port controlInterface : ControlPort;
        port dataOutput : DataOutputPort;
        
        part projector : Projector {
            attribute :>> power = 50 [W];
            attribute :>> resolution = scanResolution;
        }
        
        part leftCamera : Camera {
            attribute :>> resolution = scanResolution;
            attribute :>> frameRate = 60 [Hz];
            attribute :>> sensitivity = 0.9;
        }
        
        part rightCamera : Camera {
            attribute :>> resolution = scanResolution;
            attribute :>> frameRate = 60 [Hz];
            attribute :>> sensitivity = 0.9;
        }
        
        part processor : ProcessingUnit {
            attribute :>> computePower = 100.0;
            attribute :>> memoryCapacity = 16000.0;
        }
        
        connection projectorToScene connect projector.opticalOut to leftCamera.opticalIn;
        connection sceneToLeftCamera connect projector.opticalOut to leftCamera.opticalIn;
        connection sceneToRightCamera connect projector.opticalOut to rightCamera.opticalIn;
        
        perform action scanObject {
            out finalCloud : PointCloud;
            
            first start;
            then action initializeSystem;
            then action performCalibration : ProcessingUnit::calibrate {
                in calibrationPattern : LightPattern;
                out calibrationMatrix : Real;
            }
            then decide;
                if performCalibration.calibrationMatrix > 0.0 then proceedToScan;
                if performCalibration.calibrationMatrix <= 0.0 then abortScan;
            
            action proceedToScan {
                first begin;
                then merge scanLoop;
                
                merge scanLoop;
                then action projectStructuredLight : Projector::projectPattern {
                    in patternType = PatternType::grayCode;
                    out pattern : LightPattern;
                }
                then fork captureFromBothCameras;
                
                action captureLeft : Camera::captureImage {
                    in reflectedLight = projectStructuredLight.pattern;
                    out image : CapturedImage;
                }
                
                action captureRight : Camera::captureImage {
                    in reflectedLight = projectStructuredLight.pattern;
                    out image : CapturedImage;
                }
                
                then join processImages;
                
                action processImages : ProcessingUnit::triangulate {
                    in leftImage = captureLeft.image;
                    in rightImage = captureRight.image;
                    in projectionData = projectStructuredLight.pattern;
                    out cloud : PointCloud;
                }
                then decide;
                    if processImages.cloud.numberOfPoints >= 100000 then outputResult;
                    if processImages.cloud.numberOfPoints < 100000 then scanLoop;
                
                action outputResult {
                    out fCloud : PointCloud = processImages.cloud;
                }
                then done;
            }
            
            action abortScan {
                first begin;
                then done;
            }
            
            then done;
        }
        
        state scannerStateMachine {
            entry; then idle;
            
            state idle;
            accept at when scanObject.initializeSystem then calibrating;
            
            state calibrating;
            accept at when scanObject.performCalibration then projecting;
            
            state projecting;
            accept at when scanObject.projectStructuredLight then capturing;
            
            state capturing;
            accept at when scanObject.captureLeft then processing;
            
            state processing;
            accept at when scanObject.processImages then complete;
            
            state complete;
            accept at when scanObject.outputResult then idle;
            
            state error;
            accept at when scanObject.abortScan then idle;
        }
    }

    constraint def AccuracyConstraint {
        in requiredAccuracy : LengthValue;
        in achievedAccuracy : LengthValue;
        achievedAccuracy <= requiredAccuracy
    }

    constraint def VolumeConstraint {
        in minWidth : LengthValue;
        in minHeight : LengthValue;
        in minDepth : LengthValue;
        in actualWidth : LengthValue;
        in actualHeight : LengthValue;
        in actualDepth : LengthValue;
        (actualWidth >= minWidth) and (actualHeight >= minHeight) and (actualDepth >= minDepth)
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall reconstruct three-dimensional surface geometry 
             * of physical objects by projecting structured light patterns onto 
             * the object surface, capturing the deformed patterns using stereo 
             * cameras, and computing depth information through triangulation 
             * to generate accurate point cloud representations. */
        subject scanner : StructuredLightScanner;
    }

    requirement <'REQ-001'> accuracyRequirement {
        doc /* The system shall achieve depth measurement accuracy 
             * of 0.5 mm or better within the specified working volume. */
        subject scanner : StructuredLightScanner;
        assert constraint : AccuracyConstraint {
            in requiredAccuracy = 0.0005 [m];
            in achievedAccuracy = scanner.depthAccuracy;
        }
    }

    requirement <'REQ-002'> resolutionRequirement {
        doc /* The system shall capture point clouds with minimum 
             * resolution of 1920x1080 points per scan. */
        subject scanner : StructuredLightScanner;
        require constraint {
            scanner.scanResolution.width >= 1920 and
            scanner.scanResolution.height >= 1080
        }
    }

    requirement <'REQ-003'> volumeRequirement {
        doc /* The system shall accommodate objects within a working 
             * volume of at least 300mm x 300mm x 500mm. */
        subject scanner : StructuredLightScanner;
        assert constraint : VolumeConstraint {
            in minWidth = 0.3 [m];
            in minHeight = 0.3 [m];
            in minDepth = 0.5 [m];
            in actualWidth = scanner.scanVolume.width;
            in actualHeight = scanner.scanVolume.height;
            in actualDepth = scanner.scanVolume.depth;
        }
    }

    requirement <'REQ-004'> performanceRequirement {
        doc /* The system shall complete a full scan cycle including 
             * pattern projection, image capture, and point cloud 
             * generation within 5 seconds. */
        subject scanner : StructuredLightScanner;
    }

    part scanner3D : StructuredLightScanner;

    satisfy PrimaryFunctionRequirement by scanner3D.scanObject;
    satisfy accuracyRequirement by scanner3D;
    satisfy resolutionRequirement by scanner3D;
    satisfy volumeRequirement by scanner3D;
    satisfy performanceRequirement by scanner3D.scanObject;
}
