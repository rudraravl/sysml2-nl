package PlungerPumpingSubsystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def RotationalSpeed :> ISQ::angularVelocity {
        unit = SI::radianPerSecond;
    }

    attribute def LinearPosition :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Efficiency :> ScalarValues::Real;

    item def WorkingFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute density : Real;
        attribute dynamicViscosity : Real;
        attribute contaminationIndex : Real;
    }

    item def MechanicalPower {
        attribute shaftSpeed : RotationalSpeed;
        attribute torque : Real;
        attribute power : Power;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute commandValue : Real;
        attribute valid : Boolean;
        attribute timestamp : Real;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute timestamp : Real;
    }

    port def FluidInletPort {
        in item fluidIn : WorkingFluid;
    }

    port def FluidOutletPort {
        out item fluidOut : WorkingFluid;
    }

    port def FluidBidirectionalPort {
        inout item fluid : WorkingFluid;
    }

    port def ElectricalPowerPort {
        in item electricalPower : ElectricalPower;
    }

    port def MechanicalPowerPort {
        inout item mechanicalPower : MechanicalPower;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def SensorOutputPort {
        out item signal : SensorSignal;
    }

    port def ReliefDischargePort {
        out item relievedFluid : WorkingFluid;
    }

    part def PlungerPump {
        attribute boreDiameter : ISQ::length = 0.032 [SI::metre];
        attribute strokeLength : ISQ::length = 0.075 [SI::metre];
        attribute numberOfPlungers : Integer = 3;
        attribute volumetricEfficiency : Efficiency = 0.91;
        attribute mechanicalEfficiency : Efficiency = 0.86;
        attribute ratedDischargePressure : Pressure = 25000000 [SI::pascal];
        attribute maximumDischargePressure : Pressure = 30000000 [SI::pascal];
        attribute minimumInletPressure : Pressure = 150000 [SI::pascal];
        attribute ratedFlowRate : FlowRate = 0.0018 [SI::cubicMetrePerSecond];
        attribute plungerPosition : LinearPosition;
        attribute chamberPressure : Pressure;
        attribute hydraulicPower : Power;
        attribute drivePowerRequired : Power;

        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port shaft : MechanicalPowerPort;
        port speedCommand : ControlInputPort;
        port pressureFeedback : SensorOutputPort;

        part crankshaft {
            attribute angularSpeed : RotationalSpeed;
            attribute crankRadius : ISQ::length = 0.0375 [SI::metre];
            attribute torqueLimit : Real = 420.0;
        }

        part crosshead {
            attribute axialForce : Force;
            attribute guideWearIndex : Real;
        }

        part plungerAssembly {
            attribute plungerDiameter : ISQ::length = 0.032 [SI::metre];
            attribute sealLeakageRate : FlowRate = 0.00002 [SI::cubicMetrePerSecond];
            attribute sealTemperature : Temperature;
            attribute reciprocatingForce : Force;
        }

        part suctionCheckValve {
            attribute crackingPressure : Pressure = 20000 [SI::pascal];
            attribute open : Boolean;
            attribute reverseLeakageRate : FlowRate = 0.0 [SI::cubicMetrePerSecond];
            port upstream : FluidInletPort;
            port downstream : FluidOutletPort;
        }

        part dischargeCheckValve {
            attribute crackingPressure : Pressure = 50000 [SI::pascal];
            attribute open : Boolean;
            attribute reverseLeakageRate : FlowRate = 0.0 [SI::cubicMetrePerSecond];
            port upstream : FluidInletPort;
            port downstream : FluidOutletPort;
        }

        part compressionChamber {
            attribute sweptVolume : Volume = 0.0000603 [SI::cubicMetre];
            attribute clearanceVolume : Volume = 0.0000045 [SI::cubicMetre];
            attribute instantaneousVolume : Volume;
            attribute pressure : Pressure;
            port inlet : FluidInletPort;
            port outlet : FluidOutletPort;
        }

        connect suction to suctionCheckValve.upstream;
        connect suctionCheckValve.downstream to compressionChamber.inlet;
        connect compressionChamber.outlet to dischargeCheckValve.upstream;
        connect dischargeCheckValve.downstream to discharge;
        connect shaft to crankshaft;
        connect crankshaft to crosshead;
        connect crosshead to plungerAssembly;

        action def IntakeStroke {
            in item inletFluid : WorkingFluid;
            out item chamberFluid : WorkingFluid;
            attribute suctionValveOpen : Boolean = true;
            attribute dischargeValveOpen : Boolean = false;
        }

        action def CompressionStroke {
            in item chamberFluid : WorkingFluid;
            out item pressurizedFluid : WorkingFluid;
            attribute plungerForce : Force;
            attribute targetPressure : Pressure;
        }

        action def DischargeStroke {
            in item pressurizedFluid : WorkingFluid;
            out item outletFluid : WorkingFluid;
            attribute suctionValveOpen : Boolean = false;
            attribute dischargeValveOpen : Boolean = true;
        }

        action pumpCycle {
            first start;
            then intake : IntakeStroke;
            then compression : CompressionStroke;
            then dischargeAction : DischargeStroke;
            then done;
        }

        state def PumpOperatingState {
            entry;
            state Stopped;
            state Priming;
            state Running;
            state LowSuctionPressure;
            state OverPressureTrip;
            state SealLeakageFault;
            state Shutdown;

            transition initial then Stopped;
            transition Stopped_to_Priming
                first Stopped
                accept ControlSignal
                if command.commandValue > 0.1
                then Priming;

            transition Priming_to_Running
                first Priming
                if chamberPressure > minimumInletPressure
                then Running;

            transition Running_to_LowSuctionPressure
                first Running
                if suction.fluidIn.pressure < minimumInletPressure
                then LowSuctionPressure;

            transition LowSuctionPressure_to_Running
                first LowSuctionPressure
                if suction.fluidIn.pressure >= minimumInletPressure
                then Running;

            transition Running_to_OverPressureTrip
                first Running
                if discharge.fluidOut.pressure > maximumDischargePressure
                then OverPressureTrip;

            transition Running_to_SealLeakageFault
                first Running
                if plungerAssembly.sealLeakageRate > 0.00008 [SI::cubicMetrePerSecond]
                then SealLeakageFault;

            transition Fault_to_Shutdown
                first OverPressureTrip
                then Shutdown;

            transition LeakageFault_to_Shutdown
                first SealLeakageFault
                then Shutdown;

            transition Shutdown_to_Stopped
                first Shutdown
                accept ControlSignal
                if command.commandValue == 0.0
                then Stopped;
        }

        exhibit stateMachine : PumpOperatingState;
    }

    part def ElectricMotorDrive {
        attribute ratedPower : Power = 75000 [SI::watt];
        attribute ratedSpeed : RotationalSpeed = 188.5 [SI::radianPerSecond];
        attribute driveEfficiency : Efficiency = 0.94;
        attribute commandedSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        attribute outputTorque : Real;

        port electricalInput : ElectricalPowerPort;
        port controlInput : ControlInputPort;
        port shaftOutput : MechanicalPowerPort;
        port speedFeedback : SensorOutputPort;

        action def ConvertElectricalToMechanicalPower {
            in item supply : ElectricalPower;
            out item shaftPower : MechanicalPower;
            attribute conversionEfficiency : Efficiency;
        }

        action operateDrive {
            first receivePower;
            then convert : ConvertElectricalToMechanicalPower;
            then deliverTorque;
            then reportSpeed;
        }
    }

    part def SuctionManifold {
        attribute internalVolume : Volume = 0.012 [SI::cubicMetre];
        attribute allowablePressureDrop : Pressure = 25000 [SI::pascal];
        attribute trappedAirFraction : Real;
        port sourceConnection : FluidInletPort;
        port pumpConnection : FluidOutletPort;
        port drainConnection : FluidOutletPort;
    }

    part def DischargeManifold {
        attribute internalVolume : Volume = 0.009 [SI::cubicMetre];
        attribute ratedPressure : Pressure = 30000000 [SI::pascal];
        attribute pulsationAmplitude : Pressure;
        port pumpConnection : FluidInletPort;
        port processConnection : FluidOutletPort;
        port reliefConnection : FluidOutletPort;
    }

    part def PulsationDampener {
        attribute gasPrechargePressure : Pressure = 12000000 [SI::pascal];
        attribute shellRatedPressure : Pressure = 32000000 [SI::pascal];
        attribute gasVolume : Volume = 0.006 [SI::cubicMetre];
        attribute dampingRatio : Real = 0.72;
        port fluidConnection : FluidBidirectionalPort;
    }

    part def PressureReliefValve {
        attribute setPressure : Pressure = 28000000 [SI::pascal];
        attribute reseatPressure : Pressure = 24000000 [SI::pascal];
        attribute ratedReliefFlow : FlowRate = 0.0025 [SI::cubicMetrePerSecond];
        attribute open : Boolean;
        port inlet : FluidInletPort;
        port discharge : ReliefDischargePort;

        state def ReliefValveState {
            state Closed;
            state Opening;
            state Open;
            state Reseating;

            transition initial then Closed;
            transition Closed_to_Opening
                first Closed
                if inlet.fluidIn.pressure >= setPressure
                then Opening;

            transition Opening_to_Open
                first Opening
                then Open;

            transition Open_to_Reseating
                first Open
                if inlet.fluidIn.pressure <= reseatPressure
                then Reseating;

            transition Reseating_to_Closed
                first Reseating
                then Closed;
        }

        exhibit stateMachine : ReliefValveState;
    }

    part def InstrumentationPackage {
        part suctionPressureTransmitter {
            attribute rangeMinimum : Pressure = 0 [SI::pascal];
            attribute rangeMaximum : Pressure = 1000000 [SI::pascal];
            attribute accuracyPercentSpan : Real = 0.25;
            port processPort : FluidBidirectionalPort;
            port signalPort : SensorOutputPort;
        }

        part dischargePressureTransmitter {
            attribute rangeMinimum : Pressure = 0 [SI::pascal];
            attribute rangeMaximum : Pressure = 35000000 [SI::pascal];
            attribute accuracyPercentSpan : Real = 0.20;
            port processPort : FluidBidirectionalPort;
            port signalPort : SensorOutputPort;
        }

        part flowMeter {
            attribute rangeMaximum : FlowRate = 0.003 [SI::cubicMetrePerSecond];
            attribute accuracyPercentReading : Real = 0.5;
            port processPort : FluidBidirectionalPort;
            port signalPort : SensorOutputPort;
        }

        part temperatureElement {
            attribute rangeMinimum : Temperature = 273.15 [SI::kelvin];
            attribute rangeMaximum : Temperature = 373.15 [SI::kelvin];
            port processPort : FluidBidirectionalPort;
            port signalPort : SensorOutputPort;
        }
    }

    part def PumpController {
        attribute requestedFlowRate : FlowRate;
        attribute measuredFlowRate : FlowRate;
        attribute measuredSuctionPressure : Pressure;
        attribute measuredDischargePressure : Pressure;
        attribute speedSetpoint : RotationalSpeed;
        attribute tripActive : Boolean;
        attribute alarmActive : Boolean;

        port operatorCommand : ControlInputPort;
        port suctionPressureInput : ControlInputPort;
        port dischargePressureInput : ControlInputPort;
        port flowInput : ControlInputPort;
        port motorSpeedCommand : ControlInputPort;
        port pumpCommand : ControlInputPort;

        action def CalculateSpeedSetpoint {
            in item requested : ControlSignal;
            in item measuredFlow : SensorSignal;
            out item speedCommand : ControlSignal;
            attribute proportionalGain : Real = 120.0;
            attribute integralGain : Real = 12.0;
        }

        action def EvaluateProtection {
            in item suctionPressure : SensorSignal;
            in item dischargePressure : SensorSignal;
            out item tripCommand : ControlSignal;
            attribute lowSuctionLimit : Pressure = 150000 [SI::pascal];
            attribute highDischargeLimit : Pressure = 30000000 [SI::pascal];
        }

        action controlLoop {
            first sampleInputs;
            then evaluate : EvaluateProtection;
            then calculate : CalculateSpeedSetpoint;
            then issueCommands;
        }

        state def ControllerMode {
            state Idle;
            state StartPermissiveCheck;
            state AutomaticFlowControl;
            state ManualSpeedControl;
            state Tripped;

            transition initial then Idle;
            transition Idle_to_StartPermissiveCheck
                first Idle
                accept ControlSignal
                if command.commandValue > 0.0
                then StartPermissiveCheck;

            transition StartPermissiveCheck_to_AutomaticFlowControl
                first StartPermissiveCheck
                if measuredSuctionPressure >= 150000 [SI::pascal]
                then AutomaticFlowControl;

            transition AutomaticFlowControl_to_Tripped
                first AutomaticFlowControl
                if measuredDischargePressure > 30000000 [SI::pascal]
                then Tripped;

            transition ManualSpeedControl_to_Tripped
                first ManualSpeedControl
                if measuredSuctionPressure < 120000 [SI::pascal]
                then Tripped;

            transition Tripped_to_Idle
                first Tripped
                accept ControlSignal
                if command.commandValue == 0.0
                then Idle;
        }

        exhibit stateMachine : ControllerMode;
    }

    part def PlungerPumpingSubsystem {
        attribute designFlowRate : FlowRate = 0.0018 [SI::cubicMetrePerSecond];
        attribute normalDischargePressure : Pressure = 22000000 [SI::pascal];
        attribute maximumAllowableWorkingPressure : Pressure = 30000000 [SI::pascal];
        attribute minimumNetPositiveSuctionPressure : Pressure = 150000 [SI::pascal];
        attribute operatingTemperatureMinimum : Temperature = 278.15 [SI::kelvin];
        attribute operatingTemperatureMaximum : Temperature = 333.15 [SI::kelvin];
        attribute totalHydraulicEfficiency : Efficiency;
        attribute availabilityTarget : Real = 0.98;

        port fluidSource : FluidInletPort;
        port pressurizedFluidDelivery : FluidOutletPort;
        port reliefReturn : ReliefDischargePort;
        port electricalSupply : ElectricalPowerPort;
        port operatorCommand : ControlInputPort;

        part suctionManifold : SuctionManifold;
        part motorDrive : ElectricMotorDrive;
        part pump : PlungerPump;
        part dischargeManifold : DischargeManifold;
        part dampener : PulsationDampener;
        part reliefValve : PressureReliefValve;
        part instruments : InstrumentationPackage;
        part controller : PumpController;

        connect fluidSource to suctionManifold.sourceConnection;
        connect suctionManifold.pumpConnection to pump.suction;
        connect motorDrive.shaftOutput to pump.shaft;
        connect pump.discharge to dischargeManifold.pumpConnection;
        connect dischargeManifold.processConnection to pressurizedFluidDelivery;
        connect dischargeManifold.reliefConnection to reliefValve.inlet;
        connect reliefValve.discharge to reliefReturn;
        connect dischargeManifold.processConnection to dampener.fluidConnection;
        connect electricalSupply to motorDrive.electricalInput;
        connect operatorCommand to controller.operatorCommand;
        connect controller.motorSpeedCommand to motorDrive.controlInput;
        connect controller.pumpCommand to pump.speedCommand;
        connect suctionManifold.pumpConnection to instruments.suctionPressureTransmitter.processPort;
        connect dischargeManifold.processConnection to instruments.dischargePressureTransmitter.processPort;
        connect dischargeManifold.processConnection to instruments.flowMeter.processPort;
        connect pump.discharge to instruments.temperatureElement.processPort;
        connect instruments.suctionPressureTransmitter.signalPort to controller.suctionPressureInput;
        connect instruments.dischargePressureTransmitter.signalPort to controller.dischargePressureInput;
        connect instruments.flowMeter.signalPort to controller.flowInput;

        constraint def FlowContinuity {
            in inletFlow : FlowRate;
            in outletFlow : FlowRate;
            in leakageFlow : FlowRate;
            inletFlow = outletFlow + leakageFlow;
        }

        constraint def PressureProtection {
            in measuredPressure : Pressure;
            in allowablePressure : Pressure;
            measuredPressure <= allowablePressure;
        }

        constraint def PumpHydraulicPower {
            in dischargePressure : Pressure;
            in suctionPressure : Pressure;
            in flowRate : FlowRate;
            out hydraulicPower : Power;
            hydraulicPower = (dischargePressure - suctionPressure) * flowRate;
        }

        constraint def RequiredDrivePower {
            in hydraulicPower : Power;
            in volumetricEfficiency : Efficiency;
            in mechanicalEfficiency : Efficiency;
            out requiredPower : Power;
            requiredPower = hydraulicPower / (volumetricEfficiency * mechanicalEfficiency);
        }

        satisfy flowRequirement by pump;
        satisfy pressureRequirement by pump;
        satisfy protectionRequirement by reliefValve;
        satisfy controlRequirement by controller;
        satisfy instrumentationRequirement by instruments;
    }

    requirement flowRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The pumping subsystem shall deliver working fluid at a nominal flow rate of 0.0018 cubic metre per second during continuous operation.";
        require constraint {
            subsystem.pressurizedFluidDelivery.fluidOut.flowRate >= 0.0017 [SI::cubicMetrePerSecond] and
            subsystem.pressurizedFluidDelivery.fluidOut.flowRate <= 0.0019 [SI::cubicMetrePerSecond]
        }
    }

    requirement pressureRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The plunger pump shall raise fluid pressure to the normal discharge pressure without exceeding the maximum allowable working pressure.";
        require constraint {
            subsystem.pressurizedFluidDelivery.fluidOut.pressure >= 22000000 [SI::pascal] and
            subsystem.pressurizedFluidDelivery.fluidOut.pressure <= 30000000 [SI::pascal]
        }
    }

    requirement suctionRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The subsystem shall inhibit continuous pumping when suction pressure is below the minimum net positive suction pressure.";
        require constraint {
            subsystem.suctionManifold.pumpConnection.fluidOut.pressure >= subsystem.minimumNetPositiveSuctionPressure
        }
    }

    requirement protectionRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The subsystem shall open a relief path when discharge pressure reaches 28 MPa and shall prevent operation above 30 MPa.";
        require constraint {
            subsystem.reliefValve.setPressure == 28000000 [SI::pascal] and
            subsystem.maximumAllowableWorkingPressure == 30000000 [SI::pascal]
        }
    }

    requirement pulsationRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The subsystem shall limit discharge pressure pulsation using a dampener connected to the discharge manifold.";
        require constraint {
            subsystem.dischargeManifold.pulsationAmplitude <= 1500000 [SI::pascal]
        }
    }

    requirement controlRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The controller shall regulate motor speed to maintain requested flow and shall trip the pump on low suction pressure or high discharge pressure.";
        require constraint {
            subsystem.controller.tripActive == true implies
            subsystem.motorDrive.commandedSpeed == 0 [SI::radianPerSecond]
        }
    }

    requirement instrumentationRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The subsystem shall measure suction pressure, discharge pressure, discharge flow rate, and discharge temperature.";
        require constraint {
            subsystem.instruments.suctionPressureTransmitter.rangeMaximum >= 1000000 [SI::pascal] and
            subsystem.instruments.dischargePressureTransmitter.rangeMaximum >= 35000000 [SI::pascal] and
            subsystem.instruments.flowMeter.rangeMaximum >= 0.003 [SI::cubicMetrePerSecond]
        }
    }

    requirement efficiencyRequirement {
        subject subsystem : PlungerPumpingSubsystem;
        text = "The subsystem shall maintain total hydraulic efficiency greater than 0.75 at rated operating conditions.";
        require constraint {
            subsystem.totalHydraulicEfficiency >= 0.75
        }
    }
}