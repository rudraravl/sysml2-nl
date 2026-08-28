package PowertrainSystem {

    import ScalarValues::*;
    import SI::*;

    // ============== Value Types ==============

    attribute def Torque :> Real {
        doc { Rotational torque in Newton-meters }
        :>> unit = N * m;
    }

    attribute def AngularSpeed :> Real {
        doc { Rotational speed in radians per second }
        :>> unit = rad / s;
    }

    attribute def Power :> Real {
        doc { Mechanical power in Watts }
        :>> unit = W;
    }

    attribute def Efficiency :> Real {
        doc { Dimensionless efficiency, range 0.0 to 1.0 }
    }

    attribute def GearRatio :> Real {
        doc { Dimensionless gear ratio }
    }

    attribute def ThrottleSetting :> Real {
        doc { Throttle position, range 0.0 to 1.0 }
    }

    attribute def LoadInertia :> Real {
        doc { Moment of inertia in kilogram-square meters }
        :>> unit = kg * m * m;
    }

    attribute def DampingCoeff :> Real {
        doc { Rotational damping coefficient in N.m per rad/s }
    }

    // ============== Item Definitions ==============

    item def RotationalPowerFlow {
        attribute torque : Torque;
        attribute angularSpeed : AngularSpeed;
        attribute power : Power;
    }

    item def ThrottleCommand {
        attribute setting : ThrottleSetting;
    }

    item def SpeedMeasurement {
        attribute measuredSpeed : AngularSpeed;
        attribute targetSpeed : AngularSpeed;
        attribute speedError : AngularSpeed;
    }

    // ============== Port Definitions ==============

    port def PowerFlowPort {
        flow torque : Torque;
        flow angularSpeed : AngularSpeed;
        flow power : Power;
    }

    port def ThrottleControlPort {
        flow setting : ThrottleSetting;
    }

    port def SpeedFeedbackPort {
        flow measuredSpeed : AngularSpeed;
    }

    // ============== Connection Definitions ==============

    connection def PowerLink {
        end source : PowerFlowPort;
        end sink : PowerFlowPort;
    }

    connection def ThrottleLink {
        end source : ThrottleControlPort;
        end sink : ThrottleControlPort;
    }

    connection def FeedbackLink {
        end source : SpeedFeedbackPort;
        end sink : SpeedFeedbackPort;
    }

    // ============== Prime Mover ==============

    part def PrimeMover {
        doc { Central power source generating high-speed rotational power }

        port in throttleInput : ThrottleControlPort;
        port out powerOutput : PowerFlowPort;

        attribute ratedPower : Power = 15000 [W];
        attribute ratedSpeed : AngularSpeed = 314 [rad/s];
        attribute idleSpeed : AngularSpeed = 52 [rad/s];
        attribute maxTorque : Torque = 48 [N * m];

        attribute currentThrottle : ThrottleSetting = 0.0;
        attribute currentSpeed : AngularSpeed = 0 [rad/s];
        attribute currentTorque : Torque = 0 [N * m];
        attribute currentPower : Power = 0 [W];
        attribute running : Boolean = false;

        action def generatePower {
            in throttle : ThrottleSetting;
            out speed : AngularSpeed;
            out torque : Torque;
            out power : Power;
        }

        assert constraint powerConservation {
            currentPower == currentTorque * currentSpeed
        }

        assert constraint torqueSpeedLimit {
            currentSpeed <= ratedSpeed and currentTorque <= maxTorque
        }
    }

    // ============== Transmission System ==============

    part def TransmissionSystem {
        doc { Gear reduction system with 4:1 ratio and over 90 percent efficiency }

        port in inputPort : PowerFlowPort;
        port out outputPort : PowerFlowPort;

        attribute gearRatio : GearRatio = 4.0;
        attribute efficiency : Efficiency = 0.92;
        attribute maxInputTorque : Torque = 48 [N * m];
        attribute maxInputSpeed : AngularSpeed = 314 [rad/s];
        attribute maxOutputTorque : Torque = 176 [N * m];
        attribute maxOutputSpeed : AngularSpeed = 78.5 [rad/s];

        attribute inputTorque : Torque = 0 [N * m];
        attribute inputSpeed : AngularSpeed = 0 [rad/s];
        attribute inputPower : Power = 0 [W];
        attribute outputTorque : Torque = 0 [N * m];
        attribute outputSpeed : AngularSpeed = 0 [rad/s];
        attribute outputPower : Power = 0 [W];

        part inputShaft {
            attribute maxTorque : Torque = 50 [N * m];
            attribute maxSpeed : AngularSpeed = 314 [rad/s];
            attribute material : String = "Hardened Steel";
            attribute diameter : Real = 0.020;
        }

        part outputShaft {
            attribute maxTorque : Torque = 200 [N * m];
            attribute maxSpeed : AngularSpeed = 80 [rad/s];
            attribute material : String = "Hardened Steel";
            attribute diameter : Real = 0.035;
        }

        part gearset {
            attribute inputGearTeeth : Integer = 20;
            attribute outputGearTeeth : Integer = 80;
            attribute moduleValue : Real = 0.004;
            attribute material : String = "Hardened Steel";
            attribute pressureAngle : Real = 20.0;

            assert constraint gearRatioConstraint {
                (outputGearTeeth / inputGearTeeth) == 4.0
            }
        }

        part bearings {
            attribute type : String = "Deep Groove Ball Bearings";
            attribute ratedLoad : Real = 5000;
            attribute quantity : Integer = 4;
        }

        part housing {
            attribute material : String = "Cast Iron";
            attribute sealing : String = "Lip Seal";
        }

        action def transmitPower {
            in inTorque : Torque;
            in inSpeed : AngularSpeed;
            in inPower : Power;
            out outTorque : Torque;
            out outSpeed : AngularSpeed;
            out outPower : Power;
        }

        assert constraint speedReduction {
            outputSpeed == inputSpeed / gearRatio
        }

        assert constraint torqueMultiplication {
            outputTorque == inputTorque * gearRatio * efficiency
        }

        assert constraint powerTransfer {
            outputPower == inputPower * efficiency
        }

        assert constraint efficiencyRequirement {
            efficiency > 0.90
        }

        assert constraint inputLimit {
            inputTorque <= maxInputTorque and inputSpeed <= maxInputSpeed
        }
    }

    // ============== Load Mechanism ==============

    part def LoadMechanism {
        doc { Mechanical load driven by the powertrain }

        port in powerInput : PowerFlowPort;
        port out speedOutput : SpeedFeedbackPort;

        attribute ratedSpeed : AngularSpeed = 78.5 [rad/s];
        attribute inertia : LoadInertia = 2.5;
        attribute loadDamping : DampingCoeff = 0.15;
        attribute nominalLoadTorque : Torque = 150 [N * m];
        attribute maxLoadTorque : Torque = 180 [N * m];

        attribute currentSpeed : AngularSpeed = 0 [rad/s];
        attribute currentTorque : Torque = 0 [N * m];
        attribute loadChanged : Boolean = false;

        action def applyLoad {
            in appliedTorque : Torque;
            in appliedSpeed : AngularSpeed;
            out loadSpeed : AngularSpeed;
            out loadTorque : Torque;
        }

        assert constraint loadDynamics {
            currentSpeed >= 0 and currentTorque <= maxLoadTorque
        }
    }

    // ============== Control System ==============

    part def ControlSystem {
        doc { Brain of the operation - monitors speed and adjusts throttle via feedback }

        port in speedFeedback : SpeedFeedbackPort;
        port out throttleOutput : ThrottleControlPort;

        attribute targetSpeed : AngularSpeed = 78.5 [rad/s];
        attribute measuredSpeed : AngularSpeed = 0 [rad/s];
        attribute speedError : AngularSpeed = 0 [rad/s];
        attribute throttleCommand : ThrottleSetting = 0.0;

        attribute proportionalGain : Real = 0.01;
        attribute integralGain : Real = 0.0005;
        attribute derivativeGain : Real = 0.05;
        attribute integralError : Real = 0.0;
        attribute previousError : AngularSpeed = 0 [rad/s];

        attribute speedTolerance : AngularSpeed = 2.0 [rad/s];
        attribute maxThrottle : ThrottleSetting = 1.0;
        attribute minThrottle : ThrottleSetting = 0.0;
        attribute regulating : Boolean = false;
        attribute alarmState : Boolean = false;

        action def computeThrottle {
            in measured : AngularSpeed;
            in target : AngularSpeed;
            out throttle : ThrottleSetting;
        }

        action def monitorSpeed {
            in measured : AngularSpeed;
            in target : AngularSpeed;
            out error : AngularSpeed;
        }

        assert constraint throttleRange {
            throttleCommand >= minThrottle and throttleCommand <= maxThrottle
        }

        assert constraint errorDefinition {
            speedError == targetSpeed - measuredSpeed
        }

        state controllerStates {
            state idle {
                entry { regulating = false; }
            }
            state regulatingState {
                entry { regulating = true; }
            }
            state alarm {
                entry { alarmState = true; }
                exit { alarmState = false; }
            }

            transition from idle to regulatingState when { measuredSpeed > 0 };
            transition from regulatingState to alarm when { speedError > 10 [rad/s] };
            transition from alarm to regulatingState when { speedError < 2 [rad/s] };
            transition from regulatingState to idle when { measuredSpeed == 0 };
        }
    }

    // ============== State Machine Definition ==============

    state def PowertrainStateMachine {
        doc { Main operational state machine for the powertrain system }

        state standby {
            doc { System idle, ready to start }
        }

        state startup {
            doc { Startup sequence - ramping up to operational speed }
        }

        state operational {
            doc { Fully operational state }

            state steadyState {
                doc { Steady-state operation - load at target speed }
            }

            state transient {
                doc { Transient operation - load changing, controller adjusting }
            }

            transition from steadyState to transient when { speedError > speedTolerance };
            transition from transient to steadyState when { speedError <= speedTolerance };
        }

        state shutdown {
            doc { Shutdown procedure - ramping down to stop }
        }

        transition from standby to startup when { startRequested };
        transition from startup to operational when { loadSpeed > 0 };
        transition from operational to shutdown when { shutdownRequested };
        transition from shutdown to standby when { loadSpeed == 0 };
    }

    // ============== Top-Level Powertrain System ==============

    part def Powertrain {
        doc { Complete mechanical power transmission system delivering power from a source to a controlled mechanical load }

        attribute startRequested : Boolean = false;
        attribute shutdownRequested : Boolean = false;
        attribute loadSpeed : AngularSpeed = 0 [rad/s];
        attribute speedError : AngularSpeed = 0 [rad/s];
        attribute speedTolerance : AngularSpeed = 2.0 [rad/s];
        attribute systemTargetSpeed : AngularSpeed = 78.5 [rad/s];

        part primeMover : PrimeMover;
        part transmission : TransmissionSystem;
        part load : LoadMechanism;
        part controller : ControlSystem;

        // Power flow: Prime Mover -> Transmission -> Load
        connection : PowerLink connect primeMover.powerOutput to transmission.inputPort;
        connection : PowerLink connect transmission.outputPort to load.powerInput;

        // Control signal: Controller -> Prime Mover
        connection : ThrottleLink connect controller.throttleOutput to primeMover.throttleInput;

        // Speed feedback: Load -> Controller
        connection : FeedbackLink connect load.speedOutput to controller.speedFeedback;

        // State machine behavior
        state operationalState : PowertrainStateMachine;

        assert constraint targetSpeedConsistency {
            controller.targetSpeed == systemTargetSpeed
        }
    }

    // ============== Requirements ==============

    req def SpeedControlRequirement {
        doc { The system shall deliver power to the load at a precisely controlled target speed }
        subject p : Powertrain;
        attribute targetSpeed : AngularSpeed = 78.5 [rad/s];
        attribute tolerance : AngularSpeed = 2.0 [rad/s];
        require {
            p.load.currentSpeed >= targetSpeed - tolerance and
            p.load.currentSpeed <= targetSpeed + tolerance
        }
    }

    req def PrimeMoverPowerRequirement {
        doc { The Prime Mover shall generate high-speed rotational power as the primary power source }
        subject p : Powertrain;
        require {
            p.primeMover.ratedPower >= 10000 [W] and
            p.primeMover.ratedSpeed >= 300 [rad/s]
        }
    }

    req def TransmissionGearRatioRequirement {
        doc { The Transmission System shall have a 4:1 gear reduction ratio suitable for high-torque applications }
        subject p : Powertrain;
        attribute requiredRatio : GearRatio = 4.0;
        require {
            p.transmission.gearRatio == requiredRatio
        }
    }

    req def TransmissionEfficiencyRequirement {
        doc { The Transmission System shall operate at over 90 percent efficiency }
        subject p : Powertrain;
        attribute minEff : Efficiency = 0.90;
        require {
            p.transmission.efficiency > minEff
        }
    }

    req def TransmissionRobustnessRequirement {
        doc { The Transmission System shall be built with robust shafts and gears capable of handling significant torque loads }
        subject p : Powertrain;
        require {
            p.transmission.outputShaft.maxTorque >= 150 [N * m] and
            p.transmission.inputShaft.maxTorque >= 48 [N * m] and
            p.transmission.gearset.material == "Hardened Steel"
        }
    }

    req def ControlFeedbackRequirement {
        doc { The Control System shall constantly monitor rotational speed and adjust the Prime Mover throttle to maintain consistent load speed }
        subject p : Powertrain;
        require {
            p.controller.measuredSpeed == p.load.currentSpeed
        }
    }

    req def OperatingStatesRequirement {
        doc { The system shall operate through standby, startup, fully operational, and shutdown states }
        subject p : Powertrain;
    }

    req def SteadyStateTransientRequirement {
        doc { While running, the system shall distinguish between steady-state operation and transient periods when the load changes }
        subject p : Powertrain;
    }

    req def FeedbackLoopRequirement {
        doc { The system shall implement a feedback loop that automatically responds to changes in the load demands }
        subject p : Powertrain;
        require {
            p.controller.speedFeedback.measuredSpeed == p.load.currentSpeed
        }
    }
}
