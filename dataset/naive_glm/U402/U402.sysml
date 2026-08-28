package MedicalStretcher {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ---- Value Types with Units ----
    value type MassValue :> Real { unit 'kg'; }
    value type LengthValue :> Real { unit 'cm'; }
    value type AngleValue :> Real { unit 'deg'; }
    value type PressureValue :> Real { unit 'bar'; }
    value type SpeedValue :> Real { unit 'm/s'; }

    // ---- Enumerations ----
    enum BrakeStatus { engaged; disengaged; }
    enum RailStatus { raised; lowered; }
    enum LockStatus { locked; unlocked; }
    enum PatientSecureStatus { secured; unsecured; }
    enum OperationalMode { standby; securing; adjusting; transporting; transferring; }

    // ---- Item Definitions ----
    item def Patient {
        attribute weight : MassValue;
    }

    item def Operator;

    item def ControlCommand {
        attribute targetHeight : LengthValue;
        attribute targetBackrestAngle : AngleValue;
        attribute brakeCommand : BrakeStatus;
        attribute railCommand : RailStatus;
        attribute secureCommand : PatientSecureStatus;
    }

    item def SystemStatus {
        attribute currentHeight : LengthValue;
        attribute currentBackrestAngle : AngleValue;
        attribute brakeStatus : BrakeStatus;
        attribute railStatus : RailStatus;
        attribute patientSecureStatus : PatientSecureStatus;
        attribute mode : OperationalMode;
    }

    item def SafetyAlert {
        attribute code : String;
        attribute description : String;
        attribute severity : Integer;
    }

    // ---- Port Definitions ----
    port def ControlPort {
        in item command : ControlCommand;
        out item status : SystemStatus;
    }

    port def AlertPort {
        out item alert : SafetyAlert;
    }

    port def MechanicalLoadPort {
        in attribute appliedLoad : MassValue;
        out attribute reactionLoad : MassValue;
    }

    // ---- Requirements ----
    requirement def LoadCapacityRequirement {
        doc { The main frame shall support a maximum load of 250 kg. }
        attribute maxLoad : MassValue = 250 [kg];
        subject frame :> Frame;
        constraint { frame.loadCapacity >= maxLoad }
    }

    requirement def HeightAdjustmentRequirement {
        doc { The height adjustment mechanism shall raise/lower the patient surface between 50 cm and 90 cm. }
        attribute minHeight : LengthValue = 50 [cm];
        attribute maxHeight : LengthValue = 90 [cm];
        subject mechanism :> HeightAdjustmentMechanism;
        constraint { mechanism.minHeight >= minHeight and mechanism.maxHeight <= maxHeight }
    }

    requirement def BackrestAdjustmentRequirement {
        doc { The backrest shall be adjustable from 0 to 75 degrees. }
        attribute minAngle : AngleValue = 0 [deg];
        attribute maxAngle : AngleValue = 75 [deg];
        subject mechanism :> BackrestMechanism;
        constraint { mechanism.minAngle >= minAngle and mechanism.maxAngle <= maxAngle }
    }

    requirement def WheelCountRequirement {
        doc { The wheel assembly shall contain exactly four wheels. }
        attribute requiredWheelCount : Integer = 4;
        subject assembly :> WheelAssembly;
        constraint { assembly.wheelCount == requiredWheelCount }
    }

    requirement def SafetyInterlockRequirement {
        doc { The controller shall verify patient secured, rails raised, and wheels locked before and after movement. }
        subject controller :> CentralController;
        constraint {
            controller.status.patientSecureStatus == PatientSecureStatus::secured and
            controller.status.railStatus == RailStatus::raised and
            controller.status.brakeStatus == BrakeStatus::engaged
        }
    }

    requirement def RailPairRequirement {
        doc { The stretcher shall have a pair of safety rails on left and right sides. }
        subject stretcher :> Stretcher;
        constraint { stretcher.frame.leftRail.side == "left" and stretcher.frame.rightRail.side == "right" }
    }

    // ---- Part Definitions ----
    part def Frame {
        attribute loadCapacity : MassValue = 250 [kg];
        attribute currentLoad : MassValue = 0 [kg];
        attribute structuralIntegrityOK : Boolean = true;
        port controlPort : ControlPort;
        port loadPort : MechanicalLoadPort;
    }

    part def Wheel {
        attribute identifier : String;
        attribute brakeStatus : BrakeStatus = BrakeStatus::disengaged;
        attribute lockStatus : LockStatus = LockStatus::unlocked;
        port controlPort : ControlPort;
        action engageBrake;
        action disengageBrake;
    }

    part def WheelAssembly {
        attribute wheelCount : Integer = 4;
        attribute brakeStatus : BrakeStatus = BrakeStatus::disengaged;
        port controlPort : ControlPort;
        part wheel1 : Wheel { attribute identifier = "FL"; }
        part wheel2 : Wheel { attribute identifier = "FR"; }
        part wheel3 : Wheel { attribute identifier = "RL"; }
        part wheel4 : Wheel { attribute identifier = "RR"; }

        action engageAllBrakes {
            perform wheel1.engageBrake;
            perform wheel2.engageBrake;
            perform wheel3.engageBrake;
            perform wheel4.engageBrake;
            assign brakeStatus := BrakeStatus::engaged;
        }
        action disengageAllBrakes {
            perform wheel1.disengageBrake;
            perform wheel2.disengageBrake;
            perform wheel3.disengageBrake;
            perform wheel4.disengageBrake;
            assign brakeStatus := BrakeStatus::disengaged;
        }
    }

    part def HeightAdjustmentMechanism {
        attribute type : String = "hydraulic";
        attribute minHeight : LengthValue = 50 [cm];
        attribute maxHeight : LengthValue = 90 [cm];
        attribute currentHeight : LengthValue = 65 [cm];
        attribute hydraulicPressure : PressureValue = 0 [bar];
        port controlPort : ControlPort;
        action raise(target : LengthValue) {
            if target > maxHeight then assign target := maxHeight;
            assign currentHeight := target;
        }
        action lower(target : LengthValue) {
            if target < minHeight then assign target := minHeight;
            assign currentHeight := target;
        }
    }

    part def BackrestMechanism {
        attribute minAngle : AngleValue = 0 [deg];
        attribute maxAngle : AngleValue = 75 [deg];
        attribute currentAngle : AngleValue = 0 [deg];
        port controlPort : ControlPort;
        action incline(target : AngleValue) {
            if target > maxAngle then assign target := maxAngle;
            assign currentAngle := target;
        }
        action decline(target : AngleValue) {
            if target < minAngle then assign target := minAngle;
            assign currentAngle := target;
        }
    }

    part def SafetyRail {
        attribute side : String;
        attribute status : RailStatus = RailStatus::lowered;
        attribute lockStatus : LockStatus = LockStatus::unlocked;
        port controlPort : ControlPort;
        action raise {
            assign status := RailStatus::raised;
            assign lockStatus := LockStatus::locked;
        }
        action lower {
            assign lockStatus := LockStatus::unlocked;
            assign status := RailStatus::lowered;
        }
    }

    part def CentralController {
        attribute status : SystemStatus;
        attribute safetyVerified : Boolean = false;
        port operatorPort : ControlPort;
        port framePort : ControlPort;
        port wheelPort : ControlPort;
        port heightPort : ControlPort;
        port backrestPort : ControlPort;
        port leftRailPort : ControlPort;
        port rightRailPort : ControlPort;
        port alertPort : AlertPort;

        action verifySafety : Boolean {
            assign safetyVerified :=
                status.patientSecureStatus == PatientSecureStatus::secured and
                status.railStatus == RailStatus::raised and
                status.brakeStatus == BrakeStatus::engaged;
        }

        action issueCommand(cmd : ControlCommand) {
            send cmd to heightPort;
            send cmd to backrestPort;
            send cmd to wheelPort;
            send cmd to leftRailPort;
            send cmd to rightRailPort;
        }

        action raiseAlert(code : String, description : String, severity : Integer) {
            send SafetyAlert{ code = code; description = description; severity = severity; } to alertPort;
        }

        state def ControllerBehavior {
            entry action { assign status.mode := OperationalMode::standby; }
            then Standby;

            state Standby {
                entry action { assign status.mode := OperationalMode::standby; }
            }
            state SecuringPatient {
                entry action { assign status.mode := OperationalMode::securing; }
                do action {
                    if status.patientSecureStatus != PatientSecureStatus::secured then
                        raiseAlert("P001", "Patient not secured", 2);
                }
            }
            state Adjusting {
                entry action { assign status.mode := OperationalMode::adjusting; }
            }
            state Transporting {
                entry action { assign status.mode := OperationalMode::transporting; }
                do action {
                    if not verifySafety() then
                        raiseAlert("T001", "Safety interlock violated during transport", 3);
                }
            }
            state Transferring {
                entry action { assign status.mode := OperationalMode::transferring; }
            }

            transition Standby_to_Securing
                first Standby
                if operatorPort.command.secureCommand == PatientSecureStatus::secured
                then SecuringPatient;

            transition Securing_to_Adjusting
                first SecuringPatient
                if status.patientSecureStatus == PatientSecureStatus::secured
                then Adjusting;

            transition Adjusting_to_Transporting
                first Adjusting
                if verifySafety() and operatorPort.command.brakeCommand == BrakeStatus::disengaged
                then Transporting;

            transition Transporting_to_Transferring
                first Transporting
                if operatorPort.command.brakeCommand == BrakeStatus::engaged
                then Transferring;

            transition Transferring_to_Standby
                first Transferring
                if operatorPort.command.secureCommand == PatientSecureStatus::unsecured
                then Standby;
        }

        exhibit ControllerBehavior;
    }

    part def Stretcher {
        part frame : Frame {
            part wheelAssembly : WheelAssembly;
            part heightAdjustment : HeightAdjustmentMechanism;
            part backrest : BackrestMechanism;
            part leftRail : SafetyRail { attribute side = "left"; }
            part rightRail : SafetyRail { attribute side = "right"; }
            part controller : CentralController;
        }

        satisfy LoadCapacityRequirement by frame;
        satisfy HeightAdjustmentRequirement by frame.heightAdjustment;
        satisfy BackrestAdjustmentRequirement by frame.backrest;
        satisfy WheelCountRequirement by frame.wheelAssembly;
        satisfy SafetyInterlockRequirement by frame.controller;
        satisfy RailPairRequirement by Stretcher;

        connection operatorToController
            connect frame.controller.operatorPort to frame.controlPort;
        connection controllerToWheel
            connect frame.controller.wheelPort to frame.wheelAssembly.controlPort;
        connection controllerToHeight
            connect frame.controller.heightPort to frame.heightAdjustment.controlPort;
        connection controllerToBackrest
            connect frame.controller.backrestPort to frame.backrest.controlPort;
        connection controllerToLeftRail
            connect frame.controller.leftRailPort to frame.leftRail.controlPort;
        connection controllerToRightRail
            connect frame.controller.rightRailPort to frame.rightRail.controlPort;
        connection frameToControllerStatus
            connect frame.controlPort to frame.controller.framePort;
    }

    // ---- Operational Workflow Action Definition ----
    action def TransportWorkflow {
        in patient : Patient;
        in operator : Operator;
        out stretcher : Stretcher;

        action securePatient {
            assign stretcher.frame.controller.status.patientSecureStatus := PatientSecureStatus::secured;
        }
        action raiseRails {
            perform stretcher.frame.leftRail.raise;
            perform stretcher.frame.rightRail.raise;
            assign stretcher.frame.controller.status.railStatus := RailStatus::raised;
        }
        action adjustHeight {
            perform stretcher.frame.heightAdjustment.raise(75 [cm]);
        }
        action transportPatient {
            perform stretcher.frame.wheelAssembly.disengageAllBrakes;
            assign stretcher.frame.controller.status.brakeStatus := BrakeStatus::disengaged;
        }
        action lockWheels {
            perform stretcher.frame.wheelAssembly.engageAllBrakes;
            assign stretcher.frame.controller.status.brakeStatus := BrakeStatus::engaged;
        }
        action transferPatient {
            perform stretcher.frame.leftRail.lower;
            perform stretcher.frame.rightRail.lower;
            assign stretcher.frame.controller.status.patientSecureStatus := PatientSecureStatus::unsecured;
        }

        then securePatient;
        then raiseRails;
        then adjustHeight;
        then transportPatient;
        then lockWheels;
        then transferPatient;
    }
}
