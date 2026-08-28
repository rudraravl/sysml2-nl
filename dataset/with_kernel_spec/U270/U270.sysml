package 'Medical Cystoscopy System' {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;

    package Definitions {
        item def IrrigationFluid;
        item def TissueSample;

        item def LightEnergy {
            attribute colorTemperature : TemperatureValue;
            attribute intensity : Real;
        }

        item def VideoSignal {
            attribute frameRate : Real;
            attribute resolution : Real;
        }

        item def FluidState {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
        }

        item def ControlCommand {
            attribute targetFlowRate : VolumeFlowRateValue;
            attribute targetPressure : PressureValue;
        }

        item def SystemStatus {
            attribute isFluidLevelOK : Boolean;
            attribute isPressureOK : Boolean;
            attribute isVideoOK : Boolean;
        }

        port def FluidPort {
            out item fluid : FluidState;
        }

        port def LightPort {
            out item light : LightEnergy;
        }

        port def VideoPort {
            out item video : VideoSignal;
        }

        port def CommandPort {
            out item command : ControlCommand;
        }

        port def StatusPort {
            out item status : SystemStatus;
        }

        port def InstrumentPort {
            out item tissue : TissueSample;
        }

        part def Sheath {
            port irrigationIn : ~FluidPort;
            port irrigationOut : FluidPort;
            port lightIn : ~LightPort;
            port opticalOut : LightPort;
        }

        part def BiopsyForceps {
            port sampleOut : InstrumentPort;
        }

        part def CameraHead {
            port opticalIn : ~LightPort;
            port videoOut : VideoPort;
        }

        part def Cystoscope {
            port fluidInPort : ~FluidPort;
            port lightInPort : ~LightPort;
            port videoOutPort : VideoPort;
            
            part sheath : Sheath;
            part biopsyForceps : BiopsyForceps;
            part cameraHead : CameraHead;
            
            connect fluidInPort to sheath.irrigationIn;
            connect lightInPort to sheath.lightIn;
            connect sheath.opticalOut to cameraHead.opticalIn;
            connect cameraHead.videoOut to videoOutPort;
        }

        part def SampleContainer {
            port sampleIn : ~InstrumentPort;
        }

        part def LightSource {
            attribute inputPower : Real = 100.0;
            port lightOut : LightPort;
        }

        part def FiberOpticBundle {
            port lightIn : ~LightPort;
            port lightOut : LightPort;
        }

        part def VideoProcessor {
            port videoIn : ~VideoPort;
            port videoOut : VideoPort;
        }

        part def DisplayMonitor {
            port videoIn : ~VideoPort;
        }

        part def FluidReservoir {
            port fluidOut : FluidPort;
        }

        part def IrrigationPump {
            port fluidIn : ~FluidPort;
            port fluidOut : FluidPort;
            port commandIn : ~CommandPort;
            port statusOut : StatusPort;
        }

        part def ControlConsole {
            port statusIn : ~StatusPort;
            port commandOut : CommandPort;
        }

        part def Bladder {
            port fluidIn : ~FluidPort;
        }

        part def Patient {
            part bladder : Bladder;
        }

        action def Illuminate {
            in power : Real;
            out light : LightEnergy;
        }

        action def CaptureVideo {
            in lightIn : LightEnergy;
            out videoOut : VideoSignal;
        }

        action def ProcessVideo {
            in inputVideo : VideoSignal;
            out outputVideo : VideoSignal;
        }

        action def PumpFluid {
            in inputFluid : FluidState;
            in command : ControlCommand;
            out outputFluid : FluidState;
        }

        action def RegulateIrrigation {
            in status : SystemStatus;
            out command : ControlCommand;
        }

        action def CollectBiopsy {
            out sample : TissueSample;
        }

        action def PerformInitialization;
        action def MonitorFluidState;
        action def CaptureLiveVideo;
        action def RegulateIrrigationFlow;

        action def OperateSystem {
            action monitorFluidState : MonitorFluidState;
            action captureLiveVideo : CaptureLiveVideo;
            action regulateIrrigationFlow : RegulateIrrigationFlow;
        }

        attribute def StartProcedure;
        attribute def InitializationComplete;
        attribute def StopProcedure;

        state def SystemStates;

        requirement def 'Safe Irrigation Pressure' {
            /* The system shall maintain bladder pressure within a safe patient-specific limit. */
        }

        requirement def 'Clear Visualization' {
            /* The system shall provide continuous high-definition video during the procedure. */
        }

        requirement def 'Sterile Fluid Path' {
            /* The irrigation fluid path shall remain sterile until it enters the bladder. */
        }
    }

    package Usages {
        private import Definitions::*;

        part context {
            part lightSource : LightSource {
                perform action illuminate : Illuminate {
                    in power = inputPower;
                    out light = lightOut.light;
                }
            }

            part fiberOpticBundle : FiberOpticBundle;

            part cystoscope : Cystoscope {
                perform action capture : CaptureVideo {
                    in lightIn = cameraHead.opticalIn.light;
                    out videoOut = cameraHead.videoOut.video;
                }
                perform action collect : CollectBiopsy {
                    out sample = biopsyForceps.sampleOut.tissue;
                }
            }

            part videoProcessor : VideoProcessor {
                perform action process : ProcessVideo {
                    in inputVideo = videoIn.video;
                    out outputVideo = videoOut.video;
                }
            }

            part displayMonitor : DisplayMonitor;

            part fluidReservoir : FluidReservoir;

            part irrigationPump : IrrigationPump {
                perform action pump : PumpFluid {
                    in inputFluid = fluidIn.fluid;
                    in command = commandIn.command;
                    out outputFluid = fluidOut.fluid;
                }
            }

            part controlConsole : ControlConsole {
                perform action regulate : RegulateIrrigation {
                    in status = statusIn.status;
                    out command = commandOut.command;
                }
            }

            part patient : Patient;
            part sampleContainer : SampleContainer;

            flow of fluid : FluidState 
                from fluidReservoir.fluidOut.fluid to irrigationPump.fluidIn.fluid;
            flow of fluid : FluidState 
                from irrigationPump.fluidOut.fluid to cystoscope.fluidInPort.fluid;
            flow of fluid : FluidState 
                from cystoscope.sheath.irrigationOut.fluid to patient.bladder.fluidIn.fluid;

            flow of light : LightEnergy 
                from lightSource.lightOut.light to fiberOpticBundle.lightIn.light;
            flow of light : LightEnergy 
                from fiberOpticBundle.lightOut.light to cystoscope.lightInPort.light;

            flow of video : VideoSignal 
                from cystoscope.videoOutPort.video to videoProcessor.videoIn.video;
            flow of video : VideoSignal 
                from videoProcessor.videoOut.video to displayMonitor.videoIn.video;

            flow of command : ControlCommand 
                from controlConsole.commandOut.command to irrigationPump.commandIn.command;
            flow of status : SystemStatus 
                from irrigationPump.statusOut.status to controlConsole.statusIn.status;

            flow of tissue : TissueSample 
                from cystoscope.biopsyForceps.sampleOut.tissue to sampleContainer.sampleIn.tissue;

            action performInitialization : PerformInitialization;
            action operateSystem : OperateSystem;

            state 'system states' : SystemStates {
                entry; then standby;
                state standby;
                accept StartProcedure then initializing;
                state initializing {
                    entry performInitialization;
                }
                accept InitializationComplete then operational;
                state operational {
                    do operateSystem;
                }
                accept StopProcedure then standby;
            }

            requirement safeIrrigationPressure : 'Safe Irrigation Pressure';
            requirement clearVisualization : 'Clear Visualization';
            requirement sterileFluidPath : 'Sterile Fluid Path';
        }
    }
}
