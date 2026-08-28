package MedicalEndoscopeSystem {

    public import ScalarValues::*;

    package Definitions {

        value type Length :> Real { unit "mm"; }
        value type Diameter :> Real { unit "mm"; }
        value type Angle :> Real { unit "deg"; }
        value type Frequency :> Real { unit "Hz"; }
        value type Resolution :> Integer;
        value type FlowRate :> Real { unit "mL/min"; }
        value type Pressure :> Real { unit "kPa"; }
        value type LuminousFlux :> Real { unit "lm"; }
        value type Temperature :> Real { unit "degC"; }
        value type Voltage :> Real { unit "V"; }
        value type Current :> Real { unit "A"; }
        value type Duration :> Real { unit "s"; }

        item def Light {
            attribute wavelength : Length;
            attribute flux : LuminousFlux;
            attribute active : Boolean;
        }

        item def VideoFrame {
            attribute width : Resolution;
            attribute height : Resolution;
            attribute frameRate : Frequency;
            attribute timestamp : Duration;
            attribute enhanced : Boolean;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute value : Real;
            attribute timestamp : Duration;
        }

        item def IrrigationFluid {
            attribute fluidType : String;
            attribute temperature : Temperature;
            attribute volume : Real;
        }

        item def SuctionRequest {
            attribute suctionLevel : Real;
            attribute duration : Duration;
        }

        item def ImageCapture {
            attribute captureId : String;
            attribute timestamp : Duration;
            attribute format : String;
            attribute frame : VideoFrame;
        }

        item def Telemetry {
            attribute bendAngle : Angle;
            attribute insertionDepth : Length;
            attribute timestamp : Duration;
        }

        port def OpticalPort {
            out light : Light;
        }

        port def VideoOutPort {
            out frame : VideoFrame;
        }

        port def VideoInPort {
            in frame : VideoFrame;
        }

        port def ControlPort {
            in command : ControlCommand;
            out feedback : ControlCommand;
        }

        port def FluidPort {
            in fluid : IrrigationFluid;
            out suction : SuctionRequest;
        }

        port def DisplayPort {
            out frame : VideoFrame;
        }

        port def TelemetryPort {
            out telemetry : Telemetry;
        }

        port def PowerPort {
            attribute voltage : Voltage;
            attribute current : Current;
        }
    }

    package Components {

        part def ArticulationSection {
            attribute maxBendAngle : Angle = 210;
            attribute currentBendAngle : Angle = 0;
            attribute bendDirection : String = "neutral";
            port controlIn : Definitions::ControlPort;
            port telemetryOut : Definitions::TelemetryPort;

            action bend {
                in angle : Angle;
                in direction : String;
                update currentBendAngle;
                update bendDirection;
            }
        }

        part def ImageSensor {
            attribute resolutionWidth : Definitions::Resolution = 1920;
            attribute resolutionHeight : Definitions::Resolution = 1080;
            attribute frameRate : Definitions::Frequency = 60;
            attribute active : Boolean = false;
            port videoOut : Definitions::VideoOutPort;

            action captureFrame {
                out frame : Definitions::VideoFrame;
            }
        }

        part def InsertionTube {
            attribute length : Definitions::Length = 1200;
            attribute diameter : Definitions::Diameter = 9.5;
            attribute insertionDepth : Definitions::Length = 0;
            part articulationSection : ArticulationSection;
            part imageSensor : ImageSensor;
            part fiberOpticBundle;
            part workingChannelLumen;
            port opticalIn : Definitions::OpticalPort;
            port videoOut : Definitions::VideoOutPort;
            port workingChannel : Definitions::FluidPort;
            port articulationControl : Definitions::ControlPort;
            port telemetryOut : Definitions::TelemetryPort;

            connection sensorVideoPath connect imageSensor.videoOut to videoOut;
            connection articulationControlPath connect articulationControl to articulationSection.controlIn;
            connection telemetryPath connect articulationSection.telemetryOut to telemetryOut;
        }

        part def LightSource {
            attribute maxFlux : Definitions::LuminousFlux = 5000;
            attribute currentFlux : Definitions::LuminousFlux = 0;
            attribute active : Boolean = false;
            port opticalOut : Definitions::OpticalPort;
            port controlIn : Definitions::ControlPort;
            port powerIn : Definitions::PowerPort;

            action emitLight {
                in fluxLevel : Definitions::LuminousFlux;
                update currentFlux;
            }
        }

        part def VideoProcessor {
            attribute enhancementEnabled : Boolean = true;
            attribute noiseReductionLevel : Real = 0.5;
            attribute colorEnhancement : Boolean = true;
            port videoIn : Definitions::VideoInPort;
            port videoOut : Definitions::VideoOutPort;
            port controlIn : Definitions::ControlPort;

            action enhanceImage {
                in rawFrame : Definitions::VideoFrame;
                out enhancedFrame : Definitions::VideoFrame;
            }

            action processStream {
                in rawFrame : Definitions::VideoFrame;
                out enhancedFrame : Definitions::VideoFrame;
                then enhanceImage;
            }
        }

        part def ControlConsole {
            attribute displayWidth : Definitions::Resolution = 1920;
            attribute displayHeight : Definitions::Resolution = 1080;
            attribute brightness : Real = 0.7;
            part displayScreen;
            part articulationKnobs;
            part lightingDial;
            part irrigationButtons;
            part captureButton;
            port displayOut : Definitions::DisplayPort;
            port videoIn : Definitions::VideoInPort;
            port articulationControl : Definitions::ControlPort;
            port lightingControl : Definitions::ControlPort;
            port irrigationControl : Definitions::ControlPort;
            port captureOut : Definitions::VideoOutPort;

            action displayFeed {
                in frame : Definitions::VideoFrame;
            }

            action captureImage {
                in frame : Definitions::VideoFrame;
                out capture : Definitions::ImageCapture;
            }
        }

        part def IrrigationSystem {
            attribute maxFlowRate : Definitions::FlowRate = 500;
            attribute currentFlowRate : Definitions::FlowRate = 0;
            attribute suctionPressure : Definitions::Pressure = -80;
            attribute mode : String = "idle";
            part fluidReservoir;
            part suctionPump;
            part irrigationPump;
            port fluidOut : Definitions::FluidPort;
            port controlIn : Definitions::ControlPort;

            action irrigate {
                in flowRate : Definitions::FlowRate;
                update currentFlowRate;
                update mode := "irrigating";
            }

            action suction {
                in level : Real;
                update mode := "suctioning";
            }
        }

        part def EndoscopeHandle {
            attribute gripType : String = "ergonomic";
            port articulationControl : Definitions::ControlPort;
            port irrigationControl : Definitions::ControlPort;
            part insertionTube : InsertionTube;
        }
    }

    package System {

        part def Endoscope {
            attribute systemId : String;
            attribute manufacturer : String;
            attribute model : String;
            part handle : Components::EndoscopeHandle;
            part insertionTube : Components::InsertionTube;

            connection handleToArticulation connect handle.articulationControl to insertionTube.articulationControl;
            connection handleToIrrigation connect handle.irrigationControl to insertionTube.workingChannel;
        }

        part def EndoscopeSystem {
            attribute systemSerialNumber : String;
            attribute firmwareVersion : String;
            part lightSource : Components::LightSource;
            part videoProcessor : Components::VideoProcessor;
            part controlConsole : Components::ControlConsole;
            part irrigationSystem : Components::IrrigationSystem;
            part endoscope : Endoscope;

            connection lightToTube connect lightSource.opticalOut to endoscope.insertionTube.opticalIn;
            connection sensorToProcessor connect endoscope.insertionTube.videoOut to videoProcessor.videoIn;
            connection processorToConsole connect videoProcessor.videoOut to controlConsole.videoIn;
            connection consoleToArticulation connect controlConsole.articulationControl to endoscope.handle.articulationControl;
            connection consoleToLighting connect controlConsole.lightingControl to lightSource.controlIn;
            connection consoleToIrrigation connect controlConsole.irrigationControl to irrigationSystem.controlIn;
            connection irrigationToTube connect irrigationSystem.fluidOut to endoscope.insertionTube.workingChannel;
            connection telemetryToConsole connect endoscope.insertionTube.telemetryOut to controlConsole.videoIn;

            exhibit behavior EndoscopeOperation;
        }
    }

    package Behaviors {

        state machine def EndoscopeOperation {

            entry action initializeSystem {
                log "System power applied.";
            }

            state Off {
                entry action logOff { log "System off."; }
            }

            state Initializing {
                entry action runSelfTest {
                    log "Running self-test.";
                }
                do action warmUp {
                    log "Warming up light source and sensor.";
                }
            }

            state Ready {
                entry action logReady { log "System ready for procedure."; }
            }

            state Inserting {
                entry action logInsertion { log "Insertion tube being introduced."; }
                do action monitorDepth {
                    log "Monitoring insertion depth.";
                }
            }

            state Navigating {
                entry action logNavigation { log "Navigating to target site."; }
                do action adjustArticulation {
                    log "Adjusting articulation angle.";
                }
            }

            state Examining {
                entry action logExamination { log "Examining anatomical site."; }
                do action viewLiveFeed {
                    log "Viewing live enhanced video feed.";
                }
            }

            state Treating {
                entry action logTreatment { log "Performing therapeutic intervention."; }
                do action applyIrrigationOrSuction {
                    log "Applying irrigation or suction as needed.";
                }
            }

            state Documenting {
                entry action logDocumentation { log "Capturing images and video for documentation."; }
                do action captureMedia {
                    log "Saving captured media.";
                }
            }

            state Withdrawing {
                entry action logWithdrawal { log "Withdrawing endoscope."; }
                do action monitorWithdrawal {
                    log "Monitoring safe withdrawal.";
                }
            }

            state Cleaning {
                entry action logCleaning { log "System cleaning and shutdown."; }
            }

            transition from Off to Initializing when powerOn;
            transition from Initializing to Ready when selfTestComplete;
            transition from Ready to Inserting when insertionStarted;
            transition from Inserting to Navigating when targetSiteReached;
            transition from Navigating to Examining when examinationStarted;
            transition from Examining to Treating when treatmentRequested;
            transition from Treating to Examining when treatmentComplete;
            transition from Examining to Documenting when captureRequested;
            transition from Documenting to Examining when captureComplete;
            transition from Examining to Withdrawing when withdrawalStarted;
            transition from Withdrawing to Cleaning when scopeRemoved;
            transition from Cleaning to Off when shutdownComplete;
        }
    }

    package Requirements {

        requirement def MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The medical endoscope system shall support minimally invasive internal examinations and therapeutic procedures.";
        }

        requirement InsertionTubeDimensionRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The insertion tube shall be approximately 1.2 meters long and 9.5 mm in diameter to minimize patient trauma.";
            assume system.endoscope.insertionTube.length == 1200;
            assume system.endoscope.insertionTube.diameter == 9.5;
        }

        requirement ImageSensorResolutionRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The image sensor shall capture video at 1920x1080 resolution and 60 frames per second.";
            assume system.endoscope.insertionTube.imageSensor.resolutionWidth == 1920;
            assume system.endoscope.insertionTube.imageSensor.resolutionHeight == 1080;
            assume system.endoscope.insertionTube.imageSensor.frameRate == 60;
        }

        requirement ArticulationRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The articulation section shall bend up to 210 degrees to allow comprehensive navigation.";
            assume system.endoscope.insertionTube.articulationSection.maxBendAngle == 210;
        }

        requirement IlluminationRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "An external light source shall deliver light through fiber optic bundles to illuminate the internal site.";
            assume system.lightSource.maxFlux >= 1000;
        }

        requirement VideoProcessingRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The video processor shall enhance image quality in real-time before display.";
            assume system.videoProcessor.enhancementEnabled == true;
        }

        requirement ControlConsoleRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The control console shall display the live enhanced video feed and provide articulation controls.";
            assume system.controlConsole.displayWidth == 1920;
            assume system.controlConsole.displayHeight == 1080;
        }

        requirement IrrigationSystemRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The irrigation system shall deliver fluid to wash areas and apply suction to remove fluids and debris via the working channel.";
            assume system.irrigationSystem.maxFlowRate >= 100;
            assume system.irrigationSystem.suctionPressure <= -50;
        }

        requirement OperationalWorkflowRequirement :> MedicalEndoscopeSystemRequirement {
            subject system : System::EndoscopeSystem;
            doc "The system shall support the operational workflow: initialize, insert, navigate, examine, treat, document, and withdraw.";
        }
    }

    package Instances {

        part endoscopeSystemInstance : System::EndoscopeSystem {
            attribute systemSerialNumber = "ENDO-2024-001";
            attribute firmwareVersion = "v3.2.1";

            part lightSource {
                attribute maxFlux = 5000;
            }
            part videoProcessor {
                attribute enhancementEnabled = true;
            }
            part controlConsole {
                attribute displayWidth = 1920;
                attribute displayHeight = 1080;
            }
            part irrigationSystem {
                attribute maxFlowRate = 500;
                attribute suctionPressure = -80;
            }
            part endoscope {
                attribute systemId = "ENDO-001";
                attribute manufacturer = "MediScope";
                attribute model = "FlexView-HD";
                part insertionTube {
                    attribute length = 1200;
                    attribute diameter = 9.5;
                    part articulationSection {
                        attribute maxBendAngle = 210;
                    }
                    part imageSensor {
                        attribute resolutionWidth = 1920;
                        attribute resolutionHeight = 1080;
                        attribute frameRate = 60;
                    }
                }
            }
        }
    }
}
