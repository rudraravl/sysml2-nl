package RotodynamicPumpingSubsystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure :> ISQ::pressure;
    attribute def FlowRate :> ISQ::volumeFlowRate;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def AngularSpeed :> ISQ::angularVelocity;
    attribute def Power :> ISQ::power;
    attribute def Energy :> ISQ::energy;
    attribute def Efficiency :> ScalarValues::Real;
    attribute def Length :> ISQ::length;
    attribute def MassDensity :> ISQ::massDensity;
    attribute def DynamicViscosity :> ISQ::dynamicViscosity;
    attribute def VibrationVelocity :> ISQ::velocity;

    item def Fluid {
        attribute density : MassDensity;
        attribute dynamicViscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
        attribute contaminationClass : String;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
        attribute activePower : Power;
    }

    item def ControlSignal {
        attribute commandPercent : ScalarValues::Real;
        attribute valid : Boolean;
        attribute timestamp : String;
    }

    item def StatusSignal {
        attribute running : Boolean;
        attribute faulted : Boolean;
        attribute measuredFlow : FlowRate;
        attribute measuredDischargePressure : Pressure;
        attribute measuredTemperature : Temperature;
    }

    port def FluidPort {
        inout item fluid : Fluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }

    port def PowerPort {
        in item powerFeed : ElectricalPower;
    }

    port def CommandPort {
        in item command : ControlSignal;
    }

    port def StatusPort {
        out item status : StatusSignal;
    }

    port def MechanicalShaftPort {
        attribute torque : ISQ::torque;
        attribute speed : AngularSpeed;
    }

    part def SuctionStrainer {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute meshSize : Length = 0.001 [m];
        attribute cleanPressureDrop : Pressure = 800 [Pa];
        attribute cloggedPressureDropLimit : Pressure = 25000 [Pa];
        attribute differentialPressure : Pressure;

        constraint pressureDropLimit {
            differentialPressure <= cloggedPressureDropLimit
        }
    }

    part def IsolationValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute openingPercent : ScalarValues::Real = 100.0;
        attribute ratedPressure : Pressure = 1600000 [Pa];
        attribute pressureDrop : Pressure;

        constraint validOpening {
            openingPercent >= 0.0 and openingPercent <= 100.0
        }
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute crackingPressure : Pressure = 5000 [Pa];
        attribute reverseLeakageFlow : FlowRate = 0.000001 [m^3/s];
        attribute open : Boolean;
    }

    part def PipeSegment {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute internalDiameter : Length = 0.1 [m];
        attribute length : Length = 3.5 [m];
        attribute roughness : Length = 0.000045 [m];
        attribute pressureDrop : Pressure;
    }

    part def PressureSensor {
        port processPort : FluidPort;
        port statusOut : StatusPort;

        attribute rangeLow : Pressure = 0 [Pa];
        attribute rangeHigh : Pressure = 2000000 [Pa];
        attribute measuredPressure : Pressure;
        attribute accuracy : Pressure = 5000 [Pa];
        attribute healthy : Boolean = true;
    }

    part def FlowSensor {
        port processPort : FluidPort;
        port statusOut : StatusPort;

        attribute rangeLow : FlowRate = 0 [m^3/s];
        attribute rangeHigh : FlowRate = 0.05 [m^3/s];
        attribute measuredFlow : FlowRate;
        attribute accuracy : FlowRate = 0.00025 [m^3/s];
        attribute healthy : Boolean = true;
    }

    part def TemperatureSensor {
        port processPort : FluidPort;
        port statusOut : StatusPort;

        attribute measuredTemperature : Temperature;
        attribute rangeLow : Temperature = 273.15 [K];
        attribute rangeHigh : Temperature = 373.15 [K];
        attribute healthy : Boolean = true;
    }

    part def VariableFrequencyDrive {
        port electricalIn : PowerPort;
        port commandIn : CommandPort;
        port motorPowerOut : PowerPort;
        port statusOut : StatusPort;

        attribute commandedSpeed : AngularSpeed;
        attribute outputFrequency : ISQ::frequency;
        attribute outputVoltage : ISQ::electricPotential;
        attribute efficiency : Efficiency = 0.965;
        attribute enabled : Boolean;
        attribute faulted : Boolean = false;

        action def ConvertPower {
            in commandPercent : ScalarValues::Real;
            out frequency : ISQ::frequency;
            out voltage : ISQ::electricPotential;
        }

        state def VFDControl {
            state off;
            state ready;
            state ramping;
            state running;
            state fault;

            entry action off {
                enabled = false;
                outputFrequency = 0 [Hz];
            }

            transition first off;
            transition off_to_ready first off then ready
                if not faulted;
            transition ready_to_ramping first ready then ramping
                if commandIn.command.commandPercent > 0.0 and commandIn.command.valid;
            transition ramping_to_running first ramping then running
                if outputFrequency >= 49.5 [Hz];
            transition running_to_ready first running then ready
                if commandIn.command.commandPercent == 0.0;
            transition any_to_fault first off then fault
                if faulted;
        }
    }

    part def ElectricMotor {
        port powerIn : PowerPort;
        port shaftOut : MechanicalShaftPort;
        port statusOut : StatusPort;

        attribute ratedPower : Power = 15000 [W];
        attribute ratedSpeed : AngularSpeed = 314.16 [rad/s];
        attribute ratedVoltage : ISQ::electricPotential = 480 [V];
        attribute windingTemperature : Temperature;
        attribute efficiency : Efficiency = 0.93;
        attribute running : Boolean = false;
        attribute overload : Boolean = false;

        constraint motorPowerLimit {
            powerIn.powerFeed.activePower <= ratedPower * 1.15
        }
    }

    part def RotodynamicPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port shaftIn : MechanicalShaftPort;
        port statusOut : StatusPort;

        attribute designFlow : FlowRate = 0.025 [m^3/s];
        attribute designHead : Length = 55 [m];
        attribute designSpeed : AngularSpeed = 314.16 [rad/s];
        attribute minimumContinuousStableFlow : FlowRate = 0.008 [m^3/s];
        attribute maximumAllowableFlow : FlowRate = 0.04 [m^3/s];
        attribute hydraulicEfficiency : Efficiency = 0.78;
        attribute pumpEfficiency : Efficiency = 0.72;
        attribute requiredNPSH : Length = 3.0 [m];
        attribute availableNPSH : Length;
        attribute developedPressure : Pressure;
        attribute casingTemperature : Temperature;
        attribute vibrationVelocity : VibrationVelocity;
        attribute cavitationDetected : Boolean = false;
        attribute running : Boolean = false;

        constraint operatingFlowEnvelope {
            discharge.flowRate >= minimumContinuousStableFlow and
            discharge.flowRate <= maximumAllowableFlow
        }

        constraint npshMargin {
            availableNPSH >= requiredNPSH + 1.0 [m]
        }

        constraint vibrationLimit {
            vibrationVelocity <= 0.0045 [m/s]
        }

        action def AddKineticEnergyToFluid {
            in inletFluid : Fluid;
            in shaftSpeed : AngularSpeed;
            out outletFluid : Fluid;
            out pressureRise : Pressure;
        }

        state def PumpOperatingState {
            state stopped;
            state priming;
            state accelerating;
            state normalOperation;
            state lowFlowRecirculation;
            state cavitationWarning;
            state shutdown;
            state trip;

            entry action stopped {
                running = false;
                developedPressure = 0 [Pa];
            }

            entry action normalOperation {
                running = true;
                cavitationDetected = false;
            }

            entry action cavitationWarning {
                cavitationDetected = true;
            }

            transition initial_to_stopped first stopped;
            transition start_to_priming first stopped then priming
                if suction.pressure > suction.fluid.vaporPressure;
            transition primed_to_accelerating first priming then accelerating
                if suction.flowRate > 0.001 [m^3/s];
            transition speed_reached first accelerating then normalOperation
                if shaftIn.speed >= 0.95 * designSpeed;
            transition low_flow first normalOperation then lowFlowRecirculation
                if discharge.flowRate < minimumContinuousStableFlow;
            transition flow_restored first lowFlowRecirculation then normalOperation
                if discharge.flowRate >= minimumContinuousStableFlow;
            transition cavitation first normalOperation then cavitationWarning
                if availableNPSH < requiredNPSH;
            transition cavitation_cleared first cavitationWarning then normalOperation
                if availableNPSH >= requiredNPSH + 1.0 [m];
            transition stop_requested first normalOperation then shutdown
                if shaftIn.speed < 0.1 * designSpeed;
            transition shutdown_complete first shutdown then stopped
                if discharge.flowRate == 0 [m^3/s];
            transition protective_trip first normalOperation then trip
                if vibrationVelocity > 0.0071 [m/s] or casingTemperature > 363.15 [K];
        }
    }

    part def SealFlushSystem {
        port flushIn : FluidPort;
        port flushOut : FluidPort;

        attribute flushFlow : FlowRate = 0.00025 [m^3/s];
        attribute flushPressure : Pressure = 300000 [Pa];
        attribute sealChamberTemperature : Temperature;
        attribute healthy : Boolean = true;

        constraint flushPressureMargin {
            flushPressure >= 150000 [Pa]
        }
    }

    part def RecirculationLine {
        port pumpDischargeTap : FluidPort;
        port suctionReturn : FluidPort;

        part recircValve : IsolationValve;
        attribute minimumRecirculationFlow : FlowRate = 0.006 [m^3/s];
        attribute active : Boolean;
    }

    part def LocalController {
        port commandIn : CommandPort;
        port pumpStatusIn : StatusPort;
        port vfdCommandOut : CommandPort;
        port subsystemStatusOut : StatusPort;

        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute automaticMode : Boolean = true;
        attribute tripActive : Boolean = false;
        attribute lowFlowAlarm : Boolean = false;
        attribute highPressureAlarm : Boolean = false;
        attribute cavitationAlarm : Boolean = false;

        action def ExecuteStartSequence {
            out enableVFD : Boolean;
            out initialCommandPercent : ScalarValues::Real;
        }

        action def ExecuteProtectiveShutdown {
            out commandPercent : ScalarValues::Real;
            out trip : Boolean;
        }

        state def ControlMode {
            state idle;
            state permissiveCheck;
            state starting;
            state regulating;
            state stopping;
            state faulted;

            transition initial_idle first idle;
            transition idle_to_permissive first idle then permissiveCheck
                if startRequested and automaticMode;
            transition permissive_to_starting first permissiveCheck then starting
                if not tripActive;
            transition starting_to_regulating first starting then regulating
                if pumpStatusIn.status.running;
            transition regulating_to_stopping first regulating then stopping
                if stopRequested;
            transition stopping_to_idle first stopping then idle
                if not pumpStatusIn.status.running;
            transition trip_to_faulted first regulating then faulted
                if tripActive;
            transition reset_fault first faulted then idle
                if not tripActive and not startRequested;
        }
    }

    part def PumpingSubsystem {
        port suctionInterface : FluidPort;
        port dischargeInterface : FluidPort;
        port electricalSupply : PowerPort;
        port operatorCommand : CommandPort;
        port subsystemStatus : StatusPort;

        part suctionValve : IsolationValve;
        part suctionPipe : PipeSegment;
        part strainer : SuctionStrainer;
        part pump : RotodynamicPump;
        part motor : ElectricMotor;
        part vfd : VariableFrequencyDrive;
        part dischargePipe : PipeSegment;
        part checkValve : CheckValve;
        part dischargeValve : IsolationValve;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part temperatureSensor : TemperatureSensor;
        part sealFlush : SealFlushSystem;
        part recirculationLine : RecirculationLine;
        part controller : LocalController;

        attribute ratedFlow : FlowRate = 0.025 [m^3/s];
        attribute ratedDischargePressure : Pressure = 650000 [Pa];
        attribute maximumDischargePressure : Pressure = 1200000 [Pa];
        attribute minimumSuctionPressure : Pressure = 60000 [Pa];
        attribute fluidTemperatureLimit : Temperature = 358.15 [K];
        attribute availabilityTarget : ScalarValues::Real = 0.995;

        connect suctionInterface to suctionValve.inlet;
        connect suctionValve.outlet to suctionPipe.inlet;
        connect suctionPipe.outlet to strainer.inlet;
        connect strainer.outlet to pump.suction;
        connect pump.discharge to dischargePipe.inlet;
        connect dischargePipe.outlet to checkValve.inlet;
        connect checkValve.outlet to dischargeValve.inlet;
        connect dischargeValve.outlet to dischargeInterface;

        connect electricalSupply to vfd.electricalIn;
        connect vfd.motorPowerOut to motor.powerIn;
        connect motor.shaftOut to pump.shaftIn;

        connect operatorCommand to controller.commandIn;
        connect controller.vfdCommandOut to vfd.commandIn;
        connect pump.statusOut to controller.pumpStatusIn;
        connect controller.subsystemStatusOut to subsystemStatus;

        connect pump.discharge to recirculationLine.pumpDischargeTap;
        connect recirculationLine.suctionReturn to pump.suction;

        connect sealFlush.flushOut to pump.suction;
        connect suctionPressureSensor.processPort to pump.suction;
        connect dischargePressureSensor.processPort to pump.discharge;
        connect flowSensor.processPort to dischargeInterface;
        connect temperatureSensor.processPort to pump.discharge;

        constraint suctionPressurePermissive {
            suctionInterface.pressure >= minimumSuctionPressure
        }

        constraint dischargePressureProtection {
            dischargeInterface.pressure <= maximumDischargePressure
        }

        constraint temperatureProtection {
            dischargeInterface.temperature <= fluidTemperatureLimit
        }

        constraint nominalPerformance {
            dischargeInterface.flowRate >= 0.9 * ratedFlow and
            dischargeInterface.flowRate <= 1.1 * ratedFlow
        }

        action def PumpFluid {
            in incomingFluid : Fluid;
            in electricalPower : ElectricalPower;
            out deliveredFluid : Fluid;
            out deliveredFlow : FlowRate;
            out dischargePressure : Pressure;

            first start;
            then checkSuctionPermissive;
            then energizeDrive;
            then acceleratePump;
            then transferFluid;
            then regulateFlow;
            then reportStatus;
        }

        state def SubsystemLifecycle {
            state deenergized;
            state standby;
            state starting;
            state pumping;
            state recirculating;
            state stopping;
            state lockedOut;

            transition initial_deenergized first deenergized;
            transition powered first deenergized then standby
                if electricalSupply.powerFeed.voltage >= 430 [V];
            transition start_command first standby then starting
                if operatorCommand.command.commandPercent > 0.0;
            transition start_complete first starting then pumping
                if pump.running and dischargeInterface.flowRate >= pump.minimumContinuousStableFlow;
            transition low_demand first pumping then recirculating
                if dischargeInterface.flowRate < pump.minimumContinuousStableFlow;
            transition demand_restored first recirculating then pumping
                if dischargeInterface.flowRate >= pump.minimumContinuousStableFlow;
            transition stop_command first pumping then stopping
                if operatorCommand.command.commandPercent == 0.0;
            transition stopped first stopping then standby
                if not pump.running;
            transition lockout first pumping then lockedOut
                if dischargeInterface.pressure > maximumDischargePressure or
                   suctionInterface.pressure < minimumSuctionPressure or
                   dischargeInterface.temperature > fluidTemperatureLimit;
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : PumpingSubsystem;

        requirement fluidTransfer {
            doc /* The subsystem shall move process fluid from the suction interface to the discharge interface using a rotodynamic pump as the primary energy transfer device. */
            require constraint {
                subsystem.dischargeInterface.flowRate >= 0.9 * subsystem.ratedFlow
            }
        }

        requirement pressureIncrease {
            doc /* The rotodynamic pump shall increase fluid pressure to support the rated discharge pressure during nominal operation. */
            require constraint {
                subsystem.dischargeInterface.pressure >= subsystem.ratedDischargePressure
            }
        }

        requirement npshProtection {
            doc /* The subsystem shall operate the rotodynamic pump only when available net positive suction head exceeds required net positive suction head by at least one meter. */
            require constraint {
                subsystem.pump.availableNPSH >= subsystem.pump.requiredNPSH + 1.0 [m]
            }
        }

        requirement lowFlowProtection {
            doc /* The subsystem shall provide recirculation or shutdown protection when discharge flow falls below the minimum continuous stable flow of the pump. */
            require constraint {
                subsystem.dischargeInterface.flowRate >= subsystem.pump.minimumContinuousStableFlow or
                subsystem.recirculationLine.active
            }
        }

        requirement reverseFlowPrevention {
            doc /* The discharge check valve shall prevent sustained reverse flow from the discharge interface toward the pump. */
            require constraint {
                subsystem.checkValve.reverseLeakageFlow <= 0.000001 [m^3/s]
            }
        }

        requirement instrumentation {
            doc /* The subsystem shall measure suction pressure, discharge pressure, discharge flow, and fluid temperature for control and protection. */
            require constraint {
                subsystem.suctionPressureSensor.healthy and
                subsystem.dischargePressureSensor.healthy and
                subsystem.flowSensor.healthy and
                subsystem.temperatureSensor.healthy
            }
        }

        requirement driveControl {
            doc /* The variable frequency drive shall regulate motor speed according to controller command while limiting electrical power delivered to the motor. */
            require constraint {
                subsystem.vfd.enabled implies
                subsystem.motor.powerIn.powerFeed.activePower <= subsystem.motor.ratedPower * 1.15
            }
        }

        requirement overpressureProtection {
            doc /* The subsystem shall trip or prevent operation when discharge pressure exceeds the maximum allowable discharge pressure. */
            require constraint {
                subsystem.dischargeInterface.pressure <= subsystem.maximumDischargePressure
            }
        }

        requirement thermalProtection {
            doc /* The subsystem shall trip or prevent operation when fluid temperature exceeds the allowable temperature limit. */
            require constraint {
                subsystem.dischargeInterface.temperature <= subsystem.fluidTemperatureLimit
            }
        }
    }

    part pumpingSubsystem : PumpingSubsystem {
        attribute ratedFlow = 0.025 [m^3/s];
        attribute ratedDischargePressure = 650000 [Pa];
        attribute maximumDischargePressure = 1200000 [Pa];
        attribute minimumSuctionPressure = 60000 [Pa];
        attribute fluidTemperatureLimit = 358.15 [K];
    }

    satisfy PumpingSubsystemRequirement::fluidTransfer by pumpingSubsystem;
    satisfy PumpingSubsystemRequirement::pressureIncrease by pumpingSubsystem.pump;
    satisfy PumpingSubsystemRequirement::npshProtection by pumpingSubsystem.pump;
    satisfy PumpingSubsystemRequirement::lowFlowProtection by pumpingSubsystem.recirculationLine;
    satisfy PumpingSubsystemRequirement::reverseFlowPrevention by pumpingSubsystem.checkValve;
    satisfy PumpingSubsystemRequirement::instrumentation by pumpingSubsystem.suctionPressureSensor;
    satisfy PumpingSubsystemRequirement::instrumentation by pumpingSubsystem.dischargePressureSensor;
    satisfy PumpingSubsystemRequirement::instrumentation by pumpingSubsystem.flowSensor;
    satisfy PumpingSubsystemRequirement::instrumentation by pumpingSubsystem.temperatureSensor;
    satisfy PumpingSubsystemRequirement::driveControl by pumpingSubsystem.vfd;
    satisfy PumpingSubsystemRequirement::overpressureProtection by pumpingSubsystem.controller;
    satisfy PumpingSubsystemRequirement::thermalProtection by pumpingSubsystem.controller;
}