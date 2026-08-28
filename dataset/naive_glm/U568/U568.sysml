package SumpPumpSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value type Length :> ISQ::Length;
    value type Elevation :> ISQ::Length;
    value type Volume :> ISQ::Volume;
    value type FlowRate :> ISQ::VolumeFlowRate;
    value type Power :> ISQ::Power;
    value type Pressure :> ISQ::Pressure;
    value type Duration :> ISQ::Time;
    value type Level :> ISQ::Length;
    value type Efficiency :> Real;

    // ===== Items =====
    item def Fluid;

    // ===== Ports =====
    port def FluidPort {
        inout item fluid : Fluid;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    port def LevelSignalPort {
        attribute level : Level;
        attribute highSetpoint : Level;
        attribute lowSetpoint : Level;
        attribute highReached : Boolean;
        attribute lowReached : Boolean;
        attribute valid : Boolean;
    }

    port def CommandPort {
        attribute startCmd : Boolean;
        attribute stopCmd : Boolean;
        attribute ack : Boolean;
    }

    port def StatusPort {
        attribute running : Boolean;
        attribute fault : Boolean;
        attribute ready : Boolean;
    }

    // ===== Sump =====
    part def Sump {
        attribute capacity : Volume = 2.5 [m^3];
        attribute minSafeLevel : Level = 0.10 [m];
        attribute maxSafeLevel : Level = 1.80 [m];
        attribute currentLevel : Level = 0.10 [m];
        attribute elevation : Elevation = 0.0 [m];
        attribute inflowRate : FlowRate = 0.0008 [m^3/s];
        attribute outflowRate : FlowRate = 0.0 [m^3/s];

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port levelSignal : LevelSignalPort;

        action def UpdateLevel {
            in current : Level;
            in inflow : FlowRate;
            in outflow : FlowRate;
            in dt : Duration;
            out newLevel : Level;
        }

        action updateLevel : UpdateLevel {
            in current = currentLevel;
            in inflow = inflowRate;
            in outflow = outflowRate;
            in dt = 1.0 [s];
            out newLevel = currentLevel;
        }

        action def EvaluateSetpoints {
            in level : Level;
            in high : Level;
            in low : Level;
            out highFlag : Boolean;
            out lowFlag : Boolean;
        }

        action evaluateSetpoints : EvaluateSetpoints {
            in level = currentLevel;
            in high = levelSignal.highSetpoint;
            in low = levelSignal.lowSetpoint;
            out highFlag = levelSignal.highReached;
            out lowFlag = levelSignal.lowReached;
        }
    }

    // ===== Submersible Pump =====
    part def SubmersiblePump {
        attribute ratedPower : Power = 1500 [W];
        attribute ratedFlowRate : FlowRate = 0.006 [m^3/s];
        attribute ratedHead : Length = 10 [m];
        attribute efficiency : Efficiency = 0.75;
        attribute currentFlowRate : FlowRate = 0.0 [m^3/s];
        attribute faultFlag : Boolean = false;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port command : CommandPort;
        port status : StatusPort;

        action def RampUp {
            in target : FlowRate;
            out achieved : FlowRate;
        }

        action def RampDown {
            out achieved : FlowRate;
        }

        action def SteadyPump {
            in setpoint : FlowRate;
            out flowRate : FlowRate;
        }

        state machine PumpStateMachine {
            state off {
                entry { currentFlowRate = 0.0 [m^3/s]; status.running = false; status.ready = true; }
            }
            state starting {
                entry { status.ready = false; }
                do rampUp : RampUp {
                    in target = ratedFlowRate;
                    out achieved = currentFlowRate;
                }
            }
            state running {
                entry { status.running = true; }
                do steadyPump : SteadyPump {
                    in setpoint = ratedFlowRate;
                    out flowRate = currentFlowRate;
                }
            }
            state stopping {
                entry { status.running = false; }
                do rampDown : RampDown {
                    out achieved = currentFlowRate;
                }
            }
            state alarm {
                entry { status.fault = true; status.running = false; currentFlowRate = 0.0 [m^3/s]; }
                exit { status.fault = false; }
            }

            transition off to starting when command.startCmd == true and faultFlag == false;
            transition starting to running after 5 [s] when faultFlag == false;
            transition running to stopping when command.stopCmd == true;
            transition stopping to off after 3 [s];
            transition off to alarm when faultFlag == true;
            transition starting to alarm when faultFlag == true;
            transition running to alarm when faultFlag == true;
            transition alarm to off when faultFlag == false and command.stopCmd == true;
        }
    }

    // ===== Level Sensor =====
    part def LevelSensor {
        attribute highSetpoint : Level = 1.50 [m];
        attribute lowSetpoint : Level = 0.20 [m];
        attribute measuredLevel : Level = 0.10 [m];
        attribute highReached : Boolean = false;
        attribute lowReached : Boolean = false;
        attribute sensorValid : Boolean = true;

        port sumpPort : LevelSignalPort;
        port panelPort : LevelSignalPort;

        action def SenseLevel {
            in sumpLevel : Level;
            in high : Level;
            in low : Level;
            out highFlag : Boolean;
            out lowFlag : Boolean;
            out levelOut : Level;
        }

        action sense : SenseLevel {
            in sumpLevel = sumpPort.level;
            in high = highSetpoint;
            in low = lowSetpoint;
            out highFlag = highReached;
            out lowFlag = lowReached;
            out levelOut = measuredLevel;
        }

        action def TransmitSignal {
            in level : Level;
            in highFlag : Boolean;
            in lowFlag : Boolean;
            in valid : Boolean;
            out port : LevelSignalPort;
        }

        action transmit : TransmitSignal {
            in level = measuredLevel;
            in highFlag = highReached;
            in lowFlag = lowReached;
            in valid = sensorValid;
            out port = panelPort;
        }
    }

    // ===== Control Panel =====
    part def ControlPanel {
        attribute mode : String = "Automatic";
        attribute highSetpoint : Level = 1.50 [m];
        attribute lowSetpoint : Level = 0.20 [m];
        attribute startDelay : Duration = 2.0 [s];
        attribute stopDelay : Duration = 1.0 [s];

        port sensorPort : LevelSignalPort;
        port pumpCommand : CommandPort;
        port pumpStatus : StatusPort;

        action def EvaluateLevel {
            in level : Level;
            in high : Level;
            in low : Level;
            out startPump : Boolean;
            out stopPump : Boolean;
        }

        action evaluate : EvaluateLevel {
            in level = sensorPort.level;
            in high = highSetpoint;
            in low = lowSetpoint;
            out startPump = pumpCommand.startCmd;
            out stopPump = pumpCommand.stopCmd;
        }

        state machine ControlStateMachine {
            state idle {
                entry { pumpCommand.startCmd = false; pumpCommand.stopCmd = false; }
            }
            state monitoring {
                do evaluate : EvaluateLevel;
            }
            state pumpRunning {
                entry { pumpCommand.startCmd = true; }
                do evaluate : EvaluateLevel;
            }
            state faultHandling {
                entry { pumpCommand.stopCmd = true; }
            }

            transition idle to monitoring when mode == "Automatic";
            transition monitoring to pumpRunning when sensorPort.highReached == true and pumpStatus.fault == false;
            transition pumpRunning to monitoring when sensorPort.lowReached == true;
            transition monitoring to faultHandling when pumpStatus.fault == true;
            transition pumpRunning to faultHandling when pumpStatus.fault == true;
            transition faultHandling to idle when pumpStatus.fault == false and pumpStatus.ready == true;
        }
    }

    // ===== Discharge Pipe =====
    part def DischargePipe {
        attribute material : String = "Stainless Steel";
        attribute diameter : Length = 0.05 [m];
        attribute length : Length = 12 [m];
        attribute roughness : Real = 0.000045;
        attribute pressureDrop : Pressure = 0.0 [Pa];

        port inlet : FluidPort;
        port outlet : FluidPort;

        action def ComputePressureDrop {
            in flowRate : FlowRate;
            in length : Length;
            in diameter : Length;
            out drop : Pressure;
        }

        action computeDrop : ComputePressureDrop {
            in flowRate = inlet.flowRate;
            in length = length;
            in diameter = diameter;
            out drop = pressureDrop;
        }
    }

    // ===== Discharge Point =====
    part def DischargePoint {
        attribute elevation : Elevation = 8.0 [m];
        attribute location : String = "Storm Drain";
        attribute receivedVolume : Volume = 0.0 [m^3];

        port inlet : FluidPort;

        action def ReceiveFluid {
            in flowRate : FlowRate;
            in dt : Duration;
            out volume : Volume;
        }

        action receive : ReceiveFluid {
            in flowRate = inlet.flowRate;
            in dt = 1.0 [s];
            out volume = receivedVolume;
        }
    }

    // ===== System Assembly =====
    part def SumpPumpSystem {
        attribute systemName : String = "Automated Submersible Sump Pump System";
        attribute designHead : Length = 8.0 [m];
        attribute designFlowRate : FlowRate = 0.005 [m^3/s];

        part sump : Sump {
            redefines capacity = 2.5 [m^3];
            redefines maxSafeLevel = 1.80 [m];
            redefines minSafeLevel = 0.10 [m];
        }

        part pump : SubmersiblePump {
            redefines ratedPower = 1500 [W];
            redefines ratedFlowRate = 0.006 [m^3/s];
            redefines ratedHead = 10 [m];
        }

        part sensor : LevelSensor {
            redefines highSetpoint = 1.50 [m];
            redefines lowSetpoint = 0.20 [m];
        }

        part panel : ControlPanel {
            redefines highSetpoint = 1.50 [m];
            redefines lowSetpoint = 0.20 [m];
        }

        part pipe : DischargePipe {
            redefines length = 12 [m];
            redefines diameter = 0.05 [m];
        }

        part discharge : DischargePoint {
            redefines elevation = 8.0 [m];
        }

        // Fluid connections
        connection sumpToPump connect sump.fluidOutlet to pump.inlet;
        connection pumpToPipe connect pump.outlet to pipe.inlet;
        connection pipeToDischarge connect pipe.outlet to discharge.inlet;

        // Signal connections
        connection sumpToSensor connect sump.levelSignal to sensor.sumpPort;
        connection sensorToPanel connect sensor.panelPort to panel.sensorPort;
        connection panelToPumpCmd connect panel.pumpCommand to pump.command;
        connection pumpToPanelStatus connect pump.status to panel.pumpStatus;
    }

    // ===== Requirements =====
    requirement def MinFlowRateRequirement {
        attribute minFlowRate : FlowRate = 0.005 [m^3/s];
        subject pump : SubmersiblePump;
        require pump.ratedFlowRate >= minFlowRate;
    }

    requirement def DischargeHeightRequirement {
        attribute requiredHead : Length = 8.0 [m];
        subject pump : SubmersiblePump;
        require pump.ratedHead >= requiredHead;
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : Efficiency = 0.70;
        subject pump : SubmersiblePump;
        require pump.efficiency >= minEfficiency;
    }

    requirement def SumpCapacityRequirement {
        attribute minCapacity : Volume = 2.0 [m^3];
        subject sump : Sump;
        require sump.capacity >= minCapacity;
    }

    requirement def AutonomousOperationRequirement {
        subject panel : ControlPanel;
        require panel.mode == "Automatic";
    }

    requirement def OverflowPreventionRequirement {
        subject system : SumpPumpSystem;
        require system.sump.currentLevel <= system.sump.maxSafeLevel;
    }

    requirement def LevelControlRequirement {
        attribute highSetpoint : Level = 1.50 [m];
        attribute lowSetpoint : Level = 0.20 [m];
        subject sensor : LevelSensor;
        require sensor.highSetpoint == highSetpoint and sensor.lowSetpoint == lowSetpoint;
    }

    requirement def PumpStateRequirement {
        subject pump : SubmersiblePump;
        require pump.PumpStateMachine.states.Off.exists() and
               pump.PumpStateMachine.states.Starting.exists() and
               pump.PumpStateMachine.states.Running.exists() and
               pump.PumpStateMachine.states.Stopping.exists() and
               pump.PumpStateMachine.states.Alarm.exists();
    }

    // ===== Requirement Allocation =====
    part def SystemRequirements {
        requirement minFlow : MinFlowRateRequirement {
            subject redefines pump = SumpPumpSystem::pump;
        }
        requirement dischargeHeight : DischargeHeightRequirement {
            subject redefines pump = SumpPumpSystem::pump;
        }
        requirement efficiency : EfficiencyRequirement {
            subject redefines pump = SumpPumpSystem::pump;
        }
        requirement capacity : SumpCapacityRequirement {
            subject redefines sump = SumpPumpSystem::sump;
        }
        requirement autonomous : AutonomousOperationRequirement {
            subject redefines panel = SumpPumpSystem::panel;
        }
        requirement overflowPrevention : OverflowPreventionRequirement {
            subject redefines system = SumpPumpSystem;
        }
        requirement levelControl : LevelControlRequirement {
            subject redefines sensor = SumpPumpSystem::sensor;
        }
        requirement pumpStates : PumpStateRequirement {
            subject redefines pump = SumpPumpSystem::pump;
        }
    }

    // ===== Verification =====
    verification def VerifyFlowRate {
        subject pump : SubmersiblePump;
        objective {
            require pump.ratedFlowRate >= 0.005 [m^3/s];
        }
    }

    verification def VerifyHead {
        subject pump : SubmersiblePump;
        objective {
            require pump.ratedHead >= 8.0 [m];
        }
    }

    verification def VerifyAutonomousCycle {
        subject system : SumpPumpSystem;
        objective {
            require system.panel.mode == "Automatic";
            require system.sensor.highSetpoint == 1.50 [m];
            require system.sensor.lowSetpoint == 0.20 [m];
        }
    }
}
