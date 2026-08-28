package HydroelectricTurbineSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQTime::*;
    import ISQEnergy::*;
    import ISQPower::*;
    import ISQElectricity::*;
    import ISQThermodynamics::*;

    // ---- Value Types ----

    value type PowerMW :> Real { unit "MW"; }
    value type PressureBar :> Real { unit "bar"; }
    value type FlowRateCMS :> Real { unit "m3/s"; }
    value type RotationalSpeedRPM :> Real { unit "rpm"; }
    value type TorqueKNm :> Real { unit "kN.m"; }
    value type VoltageKV :> Real { unit "kV"; }
    value type FrequencyHz :> Real { unit "Hz"; }
    value type AngleDeg :> Real { unit "deg"; }
    value type EfficiencyPct :> Real { unit "%"; }
    value type MassKg :> Real { unit "kg"; }
    value type LengthM :> Real { unit "m"; }
    value type DiameterM :> Real { unit "m"; }

    // ---- Item Types ----

    item def Water {
        attribute pressure : PressureBar;
        attribute flowRate : FlowRateCMS;
        attribute temperature : TemperatureValue;
    }

    item def ElectricalPower {
        attribute activePower : PowerMW;
        attribute voltage : VoltageKV;
        attribute frequency : FrequencyHz;
    }

    // ---- Port Definitions ----

    port def WaterInPort {
        attribute pressure : PressureBar;
        attribute flowRate : FlowRateCMS;
        out item water : Water;
    }

    port def WaterOutPort {
        attribute pressure : PressureBar;
        attribute flowRate : FlowRateCMS;
        out item water : Water;
    }

    port def MechanicalPowerPort {
        attribute speed : RotationalSpeedRPM;
        attribute torque : TorqueKNm;
    }

    port def ElectricalPowerPort {
        attribute power : PowerMW;
        attribute voltage : VoltageKV;
        attribute frequency : FrequencyHz;
        out item electricity : ElectricalPower;
    }

    port def ControlSignalPort {
        attribute vaneAngleCommand : AngleDeg;
        attribute speedFeedback : RotationalSpeedRPM;
    }

    // ---- Part Definitions ----

    part def SpiralCasing {
        attribute shape : String = "snail";
        attribute inletDiameter : DiameterM = 4.5;
        attribute material : String = "steel";
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def GuideVane {
        attribute vaneAngle : AngleDeg = 0.0;
        attribute adjustable : Boolean = true;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port control : in ControlSignalPort;

        action def AdjustAngle {
            in command : AngleDeg;
            out newAngle : AngleDeg;
        }
    }

    part def GuideVaneAssembly {
        attribute vaneCount : Integer = 20;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port control : in ControlSignalPort;
        part vanes : GuideVane[20];
    }

    part def RunnerBlade {
        attribute bladeAngle : AngleDeg = 30.0;
        attribute material : String = "stainless steel";
    }

    part def Runner {
        attribute bladeCount : Integer = 16;
        attribute ratedSpeed : RotationalSpeedRPM = 300.0;
        attribute diameter : DiameterM = 5.0;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port mechanicalOut : MechanicalPowerPort;
        part blades : RunnerBlade[16];
    }

    part def DraftTube {
        attribute inletDiameter : DiameterM = 5.0;
        attribute outletDiameter : DiameterM = 8.0;
        attribute length : LengthM = 12.0;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def Shaft {
        attribute length : LengthM = 6.0;
        attribute diameter : DiameterM = 0.8;
        attribute material : String = "forged steel";
        port turbineEnd : MechanicalPowerPort;
        port generatorEnd : MechanicalPowerPort;
    }

    part def BearingAssembly {
        attribute type : String = "hydrodynamic";
        attribute loadCapacity : MassKg = 50000.0;
        port shaftInterface : MechanicalPowerPort;
    }

    part def Generator {
        attribute ratedPower : PowerMW = 40.0;
        attribute ratedVoltage : VoltageKV = 13.8;
        attribute ratedFrequency : FrequencyHz = 60.0;
        attribute poles : Integer = 20;
        port mechanicalIn : MechanicalPowerPort;
        port electricalOut : ElectricalPowerPort;
    }

    part def GovernorSystem {
        attribute targetSpeed : RotationalSpeedRPM = 300.0;
        attribute gridDemand : PowerMW = 40.0;
        attribute speedTolerance : RotationalSpeedRPM = 2.0;
        port speedSensor : in ControlSignalPort;
        port vaneControl : out ControlSignalPort;

        state def GovernorStates {
            entry; then Idle;

            state Idle {
                entry { vaneControl.vaneAngleCommand = 0.0; }
                transition Idle -> Monitoring
                    when (speedSensor.speedFeedback > 0.0);
            }

            state Monitoring {
                entry { /* monitor turbine speed */ }
                transition Monitoring -> Regulating
                    when (abs(speedSensor.speedFeedback - targetSpeed) > speedTolerance);
                transition Monitoring -> Idle
                    when (speedSensor.speedFeedback == 0.0);
            }

            state Regulating {
                entry { /* adjust vane angles */ }
                do {
                    if (speedSensor.speedFeedback > targetSpeed) {
                        vaneControl.vaneAngleCommand = vaneControl.vaneAngleCommand - 1.0;
                    } else {
                        vaneControl.vaneAngleCommand = vaneControl.vaneAngleCommand + 1.0;
                    }
                }
                transition Regulating -> Monitoring
                    when (abs(speedSensor.speedFeedback - targetSpeed) <= speedTolerance);
            }
        }

        state machine governorBehavior : GovernorStates;
    }

    // ---- Top-level System ----

    part def HydroelectricTurbineSystem {
        attribute systemRatedPower : PowerMW = 40.0;
        attribute systemEfficiency : EfficiencyPct = 88.0;
        attribute totalWeight : MassKg = 38000.0;
        attribute gridFrequency : FrequencyHz = 60.0;
        attribute gridVoltage : VoltageKV = 13.8;

        port waterIntake : WaterInPort;
        port waterDischarge : WaterOutPort;
        port gridConnection : ElectricalPowerPort;

        part spiralCasing : SpiralCasing;
        part guideVaneAssembly : GuideVaneAssembly;
        part runner : Runner;
        part draftTube : DraftTube;
        part shaft : Shaft;
        part bearingAssembly1 : BearingAssembly;
        part bearingAssembly2 : BearingAssembly;
        part generator : Generator;
        part governor : GovernorSystem;

        connection waterFlow1 connect spiralCasing.waterOut to guideVaneAssembly.waterIn;
        connection waterFlow2 connect guideVaneAssembly.waterOut to runner.waterIn;
        connection waterFlow3 connect runner.waterOut to draftTube.waterIn;

        connection intakePipe connect waterIntake to spiralCasing.waterIn;
        connection dischargePipe connect draftTube.waterOut to waterDischarge;

        connection mechanicalLink1 connect runner.mechanicalOut to shaft.turbineEnd;
        connection mechanicalLink2 connect shaft.generatorEnd to generator.mechanicalIn;

        connection bearingSupport1 connect bearingAssembly1.shaftInterface to shaft.turbineEnd;
        connection bearingSupport2 connect bearingAssembly2.shaftInterface to shaft.generatorEnd;

        connection governorSpeedFeedback connect runner.mechanicalOut to governor.speedSensor;
        connection governorVaneControl connect governor.vaneControl to guideVaneAssembly.control;

        connection powerOutput connect generator.electricalOut to gridConnection;

        action def StartupSequence {
            action OpenIntakeValve;
            action FillSpiralCasing;
            action InitializeGovernor;
            action GraduallyOpenGuideVanes;
            action ReachRatedSpeed;
            action SynchronizeGenerator;
            action ConnectToGrid;

            succession OpenIntakeValve then FillSpiralCasing;
            succession FillSpiralCasing then InitializeGovernor;
            succession InitializeGovernor then GraduallyOpenGuideVanes;
            succession GraduallyOpenGuideVanes then ReachRatedSpeed;
            succession ReachRatedSpeed then SynchronizeGenerator;
            succession SynchronizeGenerator then ConnectToGrid;
        }

        action def ShutdownSequence {
            action CloseGuideVanes;
            action DisconnectFromGrid;
            action ReduceSpeed;
            action CloseIntakeValve;
            action DrainSystem;

            succession CloseGuideVanes then DisconnectFromGrid;
            succession DisconnectFromGrid then ReduceSpeed;
            succession ReduceSpeed then CloseIntakeValve;
            succession CloseIntakeValve then DrainSystem;
        }
    }

    // ---- Requirements ----

    requirement def PowerGenerationRequirement {
        attribute requiredPower : PowerMW = 40.0;
        attribute requiredFrequency : FrequencyHz = 60.0;
        attribute requiredVoltage : VoltageKV = 13.8;
        subject system : HydroelectricTurbineSystem;
        require system.systemRatedPower >= requiredPower;
        require system.gridFrequency == requiredFrequency;
        require system.gridVoltage == requiredVoltage;
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : EfficiencyPct = 88.0;
        subject system : HydroelectricTurbineSystem;
        require system.systemEfficiency >= minEfficiency;
    }

    requirement def WeightRequirement {
        attribute maxWeight : MassKg = 38000.0;
        subject system : HydroelectricTurbineSystem;
        require system.totalWeight <= maxWeight;
    }

    requirement def SpeedRegulationRequirement {
        attribute targetSpeed : RotationalSpeedRPM = 300.0;
        attribute tolerance : RotationalSpeedRPM = 2.0;
        subject governor : GovernorSystem;
        require abs(governor.speedSensor.speedFeedback - governor.targetSpeed) <= tolerance;
    }

    requirement def GuideVaneCountRequirement {
        attribute requiredCount : Integer = 20;
        subject assembly : GuideVaneAssembly;
        require assembly.vaneCount == requiredCount;
    }

    requirement def RunnerBladeCountRequirement {
        attribute requiredCount : Integer = 16;
        subject runner : Runner;
        require runner.bladeCount == requiredCount;
    }

    requirement def BearingSupportRequirement {
        attribute requiredBearingCount : Integer = 2;
        subject system : HydroelectricTurbineSystem;
        require system.bearingAssembly1.type == "hydrodynamic";
        require system.bearingAssembly2.type == "hydrodynamic";
    }

    requirement HydroelectricSystemRequirements {
        subject system : HydroelectricTurbineSystem;
        satisfy PowerGenerationRequirement;
        satisfy EfficiencyRequirement;
        satisfy WeightRequirement;
        satisfy SpeedRegulationRequirement;
        satisfy GuideVaneCountRequirement;
        satisfy RunnerBladeCountRequirement;
        satisfy BearingSupportRequirement;
    }

}
