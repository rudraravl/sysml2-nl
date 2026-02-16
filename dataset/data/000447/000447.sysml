package EndoscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def IlluminationIntensity :> LuminousIntensityValue;
    attribute def FluidFlowRate :> Real;
    attribute def ArticulationAngle :> Real;
    attribute def ImageFrame;
    attribute def ControlSignal;
    attribute def VideoStream;
    
    port def OpticalOutputPort {
        out imageStream : VideoStream;
    }
    
    port def IlluminationInputPort {
        in intensity : IlluminationIntensity;
    }
    
    port def FluidDeliveryPort {
        in flowRate : FluidFlowRate;
        out pressure : PressureValue;
    }
    
    port def ArticulationControlPort {
        in command : ControlSignal;
        out angle : ArticulationAngle;
    }
    
    port def VideoDisplayPort {
        in videoInput : VideoStream;
        out displayOutput : VideoStream;
    }
    
    part def LightSource {
        attribute maxIntensity : IlluminationIntensity;
        port lightOutput : IlluminationInputPort;
        
        action def ProduceIllumination {
            in powerSetting : Real;
            out lightIntensity : IlluminationIntensity;
        }
    }
    
    part def ImageSensor {
        attribute sensorResolution : ImageResolution;
        attribute frameRate : FrequencyValue;
        port imageOutput : OpticalOutputPort;
        
        action def AcquireImage {
            in illumination : IlluminationIntensity;
            out capturedFrame : ImageFrame;
        }
    }
    
    part def InsertionTube {
        attribute tubeLength : LengthValue;
        attribute outerDiameter : LengthValue;
        
        part fiberOptics {
            attribute fiberCount : Integer;
        }
        
        part workingChannel {
            port fluidPort : FluidDeliveryPort;
        }
        
        part articulationSection {
            attribute bendRange : ArticulationAngle;
            port articulationPort : ArticulationControlPort;
        }
    }
    
    part def ControlConsole {
        port articulationOutput : ArticulationControlPort;
        port videoInput : OpticalOutputPort;
        port displayOutput : VideoDisplayPort;
        
        action def ProcessVideo {
            in rawVideo : VideoStream;
            out enhancedVideo : VideoStream;
        }
        
        action def GenerateControlSignal {
            in userInput : Real;
            out controlCommand : ControlSignal;
        }
    }
    
    part def IrrigationSystem {
        attribute maxFlowRate : FluidFlowRate;
        attribute suctionCapacity : FluidFlowRate;
        port fluidOutput : FluidDeliveryPort;
        
        action def DeliverIrrigation {
            in requestedRate : FluidFlowRate;
            out actualFlow : FluidFlowRate;
        }
        
        action def PerformSuction {
            in suctionPower : Real;
            out extractedVolume : VolumeValue;
        }
    }
    
    part def VideoProcessor {
        attribute processingRate : FrequencyValue;
        port videoIn : OpticalOutputPort;
        port videoOut : VideoDisplayPort;
        
        action def EnhanceImageQuality {
            in rawImage : ImageFrame;
            out processedImage : ImageFrame;
        }
    }
    
    part def Endoscope {
        part lightSource : LightSource {
            attribute maxIntensity = 8000.0 [cd];
        }
        
        part imageSensor : ImageSensor {
            attribute sensorResolution = ImageResolution {
                width = 1920;
                height = 1080;
            }
            attribute frameRate = 60.0 [Hz];
        }
        
        part insertionTube : InsertionTube {
            attribute tubeLength = 1200.0 [mm];
            attribute outerDiameter = 9.5 [mm];
            
            part articulationSection {
                attribute bendRange = 210.0;
            }
        }
        
        part controlConsole : ControlConsole;
        
        part irrigationSystem : IrrigationSystem {
            attribute maxFlowRate = 400.0;
            attribute suctionCapacity = 300.0;
        }
        
        part videoProcessor : VideoProcessor {
            attribute processingRate = 60.0 [Hz];
        }
        
        connection illuminationPath connect lightSource.lightOutput to insertionTube.fiberOptics;
        connection imageAcquisition connect insertionTube.fiberOptics to imageSensor.imageOutput;
        connection videoToProcessor connect imageSensor.imageOutput to videoProcessor.videoIn;
        connection processedVideo connect videoProcessor.videoOut to controlConsole.displayOutput;
        connection fluidDelivery connect irrigationSystem.fluidOutput to insertionTube.workingChannel.fluidPort;
        connection articulationControl connect controlConsole.articulationOutput to insertionTube.articulationSection.articulationPort;
        
        perform action performEndoscopicProcedure;
    }
    
    action def PerformEndoscopicProcedure {
        in targetAnatomicalSite : String;
        out procedureImages : ImageFrame[*];
        out diagnosticFindings : String;
    }
    
    action performEndoscopicProcedure : PerformEndoscopicProcedure {
        doc /* Primary function: Enable minimally invasive visual examination and therapeutic 
               intervention within internal body structures through real-time video imaging. */
        
        first start;
        
        then action initializeEndoscope {
            action activateLight {
                out lightReady : Boolean;
            }
            then action calibrateSensor {
                out sensorReady : Boolean;
            }
            then action primeFluidSystem {
                out systemReady : Boolean;
            }
        }
        
        then action insertScope {
            action navigateToSite {
                in articulationCommands : ArticulationAngle[*];
                out currentDepth : LengthValue;
            }
            then action optimizeIllumination {
                in tissueReflectance : Real;
                out adjustedIntensity : IlluminationIntensity;
            }
        }
        
        then merge procedureLoop;
        
        then action conductExamination {
            action acquireVideoFeed {
                out liveVideo : VideoStream;
            }
            
            flow acquireVideoFeed.liveVideo to enhanceVideo.rawInput;
            
            action enhanceVideo {
                in rawInput : VideoStream;
                out enhancedOutput : VideoStream;
            }
            
            flow enhanceVideo.enhancedOutput to evaluateImages.videoData;
            
            action evaluateImages {
                in videoData : VideoStream;
                out assessment : String;
            }
            
            then decide;
                if evaluateImages.assessment == "intervention_needed" then performTherapy;
                if evaluateImages.assessment == "reposition_required" then adjustPosition;
                if evaluateImages.assessment == "examination_complete" then concludeProcedure;
        }
        
        action performTherapy {
            action irrigateArea {
                in rate : FluidFlowRate;
                out clearedRegion : Boolean;
            }
            then action applySuction {
                in power : Real;
                out removedFluid : VolumeValue;
            }
            then action documentIntervention {
                out interventionRecord : ImageFrame;
            }
        }
        then procedureLoop;
        
        action adjustPosition {
            action articulateTip {
                in targetAngle : ArticulationAngle;
                out achievedAngle : ArticulationAngle;
            }
            then action advanceOrWithdraw {
                in movement : LengthValue;
                out newPosition : LengthValue;
            }
        }
        then procedureLoop;
        
        action concludeProcedure {
            action captureDocumentation {
                in allFrames : ImageFrame[*];
                out procedureReport : String;
            }
            then action withdrawScope {
                out withdrawalComplete : Boolean;
            }
        }
        
        then done;
    }
    
    requirement def EndoscopeRequirements {
        doc /* System requirements for endoscope performance, safety, and functionality. */
        
        requirement imageResolutionRequirement {
            doc /* The endoscope shall provide high-definition video with minimum resolution 
                   of 1920x1080 pixels at 60 frames per second. */
            
            subject sensor : ImageSensor;
            
            require constraint {
                sensor.sensorResolution.width >= 1920 and 
                sensor.sensorResolution.height >= 1080 and
                sensor.frameRate >= 60.0 [Hz]
            }
        }
        
        requirement illuminationRequirement {
            doc /* The system shall provide adjustable illumination with intensity 
                   range from 500 to 8000 candela. */
            
            subject light : LightSource;
            
            require constraint {
                light.maxIntensity >= 500.0 [cd] and 
                light.maxIntensity <= 8000.0 [cd]
            }
        }
        
        requirement articulationRequirement {
            doc /* The distal tip shall articulate at least 210 degrees in 
                   four directions for comprehensive visualization. */
            
            subject tube : InsertionTube;
            
            require constraint {
                tube.articulationSection.bendRange >= 210.0
            }
        }
        
        requirement fluidManagementRequirement {
            doc /* The system shall deliver irrigation at rates up to 400 mL/min 
                   and provide suction at rates up to 300 mL/min. */
            
            subject irrigation : IrrigationSystem;
            
            require constraint {
                irrigation.maxFlowRate >= 400.0 and
                irrigation.suctionCapacity >= 300.0
            }
        }
        
        requirement insertionTubeDiameterRequirement {
            doc /* The insertion tube outer diameter shall not exceed 10 mm 
                   to minimize patient trauma. */
            
            subject tube : InsertionTube;
            
            require constraint {
                tube.outerDiameter <= 10.0 [mm]
            }
        }
        
        requirement biocompatibilityRequirement {
            doc /* All patient-contact surfaces shall be biocompatible and 
                   either sterilizable or single-use disposable. */
        }
    }
    
    requirement endoscopeSystemRequirements : EndoscopeRequirements {
        subject endoscope : Endoscope;
    }
}
