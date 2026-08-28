package StationarySteamEngineSystem {
    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ===================== Value Types =====================

    valueType PressureValue :> Pressure;
    valueType TemperatureValue :> ThermodynamicTemperature;
    valueType PowerValue :> Power;
    valueType TorqueValue :> Torque;
    valueType RotationalSpeedValue :> Frequency;
    valueType LinearVelocityValue :> Velocity;
    valueType ForceValue :> Force;
    valueType MassValue :> Mass;
    valueType MassFlowRateValue :> MassFlowRate;
    valueType LengthValue :> Length;
    valueType InertiaValue :> MassMomentOfInertia;
    valueType EfficiencyValue :> Real;
    valueType FractionValue :> Real;

    // ===================== Item Definitions =====================

    item def Water {
        attribute temperature : TemperatureValue;
        attribute mass : MassValue;
    }

    item def LiquidWater :> Water {
        attribute pressure : PressureValue;
    }

    item def PressurizedWater :> LiquidWater;

    item def Steam {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def HighPressureSteam :> Steam;
    item def LowPressureSteam :> Steam;
    item def ExhaustSteam :> LowPressureSteam;

    // ===================== Port Definitions =====================

    port def LiquidWaterPort {
        in item water : LiquidWater;
    }

    port def PressurizedWaterPort {
        in item water : PressurizedWater;
    }

    port def HPSteamPort {
        in item steam : HighPressureSteam;
    }

    port def LPSteamPort {
        in item steam : LowPressureSteam;
    }

    port def ExhaustSteamPort {
        in item steam : ExhaustSteam;
    }

    port def ShaftPort {
        in attribute torque : TorqueValue;
        in attribute speed : RotationalSpeedValue;
    }

    port def ThrottleControlPort {
        in attribute openingFraction : FractionValue;
    }

    port def LinearForcePort {
        in attribute force : ForceValue;
        in attribute velocity : LinearVelocityValue;
    }

    // ===================== Boiler =====================

    part def Boiler {
        attribute operatingPressure : PressureValue = 1.8e6 [Pa];
        attribute maxSafePressure : PressureValue = 2.0e6 [Pa];
        attribute heatingPower : PowerValue = 500000 [W];
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute waterLevel : MassValue;

        port feedWaterIn : PressurizedWaterPort;
        port steamOut : ~HPSteamPort;

        action def HeatWater {
            in water : PressurizedWater;
            out steam : HighPressureSteam;
        }

        perform heatWater : HeatWater;
    }

    // ===================== Throttle Valve =====================

    part def ThrottleValve {
        attribute openingFraction : FractionValue = 1.0;
        attribute maxFlowRate : MassFlowRateValue = 0.5 [kg/s];
        attribute currentFlowRate : MassFlowRateValue;

        port steamIn : HPSteamPort;
        port steamOut : ~HPSteamPort;
        port throttleControl : ThrottleControlPort;

        action def RegulateSteam {
            in steam : HighPressureSteam;
            in opening : FractionValue;
            out regulatedSteam : HighPressureSteam;
        }

        perform regulateSteam : RegulateSteam;
    }

    // ===================== Governor =====================

    part def Governor {
        attribute targetSpeed : RotationalSpeedValue = 5.0 [Hz];
        attribute currentSpeed : RotationalSpeedValue;
        attribute proportionalGain : Real = 0.05;
        attribute speedTolerance : RotationalSpeedValue = 0.25 [Hz];
        attribute outputOpening : FractionValue;

        port shaftSpeed : ShaftPort;
        port throttleControl : ~ThrottleControlPort;

        action def MeasureSpeed {
            in speed : RotationalSpeedValue;
            out measuredSpeed : RotationalSpeedValue;
        }

        action def ComputeThrottle {
            in measuredSpeed : RotationalSpeedValue;
            in target : RotationalSpeedValue;
            in gain : Real;
            out openingCommand : FractionValue;
        }

        perform measureSpeed : MeasureSpeed;
        perform computeThrottle : ComputeThrottle;
    }

    // ===================== Cylinder =====================

    part def Cylinder {
        attribute bore : LengthValue = 0.3 [m];
        attribute stroke : LengthValue = 0.5 [m];
        attribute internalPressure : PressureValue;
        attribute exhaustPressure : PressureValue;

        port steamIn : HPSteamPort;
        port steamOut : ~ExhaustSteamPort;
        port linearForceOut : ~LinearForcePort;

        action def ExpandSteam {
            in steam : HighPressureSteam;
            out exhaust : ExhaustSteam;
            out linearForce : ForceValue;
            out linearVelocity : LinearVelocityValue;
        }

        perform expandSteam : ExpandSteam;
    }

    // ===================== Piston =====================

    part def Piston {
        attribute diameter : LengthValue = 0.3 [m];
        attribute mass : MassValue = 50 [kg];
        attribute currentForce : ForceValue;
        attribute currentVelocity : LinearVelocityValue;

        port linearForceIn : LinearForcePort;
        port linearForceOut : ~LinearForcePort;

        action def Translate {
            in inputForce : ForceValue;
            in inputVelocity : LinearVelocityValue;
            out outputForce : ForceValue;
            out outputVelocity : LinearVelocityValue;
        }

        perform translate : Translate;
    }

    // ===================== Connecting Rod =====================

    part def ConnectingRod {
        attribute length : LengthValue = 1.0 [m];
        attribute mass : MassValue = 30 [kg];

        port linearForceIn : LinearForcePort;
        port rotationalDriveOut : ~ShaftPort;

        action def ConvertLinearToRotary {
            in linearForce : ForceValue;
            in linearVelocity : LinearVelocityValue;
            out torque : TorqueValue;
            out angularSpeed : RotationalSpeedValue;
        }

        perform convertMotion : ConvertLinearToRotary;
    }

    // ===================== Crankshaft =====================

    part def Crankshaft {
        attribute crankRadius : LengthValue = 0.25 [m];
        attribute currentSpeed : RotationalSpeedValue;
        attribute currentTorque : TorqueValue;

        port rotationalDriveIn : ShaftPort;
        port shaftOutput : ~ShaftPort;

        action def ConvertTorque {
            in inputTorque : TorqueValue;
            in inputSpeed : RotationalSpeedValue;
            out outputTorque : TorqueValue;
            out outputSpeed : RotationalSpeedValue;
        }

        perform convertTorque : ConvertTorque;
    }

    // ===================== Flywheel =====================

    part def Flywheel {
        attribute mass : MassValue = 200 [kg];
        attribute radius : LengthValue = 0.5 [m];
        attribute momentOfInertia : InertiaValue;
        attribute currentSpeed : RotationalSpeedValue;

        port shaftInput : ShaftPort;
        port shaftOutput : ~ShaftPort;

        action def SmoothRotation {
            in inputSpeed : RotationalSpeedValue;
            in inputTorque : TorqueValue;
            out smoothedSpeed : RotationalSpeedValue;
            out smoothedTorque : TorqueValue;
        }

        perform smoothRotation : SmoothRotation;
    }

    // ===================== Condenser =====================

    part def Condenser {
        attribute coolingTemperature : TemperatureValue = 310 [K];
        attribute condensationRate : MassFlowRateValue;
        attribute heatRemovalRate : PowerValue;

        port steamIn : ExhaustSteamPort;
        port waterOut : ~LiquidWaterPort;

        action def CondenseSteam {
            in steam : ExhaustSteam;
            out water : LiquidWater;
        }

        perform condenseSteam : CondenseSteam;
    }

    // ===================== Feed Pump =====================

    part def FeedPump {
        attribute pumpPressure : PressureValue = 2.2e6 [Pa];
        attribute flowRate : MassFlowRateValue;
        attribute pumpPower : PowerValue;

        port waterIn : LiquidWaterPort;
        port waterOut : ~PressurizedWaterPort;

        action def PressurizeWater {
            in water : LiquidWater;
            out pressurizedWater : PressurizedWater;
        }

        perform pressurizeWater : PressurizeWater;
    }

    // ===================== Power Unit Assembly =====================

    part def PowerUnit {
        part cylinder : Cylinder;
        part piston : Piston;
        part connectingRod : ConnectingRod;
        part crankshaft : Crankshaft;
        part flywheel : Flywheel;

        port steamIn : HPSteamPort;
        port steamOut : ~ExhaustSteamPort;
        port shaftOutput : ~ShaftPort;

        connection connect cylinder.linearForceOut to piston.linearForceIn;
        connection connect piston.linearForceOut to connectingRod.linearForceIn;
        connection connect connectingRod.rotationalDriveOut to crankshaft.rotationalDriveIn;
        connection connect crankshaft.shaftOutput to flywheel.shaftInput;
        connection connect flywheel.shaftOutput to shaftOutput;
        connection connect steamIn to cylinder.steamIn;
        connection connect cylinder.steamOut to steamOut;
    }

    // ===================== Main Engine System =====================

    part def StationarySteamEngine {
        attribute startCommand : Boolean = false;
        attribute shutdownCommand : Boolean = false;
        attribute outputPower : PowerValue;
        attribute thermalEfficiency : EfficiencyValue;
        attribute ratedSpeed : RotationalSpeedValue = 5.0 [Hz];

        part boiler : Boiler;
        part throttleValve : ThrottleValve;
        part governor : Governor;
        part powerUnit : PowerUnit;
        part condenser : Condenser;
        part feedPump : FeedPump;

        port shaftOutput : ~ShaftPort;

        // Closed-loop fluid connections
        connection connect boiler.steamOut to throttleValve.steamIn;
        connection connect throttleValve.steamOut to powerUnit.steamIn;
        connection connect powerUnit.steamOut to condenser.steamIn;
        connection connect condenser.waterOut to feedPump.waterIn;
        connection connect feedPump.waterOut to boiler.feedWaterIn;

        // Governor feedback connections
        connection connect powerUnit.shaftOutput to governor.shaftSpeed;
        connection connect governor.throttleControl to throttleValve.throttleControl;

        // Output shaft delegation
        connection connect powerUnit.shaftOutput to shaftOutput;

        // Engine state machine
        stateMachine {
            state stopped {
                entry action { boiler.currentPressure = 0.0 [Pa]; }
            }
            state starting {
                entry action { feedPump.pressurizeWater; }
            }
            state warming {
                entry action { boiler.heatWater; }
            }
            state running {
                do action { governor.measureSpeed; governor.computeThrottle; throttleValve.regulateSteam; }
            }
            state stopping {
                entry action { throttleValve.openingFraction = 0.0; }
            }

            transition stopped to starting when startCommand == true;
            transition starting to warming when boiler.currentPressure > 1000.0 [Pa];
            transition warming to running when boiler.currentPressure >= boiler.operatingPressure;
            transition running to stopping when shutdownCommand == true;
            transition stopping to stopped when boiler.currentPressure < 1000.0 [Pa];
        }

        // Requirement satisfactions
        satisfy powerReq;
        satisfy efficiencyReq;
        satisfy safetyReq;
        satisfy speedReq;
    }

    // ===================== Requirements =====================

    requirement def PowerOutputRequirement {
        doc 'The engine shall produce a minimum continuous mechanical power output of 50 kW at the output shaft under rated operating conditions.';
        subject engine : StationarySteamEngine;
        attribute minPower : PowerValue = 50000 [W];
        require { engine.outputPower >= minPower }
    }

    requirement def ThermalEfficiencyRequirement {
        doc 'The engine shall achieve a minimum thermal efficiency of 15 percent under rated operating conditions, defined as the ratio of mechanical power output to thermal energy input.';
        subject engine : StationarySteamEngine;
        attribute minEfficiency : EfficiencyValue = 0.15;
        require { engine.thermalEfficiency >= minEfficiency }
    }

    requirement def BoilerSafetyRequirement {
        doc 'The boiler operating pressure shall not exceed the maximum safe pressure of 2.0 MPa under any operating condition to ensure operational safety.';
        subject engine : StationarySteamEngine;
        attribute maxSafePressure : PressureValue = 2.0e6 [Pa];
        require { engine.boiler.currentPressure <= maxSafePressure }
    }

    requirement def SpeedRegulationRequirement {
        doc 'The governor shall maintain the engine output shaft speed within plus or minus 5 percent of the rated speed under varying load conditions.';
        subject engine : StationarySteamEngine;
        attribute ratedSpeed : RotationalSpeedValue = 5.0 [Hz];
        attribute speedTolerance : RotationalSpeedValue = 0.25 [Hz];
        require {
            (engine.governor.currentSpeed >= ratedSpeed - speedTolerance) and
            (engine.governor.currentSpeed <= ratedSpeed + speedTolerance)
        }
    }

    // ===================== Requirement Usages =====================

    requirement powerReq : PowerOutputRequirement;
    requirement efficiencyReq : ThermalEfficiencyRequirement;
    requirement safetyReq : BoilerSafetyRequirement;
    requirement speedReq : SpeedRegulationRequirement;
}
