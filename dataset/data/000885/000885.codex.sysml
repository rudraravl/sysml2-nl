package GearPumpPumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = "Pa";
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = "m^3/s";
    }

    attribute def RotationalSpeed :> ISQ::frequency {
        unit = "rpm";
    }

    attribute def Torque :> ISQ::torque {
        unit = "N*m";
    }

    attribute def Power :> ISQ::power {
        unit = "W";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "K";
    }

    attribute def Volume :> ISQ::volume {
        unit = "m^3";
    }

    attribute def Efficiency :> ScalarValues::Real {
        range = "0..1";
    }

    attribute def Viscosity :> ScalarValues::Real {
        unit = "Pa*s";
    }

    item def HydraulicFluid {
        attribute density : ScalarValues::Real = 850.0;
        attribute dynamicViscosity : Viscosity = 0.046;
        attribute bulkModulus : Pressure = 1.4e9;
        attribute temperature : Temperature;
    }

    item def ElectricPower {
        attribute voltage : ScalarValues::Real = 48.0;
        attribute current : ScalarValues::Real;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute enable : Boolean;
        attribute targetFlow : FlowRate;
        attribute targetPressure : Pressure;
        attribute speedCommand : RotationalSpeed;
    }

    item def HealthStatus {
        attribute running : Boolean;
        attribute faulted : Boolean;
        attribute outletPressure : Pressure;
        attribute inletPressure : Pressure;
        attribute measuredFlow : FlowRate;
        attribute motorSpeed : RotationalSpeed;
        attribute fluidTemperature : Temperature;
    }

    port def FluidPort {
        inout fluid : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
        attribute temperature : Temperature;
    }

    port def PowerPort {
        in powerIn : ElectricPower;
    }

    port def CommandPort {
        in command : ControlCommand;
    }

    port def StatusPort {
        out status : HealthStatus;
    }

    port def ShaftPort {
        inout torque : Torque;
        inout speed : RotationalSpeed;
        attribute mechanicalPower : Power;
    }

    part def GearPump {
        attribute displacementPerRev : Volume = 8.0e-6;
        attribute volumetricEfficiency : Efficiency = 0.88;
        attribute mechanicalEfficiency : Efficiency = 0.82;
        attribute maxContinuousPressure : Pressure = 1.2e7;
        attribute maxSpeed : RotationalSpeed = 3600.0;
        attribute minPrimingPressure : Pressure = 50000.0;
        attribute outletFlow : FlowRate;
        attribute pressureRise : Pressure;
        attribute requiredTorque : Torque;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port shaft : ShaftPort;

        constraint flowGeneration {
            outletFlow == displacementPerRev * shaft.speed * volumetricEfficiency / 60.0;
        }

        constraint torqueDemand {
            requiredTorque == pressureRise * displacementPerRev / (2.0 * 3.14159 * mechanicalEfficiency);
        }

        action pumpFluid {
            in inletFluid : HydraulicFluid;
            in shaftSpeed : RotationalSpeed;
            out dischargeFluid : HydraulicFluid;
            out deliveredFlow : FlowRate;

            first startCompression;
            then transferFluid;
            then dischargeFluidAction;

            action startCompression {
                inlet.pressure >= minPrimingPressure;
            }

            action transferFluid {
                deliveredFlow = displacementPerRev * shaftSpeed * volumetricEfficiency / 60.0;
            }

            action dischargeFluidAction {
                dischargeFluid = inletFluid;
                outlet.flow = deliveredFlow;
                outlet.pressure = inlet.pressure + pressureRise;
            }
        }

        state def PumpOperatingState {
            state Off;
            state Priming;
            state Running;
            state PressureLimited;
            state Faulted;

            transition initial then Off;

            transition Off_to_Priming
                first Off
                accept ControlCommand
                if command.enable
                then Priming;

            transition Priming_to_Running
                first Priming
                if inlet.pressure >= minPrimingPressure
                then Running;

            transition Running_to_PressureLimited
                first Running
                if outlet.pressure >= maxContinuousPressure
                then PressureLimited;

            transition PressureLimited_to_Running
                first PressureLimited
                if outlet.pressure < 0.95 * maxContinuousPressure
                then Running;

            transition Any_to_Faulted
                first Running
                if shaft.speed > maxSpeed or inlet.pressure < minPrimingPressure
                then Faulted;

            transition Faulted_to_Off
                first Faulted
                accept ControlCommand
                if not command.enable
                then Off;
        }
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 3500.0;
        attribute ratedSpeed : RotationalSpeed = 3000.0;
        attribute ratedTorque : Torque = 11.1;
        attribute efficiency : Efficiency = 0.90;
        attribute commandedSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        attribute outputTorque : Torque;

        port electrical : PowerPort;
        port shaft : ShaftPort;

        constraint motorPowerLimit {
            shaft.mechanicalPower <= ratedPower;
        }

        action regulateSpeed {
            in commandSpeed : RotationalSpeed;
            out deliveredSpeed : RotationalSpeed;

            deliveredSpeed = commandSpeed;
            actualSpeed = deliveredSpeed;
            shaft.speed = actualSpeed;
        }
    }

    part def PumpController {
        attribute enabled : Boolean = false;
        attribute pressureSetpoint : Pressure = 8.0e6;
        attribute flowSetpoint : FlowRate = 3.5e-4;
        attribute speedRequest : RotationalSpeed;
        attribute pressureError : Pressure;
        attribute flowError : FlowRate;

        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action computeSpeedCommand {
            in requestedFlow : FlowRate;
            in measuredPressure : Pressure;
            out speedCommand : RotationalSpeed;

            pressureError = pressureSetpoint - measuredPressure;
            flowError = requestedFlow - flowSetpoint;
            speedCommand = requestedFlow / (8.0e-6 * 0.88) * 60.0;

            if measuredPressure >= pressureSetpoint {
                speedCommand = 0.85 * speedCommand;
            }
        }

        state def ControllerState {
            state Disabled;
            state Standby;
            state Commanding;
            state Shutdown;
            state FaultLatched;

            transition initial then Disabled;

            transition Disabled_to_Standby
                first Disabled
                accept ControlCommand
                if command.enable
                then Standby;

            transition Standby_to_Commanding
                first Standby
                if command.targetFlow > 0.0
                then Commanding;

            transition Commanding_to_Shutdown
                first Commanding
                accept ControlCommand
                if not command.enable
                then Shutdown;

            transition Shutdown_to_Disabled
                first Shutdown
                then Disabled;

            transition Commanding_to_FaultLatched
                first Commanding
                if statusOut.status.faulted
                then FaultLatched;

            transition FaultLatched_to_Disabled
                first FaultLatched
                accept ControlCommand
                if not command.enable
                then Disabled;
        }
    }

    part def ReliefValve {
        attribute crackingPressure : Pressure = 1.05e7;
        attribute fullOpenPressure : Pressure = 1.15e7;
        attribute bypassFlow : FlowRate;
        attribute reseatPressure : Pressure = 9.5e6;

        port inlet : FluidPort;
        port returnPort : FluidPort;

        action relieveOverpressure {
            in pressureIn : Pressure;
            out relievedFlow : FlowRate;

            if pressureIn >= crackingPressure {
                relievedFlow = bypassFlow;
                returnPort.flow = relievedFlow;
            } else {
                relievedFlow = 0.0;
            }
        }

        state def ReliefValveState {
            state Closed;
            state Cracking;
            state Open;

            transition initial then Closed;

            transition Closed_to_Cracking
                first Closed
                if inlet.pressure >= crackingPressure
                then Cracking;

            transition Cracking_to_Open
                first Cracking
                if inlet.pressure >= fullOpenPressure
                then Open;

            transition Open_to_Closed
                first Open
                if inlet.pressure <= reseatPressure
                then Closed;
        }
    }

    part def SuctionFilter {
        attribute filtrationRatingMicron : ScalarValues::Real = 25.0;
        attribute cleanPressureDrop : Pressure = 12000.0;
        attribute clogPressureDropLimit : Pressure = 80000.0;
        attribute currentPressureDrop : Pressure;

        port upstream : FluidPort;
        port downstream : FluidPort;

        constraint pressureDrop {
            downstream.pressure == upstream.pressure - currentPressureDrop;
        }
    }

    part def CheckValve {
        attribute openingPressure : Pressure = 20000.0;
        attribute reverseLeakageFlow : FlowRate = 1.0e-7;

        port inlet : FluidPort;
        port outlet : FluidPort;

        state def CheckValveState {
            state Closed;
            state Open;

            transition initial then Closed;

            transition Closed_to_Open
                first Closed
                if inlet.pressure > outlet.pressure + openingPressure
                then Open;

            transition Open_to_Closed
                first Open
                if inlet.pressure <= outlet.pressure
                then Closed;
        }
    }

    part def Reservoir {
        attribute capacity : Volume = 0.025;
        attribute usableVolume : Volume = 0.020;
        attribute fluidTemperature : Temperature = 313.15;
        attribute headPressure : Pressure = 101325.0;

        port supply : FluidPort;
        port returnPort : FluidPort;
    }

    part def PressureSensor {
        attribute rangeMinimum : Pressure = 0.0;
        attribute rangeMaximum : Pressure = 1.6e7;
        attribute accuracy : Pressure = 25000.0;
        attribute measuredPressure : Pressure;

        port sensingPort : FluidPort;

        action measurePressure {
            measuredPressure = sensingPort.pressure;
        }
    }

    part def FlowSensor {
        attribute rangeMinimum : FlowRate = 0.0;
        attribute rangeMaximum : FlowRate = 8.0e-4;
        attribute accuracy : FlowRate = 1.0e-5;
        attribute measuredFlow : FlowRate;

        port sensingPort : FluidPort;

        action measureFlow {
            measuredFlow = sensingPort.flow;
        }
    }

    part def TemperatureSensor {
        attribute rangeMinimum : Temperature = 253.15;
        attribute rangeMaximum : Temperature = 393.15;
        attribute accuracy : Temperature = 1.0;
        attribute measuredTemperature : Temperature;

        port sensingPort : FluidPort;

        action measureTemperature {
            measuredTemperature = sensingPort.temperature;
        }
    }

    part def PumpingSubsystem {
        attribute commandedFlow : FlowRate = 3.5e-4;
        attribute nominalOutletPressure : Pressure = 8.0e6;
        attribute maximumOutletPressure : Pressure = 1.2e7;
        attribute minimumInletPressure : Pressure = 50000.0;
        attribute nominalFluidTemperature : Temperature = 313.15;

        port suctionInterface : FluidPort;
        port dischargeInterface : FluidPort;
        port electricalInterface : PowerPort;
        port commandInterface : CommandPort;
        port statusInterface : StatusPort;

        part reservoir : Reservoir;
        part suctionFilter : SuctionFilter;
        part motor : ElectricMotor;
        part pump : GearPump;
        part outletCheckValve : CheckValve;
        part reliefValve : ReliefValve;
        part outletPressureSensor : PressureSensor;
        part inletPressureSensor : PressureSensor;
        part dischargeFlowSensor : FlowSensor;
        part fluidTemperatureSensor : TemperatureSensor;
        part controller : PumpController;

        connect reservoir.supply to suctionFilter.upstream;
        connect suctionFilter.downstream to pump.inlet;
        connect pump.outlet to outletCheckValve.inlet;
        connect outletCheckValve.outlet to dischargeInterface;
        connect outletCheckValve.outlet to reliefValve.inlet;
        connect reliefValve.returnPort to reservoir.returnPort;
        connect motor.shaft to pump.shaft;
        connect electricalInterface to motor.electrical;
        connect commandInterface to controller.commandIn;
        connect controller.statusOut to statusInterface;
        connect pump.inlet to inletPressureSensor.sensingPort;
        connect outletCheckValve.outlet to outletPressureSensor.sensingPort;
        connect outletCheckValve.outlet to dischargeFlowSensor.sensingPort;
        connect reservoir.supply to fluidTemperatureSensor.sensingPort;
        connect suctionInterface to reservoir.supply;

        action startupSequence {
            first receiveEnableCommand;
            then verifyFluidAvailable;
            then startMotor;
            then primePump;
            then regulateDischarge;

            action receiveEnableCommand {
                controller.enabled = commandInterface.command.enable;
            }

            action verifyFluidAvailable {
                reservoir.usableVolume > 0.005;
                pump.inlet.pressure >= minimumInletPressure;
            }

            action startMotor {
                motor.commandedSpeed = commandInterface.command.speedCommand;
            }

            action primePump {
                pump.inlet.pressure >= pump.minPrimingPressure;
            }

            action regulateDischarge {
                controller.computeSpeedCommand(
                    commandInterface.command.targetFlow,
                    outletPressureSensor.measuredPressure,
                    motor.commandedSpeed
                );
            }
        }

        action shutdownSequence {
            first rampDownMotor;
            then isolateDischarge;
            then reportStopped;

            action rampDownMotor {
                motor.commandedSpeed = 0.0;
            }

            action isolateDischarge {
                outletCheckValve.outlet.flow = 0.0;
            }

            action reportStopped {
                statusInterface.status.running = false;
                statusInterface.status.faulted = false;
            }
        }

        action monitorHealth {
            inletPressureSensor.measurePressure();
            outletPressureSensor.measurePressure();
            dischargeFlowSensor.measureFlow();
            fluidTemperatureSensor.measureTemperature();

            statusInterface.status.running = commandInterface.command.enable;
            statusInterface.status.outletPressure = outletPressureSensor.measuredPressure;
            statusInterface.status.inletPressure = inletPressureSensor.measuredPressure;
            statusInterface.status.measuredFlow = dischargeFlowSensor.measuredFlow;
            statusInterface.status.motorSpeed = motor.actualSpeed;
            statusInterface.status.fluidTemperature = fluidTemperatureSensor.measuredTemperature;

            if outletPressureSensor.measuredPressure > maximumOutletPressure or
               inletPressureSensor.measuredPressure < minimumInletPressure {
                statusInterface.status.faulted = true;
            } else {
                statusInterface.status.faulted = false;
            }
        }

        state def SubsystemState {
            state Off;
            state Starting;
            state Pumping;
            state Relieving;
            state Fault;
            state Stopping;

            transition initial then Off;

            transition Off_to_Starting
                first Off
                accept ControlCommand
                if command.enable
                then Starting;

            transition Starting_to_Pumping
                first Starting
                if pump.inlet.pressure >= minimumInletPressure and motor.actualSpeed > 0.0
                then Pumping;

            transition Pumping_to_Relieving
                first Pumping
                if outletPressureSensor.measuredPressure >= reliefValve.crackingPressure
                then Relieving;

            transition Relieving_to_Pumping
                first Relieving
                if outletPressureSensor.measuredPressure <= reliefValve.reseatPressure
                then Pumping;

            transition Pumping_to_Fault
                first Pumping
                if outletPressureSensor.measuredPressure > maximumOutletPressure or
                   inletPressureSensor.measuredPressure < minimumInletPressure or
                   fluidTemperatureSensor.measuredTemperature > 373.15
                then Fault;

            transition Fault_to_Stopping
                first Fault
                then Stopping;

            transition Pumping_to_Stopping
                first Pumping
                accept ControlCommand
                if not command.enable
                then Stopping;

            transition Stopping_to_Off
                first Stopping
                if motor.actualSpeed == 0.0
                then Off;
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : PumpingSubsystem;

        requirement flowDelivery {
            doc /* The pumping subsystem shall deliver at least 3.5e-4 m^3/s of hydraulic fluid at nominal operating speed. */
            require constraint { subsystem.dischargeFlowSensor.measuredFlow >= 3.5e-4; }
        }

        requirement pressureCapability {
            doc /* The gear pump subsystem shall sustain a nominal discharge pressure of 8.0e6 Pa without opening the relief valve. */
            require constraint { subsystem.outletPressureSensor.measuredPressure >= 8.0e6 and subsystem.outletPressureSensor.measuredPressure < subsystem.reliefValve.crackingPressure; }
        }

        requirement overpressureProtection {
            doc /* The subsystem shall route fluid back to the reservoir when discharge pressure reaches 1.05e7 Pa. */
            require constraint { subsystem.reliefValve.crackingPressure == 1.05e7; }
        }

        requirement inletProtection {
            doc /* The subsystem shall enter a fault state if gear pump inlet pressure falls below 5.0e4 Pa. */
            require constraint { subsystem.minimumInletPressure == 5.0e4; }
        }

        requirement noReverseFlow {
            doc /* The subsystem shall prevent reverse flow from the discharge interface to the gear pump outlet. */
            require constraint { subsystem.outletCheckValve.reverseLeakageFlow <= 1.0e-7; }
        }

        requirement temperatureLimit {
            doc /* The subsystem shall report a fault if hydraulic fluid temperature exceeds 373.15 K. */
            require constraint { subsystem.fluidTemperatureSensor.measuredTemperature <= 373.15; }
        }

        requirement filtration {
            doc /* The suction filter shall remove particles larger than 25 micrometers before fluid enters the gear pump. */
            require constraint { subsystem.suctionFilter.filtrationRatingMicron <= 25.0; }
        }
    }

    satisfy PumpingSubsystemRequirement::flowDelivery by PumpingSubsystem::pump;
    satisfy PumpingSubsystemRequirement::pressureCapability by PumpingSubsystem::pump;
    satisfy PumpingSubsystemRequirement::overpressureProtection by PumpingSubsystem::reliefValve;
    satisfy PumpingSubsystemRequirement::inletProtection by PumpingSubsystem::controller;
    satisfy PumpingSubsystemRequirement::noReverseFlow by PumpingSubsystem::outletCheckValve;
    satisfy PumpingSubsystemRequirement::temperatureLimit by PumpingSubsystem::fluidTemperatureSensor;
    satisfy PumpingSubsystemRequirement::filtration by PumpingSubsystem::suctionFilter;

    part gearPumpPumpingSubsystem : PumpingSubsystem {
        attribute commandedFlow = 3.5e-4;
        attribute nominalOutletPressure = 8.0e6;
        attribute maximumOutletPressure = 1.2e7;
        attribute minimumInletPressure = 5.0e4;
        attribute nominalFluidTemperature = 313.15;
    }
}