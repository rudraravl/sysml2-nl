package FloatSwitchSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length;
    attribute def Volume;
    attribute def Mass;
    attribute def Time;
    attribute def ElectricPotential;
    attribute def ElectricCurrent;
    attribute def Resistance;
    attribute def Force;
    attribute def Pressure;

    enum def SwitchPosition {
        enum open;
        enum closed;
    }

    enum def LiquidLevelCondition {
        enum belowSetPoint;
        enum atSetPoint;
        enum aboveSetPoint;
    }

    enum def ContactHealth {
        enum normal;
        enum stuckOpen;
        enum stuckClosed;
        enum degraded;
    }

    enum def MountingOrientation {
        enum vertical;
        enum horizontal;
    }

    enum def ControlSignalState {
        enum inactive;
        enum active;
        enum fault;
    }

    item def Liquid {
        attribute density : MassPerVolume;
        attribute temperature : TemperatureValue;
        attribute conductivity : Conductance;
    }

    item def ElectricalSignal {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute state : ControlSignalState;
    }

    item def MechanicalMotion {
        attribute displacement : Length;
        attribute force : Force;
    }

    item def LevelIndication {
        attribute measuredLevel : Length;
        attribute condition : LiquidLevelCondition;
        attribute valid : Boolean;
    }

    port def LiquidInterfacePort {
        in item liquid : Liquid;
        in item hydrostaticLevel : LevelIndication;
    }

    port def MechanicalMotionPort {
        out item motion : MechanicalMotion;
    }

    port def SwitchContactPort {
        in item supplySignal : ElectricalSignal;
        out item switchedSignal : ElectricalSignal;
    }

    port def ControllerSignalPort {
        out item levelSignal : ElectricalSignal;
        out item levelIndication : LevelIndication;
    }

    port def PumpCommandPort {
        in item commandSignal : ElectricalSignal;
    }

    part def FloatSwitchAssembly {
        attribute setPointLevel : Length;
        attribute hysteresisBand : Length;
        attribute maximumLiquidLevel : Length;
        attribute minimumLiquidLevel : Length;
        attribute ratedVoltage : ElectricPotential;
        attribute ratedCurrent : ElectricCurrent;
        attribute contactResistance : Resistance;
        attribute responseTime : Time;
        attribute mountingOrientation : MountingOrientation;
        attribute contactHealth : ContactHealth;
        attribute currentSwitchPosition : SwitchPosition;
        attribute currentLevelCondition : LiquidLevelCondition;

        port liquidPort : LiquidInterfacePort;
        port contactPort : SwitchContactPort;
        port controllerPort : ControllerSignalPort;

        part float : BuoyantFloat {
            attribute buoyancyMargin : Real = 1.25;
            attribute diameter : Length;
            attribute travelLimit : Length;
        }

        part lever : PivotLever {
            attribute armLength : Length;
            attribute pivotFriction : Force;
        }

        part magnet : ActuatingMagnet {
            attribute magneticPullForce : Force;
        }

        part reedContact : ReedSwitchContact {
            attribute normallyOpen : Boolean;
            attribute closedResistance : Resistance;
            attribute insulationResistance : Resistance;
        }

        part cable : ElectricalCable {
            attribute conductorCount : Integer = 2;
            attribute conductorResistance : Resistance;
            attribute insulationVoltageRating : ElectricPotential;
        }

        connect liquidPort.hydrostaticLevel to float.levelInput;
        connect float.motionOut to lever.motionIn;
        connect lever.motionOut to magnet.motionIn;
        connect magnet.motionOut to reedContact.actuationIn;
        connect contactPort.supplySignal to reedContact.inputSignal;
        connect reedContact.outputSignal to cable.inputSignal;
        connect cable.outputSignal to contactPort.switchedSignal;
        connect cable.outputSignal to controllerPort.levelSignal;

        action senseLiquidLevel {
            in item sensedLevel : LevelIndication;
            out item levelCondition : LevelIndication;

            first start;
            then compareToSetPoint;

            action compareToSetPoint {
                in item sensedLevel;
                out item levelCondition;
            }

            then publishLevelCondition;
            action publishLevelCondition {
                out item levelCondition;
            }

            then done;
        }

        action convertBuoyancyToContactState {
            in item levelCondition : LevelIndication;
            out item commandedPosition : SwitchPosition;

            first evaluateFloatLift;
            then transferMotion;
            then actuateContact;
            then done;

            action evaluateFloatLift;
            action transferMotion;
            action actuateContact;
        }

        action switchElectricalCircuit {
            in item supply : ElectricalSignal;
            in item commandedPosition : SwitchPosition;
            out item switched : ElectricalSignal;

            first receiveSupply;
            then setContactState;
            then routeSignal;
            then done;

            action receiveSupply;
            action setContactState;
            action routeSignal;
        }

        state def FloatSwitchOperatingState {
            entry action initializeContact {
                out item initialSignal : ElectricalSignal;
            }

            state BelowTripLevel;
            state RisingThroughSetPoint;
            state AboveTripLevel;
            state FallingThroughResetPoint;
            state ContactFault;

            transition first BelowTripLevel;

            transition BelowTripLevel_to_RisingThroughSetPoint
                first BelowTripLevel
                accept when currentLevelCondition == LiquidLevelCondition::atSetPoint
                then RisingThroughSetPoint;

            transition RisingThroughSetPoint_to_AboveTripLevel
                first RisingThroughSetPoint
                accept when currentLevelCondition == LiquidLevelCondition::aboveSetPoint
                do convertBuoyancyToContactState
                then AboveTripLevel;

            transition AboveTripLevel_to_FallingThroughResetPoint
                first AboveTripLevel
                accept when currentLevelCondition == LiquidLevelCondition::atSetPoint
                then FallingThroughResetPoint;

            transition FallingThroughResetPoint_to_BelowTripLevel
                first FallingThroughResetPoint
                accept when currentLevelCondition == LiquidLevelCondition::belowSetPoint
                do convertBuoyancyToContactState
                then BelowTripLevel;

            transition Any_to_ContactFault
                first BelowTripLevel
                accept when contactHealth != ContactHealth::normal
                then ContactFault;
        }

        perform action senseLiquidLevel;
        perform action convertBuoyancyToContactState;
        perform action switchElectricalCircuit;
    }

    part def BuoyantFloat {
        attribute volume : Volume;
        attribute mass : Mass;
        attribute diameter : Length;
        attribute materialDensity : MassPerVolume;
        attribute maximumTravel : Length;

        port levelInput : LiquidInterfacePort;
        port motionOut : MechanicalMotionPort;
    }

    part def PivotLever {
        attribute armLength : Length;
        attribute pivotAngle : PlaneAngle;
        attribute mechanicalAdvantage : Real;

        port motionIn : MechanicalMotionPort;
        port motionOut : MechanicalMotionPort;
    }

    part def ActuatingMagnet {
        attribute magneticPullForce : Force;
        attribute actuationGap : Length;

        port motionIn : MechanicalMotionPort;
        port motionOut : MechanicalMotionPort;
    }

    part def ReedSwitchContact {
        attribute normallyOpen : Boolean;
        attribute position : SwitchPosition;
        attribute closedResistance : Resistance;
        attribute openCircuitResistance : Resistance;
        attribute maximumSwitchingVoltage : ElectricPotential;
        attribute maximumSwitchingCurrent : ElectricCurrent;

        port actuationIn : MechanicalMotionPort;
        in item inputSignal : ElectricalSignal;
        out item outputSignal : ElectricalSignal;
    }

    part def ElectricalCable {
        attribute length : Length;
        attribute conductorResistance : Resistance;
        attribute insulationVoltageRating : ElectricPotential;

        in item inputSignal : ElectricalSignal;
        out item outputSignal : ElectricalSignal;
    }

    part def StorageTank {
        attribute tankCapacity : Volume;
        attribute tankHeight : Length;
        attribute liquidLevel : Length;
        attribute maximumSafeLevel : Length;
        attribute minimumSafeLevel : Length;

        port liquidStatusPort : LiquidInterfacePort;

        part containedLiquid : Liquid {
            attribute density = 1000 [kg/m^3];
            attribute temperature = 293.15 [K];
        }
    }

    part def PumpController {
        attribute inputThresholdVoltage : ElectricPotential;
        attribute commandVoltage : ElectricPotential;
        attribute lastReceivedSignalState : ControlSignalState;

        port floatSwitchInput : ControllerSignalPort;
        port pumpCommand : PumpCommandPort;

        action interpretFloatSwitchSignal {
            in item levelSignal : ElectricalSignal;
            out item levelIndication : LevelIndication;
            out item pumpCommandSignal : ElectricalSignal;

            first readSignal;
            then classifyLevel;
            then issueCommand;
            then done;

            action readSignal;
            action classifyLevel;
            action issueCommand;
        }

        state def PumpControlState {
            state PumpOff;
            state PumpOn;
            state FaultLatched;

            transition first PumpOff;

            transition PumpOff_to_PumpOn
                first PumpOff
                accept when lastReceivedSignalState == ControlSignalState::active
                do interpretFloatSwitchSignal
                then PumpOn;

            transition PumpOn_to_PumpOff
                first PumpOn
                accept when lastReceivedSignalState == ControlSignalState::inactive
                do interpretFloatSwitchSignal
                then PumpOff;

            transition Any_to_FaultLatched
                first PumpOff
                accept when lastReceivedSignalState == ControlSignalState::fault
                then FaultLatched;
        }

        perform action interpretFloatSwitchSignal;
    }

    part def DrainPump {
        attribute ratedFlowRate : VolumePerTime;
        attribute ratedPower : Power;
        attribute commandState : ControlSignalState;

        port commandPort : PumpCommandPort;

        action removeLiquid {
            in item commandSignal : ElectricalSignal;
            out item dischargedLiquid : Liquid;

            first receiveCommand;
            then energizeMotor;
            then moveLiquid;
            then done;

            action receiveCommand;
            action energizeMotor;
            action moveLiquid;
        }

        perform action removeLiquid;
    }

    part def FloatSwitchControlledTankSystem {
        attribute nominalSupplyVoltage : ElectricPotential = 24 [V];
        attribute maximumAllowedLevel : Length = 1.80 [m];
        attribute pumpStartLevel : Length = 1.50 [m];
        attribute pumpStopLevel : Length = 0.40 [m];

        part tank : StorageTank {
            attribute tankCapacity = 2.5 [m^3];
            attribute tankHeight = 2.0 [m];
            attribute maximumSafeLevel = 1.80 [m];
            attribute minimumSafeLevel = 0.20 [m];
        }

        part highLevelFloatSwitch : FloatSwitchAssembly {
            attribute setPointLevel = 1.50 [m];
            attribute hysteresisBand = 0.08 [m];
            attribute maximumLiquidLevel = 2.00 [m];
            attribute minimumLiquidLevel = 0.00 [m];
            attribute ratedVoltage = 24 [V];
            attribute ratedCurrent = 0.5 [A];
            attribute contactResistance = 0.15 [ohm];
            attribute responseTime = 0.25 [s];
            attribute mountingOrientation = MountingOrientation::vertical;
            attribute contactHealth = ContactHealth::normal;
        }

        part controller : PumpController {
            attribute inputThresholdVoltage = 18 [V];
            attribute commandVoltage = 24 [V];
        }

        part drainPump : DrainPump {
            attribute ratedFlowRate = 0.012 [m^3/s];
            attribute ratedPower = 370 [W];
        }

        connect tank.liquidStatusPort to highLevelFloatSwitch.liquidPort;
        connect highLevelFloatSwitch.controllerPort to controller.floatSwitchInput;
        connect controller.pumpCommand to drainPump.commandPort;

        action primaryFunction {
            in item tankLevel : LevelIndication;
            out item pumpCommandSignal : ElectricalSignal;

            first monitorLiquidLevel;
            then detectSetPointCrossing;
            then convertLevelToElectricalSignal;
            then commandPumpWhenLevelIsHigh;
            then done;

            action monitorLiquidLevel;
            action detectSetPointCrossing;
            action convertLevelToElectricalSignal;
            action commandPumpWhenLevelIsHigh;
        }

        perform action primaryFunction;
    }

    requirement def FloatSwitchPrimaryFunctionRequirement {
        subject system : FloatSwitchControlledTankSystem;

        doc /* The float switch system shall monitor liquid level in a tank and convert buoyant float movement at a defined set point into an electrical control signal used to indicate high level and command downstream control equipment. */

        require constraint {
            system.highLevelFloatSwitch.setPointLevel == system.pumpStartLevel
        }
    }

    requirement def LiquidLevelDetectionRequirement {
        subject switchAssembly : FloatSwitchAssembly;

        doc /* The float switch assembly shall change contact position when liquid level crosses the configured set point, with hysteresis preventing chatter near the trip level. */

        require constraint {
            switchAssembly.hysteresisBand > 0 [m]
        }

        require constraint {
            switchAssembly.responseTime <= 1 [s]
        }
    }

    requirement def ElectricalInterfaceRequirement {
        subject switchAssembly : FloatSwitchAssembly;

        doc /* The switch contact shall safely switch the controller input supply without exceeding contact voltage or current ratings. */

        require constraint {
            switchAssembly.ratedVoltage >= 24 [V]
        }

        require constraint {
            switchAssembly.ratedCurrent >= 0.25 [A]
        }
    }

    requirement def HighLevelProtectionRequirement {
        subject system : FloatSwitchControlledTankSystem;

        doc /* The system shall provide a pump command before tank liquid level exceeds the maximum allowed operating level. */

        require constraint {
            system.pumpStartLevel < system.maximumAllowedLevel
        }
    }

    requirement def MechanicalBuoyancyRequirement {
        subject switchAssembly : FloatSwitchAssembly;

        doc /* The float shall provide sufficient buoyant force and travel to actuate the internal contact mechanism throughout the specified liquid range. */

        require constraint {
            switchAssembly.float.travelLimit >= switchAssembly.hysteresisBand
        }

        require constraint {
            switchAssembly.float.buoyancyMargin >= 1.10
        }
    }

    satisfy FloatSwitchPrimaryFunctionRequirement by FloatSwitchControlledTankSystem;
    satisfy LiquidLevelDetectionRequirement by FloatSwitchAssembly;
    satisfy ElectricalInterfaceRequirement by FloatSwitchAssembly;
    satisfy HighLevelProtectionRequirement by FloatSwitchControlledTankSystem;
    satisfy MechanicalBuoyancyRequirement by FloatSwitchAssembly;
}