package PowerGenerationSystemModel {
    import ScalarValues::*;
    import ISQ::*;

    // ============ Units ============
    unit def horsepower;
    unit def rpm;
    unit def newtonMeter;
    unit def percent;
    unit def celsius;
    unit def bar;
    unit def literPerMin;

    // ============ Value Types ============
    value def PowerValue :> Real { in unit horsepower; }
    value def RotationalSpeed :> Real { in unit rpm; }
    value def TorqueValue :> Real { in unit newtonMeter; }
    value def PercentValue :> Real { in unit percent; }
    value def TemperatureValue :> Real { in unit celsius; }
    value def PressureValue :> Real { in unit bar; }
    value def FuelFlowRate :> Real { in unit literPerMin; }
    value def EfficiencyValue :> Real { in unit percent; }

    // ============ Item Types ============
    item def Fuel;
    item def Air;
    item def Exhaust;

    item def MechanicalPower {
        attribute power : PowerValue;
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeed;
    }

    item def ThrottleCommand {
        attribute position : PercentValue;
    }

    item def PowerFeedback {
        attribute actualPower : PowerValue;
        attribute actualSpeed : RotationalSpeed;
        attribute actualTorque : TorqueValue;
    }

    item def PowerSetpoint {
        attribute targetPower : PowerValue;
    }

    // ============ Port Definitions ============
    port def FuelInPort { in item fuel : Fuel; }
    port def AirInPort { in item air : Air; }
    port def ExhaustOutPort { out item exhaust : Exhaust; }
    port def MechPowerOutPort { out item mechPower : MechanicalPower; }
    port def MechPowerInPort { in item mechPower : MechanicalPower; }
    port def ThrottleInPort { in item cmd : ThrottleCommand; }
    port def ThrottleOutPort { out item cmd : ThrottleCommand; }
    port def FeedbackOutPort { out item feedback : PowerFeedback; }
    port def FeedbackInPort { in item feedback : PowerFeedback; }
    port def SetpointInPort { in item setpoint : PowerSetpoint; }

    // ============ Engine Subcomponents ============
    part def CombustionChamber {
        attribute volume : Real = 0.0005;
        attribute maxPressure : PressureValue = 120.0;
        attribute peakTemp : TemperatureValue = 2500.0;
        port fuelIn : FuelInPort;
        port airIn : AirInPort;
        port exhaustOut : ExhaustOutPort;
    }

    part def Piston {
        attribute bore : Real = 0.102;
        attribute stroke : Real = 0.120;
        attribute crankAngleDeg : Real;
        attribute ringCount : Integer = 3;
    }

    part def Crankshaft {
        attribute length : Real = 0.60;
        attribute journalDiameter : Real = 0.080;
        attribute mainBearingCount : Integer = 5;
        port powerOut : MechPowerOutPort;
    }

    part def FuelInjector {
        attribute maxFlowRate : FuelFlowRate = 5.0;
        attribute sprayPattern : String = "multi-hole";
        port fuelIn : FuelInPort;
    }

    part def IntakeManifold {
        port airIn : AirInPort;
        port airOut : AirInPort[8];
    }

    part def ExhaustManifold {
        port exhaustIn : ExhaustOutPort[8];
        port exhaustOut : ExhaustOutPort;
    }

    // ============ Power Plant (Engine) ============
    part def PowerPlant {
        attribute ratedPower : PowerValue = 500.0;
        attribute pistonCount : Integer = 8;
        attribute displacement : Real = 6.2;
        attribute compressionRatio : Real = 11.0;
        attribute currentPower : PowerValue;
        attribute currentSpeed : RotationalSpeed;
        attribute currentTorque : TorqueValue;
        attribute throttlePosition : PercentValue;
        attribute operatingTemp : TemperatureValue;
        attribute oilPressure : PressureValue;

        port fuelInput : FuelInPort;
        port airInput : AirInPort;
        port exhaustOutput : ExhaustOutPort;
        port powerOutput : MechPowerOutPort;
        port throttleCmd : ThrottleInPort;
        port feedbackOut : FeedbackOutPort;

        part combustionChambers : CombustionChamber[8];
        part pistons : Piston[8];
        part crankshaft : Crankshaft;
        part fuelInjectors : FuelInjector[8];
        part intakeManifold : IntakeManifold;
        part exhaustManifold : ExhaustManifold;

        // Internal connections
        connection fuelRail from fuelInput to fuelInjectors.fuelIn;
        connection intakeFeed from airInput to intakeManifold.airIn;
        connection intakeDist from intakeManifold.airOut to combustionChambers.airIn;
        connection fuelCharge from fuelInjectors.fuelIn to combustionChambers.fuelIn;
        connection exhaustCollect from combustionChambers.exhaustOut to exhaustManifold.exhaustIn;
        connection exhaustOut from exhaustManifold.exhaustOut to exhaustOutput;
        connection crankPower from crankshaft.powerOut to powerOutput;

        // Engine state machine
        state def EngineStates {
            entry action { /* initialize engine monitoring */ }

            state shutdown {
                entry action {
                    currentPower = 0.0;
                    currentSpeed = 0.0;
                    currentTorque = 0.0;
                    throttlePosition = 0.0;
                }
            }

            state starting {
                entry action {
                    currentSpeed = 200.0;
                    currentPower = 0.0;
                }
                do action { /* cranking and ignition sequence */ }
            }

            state idle {
                entry action {
                    currentPower = 25.0;
                    currentSpeed = 800.0;
                    currentTorque = 220.0;
                }
                do action { /* maintain stable idle */ }
            }

            state operating {
                entry action { /* enter full operating mode */ }

                state low {
                    entry action { /* low power range: 25–150 hp */ }
                }

                state medium {
                    entry action { /* medium power range: 150–350 hp */ }
                }

                state high {
                    entry action { /* high power range: 350–500 hp */ }
                }
            }

            transition from shutdown to starting
                when throttleCmd.cmd.position > 0.0;

            transition from starting to idle
                when currentSpeed >= 800.0;

            transition from idle to operating.low
                when throttlePosition > 20.0 and currentPower > 50.0;

            transition from operating.low to operating.medium
                when currentPower > 150.0;

            transition from operating.medium to operating.high
                when currentPower > 350.0;

            transition from operating.high to operating.medium
                when currentPower < 350.0;

            transition from operating.medium to operating.low
                when currentPower < 150.0;

            transition from operating.low to idle
                when throttlePosition < 10.0;

            transition from idle to shutdown
                when throttlePosition == 0.0;

            transition from operating to shutdown
                when throttlePosition == 0.0;
        }

        exhibit EngineStates;
    }

    // ============ Power Controller ============
    part def PowerController {
        attribute targetPower : PowerValue;
        attribute actualPower : PowerValue;
        attribute powerError : PowerValue;
        attribute throttleOutput : PercentValue;
        attribute controlGain : Real = 1.5;
        attribute deadband : PowerValue = 5.0;
        attribute sampleTime : Real = 0.01;
        attribute integralTerm : Real = 0.0;
        attribute integralGain : Real = 0.2;

        port setpointIn : SetpointInPort;
        port feedbackIn : FeedbackInPort;
        port throttleOut : ThrottleOutPort;

        action def ComputeError {
            in target : PowerValue;
            in actual : PowerValue;
            out error : PowerValue;
        }

        action def ComputeThrottle {
            in error : PowerValue;
            in gain : Real;
            in integral : Real;
            in currentThrottle : PercentValue;
            out newThrottle : PercentValue;
        }

        action def ControlLoop {
            action readSetpoint { /* read targetPower from setpointIn */ }
            action readFeedback { /* read actualPower from feedbackIn */ }
            action calcError : ComputeError {
                in target = targetPower;
                in actual = actualPower;
                out error = powerError;
            }
            action calcThrottle : ComputeThrottle {
                in error = powerError;
                in gain = controlGain;
                in integral = integralTerm;
                in currentThrottle = throttleOutput;
                out newThrottle = throttleOutput;
            }
            action sendThrottle { /* send throttleOutput to throttleOut */ }

            succession from readSetpoint to readFeedback;
            succession from readFeedback to calcError;
            succession from calcError to calcThrottle;
            succession from calcThrottle to sendThrottle;
        }

        state def ControllerStates {
            state initializing {
                entry action { throttleOutput = 0.0; }
            }

            state controlling {
                do action ControlLoop;
            }

            state faulted {
                entry action { throttleOutput = 0.0; }
            }

            transition from initializing to controlling
                when setpointIn.setpoint.targetPower > 0.0;

            transition from controlling to faulted
                when feedbackIn.feedback.actualPower < 0.0;

            transition from faulted to initializing
                when setpointIn.setpoint.targetPower == 0.0;
        }

        exhibit ControllerStates;
    }

    // ============ Load Device ============
    part def LoadDevice {
        attribute loadType : String = "propeller";
        attribute inputPower : PowerValue;
        attribute loadSpeed : RotationalSpeed;
        attribute loadTorque : TorqueValue;
        attribute transferEfficiency : EfficiencyValue = 92.0;
        attribute outputPower : PowerValue;
        attribute loadInertia : Real = 2.5;

        port powerInput : MechPowerInPort;

        attribute effectiveOutputPower : PowerValue = inputPower * transferEfficiency / 100.0;
    }

    // ============ Power Generation System ============
    part def PowerGenerationSystem {
        attribute systemRatedPower : PowerValue = 500.0;
        attribute overallEfficiency : EfficiencyValue;
        attribute systemActive : Boolean = false;
        attribute systemName : String = "PowerGen-500";

        port externalSetpoint : SetpointInPort;
        port externalLoad : MechPowerInPort;

        part powerPlant : PowerPlant;
        part powerController : PowerController;
        part loadDevice : LoadDevice;

        // System-level connections
        connection setpointConn from externalSetpoint to powerController.setpointIn;
        connection feedbackConn from powerPlant.feedbackOut to powerController.feedbackIn;
        connection throttleConn from powerController.throttleOut to powerPlant.throttleCmd;
        connection powerConn from powerPlant.powerOutput to loadDevice.powerInput;
        connection loadConn from loadDevice.powerInput to externalLoad;
    }

    // ============ Requirements ============
    requirement def RatedPowerRequirement {
        doc /* The power plant shall deliver 500 horsepower rated mechanical power. */
        subject powerPlant : PowerPlant;
        attribute minRatedPower : PowerValue = 500.0;
        require powerPlant.ratedPower >= minRatedPower;
    }

    requirement def PistonCountRequirement {
        doc /* The engine shall contain exactly eight pistons. */
        subject powerPlant : PowerPlant;
        attribute expectedPistonCount : Integer = 8;
        require powerPlant.pistonCount == expectedPistonCount;
    }

    requirement def ControlAccuracyRequirement {
        doc /* The controller shall regulate actual power within 5 hp of the target power. */
        subject controller : PowerController;
        attribute tolerance : PowerValue = 5.0;
        require abs(controller.targetPower - controller.actualPower) <= tolerance;
    }

    requirement def TransferEfficiencyRequirement {
        doc /* The mechanical power transfer to the load device shall be at least 90 percent efficient. */
        subject loadDevice : LoadDevice;
        attribute minEfficiency : EfficiencyValue = 90.0;
        require loadDevice.transferEfficiency >= minEfficiency;
    }

    requirement def StateLifecycleRequirement {
        doc /* The engine shall support shutdown, starting, idle, and operating states with low, medium, and high sub-states. */
        subject powerPlant : PowerPlant;
        require powerPlant.currentPower >= 0.0;
    }

    requirement def ThrottleResponseRequirement {
        doc /* The controller shall send throttle commands to increase, decrease, or maintain engine power based on the error between target and actual power. */
        subject controller : PowerController;
        require controller.throttleOutput >= 0.0 and controller.throttleOutput <= 100.0;
    }

    requirement def PowerGenerationSystemRequirement {
        doc /* The complete power generation system shall integrate a 500 hp eight-piston engine, an intelligent power controller, and a load device. */
        subject system : PowerGenerationSystem;

        requirement ratedPower : RatedPowerRequirement {
            subject powerPlant = system.powerPlant;
        }

        requirement pistonCount : PistonCountRequirement {
            subject powerPlant = system.powerPlant;
        }

        requirement controlAccuracy : ControlAccuracyRequirement {
            subject controller = system.powerController;
        }

        requirement transferEfficiency : TransferEfficiencyRequirement {
            subject loadDevice = system.loadDevice;
        }

        requirement stateLifecycle : StateLifecycleRequirement {
            subject powerPlant = system.powerPlant;
        }

        requirement throttleResponse : ThrottleResponseRequirement {
            subject controller = system.powerController;
        }
    }
}
