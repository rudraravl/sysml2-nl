package FollowerPlatePumpingSubsystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import CauseAndEffect::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::litre / SI::minute;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::litre;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Speed :> ISQ::speed {
        unit = SI::millimetre / SI::second;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def ElectricVoltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Duration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Percent :> ScalarValues::Real {
        unit = SI::one;
    }

    item def BulkFluid {
        attribute viscosity : Real;
        attribute density : ISQ::massDensity;
        attribute temperature : Temperature;
        attribute contaminationClass : String;
    }

    item def PressurizedFluid :> BulkFluid {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def ElectricalPower {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute frequency : ISQ::frequency;
    }

    item def PneumaticSupply {
        attribute pressure : Pressure;
        attribute flowCapacity : FlowRate;
    }

    item def ControlSignal {
        attribute commandName : String;
        attribute value : Real;
        attribute timestamp : Duration;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute validity : Boolean;
        attribute timestamp : Duration;
    }

    port def FluidInletPort {
        in item fluidIn : BulkFluid;
    }

    port def FluidOutletPort {
        out item fluidOut : PressurizedFluid;
    }

    port def FluidPassThroughPort {
        in item fluidIn : BulkFluid;
        out item fluidOut : PressurizedFluid;
    }

    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }

    port def PneumaticPowerPort {
        in item air : PneumaticSupply;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def TelemetryOutputPort {
        out item telemetry : SensorSignal;
    }

    port def ReliefReturnPort {
        out item bypassFluid : BulkFluid;
    }

    part def FollowerPlatePumpSubsystem {
        attribute ratedOutletPressure : Pressure = 24000000 [SI::pascal];
        attribute nominalFlowRate : FlowRate = 18 [SI::litre / SI::minute];
        attribute minimumContainerVolume : Volume = 20 [SI::litre];
        attribute maximumContainerVolume : Volume = 200 [SI::litre];
        attribute operatingTemperatureMin : Temperature = 5 [SI::degreeCelsius];
        attribute operatingTemperatureMax : Temperature = 55 [SI::degreeCelsius];
        attribute dryRunTimeout : Duration = 8 [SI::second];

        port electricalInput : ElectricalPowerPort;
        port pneumaticInput : PneumaticPowerPort;
        port controlInput : ControlInputPort;
        port discharge : FluidOutletPort;
        port reliefReturn : ReliefReturnPort;
        port telemetry : TelemetryOutputPort;

        part container : FluidContainer;
        part followerPlate : FollowerPlateAssembly;
        part ram : PneumaticRamAssembly;
        part pump : PositiveDisplacementPump;
        part outletManifold : OutletManifold;
        part reliefValve : PressureReliefValve;
        part controller : PumpController;
        part sensors : InstrumentationSet;
        part sealPurge : SealPurgeSystem;
        part frame : SupportFrame;

        connect electricalInput to controller.electricalSupply;
        connect pneumaticInput to ram.airSupply;
        connect controlInput to controller.commandInput;

        connect container.openTop to followerPlate.upperFluidInterface;
        connect followerPlate.lowerFluidInterface to pump.suction;
        connect pump.discharge to outletManifold.inlet;
        connect outletManifold.outlet to discharge;
        connect outletManifold.reliefTap to reliefValve.inlet;
        connect reliefValve.returnOutlet to reliefReturn;

        connect controller.ramCommand to ram.command;
        connect controller.pumpCommand to pump.driveCommand;
        connect controller.purgeCommand to sealPurge.command;

        connect sensors.pressureSignal to controller.pressureFeedback;
        connect sensors.levelSignal to controller.levelFeedback;
        connect sensors.positionSignal to controller.platePositionFeedback;
        connect sensors.flowSignal to controller.flowFeedback;
        connect controller.telemetryOutput to telemetry;

        bind sensors.pressureProbe.sensedPressure = outletManifold.manifoldPressure;
        bind sensors.positionProbe.sensedPosition = ram.platePosition;
        bind sensors.levelProbe.sensedLevel = container.remainingVolume;
        bind sensors.flowMeter.sensedFlow = outletManifold.deliveredFlow;

        action def PrimePump {
            in part subsystem : FollowerPlatePumpSubsystem;
            first startRam;
            then lowerPlate;
            then ventAir;
            then jogPump;
            then confirmPrime;
        }

        action def DispenseFluid {
            in part subsystem : FollowerPlatePumpSubsystem;
            in attribute requestedFlow : FlowRate;
            in attribute requestedVolume : Volume;
            out attribute deliveredVolume : Volume;

            first enablePurge;
            then regulateRamForce;
            then runPump;
            then monitorPressure;
            then stopAtVolume;
            then holdPlatePosition;
        }

        action def EmergencyShutdown {
            in part subsystem : FollowerPlatePumpSubsystem;
            first stopPump;
            then closeOutlet;
            then ventRamPressure;
            then openRelief;
            then reportFault;
        }

        state def PumpingSubsystemStates {
            entry action initializeDiagnostics;

            state Off;
            state Standby;
            state LoadingContainer;
            state Priming;
            state Ready;
            state Pumping;
            state HoldPressure;
            state Depressurizing;
            state Faulted;

            transition first Off;
            transition Off_to_Standby
                first Off
                then Standby
                accept ControlSignal
                if command.commandName == "PowerOn";

            transition Standby_to_Loading
                first Standby
                then LoadingContainer
                accept ControlSignal
                if command.commandName == "LoadContainer";

            transition Loading_to_Priming
                first LoadingContainer
                then Priming
                accept ControlSignal
                if command.commandName == "ClampAndPrime";

            transition Priming_to_Ready
                first Priming
                then Ready
                if sensors.pressureProbe.sensedPressure > 500000 [SI::pascal];

            transition Ready_to_Pumping
                first Ready
                then Pumping
                accept ControlSignal
                if command.commandName == "StartDispense";

            transition Pumping_to_HoldPressure
                first Pumping
                then HoldPressure
                if outletManifold.deliveredVolume >= controller.targetVolume;

            transition HoldPressure_to_Ready
                first HoldPressure
                then Ready
                accept ControlSignal
                if command.commandName == "ResetCycle";

            transition Pumping_to_Depressurizing
                first Pumping
                then Depressurizing
                accept ControlSignal
                if command.commandName == "Stop";

            transition Depressurizing_to_Standby
                first Depressurizing
                then Standby
                if outletManifold.manifoldPressure < 200000 [SI::pascal];

            transition any_to_Faulted
                first Off
                then Faulted
                if sensors.pressureProbe.sensedPressure > 26000000 [SI::pascal];

            transition Faulted_to_Standby
                first Faulted
                then Standby
                accept ControlSignal
                if command.commandName == "FaultReset";
        }
    }

    part def FluidContainer {
        attribute totalVolume : Volume = 200 [SI::litre];
        attribute remainingVolume : Volume;
        attribute innerDiameter : ISQ::length = 571 [SI::millimetre];
        attribute usableHeight : ISQ::length = 880 [SI::millimetre];
        attribute fluidTemperature : Temperature;

        port openTop : FluidInletPort;
    }

    part def FollowerPlateAssembly {
        attribute plateDiameter : ISQ::length = 565 [SI::millimetre];
        attribute plateMass : ISQ::mass = 38 [SI::kilogram];
        attribute sealCompressionForce : Force = 1800 [SI::newton];
        attribute residualFluidVolume : Volume = 1.2 [SI::litre];

        port upperFluidInterface : FluidInletPort;
        port lowerFluidInterface : FluidOutletPort;

        part wiperSeal : ElastomerWiperSeal;
        part ventValve : ManualVentValve;
        part checkValve : SuctionCheckValve;

        requirement sealCompatibility {
            subject followerPlate : FollowerPlateAssembly;
            require constraint {
                followerPlate.wiperSeal.material == "FKM" or
                followerPlate.wiperSeal.material == "EPDM";
            }
        }
    }

    part def ElastomerWiperSeal {
        attribute material : String = "FKM";
        attribute hardness : Real = 75;
        attribute maxCompressionSet : Percent = 0.25;
    }

    part def ManualVentValve {
        attribute ventOrificeDiameter : ISQ::length = 3 [SI::millimetre];
        attribute normallyClosed : Boolean = true;
    }

    part def SuctionCheckValve {
        attribute crackingPressure : Pressure = 15000 [SI::pascal];
        attribute reverseLeakageRate : FlowRate = 0.02 [SI::litre / SI::minute];
    }

    part def PneumaticRamAssembly {
        attribute boreDiameter : ISQ::length = 100 [SI::millimetre];
        attribute strokeLength : ISQ::length = 950 [SI::millimetre];
        attribute maximumDownForce : Force = 9200 [SI::newton];
        attribute descentSpeed : Speed = 12 [SI::millimetre / SI::second];
        attribute platePosition : ISQ::length;
        attribute commandedForce : Force;

        port airSupply : PneumaticPowerPort;
        port command : ControlInputPort;

        part leftCylinder : PneumaticCylinder;
        part rightCylinder : PneumaticCylinder;
        part proportionalRegulator : AirPressureRegulator;
        part exhaustValve : SafetyDumpValve;

        connect airSupply to proportionalRegulator.supply;
        connect proportionalRegulator.output to leftCylinder.airPort;
        connect proportionalRegulator.output to rightCylinder.airPort;
    }

    part def PneumaticCylinder {
        attribute bore : ISQ::length = 100 [SI::millimetre];
        attribute rodDiameter : ISQ::length = 25 [SI::millimetre];
        attribute stroke : ISQ::length = 950 [SI::millimetre];

        port airPort : PneumaticPowerPort;
    }

    part def AirPressureRegulator {
        attribute setPressure : Pressure;
        attribute maximumOutletPressure : Pressure = 700000 [SI::pascal];

        port supply : PneumaticPowerPort;
        port output : PneumaticPowerPort;
    }

    part def SafetyDumpValve {
        attribute ventTime : Duration = 2.5 [SI::second];
        attribute normallyOpenOnPowerLoss : Boolean = true;

        port inlet : PneumaticPowerPort;
    }

    part def PositiveDisplacementPump {
        attribute displacementPerCycle : Volume = 0.18 [SI::litre];
        attribute maximumCycleRate : ISQ::frequency = 2.2 [SI::hertz];
        attribute maximumOutletPressure : Pressure = 24000000 [SI::pascal];
        attribute volumetricEfficiency : Percent = 0.91;
        attribute dryRunDetected : Boolean;

        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port driveCommand : ControlInputPort;

        part inletValve : PumpCheckValve;
        part outletValve : PumpCheckValve;
        part driveMotor : ElectricServoMotor;
        part pumpChamber : PumpChamber;
    }

    part def PumpCheckValve {
        attribute crackingPressure : Pressure = 35000 [SI::pascal];
        attribute seatMaterial : String = "Tungsten carbide";
        attribute maxBackPressure : Pressure = 26000000 [SI::pascal];
    }

    part def PumpChamber {
        attribute sweptVolume : Volume = 0.18 [SI::litre];
        attribute wettedMaterial : String = "316 stainless steel";
        attribute surfaceFinishRa : ISQ::length = 0.8 [SI::micrometre];
    }

    part def ElectricServoMotor {
        attribute ratedVoltage : ElectricVoltage = 480 [SI::volt];
        attribute ratedCurrent : ElectricCurrent = 8 [SI::ampere];
        attribute ratedPower : ISQ::power = 2200 [SI::watt];
        attribute maximumSpeed : ISQ::angularVelocity = 1800 [SI::revolution / SI::minute];
    }

    part def OutletManifold {
        attribute manifoldPressure : Pressure;
        attribute deliveredFlow : FlowRate;
        attribute deliveredVolume : Volume;
        attribute outletConnectionSize : String = "3/4 NPT";
        attribute wettedMaterial : String = "316 stainless steel";

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port reliefTap : FluidOutletPort;

        part isolationValve : OutletIsolationValve;
        part filter : InlineFilter;
    }

    part def OutletIsolationValve {
        attribute normallyClosed : Boolean = true;
        attribute pressureRating : Pressure = 28000000 [SI::pascal];
        attribute actuationTime : Duration = 0.4 [SI::second];
    }

    part def InlineFilter {
        attribute absoluteRating : ISQ::length = 250 [SI::micrometre];
        attribute differentialPressureLimit : Pressure = 350000 [SI::pascal];
    }

    part def PressureReliefValve {
        attribute crackingPressure : Pressure = 25000000 [SI::pascal];
        attribute reseatPressure : Pressure = 22000000 [SI::pascal];
        attribute ratedBypassFlow : FlowRate = 25 [SI::litre / SI::minute];

        port inlet : FluidInletPort;
        port returnOutlet : ReliefReturnPort;
    }

    part def SealPurgeSystem {
        attribute purgeInterval : Duration = 600 [SI::second];
        attribute purgeVolume : Volume = 0.05 [SI::litre];

        port command : ControlInputPort;
    }

    part def InstrumentationSet {
        port pressureSignal : TelemetryOutputPort;
        port levelSignal : TelemetryOutputPort;
        port positionSignal : TelemetryOutputPort;
        port flowSignal : TelemetryOutputPort;

        part pressureProbe : PressureTransducer;
        part levelProbe : ContainerLevelSensor;
        part positionProbe : PlatePositionSensor;
        part flowMeter : CoriolisFlowMeter;
        part temperatureProbe : FluidTemperatureSensor;
    }

    part def PressureTransducer {
        attribute sensedPressure : Pressure;
        attribute rangeMax : Pressure = 30000000 [SI::pascal];
        attribute accuracy : Percent = 0.005;
    }

    part def ContainerLevelSensor {
        attribute sensedLevel : Volume;
        attribute lowLevelThreshold : Volume = 3 [SI::litre];
        attribute accuracy : Volume = 0.5 [SI::litre];
    }

    part def PlatePositionSensor {
        attribute sensedPosition : ISQ::length;
        attribute range : ISQ::length = 1000 [SI::millimetre];
        attribute accuracy : ISQ::length = 1 [SI::millimetre];
    }

    part def CoriolisFlowMeter {
        attribute sensedFlow : FlowRate;
        attribute maximumFlow : FlowRate = 30 [SI::litre / SI::minute];
        attribute accuracy : Percent = 0.003;
    }

    part def FluidTemperatureSensor {
        attribute sensedTemperature : Temperature;
        attribute rangeLow : Temperature = -10 [SI::degreeCelsius];
        attribute rangeHigh : Temperature = 90 [SI::degreeCelsius];
    }

    part def PumpController {
        attribute targetFlow : FlowRate;
        attribute targetVolume : Volume;
        attribute pressureLimit : Pressure = 24000000 [SI::pascal];
        attribute ramForceSetpoint : Force;
        attribute cycleCount : Integer;
        attribute faultCode : String;

        port electricalSupply : ElectricalPowerPort;
        port commandInput : ControlInputPort;
        port pressureFeedback : TelemetryOutputPort;
        port levelFeedback : TelemetryOutputPort;
        port platePositionFeedback : TelemetryOutputPort;
        port flowFeedback : TelemetryOutputPort;
        port ramCommand : ControlInputPort;
        port pumpCommand : ControlInputPort;
        port purgeCommand : ControlInputPort;
        port telemetryOutput : TelemetryOutputPort;

        action def CalculateRamForce {
            in attribute fluidViscosity : Real;
            in attribute containerDiameter : ISQ::length;
            out attribute forceSetpoint : Force;
        }

        action def RegulatePumpSpeed {
            in attribute requestedFlow : FlowRate;
            in attribute actualFlow : FlowRate;
            out attribute motorSpeedCommand : Real;
        }

        action def DetectDryRun {
            in attribute pressure : Pressure;
            in attribute flow : FlowRate;
            in attribute plateVelocity : Speed;
            out attribute dryRun : Boolean;
        }
    }

    part def SupportFrame {
        attribute material : String = "powder coated carbon steel";
        attribute staticLoadRating : Force = 18000 [SI::newton];
        attribute footprintWidth : ISQ::length = 950 [SI::millimetre];
        attribute footprintDepth : ISQ::length = 820 [SI::millimetre];

        part dripTray : DripContainmentTray;
        part guardDoor : InterlockedGuardDoor;
    }

    part def DripContainmentTray {
        attribute containmentVolume : Volume = 8 [SI::litre];
        attribute drainConnection : String = "1/2 NPT";
    }

    part def InterlockedGuardDoor {
        attribute closed : Boolean;
        attribute lockable : Boolean = true;
        attribute safetyCategory : String = "ISO 13849-1 Category 3 PL d";
    }

    requirement def PumpingRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.nominalFlowRate >= 15 [SI::litre / SI::minute] and
            subsystem.ratedOutletPressure >= 22000000 [SI::pascal];
        }
    }

    requirement def FollowerPlateResidueRequirement {
        subject plate : FollowerPlateAssembly;
        require constraint {
            plate.residualFluidVolume <= 1.5 [SI::litre];
        }
    }

    requirement def OverpressureProtectionRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.reliefValve.crackingPressure <=
            subsystem.pump.maximumOutletPressure + 1000000 [SI::pascal];
        }
    }

    requirement def DryRunProtectionRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.dryRunTimeout <= 10 [SI::second];
        }
    }

    requirement def MaterialCompatibilityRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.pump.pumpChamber.wettedMaterial == "316 stainless steel" and
            subsystem.outletManifold.wettedMaterial == "316 stainless steel";
        }
    }

    requirement def TemperatureOperatingRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.operatingTemperatureMin <= 5 [SI::degreeCelsius] and
            subsystem.operatingTemperatureMax >= 50 [SI::degreeCelsius];
        }
    }

    requirement def GuardingRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.frame.guardDoor.lockable == true;
        }
    }

    requirement def ContainerCompatibilityRequirement {
        subject subsystem : FollowerPlatePumpSubsystem;
        require constraint {
            subsystem.container.totalVolume >= subsystem.minimumContainerVolume and
            subsystem.container.totalVolume <= subsystem.maximumContainerVolume;
        }
    }

    satisfy PumpingRequirement by FollowerPlatePumpSubsystem::pump;
    satisfy FollowerPlateResidueRequirement by FollowerPlatePumpSubsystem::followerPlate;
    satisfy OverpressureProtectionRequirement by FollowerPlatePumpSubsystem::reliefValve;
    satisfy DryRunProtectionRequirement by FollowerPlatePumpSubsystem::controller;
    satisfy MaterialCompatibilityRequirement by FollowerPlatePumpSubsystem::pump;
    satisfy TemperatureOperatingRequirement by FollowerPlatePumpSubsystem::sensors::temperatureProbe;
    satisfy GuardingRequirement by FollowerPlatePumpSubsystem::frame::guardDoor;
    satisfy ContainerCompatibilityRequirement by FollowerPlatePumpSubsystem::container;

    part followerPlatePumpSystem : FollowerPlatePumpSubsystem {
        attribute ratedOutletPressure = 24000000 [SI::pascal];
        attribute nominalFlowRate = 18 [SI::litre / SI::minute];

        redefines container {
            attribute totalVolume = 200 [SI::litre];
            attribute remainingVolume = 200 [SI::litre];
            attribute fluidTemperature = 23 [SI::degreeCelsius];
        }

        redefines controller {
            attribute targetFlow = 16 [SI::litre / SI::minute];
            attribute targetVolume = 25 [SI::litre];
            attribute pressureLimit = 23000000 [SI::pascal];
        }

        redefines reliefValve {
            attribute crackingPressure = 25000000 [SI::pascal];
            attribute reseatPressure = 22000000 [SI::pascal];
        }
    }
}