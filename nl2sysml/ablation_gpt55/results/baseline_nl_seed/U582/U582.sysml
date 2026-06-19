package WendelkolbenPumpingSubsystemModel {
    private import ScalarValues::*;

    attribute def Pressure_kPa :> Real;
    attribute def VolumeFlowRate_L_per_min :> Real;
    attribute def RotationalSpeed_rpm :> Real;
    attribute def Temperature_degC :> Real;
    attribute def Power_kW :> Real;
    attribute def Voltage_V :> Real;
    attribute def Current_A :> Real;
    attribute def Frequency_Hz :> Real;
    attribute def Torque_N_m :> Real;
    attribute def Volume_L :> Real;
    attribute def Length_mm :> Real;
    attribute def Density_kg_per_m3 :> Real;
    attribute def DynamicViscosity_mPa_s :> Real;
    attribute def Efficiency_percent :> Real;
    attribute def Time_s :> Real;
    attribute def Mass_kg :> Real;
    attribute def Vibration_mm_per_s :> Real;
    attribute def SoundPressure_dBA :> Real;

    enum def PumpCommandKind {
        enum start;
        enum stop;
        enum reset;
        enum prime;
        enum hold;
        enum emergencyStop;
    }

    enum def PumpOperatingMode {
        enum off;
        enum standby;
        enum priming;
        enum running;
        enum flushing;
        enum faulted;
        enum emergencyShutdown;
    }

    enum def ValvePosition {
        enum closed;
        enum open;
        enum modulating;
        enum relieving;
    }

    item def WorkingFluid {
        attribute density_kg_per_m3 : Density_kg_per_m3 = 998.0;
        attribute dynamicViscosity_mPa_s : DynamicViscosity_mPa_s = 1.0;
        attribute temperature_degC : Temperature_degC = 20.0;
        attribute vaporPressure_kPa : Pressure_kPa = 2.4;
        attribute contaminationClass_ISO4406 : String = "18/16/13";
    }

    item def ElectricalPower {
        attribute lineVoltage_V : Voltage_V;
        attribute current_A : Current_A;
        attribute frequency_Hz : Frequency_Hz;
        attribute realPower_kW : Power_kW;
    }

    item def RotaryMechanicalPower {
        attribute speed_rpm : RotationalSpeed_rpm;
        attribute torque_N_m : Torque_N_m;
        attribute shaftPower_kW : Power_kW;
    }

    item def PumpCommand {
        attribute commandKind : PumpCommandKind;
        attribute commandedSpeed_rpm : RotationalSpeed_rpm;
        attribute commandedFlow_L_per_min : VolumeFlowRate_L_per_min;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute engineeringUnit : String;
        attribute valid : Boolean;
    }

    item def DiagnosticMessage {
        attribute active : Boolean;
        attribute code : String;
        attribute severity : String;
    }

    port def FluidPort {
        inout item fluid : WorkingFluid;
        attribute pressure_kPa : Pressure_kPa;
        attribute flow_L_per_min : VolumeFlowRate_L_per_min;
        attribute temperature_degC : Temperature_degC;
    }

    port def ElectricalPowerInPort {
        in item power : ElectricalPower;
    }

    port def ElectricalPowerOutPort {
        out item power : ElectricalPower;
    }

    port def RotaryPowerInPort {
        in item rotaryPower : RotaryMechanicalPower;
    }

    port def RotaryPowerOutPort {
        out item rotaryPower : RotaryMechanicalPower;
    }

    port def CommandInPort {
        in item command : PumpCommand;
    }

    port def CommandOutPort {
        out item command : PumpCommand;
    }

    port def SensorOutPort {
        out item signal : SensorSignal;
    }

    port def SensorInPort {
        in item signal : SensorSignal;
    }

    port def DiagnosticOutPort {
        out item diagnostic : DiagnosticMessage;
    }

    port def DiagnosticInPort {
        in item diagnostic : DiagnosticMessage;
    }

    connection def FluidConnection {
        end port1 : FluidPort;
        end port2 : FluidPort;
    }

    connection def ElectricalConnection {
        end source : ElectricalPowerOutPort;
        end load : ElectricalPowerInPort;
    }

    connection def RotaryShaftConnection {
        end driver : RotaryPowerOutPort;
        end driven : RotaryPowerInPort;
    }

    connection def CommandConnection {
        end source : CommandOutPort;
        end receiver : CommandInPort;
    }

    connection def SensorConnection {
        end source : SensorOutPort;
        end receiver : SensorInPort;
    }

    constraint def FlowOperatingEnvelope {
        in actualFlow_L_per_min : VolumeFlowRate_L_per_min;
        in minimumFlow_L_per_min : VolumeFlowRate_L_per_min;
        in maximumFlow_L_per_min : VolumeFlowRate_L_per_min;
        actualFlow_L_per_min >= minimumFlow_L_per_min and actualFlow_L_per_min <= maximumFlow_L_per_min
    }

    constraint def PressureProtectionLimit {
        in dischargePressure_kPa : Pressure_kPa;
        in maximumAllowablePressure_kPa : Pressure_kPa;
        dischargePressure_kPa <= maximumAllowablePressure_kPa
    }

    constraint def MinimumNpshMargin {
        in inletAbsolutePressure_kPa : Pressure_kPa;
        in fluidVaporPressure_kPa : Pressure_kPa;
        in requiredMargin_kPa : Pressure_kPa;
        inletAbsolutePressure_kPa - fluidVaporPressure_kPa >= requiredMargin_kPa
    }

    constraint def MotorPowerCapacity {
        in motorRatedPower_kW : Power_kW;
        in requiredShaftPower_kW : Power_kW;
        motorRatedPower_kW >= requiredShaftPower_kW
    }

    action def PrimePump {
        in item inletFluid : WorkingFluid;
        out item primedFluid : WorkingFluid;
        attribute maximumPrimeTime_s : Time_s = 30.0;
        attribute minimumPrimeFlow_L_per_min : VolumeFlowRate_L_per_min = 15.0;

        action openSuctionPath;
        action rotateAtLowSpeed {
            attribute speed_rpm : RotationalSpeed_rpm = 120.0;
        }
        action purgeAirToReservoir;
        action confirmContinuousLiquidColumn;
    }

    action def TransferFluidByWendelkolben {
        in item suctionFluid : WorkingFluid;
        in item shaftInput : RotaryMechanicalPower;
        out item dischargeFluid : WorkingFluid;
        attribute rotorSpeed_rpm : RotationalSpeed_rpm;
        attribute theoreticalDisplacement_ml_per_rev : Real = 185.0;
        attribute volumetricEfficiency_percent : Efficiency_percent = 88.0;
        attribute expectedFlow_L_per_min : VolumeFlowRate_L_per_min;

        action formExpandingSuctionCavity;
        action trapFluidInSealedHelicalPocket;
        action advancePocketAxiallyThroughStator;
        action collapseDischargeCavity;
        action deliverLowPulsationFlow;
    }

    action def ProtectPumpFromOverPressure {
        in item dischargeFluid : WorkingFluid;
        out item bypassFluid : WorkingFluid;
        attribute reliefSetPressure_kPa : Pressure_kPa = 950.0;
        attribute reseatPressure_kPa : Pressure_kPa = 850.0;

        action senseDischargePressure;
        action openReliefValve;
        action routeFluidToReservoir;
        action reseatReliefValve;
    }

    action def FlushAndStop {
        in item residualFluid : WorkingFluid;
        out item returnedFluid : WorkingFluid;
        attribute flushTime_s : Time_s = 20.0;
        attribute stopRampTime_s : Time_s = 5.0;

        action reduceSpeed;
        action circulateToReservoir;
        action deenergizeMotor;
    }

    state def PumpControllerStateMachine {
        in item startCommand : PumpCommand;
        in item stopCommand : PumpCommand;
        in item primeCommand : PumpCommand;
        in item emergencyStopCommand : PumpCommand;
        in item pressureSignal : SensorSignal;
        in item flowSignal : SensorSignal;

        state Off;
        state Standby;
        state Priming;
        state Running;
        state Flushing;
        state Faulted;
        state EmergencyShutdown;

        transition InitialToOff first Off;

        transition OffToStandby
            first Off
            accept startCommand
            then Standby;

        transition StandbyToPriming
            first Standby
            accept primeCommand
            then Priming;

        transition PrimingToRunning
            first Priming
            accept startCommand
            then Running;

        transition RunningToFlushing
            first Running
            accept stopCommand
            then Flushing;

        transition FlushingToOff
            first Flushing
            then Off;

        transition AnyToEmergencyShutdown
            first Running
            accept emergencyStopCommand
            then EmergencyShutdown;

        transition RunningToFaulted
            first Running
            then Faulted;

        transition FaultedToStandby
            first Faulted
            accept startCommand
            then Standby;
    }

    part def Reservoir {
        port supply : FluidPort;
        port return : FluidPort;
        attribute usableVolume_L : Volume_L = 250.0;
        attribute minimumOperatingVolume_L : Volume_L = 80.0;
        attribute maximumFluidTemperature_degC : Temperature_degC = 55.0;
        attribute vented : Boolean = true;
    }

    part def SuctionStrainer {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port differentialPressureSignal : SensorOutPort;
        attribute meshSize_um : Real = 250.0;
        attribute cleanPressureDrop_kPa : Pressure_kPa = 5.0;
        attribute pluggedAlarmPressureDrop_kPa : Pressure_kPa = 35.0;
    }

    part def PipeSegment {
        port endA : FluidPort;
        port endB : FluidPort;
        attribute nominalDiameter_mm : Length_mm;
        attribute length_mm : Length_mm;
        attribute designPressure_kPa : Pressure_kPa;
    }

    part def HydraulicManifold {
        port inlet : FluidPort;
        port processOutlet : FluidPort;
        port reliefOutlet : FluidPort;
        port drain : FluidPort;
        attribute designPressure_kPa : Pressure_kPa = 1200.0;
        attribute internalVolume_L : Volume_L = 3.0;
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure_kPa : Pressure_kPa = 15.0;
        attribute reverseLeakage_L_per_min : VolumeFlowRate_L_per_min = 0.1;
        attribute position : ValvePosition = ValvePosition::closed;
    }

    part def ReliefValve {
        port inlet : FluidPort;
        port bypassOutlet : FluidPort;
        port diagnostic : DiagnosticOutPort;
        attribute setPressure_kPa : Pressure_kPa = 950.0;
        attribute reseatPressure_kPa : Pressure_kPa = 850.0;
        attribute ratedBypassFlow_L_per_min : VolumeFlowRate_L_per_min = 160.0;
        attribute position : ValvePosition = ValvePosition::closed;
    }

    part def FlowSensor {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port signal : SensorOutPort;
        attribute measurementRangeMin_L_per_min : VolumeFlowRate_L_per_min = 0.0;
        attribute measurementRangeMax_L_per_min : VolumeFlowRate_L_per_min = 200.0;
        attribute accuracy_percentOfReading : Efficiency_percent = 1.0;
    }

    part def PressureSensor {
        port processConnection : FluidPort;
        port signal : SensorOutPort;
        attribute rangeMin_kPa : Pressure_kPa = 0.0;
        attribute rangeMax_kPa : Pressure_kPa = 1200.0;
        attribute accuracy_percentFullScale : Efficiency_percent = 0.5;
    }

    part def TemperatureSensor {
        port processConnection : FluidPort;
        port signal : SensorOutPort;
        attribute rangeMin_degC : Temperature_degC = -10.0;
        attribute rangeMax_degC : Temperature_degC = 90.0;
    }

    part def ElectricMotor {
        port electricalInput : ElectricalPowerInPort;
        port shaftOutput : RotaryPowerOutPort;
        port diagnostic : DiagnosticOutPort;
        attribute ratedPower_kW : Power_kW = 11.0;
        attribute ratedSpeed_rpm : RotationalSpeed_rpm = 1750.0;
        attribute ratedTorque_N_m : Torque_N_m = 60.0;
        attribute efficiency_percent : Efficiency_percent = 92.0;
        attribute enclosureRating : String = "IP55";
        attribute insulationClass : String = "F";
    }

    part def VariableFrequencyDrive {
        port acSupply : ElectricalPowerInPort;
        port motorPower : ElectricalPowerOutPort;
        port commandIn : CommandInPort;
        port diagnostic : DiagnosticOutPort;
        attribute inputVoltage_V : Voltage_V = 480.0;
        attribute outputFrequencyMin_Hz : Frequency_Hz = 5.0;
        attribute outputFrequencyMax_Hz : Frequency_Hz = 60.0;
        attribute ratedCurrent_A : Current_A = 24.0;
        attribute speedRampTime_s : Time_s = 5.0;
    }

    part def WendelRotor {
        attribute material : String = "duplex stainless steel";
        attribute lobeCount : Integer = 1;
        attribute helixPitch_mm : Length_mm = 92.0;
        attribute eccentricity_mm : Length_mm = 6.5;
        attribute outsideDiameter_mm : Length_mm = 54.0;
        attribute mass_kg : Mass_kg = 8.5;
    }

    part def ElastomerStator {
        attribute material : String = "NBR elastomer bonded to steel tube";
        attribute cavityCount : Integer = 2;
        attribute statorPitch_mm : Length_mm = 184.0;
        attribute insideDiameter_mm : Length_mm = 56.0;
        attribute maximumTemperature_degC : Temperature_degC = 80.0;
    }

    part def PumpShaftSeal {
        port leakageDrain : FluidPort;
        attribute sealType : String = "single mechanical seal";
        attribute maximumSealPressure_kPa : Pressure_kPa = 1000.0;
        attribute allowableLeakage_L_per_min : VolumeFlowRate_L_per_min = 0.02;
    }

    part def BearingHousing {
        attribute bearingType : String = "angular contact pair";
        attribute lubricant : String = "ISO VG 68 oil";
        attribute maximumVibration_mm_per_s : Vibration_mm_per_s = 4.5;
    }

    part def WendelkolbenPump {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port shaftInput : RotaryPowerInPort;
        port sealDrain : FluidPort;
        port diagnostic : DiagnosticOutPort;

        part rotor : WendelRotor;
        part stator : ElastomerStator;
        part shaftSeal : PumpShaftSeal;
        part bearingHousing : BearingHousing;

        attribute displacement_ml_per_rev : Real = 185.0;
        attribute ratedFlow_L_per_min : VolumeFlowRate_L_per_min = 120.0;
        attribute minimumContinuousFlow_L_per_min : VolumeFlowRate_L_per_min = 20.0;
        attribute maximumContinuousFlow_L_per_min : VolumeFlowRate_L_per_min = 150.0;
        attribute maximumDifferentialPressure_kPa : Pressure_kPa = 900.0;
        attribute maximumSpeed_rpm : RotationalSpeed_rpm = 800.0;
        attribute minimumSpeed_rpm : RotationalSpeed_rpm = 80.0;
        attribute volumetricEfficiency_percent : Efficiency_percent = 88.0;
        attribute soundPressureAtOneMeter_dBA : SoundPressure_dBA = 72.0;

        perform action transfer : TransferFluidByWendelkolben;
    }

    part def PumpController {
        port operatorCommand : CommandInPort;
        port driveCommand : CommandOutPort;
        port inletPressureInput : SensorInPort;
        port dischargePressureInput : SensorInPort;
        port flowInput : SensorInPort;
        port temperatureInput : SensorInPort;
        port strainerDpInput : SensorInPort;
        port driveDiagnosticInput : DiagnosticInPort;
        port reliefDiagnosticInput : DiagnosticInPort;
        port pumpDiagnosticInput : DiagnosticInPort;
        port alarmOutput : DiagnosticOutPort;

        attribute activeMode : PumpOperatingMode = PumpOperatingMode::off;
        attribute commandedSpeed_rpm : RotationalSpeed_rpm = 0.0;
        attribute lowInletPressureTrip_kPa : Pressure_kPa = 35.0;
        attribute highDischargePressureTrip_kPa : Pressure_kPa = 970.0;
        attribute lowFlowAlarm_L_per_min : VolumeFlowRate_L_per_min = 15.0;
        attribute highTemperatureTrip_degC : Temperature_degC = 65.0;

        exhibit state controllerState : PumpControllerStateMachine;
    }

    part def WendelkolbenPumpingSubsystem {
        port utilityPower : ElectricalPowerInPort;
        port suctionServicePort : FluidPort;
        port dischargeServicePort : FluidPort;
        port operatorCommand : CommandInPort;
        port alarmOutput : DiagnosticOutPort;

        part reservoir : Reservoir {
            attribute usableVolume_L = 250.0;
        }

        part suctionPipe : PipeSegment {
            attribute nominalDiameter_mm = 65.0;
            attribute length_mm = 1200.0;
            attribute designPressure_kPa = 400.0;
        }

        part inletStrainer : SuctionStrainer;

        part pump : WendelkolbenPump;

        part motor : ElectricMotor;

        part drive : VariableFrequencyDrive;

        part dischargeManifold : HydraulicManifold;

        part dischargeCheckValve : CheckValve;

        part reliefValve : ReliefValve;

        part bypassPipe : PipeSegment {
            attribute nominalDiameter_mm = 50.0;
            attribute length_mm = 900.0;
            attribute designPressure_kPa = 1200.0;
        }

        part flowMeter : FlowSensor;

        part inletPressureSensor : PressureSensor {
            attribute rangeMax_kPa = 400.0;
        }

        part dischargePressureSensor : PressureSensor {
            attribute rangeMax_kPa = 1200.0;
        }

        part fluidTemperatureSensor : TemperatureSensor;

        part controller : PumpController;

        connection externalSuctionConnection : FluidConnection connect suctionServicePort to reservoir.supply;
        connection reservoirToSuctionPipe : FluidConnection connect reservoir.supply to suctionPipe.endA;
        connection suctionPipeToStrainer : FluidConnection connect suctionPipe.endB to inletStrainer.inlet;
        connection strainerToPump : FluidConnection connect inletStrainer.outlet to pump.inlet;
        connection pumpToDischargeManifold : FluidConnection connect pump.outlet to dischargeManifold.inlet;
        connection manifoldToCheckValve : FluidConnection connect dischargeManifold.processOutlet to dischargeCheckValve.inlet;
        connection checkValveToFlowMeter : FluidConnection connect dischargeCheckValve.outlet to flowMeter.inlet;
        connection flowMeterToDischargeService : FluidConnection connect flowMeter.outlet to dischargeServicePort;
        connection manifoldToReliefValve : FluidConnection connect dischargeManifold.reliefOutlet to reliefValve.inlet;
        connection reliefValveToBypassPipe : FluidConnection connect reliefValve.bypassOutlet to bypassPipe.endA;
        connection bypassPipeToReservoir : FluidConnection connect bypassPipe.endB to reservoir.return;
        connection pumpSealDrainToReservoir : FluidConnection connect pump.sealDrain to reservoir.return;
        connection inletPressureTap : FluidConnection connect inletPressureSensor.processConnection to pump.inlet;
        connection dischargePressureTap : FluidConnection connect dischargePressureSensor.processConnection to dischargeManifold.inlet;
        connection temperatureTap : FluidConnection connect fluidTemperatureSensor.processConnection to reservoir.return;

        connection utilityToDrive : ElectricalConnection connect utilityPower to drive.acSupply;
        connection driveToMotor : ElectricalConnection connect drive.motorPower to motor.electricalInput;
        connection motorToPumpShaft : RotaryShaftConnection connect motor.shaftOutput to pump.shaftInput;

        connection operatorToController : CommandConnection connect operatorCommand to controller.operatorCommand;
        connection controllerToDrive : CommandConnection connect controller.driveCommand to drive.commandIn;

        connection inletPressureFeedback : SensorConnection connect inletPressureSensor.signal to controller.inletPressureInput;
        connection dischargePressureFeedback : SensorConnection connect dischargePressureSensor.signal to controller.dischargePressureInput;
        connection flowFeedback : SensorConnection connect flowMeter.signal to controller.flowInput;
        connection temperatureFeedback : SensorConnection connect fluidTemperatureSensor.signal to controller.temperatureInput;
        connection strainerDpFeedback : SensorConnection connect inletStrainer.differentialPressureSignal to controller.strainerDpInput;

        connection driveDiagnosticFeedback : SensorConnection connect drive.diagnostic to controller.driveDiagnosticInput;
        connection reliefDiagnosticFeedback : SensorConnection connect reliefValve.diagnostic to controller.reliefDiagnosticInput;
        connection pumpDiagnosticFeedback : SensorConnection connect pump.diagnostic to controller.pumpDiagnosticInput;
        connection controllerAlarmToSubsystem : SensorConnection connect controller.alarmOutput to alarmOutput;

        attribute deliveredFlow_L_per_min : VolumeFlowRate_L_per_min = 120.0;
        attribute dischargePressure_kPa : Pressure_kPa = 650.0;
        attribute inletAbsolutePressure_kPa : Pressure_kPa = 100.0;
        attribute requiredNpshMargin_kPa : Pressure_kPa = 25.0;
        attribute requiredShaftPower_kW : Power_kW = 8.2;
        attribute continuousDuty : Boolean = true;

        assert constraint nominalFlowEnvelope : FlowOperatingEnvelope {
            actualFlow_L_per_min = deliveredFlow_L_per_min;
            minimumFlow_L_per_min = pump.minimumContinuousFlow_L_per_min;
            maximumFlow_L_per_min = pump.maximumContinuousFlow_L_per_min;
        }

        assert constraint overPressureProtection : PressureProtectionLimit {
            dischargePressure_kPa = dischargePressure_kPa;
            maximumAllowablePressure_kPa = pump.maximumDifferentialPressure_kPa;
        }

        assert constraint suctionNpshMargin : MinimumNpshMargin {
            inletAbsolutePressure_kPa = inletAbsolutePressure_kPa;
            fluidVaporPressure_kPa = WorkingFluid::vaporPressure_kPa;
            requiredMargin_kPa = requiredNpshMargin_kPa;
        }

        assert constraint motorSizing : MotorPowerCapacity {
            motorRatedPower_kW = motor.ratedPower_kW;
            requiredShaftPower_kW = requiredShaftPower_kW;
        }

        perform action primingAction : PrimePump;
        perform action pumpingAction : TransferFluidByWendelkolben;
        perform action pressureProtectionAction : ProtectPumpFromOverPressure;
        perform action shutdownAction : FlushAndStop;
    }

    requirement def ContinuousFlowRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        attribute minimumRequiredFlow_L_per_min : VolumeFlowRate_L_per_min = 100.0;
        require constraint {
            subsystem.deliveredFlow_L_per_min >= minimumRequiredFlow_L_per_min
        }
    }

    requirement def DischargePressureRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        attribute maximumOperatingPressure_kPa : Pressure_kPa = 900.0;
        require constraint {
            subsystem.dischargePressure_kPa <= maximumOperatingPressure_kPa
        }
    }

    requirement def NpshRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        attribute minimumMargin_kPa : Pressure_kPa = 25.0;
        require constraint {
            subsystem.inletAbsolutePressure_kPa - WorkingFluid::vaporPressure_kPa >= minimumMargin_kPa
        }
    }

    requirement def OverPressureProtectionRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        attribute reliefSetPressure_kPa : Pressure_kPa = 950.0;
        require constraint {
            subsystem.reliefValve.setPressure_kPa <= reliefSetPressure_kPa
        }
    }

    requirement def PrimeAndRunBehaviorRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        attribute maximumPrimeTime_s : Time_s = 30.0;
        require constraint {
            maximumPrimeTime_s <= 30.0
        }
    }

    requirement def ContinuousDutyMotorRequirement {
        subject subsystem : WendelkolbenPumpingSubsystem;
        require constraint {
            subsystem.motor.ratedPower_kW >= subsystem.requiredShaftPower_kW
        }
    }

    part wendelkolbenPumpingSubsystem : WendelkolbenPumpingSubsystem;

    requirement continuousFlow : ContinuousFlowRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
        attribute :>> minimumRequiredFlow_L_per_min = 100.0;
    }

    requirement pressureLimit : DischargePressureRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
        attribute :>> maximumOperatingPressure_kPa = 900.0;
    }

    requirement suctionMargin : NpshRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
        attribute :>> minimumMargin_kPa = 25.0;
    }

    requirement reliefProtection : OverPressureProtectionRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
        attribute :>> reliefSetPressure_kPa = 950.0;
    }

    requirement primingBehavior : PrimeAndRunBehaviorRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
        attribute :>> maximumPrimeTime_s = 30.0;
    }

    requirement motorContinuousDuty : ContinuousDutyMotorRequirement {
        subject subsystem = wendelkolbenPumpingSubsystem;
    }
}
