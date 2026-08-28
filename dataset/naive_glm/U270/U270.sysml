package MedicalCystoscopySystem {
    import ScalarValues::*;
    
    package Units {
        attribute def PressureUnit :> Real { /* Pa */ }
        attribute def FlowRateUnit :> Real { /* mL/min */ }
        attribute def VolumeUnit :> Real { /* mL */ }
        attribute def TemperatureUnit :> Real { /* K */ }
        attribute def LuminousFluxUnit :> Real { /* lm */ }
        attribute def ColorTempUnit :> Real { /* K */ }
        attribute def FrequencyUnit :> Real { /* Hz */ }
        attribute def LengthUnit :> Real { /* mm */ }
        attribute def MassUnit :> Real { /* mg */ }
        attribute def DurationUnit :> Real { /* ms */ }
    }
    
    package Items {
        import Units::*;
        
        item def IrrigationFluid {
            attribute volume : VolumeUnit;
            attribute temperature : TemperatureUnit;
            attribute sterilityConfirmed : Boolean;
            attribute pH : Real;
        }
        
        item def TissueSample {
            attribute mass : MassUnit;
            attribute size : LengthUnit;
            attribute originLocation : String;
            attribute isPreserved : Boolean;
        }
        
        item def VideoFrame {
            attribute width : Integer;
            attribute height : Integer;
            attribute frameRate : FrequencyUnit;
            attribute timestamp : Real;
            attribute bitDepth : Integer;
        }
        
        item def LightBeam {
            attribute flux : LuminousFluxUnit;
            attribute colorTemp : ColorTempUnit;
        }
        
        item def ControlCommand {
            attribute commandId : String;
            attribute commandValue : Real;
            attribute timestamp : Real;
        }
    }
    
    package Ports {
        import Items::*;
        import Units::*;
        
        port def FluidPort {
            attribute pressure : PressureUnit;
            attribute flowRate : FlowRateUnit;
            item fluid : IrrigationFluid;
        }
        
        port def LightPort {
            attribute flux : LuminousFluxUnit;
            item beam : LightBeam;
        }
        
        port def VideoPort {
            attribute frameRate : FrequencyUnit;
            item frame : VideoFrame;
        }
        
        port def ControlPort {
            item command : ControlCommand;
        }
        
        port def ElectricalPort {
            attribute voltage : Real;
            attribute current : Real;
        }
        
        port def SamplePort {
            item sample : TissueSample;
        }
        
        port def PatientInterfacePort :> FluidPort {
            item retrievedSample : TissueSample;
        }
    }
    
    package Components {
        import Ports::*;
        import Items::*;
        import Units::*;
        
        part def LightSource {
            attribute colorTemp : ColorTempUnit = 5500;
            attribute maxFlux : LuminousFluxUnit = 5000;
            attribute currentFlux : LuminousFluxUnit;
            port lightOut : LightPort;
            port powerIn : ElectricalPort;
            
            state LightSourceStates {
                entry; then Off;
                state Off;
                state On;
                transition Off to On when powerIn.voltage > 0;
                transition On to Off when powerIn.voltage == 0;
            }
            
            action generateLight {
                out beam : LightBeam;
            }
        }
        
        part def FiberOpticBundle {
            attribute length : LengthUnit;
            attribute flexibility : Real;
            attribute transmissionEfficiency : Real = 0.92;
            port lightIn : LightPort;
            port lightOut : LightPort;
            
            action transmit {
                in beam : LightBeam;
                out transmitted : LightBeam;
            }
        }
        
        part def CameraHead {
            attribute resolutionWidth : Integer = 3840;
            attribute resolutionHeight : Integer = 2160;
            attribute frameRate : FrequencyUnit = 60;
            port videoOut : VideoPort;
            port powerIn : ElectricalPort;
            
            action capture {
                in reflectedLight : LightBeam;
                out frame : VideoFrame;
            }
        }
        
        part def VideoProcessor {
            attribute enhancementMode : String = "HD";
            attribute latency : DurationUnit;
            port videoIn : VideoPort;
            port videoOut : VideoPort;
            port control : ControlPort;
            port powerIn : ElectricalPort;
            
            action processFrame {
                in rawFrame : VideoFrame;
                out enhancedFrame : VideoFrame;
            }
        }
        
        part def DisplayMonitor {
            attribute displaySizeInches : Real;
            attribute nativeResolution : String;
            port videoIn : VideoPort;
            port powerIn : ElectricalPort;
            
            action render {
                in frame : VideoFrame;
            }
        }
        
        part def FluidReservoir {
            attribute capacity : VolumeUnit = 3000;
            attribute currentVolume : VolumeUnit;
            attribute refillThreshold : VolumeUnit = 500;
            port fluidOut : FluidPort;
            
            state ReservoirStates {
                entry; then Adequate;
                state Adequate;
                state Low;
                state Empty;
                transition Adequate to Low when currentVolume < refillThreshold;
                transition Low to Empty when currentVolume <= 0;
                transition Low to Adequate when currentVolume > refillThreshold;
                transition Empty to Adequate when currentVolume > refillThreshold;
            }
            
            action dispense {
                in amount : VolumeUnit;
                out fluid : IrrigationFluid;
            }
        }
        
        part def IrrigationPump {
            attribute maxFlowRate : FlowRateUnit = 400;
            attribute currentFlowRate : FlowRateUnit;
            attribute targetPressure : PressureUnit;
            attribute currentPressure : PressureUnit;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port control : ControlPort;
            port powerIn : ElectricalPort;
            
            state PumpStates {
                entry; then Idle;
                state Idle;
                state Pumping;
                state Faulted;
                transition Idle to Pumping when control.command.commandId == "START";
                transition Pumping to Idle when control.command.commandId == "STOP";
                transition Pumping to Faulted when currentPressure > targetPressure * 1.2;
                transition Faulted to Idle when control.command.commandId == "RESET";
            }
            
            action regulateFlow {
                in desired : FlowRateUnit;
                in measured : PressureUnit;
                out flowCommand : FlowRateUnit;
            }
        }
        
        part def Sheath {
            attribute length : LengthUnit = 300;
            attribute outerDiameter : LengthUnit = 7.5;
            attribute workingChannelDiameter : LengthUnit = 5.0;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port lightIn : LightPort;
            port toolAccess : SamplePort;
        }
        
        part def BiopsyForceps {
            attribute jawSize : LengthUnit = 3.0;
            attribute isDisposable : Boolean = true;
            port sampleOut : SamplePort;
            
            action takeBiopsy {
                in targetLocation : String;
                out sample : TissueSample;
            }
        }
        
        part def Cystoscope {
            part sheath : Sheath;
            part camera : CameraHead;
            part biopsyForceps : BiopsyForceps;
            
            port lightIn : LightPort;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port videoOut : VideoPort;
            port sampleOut : SamplePort;
            port powerIn : ElectricalPort;
            
            connect lightIn to sheath.lightIn;
            connect fluidIn to sheath.fluidIn;
            connect sheath.fluidOut to fluidOut;
            connect camera.videoOut to videoOut;
            connect biopsyForceps.sampleOut to sheath.toolAccess;
            connect sheath.toolAccess to sampleOut;
            connect powerIn to camera.powerIn;
        }
        
        part def ControlConsole {
            attribute operatorId : String;
            attribute currentFlowSetting : FlowRateUnit;
            attribute currentPressureLimit : PressureUnit;
            
            port pumpControl : ControlPort;
            port videoControl : ControlPort;
            port reservoirMonitor : ControlPort;
            
            action issueCommand {
                in cmd : ControlCommand;
            }
            
            action updateFlowRate {
                in desiredFlow : FlowRateUnit;
                out cmd : ControlCommand;
            }
            
            action updatePressureLimit {
                in limit : PressureUnit;
                out cmd : ControlCommand;
            }
        }
    }
    
    package Subsystems {
        import Components::*;
        import Ports::*;
        import Items::*;
        import Units::*;
        
        part def VisualizationSubsystem {
            part lightSource : LightSource;
            part fiberBundle : FiberOpticBundle;
            part camera : CameraHead;
            part videoProcessor : VideoProcessor;
            part monitor : DisplayMonitor;
            
            port lightOut : LightPort;
            port videoIn : VideoPort;
            port control : ControlPort;
            port powerIn : ElectricalPort;
            
            connect lightSource.lightOut to fiberBundle.lightIn;
            connect fiberBundle.lightOut to lightOut;
            connect videoIn to videoProcessor.videoIn;
            connect videoProcessor.videoOut to monitor.videoIn;
            connect powerIn to lightSource.powerIn;
            connect powerIn to camera.powerIn;
            connect powerIn to videoProcessor.powerIn;
            connect powerIn to monitor.powerIn;
        }
        
        part def FluidMgmtSubsystem {
            part reservoir : FluidReservoir;
            part pump : IrrigationPump;
            
            port fluidOut : FluidPort;
            port pumpControl : ControlPort;
            port reservoirMonitor : ControlPort;
            
            connect reservoir.fluidOut to pump.fluidIn;
            connect pump.fluidOut to fluidOut;
            connect pumpControl to pump.control;
        }
    }
    
    package System {
        import Subsystems::*;
        import Components::*;
        import Ports::*;
        import Items::*;
        import Units::*;
        
        part def CystoscopySystem {
            part cystoscope : Cystoscope;
            part visualization : VisualizationSubsystem;
            part fluidMgmt : FluidMgmtSubsystem;
            part console : ControlConsole;
            
            port patientInterface : PatientInterfacePort;
            port power : ElectricalPort;
            
            attribute startCommand : Boolean = false;
            attribute shutdownCommand : Boolean = false;
            attribute initComplete : Boolean = false;
            attribute initFailure : Boolean = false;
            attribute faultDetected : Boolean = false;
            attribute resetCommand : Boolean = false;
            attribute biopsyRequested : Boolean = false;
            attribute biopsyCompleted : Boolean = false;
            
            connect visualization.lightOut to cystoscope.lightIn;
            connect cystoscope.videoOut to visualization.videoIn;
            connect fluidMgmt.fluidOut to cystoscope.fluidIn;
            connect console.pumpControl to fluidMgmt.pumpControl;
            connect console.videoControl to visualization.control;
            connect console.reservoirMonitor to fluidMgmt.reservoirMonitor;
            connect cystoscope.fluidOut to patientInterface;
            connect power to visualization.powerIn;
            
            state SystemStates {
                entry; then Standby;
                state Standby;
                state Initialization {
                    do initializeSystem;
                }
                state Operational {
                    entry; then Monitoring;
                    state Monitoring {
                        do monitorFluidLevel;
                        do monitorPressure;
                        do captureVideo;
                        do regulateFlow;
                    }
                    state Biopsy {
                        do performBiopsy;
                    }
                    transition Monitoring to Biopsy when biopsyRequested;
                    transition Biopsy to Monitoring when biopsyCompleted;
                }
                state Fault {
                    do handleFault;
                }
                transition Standby to Initialization when startCommand;
                transition Initialization to Operational when initComplete;
                transition Initialization to Fault when initFailure;
                transition Operational to Standby when shutdownCommand;
                transition Operational to Fault when faultDetected;
                transition Fault to Standby when resetCommand;
            }
            
            action initializeSystem {
                out success : Boolean;
            }
            action monitorFluidLevel {
                out volume : VolumeUnit;
            }
            action monitorPressure {
                out pressure : PressureUnit;
            }
            action captureVideo {
                out frame : VideoFrame;
            }
            action regulateFlow {
                in targetFlow : FlowRateUnit;
                out actualFlow : FlowRateUnit;
            }
            action performBiopsy {
                in targetLocation : String;
                out sample : TissueSample;
            }
            action handleFault {
                out faultCode : Integer;
            }
        }
    }
    
    package Requirements {
        import System::*;
        import Subsystems::*;
        import Components::*;
        import Units::*;
        
        requirement def CystoscopySystemRequirements {
            subject system : CystoscopySystem;
            
            requirement ProvideVisualization {
                subject viz : system.visualization;
                doc /* The system shall provide real-time high-definition visualization of the bladder and urethra interior. */;
                require { viz.monitor.videoIn.frameRate >= 30; }
            }
            
            requirement RegulateIrrigation {
                subject fluid : system.fluidMgmt;
                doc /* The system shall maintain irrigation flow within configured limits and prevent overpressure. */;
                require { fluid.pump.currentPressure <= 50; }
            }
            
            requirement MaintainFieldOfView {
                subject fluid : system.fluidMgmt;
                doc /* The system shall provide sufficient irrigation to maintain clear field of view during procedure. */;
                require { fluid.pump.currentFlowRate >= 100; }
            }
            
            requirement AllowBiopsy {
                subject scope : system.cystoscope;
                doc /* The system shall permit insertion and operation of biopsy forceps through the cystoscope sheath. */;
                require { scope.sheath.workingChannelDiameter >= scope.biopsyForceps.jawSize; }
            }
            
            requirement SafeOperationStates {
                subject sys : CystoscopySystem;
                doc /* The system shall only enter Operational state after successful initialization. */;
            }
            
            requirement ColorTempSpec {
                subject viz : system.visualization;
                doc /* The light source shall generate bright light at specified color temperature. */;
                require { viz.lightSource.colorTemp == 5500; }
            }
            
            requirement FluidReserve {
                subject fluid : system.fluidMgmt;
                doc /* The fluid reservoir shall hold sufficient sterile irrigation fluid for a procedure. */;
                require { fluid.reservoir.capacity >= 2000; }
            }
        }
    }
}
