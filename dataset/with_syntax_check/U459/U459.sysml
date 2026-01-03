package 'Pumping Subsystem' {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volumeFlowRate : VolumeFlowRateValue;
        }

        port def FluidPort {
            attribute pressure : PressureValue;
            out item fluidOut : Fluid;
        }

        port def FluidInletPort :> FluidPort {
            in item fluidIn : Fluid;
        }

        port def FluidOutletPort :> FluidPort {
            out item fluidOut : Fluid;
        }

        port def PowerPort {
            in attribute powerIn : PowerValue;
        }

        port def ControlPort {
            in attribute commandedSpeed : Real;
            out attribute actualSpeed : Real;
            out attribute operatingStatus : PumpStatus;
        }

        enum def PumpStatus {
            enum off;
            enum starting;
            enum running;
            enum stopping;
            enum faulted;
        }

        signal def StartCommand;
        signal def StopCommand;
        signal def ResetCommand;

        part def Motor {
            port powerPort : PowerPort;
            port controlPort : ControlPort;

            attribute ratedPower : PowerValue;
            attribute efficiency : Real;
            attribute currentSpeed : Real;

            perform action driveShaft {
                in speedCommand : Real;
                out torque : TorqueValue;
                out speed : Real;
            }
        }

        part def Impeller {
            attribute diameter : LengthValue;
            attribute numberOfBlades : Real;
            attribute rotationalSpeed : Real;

            perform action impartEnergy {
                in torqueIn : TorqueValue;
                in fluidIn : Fluid;
                out fluidOut : Fluid;
            }
        }

        part def PumpCasing {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;

            attribute inletDiameter : LengthValue;
            attribute outletDiameter : LengthValue;
            attribute maxPressure : PressureValue;
        }

        part def Seal {
            attribute sealType : String;
            attribute maxLeakageRate : VolumeFlowRateValue;

            perform action preventLeakage;
        }

        part def Bearing {
            attribute bearingType : String;
            attribute loadCapacity : ForceValue;

            perform action supportRotation;
        }

        part def Shaft {
            attribute diameter : LengthValue;
            attribute length : LengthValue;
            attribute material : String;

            perform action transmitTorque {
                in torqueIn : TorqueValue;
                out torqueOut : TorqueValue;
            }
        }

        part def Pump {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;
            port powerPort : PowerPort;
            port controlPort : ControlPort;

            attribute ratedFlowRate : VolumeFlowRateValue;
            attribute ratedHead : LengthValue;
            attribute efficiency : Real;
            attribute npshRequired : LengthValue;

            part motor : Motor;
            part shaft : Shaft;
            part impeller : Impeller;
            part casing : PumpCasing;
            part seal : Seal[2];
            part bearing : Bearing[2];

            connect powerPort to motor.powerPort;
            connect controlPort to motor.controlPort;

            flow of fluid : Fluid 
                from casing.inletPort.fluidIn 
                to impeller.impartEnergy.fluidIn;
            
            flow of fluid : Fluid 
                from impeller.impartEnergy.fluidOut 
                to casing.outletPort.fluidOut;

            bind inletPort = casing.inletPort;
            bind outletPort = casing.outletPort;

            perform action pumpFluid {
                in fluidIn : Fluid = inletPort.fluidIn;
                out fluidOut : Fluid = outletPort.fluidOut;

                action startMotor;
                action accelerateImpeller;
                action maintainFlow;
                action stopMotor;

                then startMotor;
                then accelerateImpeller;
                then maintainFlow;
                then stopMotor;
            }

            state pumpStateMachine {
                entry; then idle;

                state idle;
                state starting;
                state operating {
                    state normalOperation;
                    state lowFlow;
                }
                state stopping;
                state fault;

                transition idle_to_starting
                    first idle
                    accept StartCommand
                    then starting;

                transition starting_to_operating
                    first starting
                    if motor.currentSpeed >= 0.95 * motor.controlPort.commandedSpeed
                    then operating.normalOperation;

                transition operating_to_lowFlow
                    first operating.normalOperation
                    if outletPort.fluidOut.volumeFlowRate < 0.5 * ratedFlowRate
                    then operating.lowFlow;

                transition lowFlow_to_normal
                    first operating.lowFlow
                    if outletPort.fluidOut.volumeFlowRate >= 0.5 * ratedFlowRate
                    then operating.normalOperation;

                transition operating_to_stopping
                    first operating
                    accept StopCommand
                    then stopping;

                transition stopping_to_idle
                    first stopping
                    if motor.currentSpeed <= 0.0
                    then idle;

                transition fault_to_idle
                    first fault
                    accept ResetCommand
                    then idle;
            }
        }

        part def FluidSource {
            port outletPort : FluidOutletPort;

            attribute sourceFluid : Fluid;
            attribute sourcePressure : PressureValue;
            attribute capacity : VolumeValue;
        }

        part def FluidDestination {
            port inletPort : FluidInletPort;

            attribute requiredPressure : PressureValue;
            attribute requiredFlowRate : VolumeFlowRateValue;
        }

        part def PressureSensor {
            port sensingPort : FluidPort;

            attribute measuredPressure : PressureValue;

            perform action measurePressure {
                in fluidIn : Fluid;
                out pressureReading : PressureValue;
            }
        }

        part def FlowMeter {
            port sensingPort : FluidPort;

            attribute measuredFlowRate : VolumeFlowRateValue;

            perform action measureFlow {
                in fluidIn : Fluid;
                out flowReading : VolumeFlowRateValue;
            }
        }

        part def Valve {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;

            attribute position : Real;
            attribute maxPosition : Real;

            perform action regulateFlow {
                in fluidIn : Fluid;
                in valvePosition : Real;
                out fluidOut : Fluid;
            }
        }

        part def PipingSegment {
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;

            attribute length : LengthValue;
            attribute diameter : LengthValue;
            attribute roughness : Real;

            perform action transportFluid {
                in fluidIn : Fluid;
                out fluidOut : Fluid;
            }
        }

        part def Controller {
            port controlPort : ControlPort;

            attribute setpoint : VolumeFlowRateValue;
            attribute kp : Real;
            attribute ki : Real;
            attribute kd : Real;

            perform action controlPump {
                in measuredFlow : VolumeFlowRateValue;
                in measuredPressure : PressureValue;
                out speedCommand : Real;
            }
        }
    }

    package Requirements {
        requirement def PumpingSystemRequirements {
            doc /* The pumping subsystem shall move fluid from source to destination. */

            requirement flowRateRequirement {
                doc /* The system shall deliver fluid at the specified flow rate. */

                subject pump : Definitions::Pump;

                require constraint {
                    pump.outletPort.fluidOut.volumeFlowRate >= pump.ratedFlowRate * 0.95 and
                    pump.outletPort.fluidOut.volumeFlowRate <= pump.ratedFlowRate * 1.05
                }
            }

            requirement pressureRequirement {
                doc /* The pump shall generate sufficient pressure head. */

                subject pump : Definitions::Pump;

                require constraint {
                    pump.outletPort.pressure >= pump.inletPort.pressure +
                    (pump.ratedHead * pump.inletPort.fluidIn.density * 9.81 [SI::Pa])
                }
            }

            requirement efficiencyRequirement {
                doc /* The pump shall operate at minimum efficiency. */

                subject pump : Definitions::Pump;

                require constraint {
                    pump.efficiency >= 0.70
                }
            }

            requirement npshRequirement {
                doc /* The system shall maintain adequate net positive suction head. */

                subject pump : Definitions::Pump;

                require constraint {
                    pump.inletPort.pressure >= pump.npshRequired
                }
            }
        }
    }

    package Usages {
        part pumpingSubsystem {
            part source : Definitions::FluidSource {
                attribute :>> sourceFluid {
                    attribute :>> density = 1000.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 20.0 [SI::'°C'];
                    attribute :>> pressure = 101325.0 [SI::Pa];
                }
                attribute :>> sourcePressure = 101325.0 [SI::Pa];
                attribute :>> capacity = 10.0 [SI::'m³'];
            }

            part suctionPiping : Definitions::PipingSegment {
                attribute :>> length = 5.0 [SI::m];
                attribute :>> diameter = 0.1 [SI::m];
                attribute :>> roughness = 0.000045;
            }

            part suctionValve : Definitions::Valve {
                attribute :>> position = 1.0;
                attribute :>> maxPosition = 1.0;
            }

            part inletPressureSensor : Definitions::PressureSensor;

            part mainPump : Definitions::Pump {
                attribute :>> ratedFlowRate = 0.05 [SI::'m³'/SI::s];
                attribute :>> ratedHead = 50.0 [SI::m];
                attribute :>> efficiency = 0.75;
                attribute :>> npshRequired = 3.0 [SI::m];

                part :>> motor {
                    attribute :>> ratedPower = 30000.0 [SI::W];
                    attribute :>> efficiency = 0.90;
                }

                part :>> shaft {
                    attribute :>> diameter = 0.05 [SI::m];
                    attribute :>> length = 0.3 [SI::m];
                    attribute :>> material = "Stainless Steel 316";
                }

                part :>> impeller {
                    attribute :>> diameter = 0.25 [SI::m];
                    attribute :>> numberOfBlades = 6.0;
                }

                part :>> casing {
                    attribute :>> inletDiameter = 0.1 [SI::m];
                    attribute :>> outletDiameter = 0.08 [SI::m];
                    attribute :>> maxPressure = 1000000.0 [SI::Pa];
                }

                part :>> seal[1] {
                    attribute :>> sealType = "Mechanical Seal - Primary";
                    attribute :>> maxLeakageRate = 0.0001 [SI::'m³'/SI::s];
                }

                part :>> seal[2] {
                    attribute :>> sealType = "Mechanical Seal - Secondary";
                    attribute :>> maxLeakageRate = 0.00005 [SI::'m³'/SI::s];
                }

                part :>> bearing[1] {
                    attribute :>> bearingType = "Radial Ball Bearing";
                    attribute :>> loadCapacity = 5000.0 [SI::N];
                }

                part :>> bearing[2] {
                    attribute :>> bearingType = "Thrust Bearing";
                    attribute :>> loadCapacity = 3000.0 [SI::N];
                }
            }

            part dischargePressureSensor : Definitions::PressureSensor;

            part flowMeter : Definitions::FlowMeter;

            part dischargeValve : Definitions::Valve {
                attribute :>> position = 0.8;
                attribute :>> maxPosition = 1.0;
            }

            part dischargePiping : Definitions::PipingSegment {
                attribute :>> length = 10.0 [SI::m];
                attribute :>> diameter = 0.08 [SI::m];
                attribute :>> roughness = 0.000045;
            }

            part destination : Definitions::FluidDestination {
                attribute :>> requiredPressure = 500000.0 [SI::Pa];
                attribute :>> requiredFlowRate = 0.05 [SI::'m³'/SI::s];
            }

            part pumpController : Definitions::Controller {
                attribute :>> setpoint = 0.05 [SI::'m³'/SI::s];
                attribute :>> kp = 1.5;
                attribute :>> ki = 0.5;
                attribute :>> kd = 0.1;
            }

            flow of fluid : Definitions::Fluid
                from source.outletPort.fluidOut
                to suctionPiping.inletPort.fluidIn;

            flow of fluid : Definitions::Fluid
                from suctionPiping.outletPort.fluidOut
                to suctionValve.inletPort.fluidIn;

            flow of fluid : Definitions::Fluid
                from suctionValve.outletPort.fluidOut
                to mainPump.inletPort.fluidIn;

            flow of fluid : Definitions::Fluid
                from mainPump.outletPort.fluidOut
                to dischargeValve.inletPort.fluidIn;

            flow of fluid : Definitions::Fluid
                from dischargeValve.outletPort.fluidOut
                to dischargePiping.inletPort.fluidIn;

            flow of fluid : Definitions::Fluid
                from dischargePiping.outletPort.fluidOut
                to destination.inletPort.fluidIn;

            connect inletPressureSensor.sensingPort to mainPump.inletPort;
            connect dischargePressureSensor.sensingPort to mainPump.outletPort;
            connect flowMeter.sensingPort to dischargeValve.outletPort;

            connect pumpController.controlPort to mainPump.controlPort;
        }

        requirement pumpingSystemReqs : Requirements::PumpingSystemRequirements {
            subject pumpingSubsystem.mainPump;
        }
    }

    dependency from Usages::pumpingSubsystem to Requirements::PumpingSystemRequirements;
}
