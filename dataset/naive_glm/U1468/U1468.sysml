package HydraulicPistonActuationSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit 'Pa'; }
    value type FlowRateValue :> Real { unit 'm3/s'; }
    value type ForceValue :> Real { unit 'N'; }
    value type LengthValue :> Real { unit 'm'; }
    value type VelocityValue :> Real { unit 'm/s'; }
    value type AreaValue :> Real { unit 'm2'; }
    value type VolumeValue :> Real { unit 'm3'; }
    value type MassValue :> Real { unit 'kg'; }
    value type DurationValue :> Real { unit 's'; }

    // ===== Item Types =====
    item def HydraulicFluid {
        attribute density : MassValue = 850;
        attribute bulkModulus : PressureValue = 1.6e9;
    }

    item def PressurizedFluid :> HydraulicFluid {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def ReturnFluid :> HydraulicFluid {
        attribute pressure : PressureValue = 0;
    }

    item def CommandSignal {
        attribute targetPosition : ValvePosition;
        attribute priority : Integer = 1;
    }

    // ===== Enumerations =====
    enum ValvePosition { extend; retract; hold; }
    enum SystemState { idle; extending; retracting; holding; faulted; }
    enum PumpStatus { off; running; faulted; }

    // ===== Port Definitions =====
    port def FluidSupplyPort {
        out item pressurizedFluid : PressurizedFluid;
        in item returnFluid : ReturnFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def FluidControlPort {
        in item pressurizedFluid : PressurizedFluid;
        out item returnFluid : ReturnFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def CommandPort {
        in item command : CommandSignal;
        attribute currentPosition : ValvePosition;
    }

    port def MechanicalLoadPort {
        attribute appliedForce : ForceValue;
        attribute position : LengthValue;
        attribute velocity : VelocityValue;
    }

    // ===== Requirements =====
    requirement def ActuationSystemRequirements {
        subject system : HydraulicPistonActuationSystem;

        attribute maxOperatingPressure : PressureValue = 21e6;
        attribute maxOutputForce : ForceValue = 150000;
        attribute maxStrokeLength : LengthValue = 0.8;
        attribute maxExtensionVelocity : VelocityValue = 0.5;
        attribute maxRetractionVelocity : VelocityValue = 0.6;

        requirement PressureCapacity {
            subject pump : HydraulicPowerUnit;
            doc /* The power unit shall supply fluid at pressures up to the maximum operating pressure. */
            require pump.supplyPressure <= system.maxOperatingPressure;
        }

        requirement ForceGeneration {
            subject actuator : PistonActuator;
            doc /* The actuator shall generate output force sufficient for industrial loads. */
            require actuator.outputForce <= system.maxOutputForce;
        }

        requirement StrokeRange {
            subject actuator : PistonActuator;
            doc /* The actuator shall operate within the specified stroke range. */
            require actuator.currentStroke >= 0 and actuator.currentStroke <= system.maxStrokeLength;
        }

        requirement LeakIntegrity {
            subject seals : Seal;
            doc /* Seals shall prevent fluid leakage under maximum operating pressure. */
            require seals.ratedPressure >= system.maxOperatingPressure;
        }

        requirement ResponseTime {
            subject valve : ControlValve;
            attribute maxResponseTime : DurationValue = 0.05;
            doc /* The control valve shall transition between positions within the specified response time. */
            require valve.responseTime <= maxResponseTime;
        }
    }

    // ===== Sub-Components =====
    part def Pump {
        attribute displacement : VolumeValue = 5e-5;
        attribute ratedSpeed : Real = 1800;
        attribute efficiency : Real = 0.92;
        attribute status : PumpStatus = PumpStatus::off;
        port fluidIn : FluidControlPort;
        port fluidOut : FluidSupplyPort;

        action def generateFlow {
            in command : Boolean;
            out fluid : PressurizedFluid;
            attribute generatedPressure : PressureValue;
            attribute generatedFlow : FlowRateValue;
        }

        perform generateFlow when status == PumpStatus::running;
    }

    part def Reservoir {
        attribute capacity : VolumeValue = 0.04;
        attribute currentLevel : VolumeValue = 0.035;
        attribute fluid : HydraulicFluid;
        port fluidReturn : FluidControlPort;
    }

    part def ReliefValve {
        attribute setPressure : PressureValue = 21e6;
        attribute crackingPressure : PressureValue = 20.5e6;
        port inlet : FluidControlPort;
        port outlet : FluidControlPort;
    }

    part def CylinderBody {
        attribute boreDiameter : LengthValue = 0.1;
        attribute boreArea : AreaValue = 0.007854;
        attribute length : LengthValue = 0.9;
        attribute wallThickness : LengthValue = 0.012;
        attribute material : String = "Hardened Steel";
        port extendChamberPort : FluidControlPort;
        port retractChamberPort : FluidControlPort;
    }

    part def PistonHead {
        attribute diameter : LengthValue = 0.0995;
        attribute effectiveArea : AreaValue = 0.00778;
        attribute thickness : LengthValue = 0.04;
        attribute material : String = "Aluminum Alloy";
    }

    part def PistonRod {
        attribute diameter : LengthValue = 0.04;
        attribute rodArea : AreaValue = 0.001257;
        attribute length : LengthValue = 1.1;
        attribute material : String = "Chrome-Plated Steel";
        attribute surfaceHardness : Real = 60;
    }

    part def Seal {
        attribute type : String;
        attribute ratedPressure : PressureValue = 25e6;
        attribute temperatureRange : String = "-30 to 120 C";
        attribute material : String = "Nitrile Rubber";
    }

    part def RodSeal :> Seal {
        attribute type : String = "Rod Seal";
    }

    part def PistonSeal :> Seal {
        attribute type : String = "Piston Seal";
    }

    part def WiperSeal :> Seal {
        attribute type : String = "Wiper Seal";
    }

    // ===== Main Functional Units =====
    part def HydraulicPowerUnit {
        attribute supplyPressure : PressureValue = 20e6;
        attribute nominalFlowRate : FlowRateValue = 0.0015;
        attribute tankCapacity : VolumeValue = 0.04;
        port fluidSupply : FluidSupplyPort;

        part pump : Pump {
            attribute status : PumpStatus = PumpStatus::running;
        }
        part reservoir : Reservoir;
        part reliefValve : ReliefValve;
        part electricMotor {
            attribute power : Real = 7500;
            attribute voltage : Real = 480;
            attribute speed : Real = 1800;
        }

        connection pumpToRelief connect pump.fluidOut to reliefValve.inlet;
        connection reliefToSupply connect reliefValve.outlet to fluidSupply;
        connection returnToReservoir connect fluidSupply.returnFluid to reservoir.fluidReturn;
        connection reservoirToPump connect reservoir.fluidReturn to pump.fluidIn;

        action def pressurizeFluid {
            in fluidIn : HydraulicFluid;
            out fluidOut : PressurizedFluid;
            attribute targetPressure : PressureValue = 20e6;
            attribute targetFlow : FlowRateValue = 0.0015;
        }

        perform pressurizeFluid;
    }

    part def ControlValve {
        attribute currentPosition : ValvePosition = ValvePosition::hold;
        attribute responseTime : DurationValue = 0.03;
        attribute maxFlow : FlowRateValue = 0.002;
        attribute spoolDiameter : LengthValue = 0.02;

        port fluidIn : FluidControlPort;
        port extendPort : FluidControlPort;
        port retractPort : FluidControlPort;
        port commandPort : CommandPort;

        action def shiftSpool {
            in target : ValvePosition;
            out position : ValvePosition;
        }

        perform shiftSpool when commandPort.command.targetPosition != currentPosition;

        state machine ValvePositionStateMachine {
            entry;
            state Hold {
                entry action { currentPosition = ValvePosition::hold; }
            }
            state Extend {
                entry action { currentPosition = ValvePosition::extend; }
            }
            state Retract {
                entry action { currentPosition = ValvePosition::retract; }
            }
            transition from entry to Hold;
            transition from Hold to Extend
                when commandPort.command.targetPosition == ValvePosition::extend;
            transition from Hold to Retract
                when commandPort.command.targetPosition == ValvePosition::retract;
            transition from Extend to Hold
                when commandPort.command.targetPosition == ValvePosition::hold;
            transition from Retract to Hold
                when commandPort.command.targetPosition == ValvePosition::hold;
            transition from Extend to Retract
                when commandPort.command.targetPosition == ValvePosition::retract;
            transition from Retract to Extend
                when commandPort.command.targetPosition == ValvePosition::extend;
        }

        flow from fluidIn.pressurizedFluid to extendPort.pressurizedFluid
            when currentPosition == ValvePosition::extend;
        flow from fluidIn.pressurizedFluid to retractPort.pressurizedFluid
            when currentPosition == ValvePosition::retract;
    }

    part def PistonActuator {
        attribute boreDiameter : LengthValue = 0.1;
        attribute rodDiameter : LengthValue = 0.04;
        attribute strokeLength : LengthValue = 0.8;
        attribute currentStroke : LengthValue = 0;
        attribute currentVelocity : VelocityValue = 0;
        attribute outputForce : ForceValue = 0;
        attribute extendArea : AreaValue = 0.007854;
        attribute retractArea : AreaValue = 0.006597;
        attribute maxPressure : PressureValue = 21e6;

        port extendPort : FluidControlPort;
        port retractPort : FluidControlPort;
        port loadPort : MechanicalLoadPort;

        part cylinderBody : CylinderBody;
        part pistonHead : PistonHead;
        part pistonRod : PistonRod;
        part rodSeal : RodSeal;
        part pistonSeal : PistonSeal;
        part wiperSeal : WiperSeal;
        part glandNut {
            attribute material : String = "Aluminum";
        }

        connection extendPort to cylinderBody.extendChamberPort;
        connection retractPort to cylinderBody.retractChamberPort;

        action def extendStroke {
            in fluid : PressurizedFluid;
            out force : ForceValue;
            out displacement : LengthValue;
            attribute chamberPressure : PressureValue;
            attribute generatedForce : ForceValue;
            attribute velocity : VelocityValue;
        }

        action def retractStroke {
            in fluid : PressurizedFluid;
            out force : ForceValue;
            out displacement : LengthValue;
            attribute chamberPressure : PressureValue;
            attribute generatedForce : ForceValue;
            attribute velocity : VelocityValue;
        }

        action def holdPosition {
            in trappedFluid : PressurizedFluid;
            out holdingForce : ForceValue;
        }

        perform extendStroke when currentStroke < strokeLength and extendPort.pressure > retractPort.pressure;
        perform retractStroke when currentStroke > 0 and retractPort.pressure > extendPort.pressure;
        perform holdPosition when extendPort.pressure == retractPort.pressure;

        state machine ActuatorStateMachine {
            entry;
            state Idle;
            state Extending {
                entry action { currentVelocity = 0.4; }
            }
            state Retracting {
                entry action { currentVelocity = -0.5; }
            }
            state Holding {
                entry action { currentVelocity = 0; }
            }
            transition from entry to Idle;
            transition from Idle to Extending
                when extendPort.pressure > retractPort.pressure and currentStroke < strokeLength;
            transition from Idle to Retracting
                when retractPort.pressure > extendPort.pressure and currentStroke > 0;
            transition from Extending to Holding
                when currentStroke >= strokeLength or extendPort.pressure == retractPort.pressure;
            transition from Retracting to Holding
                when currentStroke <= 0 or retractPort.pressure == extendPort.pressure;
            transition from Holding to Extending
                when extendPort.pressure > retractPort.pressure and currentStroke < strokeLength;
            transition from Holding to Retracting
                when retractPort.pressure > extendPort.pressure and currentStroke > 0;
        }
    }

    // ===== Top-Level System =====
    part def HydraulicPistonActuationSystem {
        attribute systemState : SystemState = SystemState::idle;
        attribute maxPressure : PressureValue = 21e6;
        attribute maxForce : ForceValue = 150000;
        attribute maxStroke : LengthValue = 0.8;

        port commandPort : CommandPort;
        port loadPort : MechanicalLoadPort;

        part powerUnit : HydraulicPowerUnit;
        part controlValve : ControlValve;
        part actuator : PistonActuator;

        // Fluid connections
        connection powerToValve connect powerUnit.fluidSupply to controlValve.fluidIn;
        connection valveToActuatorExtend connect controlValve.extendPort to actuator.extendPort;
        connection valveToActuatorRetract connect controlValve.retractPort to actuator.retractPort;

        // Command connection
        connection commandToValve connect commandPort to controlValve.commandPort;

        // Mechanical output connection
        connection actuatorToLoad connect actuator.loadPort to loadPort;

        // Return fluid path
        flow from actuator.extendPort.returnFluid to controlValve.extendPort.returnFluid;
        flow from actuator.retractPort.returnFluid to controlValve.retractPort.returnFluid;
        flow from controlValve.fluidIn.returnFluid to powerUnit.fluidSupply.returnFluid;

        action def initializeSystem {
            out status : Boolean;
            attribute selfTestPassed : Boolean = true;
        }

        action def executeCommand {
            in command : CommandSignal;
            out result : SystemState;
        }

        action def emergencyStop {
            out state : SystemState = SystemState::idle;
        }

        perform initializeSystem;
        perform executeCommand when commandPort.command.targetPosition != controlValve.currentPosition;

        state machine SystemStateMachine {
            entry;
            state Idle {
                doc /* System is powered and waiting for commands. */
                entry action { systemState = SystemState::idle; }
            }
            state Extending {
                doc /* Pressurized fluid is directed to the extend chamber, driving the piston outward. */
                entry action { systemState = SystemState::extending; }
            }
            state Retracting {
                doc /* Pressurized fluid is directed to the retract chamber, pulling the piston inward. */
                entry action { systemState = SystemState::retracting; }
            }
            state Holding {
                doc /* Fluid is trapped in the cylinder, maintaining the piston at a fixed position. */
                entry action { systemState = SystemState::holding; }
            }
            state Faulted {
                doc /* A fault condition has been detected; system enters safe state. */
                entry action { systemState = SystemState::faulted; }
            }

            transition from entry to Idle;
            transition from Idle to Extending
                when commandPort.command.targetPosition == ValvePosition::extend;
            transition from Idle to Retracting
                when commandPort.command.targetPosition == ValvePosition::retract;
            transition from Idle to Holding
                when commandPort.command.targetPosition == ValvePosition::hold and actuator.currentStroke > 0;
            transition from Extending to Holding
                when commandPort.command.targetPosition == ValvePosition::hold
                or actuator.currentStroke >= maxStroke;
            transition from Retracting to Holding
                when commandPort.command.targetPosition == ValvePosition::hold
                or actuator.currentStroke <= 0;
            transition from Extending to Retracting
                when commandPort.command.targetPosition == ValvePosition::retract;
            transition from Retracting to Extending
                when commandPort.command.targetPosition == ValvePosition::extend;
            transition from Holding to Extending
                when commandPort.command.targetPosition == ValvePosition::extend;
            transition from Holding to Retracting
                when commandPort.command.targetPosition == ValvePosition::retract;
            transition from Idle to Faulted when powerUnit.supplyPressure > maxPressure;
            transition from Extending to Faulted when powerUnit.supplyPressure > maxPressure;
            transition from Retracting to Faulted when powerUnit.supplyPressure > maxPressure;
            transition from Holding to Faulted when powerUnit.supplyPressure > maxPressure;
            transition from Faulted to Idle when powerUnit.supplyPressure <= maxPressure;
        }

        satisfy ActuationSystemRequirements {
            subject system = HydraulicPistonActuationSystem::this;
        }
    }
}
