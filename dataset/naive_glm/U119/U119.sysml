package StereotaxisMagneticNavigationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def MagneticFluxDensity :> Real { unit 'mT'; }
    value def Torque :> Real { unit 'mN.m'; }
    value def Force :> Real { unit 'mN'; }
    value def Angle :> Real { unit 'deg'; }
    value def Distance :> Real { unit 'mm'; }
    value def Duration :> Real { unit 'min'; }
    value def XRayDose :> Real { unit 'mGy'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Power :> Real { unit 'W'; }
    value def Pressure :> Real { unit 'mmHg'; }

    enum def OperationMode {
        manual;
        semiAutomated;
        fullyAutomated;
    }

    enum def ProcedurePhase {
        planning;
        navigation;
        intervention;
        retraction;
        completed;
    }

    enum def SafetyStatus {
        nominal;
        warning;
        emergencyStop;
    }

    // ---------- Item Types ----------
    item def MagneticField {
        attribute strength : MagneticFluxDensity;
        attribute orientation : Angle;
    }

    item def CatheterPosition {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute tipOrientation : Angle;
    }

    item def PlannedPath {
        attribute waypoints : CatheterPosition[0..*];
        attribute target : CatheterPosition;
    }

    item def FluoroscopyImage {
        attribute frameRate : Frequency;
        attribute dose : XRayDose;
        attribute timestamp : Duration;
    }

    item def MagnetCommand {
        attribute targetStrength : MagneticFluxDensity;
        attribute targetOrientation : Angle;
        attribute rampRate : MagneticFluxDensity;
    }

    item def SafetyAlert {
        attribute status : SafetyStatus;
        attribute message : String;
        attribute severity : Integer;
    }

    item def TipForceReading {
        attribute magnitude : Force;
        attribute direction : Angle;
    }

    // ---------- Port Definitions ----------
    port def ImagePort {
        out image : FluoroscopyImage;
        out position : CatheterPosition;
    }

    port def MagnetControlPort {
        in command : MagnetCommand;
        out field : MagneticField;
    }

    port def SafetyPort {
        out alert : SafetyAlert;
        out tipForce : TipForceReading;
        out elapsed : Duration;
    }

    port def WorkstationCommandPort {
        out magnetCommand : MagnetCommand;
        in image : FluoroscopyImage;
        in position : CatheterPosition;
        in alert : SafetyAlert;
    }

    port def CatheterInteractionPort {
        in field : MagneticField;
        out position : CatheterPosition;
        out tipForce : TipForceReading;
    }

    // ---------- External Magnet System ----------
    part def ExternalMagnetSystem {
        attribute maxFluxDensity : MagneticFluxDensity = 200 [mT];
        attribute maxOrientationRate : Angle = 30 [deg/s];

        port magnetControl : MagnetControlPort;
        port fieldOutput : ~MagnetControlPort;

        part leftMagnet : MagnetUnit;
        part rightMagnet : MagnetUnit;

        part def MagnetUnit {
            attribute currentStrength : MagneticFluxDensity;
            attribute currentOrientation : Angle;
            attribute power : Power;
        }

        action def AdjustField {
            in command : MagnetCommand;
            out field : MagneticField;
        }

        state def MagnetControlBehavior {
            entry; then idle;
            state idle;
            state ramping;
            state stable;
            transition idle_to_ramping
                first idle
                then ramping
                when magnetControl.command is received;
            transition ramping_to_stable
                first ramping
                then stable
                when leftMagnet.currentStrength == magnetControl.command.targetStrength
                    and rightMagnet.currentStrength == magnetControl.command.targetStrength;
            transition stable_to_idle
                first stable
                then idle
                when magnetControl.command is not received for 1 [s];
        }

        perform MagnetControlBehavior;
    }

    // ---------- Fluoroscopy Imaging System ----------
    part def FluoroscopyImagingSystem {
        attribute frameRate : Frequency = 30 [Hz];
        attribute maxDose : XRayDose = 50 [mGy];
        attribute cumulativeDose : XRayDose;

        port imageOutput : ImagePort;

        part xraySource : XRaySource;
        part detector : ImageDetector;
        part imageProcessor : ImageProcessor;

        part def XRaySource {
            attribute voltage : Real;
            attribute current : Real;
        }

        part def ImageDetector {
            attribute resolution : Real;
        }

        part def ImageProcessor {
            action def ProcessFrame {
                in rawFrame : FluoroscopyImage;
                out processedImage : FluoroscopyImage;
                out detectedPosition : CatheterPosition;
            }
        }

        action def AcquireImage {
            out image : FluoroscopyImage;
            out position : CatheterPosition;
        }

        state def ImagingBehavior {
            entry; then standby;
            state standby;
            state acquiring;
            state processing;
            transition standby_to_acquiring
                first standby
                then acquiring
                when imageOutput.image is requested;
            transition acquiring_to_processing
                first acquiring
                then processing
                when xraySource.current > 0;
            transition processing_to_standby
                first processing
                then standby
                when imageProcessor.ProcessFrame is completed;
        }

        perform ImagingBehavior;
    }

    // ---------- Navigation Workstation ----------
    part def NavigationWorkstation {
        attribute mode : OperationMode = OperationMode::manual;
        attribute currentPhase : ProcedurePhase = ProcedurePhase::planning;
        attribute controlLoopPeriod : Duration = 0.05 [min];

        port workstationPort : WorkstationCommandPort;
        port magnetOutput : ~MagnetControlPort;
        port imageInput : ~ImagePort;
        port safetyInput : ~SafetyPort;

        part ui : UserInterface;
        part pathPlanner : PathPlanner;
        part controlAlgorithm : ControlAlgorithm;
        part dataLogger : DataLogger;

        part def UserInterface {
            attribute displayResolution : Real;
            attribute inputDevices : String;
            action def DisplayImage {
                in image : FluoroscopyImage;
            }
            action def ReceivePathInput {
                out path : PlannedPath;
            }
        }

        part def PathPlanner {
            action def PlanPath {
                in image : FluoroscopyImage;
                in position : CatheterPosition;
                out path : PlannedPath;
            }
        }

        part def ControlAlgorithm {
            attribute gainProportional : Real = 1.0;
            attribute gainIntegral : Real = 0.1;
            attribute gainDerivative : Real = 0.05;

            action def ComputeCommand {
                in currentPosition : CatheterPosition;
                in plannedPath : PlannedPath;
                in tipForce : TipForceReading;
                out command : MagnetCommand;
            }
        }

        part def DataLogger {
            attribute logInterval : Duration = 0.1 [min];
            action def LogData {
                in position : CatheterPosition;
                in command : MagnetCommand;
                in alert : SafetyAlert;
            }
        }

        action def ExecuteControlLoop {
            in image : FluoroscopyImage;
            in position : CatheterPosition;
            in alert : SafetyAlert;
            out command : MagnetCommand;
        }

        state def WorkstationBehavior {
            entry; then planning;
            state planning {
                entry action ui.ReceivePathInput;
                do action pathPlanner.PlanPath;
            }
            state navigation {
                do action controlAlgorithm.ComputeCommand;
            }
            state intervention {
                do action controlAlgorithm.ComputeCommand;
            }
            state retraction {
                do action controlAlgorithm.ComputeCommand;
            }
            state completed {
                entry action dataLogger.LogData;
            }
            transition planning_to_navigation
                first planning
                then navigation
                when pathPlanner.PlanPath is completed;
            transition navigation_to_intervention
                first navigation
                then intervention
                when position.distanceTo(target) < 2 [mm];
            transition intervention_to_retraction
                first intervention
                then retraction
                when intervention is completed;
            transition retraction_to_completed
                first retraction
                then completed
                when position.x < entryPoint.x;
        }

        perform WorkstationBehavior;
    }

    // ---------- Safety Monitoring System ----------
    part def SafetyMonitoringSystem {
        attribute maxTipForce : Force = 50 [mN];
        attribute maxProcedureDuration : Duration = 120 [min];
        attribute maxXRayDose : XRayDose = 50 [mGy];
        attribute warningForceThreshold : Force = 35 [mN];
        attribute elapsed : Duration = 0 [min];

        port safetyOutput : SafetyPort;
        port sensorInput : ~CatheterInteractionPort;

        part forceSensor : ForceSensor;
        part timer : ProcedureTimer;
        part doseMonitor : DoseMonitor;

        part def ForceSensor {
            attribute calibration : Real;
            action def MeasureForce {
                out reading : TipForceReading;
            }
        }

        part def ProcedureTimer {
            attribute startTime : Duration;
            action def UpdateElapsed {
                out elapsed : Duration;
            }
        }

        part def DoseMonitor {
            attribute cumulativeDose : XRayDose;
            action def AccumulateDose {
                in image : FluoroscopyImage;
                out total : XRayDose;
            }
        }

        action def EvaluateSafety {
            in tipForce : TipForceReading;
            in elapsed : Duration;
            in dose : XRayDose;
            out alert : SafetyAlert;
        }

        state def SafetyBehavior {
            entry; then monitoring;
            state monitoring {
                do action EvaluateSafety;
            }
            state warningIssued;
            state emergencyStopped;
            transition monitoring_to_warning
                first monitoring
                then warningIssued
                when forceSensor.MeasureForce.reading.magnitude > warningForceThreshold;
            transition warning_to_monitoring
                first warningIssued
                then monitoring
                when forceSensor.MeasureForce.reading.magnitude <= warningForceThreshold;
            transition monitoring_to_emergency
                first monitoring
                then emergencyStopped
                when forceSensor.MeasureForce.reading.magnitude > maxTipForce
                    or timer.UpdateElapsed.elapsed > maxProcedureDuration
                    or doseMonitor.AccumulateDose.total > maxXRayDose;
            transition warning_to_emergency
                first warningIssued
                then emergencyStopped
                when forceSensor.MeasureForce.reading.magnitude > maxTipForce;
        }

        perform SafetyBehavior;
    }

    // ---------- Magnetic Catheter ----------
    part def MagneticCatheter {
        attribute length : Distance = 1200 [mm];
        attribute diameter : Distance = 2.3 [mm];
        attribute magneticTipStrength : MagneticFluxDensity = 10 [mT];
        attribute maxBendAngle : Angle = 90 [deg];

        port interaction : CatheterInteractionPort;

        part magneticTip : MagneticTip;
        part flexibleBody : FlexibleBody;
        part steeringCoil : SteeringCoil;

        part def MagneticTip {
            attribute magnetization : MagneticFluxDensity;
            attribute currentForce : Force;
            attribute currentTorque : Torque;
        }

        part def FlexibleBody {
            attribute stiffness : Real;
            attribute bendRadius : Distance;
        }

        part def SteeringCoil {
            attribute turns : Integer;
            attribute current : Real;
        }

        action def RespondToField {
            in field : MagneticField;
            out position : CatheterPosition;
            out tipForce : TipForceReading;
        }

        state def CatheterBehavior {
            entry; then atRest;
            state atRest;
            state steering;
            state retracted;
            transition atRest_to_steering
                first atRest
                then steering
                when interaction.field is received;
            transition steering_to_retracted
                first steering
                then retracted
                when retraction is commanded;
        }

        perform CatheterBehavior;
    }

    // ---------- Patient ----------
    part def Patient {
        attribute bodyMass : Mass;
        part cardiovascularSystem : CardiovascularSystem;
        part heart : Heart;
        part vasculature : Vasculature;

        part def CardiovascularSystem {
            attribute bloodPressure : Pressure;
        }

        part def Heart {
            attribute targetChamber : String;
        }

        part def Vasculature {
            attribute vesselCount : Integer;
        }
    }

    // ---------- Top-level System ----------
    part def StereotaxisSystem {
        attribute systemId : String;
        attribute manufacturer : String = "Stereotaxis";
        attribute firmwareVersion : String;

        port externalInterface : WorkstationCommandPort;

        part externalMagnetSystem : ExternalMagnetSystem;
        part fluoroscopyImagingSystem : FluoroscopyImagingSystem;
        part navigationWorkstation : NavigationWorkstation;
        part safetyMonitoringSystem : SafetyMonitoringSystem;
        part catheter : MagneticCatheter;
        part patient : Patient;

        connection def ImageFlow {
            end source : FluoroscopyImagingSystem;
            end destination : NavigationWorkstation;
            item : FluoroscopyImage;
            item : CatheterPosition;
        }

        connection def CommandFlow {
            end source : NavigationWorkstation;
            end destination : ExternalMagnetSystem;
            item : MagnetCommand;
        }

        connection def FieldFlow {
            end source : ExternalMagnetSystem;
            end destination : MagneticCatheter;
            item : MagneticField;
        }

        connection def CatheterFeedback {
            end source : MagneticCatheter;
            end destination : FluoroscopyImagingSystem;
            item : CatheterPosition;
        }

        connection def SafetyFeedback {
            end source : MagneticCatheter;
            end destination : SafetyMonitoringSystem;
            item : TipForceReading;
        }

        connection def SafetyAlertFlow {
            end source : SafetyMonitoringSystem;
            end destination : NavigationWorkstation;
            item : SafetyAlert;
        }

        connection imageFlow : ImageFlow connect fluoroscopyImagingSystem.imageOutput to navigationWorkstation.imageInput;
        connection commandFlow : CommandFlow connect navigationWorkstation.magnetOutput to externalMagnetSystem.magnetControl;
        connection fieldFlow : FieldFlow connect externalMagnetSystem.fieldOutput to catheter.interaction;
        connection catheterFeedback : CatheterFeedback connect catheter.interaction to fluoroscopyImagingSystem.imageOutput;
        connection safetyFeedback : SafetyFeedback connect catheter.interaction to safetyMonitoringSystem.sensorInput;
        connection safetyAlertFlow : SafetyAlertFlow connect safetyMonitoringSystem.safetyOutput to navigationWorkstation.safetyInput;

        state def SystemOperationBehavior {
            entry; then systemInitialization;
            state systemInitialization;
            state systemReady;
            state procedureActive;
            state systemShutdown;
            transition init_to_ready
                first systemInitialization
                then systemReady
                when all subsystems are nominal;
            transition ready_to_active
                first systemReady
                then procedureActive
                when physician initiates procedure;
            transition active_to_shutdown
                first procedureActive
                then systemShutdown
                when navigationWorkstation.currentPhase == ProcedurePhase::completed;
        }

        perform SystemOperationBehavior;
    }

    // ---------- Requirements ----------
    requirement def MagneticSteeringRequirement {
        subject system : StereotaxisSystem;
        objective {
            doc /* The system shall remotely steer a magnetic-tipped catheter through the cardiovascular system to a target area. */
        }
        assume patient is positioned between the two magnets.
    }

    requirement def PrecisionNavigationRequirement {
        subject system : StereotaxisSystem;
        attribute positioningAccuracy : Distance = 2 [mm];
        objective {
            doc /* The system shall position the catheter tip within 2 mm of the planned target. */
        }
    }

    requirement def ClosedLoopControlRequirement {
        subject workstation : NavigationWorkstation;
        attribute controlLoopPeriod : Duration = 0.05 [min];
        objective {
            doc /* The workstation shall continuously receive position data and send magnet commands in a closed loop. */
        }
    }

    requirement def OperationModeRequirement {
        subject workstation : NavigationWorkstation;
        objective {
            doc /* The workstation shall support manual, semi-automated, and fully automated operation modes. */
        }
    }

    requirement def SafetyMonitoringRequirement {
        subject safetySystem : SafetyMonitoringSystem;
        attribute maxTipForce : Force = 50 [mN];
        attribute maxProcedureDuration : Duration = 120 [min];
        objective {
            doc /* The safety system shall monitor tip force and procedure duration and trigger warnings or emergency stops when thresholds are exceeded. */
        }
    }

    requirement def FluoroscopyRequirement {
        subject imaging : FluoroscopyImagingSystem;
        attribute minFrameRate : Frequency = 15 [Hz];
        objective {
            doc /* The imaging system shall provide real-time fluoroscopy images at a minimum of 15 Hz. */
        }
    }

    requirement def ProcedurePhasesRequirement {
        subject system : StereotaxisSystem;
        objective {
            doc /* The procedure shall follow the phases: planning, navigation, intervention, retraction, and completion. */
        }
    }

    requirement def EmergencyStopRequirement {
        subject safetySystem : SafetyMonitoringSystem;
        objective {
            doc /* The safety system shall trigger an emergency stop when tip force exceeds 50 mN or procedure duration exceeds 120 minutes. */
        }
    }

    requirement def MagnetFieldControlRequirement {
        subject magnets : ExternalMagnetSystem;
        attribute maxFluxDensity : MagneticFluxDensity = 200 [mT];
        objective {
            doc /* The external magnets shall generate a controlled magnetic field up to 200 mT with adjustable strength and orientation. */
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction magneticSteeringSatisfaction : MagneticSteeringRequirement satisfy system : StereotaxisSystem by catheter.steeringCoil;
    satisfaction precisionSatisfaction : PrecisionNavigationRequirement satisfy system : StereotaxisSystem by navigationWorkstation.controlAlgorithm;
    satisfaction closedLoopSatisfaction : ClosedLoopControlRequirement satisfy workstation : NavigationWorkstation by navigationWorkstation.ExecuteControlLoop;
    satisfaction modeSatisfaction : OperationModeRequirement satisfy workstation : NavigationWorkstation by navigationWorkstation.mode;
    satisfaction safetySatisfaction : SafetyMonitoringRequirement satisfy safetySystem : SafetyMonitoringSystem by safetyMonitoringSystem.SafetyBehavior;
    satisfaction fluoroscopySatisfaction : FluoroscopyRequirement satisfy imaging : FluoroscopyImagingSystem by fluoroscopyImagingSystem.ImagingBehavior;
    satisfaction phasesSatisfaction : ProcedurePhasesRequirement satisfy system : StereotaxisSystem by system.SystemOperationBehavior;
    satisfaction emergencySatisfaction : EmergencyStopRequirement satisfy safetySystem : SafetyMonitoringSystem by safetyMonitoringSystem.emergencyStopped;
    satisfaction magnetSatisfaction : MagnetFieldControlRequirement satisfy magnets : ExternalMagnetSystem by externalMagnetSystem.MagnetControlBehavior;

}
