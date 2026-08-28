package PumpjackSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    attribute def Power :> Real { unit 'kW'; }
    attribute def Torque :> Real { unit 'N*m'; }
    attribute def RotationalSpeed :> Real { unit 'rpm'; }
    attribute def LinearLength :> Real { unit 'm'; }
    attribute def StrokeRate :> Real { unit '1/min'; }
    attribute def Pressure :> Real { unit 'bar'; }
    attribute def FlowRate :> Real { unit 'm3/h'; }
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Duration :> Real { unit 's'; }
    attribute def Ratio :> Real;

    item def ElectricalEnergy;
    item def RotationalMotion {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }
    item def LinearMotion {
        attribute position : LinearLength;
        attribute velocity : LinearLength;
    }
    item def CrudeOil;
    item def Water;
    item def NaturalGas;
    item def ProducedFluid {
        attribute oilFraction : Real;
        attribute waterFraction : Real;
        attribute gasFraction : Real;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    item def ControlCommand {
        attribute targetStrokeRate : StrokeRate;
        attribute emergencyStop : Boolean;
    }
    item def SensorFeedback {
        attribute measuredStrokeRate : StrokeRate;
        attribute wellheadPressure : Pressure;
        attribute motorCurrent : Power;
    }

    port def ElectricalPort {
        out energy : ElectricalEnergy;
        attribute voltage : Real;
        attribute current : Real;
    }
    port def RotationalPort {
        out motion : RotationalMotion;
    }
    port def LinearPort {
        out motion : LinearMotion;
    }
    port def FluidPort {
        out fluid : ProducedFluid;
    }
    port def ControlPort {
        in command : ControlCommand;
        out feedback : SensorFeedback;
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 75.0;
        attribute ratedSpeed : RotationalSpeed = 1450.0;
        attribute efficiency : Ratio = 0.92;
        port electricalIn : ElectricalPort;
        port shaftOut : RotationalPort;
        attribute outputMotion : RotationalMotion;

        action def generateRotation {
            in electrical : ElectricalEnergy;
            out rotation : RotationalMotion;
        }
    }

    part def SpeedReducer {
        attribute gearRatio : Ratio = 30.0;
        attribute efficiency : Ratio = 0.95;
        port input : RotationalPort;
        port output : RotationalPort;

        action def reduceSpeed {
            in highSpeed : RotationalMotion;
            out lowSpeed : RotationalMotion;
        }
    }

    part def CrankAssembly {
        attribute counterweightMass : Mass = 5000.0;
        attribute crankRadius : LinearLength = 1.5;
        port input : RotationalPort;
        port output : LinearPort;

        action def convertRotationToStroke {
            in rotation : RotationalMotion;
            out stroke : LinearMotion;
        }
    }

    part def WalkingBeam {
        attribute beamLength : LinearLength = 8.0;
        attribute pivotRatio : Ratio = 1.2;
        port input : LinearPort;
        port output : LinearPort;

        action def transmitStroke {
            in inputStroke : LinearMotion;
            out outputStroke : LinearMotion;
        }
    }

    part def PolishedRodString {
        attribute rodLength : LinearLength = 1200.0;
        attribute rodDiameter : LinearLength = 0.025;
        port surfaceIn : LinearPort;
        port downholeOut : LinearPort;

        action def transmitMotionDownhole {
            in surfaceMotion : LinearMotion;
            out downholeMotion : LinearMotion;
        }
    }

    part def SubsurfacePump {
        attribute plungerDiameter : LinearLength = 0.05;
        attribute strokeLength : LinearLength = 3.0;
        port mechanicalIn : LinearPort;
        port fluidOut : FluidPort;

        action def liftFluid {
            in rodMotion : LinearMotion;
            out producedFluid : ProducedFluid;
        }
    }

    part def ProductionTubing {
        attribute tubingLength : LinearLength = 1200.0;
        attribute innerDiameter : LinearLength = 0.062;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        action def conductFluid {
            in fluid : ProducedFluid;
            out fluid : ProducedFluid;
        }
    }

    part def WellheadAssembly {
        attribute maxPressure : Pressure = 150.0;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;

        action def managePressure {
            in fluid : ProducedFluid;
            out fluid : ProducedFluid;
        }
    }

    part def Flowline {
        attribute length : LinearLength = 500.0;
        attribute diameter : LinearLength = 0.15;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        action def transportFluid {
            in fluid : ProducedFluid;
            out fluid : ProducedFluid;
        }
    }

    state machine def PumpjackControlStateMachine {
        state standby;
        state pumping {
            state upstroke;
            state downstroke;
            transition upstroke_to_downstroke
                first upstroke then downstroke
                when strokeRateCycleComplete;
            transition downstroke_to_upstroke
                first downstroke then upstroke
                when strokeRateCycleComplete;
        }
        state emergencyShutdown;

        transition standby_to_pumping
            first standby then pumping
            when startCommandReceived;
        transition pumping_to_standby
            first pumping then standby
            when stopCommandReceived;
        transition standby_to_emergency
            first standby then emergencyShutdown
            when emergencyStopReceived;
        transition pumping_to_emergency
            first pumping then emergencyShutdown
            when emergencyStopReceived;
        transition emergency_to_standby
            first emergencyShutdown then standby
            when resetCommandReceived;
    }

    part def ControlSystem {
        attribute nominalStrokeRate : StrokeRate = 6.0;
        attribute minStrokeRate : StrokeRate = 1.0;
        attribute maxStrokeRate : StrokeRate = 12.0;
        port motorControl : ControlPort;
        port wellheadControl : ControlPort;
        port operatorCommand : ControlPort;
        exhibit state PumpjackControlStateMachine;

        action def regulateStrokeRate {
            in feedback : SensorFeedback;
            in target : StrokeRate;
            out command : ControlCommand;
        }
    }

    part def OilWell {
        attribute reservoirDepth : LinearLength = 1200.0;
        attribute reservoirPressure : Pressure = 90.0;
        port fluidOut : FluidPort;
    }

    part def Pumpjack {
        attribute systemStrokeRate : StrokeRate = 6.0;
        attribute systemStatus : String = "standby";

        part motor : ElectricMotor {
            attribute ratedPower = 75.0;
        }
        part reducer : SpeedReducer {
            attribute gearRatio = 30.0;
        }
        part crank : CrankAssembly {
            attribute counterweightMass = 5000.0;
        }
        part beam : WalkingBeam {
            attribute beamLength = 8.0;
        }
        part rodString : PolishedRodString {
            attribute rodLength = 1200.0;
        }
        part pump : SubsurfacePump {
            attribute strokeLength = 3.0;
        }
        part tubing : ProductionTubing {
            attribute tubingLength = 1200.0;
        }
        part wellhead : WellheadAssembly {
            attribute maxPressure = 150.0;
        }
        part flowline : Flowline {
            attribute length = 500.0;
        }
        part controller : ControlSystem {
            attribute nominalStrokeRate = 6.0;
        }
        part well : OilWell {
            attribute reservoirDepth = 1200.0;
        }

        port powerInput : ElectricalPort;
        port fluidOutput : FluidPort;
        port operatorInterface : ControlPort;

        connection motorToReducer connect motor.shaftOut to reducer.input;
        connection reducerToCrank connect reducer.output to crank.input;
        connection crankToBeam connect crank.output to beam.input;
        connection beamToRod connect beam.output to rodString.surfaceIn;
        connection rodToPump connect rodString.downholeOut to pump.mechanicalIn;
        connection pumpToTubing connect pump.fluidOut to tubing.fluidIn;
        connection tubingToWellhead connect tubing.fluidOut to wellhead.fluidIn;
        connection wellheadToFlowline connect wellhead.fluidOut to flowline.fluidIn;
        connection flowlineToOutput connect flowline.fluidOut to fluidOutput;

        connection powerFeed connect powerInput to motor.electricalIn;
        connection controllerToMotor connect controller.motorControl to motor.electricalIn;
        connection controllerToWellhead connect controller.wellheadControl to wellhead.control;
        connection operatorToController connect operatorInterface to controller.operatorCommand;
    }

    requirement def PumpjackFunctionalRequirement {
        subject pumpjack : Pumpjack;
        objective {
            doc "The pumpjack shall convert electrical energy into reciprocating motion to lift produced fluid from the reservoir to the surface."
        }
    }

    requirement def StrokeRateControlRequirement {
        subject controller : ControlSystem;
        attribute tolerance : StrokeRate = 0.5;
        objective {
            doc "The control system shall regulate the pumpjack stroke rate between 1.0 and 12.0 strokes per minute with a tolerance of 0.5 strokes per minute."
        }
    }

    requirement def EmergencyShutdownRequirement {
        subject pumpjack : Pumpjack;
        objective {
            doc "The pumpjack shall enter an emergency shutdown state within 2 seconds upon receiving an emergency stop command."
        }
    }

    requirement def FluidLiftRequirement {
        subject pump : SubsurfacePump;
        attribute minFlowRate : FlowRate = 5.0;
        objective {
            doc "The subsurface pump shall lift produced fluid at a minimum flow rate of 5.0 cubic meters per hour during active pumping."
        }
    }

    requirement PumpjackSystemRequirement : PumpjackFunctionalRequirement {
        subject pumpjack : Pumpjack;
    }

    requirement StrokeRateRequirement : StrokeRateControlRequirement {
        subject controller : Pumpjack::controller;
    }

    requirement EmergencyStopRequirement : EmergencyShutdownRequirement {
        subject pumpjack : Pumpjack;
    }

    requirement FluidProductionRequirement : FluidLiftRequirement {
        subject pump : Pumpjack::pump;
    }
}
