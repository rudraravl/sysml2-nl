package VeressNeedleInsufflationSystem {

    import SI::*;
    import ScalarValues::*;

    // ============ Custom Unit Definitions ============
    unit L_per_min :> Unit;
    unit N_per_mm :> Unit;

    // ============ Value Types ============
    value type DiameterValue :> Real {
        :> unit = mm;
    }
    value type LengthValue :> Real {
        :> unit = mm;
    }
    value type PressureValue :> Real {
        :> unit = kPa;
    }
    value type FlowRateValue :> Real {
        :> unit = L_per_min;
    }
    value type ForceValue :> Real {
        :> unit = N;
    }
    value type ResistanceValue :> Real {
        :> unit = N_per_mm;
    }
    value type VolumeValue :> Real {
        :> unit = L;
    }

    // ============ Item Types ============
    item def CO2Gas;

    // ============ Port Definitions ============
    port def GasFlowInlet {
        in item gas : CO2Gas;
    }
    port def GasFlowOutlet {
        out item gas : CO2Gas;
    }
    port def PressureSignalOut {
        out pressure : PressureValue;
    }
    port def PressureSignalIn {
        in pressure : PressureValue;
    }
    port def CommandInput {
        in command : String;
        in targetPressure : PressureValue;
        in targetFlowRate : FlowRateValue;
    }
    port def StatusOutput {
        out status : String;
        out currentPressure : PressureValue;
        out currentFlowRate : FlowRateValue;
    }

    // ============ Requirement Definitions ============
    requirement def SafePneumoperitoneumCreation {
        doc {
            The Veress Needle Insufflation System shall safely create
            a pneumoperitoneum by delivering pressurized CO2 gas to the
            abdominal cavity, creating a clear expanded space for
            laparoscopic surgery.
        }
    }
    requirement def PreventOrganPuncture {
        doc {
            The spring-loaded obturator shall extend automatically upon
            entry into the low-resistance peritoneal cavity, shielding
            the sharp cannula tip to prevent accidental puncture of
            internal organs.
        }
    }
    requirement def MaintainTargetAbdominalPressure {
        doc {
            The insufflator shall maintain abdominal cavity pressure
            between 1.6 kPa and 2.0 kPa throughout the surgical procedure.
        }
        attribute minPressure : PressureValue = 1.6 [kPa];
        attribute maxPressure : PressureValue = 2.0 [kPa];
    }
    requirement def ControlledInsufflationFlow {
        doc {
            The insufflator shall deliver CO2 at a controlled low flow
            rate during insufflation to safely inflate the abdominal cavity.
        }
        attribute maxFlowRate : FlowRateValue = 1.0 [L_per_min];
    }
    requirement def PlacementVerificationReq {
        doc {
            Before insufflation the system shall support placement
            verification through aspiration tests, saline drop tests,
            and monitoring of initial low-pressure readings.
        }
    }
    requirement def CannulaDimensionsReq {
        doc {
            The sharp cannula shall have a standard diameter of 2.1 mm
            and a length of 120 mm.
        }
        attribute diameter : DiameterValue = 2.1 [mm];
        attribute length : LengthValue = 120 [mm];
    }

    // ============ Part: Sharp Cannula ============
    part def SharpCannula {
        attribute outerDiameter : DiameterValue = 2.1 [mm];
        attribute cannulaLength : LengthValue = 120 [mm];
        attribute isSharp : Boolean = true;
        port tipPort : GasFlowOutlet;
        port basePort : GasFlowInlet;
        satisfy cannulaDims : CannulaDimensionsReq;
    }

    // ============ Part: Spring-Loaded Obturator ============
    part def SpringLoadedObturator {
        attribute isBlunt : Boolean = true;
        attribute springConstant : Real = 2.5;
        attribute extensionLength : LengthValue = 5 [mm];
        attribute currentResistance : ResistanceValue = 0.0 [N_per_mm];
        attribute thresholdResistance : ResistanceValue = 0.5 [N_per_mm];
        attribute isExtended : Boolean = false;
        stateMachine obturatorSafetyStates {
            state Retracted {
                entry { isExtended = false; }
                doc {
                    Obturator retracted by spring force against tissue
                    resistance exposing sharp cannula tip for penetration
                    of abdominal wall layers.
                }
            }
            state Extended {
                entry { isExtended = true; }
                doc {
                    Obturator extended forward by spring when resistance
                    drops upon entering peritoneal cavity. Blunt tip shields
                    sharp cannula to protect internal organs.
                }
            }
            transition from Retracted to Extended
                when currentResistance < thresholdResistance;
            transition from Extended to Retracted
                when currentResistance >= thresholdResistance;
        }
        satisfy preventPuncture : PreventOrganPuncture;
    }

    // ============ Part: Stopcock ============
    part def Stopcock {
        attribute isOpen : Boolean = false;
        port inputPort : GasFlowInlet;
        port outputPort : GasFlowOutlet;
        action def Open {
            doc { Open the stopcock valve to allow gas flow through the needle. }
        }
        action def Close {
            doc { Close the stopcock valve to block gas flow. }
        }
        stateMachine stopcockStates {
            state Closed {
                entry { isOpen = false; }
            }
            state Open {
                entry { isOpen = true; }
            }
            transition from Closed to Open when isOpen;
            transition from Open to Closed when not isOpen;
        }
    }

    // ============ Part: Pressure Sensor ============
    part def PressureSensor {
        attribute measuredPressure : PressureValue = 0.0 [kPa];
        attribute maxRange : PressureValue = 10.0 [kPa];
        attribute accuracy : PressureValue = 0.05 [kPa];
        attribute isCalibrated : Boolean = true;
        port outputPort : PressureSignalOut;
        action def MeasurePressure {
            in inputPressure : PressureValue;
            out measuredPressure : PressureValue;
            doc { Measure pressure at needle tip and provide reading. }
        }
        action def Calibrate {
            doc { Calibrate the pressure sensor against a known reference. }
        }
    }

    // ============ Part: CO2 Cylinder ============
    part def CO2Cylinder {
        attribute cylinderPressure : PressureValue = 60000.0 [kPa];
        attribute cylinderVolume : VolumeValue = 2.0 [L];
        attribute remainingVolume : VolumeValue = 2.0 [L];
        attribute gasType : String = "CO2";
        attribute isEmpty : Boolean = false;
        port outputPort : GasFlowOutlet;
        stateMachine cylinderStates {
            state Full {
                doc { Cylinder full, maximum CO2 available. }
            }
            state Depleting {
                doc { CO2 being consumed, remaining volume decreasing. }
            }
            state Empty {
                entry { isEmpty = true; }
                doc { Cylinder empty, needs replacement. }
            }
            transition from Full to Depleting
                when remainingVolume < cylinderVolume;
            transition from Depleting to Empty
                when remainingVolume <= 0.0 [L];
        }
    }

    // ============ Part: Pressure Regulator ============
    part def PressureRegulator {
        attribute inputPressure : PressureValue = 0.0 [kPa];
        attribute outputPressure : PressureValue = 1500.0 [kPa];
        attribute regulationFactor : Real = 0.025;
        port inputPort : GasFlowInlet;
        port outputPort : GasFlowOutlet;
        action def Regulate {
            in inputPressure : PressureValue;
            out outputPressure : PressureValue;
            doc {
                Reduce high cylinder pressure to safe intermediate
                pressure for insufflation control.
            }
        }
    }

    // ============ Part: Flow Controller ============
    part def FlowController {
        attribute currentFlowRate : FlowRateValue = 0.0 [L_per_min];
        attribute targetFlowRate : FlowRateValue = 0.0 [L_per_min];
        attribute measuredPressure : PressureValue = 0.0 [kPa];
        attribute targetPressure : PressureValue = 1.8 [kPa];
        attribute maxFlowRate : FlowRateValue = 1.0 [L_per_min];
        attribute isActive : Boolean = false;
        port inputPort : GasFlowInlet;
        port outputPort : GasFlowOutlet;
        port pressureInput : PressureSignalIn;
        port commandInput : CommandInput;
        port statusOutput : StatusOutput;
        action def ControlFlow {
            in targetFlowRate : FlowRateValue;
            in targetPressure : PressureValue;
            in measuredPressure : PressureValue;
            out currentFlowRate : FlowRateValue;
            doc {
                Control gas flow rate based on target parameters
                and measured cavity pressure.
            }
        }
        action def StopFlow {
            doc { Immediately stop all gas flow for safety. }
        }
        action def AdjustFlow {
            in currentPressure : PressureValue;
            in targetPressure : PressureValue;
            out adjustedFlowRate : FlowRateValue;
            doc {
                Adjust flow rate based on difference between current
                and target pressure. Reduce flow as target is approached.
            }
        }
        satisfy flowCtrl : ControlledInsufflationFlow;
    }

    // ============ Part: CO2 Insufflator ============
    part def CO2Insufflator {
        attribute isPowered : Boolean = false;
        attribute targetPressure : PressureValue = 1.8 [kPa];
        attribute targetFlowRate : FlowRateValue = 0.5 [L_per_min];
        attribute currentFlowRate : FlowRateValue = 0.0 [L_per_min];
        attribute measuredPressure : PressureValue = 0.0 [kPa];
        attribute currentCommand : String = "none";
        attribute isFlowing : Boolean = false;
        attribute alarmActive : Boolean = false;
        part regulator : PressureRegulator;
        part flowController : FlowController;
        part cylinder : CO2Cylinder;
        port gasOutputPort : GasFlowOutlet;
        port pressureMonitorPort : PressureSignalIn;
        port commandPort : CommandInput;
        port statusPort : StatusOutput;
        connection connect cylinder.outputPort to regulator.inputPort;
        connection connect regulator.outputPort to flowController.inputPort;
        connection connect flowController.outputPort to gasOutputPort;
        connection connect pressureMonitorPort to flowController.pressureInput;
        connection connect commandPort to flowController.commandInput;
        connection connect flowController.statusOutput to statusPort;
        stateMachine insufflatorStates {
            state Idle {
                entry {
                    isFlowing = false;
                    currentFlowRate = 0.0 [L_per_min];
                }
                doc { Insufflator powered off or standing by. }
            }
            state Regulating {
                doc {
                    Regulating high-pressure CO2 from cylinder to
                    safe intermediate pressure for insufflation.
                }
            }
            state Delivering {
                entry { isFlowing = true; }
                doc {
                    Delivering CO2 at controlled flow rate through
                    the needle to the peritoneal cavity.
                }
            }
            state Maintaining {
                entry { isFlowing = false; }
                doc {
                    Target pressure reached. Maintaining stable pressure
                    with minimal compensatory flow as needed.
                }
            }
            state Alarm {
                entry {
                    isFlowing = false;
                    currentFlowRate = 0.0 [L_per_min];
                    alarmActive = true;
                }
                doc {
                    Pressure alarm triggered. Flow stopped immediately
                    for patient safety. Operator intervention required.
                }
            }
            transition from Idle to Regulating when isPowered;
            transition from Regulating to Delivering
                when currentCommand == "start";
            transition from Delivering to Maintaining
                when measuredPressure >= targetPressure;
            transition from Maintaining to Delivering
                when measuredPressure < targetPressure - 0.1 [kPa];
            transition from Delivering to Alarm
                when measuredPressure > 2.0 [kPa];
            transition from Maintaining to Alarm
                when measuredPressure > 2.0 [kPa];
            transition from Alarm to Idle
                when currentCommand == "reset";
        }
        satisfy pressureMaint : MaintainTargetAbdominalPressure;
        satisfy flowControl : ControlledInsufflationFlow;
    }

    // ============ Part: Veress Needle ============
    part def VeressNeedle {
        attribute isDisposable : Boolean = true;
        attribute isSterile : Boolean = true;
        attribute needleLength : LengthValue = 120 [mm];
        attribute needleDiameter : DiameterValue = 2.1 [mm];
        attribute currentTissueResistance : ResistanceValue = 0.0 [N_per_mm];
        attribute isInserted : Boolean = false;
        attribute isInCavity : Boolean = false;
        attribute isPlacementVerified : Boolean = false;
        attribute currentCommand : String = "none";
        attribute measuredPressure : PressureValue = 0.0 [kPa];
        part cannula : SharpCannula;
        part obturator : SpringLoadedObturator;
        part stopcock : Stopcock;
        part pressureSensor : PressureSensor;
        port gasInputPort : GasFlowInlet;
        port gasOutputPort : GasFlowOutlet;
        port pressureOutputPort : PressureSignalOut;
        connection connect gasInputPort to stopcock.inputPort;
        connection connect stopcock.outputPort to cannula.basePort;
        connection connect cannula.tipPort to gasOutputPort;
        connection connect pressureSensor.outputPort to pressureOutputPort;
        stateMachine needleOperationStates {
            state Idle {
                entry { isInserted = false; }
                doc { Needle idle, before insertion into abdominal wall. }
            }
            state Inserting {
                entry { isInserted = true; }
                doc {
                    Surgeon pushes needle through abdominal wall.
                    Tissue resistance keeps obturator retracted.
                    Sharp cannula tip penetrates tissue layers.
                }
            }
            state CavityEntered {
                entry { isInCavity = true; }
                doc {
                    Sudden drop in resistance and pressure indicates
                    needle tip entered peritoneal cavity. Spring-loaded
                    obturator extends to shield sharp tip.
                }
            }
            state Verifying {
                doc {
                    Placement verification: aspiration test, saline drop
                    test, and initial low-pressure reading check.
                }
            }
            state Ready {
                doc { Placement verified, needle ready for insufflation. }
            }
            transition from Idle to Inserting
                when currentCommand == "insert";
            transition from Inserting to CavityEntered
                when currentTissueResistance < 0.5 [N_per_mm];
            transition from CavityEntered to Verifying
                when currentCommand == "verify";
            transition from Verifying to Ready
                when isPlacementVerified;
        }
        action def PerformAspirationTest {
            out result : Boolean;
            doc {
                Aspirate through needle to check for fluid, blood,
                or bowel contents indicating incorrect placement.
            }
        }
        action def PerformSalineDropTest {
            out result : Boolean;
            doc {
                Drop saline through needle. Easy flow into cavity
                confirms correct intraperitoneal placement.
            }
        }
        action def MonitorInitialPressure {
            in pressure : PressureValue;
            out isLow : Boolean;
            doc {
                Monitor initial pressure reading. Low or near-zero
                pressure confirms correct placement in cavity.
            }
        }
    }

    // ============ Part: Veress Needle Insufflation System ============
    part def VeressNeedleInsufflationSystem {
        attribute systemStatus : String = "Idle";
        attribute targetPressure : PressureValue = 1.8 [kPa];
        attribute targetFlowRate : FlowRateValue = 0.5 [L_per_min];
        attribute measuredPressure : PressureValue = 0.0 [kPa];
        attribute currentTissueResistance : ResistanceValue = 0.0 [N_per_mm];
        attribute isPlacementVerified : Boolean = false;
        attribute currentCommand : String = "none";
        attribute isReadyForSurgery : Boolean = false;
        part needle : VeressNeedle;
        part insufflator : CO2Insufflator;
        port needleTipPort : GasFlowOutlet;
        port systemCommandPort : CommandInput;
        port systemStatusPort : StatusOutput;
        port systemPressurePort : PressureSignalOut;
        connection connect insufflator.gasOutputPort to needle.gasInputPort;
        connection connect needle.pressureOutputPort to insufflator.pressureMonitorPort;
        connection connect needle.gasOutputPort to needleTipPort;
        connection connect systemCommandPort to insufflator.commandPort;
        connection connect insufflator.statusPort to systemStatusPort;
        connection connect needle.pressureOutputPort to systemPressurePort;
        stateMachine systemOperationStates {
            state Idle {
                entry { systemStatus = "Idle"; }
                doc { System idle, before needle insertion. }
            }
            state Insertion {
                entry { systemStatus = "Inserting"; }
                doc {
                    Surgeon pushes needle through abdominal wall.
                    Increasing tissue resistance. Obturator retracted.
                    Sharp cannula tip penetrates tissue layers.
                }
            }
            state CavityEntry {
                entry { systemStatus = "CavityEntered"; }
                doc {
                    Sudden drop in resistance and pressure indicates
                    needle tip entered peritoneal cavity. Obturator
                    extends automatically for organ protection.
                }
            }
            state PlacementVerification {
                entry { systemStatus = "Verifying"; }
                doc {
                    Surgeon performs aspiration and saline drop tests,
                    monitors initial low-pressure reading to confirm
                    correct needle placement before insufflation.
                }
            }
            state Insufflating {
                entry { systemStatus = "Insufflating"; }
                doc {
                    Insufflator delivers CO2 through needle at controlled
                    low flow rate. Abdominal cavity gradually inflates
                    toward target pressure.
                }
            }
            state TargetPressureReached {
                entry {
                    systemStatus = "ReadyForSurgery";
                    isReadyForSurgery = true;
                }
                doc {
                    Target pressure reached. Abdomen inflated creating
                    clear expanded space. System ready for main
                    surgical procedure.
                }
            }
            transition from Idle to Insertion
                when currentCommand == "insert";
            transition from Insertion to CavityEntry
                when currentTissueResistance < 0.5 [N_per_mm];
            transition from CavityEntry to PlacementVerification
                when currentCommand == "verify";
            transition from PlacementVerification to Insufflating
                when isPlacementVerified and currentCommand == "insufflate";
            transition from Insufflating to TargetPressureReached
                when measuredPressure >= targetPressure;
            transition from TargetPressureReached to Insufflating
                when measuredPressure < targetPressure - 0.1 [kPa];
        }
        action def InsertionAction {
            in tissueResistance : ResistanceValue;
            out currentResistance : ResistanceValue;
            doc { Advance needle through abdominal wall tissue layers. }
        }
        action def CavityEntryDetection {
            in currentTissueResistance : ResistanceValue;
            in threshold : ResistanceValue;
            out isInCavity : Boolean;
            doc { Detect sudden drop in resistance indicating peritoneal cavity entry. }
        }
        action def VerifyPlacementAction {
            in pressure : PressureValue;
            out isVerified : Boolean;
            doc {
                Perform aspiration test, saline drop test, and pressure
                check to verify correct needle placement.
            }
        }
        action def InsufflateAction {
            in targetFlowRate : FlowRateValue;
            in targetPressure : PressureValue;
            in measuredPressure : PressureValue;
            out currentFlowRate : FlowRateValue;
            doc {
                Deliver CO2 at controlled flow rate through needle until
                target pressure is reached.
            }
        }
        action def MonitorPressureAction {
            in measuredPressure : PressureValue;
            in targetPressure : PressureValue;
            out isTargetReached : Boolean;
            doc {
                Continuously monitor pressure and determine whether
                target pressure has been reached.
            }
        }
        satisfy safePneumo : SafePneumoperitoneumCreation;
        satisfy placementVer : PlacementVerificationReq;
    }
}
