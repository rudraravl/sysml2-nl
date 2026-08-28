package 'Follower Plate Pumping Subsystem' {
    private import ISQ::*;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    package Definitions {
        item def HighViscosityFluid {
            attribute viscosity : DynamicViscosityValue;
            attribute temperature : ThermodynamicTemperatureValue;
        }

        item def StartCommand;
        item def StopCommand;
        item def FaultSignal;
        item def ResetCommand;
        item def TargetFlowRate {
            attribute value : VolumeFlowRateValue;
        }
        item def ActuatorCommand {
            attribute velocity : SpeedValue;
        }
        item def PressureReading {
            attribute value : PressureValue;
        }
        item def FlowReading {
            attribute value : VolumeFlowRateValue;
        }

        port def FluidOutPort {
            out item fluid : HighViscosityFluid;
        }

        port def FluidInPort {
            in item fluid : HighViscosityFluid;
        }

        port def CommandInPort {
            in item start : StartCommand;
            in item stop : StopCommand;
            in item target : TargetFlowRate;
        }

        port def ActuatorCmdPort {
            out item command : ActuatorCommand;
        }

        port def PressureFeedbackPort {
            out item reading : PressureReading;
        }

        port def FlowFeedbackPort {
            out item reading : FlowReading;
        }

        part def Reservoir {
            port fluidOutPort : FluidOutPort;
            item storedFluid : HighViscosityFluid;
            attribute capacity : VolumeValue;
            attribute level : VolumeValue;
        }

        part def FollowerPlate {
            attribute position : LengthValue;
            attribute sealIntegrity : Boolean;
        }

        part def PumpCylinder {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            part followerPlate : FollowerPlate;
        }

        part def CheckValve {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            attribute crackingPressure : PressureValue;
            attribute isOpen : Boolean;
        }

        part def LinearActuator {
            port cmdPort : ~ActuatorCmdPort;
            attribute velocity : SpeedValue;
            attribute position : LengthValue;
        }

        part def PositiveDisplacementPump {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            part cylinder : PumpCylinder;
            part actuator : LinearActuator;
        }

        part def DischargeManifold {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
        }

        part def PressureSensor {
            port fluidPort : FluidInPort;
            port feedbackPort : PressureFeedbackPort;
        }

        part def FlowSensor {
            port fluidPort : FluidInPort;
            port feedbackPort : FlowFeedbackPort;
        }

        part def PumpController {
            port cmdPort : CommandInPort;
            port pressureFeedbackPort : ~PressureFeedbackPort;
            port flowFeedbackPort : ~FlowFeedbackPort;
            port actuatorCmdPort : ActuatorCmdPort;
            attribute targetFlow : VolumeFlowRateValue;
            attribute error : Real;
        }

        action def IntakeStroke {
            in fluidIn : HighViscosityFluid;
            out fluidOut : HighViscosityFluid;
        }

        action def DischargeStroke {
            in fluidIn : HighViscosityFluid;
            out fluidOut : HighViscosityFluid;
        }

        action def PumpCycle {
            in suctionFluid : HighViscosityFluid;
            out dischargeFluid : HighViscosityFluid;
            action intake : IntakeStroke {
                in fluidIn = PumpCycle::suctionFluid;
                out fluidOut;
            }
            flow from intake.fluidOut to discharge.fluidIn;
            action discharge : DischargeStroke {
                in fluidIn;
                out fluidOut = PumpCycle::dischargeFluid;
            }
        }

        action def PrimePump;
        action def MonitorAndRegulate;
        action def HandleFault;

        state def PumpControlState {
            entry; then Idle;
            state Idle;
            state Priming {
                do action PrimePump;
            }
            state ActivePumping {
                do action MonitorAndRegulate;
            }
            state Fault {
                do action HandleFault;
            }
            transition first Idle accept start : StartCommand then Priming;
            transition first Priming accept target : TargetFlowRate then ActivePumping;
            transition first ActivePumping accept stop : StopCommand then Idle;
            transition first ActivePumping accept fault : FaultSignal then Fault;
            transition first Fault accept reset : ResetCommand then Idle;
        }
    }

    public import Definitions::*;

    package Usages {
        public import Definitions::*;

        part subsystem {
            port cmdPort : CommandInPort;
            port dischargePort : FluidOutPort;

            part reservoir : Reservoir;
            part inletValve : CheckValve;
            part pump : PositiveDisplacementPump;
            part outletValve : CheckValve;
            part manifold : DischargeManifold;
            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part controller : PumpController;

            connect controller.cmdPort to cmdPort;
            connect controller.actuatorCmdPort to pump.actuator.cmdPort;
            connect pressureSensor.feedbackPort to controller.pressureFeedbackPort;
            connect flowSensor.feedbackPort to controller.flowFeedbackPort;

            flow of fluid : HighViscosityFluid
                from reservoir.fluidOutPort.fluid to inletValve.fluidInPort.fluid;
            flow of fluid : HighViscosityFluid
                from inletValve.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of fluid : HighViscosityFluid
                from pump.fluidOutPort.fluid to outletValve.fluidInPort.fluid;
            flow of fluid : HighViscosityFluid
                from outletValve.fluidOutPort.fluid to manifold.fluidInPort.fluid;
            flow of fluid : HighViscosityFluid
                from manifold.fluidOutPort.fluid to dischargePort.fluid;

            perform action pumpCycle : PumpCycle {
                in suctionFluid = pump.fluidInPort.fluid;
                out dischargeFluid = pump.fluidOutPort.fluid;
            }

            state controlState : PumpControlState;
        }
    }

    package Requirements {
        requirement def FunctionalRequirement;
        requirement def PerformanceRequirement;

        requirement 'Two-Stroke Pumping Cycle' : FunctionalRequirement {
            comment /*
                The pump shall draw fluid from the reservoir during the intake stroke
                and discharge pressurized fluid through the outlet check valve during
                the discharge stroke.
            */
        }

        requirement 'Accurate Dispensing' : PerformanceRequirement {
            comment /*
                The subsystem shall dispense high-viscosity fluid with a volumetric
                accuracy of ±1%.
            */
        }

        requirement 'Viscosity and Temperature Handling' : PerformanceRequirement {
            comment /*
                The subsystem shall handle fluids with dynamic viscosity in the range
                1000 to 1000000 cP and temperature in the range 10 to 60 degrees Celsius.
            */
        }

        requirement 'Controller State Management' : FunctionalRequirement {
            comment /*
                The pump controller shall manage idle, priming, active pumping, and fault
                states, and shall respond to start, stop, target flow rate, pressure,
                and flow sensor signals.
            */
        }

        requirement 'Follower Plate Seal Integrity' : FunctionalRequirement {
            comment /*
                The follower plate shall maintain a seal against the reservoir wall to
                prevent air pockets and ensure cavity-free fluid supply into the pump.
            */
        }
    }
}
