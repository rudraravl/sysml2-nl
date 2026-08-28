package 'Hydraulic Operating Table System' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def HeightValue :> Real;
    attribute def TiltAngle :> Real;
    attribute def PatientWeight :> Real;
    attribute def FluidPressureValue :> Real;
    attribute def FlowRateValue :> Real;

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }

    item def HydraulicFluid {
        attribute pressure : FluidPressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def DesiredPosition {
        attribute height : HeightValue;
        attribute longitudinalTilt : TiltAngle;
        attribute lateralTilt : TiltAngle;
        attribute trendelenburgTilt : TiltAngle;
    }

    item def CurrentPosition {
        attribute height : HeightValue;
        attribute longitudinalTilt : TiltAngle;
        attribute lateralTilt : TiltAngle;
        attribute trendelenburgTilt : TiltAngle;
        attribute weight : PatientWeight;
    }

    item def ActuatorCommand {
        attribute flowRate : FlowRateValue;
    }

    attribute def EmergencyStopSignal;
    attribute def SafetyAlertSignal;
    attribute def LockCommand;
    attribute def PositioningCompleteSignal;
    attribute def ResetSignal;

    part def ControlPanel {
        port desiredPositionOutPort {
            out desiredPosition : DesiredPosition;
        }
        port emergencyStopOutPort {
            out emergencyStopSignal : EmergencyStopSignal;
        }
        port resetOutPort {
            out resetSignal : ResetSignal;
        }
    }

    part def PositionController {
        port desiredPositionInPort {
            in desiredPosition : DesiredPosition;
        }
        port currentPositionInPort {
            in currentPosition : CurrentPosition;
        }
        port safetyAlertInPort {
            in safetyAlert : SafetyAlertSignal;
        }
        port emergencyStopInPort {
            in emergencyStopSignal : EmergencyStopSignal;
        }
        port resetInPort {
            in resetSignal : ResetSignal;
        }
        port heightCommandOutPort {
            out heightCommand : ActuatorCommand;
        }
        port longitudinalTiltCommandOutPort {
            out longitudinalTiltCommand : ActuatorCommand;
        }
        port lateralTiltCommandOutPort {
            out lateralTiltCommand : ActuatorCommand;
        }
        port trendelenburgTiltCommandOutPort {
            out trendelenburgTiltCommand : ActuatorCommand;
        }
        port lockCommandOutPort {
            out lockCommand : LockCommand;
        }
        port positioningCompleteOutPort {
            out positioningCompleteSignal : PositioningCompleteSignal;
        }

        exhibit state controllerState {
            entry; then idle;

            state idle;
            accept DesiredPosition
                then positioning;
            accept SafetyAlertSignal
                then halted;
            accept EmergencyStopSignal
                then halted;

            state positioning {
                do send new ActuatorCommand() to heightCommandOutPort;
            }
            accept CurrentPosition
                if currentPositionInPort.currentPosition.height == desiredPositionInPort.desiredPosition.height
                then locked;
            accept SafetyAlertSignal
                then halted;
            accept EmergencyStopSignal
                then halted;

            state locked {
                do send new LockCommand() to lockCommandOutPort;
            }
            accept DesiredPosition
                then positioning;
            accept SafetyAlertSignal
                then halted;
            accept EmergencyStopSignal
                then halted;

            state halted {
                do send new LockCommand() to lockCommandOutPort;
            }
            accept ResetSignal
                then idle;
        }
    }

    part def SafetyMonitor {
        port positionInPort {
            in position : CurrentPosition;
        }
        port emergencyStopInPort {
            in emergencyStopSignal : EmergencyStopSignal;
        }
        port alertOutPort {
            out alert : SafetyAlertSignal;
        }
        port resetInPort {
            in resetSignal : ResetSignal;
        }

        exhibit state monitorState {
            entry; then normal;

            state normal;
            accept when positionInPort.position.weight > 250
                do send new SafetyAlertSignal() to alertOutPort
                then alerting;
            accept EmergencyStopSignal
                do send new SafetyAlertSignal() to alertOutPort
                then alerting;

            state alerting;
            accept ResetSignal
                then normal;
        }
    }

    part def HydraulicPump {
        port powerInPort {
            in power : ElectricalPower;
        }
        port fluidOutPort {
            out fluid : HydraulicFluid;
        }
    }

    part def HeightActuator {
        port commandInPort {
            in command : ActuatorCommand;
        }
        port fluidInPort {
            in fluid : HydraulicFluid;
        }
        port positionOutPort {
            out position : HeightValue;
        }
    }

    part def TiltActuator {
        port commandInPort {
            in command : ActuatorCommand;
        }
        port fluidInPort {
            in fluid : HydraulicFluid;
        }
        port positionOutPort {
            out position : TiltAngle;
        }
    }

    part def TableSurface {
        port heightPositionInPort {
            in heightPosition : HeightValue;
        }
        port longitudinalTiltInPort {
            in longitudinalTilt : TiltAngle;
        }
        port lateralTiltInPort {
            in lateralTilt : TiltAngle;
        }
        port trendelenburgTiltInPort {
            in trendelenburgTilt : TiltAngle;
        }
        port positionFeedbackOutPort {
            out positionFeedback : CurrentPosition;
        }
    }

    part def LockingMechanism {
        port lockCommandInPort {
            in lockCommand : LockCommand;
        }

        exhibit state lockState {
            entry; then unlocked;

            state unlocked;
            accept LockCommand
                then locked;

            state locked;
            accept LockCommand
                then unlocked;
        }
    }

    part def OperatingTable {
        part controlPanel : ControlPanel;
        part positionController : PositionController;
        part safetyMonitor : SafetyMonitor;
        part hydraulicPump : HydraulicPump;
        part heightActuator : HeightActuator;
        part longitudinalTiltActuator : TiltActuator;
        part lateralTiltActuator : TiltActuator;
        part trendelenburgTiltActuator : TiltActuator;
        part tableSurface : TableSurface;
        part lockingMechanism : LockingMechanism;

        interface panelToControllerInterface connect controlPanel.desiredPositionOutPort to positionController.desiredPositionInPort {
            flow desiredPositionFlow of DesiredPosition
                from controlPanel.desiredPositionOutPort.desiredPosition to positionController.desiredPositionInPort.desiredPosition;
        }

        interface panelToSafetyEStopInterface connect controlPanel.emergencyStopOutPort to safetyMonitor.emergencyStopInPort {
            flow emergencyStopFlow of EmergencyStopSignal
                from controlPanel.emergencyStopOutPort.emergencyStopSignal to safetyMonitor.emergencyStopInPort.emergencyStopSignal;
        }

        interface panelToControllerEStopInterface connect controlPanel.emergencyStopOutPort to positionController.emergencyStopInPort {
            flow eStopToControllerFlow of EmergencyStopSignal
                from controlPanel.emergencyStopOutPort.emergencyStopSignal to positionController.emergencyStopInPort.emergencyStopSignal;
        }

        interface panelToSafetyResetInterface connect controlPanel.resetOutPort to safetyMonitor.resetInPort {
            flow resetFlow of ResetSignal
                from controlPanel.resetOutPort.resetSignal to safetyMonitor.resetInPort.resetSignal;
        }

        interface panelToControllerResetInterface connect controlPanel.resetOutPort to positionController.resetInPort {
            flow controllerResetFlow of ResetSignal
                from controlPanel.resetOutPort.resetSignal to positionController.resetInPort.resetSignal;
        }

        interface surfaceToControllerInterface connect tableSurface.positionFeedbackOutPort to positionController.currentPositionInPort {
            flow currentPositionFlow of CurrentPosition
                from tableSurface.positionFeedbackOutPort.positionFeedback to positionController.currentPositionInPort.currentPosition;
        }

        interface surfaceToSafetyInterface connect tableSurface.positionFeedbackOutPort to safetyMonitor.positionInPort {
            flow safetyPositionFlow of CurrentPosition
                from tableSurface.positionFeedbackOutPort.positionFeedback to safetyMonitor.positionInPort.position;
        }

        interface safetyToControllerInterface connect safetyMonitor.alertOutPort to positionController.safetyAlertInPort {
            flow safetyAlertFlow of SafetyAlertSignal
                from safetyMonitor.alertOutPort.alert to positionController.safetyAlertInPort.safetyAlert;
        }

        interface controllerToHeightInterface connect positionController.heightCommandOutPort to heightActuator.commandInPort {
            flow heightCommandFlow of ActuatorCommand
                from positionController.heightCommandOutPort.heightCommand to heightActuator.commandInPort.command;
        }

        interface controllerToLongTiltInterface connect positionController.longitudinalTiltCommandOutPort to longitudinalTiltActuator.commandInPort {
            flow longTiltCommandFlow of ActuatorCommand
                from positionController.longitudinalTiltCommandOutPort.longitudinalTiltCommand to longitudinalTiltActuator.commandInPort.command;
        }

        interface controllerToLatTiltInterface connect positionController.lateralTiltCommandOutPort to lateralTiltActuator.commandInPort {
            flow latTiltCommandFlow of ActuatorCommand
                from positionController.lateralTiltCommandOutPort.lateralTiltCommand to lateralTiltActuator.commandInPort.command;
        }

        interface controllerToTrendTiltInterface connect positionController.trendelenburgTiltCommandOutPort to trendelenburgTiltActuator.commandInPort {
            flow trendTiltCommandFlow of ActuatorCommand
                from positionController.trendelenburgTiltCommandOutPort.trendelenburgTiltCommand to trendelenburgTiltActuator.commandInPort.command;
        }

        interface controllerToLockInterface connect positionController.lockCommandOutPort to lockingMechanism.lockCommandInPort {
            flow lockCommandFlow of LockCommand
                from positionController.lockCommandOutPort.lockCommand to lockingMechanism.lockCommandInPort.lockCommand;
        }

        flow heightFluidFlow of HydraulicFluid
            from hydraulicPump.fluidOutPort.fluid to heightActuator.fluidInPort.fluid;
        flow longitudinalFluidFlow of HydraulicFluid
            from hydraulicPump.fluidOutPort.fluid to longitudinalTiltActuator.fluidInPort.fluid;
        flow lateralFluidFlow of HydraulicFluid
            from hydraulicPump.fluidOutPort.fluid to lateralTiltActuator.fluidInPort.fluid;
        flow trendelenburgFluidFlow of HydraulicFluid
            from hydraulicPump.fluidOutPort.fluid to trendelenburgTiltActuator.fluidInPort.fluid;

        flow heightPositionFlow of HeightValue
            from heightActuator.positionOutPort.position to tableSurface.heightPositionInPort.heightPosition;
        flow longitudinalTiltPositionFlow of TiltAngle
            from longitudinalTiltActuator.positionOutPort.position to tableSurface.longitudinalTiltInPort.longitudinalTilt;
        flow lateralTiltPositionFlow of TiltAngle
            from lateralTiltActuator.positionOutPort.position to tableSurface.lateralTiltInPort.lateralTilt;
        flow trendelenburgTiltPositionFlow of TiltAngle
            from trendelenburgTiltActuator.positionOutPort.position to tableSurface.trendelenburgTiltInPort.trendelenburgTilt;

        requirement patientSafetyRequirement {
            doc /* The system shall monitor patient weight and table position to prevent unsafe conditions. */
            attribute maxWeight : PatientWeight = 250;
            attribute maxHeight : HeightValue = 1.2;
            attribute maxTilt : TiltAngle = 30;
        }

        requirement emergencyStopRequirement {
            doc /* The system shall immediately halt all movement when an unsafe condition is detected or emergency stop is triggered. */
            attribute maxResponseTime : Real = 0.5;
        }

        requirement lockingRequirement {
            doc /* The locking mechanism shall automatically engage when positioning is complete or during an emergency. */
        }

        requirement positioningAccuracyRequirement {
            doc /* The table shall achieve positioning accuracy within specified tolerances for height and all tilt axes. */
            attribute heightTolerance : HeightValue = 0.001;
            attribute tiltTolerance : TiltAngle = 0.5;
        }
    }
}
