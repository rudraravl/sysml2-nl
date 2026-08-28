package 'Peristaltic Pump System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ISQ::*;

    package Definitions {
        item def Fluid {
            attribute density : MassDensityValue;
            attribute viscosity : Real;
        }
        item def PressureReading {
            attribute pressure : PressureValue;
        }
        item def FlowRateReading {
            attribute flowRate : VolumeFlowRateValue;
        }
        item def MotorSpeedCommand {
            attribute speed : RotationalSpeedValue;
            attribute direction : Integer;
        }

        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def MotorSpeedValue :> Real;
        attribute def RotationalSpeedValue :> Real;
        attribute def TorqueValue :> Real;

        port def FluidPort {
            out item fluid : Fluid;
        }
        port def SensorDataPort {
            out item reading;
        }
        port def MotorCommandPort {
            out item command : MotorSpeedCommand;
        }

        part def Roller;

        part def Rotor {
            part roller1 : Roller;
            part roller2 : Roller;
            part roller3 : Roller;
            port driveIn : ~MotorCommandPort;
            attribute rollerCount : Integer = 3;
        }

        part def FlexibleTube {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute innerDiameter : LengthValue;
            attribute elasticity : Real;
            attribute length : LengthValue;
        }

        part def ElectricMotor {
            port speedCommandIn : ~MotorCommandPort;
            port driveOut : MotorCommandPort;
            attribute currentSpeed : RotationalSpeedValue;
            attribute ratedTorque : TorqueValue;
        }

        part def PressureSensor {
            port fluidSensePort : ~FluidPort;
            port dataOutPort : SensorDataPort;
            attribute measuredPressure : PressureValue;
        }

        part def FlowRateSensor {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port dataOutPort : SensorDataPort;
            attribute measuredFlowRate : VolumeFlowRateValue;
        }

        calc def ControlLoop {
            in desired : VolumeFlowRateValue;
            in measured : VolumeFlowRateValue;
            in displacement : VolumeValue;
            return speed = desired / displacement + 0.1 * (desired - measured) / displacement;
        }

        state def PumpControllerStates {
            in outletPressure : PressureValue;
            in flowRate : VolumeFlowRateValue;
            in inletPressure : PressureValue;
            in maxPressure : PressureValue;

            entry; then idle;
            state idle;
            state priming;
            state running;
            state reversing;
            state faulted;

            transition t_start first idle if (true) then priming;
            transition t_prime_done first priming if (flowRate > 0.0) then running;
            transition t_reverse first running if (true) then reversing;
            transition t_forward first reversing if (true) then running;
            transition t_stop_run first running if (true) then idle;
            transition t_stop_rev first reversing if (true) then idle;
            transition t_occlusion_running first running if (outletPressure > maxPressure) then faulted;
            transition t_occlusion_priming first priming if (inletPressure < 0.0) then faulted;
            transition t_occlusion_reversing first reversing if (outletPressure > maxPressure) then faulted;
            transition t_reset first faulted if (true) then idle;
        }

        part def PumpController {
            attribute desiredFlowRate : VolumeFlowRateValue;
            attribute maxOutletPressure : PressureValue = 100000.0;
            attribute displacementPerRevolution : VolumeValue = 1e-6;
            attribute measuredFlowRate : VolumeFlowRateValue;
            attribute measuredOutletPressure : PressureValue;
            attribute measuredInletPressure : PressureValue;
            attribute motorSpeed : RotationalSpeedValue;

            port motorCommandOut : MotorCommandPort;
            port inletPressureIn : ~SensorDataPort;
            port outletPressureIn : ~SensorDataPort;
            port flowRateIn : ~SensorDataPort;

            exhibit controllerStates : PumpControllerStates {
                in outletPressure = measuredOutletPressure;
                in flowRate = measuredFlowRate;
                in inletPressure = measuredInletPressure;
                in maxPressure = maxOutletPressure;
            }

            calc controlLoopAction : ControlLoop {
                in desired = desiredFlowRate;
                in measured = measuredFlowRate;
                in displacement = displacementPerRevolution;
            }
            bind motorSpeed = controlLoopAction.speed;
        }

        part def PumpAssembly {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;

            part flexibleTube : FlexibleTube;
            part rotor : Rotor;
            part driveMotor : ElectricMotor;
            part controller : PumpController;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part outletFlowSensor : FlowRateSensor;

            flow of fluid : Fluid
                from fluidInPort.fluid to flexibleTube.fluidInPort.fluid;
            flow of fluid : Fluid
                from flexibleTube.fluidOutPort.fluid to outletFlowSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from outletFlowSensor.fluidOutPort.fluid to fluidOutPort.fluid;

            flow of fluid : Fluid
                from fluidInPort.fluid to inletPressureSensor.fluidSensePort.fluid;

            flow of fluid : Fluid
                from fluidOutPort.fluid to outletPressureSensor.fluidSensePort.fluid;

            connect controller.motorCommandOut to driveMotor.speedCommandIn;
            connect driveMotor.driveOut to rotor.driveIn;

            connect inletPressureSensor.dataOutPort to controller.inletPressureIn;
            connect outletPressureSensor.dataOutPort to controller.outletPressureIn;
            connect outletFlowSensor.dataOutPort to controller.flowRateIn;
        }

        part def SourceReservoir {
            port fluidOutPort : FluidPort;
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
        }

        part def DeliveryLine {
            port fluidInPort : ~FluidPort;
            attribute length : LengthValue;
            attribute innerDiameter : LengthValue;
        }
    }

    package Usages {
        part systemContext {
            part sourceReservoir : SourceReservoir {
                attribute capacity = 5.0 [L];
                attribute currentVolume = 4.0 [L];
            }
            part pump : PumpAssembly {
                part flexibleTube : FlexibleTube {
                    attribute innerDiameter = 3.0 [mm];
                    attribute elasticity = 0.85;
                    attribute length = 150.0 [mm];
                }
            }
            part deliveryLine : DeliveryLine {
                attribute length = 2.0 [m];
                attribute innerDiameter = 3.0 [mm];
            }

            flow of fluid : Fluid
                from sourceReservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of fluid : Fluid
                from pump.fluidOutPort.fluid to deliveryLine.fluidInPort.fluid;
        }
    }

    package Requirements {
        requirement def SterilityRequirement {
            doc "The fluid shall only contact the flexible tube and never touch the pump's mechanical components (rollers, rotor, motor).";
        }

        requirement def OcclusionDetectionRequirement {
            doc "The system shall detect downstream blockages via outlet pressure exceeding the safe limit and transition to a faulted state, stopping the motor.";
        }

        requirement def FlowControlRequirement {
            doc "The controller shall regulate motor speed to maintain the target flow rate based on real-time sensor feedback.";
        }

        requirement def PrimingRequirement {
            doc "The system shall execute a priming sequence to fill the tube with fluid before entering continuous running mode.";
        }

        requirement def ReversingRequirement {
            doc "The system shall support a reversing mode to change the direction of fluid flow.";
        }
    }

    package Verification {
        verification verifySterility : Requirements::SterilityRequirement {
            subject pump : Definitions::PumpAssembly;
            objective {
                doc "Confirm that fluid only contacts the flexible tube.";
            }
        }
        verification verifyOcclusion : Requirements::OcclusionDetectionRequirement {
            subject controller : Definitions::PumpController;
            objective {
                doc "Confirm occlusion detection triggers faulted state.";
            }
        }
        verification verifyFlowControl : Requirements::FlowControlRequirement {
            subject controller : Definitions::PumpController;
            objective {
                doc "Confirm closed-loop flow rate control.";
            }
        }
    }
}
