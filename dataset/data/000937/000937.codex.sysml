package ScrewPumpPumpingSubsystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import Time::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def RotationalSpeed {
        :>> scalarValue: Real;
        unit = SI::revolutionPerMinute;
    }

    attribute def Torque {
        :>> scalarValue: Real;
        unit = SI::newtonMetre;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::litre;
    }

    attribute def Viscosity {
        :>> scalarValue: Real;
        unit = SI::pascal * SI::second;
    }

    attribute def Percentage {
        :>> scalarValue: Real;
        unit = SI::one;
    }

    item def WorkingFluid {
        attribute density : ISQ::density;
        attribute dynamicViscosity : Viscosity;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
        attribute realPower : Power;
    }

    item def ControlSignal {
        attribute commandValue : Percentage;
        attribute enabled : Boolean;
    }

    item def SensorSignal {
        attribute measuredPressure : Pressure;
        attribute measuredFlow : FlowRate;
        attribute measuredTemperature : Temperature;
        attribute valid : Boolean;
    }

    port def FluidPort {
        inout fluid : WorkingFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def PowerPort {
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
        attribute usableVolume : Volume = 500 [SI::litre];
        attribute minimumLevel : Percentage = 0.10;
        attribute currentLevel : Percentage;
    }

    part def InletStrainer {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute meshRating : Real = 250;
        attribute maxCleanDifferentialPressure : Pressure = 15000 [SI::pascal];
        attribute clogged : Boolean;
    }

    part def IsolationValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        in control : ControlSignal;
        attribute commandedOpen : Boolean;
        attribute actualOpen : Boolean;
        attribute pressureDropWhenOpen : Pressure = 5000 [SI::pascal];
    }

    part def ScrewPump {
        port suction : FluidPort;
        port discharge : FluidPort;
        port shaftPower : PowerPort;
        in speedCommand : ControlSignal;

        attribute displacementPerRevolution : Volume = 0.075 [SI::litre];
        attribute nominalSpeed : RotationalSpeed = 1800 [SI::revolutionPerMinute];
        attribute minimumSpeed : RotationalSpeed = 300 [SI::revolutionPerMinute];
        attribute maximumSpeed : RotationalSpeed = 2400 [SI::revolutionPerMinute];
        attribute nominalFlow : FlowRate = 0.0021 [SI::cubicMetrePerSecond];
        attribute maximumDischargePressure : Pressure = 1200000 [SI::pascal];
        attribute minimumSuctionPressure : Pressure = 60000 [SI::pascal];
        attribute volumetricEfficiency : Percentage = 0.88;
        attribute mechanicalEfficiency : Percentage = 0.82;
        attribute casingTemperature : Temperature;
        attribute running : Boolean;
        attribute internalBypassOpen : Boolean;

        action startPump {
            in requestedSpeed : RotationalSpeed;
            out accepted : Boolean;

            first start;
            then verifySpeed;
            then energizeMotor;
            then buildPressure;
            then complete;

            action verifySpeed {
                in speed : RotationalSpeed = requestedSpeed;
                out speedValid : Boolean;
            }

            action energizeMotor {
                in enablePower : Boolean = true;
            }

            action buildPressure {
                out dischargePressureEstablished : Boolean;
            }
        }

        action stopPump {
            first reduceSpeed;
            then deenergizeMotor;
            then completeStop;

            action reduceSpeed;
            action deenergizeMotor;
            action completeStop;
        }

        action moveFluid {
            in inletFluid : WorkingFluid;
            in speed : RotationalSpeed;
            out outletFluid : WorkingFluid;
            out deliveredFlow : FlowRate;
            out pressureRise : Pressure;
        }

        state def PumpOperatingState {
            state off;
            state starting;
            state runningNormal;
            state bypassing;
            state cavitationRisk;
            state faulted;
            state stopping;

            transition first off;

            transition startCommand
                first off
                accept ControlSignal
                if signal.enabled
                then starting;

            transition pressureBuilt
                first starting
                if discharge.pressure > suction.pressure
                then runningNormal;

            transition highDischargePressure
                first runningNormal
                if discharge.pressure > maximumDischargePressure * 0.95
                then bypassing;

            transition pressureRecovered
                first bypassing
                if discharge.pressure < maximumDischargePressure * 0.85
                then runningNormal;

            transition lowSuctionPressure
                first runningNormal
                if suction.pressure < minimumSuctionPressure
                then cavitationRisk;

            transition suctionRecovered
                first cavitationRisk
                if suction.pressure >= minimumSuctionPressure * 1.15
                then runningNormal;

            transition severeFault
                first cavitationRisk
                if suction.pressure < minimumSuctionPressure * 0.75
                then faulted;

            transition overPressureFault
                first bypassing
                if discharge.pressure > maximumDischargePressure
                then faulted;

            transition stopCommand
                first runningNormal
                accept ControlSignal
                if not signal.enabled
                then stopping;

            transition stopped
                first stopping
                then off;
        }

        perform stateMachine : PumpOperatingState;
    }

    part def ElectricMotor {
        port powerSupply : PowerPort;
        out shaftOutput : PowerPort;
        in speedReference : ControlSignal;

        attribute ratedPower : Power = 7500 [SI::watt];
        attribute ratedSpeed : RotationalSpeed = 1800 [SI::revolutionPerMinute];
        attribute ratedTorque : Torque = 39.8 [SI::newtonMetre];
        attribute efficiency : Percentage = 0.91;
        attribute windingTemperature : Temperature;
        attribute energized : Boolean;

        action convertElectricalToMechanicalPower {
            in electricalInput : ElectricalPower;
            in commandedSpeed : RotationalSpeed;
            out mechanicalPower : Power;
            out shaftSpeed : RotationalSpeed;
            out availableTorque : Torque;
        }
    }

    part def VariableFrequencyDrive {
        port supplyInput : PowerPort;
        port motorOutput : PowerPort;
        in commandInput : ControlSignal;
        out statusOutput : SignalOutPort;

        attribute minimumFrequency : ISQ::frequency = 10 [SI::hertz];
        attribute maximumFrequency : ISQ::frequency = 80 [SI::hertz];
        attribute outputFrequency : ISQ::frequency;
        attribute enabled : Boolean;
        attribute faultPresent : Boolean;

        action regulateMotorSpeed {
            in speedDemand : Percentage;
            out outputFrequencyCommand : ISQ::frequency;
        }
    }

    part def PressureSensor {
        port processPort : FluidPort;
        out measurement : SignalOutPort;
        attribute rangeMinimum : Pressure = 0 [SI::pascal];
        attribute rangeMaximum : Pressure = 1600000 [SI::pascal];
        attribute accuracy : Percentage = 0.005;
    }

    part def FlowSensor {
        port processPort : FluidPort;
        out measurement : SignalOutPort;
        attribute rangeMinimum : FlowRate = 0 [SI::cubicMetrePerSecond];
        attribute rangeMaximum : FlowRate = 0.004 [SI::cubicMetrePerSecond];
        attribute accuracy : Percentage = 0.01;
    }

    part def ReliefValve {
        port inlet : FluidPort;
        port returnOutlet : FluidPort;
        attribute setPressure : Pressure = 1100000 [SI::pascal];
        attribute reseatPressure : Pressure = 950000 [SI::pascal];
        attribute relieving : Boolean;

        state def ReliefValveState {
            state closed;
            state opening;
            state relieving;
            state reseating;

            transition first closed;

            transition crack
                first closed
                if inlet.pressure >= setPressure
                then opening;

            transition fullyOpen
                first opening
                then relieving;

            transition pressureReduced
                first relieving
                if inlet.pressure <= reseatPressure
                then reseating;

            transition seated
                first reseating
                then closed;
        }

        perform stateMachine : ReliefValveState;
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 10000 [SI::pascal];
        attribute open : Boolean;
    }

    part def DischargeAccumulator {
        port processPort : FluidPort;
        attribute prechargePressure : Pressure = 450000 [SI::pascal];
        attribute gasVolume : Volume = 12 [SI::litre];
        attribute dampedPressureRipple : Pressure;
    }

    part def PumpController {
        in operatorCommand : SignalInPort;
        in inletPressureSignal : SignalOutPort;
        in dischargePressureSignal : SignalOutPort;
        in flowSignal : SignalOutPort;
        out driveCommand : SignalInPort;
        out inletValveCommand : SignalInPort;
        out outletValveCommand : SignalInPort;

        attribute targetFlow : FlowRate = 0.0020 [SI::cubicMetrePerSecond];
        attribute lowSuctionTrip : Pressure = 55000 [SI::pascal];
        attribute highDischargeTrip : Pressure = 1200000 [SI::pascal];
        attribute minimumAllowedFlow : FlowRate = 0.0004 [SI::cubicMetrePerSecond];
        attribute commandedSpeedPercent : Percentage;
        attribute shutdownRequested : Boolean;

        action calculateSpeedCommand {
            in requestedFlow : FlowRate;
            in actualFlow : FlowRate;
            out speedCommand : Percentage;
        }

        action protectPump {
            in suctionPressure : Pressure;
            in dischargePressure : Pressure;
            in flow : FlowRate;
            out permitRun : Boolean;
            out tripReason : String;
        }

        state def ControllerState {
            state idle;
            state permissiveCheck;
            state starting;
            state regulating;
            state protectiveShutdown;
            state stopped;

            transition first idle;

            transition commandStart
                first idle
                accept ControlSignal
                if signal.enabled
                then permissiveCheck;

            transition permissivesOk
                first permissiveCheck
                if inletPressureSignal.signal.measuredPressure > lowSuctionTrip
                then starting;

            transition noPermissive
                first permissiveCheck
                if inletPressureSignal.signal.measuredPressure <= lowSuctionTrip
                then protectiveShutdown;

            transition atFlow
                first starting
                if flowSignal.signal.measuredFlow >= minimumAllowedFlow
                then regulating;

            transition abnormalPressure
                first regulating
                if dischargePressureSignal.signal.measuredPressure >= highDischargeTrip
                then protectiveShutdown;

            transition suctionLoss
                first regulating
                if inletPressureSignal.signal.measuredPressure <= lowSuctionTrip
                then protectiveShutdown;

            transition commandStop
                first regulating
                accept ControlSignal
                if not signal.enabled
                then stopped;

            transition reset
                first protectiveShutdown
                accept ControlSignal
                if not signal.enabled
                then stopped;
        }

        perform stateMachine : ControllerState;
    }

    part def PipingSegment {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute insideDiameter : ISQ::length;
        attribute length : ISQ::length;
        attribute roughness : ISQ::length;
        attribute pressureLossAtNominalFlow : Pressure;
    }

    part def PumpingSubsystem {
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port electricalSupply : PowerPort;
        in operatorStartStop : SignalInPort;
        out subsystemStatus : SignalOutPort;

        part sourceReservoir : Reservoir;
        part suctionPipe : PipingSegment {
            :>> insideDiameter = 0.05 [SI::metre];
            :>> length = 2.0 [SI::metre];
            :>> roughness = 0.000045 [SI::metre];
            :>> pressureLossAtNominalFlow = 8000 [SI::pascal];
        }

        part suctionStrainer : InletStrainer;
        part inletIsolationValve : IsolationValve;
        part mainPump : ScrewPump;
        part driveMotor : ElectricMotor;
        part vfd : VariableFrequencyDrive;
        part dischargeCheckValve : CheckValve;
        part dischargePipe : PipingSegment {
            :>> insideDiameter = 0.04 [SI::metre];
            :>> length = 8.0 [SI::metre];
            :>> roughness = 0.000045 [SI::metre];
            :>> pressureLossAtNominalFlow = 22000 [SI::pascal];
        }

        part outletIsolationValve : IsolationValve;
        part reliefValve : ReliefValve;
        part accumulator : DischargeAccumulator;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part dischargeFlowSensor : FlowSensor;
        part controller : PumpController;

        connection externalSupplyToVfd
            connect electricalSupply to vfd.supplyInput;

        connection vfdToMotor
            connect vfd.motorOutput to driveMotor.powerSupply;

        connection motorToPump
            connect driveMotor.shaftOutput to mainPump.shaftPower;

        connection externalInletToReservoir
            connect fluidInlet to sourceReservoir.outlet;

        connection reservoirToSuctionPipe
            connect sourceReservoir.outlet to suctionPipe.inlet;

        connection suctionPipeToStrainer
            connect suctionPipe.outlet to suctionStrainer.inlet;

        connection strainerToInletValve
            connect suctionStrainer.outlet to inletIsolationValve.inlet;

        connection inletValveToPump
            connect inletIsolationValve.outlet to mainPump.suction;

        connection pumpToCheckValve
            connect mainPump.discharge to dischargeCheckValve.inlet;

        connection checkValveToAccumulator
            connect dischargeCheckValve.outlet to accumulator.processPort;

        connection accumulatorToDischargePipe
            connect accumulator.processPort to dischargePipe.inlet;

        connection dischargePipeToOutletValve
            connect dischargePipe.outlet to outletIsolationValve.inlet;

        connection outletValveToExternalOutlet
            connect outletIsolationValve.outlet to fluidOutlet;

        connection reliefInlet
            connect mainPump.discharge to reliefValve.inlet;

        connection reliefReturn
            connect reliefValve.returnOutlet to sourceReservoir.outlet;

        connection suctionPressureTap
            connect mainPump.suction to suctionPressureSensor.processPort;

        connection dischargePressureTap
            connect mainPump.discharge to dischargePressureSensor.processPort;

        connection flowTap
            connect dischargePipe.outlet to dischargeFlowSensor.processPort;

        connection operatorToController
            connect operatorStartStop to controller.operatorCommand;

        connection controllerToVfd
            connect controller.driveCommand to vfd.commandInput;

        connection controllerToInletValve
            connect controller.inletValveCommand to inletIsolationValve.control;

        connection controllerToOutletValve
            connect controller.outletValveCommand to outletIsolationValve.control;

        connection controllerToPumpSpeed
            connect controller.driveCommand to mainPump.speedCommand;

        connection suctionSensorToController
            connect suctionPressureSensor.measurement to controller.inletPressureSignal;

        connection dischargeSensorToController
            connect dischargePressureSensor.measurement to controller.dischargePressureSignal;

        connection flowSensorToController
            connect dischargeFlowSensor.measurement to controller.flowSignal;

        connection statusConnection
            connect vfd.statusOutput to subsystemStatus;

        action startSubsystem {
            first openInletValve;
            then openOutletValve;
            then verifySuctionPressure;
            then rampPumpSpeed;
            then confirmFlow;

            action openInletValve;
            action openOutletValve;
            action verifySuctionPressure;
            action rampPumpSpeed;
            action confirmFlow;
        }

        action stopSubsystem {
            first rampDownPump;
            then stopMotor;
            then closeOutletValve;
            then closeInletValve;

            action rampDownPump;
            action stopMotor;
            action closeOutletValve;
            action closeInletValve;
        }

        action maintainFlow {
            in demandedFlow : FlowRate;
            out actualFlow : FlowRate;
            out speedCommand : Percentage;
        }

        state def SubsystemState {
            state unavailable;
            state ready;
            state starting;
            state pumping;
            state recirculatingRelief;
            state controlledStop;
            state emergencyStop;
            state maintenanceIsolated;

            transition first unavailable;

            transition supplyAvailable
                first unavailable
                if electricalSupply.powerIn.realPower > 0 [SI::watt]
                then ready;

            transition startRequested
                first ready
                accept ControlSignal
                if signal.enabled
                then starting;

            transition flowEstablished
                first starting
                if dischargeFlowSensor.measurement.signal.measuredFlow >= controller.minimumAllowedFlow
                then pumping;

            transition reliefActive
                first pumping
                if reliefValve.relieving
                then recirculatingRelief;

            transition reliefCleared
                first recirculatingRelief
                if not reliefValve.relieving
                then pumping;

            transition normalStop
                first pumping
                accept ControlSignal
                if not signal.enabled
                then controlledStop;

            transition stopComplete
                first controlledStop
                then ready;

            transition protectionTrip
                first pumping
                if controller.shutdownRequested
                then emergencyStop;

            transition isolate
                first ready
                if not inletIsolationValve.actualOpen and not outletIsolationValve.actualOpen
                then maintenanceIsolated;

            transition returnToReady
                first maintenanceIsolated
                if inletIsolationValve.actualOpen and outletIsolationValve.actualOpen
                then ready;
        }

        perform stateMachine : SubsystemState;
    }

    requirement def MoveFluidRequirement {
        doc /* The pumping subsystem shall move working fluid from the fluid inlet to the fluid outlet using a screw pump as the primary energy-transfer device. */
    }

    requirement def FlowCapacityRequirement {
        doc /* The subsystem shall deliver at least 0.002 cubic metre per second of working fluid at nominal operating conditions. */
        attribute requiredFlow : FlowRate = 0.002 [SI::cubicMetrePerSecond];
    }

    requirement def PressureRiseRequirement {
        doc /* The screw pump shall provide a pressure rise sufficient to maintain outlet pressure up to 1.0 MPa during rated flow operation. */
        attribute requiredOutletPressure : Pressure = 1000000 [SI::pascal];
    }

    requirement def SuctionProtectionRequirement {
        doc /* The controller shall stop the screw pump when suction pressure falls to or below 55 kPa to reduce cavitation risk. */
        attribute tripPressure : Pressure = 55000 [SI::pascal];
    }

    requirement def OverpressureProtectionRequirement {
        doc /* The subsystem shall limit discharge pressure by relief valve action and controller trip before pressure exceeds 1.2 MPa. */
        attribute maximumAllowedPressure : Pressure = 1200000 [SI::pascal];
    }

    requirement def ReverseFlowPreventionRequirement {
        doc /* The discharge check valve shall prevent reverse flow from the outlet side toward the screw pump when pump discharge pressure is lower than downstream pressure. */
    }

    requirement def ControlledStartRequirement {
        doc /* The subsystem shall open isolation valves and ramp screw pump speed through the variable frequency drive before declaring pumping operation. */
    }

    requirement def ControlledStopRequirement {
        doc /* The subsystem shall ramp down screw pump speed before closing the outlet and inlet isolation valves during a normal stop. */
    }

    requirement def MonitoringRequirement {
        doc /* The subsystem shall measure suction pressure, discharge pressure, and discharge flow and provide these measurements to the pump controller. */
    }

    part screwPumpPumpingSubsystem : PumpingSubsystem;

    satisfy MoveFluidRequirement by screwPumpPumpingSubsystem.mainPump;
    satisfy FlowCapacityRequirement by screwPumpPumpingSubsystem.mainPump;
    satisfy PressureRiseRequirement by screwPumpPumpingSubsystem.mainPump;
    satisfy SuctionProtectionRequirement by screwPumpPumpingSubsystem.controller;
    satisfy OverpressureProtectionRequirement by screwPumpPumpingSubsystem.reliefValve;
    satisfy OverpressureProtectionRequirement by screwPumpPumpingSubsystem.controller;
    satisfy ReverseFlowPreventionRequirement by screwPumpPumpingSubsystem.dischargeCheckValve;
    satisfy ControlledStartRequirement by screwPumpPumpingSubsystem;
    satisfy ControlledStopRequirement by screwPumpPumpingSubsystem;
    satisfy MonitoringRequirement by screwPumpPumpingSubsystem.suctionPressureSensor;
    satisfy MonitoringRequirement by screwPumpPumpingSubsystem.dischargePressureSensor;
    satisfy MonitoringRequirement by screwPumpPumpingSubsystem.dischargeFlowSensor;

    constraint def ScrewPumpFlowEquation {
        in displacementPerRevolution : Volume;
        in rotationalSpeed : RotationalSpeed;
        in volumetricEfficiency : Percentage;
        out theoreticalFlow : FlowRate;

        theoreticalFlow == displacementPerRevolution * rotationalSpeed * volumetricEfficiency;
    }

    constraint def HydraulicPowerEquation {
        in pressureRise : Pressure;
        in deliveredFlow : FlowRate;
        out hydraulicPower : Power;

        hydraulicPower == pressureRise * deliveredFlow;
    }

    constraint def RequiredShaftPowerEquation {
        in hydraulicPower : Power;
        in mechanicalEfficiency : Percentage;
        out shaftPowerRequired : Power;

        shaftPowerRequired == hydraulicPower / mechanicalEfficiency;
    }

    constraint def ReliefValveLogic {
        in dischargePressure : Pressure;
        in setPressure : Pressure;
        out reliefRequired : Boolean;

        reliefRequired == dischargePressure >= setPressure;
    }

    assert constraint ScrewPumpFlowEquation {
        displacementPerRevolution = screwPumpPumpingSubsystem.mainPump.displacementPerRevolution;
        rotationalSpeed = screwPumpPumpingSubsystem.mainPump.nominalSpeed;
        volumetricEfficiency = screwPumpPumpingSubsystem.mainPump.volumetricEfficiency;
        theoreticalFlow = screwPumpPumpingSubsystem.mainPump.nominalFlow;
    }

    assert constraint ReliefValveLogic {
        dischargePressure = screwPumpPumpingSubsystem.mainPump.discharge.pressure;
        setPressure = screwPumpPumpingSubsystem.reliefValve.setPressure;
        reliefRequired = screwPumpPumpingSubsystem.reliefValve.relieving;
    }
}