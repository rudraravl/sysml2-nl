package StirrupPumpSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def VolumeFlowRate {
        :>> scalarValues::Real;
        unit : Unit = SI::cubicMetre / SI::second;
    }

    attribute def StrokeRate {
        :>> scalarValues::Real;
        unit : Unit = SI::hertz;
    }

    attribute def StrokeLength :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Efficiency {
        :>> scalarValues::Real;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def ContaminationLevel {
        :>> scalarValues::Real;
    }

    attribute def FluidVolume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def TimeDuration :> ISQ::duration {
        unit = SI::second;
    }

    item def WorkingFluid {
        attribute density : Real = 998.0;
        attribute dynamicViscosity : Real = 0.001;
        attribute temperature : Temperature = 293.15 [SI::kelvin];
        attribute contamination : ContaminationLevel = 0.0;
    }

    item def MechanicalWork {
        attribute inputForce : Force;
        attribute displacement : StrokeLength;
        attribute cycleEnergy : Real;
    }

    item def StatusSignal {
        attribute healthy : Boolean;
        attribute messageCode : Integer;
        attribute measuredOutletPressure : Pressure;
        attribute measuredFlowRate : VolumeFlowRate;
    }

    item def CommandSignal {
        attribute enablePump : Boolean;
        attribute requestedFlowRate : VolumeFlowRate;
        attribute maxAllowedPressure : Pressure;
    }

    port def FluidPort {
        inout item fluid : WorkingFluid;
        attribute staticPressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def MechanicalDrivePort {
        in item work : MechanicalWork;
        attribute handleForce : Force;
        attribute strokeRate : StrokeRate;
        attribute strokeLength : StrokeLength;
    }

    port def ControlInputPort {
        in item command : CommandSignal;
    }

    port def StatusOutputPort {
        out item status : StatusSignal;
    }

    part def InletFilter {
        port rawInlet : FluidPort;
        port filteredOutlet : FluidPort;

        attribute meshRatingMicron : Real = 100.0;
        attribute pressureDropAtNominalFlow : Pressure = 3500.0 [SI::pascal];
        attribute retainedContaminationFraction : Real = 0.85;

        perform action filterFluid {
            in item incoming : WorkingFluid;
            out item outgoing : WorkingFluid;

            first start;
            then reduceContamination;
            then deliverFilteredFluid;
            then done;

            action reduceContamination;
            action deliverFilteredFluid;
        }
    }

    part def InletCheckValve {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute crackingPressure : Pressure = 1500.0 [SI::pascal];
        attribute reverseLeakageRate : VolumeFlowRate = 0.0000002 [SI::cubicMetre / SI::second];
        attribute open : Boolean = false;

        state valveState {
            state Closed;
            state Open;

            initial then Closed;

            transition Closed_to_Open
                first Closed
                accept when upstream.staticPressure > downstream.staticPressure + crackingPressure
                then Open;

            transition Open_to_Closed
                first Open
                accept when upstream.staticPressure <= downstream.staticPressure
                then Closed;
        }
    }

    part def OutletCheckValve {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute crackingPressure : Pressure = 2500.0 [SI::pascal];
        attribute reverseLeakageRate : VolumeFlowRate = 0.0000001 [SI::cubicMetre / SI::second];
        attribute open : Boolean = false;

        state valveState {
            state Closed;
            state Open;

            initial then Closed;

            transition Closed_to_Open
                first Closed
                accept when upstream.staticPressure > downstream.staticPressure + crackingPressure
                then Open;

            transition Open_to_Closed
                first Open
                accept when upstream.staticPressure <= downstream.staticPressure
                then Closed;
        }
    }

    part def StirrupHandle {
        port driveOutput : MechanicalDrivePort;

        attribute operatorForce : Force = 180.0 [SI::newton];
        attribute maxOperatorForce : Force = 350.0 [SI::newton];
        attribute nominalStrokeRate : StrokeRate = 1.2 [SI::hertz];
        attribute commandedStrokeLength : StrokeLength = 0.28 [SI::metre];

        perform action applyReciprocatingMotion {
            in attribute forceInput : Force;
            out item mechanicalWork : MechanicalWork;

            first gripHandle;
            then pullUpstroke;
            then pushDownstroke;
            then transmitWork;
            then done;

            action gripHandle;
            action pullUpstroke;
            action pushDownstroke;
            action transmitWork;
        }
    }

    part def PistonAndRodAssembly {
        port mechanicalInput : MechanicalDrivePort;
        port chamberInterface : FluidPort;

        attribute pistonDiameter : Length = 0.038 [SI::metre];
        attribute pistonArea : Area = 0.001134 [SI::squareMetre];
        attribute strokeLength : StrokeLength = 0.28 [SI::metre];
        attribute sealFrictionForce : Force = 22.0 [SI::newton];
        attribute volumetricDisplacementPerStroke : FluidVolume = 0.0003175 [SI::cubicMetre];

        perform action convertMotionToPressure {
            in item work : MechanicalWork;
            out attribute chamberPressure : Pressure;

            first receiveStroke;
            then compressChamberFluid;
            then overcomeValveCrackingPressure;
            then expelDisplacedVolume;
            then done;

            action receiveStroke;
            action compressChamberFluid;
            action overcomeValveCrackingPressure;
            action expelDisplacedVolume;
        }
    }

    part def PumpCylinder {
        port inletSide : FluidPort;
        port outletSide : FluidPort;
        port pistonSide : FluidPort;

        attribute boreDiameter : Length = 0.040 [SI::metre];
        attribute chamberVolumeAtTopDeadCenter : FluidVolume = 0.000040 [SI::cubicMetre];
        attribute chamberVolumeAtBottomDeadCenter : FluidVolume = 0.000358 [SI::cubicMetre];
        attribute maximumWorkingPressure : Pressure = 650000.0 [SI::pascal];
        attribute internalSurfaceRoughness : Length = 0.0000016 [SI::metre];

        state chamberCycle {
            state Primed;
            state SuctionStroke;
            state CompressionStroke;
            state DischargeStroke;
            state PressureRelief;
            state Faulted;

            initial then Primed;

            transition beginSuction
                first Primed
                accept when pistonSide.flowRate < 0.0 [SI::cubicMetre / SI::second]
                then SuctionStroke;

            transition fillComplete
                first SuctionStroke
                accept after 0.42 [SI::second]
                then CompressionStroke;

            transition dischargeBegins
                first CompressionStroke
                accept when pistonSide.staticPressure > outletSide.staticPressure
                then DischargeStroke;

            transition dischargeComplete
                first DischargeStroke
                accept after 0.42 [SI::second]
                then Primed;

            transition overPressure
                first Primed
                accept when outletSide.staticPressure > maximumWorkingPressure
                then PressureRelief;

            transition reliefFailed
                first PressureRelief
                accept after 2.0 [SI::second]
                then Faulted;
        }
    }

    part def ReliefValve {
        port protectedSide : FluidPort;
        port returnSide : FluidPort;

        attribute setPressure : Pressure = 600000.0 [SI::pascal];
        attribute reseatPressure : Pressure = 520000.0 [SI::pascal];
        attribute reliefCapacity : VolumeFlowRate = 0.00055 [SI::cubicMetre / SI::second];

        state reliefState {
            state Seated;
            state Relieving;

            initial then Seated;

            transition openRelief
                first Seated
                accept when protectedSide.staticPressure >= setPressure
                then Relieving;

            transition reseatRelief
                first Relieving
                accept when protectedSide.staticPressure <= reseatPressure
                then Seated;
        }
    }

    part def OutletAccumulator {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute gasPrechargePressure : Pressure = 180000.0 [SI::pascal];
        attribute nominalFluidCapacity : FluidVolume = 0.0015 [SI::cubicMetre];
        attribute dampingRatio : Real = 0.55;

        perform action dampPressureRipple {
            in attribute pulsatingFlow : VolumeFlowRate;
            out attribute smoothedFlow : VolumeFlowRate;

            first receivePulse;
            then storeFluidDuringPeak;
            then releaseFluidDuringTrough;
            then provideSmoothedFlow;
            then done;

            action receivePulse;
            action storeFluidDuringPeak;
            action releaseFluidDuringTrough;
            action provideSmoothedFlow;
        }
    }

    part def PressureSensor {
        port sensedLine : FluidPort;
        port statusOut : StatusOutputPort;

        attribute rangeMinimum : Pressure = 0.0 [SI::pascal];
        attribute rangeMaximum : Pressure = 700000.0 [SI::pascal];
        attribute accuracyPercentFullScale : Real = 1.0;
        attribute measuredPressure : Pressure;

        perform action measurePressure {
            in attribute actualPressure : Pressure;
            out attribute reportedPressure : Pressure;

            first sampleLine;
            then applyCalibration;
            then publishMeasurement;
            then done;

            action sampleLine;
            action applyCalibration;
            action publishMeasurement;
        }
    }

    part def FlowSensor {
        port sensedLine : FluidPort;
        port statusOut : StatusOutputPort;

        attribute minimumReadableFlow : VolumeFlowRate = 0.000001 [SI::cubicMetre / SI::second];
        attribute maximumReadableFlow : VolumeFlowRate = 0.0010 [SI::cubicMetre / SI::second];
        attribute measuredFlowRate : VolumeFlowRate;

        perform action measureFlow {
            in attribute actualFlow : VolumeFlowRate;
            out attribute reportedFlow : VolumeFlowRate;

            first sampleFlow;
            then rejectPulsationNoise;
            then publishFlow;
            then done;

            action sampleFlow;
            action rejectPulsationNoise;
            action publishFlow;
        }
    }

    part def PumpController {
        port commandIn : ControlInputPort;
        port statusOut : StatusOutputPort;
        port pressureStatusIn : StatusOutputPort;
        port flowStatusIn : StatusOutputPort;

        attribute enabled : Boolean = false;
        attribute targetFlowRate : VolumeFlowRate = 0.00030 [SI::cubicMetre / SI::second];
        attribute pressureLimit : Pressure = 600000.0 [SI::pascal];
        attribute faultLatched : Boolean = false;

        state controllerState {
            state Disabled;
            state Ready;
            state Pumping;
            state OverPressureShutdown;
            state LowFlowFault;

            initial then Disabled;

            transition enable
                first Disabled
                accept when commandIn.command.enablePump == true
                then Ready;

            transition startPumping
                first Ready
                accept when commandIn.command.requestedFlowRate > 0.0 [SI::cubicMetre / SI::second]
                then Pumping;

            transition stopPumping
                first Pumping
                accept when commandIn.command.enablePump == false
                then Disabled;

            transition pressureTrip
                first Pumping
                accept when pressureStatusIn.status.measuredOutletPressure >= pressureLimit
                then OverPressureShutdown;

            transition insufficientFlow
                first Pumping
                accept after 5.0 [SI::second]
                if flowStatusIn.status.measuredFlowRate < 0.60 * targetFlowRate
                then LowFlowFault;
        }
    }

    part def StirrupPumpSubsystem {
        port suctionInlet : FluidPort;
        port pressurizedOutlet : FluidPort;
        port operatorDrive : MechanicalDrivePort;
        port controlInput : ControlInputPort;
        port healthStatus : StatusOutputPort;

        attribute nominalOutletPressure : Pressure = 350000.0 [SI::pascal];
        attribute maximumOutletPressure : Pressure = 600000.0 [SI::pascal];
        attribute nominalFlowRate : VolumeFlowRate = 0.00030 [SI::cubicMetre / SI::second];
        attribute minimumPrimingVolume : FluidVolume = 0.00020 [SI::cubicMetre];
        attribute dryMass : Mass = 4.8 [SI::kilogram];
        attribute overallEfficiency : Efficiency = 0.72;
        attribute allowableFluidTemperatureMin : Temperature = 278.15 [SI::kelvin];
        attribute allowableFluidTemperatureMax : Temperature = 323.15 [SI::kelvin];

        part inletFilter : InletFilter;
        part inletValve : InletCheckValve;
        part outletValve : OutletCheckValve;
        part cylinder : PumpCylinder;
        part pistonAssembly : PistonAndRodAssembly;
        part handle : StirrupHandle;
        part reliefValve : ReliefValve;
        part accumulator : OutletAccumulator;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : PumpController;

        connect suctionInlet to inletFilter.rawInlet;
        connect inletFilter.filteredOutlet to inletValve.upstream;
        connect inletValve.downstream to cylinder.inletSide;
        connect cylinder.outletSide to outletValve.upstream;
        connect outletValve.downstream to accumulator.inlet;
        connect accumulator.outlet to pressurizedOutlet;
        connect cylinder.pistonSide to pistonAssembly.chamberInterface;
        connect operatorDrive to handle.driveOutput;
        connect handle.driveOutput to pistonAssembly.mechanicalInput;
        connect accumulator.outlet to pressureSensor.sensedLine;
        connect accumulator.outlet to flowSensor.sensedLine;
        connect accumulator.inlet to reliefValve.protectedSide;
        connect reliefValve.returnSide to cylinder.inletSide;
        connect controlInput to controller.commandIn;
        connect pressureSensor.statusOut to controller.pressureStatusIn;
        connect flowSensor.statusOut to controller.flowStatusIn;
        connect controller.statusOut to healthStatus;

        perform action pumpFluid {
            in item sourceFluid : WorkingFluid;
            in item command : CommandSignal;
            in item operatorWork : MechanicalWork;
            out item deliveredFluid : WorkingFluid;
            out item status : StatusSignal;

            first acceptCommand;
            then verifyFluidTemperature;
            then primeCylinder;
            then receiveOperatorStroke;
            then drawFluidThroughFilter;
            then closeOutletDuringSuction;
            then compressFluid;
            then openOutletCheckValve;
            then dischargeFluidToAccumulator;
            then dampOutletPulsation;
            then monitorPressureAndFlow;
            then reportHealth;
            then done;

            action acceptCommand;
            action verifyFluidTemperature;
            action primeCylinder;
            action receiveOperatorStroke;
            action drawFluidThroughFilter;
            action closeOutletDuringSuction;
            action compressFluid;
            action openOutletCheckValve;
            action dischargeFluidToAccumulator;
            action dampOutletPulsation;
            action monitorPressureAndFlow;
            action reportHealth;
        }

        state subsystemState {
            state Off;
            state Priming;
            state Ready;
            state Pumping;
            state RelievingPressure;
            state Fault;

            initial then Off;

            transition powerEnable
                first Off
                accept when controlInput.command.enablePump == true
                then Priming;

            transition primed
                first Priming
                accept after 3.0 [SI::second]
                then Ready;

            transition commandedPump
                first Ready
                accept when controlInput.command.requestedFlowRate > 0.0 [SI::cubicMetre / SI::second]
                then Pumping;

            transition commandedStop
                first Pumping
                accept when controlInput.command.enablePump == false
                then Off;

            transition outletOverPressure
                first Pumping
                accept when pressurizedOutlet.staticPressure >= maximumOutletPressure
                then RelievingPressure;

            transition pressureRecovered
                first RelievingPressure
                accept when pressurizedOutlet.staticPressure < 0.87 * maximumOutletPressure
                then Ready;

            transition cannotMaintainFlow
                first Pumping
                accept after 10.0 [SI::second]
                if flowSensor.measuredFlowRate < 0.50 * nominalFlowRate
                then Fault;
        }
    }

    requirement def Req_NominalFlow {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.pressurizedOutlet.flowRate >= pump.nominalFlowRate
        }
    }

    requirement def Req_MaximumPressureProtection {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.pressurizedOutlet.staticPressure <= pump.maximumOutletPressure
        }
    }

    requirement def Req_CheckValveBackflow {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.inletValve.reverseLeakageRate <= 0.0000002 [SI::cubicMetre / SI::second] and
            pump.outletValve.reverseLeakageRate <= 0.0000001 [SI::cubicMetre / SI::second]
        }
    }

    requirement def Req_Priming {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.minimumPrimingVolume <= pump.cylinder.chamberVolumeAtBottomDeadCenter
        }
    }

    requirement def Req_OperatorForceLimit {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.handle.operatorForce <= pump.handle.maxOperatorForce
        }
    }

    requirement def Req_TemperatureCompatibility {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.suctionInlet.fluid.temperature >= pump.allowableFluidTemperatureMin and
            pump.suctionInlet.fluid.temperature <= pump.allowableFluidTemperatureMax
        }
    }

    requirement def Req_PressureSensorRange {
        subject pump : StirrupPumpSubsystem;
        require constraint {
            pump.pressureSensor.rangeMaximum >= pump.maximumOutletPressure
        }
    }

    part exampleInstallation {
        part pump : StirrupPumpSubsystem;

        item potableWater : WorkingFluid {
            attribute density = 998.0;
            attribute dynamicViscosity = 0.001;
            attribute temperature = 293.15 [SI::kelvin];
            attribute contamination = 0.20;
        }

        item nominalCommand : CommandSignal {
            attribute enablePump = true;
            attribute requestedFlowRate = 0.00030 [SI::cubicMetre / SI::second];
            attribute maxAllowedPressure = 600000.0 [SI::pascal];
        }

        item manualStroke : MechanicalWork {
            attribute inputForce = 180.0 [SI::newton];
            attribute displacement = 0.28 [SI::metre];
            attribute cycleEnergy = 50.4;
        }

        assert requirement Req_NominalFlow {
            subject pump = pump;
        }

        assert requirement Req_MaximumPressureProtection {
            subject pump = pump;
        }

        assert requirement Req_CheckValveBackflow {
            subject pump = pump;
        }

        assert requirement Req_Priming {
            subject pump = pump;
        }

        assert requirement Req_OperatorForceLimit {
            subject pump = pump;
        }

        assert requirement Req_TemperatureCompatibility {
            subject pump = pump;
        }

        assert requirement Req_PressureSensorRange {
            subject pump = pump;
        }
    }
}