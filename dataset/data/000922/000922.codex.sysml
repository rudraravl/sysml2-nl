package PumpingSubsystemWithPulserPump {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import USCustomaryUnits::*;

    attribute def Pressure :> ISQ::pressure {
        unit = "Pa";
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = "m^3/s";
    }

    attribute def Volume :> ISQ::volume {
        unit = "m^3";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "K";
    }

    attribute def RotationalSpeed :> ISQ::frequency {
        unit = "Hz";
    }

    attribute def ElectricVoltage :> ISQ::electricPotential {
        unit = "V";
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = "A";
    }

    attribute def Power :> ISQ::power {
        unit = "W";
    }

    attribute def TimeDuration :> ISQ::time {
        unit = "s";
    }

    attribute def Efficiency :> ScalarValues::Real {
        :>> range = "0..1";
    }

    attribute def Percentage :> ScalarValues::Real {
        :>> range = "0..100";
    }

    item def Fluid {
        attribute density : Real;
        attribute dynamicViscosity : Real;
        attribute bulkModulus : Pressure;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
    }

    item def ElectricalPower {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute frequency : Real;
    }

    item def ControlSignal {
        attribute command : String;
        attribute value : Real;
        attribute timestamp : TimeDuration;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute timestamp : TimeDuration;
    }

    port def FluidPort {
        inout fluid : Fluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPort {
        in powerIn : ElectricalPower;
    }

    port def SignalInPort {
        in signal : ControlSignal;
    }

    port def SignalOutPort {
        out signal : SensorSignal;
    }

    part def Reservoir {
        port outlet : FluidPort;
        port returnInlet : FluidPort;

        attribute capacity : Volume = 0.050;
        attribute usableVolume : Volume = 0.040;
        attribute minimumOperatingVolume : Volume = 0.008;
        attribute internalPressure : Pressure = 101325;
        attribute fluidLevelPercent : Percentage;

        constraint levelWithinRange {
            fluidLevelPercent >= 0 and fluidLevelPercent <= 100
        }
    }

    part def SuctionStrainer {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute meshRatingMicron : Real = 100;
        attribute cleanPressureDrop : Pressure = 2500;
        attribute cloggedPressureDropLimit : Pressure = 25000;

        requirement filtrationRequirement {
            doc /* The suction strainer shall prevent particles larger than 100 micrometers from entering the Pulser pump inlet. */
        }
    }

    part def InletCheckValve {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute crackingPressure : Pressure = 3500;
        attribute reverseLeakageLimit : FlowRate = 0.00000002;

        state def CheckValveState {
            entry; then Closed;
            state Closed;
            state Opening;
            state Open;

            transition Closed_to_Opening
                first Closed
                accept when downstream.pressure + crackingPressure < upstream.pressure
                then Opening;

            transition Opening_to_Open
                first Opening
                accept after 0.05
                then Open;

            transition Open_to_Closed
                first Open
                accept when downstream.pressure >= upstream.pressure
                then Closed;
        }

        exhibit stateMachine : CheckValveState;
    }

    part def OutletCheckValve {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute crackingPressure : Pressure = 5000;
        attribute reverseLeakageLimit : FlowRate = 0.00000001;

        state def CheckValveState {
            entry; then Closed;
            state Closed;
            state Opening;
            state Open;

            transition Closed_to_Opening
                first Closed
                accept when upstream.pressure > downstream.pressure + crackingPressure
                then Opening;

            transition Opening_to_Open
                first Opening
                accept after 0.03
                then Open;

            transition Open_to_Closed
                first Open
                accept when upstream.pressure <= downstream.pressure
                then Closed;
        }

        exhibit stateMachine : CheckValveState;
    }

    part def PulserPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port electricalSupply : ElectricalPort;
        port commandIn : SignalInPort;
        port speedFeedback : SignalOutPort;
        port faultOut : SignalOutPort;

        attribute displacementPerStroke : Volume = 0.00000035;
        attribute nominalPulseFrequency : RotationalSpeed = 25;
        attribute maximumPulseFrequency : RotationalSpeed = 50;
        attribute minimumPulseFrequency : RotationalSpeed = 2;
        attribute ratedDischargePressure : Pressure = 1200000;
        attribute maximumDischargePressure : Pressure = 1500000;
        attribute nominalFlowRate : FlowRate = 0.00000875;
        attribute volumetricEfficiency : Efficiency = 0.88;
        attribute motorPowerRating : Power = 180;
        attribute allowedDryRunTime : TimeDuration = 5;
        attribute caseTemperatureLimit : Temperature = 358.15;
        attribute netPositiveSuctionPressureRequired : Pressure = 25000;
        attribute commandedPulseFrequency : RotationalSpeed;
        attribute actualPulseFrequency : RotationalSpeed;
        attribute caseTemperature : Temperature;
        attribute accumulatedRunTime : TimeDuration;

        action def StartPump {
            in targetFrequency : RotationalSpeed;
            out accepted : Boolean;

            first start;
            then validateFrequency;
            then energizeMotor;
            then rampToTarget;
            then done;

            action validateFrequency {
                accepted = targetFrequency >= minimumPulseFrequency and targetFrequency <= maximumPulseFrequency;
            }

            action energizeMotor;
            action rampToTarget;
        }

        action def StopPump {
            first reduceFrequency;
            then deenergizeMotor;
            then stopped;

            action reduceFrequency;
            action deenergizeMotor;
        }

        action def DeliverPulse {
            in strokeVolume : Volume;
            out deliveredVolume : Volume;

            first drawFluid;
            then compressChamber;
            then expelFluid;
            then complete;

            action drawFluid;
            action compressChamber;
            action expelFluid {
                deliveredVolume = strokeVolume * volumetricEfficiency;
            }
        }

        state def PulserPumpOperatingState {
            entry; then Off;

            state Off;
            state Priming;
            state Standby;
            state Running;
            state PressureLimited;
            state Faulted;

            transition Off_to_Priming
                first Off
                accept commandIn.signal.command == "START"
                then Priming;

            transition Priming_to_Standby
                first Priming
                accept after 3.0
                then Standby;

            transition Standby_to_Running
                first Standby
                accept commandIn.signal.command == "RUN"
                then Running;

            transition Running_to_PressureLimited
                first Running
                accept when discharge.pressure >= ratedDischargePressure
                then PressureLimited;

            transition PressureLimited_to_Running
                first PressureLimited
                accept when discharge.pressure < ratedDischargePressure * 0.92
                then Running;

            transition Running_to_Faulted
                first Running
                accept when suction.pressure < netPositiveSuctionPressureRequired or caseTemperature > caseTemperatureLimit or discharge.pressure > maximumDischargePressure
                then Faulted;

            transition PressureLimited_to_Faulted
                first PressureLimited
                accept when discharge.pressure > maximumDischargePressure
                then Faulted;

            transition Running_to_Standby
                first Running
                accept commandIn.signal.command == "HOLD"
                then Standby;

            transition Standby_to_Off
                first Standby
                accept commandIn.signal.command == "STOP"
                then Off;

            transition Faulted_to_Off
                first Faulted
                accept commandIn.signal.command == "RESET"
                then Off;
        }

        exhibit stateMachine : PulserPumpOperatingState;

        constraint generatedFlow {
            discharge.flowRate == displacementPerStroke * actualPulseFrequency * volumetricEfficiency
        }

        constraint pressureCapability {
            discharge.pressure <= maximumDischargePressure
        }

        constraint suctionProtection {
            suction.pressure >= netPositiveSuctionPressureRequired
        }
    }

    part def PulsationDampener {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute gasPrechargePressure : Pressure = 550000;
        attribute shellPressureRating : Pressure = 1800000;
        attribute effectiveGasVolume : Volume = 0.0015;
        attribute rippleReductionRatio : Percentage = 75;

        requirement dampenerRequirement {
            doc /* The pulsation dampener shall reduce peak-to-peak discharge pressure ripple by at least 75 percent at nominal pump flow. */
        }
    }

    part def PressureReliefValve {
        port inlet : FluidPort;
        port bypassOutlet : FluidPort;

        attribute setPressure : Pressure = 1350000;
        attribute reseatPressure : Pressure = 1200000;
        attribute reliefCapacity : FlowRate = 0.000020;

        state def ReliefValveState {
            entry; then Closed;
            state Closed;
            state Relieving;

            transition Closed_to_Relieving
                first Closed
                accept when inlet.pressure >= setPressure
                then Relieving;

            transition Relieving_to_Closed
                first Relieving
                accept when inlet.pressure <= reseatPressure
                then Closed;
        }

        exhibit stateMachine : ReliefValveState;
    }

    part def OutletManifold {
        port pumpInlet : FluidPort;
        port dampenerOutlet : FluidPort;
        port systemOutlet : FluidPort;
        port reliefBranch : FluidPort;

        attribute internalVolume : Volume = 0.00020;
        attribute pressureRating : Pressure = 1600000;
    }

    part def PressureSensor {
        port processPort : FluidPort;
        port signalOut : SignalOutPort;

        attribute rangeMinimum : Pressure = 0;
        attribute rangeMaximum : Pressure = 2000000;
        attribute accuracyPercentFullScale : Percentage = 0.5;
        attribute samplePeriod : TimeDuration = 0.02;

        constraint range {
            processPort.pressure >= rangeMinimum and processPort.pressure <= rangeMaximum
        }
    }

    part def FlowSensor {
        port processIn : FluidPort;
        port processOut : FluidPort;
        port signalOut : SignalOutPort;

        attribute rangeMinimum : FlowRate = 0;
        attribute rangeMaximum : FlowRate = 0.000030;
        attribute accuracyPercentReading : Percentage = 1.0;
        attribute samplePeriod : TimeDuration = 0.05;
    }

    part def MotorController {
        port powerInput : ElectricalPort;
        port pumpPowerOutput : ElectricalPort;
        port commandOutput : SignalInPort;
        port pressureFeedback : SignalOutPort;
        port flowFeedback : SignalOutPort;
        port faultInput : SignalOutPort;

        attribute dcBusVoltage : ElectricVoltage = 48;
        attribute maximumOutputCurrent : ElectricCurrent = 8;
        attribute controlLoopPeriod : TimeDuration = 0.01;
        attribute targetFlowRate : FlowRate = 0.00000875;
        attribute targetPressureLimit : Pressure = 1200000;
        attribute commandedFrequency : RotationalSpeed;
        attribute controllerEfficiency : Efficiency = 0.94;

        action def ComputePulseFrequency {
            in desiredFlow : FlowRate;
            in displacement : Volume;
            in efficiency : Efficiency;
            out frequencyCommand : RotationalSpeed;

            first calculate;
            then limit;

            action calculate {
                frequencyCommand = desiredFlow / (displacement * efficiency);
            }

            action limit {
                if frequencyCommand > 50 then frequencyCommand = 50;
                if frequencyCommand < 2 then frequencyCommand = 2;
            }
        }

        state def ControllerState {
            entry; then Disabled;

            state Disabled;
            state Ready;
            state ClosedLoopFlowControl;
            state PressureLimitControl;
            state ShutdownFault;

            transition Disabled_to_Ready
                first Disabled
                accept commandOutput.signal.command == "ENABLE"
                then Ready;

            transition Ready_to_ClosedLoopFlowControl
                first Ready
                accept commandOutput.signal.command == "RUN"
                then ClosedLoopFlowControl;

            transition ClosedLoopFlowControl_to_PressureLimitControl
                first ClosedLoopFlowControl
                accept when pressureFeedback.signal.measuredValue >= targetPressureLimit
                then PressureLimitControl;

            transition PressureLimitControl_to_ClosedLoopFlowControl
                first PressureLimitControl
                accept when pressureFeedback.signal.measuredValue < targetPressureLimit * 0.92
                then ClosedLoopFlowControl;

            transition ClosedLoopFlowControl_to_ShutdownFault
                first ClosedLoopFlowControl
                accept when faultInput.signal.valid
                then ShutdownFault;

            transition PressureLimitControl_to_ShutdownFault
                first PressureLimitControl
                accept when faultInput.signal.valid
                then ShutdownFault;

            transition ShutdownFault_to_Disabled
                first ShutdownFault
                accept commandOutput.signal.command == "RESET"
                then Disabled;
        }

        exhibit stateMachine : ControllerState;
    }

    part def ThermalSwitch {
        port signalOut : SignalOutPort;

        attribute tripTemperature : Temperature = 363.15;
        attribute resetTemperature : Temperature = 348.15;

        state def ThermalSwitchState {
            entry; then Normal;
            state Normal;
            state Tripped;

            transition Normal_to_Tripped
                first Normal
                accept when signalOut.signal.measuredValue >= tripTemperature
                then Tripped;

            transition Tripped_to_Normal
                first Tripped
                accept when signalOut.signal.measuredValue <= resetTemperature
                then Normal;
        }

        exhibit stateMachine : ThermalSwitchState;
    }

    part def PumpingSubsystem {
        port fluidSupply : FluidPort;
        port fluidDelivery : FluidPort;
        port electricalInput : ElectricalPort;
        port externalCommand : SignalInPort;
        port statusOutput : SignalOutPort;

        part reservoir : Reservoir;
        part suctionStrainer : SuctionStrainer;
        part inletCheckValve : InletCheckValve;
        part pulserPump : PulserPump;
        part outletCheckValve : OutletCheckValve;
        part dampener : PulsationDampener;
        part outletManifold : OutletManifold;
        part reliefValve : PressureReliefValve;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : MotorController;
        part thermalSwitch : ThermalSwitch;

        attribute requiredNominalFlow : FlowRate = 0.00000875;
        attribute requiredMinimumFlow : FlowRate = 0.00000600;
        attribute requiredOutletPressure : Pressure = 1000000;
        attribute maximumSafePressure : Pressure = 1500000;
        attribute maximumPressureRipple : Pressure = 60000;
        attribute startupTimeLimit : TimeDuration = 5;
        attribute dryMassLimit : Real = 12.5;
        attribute operatingTemperatureMinimum : Temperature = 273.15;
        attribute operatingTemperatureMaximum : Temperature = 323.15;

        connect fluidSupply to reservoir.outlet;
        connect reservoir.outlet to suctionStrainer.inlet;
        connect suctionStrainer.outlet to inletCheckValve.upstream;
        connect inletCheckValve.downstream to pulserPump.suction;
        connect pulserPump.discharge to outletCheckValve.upstream;
        connect outletCheckValve.downstream to dampener.inlet;
        connect dampener.outlet to outletManifold.dampenerOutlet;
        connect outletManifold.systemOutlet to flowSensor.processIn;
        connect flowSensor.processOut to fluidDelivery;
        connect outletManifold.reliefBranch to reliefValve.inlet;
        connect reliefValve.bypassOutlet to reservoir.returnInlet;
        connect outletManifold.systemOutlet to pressureSensor.processPort;

        connect electricalInput to controller.powerInput;
        connect controller.pumpPowerOutput to pulserPump.electricalSupply;
        connect externalCommand to controller.commandOutput;
        connect controller.commandOutput to pulserPump.commandIn;
        connect pressureSensor.signalOut to controller.pressureFeedback;
        connect flowSensor.signalOut to controller.flowFeedback;
        connect pulserPump.faultOut to controller.faultInput;
        connect thermalSwitch.signalOut to statusOutput;

        constraint nominalDelivery {
            fluidDelivery.flowRate >= requiredNominalFlow and fluidDelivery.pressure >= requiredOutletPressure
        }

        constraint minimumDelivery {
            fluidDelivery.flowRate >= requiredMinimumFlow
        }

        constraint safePressure {
            fluidDelivery.pressure <= maximumSafePressure
        }

        constraint reliefSetBelowMaximum {
            reliefValve.setPressure < maximumSafePressure
        }

        constraint pumpAndControllerCompatibility {
            controller.maximumOutputCurrent * controller.dcBusVoltage >= pulserPump.motorPowerRating
        }

        constraint reservoirCapacityAdequacy {
            reservoir.usableVolume >= requiredNominalFlow * 300
        }

        state def SubsystemState {
            entry; then Unpowered;

            state Unpowered;
            state Initializing;
            state Ready;
            state Pumping;
            state RecirculatingRelief;
            state ControlledShutdown;
            state Fault;

            transition Unpowered_to_Initializing
                first Unpowered
                accept externalCommand.signal.command == "POWER_ON"
                then Initializing;

            transition Initializing_to_Ready
                first Initializing
                accept after 2.0
                then Ready;

            transition Ready_to_Pumping
                first Ready
                accept externalCommand.signal.command == "START"
                then Pumping;

            transition Pumping_to_RecirculatingRelief
                first Pumping
                accept when outletManifold.systemOutlet.pressure >= reliefValve.setPressure
                then RecirculatingRelief;

            transition RecirculatingRelief_to_Pumping
                first RecirculatingRelief
                accept when outletManifold.systemOutlet.pressure <= reliefValve.reseatPressure
                then Pumping;

            transition Pumping_to_ControlledShutdown
                first Pumping
                accept externalCommand.signal.command == "STOP"
                then ControlledShutdown;

            transition RecirculatingRelief_to_ControlledShutdown
                first RecirculatingRelief
                accept externalCommand.signal.command == "STOP"
                then ControlledShutdown;

            transition ControlledShutdown_to_Ready
                first ControlledShutdown
                accept after 1.5
                then Ready;

            transition Pumping_to_Fault
                first Pumping
                accept when pressureSensor.processPort.pressure > maximumSafePressure or reservoir.fluidLevelPercent < 10
                then Fault;

            transition Fault_to_Ready
                first Fault
                accept externalCommand.signal.command == "RESET"
                then Ready;
        }

        exhibit stateMachine : SubsystemState;
    }

    requirement def NominalFlowRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.fluidDelivery.flowRate >= subsystem.requiredNominalFlow
        }
        doc /* The pumping subsystem shall deliver at least 0.00000875 cubic meters per second of fluid during nominal operation. */
    }

    requirement def OutletPressureRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.fluidDelivery.pressure >= subsystem.requiredOutletPressure
        }
        doc /* The pumping subsystem shall provide a nominal outlet pressure of at least 1.0 MPa. */
    }

    requirement def OverPressureProtectionRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.reliefValve.setPressure < subsystem.maximumSafePressure and subsystem.fluidDelivery.pressure <= subsystem.maximumSafePressure
        }
        doc /* The pumping subsystem shall protect downstream equipment from pressure above 1.5 MPa. */
    }

    requirement def PulsationRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.maximumPressureRipple <= 60000
        }
        doc /* The pumping subsystem shall limit discharge pressure ripple to no more than 60 kPa peak-to-peak after the pulsation dampener. */
    }

    requirement def StartupRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.startupTimeLimit <= 5
        }
        doc /* The pumping subsystem shall reach commanded nominal flow within 5 seconds after receiving a START command. */
    }

    requirement def DryRunProtectionRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.pulserPump.allowedDryRunTime <= 5 and subsystem.reservoir.minimumOperatingVolume >= 0.008
        }
        doc /* The pumping subsystem shall detect insufficient supply fluid and prevent dry running beyond 5 seconds. */
    }

    requirement def SuctionPressureRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.pulserPump.suction.pressure >= subsystem.pulserPump.netPositiveSuctionPressureRequired
        }
        doc /* The pump inlet shall maintain sufficient suction pressure to avoid cavitation during commanded operation. */
    }

    requirement def ElectricalCompatibilityRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.controller.dcBusVoltage == 48 and subsystem.controller.maximumOutputCurrent >= 8
        }
        doc /* The pumping subsystem shall operate from a 48 VDC electrical input with no more than 8 A controller output current under nominal load. */
    }

    requirement def TemperatureRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.operatingTemperatureMinimum <= subsystem.pulserPump.caseTemperature and subsystem.pulserPump.caseTemperature <= subsystem.pulserPump.caseTemperatureLimit
        }
        doc /* The pumping subsystem shall operate without thermal shutdown across the specified ambient operating temperature range. */
    }

    part pumpingSubsystem : PumpingSubsystem;

    satisfy NominalFlowRequirement by pumpingSubsystem;
    satisfy OutletPressureRequirement by pumpingSubsystem;
    satisfy OverPressureProtectionRequirement by pumpingSubsystem;
    satisfy PulsationRequirement by pumpingSubsystem;
    satisfy StartupRequirement by pumpingSubsystem;
    satisfy DryRunProtectionRequirement by pumpingSubsystem;
    satisfy SuctionPressureRequirement by pumpingSubsystem;
    satisfy ElectricalCompatibilityRequirement by pumpingSubsystem;
    satisfy TemperatureRequirement by pumpingSubsystem;
}