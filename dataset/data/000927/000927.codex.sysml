package PumpjackSystemModel {
    import ScalarValues::*;
    import ISQ::*;

    attribute def LengthValue :> ISQ::length {
        unit = SI::metre;
    }

    attribute def MassValue :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def PowerValue :> ISQ::power {
        unit = SI::watt;
    }

    attribute def ForceValue :> ISQ::force {
        unit = SI::newton;
    }

    attribute def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRateValue :> ISQ::volumeFlowRate {
        unit = SI::metreCubedPerSecond;
    }

    attribute def RotationalSpeedValue {
        :>> num : Real;
        unit = "rpm";
    }

    attribute def StrokeRateValue {
        :>> num : Real;
        unit = "strokes/min";
    }

    attribute def EfficiencyValue {
        :>> num : Real;
        unit = "%";
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    item def MechanicalTorque {
        attribute torque : Real;
        attribute rotationalSpeed : RotationalSpeedValue;
    }

    item def ReciprocatingMotion {
        attribute strokeLength : LengthValue;
        attribute strokeRate : StrokeRateValue;
        attribute polishedRodLoad : ForceValue;
    }

    item def CrudeOil {
        attribute density : Real;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute waterCut : EfficiencyValue;
    }

    item def ControlSignal {
        attribute command : String;
        attribute setpointStrokeRate : StrokeRateValue;
    }

    item def StatusSignal {
        attribute stateName : String;
        attribute motorRunning : Boolean;
        attribute faultPresent : Boolean;
        attribute measuredLoad : ForceValue;
        attribute measuredFlow : FlowRateValue;
    }

    port def ElectricalPowerIn {
        in item power : ElectricalPower;
    }

    port def TorqueOut {
        out item torque : MechanicalTorque;
    }

    port def TorqueIn {
        in item torque : MechanicalTorque;
    }

    port def MotionOut {
        out item motion : ReciprocatingMotion;
    }

    port def MotionIn {
        in item motion : ReciprocatingMotion;
    }

    port def FluidOut {
        out item fluid : CrudeOil;
    }

    port def ControlIn {
        in item control : ControlSignal;
    }

    port def StatusOut {
        out item status : StatusSignal;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue = 45000 [SI::watt];
        attribute nominalSpeed : RotationalSpeedValue = 1200;
        attribute efficiency : EfficiencyValue = 92;

        port electricalInput : ElectricalPowerIn;
        port shaftOutput : TorqueOut;

        action convertElectricalPowerToTorque {
            in item suppliedPower : ElectricalPower;
            out item producedTorque : MechanicalTorque;

            first startMotor;
            then stabilizeSpeed;
            then deliverTorque;

            action startMotor;
            action stabilizeSpeed;
            action deliverTorque;
        }
    }

    part def GearReducer {
        attribute gearRatio : Real = 30.0;
        attribute mechanicalEfficiency : EfficiencyValue = 94;

        port highSpeedInput : TorqueIn;
        port lowSpeedOutput : TorqueOut;

        action reduceSpeedIncreaseTorque {
            in item highSpeedTorque : MechanicalTorque;
            out item lowSpeedTorque : MechanicalTorque;

            first receiveMotorTorque;
            then reduceRotationalSpeed;
            then transmitOutputTorque;

            action receiveMotorTorque;
            action reduceRotationalSpeed;
            action transmitOutputTorque;
        }
    }

    part def CrankAndCounterweightAssembly {
        attribute crankRadius : LengthValue = 0.75 [SI::metre];
        attribute counterweightMass : MassValue = 2400 [SI::kilogram];

        port rotaryInput : TorqueIn;
        port oscillatingOutput : MotionOut;

        action transformRotationToOscillation {
            in item inputTorque : MechanicalTorque;
            out item outputMotion : ReciprocatingMotion;

            first rotateCrank;
            then balanceRodLoadWithCounterweights;
            then driveWalkingBeam;
        }

        action rotateCrank;
        action balanceRodLoadWithCounterweights;
        action driveWalkingBeam;
    }

    part def WalkingBeamAssembly {
        attribute beamLength : LengthValue = 7.5 [SI::metre];
        attribute structuralLoadLimit : ForceValue = 180000 [SI::newton];

        port beamInput : MotionIn;
        port polishedRodOutput : MotionOut;

        action amplifyAndTransferMotion {
            in item crankMotion : ReciprocatingMotion;
            out item rodMotion : ReciprocatingMotion;

            first receiveOscillation;
            then pivotAboutSampsonPost;
            then moveHorsehead;
        }

        action receiveOscillation;
        action pivotAboutSampsonPost;
        action moveHorsehead;
    }

    part def SuckerRodString {
        attribute totalLength : LengthValue = 1200 [SI::metre];
        attribute rodDiameter : LengthValue = 0.022 [SI::metre];
        attribute allowableTension : ForceValue = 140000 [SI::newton];

        port surfaceMotionInput : MotionIn;
        port downholeMotionOutput : MotionOut;

        action transmitReciprocatingMotionDownhole {
            in item surfaceMotion : ReciprocatingMotion;
            out item downholeMotion : ReciprocatingMotion;

            first tensionRods;
            then propagateStroke;
            then actuatePumpPlunger;
        }

        action tensionRods;
        action propagateStroke;
        action actuatePumpPlunger;
    }

    part def DownholePump {
        attribute pumpDepth : LengthValue = 1200 [SI::metre];
        attribute barrelDiameter : LengthValue = 0.057 [SI::metre];
        attribute designDischargePressure : PressureValue = 8500000 [SI::pascal];
        attribute nominalFlowRate : FlowRateValue = 0.0035 [SI::metreCubedPerSecond];

        port plungerMotionInput : MotionIn;
        port producedFluidOutput : FluidOut;

        action liftReservoirFluid {
            in item plungerMotion : ReciprocatingMotion;
            out item producedFluid : CrudeOil;

            first openStandingValve;
            then fillPumpBarrel;
            then closeStandingValve;
            then openTravelingValve;
            then displaceFluidUpTubing;
        }

        action openStandingValve;
        action fillPumpBarrel;
        action closeStandingValve;
        action openTravelingValve;
        action displaceFluidUpTubing;
    }

    part def ProductionTubing {
        attribute tubingLength : LengthValue = 1200 [SI::metre];
        attribute innerDiameter : LengthValue = 0.073 [SI::metre];
        attribute maximumWorkingPressure : PressureValue = 10000000 [SI::pascal];

        port downholeFluidInput : FluidOut;
        port surfaceFluidOutput : FluidOut;

        action conveyFluidToSurface {
            in item downholeFluid : CrudeOil;
            out item surfaceFluid : CrudeOil;

            first receivePumpedFluid;
            then transportThroughTubing;
            then dischargeAtWellhead;
        }

        action receivePumpedFluid;
        action transportThroughTubing;
        action dischargeAtWellhead;
    }

    part def Wellhead {
        attribute ratedPressure : PressureValue = 10000000 [SI::pascal];

        port productionInput : FluidOut;
        port productionOutput : FluidOut;

        action routeProducedFluid {
            in item liftedFluid : CrudeOil;
            out item exportedFluid : CrudeOil;

            first receiveFromTubing;
            then regulateFlow;
            then deliverToFlowline;
        }

        action receiveFromTubing;
        action regulateFlow;
        action deliverToFlowline;
    }

    part def PumpjackController {
        attribute commandedStrokeRate : StrokeRateValue = 8;
        attribute lowLoadTripLimit : ForceValue = 15000 [SI::newton];
        attribute highLoadTripLimit : ForceValue = 150000 [SI::newton];

        port operatorCommandInput : ControlIn;
        port motorCommandOutput : ControlIn;
        port systemStatusOutput : StatusOut;

        state def PumpjackControlStateMachine {
            state off;
            state starting;
            state pumping;
            state idle;
            state faulted;
            state stopping;

            entry action initializeController;
            then off;

            transition off_to_starting
                first off
                accept ControlSignal
                if control.command == "START"
                then starting;

            transition starting_to_pumping
                first starting
                if status.motorRunning == true
                then pumping;

            transition pumping_to_idle
                first pumping
                accept ControlSignal
                if control.command == "IDLE"
                then idle;

            transition idle_to_pumping
                first idle
                accept ControlSignal
                if control.command == "RESUME"
                then pumping;

            transition pumping_to_faulted
                first pumping
                if status.faultPresent == true
                then faulted;

            transition faulted_to_off
                first faulted
                accept ControlSignal
                if control.command == "RESET"
                then off;

            transition pumping_to_stopping
                first pumping
                accept ControlSignal
                if control.command == "STOP"
                then stopping;

            transition stopping_to_off
                first stopping
                then off;
        }

        action regulatePumpjackOperation {
            in item operatorCommand : ControlSignal;
            out item motorCommand : ControlSignal;
            out item status : StatusSignal;

            first readOperatorCommand;
            then evaluateLoadLimits;
            then computeStrokeRateCommand;
            then issueMotorCommand;
            then publishStatus;
        }

        action initializeController;
        action readOperatorCommand;
        action evaluateLoadLimits;
        action computeStrokeRateCommand;
        action issueMotorCommand;
        action publishStatus;
    }

    part def PumpjackSystem {
        attribute installedDepth : LengthValue = 1200 [SI::metre];
        attribute nominalStrokeLength : LengthValue = 1.5 [SI::metre];
        attribute nominalStrokeRate : StrokeRateValue = 8;
        attribute designFlowRate : FlowRateValue = 0.0035 [SI::metreCubedPerSecond];
        attribute primaryFunction : String = "Convert electrical energy into reciprocating mechanical motion to lift crude oil from a subsurface reservoir to the surface.";

        port electricalSupplyPort : ElectricalPowerIn;
        port operatorControlPort : ControlIn;
        port producedFluidPort : FluidOut;
        port statusPort : StatusOut;

        part motor : ElectricMotor;
        part reducer : GearReducer;
        part crankAssembly : CrankAndCounterweightAssembly;
        part walkingBeam : WalkingBeamAssembly;
        part rodString : SuckerRodString;
        part downholePump : DownholePump;
        part tubing : ProductionTubing;
        part wellhead : Wellhead;
        part controller : PumpjackController;

        connect electricalSupplyPort to motor.electricalInput;
        connect motor.shaftOutput to reducer.highSpeedInput;
        connect reducer.lowSpeedOutput to crankAssembly.rotaryInput;
        connect crankAssembly.oscillatingOutput to walkingBeam.beamInput;
        connect walkingBeam.polishedRodOutput to rodString.surfaceMotionInput;
        connect rodString.downholeMotionOutput to downholePump.plungerMotionInput;
        connect downholePump.producedFluidOutput to tubing.downholeFluidInput;
        connect tubing.surfaceFluidOutput to wellhead.productionInput;
        connect wellhead.productionOutput to producedFluidPort;
        connect operatorControlPort to controller.operatorCommandInput;
        connect controller.systemStatusOutput to statusPort;

        action performPrimaryFunction {
            in item electricalPower : ElectricalPower;
            in item operatorCommand : ControlSignal;
            out item producedOil : CrudeOil;
            out item operatingStatus : StatusSignal;

            first acceptElectricalPower;
            then regulatePumpjackOperation;
            then convertElectricalPowerToTorque;
            then reduceSpeedIncreaseTorque;
            then transformRotationToOscillation;
            then amplifyAndTransferMotion;
            then transmitReciprocatingMotionDownhole;
            then liftReservoirFluid;
            then conveyFluidToSurface;
            then routeProducedFluid;
            then reportOperatingStatus;
        }

        action acceptElectricalPower;
        action reportOperatingStatus;

        state def OperatingStateMachine {
            state shutdown;
            state ready;
            state startSequence;
            state normalPumping;
            state reducedRatePumping;
            state maintenanceLockout;
            state emergencyStop;

            entry action enterShutdown;
            then shutdown;

            transition shutdown_to_ready
                first shutdown
                accept ControlSignal
                if control.command == "POWER_AVAILABLE"
                then ready;

            transition ready_to_start
                first ready
                accept ControlSignal
                if control.command == "START"
                then startSequence;

            transition start_to_normal
                first startSequence
                then normalPumping;

            transition normal_to_reduced
                first normalPumping
                accept ControlSignal
                if control.command == "REDUCE_RATE"
                then reducedRatePumping;

            transition reduced_to_normal
                first reducedRatePumping
                accept ControlSignal
                if control.command == "NORMAL_RATE"
                then normalPumping;

            transition normal_to_emergency
                first normalPumping
                accept ControlSignal
                if control.command == "EMERGENCY_STOP"
                then emergencyStop;

            transition reduced_to_emergency
                first reducedRatePumping
                accept ControlSignal
                if control.command == "EMERGENCY_STOP"
                then emergencyStop;

            transition emergency_to_shutdown
                first emergencyStop
                accept ControlSignal
                if control.command == "RESET"
                then shutdown;

            transition ready_to_lockout
                first ready
                accept ControlSignal
                if control.command == "LOCKOUT"
                then maintenanceLockout;

            transition lockout_to_shutdown
                first maintenanceLockout
                accept ControlSignal
                if control.command == "UNLOCK"
                then shutdown;
        }

        action enterShutdown;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The pumpjack system shall lift crude oil from a subsurface reservoir to the surface by converting supplied electrical power into controlled reciprocating motion of a downhole pump. */

        subject pumpjack : PumpjackSystem;

        require constraint {
            pumpjack.designFlowRate >= 0.003 [SI::metreCubedPerSecond]
        }
    }

    requirement def StrokeRequirement {
        doc /* The pumpjack system shall provide a controlled reciprocating stroke suitable for downhole plunger pump operation. */

        subject pumpjack : PumpjackSystem;

        require constraint {
            pumpjack.nominalStrokeLength >= 1.0 [SI::metre] and
            pumpjack.nominalStrokeLength <= 2.0 [SI::metre]
        }
    }

    requirement def LoadProtectionRequirement {
        doc /* The pumpjack controller shall transition the system to a faulted or emergency stop condition when measured polished rod load exceeds configured limits. */

        subject controller : PumpjackController;

        require constraint {
            controller.highLoadTripLimit <= 150000 [SI::newton]
        }
    }

    requirement def SurfaceProductionRequirement {
        doc /* The pumpjack system shall discharge lifted crude oil through the wellhead production outlet for routing to the surface flowline. */

        subject pumpjack : PumpjackSystem;

        require constraint {
            pumpjack.producedFluidPort != null
        }
    }

    requirement def EnergyConversionRequirement {
        doc /* The pumpjack drive train shall transmit motor shaft torque through a gear reducer and crank assembly to create the walking beam motion used for pumping. */

        subject pumpjack : PumpjackSystem;

        require constraint {
            pumpjack.motor.ratedPower >= 30000 [SI::watt] and
            pumpjack.reducer.gearRatio >= 20.0
        }
    }

    satisfy PrimaryFunctionRequirement by PumpjackSystem::performPrimaryFunction;
    satisfy StrokeRequirement by PumpjackSystem::walkingBeam;
    satisfy LoadProtectionRequirement by PumpjackSystem::controller;
    satisfy SurfaceProductionRequirement by PumpjackSystem::wellhead;
    satisfy EnergyConversionRequirement by PumpjackSystem::motor;
}