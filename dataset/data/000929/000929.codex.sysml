package PumpingSubsystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def Fluid {
        attribute density : Real;
        attribute dynamicViscosity : Real;
        attribute vaporPressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def HydraulicPower {
        attribute pressure : PressureValue;
        attribute volumetricFlowRate : VolumetricFlowRateValue;
    }

    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute angularSpeed : AngularVelocityValue;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
    }

    value def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    value def VolumetricFlowRateValue :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    value def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    value def TorqueValue :> ISQ::momentOfForce {
        unit = SI::newtonMetre;
    }

    value def AngularVelocityValue :> ISQ::angularVelocity {
        unit = SI::radianPerSecond;
    }

    value def ElectricPotentialValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    value def ElectricCurrentValue :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    value def FrequencyValue :> ISQ::frequency {
        unit = SI::hertz;
    }

    value def StrokeLengthValue :> ISQ::length {
        unit = SI::metre;
    }

    value def BoreDiameterValue :> ISQ::length {
        unit = SI::metre;
    }

    value def VolumeValue :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    value def TimeValue :> ISQ::time {
        unit = SI::second;
    }

    port def FluidPort {
        inout item fluid : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : VolumetricFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    port def MechanicalShaftPort {
        inout item power : MechanicalPower;
        attribute torque : TorqueValue;
        attribute speed : AngularVelocityValue;
    }

    port def ElectricalPort {
        in item power : ElectricalPower;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def ControlPort {
        in attribute startCommand : Boolean;
        in attribute stopCommand : Boolean;
        in attribute emergencyStop : Boolean;
        out attribute runningStatus : Boolean;
        out attribute faultStatus : Boolean;
        out attribute measuredDischargePressure : PressureValue;
        out attribute measuredFlowRate : VolumetricFlowRateValue;
    }

    port def DrainPort {
        out item leakedFluid : Fluid;
        attribute leakFlowRate : VolumetricFlowRateValue;
    }

    part def SuctionLine {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute nominalDiameter : BoreDiameterValue = 0.08 [SI::metre];
        attribute designPressure : PressureValue = 600000 [SI::pascal];
        attribute pressureLoss : PressureValue;

        constraint pressureDrop {
            outlet.pressure == inlet.pressure - pressureLoss;
        }
    }

    part def DischargeLine {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute nominalDiameter : BoreDiameterValue = 0.05 [SI::metre];
        attribute designPressure : PressureValue = 12000000 [SI::pascal];
        attribute pressureLoss : PressureValue;

        constraint pressureDrop {
            outlet.pressure == inlet.pressure - pressureLoss;
        }
    }

    part def CheckValve {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute crackingPressure : PressureValue = 5000 [SI::pascal];
        attribute reverseLeakageRate : VolumetricFlowRateValue = 0.000001 [SI::cubicMetrePerSecond];
        attribute open : Boolean;

        constraint openingLogic {
            open == (upstream.pressure > downstream.pressure + crackingPressure);
        }

        state def ValveState {
            entry;
            state Closed;
            state Open;

            transition first Closed;
            transition Closed_to_Open
                first Closed
                then Open
                accept when upstream.pressure > downstream.pressure + crackingPressure;

            transition Open_to_Closed
                first Open
                then Closed
                accept when upstream.pressure <= downstream.pressure + crackingPressure;
        }
    }

    part def ReliefValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute setPressure : PressureValue = 9500000 [SI::pascal];
        attribute reseatPressure : PressureValue = 8500000 [SI::pascal];
        attribute reliefFlowRate : VolumetricFlowRateValue;
        attribute open : Boolean;

        state def ReliefValveState {
            entry;
            state Seated;
            state Relieving;

            transition first Seated;

            transition Lift
                first Seated
                then Relieving
                accept when inlet.pressure >= setPressure;

            transition Reseat
                first Relieving
                then Seated
                accept when inlet.pressure <= reseatPressure;
        }
    }

    part def ElectricMotor {
        port electricalSupply : ElectricalPort;
        port shaftOutput : MechanicalShaftPort;
        port controls : ControlPort;

        attribute ratedVoltage : ElectricPotentialValue = 480 [SI::volt];
        attribute ratedCurrent : ElectricCurrentValue = 18 [SI::ampere];
        attribute ratedSpeed : AngularVelocityValue = 188.5 [SI::radianPerSecond];
        attribute ratedTorque : TorqueValue = 45 [SI::newtonMetre];
        attribute efficiency : Real = 0.91;
        attribute energized : Boolean;

        action def StartMotor {
            in attribute command : Boolean;
            out attribute energizedResult : Boolean;

            action setEnergized {
                energizedResult = command;
            }
        }

        action def StopMotor {
            out attribute energizedResult : Boolean;

            action clearEnergized {
                energizedResult = false;
            }
        }

        state def MotorOperatingState {
            entry;
            state DeEnergized;
            state Accelerating;
            state Running;
            state Tripped;

            transition first DeEnergized;

            transition Start
                first DeEnergized
                then Accelerating
                accept when controls.startCommand and not controls.emergencyStop;

            transition AtSpeed
                first Accelerating
                then Running
                accept after 3 [SI::second];

            transition Stop
                first Running
                then DeEnergized
                accept when controls.stopCommand;

            transition TripFromRunning
                first Running
                then Tripped
                accept when controls.emergencyStop or electricalSupply.current > ratedCurrent * 1.25;

            transition TripFromAccelerating
                first Accelerating
                then Tripped
                accept when controls.emergencyStop;

            transition Reset
                first Tripped
                then DeEnergized
                accept when controls.stopCommand and not controls.emergencyStop;
        }
    }

    part def CrankMechanism {
        port shaftInput : MechanicalShaftPort;

        attribute crankRadius : StrokeLengthValue = 0.04 [SI::metre];
        attribute connectingRodLength : StrokeLengthValue = 0.18 [SI::metre];
        attribute crankAngle : Real;
        attribute reciprocatingFrequency : FrequencyValue;

        constraint strokeGeometry {
            reciprocatingFrequency == shaftInput.speed / (2 * 3.14159265);
        }
    }

    part def PistonAssembly {
        attribute boreDiameter : BoreDiameterValue = 0.06 [SI::metre];
        attribute strokeLength : StrokeLengthValue = 0.08 [SI::metre];
        attribute displacementPerStroke : VolumeValue;
        attribute sealLeakageRate : VolumetricFlowRateValue = 0.000002 [SI::cubicMetrePerSecond];

        constraint displacement {
            displacementPerStroke == 3.14159265 * boreDiameter * boreDiameter * strokeLength / 4;
        }
    }

    part def PumpChamber {
        port suction : FluidPort;
        port discharge : FluidPort;
        port drain : DrainPort;

        attribute chamberVolume : VolumeValue;
        attribute minimumClearanceVolume : VolumeValue = 0.000015 [SI::cubicMetre];
        attribute chamberPressure : PressureValue;
        attribute filling : Boolean;
        attribute discharging : Boolean;

        state def ChamberCycle {
            entry;
            state SuctionStroke;
            state CompressionStroke;
            state DischargeStroke;
            state ExpansionStroke;

            transition first SuctionStroke;

            transition CompleteFill
                first SuctionStroke
                then CompressionStroke
                accept when chamberVolume >= maximumChamberVolume;

            transition ReachDischargePressure
                first CompressionStroke
                then DischargeStroke
                accept when chamberPressure > discharge.pressure;

            transition CompleteDischarge
                first DischargeStroke
                then ExpansionStroke
                accept when chamberVolume <= minimumClearanceVolume;

            transition ReachSuctionPressure
                first ExpansionStroke
                then SuctionStroke
                accept when chamberPressure < suction.pressure;
        }

        attribute maximumChamberVolume : VolumeValue = 0.000241 [SI::cubicMetre];
    }

    part def ReciprocatingPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port shaftPort : MechanicalShaftPort;
        port controls : ControlPort;
        port leakageDrain : DrainPort;

        part suctionValve : CheckValve;
        part dischargeValve : CheckValve;
        part chamber : PumpChamber;
        part piston : PistonAssembly;
        part crank : CrankMechanism;

        attribute ratedDischargePressure : PressureValue = 8000000 [SI::pascal];
        attribute maximumAllowablePressure : PressureValue = 10000000 [SI::pascal];
        attribute ratedFlowRate : VolumetricFlowRateValue = 0.0035 [SI::cubicMetrePerSecond];
        attribute volumetricEfficiency : Real = 0.88;
        attribute mechanicalEfficiency : Real = 0.86;
        attribute netPositiveSuctionHeadRequired : StrokeLengthValue = 2.5 [SI::metre];
        attribute pumpRunning : Boolean;
        attribute faulted : Boolean;

        connect suctionPort to suctionValve.upstream;
        connect suctionValve.downstream to chamber.suction;
        connect chamber.discharge to dischargeValve.upstream;
        connect dischargeValve.downstream to dischargePort;
        connect shaftPort to crank.shaftInput;
        connect chamber.drain to leakageDrain;

        constraint deliveredFlow {
            dischargePort.flowRate == piston.displacementPerStroke * crank.reciprocatingFrequency * volumetricEfficiency;
        }

        constraint dischargePressureLimit {
            dischargePort.pressure <= maximumAllowablePressure;
        }

        constraint runningStatusMapping {
            controls.runningStatus == pumpRunning;
            controls.faultStatus == faulted;
            controls.measuredDischargePressure == dischargePort.pressure;
            controls.measuredFlowRate == dischargePort.flowRate;
        }

        action def PrimePump {
            inout item primingFluid : Fluid;
            out attribute primed : Boolean;

            action fillSuctionLine;
            action ventChamber;
            action verifyContinuousLiquid {
                primed = true;
            }

            flow fillSuctionLine then ventChamber;
            flow ventChamber then verifyContinuousLiquid;
        }

        action def PumpOneCycle {
            in item inletFluid : Fluid;
            out item outletFluid : Fluid;
            out attribute displacedVolume : VolumeValue;

            action suctionStroke;
            action compressionStroke;
            action dischargeStroke;
            action expansionStroke;

            flow suctionStroke then compressionStroke;
            flow compressionStroke then dischargeStroke;
            flow dischargeStroke then expansionStroke;
        }

        state def PumpOperatingState {
            entry;
            state Idle;
            state Priming;
            state Ready;
            state Starting;
            state Pumping;
            state LowSuctionPressureTrip;
            state HighDischargePressureTrip;
            state EmergencyStopped;
            state Shutdown;

            transition first Idle;

            transition BeginPriming
                first Idle
                then Priming
                accept when controls.startCommand;

            transition Primed
                first Priming
                then Ready
                accept when suctionPort.pressure > 150000 [SI::pascal];

            transition StartPump
                first Ready
                then Starting
                accept when controls.startCommand and not controls.emergencyStop;

            transition AtOperatingSpeed
                first Starting
                then Pumping
                accept after 3 [SI::second];

            transition StopRequested
                first Pumping
                then Shutdown
                accept when controls.stopCommand;

            transition ShutdownComplete
                first Shutdown
                then Idle
                accept after 5 [SI::second];

            transition LowSuctionTrip
                first Pumping
                then LowSuctionPressureTrip
                accept when suctionPort.pressure < 100000 [SI::pascal];

            transition HighPressureTrip
                first Pumping
                then HighDischargePressureTrip
                accept when dischargePort.pressure > maximumAllowablePressure;

            transition EmergencyStopFromStarting
                first Starting
                then EmergencyStopped
                accept when controls.emergencyStop;

            transition EmergencyStopFromPumping
                first Pumping
                then EmergencyStopped
                accept when controls.emergencyStop;

            transition ResetLowSuction
                first LowSuctionPressureTrip
                then Idle
                accept when controls.stopCommand and suctionPort.pressure >= 150000 [SI::pascal];

            transition ResetHighPressure
                first HighDischargePressureTrip
                then Idle
                accept when controls.stopCommand and dischargePort.pressure < ratedDischargePressure;

            transition ResetEmergency
                first EmergencyStopped
                then Idle
                accept when controls.stopCommand and not controls.emergencyStop;
        }
    }

    part def PressureTransmitter {
        port processConnection : FluidPort;
        port signal : ControlPort;

        attribute rangeLow : PressureValue = 0 [SI::pascal];
        attribute rangeHigh : PressureValue = 10000000 [SI::pascal];
        attribute measuredPressure : PressureValue;
        attribute failed : Boolean = false;

        constraint measurement {
            measuredPressure == processConnection.pressure;
            signal.measuredDischargePressure == measuredPressure;
        }
    }

    part def FlowTransmitter {
        port processConnection : FluidPort;
        port signal : ControlPort;

        attribute rangeLow : VolumetricFlowRateValue = 0 [SI::cubicMetrePerSecond];
        attribute rangeHigh : VolumetricFlowRateValue = 0.006 [SI::cubicMetrePerSecond];
        attribute measuredFlow : VolumetricFlowRateValue;
        attribute failed : Boolean = false;

        constraint measurement {
            measuredFlow == processConnection.flowRate;
            signal.measuredFlowRate == measuredFlow;
        }
    }

    part def LocalController {
        port operatorInterface : ControlPort;
        port motorCommand : ControlPort;
        port pumpSignal : ControlPort;
        port pressureSignal : ControlPort;
        port flowSignal : ControlPort;

        attribute commandedRun : Boolean;
        attribute permissiveHealthy : Boolean;
        attribute alarmActive : Boolean;

        constraint permissiveLogic {
            permissiveHealthy == not operatorInterface.emergencyStop
                and pressureSignal.measuredDischargePressure < 9500000 [SI::pascal]
                and pumpSignal.faultStatus == false;
        }

        action def ExecuteStartSequence {
            out attribute startIssued : Boolean;

            action checkPermissives;
            action energizeMotor;
            action confirmPumpFlow;

            flow checkPermissives then energizeMotor;
            flow energizeMotor then confirmPumpFlow;
        }

        action def ExecuteStopSequence {
            out attribute stopIssued : Boolean;

            action deenergizeMotor;
            action verifyZeroFlow;

            flow deenergizeMotor then verifyZeroFlow;
        }

        state def ControlState {
            entry;
            state Standby;
            state Starting;
            state Running;
            state Stopping;
            state Alarm;

            transition first Standby;

            transition CommandStart
                first Standby
                then Starting
                accept when operatorInterface.startCommand and permissiveHealthy;

            transition StartConfirmed
                first Starting
                then Running
                accept when flowSignal.measuredFlowRate > 0.001 [SI::cubicMetrePerSecond];

            transition CommandStop
                first Running
                then Stopping
                accept when operatorInterface.stopCommand;

            transition StopConfirmed
                first Stopping
                then Standby
                accept when flowSignal.measuredFlowRate <= 0.0001 [SI::cubicMetrePerSecond];

            transition AlarmOnHighPressure
                first Running
                then Alarm
                accept when pressureSignal.measuredDischargePressure >= 9500000 [SI::pascal];

            transition AlarmOnPumpFault
                first Running
                then Alarm
                accept when pumpSignal.faultStatus;

            transition AlarmReset
                first Alarm
                then Standby
                accept when operatorInterface.stopCommand and not operatorInterface.emergencyStop;
        }
    }

    part def PumpingSubsystem {
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port electricalInput : ElectricalPort;
        port operatorControls : ControlPort;
        port drainOutlet : DrainPort;

        part suctionLine : SuctionLine;
        part dischargeLine : DischargeLine;
        part pump : ReciprocatingPump;
        part motor : ElectricMotor;
        part reliefValve : ReliefValve;
        part pressureTransmitter : PressureTransmitter;
        part flowTransmitter : FlowTransmitter;
        part controller : LocalController;

        attribute requiredFlowRate : VolumetricFlowRateValue = 0.003 [SI::cubicMetrePerSecond];
        attribute requiredDischargePressure : PressureValue = 7500000 [SI::pascal];
        attribute minimumSuctionPressure : PressureValue = 150000 [SI::pascal];
        attribute maximumDischargePressure : PressureValue = 9500000 [SI::pascal];
        attribute normalFluidTemperature : TemperatureValue = 293.15 [SI::kelvin];

        connect fluidInlet to suctionLine.inlet;
        connect suctionLine.outlet to pump.suctionPort;
        connect pump.dischargePort to dischargeLine.inlet;
        connect dischargeLine.outlet to fluidOutlet;

        connect pump.dischargePort to reliefValve.inlet;
        connect reliefValve.outlet to pump.suctionPort;

        connect electricalInput to motor.electricalSupply;
        connect motor.shaftOutput to pump.shaftPort;

        connect operatorControls to controller.operatorInterface;
        connect controller.motorCommand to motor.controls;
        connect controller.pumpSignal to pump.controls;
        connect pressureTransmitter.signal to controller.pressureSignal;
        connect flowTransmitter.signal to controller.flowSignal;

        connect pump.dischargePort to pressureTransmitter.processConnection;
        connect pump.dischargePort to flowTransmitter.processConnection;
        connect pump.leakageDrain to drainOutlet;

        constraint subsystemPerformance {
            fluidOutlet.flowRate >= requiredFlowRate;
            fluidOutlet.pressure >= requiredDischargePressure;
            fluidInlet.pressure >= minimumSuctionPressure;
            fluidOutlet.pressure <= maximumDischargePressure;
        }

        state def SubsystemState {
            entry;
            state Offline;
            state Available;
            state Starting;
            state InService;
            state ProtectedShutdown;
            state MaintenanceRequired;

            transition first Offline;

            transition PowerAvailable
                first Offline
                then Available
                accept when electricalInput.voltage >= 432 [SI::volt];

            transition Start
                first Available
                then Starting
                accept when operatorControls.startCommand;

            transition StableOperation
                first Starting
                then InService
                accept when fluidOutlet.flowRate >= requiredFlowRate
                    and fluidOutlet.pressure >= requiredDischargePressure;

            transition NormalStop
                first InService
                then Available
                accept when operatorControls.stopCommand;

            transition ProtectiveStop
                first InService
                then ProtectedShutdown
                accept when operatorControls.emergencyStop
                    or fluidOutlet.pressure > maximumDischargePressure
                    or fluidInlet.pressure < minimumSuctionPressure;

            transition ResetProtection
                first ProtectedShutdown
                then Available
                accept when operatorControls.stopCommand
                    and not operatorControls.emergencyStop
                    and fluidOutlet.pressure < requiredDischargePressure;

            transition ServiceDue
                first Available
                then MaintenanceRequired
                accept when pump.piston.sealLeakageRate > 0.00001 [SI::cubicMetrePerSecond];

            transition MaintenanceComplete
                first MaintenanceRequired
                then Available
                accept when pump.piston.sealLeakageRate <= 0.000002 [SI::cubicMetrePerSecond];
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.fluidOutlet.flowRate >= subsystem.requiredFlowRate;
            subsystem.fluidOutlet.pressure >= subsystem.requiredDischargePressure;
            subsystem.fluidOutlet.pressure <= subsystem.maximumDischargePressure;
            subsystem.fluidInlet.pressure >= subsystem.minimumSuctionPressure;
        }
    }

    requirement def ReciprocatingPumpRequirement {
        subject pump : ReciprocatingPump;

        require constraint {
            pump.ratedFlowRate >= 0.0035 [SI::cubicMetrePerSecond];
            pump.ratedDischargePressure >= 8000000 [SI::pascal];
            pump.maximumAllowablePressure >= 10000000 [SI::pascal];
            pump.volumetricEfficiency >= 0.85;
            pump.mechanicalEfficiency >= 0.80;
        }
    }

    requirement def ProtectionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.reliefValve.setPressure <= subsystem.maximumDischargePressure;
            subsystem.pump.maximumAllowablePressure > subsystem.maximumDischargePressure;
        }
    }

    requirement def ControlRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.controller.permissiveHealthy == (
                not subsystem.operatorControls.emergencyStop
                and subsystem.pressureTransmitter.measuredPressure < subsystem.maximumDischargePressure
                and subsystem.pump.faulted == false
            );
        }
    }

    requirement def LeakContainmentRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.drainOutlet.leakFlowRate <= 0.00001 [SI::cubicMetrePerSecond];
        }
    }

    part pumpingSubsystem : PumpingSubsystem {
        attribute requiredFlowRate = 0.003 [SI::cubicMetrePerSecond];
        attribute requiredDischargePressure = 7500000 [SI::pascal];
        attribute minimumSuctionPressure = 150000 [SI::pascal];
        attribute maximumDischargePressure = 9500000 [SI::pascal];
    }

    satisfy PumpingSubsystemRequirement by pumpingSubsystem;
    satisfy ReciprocatingPumpRequirement by pumpingSubsystem.pump;
    satisfy ProtectionRequirement by pumpingSubsystem;
    satisfy ControlRequirement by pumpingSubsystem;
    satisfy LeakContainmentRequirement by pumpingSubsystem;
}