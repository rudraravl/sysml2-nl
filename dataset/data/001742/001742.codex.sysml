package AlJazariInspiredWaterRaisingSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def VolumeRate :> ISQ::volumeFlowRate;
    attribute def Pressure :> ISQ::pressure;
    attribute def RotationalSpeed :> ISQ::angularVelocity;
    attribute def Torque :> ISQ::torque;
    attribute def StrokeLength :> ISQ::length;
    attribute def Efficiency :> ScalarValues::Real;
    attribute def WaterLevel :> ISQ::length;

    item def Water {
        attribute temperature : ISQ::thermodynamicTemperature;
        attribute flowRate : VolumeRate;
        attribute pressure : Pressure;
    }

    item def RotaryMotion {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    item def ReciprocatingMotion {
        attribute stroke : StrokeLength;
        attribute cyclesPerMinute : ScalarValues::Real;
    }

    port def WaterPort {
        inout item water : Water;
    }

    port def RotaryShaftPort {
        inout item motion : RotaryMotion;
    }

    port def ReciprocatingLinkPort {
        inout item motion : ReciprocatingMotion;
    }

    port def ControlPort {
        in attribute enabled : ScalarValues::Boolean;
        out attribute fault : ScalarValues::Boolean;
    }

    requirement def RaiseWaterRequirement {
        subject system : AlJazariTwinCylinderPump;
        require constraint {
            system.outlet.water.flowRate >= 0.012 [m^3/s]
        }
    }

    requirement def LiftHeightRequirement {
        subject system : AlJazariTwinCylinderPump;
        require constraint {
            system.deliveryHead >= 6.0 [m]
        }
    }

    requirement def ContinuousOperationRequirement {
        subject system : AlJazariTwinCylinderPump;
        require constraint {
            system.nominalOperatingDuration >= 8.0 [h]
        }
    }

    requirement def PassiveMechanicalControlRequirement {
        subject system : AlJazariTwinCylinderPump;
        require constraint {
            system.requiresElectronicControl == false
        }
    }

    part def IntakeReservoir {
        attribute storedVolume : ISQ::volume = 12.0 [m^3];
        attribute level : WaterLevel = 1.5 [m];

        port outlet : WaterPort;
    }

    part def FlowChannel {
        attribute channelWidth : ISQ::length = 0.75 [m];
        attribute channelDepth : ISQ::length = 0.45 [m];
        attribute availableFlow : VolumeRate = 0.16 [m^3/s];

        port inlet : WaterPort;
        port outlet : WaterPort;
    }

    part def UndershotWaterWheel {
        attribute diameter : ISQ::length = 2.4 [m];
        attribute bladeCount : ScalarValues::Integer = 18;
        attribute nominalSpeed : RotationalSpeed = 4.2 [rad/s];
        attribute outputTorque : Torque = 180.0 [N*m];
        attribute hydraulicEfficiency : Efficiency = 0.62;

        port waterIn : WaterPort;
        port waterOut : WaterPort;
        port shaft : RotaryShaftPort;

        action convertWaterFlowToRotation {
            in item inflow : Water;
            out item rotation : RotaryMotion;

            first start;
            then captureMomentum;
            then turnWheel;
            then deliverShaftPower;
            then done;

            action captureMomentum;
            action turnWheel;
            action deliverShaftPower;
        }
    }

    part def GearTrain {
        attribute gearRatio : ScalarValues::Real = 3.0;
        attribute mechanicalEfficiency : Efficiency = 0.88;

        port driveInput : RotaryShaftPort;
        port driveOutput : RotaryShaftPort;

        action reduceSpeedIncreaseTorque {
            in item inputMotion : RotaryMotion;
            out item outputMotion : RotaryMotion;
        }
    }

    part def Crankshaft {
        attribute crankRadius : ISQ::length = 0.18 [m];
        attribute phaseOffset : ISQ::planeAngle = 180 [deg];

        port rotaryInput : RotaryShaftPort;
        port leftRod : ReciprocatingLinkPort;
        port rightRod : ReciprocatingLinkPort;

        action convertRotationToReciprocation {
            in item rotary : RotaryMotion;
            out item leftStroke : ReciprocatingMotion;
            out item rightStroke : ReciprocatingMotion;
        }
    }

    part def ConnectingRod {
        attribute rodLength : ISQ::length = 0.9 [m];

        port crankEnd : ReciprocatingLinkPort;
        port pistonEnd : ReciprocatingLinkPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 1800 [Pa];
        attribute leakageRate : VolumeRate = 0.00002 [m^3/s];

        port upstream : WaterPort;
        port downstream : WaterPort;

        state def ValveState {
            state closed;
            state opening;
            state open;
            state closing;

            initial then closed;

            transition closed_to_opening
                first closed
                accept when upstream.water.pressure > downstream.water.pressure + crackingPressure
                then opening;

            transition opening_to_open
                first opening
                then open;

            transition open_to_closing
                first open
                accept when upstream.water.pressure <= downstream.water.pressure
                then closing;

            transition closing_to_closed
                first closing
                then closed;
        }

        exhibit state valveBehavior : ValveState;
    }

    part def PumpCylinder {
        attribute boreDiameter : ISQ::length = 0.22 [m];
        attribute strokeLength : StrokeLength = 0.36 [m];
        attribute displacementPerStroke : ISQ::volume = 0.0137 [m^3];
        attribute sealEfficiency : Efficiency = 0.91;

        port suction : WaterPort;
        port discharge : WaterPort;
        port pistonRod : ReciprocatingLinkPort;

        part suctionValve : CheckValve;
        part dischargeValve : CheckValve;

        connect suction to suctionValve.upstream;
        connect suctionValve.downstream to dischargeValve.upstream;
        connect dischargeValve.downstream to discharge;

        action pumpStroke {
            in item rodMotion : ReciprocatingMotion;
            inout item chamberWater : Water;
            out item pressurizedWater : Water;

            first determineStrokeDirection;
            then if suctionStroke then drawWater else compressWater;
            then transferThroughValve;
            then done;

            action determineStrokeDirection;
            action drawWater;
            action compressWater;
            action transferThroughValve;
        }

        state def CylinderCycle {
            state primed;
            state suctionStroke;
            state compressionStroke;
            state dischargeStroke;

            initial then primed;

            transition primed_to_suction
                first primed
                then suctionStroke;

            transition suction_to_compression
                first suctionStroke
                accept when pistonRod.motion.stroke >= strokeLength
                then compressionStroke;

            transition compression_to_discharge
                first compressionStroke
                accept when discharge.water.pressure >= 62000 [Pa]
                then dischargeStroke;

            transition discharge_to_suction
                first dischargeStroke
                then suctionStroke;
        }

        exhibit state cylinderBehavior : CylinderCycle;
    }

    part def DeliveryPipe {
        attribute length : ISQ::length = 8.5 [m];
        attribute innerDiameter : ISQ::length = 0.16 [m];
        attribute elevationGain : ISQ::length = 6.0 [m];
        attribute pressureLoss : Pressure = 8500 [Pa];

        port inlet : WaterPort;
        port outlet : WaterPort;
    }

    part def ElevatedStorageTank {
        attribute capacity : ISQ::volume = 5.0 [m^3];
        attribute currentVolume : ISQ::volume = 1.2 [m^3];
        attribute overflowLevel : WaterLevel = 2.2 [m];

        port inlet : WaterPort;
        port serviceOutlet : WaterPort;
        port overflow : WaterPort;
    }

    part def MechanicalGovernor {
        attribute overspeedLimit : RotationalSpeed = 7.0 [rad/s];
        attribute underspeedLimit : RotationalSpeed = 1.2 [rad/s];

        port shaftSense : RotaryShaftPort;
        port control : ControlPort;

        state def GovernorState {
            state ready;
            state regulating;
            state overspeedFault;
            state stalledFault;

            initial then ready;

            transition ready_to_regulating
                first ready
                accept when control.enabled
                then regulating;

            transition regulating_to_overspeed
                first regulating
                accept when shaftSense.motion.speed > overspeedLimit
                then overspeedFault;

            transition regulating_to_stalled
                first regulating
                accept when shaftSense.motion.speed < underspeedLimit
                then stalledFault;

            transition fault_to_ready
                first overspeedFault
                accept when not control.enabled
                then ready;

            transition stalled_to_ready
                first stalledFault
                accept when not control.enabled
                then ready;
        }

        exhibit state governorBehavior : GovernorState;
    }

    part def OrnamentalAutomatonIndicator {
        attribute displayMotionFrequency : ScalarValues::Real = 12.0;
        attribute indicatesOperation : ScalarValues::Boolean = true;

        port drive : RotaryShaftPort;

        action showSystemRunning {
            in item rotary : RotaryMotion;
        }
    }

    part def AlJazariTwinCylinderPump {
        doc /* High-level primary function: mechanically raise water from a low reservoir to an elevated storage tank by using flowing water to turn a wheel, converting that rotary motion through gears and a crankshaft into alternating piston strokes that lift and deliver water. */

        attribute deliveryHead : ISQ::length = 6.0 [m];
        attribute targetFlowRate : VolumeRate = 0.012 [m^3/s];
        attribute nominalOperatingDuration : ISQ::time = 8.0 [h];
        attribute requiresElectronicControl : ScalarValues::Boolean = false;
        attribute overallEfficiency : Efficiency = 0.49;

        port inlet : WaterPort;
        port outlet : WaterPort;
        port control : ControlPort;

        part reservoir : IntakeReservoir;
        part millRace : FlowChannel;
        part wheel : UndershotWaterWheel;
        part reductionGears : GearTrain;
        part crank : Crankshaft;
        part leftRod : ConnectingRod;
        part rightRod : ConnectingRod;
        part leftCylinder : PumpCylinder;
        part rightCylinder : PumpCylinder;
        part deliveryPipe : DeliveryPipe;
        part tank : ElevatedStorageTank;
        part governor : MechanicalGovernor;
        part automatonIndicator : OrnamentalAutomatonIndicator;

        connect inlet to reservoir.outlet;
        connect reservoir.outlet to millRace.inlet;
        connect millRace.outlet to wheel.waterIn;
        connect wheel.shaft to reductionGears.driveInput;
        connect reductionGears.driveOutput to crank.rotaryInput;
        connect crank.leftRod to leftRod.crankEnd;
        connect crank.rightRod to rightRod.crankEnd;
        connect leftRod.pistonEnd to leftCylinder.pistonRod;
        connect rightRod.pistonEnd to rightCylinder.pistonRod;
        connect reservoir.outlet to leftCylinder.suction;
        connect reservoir.outlet to rightCylinder.suction;
        connect leftCylinder.discharge to deliveryPipe.inlet;
        connect rightCylinder.discharge to deliveryPipe.inlet;
        connect deliveryPipe.outlet to tank.inlet;
        connect tank.serviceOutlet to outlet;
        connect reductionGears.driveOutput to governor.shaftSense;
        connect reductionGears.driveOutput to automatonIndicator.drive;
        connect control to governor.control;

        action operatePump {
            in attribute startCommand : ScalarValues::Boolean;
            out item deliveredWater : Water;

            first awaitStart;
            then admitFlowToWheel;
            then rotateWheel;
            then transmitPower;
            then alternatePistonStrokes;
            then liftWater;
            then storeWater;
            then done;

            action awaitStart;
            action admitFlowToWheel;
            action rotateWheel;
            action transmitPower;
            action alternatePistonStrokes;
            action liftWater;
            action storeWater;
        }

        state def PumpSystemState {
            state idle;
            state priming;
            state running;
            state delivering;
            state lowFlow;
            state fault;
            state stopped;

            initial then idle;

            transition idle_to_priming
                first idle
                accept when control.enabled
                then priming;

            transition priming_to_running
                first priming
                accept when reservoir.level > 0.4 [m]
                then running;

            transition running_to_delivering
                first running
                accept when deliveryPipe.outlet.water.flowRate >= targetFlowRate
                then delivering;

            transition delivering_to_lowFlow
                first delivering
                accept when deliveryPipe.outlet.water.flowRate < 0.006 [m^3/s]
                then lowFlow;

            transition lowFlow_to_running
                first lowFlow
                accept when millRace.availableFlow >= 0.08 [m^3/s]
                then running;

            transition running_to_fault
                first running
                accept when governor.control.fault
                then fault;

            transition delivering_to_fault
                first delivering
                accept when governor.control.fault
                then fault;

            transition fault_to_stopped
                first fault
                accept when not control.enabled
                then stopped;

            transition stopped_to_idle
                first stopped
                then idle;
        }

        exhibit state systemBehavior : PumpSystemState;
    }

    part alJazariInspiredPumpSystem : AlJazariTwinCylinderPump;

    requirement raiseWater : RaiseWaterRequirement {
        subject system = alJazariInspiredPumpSystem;
    }

    requirement liftHeight : LiftHeightRequirement {
        subject system = alJazariInspiredPumpSystem;
    }

    requirement continuousOperation : ContinuousOperationRequirement {
        subject system = alJazariInspiredPumpSystem;
    }

    requirement passiveMechanicalControl : PassiveMechanicalControlRequirement {
        subject system = alJazariInspiredPumpSystem;
    }

    satisfy raiseWater by alJazariInspiredPumpSystem;
    satisfy liftHeight by alJazariInspiredPumpSystem;
    satisfy continuousOperation by alJazariInspiredPumpSystem;
    satisfy passiveMechanicalControl by alJazariInspiredPumpSystem;
}