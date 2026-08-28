package LiftChairSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQMass::*;
    import ISQTime::*;
    import ISQElectricity::*;
    import ISQForce::*;
    import ISQAngle::*;

    // ---- Value types ----
    value def MassKg :> Mass { unit 'kg'; }
    value def TimeSec :> Time { unit 's'; }
    value def AngleDeg :> AngleValue { unit 'deg'; }
    value def ForceN :> Force { unit 'N'; }
    value def VoltageV :> ElectricPotential { unit 'V'; }
    value def CurrentA :> ElectricCurrent { unit 'A'; }
    value def Percent :> Real { unit '%'; }

    // ---- Item types ----
    item def ControlCommand {
        attribute command : CommandKind;
        enum CommandKind { raise, lower, stop }
    }

    item def ActuatorFeedback {
        attribute load : ForceN;
        attribute position : AngleDeg;
        attribute moving : Boolean;
        attribute direction : DirectionKind;
        enum DirectionKind { up, down, none }
    }

    item def PowerFlow {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    // ---- Requirements ----
    requirement def SupportCapacity {
        doc { The system shall safely support a person weighing up to 136 kg. }
        attribute maxOccupantMass : MassKg = 136 [kg];
        constraint { self.maxOccupantMass <= 136 [kg] }
    }

    requirement def LiftCycleTime {
        doc { The system shall complete a full lift cycle in under 10 seconds. }
        attribute maxCycleTime : TimeSec = 10 [s];
        constraint { self.maxCycleTime < 10 [s] }
    }

    requirement def SafetyOverride {
        doc { The SafetyController shall stop all movement when actuator load exceeds the safety threshold. }
        attribute loadThreshold : ForceN = 600 [N];
        constraint { self.loadThreshold == 600 [N] }
    }

    requirement def SeatAngleRange {
        doc { The seat frame shall tilt from 0 deg (seated) to 45 deg (standing). }
        attribute seatedAngle : AngleDeg = 0 [deg];
        attribute standingAngle : AngleDeg = 45 [deg];
    }

    // ---- Ports ----
    port def PowerPort {
        out power : PowerFlow;
    }

    port def CommandPort {
        out command : ControlCommand;
    }

    port def FeedbackPort {
        out feedback : ActuatorFeedback;
    }

    // ---- Parts ----

    part def PowerSupply {
        attribute inputVoltage : VoltageV = 120 [V];
        attribute outputVoltage : VoltageV = 24 [V];
        attribute maxOutputCurrent : CurrentA = 15 [A];
        port powerOut : PowerPort;
        satisfy SupportCapacity by powerOut;
    }

    part def HandControl {
        attribute raisePressed : Boolean = false;
        attribute lowerPressed : Boolean = false;
        attribute stopPressed : Boolean = false;
        port commandOut : CommandPort;
        action issueCommand {
            in raiseBtn : Boolean;
            in lowerBtn : Boolean;
            in stopBtn : Boolean;
            out cmd : ControlCommand;
            if stopBtn then
                cmd.command := ControlCommand::CommandKind::stop;
            else if raiseBtn then
                cmd.command := ControlCommand::CommandKind::raise;
            else if lowerBtn then
                cmd.command := ControlCommand::CommandKind::lower;
            else
                cmd.command := ControlCommand::CommandKind::stop;
        }
    }

    part def LinearActuator {
        attribute strokeAngle : AngleDeg = 45 [deg];
        attribute maxForce : ForceN = 1200 [N];
        attribute currentLoad : ForceN = 0 [N];
        attribute currentPosition : AngleDeg = 0 [deg];
        attribute moving : Boolean = false;
        attribute direction : ActuatorFeedback::DirectionKind = ActuatorFeedback::DirectionKind::none;
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port feedbackOut : FeedbackPort;
        action move {
            in cmd : ControlCommand;
            in power : PowerFlow;
            out fb : ActuatorFeedback;
            if cmd.command == ControlCommand::CommandKind::raise then {
                self.direction := ActuatorFeedback::DirectionKind::up;
                self.moving := true;
                self.currentPosition := self.currentPosition + 1 [deg];
            } else if cmd.command == ControlCommand::CommandKind::lower then {
                self.direction := ActuatorFeedback::DirectionKind::down;
                self.moving := true;
                self.currentPosition := self.currentPosition - 1 [deg];
            } else {
                self.direction := ActuatorFeedback::DirectionKind::none;
                self.moving := false;
            }
            fb.load := self.currentLoad;
            fb.position := self.currentPosition;
            fb.moving := self.moving;
            fb.direction := self.direction;
        }
    }

    part def SeatFrame {
        attribute angle : AngleDeg = 0 [deg];
        attribute maxOccupantMass : MassKg = 136 [kg];
        attribute currentOccupantMass : MassKg = 0 [kg];
        satisfy SeatAngleRange;
        action tilt {
            in targetAngle : AngleDeg;
            if targetAngle > 45 [deg] then
                self.angle := 45 [deg];
            else if targetAngle < 0 [deg] then
                self.angle := 0 [deg];
            else
                self.angle := targetAngle;
        }
    }

    part def SafetyController {
        attribute loadThreshold : ForceN = 600 [N];
        attribute overrideActive : Boolean = false;
        port feedbackIn : FeedbackPort;
        port commandOut : CommandPort;
        satisfy SafetyOverride;
        action monitor {
            in fb : ActuatorFeedback;
            in userCmd : ControlCommand;
            out safeCmd : ControlCommand;
            if fb.load > self.loadThreshold then {
                self.overrideActive := true;
                safeCmd.command := ControlCommand::CommandKind::stop;
            } else {
                self.overrideActive := false;
                safeCmd := userCmd;
            }
        }
    }

    // ---- State machine for chair operation ----
    state def ChairStates {
        attribute currentAngle : AngleDeg;
        attribute loadThreshold : ForceN = 600 [N];

        initial seated;
        state seated {
            entry { self.currentAngle := 0 [deg]; }
        }
        state lifting {
            entry { self.currentAngle := self.currentAngle + 1 [deg]; }
            do { self.currentAngle := self.currentAngle + 1 [deg]; }
        }
        state standing {
            entry { self.currentAngle := 45 [deg]; }
        }
        state lowering {
            entry { self.currentAngle := self.currentAngle - 1 [deg]; }
            do { self.currentAngle := self.currentAngle - 1 [deg]; }
        }
        state stopped;

        transition seated_to_lifting
            first seated
            accept ControlCommand{command == ControlCommand::CommandKind::raise}
            then lifting;

        transition lifting_to_standing
            first lifting
            accept ControlCommand{command == ControlCommand::CommandKind::stop}
            then standing
            if currentAngle >= 45 [deg];

        transition lifting_to_stopped
            first lifting
            accept ControlCommand{command == ControlCommand::CommandKind::stop}
            then stopped;

        transition standing_to_lowering
            first standing
            accept ControlCommand{command == ControlCommand::CommandKind::lower}
            then lowering;

        transition lowering_to_seated
            first lowering
            accept ControlCommand{command == ControlCommand::CommandKind::stop}
            then seated
            if currentAngle <= 0 [deg];

        transition lowering_to_stopped
            first lowering
            accept ControlCommand{command == ControlCommand::CommandKind::stop}
            then stopped;

        transition stopped_to_lifting
            first stopped
            accept ControlCommand{command == ControlCommand::CommandKind::raise}
            then lifting;

        transition stopped_to_lowering
            first stopped
            accept ControlCommand{command == ControlCommand::CommandKind::lower}
            then lowering;

        transition any_to_stopped_safety
            first lifting
            accept ActuatorFeedback{load > loadThreshold}
            then stopped;

        transition lowering_safety
            first lowering
            accept ActuatorFeedback{load > loadThreshold}
            then stopped;
    }

    // ---- Top-level system ----
    part def LiftChairSystem {
        satisfy SupportCapacity;
        satisfy LiftCycleTime;

        part powerSupply : PowerSupply {
            attribute outputVoltage : VoltageV = 24 [V];
        }
        part handControl : HandControl;
        part linearActuator : LinearActuator;
        part seatFrame : SeatFrame;
        part safetyController : SafetyController;

        port externalPower : PowerPort;
        port userCommand : CommandPort;

        // Internal connections
        connection powerConnection : PowerFlow
            from powerSupply.powerOut
            to linearActuator.powerIn;

        connection userCommandConnection : ControlCommand
            from handControl.commandOut
            to safetyController.commandOut;

        connection safetyCommandConnection : ControlCommand
            from safetyController.commandOut
            to linearActuator.commandIn;

        connection feedbackConnection : ActuatorFeedback
            from linearActuator.feedbackOut
            to safetyController.feedbackIn;

        // External connections
        connection externalPowerConnection : PowerFlow
            from externalPower
            to powerSupply.powerOut;

        // State machine instance
        exhibit state chairState : ChairStates;

        // Requirements allocation
        satisfy SupportCapacity by seatFrame;
        satisfy LiftCycleTime by linearActuator;
        satisfy SafetyOverride by safetyController;
    }
}
