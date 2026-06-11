package PistonlessPumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> ISQ::pressure;
        unit = SI::pascal;
    }

    attribute def FlowRate {
        :> ISQ::volumeFlowRate;
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Volume {
        :> ISQ::volume;
        unit = SI::cubicMetre;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = SI::kelvin;
    }

    attribute def AngularSpeed {
        :> ISQ::angularVelocity;
        unit = SI::radianPerSecond;
    }

    attribute def ElectricPower {
        :> ISQ::power;
        unit = SI::watt;
    }

    attribute def Efficiency {
        :> ScalarValues::Real;
    }

    attribute def Viscosity {
        :> ISQ::dynamicViscosity;
        unit = SI::pascal * SI::second;
    }

    item def WorkingFluid {
        attribute density : ISQ::density;
        attribute dynamicViscosity : Viscosity;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
        attribute contaminationClass : String;
    }

    item def ElectricalEnergy {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
        attribute power : ElectricPower;
    }

    item def ControlCommand {
        attribute requestedFlowRate : FlowRate;
        attribute requestedOutletPressure : Pressure;
        attribute enable : Boolean;
        attribute emergencyStop : Boolean;
    }

    item def PumpTelemetry {
        attribute measuredInletPressure : Pressure;
        attribute measuredOutletPressure : Pressure;
        attribute measuredFlowRate : FlowRate;
        attribute measuredMotorSpeed : AngularSpeed;
        attribute measuredFluidTemperature : Temperature;
        attribute faultActive : Boolean;
        attribute operatingState : String;
    }

    port def FluidInletPort {
        in item fluid : WorkingFluid;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    port def FluidOutletPort {
        out item fluid : WorkingFluid;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPowerPort {
        in item energy : ElectricalEnergy;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def TelemetryPort {
        out item telemetry : PumpTelemetry;
    }

    port def MechanicalDrivePort {
        inout attribute shaftSpeed : AngularSpeed;
        inout attribute transmittedPower : ElectricPower;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 3000 [SI::pascal];
        attribute reverseLeakageRate : FlowRate = 1.0e-8 [SI::cubicMetrePerSecond];
        attribute open : Boolean;

        port upstream : FluidInletPort;
        port downstream : FluidOutletPort;

        state def ValveState {
            state closed;
            state opening;
            state openState;
            state faulted;

            entry; then closed;

            transition closed_to_opening
                first closed
                accept when upstream.pressure - downstream.pressure > crackingPressure
                then opening;

            transition opening_to_open
                first opening
                accept after 0.05 [SI::second]
                then openState;

            transition open_to_closed
                first openState
                accept when upstream.pressure <= downstream.pressure
                then closed;

            transition any_to_faulted
                first closed
                accept when reverseLeakageRate > 5.0e-7 [SI::cubicMetrePerSecond]
                then faulted;
        }

        exhibit state valveBehavior : ValveState;
    }

    part def PressureSensor {
        attribute rangeMinimum : Pressure = 0 [SI::pascal];
        attribute rangeMaximum : Pressure = 2000000 [SI::pascal];
        attribute accuracy : Pressure = 5000 [SI::pascal];
        attribute measuredPressure : Pressure;

        port sensedFluid : FluidInletPort;
    }

    part def TemperatureSensor {
        attribute rangeMinimum : Temperature = 273.15 [SI::kelvin];
        attribute rangeMaximum : Temperature = 423.15 [SI::kelvin];
        attribute accuracy : Temperature = 0.5 [SI::kelvin];
        attribute measuredTemperature : Temperature;

        port sensedFluid : FluidInletPort;
    }

    part def FlowSensor {
        attribute rangeMinimum : FlowRate = 0 [SI::cubicMetrePerSecond];
        attribute rangeMaximum : FlowRate = 0.01 [SI::cubicMetrePerSecond];
        attribute accuracy : FlowRate = 0.00005 [SI::cubicMetrePerSecond];
        attribute measuredFlowRate : FlowRate;

        port sensedFlow : FluidOutletPort;
    }

    part def VariableSpeedMotor {
        attribute ratedPower : ElectricPower = 1500 [SI::watt];
        attribute maximumSpeed : AngularSpeed = 314.16 [SI::radianPerSecond];
        attribute commandedSpeed : AngularSpeed;
        attribute actualSpeed : AngularSpeed;
        attribute motorEfficiency : Efficiency = 0.88;

        port electricalInput : ElectricalPowerPort;
        port driveOutput : MechanicalDrivePort;

        action def RegulateSpeed {
            in targetSpeed : AngularSpeed;
            out shaftSpeed : AngularSpeed;

            action computeSpeed {
                out result : AngularSpeed = targetSpeed;
            }

            action limitSpeed {
                in requested : AngularSpeed = computeSpeed.result;
                out limited : AngularSpeed;
            }

            flow computeSpeed.result to limitSpeed.requested;
            flow limitSpeed.limited to shaftSpeed;
        }

        perform action speedControl : RegulateSpeed {
            in targetSpeed = commandedSpeed;
            out shaftSpeed = actualSpeed;
        }
    }

    part def PistonlessPumpCore {
        attribute displacementPerRevolution : Volume = 1.6e-5 [SI::cubicMetre];
        attribute volumetricEfficiency : Efficiency = 0.82;
        attribute mechanicalEfficiency : Efficiency = 0.76;
        attribute maximumDifferentialPressure : Pressure = 800000 [SI::pascal];
        attribute minimumNPSHRequired : Pressure = 35000 [SI::pascal];
        attribute trappedGasFraction : Real = 0.0;
        attribute internalSlipFlow : FlowRate;
        attribute deliveredFlowRate : FlowRate;

        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port shaft : MechanicalDrivePort;

        part inletCheckValve : CheckValve;
        part outletCheckValve : CheckValve;

        connect suction to inletCheckValve.upstream;
        connect inletCheckValve.downstream to outletCheckValve.upstream;
        connect outletCheckValve.downstream to discharge;

        action def TransferFluidWithoutPiston {
            in inletFluid : WorkingFluid;
            in shaftSpeed : AngularSpeed;
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            out outletFluid : WorkingFluid;
            out flow : FlowRate;

            action admitFluid {
                in fluid : WorkingFluid = inletFluid;
                out admittedFluid : WorkingFluid;
            }

            action displaceByRotatingSeallessChamber {
                in fluid : WorkingFluid = admitFluid.admittedFluid;
                in speed : AngularSpeed = shaftSpeed;
                out displacedFluid : WorkingFluid;
                out theoreticalFlow : FlowRate;
            }

            action compensateSlip {
                in theoreticalFlow : FlowRate = displaceByRotatingSeallessChamber.theoreticalFlow;
                in deltaPressure : Pressure;
                out correctedFlow : FlowRate;
            }

            action dischargeFluid {
                in fluid : WorkingFluid = displaceByRotatingSeallessChamber.displacedFluid;
                in correctedFlow : FlowRate = compensateSlip.correctedFlow;
                out pumpedFluid : WorkingFluid;
                out deliveredFlow : FlowRate;
            }

            flow admitFluid.admittedFluid to displaceByRotatingSeallessChamber.fluid;
            flow displaceByRotatingSeallessChamber.displacedFluid to dischargeFluid.fluid;
            flow displaceByRotatingSeallessChamber.theoreticalFlow to compensateSlip.theoreticalFlow;
            flow compensateSlip.correctedFlow to dischargeFluid.correctedFlow;
            flow dischargeFluid.pumpedFluid to outletFluid;
            flow dischargeFluid.deliveredFlow to flow;
        }

        perform action pumpingAction : TransferFluidWithoutPiston {
            in inletFluid = suction.fluid;
            in shaftSpeed = shaft.shaftSpeed;
            in inletPressure = suction.pressure;
            in outletPressure = discharge.pressure;
            out outletFluid = discharge.fluid;
            out flow = deliveredFlowRate;
        }
    }

    part def Controller {
        attribute enabled : Boolean;
        attribute faultLatched : Boolean;
        attribute targetFlowRate : FlowRate;
        attribute targetPressure : Pressure;
        attribute targetMotorSpeed : AngularSpeed;

        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        action def ComputeMotorSpeed {
            in requestedFlow : FlowRate;
            in measuredFlow : FlowRate;
            in pressureError : Pressure;
            out speedCommand : AngularSpeed;

            action proportionalFlowControl {
                out flowSpeedTerm : AngularSpeed;
            }

            action pressureTrim {
                out pressureSpeedTerm : AngularSpeed;
            }

            action combineAndLimit {
                in flowTerm : AngularSpeed = proportionalFlowControl.flowSpeedTerm;
                in pressureTerm : AngularSpeed = pressureTrim.pressureSpeedTerm;
                out limitedSpeed : AngularSpeed;
            }

            flow proportionalFlowControl.flowSpeedTerm to combineAndLimit.flowTerm;
            flow pressureTrim.pressureSpeedTerm to combineAndLimit.pressureTerm;
            flow combineAndLimit.limitedSpeed to speedCommand;
        }

        state def ControllerState {
            state off;
            state standby;
            state priming;
            state regulating;
            state fault;

            entry; then off;

            transition off_to_standby
                first off
                accept when commandInput.command.enable and not commandInput.command.emergencyStop
                then standby;

            transition standby_to_priming
                first standby
                accept when commandInput.command.requestedFlowRate > 0 [SI::cubicMetrePerSecond]
                then priming;

            transition priming_to_regulating
                first priming
                accept after 3 [SI::second]
                then regulating;

            transition regulating_to_standby
                first regulating
                accept when commandInput.command.requestedFlowRate == 0 [SI::cubicMetrePerSecond]
                then standby;

            transition any_to_fault
                first off
                accept when commandInput.command.emergencyStop
                then fault;

            transition fault_to_off
                first fault
                accept when not commandInput.command.enable and not commandInput.command.emergencyStop
                then off;
        }

        exhibit state controllerBehavior : ControllerState;
    }

    part def ReliefValve {
        attribute setPressure : Pressure = 900000 [SI::pascal];
        attribute reseatPressure : Pressure = 820000 [SI::pascal];
        attribute bypassFlowRate : FlowRate;
        attribute open : Boolean;

        port highPressureSide : FluidInletPort;
        port lowPressureSide : FluidOutletPort;

        state def ReliefValveState {
            state closed;
            state relieving;

            entry; then closed;

            transition closed_to_relieving
                first closed
                accept when highPressureSide.pressure >= setPressure
                then relieving;

            transition relieving_to_closed
                first relieving
                accept when highPressureSide.pressure <= reseatPressure
                then closed;
        }

        exhibit state reliefBehavior : ReliefValveState;
    }

    part def PistonlessPumpingSubsystem {
        attribute nominalFlowRate : FlowRate = 0.002 [SI::cubicMetrePerSecond];
        attribute maximumFlowRate : FlowRate = 0.004 [SI::cubicMetrePerSecond];
        attribute nominalOutletPressure : Pressure = 600000 [SI::pascal];
        attribute maximumOutletPressure : Pressure = 850000 [SI::pascal];
        attribute minimumInletPressure : Pressure = 70000 [SI::pascal];
        attribute allowedFluidTemperatureMinimum : Temperature = 278.15 [SI::kelvin];
        attribute allowedFluidTemperatureMaximum : Temperature = 353.15 [SI::kelvin];
        attribute totalElectricalPowerLimit : ElectricPower = 1800 [SI::watt];

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port powerInput : ElectricalPowerPort;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        part pumpCore : PistonlessPumpCore;
        part driveMotor : VariableSpeedMotor;
        part controller : Controller;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part fluidTemperatureSensor : TemperatureSensor;
        part outletFlowSensor : FlowSensor;
        part overPressureRelief : ReliefValve;

        connect inlet to pumpCore.suction;
        connect pumpCore.discharge to outlet;
        connect powerInput to driveMotor.electricalInput;
        connect driveMotor.driveOutput to pumpCore.shaft;
        connect commandInput to controller.commandInput;
        connect controller.telemetryOutput to telemetryOutput;
        connect inlet to inletPressureSensor.sensedFluid;
        connect outlet to outletPressureSensor.sensedFluid;
        connect inlet to fluidTemperatureSensor.sensedFluid;
        connect outlet to outletFlowSensor.sensedFlow;
        connect outlet to overPressureRelief.highPressureSide;
        connect overPressureRelief.lowPressureSide to inlet;

        action def StartPump {
            in command : ControlCommand;
            out ready : Boolean;

            action verifyCommandEnable;
            action verifyFluidAvailable;
            action energizeMotor;
            action primePumpCore;
            action declareReady;

            succession verifyCommandEnable then verifyFluidAvailable;
            succession verifyFluidAvailable then energizeMotor;
            succession energizeMotor then primePumpCore;
            succession primePumpCore then declareReady;
        }

        action def StopPump {
            out stopped : Boolean;

            action rampDownMotor;
            action closeDischargePath;
            action reportStopped;

            succession rampDownMotor then closeDischargePath;
            succession closeDischargePath then reportStopped;
        }

        action def ProtectPump {
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            in fluidTemperature : Temperature;
            out faultActive : Boolean;

            action detectDryRun;
            action detectOverPressure;
            action detectOverTemperature;
            action latchFault;

            succession detectDryRun then latchFault;
            succession detectOverPressure then latchFault;
            succession detectOverTemperature then latchFault;
        }

        state def PumpingSubsystemState {
            state deenergized;
            state idle;
            state starting;
            state primed;
            state pumping;
            state stopping;
            state faulted;

            entry; then deenergized;

            transition deenergized_to_idle
                first deenergized
                accept when commandInput.command.enable and not commandInput.command.emergencyStop
                then idle;

            transition idle_to_starting
                first idle
                accept when commandInput.command.requestedFlowRate > 0 [SI::cubicMetrePerSecond]
                do StartPump
                then starting;

            transition starting_to_primed
                first starting
                accept after 3 [SI::second]
                then primed;

            transition primed_to_pumping
                first primed
                accept when inlet.pressure >= minimumInletPressure
                then pumping;

            transition pumping_to_stopping
                first pumping
                accept when commandInput.command.requestedFlowRate == 0 [SI::cubicMetrePerSecond]
                do StopPump
                then stopping;

            transition stopping_to_idle
                first stopping
                accept after 2 [SI::second]
                then idle;

            transition pumping_to_faulted_low_inlet_pressure
                first pumping
                accept when inlet.pressure < minimumInletPressure
                do ProtectPump
                then faulted;

            transition pumping_to_faulted_overpressure
                first pumping
                accept when outlet.pressure > maximumOutletPressure
                do ProtectPump
                then faulted;

            transition pumping_to_faulted_overtemperature
                first pumping
                accept when inlet.temperature > allowedFluidTemperatureMaximum
                do ProtectPump
                then faulted;

            transition any_to_faulted_emergency_stop
                first deenergized
                accept when commandInput.command.emergencyStop
                do StopPump
                then faulted;

            transition faulted_to_deenergized
                first faulted
                accept when not commandInput.command.enable and not commandInput.command.emergencyStop
                then deenergized;
        }

        exhibit state subsystemBehavior : PumpingSubsystemState;
    }

    requirement def PistonlessPumpRequirement {
        subject subsystem : PistonlessPumpingSubsystem;
    }

    requirement req noPistonMechanism : PistonlessPumpRequirement {
        doc /* The pumping subsystem shall move fluid without using a reciprocating piston, piston rod, piston seal, or cylinder bore as the primary displacement element. */
    }

    requirement req nominalFlowCapability : PistonlessPumpRequirement {
        doc /* The pumping subsystem shall deliver at least 0.002 cubic metre per second of working fluid at nominal operating conditions. */
        require constraint {
            subsystem.outlet.flowRate >= subsystem.nominalFlowRate
        }
    }

    requirement req maximumFlowLimit : PistonlessPumpRequirement {
        doc /* The pumping subsystem shall limit commanded delivery flow to no more than 0.004 cubic metre per second. */
        require constraint {
            subsystem.outlet.flowRate <= subsystem.maximumFlowRate
        }
    }

    requirement req outletPressureCapability : PistonlessPumpRequirement {
        doc /* The subsystem shall sustain a nominal outlet pressure of 600000 pascal during continuous pumping operation. */
        require constraint {
            subsystem.outlet.pressure >= subsystem.nominalOutletPressure
        }
    }

    requirement req overPressureProtection : PistonlessPumpRequirement {
        doc /* The subsystem shall transition to a protected fault condition or open the relief path before outlet pressure exceeds 900000 pascal. */
        require constraint {
            subsystem.outlet.pressure <= 900000 [SI::pascal]
        }
    }

    requirement req inletPressureProtection : PistonlessPumpRequirement {
        doc /* The subsystem shall stop pumping if inlet pressure falls below 70000 pascal to prevent dry running and cavitation. */
        require constraint {
            subsystem.inlet.pressure >= subsystem.minimumInletPressure
        }
    }

    requirement req fluidTemperatureRange : PistonlessPumpRequirement {
        doc /* The subsystem shall operate only when working fluid temperature is between 278.15 kelvin and 353.15 kelvin. */
        require constraint {
            subsystem.inlet.temperature >= subsystem.allowedFluidTemperatureMinimum and
            subsystem.inlet.temperature <= subsystem.allowedFluidTemperatureMaximum
        }
    }

    requirement req powerLimit : PistonlessPumpRequirement {
        doc /* The subsystem shall consume no more than 1800 watt of electrical power during continuous nominal operation. */
        require constraint {
            subsystem.powerInput.energy.power <= subsystem.totalElectricalPowerLimit
        }
    }

    requirement req telemetryRequirement : PistonlessPumpRequirement {
        doc /* The subsystem shall provide telemetry for inlet pressure, outlet pressure, flow rate, motor speed, fluid temperature, fault status, and operating state. */
    }

    satisfy noPistonMechanism by PistonlessPumpingSubsystem::pumpCore;
    satisfy nominalFlowCapability by PistonlessPumpingSubsystem::pumpCore;
    satisfy maximumFlowLimit by PistonlessPumpingSubsystem::controller;
    satisfy outletPressureCapability by PistonlessPumpingSubsystem::pumpCore;
    satisfy overPressureProtection by PistonlessPumpingSubsystem::overPressureRelief;
    satisfy inletPressureProtection by PistonlessPumpingSubsystem::controller;
    satisfy fluidTemperatureRange by PistonlessPumpingSubsystem::controller;
    satisfy powerLimit by PistonlessPumpingSubsystem::driveMotor;
    satisfy telemetryRequirement by PistonlessPumpingSubsystem::controller;

    constraint def PumpHydraulicPower {
        in pressureRise : Pressure;
        in flowRate : FlowRate;
        out hydraulicPower : ElectricPower;

        hydraulicPower == pressureRise * flowRate;
    }

    constraint def PumpFlowEstimate {
        in displacementPerRevolution : Volume;
        in shaftSpeed : AngularSpeed;
        in volumetricEfficiency : Efficiency;
        out estimatedFlow : FlowRate;

        estimatedFlow == displacementPerRevolution * shaftSpeed * volumetricEfficiency / (2 * 3.141592653589793);
    }

    constraint def SafeOperatingEnvelope {
        in inletPressure : Pressure;
        in outletPressure : Pressure;
        in fluidTemperature : Temperature;
        in flowRate : FlowRate;

        inletPressure >= 70000 [SI::pascal] and
        outletPressure <= 850000 [SI::pascal] and
        fluidTemperature >= 278.15 [SI::kelvin] and
        fluidTemperature <= 353.15 [SI::kelvin] and
        flowRate <= 0.004 [SI::cubicMetrePerSecond];
    }

    analysis def VerifyNominalHydraulicPerformance {
        subject subsystem : PistonlessPumpingSubsystem;

        objective {
            verify nominalFlowCapability;
            verify outletPressureCapability;
            verify powerLimit;
        }

        constraint hydraulicPower : PumpHydraulicPower {
            in pressureRise = subsystem.outlet.pressure - subsystem.inlet.pressure;
            in flowRate = subsystem.outlet.flowRate;
        }

        constraint safeEnvelope : SafeOperatingEnvelope {
            in inletPressure = subsystem.inlet.pressure;
            in outletPressure = subsystem.outlet.pressure;
            in fluidTemperature = subsystem.inlet.temperature;
            in flowRate = subsystem.outlet.flowRate;
        }
    }

    part pumpingSubsystem : PistonlessPumpingSubsystem;

}