package FluidTransferSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit = "Pa"; }
    value type FlowRateValue :> Real { unit = "m3/s"; }
    value type RotationalSpeed :> Real { unit = "rad/s"; }
    value type TorqueValue :> Real { unit = "N.m"; }
    value type VolumeValue :> Real { unit = "m3"; }
    value type ValveOpening :> Real { min = 0.0; max = 1.0; }
    value type PowerValue :> Real { unit = "W"; }
    value type TemperatureValue :> Real { unit = "K"; }
    value type DurationValue :> Real { unit = "s"; }

    // ===== Item Types =====
    item def Liquid;
    item def PressurizedLiquid :> Liquid;

    attribute def PressureReading {
        attr value : PressureValue;
    }
    attribute def FlowRateReading {
        attr value : FlowRateValue;
    }
    attribute def ValveCommand {
        attr opening : ValveOpening;
    }
    attribute def PumpCommand {
        attr run : Boolean;
        attr targetSpeed : RotationalSpeed;
    }

    // ===== Ports =====
    port def FluidInPort {
        out item liquid : Liquid;
    }
    port def FluidOutPort {
        in item liquid : Liquid;
    }
    port def PressureOutPort {
        out reading : PressureReading;
    }
    port def FlowRateOutPort {
        out reading : FlowRateReading;
    }
    port def ValveCmdPort {
        in command : ValveCommand;
    }
    port def PumpCmdPort {
        in command : PumpCommand;
    }
    port def PressureInPort {
        in reading : PressureReading;
    }
    port def FlowRateInPort {
        in reading : FlowRateReading;
    }

    // ===== Requirements =====
    requirement def PressureControlRequirement {
        doc /* The discharge pressure shall be maintained within the operating range. */
        attr minPressure : PressureValue;
        attr maxPressure : PressureValue;
        attr targetPressure : PressureValue;
        requirement pressureMaintained {
            subject dischargePressure : PressureValue;
            require dischargePressure >= minPressure and dischargePressure <= maxPressure;
        }
    }

    requirement def FlowContinuityRequirement {
        doc /* Fluid shall flow continuously from source to destination during operation. */
        attr minFlowRate : FlowRateValue;
        require flowRate >= minFlowRate;
        subject flowRate : FlowRateValue;
    }

    requirement def PumpLifecycleRequirement {
        doc /* The pump shall transition through off, startup, operational, and shutdown states. */
        require pumpState in {"off", "startup", "operational", "shutdown"};
        subject pumpState : String;
    }

    requirement def PumpConfigurationRequirement {
        doc /* The subsystem shall support different pump configurations. */
        require configurablePump :> PumpAssembly;
        subject configurablePump;
    }

    // ===== Pump Assembly =====
    part def Motor {
        attr ratedPower : PowerValue;
        attr ratedSpeed : RotationalSpeed;
        port in cmd : PumpCmdPort;
        port out mechanicalShaft : TorqueValue;
        exhibit state motorBehavior {
            entry; then off;
            state off;
            transition off_to_running first off if cmd.command.run then running;
            state running;
            transition running_to_off first running if !cmd.command.run then off;
        }
    }

    part def Shaft {
        attr length : Real { unit = "m"; }
        attr diameter : Real { unit = "m"; }
        in torque : TorqueValue;
        out rotationalSpeed : RotationalSpeed;
    }

    part def Bearing {
        attr type : String;
        attr ratedLoad : Real { unit = "N"; }
    }

    part def Impeller {
        attr diameter : Real { unit = "m"; }
        attr bladeCount : Integer;
        in speed : RotationalSpeed;
        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
    }

    part def Volute {
        attr inletDiameter : Real { unit = "m"; }
        attr outletDiameter : Real { unit = "m"; }
        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
    }

    part def PumpAssembly {
        doc /* Pistonless pump using a motor-driven impeller in a volute casing. */
        attr ratedFlowRate : FlowRateValue;
        attr ratedPressure : PressureValue;
        attr ratedSpeed : RotationalSpeed;

        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
        port in cmd : PumpCmdPort;

        part motor : Motor {
            port in cmd : PumpCmdPort;
        }
        part shaft : Shaft;
        part bearing1 : Bearing;
        part bearing2 : Bearing;
        part impeller : Impeller {
            port in fluidIn : FluidInPort;
            port out fluidOut : FluidOutPort;
        }
        part volute : Volute {
            port in fluidIn : FluidInPort;
            port out fluidOut : FluidOutPort;
        }

        connection motorToShaft connect motor.mechanicalShaft to shaft.torque;
        connection shaftToImpeller connect shaft.rotationalSpeed to impeller.speed;
        connection fluidInToVolute connect fluidIn.liquid to volute.fluidIn.liquid;
        connection voluteToImpeller connect volute.fluidOut.liquid to impeller.fluidIn.liquid;
        connection impellerOut connect impeller.fluidOut.liquid to fluidOut.liquid;

        exhibit state pumpLifecycle {
            entry; then off;
            state off;
            transition off_to_startup first off if cmd.command.run then startup;
            state startup {
                entry;
                do actions::primeAndAccelerate;
                then operational;
            }
            state operational {
                entry;
                then normalFlow;
                state normalFlow;
                transition normal_to_reduced first normalFlow if dischargePressure > maxOperatingPressure then reducedFlow;
                state reducedFlow;
                transition reduced_to_normal first reducedFlow if dischargePressure <= targetOperatingPressure then normalFlow;
            }
            transition operational_to_shutdown first operational if !cmd.command.run then shutdown;
            state shutdown {
                entry;
                do actions::controlledStop;
                then off;
            }
            transition shutdown_to_off first shutdown to off;
            attr dischargePressure : PressureValue;
            attr maxOperatingPressure : PressureValue;
            attr targetOperatingPressure : PressureValue;
        }
    }

    // ===== High-Capacity Pump Variant =====
    part def HighCapacityPump :> PumpAssembly {
        redef ratedFlowRate = 0.05 [m3/s];
        redef ratedPressure = 500000.0 [Pa];
        redef ratedSpeed = 314.0 [rad/s];
        part redef motor : Motor {
            redef ratedPower = 5000.0 [W];
            redef ratedSpeed = 314.0 [rad/s];
        }
        part redef impeller : Impeller {
            redef diameter = 0.2 [m];
            redef bladeCount = 7;
        }
        part redef volute : Volute {
            redef inletDiameter = 0.08 [m];
            redef outletDiameter = 0.06 [m];
        }
    }

    // ===== Sensors =====
    part def PressureSensor {
        attr range : PressureValue;
        attr accuracy : PressureValue;
        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
        port out reading : PressureOutPort;
        exhibit action measurePressure {
            in fluid;
            out pressure : PressureReading;
        }
    }

    part def FlowRateSensor {
        attr range : FlowRateValue;
        attr accuracy : FlowRateValue;
        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
        port out reading : FlowRateOutPort;
        exhibit action measureFlowRate {
            in fluid;
            out flowRate : FlowRateReading;
        }
    }

    // ===== Control Valve =====
    part def ControlValve {
        attr maxFlowRate : FlowRateValue;
        attr currentOpening : ValveOpening;
        port in fluidIn : FluidInPort;
        port out fluidOut : FluidOutPort;
        port in cmd : ValveCmdPort;
        exhibit action adjustValve {
            in command : ValveCommand;
            out opening : ValveOpening;
        }
    }

    // ===== Tanks =====
    part def StorageTank {
        attr capacity : VolumeValue;
        attr currentVolume : VolumeValue;
        attr fluidType : String;
        port out fluidOut : FluidOutPort;
        port in fluidIn : FluidInPort;
    }

    // ===== Controller =====
    part def PumpController {
        attr minPressure : PressureValue = 200000.0 [Pa];
        attr maxPressure : PressureValue = 400000.0 [Pa];
        attr targetPressure : PressureValue = 300000.0 [Pa];
        attr currentValveOpening : ValveOpening = 0.5;
        attr currentPressure : PressureValue;
        attr currentFlowRate : FlowRateValue;

        port in pressureInput : PressureInPort;
        port in flowRateInput : FlowRateInPort;
        port out valveOutput : ValveCmdPort;
        port out pumpOutput : PumpCmdPort;

        exhibit state controlLoop {
            entry; then monitoring;
            state monitoring {
                do actions::readSensors;
                then evaluating;
            }
            state evaluating {
                do actions::evaluatePressure;
                then adjusting;
            }
            state adjusting {
                do actions::adjustValveOpening;
                then monitoring;
            }
            transition emergencyShutdown first monitoring if currentPressure > maxPressure * 1.5 then shutdownState;
            state shutdownState {
                do actions::emergencyShutdown;
            }
        }

        satisfy PressureControlRequirement {
            minPressure = minPressure;
            maxPressure = maxPressure;
            targetPressure = targetPressure;
        }
    }

    // ===== Actions =====
    package actions {
        action def primeAndAccelerate {
            doc /* Prime the pump and accelerate the impeller to operating speed. */
            in pump : PumpAssembly;
            attr primeDuration : DurationValue = 5.0 [s];
            attr accelerationRamp : RotationalSpeed = 50.0 [rad/s];
        }
        action def controlledStop {
            doc /* Gradually decelerate the pump to a stop. */
            in pump : PumpAssembly;
            attr decelerationRamp : RotationalSpeed = 20.0 [rad/s];
        }
        action def readSensors {
            doc /* Read pressure and flow rate sensor data. */
            in pressure : PressureReading;
            in flowRate : FlowRateReading;
            out recordedPressure : PressureValue;
            out recordedFlowRate : FlowRateValue;
        }
        action def evaluatePressure {
            doc /* Evaluate whether pressure is within range. */
            in pressure : PressureValue;
            in minPressure : PressureValue;
            in maxPressure : PressureValue;
            out deviation : PressureValue;
            out needsAdjustment : Boolean;
        }
        action def adjustValveOpening {
            doc /* Adjust the control valve opening based on pressure deviation. */
            in deviation : PressureValue;
            in currentOpening : ValveOpening;
            out newOpening : ValveOpening;
        }
        action def emergencyShutdown {
            doc /* Shut down the pump immediately due to overpressure. */
            out pumpCommand : PumpCommand;
            out valveCommand : ValveCommand;
        }
    }

    // ===== Fluid Transfer Subsystem =====
    part def FluidTransferSystem {
        doc /* Automated fluid transfer subsystem moving liquid from source to destination. */

        part sourceTank : StorageTank {
            redef capacity = 10.0 [m3];
            redef currentVolume = 8.0 [m3];
            redef fluidType = "Water";
        }
        part pump : PumpAssembly {
            redef ratedFlowRate = 0.02 [m3/s];
            redef ratedPressure = 300000.0 [Pa];
            redef ratedSpeed = 157.0 [rad/s];
        }
        part pressureSensor : PressureSensor {
            redef range = 500000.0 [Pa];
            redef accuracy = 1000.0 [Pa];
        }
        part flowRateSensor : FlowRateSensor {
            redef range = 0.1 [m3/s];
            redef accuracy = 0.001 [m3/s];
        }
        part controlValve : ControlValve {
            redef maxFlowRate = 0.05 [m3/s];
            redef currentOpening = 0.5;
        }
        part destinationTank : StorageTank {
            redef capacity = 10.0 [m3];
            redef currentVolume = 2.0 [m3];
            redef fluidType = "Water";
        }
        part controller : PumpController;

        // Fluid connections
        connection sourceToPump connect sourceTank.fluidOut.liquid to pump.fluidIn.liquid;
        connection pumpToPressure connect pump.fluidOut.liquid to pressureSensor.fluidIn.liquid;
        connection pressureToFlow connect pressureSensor.fluidOut.liquid to flowRateSensor.fluidIn.liquid;
        connection flowToValve connect flowRateSensor.fluidOut.liquid to controlValve.fluidIn.liquid;
        connection valveToDest connect controlValve.fluidOut.liquid to destinationTank.fluidIn.liquid;

        // Signal connections
        connection pressureToController connect pressureSensor.reading to controller.pressureInput.reading;
        connection flowToController connect flowRateSensor.reading to controller.flowRateInput.reading;
        connection controllerToValve connect controller.valveOutput.command to controlValve.cmd.command;
        connection controllerToPump connect controller.pumpOutput.command to pump.cmd.command;

        satisfy PressureControlRequirement {
            minPressure = controller.minPressure;
            maxPressure = controller.maxPressure;
            targetPressure = controller.targetPressure;
        }
        satisfy FlowContinuityRequirement {
            minFlowRate = 0.005 [m3/s];
            subject flowRate = controller.currentFlowRate;
        }
        satisfy PumpLifecycleRequirement {
            subject pumpState = pump.pumpLifecycle.activeState.name;
        }
        satisfy PumpConfigurationRequirement {
            subject configurablePump = pump;
        }
    }

    // ===== High-Capacity Configuration =====
    part def HighCapacityFluidTransferSystem :> FluidTransferSystem {
        part redef pump : HighCapacityPump;
        part redef controlValve : ControlValve {
            redef maxFlowRate = 0.1 [m3/s];
        }
        part redef pressureSensor : PressureSensor {
            redef range = 1000000.0 [Pa];
        }
        part redef flowRateSensor : FlowRateSensor {
            redef range = 0.2 [m3/s];
        }
        part redef controller : PumpController {
            redef minPressure = 300000.0 [Pa];
            redef maxPressure = 600000.0 [Pa];
            redef targetPressure = 450000.0 [Pa];
        }
    }
}
