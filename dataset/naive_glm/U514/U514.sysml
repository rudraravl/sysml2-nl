package WaterPumpSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ============ Value Types ============
    value type FlowRateValue = Real { unit "L/min"; }
    value type PressureValue = Real { unit "bar"; }
    value type MassValue = Real { unit "kg"; }
    value type VolumeValue = Real { unit "L"; }
    value type DisplacementValue = Real { unit "cc"; }
    value type HeadValue = Real { unit "m"; }
    value type DurationValue = Real { unit "h"; }
    value type TemperatureValue = Real { unit "degC"; }
    value type RotationalSpeedValue = Real { unit "rpm"; }
    value type PowerValue = Real { unit "kW"; }
    value type TorqueValue = Real { unit "N*m"; }
    value type ForceValue = Real { unit "N"; }
    value type FrequencyValue = Real { unit "Hz"; }

    // ============ Item Types ============
    item def Gasoline;
    item def Water;
    item def Air;
    item def ExhaustGas;
    item def Vibration;
    item def ControlSignal;
    item def FuelMixture :> Gasoline;

    // ============ Port Definitions ============
    port def FuelPort {
        out item gasoline : Gasoline;
    }

    port def WaterInletPort {
        in item water : Water;
    }

    port def WaterOutletPort {
        out item water : Water;
    }

    port def AirIntakePort {
        in item air : Air;
    }

    port def ExhaustPort {
        out item exhaust : ExhaustGas;
    }

    port def DriveShaftPort {
        out torque : TorqueValue;
        out speed : RotationalSpeedValue;
    }

    port def ControlCmdPort {
        out item signal : ControlSignal;
    }

    port def VibrationPort {
        out item vibration : Vibration;
    }

    // ============ Requirements ============
    requirement def PumpPerformanceRequirement {
        subject pumpSystem :> WaterPumpSystem::waterPumpSystem;
        doc /* The pump system shall deliver the required flow rate and head pressure. */
        requirement flowRateRequirement {
            doc /* The pump shall deliver a flow rate of at least 600 liters per minute. */
            assert pumpSystem.deliveredFlowRate >= 600 [L/min];
        }
        requirement headPressureRequirement {
            doc /* The pump shall generate enough pressure to push water vertically up to 30 meters. */
            assert pumpSystem.maxHead >= 30 [m];
        }
    }

    requirement def PortabilityRequirement {
        subject pumpSystem :> WaterPumpSystem::waterPumpSystem;
        doc /* The entire assembly shall weigh under 25 kg and be mounted on a steel frame with a handle. */
        assert pumpSystem.totalMass < 25 [kg];
        assert pumpSystem.frame.material == "steel";
        assert pumpSystem.frame.hasHandle == true;
    }

    requirement def EnduranceRequirement {
        subject pumpSystem :> WaterPumpSystem::waterPumpSystem;
        doc /* The pump shall operate continuously for over two hours on a full fuel tank. */
        assert pumpSystem.runtimeOnFullTank > 2 [h];
    }

    requirement def EngineSpecRequirement {
        subject engine :> WaterPumpSystem::waterPumpSystem::engine;
        doc /* The engine shall be a 163cc gasoline engine with a 3.1-liter fuel tank. */
        assert engine.displacement == 163 [cc];
        assert engine.fuelTank.capacity == 3.1 [L];
    }

    requirement def PumpHeadSpecRequirement {
        subject pumpHead :> WaterPumpSystem::waterPumpSystem::pumpHead;
        doc /* The pump head shall contain a cast-iron impeller with six blades. */
        assert pumpHead.impeller.material == "cast-iron";
        assert pumpHead.impeller.bladeCount == 6;
    }

    requirement def FaultProtectionRequirement {
        subject pumpSystem :> WaterPumpSystem::waterPumpSystem;
        doc /* The system shall enter a fault mode to protect the pump if excessive pressure is detected. */
        assert pumpSystem.controlSystem.overPressureProtection == true;
    }

    // ============ Part Definitions ============

    part def IgnitionSystem {
        attribute ignitionType : String = "magneto";
        attribute sparkPlugCount : Integer = 1;
        action generateSpark;
    }

    part def CoolingSystem {
        attribute coolingType : String = "air-cooled";
        attribute fanBladeCount : Integer = 6;
        action circulateAir;
    }

    part def FuelTank {
        attribute capacity : VolumeValue = 3.1 [L];
        attribute currentFuelLevel : VolumeValue;
        port fuelFill : FuelPort;
        action supplyFuel {
            out item fuel : Gasoline;
        }
    }

    part def Carburetor {
        attribute mixtureRatio : Real = 14.7;
        action mixFuel {
            in item fuel : Gasoline;
            in item air : Air;
            out item mixture : FuelMixture;
        }
    }

    part def CombustionChamber {
        attribute bore : LengthValue;
        attribute stroke : LengthValue;
        action combust {
            in item mixture : FuelMixture;
            out item exhaust : ExhaustGas;
            out torque : TorqueValue;
        }
    }

    part def Crankshaft {
        port driveOutput : DriveShaftPort;
        action transmitTorque {
            in torque : TorqueValue;
            out torqueOut : TorqueValue;
            out speedOut : RotationalSpeedValue;
        }
    }

    part def Muffler {
        port exhaustIn : ExhaustPort;
        port exhaustOut : ExhaustPort;
        action reduceNoise {
            in item exhaust : ExhaustGas;
            out item quietExhaust : ExhaustGas;
        }
    }

    part def GasolineEngine {
        attribute displacement : DisplacementValue = 163 [cc];
        attribute maxPower : PowerValue = 4.4 [kW];
        attribute ratedSpeed : RotationalSpeedValue = 3600 [rpm];
        attribute operatingTemperature : TemperatureValue;
        attribute runtimeOnFullTank : DurationValue = 2.2 [h];

        port fuelInput : FuelPort;
        port driveOutput : DriveShaftPort;
        port airIntake : AirIntakePort;
        port exhaustOut : ExhaustPort;
        port vibrationOut : VibrationPort;

        part ignitionSystem : IgnitionSystem {
            part sparkPlug;
        }
        part coolingSystem : CoolingSystem {
            part coolingFan;
            part coolingFins;
        }
        part fuelTank : FuelTank;
        part carburetor : Carburetor;
        part combustionChamber : CombustionChamber;
        part crankshaft : Crankshaft;
        part muffler : Muffler;
        part pullStarter;
        part governor {
            attribute targetSpeed : RotationalSpeedValue = 3600 [rpm];
            action regulateSpeed;
        }

        action startEngine {
            in fuel : Gasoline;
            out status : String;
        }
        action warmUp {
            duration minWarmup : DurationValue = 0.05 [h];
        }
        action idle {
            out speed : RotationalSpeedValue = 1200 [rpm];
        }
        action runAtLoad {
            in targetSpeed : RotationalSpeedValue;
            out torque : TorqueValue;
            out speed : RotationalSpeedValue;
        }
        action shutdownEngine;
    }

    part def Impeller {
        attribute material : String = "cast-iron";
        attribute bladeCount : Integer = 6;
        attribute diameter : LengthValue;
        action accelerateWater {
            in item water : Water;
            in torque : TorqueValue;
            in speed : RotationalSpeedValue;
            out item pressurizedWater : Water;
        }
    }

    part def PumpShaft {
        attribute material : String = "stainless-steel";
        port driveInput : DriveShaftPort;
        action transmitRotation {
            in torque : TorqueValue;
            in speed : RotationalSpeedValue;
            out torqueOut : TorqueValue;
            out speedOut : RotationalSpeedValue;
        }
    }

    part def BallBearing {
        attribute lubricated : Boolean = true;
        attribute boreDiameter : LengthValue;
        action supportShaft;
    }

    part def MechanicalSeal {
        attribute sealType : String = "carbon-ceramic";
        action preventLeakage;
    }

    part def PumpCasing {
        attribute material : String = "cast-aluminum";
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        action guideWater {
            in item water : Water;
            out item water : Water;
        }
    }

    part def CentrifugalPumpHead {
        attribute ratedFlowRate : FlowRateValue = 600 [L/min];
        attribute maxHead : HeadValue = 30 [m];
        attribute maxPressure : PressureValue = 3.0 [bar];

        port driveInput : DriveShaftPort;
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;

        part casing : PumpCasing;
        part impeller : Impeller;
        part shaft : PumpShaft;
        part bearings : BallBearing[2];
        part seal : MechanicalSeal;
        part volute;
        part wearRing;

        action createSuction {
            in speed : RotationalSpeedValue;
            out item water : Water;
        }
        action pressurizeWater {
            in item water : Water;
            in torque : TorqueValue;
            in speed : RotationalSpeedValue;
            out item pressurizedWater : Water;
            out pressure : PressureValue;
            out flowRate : FlowRateValue;
        }
    }

    part def VibrationIsolator {
        attribute material : String = "rubber";
        attribute durometer : Integer = 60;
        action dampenVibration {
            in item vibration : Vibration;
            out item reducedVibration : Vibration;
        }
    }

    part def Handle {
        attribute material : String = "steel";
        attribute gripType : String = "foam";
    }

    part def SteelFrame {
        attribute material : String = "steel";
        attribute hasHandle : Boolean = true;
        attribute mass : MassValue = 5.5 [kg];
        part isolators : VibrationIsolator[4];
        part handle : Handle;
        action supportComponents;
        action enableTransport;
    }

    part def PrimingChamber {
        attribute capacity : VolumeValue = 0.5 [L];
        attribute isFilled : Boolean = false;
        port fillPort : WaterInletPort;
        action fillWithWater {
            in item water : Water;
            out isFilled : Boolean = true;
        }
        action providePrime {
            out item water : Water;
        }
    }

    part def PrimingSystem {
        part chamber : PrimingChamber;
        port fillPort : WaterInletPort;
        port primeOutput : WaterOutletPort;
        action prime {
            in item water : Water;
            out item primeWater : Water;
        }
    }

    part def ThrottleActuator {
        attribute position : Real = 0.0; // 0..1
        action adjustThrottle {
            in item signal : ControlSignal;
            out position : Real;
        }
    }

    part def PressureGauge {
        attribute reading : PressureValue;
        port sensorPort;
        action measurePressure {
            out pressure : PressureValue;
        }
    }

    part def FlowGauge {
        attribute reading : FlowRateValue;
        port sensorPort;
        action measureFlow {
            out flowRate : FlowRateValue;
        }
    }

    part def ControlSystem {
        attribute targetFlowRate : FlowRateValue = 600 [L/min];
        attribute maxPressure : PressureValue = 3.5 [bar];
        attribute overPressureProtection : Boolean = true;
        attribute autoThrottleEnabled : Boolean = true;

        port throttleCmd : ControlCmdPort;
        port pressureFeedback;
        port flowFeedback;

        part throttleActuator : ThrottleActuator;
        part pressureGauge : PressureGauge;
        part flowGauge : FlowGauge;

        action monitorPerformance {
            in pressure : PressureValue;
            in flowRate : FlowRateValue;
            out item signal : ControlSignal;
        }
        action adjustThrottle {
            in targetFlow : FlowRateValue;
            in actualFlow : FlowRateValue;
            out item signal : ControlSignal;
        }
        action detectFault {
            in pressure : PressureValue;
            out faultDetected : Boolean;
        }
    }

    // ============ Top-Level System ============

    part waterPumpSystem {
        attribute totalMass : MassValue = 24.0 [kg];
        attribute deliveredFlowRate : FlowRateValue = 600 [L/min];
        attribute maxHead : HeadValue = 30 [m];
        attribute runtimeOnFullTank : DurationValue = 2.2 [h];

        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port fuelFill : FuelPort;

        part engine : GasolineEngine {
            port fuelInput : FuelPort;
            port driveOutput : DriveShaftPort;
            port airIntake : AirIntakePort;
            port exhaustOut : ExhaustPort;
            port vibrationOut : VibrationPort;
        }

        part pumpHead : CentrifugalPumpHead {
            port driveInput : DriveShaftPort;
            port waterInlet : WaterInletPort;
            port waterOutlet : WaterOutletPort;
        }

        part frame : SteelFrame;
        part primingSystem : PrimingSystem;
        part controlSystem : ControlSystem;

        // ---- Connections ----
        connection fuelLine connect fuelFill to engine.fuelInput;
        connection driveShaft connect engine.driveOutput to pumpHead.driveInput;
        connection inletLine connect waterInlet to primingSystem.fillPort;
        connection primeLine connect primingSystem.primeOutput to pumpHead.waterInlet;
        connection dischargeLine connect pumpHead.waterOutlet to waterOutlet;
        connection throttleControl connect controlSystem.throttleCmd to engine.governor;
        connection pressureFeedback connect pumpHead.waterOutlet to controlSystem.pressureFeedback;
        connection flowFeedback connect pumpHead.waterOutlet to controlSystem.flowFeedback;
        connection vibrationPath connect engine.vibrationOut to frame.isolators;

        // ---- Lifecycle State Machine ----
        state def PumpLifecycle {
            entry action initializeSystem;
            
            state Off {
                entry action turnOffSystem;
            }
            
            state Startup {
                entry action beginStartup;
                state CheckFuel {
                    entry action checkFuelLevel;
                    transition to Prime if fuelAdequate;
                }
                state Prime {
                    entry action primePump;
                    transition to StartEngine if primed;
                }
                state StartEngine {
                    entry action startEngine;
                    transition to WarmUp if engineRunning;
                }
                state WarmUp {
                    entry action warmUpEngine;
                    transition to Operational if warmedUp;
                }
            }
            
            state Operational {
                entry action beginOperation;
                do action pumpWater {
                    in item water : Water;
                    out item pressurizedWater : Water;
                }
                action monitorPerformance;
                action adjustFlow;
                transition to Shutdown if shutdownRequested;
                transition to FaultMode if faultDetected;
            }
            
            state Shutdown {
                entry action beginShutdown;
                state IdleDown {
                    entry action idleEngine;
                    transition to CoolDown if idleComplete;
                }
                state CoolDown {
                    entry action coolEngine;
                    transition to SwitchOff if coolDownComplete;
                }
            }
            
            state FaultMode {
                entry action activateProtection;
                action reduceThrottle;
                action alertOperator;
                transition to Shutdown if safeToShutdown;
                transition to Off if emergencyStop;
            }
            
            transition to Off initial;
            transition from Off to Startup when startRequested;
            transition from Startup to Operational when startupComplete;
            transition from Shutdown to Off when shutdownComplete;
            transition from FaultMode to Off when systemReset;
        }
        
        // ---- Lifecycle Actions ----
        action checkFuelLevel {
            in fuelLevel : VolumeValue;
            out fuelAdequate : Boolean;
        }
        action primePump {
            in item water : Water;
            out primed : Boolean;
        }
        action startEngine {
            out engineRunning : Boolean;
        }
        action warmUpEngine {
            out warmedUp : Boolean;
        }
        action pumpWater {
            in item water : Water;
            out item pressurizedWater : Water;
        }
        action beginOperation;
        action beginStartup;
        action beginShutdown;
        action turnOffSystem;
        action idleEngine {
            out idleComplete : Boolean;
        }
        action coolEngine {
            out coolDownComplete : Boolean;
        }
        action activateProtection;
        action reduceThrottle;
        action alertOperator;
    }

    // ============ Requirement Satisfaction ============
    satisfaction satisfyPerformance : PumpPerformanceRequirement {
        subject pumpSystem :> waterPumpSystem;
    }
    satisfaction satisfyPortability : PortabilityRequirement {
        subject pumpSystem :> waterPumpSystem;
    }
    satisfaction satisfyEndurance : EnduranceRequirement {
        subject pumpSystem :> waterPumpSystem;
    }
    satisfaction satisfyEngineSpec : EngineSpecRequirement {
        subject engine :> waterPumpSystem.engine;
    }
    satisfaction satisfyPumpHeadSpec : PumpHeadSpecRequirement {
        subject pumpHead :> waterPumpSystem.pumpHead;
    }
    satisfaction satisfyFaultProtection : FaultProtectionRequirement {
        subject pumpSystem :> waterPumpSystem;
    }
}
