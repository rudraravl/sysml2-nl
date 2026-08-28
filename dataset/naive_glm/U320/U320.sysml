package NanoneedleDeliverySystem {
    import ScalarValues::*;
    import SI::*;

    // ============================================================
    // Units
    // ============================================================
    unit def nanometre :> SI::metre;
    unit def picolitre :> SI::litre;
    unit def nanonewton :> SI::newton;
    unit def kiloohm :> SI::ohm;
    unit def millisecond :> SI::second;
    unit def kilohertz :> SI::hertz;
    unit def millivolt :> SI::volt;
    unit def microwatt :> SI::watt;

    // ============================================================
    // Value Types
    // ============================================================
    value type Length :> Real { unit nanometre; }
    value type Diameter :> Real { unit nanometre; }
    value type Depth :> Real { unit nanometre; }
    value type Volume :> Real { unit picolitre; }
    value type FlowRate :> Real { unit picolitre; }
    value type Force :> Real { unit nanonewton; }
    value type Impedance :> Real { unit kiloohm; }
    value type Pressure :> Real { unit SI::pascal; }
    value type Duration :> Real { unit millisecond; }
    value type Frequency :> Real { unit kilohertz; }
    value type Voltage :> Real { unit millivolt; }
    value type Power :> Real { unit microwatt; }
    value type Dimensionless :> Real;

    value type Position3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    // ============================================================
    // Items
    // ============================================================
    item def TherapeuticPayload {
        attribute name : String;
        attribute concentration : Dimensionless;
        attribute volume : Volume;
    }

    item def BiologicalCell {
        attribute cellId : String;
        attribute viability : Boolean = true;
        attribute membraneImpedance : Impedance = 100 [kΩ];
        attribute location : Position3D;
    }

    item def ImageFrame {
        attribute frameId : Integer;
        attribute magnification : Dimensionless;
        attribute resolution : Length;
        attribute timestamp : Duration;
    }

    item def ForceMeasurement {
        attribute value : Force;
        attribute timestamp : Duration;
    }

    item def ImpedanceMeasurement {
        attribute value : Impedance;
        attribute timestamp : Duration;
    }

    item def PositionCommand {
        attribute target : Position3D;
        attribute speed : Length;
    }

    item def PositionFeedback {
        attribute actual : Position3D;
        attribute timestamp : Duration;
    }

    item def InjectionCommand {
        attribute volume : Volume;
        attribute rate : FlowRate;
    }

    item def StatusReport {
        attribute phase : String;
        attribute success : Boolean;
        attribute timestamp : Duration;
    }

    item def TargetCellReport {
        attribute cell : BiologicalCell;
        attribute confidence : Dimensionless;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def ImageFeed {
        out item frame : ImageFrame;
    }

    port def TargetCellFeed {
        out item report : TargetCellReport;
    }

    port def ForceFeed {
        out item measurement : ForceMeasurement;
    }

    port def ImpedanceFeed {
        out item measurement : ImpedanceMeasurement;
    }

    port def PositionCommandFeed {
        in item command : PositionCommand;
    }

    port def PositionFeedbackFeed {
        out item feedback : PositionFeedback;
    }

    port def InjectionCommandFeed {
        in item command : InjectionCommand;
    }

    port def PayloadFlowFeed {
        out item payload : TherapeuticPayload;
    }

    port def StatusFeed {
        out item report : StatusReport;
    }

    port def MechanicalInterface {
        out item position : Position3D;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================
    part def NanoneedleTip {
        attribute tipDiameter : Diameter = 80 [nm];
        attribute shaftLength : Length = 5000 [nm];
        attribute maxPenetrationDepth : Depth = 3000 [nm];
        attribute material : String = "Silicon Carbide";

        port forceOut : ForceFeed;
        port impedanceOut : ImpedanceFeed;
        port payloadIn :~ PayloadFlowFeed;
        port mechanicalMount : MechanicalInterface;

        part def ForceSensor {
            attribute sensitivity : Force = 0.5 [nN];
            attribute range : Force = 500 [nN];
            action def sense {
                out item measurement : ForceMeasurement;
            }
        }

        part def ImpedanceSensor {
            attribute excitationVoltage : Voltage = 10 [mV];
            attribute excitationFrequency : Frequency = 1 [kHz];
            attribute baseImpedance : Impedance = 100 [kΩ];
            action def sense {
                out item measurement : ImpedanceMeasurement;
            }
        }

        part forceSensor : ForceSensor {
            bind forceOut = NanoneedleTip::forceOut;
        }
        part impedanceSensor : ImpedanceSensor {
            bind impedanceOut = NanoneedleTip::impedanceOut;
        }

        action def detectContact {
            in item force : ForceMeasurement;
            in item impedance : ImpedanceMeasurement;
            out item contactConfirmed : Boolean;
        }
    }

    part def PiezoelectricPositioner {
        attribute positionAccuracy : Length = 50 [nm];
        attribute travelRangeX : Length = 100000 [nm];
        attribute travelRangeY : Length = 100000 [nm];
        attribute travelRangeZ : Length = 20000 [nm];
        attribute resolution : Length = 1 [nm];
        attribute maxSpeed : Length = 5000 [nm];
        attribute bandwidth : Frequency = 1 [kHz];

        port commandIn :~ PositionCommandFeed;
        port feedbackOut : PositionFeedbackFeed;
        port mechanicalOut : MechanicalInterface;

        attribute currentTarget : Position3D;
        attribute currentPosition : Position3D;

        action def moveTo {
            in item command : PositionCommand;
            out item feedback : PositionFeedback;
        }

        action def home {
            out item feedback : PositionFeedback;
        }
    }

    part def MicrofluidicInjector {
        attribute minVolume : Volume = 1 [pL];
        attribute maxVolume : Volume = 500 [pL];
        attribute volumeAccuracy : Volume = 0.5 [pL];
        attribute maxPressure : Pressure = 100000 [Pa];
        attribute reservoirContents : TherapeuticPayload;

        port commandIn :~ InjectionCommandFeed;
        port payloadOut : PayloadFlowFeed;

        action def inject {
            in item command : InjectionCommand;
            out item payload : TherapeuticPayload;
        }

        action def prime {
            out item payload : TherapeuticPayload;
        }
    }

    part def ImagingSystem {
        attribute magnification : Dimensionless = 1000;
        attribute resolution : Length = 50 [nm];
        attribute frameRate : Frequency = 30 [kHz];
        attribute fieldOfView : Length = 50000 [nm];

        port imageOut : ImageFeed;
        port targetOut : TargetCellFeed;

        action def captureFrame {
            out item frame : ImageFrame;
        }

        action def identifyTargetCell {
            in item frame : ImageFrame;
            out item report : TargetCellReport;
        }
    }

    part def FeedbackController {
        attribute positionAccuracy : Length = 50 [nm];
        attribute contactForceThreshold : Force = 10 [nN];
        attribute membraneImpedanceThreshold : Impedance = 50 [kΩ];
        attribute targetPenetrationDepth : Depth = 2000 [nm];
        attribute injectionVolume : Volume = 10 [pL];
        attribute injectionRate : FlowRate = 1 [pL];
        attribute approachSpeed : Length = 1000 [nm];
        attribute penetrationSpeed : Length = 100 [nm];
        attribute withdrawalSpeed : Length = 500 [nm];

        port imageIn :~ ImageFeed;
        port targetIn :~ TargetCellFeed;
        port forceIn :~ ForceFeed;
        port impedanceIn :~ ImpedanceFeed;
        port positionFeedbackIn :~ PositionFeedbackFeed;
        port positionCmdOut : PositionCommandFeed;
        port injectionCmdOut : InjectionCommandFeed;
        port statusOut : StatusFeed;

        attribute currentPhase : String = "Idle";
        attribute targetCell : BiologicalCell;
        attribute contactConfirmed : Boolean = false;
        attribute depthReached : Boolean = false;
        attribute injectionComplete : Boolean = false;
        attribute withdrawalComplete : Boolean = false;
        attribute operationSuccess : Boolean = false;

        action def evaluateContact {
            in item force : ForceMeasurement;
            in item impedance : ImpedanceMeasurement;
            out item confirmed : Boolean;
        }

        action def computePositionCommand {
            in item target : Position3D;
            in item actual : Position3D;
            in item speed : Length;
            out item command : PositionCommand;
        }

        action def generateInjectionCommand {
            in item volume : Volume;
            in item rate : FlowRate;
            out item command : InjectionCommand;
        }

        action def emitStatus {
            out item report : StatusReport;
        }

        exhibit state DeliveryProcess {
            entry; then Idle;

            state Idle {
                entry action {
                    currentPhase = "Idle";
                }
                do action emitStatus;
            }

            state Imaging {
                entry action {
                    currentPhase = "Imaging";
                }
                do action identifyTarget;
            }

            state Approaching {
                entry action {
                    currentPhase = "Approaching";
                }
                do action controlApproach;
            }

            state ContactDetection {
                entry action {
                    currentPhase = "ContactDetection";
                }
                do action monitorContact;
            }

            state Penetration {
                entry action {
                    currentPhase = "Penetration";
                }
                do action controlPenetration;
            }

            state Injection {
                entry action {
                    currentPhase = "Injection";
                }
                do action controlInjection;
            }

            state Withdrawal {
                entry action {
                    currentPhase = "Withdrawal";
                }
                do action controlWithdrawal;
            }

            state Completed {
                entry action {
                    currentPhase = "Completed";
                    operationSuccess = true;
                }
                do action emitStatus;
            }

            state Aborted {
                entry action {
                    currentPhase = "Aborted";
                    operationSuccess = false;
                }
                do action emitStatus;
            }

            transition Idle_to_Imaging
                first Idle then Imaging
                accept StartCommand;

            transition Imaging_to_Approaching
                first Imaging then Approaching
                when targetCell.viability == true;

            transition Approaching_to_ContactDetection
                first Approaching then ContactDetection
                when proximityReached;

            transition ContactDetection_to_Penetration
                first ContactDetection then Penetration
                when contactConfirmed == true;

            transition ContactDetection_to_Aborted
                first ContactDetection then Aborted
                when contactTimeout;

            transition Penetration_to_Injection
                first Penetration then Injection
                when depthReached == true;

            transition Penetration_to_Aborted
                first Penetration then Aborted
                when penetrationError;

            transition Injection_to_Withdrawal
                first Injection then Withdrawal
                when injectionComplete == true;

            transition Withdrawal_to_Completed
                first Withdrawal then Completed
                when withdrawalComplete == true;

            transition Withdrawal_to_Aborted
                first Withdrawal then Aborted
                when withdrawalError;
        }
    }

    // ============================================================
    // System Composition
    // ============================================================
    part def NanoneedleDeliverySystem {
        attribute systemId : String;
        attribute positionAccuracy : Length = 50 [nm];
        attribute tipDiameter : Diameter = 80 [nm];
        attribute maxInjectionVolume : Volume = 500 [pL];

        port operatorInterface : StatusFeed;
        port startCommandIn;

        part nanoneedleTip : NanoneedleTip {
            attribute redefines tipDiameter = 80 [nm];
        }
        part piezoPositioner : PiezoelectricPositioner {
            attribute redefines positionAccuracy = 50 [nm];
        }
        part microfluidicInjector : MicrofluidicInjector {
            attribute redefines volumeAccuracy = 0.5 [pL];
        }
        part imagingSystem : ImagingSystem {
            attribute redefines resolution = 50 [nm];
        }
        part feedbackController : FeedbackController {
            attribute redefines positionAccuracy = 50 [nm];
            attribute redefines contactForceThreshold = 10 [nN];
            attribute redefines membraneImpedanceThreshold = 50 [kΩ];
            attribute redefines targetPenetrationDepth = 2000 [nm];
            attribute redefines injectionVolume = 10 [pL];
        }

        // Connections
        connect imagingSystem.imageOut to feedbackController.imageIn;
        connect imagingSystem.targetOut to feedbackController.targetIn;
        connect nanoneedleTip.forceOut to feedbackController.forceIn;
        connect nanoneedleTip.impedanceOut to feedbackController.impedanceIn;
        connect piezoPositioner.feedbackOut to feedbackController.positionFeedbackIn;
        connect feedbackController.positionCmdOut to piezoPositioner.commandIn;
        connect feedbackController.injectionCmdOut to microfluidicInjector.commandIn;
        connect microfluidicInjector.payloadOut to nanoneedleTip.payloadIn;
        connect piezoPositioner.mechanicalOut to nanoneedleTip.mechanicalMount;
        connect feedbackController.statusOut to operatorInterface;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def PrecisionPositioningRequirement {
        doc "The system shall position the nanoneedle with accuracy better than 100 nm in all three axes."
        subject theSystem : NanoneedleDeliverySystem;
        require theSystem.positionAccuracy < 100 [nm];
    }

    requirement def NanoneedleSharpnessRequirement {
        doc "The nanoneedle tip shall have a diameter smaller than 100 nm to ensure minimal invasiveness."
        subject theTip : NanoneedleTip;
        require theTip.tipDiameter < 100 [nm];
    }

    requirement def InjectionVolumeRequirement {
        doc "The microfluidic injector shall deliver controlled volumes in the picoliter range."
        subject theInjector : MicrofluidicInjector;
        require theInjector.minVolume >= 1 [pL];
        require theInjector.maxVolume <= 500 [pL];
    }

    requirement def CellViabilityRequirement {
        doc "The target cell shall remain viable after the injection procedure."
        subject theCell : BiologicalCell;
        require theCell.viability == true;
    }

    requirement def ContactDetectionRequirement {
        doc "The system shall detect cell membrane contact using force and impedance sensing before penetration."
        subject theController : FeedbackController;
        require theController.contactForceThreshold <= 10 [nN];
        require theController.membraneImpedanceThreshold <= 50 [kΩ];
    }

    requirement def ClosedLoopControlRequirement {
        doc "The feedback controller shall use real-time sensor data to manage approach, penetration, injection, and withdrawal."
        subject theController : FeedbackController;
        require theController.positionAccuracy < 100 [nm];
    }

    requirement def ImagingResolutionRequirement {
        doc "The imaging system shall resolve features smaller than 100 nm to locate target cells."
        subject theImager : ImagingSystem;
        require theImager.resolution < 100 [nm];
    }

    requirement def PenetrationDepthRequirement {
        doc "The system shall penetrate the cell membrane to a controlled, specified depth without exceeding the maximum safe depth."
        subject theController : FeedbackController;
        subject theTip : NanoneedleTip;
        require theController.targetPenetrationDepth <= theTip.maxPenetrationDepth;
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    satisfaction def PrecisionPositioningSatisfaction
        satisfy PrecisionPositioningRequirement
        by NanoneedleDeliverySystem::piezoPositioner;

    satisfaction def NanoneedleSharpnessSatisfaction
        satisfy NanoneedleSharpnessRequirement
        by NanoneedleDeliverySystem::nanoneedleTip;

    satisfaction def InjectionVolumeSatisfaction
        satisfy InjectionVolumeRequirement
        by NanoneedleDeliverySystem::microfluidicInjector;

    satisfaction def ImagingResolutionSatisfaction
        satisfy ImagingResolutionRequirement
        by NanoneedleDeliverySystem::imagingSystem;

    satisfaction def ClosedLoopControlSatisfaction
        satisfy ClosedLoopControlRequirement
        by NanoneedleDeliverySystem::feedbackController;
}
