package OperatingTableSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type HeightUnit = Real {unit "mm"} default 0;
    value type AngleUnit = Real {unit "deg"} default 0;
    value type PressureUnit = Real {unit "bar"} default 0;
    value type WeightUnit = Real {unit "kg"} default 0;
    value type VoltageUnit = Real {unit "V"} default 0;
    value type CurrentUnit = Real {unit "A"} default 0;
    value type FlowRateUnit = Real {unit "L/min"} default 0;
    value type SpeedUnit = Real {unit "mm/s"} default 0;

    // ===== Item Types =====
    item def ElectricalPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def HydraulicFluid {
        attribute pressure : PressureUnit;
        attribute flowRate : FlowRateUnit;
    }

    item def PositionCommand {
        attribute targetHeight : HeightUnit;
        attribute targetLongitudinalTilt : AngleUnit;
        attribute targetLateralTilt : AngleUnit;
        attribute targetTrendelenburg : AngleUnit;
    }

    item def PositionFeedback {
        attribute currentHeight : HeightUnit;
        attribute currentLongitudinalTilt : AngleUnit;
        attribute currentLateralTilt : AngleUnit;
        attribute currentTrendelenburg : AngleUnit;
    }

    item def ActuatorCommand {
        attribute targetPosition : Real;
        attribute enable : Boolean;
    }

    item def SafetyStatus {
        attribute overload : Boolean;
        attribute heightLimitExceeded : Boolean;
        attribute tiltLimitExceeded : Boolean;
        attribute emergencyStop : Boolean;
        attribute safe : Boolean;
    }

    item def LockCommand {
        attribute engage : Boolean;
    }

    item def WeightReading {
        attribute weight : WeightUnit;
    }

    // ===== Port Definitions =====
    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }

    port def HydraulicFluidPort {
        out item fluid : HydraulicFluid;
    }

    port def HydraulicFluidInPort {
        in item fluid : HydraulicFluid;
    }

    port def CommandInputPort {
        in item command : PositionCommand;
    }

    port def FeedbackPort {
        out item feedback : PositionFeedback;
    }

    port def FeedbackInPort {
        in item feedback : PositionFeedback;
    }

    port def ActuatorCommandPort {
        out item command : ActuatorCommand;
    }

    port def ActuatorCommandInPort {
        in item command : ActuatorCommand;
    }

    port def SafetyStatusPort {
        out item status : SafetyStatus;
    }

    port def SafetyStatusInPort {
        in item status : SafetyStatus;
    }

    port def LockCommandPort {
        out item command : LockCommand;
    }

    port def LockCommandInPort {
        in item command : LockCommand;
    }

    port def WeightPort {
        out item reading : WeightReading;
    }

    port def WeightInPort {
        in item reading : WeightReading;
    }

    // ===== Requirements =====
    requirement def PositioningRequirement {
        attribute maxHeight : HeightUnit = 1000;
        attribute minHeight : HeightUnit = 500;
        attribute maxLongitudinalTilt : AngleUnit = 30;
        attribute maxLateralTilt : AngleUnit = 20;
        attribute maxTrendelenburg : AngleUnit = 30;
        requirement {
            doc "The table shall position the patient within specified height and tilt ranges."
        }
    }

    requirement def SafetyRequirement {
        attribute maxPatientWeight : WeightUnit = 250;
        attribute emergencyResponseTime : Real = 0.1 {unit "s"};
        requirement {
            doc "The system shall halt all movement within 0.1 seconds when an unsafe condition is detected."
        }
    }

    requirement def LockingRequirement {
        requirement {
            doc "The locking mechanism shall engage automatically when positioning is complete or during emergency."
        }
    }

    requirement def HydraulicPowerRequirement {
        attribute operatingPressure : PressureUnit = 200;
        attribute maxFlowRate : FlowRateUnit = 10;
        requirement {
            doc "The hydraulic pump shall supply fluid at 200 bar and up to 10 L/min."
        }
    }

    // ===== Part Definitions =====
    part def TableSurface {
        attribute currentHeight : HeightUnit;
        attribute currentLongitudinalTilt : AngleUnit;
        attribute currentLateralTilt : AngleUnit;
        attribute currentTrendelenburg : AngleUnit;

        port feedbackOut : FeedbackPort;
        port heightActuatorIn : ActuatorCommandInPort;
        port longitudinalActuatorIn : ActuatorCommandInPort;
        port lateralActuatorIn : ActuatorCommandInPort;
        port trendelenburgActuatorIn : ActuatorCommandInPort;
        port lockIn : LockCommandInPort;
        port weightOut : WeightPort;

        attribute locked : Boolean;

        state tableSurfaceBehavior {
            entry { locked = false; }

            state Unlocked;
            state Locked;

            transition Unlocked to Locked
                when lockIn.command.engage == true
                { locked = true; }

            transition Locked to Unlocked
                when lockIn.command.engage == false
                { locked = false; }

            do action updatePosition {
                if (heightActuatorIn.command.enable) {
                    currentHeight := currentHeight + heightActuatorIn.command.targetPosition * 0.01;
                }
                if (longitudinalActuatorIn.command.enable) {
                    currentLongitudinalTilt := currentLongitudinalTilt + longitudinalActuatorIn.command.targetPosition * 0.01;
                }
                if (lateralActuatorIn.command.enable) {
                    currentLateralTilt := currentLateralTilt + lateralActuatorIn.command.targetPosition * 0.01;
                }
                if (trendelenburgActuatorIn.command.enable) {
                    currentTrendelenburg := currentTrendelenburg + trendelenburgActuatorIn.command.targetPosition * 0.01;
                }
                feedbackOut.feedback.currentHeight := currentHeight;
                feedbackOut.feedback.currentLongitudinalTilt := currentLongitudinalTilt;
                feedbackOut.feedback.currentLateralTilt := currentLateralTilt;
                feedbackOut.feedback.currentTrendelenburg := currentTrendelenburg;
            }
        }
    }

    part def HydraulicPump {
        port powerIn : ElectricalPowerPort;
        port fluidOut : HydraulicFluidPort;

        attribute outputPressure : PressureUnit;
        attribute outputFlowRate : FlowRateUnit;
        attribute active : Boolean;

        state pumpOperation {
            state Off;
            state On;

            transition Off to On
                when powerIn.power.voltage > 0
                { active = true; outputPressure = 200; outputFlowRate = 10; }

            transition On to Off
                when powerIn.power.voltage == 0
                { active = false; outputPressure = 0; outputFlowRate = 0; }

            do action generateFluid {
                if (active) {
                    fluidOut.fluid.pressure := outputPressure;
                    fluidOut.fluid.flowRate := outputFlowRate;
                } else {
                    fluidOut.fluid.pressure := 0;
                    fluidOut.fluid.flowRate := 0;
                }
            }
        }
    }

    part def HeightActuator {
        port fluidIn : HydraulicFluidInPort;
        port commandIn : ActuatorCommandInPort;
        port mechanicalOut : ~ActuatorCommandPort;

        attribute position : HeightUnit;
        attribute speed : SpeedUnit;
        attribute enabled : Boolean;

        do action actuate {
            enabled := commandIn.command.enable;
            if (enabled && fluidIn.fluid.pressure > 0) {
                speed := fluidIn.fluid.flowRate * 10.0;
                position := position + commandIn.command.targetPosition * 0.01;
                mechanicalOut.command.targetPosition := commandIn.command.targetPosition;
                mechanicalOut.command.enable := true;
            } else {
                speed := 0;
                mechanicalOut.command.enable := false;
            }
        }
    }

    part def TiltActuator {
        port fluidIn : HydraulicFluidInPort;
        port commandIn : ActuatorCommandInPort;
        port mechanicalOut : ~ActuatorCommandPort;

        attribute angle : AngleUnit;
        attribute enabled : Boolean;
        attribute axisName : String;

        do action actuate {
            enabled := commandIn.command.enable;
            if (enabled && fluidIn.fluid.pressure > 0) {
                angle := angle + commandIn.command.targetPosition * 0.01;
                mechanicalOut.command.targetPosition := commandIn.command.targetPosition;
                mechanicalOut.command.enable := true;
            } else {
                mechanicalOut.command.enable := false;
            }
        }
    }

    part def ControlPanel {
        port commandOut : ~CommandInputPort;

        attribute desiredHeight : HeightUnit;
        attribute desiredLongitudinalTilt : AngleUnit;
        attribute desiredLateralTilt : AngleUnit;
        attribute desiredTrendelenburg : AngleUnit;
        attribute emergencyStopPressed : Boolean;

        do action acceptInput {
            commandOut.command.targetHeight := desiredHeight;
            commandOut.command.targetLongitudinalTilt := desiredLongitudinalTilt;
            commandOut.command.targetLateralTilt := desiredLateralTilt;
            commandOut.command.targetTrendelenburg := desiredTrendelenburg;
        }
    }

    part def PositionController {
        port commandIn : CommandInputPort;
        port feedbackIn : FeedbackInPort;
        port safetyIn : SafetyStatusInPort;
        port heightCmdOut : ~ActuatorCommandPort;
        port longitudinalCmdOut : ~ActuatorCommandPort;
        port lateralCmdOut : ~ActuatorCommandPort;
        port trendelenburgCmdOut : ~ActuatorCommandPort;
        port lockCmdOut : ~LockCommandPort;

        attribute heightError : HeightUnit;
        attribute longitudinalError : AngleUnit;
        attribute lateralError : AngleUnit;
        attribute trendelenburgError : AngleUnit;
        attribute positioningComplete : Boolean;
        attribute tolerance : Real = 1.0;

        state controllerBehavior {
            state Idle;
            state Positioning;
            state Complete;
            state EmergencyHalt;

            transition Idle to Positioning
                when commandIn.command.targetHeight != feedbackIn.feedback.currentHeight
                    or commandIn.command.targetLongitudinalTilt != feedbackIn.feedback.currentLongitudinalTilt
                    or commandIn.command.targetLateralTilt != feedbackIn.feedback.currentLateralTilt
                    or commandIn.command.targetTrendelenburg != feedbackIn.feedback.currentTrendelenburg
                { positioningComplete = false; }

            transition Positioning to EmergencyHalt
                when safetyIn.status.safe == false
                {
                    heightCmdOut.command.enable := false;
                    longitudinalCmdOut.command.enable := false;
                    lateralCmdOut.command.enable := false;
                    trendelenburgCmdOut.command.enable := false;
                    lockCmdOut.command.engage := true;
                }

            transition Positioning to Complete
                when abs(heightError) < tolerance
                    and abs(longitudinalError) < tolerance
                    and abs(lateralError) < tolerance
                    and abs(trendelenburgError) < tolerance
                {
                    positioningComplete = true;
                    heightCmdOut.command.enable := false;
                    longitudinalCmdOut.command.enable := false;
                    lateralCmdOut.command.enable := false;
                    trendelenburgCmdOut.command.enable := false;
                    lockCmdOut.command.engage := true;
                }

            transition Complete to Idle
                when true
                { }

            transition EmergencyHalt to Idle
                when safetyIn.status.safe == true
                { lockCmdOut.command.engage := false; }

            do action computeCommands {
                heightError := commandIn.command.targetHeight - feedbackIn.feedback.currentHeight;
                longitudinalError := commandIn.command.targetLongitudinalTilt - feedbackIn.feedback.currentLongitudinalTilt;
                lateralError := commandIn.command.targetLateralTilt - feedbackIn.feedback.currentLateralTilt;
                trendelenburgError := commandIn.command.targetTrendelenburg - feedbackIn.feedback.currentTrendelenburg;

                if (safetyIn.status.safe) {
                    heightCmdOut.command.targetPosition := heightError;
                    heightCmdOut.command.enable := abs(heightError) >= tolerance;
                    longitudinalCmdOut.command.targetPosition := longitudinalError;
                    longitudinalCmdOut.command.enable := abs(longitudinalError) >= tolerance;
                    lateralCmdOut.command.targetPosition := lateralError;
                    lateralCmdOut.command.enable := abs(lateralError) >= tolerance;
                    trendelenburgCmdOut.command.targetPosition := trendelenburgError;
                    trendelenburgCmdOut.command.enable := abs(trendelenburgError) >= tolerance;
                } else {
                    heightCmdOut.command.enable := false;
                    longitudinalCmdOut.command.enable := false;
                    lateralCmdOut.command.enable := false;
                    trendelenburgCmdOut.command.enable := false;
                    lockCmdOut.command.engage := true;
                }
            }
        }
    }

    part def SafetyMonitor {
        port weightIn : WeightInPort;
        port feedbackIn : FeedbackInPort;
        port statusOut : ~SafetyStatusPort;

        attribute maxWeight : WeightUnit = 250;
        attribute maxHeight : HeightUnit = 1000;
        attribute minHeight : HeightUnit = 500;
        attribute maxLongitudinalTilt : AngleUnit = 30;
        attribute maxLateralTilt : AngleUnit = 20;
        attribute maxTrendelenburg : AngleUnit = 30;
        attribute emergencyStop : Boolean;

        do action monitor {
            statusOut.status.overload := weightIn.reading.weight > maxWeight;
            statusOut.status.heightLimitExceeded := feedbackIn.feedback.currentHeight > maxHeight
                or feedbackIn.feedback.currentHeight < minHeight;
            statusOut.status.tiltLimitExceeded := abs(feedbackIn.feedback.currentLongitudinalTilt) > maxLongitudinalTilt
                or abs(feedbackIn.feedback.currentLateralTilt) > maxLateralTilt
                or abs(feedbackIn.feedback.currentTrendelenburg) > maxTrendelenburg;
            statusOut.status.emergencyStop := emergencyStop;
            statusOut.status.safe := not statusOut.status.overload
                and not statusOut.status.heightLimitExceeded
                and not statusOut.status.tiltLimitExceeded
                and not statusOut.status.emergencyStop;
        }
    }

    part def LockingMechanism {
        port lockCmdIn : LockCommandInPort;

        attribute engaged : Boolean;
        attribute lockForce : PressureUnit;

        state lockBehavior {
            state Disengaged;
            state Engaged;

            transition Disengaged to Engaged
                when lockCmdIn.command.engage == true
                { engaged = true; lockForce = 150; }

            transition Engaged to Disengaged
                when lockCmdIn.command.engage == false
                { engaged = false; lockForce = 0; }
        }
    }

    part def WeightSensor {
        port weightOut : ~WeightPort;

        attribute measuredWeight : WeightUnit;

        do action sense {
            weightOut.reading.weight := measuredWeight;
        }
    }

    part def PositionSensor {
        port feedbackOut : ~FeedbackPort;

        attribute height : HeightUnit;
        attribute longitudinalTilt : AngleUnit;
        attribute lateralTilt : AngleUnit;
        attribute trendelenburg : AngleUnit;

        do action sense {
            feedbackOut.feedback.currentHeight := height;
            feedbackOut.feedback.currentLongitudinalTilt := longitudinalTilt;
            feedbackOut.feedback.currentLateralTilt := lateralTilt;
            feedbackOut.feedback.currentTrendelenburg := trendelenburg;
        }
    }

    // ===== System Assembly =====
    part def OperatingTable {
        satisfy PositioningRequirement;
        satisfy SafetyRequirement;
        satisfy LockingRequirement;
        satisfy HydraulicPowerRequirement;

        port externalPower : ElectricalPowerPort;

        part tableSurface : TableSurface {
            port feedbackOut : FeedbackPort;
            port heightActuatorIn : ActuatorCommandInPort;
            port longitudinalActuatorIn : ActuatorCommandInPort;
            port lateralActuatorIn : ActuatorCommandInPort;
            port trendelenburgActuatorIn : ActuatorCommandInPort;
            port lockIn : LockCommandInPort;
            port weightOut : WeightPort;
        }

        part hydraulicPump : HydraulicPump {
            port powerIn : ElectricalPowerPort;
            port fluidOut : HydraulicFluidPort;
        }

        part heightActuator : HeightActuator {
            port fluidIn : HydraulicFluidInPort;
            port commandIn : ActuatorCommandInPort;
            port mechanicalOut : ~ActuatorCommandPort;
        }

        part longitudinalTiltActuator : TiltActuator {
            port fluidIn : HydraulicFluidInPort;
            port commandIn : ActuatorCommandInPort;
            port mechanicalOut : ~ActuatorCommandPort;
            attribute axisName = "longitudinal";
        }

        part lateralTiltActuator : TiltActuator {
            port fluidIn : HydraulicFluidInPort;
            port commandIn : ActuatorCommandInPort;
            port mechanicalOut : ~ActuatorCommandPort;
            attribute axisName = "lateral";
        }

        part trendelenburgActuator : TiltActuator {
            port fluidIn : HydraulicFluidInPort;
            port commandIn : ActuatorCommandInPort;
            port mechanicalOut : ~ActuatorCommandPort;
            attribute axisName = "trendelenburg";
        }

        part controlPanel : ControlPanel {
            port commandOut : ~CommandInputPort;
        }

        part positionController : PositionController {
            port commandIn : CommandInputPort;
            port feedbackIn : FeedbackInPort;
            port safetyIn : SafetyStatusInPort;
            port heightCmdOut : ~ActuatorCommandPort;
            port longitudinalCmdOut : ~ActuatorCommandPort;
            port lateralCmdOut : ~ActuatorCommandPort;
            port trendelenburgCmdOut : ~ActuatorCommandPort;
            port lockCmdOut : ~LockCommandPort;
        }

        part safetyMonitor : SafetyMonitor {
            port weightIn : WeightInPort;
            port feedbackIn : FeedbackInPort;
            port statusOut : ~SafetyStatusPort;
        }

        part lockingMechanism : LockingMechanism {
            port lockCmdIn : LockCommandInPort;
        }

        part weightSensor : WeightSensor {
            port weightOut : ~WeightPort;
        }

        part positionSensor : PositionSensor {
            port feedbackOut : ~FeedbackPort;
        }

        // ===== Connections =====
        connection externalPower to hydraulicPump.powerIn;
        connection hydraulicPump.fluidOut to heightActuator.fluidIn;
        connection hydraulicPump.fluidOut to longitudinalTiltActuator.fluidIn;
        connection hydraulicPump.fluidOut to lateralTiltActuator.fluidIn;
        connection hydraulicPump.fluidOut to trendelenburgActuator.fluidIn;

        connection controlPanel.commandOut to positionController.commandIn;
        connection positionSensor.feedbackOut to positionController.feedbackIn;
        connection positionSensor.feedbackOut to safetyMonitor.feedbackIn;
        connection safetyMonitor.statusOut to positionController.safetyIn;

        connection positionController.heightCmdOut to heightActuator.commandIn;
        connection positionController.longitudinalCmdOut to longitudinalTiltActuator.commandIn;
        connection positionController.lateralCmdOut to lateralTiltActuator.commandIn;
        connection positionController.trendelenburgCmdOut to trendelenburgActuator.commandIn;

        connection heightActuator.mechanicalOut to tableSurface.heightActuatorIn;
        connection longitudinalTiltActuator.mechanicalOut to tableSurface.longitudinalActuatorIn;
        connection lateralTiltActuator.mechanicalOut to tableSurface.lateralActuatorIn;
        connection trendelenburgActuator.mechanicalOut to tableSurface.trendelenburgActuatorIn;

        connection positionController.lockCmdOut to lockingMechanism.lockCmdIn;
        connection lockingMechanism.lockCmdIn to tableSurface.lockIn;

        connection weightSensor.weightOut to safetyMonitor.weightIn;
        connection tableSurface.weightOut to weightSensor.weightOut;
        connection tableSurface.feedbackOut to positionSensor.feedbackOut;
    }
}
