package NutatingDiscEngine {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def PressureValue :> Real { unit 'Pa'; }
    value def TorqueValue :> Real { unit 'N*m'; }
    value def AngularSpeedValue :> Real { unit 'rad/s'; }
    value def RotationalSpeedValue :> Real { unit 'rpm'; }
    value def EfficiencyValue :> Real; // dimensionless fraction
    value def VolumetricFlowRateValue :> Real { unit 'm^3/s'; }
    value def TemperatureValue :> Real { unit 'K'; }
    value def AngleValue :> Real { unit 'rad'; }
    value def PowerValue :> Real { unit 'W'; }
    value def MassValue :> Real { unit 'kg'; }
    value def LengthValue :> Real { unit 'm'; }
    value def VolumeValue :> Real { unit 'm^3'; }
    value def ForceValue :> Real { unit 'N'; }

    // ---- Item types ----
    item def PressurizedFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumetricFlowRateValue;
    }

    item def ExhaustFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumetricFlowRateValue;
    }

    // ---- Port definitions ----
    port def FluidInPort {
        in item inflow : PressurizedFluid;
    }

    port def FluidOutPort {
        out item outflow : ExhaustFluid;
    }

    port def MechanicalPowerPort {
        out torque : TorqueValue;
        out speed : AngularSpeedValue;
    }

    port def MechanicalInterfacePort {
        in force : ForceValue;
        out torque : TorqueValue;
        out speed : AngularSpeedValue;
    }

    // ---- Requirements ----
    requirement def EfficiencyRequirement {
        subject engine : NutatingDiscEngine;
        attribute minEfficiency : EfficiencyValue = 0.85;
        objective {
            doc /* The engine shall achieve at least the specified minimum efficiency at rated operating conditions. */
        }
        require engine.efficiency >= minEfficiency;
    }

    requirement def TorqueRequirement {
        subject engine : NutatingDiscEngine;
        attribute minTorque : TorqueValue = 50.0;
        objective {
            doc /* The engine shall deliver at least the specified minimum torque at rated speed. */
        }
        require engine.outputTorque >= minTorque;
    }

    requirement def OperatingSpeedRequirement {
        subject engine : NutatingDiscEngine;
        attribute ratedSpeed : RotationalSpeedValue = 3000.0;
        attribute maxSpeed : RotationalSpeedValue = 4500.0;
        objective {
            doc /* The engine shall operate continuously at rated speed without exceeding maximum speed. */
        }
        require engine.outputSpeed <= maxSpeed;
        require engine.outputSpeed >= ratedSpeed when engine.operationalState == 'running';
    }

    // ---- Component parts ----
    part def CentralSphereSupport {
        attribute mass : MassValue = 0.5;
        attribute radius : LengthValue = 0.02;
        attribute maxLoad : ForceValue = 5000.0;
        port mechanicalInterface : MechanicalInterfacePort;
    }

    part def NutatingDisc {
        attribute mass : MassValue = 1.2;
        attribute radius : LengthValue = 0.08;
        attribute thickness : LengthValue = 0.01;
        attribute tiltAngle : AngleValue = 0.087; // ~5 degrees
        attribute nutationAngle : AngleValue;
        attribute nutationRate : AngularSpeedValue;

        port supportInterface : MechanicalInterfacePort;
        port shaftInterface : MechanicalInterfacePort;
        port chamberInterface;

        action wobble : WobbleAction;

        action def WobbleAction {
            in appliedPressure : PressureValue;
            in discArea : AreaValue;
            out nutationRate : AngularSpeedValue;
            out transmittedTorque : TorqueValue;
        }
    }

    part def Chamber {
        attribute volume : VolumeValue = 0.0005;
        attribute highPressureSidePressure : PressureValue;
        attribute lowPressureSidePressure : PressureValue;
        attribute partitionAngle : AngleValue;

        port intakeConnection : FluidInPort;
        port exhaustConnection : FluidOutPort;
        port discInterface;
    }

    part def IntakeValve {
        attribute openFraction : Real = 0.0; // 0.0 closed, 1.0 fully open
        attribute maxFlowRate : VolumetricFlowRateValue = 0.01;
        attribute commandSignal : Real;

        port inlet : FluidInPort;
        port outlet : FluidInPort;

        action modulate : ModulateAction;

        action def ModulateAction {
            in command : Real;
            out openFraction : Real;
        }
    }

    part def ExhaustValve {
        attribute openFraction : Real = 0.0;
        attribute maxFlowRate : VolumetricFlowRateValue = 0.01;
        attribute commandSignal : Real;

        port inlet : FluidOutPort;
        port outlet : FluidOutPort;

        action modulate : ModulateAction;
    }

    part def OutputShaft {
        attribute length : LengthValue = 0.25;
        attribute diameter : LengthValue = 0.03;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : AngularSpeedValue;
        attribute inertia : Real { unit 'kg*m^2'; } = 0.005;

        port mechanicalInput : MechanicalInterfacePort;
        port mechanicalOutput : MechanicalPowerPort;
    }

    part def Controller {
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute resetCommand : Boolean = false;
        attribute ratedSpeed : RotationalSpeedValue = 3000.0;

        port commandPort;
        port feedbackPort;

        action monitor : MonitorAction;

        action def MonitorAction {
            in currentSpeed : RotationalSpeedValue;
            in currentTorque : TorqueValue;
            out intakeValveCommand : Real;
            out exhaustValveCommand : Real;
        }
    }

    // ---- Top-level engine ----
    part def NutatingDiscEngine {
        attribute efficiency : EfficiencyValue;
        attribute outputTorque : TorqueValue;
        attribute outputSpeed : RotationalSpeedValue;
        attribute operationalState : String = 'idle';
        attribute ratedPressure : PressureValue = 600000.0;
        attribute exhaustPressure : PressureValue = 101325.0;

        port fluidIntake : FluidInPort;
        port fluidExhaust : FluidOutPort;
        port powerOutput : MechanicalPowerPort;

        part centralSupport : CentralSphereSupport;
        part disc : NutatingDisc;
        part chamber : Chamber;
        part intakeValve : IntakeValve;
        part exhaustValve : ExhaustValve;
        part outputShaft : OutputShaft;
        part controller : Controller;

        // External fluid connections
        connection fluidInPath connect fluidIntake to intakeValve.inlet;
        connection fluidInToChamber connect intakeValve.outlet to chamber.intakeConnection;
        connection fluidOutFromChamber connect chamber.exhaustConnection to exhaustValve.inlet;
        connection fluidOutPath connect exhaustValve.outlet to fluidExhaust;

        // Mechanical connections
        connection discSupport connect disc.supportInterface to centralSupport.mechanicalInterface;
        connection discToShaft connect disc.shaftInterface to outputShaft.mechanicalInput;
        connection shaftOutput connect outputShaft.mechanicalOutput to powerOutput;

        // Disc-chamber interaction
        connection discChamber connect disc.chamberInterface to chamber.discInterface;

        // Controller connections
        connection controllerCommand connect controller.commandPort to intakeValve.commandSignal;
        connection controllerFeedback connect outputShaft.mechanicalOutput to controller.feedbackPort;

        // Requirement satisfaction
        satisfy efficiencyReq : EfficiencyRequirement;
        satisfy torqueReq : TorqueRequirement;
        satisfy speedReq : OperatingSpeedRequirement;

        // Operational state machine
        state def EngineStates {
            state idle;
            state starting;
            state running;
            state stopping;
            state fault;

            transition idle_to_starting
                first idle then starting
                when controller.startCommand == true;

            transition starting_to_running
                first starting then running
                when outputSpeed >= controller.ratedSpeed;

            transition running_to_stopping
                first running then stopping
                when controller.stopCommand == true;

            transition stopping_to_idle
                first stopping then idle
                when outputSpeed == 0.0;

            transition idle_to_fault
                first idle then fault
                when controller.faultDetected == true;

            transition starting_to_fault
                first starting then fault
                when controller.faultDetected == true;

            transition running_to_fault
                first running then fault
                when controller.faultDetected == true;

            transition stopping_to_fault
                first stopping then fault
                when controller.faultDetected == true;

            transition fault_to_idle
                first fault then idle
                when controller.resetCommand == true;
        }

        exhibit EngineStates {
            // Entry actions update operationalState attribute
            entry idle action { operationalState = 'idle'; }
            entry starting action { operationalState = 'starting'; }
            entry running action { operationalState = 'running'; }
            entry stopping action { operationalState = 'stopping'; }
            entry fault action { operationalState = 'fault'; }
        }

        // Continuous operating behavior
        action def OperatingCycle {
            in highPressureFluid : PressurizedFluid;
            out mechanicalPower : PowerValue;
            out exhaustFluid : ExhaustFluid;

            action admitFluid {
                in fluid : PressurizedFluid;
                out admittedFluid : PressurizedFluid;
            }
            action wobbleDisc {
                in fluid : PressurizedFluid;
                out nutationRate : AngularSpeedValue;
                out transmittedTorque : TorqueValue;
            }
            action rotateShaft {
                in torque : TorqueValue;
                out speed : AngularSpeedValue;
                out power : PowerValue;
            }
            action expelFluid {
                in usedFluid : ExhaustFluid;
                out expelledFluid : ExhaustFluid;
            }

            flow admitFluid.admittedFluid to wobbleDisc.fluid;
            flow wobbleDisc.transmittedTorque to rotateShaft.torque;
            flow wobbleDisc.nutationRate to expelFluid; // disc motion partitions chamber
        }

        perform operatingCycle : OperatingCycle;
    }
}
