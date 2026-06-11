package AirPumpedFluidSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ScalarValues::Real {
        unit = "kPa";
    }

    attribute def VolumetricFlowRate :> ScalarValues::Real {
        unit = "L/min";
    }

    attribute def Temperature :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def Volume :> ScalarValues::Real {
        unit = "L";
    }

    attribute def Power :> ScalarValues::Real {
        unit = "W";
    }

    attribute def Voltage :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current :> ScalarValues::Real {
        unit = "A";
    }

    attribute def TimeDuration :> ScalarValues::Real {
        unit = "s";
    }

    attribute def Percent :> ScalarValues::Real {
        unit = "%";
    }

    item def Air {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : VolumetricFlowRate;
    }

    item def WorkingFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : VolumetricFlowRate;
        attribute volumeTransferred : Volume;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute dutyCycle : Percent;
        attribute enable : Boolean;
    }

    item def SensorSignal {
        attribute measuredPressure : Pressure;
        attribute measuredFlowRate : VolumetricFlowRate;
        attribute valid : Boolean;
    }

    port def AirInletPort {
        in item airIn : Air;
    }

    port def AirOutletPort {
        out item airOut : Air;
    }

    port def FluidInletPort {
        in item fluidIn : WorkingFluid;
    }

    port def FluidOutletPort {
        out item fluidOut : WorkingFluid;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def SensorOutputPort {
        out item signal : SensorSignal;
    }

    part def AirPump {
        port airInlet : AirInletPort;
        port compressedAirOutlet : AirOutletPort;
        port powerPort : PowerInputPort;
        port controlPort : ControlInputPort;

        attribute maximumAirPressure : Pressure = 250;
        attribute nominalAirFlowRate : VolumetricFlowRate = 18;
        attribute nominalVoltage : Voltage = 24;
        attribute maximumCurrent : Current = 4.5;
        attribute efficiency : Percent = 68;

        action compressAir {
            in item ambientAir : Air;
            in item electricalPower : ElectricalPower;
            in item command : ControlSignal;
            out item compressedAir : Air;

            first startCompression;
            then regulateCompression;
            then dischargeCompressedAir;

            action startCompression;
            action regulateCompression;
            action dischargeCompressedAir;
        }

        state def PumpOperatingState {
            state off;
            state starting;
            state running;
            state faulted;

            initial then off;

            transition off_to_starting
                first off
                accept ControlSignal
                if command.enable == true
                then starting;

            transition starting_to_running
                first starting
                if powerPort.powerIn.voltage >= 21
                then running;

            transition running_to_off
                first running
                accept ControlSignal
                if command.enable == false
                then off;

            transition running_to_faulted
                first running
                if powerPort.powerIn.current > maximumCurrent
                then faulted;

            transition faulted_to_off
                first faulted
                accept ControlSignal
                if command.enable == false
                then off;
        }

        exhibit state pumpState : PumpOperatingState;
    }

    part def PneumaticAccumulator {
        port airInlet : AirInletPort;
        port airOutlet : AirOutletPort;

        attribute storageVolume : Volume = 1.5;
        attribute reliefPressure : Pressure = 275;
        attribute minimumOperatingPressure : Pressure = 80;
        attribute maximumOperatingPressure : Pressure = 240;
    }

    part def AirReliefValve {
        port airInlet : AirInletPort;
        port ventOutlet : AirOutletPort;

        attribute crackingPressure : Pressure = 260;
        attribute reseatPressure : Pressure = 230;

        state def ReliefValveState {
            state closed;
            state open;

            initial then closed;

            transition closed_to_open
                first closed
                if airInlet.airIn.pressure >= crackingPressure
                then open;

            transition open_to_closed
                first open
                if airInlet.airIn.pressure <= reseatPressure
                then closed;
        }

        exhibit state reliefState : ReliefValveState;
    }

    part def AirDrivenDiaphragmChamber {
        port driveAirInlet : AirInletPort;
        port exhaustAirOutlet : AirOutletPort;
        port fluidInlet : FluidInletPort;
        port fluidOutlet : FluidOutletPort;

        attribute chamberDisplacement : Volume = 0.12;
        attribute maximumFluidPressure : Pressure = 180;
        attribute nominalFluidFlowRate : VolumetricFlowRate = 6.5;
        attribute transferEfficiency : Percent = 74;

        action transferFluid {
            in item driveAir : Air;
            in item inletFluid : WorkingFluid;
            out item outletFluid : WorkingFluid;
            out item exhaustAir : Air;

            first pressurizeDiaphragm;
            then displaceFluid;
            then ventDriveAir;

            action pressurizeDiaphragm;
            action displaceFluid;
            action ventDriveAir;
        }

        state def ChamberCycleState {
            state idle;
            state intakeStroke;
            state dischargeStroke;
            state ventStroke;

            initial then idle;

            transition idle_to_intake
                first idle
                if driveAirInlet.airIn.pressure < 40
                then intakeStroke;

            transition intake_to_discharge
                first intakeStroke
                if fluidInlet.fluidIn.volumeTransferred >= chamberDisplacement
                then dischargeStroke;

            transition discharge_to_vent
                first dischargeStroke
                if fluidOutlet.fluidOut.pressure >= 60
                then ventStroke;

            transition vent_to_intake
                first ventStroke
                if exhaustAirOutlet.airOut.pressure <= 15
                then intakeStroke;
        }

        exhibit state cycleState : ChamberCycleState;
    }

    part def FluidCheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute openingPressureDelta : Pressure = 8;
        attribute reverseLeakageLimit : VolumetricFlowRate = 0.02;

        state def CheckValveState {
            state closed;
            state open;

            initial then closed;

            transition closed_to_open
                first closed
                if inlet.fluidIn.pressure >= outlet.fluidOut.pressure + openingPressureDelta
                then open;

            transition open_to_closed
                first open
                if inlet.fluidIn.pressure < outlet.fluidOut.pressure + openingPressureDelta
                then closed;
        }

        exhibit state checkValveState : CheckValveState;
    }

    part def FluidReservoir {
        port outlet : FluidOutletPort;
        port returnInlet : FluidInletPort;

        attribute capacity : Volume = 20;
        attribute minimumUsableVolume : Volume = 2;
        attribute nominalFluidTemperature : Temperature = 22;
    }

    part def OutletManifold {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port sensorTap : SensorOutputPort;

        attribute ratedPressure : Pressure = 200;
        attribute internalVolume : Volume = 0.35;
    }

    part def PressureFlowSensor {
        port fluidSenseInlet : FluidInletPort;
        port signalOut : SensorOutputPort;

        attribute pressureRange : Pressure = 250;
        attribute flowRange : VolumetricFlowRate = 12;
        attribute responseTime : TimeDuration = 0.08;

        action measureFluidCondition {
            in item sensedFluid : WorkingFluid;
            out item signal : SensorSignal;

            first samplePressure;
            then sampleFlow;
            then validateSignal;

            action samplePressure;
            action sampleFlow;
            action validateSignal;
        }
    }

    part def ElectronicController {
        port powerPort : PowerInputPort;
        port pressureFlowInput : SensorOutputPort;
        port pumpCommand : ControlInputPort;

        attribute targetOutletPressure : Pressure = 120;
        attribute minimumOutletPressure : Pressure = 90;
        attribute maximumOutletPressure : Pressure = 160;
        attribute targetFlowRate : VolumetricFlowRate = 5;
        attribute controlLoopPeriod : TimeDuration = 0.05;

        action regulatePump {
            in item feedback : SensorSignal;
            out item command : ControlSignal;

            first comparePressure;
            then compareFlow;
            then computeDutyCycle;
            then issueCommand;

            action comparePressure;
            action compareFlow;
            action computeDutyCycle;
            action issueCommand;
        }

        state def ControlState {
            state disabled;
            state priming;
            state regulating;
            state shutdown;
            state fault;

            initial then disabled;

            transition disabled_to_priming
                first disabled
                accept ControlSignal
                if command.enable == true
                then priming;

            transition priming_to_regulating
                first priming
                if pressureFlowInput.signal.measuredPressure >= minimumOutletPressure
                then regulating;

            transition regulating_to_shutdown
                first regulating
                accept ControlSignal
                if command.enable == false
                then shutdown;

            transition regulating_to_fault
                first regulating
                if pressureFlowInput.signal.measuredPressure > maximumOutletPressure
                then fault;

            transition fault_to_disabled
                first fault
                accept ControlSignal
                if command.enable == false
                then disabled;

            transition shutdown_to_disabled
                first shutdown
                then disabled;
        }

        exhibit state controllerState : ControlState;
    }

    part def AirPumpedFluidSubsystem {
        port electricalInput : PowerInputPort;
        port fluidSourcePort : FluidInletPort;
        port fluidDeliveryPort : FluidOutletPort;
        port ambientAirPort : AirInletPort;
        port exhaustAirPort : AirOutletPort;
        port externalCommandPort : ControlInputPort;
        port telemetryPort : SensorOutputPort;

        attribute requiredOutletPressure : Pressure = 120;
        attribute requiredOutletFlowRate : VolumetricFlowRate = 5;
        attribute maximumSystemPressure : Pressure = 200;
        attribute primingTimeLimit : TimeDuration = 20;
        attribute continuousRunTimeRating : TimeDuration = 3600;

        part reservoir : FluidReservoir;
        part airPump : AirPump;
        part accumulator : PneumaticAccumulator;
        part reliefValve : AirReliefValve;
        part inletCheckValve : FluidCheckValve;
        part outletCheckValve : FluidCheckValve;
        part diaphragmChamber : AirDrivenDiaphragmChamber;
        part outletManifold : OutletManifold;
        part pressureFlowSensor : PressureFlowSensor;
        part controller : ElectronicController;

        connection electrical_supply_to_air_pump
            connect electricalInput to airPump.powerPort;

        connection electrical_supply_to_controller
            connect electricalInput to controller.powerPort;

        connection ambient_air_to_pump
            connect ambientAirPort to airPump.airInlet;

        connection pump_to_accumulator
            connect airPump.compressedAirOutlet to accumulator.airInlet;

        connection accumulator_to_diaphragm
            connect accumulator.airOutlet to diaphragmChamber.driveAirInlet;

        connection accumulator_to_relief_valve
            connect accumulator.airOutlet to reliefValve.airInlet;

        connection relief_to_exhaust
            connect reliefValve.ventOutlet to exhaustAirPort;

        connection diaphragm_exhaust_to_exhaust
            connect diaphragmChamber.exhaustAirOutlet to exhaustAirPort;

        connection fluid_source_to_reservoir
            connect fluidSourcePort to reservoir.returnInlet;

        connection reservoir_to_inlet_check
            connect reservoir.outlet to inletCheckValve.inlet;

        connection inlet_check_to_chamber
            connect inletCheckValve.outlet to diaphragmChamber.fluidInlet;

        connection chamber_to_outlet_check
            connect diaphragmChamber.fluidOutlet to outletCheckValve.inlet;

        connection outlet_check_to_manifold
            connect outletCheckValve.outlet to outletManifold.inlet;

        connection manifold_to_delivery
            connect outletManifold.outlet to fluidDeliveryPort;

        connection manifold_to_sensor
            connect outletManifold.outlet to pressureFlowSensor.fluidSenseInlet;

        connection sensor_to_controller
            connect pressureFlowSensor.signalOut to controller.pressureFlowInput;

        connection sensor_to_telemetry
            connect pressureFlowSensor.signalOut to telemetryPort;

        connection external_command_to_controller
            connect externalCommandPort to controller.pumpCommand;

        connection controller_to_pump
            connect controller.pumpCommand to airPump.controlPort;

        action operateSubsystem {
            in item electricalPower : ElectricalPower;
            in item externalCommand : ControlSignal;
            in item sourceFluid : WorkingFluid;
            in item ambientAir : Air;
            out item deliveredFluid : WorkingFluid;
            out item telemetry : SensorSignal;

            first initializeController;
            then primeFluidPath;
            then compressDriveAir;
            then driveDiaphragmPump;
            then measureOutletCondition;
            then regulateAirPump;
            then deliverFluid;

            action initializeController;
            action primeFluidPath;
            action compressDriveAir;
            action driveDiaphragmPump;
            action measureOutletCondition;
            action regulateAirPump;
            action deliverFluid;
        }

        state def SubsystemState {
            state off;
            state selfTest;
            state priming;
            state pumping;
            state pressureHold;
            state overpressureRelief;
            state faulted;
            state shutdown;

            initial then off;

            transition off_to_selfTest
                first off
                accept ControlSignal
                if externalCommandPort.command.enable == true
                then selfTest;

            transition selfTest_to_priming
                first selfTest
                if electricalInput.powerIn.voltage >= 21 and electricalInput.powerIn.voltage <= 30
                then priming;

            transition priming_to_pumping
                first priming
                if pressureFlowSensor.signalOut.signal.measuredFlowRate >= 1
                then pumping;

            transition pumping_to_pressureHold
                first pumping
                if pressureFlowSensor.signalOut.signal.measuredPressure >= requiredOutletPressure
                then pressureHold;

            transition pressureHold_to_pumping
                first pressureHold
                if pressureFlowSensor.signalOut.signal.measuredPressure < controller.minimumOutletPressure
                then pumping;

            transition pumping_to_overpressureRelief
                first pumping
                if pressureFlowSensor.signalOut.signal.measuredPressure > maximumSystemPressure
                then overpressureRelief;

            transition overpressureRelief_to_faulted
                first overpressureRelief
                if pressureFlowSensor.signalOut.signal.measuredPressure > maximumSystemPressure
                then faulted;

            transition pumping_to_faulted
                first pumping
                if pressureFlowSensor.signalOut.signal.valid == false
                then faulted;

            transition pressureHold_to_shutdown
                first pressureHold
                accept ControlSignal
                if externalCommandPort.command.enable == false
                then shutdown;

            transition pumping_to_shutdown
                first pumping
                accept ControlSignal
                if externalCommandPort.command.enable == false
                then shutdown;

            transition shutdown_to_off
                first shutdown
                then off;
        }

        exhibit state operatingState : SubsystemState;
    }

    requirement def MoveFluidUsingAirPumpRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.fluidDeliveryPort.fluidOut.flowRate >= subsystem.requiredOutletFlowRate
        }

        require constraint {
            subsystem.fluidDeliveryPort.fluidOut.pressure >= subsystem.requiredOutletPressure
        }

        require constraint {
            subsystem.fluidDeliveryPort.fluidOut.pressure <= subsystem.maximumSystemPressure
        }
    }

    requirement def ElectricalCompatibilityRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.electricalInput.powerIn.voltage >= 21 and
            subsystem.electricalInput.powerIn.voltage <= 30
        }

        require constraint {
            subsystem.airPump.powerPort.powerIn.current <= subsystem.airPump.maximumCurrent
        }
    }

    requirement def OverpressureProtectionRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.reliefValve.crackingPressure < subsystem.accumulator.reliefPressure
        }

        require constraint {
            subsystem.reliefValve.crackingPressure <= 260
        }

        require constraint {
            subsystem.outletManifold.ratedPressure >= subsystem.maximumSystemPressure
        }
    }

    requirement def PrimingRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.primingTimeLimit <= 20
        }

        require constraint {
            subsystem.reservoir.minimumUsableVolume >= 2
        }
    }

    requirement def MonitoringRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.pressureFlowSensor.responseTime <= 0.1
        }

        require constraint {
            subsystem.pressureFlowSensor.pressureRange >= subsystem.maximumSystemPressure
        }

        require constraint {
            subsystem.pressureFlowSensor.flowRange >= subsystem.requiredOutletFlowRate
        }
    }

    requirement def ContinuousOperationRequirement {
        subject subsystem : AirPumpedFluidSubsystem;

        require constraint {
            subsystem.continuousRunTimeRating >= 3600
        }

        require constraint {
            subsystem.airPump.efficiency >= 60
        }

        require constraint {
            subsystem.diaphragmChamber.transferEfficiency >= 70
        }
    }

    part airPumpedFluidSubsystem : AirPumpedFluidSubsystem;

    requirement moveFluidRequirement : MoveFluidUsingAirPumpRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    requirement electricalRequirement : ElectricalCompatibilityRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    requirement protectionRequirement : OverpressureProtectionRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    requirement primingRequirement : PrimingRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    requirement monitoringRequirement : MonitoringRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    requirement continuousOperationRequirement : ContinuousOperationRequirement {
        subject subsystem = airPumpedFluidSubsystem;
    }

    satisfy moveFluidRequirement by airPumpedFluidSubsystem;
    satisfy electricalRequirement by airPumpedFluidSubsystem;
    satisfy protectionRequirement by airPumpedFluidSubsystem;
    satisfy primingRequirement by airPumpedFluidSubsystem;
    satisfy monitoringRequirement by airPumpedFluidSubsystem;
    satisfy continuousOperationRequirement by airPumpedFluidSubsystem;
}