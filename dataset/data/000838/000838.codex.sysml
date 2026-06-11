package PumpingSubsystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import USCustomaryUnits::*;

    attribute def Pressure;
    attribute def VolumeFlowRate;
    attribute def Temperature;
    attribute def Duration;
    attribute def Mass;
    attribute def Volume;
    attribute def Frequency;
    attribute def Length;
    attribute def Area;
    attribute def Power;
    attribute def ElectricPotential;
    attribute def ElectricCurrent;

    value def Percent :> ScalarValues::Real {
        unit = "%";
    }

    value def Milliliter :> SI::Unit {
        symbol = "mL";
    }

    value def MilliliterPerMinute :> SI::Unit {
        symbol = "mL/min";
    }

    value def StrokePerMinute :> SI::Unit {
        symbol = "stroke/min";
    }

    value def Bar :> SI::Unit {
        symbol = "bar";
    }

    value def Micrometer :> SI::Unit {
        symbol = "um";
    }

    item def Fluid {
        attribute density : Real [kg/m^3] = 998.0;
        attribute dynamicViscosity : Real [Pa*s] = 0.001;
        attribute temperature : Real [K];
        attribute particulateLimit : Real [um] = 100.0;
        attribute compatibilityCode : String;
    }

    item def MeteredFluid :> Fluid {
        attribute targetFlowRate : Real [mL/min];
        attribute deliveredVolume : Real [mL];
        attribute dischargePressure : Real [bar];
        attribute batchIdentifier : String;
    }

    item def ElectricalPower {
        attribute voltage : Real [V];
        attribute current : Real [A];
        attribute frequency : Real [Hz];
        attribute availablePower : Real [W];
    }

    item def ControlCommand {
        attribute enable : Boolean;
        attribute targetFlowRate : Real [mL/min];
        attribute primeRequest : Boolean;
        attribute purgeRequest : Boolean;
        attribute calibrationRequest : Boolean;
        attribute stopRequest : Boolean;
    }

    item def PumpStatus {
        attribute running : Boolean;
        attribute primed : Boolean;
        attribute faulted : Boolean;
        attribute actualFlowRate : Real [mL/min];
        attribute dischargePressure : Real [bar];
        attribute cumulativeVolume : Real [mL];
        attribute activeFaultCode : String;
    }

    item def FaultSignal {
        attribute active : Boolean;
        attribute code : String;
        attribute severity : Integer;
        attribute message : String;
    }

    port def FluidInletPort {
        in item fluidIn : Fluid;
        attribute allowablePressure : Real [bar];
        attribute nominalTemperature : Real [K];
    }

    port def FluidOutletPort {
        out item fluidOut : MeteredFluid;
        attribute ratedPressure : Real [bar];
        attribute flowCapacity : Real [mL/min];
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def CommandInputPort {
        in item commandIn : ControlCommand;
    }

    port def StatusOutputPort {
        out item statusOut : PumpStatus;
    }

    port def FaultOutputPort {
        out item faultOut : FaultSignal;
    }

    part def Reservoir {
        attribute usableVolume : Real [mL] = 2000.0;
        attribute minimumOperatingVolume : Real [mL] = 100.0;
        attribute currentVolume : Real [mL];
        attribute vented : Boolean = true;

        port outlet : FluidOutletPort {
            flowCapacity = 500.0;
            ratedPressure = 1.2;
        }
    }

    part def InletFilter {
        attribute poreSize : Real [um] = 40.0;
        attribute maximumDifferentialPressure : Real [bar] = 0.5;
        attribute capturedParticulateMass : Real [mg];

        port inlet : FluidInletPort {
            allowablePressure = 1.2;
            nominalTemperature = 293.15;
        }

        port outlet : FluidOutletPort {
            flowCapacity = 250.0;
            ratedPressure = 1.2;
        }
    }

    part def CheckValve {
        attribute crackingPressure : Real [bar] = 0.15;
        attribute reverseLeakageLimit : Real [mL/min] = 0.01;
        attribute open : Boolean;

        port inlet : FluidInletPort {
            allowablePressure = 16.0;
            nominalTemperature = 293.15;
        }

        port outlet : FluidOutletPort {
            flowCapacity = 250.0;
            ratedPressure = 16.0;
        }
    }

    part def MeteringPump {
        attribute displacementPerStroke : Real [mL] = 0.25;
        attribute commandedStrokeRate : Real [stroke/min];
        attribute actualStrokeRate : Real [stroke/min];
        attribute strokeLengthSetting : Real [%] = 100.0;
        attribute minimumFlowRate : Real [mL/min] = 0.5;
        attribute maximumFlowRate : Real [mL/min] = 125.0;
        attribute maximumDischargePressure : Real [bar] = 10.0;
        attribute flowAccuracy : Real [%] = 1.0;
        attribute repeatability : Real [%] = 0.5;
        attribute primed : Boolean = false;
        attribute running : Boolean = false;
        attribute cumulativeVolume : Real [mL] = 0.0;

        port suction : FluidInletPort {
            allowablePressure = 1.5;
            nominalTemperature = 293.15;
        }

        port discharge : FluidOutletPort {
            flowCapacity = 125.0;
            ratedPressure = 10.0;
        }

        port power : PowerInputPort;

        port command : CommandInputPort;

        port status : StatusOutputPort;

        port fault : FaultOutputPort;

        action primePump {
            in item incomingFluid : Fluid;
            out item primedFluid : MeteredFluid;
            first startMotor;
            then evacuateAir;
            then confirmPrime;
            action startMotor;
            action evacuateAir;
            action confirmPrime;
        }

        action meterFluid {
            in item inletFluid : Fluid;
            in item command : ControlCommand;
            out item outletFluid : MeteredFluid;

            attribute computedStrokeRate : Real [stroke/min];

            first calculateStrokeRate;
            then actuateDiaphragm;
            then updateDeliveredVolume;
            then emitStatus;

            action calculateStrokeRate {
                out attribute computedStrokeRate : Real [stroke/min];
            }

            action actuateDiaphragm;
            action updateDeliveredVolume;
            action emitStatus;
        }

        action stopPump {
            first disableDrive;
            then closeInternalValves;
            then emitStoppedStatus;
            action disableDrive;
            action closeInternalValves;
            action emitStoppedStatus;
        }

        state def PumpOperatingState {
            entry action initializeStatus;

            state Off;
            state Standby;
            state Priming;
            state Metering;
            state Purging;
            state Calibrating;
            state Faulted;

            transition initial then Off;

            transition powerApplied
                first Off
                accept ControlCommand
                if commandIn.enable
                then Standby;

            transition beginPrime
                first Standby
                accept ControlCommand
                if commandIn.primeRequest
                do primePump
                then Priming;

            transition primeComplete
                first Priming
                if primed
                then Standby;

            transition beginMetering
                first Standby
                accept ControlCommand
                if commandIn.enable and commandIn.targetFlowRate >= minimumFlowRate and commandIn.targetFlowRate <= maximumFlowRate
                do meterFluid
                then Metering;

            transition adjustMetering
                first Metering
                accept ControlCommand
                if commandIn.enable and not commandIn.stopRequest
                do meterFluid
                then Metering;

            transition stopMetering
                first Metering
                accept ControlCommand
                if commandIn.stopRequest or not commandIn.enable
                do stopPump
                then Standby;

            transition beginPurge
                first Standby
                accept ControlCommand
                if commandIn.purgeRequest
                then Purging;

            transition purgeComplete
                first Purging
                then Standby;

            transition beginCalibration
                first Standby
                accept ControlCommand
                if commandIn.calibrationRequest
                then Calibrating;

            transition calibrationComplete
                first Calibrating
                then Standby;

            transition overPressureFault
                first Metering
                if discharge.ratedPressure > maximumDischargePressure
                then Faulted;

            transition invalidCommandFault
                first Standby
                accept ControlCommand
                if commandIn.targetFlowRate > maximumFlowRate
                then Faulted;

            transition resetFault
                first Faulted
                accept ControlCommand
                if not commandIn.enable
                then Off;
        }
    }

    part def PressureSensor {
        attribute measurementRange : Real [bar] = 16.0;
        attribute accuracy : Real [%] = 0.25;
        attribute measuredPressure : Real [bar];

        port processPort : FluidInletPort {
            allowablePressure = 16.0;
            nominalTemperature = 293.15;
        }

        port status : StatusOutputPort;
    }

    part def FlowSensor {
        attribute measurementRange : Real [mL/min] = 150.0;
        attribute accuracy : Real [%] = 0.5;
        attribute measuredFlowRate : Real [mL/min];

        port inlet : FluidInletPort {
            allowablePressure = 10.0;
            nominalTemperature = 293.15;
        }

        port outlet : FluidOutletPort {
            flowCapacity = 150.0;
            ratedPressure = 10.0;
        }

        port status : StatusOutputPort;
    }

    part def Controller {
        attribute requestedFlowRate : Real [mL/min];
        attribute closedLoopEnabled : Boolean = true;
        attribute pressureTripLimit : Real [bar] = 9.5;
        attribute lowReservoirLimit : Real [mL] = 100.0;
        attribute totalizedVolume : Real [mL];

        port commandIn : CommandInputPort;
        port pumpCommand : CommandInputPort;
        port pumpStatus : StatusOutputPort;
        port pressureStatus : StatusOutputPort;
        port flowStatus : StatusOutputPort;
        port subsystemStatus : StatusOutputPort;
        port faultOut : FaultOutputPort;

        action regulateFlow {
            in item operatorCommand : ControlCommand;
            in item measuredStatus : PumpStatus;
            out item pumpCommandOut : ControlCommand;

            first compareTargetAndActual;
            then computeStrokeCorrection;
            then issuePumpCommand;

            action compareTargetAndActual;
            action computeStrokeCorrection;
            action issuePumpCommand;
        }

        action detectFaults {
            in item measuredStatus : PumpStatus;
            out item fault : FaultSignal;

            first evaluatePressure;
            then evaluateFlowDeviation;
            then evaluateReservoirLevel;
            then publishFault;

            action evaluatePressure;
            action evaluateFlowDeviation;
            action evaluateReservoirLevel;
            action publishFault;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : Real [V] = 24.0;
        attribute maximumCurrent : Real [A] = 4.0;
        attribute outputPowerLimit : Real [W] = 96.0;

        port powerOut : PowerInputPort;
    }

    part def DischargeLine {
        attribute internalDiameter : Real [mm] = 6.0;
        attribute length : Real [m] = 2.0;
        attribute maximumWorkingPressure : Real [bar] = 10.0;
        attribute holdUpVolume : Real [mL] = 56.5;

        port inlet : FluidInletPort {
            allowablePressure = 10.0;
            nominalTemperature = 293.15;
        }

        port outlet : FluidOutletPort {
            flowCapacity = 125.0;
            ratedPressure = 10.0;
        }
    }

    part def PumpingSubsystem {
        attribute requiredFlowRate : Real [mL/min] = 50.0;
        attribute allowableFlowError : Real [%] = 2.0;
        attribute maximumOperatingPressure : Real [bar] = 10.0;
        attribute nominalFluidTemperature : Real [K] = 293.15;
        attribute deliveredVolumeTotal : Real [mL];

        port fluidSupply : FluidInletPort {
            allowablePressure = 1.2;
            nominalTemperature = 293.15;
        }

        port meteredDischarge : FluidOutletPort {
            flowCapacity = 125.0;
            ratedPressure = 10.0;
        }

        port electricalInput : PowerInputPort;
        port operatorCommand : CommandInputPort;
        port subsystemStatus : StatusOutputPort;
        port subsystemFault : FaultOutputPort;

        part reservoir : Reservoir;
        part inletFilter : InletFilter;
        part suctionCheckValve : CheckValve {
            crackingPressure = 0.05;
            reverseLeakageLimit = 0.005;
        }
        part meteringPump : MeteringPump;
        part dischargeCheckValve : CheckValve {
            crackingPressure = 0.20;
            reverseLeakageLimit = 0.005;
        }
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : Controller;
        part powerSupply : PowerSupply;
        part dischargeLine : DischargeLine;

        connect fluidSupply to reservoir.outlet;
        connect reservoir.outlet to inletFilter.inlet;
        connect inletFilter.outlet to suctionCheckValve.inlet;
        connect suctionCheckValve.outlet to meteringPump.suction;
        connect meteringPump.discharge to dischargeCheckValve.inlet;
        connect dischargeCheckValve.outlet to pressureSensor.processPort;
        connect pressureSensor.processPort to flowSensor.inlet;
        connect flowSensor.outlet to dischargeLine.inlet;
        connect dischargeLine.outlet to meteredDischarge;

        connect electricalInput to powerSupply.powerOut;
        connect powerSupply.powerOut to meteringPump.power;

        connect operatorCommand to controller.commandIn;
        connect controller.pumpCommand to meteringPump.command;
        connect meteringPump.status to controller.pumpStatus;
        connect pressureSensor.status to controller.pressureStatus;
        connect flowSensor.status to controller.flowStatus;
        connect controller.subsystemStatus to subsystemStatus;
        connect controller.faultOut to subsystemFault;
        connect meteringPump.fault to subsystemFault;

        action deliverMeteredFluid {
            in item sourceFluid : Fluid;
            in item command : ControlCommand;
            out item deliveredFluid : MeteredFluid;

            first validateCommand;
            then conditionFluid;
            then primeIfRequired;
            then meterThroughPump;
            then verifyDelivery;
            then updateSubsystemStatus;

            action validateCommand;
            action conditionFluid;
            action primeIfRequired;
            action meterThroughPump;
            action verifyDelivery;
            action updateSubsystemStatus;
        }

        action shutdownSubsystem {
            first commandPumpStop;
            then isolateDischarge;
            then publishStoppedStatus;

            action commandPumpStop;
            action isolateDischarge;
            action publishStoppedStatus;
        }

        state def SubsystemState {
            state DeEnergized;
            state Ready;
            state Priming;
            state Delivering;
            state Hold;
            state Shutdown;
            state Fault;

            transition initial then DeEnergized;

            transition energize
                first DeEnergized
                accept ElectricalPower
                if powerIn.voltage >= 21.6 and powerIn.voltage <= 26.4
                then Ready;

            transition commandPrime
                first Ready
                accept ControlCommand
                if commandIn.primeRequest
                then Priming;

            transition primeDone
                first Priming
                if meteringPump.primed
                then Ready;

            transition commandDelivery
                first Ready
                accept ControlCommand
                if commandIn.enable and commandIn.targetFlowRate > 0.0
                do deliverMeteredFluid
                then Delivering;

            transition holdDelivery
                first Delivering
                accept ControlCommand
                if commandIn.enable and commandIn.targetFlowRate == 0.0
                then Hold;

            transition resumeDelivery
                first Hold
                accept ControlCommand
                if commandIn.enable and commandIn.targetFlowRate > 0.0
                then Delivering;

            transition stopDelivery
                first Delivering
                accept ControlCommand
                if commandIn.stopRequest or not commandIn.enable
                do shutdownSubsystem
                then Shutdown;

            transition shutdownComplete
                first Shutdown
                then Ready;

            transition pressureFault
                first Delivering
                if pressureSensor.measuredPressure >= maximumOperatingPressure
                then Fault;

            transition flowFault
                first Delivering
                if flowSensor.measuredFlowRate < requiredFlowRate * 0.90
                then Fault;

            transition deenergize
                first Ready
                accept ElectricalPower
                if powerIn.availablePower == 0.0
                then DeEnergized;
        }
    }

    requirement def MeteredFluidDeliveryRequirement {
        subject subsystem : PumpingSubsystem;
        attribute requiredNominalFlow : Real [mL/min] = 50.0;
        attribute permittedError : Real [%] = 2.0;

        require constraint {
            subsystem.flowSensor.measuredFlowRate >= requiredNominalFlow * (1.0 - permittedError / 100.0) and
            subsystem.flowSensor.measuredFlowRate <= requiredNominalFlow * (1.0 + permittedError / 100.0)
        }
    }

    requirement def MaximumPressureRequirement {
        subject subsystem : PumpingSubsystem;
        attribute pressureLimit : Real [bar] = 10.0;

        require constraint {
            subsystem.pressureSensor.measuredPressure <= pressureLimit
        }
    }

    requirement def PumpCapacityRequirement {
        subject pump : MeteringPump;

        require constraint {
            pump.maximumFlowRate >= 125.0 and
            pump.maximumDischargePressure >= 10.0
        }
    }

    requirement def ReverseLeakageRequirement {
        subject subsystem : PumpingSubsystem;
        attribute leakageLimit : Real [mL/min] = 0.01;

        require constraint {
            subsystem.suctionCheckValve.reverseLeakageLimit <= leakageLimit and
            subsystem.dischargeCheckValve.reverseLeakageLimit <= leakageLimit
        }
    }

    requirement def PrimeBeforeDeliveryRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.meteringPump.primed == true
        }
    }

    requirement def ElectricalCompatibilityRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.powerSupply.nominalVoltage == 24.0 and
            subsystem.powerSupply.maximumCurrent >= 4.0
        }
    }

    requirement def FiltrationRequirement {
        subject subsystem : PumpingSubsystem;
        attribute maximumParticleSize : Real [um] = 40.0;

        require constraint {
            subsystem.inletFilter.poreSize <= maximumParticleSize
        }
    }

    satisfy MeteredFluidDeliveryRequirement by PumpingSubsystem;
    satisfy MaximumPressureRequirement by PumpingSubsystem;
    satisfy PumpCapacityRequirement by MeteringPump;
    satisfy ReverseLeakageRequirement by PumpingSubsystem;
    satisfy PrimeBeforeDeliveryRequirement by PumpingSubsystem;
    satisfy ElectricalCompatibilityRequirement by PumpingSubsystem;
    satisfy FiltrationRequirement by PumpingSubsystem;

    part pumpingSubsystem : PumpingSubsystem {
        requiredFlowRate = 50.0;
        allowableFlowError = 2.0;
        maximumOperatingPressure = 10.0;
        nominalFluidTemperature = 293.15;
    }
}