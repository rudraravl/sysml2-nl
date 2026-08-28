package SumpPumpSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type Length :> Real { unit 'm'; }
    value type Diameter :> Real { unit 'm'; }
    value type Volume :> Real { RealUnit 'm3'; }
    value type VolumetricFlowRate :> Real { unit 'm3/s'; }
    value type Pressure :> Real { unit 'Pa'; }
    value type LiquidLevel :> Real { unit 'm'; }
    value type ElectricPower :> Real { unit 'W'; }
    value type AngularVelocity :> Real { unit 'rad/s'; }
    value type Threshold :> LiquidLevel;

    // ---- Item Definitions ----
    item def Water;
    item def Fluid :> Water;

    // ---- Port Definitions ----
    port def FluidFlowPort {
        attribute isInput : Boolean;
        flow of Fluid;
    }

    port def ElectricPowerPort {
        attribute active : Boolean;
        in power : ElectricPower;
    }

    port def ControlSignalPort {
        attribute commandOn : Boolean;
    }

    // ---- Sump Basin ----
    part def SumpBasin {
        attribute capacity : Volume = 0.5 [m3];
        attribute highThreshold : Threshold = 0.45 [m];
        attribute lowThreshold : Threshold = 0.10 [m];
        attribute currentLevel : LiquidLevel = 0.0 [m];
        attribute crossSectionArea : Real = 0.25 [m2];

        port basinOutlet : FluidFlowPort {
            attribute isInput = false;
        }

        item storedFluid : Fluid;

        action def AccumulateFluid {
            in inflowRate : VolumetricFlowRate;
            update currentLevel := currentLevel + (inflowRate * 1.0 [s]) / crossSectionArea;
        }

        action def EvacuateFluid {
            in outflowRate : VolumetricFlowRate;
            update currentLevel := currentLevel - (outflowRate * 1.0 [s]) / crossSectionArea;
        }
    }

    // ---- Float Switch ----
    part def FloatSwitch {
        attribute triggered : Boolean = false;
        attribute highLevel : Threshold;
        attribute lowLevel : Threshold;

        port sensorInput : ControlSignalPort;
        port pumpControl : ControlSignalPort;

        action def SenseLevel {
            in level : LiquidLevel;
            if level >= highLevel then {
                assign triggered := true;
            } else if level <= lowLevel then {
                assign triggered := false;
            }
            assign pumpControl.commandOn := triggered;
        }
    }

    // ---- Electric Motor ----
    part def ElectricMotor {
        attribute ratedPower : ElectricPower = 750 [W];
        attribute running : Boolean = false;
        attribute shaftSpeed : AngularVelocity = 0 [rad/s];

        port powerIn : ElectricPowerPort;
        port controlIn : ControlSignalPort;
        port mechanicalOut : ControlSignalPort;

        action def Run {
            if controlIn.commandOn == true then {
                assign running := true;
                assign shaftSpeed := 314.16 [rad/s];
                assign mechanicalOut.commandOn := true;
            } else {
                assign running := false;
                assign shaftSpeed := 0 [rad/s];
                assign mechanicalOut.commandOn := false;
            }
        }
    }

    // ---- Impeller ----
    part def Impeller {
        attribute bladeCount : Integer = 6;
        attribute dischargePressure : Pressure = 0 [Pa];
        attribute flowRate : VolumetricFlowRate = 0 [m3/s];

        port driveInput : ControlSignalPort;
        port fluidIn : FluidFlowPort {
            attribute isInput = true;
        }
        port fluidOut : FluidFlowPort {
            attribute isInput = false;
        }

        action def PumpFluid {
            if driveInput.commandOn == true then {
                assign dischargePressure := 120000 [Pa];
                assign flowRate := 0.002 [m3/s];
            } else {
                assign dischargePressure := 0 [Pa];
                assign flowRate := 0 [m3/s];
            }
        }
    }

    // ---- Check Valve ----
    part def CheckValve {
        attribute open : Boolean = false;

        port inlet : FluidFlowPort {
            attribute isInput = true;
        }
        port outlet : FluidFlowPort {
            attribute isInput = false;
        }

        action def RegulateFlow {
            if inlet.flow != null and inlet.flow.quantity > 0 then {
                assign open := true;
                assign outlet.flow := inlet.flow;
            } else {
                assign open := false;
                assign outlet.flow := null;
            }
        }
    }

    // ---- Sump Pump Assembly ----
    part def SumpPump {
        attribute manufacturer : String = "AquaGuard";
        attribute model : String = "SP-1000";

        part motor : ElectricMotor {
            attribute ratedPower = 750 [W];
        }
        part impeller : Impeller;
        part floatSwitch : FloatSwitch;
        part checkValve : CheckValve;

        port pumpIntake : FluidFlowPort {
            attribute isInput = true;
        }
        port pumpDischarge : FluidFlowPort {
            attribute isInput = false;
        }
        port powerConnection : ElectricPowerPort;
        port levelSensorPort : ControlSignalPort;

        connection motorToImpeller connect motor.mechanicalOut to impeller.driveInput;
        connection impellerToValve connect impeller.fluidOut to checkValve.inlet;
        connection intakeToImpeller connect pumpIntake to impeller.fluidIn;
        connection valveToDischarge connect checkValve.outlet to pumpDischarge;
        connection powerToMotor connect powerConnection to motor.powerIn;
        connection controlToMotor connect floatSwitch.pumpControl to motor.controlIn;
        connection levelToFloat connect levelSensorPort to floatSwitch.sensorInput;
    }

    // ---- Discharge Pipe ----
    part def DischargePipe {
        attribute length : Length = 10.0 [m];
        attribute diameter : Diameter = 0.040 [m];
        attribute material : String = "PVC";
        attribute frictionLoss : Pressure = 5000 [Pa];

        port pipeInlet : FluidFlowPort {
            attribute isInput = true;
        }
        port pipeOutlet : FluidFlowPort {
            attribute isInput = false;
        }

        action def TransportFluid {
            assign pipeOutlet.flow := pipeInlet.flow;
        }
    }

    // ---- Discharge Point ----
    part def DischargePoint {
        attribute location : String = "Storm Drain";
        attribute elevation : Length = 0.5 [m];

        port dischargeInlet : FluidFlowPort {
            attribute isInput = true;
        }

        item expelledFluid : Fluid;

        action def ReceiveFluid {
            assign expelledFluid := dischargeInlet.flow;
        }
    }

    // ---- Sump Pumping System ----
    part def SumpPumpingSystem {
        attribute systemId : String = "SPS-001";

        part basin : SumpBasin {
            attribute capacity = 0.5 [m3];
            attribute highThreshold = 0.45 [m];
            attribute lowThreshold = 0.10 [m];
        }
        part pump : SumpPump;
        part pipe : DischargePipe {
            attribute length = 10.0 [m];
            attribute diameter = 0.040 [m];
        }
        part discharge : DischargePoint;

        connection basinToPump connect basin.basinOutlet to pump.pumpIntake;
        connection pumpToPipe connect pump.pumpDischarge to pipe.pipeInlet;
        connection pipeToDischarge connect pipe.pipeOutlet to discharge.dischargeInlet;
        connection levelFeedback connect basin.basinOutlet to pump.levelSensorPort;

        state machine PumpingOperation {
            entry action {
                pump.floatSwitch.highLevel := basin.highThreshold;
                pump.floatSwitch.lowLevel := basin.lowThreshold;
            }

            state Idle {
                entry action {
                    pump.motor.running := false;
                    pump.checkValve.open := false;
                }
                do action MonitorRisingLevel {
                    if basin.currentLevel >= basin.highThreshold then {
                        send PumpStart to pump.floatSwitch.sensorInput;
                    }
                }
                transition Idle to Pumping
                    when basin.currentLevel >= basin.highThreshold
                    do action send StartCommand to pump.floatSwitch.sensorInput;
            }

            state Pumping {
                entry action {
                    pump.motor.running := true;
                    pump.impeller.PumpFluid();
                    pump.checkValve.RegulateFlow();
                    pipe.TransportFluid();
                    discharge.ReceiveFluid();
                    basin.EvacuateFluid(pump.impeller.flowRate);
                }
                do action ContinueEvacuation {
                    basin.EvacuateFluid(pump.impeller.flowRate);
                }
                transition Pumping to Idle
                    when basin.currentLevel <= basin.lowThreshold
                    do action send StopCommand to pump.floatSwitch.sensorInput;
            }
        }
    }

    // ---- Requirements ----
    requirement def PreventFlooding {
        doc "The system shall prevent flooding by removing accumulated fluid from the basin before overflow occurs.";
        subject : SumpPumpingSystem;
        objective {
            basin.currentLevel < basin.capacity / basin.crossSectionArea;
        }
    }

    requirement def AutoActivation {
        doc "The pump shall activate automatically when the fluid level reaches the high threshold.";
        subject : SumpPump;
        attribute highThreshold : Threshold;
        satisfy when basin.currentLevel >= highThreshold then pump.motor.running == true;
    }

    requirement def AutoDeactivation {
        doc "The pump shall deactivate automatically when the fluid level reaches the low threshold.";
        subject : SumpPump;
        attribute lowThreshold : Threshold;
        satisfy when basin.currentLevel <= lowThreshold then pump.motor.running == false;
    }

    requirement def BackflowPrevention {
        doc "The check valve shall prevent fluid from flowing back into the basin when the pump is not running.";
        subject : CheckValve;
        satisfy when pump.motor.running == false then checkValve.open == false;
    }

    requirement def DischargeCapacity {
        doc "The pump shall evacuate fluid at a rate sufficient to lower the basin level from high to low threshold within 5 minutes.";
        subject : SumpPump;
        attribute requiredFlowRate : VolumetricFlowRate = 0.002 [m3/s];
        satisfy pump.impeller.flowRate >= requiredFlowRate;
    }

    requirement def SafeDischargeLocation {
        doc "The discharge point shall direct fluid to a location safely away from the building foundation.";
        subject : DischargePoint;
        attribute minDistance : Length = 3.0 [m];
        satisfy discharge.elevation >= 0.3 [m];
    }

    requirement SumpSystemRequirements :> PreventFlooding {
        subject : SumpPumpingSystem = system;
        part system : SumpPumpingSystem;

        requirement autoActivate :> AutoActivation {
            subject : SumpPump = system.pump;
        }
        requirement autoDeactivate :> AutoDeactivation {
            subject : SumpPump = system.pump;
        }
        requirement noBackflow :> BackflowPrevention {
            subject : CheckValve = system.pump.checkValve;
        }
        requirement adequateFlow :> DischargeCapacity {
            subject : SumpPump = system.pump;
        }
        requirement safeDischarge :> SafeDischargeLocation {
            subject : DischargePoint = system.discharge;
        }
    }

    // ---- Instantiation ----
    part sumpSystem : SumpPumpingSystem {
        attribute systemId = "SPS-001";
        part basin {
            attribute capacity = 0.5 [m3];
            attribute highThreshold = 0.45 [m];
            attribute lowThreshold = 0.10 [m];
        }
        part pump {
            attribute manufacturer = "AquaGuard";
            attribute model = "SP-1000";
            part motor {
                attribute ratedPower = 750 [W];
            }
            part floatSwitch {
                attribute highLevel = 0.45 [m];
                attribute lowLevel = 0.10 [m];
            }
        }
        part pipe {
            attribute length = 10.0 [m];
            attribute diameter = 0.040 [m];
            attribute material = "PVC";
        }
        part discharge {
            attribute location = "Storm Drain";
            attribute elevation = 0.5 [m];
        }
    }

}
