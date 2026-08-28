package DowntonPumpingSystem {

    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def Pressure :> Real { unit = 'Pa'; }
    value def FlowRate :> Real { unit = 'm3/s'; }
    value def RotationalSpeed :> Real { unit = 'rad/s'; }
    value def Voltage :> Real { unit = 'V'; }
    value def Current :> Real { unit = 'A'; }
    value def Torque :> Real { unit = 'N*m'; }
    value def Temperature :> Real { unit = 'K'; }
    value def Volume :> Real { unit = 'm3'; }
    value def Power :> Real { unit = 'W'; }
    value def Dimensionless :> Real { unit = '1'; }
    value def Length :> Real { unit = 'm'; }
    value def MassDensity :> Real { unit = 'kg/m3'; }
    value def DynamicViscosity :> Real { unit = 'Pa*s'; }

    // ===== Item Definitions =====
    item def Fluid {
        attribute density : MassDensity = 1000 [kg/m3];
        attribute viscosity : DynamicViscosity = 0.001 [Pa*s];
        attribute temperature : Temperature = 293.15 [K];
    }

    item def StartSignal;
    item def StopSignal;
    item def FaultSignal;
    item def ResetSignal;
    item def ModeSwitchSignal;
    item def SystemReadySignal;
    item def ShutdownCompleteSignal;

    // ===== Port Definitions =====
    port def FluidPort {
        out item fluid : Fluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def MechanicalPort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def ControlPort {
        attribute speedCommand : RotationalSpeed;
        attribute powerEnable : Boolean;
    }

    port def PressureDataPort {
        attribute measuredPressure : Pressure;
        attribute status : String;
    }

    port def FlowDataPort {
        attribute measuredFlowRate : FlowRate;
        attribute status : String;
    }

    // ===== Part Definitions =====

    part def Reservoir {
        port outlet : FluidPort;
        attribute fluidVolume : Volume = 5 [m3];
        attribute maxVolume : Volume = 10 [m3];
        attribute minVolume : Volume = 0.1 [m3];
        attribute fluid : Fluid;
        attribute ambientPressure : Pressure = 101325 [Pa];

        action def SupplyFluid {
            in requestedFlow : FlowRate;
            out suppliedFlow : FlowRate;
            out suppliedPressure : Pressure;
            assign suppliedFlow { = requestedFlow; }
            assign suppliedPressure { = ambientPressure; }
        }
    }

    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute length : Length = 1.0 [m];
        attribute diameter : Length = 0.05 [m];
        attribute roughness : Length = 0.000045 [m];
        attribute pressureDrop : Pressure = 0 [Pa];

        action def TransportFluid {
            in inFlow : FlowRate;
            in inPressure : Pressure;
            out outFlow : FlowRate;
            out outPressure : Pressure;
            assign outFlow { = inFlow; }
            assign outPressure { = inPressure - pressureDrop; }
        }
    }

    part def IsolationValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute isOpen : Boolean = false;
        attribute position : Dimensionless = 0 [1];
        attribute maxPressure : Pressure = 1000000 [Pa];

        action def Open {
            assign isOpen { = true; }
            assign position { = 1.0; }
        }

        action def Close {
            assign isOpen { = false; }
            assign position { = 0.0; }
        }

        action def RegulateFlow {
            in inFlow : FlowRate;
            in inPressure : Pressure;
            out outFlow : FlowRate;
            out outPressure : Pressure;
            assign outFlow { = inFlow * position; }
            assign outPressure { = inPressure; }
        }
    }

    part def FlowSensor {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port dataOut : FlowDataPort;
        attribute measuredFlowRate : FlowRate = 0 [m3/s];
        attribute calibrationFactor : Dimensionless = 1.0;
        attribute faultDetected : Boolean = false;
        attribute maxFlowRate : FlowRate = 0.05 [m3/s];

        action def Measure {
            in actualFlow : FlowRate;
            out reading : FlowRate;
            out status : String;
            assign reading { = actualFlow * calibrationFactor; }
            assign status { = faultDetected ? "FAULT" : "OK"; }
        }
    }

    part def PressureSensor {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port dataOut : PressureDataPort;
        attribute measuredPressure : Pressure = 0 [Pa];
        attribute calibrationFactor : Dimensionless = 1.0;
        attribute faultDetected : Boolean = false;
        attribute maxPressure : Pressure = 2000000 [Pa];

        action def Measure {
            in actualPressure : Pressure;
            out reading : Pressure;
            out status : String;
            assign reading { = actualPressure * calibrationFactor; }
            assign status { = faultDetected ? "FAULT" : "OK"; }
        }
    }

    part def ElectricMotor {
        port powerIn : ElectricalPort;
        port mechOut : MechanicalPort;
        attribute ratedSpeed : RotationalSpeed = 314 [rad/s];
        attribute ratedPower : Power = 5000 [W];
        attribute efficiency : Dimensionless = 0.92;
        attribute currentSpeed : RotationalSpeed = 0 [rad/s];
        attribute windingTemp : Temperature = 293.15 [K];
        attribute maxWindingTemp : Temperature = 353.15 [K];

        action def Drive {
            in voltage : Voltage;
            in current : Current;
            in speedCommand : RotationalSpeed;
            out speed : RotationalSpeed;
            out torque : Torque;
            assign speed { = speedCommand; }
            assign torque { = (voltage * current * efficiency) / speed; }
        }

        action def Stop {
            assign currentSpeed { = 0 [rad/s]; }
        }
    }

    part def DriveShaft {
        port inputSide : MechanicalPort;
        port outputSide : MechanicalPort;
        attribute length : Length = 0.5 [m];
        attribute diameter : Length = 0.03 [m];
        attribute material : String = "Stainless Steel";
        attribute transmissionEfficiency : Dimensionless = 0.98;

        action def Transmit {
            in inputSpeed : RotationalSpeed;
            in inputTorque : Torque;
            out outputSpeed : RotationalSpeed;
            out outputTorque : Torque;
            assign outputSpeed { = inputSpeed; }
            assign outputTorque { = inputTorque * transmissionEfficiency; }
        }
    }

    part def Impeller {
        port driveInput : MechanicalPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute diameter : Length = 0.15 [m];
        attribute bladeCount : Integer = 7;
        attribute ratedSpeed : RotationalSpeed = 314 [rad/s];
        attribute fluidDensity : MassDensity = 1000 [kg/m3];

        action def ImpartEnergy {
            in speed : RotationalSpeed;
            in inFlow : FlowRate;
            in inPressure : Pressure;
            out outFlow : FlowRate;
            out outPressure : Pressure;
            assign outFlow { = inFlow; }
            assign outPressure { = inPressure + (fluidDensity * speed * speed * diameter * diameter / 2); }
        }
    }

    part def Casing {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        attribute material : String = "Cast Iron";
        attribute maxPressure : Pressure = 1000000 [Pa];
        attribute volume : Volume = 0.002 [m3];
    }

    part def SealAssembly {
        attribute sealType : String = "Mechanical Seal";
        attribute maxPressure : Pressure = 1500000 [Pa];
        attribute leakRate : FlowRate = 0 [m3/s];
        attribute integrityOK : Boolean = true;
        attribute operatingTemp : Temperature = 293.15 [K];
        attribute maxOperatingTemp : Temperature = 423.15 [K];

        action def CheckIntegrity {
            out status : Boolean;
            assign status { = integrityOK && (leakRate < 0.000001 [m3/s]); }
        }
    }

    part def DowntonPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port powerPort : ElectricalPort;
        port controlPort : ControlPort;

        part motor : ElectricMotor;
        part shaft : DriveShaft;
        part impeller : Impeller;
        part casing : Casing;
        part seal : SealAssembly;

        connection motorToShaft connect motor.mechOut to shaft.inputSide;
        connection shaftToImpeller connect shaft.outputSide to impeller.driveInput;
        connection suctionToCasing connect suctionPort to casing.suctionPort;
        connection casingToImpellerIn connect casing.suctionPort to impeller.fluidIn;
        connection impellerOutToCasing connect impeller.fluidOut to casing.dischargePort;
        connection casingToDischarge connect casing.dischargePort to dischargePort;
        connection powerToMotor connect powerPort to motor.powerIn;

        attribute ratedFlowRate : FlowRate = 0.01 [m3/s];
        attribute ratedPressure : Pressure = 500000 [Pa];
        attribute ratedSpeed : RotationalSpeed = 314 [rad/s];
        attribute pumpEfficiency : Dimensionless = 0.75;
    }

    part def PressureVessel {
        port inlet : FluidPort;
        attribute currentVolume : Volume = 0 [m3];
        attribute maxVolume : Volume = 2 [m3];
        attribute currentPressure : Pressure = 101325 [Pa];
        attribute maxPressure : Pressure = 800000 [Pa];
        attribute fluid : Fluid;
        attribute safetyValveThreshold : Pressure = 750000 [Pa];

        action def ReceiveFluid {
            in incomingFlow : FlowRate;
            in incomingPressure : Pressure;
            out newVolume : Volume;
            out newPressure : Pressure;
            assign newVolume { = currentVolume + incomingFlow * 1.0; }
            assign newPressure { = currentPressure + (incomingPressure - currentPressure) * 0.5; }
        }

        action def CheckSafety {
            out safe : Boolean;
            assign safe { = currentPressure < safetyValveThreshold; }
        }
    }

    part def PumpController {
        port pressureFeedbackIn : PressureDataPort;
        port flowFeedbackIn : FlowDataPort;
        port pumpControlOut : ControlPort;
        port powerOutput : ElectricalPort;

        attribute controlMode : String = "constantFlow";
        attribute targetFlowRate : FlowRate = 0.008 [m3/s];
        attribute targetPressure : Pressure = 400000 [Pa];
        attribute maxSpeed : RotationalSpeed = 314 [rad/s];
        attribute minSpeed : RotationalSpeed = 0 [rad/s];
        attribute kp : Dimensionless = 2.0;
        attribute ki : Dimensionless = 0.5;
        attribute integralError : Dimensionless = 0.0;
        attribute currentSpeedCommand : RotationalSpeed = 0 [rad/s];
        attribute powerEnabled : Boolean = false;
        attribute supplyVoltage : Voltage = 400 [V];
        attribute supplyCurrent : Current = 15 [A];
        attribute faultDetected : Boolean = false;

        action def ComputeControl {
            in measuredPressure : Pressure;
            in measuredFlow : FlowRate;
            out speedCommand : RotationalSpeed;
            out powerEnable : Boolean;

            attribute error : Dimensionless;

            if (controlMode == "constantFlow") {
                assign error { = (targetFlowRate - measuredFlow) / targetFlowRate; }
            } else {
                assign error { = (targetPressure - measuredPressure) / targetPressure; }
            }
            assign integralError { = integralError + error; }
            assign speedCommand { = currentSpeedCommand + kp * error + ki * integralError; }
            assign powerEnable { = true; }
        }

        action def EmergencyStop {
            assign currentSpeedCommand { = 0 [rad/s]; }
            assign powerEnabled { = false; }
            assign faultDetected { = true; }
        }

        action def Reset {
            assign faultDetected { = false; }
            assign integralError { = 0.0; }
            assign currentSpeedCommand { = 0 [rad/s]; }
        }

        action def SwitchMode {
            in newMode : String;
            assign controlMode { = newMode; }
            assign integralError { = 0.0; }
        }
    }

    // ===== State Machine =====
    state def PumpSystemStates {
        attribute systemActive : Boolean = false;
        attribute controlMode : String = "constantFlow";
        attribute faultDetected : Boolean = false;
        attribute motorAtSpeed : Boolean = false;
        attribute motorStopped : Boolean = false;
        attribute valvesOpen : Boolean = false;
        attribute valvesClosed : Boolean = false;
        attribute rampSpeed : RotationalSpeed = 0 [rad/s];

        state idle {
            entry {
                assign systemActive { = false; }
                assign motorStopped { = true; }
                assign valvesClosed { = true; }
            }
        }

        state startup {
            entry {
                assign systemActive { = true; }
                assign motorAtSpeed { = false; }
                assign valvesOpen { = false; }
            }
            do {
                assign rampSpeed { = 50 [rad/s]; }
            }
            exit {
                assign motorAtSpeed { = true; }
                assign valvesOpen { = true; }
            }
        }

        state operational {
            entry {
                assign systemActive { = true; }
            }

            state constantFlowMode {
                entry {
                    assign controlMode { = "constantFlow"; }
                }
            }

            state constantPressureMode {
                entry {
                    assign controlMode { = "constantPressure"; }
                }
            }

            transition constantFlowMode to constantPressureMode
                accept ModeSwitchSignal;
            transition constantPressureMode to constantFlowMode
                accept ModeSwitchSignal;

            exit {
                assign systemActive { = false; }
            }
        }

        state shutdown {
            entry {
                assign systemActive { = false; }
                assign motorStopped { = false; }
            }
            do {
                assign rampSpeed { = 0 [rad/s]; }
            }
            exit {
                assign motorStopped { = true; }
                assign valvesClosed { = true; }
            }
        }

        state faulted {
            entry {
                assign systemActive { = false; }
                assign faultDetected { = true; }
            }
        }

        transition idle to startup
            accept StartSignal;
        transition startup to operational
            accept SystemReadySignal;
        transition startup to faulted
            accept FaultSignal;
        transition operational to shutdown
            accept StopSignal;
        transition operational to faulted
            accept FaultSignal;
        transition shutdown to idle
            accept ShutdownCompleteSignal;
        transition faulted to idle
            accept ResetSignal;
    }

    // ===== Requirements =====
    requirement def PumpingSystemRequirement {
        doc /* The automated industrial fluid pumping system shall transfer fluid from a source reservoir to a destination pressure vessel with precise and automated control. */
        subject pumpSystem : DowntonPumpingSystem;
    }

    requirement def FlowRateRequirement {
        doc /* The system shall transfer fluid at a minimum flow rate of 0.005 m3/s during operational state. */
        subject pumpSystem : DowntonPumpingSystem;
        attribute minFlowRate : FlowRate = 0.005 [m3/s];
        constraint { pumpSystem.dischargeFlowSensor.measuredFlowRate >= minFlowRate }
    }

    requirement def PressureControlRequirement {
        doc /* The system shall maintain discharge pressure within 5 percent of the target pressure in constant pressure mode. */
        subject pumpSystem : DowntonPumpingSystem;
        attribute targetPressure : Pressure = 400000 [Pa];
        attribute tolerance : Dimensionless = 0.05;
        constraint { abs(pumpSystem.dischargePressureSensor.measuredPressure - targetPressure) / targetPressure <= tolerance }
    }

    requirement def SafetyFaultRequirement {
        doc /* The system shall enter a faulted state when any sensor reports a fault, requiring an explicit reset before returning to idle. */
        subject pumpSystem : DowntonPumpingSystem;
        constraint { pumpSystem.dischargePressureSensor.faultDetected implies pumpSystem.systemStateMachine.faultDetected }
        constraint { pumpSystem.dischargeFlowSensor.faultDetected implies pumpSystem.systemStateMachine.faultDetected }
    }

    requirement def LifecycleRequirement {
        doc /* The system shall support idle, startup, operational, shutdown, and faulted states with proper transitions. */
        subject pumpSystem : DowntonPumpingSystem;
    }

    requirement def ControlModeRequirement {
        doc /* The controller shall support constant flow and constant pressure control modes, switchable during operational state. */
        subject controller : PumpController;
    }

    requirement def PumpAssemblyRequirement {
        doc /* The Downton Pump shall consist of an electric motor, drive shaft, impeller, casing, and seal assembly. */
        subject pump : DowntonPump;
    }

    requirement def VesselPressureRequirement {
        doc /* The destination pressure vessel shall hold fluid under pressure up to 800000 Pa without exceeding safety threshold. */
        subject vessel : PressureVessel;
        attribute maxSafePressure : Pressure = 750000 [Pa];
        constraint { vessel.currentPressure <= maxSafePressure }
    }

    // ===== Top-Level System =====
    part def DowntonPumpingSystem {
        part reservoir : Reservoir;
        part suctionPipe : Pipe;
        part suctionValve : IsolationValve;
        part inletFlowSensor : FlowSensor;
        part pump : DowntonPump;
        part dischargePipe : Pipe;
        part dischargePressureSensor : PressureSensor;
        part dischargeFlowSensor : FlowSensor;
        part dischargeValve : IsolationValve;
        part destinationVessel : PressureVessel;
        part controller : PumpController;

        // Fluid path connections
        connection reservoirToSuctionPipe connect reservoir.outlet to suctionPipe.inlet;
        connection suctionPipeToValve connect suctionPipe.outlet to suctionValve.inlet;
        connection valveToInletFlowSensor connect suctionValve.outlet to inletFlowSensor.inlet;
        connection inletFlowSensorToPump connect inletFlowSensor.outlet to pump.suctionPort;
        connection pumpToDischargePipe connect pump.dischargePort to dischargePipe.inlet;
        connection dischargePipeToPressureSensor connect dischargePipe.outlet to dischargePressureSensor.inlet;
        connection pressureSensorToFlowSensor connect dischargePressureSensor.outlet to dischargeFlowSensor.inlet;
        connection flowSensorToDischargeValve connect dischargeFlowSensor.outlet to dischargeValve.inlet;
        connection dischargeValveToVessel connect dischargeValve.outlet to destinationVessel.inlet;

        // Control and feedback connections
        connection pressureFeedback connect dischargePressureSensor.dataOut to controller.pressureFeedbackIn;
        connection flowFeedback connect dischargeFlowSensor.dataOut to controller.flowFeedbackIn;
        connection controlToPump connect controller.pumpControlOut to pump.controlPort;
        connection powerToPump connect controller.powerOutput to pump.powerPort;

        // State machine behavior
        behavior systemStateMachine : PumpSystemStates;

        // Requirements satisfaction
        satisfy PumpingSystemRequirement;
        satisfy FlowRateRequirement;
        satisfy PressureControlRequirement;
        satisfy SafetyFaultRequirement;
        satisfy LifecycleRequirement;
        satisfy ControlModeRequirement;
        satisfy PumpAssemblyRequirement;
        satisfy VesselPressureRequirement;
    }
}
