package PaddleWheelSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types
    // ============================================================

    value type VolumetricFlowRate :> Real {
        :>> unit = "m^3/s";
    }

    value type RotationalSpeed :> Real {
        :>> unit = "rpm";
    }

    value type Torque :> Real {
        :>> unit = "N*m";
    }

    value type MechanicalPower :> Real {
        :>> unit = "W";
    }

    value type Length :> Real {
        :>> unit = "m";
    }

    value type Force :> Real {
        :>> unit = "N";
    }

    value type Angle :> Real {
        :>> unit = "degree";
    }

    value type Mass :> Real {
        :>> unit = "kg";
    }

    // ============================================================
    // Enumerations
    // ============================================================

    enum def ControlCommand {
        START;
        STOP;
        EMERGENCY_STOP;
    }

    enum def LoadCondition {
        LOW;
        NORMAL;
        HIGH;
    }

    enum def OperationalState {
        IDLE;
        STARTUP;
        OPERATING;
        SHUTDOWN;
        EMERGENCY_SHUTDOWN;
        FAULTED;
    }

    // ============================================================
    // Items
    // ============================================================

    item def Water;

    // ============================================================
    // Ports
    // ============================================================

    port def WaterInletPort {
        in item water : Water;
        attribute flowRate : VolumetricFlowRate;
    }

    port def WaterOutletPort {
        out item water : Water;
        attribute flowRate : VolumetricFlowRate;
    }

    port def MechanicalPowerPort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute power : MechanicalPower;
    }

    port def ControlInterfacePort {
        in attribute command : ControlCommand;
        out attribute state : OperationalState;
        out attribute speed : RotationalSpeed;
        out attribute torque : Torque;
        out attribute power : MechanicalPower;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================

    part def CentralAxle {
        attribute material : String = "Carbon Steel";
        attribute diameter : Length = 0.3 [m];
        attribute axleLength : Length = 6.0 [m];
        attribute maxTorque : Torque = 50000 [N*m];
        attribute maxForce : Force = 500000 [N];
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
        attribute currentTorque : Torque = 0 [N*m];

        port inputEnd : MechanicalPowerPort;
        port outputEnd : MechanicalPowerPort;
    }

    part def Hub {
        attribute material : String = "Cast Iron";
        attribute outerDiameter : Length = 0.8 [m];
        attribute innerDiameter : Length = 0.3 [m];
        attribute hubLength : Length = 0.6 [m];
        attribute paddleMountCount : Integer = 16;

        port axleInterface : MechanicalPowerPort;
    }

    part def Paddle {
        attribute paddleNumber : Integer;
        attribute material : String = "Reinforced Steel";
        attribute paddleLength : Length = 2.1 [m];
        attribute paddleWidth : Length = 1.5 [m];
        attribute paddleAngle : Angle = 30 [degree];
    }

    part def SupportFrame {
        attribute material : String = "Reinforced Steel";
        attribute frameHeight : Length = 7.0 [m];
        attribute frameWidth : Length = 8.0 [m];
        attribute frameDepth : Length = 3.0 [m];
        attribute maxLoad : Force = 1000000 [N];
    }

    part def BearingAssembly {
        attribute bearingType : String = "Heavy-Duty Roller";
        attribute loadCapacity : Force = 250000 [N];
        attribute innerDiameter : Length = 0.3 [m];
        attribute outerDiameter : Length = 0.5 [m];
        attribute lubricationType : String = "Grease";
    }

    part def Wheel {
        attribute wheelDiameter : Length = 5.0 [m];
        attribute paddleCount : Integer = 16;
        attribute material : String = "Reinforced Steel";
        attribute currentRotationalSpeed : RotationalSpeed = 0 [rpm];

        part hub : Hub;
        part paddles[16] : Paddle;

        port powerOutput : MechanicalPowerPort;
    }

    // ============================================================
    // State Machine Definition
    // ============================================================

    state def PaddleWheelStateMachine {
        state Idle {
            entry {
                currentSpeed := 0 [rpm];
                currentTorque := 0 [N*m];
                currentPower := 0 [W];
                loadCondition := LoadCondition::NORMAL;
            }
        }

        state Startup {
            entry {
                systemState := OperationalState::STARTUP;
            }
        }

        state Operating {
            entry {
                systemState := OperationalState::OPERATING;
            }

            state LowLoad {
                entry {
                    loadCondition := LoadCondition::LOW;
                }
            }

            state NormalLoad {
                entry {
                    loadCondition := LoadCondition::NORMAL;
                }
            }

            state HighLoad {
                entry {
                    loadCondition := LoadCondition::HIGH;
                }
            }

            transition initial to NormalLoad;
            transition from LowLoad to NormalLoad
                when measuredFlowRate >= 2.0 [m^3/s];
            transition from NormalLoad to LowLoad
                when measuredFlowRate < 2.0 [m^3/s];
            transition from NormalLoad to HighLoad
                when measuredFlowRate > 5.0 [m^3/s];
            transition from HighLoad to NormalLoad
                when measuredFlowRate <= 5.0 [m^3/s];
        }

        state Shutdown {
            entry {
                systemState := OperationalState::SHUTDOWN;
            }
        }

        state EmergencyShutdown {
            entry {
                systemState := OperationalState::EMERGENCY_SHUTDOWN;
            }
        }

        state Faulted {
            entry {
                systemState := OperationalState::FAULTED;
            }
        }

        transition initial to Idle;
        transition from Idle to Startup
            when command == ControlCommand::START;
        transition from Startup to Operating
            when currentSpeed >= startupTargetSpeed;
        transition from Operating to Shutdown
            when command == ControlCommand::STOP;
        transition from Shutdown to Idle
            when currentSpeed <= 0.1 [rpm];
        transition from Operating to EmergencyShutdown
            when currentSpeed > overspeedLimit
            || currentTorque > overloadLimit
            || command == ControlCommand::EMERGENCY_STOP;
        transition from EmergencyShutdown to Faulted
            when currentSpeed <= 0.0 [rpm];
        transition from Faulted to Idle
            when command == ControlCommand::START;
    }

    // ============================================================
    // Main System Definition
    // ============================================================

    part def PaddleWheelSystem {
        // External ports
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port powerOutput : MechanicalPowerPort;
        port controlPort : ControlInterfacePort;

        // Internal parts
        part wheel : Wheel;
        part axle : CentralAxle;
        part frame : SupportFrame;
        part bearings[2] : BearingAssembly;

        // Connections
        connect wheel.hub.axleInterface to axle.inputEnd;
        connect axle.outputEnd to powerOutput;
        connect wheel.powerOutput to axle.inputEnd;
        connect waterInlet to waterOutlet;

        // Operating attributes
        attribute command : ControlCommand;
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
        attribute currentTorque : Torque = 0 [N*m];
        attribute currentPower : MechanicalPower = 0 [W];
        attribute measuredFlowRate : VolumetricFlowRate = 0 [m^3/s];
        attribute loadCondition : LoadCondition = LoadCondition::NORMAL;
        attribute systemState : OperationalState = OperationalState::IDLE;

        // Design parameters
        attribute designFlowMin : VolumetricFlowRate = 0.5 [m^3/s];
        attribute designFlowMax : VolumetricFlowRate = 10.0 [m^3/s];
        attribute maxOperatingSpeed : RotationalSpeed = 30 [rpm];
        attribute maxOperatingTorque : Torque = 50000 [N*m];
        attribute maxPower : MechanicalPower = 150000 [W];
        attribute overspeedLimit : RotationalSpeed = 36 [rpm];
        attribute overloadLimit : Torque = 60000 [N*m];
        attribute startupTargetSpeed : RotationalSpeed = 24 [rpm];

        // State machine
        state machine : PaddleWheelStateMachine;

        // Behaviors
        action computePower {
            currentPower := currentTorque * currentSpeed * 0.10472;
        }

        action monitorSafety {
            if currentSpeed > overspeedLimit {
                systemState := OperationalState::EMERGENCY_SHUTDOWN;
            }
            if currentTorque > overloadLimit {
                systemState := OperationalState::EMERGENCY_SHUTDOWN;
            }
        }

        action updateLoadCondition {
            if measuredFlowRate < 2.0 [m^3/s] {
                loadCondition := LoadCondition::LOW;
            } else if measuredFlowRate <= 5.0 [m^3/s] {
                loadCondition := LoadCondition::NORMAL;
            } else {
                loadCondition := LoadCondition::HIGH;
            }
        }

        action rampUpSpeed {
            if currentSpeed < maxOperatingSpeed {
                currentSpeed := currentSpeed + 1.0 [rpm];
            }
        }

        action rampDownSpeed {
            if currentSpeed > 0.0 [rpm] {
                currentSpeed := currentSpeed - 0.5 [rpm];
            }
        }

        action rapidStop {
            currentSpeed := 0 [rpm];
            currentTorque := 0 [N*m];
            currentPower := 0 [W];
        }
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def FlowRateRange {
        subject system : PaddleWheelSystem;
        attribute minFlow : VolumetricFlowRate = 0.5 [m^3/s];
        attribute maxFlow : VolumetricFlowRate = 10.0 [m^3/s];
        assert {
            system.designFlowMin == minFlow;
            system.designFlowMax == maxFlow;
        }
    }

    requirement def WheelDiameter5m {
        subject system : PaddleWheelSystem;
        attribute requiredDiameter : Length = 5.0 [m];
        assert {
            system.wheel.wheelDiameter == requiredDiameter;
        }
    }

    requirement def PaddleCount16 {
        subject system : PaddleWheelSystem;
        attribute requiredCount : Integer = 16;
        assert {
            system.wheel.paddleCount == requiredCount;
        }
    }

    requirement def SafetyMonitoring {
        subject system : PaddleWheelSystem;
        assert {
            system.overspeedLimit > system.maxOperatingSpeed;
            system.overloadLimit > system.maxOperatingTorque;
        }
    }

    requirement def AxleCarbonSteel {
        subject system : PaddleWheelSystem;
        assert {
            system.axle.material == "Carbon Steel";
        }
    }

    requirement def FrameReinforcedSteel {
        subject system : PaddleWheelSystem;
        assert {
            system.frame.material == "Reinforced Steel";
        }
    }

    requirement def BearingCapacity {
        subject system : PaddleWheelSystem;
        attribute minBearingLoad : Force = 200000 [N];
        assert {
            system.bearings[1].loadCapacity >= minBearingLoad;
            system.bearings[2].loadCapacity >= minBearingLoad;
        }
    }

    requirement def PowerGeneration {
        subject system : PaddleWheelSystem;
        assert {
            system.currentPower >= 0 [W];
        }
    }

    requirement def EmergencyShutdownCapability {
        subject system : PaddleWheelSystem;
        assert {
            system.overspeedLimit == 36 [rpm];
            system.overloadLimit == 60000 [N*m];
        }
    }

    requirement def StateManagement {
        subject system : PaddleWheelSystem;
        assert {
            system.systemState == OperationalState::IDLE
            || system.systemState == OperationalState::STARTUP
            || system.systemState == OperationalState::OPERATING
            || system.systemState == OperationalState::SHUTDOWN
            || system.systemState == OperationalState::EMERGENCY_SHUTDOWN
            || system.systemState == OperationalState::FAULTED;
        }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================

    satisfaction def FlowRateSatisfaction : FlowRateRange {
        subject system = paddleWheel;
    }

    satisfaction def WheelDiameterSatisfaction : WheelDiameter5m {
        subject system = paddleWheel;
    }

    satisfaction def PaddleCountSatisfaction : PaddleCount16 {
        subject system = paddleWheel;
    }

    satisfaction def SafetySatisfaction : SafetyMonitoring {
        subject system = paddleWheel;
    }

    satisfaction def AxleMaterialSatisfaction : AxleCarbonSteel {
        subject system = paddleWheel;
    }

    satisfaction def FrameMaterialSatisfaction : FrameReinforcedSteel {
        subject system = paddleWheel;
    }

    satisfaction def BearingSatisfaction : BearingCapacity {
        subject system = paddleWheel;
    }

    // ============================================================
    // System Instance
    // ============================================================

    part paddleWheel : PaddleWheelSystem {
        redefinition wheel.hub.material = "Cast Iron";
        redefinition axle.material = "Carbon Steel";
        redefinition frame.material = "Reinforced Steel";
        redefinition bearings[1].bearingType = "Heavy-Duty Roller";
        redefinition bearings[2].bearingType = "Heavy-Duty Roller";
    }

}
