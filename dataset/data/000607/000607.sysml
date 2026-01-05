package FetoscopySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def IlluminationIntensity :> Real;
    
    item def OpticalSignal {
        attribute wavelength : LengthValue;
        attribute intensity : IlluminationIntensity;
    }
    
    item def VideoFrame {
        attribute resolution : ImageResolution;
        attribute timestamp : TimeValue;
    }
    
    item def ControlCommand {
        attribute illuminationLevel : IlluminationIntensity;
        attribute focusAdjustment : Real;
    }
    
    item def AmnioticFluid {
        attribute flowRate : VolumetricFlowValue;
        attribute pressure : PressureValue;
    }
    
    port def OpticalInputPort {
        in item signal : OpticalSignal;
    }
    
    port def OpticalOutputPort {
        out item signal : OpticalSignal;
    }
    
    port def VideoOutputPort {
        out item videoFrame : VideoFrame;
    }
    
    port def VideoInputPort {
        in item videoFrame : VideoFrame;
    }
    
    port def ControlInputPort {
        in item command : ControlCommand;
    }
    
    port def FluidInputPort {
        in item fluid : AmnioticFluid;
    }
    
    port def FluidOutputPort {
        out item fluid : AmnioticFluid;
    }
    
    part def LightSource {
        attribute powerOutput : PowerValue;
        attribute wavelengthRange : LengthValue[2];
        port lightOut : OpticalOutputPort;
        port controlIn : ControlInputPort;
    }
    
    part def Fetoscope {
        attribute insertionDiameter : LengthValue;
        attribute workingLength : LengthValue;
        
        port lightIn : OpticalInputPort;
        port videoOut : VideoOutputPort;
        port fluidIn : FluidInputPort;
        port fluidOut : FluidOutputPort;
        port controlIn : ControlInputPort;
        
        part opticalSystem {
            part objectiveLens {
                attribute focalLength : LengthValue;
            }
            part imagingFibers {
                attribute fiberCount : Integer;
            }
        }
        
        part workingChannel {
            attribute channelDiameter : LengthValue;
        }
    }
    
    part def CameraHead {
        attribute sensorType : String;
        attribute sensitivity : Real;
        
        port opticalIn : OpticalInputPort;
        port videoOut : VideoOutputPort;
        port controlIn : ControlInputPort;
    }
    
    part def VideoProcessor {
        port videoIn : VideoInputPort;
        port videoOut : VideoOutputPort;
        port controlIn : ControlInputPort;
        
        part imageEnhancer;
        part signalConverter;
    }
    
    part def DisplayMonitor {
        attribute screenSize : LengthValue;
        attribute displayResolution : ImageResolution;
        
        port videoIn : VideoInputPort;
    }
    
    part def FluidManagementUnit {
        attribute maxFlowRate : VolumetricFlowValue;
        attribute targetPressure : PressureValue;
        
        port fluidSupply : FluidOutputPort;
        port fluidReturn : FluidInputPort;
        port controlIn : ControlInputPort;
        
        part irrigationPump {
            attribute pumpRate : VolumetricFlowValue;
        }
        part suctionPump {
            attribute vacuumPressure : PressureValue;
        }
        part pressureSensor;
    }
    
    part def ControlConsole {
        port lightControl : ControlInputPort;
        port cameraControl : ControlInputPort;
        port videoControl : ControlInputPort;
        port fluidControl : ControlInputPort;
        port displayVideoIn : VideoInputPort;
        
        part userInterface;
        part systemController;
    }
    
    requirement def VisualizationRequirement {
        doc /* System shall provide clear, real-time visualization of fetal anatomy */
        subject fetoscope : Fetoscope;
        subject lightSource : LightSource;
    }
    
    requirement def SafetyRequirement {
        doc /* System shall ensure maternal and fetal safety during procedure */
        subject fetoscope : Fetoscope;
        subject fluidManagementUnit : FluidManagementUnit;
    }
    
    requirement def FunctionalRequirement {
        doc /* System shall enable diagnostic examination and therapeutic intervention */
    }
    
    action def PerformFetoscopy {
        doc /* Primary function: Enable minimally invasive visualization and intervention in utero */
        
        first start;
        
        then action prepareSystem {
            action initializeEquipment;
            then action verifySystemReadiness;
            then action calibrateOptics;
        }
        
        then action establishAccess {
            action insertFetoscope;
            then action positionInAmnioticCavity;
            then action initiateFluidManagement;
        }
        
        then merge examinationLoop;
        
        then action performExamination {
            action activateIllumination {
                out lightActive : Boolean;
            }
            then action acquireImages {
                in illuminationOn = activateIllumination.lightActive;
                out rawOpticalData : OpticalSignal;
            }
            then action processVideo {
                in opticalData = acquireImages.rawOpticalData;
                out processedFrames : VideoFrame;
            }
            then action displayImages {
                in videoFrames = processVideo.processedFrames;
            }
            then action maintainFluidClarity {
                action irrigateField;
                then action removeDebris;
            }
            then action assessVisualization;
            then decide;
                if assessVisualization.viewAdequate then continueExam;
                if not assessVisualization.viewAdequate then optimizeView;
        }
        
        action optimizeView {
            action adjustIllumination;
            then action adjustFocus;
            then action repositionScope;
            then action increaseIrrigation;
        }
        then examinationLoop;
        
        action continueExam {
            action documentFindings;
            then decide;
                if continueExam.examinationComplete then withdrawInstrument;
                if not continueExam.examinationComplete then examinationLoop;
        }
        
        action withdrawInstrument {
            action retractFetoscope;
            then action verifyHemostasis;
            then action closeAccess;
        }
        
        then action completeProcedure;
        then done;
    }
    
    state def FetoscopySystemStates {
        entry; then standby;
        
        state standby {
            doc /* System powered but not in use */
        }
        
        transition standbyToPreparation
            first standby
            accept ControlCommand
            then preparation;
        
        state preparation {
            entry; then systemCheck;
            
            state systemCheck;
            transition checkToCalibration
                first systemCheck
                then calibration;
            
            state calibration;
        }
        
        transition preparationToOperating
            first preparation
            then operating;
        
        state operating {
            entry; then imaging;
            
            state imaging {
                do action acquireImages;
                
                state acquiring;
                transition acquiringToProcessing
                    first acquiring
                    then processing;
                
                state processing {
                    do action processVideo;
                }
                transition processingToDisplaying
                    first processing
                    then displaying;
                
                state displaying {
                    do action displayImages;
                }
                transition displayingToAcquiring
                    first displaying
                    then acquiring;
            }
            
            state fluidManagement {
                do action maintainFluidClarity;
                
                state irrigating;
                state suctioning;
                
                transition irrigateToSuction
                    first irrigating
                    then suctioning;
                
                transition suctionToIrrigate
                    first suctioning
                    then irrigating;
            }
        }
        
        transition operatingToWithdrawal
            first operating
            accept command : ControlCommand
            if command.illuminationLevel == 0.0
            then withdrawal;
        
        state withdrawal {
            entry; then retracting;
            state retracting;
            transition retractingToVerifying
                first retracting
                then verifying;
            state verifying;
        }
        
        transition withdrawalToStandby
            first withdrawal
            then standby;
    }
    
    part fetoscopySystem {
        doc /* Complete fetoscopy system for prenatal diagnosis and fetal therapy */
        
        satisfy functionalReq : FunctionalRequirement;
        
        perform action primaryFunction : PerformFetoscopy;
        
        exhibit state systemStates : FetoscopySystemStates;
        
        part lightSource : LightSource {
            attribute :>> powerOutput = 200.0;
            attribute :>> wavelengthRange = (400.0, 700.0);
        }
        
        part fetoscope : Fetoscope {
            attribute :>> insertionDiameter = 3.0;
            attribute :>> workingLength = 350.0;
            
            part :>> opticalSystem {
                part :>> objectiveLens {
                    attribute :>> focalLength = 5.0;
                }
                part :>> imagingFibers {
                    attribute :>> fiberCount = 10000;
                }
            }
            
            part :>> workingChannel {
                attribute :>> channelDiameter = 1.2;
            }
        }
        
        part cameraHead : CameraHead {
            attribute :>> sensorType = "CMOS";
            attribute :>> sensitivity = 0.001;
            
            perform primaryFunction.performExamination.acquireImages;
        }
        
        part videoProcessor : VideoProcessor {
            perform primaryFunction.performExamination.processVideo;
        }
        
        part displayMonitor : DisplayMonitor {
            attribute :>> screenSize = 550.0;
            attribute :>> displayResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
            }
            
            perform primaryFunction.performExamination.displayImages;
        }
        
        part fluidManagementUnit : FluidManagementUnit {
            attribute :>> maxFlowRate = 100.0;
            attribute :>> targetPressure = 12.0;
            
            part :>> irrigationPump {
                attribute :>> pumpRate = 50.0;
            }
            
            part :>> suctionPump {
                attribute :>> vacuumPressure = -5.0;
            }
            
            perform primaryFunction.performExamination.maintainFluidClarity;
        }
        
        part controlConsole : ControlConsole {
            perform primaryFunction.optimizeView;
        }
        
        connect lightSource.lightOut to fetoscope.lightIn;
        connect fetoscope.videoOut to cameraHead.opticalIn;
        connect cameraHead.videoOut to videoProcessor.videoIn;
        connect videoProcessor.videoOut to displayMonitor.videoIn;
        connect videoProcessor.videoOut to controlConsole.displayVideoIn;
        connect fluidManagementUnit.fluidSupply to fetoscope.fluidIn;
        connect fetoscope.fluidOut to fluidManagementUnit.fluidReturn;
        connect controlConsole.lightControl to lightSource.controlIn;
        connect controlConsole.cameraControl to cameraHead.controlIn;
        connect controlConsole.videoControl to videoProcessor.controlIn;
        connect controlConsole.fluidControl to fluidManagementUnit.controlIn;
    }
}
