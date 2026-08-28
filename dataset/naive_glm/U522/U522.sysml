package ImpellerPumpSystem {

    // ---- Value Types with Units ----

    attribute def Power :> Real { unit 'kW'; }
    attribute def Efficiency :> Real { unit '%'; }
    attribute def Length :> Real { unit 'm'; }
    attribute def RotationalSpeed :> Real { unit 'rpm'; }
    attribute def Torque :> Real { unit 'N*m'; }
    attribute def Pressure :> Real { unit 'bar'; }
    attribute def FlowRate :> Real { unit 'm^3/h'; }
    attribute def Temperature :> Real { unit 'degC'; }
    attribute def Duration :> Real { unit 'h'; }
    attribute def BladeCount :> Integer;
    attribute def ControlSignal :> Real { unit 'V'; }

    // ---- Item Definitions ----

    item def ElectricalPower {
        attribute voltage : Real { unit 'V'; }
        attribute current : Real { unit 'A'; }
        attribute frequency : Real { unit 'Hz'; }
    }

    item def Fluid {
        attribute density : Real { unit 'kg/m^3'; }
        attribute viscosity : Real { unit 'Pa*s'; }
        attribute temperature : Temperature;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def RotationalMotion {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    // ---- Port Definitions ----

    port def ElectricalInPort {
        in power : ElectricalPower;
        in command : ControlSignal;
    }

    port def MechanicalPort {
        out motion : RotationalMotion;
    }

    port def FluidInPort {
        in fluid : Fluid;
    }

    port def FluidOutPort {
        out fluid : Fluid;
    }

    // ---- Motor ----

    part def Motor {
        attribute ratedPower : Power = 5.0;
        attribute efficiency : Efficiency = 92.0;
        attribute operatingSpeed : RotationalSpeed = 2900;

        port electricalIn : ElectricalInPort;
        port driveOut : MechanicalPort;

        state machine MotorStates {
            entry action { send MotorStarted; }
            state Off;
            state Starting;
            state Running {
                entry action {
                    driveOut.motion.speed = operatingSpeed;
                    driveOut.motion.torque = (ratedPower * 1000 * efficiency / 100) / (2 * 3.14159 * operatingSpeed / 60);
                }
            }
            state Faulted;
            transition off_to_starting
                from Off to Starting
                when electricalIn.command > 0;
            transition starting_to_running
                from Starting to Running
                when driveOut.motion.speed >= operatingSpeed * 0.95;
            transition running_to_off
                from Running to Off
                when electricalIn.command == 0;
            transition any_to_faulted
                from Running to Faulted
                when electricalIn.current > ratedPower * 1000 / electricalIn.voltage * 1.5;
        }
    }

    // ---- Shaft ----

    part def Shaft {
        attribute length : Length = 0.30;
        attribute material : String = "Stainless Steel";
        attribute maxTorque : Torque = 50.0;

        port inputSide : MechanicalPort;
        port outputSide : MechanicalPort;

        action transmitMotion {
            in inputMotion : RotationalMotion;
            out outputMotion : RotationalMotion;
            perform {
                outputMotion.speed = inputMotion.speed;
                outputMotion.torque = inputMotion.torque * 0.98;
            }
        }
    }

    // ---- Impeller ----

    part def Impeller {
        attribute bladeCount : BladeCount = 6;
        attribute bladeAngle : Real { unit 'deg'; } = 30.0;
        attribute diameter : Real { unit 'm'; } = 0.15;

        port driveIn : MechanicalPort;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;

        action accelerateFluid {
            in motion : RotationalMotion;
            in inFluid : Fluid;
            out outFluid : Fluid;
            perform {
                outFluid.flowRate = inFluid.flowRate + motion.speed * diameter * 0.01;
                outFluid.outletPressure = inFluid.inletPressure + (motion.speed * motion.speed * diameter * diameter) / 2000000.0;
                outFluid.temperature = inFluid.temperature + 2.0;
            }
        }
    }

    // ---- Casing ----

    part def Casing {
        attribute inletDiameter : Real { unit 'm'; } = 0.08;
        attribute outletDiameter : Real { unit 'm'; } = 0.06;
        attribute voluteRatio : Real = 1.4;

        port suctionPort : FluidInPort;
        port dischargePort : FluidOutPort;
        port impellerInterface : FluidOutPort;

        action directAndConvert {
            in incomingFluid : Fluid;
            out dischargedFluid : Fluid;
            perform {
                dischargedFluid.outletPressure = incomingFluid.outletPressure * voluteRatio;
                dischargedFluid.flowRate = incomingFluid.flowRate;
                dischargedFluid.temperature = incomingFluid.temperature;
            }
        }
    }

    // ---- Pump System Assembly ----

    part def ImpellerPumpSystem {
        attribute systemFlowRate : FlowRate;
        attribute systemPressureRise : Pressure;
        attribute totalOperatingHours : Duration = 0.0;

        port electricalInput : ElectricalInPort;
        port suctionInlet : FluidInPort;
        port dischargeOutlet : FluidOutPort;

        part motor : Motor {
            port electricalIn : ElectricalInPort;
            port driveOut : MechanicalPort;
        }

        part shaft : Shaft {
            port inputSide : MechanicalPort;
            port outputSide : MechanicalPort;
        }

        part impeller : Impeller {
            port driveIn : MechanicalPort;
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
        }

        part casing : Casing {
            port suctionPort : FluidInPort;
            port dischargePort : FluidOutPort;
            port impellerInterface : FluidOutPort;
        }

        // Connections
        connection electricalPowerFlow
            from electricalInput to motor.electricalIn;

        connection mechanicalDrive1
            from motor.driveOut to shaft.inputSide;

        connection mechanicalDrive2
            from shaft.outputSide to impeller.driveIn;

        connection fluidSuction
            from suctionInlet to casing.suctionPort;

        connection fluidToImpeller
            from casing.suctionPort to impeller.fluidIn;

        connection fluidFromImpeller
            from impeller.fluidOut to casing.impellerInterface;

        connection fluidDischarge
            from casing.dischargePort to dischargeOutlet;

        // System behavior
        action operatePump {
            in electricalPower : ElectricalPower;
            in command : ControlSignal;
            in suctionFluid : Fluid;
            out dischargeFluid : Fluid;
            perform {
                motor.electricalIn.power = electricalPower;
                motor.electricalIn.command = command;
                shaft.transmitMotion(motor.driveOut.motion, shaft.outputSide.motion);
                impeller.accelerateFluid(shaft.outputSide.motion, suctionFluid, impeller.fluidOut.fluid);
                casing.directAndConvert(impeller.fluidOut.fluid, dischargeFluid);
                systemFlowRate = dischargeFluid.flowRate;
                systemPressureRise = dischargeFluid.outletPressure - suctionFluid.inletPressure;
            }
        }

        state machine SystemOperation {
            state Idle;
            state Priming;
            state Operating;
            state Maintenance;
            transition idle_to_priming
                from Idle to Priming
                when electricalInput.command > 0;
            transition priming_to_operating
                from Priming to Operating
                when suctionInlet.fluid.flowRate > 0;
            transition operating_to_idle
                from Operating to Idle
                when electricalInput.command == 0;
            transition operating_to_maintenance
                from Operating to Maintenance
                when totalOperatingHours >= 10000;
            transition maintenance_to_idle
                from Maintenance to Idle
                when totalOperatingHours < 10000;
        }
    }

    // ---- Requirements ----

    requirement def PerformanceRequirements {
        subject pump : ImpellerPumpSystem;

        requirement TargetFlowRate {
            subject p : ImpellerPumpSystem;
            require {
                p.systemFlowRate >= 15.0;
            }
        }

        requirement TargetPressureRise {
            subject p : ImpellerPumpSystem;
            require {
                p.systemPressureRise >= 2.0;
            }
        }

        requirement MaxPowerConsumption {
            subject p : ImpellerPumpSystem;
            require {
                p.motor.ratedPower <= 5.0;
            }
        }

        requirement ContinuousOperationReliability {
            subject p : ImpellerPumpSystem;
            require {
                p.totalOperatingHours >= 10000;
            }
        }
    }

    requirement pumpPerformance : PerformanceRequirements {
        subject pump : ImpellerPumpSystem;
    }

}
