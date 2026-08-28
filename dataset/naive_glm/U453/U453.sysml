package OphthalmicExaminationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value type LengthUnit > Real { unit 'm'; }
    value type AngleUnit > Real { unit 'deg'; }
    value type MassUnit > Real { unit 'kg'; }
    value type VoltageUnit > Real { unit 'V'; }
    value type PowerUnit > Real { unit 'W'; }
    value type CurrentUnit > Real { unit 'A'; }
    value type DiopterUnit > Real { unit 'D'; }
    value type SpeedUnit > Real { unit 'm/s'; }
    value type AngularSpeedUnit > Real { unit 'deg/s'; }

    // ---------- Enumerations ----------
    enum SystemState { idle, positioning, examining, emergencyStopped }
    enum CommandKind { setHeight, setTilt, setChairHeight, setSphere, setCylinder, emergencyStop, resume }

    // ---------- Item Types ----------
    item def ACPower {
        attribute voltage : VoltageUnit = 230;
        attribute frequency : Real = 50;
    }

    item def DCPower {
        attribute voltage : VoltageUnit;
        attribute maxCurrent : CurrentUnit;
    }

    item def ControlCommand {
        attribute kind : CommandKind;
        attribute targetValue : Real;
    }

    item def PositionFeedback {
        attribute height : LengthUnit;
        attribute tilt : AngleUnit;
        attribute chairHeight : LengthUnit;
    }

    item def LensSettings {
        attribute sphere : DiopterUnit;
        attribute cylinder : DiopterUnit;
    }

    // ---------- Port Definitions ----------
    port def ACInputPort {
        in item acIn : ACPower;
    }

    port def DCOutputPort {
        out item dcOut : DCPower;
    }

    port def CommandPort {
        in item command : ControlCommand;
        out item feedback : PositionFeedback;
    }

    port def LensCommandPort {
        in item lensCmd : LensSettings;
        out item lensFeedback : LensSettings;
    }

    port def EmergencyStopPort {
        in item estopTrigger : Boolean;
    }

    // ---------- Requirements ----------
    requirement def HeightAdjustmentRequirement {
        doc { The table height shall be adjustable between 0.60 m and 1.20 m. }
        attribute minHeight : LengthUnit = 0.60;
        attribute maxHeight : LengthUnit = 1.20;
        subject tableHeight : LengthUnit;
        require tableHeight >= minHeight and tableHeight <= maxHeight;
    }

    requirement def TiltAdjustmentRequirement {
        doc { The instrument arm tilt shall be adjustable from -15 to +45 degrees. }
        attribute minTilt : AngleUnit = -15;
        attribute maxTilt : AngleUnit = 45;
        subject armTilt : AngleUnit;
        require armTilt >= minTilt and armTilt <= maxTilt;
    }

    requirement def ChairLoadRequirement {
        doc { The patient chair shall support patients weighing up to 180 kg. }
        attribute maxLoad : MassUnit = 180;
        subject patientWeight : MassUnit;
        require patientWeight <= maxLoad;
    }

    requirement def EmergencyStopRequirement {
        doc { The emergency stop shall halt all motorized motion instantly. }
        subject estopActive : Boolean;
        require estopActive implies allMotionStopped;
        attribute allMotionStopped : Boolean;
    }

    requirement def PowerSupplyRequirement {
        doc { The power supply shall convert standard wall AC power to low-voltage DC. }
        attribute inputVoltage : VoltageUnit = 230;
        attribute outputVoltage : VoltageUnit = 24;
        require outputVoltage < inputVoltage;
    }

    // ---------- Parts: Actuators ----------
    part def LinearActuator {
        attribute minPosition : LengthUnit;
        attribute maxPosition : LengthUnit;
        attribute maxSpeed : SpeedUnit = 0.05;
        attribute currentPosition : LengthUnit;
        attribute targetPosition : LengthUnit;
        attribute isMoving : Boolean = false;
        attribute powerOn : Boolean = false;

        in item dcPower : DCPower;
        in item estop : Boolean;

        action def MoveToPosition {
            in target : LengthUnit;
            in current : LengthUnit;
            out newPosition : LengthUnit;
        }

        perform action moveSequence {
            if estop then {
                isMoving = false;
            } else {
                if targetPosition > minPosition and targetPosition < maxPosition then {
                    isMoving = true;
                    currentPosition = targetPosition;
                    isMoving = false;
                }
            }
        }
    }

    part def TiltActuator {
        attribute minAngle : AngleUnit;
        attribute maxAngle : AngleUnit;
        attribute maxAngularSpeed : AngularSpeedUnit = 5.0;
        attribute currentAngle : AngleUnit;
        attribute targetAngle : AngleUnit;
        attribute isMoving : Boolean = false;
        attribute powerOn : Boolean = false;

        in item dcPower : DCPower;
        in item estop : Boolean;

        perform action tiltSequence {
            if estop then {
                isMoving = false;
            } else {
                if targetAngle >= minAngle and targetAngle <= maxAngle then {
                    isMoving = true;
                    currentAngle = targetAngle;
                    isMoving = false;
                }
            }
        }
    }

    // ---------- Parts: Welner Table ----------
    part def WelnerTable {
        port acPowerRef : ACInputPort;
        port cmdPort : CommandPort;
        port estopPort : EmergencyStopPort;

        attribute tableHeight : LengthUnit;
        attribute armTilt : AngleUnit;

        part heightActuator : LinearActuator {
            redefines minPosition = 0.60;
            redefines maxPosition = 1.20;
        }

        part tiltActuator : TiltActuator {
            redefines minAngle = -15;
            redefines maxAngle = 45;
        }

        part instrumentArm {
            attribute loadCapacity : MassUnit = 15;
            attribute mounted : Boolean = true;
            port instrumentMount : CommandPort;
        }

        satisfy HeightAdjustmentRequirement {
            subject tableHeight = heightActuator.currentPosition;
        }

        satisfy TiltAdjustmentRequirement {
            subject armTilt = tiltActuator.currentAngle;
        }

        perform action handleCommand {
            in cmd : ControlCommand;
            if cmd.kind == CommandKind::setHeight then {
                heightActuator.targetPosition = cmd.targetValue;
            } else if cmd.kind == CommandKind::setTilt then {
                tiltActuator.targetAngle = cmd.targetValue;
            }
        }
    }

    // ---------- Parts: Patient Chair ----------
    part def PatientChair {
        port cmdPort : CommandPort;
        port estopPort : EmergencyStopPort;

        attribute maxPatientWeight : MassUnit = 180;
        attribute currentHeight : LengthUnit;
        attribute minHeight : LengthUnit = 0.40;
        attribute maxHeight : LengthUnit = 0.80;
        attribute isMoving : Boolean = false;

        part chairHeightActuator : LinearActuator {
            redefines minPosition = 0.40;
            redefines maxPosition = 0.80;
        }

        satisfy ChairLoadRequirement {
            subject patientWeight = maxPatientWeight;
        }

        perform action adjustChair {
            in cmd : ControlCommand;
            if cmd.kind == CommandKind::setChairHeight then {
                chairHeightActuator.targetPosition = cmd.targetValue;
            }
        }
    }

    // ---------- Parts: Phoropter ----------
    part def Phoropter {
        port lensPort : LensCommandPort;
        port cmdPort : CommandPort;
        port estopPort : EmergencyStopPort;

        attribute spherePower : DiopterUnit;
        attribute cylinderPower : DiopterUnit;
        attribute sphereRange : DiopterUnit[2] = [-20.0, 20.0];
        attribute cylinderRange : DiopterUnit[2] = [0.0, 6.0];
        attribute isAdjusting : Boolean = false;

        perform action adjustLens {
            in cmd : ControlCommand;
            if cmd.kind == CommandKind::setSphere then {
                if cmd.targetValue >= sphereRange[1] and cmd.targetValue <= sphereRange[2] then {
                    spherePower = cmd.targetValue;
                }
            } else if cmd.kind == CommandKind::setCylinder then {
                if cmd.targetValue >= cylinderRange[1] and cmd.targetValue <= cylinderRange[2] then {
                    cylinderPower = cmd.targetValue;
                }
            }
        }

        perform action refractionTest {
            in s : DiopterUnit;
            in c : DiopterUnit;
            out result : LensSettings;
            result.sphere = s;
            result.cylinder = c;
        }
    }

    // ---------- Parts: Control Panel ----------
    part def TouchscreenControlPanel {
        port tableCmdOut : CommandPort;
        port chairCmdOut : CommandPort;
        port phoropterCmdOut : CommandPort;
        port lensCmdOut : LensCommandPort;
        port estopOut : EmergencyStopPort;

        attribute currentState : SystemState = SystemState::idle;
        attribute uiActive : Boolean = true;

        action def ProcessUserInput {
            in selection : CommandKind;
            in value : Real;
            out cmd : ControlCommand;
            cmd.kind = selection;
            cmd.targetValue = value;
        }

        action def TriggerEstop {
            out estopSignal : Boolean;
            estopSignal = true;
        }

        perform action manageStates {
            if currentState == SystemState::idle then {
                // Accept positioning commands
            } else if currentState == SystemState::positioning then {
                // Adjusting components
            } else if currentState == SystemState::examining then {
                // Examination in progress
            } else if currentState == SystemState::emergencyStopped then {
                // All motion halted
            }
        }

        state def ControlPanelStateMachine {
            entry; then Idle;

            state Idle;
            transition from Idle to Positioning
                when cmdPort.command.kind == CommandKind::setHeight
                or cmdPort.command.kind == CommandKind::setTilt
                or cmdPort.command.kind == CommandKind::setChairHeight;

            state Positioning;
            transition from Positioning to Examining
                when cmdPort.command.kind == CommandKind::setSphere
                or cmdPort.command.kind == CommandKind::setCylinder;

            state Examining;
            transition from Examining to Idle
                when uiActive == false;

            transition from Idle to EmergencyStopped
                when estopOut.estopTrigger == true;
            transition from Positioning to EmergencyStopped
                when estopOut.estopTrigger == true;
            transition from Examining to EmergencyStopped
                when estopOut.estopTrigger == true;

            state EmergencyStopped;
            transition from EmergencyStopped to Idle
                when cmdPort.command.kind == CommandKind::resume;
        }

        exhibit ControlPanelStateMachine;
    }

    // ---------- Parts: Power Supply ----------
    part def PowerSupplyUnit {
        port acInput : ACInputPort;
        port dcOutput : DCOutputPort;

        attribute inputVoltage : VoltageUnit = 230;
        attribute outputVoltage : VoltageUnit = 24;
        attribute maxOutputPower : PowerUnit = 300;
        attribute efficiency : Real = 0.90;
        attribute isOn : Boolean = false;

        satisfy PowerSupplyRequirement {
            attribute redefines inputVoltage = 230;
            attribute redefines outputVoltage = 24;
        }

        perform action convertPower {
            in ac : ACPower;
            out dc : DCPower;
            dc.voltage = outputVoltage;
            dc.maxCurrent = maxOutputPower / outputVoltage;
            isOn = true;
        }
    }

    // ---------- Top-level System ----------
    part def OphthalmicExaminationSystem {
        port mainACInput : ACInputPort;
        port systemEstop : EmergencyStopPort;

        attribute systemState : SystemState = SystemState::idle;
        attribute estopActive : Boolean = false;

        part powerSupply : PowerSupplyUnit;
        part welnerTable : WelnerTable;
        part patientChair : PatientChair;
        part phoropter : Phoropter;
        part controlPanel : TouchscreenControlPanel;

        // Internal DC power bus
        item dcBus : DCPower;

        // Connections
        connection acToPS connect mainACInput to powerSupply.acInput;
        connection psToTable connect powerSupply.dcOutput to welnerTable.acPowerRef;
        connection psToChair connect powerSupply.dcOutput to patientChair.cmdPort;
        connection psToPhoropter connect powerSupply.dcOutput to phoropter.cmdPort;
        connection psToPanel connect powerSupply.dcOutput to controlPanel.tableCmdOut;

        connection panelToTable connect controlPanel.tableCmdOut to welnerTable.cmdPort;
        connection panelToChair connect controlPanel.chairCmdOut to patientChair.cmdPort;
        connection panelToPhoropter connect controlPanel.phoropterCmdOut to phoropter.cmdPort;
        connection panelLensToPhoropter connect controlPanel.lensCmdOut to phoropter.lensPort;

        // Emergency stop distribution
        connection estopToTable connect systemEstop to welnerTable.estopPort;
        connection estopToChair connect systemEstop to patientChair.estopPort;
        connection estopToPhoropter connect systemEstop to phoropter.estopPort;
        connection estopToPanel connect systemEstop to controlPanel.estopOut;

        satisfy EmergencyStopRequirement {
            subject estopActive = systemEstop.estopTrigger;
            attribute allMotionStopped = (not welnerTable.heightActuator.isMoving)
                and (not welnerTable.tiltActuator.isMoving)
                and (not patientChair.isMoving)
                and (not phoropter.isAdjusting);
        }

        state def SystemStateMachine {
            entry; then SystemIdle;

            state SystemIdle {
                entry;
                // System powered on, awaiting commands
            }

            transition from SystemIdle to SystemPositioning
                when controlPanel.tableCmdOut.command.kind == CommandKind::setHeight
                or controlPanel.tableCmdOut.command.kind == CommandKind::setTilt
                or controlPanel.chairCmdOut.command.kind == CommandKind::setChairHeight;

            state SystemPositioning {
                // Table height/tilt and chair height being adjusted
            }

            transition from SystemPositioning to SystemExamining
                when controlPanel.phoropterCmdOut.command.kind == CommandKind::setSphere
                or controlPanel.phoropterCmdOut.command.kind == CommandKind::setCylinder;

            state SystemExamining {
                // Refraction test in progress
            }

            transition from SystemExamining to SystemIdle
                when controlPanel.uiActive == false;

            transition from SystemIdle to SystemEmergencyStopped
                when systemEstop.estopTrigger == true;
            transition from SystemPositioning to SystemEmergencyStopped
                when systemEstop.estopTrigger == true;
            transition from SystemExamining to SystemEmergencyStopped
                when systemEstop.estopTrigger == true;

            state SystemEmergencyStopped {
                entry;
                // All motorized motion halted
            }

            transition from SystemEmergencyStopped to SystemIdle
                when controlPanel.tableCmdOut.command.kind == CommandKind::resume;
        }

        exhibit SystemStateMachine;

        perform action powerOnSequence {
            in ac : ACPower;
            powerSupply.convertPower(ac, dcBus);
            systemState = SystemState::idle;
        }
    }
}
