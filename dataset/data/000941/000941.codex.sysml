package SolarPoweredPumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def VolumetricFlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def Irradiance :> Real {
        unit = "W/m^2";
    }

    attribute def ElectricPower :> Real {
        unit = "W";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Energy :> Real {
        unit = "J";
    }

    attribute def Volume :> Real {
        unit = "m^3";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    item def Fluid {
        attribute density : Real = 998.0;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : ElectricPower;
    }

    item def SolarRadiation {
        attribute irradiance : Irradiance;
        attribute ambientTemperature : Temperature;
    }

    item def ControlSignal {
        attribute enabled : Boolean;
        attribute targetFlowRate : VolumetricFlowRate;
        attribute commandedSpeed : RotationalSpeed;
    }

    item def FaultSignal {
        attribute active : Boolean;
        attribute code : String;
    }

    port def FluidInletPort {
        in item incomingFluid : Fluid;
    }

    port def FluidOutletPort {
        out item outgoingFluid : Fluid;
    }

    port def ElectricalInputPort {
        in item suppliedPower : ElectricalEnergy;
    }

    port def ElectricalOutputPort {
        out item generatedPower : ElectricalEnergy;
    }

    port def SolarInputPort {
        in item sunlight : SolarRadiation;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def StatusOutputPort {
        out item fault : FaultSignal;
        out item measuredFlow : Fluid;
        out item measuredPower : ElectricalEnergy;
    }

    part def SolarPanelArray {
        port solarInput : SolarInputPort;
        port dcOutput : ElectricalOutputPort;

        attribute panelArea : Real = 8.0;
        attribute conversionEfficiency : Efficiency = 0.21;
        attribute nominalVoltage : Voltage = 48.0;
        attribute maxPower : ElectricPower = 1600.0;
        attribute minimumOperatingIrradiance : Irradiance = 150.0;
        attribute cellTemperature : Temperature;

        action generateDcPower {
            in item radiation : SolarRadiation;
            out item powerOut : ElectricalEnergy;

            first start;
            then computeAvailablePower;
            then limitToRatedPower;
            then emitElectricalEnergy;
            then done;

            action computeAvailablePower {
                in item radiation : SolarRadiation;
                out attribute availablePower : ElectricPower;
            }

            action limitToRatedPower {
                in attribute availablePower : ElectricPower;
                out item limitedPower : ElectricalEnergy;
            }

            action emitElectricalEnergy {
                in item limitedPower : ElectricalEnergy;
                out item powerOut : ElectricalEnergy;
            }
        }

        state machine panelOperatingStates {
            state off;
            state producing;
            state lowIrradiance;
            state overTemperature;

            entry; then off;

            transition off_to_producing
                first off
                accept when solarInput.sunlight.irradiance >= minimumOperatingIrradiance
                then producing;

            transition producing_to_lowIrradiance
                first producing
                accept when solarInput.sunlight.irradiance < minimumOperatingIrradiance
                then lowIrradiance;

            transition lowIrradiance_to_producing
                first lowIrradiance
                accept when solarInput.sunlight.irradiance >= minimumOperatingIrradiance
                then producing;

            transition producing_to_overTemperature
                first producing
                accept when cellTemperature > 85.0
                then overTemperature;

            transition overTemperature_to_producing
                first overTemperature
                accept when cellTemperature <= 75.0
                then producing;
        }
    }

    part def PowerConditioner {
        port dcInput : ElectricalInputPort;
        port regulatedOutput : ElectricalOutputPort;
        port status : StatusOutputPort;

        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage = 48.0;
        attribute maxOutputCurrent : Current = 35.0;
        attribute converterEfficiency : Efficiency = 0.94;
        attribute undervoltageLimit : Voltage = 36.0;
        attribute overvoltageLimit : Voltage = 60.0;

        action regulatePower {
            in item rawPower : ElectricalEnergy;
            out item conditionedPower : ElectricalEnergy;

            first senseInput;
            then validateVoltage;
            then convertVoltage;
            then provideOutput;
            then done;

            action senseInput;
            action validateVoltage;
            action convertVoltage;
            action provideOutput;
        }

        state machine conditionerStates {
            state disabled;
            state regulating;
            state undervoltageFault;
            state overvoltageFault;

            entry; then disabled;

            transition disabled_to_regulating
                first disabled
                accept when dcInput.suppliedPower.voltage >= undervoltageLimit and dcInput.suppliedPower.voltage <= overvoltageLimit
                then regulating;

            transition regulating_to_undervoltageFault
                first regulating
                accept when dcInput.suppliedPower.voltage < undervoltageLimit
                then undervoltageFault;

            transition regulating_to_overvoltageFault
                first regulating
                accept when dcInput.suppliedPower.voltage > overvoltageLimit
                then overvoltageFault;

            transition undervoltageFault_to_regulating
                first undervoltageFault
                accept when dcInput.suppliedPower.voltage >= undervoltageLimit
                then regulating;

            transition overvoltageFault_to_regulating
                first overvoltageFault
                accept when dcInput.suppliedPower.voltage <= overvoltageLimit
                then regulating;
        }
    }

    part def PumpMotor {
        port powerInput : ElectricalInputPort;
        port controlInput : ControlInputPort;
        port status : StatusOutputPort;

        attribute ratedPower : ElectricPower = 1200.0;
        attribute ratedVoltage : Voltage = 48.0;
        attribute maxCurrent : Current = 30.0;
        attribute motorEfficiency : Efficiency = 0.88;
        attribute shaftSpeed : RotationalSpeed;
        attribute motorTemperature : Temperature;
        attribute overTemperatureLimit : Temperature = 95.0;

        action convertElectricalToMechanicalPower {
            in item electricalInput : ElectricalEnergy;
            in item command : ControlSignal;
            out attribute speed : RotationalSpeed;

            first checkCommand;
            then computeTorqueSpeed;
            then applySpeedLimit;
            then done;

            action checkCommand;
            action computeTorqueSpeed;
            action applySpeedLimit;
        }

        state machine motorStates {
            state stopped;
            state starting;
            state running;
            state thermalShutdown;
            state electricalFault;

            entry; then stopped;

            transition stopped_to_starting
                first stopped
                accept when controlInput.command.enabled
                then starting;

            transition starting_to_running
                first starting
                accept when shaftSpeed > 300.0
                then running;

            transition running_to_stopped
                first running
                accept when not controlInput.command.enabled
                then stopped;

            transition running_to_thermalShutdown
                first running
                accept when motorTemperature >= overTemperatureLimit
                then thermalShutdown;

            transition thermalShutdown_to_stopped
                first thermalShutdown
                accept when motorTemperature < 80.0 and not controlInput.command.enabled
                then stopped;

            transition running_to_electricalFault
                first running
                accept when powerInput.suppliedPower.current > maxCurrent
                then electricalFault;

            transition electricalFault_to_stopped
                first electricalFault
                accept when not controlInput.command.enabled
                then stopped;
        }
    }

    part def CentrifugalPump {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port controlInput : ControlInputPort;
        port status : StatusOutputPort;

        attribute impellerSpeed : RotationalSpeed;
        attribute nominalFlowRate : VolumetricFlowRate = 0.004;
        attribute minimumFlowRate : VolumetricFlowRate = 0.0007;
        attribute maximumFlowRate : VolumetricFlowRate = 0.006;
        attribute nominalPressureRise : Pressure = 250000.0;
        attribute hydraulicEfficiency : Efficiency = 0.72;
        attribute dryRunDetected : Boolean = false;

        action moveFluid {
            in item inletFluid : Fluid;
            in attribute speed : RotationalSpeed;
            out item outletFluid : Fluid;

            first admitFluid;
            then addHydraulicEnergy;
            then produceDischargeFlow;
            then done;

            action admitFluid;
            action addHydraulicEnergy;
            action produceDischargeFlow;
        }

        state machine pumpStates {
            state idle;
            state priming;
            state pumping;
            state dryRunFault;
            state blockedDischargeFault;

            entry; then idle;

            transition idle_to_priming
                first idle
                accept when controlInput.command.enabled
                then priming;

            transition priming_to_pumping
                first priming
                accept when suction.incomingFluid.pressure > 50000.0
                then pumping;

            transition pumping_to_idle
                first pumping
                accept when not controlInput.command.enabled
                then idle;

            transition pumping_to_dryRunFault
                first pumping
                accept when suction.incomingFluid.flowRate < minimumFlowRate
                then dryRunFault;

            transition pumping_to_blockedDischargeFault
                first pumping
                accept when discharge.outgoingFluid.pressure > 450000.0
                then blockedDischargeFault;

            transition dryRunFault_to_idle
                first dryRunFault
                accept when not controlInput.command.enabled
                then idle;

            transition blockedDischargeFault_to_idle
                first blockedDischargeFault
                accept when not controlInput.command.enabled
                then idle;
        }
    }

    part def IntakeFilter {
        port rawFluidIn : FluidInletPort;
        port filteredFluidOut : FluidOutletPort;

        attribute meshSize : Real = 0.0005;
        attribute pressureDropAtNominalFlow : Pressure = 12000.0;
        attribute cloggingFactor : Real = 0.0;
        attribute cloggingLimit : Real = 0.8;

        action filterFluid {
            in item rawFluid : Fluid;
            out item filteredFluid : Fluid;

            first captureDebris;
            then reducePressure;
            then passFilteredFluid;
            then done;

            action captureDebris;
            action reducePressure;
            action passFilteredFluid;
        }
    }

    part def CheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : Pressure = 8000.0;
        attribute reverseLeakageRate : VolumetricFlowRate = 0.00001;
        attribute open : Boolean;

        state machine valveStates {
            state closed;
            state openForwardFlow;

            entry; then closed;

            transition closed_to_openForwardFlow
                first closed
                accept when inlet.incomingFluid.pressure - outlet.outgoingFluid.pressure > crackingPressure
                then openForwardFlow;

            transition openForwardFlow_to_closed
                first openForwardFlow
                accept when inlet.incomingFluid.pressure <= outlet.outgoingFluid.pressure
                then closed;
        }
    }

    part def FlowAndPressureSensor {
        port sensedFluidIn : FluidInletPort;
        port sensedFluidOut : FluidOutletPort;
        port status : StatusOutputPort;

        attribute measuredFlowRate : VolumetricFlowRate;
        attribute measuredPressure : Pressure;
        attribute accuracyFlow : Real = 0.03;
        attribute accuracyPressure : Real = 0.02;

        action measureHydraulicState {
            in item fluid : Fluid;
            out item measuredFluid : Fluid;

            first sampleFlow;
            then samplePressure;
            then publishMeasurement;
            then done;

            action sampleFlow;
            action samplePressure;
            action publishMeasurement;
        }
    }

    part def PumpController {
        port commandInput : ControlInputPort;
        port motorCommand : ControlInputPort;
        port pumpCommand : ControlInputPort;
        port sensorStatus : StatusOutputPort;
        port powerStatus : StatusOutputPort;
        port systemStatus : StatusOutputPort;

        attribute targetFlowRate : VolumetricFlowRate = 0.0035;
        attribute lowFlowLimit : VolumetricFlowRate = 0.0007;
        attribute highPressureLimit : Pressure = 450000.0;
        attribute minimumPowerToStart : ElectricPower = 350.0;
        attribute commandedSpeed : RotationalSpeed;
        attribute faultLatched : Boolean = false;

        action controlPumping {
            in item requestedCommand : ControlSignal;
            in item measuredFluid : Fluid;
            in item measuredPower : ElectricalEnergy;
            out item motorControl : ControlSignal;
            out item pumpControl : ControlSignal;
            out item faultStatus : FaultSignal;

            first evaluateStartConditions;
            then computeSpeedCommand;
            then protectAgainstFaults;
            then publishCommands;
            then done;

            action evaluateStartConditions;
            action computeSpeedCommand;
            action protectAgainstFaults;
            action publishCommands;
        }

        state machine controllerStates {
            state standby;
            state enabling;
            state closedLoopControl;
            state faulted;

            entry; then standby;

            transition standby_to_enabling
                first standby
                accept when commandInput.command.enabled
                then enabling;

            transition enabling_to_closedLoopControl
                first enabling
                accept when powerStatus.measuredPower.power >= minimumPowerToStart
                then closedLoopControl;

            transition closedLoopControl_to_standby
                first closedLoopControl
                accept when not commandInput.command.enabled
                then standby;

            transition closedLoopControl_to_faulted
                first closedLoopControl
                accept when sensorStatus.measuredFlow.pressure > highPressureLimit or sensorStatus.measuredFlow.flowRate < lowFlowLimit
                then faulted;

            transition faulted_to_standby
                first faulted
                accept when not commandInput.command.enabled
                then standby;
        }
    }

    part def SolarPoweredPumpSubsystem {
        port solarInput : SolarInputPort;
        port sourceFluid : FluidInletPort;
        port deliveredFluid : FluidOutletPort;
        port operatorCommand : ControlInputPort;
        port subsystemStatus : StatusOutputPort;

        part solarArray : SolarPanelArray;
        part conditioner : PowerConditioner;
        part controller : PumpController;
        part motor : PumpMotor;
        part pump : CentrifugalPump;
        part intakeFilter : IntakeFilter;
        part checkValve : CheckValve;
        part dischargeSensor : FlowAndPressureSensor;

        attribute deliveredVolumeToday : Volume;
        attribute operatingEnergyToday : Energy;
        attribute subsystemAvailability : Real;
        attribute nominalSystemFlowRate : VolumetricFlowRate = 0.0035;
        attribute nominalDischargePressure : Pressure = 250000.0;

        connect solarInput to solarArray.solarInput;
        connect solarArray.dcOutput to conditioner.dcInput;
        connect conditioner.regulatedOutput to motor.powerInput;

        connect operatorCommand to controller.commandInput;
        connect controller.motorCommand to motor.controlInput;
        connect controller.pumpCommand to pump.controlInput;

        connect sourceFluid to intakeFilter.rawFluidIn;
        connect intakeFilter.filteredFluidOut to pump.suction;
        connect pump.discharge to checkValve.inlet;
        connect checkValve.outlet to dischargeSensor.sensedFluidIn;
        connect dischargeSensor.sensedFluidOut to deliveredFluid;

        connect dischargeSensor.status to controller.sensorStatus;
        connect conditioner.status to controller.powerStatus;
        connect controller.systemStatus to subsystemStatus;

        action performPumpingMission {
            in item sunlight : SolarRadiation;
            in item inletFluid : Fluid;
            in item requestedOperation : ControlSignal;
            out item delivered : Fluid;
            out item status : FaultSignal;

            first collectSolarEnergy;
            then conditionPower;
            then startMotor;
            then filterIntake;
            then pumpFluid;
            then preventBackflow;
            then measureDischarge;
            then updateController;
            then done;

            action collectSolarEnergy;
            action conditionPower;
            action startMotor;
            action filterIntake;
            action pumpFluid;
            action preventBackflow;
            action measureDischarge;
            action updateController;
        }

        state machine subsystemStates {
            state unavailable;
            state ready;
            state starting;
            state pumping;
            state stopping;
            state fault;

            entry; then unavailable;

            transition unavailable_to_ready
                first unavailable
                accept when solarArray.dcOutput.generatedPower.power >= controller.minimumPowerToStart
                then ready;

            transition ready_to_starting
                first ready
                accept when operatorCommand.command.enabled
                then starting;

            transition starting_to_pumping
                first starting
                accept when motor.shaftSpeed > 300.0 and pump.suction.incomingFluid.pressure > 50000.0
                then pumping;

            transition pumping_to_stopping
                first pumping
                accept when not operatorCommand.command.enabled
                then stopping;

            transition stopping_to_ready
                first stopping
                accept when motor.shaftSpeed <= 50.0
                then ready;

            transition pumping_to_fault
                first pumping
                accept when controller.faultLatched
                then fault;

            transition fault_to_ready
                first fault
                accept when not operatorCommand.command.enabled and solarArray.dcOutput.generatedPower.power >= controller.minimumPowerToStart
                then ready;

            transition ready_to_unavailable
                first ready
                accept when solarArray.dcOutput.generatedPower.power < controller.minimumPowerToStart
                then unavailable;
        }
    }

    requirement def SolarPoweredPumpRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.nominalSystemFlowRate >= 0.003 and
            subsystem.nominalSystemFlowRate <= 0.004
        }

        require constraint {
            subsystem.nominalDischargePressure >= 200000.0
        }

        require constraint {
            subsystem.solarArray.maxPower >= subsystem.motor.ratedPower
        }

        require constraint {
            subsystem.conditioner.outputVoltage == subsystem.motor.ratedVoltage
        }
    }

    requirement def DryRunProtectionRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.pump.minimumFlowRate >= 0.0005
        }

        require constraint {
            subsystem.controller.lowFlowLimit == subsystem.pump.minimumFlowRate
        }
    }

    requirement def BackflowPreventionRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.checkValve.reverseLeakageRate <= 0.00001
        }
    }

    requirement def SolarStartRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.controller.minimumPowerToStart <= subsystem.solarArray.maxPower
        }

        require constraint {
            subsystem.solarArray.minimumOperatingIrradiance <= 200.0
        }
    }

    requirement def ElectricalProtectionRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.conditioner.undervoltageLimit < subsystem.motor.ratedVoltage
        }

        require constraint {
            subsystem.conditioner.overvoltageLimit > subsystem.motor.ratedVoltage
        }

        require constraint {
            subsystem.motor.maxCurrent <= subsystem.conditioner.maxOutputCurrent
        }
    }

    requirement def ThermalProtectionRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.motor.overTemperatureLimit <= 100.0
        }
    }

    requirement def FluidDeliveryRequirement {
        subject subsystem : SolarPoweredPumpSubsystem;

        require constraint {
            subsystem.pump.maximumFlowRate >= 0.006
        }

        require constraint {
            subsystem.pump.nominalPressureRise >= 250000.0
        }

        require constraint {
            subsystem.intakeFilter.pressureDropAtNominalFlow <= 15000.0
        }
    }

    part solarPoweredPumpingSubsystem : SolarPoweredPumpSubsystem {
        attribute nominalSystemFlowRate = 0.0035;
        attribute nominalDischargePressure = 250000.0;

        part solarArray {
            attribute panelArea = 8.0;
            attribute conversionEfficiency = 0.21;
            attribute nominalVoltage = 48.0;
            attribute maxPower = 1600.0;
            attribute minimumOperatingIrradiance = 150.0;
        }

        part conditioner {
            attribute outputVoltage = 48.0;
            attribute maxOutputCurrent = 35.0;
            attribute converterEfficiency = 0.94;
            attribute undervoltageLimit = 36.0;
            attribute overvoltageLimit = 60.0;
        }

        part motor {
            attribute ratedPower = 1200.0;
            attribute ratedVoltage = 48.0;
            attribute maxCurrent = 30.0;
            attribute motorEfficiency = 0.88;
            attribute overTemperatureLimit = 95.0;
        }

        part pump {
            attribute nominalFlowRate = 0.004;
            attribute minimumFlowRate = 0.0007;
            attribute maximumFlowRate = 0.006;
            attribute nominalPressureRise = 250000.0;
            attribute hydraulicEfficiency = 0.72;
        }

        part intakeFilter {
            attribute meshSize = 0.0005;
            attribute pressureDropAtNominalFlow = 12000.0;
            attribute cloggingLimit = 0.8;
        }

        part checkValve {
            attribute crackingPressure = 8000.0;
            attribute reverseLeakageRate = 0.00001;
        }

        part controller {
            attribute targetFlowRate = 0.0035;
            attribute lowFlowLimit = 0.0007;
            attribute highPressureLimit = 450000.0;
            attribute minimumPowerToStart = 350.0;
        }
    }

    satisfy SolarPoweredPumpRequirement by solarPoweredPumpingSubsystem;
    satisfy DryRunProtectionRequirement by solarPoweredPumpingSubsystem;
    satisfy BackflowPreventionRequirement by solarPoweredPumpingSubsystem;
    satisfy SolarStartRequirement by solarPoweredPumpingSubsystem;
    satisfy ElectricalProtectionRequirement by solarPoweredPumpingSubsystem;
    satisfy ThermalProtectionRequirement by solarPoweredPumpingSubsystem;
    satisfy FluidDeliveryRequirement by solarPoweredPumpingSubsystem;
}