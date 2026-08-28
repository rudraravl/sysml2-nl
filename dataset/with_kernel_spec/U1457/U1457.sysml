package 'Nutating Disc Engine System' {
    private import ISQ::*;
    private import ScalarValues::*;

    /* Value Types not available in ISQ */
    value type AngularSpeedValue :> Real { unit 'rad/s'; }
    value type AngleValue :> Real { unit 'rad'; }

    /* Item Types */
    item def PressurizedFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
    }

    item def ExhaustFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
    }

    /* Signal Types */
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def FaultDetected;
    attribute def FaultCleared;
    attribute def UpToSpeedSignal;
    attribute def DecelerationCompleteSignal;

    /* Port Definitions */
    port def FluidPort {
        in item pressurizedFluid : PressurizedFluid;
    }

    port def ExhaustFluidPort {
        out item exhaustFluid : ExhaustFluid;
    }

    port def MechanicalPort;

    /* Action Definitions */
    action def AdmitHighPressureFluid {
        in fluid : PressurizedFluid;
        out admittedFluid : PressurizedFluid;
    }

    action def NutateDisc {
        in fluid : PressurizedFluid;
        out wobbleMotion : TorqueValue;
        out exhaustFluid : ExhaustFluid;
    }

    action def ConvertNutationToRotation {
        in wobbleMotion : TorqueValue;
        out shaftTorque : TorqueValue;
        out shaftSpeed : AngularSpeedValue;
    }

    action def ExpelLowPressureFluid {
        in exhaustFluid : ExhaustFluid;
        out expelledFluid : ExhaustFluid;
    }

    action def GeneratePower {
        in intakeFluid : PressurizedFluid;
        out outputTorque : TorqueValue;
        out outputSpeed : AngularSpeedValue;
        out exhaustFluid : ExhaustFluid;

        perform action admit : AdmitHighPressureFluid {
            in fluid = intakeFluid;
        }
        then perform action nutate : NutateDisc {
            in fluid = admit.admittedFluid;
        }
        then perform action convert : ConvertNutationToRotation {
            in wobbleMotion = nutate.wobbleMotion;
        }
        perform action expel : ExpelLowPressureFluid {
            in exhaustFluid = nutate.exhaustFluid;
        }
        bind outputTorque = convert.shaftTorque;
        bind outputSpeed = convert.shaftSpeed;
        bind exhaustFluid = expel.expelledFluid;
    }

    /* Part Definitions */
    part def NutatingDisc {
        attribute diameter : LengthValue;
        attribute thickness : LengthValue;
        attribute currentWobbleAngle : AngleValue;
        port centralSupportInterface : MechanicalPort;
        port shaftInterface : MechanicalPort;
        perform action nutate : NutateDisc;
    }

    part def CentralSphereSupport {
        attribute radius : LengthValue;
        port discInterface : MechanicalPort;
    }

    part def EngineChamber {
        attribute volume : VolumeValue;
        port intakePort : FluidPort;
        port exhaustPort : ExhaustFluidPort;
        part disc : NutatingDisc;
        part sphereSupport : CentralSphereSupport;
        connect disc.centralSupportInterface to sphereSupport.discInterface;
    }

    part def IntakeValve {
        attribute isOpen : Boolean;
        port inlet : FluidPort;
        port outlet : FluidPort;
        perform action admit : AdmitHighPressureFluid;
    }

    part def ExhaustValve {
        attribute isOpen : Boolean;
        port inlet : ExhaustFluidPort;
        port outlet : ExhaustFluidPort;
        perform action expel : ExpelLowPressureFluid;
    }

    part def OutputShaft {
        attribute currentSpeed : AngularSpeedValue;
        attribute currentTorque : TorqueValue;
        port inputInterface : MechanicalPort;
        port powerOutput : MechanicalPort;
    }

    part def NutatingDiscEngine {
        attribute efficiency : Real;
        attribute nominalSpeed : AngularSpeedValue;
        attribute maxTorque : TorqueValue;

        port intakePort : FluidPort;
        port exhaustPort : ExhaustFluidPort;
        port powerPort : MechanicalPort;

        part chamber : EngineChamber;
        part intakeValve : IntakeValve;
        part exhaustValve : ExhaustValve;
        part outputShaft : OutputShaft;

        connection fluidIntakeConnection connect intakePort to intakeValve.inlet;
        connection fluidToChamberConnection connect intakeValve.outlet to chamber.intakePort;
        connection chamberToExhaustConnection connect chamber.exhaustPort to exhaustValve.inlet;
        connection fluidExhaustConnection connect exhaustValve.outlet to exhaustPort;
        connection discToShaftConnection connect chamber.disc.shaftInterface to outputShaft.inputInterface;
        connection powerConnection connect outputShaft.powerOutput to powerPort;

        perform action generatePower : GeneratePower;

        state engineLifecycle : EngineLifecycleStates;
    }

    /* State Machine */
    state def EngineLifecycleStates {
        entry; then idle;

        state idle {
            entry action { /* Engine at rest, valves closed */ }
        }

        transition idle_to_starting
            first idle
            accept StartCommand
            then starting;

        state starting {
            entry action { /* Open intake valve, begin fluid admission, disc begins nutating */ }
            do action { /* Ramp up disc wobble frequency, increase shaft speed */ }
        }

        transition starting_to_running
            first starting
            accept UpToSpeedSignal
            then running;

        transition starting_to_fault
            first starting
            accept FaultDetected
            then fault;

        state running {
            entry action { /* Steady-state operation: continuous fluid admission, nutation, exhaust */ }
            do action { /* Continuous power generation cycle */ }
        }

        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;

        transition running_to_fault
            first running
            accept FaultDetected
            then fault;

        state stopping {
            entry action { /* Close intake valve, allow residual pressure to dissipate */ }
            do action { /* Decelerate shaft, reduce wobble amplitude */ }
        }

        transition stopping_to_idle
            first stopping
            accept DecelerationCompleteSignal
            then idle;

        transition stopping_to_fault
            first stopping
            accept FaultDetected
            then fault;

        state fault {
            entry action { /* Close intake valve, emergency stop, log fault */ }
        }

        transition fault_to_idle
            first fault
            accept FaultCleared
            then idle;
    }

    /* Requirements */
    requirement def EfficiencyRequirement {
        doc /* The engine must achieve a minimum thermodynamic efficiency */
        subject engine : NutatingDiscEngine;
        attribute minEfficiency : Real = 0.75;
        constraint efficiencyConstraint { engine.efficiency >= minEfficiency }
    }

    requirement def TorqueRequirement {
        doc /* The engine must produce a minimum output torque at the shaft */
        subject shaft : OutputShaft;
        attribute minTorque : TorqueValue = 50.0;
        constraint torqueConstraint { shaft.currentTorque >= minTorque }
    }

    requirement def OperatingSpeedRequirement {
        doc /* The engine must operate within a specified rotational speed range */
        subject shaft : OutputShaft;
        attribute minSpeed : AngularSpeedValue = 100.0;
        attribute maxSpeed : AngularSpeedValue = 500.0;
        constraint speedConstraint { shaft.currentSpeed >= minSpeed and shaft.currentSpeed <= maxSpeed }
    }

    requirement def FluidPressureRequirement {
        doc /* The engine must accept pressurized fluid within a specified input range */
        subject intake : FluidPort;
        attribute minPressure : PressureValue = 200000.0;
        attribute maxPressure : PressureValue = 10000000.0;
        constraint pressureConstraint { intake.pressurizedFluid.pressure >= minPressure and intake.pressurizedFluid.pressure <= maxPressure }
    }

    requirement engineSpecification {
        doc /* Overall nutating disc engine performance requirements */
        subject engine : NutatingDiscEngine;
        requirement efficiencyReq : EfficiencyRequirement {
            subject = engine;
        }
        requirement torqueReq : TorqueRequirement {
            subject = engine.outputShaft;
        }
        requirement speedReq : OperatingSpeedRequirement {
            subject = engine.outputShaft;
        }
        requirement pressureReq : FluidPressureRequirement {
            subject = engine.intakePort;
        }
    }
}
