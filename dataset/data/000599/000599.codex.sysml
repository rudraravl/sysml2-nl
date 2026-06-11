package ErYAGLaserSystemSpecification {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> ScalarValues::Real;
    attribute def Nanometer :> ScalarValues::Real;
    attribute def Millijoule :> ScalarValues::Real;
    attribute def Hertz :> ScalarValues::Real;
    attribute def Microsecond :> ScalarValues::Real;
    attribute def Millimeter :> ScalarValues::Real;
    attribute def LiterPerMinute :> ScalarValues::Real;
    attribute def DegreeCelsius :> ScalarValues::Real;

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute frequency : Hertz;
    }

    item def OpticalPulse {
        attribute wavelength : Nanometer;
        attribute pulseEnergy : Millijoule;
        attribute pulseDuration : Microsecond;
        attribute repetitionRate : Hertz;
        attribute beamDiameter : Millimeter;
        attribute divergence : Real;
    }

    item def CoolingFluid {
        attribute inletTemperature : DegreeCelsius;
        attribute outletTemperature : DegreeCelsius;
        attribute flowRate : LiterPerMinute;
        attribute pressure : Pascal;
    }

    item def ControlCommand {
        attribute enableRequested : Boolean;
        attribute requestedPulseEnergy : Millijoule;
        attribute requestedRepetitionRate : Hertz;
        attribute emissionDuration : Second;
    }

    item def StatusReport {
        attribute ready : Boolean;
        attribute emitting : Boolean;
        attribute faultActive : Boolean;
        attribute measuredPulseEnergy : Millijoule;
        attribute crystalTemperature : DegreeCelsius;
        attribute coolingFlowRate : LiterPerMinute;
    }

    item def ThermalLoad {
        attribute heatPower : Watt;
        attribute sourceTemperature : DegreeCelsius;
    }

    port def ElectricalPowerIn {
        in item power : ElectricalPower;
    }

    port def OpticalPulseOut {
        out item pulse : OpticalPulse;
    }

    port def CoolingIn {
        in item coolant : CoolingFluid;
    }

    port def CoolingOut {
        out item coolant : CoolingFluid;
    }

    port def CommandIn {
        in item command : ControlCommand;
    }

    port def StatusOut {
        out item status : StatusReport;
    }

    port def HeatOut {
        out item heat : ThermalLoad;
    }

    port def HeatIn {
        in item heat : ThermalLoad;
    }

    part def ErYAGLaserSystem {
        attribute nominalWavelength : Nanometer = 2940.0;
        attribute maximumPulseEnergy : Millijoule = 800.0;
        attribute maximumRepetitionRate : Hertz = 50.0;
        attribute primaryFunction : String = "Generate controlled 2940 nm pulsed infrared laser energy for high-water-absorption surface ablation and precise material interaction.";

        port electricalInput : ElectricalPowerIn;
        port commandInput : CommandIn;
        port statusOutput : StatusOut;
        port coolingSupply : CoolingIn;
        port coolingReturn : CoolingOut;
        port treatmentBeam : OpticalPulseOut;

        part powerSupply : LaserPowerSupply;
        part controller : LaserController;
        part pumpModule : FlashlampPumpModule;
        part resonator : ErYAGResonator;
        part qSwitch : PulseControlModule;
        part beamDelivery : BeamDeliveryModule;
        part coolingUnit : CoolingSubsystem;
        part safetyInterlock : SafetyInterlockSubsystem;
        part userInterface : OperatorInterface;
        part energyMonitor : PulseEnergyMonitor;
        part thermalManager : ThermalManagementAssembly;

        connect electricalInput.power to powerSupply.inputPower.power;
        connect commandInput.command to controller.operatorCommand.command;
        connect userInterface.userCommand.command to controller.operatorCommand.command;
        connect controller.powerCommand.command to powerSupply.controlCommand.command;
        connect controller.pumpCommand.command to pumpModule.pumpCommand.command;
        connect controller.qSwitchCommand.command to qSwitch.triggerCommand.command;
        connect controller.status.status to statusOutput.status;
        connect safetyInterlock.interlockStatus.status to controller.interlockStatus.status;

        connect powerSupply.pumpPower.power to pumpModule.electricalInput.power;
        connect pumpModule.pumpLight.pulse to resonator.pumpInput.pulse;
        connect resonator.cavityPulse.pulse to qSwitch.inputPulse.pulse;
        connect qSwitch.shapedPulse.pulse to beamDelivery.inputPulse.pulse;
        connect beamDelivery.deliveredPulse.pulse to treatmentBeam.pulse;
        connect beamDelivery.sampledPulse.pulse to energyMonitor.measuredPulse.pulse;
        connect energyMonitor.energyStatus.status to controller.energyFeedback.status;

        connect coolingSupply.coolant to coolingUnit.coolantIn.coolant;
        connect coolingUnit.coolantOut.coolant to coolingReturn.coolant;
        connect pumpModule.thermalOutput.heat to thermalManager.heatInput.heat;
        connect resonator.thermalOutput.heat to thermalManager.heatInput.heat;
        connect qSwitch.thermalOutput.heat to thermalManager.heatInput.heat;
        connect thermalManager.coolingDemand.heat to coolingUnit.heatInput.heat;

        perform action initializeSystem;
        perform action generateTreatmentPulse;
        perform action shutdownSystem;

        state machine operationalStates {
            state Off;
            state Initializing;
            state Standby;
            state Armed;
            state Emitting;
            state Fault;
            state CoolingDown;

            initial then Off;

            transition Off_to_Initializing
                first Off
                accept ControlCommand
                if command.enableRequested
                then Initializing;

            transition Initializing_to_Standby
                first Initializing
                if controller.selfTestPassed and coolingUnit.flowVerified and safetyInterlock.closed
                then Standby;

            transition Initializing_to_Fault
                first Initializing
                if not controller.selfTestPassed or not coolingUnit.flowVerified
                then Fault;

            transition Standby_to_Armed
                first Standby
                accept ControlCommand
                if command.enableRequested and safetyInterlock.closed
                then Armed;

            transition Armed_to_Emitting
                first Armed
                accept ControlCommand
                if command.requestedPulseEnergy <= maximumPulseEnergy and command.requestedRepetitionRate <= maximumRepetitionRate
                then Emitting;

            transition Emitting_to_Armed
                first Emitting
                if controller.commandComplete
                then Armed;

            transition Emitting_to_Fault
                first Emitting
                if safetyInterlock.opened or energyMonitor.energyOutOfTolerance or coolingUnit.flowBelowMinimum
                then Fault;

            transition Armed_to_Standby
                first Armed
                accept ControlCommand
                if not command.enableRequested
                then Standby;

            transition Fault_to_CoolingDown
                first Fault
                if controller.faultAcknowledged
                then CoolingDown;

            transition CoolingDown_to_Standby
                first CoolingDown
                if resonator.crystalTemperature <= 35.0
                then Standby;
        }
    }

    part def LaserPowerSupply {
        port inputPower : ElectricalPowerIn;
        port controlCommand : CommandIn;
        port pumpPower : ElectricalPowerIn;

        attribute inputVoltage : Volt = 230.0;
        attribute maximumOutputPower : Watt = 3000.0;
        attribute conversionEfficiency : Percent = 88.0;
    }

    part def LaserController {
        port operatorCommand : CommandIn;
        port powerCommand : CommandIn;
        port pumpCommand : CommandIn;
        port qSwitchCommand : CommandIn;
        port interlockStatus : StatusOut;
        port energyFeedback : StatusOut;
        port status : StatusOut;

        attribute selfTestPassed : Boolean;
        attribute commandComplete : Boolean;
        attribute faultAcknowledged : Boolean;

        action def regulatePulseEnergy {
            in attribute requestedEnergy : Millijoule;
            in attribute measuredEnergy : Millijoule;
            out attribute pumpAdjustment : Percent;
        }

        action def superviseEmission {
            in item command : ControlCommand;
            in item feedback : StatusReport;
            out item status : StatusReport;
        }
    }

    part def FlashlampPumpModule {
        port electricalInput : ElectricalPowerIn;
        port pumpCommand : CommandIn;
        port pumpLight : OpticalPulseOut;
        port thermalOutput : HeatOut;

        attribute pumpPulseDuration : Microsecond = 250.0;
        attribute pumpEfficiency : Percent = 18.0;
        attribute maximumLampCurrent : Ampere = 600.0;
    }

    part def ErYAGResonator {
        port pumpInput : OpticalPulseOut;
        port cavityPulse : OpticalPulseOut;
        port thermalOutput : HeatOut;

        attribute erbiumDopingFraction : Percent = 50.0;
        attribute crystalLength : Millimeter = 80.0;
        attribute crystalDiameter : Millimeter = 6.0;
        attribute crystalTemperature : DegreeCelsius;
        attribute outputCouplerReflectivity : Percent = 85.0;
        attribute generatedWavelength : Nanometer = 2940.0;
    }

    part def PulseControlModule {
        port triggerCommand : CommandIn;
        port inputPulse : OpticalPulseOut;
        port shapedPulse : OpticalPulseOut;
        port thermalOutput : HeatOut;

        attribute minimumPulseDuration : Microsecond = 100.0;
        attribute maximumPulseDuration : Microsecond = 500.0;
        attribute timingJitter : Microsecond = 1.0;
    }

    part def BeamDeliveryModule {
        port inputPulse : OpticalPulseOut;
        port deliveredPulse : OpticalPulseOut;
        port sampledPulse : OpticalPulseOut;

        attribute focusingSpotDiameter : Millimeter = 0.8;
        attribute transmissionEfficiency : Percent = 92.0;
        attribute aimingBeamWavelength : Nanometer = 635.0;
        attribute workingDistance : Millimeter = 120.0;
    }

    part def CoolingSubsystem {
        port coolantIn : CoolingIn;
        port coolantOut : CoolingOut;
        port heatInput : HeatIn;

        attribute nominalFlowRate : LiterPerMinute = 4.0;
        attribute minimumFlowRate : LiterPerMinute = 2.5;
        attribute setpointTemperature : DegreeCelsius = 22.0;
        attribute maximumReturnTemperature : DegreeCelsius = 32.0;
        attribute flowVerified : Boolean;
        attribute flowBelowMinimum : Boolean;
    }

    part def SafetyInterlockSubsystem {
        port interlockStatus : StatusOut;

        attribute enclosureClosed : Boolean;
        attribute keySwitchEnabled : Boolean;
        attribute emergencyStopReleased : Boolean;
        attribute coolingPermissive : Boolean;
        attribute closed : Boolean;
        attribute opened : Boolean;

        action def evaluatePermissive {
            in attribute enclosureClosed : Boolean;
            in attribute keySwitchEnabled : Boolean;
            in attribute emergencyStopReleased : Boolean;
            in attribute coolingPermissive : Boolean;
            out attribute emissionPermitted : Boolean;
        }
    }

    part def OperatorInterface {
        port userCommand : CommandIn;

        attribute selectedPulseEnergy : Millijoule;
        attribute selectedRepetitionRate : Hertz;
        attribute emissionEnabled : Boolean;
    }

    part def PulseEnergyMonitor {
        port measuredPulse : OpticalPulseOut;
        port energyStatus : StatusOut;

        attribute calibrationWavelength : Nanometer = 2940.0;
        attribute measurementAccuracy : Percent = 5.0;
        attribute energyOutOfTolerance : Boolean;
    }

    part def ThermalManagementAssembly {
        port heatInput : HeatIn;
        port coolingDemand : HeatOut;

        attribute maximumCrystalTemperature : DegreeCelsius = 45.0;
        attribute maximumPumpHousingTemperature : DegreeCelsius = 60.0;
        attribute rejectedHeatPower : Watt;
    }

    action def initializeSystem {
        out attribute ready : Boolean;
        first start;
        then verifyPower;
        then verifyCooling;
        then verifyInterlocks;
        then prechargePowerSupply;
        then ready := true;
    }

    action def generateTreatmentPulse {
        in attribute commandedEnergy : Millijoule;
        in attribute commandedRate : Hertz;
        out item emittedPulse : OpticalPulse;
        first validateCommand;
        then energizePumpModule;
        then buildPopulationInversion;
        then triggerPulseControl;
        then shapeAndDeliverBeam;
        then measurePulseEnergy;
    }

    action def shutdownSystem {
        first disableEmission;
        then dischargePowerSupply;
        then continueCooling;
        then storeStatus;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall generate controlled pulsed infrared laser radiation at the Er:YAG wavelength for precise surface energy delivery. */

        attribute requiredWavelength : Nanometer = 2940.0;
        attribute wavelengthTolerance : Nanometer = 10.0;

        require constraint {
            ErYAGLaserSystem::nominalWavelength >= requiredWavelength - wavelengthTolerance and
            ErYAGLaserSystem::nominalWavelength <= requiredWavelength + wavelengthTolerance
        }
    }

    requirement def PulseEnergyRequirement {
        doc
        /* The system shall deliver operator-selected pulse energy up to 800 mJ while monitoring delivered energy. */

        require constraint {
            ErYAGLaserSystem::maximumPulseEnergy >= 800.0
        }
    }

    requirement def RepetitionRateRequirement {
        doc
        /* The system shall support pulsed operation up to 50 Hz for controlled treatment throughput. */

        require constraint {
            ErYAGLaserSystem::maximumRepetitionRate >= 50.0
        }
    }

    requirement def CoolingRequirement {
        doc
        /* The cooling subsystem shall maintain resonator crystal temperature below 45 degC during enabled operation. */

        require constraint {
            ThermalManagementAssembly::maximumCrystalTemperature <= 45.0
        }
    }

    requirement def SafetyInterlockRequirement {
        doc
        /* Laser emission shall be inhibited unless enclosure, key switch, emergency stop, and cooling permissive conditions are satisfied. */

        require constraint {
            SafetyInterlockSubsystem::closed ==
            (SafetyInterlockSubsystem::enclosureClosed and
             SafetyInterlockSubsystem::keySwitchEnabled and
             SafetyInterlockSubsystem::emergencyStopReleased and
             SafetyInterlockSubsystem::coolingPermissive)
        }
    }

    requirement def BeamDeliveryRequirement {
        doc
        /* The beam delivery module shall transmit at least 90 percent of resonator output energy to the treatment beam output. */

        require constraint {
            BeamDeliveryModule::transmissionEfficiency >= 90.0
        }
    }

    satisfy PrimaryFunctionRequirement by ErYAGLaserSystem;
    satisfy PulseEnergyRequirement by ErYAGLaserSystem;
    satisfy RepetitionRateRequirement by ErYAGLaserSystem;
    satisfy CoolingRequirement by CoolingSubsystem;
    satisfy SafetyInterlockRequirement by SafetyInterlockSubsystem;
    satisfy BeamDeliveryRequirement by BeamDeliveryModule;
}