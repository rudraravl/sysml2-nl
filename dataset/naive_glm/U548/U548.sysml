package IndustrialFluidPumpingSubsystem {
    import SI::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def AngularVelocity :> Real { unit "rad/s"; }
    value def Torque :> Real { unit "N*m"; }
    value def FlowRate :> Real { unit "m3/s"; }
    value def PressureValue :> Real { unit "Pa"; }
    value def Volume :> Real { unit "m3"; }
    value def Temperature :> Real { unit "K"; }
    value def ValvePosition :> Real { unit "1"; }  // 0.0 = closed, 1.0 = fully open
    value def Dimensionless :> Real { unit "1"; }

    // ===== Item Definitions =====
    item def Fluid {
        attribute density : Real = 1000 [kg/m3];
        attribute viscosity : Real = 0.001 [Pa*s];
        attribute temperature : Temperature = 293.15 [K];
    }

    item def PressurizedFluid :> Fluid {
        attribute pressure : PressureValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        attribute flowRate : FlowRate;
        attribute pressure : PressureValue;
        item fluid : Fluid;
    }

    port def ElectricalPowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def RotationalPort {
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
    }

    port def FlowSignalPort {
        attribute measuredFlow : FlowRate;
    }

    port def PressureSignalPort {
        attribute measuredPressure : PressureValue;
    }

    port def ValveCommandPort {
        attribute commandedPosition : ValvePosition;
    }

    port def ControlSignalPort {
        attribute targetFlow : FlowRate;
    }

    // ===== Pump Sub-Components =====

    part def ElectricMotor {
        port in powerIn : ElectricalPowerPort;
        port out driveOut : RotationalPort;
        attribute ratedPower : Real = 5000 [W];
        attribute efficiency : Dimensionless = 0.92;

        action def GenerateTorque {
            in voltage : Voltage;
            in current : Current;
            out torque : Torque;
            out speed : AngularVelocity;
        }
    }

    part def Shaft {
        port in driveIn : RotationalPort;
        port out driveOut : RotationalPort;
        attribute length : Real = 0.5 [m];
        attribute diameter : Real = 0.04 [m];
        attribute material : String = "StainlessSteel";
    }

    part def RadialBearing {
        port in supportIn : RotationalPort;
        port out supportOut : RotationalPort;
        attribute loadCapacity : Real = 2000 [N];
    }

    part def ThrustBearing {
        port in thrustIn : RotationalPort;
        port out thrustOut : RotationalPort;
        attribute axialLoadCapacity : Real = 3000 [N];
    }

    part def Inducer {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in driveIn : RotationalPort;
        attribute bladeCount : Integer = 4;
        attribute pressureBoost : PressureValue = 50000 [Pa];
    }

    part def Impeller {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in driveIn : RotationalPort;
        attribute bladeCount : Integer = 7;
        attribute outerDiameter : Real = 0.2 [m];
        attribute headCoefficient : Dimensionless = 0.6;
    }

    part def Casing {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        attribute material : String = "StainlessSteel";
        attribute inletDiameter : Real = 0.1 [m];
        attribute outletDiameter : Real = 0.08 [m];
        attribute maxPressureRating : PressureValue = 2000000 [Pa];
    }

    part def MechanicalSeal {
        port in shaftInterface : RotationalPort;
        attribute leakRate : FlowRate = 0.0 [m3/s];
        attribute maxPressure : PressureValue = 1500000 [Pa];
    }

    // ===== Main Pump =====

    part def MainPump {
        port in electricalIn : ElectricalPowerPort;
        port in pumpInlet : FluidPort;
        port out pumpOutlet : FluidPort;

        attribute ratedFlow : FlowRate = 0.01 [m3/s];
        attribute ratedHead : PressureValue = 800000 [Pa];

        part motor : ElectricMotor {
            port in powerIn : ElectricalPowerPort;
            port out driveOut : RotationalPort;
        }

        part shaft : Shaft {
            port in driveIn : RotationalPort;
            port out driveOut : RotationalPort;
        }

        part radialBearing : RadialBearing {
            port in supportIn : RotationalPort;
            port out supportOut : RotationalPort;
        }

        part thrustBearing : ThrustBearing {
            port in thrustIn : RotationalPort;
            port out thrustOut : RotationalPort;
        }

        part inducer : Inducer {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
            port in driveIn : RotationalPort;
        }

        part impeller : Impeller {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
            port in driveIn : RotationalPort;
        }

        part casing : Casing {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
        }

        part seal : MechanicalSeal {
            port in shaftInterface : RotationalPort;
        }

        // Internal connections
        connection motorToShaft connect motor.driveOut to shaft.driveIn;
        connection shaftToRadial connect shaft.driveOut to radialBearing.supportIn;
        connection radialToThrust connect radialBearing.supportOut to thrustBearing.thrustIn;
        connection thrustToInducer connect thrustBearing.thrustOut to inducer.driveIn;
        connection inducerToImpeller connect inducer.driveOut to impeller.driveIn;
        connection shaftToSeal connect shaft.driveOut to seal.shaftInterface;

        // Fluid path connections
        connection inletToInducer connect pumpInlet to inducer.fluidIn;
        connection inducerToImpellerFluid connect inducer.fluidOut to impeller.fluidIn;
        connection impellerToCasing connect impeller.fluidOut to casing.fluidIn;
        connection casingToOutlet connect casing.fluidOut to pumpOutlet;

        // Power connection
        connection powerToMotor connect electricalIn to motor.powerIn;

        // Pump state machine
        state def PumpLifecycle {
            entry action { send PumpOff(); }
            state Off {
                entry action { /* Pump is de-energized */ }
                transition Off -> StartingUp
                    when (electricalIn.voltage > 0 [V]) {
                        send StartCommand();
                    }
            }
            state StartingUp {
                entry action { send RampUp(); }
                do action { 
                    // Motor ramps up to operating speed
                    wait(5 [s]);
                }
                transition StartingUp -> OperatingNormal
                    when (motor.driveOut.angularVelocity > 290 [rad/s]);
                transition StartingUp -> Fault
                    when (motor.driveOut.angularVelocity < 10 [rad/s]) {
                        send StartupFailure();
                    }
            }
            state OperatingNormal {
                entry action { send NormalOperation(); }
                transition OperatingNormal -> ShuttingDown
                    when (electricalIn.voltage < 1 [V]) {
                        send ShutdownCommand();
                    }
                transition OperatingNormal -> Fault
                    when (casing.fluidOut.pressure > casing.maxPressureRating) {
                        send OverPressureFault();
                    }
            }
            state ShuttingDown {
                entry action { send RampDown(); }
                do action {
                    wait(3 [s]);
                }
                transition ShuttingDown -> Off
                    when (motor.driveOut.angularVelocity < 1 [rad/s]);
            }
            state Fault {
                entry action { send FaultAlert(); }
                transition Fault -> Off
                    when (electricalIn.voltage < 1 [V]) {
                        send ResetCommand();
                    }
            }
        }

        exhibit state machine : PumpLifecycle;
    }

    // ===== System Components =====

    part def SupplyTank {
        port out fluidOut : FluidPort;
        attribute capacity : Volume = 5.0 [m3];
        attribute currentLevel : Volume = 4.0 [m3];
        attribute minLevel : Volume = 0.5 [m3];
    }

    part def DischargeTank {
        port in fluidIn : FluidPort;
        attribute capacity : Volume = 3.0 [m3];
        attribute currentLevel : Volume = 1.0 [m3];
        attribute targetPressure : PressureValue = 600000 [Pa];
    }

    part def FlowSensor {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port out signalOut : FlowSignalPort;
        attribute accuracy : Dimensionless = 0.01;
        attribute range : FlowRate = 0.02 [m3/s];

        action def MeasureFlow {
            in actualFlow : FlowRate;
            out measuredFlow : FlowRate;
        }
    }

    part def PressureSensor {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port out signalOut : PressureSignalPort;
        attribute accuracy : Dimensionless = 0.005;
        attribute range : PressureValue = 2000000 [Pa];

        action def MeasurePressure {
            in actualPressure : PressureValue;
            out measuredPressure : PressureValue;
        }
    }

    part def DischargeValve {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in commandIn : ValveCommandPort;
        attribute currentPosition : ValvePosition = 0.5;
        attribute maxFlow : FlowRate = 0.02 [m3/s];
        attribute actuationTime : Real = 0.5 [s];

        action def AdjustPosition {
            in commandedPosition : ValvePosition;
            out actualPosition : ValvePosition;
        }
    }

    part def Controller {
        port in flowFeedback : FlowSignalPort;
        port in pressureFeedback : PressureSignalPort;
        port out valveCommand : ValveCommandPort;
        port in targetInput : ControlSignalPort;

        attribute targetFlowRate : FlowRate = 0.01 [m3/s];
        attribute proportionalGain : Dimensionless = 2.0;
        attribute integralGain : Dimensionless = 0.1;
        attribute integralError : FlowRate = 0.0 [m3/s];
        attribute valvePositionCommand : ValvePosition = 0.5;
        attribute tolerance : FlowRate = 0.0001 [m3/s];

        action def ControlLoop {
            in measuredFlow : FlowRate;
            in targetFlow : FlowRate;
            out valveCommand : ValvePosition;

            private attribute error : FlowRate;
            private attribute proportionalTerm : ValvePosition;
            private attribute integralTerm : ValvePosition;

            // Compute error
            assign error := targetFlow - measuredFlow;

            // Proportional term
            assign proportionalTerm := proportionalGain * (error / maxFlow);

            // Integral term (accumulated)
            assign integralError := integralError + error * dt;
            assign integralTerm := integralGain * (integralError / maxFlow);

            // Decide valve command
            if error > tolerance {
                // Flow too low: open valve further
                assign valvePositionCommand := valvePositionCommand + proportionalTerm + integralTerm;
                if valvePositionCommand > 1.0 {
                    assign valvePositionCommand := 1.0;
                }
            } else if error < -tolerance {
                // Flow too high: close valve further
                assign valvePositionCommand := valvePositionCommand + proportionalTerm + integralTerm;
                if valvePositionCommand < 0.0 {
                    assign valvePositionCommand := 0.0;
                }
            } else {
                // Flow correct: maintain valve position
                // No change to valvePositionCommand
            }

            assign valveCommand := valvePositionCommand;
        }

        private attribute maxFlow : FlowRate = 0.02 [m3/s];
        private attribute dt : Real = 0.1 [s];
    }

    // ===== Top-Level Subsystem =====

    part def PumpingSubsystem {
        attribute systemName : String = "IndustrialFluidPumpingSubsystem";
        attribute designFlowRate : FlowRate = 0.01 [m3/s];
        attribute designPressure : PressureValue = 800000 [Pa];

        part supplyTank : SupplyTank {
            port out fluidOut : FluidPort;
        }

        part mainPump : MainPump {
            port in electricalIn : ElectricalPowerPort;
            port in pumpInlet : FluidPort;
            port out pumpOutlet : FluidPort;
        }

        part flowSensor : FlowSensor {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
            port out signalOut : FlowSignalPort;
        }

        part pressureSensor : PressureSensor {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
            port out signalOut : PressureSignalPort;
        }

        part dischargeValve : DischargeValve {
            port in fluidIn : FluidPort;
            port out fluidOut : FluidPort;
            port in commandIn : ValveCommandPort;
        }

        part dischargeTank : DischargeTank {
            port in fluidIn : FluidPort;
        }

        part controller : Controller {
            port in flowFeedback : FlowSignalPort;
            port in pressureFeedback : PressureSignalPort;
            port out valveCommand : ValveCommandPort;
            port in targetInput : ControlSignalPort;
        }

        // External power source port
        port in systemPower : ElectricalPowerPort;
        port in systemTarget : ControlSignalPort;

        // Fluid connections
        connection supplyToPump connect supplyTank.fluidOut to mainPump.pumpInlet;
        connection pumpToFlowSensor connect mainPump.pumpOutlet to flowSensor.fluidIn;
        connection flowSensorToPressureSensor connect flowSensor.fluidOut to pressureSensor.fluidIn;
        connection pressureSensorToValve connect pressureSensor.fluidOut to dischargeValve.fluidIn;
        connection valveToDischargeTank connect dischargeValve.fluidOut to dischargeTank.fluidIn;

        // Signal connections
        connection flowSignalToController connect flowSensor.signalOut to controller.flowFeedback;
        connection pressureSignalToController connect pressureSensor.signalOut to controller.pressureFeedback;
        connection controllerToValve connect controller.valveCommand to dischargeValve.commandIn;
        connection powerToPump connect systemPower to mainPump.electricalIn;
        connection targetToController connect systemTarget to controller.targetInput;

        // System-level control action
        action def SystemOperation {
            action supplyFluid;
            action pumpFluid;
            action measureFlow;
            action measurePressure;
            action controlValve;
            action storeFluid;

            succession supplyFluid then pumpFluid;
            succession pumpFluid then measureFlow;
            succession measureFlow then measurePressure;
            succession measurePressure then controlValve;
            succession controlValve then storeFluid;
            succession storeFluid then supplyFluid;
        }

        exhibit action : SystemOperation;
    }

    // ===== Requirements =====

    requirement def TransferFluidRequirement {
        doc "The subsystem shall transfer fluid from the supply tank to the discharge tank at a controlled flow rate."
        attribute targetFlowRate : FlowRate = 0.01 [m3/s];
        attribute tolerance : FlowRate = 0.0001 [m3/s];
        subject pumpingSubsystem : PumpingSubsystem;
        objective {
            pumpingSubsystem.designFlowRate == targetFlowRate
        }
    }

    requirement def PressureBoostRequirement {
        doc "The main pump shall increase fluid pressure to at least the design pressure."
        attribute minDischargePressure : PressureValue = 800000 [Pa];
        subject mainPump : MainPump;
        objective {
            mainPump.ratedHead >= minDischargePressure
        }
    }

    requirement def CavitationPreventionRequirement {
        doc "The inducer shall provide sufficient inlet pressure boost to prevent cavitation."
        attribute minPressureBoost : PressureValue = 50000 [Pa];
        subject inducer : Inducer;
        objective {
            inducer.pressureBoost >= minPressureBoost
        }
    }

    requirement def LeakPreventionRequirement {
        doc "The mechanical seal shall prevent fluid leakage at the shaft exit point."
        attribute maxLeakRate : FlowRate = 0.0 [m3/s];
        subject seal : MechanicalSeal;
        objective {
            seal.leakRate <= maxLeakRate
        }
    }

    requirement def FlowControlRequirement {
        doc "The controller shall maintain actual flow rate within tolerance of the target flow rate."
        attribute targetFlow : FlowRate = 0.01 [m3/s];
        attribute allowedError : FlowRate = 0.0001 [m3/s];
        subject controller : Controller;
        objective {
            controller.tolerance <= allowedError
        }
    }

    requirement def ValveActuationRequirement {
        doc "The discharge valve shall adjust position based on controller commands."
        attribute maxActuationTime : Real = 1.0 [s];
        subject dischargeValve : DischargeValve;
        objective {
            dischargeValve.actuationTime <= maxActuationTime
        }
    }

    requirement def PumpLifecycleRequirement {
        doc "The pump shall support states: Off, StartingUp, OperatingNormal, ShuttingDown, and Fault."
        subject mainPump : MainPump;
        objective {
            mainPump exhibits PumpLifecycle
        }
    }

    requirement def CasingMaterialRequirement {
        doc "The pump casing shall be made of stainless steel for durability and corrosion resistance."
        subject casing : Casing;
        objective {
            casing.material == "StainlessSteel"
        }
    }

    requirement def DischargeTankPressureRequirement {
        doc "The discharge tank shall maintain a target pressure for pressurized storage."
        attribute targetPressure : PressureValue = 600000 [Pa];
        subject dischargeTank : DischargeTank;
        objective {
            dischargeTank.targetPressure == targetPressure
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction satisfyTransferFluid : TransferFluidRequirement {
        subject pumpingSubsystem : PumpingSubsystem;
    }

    satisfaction satisfyPressureBoost : PressureBoostRequirement {
        subject mainPump : MainPump;
    }

    satisfaction satisfyCavitationPrevention : CavitationPreventionRequirement {
        subject inducer : Inducer;
    }

    satisfaction satisfyLeakPrevention : LeakPreventionRequirement {
        subject seal : MechanicalSeal;
    }

    satisfaction satisfyFlowControl : FlowControlRequirement {
        subject controller : Controller;
    }

    satisfaction satisfyValveActuation : ValveActuationRequirement {
        subject dischargeValve : DischargeValve;
    }

    satisfaction satisfyPumpLifecycle : PumpLifecycleRequirement {
        subject mainPump : MainPump;
    }

    satisfaction satisfyCasingMaterial : CasingMaterialRequirement {
        subject casing : Casing;
    }

    satisfaction satisfyDischargeTankPressure : DischargeTankPressureRequirement {
        subject dischargeTank : DischargeTank;
    }
}
