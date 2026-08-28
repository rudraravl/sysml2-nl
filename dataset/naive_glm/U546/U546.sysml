package EnergyRecoveryPumpingSystem {

    import SI::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value type Pressure :> Real { unit "Pa"; }
    value type VolumetricFlowRate :> Real { unit "m3/s"; }
    value type Power :> Real { unit "W"; }
    value type Torque :> Real { unit "N.m"; }
    value type AngularSpeed :> Real { unit "rad/s"; }
    value type Temperature :> Real { unit "K"; }
    value type Efficiency :> Real { unit "1"; }
    value type Volume :> Real { unit "m3"; }
    value type Duration :> Real { unit "s"; }
    value type Dimensionless :> Real { unit "1"; }

    // ---------- Item Definitions ----------
    item def HydraulicFluid {
        attribute density : Real { unit "kg/m3"; } = 1000;
        attribute viscosity : Real { unit "Pa.s"; } = 0.001;
        attribute temperature : Temperature;
    }

    // ---------- Port Definitions ----------
    port def FluidInPort {
        in item fluid : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    port def FluidOutPort {
        out item fluid : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    port def MechanicalPowerPort {
        attribute torque : Torque;
        attribute speed : AngularSpeed;
        attribute power : Power;
    }

    port def PressureSignalPort {
        out attribute pressure : Pressure;
    }

    port def FlowSignalPort {
        out attribute flowRate : VolumetricFlowRate;
    }

    port def CommandPort {
        in attribute command : String;
        in attribute setpoint : VolumetricFlowRate;
    }

    port def StatusPort {
        out attribute state : String;
        out attribute netPower : Power;
        out attribute efficiency : Efficiency;
    }

    // ---------- Part Definitions ----------

    part def HighPressureReservoir {
        port fluidOut : FluidOutPort;
        attribute volume : Volume = 5.0;
        attribute initialPressure : Pressure = 2.0e6;
        attribute currentPressure : Pressure = initialPressure;
        attribute storedFluid : HydraulicFluid;

        action def Drain :> Action {
            in item f : HydraulicFluid;
            out item discharged : HydraulicFluid;
        }
    }

    part def LowPressureReservoir {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        attribute volume : Volume = 10.0;
        attribute initialPressure : Pressure = 1.0e5;
        attribute currentPressure : Pressure = initialPressure;
        attribute storedFluid : HydraulicFluid;
    }

    part def FinalDischargePoint {
        port fluidIn : FluidInPort;
        attribute requiredPressure : Pressure = 1.8e6;
        attribute deliveredFlow : VolumetricFlowRate;
    }

    part def PumpAsTurbine {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port shaftOut : MechanicalPowerPort;
        port pressureInSensor : PressureSignalPort;
        port pressureOutSensor : PressureSignalPort;
        port flowSensor : FlowSignalPort;

        attribute ratedFlow : VolumetricFlowRate = 0.05;
        attribute ratedPressureDrop : Pressure = 1.9e6;
        attribute ratedSpeed : AngularSpeed = 314.16;
        attribute ratedTorque : Torque = 60.0;
        attribute ratedPower : Power = 18850.0;
        attribute efficiency : Efficiency = 0.78;
        attribute currentSpeed : AngularSpeed;
        attribute currentTorque : Torque;
        attribute currentPower : Power;
        attribute currentFlow : VolumetricFlowRate;

        state machine PATStateMachine {
            state idle;
            state starting;
            state operating {
                state normal;
                state highFlow;
                state lowFlow;
                transition normal to highFlow
                    if currentFlow > 1.2 * ratedFlow;
                transition highFlow to normal
                    if currentFlow <= 1.2 * ratedFlow and currentFlow >= 0.8 * ratedFlow;
                transition normal to lowFlow
                    if currentFlow < 0.8 * ratedFlow;
                transition lowFlow to normal
                    if currentFlow >= 0.8 * ratedFlow and currentFlow <= 1.2 * ratedFlow;
            }
            state stopping;
            state faulted;

            transition idle to starting
                if receive StartCommand;
            transition starting to operating
                if currentSpeed >= 0.9 * ratedSpeed;
            transition operating to stopping
                if receive StopCommand;
            transition stopping to idle
                if currentSpeed <= 1.0;
            transition any to faulted
                if receive FaultSignal;
            transition faulted to idle
                if receive ResetCommand;
        }

        action def GeneratePower {
            in item inflow : HydraulicFluid;
            out item outflow : HydraulicFluid;
            out attribute mechanicalPower : Power;
        }
    }

    part def MainPump {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port shaftIn : MechanicalPowerPort;
        port pressureInSensor : PressureSignalPort;
        port pressureOutSensor : PressureSignalPort;
        port flowSensor : FlowSignalPort;

        attribute ratedFlow : VolumetricFlowRate = 0.04;
        attribute ratedPressureRise : Pressure = 1.7e6;
        attribute ratedSpeed : AngularSpeed = 314.16;
        attribute ratedTorque : Torque = 55.0;
        attribute ratedPower : Power = 17278.0;
        attribute efficiency : Efficiency = 0.75;
        attribute currentSpeed : AngularSpeed;
        attribute currentTorque : Torque;
        attribute currentFlow : VolumetricFlowRate;
        attribute dischargePressure : Pressure;

        state machine PumpStateMachine {
            state idle;
            state starting;
            state operating {
                state normal;
                state highFlow;
                state lowFlow;
                transition normal to highFlow
                    if currentFlow > 1.2 * ratedFlow;
                transition highFlow to normal
                    if currentFlow <= 1.2 * ratedFlow and currentFlow >= 0.8 * ratedFlow;
                transition normal to lowFlow
                    if currentFlow < 0.8 * ratedFlow;
                transition lowFlow to normal
                    if currentFlow >= 0.8 * ratedFlow and currentFlow <= 1.2 * ratedFlow;
            }
            state stopping;
            state faulted;

            transition idle to starting
                if receive StartCommand;
            transition starting to operating
                if currentSpeed >= 0.9 * ratedSpeed;
            transition operating to stopping
                if receive StopCommand;
            transition stopping to idle
                if currentSpeed <= 1.0;
            transition any to faulted
                if receive FaultSignal;
            transition faulted to idle
                if receive ResetCommand;
        }

        action def BoostPressure {
            in item inflow : HydraulicFluid;
            in attribute mechanicalPower : Power;
            out item outflow : HydraulicFluid;
            out attribute dischargePressure : Pressure;
        }
    }

    part def MechanicalCoupling {
        port shaftFromPAT : MechanicalPowerPort;
        port shaftToPump : MechanicalPowerPort;
        attribute couplingEfficiency : Efficiency = 0.98;
        attribute transmittedTorque : Torque;
        attribute transmittedSpeed : AngularSpeed;
        attribute transmittedPower : Power;

        action def TransferPower {
            in attribute inputPower : Power;
            in attribute inputTorque : Torque;
            in attribute inputSpeed : AngularSpeed;
            out attribute outputPower : Power;
            out attribute outputTorque : Torque;
            out attribute outputSpeed : AngularSpeed;
        }
    }

    part def PressureSensor {
        port measuredPort : FluidInPort;
        port signalOut : PressureSignalPort;
        attribute measuredPressure : Pressure;
        attribute accuracy : Pressure = 1000.0;
        attribute samplingPeriod : Duration = 0.1;

        action def Sample {
            in attribute actualPressure : Pressure;
            out attribute measured : Pressure;
        }
    }

    part def FlowSensor {
        port measuredPort : FluidInPort;
        port signalOut : FlowSignalPort;
        attribute measuredFlow : VolumetricFlowRate;
        attribute accuracy : VolumetricFlowRate = 0.0005;
        attribute samplingPeriod : Duration = 0.1;

        action def Sample {
            in attribute actualFlow : VolumetricFlowRate;
            out attribute measured : VolumetricFlowRate;
        }
    }

    part def SystemController {
        port patPressureIn : PressureSignalPort;
        port patPressureOut : PressureSignalPort;
        port patFlow : FlowSignalPort;
        port pumpPressureIn : PressureSignalPort;
        port pumpPressureOut : PressureSignalPort;
        port pumpFlow : FlowSignalPort;
        port patCommand : CommandPort;
        port pumpCommand : CommandPort;
        port statusOut : StatusPort;

        attribute setpointFlow : VolumetricFlowRate = 0.04;
        attribute netPower : Power;
        attribute systemEfficiency : Efficiency;
        attribute controlState : String;

        state machine ControllerStateMachine {
            state idle;
            state initializing;
            state running {
                state monitoring;
                state adjusting;
                transition monitoring to adjusting
                    if abs(pumpFlow.flowRate - setpointFlow) > 0.1 * setpointFlow;
                transition adjusting to monitoring
                    if abs(pumpFlow.flowRate - setpointFlow) <= 0.05 * setpointFlow;
            }
            state shuttingDown;
            state emergency;

            transition idle to initializing
                if receive SystemStart;
            transition initializing to running
                if pat.state == "operating" and pump.state == "opering";
            transition running to shuttingDown
                if receive SystemStop;
            transition shuttingDown to idle
                if pat.state == "idle" and pump.state == "idle";
            transition any to emergency
                if receive EmergencySignal;
            transition emergency to idle
                if receive ResetCommand;
        }

        action def ComputeNetPower {
            in attribute patPower : Power;
            in attribute pumpPower : Power;
            out attribute net : Power;
        }

        action def AdjustSetpoint {
            in attribute measuredFlow : VolumetricFlowRate;
            in attribute currentSetpoint : VolumetricFlowRate;
            out attribute newSetpoint : VolumetricFlowRate;
        }
    }

    // ---------- Top-level System ----------
    part def EnergyRecoveryPumpingSystem {
        part hpReservoir : HighPressureReservoir;
        part lpReservoir : LowPressureReservoir;
        part pat : PumpAsTurbine;
        part mainPump : MainPump;
        part coupling : MechanicalCoupling;
        part dischargePoint : FinalDischargePoint;
        part patInPressureSensor : PressureSensor;
        part patOutPressureSensor : PressureSensor;
        part patFlowSensor : FlowSensor;
        part pumpInPressureSensor : PressureSensor;
        part pumpOutPressureSensor : PressureSensor;
        part pumpFlowSensor : FlowSensor;
        part controller : SystemController;

        // Fluid connections
        connection hpToPAT connect hpReservoir.fluidOut to pat.fluidIn;
        connection patToLP connect pat.fluidOut to lpReservoir.fluidIn;
        connection lpToPump connect lpReservoir.fluidOut to mainPump.fluidIn;
        connection pumpToDischarge connect mainPump.fluidOut to dischargePoint.fluidIn;

        // Mechanical connection
        connection patToCoupling connect pat.shaftOut to coupling.shaftFromPAT;
        connection couplingToPump connect coupling.shaftToPump to mainPump.shaftIn;

        // Sensor connections
        connection patInPressureSense connect hpReservoir.fluidOut to patInPressureSensor.measuredPort;
        connection patOutPressureSense connect pat.fluidOut to patOutPressureSensor.measuredPort;
        connection patFlowSense connect pat.fluidOut to patFlowSensor.measuredPort;
        connection pumpInPressureSense connect lpReservoir.fluidOut to pumpInPressureSensor.measuredPort;
        connection pumpOutPressureSense connect mainPump.fluidOut to pumpOutPressureSensor.measuredPort;
        connection pumpFlowSense connect mainPump.fluidOut to pumpFlowSensor.measuredPort;

        // Signal connections to controller
        connection patInPressSig connect patInPressureSensor.signalOut to controller.patPressureIn;
        connection patOutPressSig connect patOutPressureSensor.signalOut to controller.patPressureOut;
        connection patFlowSig connect patFlowSensor.signalOut to controller.patFlow;
        connection pumpInPressSig connect pumpInPressureSensor.signalOut to controller.pumpPressureIn;
        connection pumpOutPressSig connect pumpOutPressureSensor.signalOut to controller.pumpPressureOut;
        connection pumpFlowSig connect pumpFlowSensor.signalOut to controller.pumpFlow;

        // Command connections
        connection patCmd connect controller.patCommand to pat.shaftOut;
        connection pumpCmd connect controller.pumpCommand to mainPump.shaftIn;

        attribute totalRecoveredPower : Power;
        attribute totalConsumedPower : Power;
        attribute netEnergySavings : Efficiency;

        action def SystemStartup {
            first StartController;
            then StartPAT;
            then EngageCoupling;
            then StartPump;
            then VerifyOperation;
        }

        action def SystemShutdown {
            first StopPump;
            then DisengageCoupling;
            then StopPAT;
            then StopController;
        }
    }

    // ---------- Requirements ----------
    requirement def EnergyRecoveryRequirement {
        subject system : EnergyRecoveryPumpingSystem;
        objective {
            doc "The system shall recover energy from a high-pressure fluid stream to reduce net power consumption."
        }
        require system.totalRecoveredPower > 0;
        require system.netEnergySavings > 0.3;
    }

    requirement def PumpingRequirement {
        subject system : EnergyRecoveryPumpingSystem;
        objective {
            doc "The system shall move fluid from a low-pressure source to a high-pressure destination."
        }
        require system.dischargePoint.deliveredFlow >= 0.03;
        require system.dischargePoint.requiredPressure >= 1.8e6;
    }

    requirement def PATOperationRequirement {
        subject pat : PumpAsTurbine;
        objective {
            doc "The PAT shall generate mechanical power from a pressure drop in the high-pressure fluid stream."
        }
        require pat.currentPower > 0;
        require pat.efficiency >= 0.7;
    }

    requirement def PumpOperationRequirement {
        subject pump : MainPump;
        objective {
            doc "The main pump shall boost fluid pressure using mechanical power supplied by the PAT."
        }
        require pump.dischargePressure >= 1.8e6;
        require pump.efficiency >= 0.7;
    }

    requirement def MechanicalCouplingRequirement {
        subject coupling : MechanicalCoupling;
        objective {
            doc "The mechanical coupling shall transfer power from the PAT to the main pump with minimal loss."
        }
        require coupling.couplingEfficiency >= 0.95;
    }

    requirement def StateMachineRequirement {
        subject pat : PumpAsTurbine;
        subject pump : MainPump;
        objective {
            doc "Both the PAT and the pump shall operate through idle, starting, stopping, and operating states, with operating subdivided into normal, high-flow, and low-flow modes."
        }
        require pat.PATStateMachine.idle.exists;
        require pat.PATStateMachine.starting.exists;
        require pat.PATStateMachine.stopping.exists;
        require pat.PATStateMachine.operating.exists;
        require pat.PATStateMachine.operating.normal.exists;
        require pat.PATStateMachine.operating.highFlow.exists;
        require pat.PATStateMachine.operating.lowFlow.exists;
        require pump.PumpStateMachine.idle.exists;
        require pump.PumpStateMachine.starting.exists;
        require pump.PumpStateMachine.stopping.exists;
        require pump.PumpStateMachine.operating.exists;
        require pump.PumpStateMachine.operating.normal.exists;
        require pump.PumpStateMachine.operating.highFlow.exists;
        require pump.PumpStateMachine.operating.lowFlow.exists;
    }

    requirement def MonitoringRequirement {
        subject controller : SystemController;
        objective {
            doc "The controller shall monitor pressure and flow rates and manage system operation."
        }
        require controller.patPressureIn.pressure.exists;
        require controller.patFlow.flowRate.exists;
        require controller.pumpPressureOut.pressure.exists;
        require controller.pumpFlow.flowRate.exists;
    }

    requirement package SystemRequirements {
        satisfy EnergyRecoveryRequirement by EnergyRecoveryPumpingSystem;
        satisfy PumpingRequirement by EnergyRecoveryPumpingSystem;
        satisfy PATOperationRequirement by PumpAsTurbine;
        satisfy PumpOperationRequirement by MainPump;
        satisfy MechanicalCouplingRequirement by MechanicalCoupling;
        satisfy StateMachineRequirement by PumpAsTurbine, MainPump;
        satisfy MonitoringRequirement by SystemController;
    }

}
