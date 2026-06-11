package PumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRateValue {
        :>> quantityKind = ISQ::volumeFlowRate;
        unit = SI::litre / SI::minute;
    }

    attribute def VolumeValue :> ISQ::volume {
        unit = SI::litre;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def PowerValue :> ISQ::power {
        unit = SI::watt;
    }

    attribute def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def CurrentValue :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def LengthValue :> ISQ::length {
        unit = SI::metre;
    }

    attribute def EfficiencyValue :> ISQ::dimensionless {
        unit = SI::one;
    }

    item def Fluid {
        attribute density : Real;
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
    }

    item def Water :> Fluid {
        :>> density = 998.0;
        :>> viscosity = 0.001;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : Real;
    }

    item def ControlSignal {
        attribute command : PumpCommandKind;
        attribute requestedFlow : FlowRateValue;
    }

    enum def PumpCommandKind {
        enum idle;
        enum start;
        enum stop;
        enum reset;
        enum emergencyStop;
    }

    enum def PumpOperatingMode {
        enum off;
        enum filling;
        enum regulating;
        enum faulted;
        enum lockedOut;
    }

    port def FluidInletPort {
        in item fluidIn : Fluid;
        attribute pressure : PressureValue;
        attribute staticHead : LengthValue;
    }

    port def FluidOutletPort {
        out item fluidOut : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ElectricalPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlInputPort {
        in item controlIn : ControlSignal;
    }

    port def StatusOutputPort {
        out attribute mode : PumpOperatingMode;
        out attribute measuredFlow : FlowRateValue;
        out attribute dischargePressure : PressureValue;
        out attribute motorCurrent : CurrentValue;
        out attribute alarmActive : Boolean;
    }

    port def SensorPort {
        out attribute measuredValue : Real;
        out attribute valid : Boolean;
    }

    port def ProtectionTripPort {
        out attribute tripped : Boolean;
        out attribute reasonCode : String;
    }

    part def IntakeScreen {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute meshOpening : LengthValue = 0.003 [SI::metre];
        attribute maximumDebrisDiameter : LengthValue = 0.0025 [SI::metre];
        attribute pressureDropAtRatedFlow : PressureValue = 1200 [SI::pascal];
    }

    part def SubmersibleMotor {
        port power : ElectricalPowerPort;
        port control : ControlInputPort;
        port trip : ProtectionTripPort;

        attribute ratedVoltage : VoltageValue = 230 [SI::volt];
        attribute ratedCurrent : CurrentValue = 8.5 [SI::ampere];
        attribute ratedPower : PowerValue = 1500 [SI::watt];
        attribute windingTemperature : TemperatureValue;
        attribute maximumWindingTemperature : TemperatureValue = 105 [SI::degreeCelsius];
        attribute submergedCoolingRequired : Boolean = true;
        attribute running : Boolean;

        action def Energize {
            in item electricalInput : ElectricalPower;
            out attribute motorRunning : Boolean;
        }

        action def DeEnergize {
            out attribute motorRunning : Boolean;
        }

        state def MotorStateMachine {
            state deenergized;
            state starting;
            state running;
            state overheated;
            state electricalFault;

            transition first deenergized;
            transition startMotor
                first deenergized
                then starting
                accept control.controlIn.command == PumpCommandKind::start;

            transition completeStart
                first starting
                then running;

            transition stopMotor
                first running
                then deenergized
                accept control.controlIn.command == PumpCommandKind::stop;

            transition highTemperatureTrip
                first running
                then overheated
                accept windingTemperature > maximumWindingTemperature;

            transition resetOverheat
                first overheated
                then deenergized
                accept control.controlIn.command == PumpCommandKind::reset;

            transition powerFault
                first starting
                then electricalFault
                accept power.powerIn.voltage < 190 [SI::volt];

            transition resetElectricalFault
                first electricalFault
                then deenergized
                accept control.controlIn.command == PumpCommandKind::reset;
        }

        behavior motorBehavior : MotorStateMachine;
    }

    part def CentrifugalImpeller {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;

        attribute impellerDiameter : LengthValue = 0.118 [SI::metre];
        attribute ratedSpeed : Real = 3450.0;
        attribute hydraulicEfficiency : EfficiencyValue = 0.62 [SI::one];
        attribute ratedFlow : FlowRateValue = 95 [SI::litre / SI::minute];
        attribute shutoffHead : LengthValue = 42 [SI::metre];

        action def IncreaseFluidEnergy {
            in item incomingFluid : Fluid;
            in attribute rotationalSpeed : Real;
            out item pressurizedFluid : Fluid;
            out attribute producedFlow : FlowRateValue;
            out attribute producedPressure : PressureValue;
        }
    }

    part def PumpHousing {
        port intake : FluidInletPort;
        port discharge : FluidOutletPort;

        attribute material : String = "316 stainless steel";
        attribute maximumSubmergenceDepth : LengthValue = 30 [SI::metre];
        attribute minimumSubmergenceDepth : LengthValue = 0.5 [SI::metre];
        attribute sealLeakRate : FlowRateValue = 0.0 [SI::litre / SI::minute];
    }

    part def CheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : PressureValue = 3000 [SI::pascal];
        attribute reverseLeakageLimit : FlowRateValue = 0.1 [SI::litre / SI::minute];
        attribute open : Boolean;

        state def CheckValveState {
            state closed;
            state opening;
            state openState;
            state closing;

            transition first closed;
            transition forwardPressure
                first closed
                then opening
                accept inlet.pressure > outlet.pressure + crackingPressure;

            transition fullyOpen
                first opening
                then openState;

            transition lowForwardPressure
                first openState
                then closing
                accept inlet.pressure <= outlet.pressure;

            transition fullyClosed
                first closing
                then closed;
        }

        behavior valveBehavior : CheckValveState;
    }

    part def FlowSensor {
        port processConnection : FluidOutletPort;
        port measurement : SensorPort;

        attribute rangeMinimum : FlowRateValue = 0 [SI::litre / SI::minute];
        attribute rangeMaximum : FlowRateValue = 150 [SI::litre / SI::minute];
        attribute accuracyPercentFullScale : Real = 1.5;
        attribute measuredFlow : FlowRateValue;
    }

    part def PressureSensor {
        port processConnection : FluidOutletPort;
        port measurement : SensorPort;

        attribute rangeMinimum : PressureValue = 0 [SI::pascal];
        attribute rangeMaximum : PressureValue = 600000 [SI::pascal];
        attribute accuracyPercentFullScale : Real = 1.0;
        attribute measuredPressure : PressureValue;
    }

    part def LevelSensor {
        port measurement : SensorPort;

        attribute rangeMinimum : LengthValue = 0 [SI::metre];
        attribute rangeMaximum : LengthValue = 10 [SI::metre];
        attribute minimumSafeLevel : LengthValue = 0.6 [SI::metre];
        attribute measuredLevel : LengthValue;
    }

    part def PumpController {
        port commandInput : ControlInputPort;
        port motorCommand : ControlInputPort;
        port status : StatusOutputPort;

        attribute targetFlow : FlowRateValue = 90 [SI::litre / SI::minute];
        attribute lowFlowTripThreshold : FlowRateValue = 10 [SI::litre / SI::minute];
        attribute highPressureTripThreshold : PressureValue = 520000 [SI::pascal];
        attribute dryRunLevelThreshold : LengthValue = 0.6 [SI::metre];
        attribute restartDelay : Real = 30.0;
        attribute mode : PumpOperatingMode = PumpOperatingMode::off;
        attribute faultLatched : Boolean = false;

        ref part flowSensor : FlowSensor;
        ref part pressureSensor : PressureSensor;
        ref part levelSensor : LevelSensor;
        ref part motor : SubmersibleMotor;

        action def StartPump {
            out item startCommand : ControlSignal;
        }

        action def StopPump {
            out item stopCommand : ControlSignal;
        }

        action def LatchFault {
            in attribute reason : String;
            out attribute faultLatchedOut : Boolean;
        }

        action def ClearFault {
            out attribute faultLatchedOut : Boolean;
        }

        state def ControllerStateMachine {
            state off;
            state precheck;
            state starting;
            state regulating;
            state lowLevelStop;
            state highPressureFault;
            state lowFlowFault;
            state emergencyStop;
            state lockedOut;

            transition first off;

            transition receiveStart
                first off
                then precheck
                accept commandInput.controlIn.command == PumpCommandKind::start;

            transition precheckPass
                first precheck
                then starting
                accept levelSensor.measuredLevel >= dryRunLevelThreshold;

            transition dryRunPrevented
                first precheck
                then lowLevelStop
                accept levelSensor.measuredLevel < dryRunLevelThreshold;

            transition pumpAtFlow
                first starting
                then regulating
                accept flowSensor.measuredFlow >= lowFlowTripThreshold;

            transition stopRequested
                first regulating
                then off
                accept commandInput.controlIn.command == PumpCommandKind::stop;

            transition lowLevelDetected
                first regulating
                then lowLevelStop
                accept levelSensor.measuredLevel < dryRunLevelThreshold;

            transition highPressureDetected
                first regulating
                then highPressureFault
                accept pressureSensor.measuredPressure > highPressureTripThreshold;

            transition lowFlowDetected
                first regulating
                then lowFlowFault
                accept flowSensor.measuredFlow < lowFlowTripThreshold;

            transition emergencyStopRequested
                first regulating
                then emergencyStop
                accept commandInput.controlIn.command == PumpCommandKind::emergencyStop;

            transition faultLockout1
                first highPressureFault
                then lockedOut;

            transition faultLockout2
                first lowFlowFault
                then lockedOut;

            transition faultLockout3
                first emergencyStop
                then lockedOut;

            transition resetLockout
                first lockedOut
                then off
                accept commandInput.controlIn.command == PumpCommandKind::reset;

            transition levelRecovered
                first lowLevelStop
                then off
                accept levelSensor.measuredLevel >= dryRunLevelThreshold;
        }

        behavior controlBehavior : ControllerStateMachine;
    }

    part def DischargePipe {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute internalDiameter : LengthValue = 0.038 [SI::metre];
        attribute length : LengthValue = 12 [SI::metre];
        attribute maximumWorkingPressure : PressureValue = 690000 [SI::pascal];
        attribute frictionLossAtRatedFlow : PressureValue = 18000 [SI::pascal];
    }

    part def SumpReservoir {
        port supply : FluidOutletPort;

        attribute usableVolume : VolumeValue = 450 [SI::litre];
        attribute currentLevel : LengthValue;
        attribute minimumOperatingLevel : LengthValue = 0.6 [SI::metre];
        attribute maximumLevel : LengthValue = 2.8 [SI::metre];
        attribute fluid : Water;
    }

    part def PumpingSubsystem {
        port suctionBoundary : FluidInletPort;
        port dischargeBoundary : FluidOutletPort;
        port electricalSupply : ElectricalPowerPort;
        port operatorCommand : ControlInputPort;
        port subsystemStatus : StatusOutputPort;

        attribute ratedFlow : FlowRateValue = 95 [SI::litre / SI::minute];
        attribute minimumContinuousFlow : FlowRateValue = 15 [SI::litre / SI::minute];
        attribute maximumDischargePressure : PressureValue = 520000 [SI::pascal];
        attribute nominalDischargePressure : PressureValue = 350000 [SI::pascal];
        attribute requiredStaticHead : LengthValue = 18 [SI::metre];
        attribute hydraulicEfficiency : EfficiencyValue = 0.58 [SI::one];
        attribute operatingMode : PumpOperatingMode;

        part reservoir : SumpReservoir;
        part intakeScreen : IntakeScreen;
        part housing : PumpHousing;
        part motor : SubmersibleMotor;
        part impeller : CentrifugalImpeller;
        part checkValve : CheckValve;
        part dischargePipe : DischargePipe;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part levelSensor : LevelSensor;
        part controller : PumpController;

        bind controller.flowSensor = flowSensor;
        bind controller.pressureSensor = pressureSensor;
        bind controller.levelSensor = levelSensor;
        bind controller.motor = motor;

        connection reservoirToScreen connect reservoir.supply to intakeScreen.inlet;
        connection screenToHousing connect intakeScreen.outlet to housing.intake;
        connection housingToImpeller connect housing.discharge to impeller.suction;
        connection impellerToCheckValve connect impeller.discharge to checkValve.inlet;
        connection checkValveToPipe connect checkValve.outlet to dischargePipe.inlet;
        connection pipeToBoundary connect dischargePipe.outlet to dischargeBoundary;
        connection flowMeasurement connect dischargePipe.outlet to flowSensor.processConnection;
        connection pressureMeasurement connect dischargePipe.outlet to pressureSensor.processConnection;
        connection externalPower connect electricalSupply to motor.power;
        connection operatorToController connect operatorCommand to controller.commandInput;
        connection controllerToMotor connect controller.motorCommand to motor.control;
        connection controllerStatus connect controller.status to subsystemStatus;

        action def PumpFluid {
            in item sourceFluid : Water;
            in item electricalInput : ElectricalPower;
            in item command : ControlSignal;
            out item deliveredFluid : Water;
            out attribute deliveredFlow : FlowRateValue;
            out attribute deliveredPressure : PressureValue;

            first start;
            then verifySubmergence;
            then energizeMotor;
            then accelerateImpeller;
            then raisePressure;
            then dischargeFlow;
            then monitorOperation;

            action start;
            action verifySubmergence;
            action energizeMotor;
            action accelerateImpeller;
            action raisePressure;
            action dischargeFlow;
            action monitorOperation;
        }

        state def PumpingSubsystemStateMachine {
            state unavailable;
            state ready;
            state pumping;
            state controlledShutdown;
            state dryRunProtected;
            state pressureProtected;
            state failed;

            transition first ready;

            transition startPumping
                first ready
                then pumping
                accept operatorCommand.controlIn.command == PumpCommandKind::start;

            transition normalStop
                first pumping
                then controlledShutdown
                accept operatorCommand.controlIn.command == PumpCommandKind::stop;

            transition shutdownComplete
                first controlledShutdown
                then ready;

            transition dryRunProtection
                first pumping
                then dryRunProtected
                accept reservoir.currentLevel < reservoir.minimumOperatingLevel;

            transition pressureProtection
                first pumping
                then pressureProtected
                accept pressureSensor.measuredPressure > maximumDischargePressure;

            transition protectionReset1
                first dryRunProtected
                then ready
                accept operatorCommand.controlIn.command == PumpCommandKind::reset;

            transition protectionReset2
                first pressureProtected
                then ready
                accept operatorCommand.controlIn.command == PumpCommandKind::reset;

            transition unrecoverableMotorTrip
                first pumping
                then failed
                accept motor.trip.tripped == true;

            transition serviceReset
                first failed
                then ready
                accept operatorCommand.controlIn.command == PumpCommandKind::reset;
        }

        behavior subsystemBehavior : PumpingSubsystemStateMachine;
    }

    requirement def MoveFluidRequirement {
        doc /* The pumping subsystem shall move water from the sump reservoir to the discharge boundary using a submersible pump. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.ratedFlow >= 90 [SI::litre / SI::minute]
        }
    }

    requirement def SubmersiblePumpRequirement {
        doc /* The pump motor and hydraulic assembly shall operate while submerged and shall use the surrounding fluid for cooling. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.motor.submergedCoolingRequired == true and
            subsystem.housing.minimumSubmergenceDepth >= 0.5 [SI::metre]
        }
    }

    requirement def DischargePressureRequirement {
        doc /* The subsystem shall provide nominal discharge pressure sufficient to overcome the required static head and pipe losses. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.nominalDischargePressure >= 300000 [SI::pascal] and
            subsystem.maximumDischargePressure <= 520000 [SI::pascal]
        }
    }

    requirement def DryRunProtectionRequirement {
        doc /* The subsystem shall prevent pump operation when reservoir level is below the minimum operating level. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.levelSensor.minimumSafeLevel == subsystem.reservoir.minimumOperatingLevel
        }
    }

    requirement def BackflowPreventionRequirement {
        doc /* The subsystem shall prevent reverse flow from the discharge line into the sump reservoir when the pump is stopped. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.checkValve.reverseLeakageLimit <= 0.1 [SI::litre / SI::minute]
        }
    }

    requirement def ElectricalRatingRequirement {
        doc /* The submersible motor shall be compatible with a 230 volt single phase supply and shall not exceed its rated current in continuous operation. */
        subject motor : SubmersibleMotor;
        require constraint {
            motor.ratedVoltage == 230 [SI::volt] and
            motor.ratedCurrent <= 8.5 [SI::ampere]
        }
    }

    requirement def InstrumentationRequirement {
        doc /* The subsystem shall measure discharge flow, discharge pressure, and sump level for automatic protection and status reporting. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.flowSensor.rangeMaximum >= subsystem.ratedFlow and
            subsystem.pressureSensor.rangeMaximum >= subsystem.maximumDischargePressure and
            subsystem.levelSensor.rangeMaximum >= subsystem.reservoir.maximumLevel
        }
    }

    requirement def MinimumContinuousFlowRequirement {
        doc /* The subsystem shall maintain a minimum continuous flow to avoid overheating and hydraulic instability during pumping. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.minimumContinuousFlow >= 15 [SI::litre / SI::minute] and
            subsystem.controller.lowFlowTripThreshold < subsystem.ratedFlow
        }
    }

    satisfy MoveFluidRequirement by PumpingSubsystem;
    satisfy SubmersiblePumpRequirement by PumpingSubsystem;
    satisfy DischargePressureRequirement by PumpingSubsystem;
    satisfy DryRunProtectionRequirement by PumpingSubsystem;
    satisfy BackflowPreventionRequirement by PumpingSubsystem;
    satisfy ElectricalRatingRequirement by SubmersibleMotor;
    satisfy InstrumentationRequirement by PumpingSubsystem;
    satisfy MinimumContinuousFlowRequirement by PumpingSubsystem;

    part pumpingSubsystem : PumpingSubsystem {
        :>> reservoir.currentLevel = 1.4 [SI::metre];
        :>> operatingMode = PumpOperatingMode::off;
    }
}