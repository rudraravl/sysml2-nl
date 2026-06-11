package PumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def FlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def Volume :> Real {
        unit = "m^3";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    attribute def Level :> Real {
        unit = "m";
    }

    enum def PumpOperatingMode {
        enum idle;
        enum priming;
        enum pumping;
        enum standby;
        enum faulted;
        enum shutdown;
    }

    enum def ValvePosition {
        enum closed;
        enum opening;
        enum open;
        enum closing;
    }

    enum def FaultCode {
        enum none;
        enum lowInletPressure;
        enum highOutletPressure;
        enum motorOvercurrent;
        enum dryRunDetected;
        enum sensorFailure;
        enum emergencyStop;
    }

    item def Fluid {
        attribute density : Real = 998.0;
        attribute dynamicViscosity : Real = 0.001;
        attribute temperature : Temperature = 293.15;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute enabled : Boolean;
        attribute commandSpeed : RotationalSpeed;
        attribute resetFault : Boolean;
        attribute emergencyStop : Boolean;
    }

    item def PumpStatus {
        attribute mode : PumpOperatingMode;
        attribute actualSpeed : RotationalSpeed;
        attribute measuredFlow : FlowRate;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute fault : FaultCode;
    }

    port def FluidPort {
        inout item fluid : Fluid;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
        attribute temperature : Temperature;
    }

    port def ElectricalPowerPort {
        in item supply : ElectricalEnergy;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def StatusOutputPort {
        out item status : PumpStatus;
    }

    port def DrainPort {
        out item drainedFluid : Fluid;
        attribute drainFlow : FlowRate;
    }

    part def Reservoir {
        port outlet : FluidPort;
        port inlet : FluidPort;

        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute fluidLevel : Level;
        attribute outletPressure : Pressure;
        attribute fluidTemperature : Temperature;

        constraint volumeWithinCapacity {
            currentVolume >= 0.0 and currentVolume <= capacity;
        }
    }

    part def IsolationValve {
        port upstream : FluidPort;
        port downstream : FluidPort;
        port control : ControlInputPort;
        port status : StatusOutputPort;

        attribute position : ValvePosition = ValvePosition::closed;
        attribute commandedOpen : Boolean = false;
        attribute pressureDropWhenOpen : Pressure = 500.0;
        attribute maximumRatedPressure : Pressure = 600000.0;

        action openValve {
            first start;
            then setOpening;
            then setOpen;
            then done;

            action setOpening {
                position = ValvePosition::opening;
            }

            action setOpen {
                position = ValvePosition::open;
            }
        }

        action closeValve {
            first start;
            then setClosing;
            then setClosed;
            then done;

            action setClosing {
                position = ValvePosition::closing;
            }

            action setClosed {
                position = ValvePosition::closed;
            }
        }
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute crackingPressure : Pressure = 2000.0;
        attribute reverseLeakageFlow : FlowRate = 0.000001;
        attribute open : Boolean;

        constraint forwardFlowOnly {
            outlet.flow >= -reverseLeakageFlow;
        }
    }

    part def ElectricMotor {
        port powerIn : ElectricalPowerPort;
        port controlIn : ControlInputPort;
        port statusOut : StatusOutputPort;

        attribute ratedPower : Power = 1500.0;
        attribute ratedVoltage : Voltage = 230.0;
        attribute ratedCurrent : Current = 8.0;
        attribute actualCurrent : Current;
        attribute commandedSpeed : RotationalSpeed;
        attribute shaftSpeed : RotationalSpeed;
        attribute motorEfficiency : Efficiency = 0.88;
        attribute overcurrentTrip : Current = 10.5;
        attribute enabled : Boolean = false;

        action energize {
            first receiveEnable;
            then accelerate;
            then regulateSpeed;

            action receiveEnable {
                enabled = true;
            }

            action accelerate {
                shaftSpeed = commandedSpeed;
            }

            action regulateSpeed {
                shaftSpeed = commandedSpeed;
            }
        }

        action deenergize {
            first removeTorque;
            then coastDown;

            action removeTorque {
                enabled = false;
            }

            action coastDown {
                shaftSpeed = 0.0;
            }
        }
    }

    part def CentrifugalPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port shaftPower : ElectricalPowerPort;
        port control : ControlInputPort;
        port status : StatusOutputPort;

        attribute nominalFlow : FlowRate = 0.012;
        attribute minimumContinuousFlow : FlowRate = 0.003;
        attribute maximumFlow : FlowRate = 0.018;
        attribute nominalDifferentialPressure : Pressure = 250000.0;
        attribute maximumDischargePressure : Pressure = 650000.0;
        attribute minimumSuctionPressure : Pressure = 25000.0;
        attribute hydraulicEfficiency : Efficiency = 0.72;
        attribute impellerSpeed : RotationalSpeed;
        attribute currentMode : PumpOperatingMode = PumpOperatingMode::idle;
        attribute detectedFault : FaultCode = FaultCode::none;
        attribute primingTimeout : TimeDuration = 20.0;

        constraint pressureRise {
            discharge.pressure - suction.pressure <= nominalDifferentialPressure;
        }

        constraint flowEnvelope {
            discharge.flow >= 0.0 and discharge.flow <= maximumFlow;
        }

        constraint suctionProtection {
            suction.pressure >= minimumSuctionPressure;
        }

        action primePump {
            first beginPrime;
            then verifyLiquidPresent;
            then completePrime;

            action beginPrime {
                currentMode = PumpOperatingMode::priming;
            }

            action verifyLiquidPresent {
                detectedFault = FaultCode::none;
            }

            action completePrime {
                currentMode = PumpOperatingMode::standby;
            }
        }

        action transferFluid {
            first startTransfer;
            then buildPressure;
            then maintainFlow;

            action startTransfer {
                currentMode = PumpOperatingMode::pumping;
            }

            action buildPressure {
                discharge.pressure = suction.pressure + nominalDifferentialPressure;
            }

            action maintainFlow {
                discharge.flow = nominalFlow;
            }
        }

        action stopPump {
            first rampDown;
            then stopFlow;

            action rampDown {
                impellerSpeed = 0.0;
            }

            action stopFlow {
                currentMode = PumpOperatingMode::idle;
                discharge.flow = 0.0;
            }
        }

        state def PumpStateMachine {
            entry; then Off;

            state Off;
            state Priming;
            state Pumping;
            state Standby;
            state Faulted;
            state Shutdown;

            transition Off_to_Priming
                first Off
                accept ControlSignal
                if command.enabled and not command.emergencyStop
                do primePump
                then Priming;

            transition Priming_to_Standby
                first Priming
                if detectedFault == FaultCode::none
                then Standby;

            transition Standby_to_Pumping
                first Standby
                accept ControlSignal
                if command.enabled and command.commandSpeed > 0.0
                do transferFluid
                then Pumping;

            transition Pumping_to_Standby
                first Pumping
                accept ControlSignal
                if command.enabled and command.commandSpeed == 0.0
                then Standby;

            transition Pumping_to_Faulted_LowSuction
                first Pumping
                if suction.pressure < minimumSuctionPressure
                then Faulted;

            transition Pumping_to_Faulted_HighDischarge
                first Pumping
                if discharge.pressure > maximumDischargePressure
                then Faulted;

            transition Any_to_Shutdown
                first Off
                accept ControlSignal
                if command.emergencyStop
                then Shutdown;

            transition Faulted_to_Off
                first Faulted
                accept ControlSignal
                if command.resetFault
                do stopPump
                then Off;
        }
    }

    part def PressureSensor {
        port process : FluidPort;
        port status : StatusOutputPort;

        attribute measuredPressure : Pressure;
        attribute accuracy : Pressure = 1000.0;
        attribute failed : Boolean = false;
    }

    part def FlowSensor {
        port process : FluidPort;
        port status : StatusOutputPort;

        attribute measuredFlow : FlowRate;
        attribute accuracy : FlowRate = 0.0002;
        attribute failed : Boolean = false;
    }

    part def PumpController {
        port commandIn : ControlInputPort;
        port pumpCommand : ControlInputPort;
        port valveCommand : ControlInputPort;
        port statusIn : StatusOutputPort;
        port statusOut : StatusOutputPort;

        attribute requestedFlow : FlowRate = 0.012;
        attribute requestedSpeed : RotationalSpeed = 1800.0;
        attribute lowSuctionTrip : Pressure = 25000.0;
        attribute highDischargeTrip : Pressure = 650000.0;
        attribute minimumRunTime : TimeDuration = 5.0;
        attribute activeFault : FaultCode = FaultCode::none;
        attribute mode : PumpOperatingMode = PumpOperatingMode::idle;

        action evaluateCommand {
            first readCommand;
            then computeSpeed;
            then issueCommand;

            action readCommand {
                mode = PumpOperatingMode::standby;
            }

            action computeSpeed {
                requestedSpeed = 1800.0;
            }

            action issueCommand {
                mode = PumpOperatingMode::pumping;
            }
        }

        action handleFault {
            first latchFault;
            then stopCommand;

            action latchFault {
                mode = PumpOperatingMode::faulted;
            }

            action stopCommand {
                requestedSpeed = 0.0;
            }
        }
    }

    part def PumpingSubsystem {
        port suctionInterface : FluidPort;
        port dischargeInterface : FluidPort;
        port electricalSupply : ElectricalPowerPort;
        port operatorCommand : ControlInputPort;
        port subsystemStatus : StatusOutputPort;
        port maintenanceDrain : DrainPort;

        part sourceReservoir : Reservoir {
            capacity = 2.0;
            currentVolume = 1.5;
            fluidLevel = 1.2;
            outletPressure = 101325.0;
            fluidTemperature = 293.15;
        }

        part destinationReservoir : Reservoir {
            capacity = 2.5;
            currentVolume = 0.4;
            fluidLevel = 0.3;
            outletPressure = 101325.0;
            fluidTemperature = 293.15;
        }

        part suctionValve : IsolationValve {
            pressureDropWhenOpen = 400.0;
            maximumRatedPressure = 600000.0;
        }

        part dischargeValve : IsolationValve {
            pressureDropWhenOpen = 700.0;
            maximumRatedPressure = 700000.0;
        }

        part nonReturnValve : CheckValve {
            crackingPressure = 1500.0;
        }

        part pump : CentrifugalPump {
            nominalFlow = 0.012;
            minimumContinuousFlow = 0.003;
            maximumFlow = 0.018;
            nominalDifferentialPressure = 250000.0;
            maximumDischargePressure = 650000.0;
            minimumSuctionPressure = 25000.0;
        }

        part motor : ElectricMotor {
            ratedPower = 1500.0;
            ratedVoltage = 230.0;
            ratedCurrent = 8.0;
        }

        part suctionPressureSensor : PressureSensor {
            accuracy = 750.0;
        }

        part dischargePressureSensor : PressureSensor {
            accuracy = 1000.0;
        }

        part flowSensor : FlowSensor {
            accuracy = 0.0002;
        }

        part controller : PumpController {
            requestedFlow = 0.012;
            requestedSpeed = 1800.0;
            lowSuctionTrip = 25000.0;
            highDischargeTrip = 650000.0;
        }

        connect suctionInterface to sourceReservoir.outlet;
        connect sourceReservoir.outlet to suctionValve.upstream;
        connect suctionValve.downstream to suctionPressureSensor.process;
        connect suctionPressureSensor.process to pump.suction;
        connect pump.discharge to dischargePressureSensor.process;
        connect dischargePressureSensor.process to nonReturnValve.inlet;
        connect nonReturnValve.outlet to flowSensor.process;
        connect flowSensor.process to dischargeValve.upstream;
        connect dischargeValve.downstream to destinationReservoir.inlet;
        connect destinationReservoir.inlet to dischargeInterface;

        connect electricalSupply to motor.powerIn;
        connect motor.powerIn to pump.shaftPower;

        connect operatorCommand to controller.commandIn;
        connect controller.pumpCommand to pump.control;
        connect controller.pumpCommand to motor.controlIn;
        connect controller.valveCommand to suctionValve.control;
        connect controller.valveCommand to dischargeValve.control;

        connect pump.status to controller.statusIn;
        connect motor.statusOut to controller.statusIn;
        connect suctionValve.status to controller.statusIn;
        connect dischargeValve.status to controller.statusIn;
        connect suctionPressureSensor.status to controller.statusIn;
        connect dischargePressureSensor.status to controller.statusIn;
        connect flowSensor.status to controller.statusIn;
        connect controller.statusOut to subsystemStatus;

        constraint normalOperatingFlow {
            flowSensor.measuredFlow >= pump.minimumContinuousFlow and
            flowSensor.measuredFlow <= pump.maximumFlow;
        }

        constraint normalOperatingPressure {
            dischargePressureSensor.measuredPressure <= pump.maximumDischargePressure and
            suctionPressureSensor.measuredPressure >= pump.minimumSuctionPressure;
        }

        constraint electricalPowerCapacity {
            electricalSupply.supply.power >= motor.ratedPower;
        }

        action startSubsystem {
            first openSuction;
            then openDischarge;
            then prime;
            then energizeMotor;
            then pumpFluid;

            action openSuction {
                suctionValve.openValve;
            }

            action openDischarge {
                dischargeValve.openValve;
            }

            action prime {
                pump.primePump;
            }

            action energizeMotor {
                motor.energize;
            }

            action pumpFluid {
                pump.transferFluid;
            }
        }

        action stopSubsystem {
            first stopPumping;
            then stopMotor;
            then closeDischarge;
            then closeSuction;

            action stopPumping {
                pump.stopPump;
            }

            action stopMotor {
                motor.deenergize;
            }

            action closeDischarge {
                dischargeValve.closeValve;
            }

            action closeSuction {
                suctionValve.closeValve;
            }
        }

        action emergencyShutdown {
            first latchEmergency;
            then removeMotorPower;
            then isolateFluidPath;

            action latchEmergency {
                controller.activeFault = FaultCode::emergencyStop;
            }

            action removeMotorPower {
                motor.deenergize;
            }

            action isolateFluidPath {
                suctionValve.closeValve;
                dischargeValve.closeValve;
            }
        }
    }

    requirement def PumpFluidTransferRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.flowSensor.measuredFlow >= 0.010 and
            subsystem.flowSensor.measuredFlow <= 0.014;
        }

        doc /* The pumping subsystem shall transfer fluid through the Pump at a controlled nominal flow rate of 0.012 m^3/s during normal operation. */
    }

    requirement def PressureProtectionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.dischargePressureSensor.measuredPressure <= 650000.0 and
            subsystem.suctionPressureSensor.measuredPressure >= 25000.0;
        }

        doc /* The subsystem shall prevent operation when suction pressure is too low or discharge pressure exceeds the rated limit. */
    }

    requirement def IsolationRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.suctionValve.maximumRatedPressure >= 600000.0 and
            subsystem.dischargeValve.maximumRatedPressure >= 650000.0;
        }

        doc /* The subsystem shall provide upstream and downstream isolation valves rated for the maximum operating pressure envelope. */
    }

    requirement def BackflowPreventionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.nonReturnValve.reverseLeakageFlow <= 0.000001;
        }

        doc /* The subsystem shall prevent reverse flow from the discharge side toward the Pump suction side. */
    }

    requirement def ElectricalSupplyRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.electricalSupply.supply.voltage >= 220.0 and
            subsystem.electricalSupply.supply.voltage <= 240.0 and
            subsystem.electricalSupply.supply.power >= 1500.0;
        }

        doc /* The subsystem shall operate from a 230 V electrical supply capable of delivering the rated motor power. */
    }

    requirement def EmergencyShutdownRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.controller.activeFault == FaultCode::emergencyStop implies
            subsystem.motor.enabled == false;
        }

        doc /* The subsystem shall deenergize the motor and isolate the fluid path during emergency shutdown. */
    }

    satisfy PumpFluidTransferRequirement by PumpingSubsystem::pump;
    satisfy PressureProtectionRequirement by PumpingSubsystem::controller;
    satisfy IsolationRequirement by PumpingSubsystem::suctionValve;
    satisfy IsolationRequirement by PumpingSubsystem::dischargeValve;
    satisfy BackflowPreventionRequirement by PumpingSubsystem::nonReturnValve;
    satisfy ElectricalSupplyRequirement by PumpingSubsystem::motor;
    satisfy EmergencyShutdownRequirement by PumpingSubsystem::controller;
}