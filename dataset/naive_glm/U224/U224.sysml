package MedicalFetoscopySystem {

    // ---------- Value Types with Units ----------
    value type LightIntensityValue = Real { unit 'cd'; }
    value type OpticalPowerValue = Real { unit 'W'; }
    value type PressureValue = Real { unit 'Pa'; }
    value type FlowRateValue = Real { unit 'mL/min'; }
    value type TemperatureValue = Real { unit 'degC'; }
    value type FrameRateValue = Real { unit 'Hz'; }
    value type ResolutionValue = Integer { unit 'px'; }
    value type DiameterValue = Real { unit 'mm'; }
    value type LengthValue = Real { unit 'mm'; }
    value type VolumeValue = Real { unit 'mL'; }

    // ---------- Item Definitions ----------
    item def AmnioticFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue = 37 [degC];
    }
    item def IrrigationFluid :> AmnioticFluid;
    item def LightSignal {
        attribute intensity : LightIntensityValue;
    }
    item def OpticalImage {
        attribute resolution : ResolutionValue;
    }
    item def DigitalVideoStream {
        attribute frameRate : FrameRateValue;
        attribute resolution : ResolutionValue;
        attribute brightness : Real;
        attribute contrast : Real;
    }
    item def ControlCommand {
        attribute target : String;
        attribute parameter : String;
        attribute value : Real;
    }
    item def TelemetryData {
        attribute pressureReading : PressureValue;
        attribute flowReading : FlowRateValue;
        attribute temperatureReading : TemperatureValue;
        attribute lightLevel : LightIntensityValue;
    }

    // ---------- Port Definitions ----------
    port def LightPort { out light : LightSignal; }
    port def OpticalPort { out image : OpticalImage; }
    port def VideoPort { out video : DigitalVideoStream; }
    port def FluidPort { out fluid : AmnioticFluid; in fluid : AmnioticFluid; }
    port def ControlPort { out command : ControlCommand; in telemetry : TelemetryData; }
    port def PowerPort { in voltage : Real { unit 'V'; } }

    // ---------- Interface Definitions ----------
    interface def LightInterface {
        end supplier : LightPort;
        end consumer : ~LightPort;
    }
    interface def OpticalInterface {
        end supplier : OpticalPort;
        end consumer : ~OpticalPort;
    }
    interface def VideoInterface {
        end supplier : VideoPort;
        end consumer : ~VideoPort;
    }
    interface def FluidInterface {
        end supplier : FluidPort;
        end consumer : ~FluidPort;
    }
    interface def ControlInterface {
        end supplier : ControlPort;
        end consumer : ~ControlPort;
    }

    // ---------- Part Definitions ----------

    part def Fetoscope {
        attribute outerDiameter : DiameterValue = 3.0 [mm];
        attribute workingLength : LengthValue = 300 [mm];
        attribute inserted : Boolean = false;
        attribute removed : Boolean = true;

        port lightIn : ~LightPort;
        port opticalOut : OpticalPort;
        port workingChannelIn : ~FluidPort;
        port workingChannelOut : FluidPort;

        part objectiveLens {
            attribute focalLength : LengthValue = 2.5 [mm];
        }
        part imagingFibers {
            attribute fiberCount : Integer = 10000;
        }
        part illuminationFibers {
            attribute fiberCount : Integer = 6000;
        }
        part workingChannel {
            attribute innerDiameter : DiameterValue = 1.2 [mm];
        }

        action def captureImage {
            in receivedLight : LightSignal;
            out capturedImage : OpticalImage;
        }

        state machine def FetoscopeOperation {
            entry; then Idle;
            state Idle;
            state Inserted;
            state Active;
            transition from Idle to Inserted when self.inserted == true;
            transition from Inserted to Active when workingChannelIn.fluid != null;
            transition from Active to Inserted when self.inserted == false;
            transition from Inserted to Idle when self.removed == true;
        }
    }

    part def LightSource {
        attribute maxIntensity : LightIntensityValue = 5000 [cd];
        attribute currentIntensity : LightIntensityValue = 0 [cd];
        attribute powerConsumption : OpticalPowerValue = 300 [W];
        attribute poweredOn : Boolean = false;

        port lightOut : LightPort;
        port controlIn : ~ControlPort;
        port powerIn : PowerPort;

        action def generateLight {
            in level : LightIntensityValue;
            out beam : LightSignal;
        }

        state machine def LightSourceOperation {
            entry; then Off;
            state Off;
            state Standby;
            state Active;
            transition from Off to Standby when self.poweredOn == true;
            transition from Standby to Active when controlIn.command != null;
            transition from Active to Standby when controlIn.command.target == "light" && controlIn.command.value == 0;
            transition from Standby to Off when self.poweredOn == false;
        }
    }

    part def CameraHead {
        attribute sensorResolution : ResolutionValue = 1920 * 1080 [px];
        attribute calibrated : Boolean = false;
        attribute poweredOn : Boolean = false;

        port opticalIn : ~OpticalPort;
        port videoOut : VideoPort;
        port controlIn : ~ControlPort;
        port powerIn : PowerPort;

        action def convertOpticalToDigital {
            in image : OpticalImage;
            out stream : DigitalVideoStream;
        }

        state machine def CameraOperation {
            entry; then Off;
            state Off;
            state Calibrating;
            state Streaming;
            transition from Off to Calibrating when self.poweredOn == true;
            transition from Calibrating to Streaming when self.calibrated == true && opticalIn.image != null;
            transition from Streaming to Off when self.poweredOn == false;
        }
    }

    part def VideoProcessor {
        attribute supportedFrameRate : FrameRateValue = 60 [Hz];
        attribute noiseReductionEnabled : Boolean = true;
        attribute poweredOn : Boolean = false;

        port videoIn : ~VideoPort;
        port videoOut : VideoPort;
        port controlIn : ~ControlPort;
        port powerIn : PowerPort;

        action def processVideo {
            in raw : DigitalVideoStream;
            out enhanced : DigitalVideoStream;
        }

        state machine def VideoProcessorOperation {
            entry; then Off;
            state Off;
            state Ready;
            state Processing;
            transition from Off to Ready when self.poweredOn == true;
            transition from Ready to Processing when videoIn.video != null;
            transition from Processing to Ready when videoIn.video == null;
            transition from Ready to Off when self.poweredOn == false;
        }
    }

    part def DisplayMonitor {
        attribute screenSize : LengthValue = 600 [mm];
        attribute nativeResolution : ResolutionValue = 1920 * 1080 [px];
        attribute poweredOn : Boolean = false;

        port videoIn : ~VideoPort;
        port controlIn : ~ControlPort;
        port powerIn : PowerPort;

        action def renderVideo {
            in stream : DigitalVideoStream;
        }

        state machine def DisplayOperation {
            entry; then Off;
            state Off;
            state On;
            transition from Off to On when self.poweredOn == true;
            transition from On to Off when self.poweredOn == false;
        }
    }

    part def FluidManagementUnit {
        attribute targetPressure : PressureValue = 1500 [Pa];
        attribute minSafePressure : PressureValue = 800 [Pa];
        attribute maxSafePressure : PressureValue = 2200 [Pa];
        attribute irrigationFlowSetting : FlowRateValue = 250 [mL/min];
        attribute suctionFlowSetting : FlowRateValue = 250 [mL/min];
        attribute currentPressure : PressureValue = 0 [Pa];
        attribute primed : Boolean = false;
        attribute poweredOn : Boolean = false;

        port irrigationOut : FluidPort;
        port suctionIn : ~FluidPort;
        port controlIn : ~ControlPort;
        port powerIn : PowerPort;

        part irrigationPump {
            attribute maxFlow : FlowRateValue = 500 [mL/min];
            attribute currentFlow : FlowRateValue = 0 [mL/min];
        }
        part suctionPump {
            attribute maxFlow : FlowRateValue = 500 [mL/min];
            attribute currentFlow : FlowRateValue = 0 [mL/min];
        }
        part pressureSensor {
            attribute reading : PressureValue = 0 [Pa];
        }

        action def circulateFluid {
            in irrigation : FlowRateValue;
            in suction : FlowRateValue;
            out fluidOut : AmnioticFluid;
            in fluidReturn : AmnioticFluid;
        }

        state machine def FluidManagementOperation {
            entry; then Idle;
            state Idle;
            state Priming;
            state Circulating;
            state Draining;
            transition from Idle to Priming when self.poweredOn == true;
            transition from Priming to Circulating when self.primed == true;
            transition from Circulating to Draining when controlIn.command.target == "fluid" && controlIn.command.parameter == "withdraw";
            transition from Draining to Idle when pressureSensor.reading <= 0 [Pa];
        }
    }

    part def ControlConsole {
        attribute lightIntensitySetting : LightIntensityValue = 2000 [cd];
        attribute irrigationFlowSetting : FlowRateValue = 200 [mL/min];
        attribute suctionFlowSetting : FlowRateValue = 200 [mL/min];
        attribute videoBrightnessSetting : Real = 0.5;
        attribute videoContrastSetting : Real = 0.5;
        attribute powerOn : Boolean = false;
        attribute withdrawCommand : Boolean = false;

        port controlOut : ControlPort;
        port telemetryIn : ~ControlPort;
        port powerIn : PowerPort;

        action def adjustLight {
            in level : LightIntensityValue;
            out command : ControlCommand;
        }
        action def adjustFluid {
            in irrigation : FlowRateValue;
            in suction : FlowRateValue;
            out command : ControlCommand;
        }
        action def adjustVideo {
            in brightness : Real;
            in contrast : Real;
            out command : ControlCommand;
        }
        action def monitorTelemetry {
            in telemetry : TelemetryData;
        }

        state machine def ConsoleOperation {
            entry; then PoweredOff;
            state PoweredOff;
            state Standby;
            state Active;
            transition from PoweredOff to Standby when self.powerOn == true;
            transition from Standby to Active when self.withdrawCommand == false;
            transition from Active to Standby when self.withdrawCommand == true;
            transition from Standby to PoweredOff when self.powerOn == false;
        }
    }

    // ---------- Top-Level System ----------
    part def FetoscopySystem {
        attribute systemReady : Boolean = false;
        attribute procedureActive : Boolean = false;
        attribute powerOn : Boolean = false;
        attribute withdrawCommand : Boolean = false;

        part fetoscope : Fetoscope;
        part lightSource : LightSource;
        part cameraHead : CameraHead;
        part videoProcessor : VideoProcessor;
        part displayMonitor : DisplayMonitor;
        part fluidManagementUnit : FluidManagementUnit;
        part controlConsole : ControlConsole;

        // Optical / light path
        connection lightSource.lightOut to fetoscope.lightIn;
        connection fetoscope.opticalOut to cameraHead.opticalIn;

        // Video path
        connection cameraHead.videoOut to videoProcessor.videoIn;
        connection videoProcessor.videoOut to displayMonitor.videoIn;

        // Fluid path
        connection fluidManagementUnit.irrigationOut to fetoscope.workingChannelIn;
        connection fetoscope.workingChannelOut to fluidManagementUnit.suctionIn;

        // Control network
        connection controlConsole.controlOut to lightSource.controlIn;
        connection controlConsole.controlOut to cameraHead.controlIn;
        connection controlConsole.controlOut to videoProcessor.controlIn;
        connection controlConsole.controlOut to displayMonitor.controlIn;
        connection controlConsole.controlOut to fluidManagementUnit.controlIn;

        // Telemetry return
        connection lightSource.controlIn to controlConsole.telemetryIn;
        connection fluidManagementUnit.controlIn to controlConsole.telemetryIn;

        state machine def SystemOperation {
            entry; then Standby;
            state Standby {
                entry action { self.powerOn = false; }
            }
            state PreparationCalibration {
                entry action {
                    lightSource.poweredOn = true;
                    cameraHead.poweredOn = true;
                    videoProcessor.poweredOn = true;
                    displayMonitor.poweredOn = true;
                    fluidManagementUnit.poweredOn = true;
                }
            }
            state ActiveOperating {
                entry action {
                    fetoscope.inserted = true;
                    self.procedureActive = true;
                }
            }
            state SafeWithdrawal {
                entry action {
                    self.withdrawCommand = true;
                    fluidManagementUnit.currentPressure = 0 [Pa];
                }
            }
            transition from Standby to PreparationCalibration when controlConsole.powerOn == true;
            transition from PreparationCalibration to ActiveOperating when cameraHead.calibrated == true && fluidManagementUnit.primed == true;
            transition from ActiveOperating to SafeWithdrawal when controlConsole.withdrawCommand == true;
            transition from SafeWithdrawal to Standby when fetoscope.removed == true;
        }

        satisfy ProvideRealTimeVisualization by self;
        satisfy MaintainUterinePressure by self;
        satisfy ProvideIllumination by self;
        satisfy ProvideFluidCirculation by self;
    }

    // ---------- Requirements ----------
    requirement def ProvideRealTimeVisualization {
        subject system : FetoscopySystem;
        requirement {
            system.displayMonitor.videoIn.video.frameRate >= 30 [Hz]
        }
        requirement {
            system.displayMonitor.videoIn.video.resolution >= 1920 * 1080 [px]
        }
    }

    requirement def MaintainUterinePressure {
        subject system : FetoscopySystem;
        requirement {
            system.fluidManagementUnit.currentPressure >= system.fluidManagementUnit.minSafePressure
        }
        requirement {
            system.fluidManagementUnit.currentPressure <= system.fluidManagementUnit.maxSafePressure
        }
    }

    requirement def ProvideIllumination {
        subject system : FetoscopySystem;
        requirement {
            system.lightSource.currentIntensity >= 500 [cd]
        }
        requirement {
            system.lightSource.currentIntensity <= system.lightSource.maxIntensity
        }
    }

    requirement def ProvideFluidCirculation {
        subject system : FetoscopySystem;
        requirement {
            system.fluidManagementUnit.irrigationPump.currentFlow >= 50 [mL/min]
        }
        requirement {
            system.fluidManagementUnit.suctionPump.currentFlow >= 50 [mL/min]
        }
    }

    requirement def EnsureSafeWithdrawal {
        subject system : FetoscopySystem;
        requirement {
            system.fluidManagementUnit.currentPressure <= 100 [Pa] @ SafeWithdrawal
        }
    }

}
