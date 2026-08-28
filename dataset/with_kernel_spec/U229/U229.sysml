package FluorescenceImageGuidedSurgerySystem {
    private import ScalarValues::*;
    
    item def ICGDye;
    item def NIRLight;
    item def FluorescentLight;
    item def RawImageData;
    item def ProcessedImage;
    
    item def StartProcedureSignal;
    item def InjectionCompleteSignal;
    item def ResectionCompleteSignal;
    item def EmergencyStopSignal;
    
    port def DyePort;
    port def LightPort;
    port def OpticalPort;
    port def ImageDataPort;
    port def DisplayPort;
    
    action def InjectDye {
        out item dye : ICGDye;
    }
    action def Illuminate {
        out item light : NIRLight;
    }
    action def FilterLight {
        in item light : NIRLight;
        out item filteredFluorescence : FluorescentLight;
    }
    action def Capture {
        in item light : FluorescentLight;
        out item rawData : RawImageData;
    }
    action def ProcessImage {
        in item rawData : RawImageData;
        out item processedImage : ProcessedImage;
    }
    action def DisplayImage {
        in item image : ProcessedImage;
    }
    
    part def Patient {
        attribute dyeConcentration : Real;
        port dyePort : DyePort;
        port tissuePort : LightPort;
    }
    part def DyeInjectionSystem {
        port dyeOutputPort : DyePort;
    }
    part def NIRLightSource {
        port lightOutputPort : LightPort;
        attribute wavelength : Real = 780;
    }
    part def OpticalFilterAssembly {
        port opticalInputPort : LightPort;
        port filteredOutputPort : OpticalPort;
        attribute passbandWavelength : Real = 830;
    }
    part def CCDCamera {
        port opticalInputPort : OpticalPort;
        port dataOutputPort : ImageDataPort;
        attribute frameRate : Real = 30;
    }
    part def ImageProcessingUnit {
        port dataInputPort : ImageDataPort;
        port processedOutputPort : DisplayPort;
    }
    part def SurgicalDisplay {
        port displayInputPort : DisplayPort;
    }
    part def Surgeon {
        port visualPort : DisplayPort;
    }
    
    action def ImagingLoop {
        first start;
        then merge loopContinue;
        then action illuminate : Illuminate {
            out item light;
        }
        then action opticalFilter : FilterLight {
            in item light = illuminate.light;
            out item filteredFluorescence;
        }
        then action capture : Capture {
            in item light = opticalFilter.filteredFluorescence;
            out item rawData;
        }
        then action process : ProcessImage {
            in item rawData = capture.rawData;
            out item processedImage;
        }
        then action display : DisplayImage {
            in item image = process.processedImage;
        }
        then loopContinue;
    }
    
    state def SystemOperationStates {
        entry; then standby;
        
        state standby;
        transition standby_to_injection
            first standby
            accept start : StartProcedureSignal
            then dyeInjection;
        
        state dyeInjection {
            do action inject : InjectDye {
                out item dye;
            }
        }
        transition injection_to_imaging
            first dyeInjection
            accept injectionComplete : InjectionCompleteSignal
            then activeImaging;
        
        state activeImaging {
            do action imagingLoop : ImagingLoop;
        }
        transition imaging_to_standby
            first activeImaging
            accept resectionComplete : ResectionCompleteSignal
            then standby;
        
        transition emergency_stop
            first activeImaging
            accept emergencyStop : EmergencyStopSignal
            then standby;
    }
    
    part def FluorescenceSurgerySystem {
        part patient : Patient;
        part dyeInjector : DyeInjectionSystem;
        part lightSource : NIRLightSource;
        part filterAssembly : OpticalFilterAssembly;
        part camera : CCDCamera;
        part processingUnit : ImageProcessingUnit;
        part display : SurgicalDisplay;
        part surgeon : Surgeon;
        
        connector from dyeInjector.dyeOutputPort to patient.dyePort;
        connector from lightSource.lightOutputPort to patient.tissuePort;
        connector from patient.tissuePort to filterAssembly.opticalInputPort;
        connector from filterAssembly.filteredOutputPort to camera.opticalInputPort;
        connector from camera.dataOutputPort to processingUnit.dataInputPort;
        connector from processingUnit.processedOutputPort to display.displayInputPort;
        connector from display.displayInputPort to surgeon.visualPort;
        
        state systemState : SystemOperationStates;
    }
    
    requirement def HighlightTumorBoundaries {
        subject system : FluorescenceSurgerySystem;
        objective {
            doc /* The system shall make cancerous tissue visibly distinct from healthy tissue during surgery. */
        }
    }
    requirement def RealTimeOverlay {
        subject system : FluorescenceSurgerySystem;
        objective {
            doc /* The system shall provide a real-time visual overlay highlighting tumor boundaries with latency less than 100 milliseconds. */
        }
    }
    requirement def DyeAccumulation {
        subject dyeInjector : DyeInjectionSystem;
        objective {
            doc /* The administered fluorescent dye shall accumulate in higher concentrations within tumor tissue compared to surrounding healthy tissue. */
        }
    }
    requirement def OpticalFiltering {
        subject filterAssembly : OpticalFilterAssembly;
        objective {
            doc /* The optical filter assembly shall block excitation light and ambient light, transmitting only fluorescence emission to the CCD camera. */
        }
    }
    requirement def NIRExcitation {
        subject lightSource : NIRLightSource;
        objective {
            doc /* The NIR light source shall emit light at approximately 780nm to excite ICG dye for fluorescence. */
        }
    }
    requirement def RealTimeProcessing {
        subject processingUnit : ImageProcessingUnit;
        objective {
            doc /* The image processing unit shall process raw images and generate overlay at a minimum frame rate of 25Hz. */
        }
    }
}
