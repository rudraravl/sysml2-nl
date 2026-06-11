package AxialFlowPumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def FlowRate :> scalarValues::Real;
    attribute def Pressure :> scalarValues::Real;
    attribute def RotationalSpeed :> scalarValues::Real;
    attribute def Power :> scalarValues::Real;
    attribute def Temperature :> scalarValues::Real;
    attribute def Efficiency :> scalarValues::Real;
    attribute def Volume :> scalarValues::Real;

    item def Fluid {
        attribute density : Real;
        attribute dynamicViscosity : Real;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
        attribute activePower : Power;
    }

    item def ControlSignal {
        attribute commandValue : Real;
        attribute timestamp : Real;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute timestamp : Real;
    }

    port def FluidPort {
        inout item fluid : Fluid;
        attribute staticPressure : Pressure;
        attribute volumetricFlowRate : FlowRate;
        attribute temperature : Temperature;
    }

    port def ElectricalPowerPort {
        in item powerFeed : ElectricalPower;
    }

    port def CommandPort {
        in item command : ControlSignal;
    }

    port def TelemetryPort {
        out item telemetry : SensorSignal;
    }

    part def AxialFlowPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port shaftPort;
        attribute nominalFlowRate : FlowRate = 2.5;
        attribute nominalPressureRise : Pressure = 85000.0;
        attribute maximumFlowRate : FlowRate = 3.2;
        attribute minimumContinuousFlowRate : FlowRate = 0.8;
        attribute hydraulicEfficiency : Efficiency = 0.82;
        attribute impellerDiameter : Real = 0.42;
        attribute bladeCount : Integer = 6;
        attribute currentPressureRise : Pressure;
        attribute currentFlowRate : FlowRate;
        attribute netPositiveSuctionHeadRequired : Real = 3.5;

        action computeHydraulicPerformance {
            in flow : FlowRate;
            in speed : RotationalSpeed;
            out pressureRise : Pressure;
            out efficiency : Efficiency;
        }

        state machine pumpHydraulicState {
            state stopped;
            state priming;
            state pumping;
            state lowFlowRecirculation;
            state cavitationRisk;
            state faulted;

            initial then stopped;

            transition stopped_to_priming
                first stopped
                accept startCommand
                then priming;

            transition priming_to_pumping
                first priming
                guard suctionPort.staticPressure > fluid.vaporPressure
                then pumping;

            transition pumping_to_lowFlow
                first pumping
                guard currentFlowRate < minimumContinuousFlowRate
                then lowFlowRecirculation;

            transition lowFlow_to_pumping
                first lowFlowRecirculation
                guard currentFlowRate >= minimumContinuousFlowRate
                then pumping;

            transition pumping_to_cavitationRisk
                first pumping
                guard suctionPort.staticPressure <= fluid.vaporPressure
                then cavitationRisk;

            transition cavitationRisk_to_faulted
                first cavitationRisk
                accept cavitationTimeout
                then faulted;

            transition any_to_stopped
                first pumping
                accept stopCommand
                then stopped;
        }
    }

    part def ElectricMotor {
        port powerInput : ElectricalPowerPort;
        port shaftOutput;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;
        attribute ratedPower : Power = 125000.0;
        attribute ratedSpeed : RotationalSpeed = 1180.0;
        attribute ratedVoltage : Real = 480.0;
        attribute ratedFrequency : Real = 60.0;
        attribute motorEfficiency : Efficiency = 0.94;
        attribute shaftSpeed : RotationalSpeed;
        attribute shaftTorque : Real;
        attribute windingTemperature : Temperature;

        action regulateSpeed {
            in demandedSpeed : RotationalSpeed;
            out deliveredSpeed : RotationalSpeed;
        }

        state machine motorState {
            state deenergized;
            state accelerating;
            state running;
            state overloaded;
            state tripped;

            initial then deenergized;

            transition start
                first deenergized
                accept enableMotor
                then accelerating;

            transition reachSpeed
                first accelerating
                guard shaftSpeed >= 0.98 * ratedSpeed
                then running;

            transition overload
                first running
                guard powerInput.powerFeed.current > 1.15 * ratedPower / ratedVoltage
                then overloaded;

            transition trip
                first overloaded
                accept overloadDelayElapsed
                then tripped;

            transition stop
                first running
                accept disableMotor
                then deenergized;
        }
    }

    part def InletIsolationValve {
        port upstream : FluidPort;
        port downstream : FluidPort;
        port commandInput : CommandPort;
        port positionTelemetry : TelemetryPort;
        attribute openFraction : Real;
        attribute fullOpenCv : Real = 480.0;
        attribute failPositionOpen : Boolean = true;

        action setPosition {
            in demandedOpenFraction : Real;
            out achievedOpenFraction : Real;
        }
    }

    part def DischargeCheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 1200.0;
        attribute reverseLeakageFlowRate : FlowRate = 0.002;
        attribute open : Boolean;

        state machine checkValveState {
            state closed;
            state openForward;

            initial then closed;

            transition openOnForwardPressure
                first closed
                guard inlet.staticPressure > outlet.staticPressure + crackingPressure
                then openForward;

            transition closeOnReversePressure
                first openForward
                guard inlet.staticPressure <= outlet.staticPressure
                then closed;
        }
    }

    part def DischargeControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port commandInput : CommandPort;
        port positionTelemetry : TelemetryPort;
        attribute openFraction : Real;
        attribute fullOpenCv : Real = 360.0;
        attribute minimumCommandedOpenFraction : Real = 0.15;

        action modulateForFlow {
            in demandedFlowRate : FlowRate;
            in measuredFlowRate : FlowRate;
            out valveOpenFraction : Real;
        }
    }

    part def FlowSensor {
        port measuredLine : FluidPort;
        port signalOutput : TelemetryPort;
        attribute rangeMinimum : FlowRate = 0.0;
        attribute rangeMaximum : FlowRate = 3.5;
        attribute accuracyPercentSpan : Real = 0.5;
        attribute measuredFlowRate : FlowRate;

        action sampleFlow {
            out flowSignal : SensorSignal;
        }
    }

    part def PressureSensor {
        port measuredLine : FluidPort;
        port signalOutput : TelemetryPort;
        attribute rangeMinimum : Pressure = 0.0;
        attribute rangeMaximum : Pressure = 600000.0;
        attribute accuracyPercentSpan : Real = 0.25;
        attribute measuredPressure : Pressure;

        action samplePressure {
            out pressureSignal : SensorSignal;
        }
    }

    part def PumpController {
        port startStopCommand : CommandPort;
        port speedCommandOutput : CommandPort;
        port inletValveCommandOutput : CommandPort;
        port dischargeValveCommandOutput : CommandPort;
        port flowTelemetryInput : TelemetryPort;
        port suctionPressureTelemetryInput : TelemetryPort;
        port dischargePressureTelemetryInput : TelemetryPort;
        port alarmTelemetryOutput : TelemetryPort;

        attribute demandedFlowRate : FlowRate = 2.5;
        attribute lowFlowTripThreshold : FlowRate = 0.65;
        attribute highDischargePressureTrip : Pressure = 520000.0;
        attribute lowSuctionPressureTrip : Pressure = 45000.0;
        attribute commandedPumpSpeed : RotationalSpeed;
        attribute permissiveSatisfied : Boolean;

        action closedLoopFlowControl {
            in demandedFlowRate : FlowRate;
            in measuredFlowRate : FlowRate;
            in suctionPressure : Pressure;
            in dischargePressure : Pressure;
            out motorSpeedCommand : ControlSignal;
            out dischargeValveCommand : ControlSignal;
            out alarmSignal : SensorSignal;
        }

        state machine controlState {
            state idle;
            state prestartChecks;
            state openingInletValve;
            state startingMotor;
            state regulatingFlow;
            state protectiveShutdown;
            state stoppedFault;

            initial then idle;

            transition commandStart
                first idle
                accept operatorStart
                then prestartChecks;

            transition permissivesPassed
                first prestartChecks
                guard permissiveSatisfied
                then openingInletValve;

            transition inletReady
                first openingInletValve
                accept inletValveOpenConfirmed
                then startingMotor;

            transition motorRunning
                first startingMotor
                accept motorAtSpeed
                then regulatingFlow;

            transition highPressureShutdown
                first regulatingFlow
                guard dischargePressureTelemetryInput.telemetry.measuredValue > highDischargePressureTrip
                then protectiveShutdown;

            transition lowSuctionShutdown
                first regulatingFlow
                guard suctionPressureTelemetryInput.telemetry.measuredValue < lowSuctionPressureTrip
                then protectiveShutdown;

            transition lowFlowShutdown
                first regulatingFlow
                guard flowTelemetryInput.telemetry.measuredValue < lowFlowTripThreshold
                then protectiveShutdown;

            transition shutdownComplete
                first protectiveShutdown
                accept shutdownActionsComplete
                then stoppedFault;

            transition reset
                first stoppedFault
                accept operatorReset
                then idle;
        }
    }

    part def AxialFlowPumpingSubsystem {
        port systemInlet : FluidPort;
        port systemOutlet : FluidPort;
        port electricalSupply : ElectricalPowerPort;
        port operatorCommand : CommandPort;
        port systemTelemetry : TelemetryPort;

        attribute designFlowRate : FlowRate = 2.5;
        attribute designPressureIncrease : Pressure = 85000.0;
        attribute maximumAllowableWorkingPressure : Pressure = 600000.0;
        attribute normalFluidTemperature : Temperature = 293.15;
        attribute availableNPSH : Real = 6.0;
        attribute subsystemAvailabilityTarget : Real = 0.995;

        part inletValve : InletIsolationValve;
        part pump : AxialFlowPump;
        part motor : ElectricMotor;
        part checkValve : DischargeCheckValve;
        part controlValve : DischargeControlValve;
        part flowSensor : FlowSensor;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part controller : PumpController;

        connect systemInlet to inletValve.upstream;
        connect inletValve.downstream to pump.suctionPort;
        connect pump.dischargePort to checkValve.inlet;
        connect checkValve.outlet to controlValve.inlet;
        connect controlValve.outlet to systemOutlet;

        connect electricalSupply to motor.powerInput;
        connect motor.shaftOutput to pump.shaftPort;

        connect operatorCommand to controller.startStopCommand;
        connect controller.speedCommandOutput to motor.commandInput;
        connect controller.inletValveCommandOutput to inletValve.commandInput;
        connect controller.dischargeValveCommandOutput to controlValve.commandInput;

        connect flowSensor.measuredLine to controlValve.outlet;
        connect suctionPressureSensor.measuredLine to pump.suctionPort;
        connect dischargePressureSensor.measuredLine to pump.dischargePort;

        connect flowSensor.signalOutput to controller.flowTelemetryInput;
        connect suctionPressureSensor.signalOutput to controller.suctionPressureTelemetryInput;
        connect dischargePressureSensor.signalOutput to controller.dischargePressureTelemetryInput;
        connect controller.alarmTelemetryOutput to systemTelemetry;

        constraint pressureBoundary {
            assert pump.dischargePort.staticPressure <= maximumAllowableWorkingPressure;
            assert controlValve.outlet.staticPressure <= maximumAllowableWorkingPressure;
        }

        constraint hydraulicCapacity {
            assert designFlowRate <= pump.maximumFlowRate;
            assert designFlowRate >= pump.minimumContinuousFlowRate;
            assert designPressureIncrease <= pump.nominalPressureRise * 1.10;
        }

        constraint cavitationMargin {
            assert availableNPSH >= pump.netPositiveSuctionHeadRequired + 1.0;
        }

        perform controller.closedLoopFlowControl;
        perform pump.computeHydraulicPerformance;
        perform motor.regulateSpeed;
        perform controlValve.modulateForFlow;
    }

    requirement def MoveFluidRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.designFlowRate >= 2.5 and
            subsystem.designPressureIncrease >= 85000.0;
        }
    }

    requirement def AxialFlowPumpRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.pump.bladeCount >= 4 and
            subsystem.pump.hydraulicEfficiency >= 0.78 and
            subsystem.pump.nominalFlowRate >= subsystem.designFlowRate;
        }
    }

    requirement def AntiCavitationRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.availableNPSH >= subsystem.pump.netPositiveSuctionHeadRequired + 1.0;
        }
    }

    requirement def ReverseFlowPreventionRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.checkValve.reverseLeakageFlowRate <= 0.005;
        }
    }

    requirement def ProtectiveShutdownRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.controller.highDischargePressureTrip < subsystem.maximumAllowableWorkingPressure and
            subsystem.controller.lowFlowTripThreshold < subsystem.pump.minimumContinuousFlowRate and
            subsystem.controller.lowSuctionPressureTrip > 0.0;
        }
    }

    requirement def ControlAccuracyRequirement {
        subject subsystem : AxialFlowPumpingSubsystem;
        require constraint {
            subsystem.flowSensor.accuracyPercentSpan <= 0.5 and
            subsystem.suctionPressureSensor.accuracyPercentSpan <= 0.25 and
            subsystem.dischargePressureSensor.accuracyPercentSpan <= 0.25;
        }
    }

    satisfy MoveFluidRequirement by AxialFlowPumpingSubsystem;
    satisfy AxialFlowPumpRequirement by AxialFlowPumpingSubsystem::pump;
    satisfy AntiCavitationRequirement by AxialFlowPumpingSubsystem;
    satisfy ReverseFlowPreventionRequirement by AxialFlowPumpingSubsystem::checkValve;
    satisfy ProtectiveShutdownRequirement by AxialFlowPumpingSubsystem::controller;
    satisfy ControlAccuracyRequirement by AxialFlowPumpingSubsystem;

    part axialFlowPumpStation : AxialFlowPumpingSubsystem {
        attribute designFlowRate = 2.5;
        attribute designPressureIncrease = 85000.0;
        attribute maximumAllowableWorkingPressure = 600000.0;
        attribute availableNPSH = 6.0;
    }
}