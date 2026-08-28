package HydristorDriveSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def RotationalSpeed :> Real { unit 'rad/s'; }
    attribute def Torque :> Real { unit 'N*m'; }
    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def VolumetricFlowRate :> Real { unit 'm^3/s'; }
    attribute def Displacement :> Real { unit 'm^3/rev'; }
    attribute def Volume :> Real { unit 'm^3'; }
    attribute def ControlSignal :> Real { unit '1'; }
    attribute def DimensionlessRatio :> Real { unit '1'; }

    // ---- Item types ----
    item def HydraulicFluid {
        attribute density : Real { unit 'kg/m^3'; }
        attribute viscosity : Real { unit 'Pa*s'; }
        attribute bulkModulus : Real { unit 'Pa'; }
    }

    // ---- Port definitions ----
    port def RotationalMechanicalPort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    port def HydraulicPort {
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
        item hydraulicFluid : HydraulicFluid;
    }

    port def PressureSignalPort {
        attribute measuredPressure : Pressure;
    }

    port def SpeedSignalPort {
        attribute measuredSpeed : RotationalSpeed;
    }

    port def ControlSignalPort {
        attribute command : ControlSignal;
    }

    // ---- Requirements ----
    requirement def DriveSystemRequirements {
        requirement ConstantSpeedSource {
            doc { The Prime Driver shall provide rotational power at a constant nominal speed. }
        }
        requirement VariableOutputSpeed {
            doc { The system shall provide variable output speed at the Mechanical Load while the Prime Driver speed remains constant. }
        }
        requirement ClosedLoopControl {
            doc { The Displacement Controller shall adjust Hydristor displacement based on measured speed error to maintain target speed within tolerance. }
        }
        requirement FluidCirculation {
            doc { Hydraulic fluid shall circulate from Reservoir through Pump, Hydristor, and back to Reservoir in a closed circuit. }
        }
    }

    // ---- Component definitions ----

    part def PrimeDriver {
        port mechanicalOutput : RotationalMechanicalPort;
        attribute nominalSpeed : RotationalSpeed = 157.08; // ~1500 rpm
        attribute nominalTorque : Torque = 100.0;
    }

    part def Reservoir {
        port supplyPort : HydraulicPort;
        port returnPort : HydraulicPort;
        attribute capacity : Volume = 0.05;
        attribute fluid : HydraulicFluid;
    }

    part def HydraulicPump {
        port mechanicalInput : RotationalMechanicalPort;
        port suctionPort : HydraulicPort;
        port dischargePort : HydraulicPort;
        attribute displacement : Displacement = 0.00005;
        attribute volumetricEfficiency : DimensionlessRatio = 0.95;
        attribute mechanicalEfficiency : DimensionlessRatio = 0.92;
    }

    part def Hydristor {
        port hydraulicInlet : HydraulicPort;
        port hydraulicOutlet : HydraulicPort;
        port mechanicalOutput : RotationalMechanicalPort;
        port controlInput : ControlSignalPort;
        attribute maxDisplacement : Displacement = 0.0001;
        attribute currentDisplacement : Displacement = 0.00005;
        attribute volumetricEfficiency : DimensionlessRatio = 0.96;
        attribute mechanicalEfficiency : DimensionlessRatio = 0.93;
    }

    part def MechanicalLoad {
        port mechanicalInput : RotationalMechanicalPort;
        attribute loadInertia : Real { unit 'kg*m^2'; } = 2.5;
        attribute loadTorque : Torque = 50.0;
        attribute targetSpeed : RotationalSpeed = 31.42; // ~300 rpm
        attribute actualSpeed : RotationalSpeed = 0.0;
    }

    part def PressureSensor {
        port hydraulicSense : HydraulicPort;
        port signalOutput : PressureSignalPort;
        attribute range : Pressure = 35.0e6;
        attribute accuracy : DimensionlessRatio = 0.01;
    }

    part def SpeedSensor {
        port mechanicalSense : RotationalMechanicalPort;
        port signalOutput : SpeedSignalPort;
        attribute range : RotationalSpeed = 314.16;
        attribute accuracy : DimensionlessRatio = 0.005;
    }

    part def DisplacementController {
        port pressureFeedback : PressureSignalPort;
        port speedFeedback : SpeedSignalPort;
        port controlOutput : ControlSignalPort;
        attribute targetSpeed : RotationalSpeed = 31.42;
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.2;
        attribute integralError : Real = 0.0;
        attribute maxCommand : ControlSignal = 1.0;
        attribute minCommand : ControlSignal = 0.0;

        action computeControl {
            in measuredSpeed : RotationalSpeed;
            in measuredPressure : Pressure;
            out command : ControlSignal;
        }
    }

    // ---- System assembly ----
    part def HydristorDriveSystem {
        satisfies DriveSystemRequirements;

        port driverInput : RotationalMechanicalPort;
        port loadOutput : RotationalMechanicalPort;

        part primeDriver : PrimeDriver {
            attribute nominalSpeed = 157.08;
        }
        part reservoir : Reservoir {
            attribute capacity = 0.05;
        }
        part hydraulicPump : HydraulicPump {
            attribute displacement = 0.00005;
        }
        part hydristor : Hydristor {
            attribute maxDisplacement = 0.0001;
        }
        part mechanicalLoad : MechanicalLoad {
            attribute targetSpeed = 31.42;
        }
        part pressureSensor : PressureSensor {}
        part speedSensor : SpeedSensor {}
        part displacementController : DisplacementController {
            attribute targetSpeed = 31.42;
        }

        // Mechanical connections
        connection primeDriverToPump : RotationalMechanicalPort
            connect primeDriver.mechanicalOutput to hydraulicPump.mechanicalInput;

        connection hydristorToLoad : RotationalMechanicalPort
            connect hydristor.mechanicalOutput to mechanicalLoad.mechanicalInput;

        // Hydraulic connections
        connection reservoirToPump : HydraulicPort
            connect reservoir.supplyPort to hydraulicPump.suctionPort;

        connection pumpToHydristor : HydraulicPort
            connect hydraulicPump.dischargePort to hydristor.hydraulicInlet;

        connection hydristorToReservoir : HydraulicPort
            connect hydristor.hydraulicOutlet to reservoir.returnPort;

        // Sensor connections
        connection pressureSenseLine : PressureSignalPort
            connect pressureSensor.signalOutput to displacementController.pressureFeedback;

        connection speedSenseLine : SpeedSignalPort
            connect speedSensor.signalOutput to displacementController.speedFeedback;

        connection controlLine : ControlSignalPort
            connect displacementController.controlOutput to hydristor.controlInput;

        // Bind sensors to physical points
        binding pressureSensor.hydraulicSense = hydraulicPump.dischargePort;
        binding speedSensor.mechanicalSense = hydristor.mechanicalOutput;

        // ---- State machine behavior ----
        state def SystemStates {
            entry action { 
                // initialize integral error 
            }
            state Off {
                entry action { /* system de-energized */ }
            }
            state Starting {
                entry action { /* prime driver spins up pump */ }
            }
            state Running {
                entry action { /* closed-loop control active */ }
            }
            state Faulted {
                entry action { /* protective shutdown */ }
            }
            transition offToStarting first Off then Starting
                when primeDriver.nominalSpeed > 0.0;
            transition startingToRunning first Starting then Running
                when hydraulicPump.dischargePort.pressure > 1.0e6;
            transition runningToFaulted first Running then Faulted
                when pressureSensor.signalOutput.measuredPressure > 35.0e6
                    or speedSensor.signalOutput.measuredSpeed > 314.16;
            transition faultedToOff first Faulted then Off
                when true;
        }

        // ---- Control action behavior ----
        action def ControlAction {
            in measuredSpeed : RotationalSpeed;
            in measuredPressure : Pressure;
            in target : RotationalSpeed;
            in pGain : Real;
            in iGain : Real;
            in integralAccumulator : Real;
            out command : ControlSignal;

            private speedError : Real;
            private rawCommand : Real;

            action computeError {
                speedError := target - measuredSpeed;
            }
            action updateIntegral {
                integralAccumulator := integralAccumulator + speedError;
            }
            action computeCommand {
                rawCommand := pGain * speedError + iGain * integralAccumulator;
            }
            action clampCommand {
                if rawCommand > 1.0 then
                    command := 1.0;
                else if rawCommand < 0.0 then
                    command := 0.0;
                else
                    command := rawCommand;
            }
        }

        // Controller behavior binding
        action controllerBehavior : ControlAction {
            in measuredSpeed = speedSensor.signalOutput.measuredSpeed;
            in measuredPressure = pressureSensor.signalOutput.measuredPressure;
            in target = displacementController.targetSpeed;
            in pGain = displacementController.proportionalGain;
            in iGain = displacementController.integralGain;
            in integralAccumulator = displacementController.integralError;
            out command to displacementController.controlOutput.command;
        }
    }
}
