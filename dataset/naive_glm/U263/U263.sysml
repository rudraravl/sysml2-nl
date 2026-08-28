package EndoscopySystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    attribute def PressureValue :> Real {
        unit mmHg;
    }
    attribute def FlowRateValue :> Real {
        unit 'mL/min';
    }
    attribute def ResolutionValue :> Real {
        unit pixel;
    }
    attribute def TemperatureValue :> Real {
        unit 'degC';
    }
    attribute def DiameterValue :> Real {
        unit mm;
    }
    attribute def LengthValue :> Real {
        unit mm;
    }
    attribute def FrequencyValue :> Real {
        unit Hz;
    }
    attribute def LuminousFluxValue :> Real {
        unit lumen;
    }

    // ---------- Enumerations ----------
    enum def ProcedurePhase {
        EquipmentCheck = 0,
        Insertion = 1,
        Examination = 2,
        Intervention = 3,
        Withdrawal = 4,
        Shutdown = 5
    }

    enum def GasType {
        CO2,
        Air
    }

    enum def FluidType {
        SterileSaline,
        Water
    }

    enum def InstrumentType {
        BiopsyForceps,
        Snare,
        Grasper,
        None
    }

    enum def ImageMode {
        Standard,
        Enhanced,
        NarrowBand
    }

    // ---------- Item Types ----------
    item def Gas {
        attribute type : GasType;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def Fluid {
        attribute type : FluidType;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    item def LightBeam {
        attribute flux : LuminousFluxValue;
        attribute colorTemp : TemperatureValue;
    }

    item def RawVideoSignal {
        attribute resolution : ResolutionValue;
        attribute frameRate : FrequencyValue;
    }

    item def ProcessedVideoSignal {
        attribute resolution : ResolutionValue;
        attribute frameRate : FrequencyValue;
        attribute mode : ImageMode;
    }

    item def TissueSpecimen {
        attribute sampleId : String;
        attribute origin : String;
    }

    item def ControlCommand {
        attribute target : String;
        attribute action : String;
        attribute value : Real;
    }

    item def StatusReport {
        attribute component : String;
        attribute state : String;
        attribute alarm : Boolean;
    }

    // ---------- Port Definitions ----------
    port def LightPort {
        out light : LightBeam;
    }

    port def GasPort {
        out gas : Gas;
    }

    port def FluidPort {
        out fluid : Fluid;
    }

    port def RawVideoPort {
        out rawVideo : RawVideoSignal;
    }

    port def ProcessedVideoPort {
        out processedVideo : ProcessedVideoSignal;
    }

    port def WorkingChannelPort {
        in instrument : InstrumentType;
        out specimen : TissueSpecimen;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : StatusReport;
    }

    port def DisplayPort {
        in video : ProcessedVideoSignal;
    }

    // ---------- Requirements ----------
    requirement def PatientSafetyRequirement {
        doc /* The system shall ensure patient safety during all phases of operation. */
        requirement maxGasPressure {
            doc /* Gas pressure delivered to the patient shall not exceed 15 mmHg. */
            attribute maxPressure : PressureValue = 15;
        }
        requirement maxFluidFlow {
            doc /* Irrigation fluid flow rate shall not exceed 500 mL/min. */
            attribute maxFlow : FlowRateValue = 500;
        }
        requirement sterility {
            doc /* All patient-contact components shall be sterile or sterilizable. */
            attribute contactComponentsSterile : Boolean = true;
        }
        requirement temperatureLimit {
            doc /* Surface temperature of patient-contact parts shall not exceed 42 degC. */
            attribute maxTemp : TemperatureValue = 42;
        }
    }

    requirement def ImageQualityRequirement {
        doc /* The system shall provide high-definition image quality for accurate diagnosis. */
        requirement minResolution {
            doc /* Video resolution shall be at least 1920x1080 pixels. */
            attribute minPixels : ResolutionValue = 2073600;
        }
        requirement minFrameRate {
            doc /* Video frame rate shall be at least 30 Hz. */
            attribute minFrames : FrequencyValue = 30;
        }
        requirement lowLatency {
            doc /* Video processing latency shall not exceed 50 ms. */
            attribute maxLatencyMs : Real = 50;
        }
    }

    requirement def ProcedureWorkflowRequirement {
        doc /* The system shall support all phases of an endoscopic procedure. */
        requirement phaseSupport {
            doc /* The system shall operate through EquipmentCheck, Insertion, Examination, Intervention, and Withdrawal phases. */
        }
        requirement emergencyWithdrawal {
            doc /* The system shall allow rapid withdrawal of the endoscope in case of emergency. */
            attribute maxWithdrawalTimeSec : Real = 30;
        }
    }

    // ---------- Part Definitions ----------

    part def Endoscope {
        attribute insertionLength : LengthValue = 1100;
        attribute insertionDiameter : DiameterValue = 9.8;
        attribute isSterile : Boolean = true;

        port lightIn : LightPort;
        port rawVideoOut : RawVideoPort;
        port workingChannel : WorkingChannelPort;
        port gasDelivery : GasPort;
        port fluidDelivery : FluidPort;
        port control : ControlPort;

        part insertionTube :> InsertionTube;
        part camera :> CameraModule;
        part lightChannel :> LightChannel;
        part workingChannelTube :> WorkingChannelTube;

        connection lightConn connect lightIn to lightChannel.lightIn;
        connection lightToTip connect lightChannel.lightOut to camera.illumination;
        connection cameraConn connect camera.videoOut to rawVideoOut;
        connection workingConn connect workingChannelTube.instrumentPort to workingChannel;
    }

    part def InsertionTube {
        attribute length : LengthValue = 1100;
        attribute diameter : DiameterValue = 9.8;
        attribute bendingAngle : Real = 210;
        attribute isFlexible : Boolean = true;
    }

    part def CameraModule {
        attribute sensorResolution : ResolutionValue = 2073600;
        attribute frameRate : FrequencyValue = 60;
        attribute fieldOfView : Real = 140;

        port illumination : LightPort;
        port videoOut : RawVideoPort;
    }

    part def LightChannel {
        attribute diameter : DiameterValue = 1.2;
        port lightIn : LightPort;
        port lightOut : LightPort;
    }

    part def WorkingChannelTube {
        attribute diameter : DiameterValue = 3.2;
        attribute length : LengthValue = 1100;
        port instrumentPort : WorkingChannelPort;
    }

    part def LightSource {
        attribute maxFlux : LuminousFluxValue = 5000;
        attribute colorTemp : TemperatureValue = 5500;
        attribute intensityLevel : Real = 0.0;

        port lightOut : LightPort;
        port control : ControlPort;

        action def adjustIntensity {
            in targetLevel : Real;
            out newLevel : Real;
        }
    }

    part def VideoProcessor {
        attribute supportedModes : ImageMode[3] = [ImageMode::Standard, ImageMode::Enhanced, ImageMode::NarrowBand];
        attribute currentMode : ImageMode = ImageMode::Enhanced;
        attribute processingLatencyMs : Real = 35;

        port rawVideoIn : RawVideoPort;
        port processedVideoOut : ProcessedVideoPort;
        port control : ControlPort;

        action def processVideo {
            in raw : RawVideoSignal;
            out processed : ProcessedVideoSignal;
        }
    }

    part def DisplayMonitor {
        attribute resolution : ResolutionValue = 2073600;
        attribute screenSize : Real = 27;
        attribute refreshRate : FrequencyValue = 60;

        port videoIn : DisplayPort;
    }

    part def InsufflationUnit {
        attribute gasType : GasType = GasType::CO2;
        attribute maxPressure : PressureValue = 15;
        attribute currentPressure : PressureValue = 0;
        attribute flowRate : FlowRateValue = 0;

        port gasOut : GasPort;
        port control : ControlPort;

        action def pumpGas {
            in targetPressure : PressureValue;
            in flow : FlowRateValue;
            out deliveredGas : Gas;
        }

        action def monitorPressure {
            in measuredPressure : PressureValue;
            out alarm : Boolean;
        }
    }

    part def IrrigationPump {
        attribute fluidType : FluidType = FluidType::SterileSaline;
        attribute maxFlowRate : FlowRateValue = 500;
        attribute currentFlowRate : FlowRateValue = 0;
        attribute reservoirVolume : Real = 1000;

        port fluidOut : FluidPort;
        port control : ControlPort;

        action def deliverFluid {
            in flow : FlowRateValue;
            out deliveredFluid : Fluid;
        }
    }

    part def BiopsyForceps {
        attribute type : InstrumentType = InstrumentType::BiopsyForceps;
        attribute cupDiameter : DiameterValue = 2.5;
        attribute isSterile : Boolean = true;
        attribute isSingleUse : Boolean = true;

        port interface : WorkingChannelPort;

        action def collectSpecimen {
            in site : String;
            out specimen : TissueSpecimen;
        }
    }

    part def CentralControlUnit {
        attribute currentPhase : ProcedurePhase = ProcedurePhase::EquipmentCheck;
        attribute systemActive : Boolean = false;
        attribute safetyInterlocksActive : Boolean = true;

        port lightControl : ControlPort;
        port gasControl : ControlPort;
        port fluidControl : ControlPort;
        port processorControl : ControlPort;
        port endoscopeControl : ControlPort;

        action def executePhase {
            in phase : ProcedurePhase;
            out commands : ControlCommand[*];
        }

        action def safetyCheck {
            out allClear : Boolean;
            out alarms : StatusReport[*];
        }

        action def emergencyStop {
            out stopCommand : ControlCommand;
        }

        state def ControlStateMachine {
            entry; then EquipmentCheckState;

            state EquipmentCheckState {
                entry {
                    attribute currentPhase = ProcedurePhase::EquipmentCheck;
                }
                do perform safetyCheck();
                transition to InsertionState
                    when (safetyCheck.allClear == true);
            }

            state InsertionState {
                entry {
                    attribute currentPhase = ProcedurePhase::Insertion;
                }
                do executePhase(ProcedurePhase::Insertion);
                transition to ExaminationState
                    when (endoscopeControl.status.state == "inserted");
            }

            state ExaminationState {
                entry {
                    attribute currentPhase = ProcedurePhase::Examination;
                }
                do executePhase(ProcedurePhase::Examination);
                transition to InterventionState
                    when (workingChannel.instrument == InstrumentType::BiopsyForceps);
                transition to WithdrawalState
                    when (endoscopeControl.status.state == "withdrawal_requested");
            }

            state InterventionState {
                entry {
                    attribute currentPhase = ProcedurePhase::Intervention;
                }
                do executePhase(ProcedurePhase::Intervention);
                transition to ExaminationState
                    when (workingChannel.specimen != null);
            }

            state WithdrawalState {
                entry {
                    attribute currentPhase = ProcedurePhase::Withdrawal;
                }
                do executePhase(ProcedurePhase::Withdrawal);
                transition to ShutdownState
                    when (endoscopeControl.status.state == "removed");
            }

            state ShutdownState {
                entry {
                    attribute currentPhase = ProcedurePhase::Shutdown;
                    attribute systemActive = false;
                }
            }
        }
    }

    // ---------- Top-level System ----------
    part def EndoscopySystem {
        satisfy PatientSafetyRequirement;
        satisfy ImageQualityRequirement;
        satisfy ProcedureWorkflowRequirement;

        part controlUnit : CentralControlUnit {
            part stateMachine : ControlStateMachine;
        }
        part lightSource : LightSource;
        part videoProcessor : VideoProcessor;
        part displayMonitor : DisplayMonitor;
        part insufflationUnit : InsufflationUnit;
        part irrigationPump : IrrigationPump;
        part endoscope : Endoscope;
        part biopsyForceps : BiopsyForceps;

        // Light path: LightSource -> Endoscope
        connection lightToScope connect lightSource.lightOut to endoscope.lightIn;

        // Video path: Endoscope -> VideoProcessor -> Display
        connection rawVideoToProcessor connect endoscope.rawVideoOut to videoProcessor.rawVideoIn;
        connection processedVideoToDisplay connect videoProcessor.processedVideoOut to displayMonitor.videoIn;

        // Gas path: Insufflation -> Endoscope
        connection gasToScope connect insufflationUnit.gasOut to endoscope.gasDelivery;

        // Fluid path: Irrigation -> Endoscope
        connection fluidToScope connect irrigationPump.fluidOut to endoscope.fluidDelivery;

        // Instrument path: BiopsyForceps -> Endoscope working channel
        connection forcepsToScope connect biopsyForceps.interface to endoscope.workingChannel;

        // Control connections
        connection controlToLight connect controlUnit.lightControl to lightSource.control;
        connection controlToGas connect controlUnit.gasControl to insufflationUnit.control;
        connection controlToFluid connect controlUnit.fluidControl to irrigationPump.control;
        connection controlToProcessor connect controlUnit.processorControl to videoProcessor.control;
        connection controlToEndoscope connect controlUnit.endoscopeControl to endoscope.control;
    }
}
