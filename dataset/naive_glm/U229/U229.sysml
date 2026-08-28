package FIGS_System {
    import ISQ::*;
    import ScalarValues::*;

    value type Wavelength > Real { unit 'nm'; }
    value type LightIntensity > Real { unit 'mW/cm^2'; }
    value type DoseVolume > Real { unit 'mL'; }
    value type Concentration > Real { unit 'mg/mL'; }
    value type FrameRate > Real { unit 'fps'; }
    value type PixelCount > Integer;
    value type ElapsedTime > Real { unit 's'; }

    item def ICGDye {
        attribute concentration : Concentration = 2.5;
    }
    item def ExcitationLight {
        attribute wavelength : Wavelength = 780;
        attribute intensity : LightIntensity;
    }
    item def EmissionLight {
        attribute wavelength : Wavelength = 830;
        attribute intensity : LightIntensity;
    }
    item def RawImageData {
        attribute resolution : PixelCount = 1920;
        attribute frameRate : FrameRate = 30;
    }
    item def ProcessedImage {
        attribute resolution : PixelCount = 1920;
        attribute frameRate : FrameRate = 30;
        attribute contrastEnhanced : Boolean = true;
    }
    item def ImageOverlay {
        attribute tumorBoundaryHighlighted : Boolean = true;
        attribute colorCoded : Boolean = true;
    }

    port def FluidPort {
        out item dye : ICGDye;
    }
    port def ExcitationLightOutputPort {
        out item excitation : ExcitationLight;
    }
    port def ExcitationLightInputPort {
        in item excitation : ExcitationLight;
    }
    port def EmissionLightOutputPort {
        out item emission : EmissionLight;
    }
    port def EmissionLightInputPort {
        in item emission : EmissionLight;
    }
    port def RawDataOutputPort {
        out item raw : RawImageData;
    }
    port def RawDataInputPort {
        in item raw : RawImageData;
    }
    port def DisplayOutputPort {
        out item processed : ProcessedImage;
        out item overlay : ImageOverlay;
    }
    port def DisplayInputPort {
        in item processed : ProcessedImage;
        in item overlay : ImageOverlay;
    }

    action def AdministerDye {
        in item dye : ICGDye;
        out item administeredDye : ICGDye;
    }
    action def Illuminate {
        out item excitation : ExcitationLight;
    }
    action def FilterLight {
        in item excitation : ExcitationLight;
        out item emission : EmissionLight;
    }
    action def CaptureImage {
        in item emission : EmissionLight;
        out item raw : RawImageData;
    }
    action def ProcessImage {
        in item raw : RawImageData;
        out item processed : ProcessedImage;
        out item overlay : ImageOverlay;
    }
    action def DisplayImage {
        in item processed : ProcessedImage;
        in item overlay : ImageOverlay;
    }

    part def DyeInjectionSystem {
        port out patientInjection : FluidPort;
        attribute doseVolume : DoseVolume = 5.0;
        attribute dyeConcentration : Concentration = 2.5;
    }

    part def NIRLightSource {
        port out illumination : ExcitationLightOutputPort;
        attribute excitationWavelength : Wavelength = 780;
        attribute intensity : LightIntensity = 10.0;
    }

    part def OpticalFilterAssembly {
        port in filterInput : ExcitationLightInputPort;
        port out filterOutput : EmissionLightOutputPort;
        attribute passbandCenter : Wavelength = 830;
        attribute passbandWidth : Wavelength = 40;
    }

    part def CCDCamera {
        port in opticalInput : EmissionLightInputPort;
        port out dataOutput : RawDataOutputPort;
        attribute sensitivity : Real = 0.95;
        attribute resolution : PixelCount = 1920;
        attribute frameRate : FrameRate = 30;
    }

    part def ImageProcessingUnit {
        port in dataInput : RawDataInputPort;
        port out displayOutput : DisplayOutputPort;
        attribute processingDelay : ElapsedTime = 0.03;
    }

    part def SurgicalDisplay {
        port in displayInput : DisplayInputPort;
        attribute screenSize : Real = 24.0;
        attribute refreshRate : FrameRate = 60;
    }

    requirement def TumorVisibilityRequirement {
        doc "The system shall make cancerous tissue visibly distinct from healthy tissue during surgery using fluorescence imaging.";
    }
    requirement def RealTimeFeedbackRequirement {
        doc "The system shall provide real-time visual feedback to the surgeon with minimal latency.";
        attribute maxLatency : ElapsedTime = 0.1;
    }
    requirement def LightFilteringRequirement {
        doc "The Optical Filter Assembly shall filter out excitation light and ambient light, allowing only emission light to reach the camera.";
    }
    requirement def DyeAccumulationRequirement {
        doc "The fluorescent dye shall accumulate in higher concentrations within tumor tissue compared to healthy tissue.";
    }
    requirement def CompleteResectionRequirement {
        doc "The system shall enable more precise and complete tumor resection while preserving surrounding critical structures.";
    }

    part def FluorescenceImageGuidedSurgerySystem {
        port out patientConnection : FluidPort;

        attribute startCommand : Boolean = false;
        attribute dyeInjectionComplete : Boolean = false;
        attribute resectionComplete : Boolean = false;

        part dyeInjection : DyeInjectionSystem;
        part lightSource : NIRLightSource;
        part filterAssembly : OpticalFilterAssembly;
        part camera : CCDCamera;
        part processingUnit : ImageProcessingUnit;
        part display : SurgicalDisplay;

        connection dyeToPatient connect dyeInjection.patientInjection to patientConnection;
        connection lightToFilter connect lightSource.illumination to filterAssembly.filterInput;
        connection filterToCamera connect filterAssembly.filterOutput to camera.opticalInput;
        connection cameraToProcessor connect camera.dataOutput to processingUnit.dataInput;
        connection processorToDisplay connect processingUnit.displayOutput to display.displayInput;

        exhibit {
            state standby {
                entry action {
                    // System initialized, waiting for start command
                }
            }

            state dyeInjection {
                entry action {
                    perform administerDye : AdministerDye;
                }
            }

            state activeImaging {
                do action {
                    while (true) {
                        perform illuminate : Illuminate;
                        perform filterLight : FilterLight;
                        perform captureImage : CaptureImage;
                        perform processImage : ProcessImage;
                        perform displayImage : DisplayImage;
                    }
                }
            }

            transition standby to dyeInjection when startCommand;
            transition dyeInjection to activeImaging when dyeInjectionComplete;
            transition activeImaging to standby when resectionComplete;
        }

        requirement tumorVisibility : TumorVisibilityRequirement;
        requirement realTimeFeedback : RealTimeFeedbackRequirement;
        requirement lightFiltering : LightFilteringRequirement;
        requirement dyeAccumulation : DyeAccumulationRequirement;
        requirement completeResection : CompleteResectionRequirement;

        satisfy tumorVisibility by processingUnit;
        satisfy realTimeFeedback by processingUnit;
        satisfy lightFiltering by filterAssembly;
        satisfy dyeAccumulation by dyeInjection;
        satisfy completeResection by display;
    }
}
