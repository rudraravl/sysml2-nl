package FollowerPlatePumpingSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Viscosity :> Real { unit 'Pa*s'; }
    value type Pressure :> Real { unit 'Pa'; }
    value type FlowRate :> Real { unit 'm^3/s'; }
    value type Velocity :> Real { unit 'm/s'; }
    value type Temperature :> Real { unit 'K'; }
    value type Volume :> Real { unit 'm^3'; }
    value type Displacement :> Real { unit 'm'; }
    value type Force :> Real { unit 'N'; }

    // ===== Item Types =====
    item def HighViscosityFluid {
        attribute viscosity : Viscosity;
        attribute temperature : Temperature;
    }

    item def Grease :> HighViscosityFluid;
    item def Sealant :> HighViscosityFluid;
    item def Adhesive :> HighViscosityFluid;

    // ===== Port Definitions =====
    port def FluidPort {
        out item fluid : HighViscosityFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def CommandPort {
        in attribute startCmd : Boolean;
        in attribute stopCmd : Boolean;
        in attribute targetFlowRate : FlowRate;
    }

    port def FeedbackPort {
        out attribute measuredPressure : Pressure;
        out attribute measuredFlowRate : FlowRate;
    }

    port def ActuatorCmdPort {
        out attribute actuatorVelocity : Velocity;
        out attribute actuatorEnable : Boolean;
    }

    port def ActuatorFbPort {
        out attribute actuatorPosition : Displacement;
        out attribute actuatorForce : Force;
    }

    // ===== Requirements =====
    requirement def DispensingAccuracy {
        attribute targetFlow : FlowRate;
        attribute tolerance : FlowRate;
        require { |measuredFlow - targetFlow| <= tolerance }
    }

    requirement def ViscosityRange {
        attribute minViscosity : Viscosity = 1.0;
        attribute maxViscosity : Viscosity = 1000.0;
        require { fluidViscosity >= minViscosity and fluidViscosity <= maxViscosity }
    }

    requirement def TemperatureRange {
        attribute minTemp : Temperature = 263.15;
        attribute maxTemp : Temperature = 333.15;
        require { fluidTemp >= minTemp and fluidTemp <= maxTemp }
    }

    requirement def PressureRegulation {
        attribute targetPressure : Pressure;
        attribute tolerance : Pressure;
        require { |measuredPressure - targetPressure| <= tolerance }
    }

    requirement def AirPocketPrevention {
        require { followerPlateSealed == true }
    }

    requirement def TwoStrokeCycle {
        require { intakeStrokeComplete and dischargeStrokeComplete }
    }

    requirement def SubsystemRequirements {
        subject subsystem : FollowerPlatePumpingSubsystem;
        require { subsystem.dispensingAccuracy.satisfied }
        require { subsystem.viscosityHandling.satisfied }
        require { subsystem.tempHandling.satisfied }
        require { subsystem.pressureReg.satisfied }
        require { subsystem.airPocketPrevention.satisfied }
        require { subsystem.cycleRequirement.satisfied }
    }

    // ===== Check Valve =====
    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute isOpen : Boolean;
        attribute crackingPressure : Pressure = 500.0;

        action def Evaluate {
            in deltaP : Pressure;
            out openState : Boolean;
            if deltaP >= crackingPressure then openState = true;
            else openState = false;
        }
    }

    // ===== Follower Plate =====
    part def FollowerPlate {
        attribute plateDiameter : Displacement = 0.1;
        attribute sealIntegrity : Boolean = true;
        attribute position : Displacement;
        attribute followerPlateSealed : Boolean = sealIntegrity;

        action def Move {
            in targetPosition : Displacement;
            in velocity : Velocity;
            then update position;
        }
    }

    // ===== Pump Cylinder =====
    part def PumpCylinder {
        port reservoirPort : FluidPort;
        port inletValvePort : FluidPort;
        port outletValvePort : FluidPort;
        attribute cylinderVolume : Volume = 0.0005;
        attribute currentVolume : Volume;
        attribute internalPressure : Pressure;
        part followerPlate : FollowerPlate;
    }

    // ===== Linear Actuator =====
    part def LinearActuator {
        port cmdPort : ActuatorCmdPort;
        port fbPort : ActuatorFbPort;
        port mechanicalPort {
            out attribute position : Displacement;
            out attribute force : Force;
        }
        attribute maxVelocity : Velocity = 0.05;
        attribute currentPosition : Displacement;
        attribute currentVelocity : Velocity;
        attribute enabled : Boolean;

        action def Drive {
            in velocityCmd : Velocity;
            in enable : Boolean;
            if enable then currentVelocity = velocityCmd;
            else currentVelocity = 0.0;
            then update currentPosition;
        }
    }

    // ===== Pressure Sensor =====
    part def PressureSensor {
        port fluidPort : FluidPort;
        port feedbackPort : FeedbackPort;
        attribute measuredPressure : Pressure;

        action def Sample {
            in pressureInput : Pressure;
            out pressureOutput : Pressure;
            pressureOutput = pressureInput;
        }
    }

    // ===== Flow Sensor =====
    part def FlowSensor {
        port fluidPort : FluidPort;
        port feedbackPort : FeedbackPort;
        attribute measuredFlowRate : FlowRate;

        action def Sample {
            in flowInput : FlowRate;
            out flowOutput : FlowRate;
            flowOutput = flowInput;
        }
    }

    // ===== Discharge Manifold =====
    part def DischargeManifold {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        port pressureTap : FluidPort;
        port flowTap : FluidPort;
        attribute manifoldPressure : Pressure;
        attribute manifoldFlowRate : FlowRate;
    }

    // ===== Bulk Reservoir =====
    part def BulkReservoir {
        port outletPort : FluidPort;
        attribute fluidLevel : Displacement;
        attribute reservoirVolume : Volume = 0.02;
        attribute fluidViscosity : Viscosity;
        attribute fluidTemp : Temperature;
        item contents : HighViscosityFluid;
    }

    // ===== Pump Controller =====
    part def PumpController {
        port commandPort : CommandPort;
        port feedbackPort : FeedbackPort;
        port actuatorCmdPort : ActuatorCmdPort;
        attribute targetFlowRate : FlowRate;
        attribute targetPressure : Pressure = 2.0e5;
        attribute measuredFlow : FlowRate;
        attribute measuredPressure : Pressure;
        attribute kp : Real = 0.8;
        attribute ki : Real = 0.2;
        attribute integralError : Real = 0.0;
        attribute computedVelocity : Velocity;

        state machine ControllerStateMachine {
            entry;
            then Idle;

            state Idle;
            transition Idle_to_Priming
                first Idle
                accept StartCommand
                then Priming;

            state Priming;
            transition Priming_to_Active
                first Priming
                accept PrimingComplete
                then ActivePumping;
            transition Priming_to_Fault
                first Priming
                accept FaultDetected
                then Fault;

            state ActivePumping;
            transition Active_to_Idle
                first ActivePumping
                accept StopCommand
                then Idle;
            transition Active_to_Fault
                first ActivePumping
                accept FaultDetected
                then Fault;

            state Fault;
            transition Fault_to_Idle
                first Fault
                accept ResetCommand
                then Idle;
        }

        action def Regulate {
            in targetFlow : FlowRate;
            in measuredFlowInput : FlowRate;
            in measuredPressureInput : Pressure;
            out velocityCmd : Velocity;
            attribute error : Real;
            error = targetFlow - measuredFlowInput;
            integralError = integralError + error;
            velocityCmd = kp * error + ki * integralError;
            if velocityCmd > maxActuatorVelocity then velocityCmd = maxActuatorVelocity;
            if velocityCmd < 0.0 then velocityCmd = 0.0;
        }

        attribute maxActuatorVelocity : Velocity = 0.05;
    }

    // ===== Positive Displacement Pump =====
    part def PositiveDisplacementPump {
        port reservoirPort : FluidPort;
        port dischargePort : FluidPort;
        port actuatorCmdPort : ActuatorCmdPort;
        port actuatorFbPort : ActuatorFbPort;

        part cylinder : PumpCylinder;
        part followerPlate : FollowerPlate;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        part actuator : LinearActuator;

        attribute intakeStrokeComplete : Boolean = false;
        attribute dischargeStrokeComplete : Boolean = false;
        attribute cycleCount : Integer = 0;

        action def IntakeStroke {
            in actuatorVelocity : Velocity;
            attribute deltaP : Pressure;
            // Actuator retracts follower plate creating vacuum
            followerPlate.position = followerPlate.position - actuatorVelocity * 0.1;
            deltaP = cylinder.internalPressure - reservoirPort.pressure;
            inletValve.isOpen = true;
            outletValve.isOpen = false;
            cylinder.currentVolume = cylinder.currentVolume + (actuatorVelocity * 0.1 * 3.14159 * (followerPlate.plateDiameter/2)^2);
            intakeStrokeComplete = true;
            dischargeStrokeComplete = false;
        }

        action def DischargeStroke {
            in actuatorVelocity : Velocity;
            attribute deltaP : Pressure;
            // Actuator pushes plate forward, pressurizing fluid
            followerPlate.position = followerPlate.position + actuatorVelocity * 0.1;
            deltaP = cylinder.internalPressure - dischargePort.pressure;
            inletValve.isOpen = false;
            outletValve.isOpen = true;
            cylinder.currentVolume = cylinder.currentVolume - (actuatorVelocity * 0.1 * 3.14159 * (followerPlate.plateDiameter/2)^2);
            dischargeStrokeComplete = true;
            intakeStrokeComplete = false;
            cycleCount = cycleCount + 1;
        }

        action def PumpCycle {
            then IntakeStroke;
            then DischargeStroke;
        }
    }

    // ===== Follower Plate Pumping Subsystem =====
    part def FollowerPlatePumpingSubsystem {
        port commandPort : CommandPort;
        port dischargePort : FluidPort;
        port reservoirPort : FluidPort;

        part reservoir : BulkReservoir;
        part pump : PositiveDisplacementPump;
        part manifold : DischargeManifold;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : PumpController;

        // Requirements satisfaction
        satisfy dispensingAccuracy : DispensingAccuracy {
            attribute targetFlow : FlowRate = 1.0e-5;
            attribute tolerance : FlowRate = 1.0e-6;
        }
        satisfy viscosityHandling : ViscosityRange;
        satisfy tempHandling : TemperatureRange;
        satisfy pressureReg : PressureRegulation {
            attribute targetPressure : Pressure = 2.0e5;
            attribute tolerance : Pressure = 1.0e4;
        }
        satisfy airPocketPrevention : AirPocketPrevention;
        satisfy cycleRequirement : TwoStrokeCycle;

        attribute fluidViscosity : Viscosity;
        attribute fluidTemp : Temperature;
        attribute measuredFlow : FlowRate;
        attribute measuredPressure : Pressure;

        // Connections
        connection reservoirToPump connect reservoir.outletPort to pump.reservoirPort;
        connection pumpToManifold connect pump.dischargePort to manifold.inletPort;
        connection manifoldToDischarge connect manifold.outletPort to dischargePort;
        connection manifoldPressureTap connect manifold.pressureTap to pressureSensor.fluidPort;
        connection manifoldFlowTap connect manifold.flowTap to flowSensor.fluidPort;
        connection pressureFeedback connect pressureSensor.feedbackPort to controller.feedbackPort;
        connection flowFeedback connect flowSensor.feedbackPort to controller.feedbackPort;
        connection controllerToPumpCmd connect controller.actuatorCmdPort to pump.actuatorCmdPort;
        connection pumpFbToController connect pump.actuatorFbPort to controller.actuatorFbPort;
        connection commandConnect connect commandPort to controller.commandPort;

        // Flow of items
        flow fluidFlow : HighViscosityFluid from reservoir.outletPort to pump.reservoirPort;
        flow pressurizedFluid : HighViscosityFluid from pump.dischargePort to manifold.inletPort;
        flow outputFluid : HighViscosityFluid from manifold.outletPort to dischargePort;

        action def Initialize {
            attribute fluidViscosityInput : Viscosity;
            attribute fluidTempInput : Temperature;
            fluidViscosity = fluidViscosityInput;
            fluidTemp = fluidTempInput;
            controller.targetFlowRate = 1.0e-5;
        }

        action def Operate {
            then controller.Regulate;
            then pump.PumpCycle;
        }

        state machine SubsystemStateMachine {
            entry;
            then Idle;

            state Idle {
                entry { controller.ControllerStateMachine.current = Idle; }
            }

            transition Idle_to_Priming
                first Idle
                accept StartCommand
                then Priming;

            state Priming {
                entry { controller.ControllerStateMachine.current = Priming; }
            }

            transition Priming_to_Active
                first Priming
                accept PrimingComplete
                then ActivePumping;

            transition Priming_to_Fault
                first Priming
                accept FaultDetected
                then Fault;

            state ActivePumping {
                entry { controller.ControllerStateMachine.current = ActivePumping; }
                do Operate;
            }

            transition Active_to_Idle
                first ActivePumping
                accept StopCommand
                then Idle;

            transition Active_to_Fault
                first ActivePumping
                accept FaultDetected
                then Fault;

            state Fault {
                entry { controller.ControllerStateMachine.current = Fault; }
            }

            transition Fault_to_Idle
                first Fault
                accept ResetCommand
                then Idle;
        }
    }

    // ===== Instantiated System =====
    part pumpingSystem : FollowerPlatePumpingSubsystem {
        part reservoirInstance : BulkReservoir {
            attribute fluidViscosity : Viscosity = 50.0;
            attribute fluidTemp : Temperature = 293.15;
            item greaseSupply : Grease {
                attribute viscosity : Viscosity = 50.0;
                attribute temperature : Temperature = 293.15;
            }
        }

        part pumpInstance : PositiveDisplacementPump {
            part cylinderInstance : PumpCylinder {
                attribute cylinderVolume : Volume = 0.0005;
            }
            part followerPlateInstance : FollowerPlate {
                attribute plateDiameter : Displacement = 0.1;
                attribute sealIntegrity : Boolean = true;
            }
            part inletValveInstance : CheckValve {
                attribute crackingPressure : Pressure = 500.0;
            }
            part outletValveInstance : CheckValve {
                attribute crackingPressure : Pressure = 500.0;
            }
            part actuatorInstance : LinearActuator {
                attribute maxVelocity : Velocity = 0.05;
            }
        }

        part manifoldInstance : DischargeManifold;
        part pressureSensorInstance : PressureSensor;
        part flowSensorInstance : FlowSensor;
        part controllerInstance : PumpController {
            attribute targetFlowRate : FlowRate = 1.0e-5;
            attribute targetPressure : Pressure = 2.0e5;
        }
    }
}
