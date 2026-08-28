package AirtraqVideoLaryngoscope {

    import ScalarValues::*;
    import SI::*;

    // ---- Value Types ----
    value type LuminousFlux :> Real { unit "lm"; }
    value type ElectricPotential :> Real { unit "V"; }
    value type ElectricCharge :> Real { unit "C"; }
    value type ElectricCurrent :> Real { unit "A"; }
    value type Angle :> Real { unit "deg"; }
    value type Length :> Real { unit "mm"; }
    value type Mass :> Real { unit "g"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Duration_ms :> Real { unit "ms"; }
    value type Resolution :> Real { unit "px"; }
    value type Dimensionless :> Real { unit "1"; }

    // ---- Item Types ----
    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def RawVideoFrame {
        attribute width : Resolution = 1280;
        attribute height : Resolution = 720;
        attribute frameRate : Frequency = 30;
    }

    item def EnhancedVideoFrame {
        attribute width : Resolution = 1280;
        attribute height : Resolution = 720;
        attribute frameRate : Frequency = 30;
        attribute brightnessGain : Dimensionless = 1.5;
        attribute contrastGain : Dimensionless = 1.3;
    }

    item def LightBeam {
        attribute flux : LuminousFlux;
        attribute colorTemp : Integer = 6500;
    }

    item def OpticalImage {
        attribute magnification : Dimensionless = 2.0;
        attribute fieldOfView : Angle = 80;
    }

    item def EndotrachealTube {
        attribute innerDiameter : Length = 8.0;
        attribute outerDiameter : Length = 11.0;
        attribute length : Length = 300;
    }

    // ---- Port Definitions ----
    port def PowerPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def LightEmissionPort {
        out beam : LightBeam;
    }

    port def LightReceptionPort {
        in beam : LightBeam;
    }

    port def OpticalImagePort {
        out image : OpticalImage;
    }

    port def OpticalImageInPort {
        in image : OpticalImage;
    }

    port def RawVideoPort {
        out frame : RawVideoFrame;
    }

    port def RawVideoInPort {
        in frame : RawVideoFrame;
    }

    port def EnhancedVideoPort {
        out frame : EnhancedVideoFrame;
    }

    port def EnhancedVideoInPort {
        in frame : EnhancedVideoFrame;
    }

    // ---- Requirements ----
    requirement def ShallProvideClearAirwayView {
        doc { The device shall provide a clear, indirect view of the patient's airway during intubation. }
    }

    requirement def ShallIlluminateAirway {
        doc { The LED illumination system shall provide bright, cool light at the blade tip. }
        attribute minFlux : LuminousFlux = 200;
    }

    requirement def ShallGuideTubePrecisely {
        doc { The tube guiding channel shall direct the endotracheal tube at a precise angle toward the vocal cords. }
        attribute guideAngle : Angle = 35;
    }

    requirement def ShallDisplayRealTimeVideo {
        doc { The display screen shall show enhanced real-time video of the airway. }
        attribute minFrameRate : Frequency = 30;
    }

    requirement def ShallPowerAllElectronics {
        doc { The battery module shall provide sufficient power to all electronic components. }
        attribute nominalVoltage : ElectricPotential = 3.7;
        attribute minCapacity : ElectricCharge = 2000;
    }

    requirement def ShallEnhanceImage {
        doc { The video processing unit shall enhance image clarity, brightness, and contrast. }
    }

    // ---- Parts ----

    part def BatteryModule {
        attribute nominalVoltage : ElectricPotential = 3.7;
        attribute capacity_mAh : Integer = 2000;
        attribute mass : Mass = 25;
        port powerOut : PowerPort;
        requirement satisfies ShallPowerAllElectronics;
    }

    part def LEDIlluminationSystem {
        attribute luminousFlux : LuminousFlux = 250;
        attribute colorTemperatureK : Integer = 6500;
        attribute powerConsumption : ElectricCurrent = 0.12;
        port powerIn : PowerInPort;
        port lightOut : LightEmissionPort;
        requirement satisfies ShallIlluminateAirway;
    }

    part def OpticalPrismSystem {
        attribute magnification : Dimensionless = 2.0;
        attribute fieldOfView : Angle = 80;
        attribute prismAngle : Angle = 45;
        port lightIn : LightReceptionPort;
        port imageOut : OpticalImagePort;
    }

    part def MicroCameraModule {
        attribute resolutionWidth : Resolution = 1280;
        attribute resolutionHeight : Resolution = 720;
        attribute frameRate : Frequency = 30;
        attribute powerConsumption : ElectricCurrent = 0.15;
        port powerIn : PowerInPort;
        port imageIn : OpticalImageInPort;
        port videoOut : RawVideoPort;
    }

    part def VideoProcessingUnit {
        attribute brightnessGain : Dimensionless = 1.5;
        attribute contrastGain : Dimensionless = 1.3;
        attribute sharpnessGain : Dimensionless = 1.2;
        attribute processingLatency : Duration_ms = 20;
        attribute powerConsumption : ElectricCurrent = 0.20;
        port powerIn : PowerInPort;
        port videoIn : RawVideoInPort;
        port videoOut : EnhancedVideoPort;
        requirement satisfies ShallEnhanceImage;
    }

    part def DisplayScreen {
        attribute screenWidth : Resolution = 1280;
        attribute screenHeight : Resolution = 720;
        attribute refreshRate : Frequency = 60;
        attribute diagonalSize : Length = 50;
        attribute powerConsumption : ElectricCurrent = 0.25;
        port powerIn : PowerInPort;
        port videoIn : EnhancedVideoInPort;
        requirement satisfies ShallDisplayRealTimeVideo;
    }

    part def AnatomicalBlade {
        attribute bladeLength : Length = 120;
        attribute bladeWidth : Length = 25;
        attribute bladeAngle : Angle = 60;
        attribute mass : Mass = 30;
    }

    part def TubeGuidingChannel {
        attribute channelDiameter : Length = 12;
        attribute channelLength : Length = 110;
        attribute guideAngle : Angle = 35;
        attribute accommodatedTube : EndotrachealTube;
        requirement satisfies ShallGuideTubePrecisely;
    }

    // ---- Main Device ----

    part def AirtraqVideoLaryngoscope {
        requirement satisfies ShallProvideClearAirwayView;

        part battery : BatteryModule;
        part led : LEDIlluminationSystem;
        part prism : OpticalPrismSystem;
        part camera : MicroCameraModule;
        part vpu : VideoProcessingUnit;
        part display : DisplayScreen;
        part blade : AnatomicalBlade;
        part guideChannel : TubeGuidingChannel;

        // Internal power distribution
        connection powerToLED connect battery.powerOut to led.powerIn;
        connection powerToCamera connect battery.powerOut to camera.powerIn;
        connection powerToVPU connect battery.powerOut to vpu.powerIn;
        connection powerToDisplay connect battery.powerOut to display.powerIn;

        // Optical path
        connection lightToPrism connect led.lightOut to prism.lightIn;
        connection imageToCamera connect prism.imageOut to camera.imageIn;

        // Video signal path
        connection rawToVPU connect camera.videoOut to vpu.videoIn;
        connection enhancedToDisplay connect vpu.videoOut to display.videoIn;

        // Operational state machine
        behavior stateMachine IntubationProcedure {

            state Off {
                entry action { /* Device powered down */ }
            }

            state PoweredOn {
                entry action {
                    // Initialize all electronic subsystems
                    // Battery supplies power to LED, camera, VPU, display
                }
            }

            state BladeInsertion {
                entry action {
                    // Clinician inserts anatomical blade into patient's mouth
                    // LED illuminates airway; camera captures live feed
                }
            }

            state NavigatingAnatomy {
                entry action {
                    // Clinician repositions blade using display feedback
                    // Prism relays optical image to camera
                }
            }

            state GlottisVisualized {
                entry action {
                    // Clear view of glottis achieved on display
                    // Clinician confirms target visualization
                }
            }

            state TubeAdvancement {
                entry action {
                    // Clinician advances endotracheal tube through guiding channel
                    // Progress monitored on display screen
                }
            }

            state PlacementVerified {
                entry action {
                    // Tube passes through vocal cords correctly
                    // Visual verification complete
                }
            }

            state DeviceRemoval {
                entry action {
                    // Device carefully withdrawn from patient's mouth
                    // Endotracheal tube remains in trachea
                }
            }

            transition Off to PoweredOn when { /* power button pressed */ };
            transition PoweredOn to BladeInsertion when { /* clinician begins insertion */ };
            transition BladeInsertion to NavigatingAnatomy when { /* blade fully inserted */ };
            transition NavigatingAnatomy to GlottisVisualized when { /* glottis visible on display */ };
            transition NavigatingAnatomy to NavigatingAnatomy when { /* repositioning continues */ };
            transition GlottisVisualized to TubeAdvancement when { /* clinician advances tube */ };
            transition TubeAdvancement to PlacementVerified when { /* tube through vocal cords */ };
            transition PlacementVerified to DeviceRemoval when { /* verification accepted */ };
            transition DeviceRemoval to Off when { /* device removed and powered off */ };
        }
    }

    // ---- Verification Actions ----

    action def VerifyIllumination {
        in led : LEDIlluminationSystem;
        attribute measuredFlux : LuminousFlux;
        assert { led.luminousFlux >= 200 };
    }

    action def VerifyTubeGuidance {
        in channel : TubeGuidingChannel;
        in tube : EndotrachealTube;
        assert { tube.outerDiameter <= channel.channelDiameter };
        assert { channel.guideAngle == 35 };
    }

    action def VerifyVideoPipeline {
        in camera : MicroCameraModule;
        in vpu : VideoProcessingUnit;
        in display : DisplayScreen;
        assert { camera.frameRate >= 30 };
        assert { vpu.brightnessGain > 1.0 };
        assert { vpu.contrastGain > 1.0 };
        assert { display.refreshRate >= 30 };
    }

    action def VerifyPowerDistribution {
        in battery : BatteryModule;
        in led : LEDIlluminationSystem;
        in camera : MicroCameraModule;
        in vpu : VideoProcessingUnit;
        in display : DisplayScreen;
        attribute totalCurrent : ElectricCurrent = led.powerConsumption + camera.powerConsumption + vpu.powerConsumption + display.powerConsumption;
        assert { battery.nominalVoltage == 3.7 };
        assert { battery.capacity_mAh >= 2000 };
    }

}
