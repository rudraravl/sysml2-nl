package IntuitiveSurgicalRoboticAssistedSurgeryModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Length_mm :> ScalarValues::Real {
        unit = "mm";
    }

    attribute def Angle_deg :> ScalarValues::Real {
        unit = "deg";
    }

    attribute def Force_N :> ScalarValues::Real {
        unit = "N";
    }

    attribute def Torque_Nm :> ScalarValues::Real {
        unit = "N*m";
    }

    attribute def Time_s :> ScalarValues::Real {
        unit = "s";
    }

    attribute def Frequency_Hz :> ScalarValues::Real {
        unit = "Hz";
    }

    attribute def Power_W :> ScalarValues::Real {
        unit = "W";
    }

    attribute def Voltage_V :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Temperature_C :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def DataRate_Mbps :> ScalarValues::Real {
        unit = "Mbit/s";
    }

    enum def InstrumentKind {
        grasper;
        needleDriver;
        monopolarScissors;
        bipolarForceps;
        clipApplier;
        suctionIrrigator;
        endoscope;
    }

    enum def SystemMode {
        poweredOff;
        selfTest;
        sterileSetup;
        docking;
        ready;
        teleoperation;
        paused;
        fault;
        emergencyStop;
        shutdown;
    }

    enum def EnergyMode {
        disabled;
        monopolarCut;
        monopolarCoagulate;
        bipolarCoagulate;
    }

    item def SurgeonHandMotion {
        attribute x: Length_mm;
        attribute y: Length_mm;
        attribute z: Length_mm;
        attribute roll: Angle_deg;
        attribute pitch: Angle_deg;
        attribute yaw: Angle_deg;
        attribute grip: ScalarValues::Real;
        attribute timestamp: Time_s;
    }

    item def SurgeonFootCommand {
        attribute clutch: Boolean;
        attribute cameraControl: Boolean;
        attribute energyEnable: Boolean;
        attribute energyMode: EnergyMode;
        attribute timestamp: Time_s;
    }

    item def InstrumentMotionCommand {
        attribute armId: ScalarValues::Integer;
        attribute targetX: Length_mm;
        attribute targetY: Length_mm;
        attribute targetZ: Length_mm;
        attribute targetRoll: Angle_deg;
        attribute targetPitch: Angle_deg;
        attribute targetYaw: Angle_deg;
        attribute jawAngle: Angle_deg;
        attribute maxForce: Force_N;
        attribute timestamp: Time_s;
    }

    item def InstrumentTelemetry {
        attribute armId: ScalarValues::Integer;
        attribute actualX: Length_mm;
        attribute actualY: Length_mm;
        attribute actualZ: Length_mm;
        attribute actualRoll: Angle_deg;
        attribute actualPitch: Angle_deg;
        attribute actualYaw: Angle_deg;
        attribute jawAngle: Angle_deg;
        attribute tipForceEstimate: Force_N;
        attribute motorTemperature: Temperature_C;
        attribute timestamp: Time_s;
    }

    item def StereoVideoFrame {
        attribute frameId: ScalarValues::Integer;
        attribute widthPixels: ScalarValues::Integer;
        attribute heightPixels: ScalarValues::Integer;
        attribute frameRate: Frequency_Hz;
        attribute latency: Time_s;
        attribute timestamp: Time_s;
    }

    item def PatientPhysiology {
        attribute heartRate: Frequency_Hz;
        attribute oxygenSaturation: ScalarValues::Real;
        attribute insufflationPressure: ScalarValues::Real;
        attribute timestamp: Time_s;
    }

    item def SystemAlert {
        attribute code: ScalarValues::String;
        attribute severity: ScalarValues::Integer;
        attribute message: ScalarValues::String;
        attribute timestamp: Time_s;
    }

    port def HandControllerPort {
        out item motion: SurgeonHandMotion;
    }

    port def FootPedalPort {
        out item command: SurgeonFootCommand;
    }

    port def CommandPort {
        in item handMotion: SurgeonHandMotion;
        in item footCommand: SurgeonFootCommand;
        out item instrumentCommand: InstrumentMotionCommand;
    }

    port def ArmCommandPort {
        in item command: InstrumentMotionCommand;
        out item telemetry: InstrumentTelemetry;
    }

    port def VideoCapturePort {
        out item frame: StereoVideoFrame;
    }

    port def VideoDisplayPort {
        in item frame: StereoVideoFrame;
    }

    port def AlertPort {
        inout item alert: SystemAlert;
    }

    port def PhysiologyMonitorPort {
        in item physiology: PatientPhysiology;
    }

    port def PowerPort {
        in attribute voltage: Voltage_V;
        in attribute availablePower: Power_W;
    }

    part def SurgeonConsole {
        attribute displayLatencyLimit: Time_s = 0.150;
        attribute handControllerSamplingRate: Frequency_Hz = 1000.0;
        attribute ergonomicAdjustmentRange: Length_mm = 250.0;

        port leftHand: HandControllerPort;
        port rightHand: HandControllerPort;
        port footPedals: FootPedalPort;
        port videoDisplay: VideoDisplayPort;
        port alerts: AlertPort;
        port power: PowerPort;

        action def CaptureSurgeonInput {
            out item leftMotion: SurgeonHandMotion;
            out item rightMotion: SurgeonHandMotion;
            out item footCommand: SurgeonFootCommand;
        }
    }

    part def VisionSystem {
        attribute nominalFrameRate: Frequency_Hz = 60.0;
        attribute maxEndToEndLatency: Time_s = 0.150;
        attribute endoscopeDiameter: Length_mm = 8.0;
        attribute illuminationPower: Power_W = 120.0;

        port capture: VideoCapturePort;
        port displayFeed: VideoDisplayPort;
        port alerts: AlertPort;
        port power: PowerPort;

        action def AcquireStereoImage {
            out item frame: StereoVideoFrame;
        }

        action def AdjustCameraView {
            in item command: InstrumentMotionCommand;
            out item frame: StereoVideoFrame;
        }
    }

    part def SurgicalInstrument {
        attribute kind: InstrumentKind;
        attribute shaftDiameter: Length_mm = 8.0;
        attribute usableLength: Length_mm = 540.0;
        attribute wristYawRange: Angle_deg = 90.0;
        attribute wristPitchRange: Angle_deg = 90.0;
        attribute maximumTipForce: Force_N = 7.5;
        attribute sterileUseRemaining: ScalarValues::Integer;

        port armInterface: ArmCommandPort;

        action def MoveEndEffector {
            in item command: InstrumentMotionCommand;
            out item telemetry: InstrumentTelemetry;
        }

        action def ApplyEnergy {
            in attribute mode: EnergyMode;
            in attribute duration: Time_s;
            out item alert: SystemAlert;
        }
    }

    part def PatientCartArm {
        attribute armId: ScalarValues::Integer;
        attribute remoteCenterOfMotionErrorLimit: Length_mm = 1.0;
        attribute positionAccuracy: Length_mm = 0.5;
        attribute maximumJointTorque: Torque_Nm = 24.0;
        attribute maximumPayload: Force_N = 35.0;

        port commandInterface: ArmCommandPort;
        part instrument: SurgicalInstrument;

        bind commandInterface = instrument.armInterface;

        action def EnforceRemoteCenterOfMotion {
            in item command: InstrumentMotionCommand;
            out item constrainedCommand: InstrumentMotionCommand;
        }

        action def ExecuteArmMotion {
            in item command: InstrumentMotionCommand;
            out item telemetry: InstrumentTelemetry;
        }
    }

    part def PatientCart {
        attribute armCount: ScalarValues::Integer = 4;
        attribute dockingWorkspaceRadius: Length_mm = 900.0;
        attribute setupJointSpeedLimit: ScalarValues::Real = 0.05;

        port armCommand: ArmCommandPort;
        port alerts: AlertPort;
        port power: PowerPort;

        part cameraArm: PatientCartArm {
            attribute armId = 0;
            part instrument: SurgicalInstrument {
                attribute kind = InstrumentKind::endoscope;
            }
        }

        part instrumentArm1: PatientCartArm {
            attribute armId = 1;
            part instrument: SurgicalInstrument {
                attribute kind = InstrumentKind::monopolarScissors;
            }
        }

        part instrumentArm2: PatientCartArm {
            attribute armId = 2;
            part instrument: SurgicalInstrument {
                attribute kind = InstrumentKind::bipolarForceps;
            }
        }

        part instrumentArm3: PatientCartArm {
            attribute armId = 3;
            part instrument: SurgicalInstrument {
                attribute kind = InstrumentKind::needleDriver;
            }
        }

        action def DockToPatient {
            in attribute targetPortSpacing: Length_mm;
            out attribute docked: Boolean;
        }

        action def RetractAllArms {
            out attribute retracted: Boolean;
        }
    }

    part def ControlCore {
        attribute controlLoopRate: Frequency_Hz = 1000.0;
        attribute maxCommandLatency: Time_s = 0.050;
        attribute motionScale: ScalarValues::Real = 0.33;
        attribute tremorFilterCutoff: Frequency_Hz = 10.0;
        attribute safetyProcessorPower: Power_W = 85.0;

        port consoleCommands: CommandPort;
        port cartCommands: ArmCommandPort;
        port videoInput: VideoCapturePort;
        port videoOutput: VideoDisplayPort;
        port physiologyInput: PhysiologyMonitorPort;
        port alerts: AlertPort;
        port power: PowerPort;

        action def TransformSurgeonMotionToInstrumentMotion {
            in item leftMotion: SurgeonHandMotion;
            in item rightMotion: SurgeonHandMotion;
            in item footCommand: SurgeonFootCommand;
            out item instrumentCommand: InstrumentMotionCommand;
        }

        action def MonitorSafetyLimits {
            in item telemetry: InstrumentTelemetry;
            in item physiology: PatientPhysiology;
            out item alert: SystemAlert;
        }

        action def RouteStereoVideo {
            in item frame: StereoVideoFrame;
            out item displayedFrame: StereoVideoFrame;
        }
    }

    part def EnergyUnit {
        attribute maximumOutputPower: Power_W = 120.0;
        attribute activationLatency: Time_s = 0.020;
        attribute neutralElectrodeRequired: Boolean = true;

        port commandInput: FootPedalPort;
        port alerts: AlertPort;
        port power: PowerPort;

        action def DeliverTherapeuticEnergy {
            in attribute mode: EnergyMode;
            in attribute duration: Time_s;
            out item alert: SystemAlert;
        }
    }

    part def RoboticAssistedSurgerySystem {
        attribute manufacturerDomain: ScalarValues::String = "Intuitive Surgical";
        attribute primaryFunction: ScalarValues::String =
            "Enable a surgeon at a console to perform minimally invasive surgery by translating hand and foot inputs into scaled, filtered robotic instrument motion while providing stereoscopic visualization and safety interlocks.";
        attribute currentMode: SystemMode = SystemMode::poweredOff;
        attribute nominalSupplyVoltage: Voltage_V = 240.0;
        attribute maximumSystemPower: Power_W = 1800.0;

        port mainsPower: PowerPort;
        port clinicalAlerts: AlertPort;
        port patientMonitor: PhysiologyMonitorPort;

        part console: SurgeonConsole;
        part controlCore: ControlCore;
        part patientCart: PatientCart;
        part vision: VisionSystem;
        part energyUnit: EnergyUnit;

        connect console.leftHand.motion to controlCore.consoleCommands.handMotion;
        connect console.rightHand.motion to controlCore.consoleCommands.handMotion;
        connect console.footPedals.command to controlCore.consoleCommands.footCommand;
        connect console.footPedals.command to energyUnit.commandInput.command;

        connect controlCore.cartCommands.command to patientCart.armCommand.command;
        connect patientCart.armCommand.telemetry to controlCore.cartCommands.telemetry;

        connect vision.capture.frame to controlCore.videoInput.frame;
        connect controlCore.videoOutput.frame to console.videoDisplay.frame;

        connect patientMonitor.physiology to controlCore.physiologyInput.physiology;

        connect controlCore.alerts.alert to clinicalAlerts.alert;
        connect patientCart.alerts.alert to clinicalAlerts.alert;
        connect vision.alerts.alert to clinicalAlerts.alert;
        connect energyUnit.alerts.alert to clinicalAlerts.alert;
        connect console.alerts.alert to clinicalAlerts.alert;

        connect mainsPower.voltage to console.power.voltage;
        connect mainsPower.voltage to controlCore.power.voltage;
        connect mainsPower.voltage to patientCart.power.voltage;
        connect mainsPower.voltage to vision.power.voltage;
        connect mainsPower.voltage to energyUnit.power.voltage;

        action def PerformRoboticAssistedProcedure {
            in item physiology: PatientPhysiology;
            out item alerts: SystemAlert;

            first start;
            then initialize;
            then dock;
            then teleoperate;
            then close;

            action start {
                out attribute mode: SystemMode = SystemMode::selfTest;
            }

            action initialize {
                out attribute mode: SystemMode = SystemMode::sterileSetup;
            }

            action dock {
                in attribute targetPortSpacing: Length_mm = 80.0;
                out attribute mode: SystemMode = SystemMode::ready;
            }

            action teleoperate {
                in item physiology;
                out attribute mode: SystemMode = SystemMode::teleoperation;
                out item alerts;
            }

            action close {
                out attribute mode: SystemMode = SystemMode::shutdown;
            }
        }

        state def OperationalStates {
            entry action InitializePower {
                out attribute mode: SystemMode = SystemMode::selfTest;
            }

            state PoweredOff;
            state SelfTest;
            state SterileSetup;
            state Docking;
            state Ready;
            state Teleoperation;
            state Paused;
            state Fault;
            state EmergencyStop;
            state Shutdown;

            first PoweredOff;

            transition PowerOn
                first PoweredOff
                then SelfTest;

            transition SelfTestPassed
                first SelfTest
                then SterileSetup;

            transition SterileFieldConfirmed
                first SterileSetup
                then Docking;

            transition DockingComplete
                first Docking
                then Ready;

            transition SurgeonHeadInConsoleAndInstrumentsEnabled
                first Ready
                then Teleoperation;

            transition SurgeonClutchOrHeadOut
                first Teleoperation
                then Paused;

            transition ResumeProcedure
                first Paused
                then Teleoperation;

            transition RecoverPause
                first Paused
                then Ready;

            transition SafetyLimitExceeded
                first Teleoperation
                then Fault;

            transition FaultCleared
                first Fault
                then Ready;

            transition EmergencyStopPressed
                first Ready
                then EmergencyStop;

            transition EmergencyStopDuringTeleoperation
                first Teleoperation
                then EmergencyStop;

            transition ProcedureComplete
                first Ready
                then Shutdown;

            transition ShutdownComplete
                first Shutdown
                then PoweredOff;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system: RoboticAssistedSurgerySystem;

        doc
            /* The system shall provide surgeon-controlled robotic assistance for minimally invasive procedures by converting surgeon console inputs into scaled and filtered motion of patient-side surgical instruments while maintaining real-time stereoscopic visualization. */

        require constraint {
            system.controlCore.controlLoopRate >= 1000.0 and
            system.controlCore.maxCommandLatency <= 0.050 and
            system.vision.maxEndToEndLatency <= 0.150
        }
    }

    requirement def MotionScalingRequirement {
        subject system: RoboticAssistedSurgerySystem;

        doc
            /* The control core shall scale surgeon hand motion to instrument tip motion to support precise manipulation in confined anatomy. */

        require constraint {
            system.controlCore.motionScale > 0.0 and
            system.controlCore.motionScale <= 1.0
        }
    }

    requirement def RemoteCenterOfMotionRequirement {
        subject arm: PatientCartArm;

        doc
            /* Each patient cart arm shall constrain instrument shaft motion about a remote center of motion at the body-wall entry site. */

        require constraint {
            arm.remoteCenterOfMotionErrorLimit <= 1.0
        }
    }

    requirement def VisualizationRequirement {
        subject visionSystem: VisionSystem;

        doc
            /* The vision system shall provide stereoscopic video to the surgeon console with frame rate and latency sufficient for teleoperated surgery. */

        require constraint {
            visionSystem.nominalFrameRate >= 60.0 and
            visionSystem.maxEndToEndLatency <= 0.150
        }
    }

    requirement def InstrumentSafetyRequirement {
        subject instrument: SurgicalInstrument;

        doc
            /* Surgical instruments shall limit commanded end-effector force to reduce risk of unintended tissue trauma. */

        require constraint {
            instrument.maximumTipForce <= 7.5
        }
    }

    requirement def EmergencyStopRequirement {
        subject system: RoboticAssistedSurgerySystem;

        doc
            /* The system shall transition to emergency stop when a critical safety command is asserted or a severe unrecoverable fault is detected. */

        require constraint {
            system.currentMode != SystemMode::teleoperation or
            system.controlCore.maxCommandLatency <= 0.050
        }
    }

    requirement def ElectricalPowerRequirement {
        subject system: RoboticAssistedSurgerySystem;

        doc
            /* The system shall operate from clinical mains power while keeping total power draw within the rated system limit. */

        require constraint {
            system.nominalSupplyVoltage == 240.0 and
            system.maximumSystemPower <= 1800.0
        }
    }

    satisfy PrimaryFunctionRequirement by RoboticAssistedSurgerySystem;
    satisfy MotionScalingRequirement by ControlCore;
    satisfy RemoteCenterOfMotionRequirement by PatientCartArm;
    satisfy VisualizationRequirement by VisionSystem;
    satisfy InstrumentSafetyRequirement by SurgicalInstrument;
    satisfy EmergencyStopRequirement by RoboticAssistedSurgerySystem;
    satisfy ElectricalPowerRequirement by RoboticAssistedSurgerySystem;

}