package SteamEngineSystem {
    attribute def StartCommand;
    attribute def StopCommand;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SteamPressure :> PressureValue;
    attribute def SteamTemperature :> ThermodynamicTemperatureValue;
    attribute def ValvePosition :> Real;
    attribute def PistonDisplacement :> LengthValue;
    
    item def Water {
        attribute mass : MassValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def Steam {
        attribute pressure : SteamPressure;
        attribute temperature : SteamTemperature;
        attribute massFlowRate : MassFlowRateValue;
    }
    
    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : AngularVelocityValue;
    }
    
    port def WaterInletPort {
        in item water : Water;
    }
    
    port def SteamPort {
        in item steamIn : Steam;
        out item steamOut : Steam;
    }
    
    port def MechanicalOutputPort {
        out item power : MechanicalPower;
    }
    
    port def ExhaustPort {
        out item exhaustSteam : Steam;
    }
    
    part def Boiler {
        attribute operatingPressure : SteamPressure;
        attribute waterLevel : Real;
        port waterInlet : WaterInletPort;
        port steamOutlet : SteamPort;
        
        action boilWater {
            in waterSupply : Water;
            in heatInput : PowerValue;
            out steamProduced : Steam;
        }
    }
    
    part def ThrottleValve {
        attribute position : ValvePosition;
        port steamInlet : SteamPort;
        port steamOutlet : SteamPort;
        
        action regulateFlow {
            in steamIn : Steam;
            in valvePos : ValvePosition;
            out steamOut : Steam;
        }
    }
    
    part def Cylinder {
        attribute bore : LengthValue;
        attribute stroke : LengthValue;
        attribute pistonPosition : PistonDisplacement;
        port steamAdmission : SteamPort;
        port exhaustPort : ExhaustPort;
        
        part piston {
            attribute position : PistonDisplacement;
            attribute velocity : SpeedValue;
        }
        
        action expandSteam {
            in admittedSteam : Steam;
            in pistonPos : PistonDisplacement;
            out linearForce : ForceValue;
            out exhaustedSteam : Steam;
        }
    }
    
    part def ConnectingRod {
        attribute length : LengthValue;
        
        action transmitForce {
            in pistonForce : ForceValue;
            in rodAngle : Real;
            out crankForce : ForceValue;
        }
    }
    
    part def Crankshaft {
        attribute crankRadius : LengthValue;
        attribute angularPosition : Real;
        attribute angularVelocity : AngularVelocityValue;
        port powerOutput : MechanicalOutputPort;
        
        action convertToRotation {
            in linearForce : ForceValue;
            in crankAngle : Real;
            out outputTorque : TorqueValue;
        }
    }
    
    part def Flywheel {
        attribute mass : MassValue;
        attribute radius : LengthValue;
        attribute momentOfInertia : Real;
        
        action smoothRotation {
            in variableTorque : TorqueValue;
            out steadyTorque : TorqueValue;
        }
    }
    
    part def Governor {
        attribute setpointSpeed : AngularVelocityValue;
        attribute measuredSpeed : AngularVelocityValue;
        
        action controlSpeed {
            in currentSpeed : AngularVelocityValue;
            in targetSpeed : AngularVelocityValue;
            out throttleCommand : ValvePosition;
        }
    }
    
    part def Condenser {
        attribute coolingWaterFlow : MassFlowRateValue;
        port exhaustInlet : ExhaustPort;
        port waterOutlet : WaterInletPort;
        
        action condenseSteam {
            in exhaustSteam : Steam;
            in coolingWater : Water;
            out condensedWater : Water;
        }
    }
    
    part def FeedPump {
        attribute pumpPressure : PressureValue;
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterInletPort;
        
        action pumpWater {
            in waterIn : Water;
            in pumpPower : PowerValue;
            out pressurizedWater : Water;
        }
    }
    
    action def HeatWater {
        in waterInput : Water;
        in fuelEnergy : PowerValue;
        out highPressureSteam : Steam;
    }
    
    action def ThrottleSteam {
        in steamSupply : Steam;
        in throttlePosition : ValvePosition;
        out controlledSteam : Steam;
    }
    
    action def PerformExpansion {
        in workingSteam : Steam;
        in cylinderVolume : VolumeValue;
        out mechanicalForce : ForceValue;
        out lowPressureSteam : Steam;
    }
    
    action def TransmitPower {
        in pistonForce : ForceValue;
        in mechanicalAdvantage : Real;
        out rotationalTorque : TorqueValue;
    }
    
    action def DeliverWork {
        in torque : TorqueValue;
        in speed : AngularVelocityValue;
        out usefulPower : PowerValue;
    }
    
    action def RecycleSteam {
        in exhaustedSteam : Steam;
        in coolingCapacity : PowerValue;
        out feedWater : Water;
    }
    
    action def SteamEngineCycle {
        doc /* Primary function: Convert thermal energy from steam into mechanical rotational power through cyclic expansion and condensation. */
        
        first start;
        
        then action heatWater : HeatWater {
            in waterInput : Water;
            in fuelEnergy : PowerValue;
            out highPressureSteam : Steam;
        }
        
        flow heatWater.highPressureSteam to throttleSteam.steamSupply;
        
        then action throttleSteam : ThrottleSteam {
            in steamSupply : Steam;
            in throttlePosition : ValvePosition;
            out controlledSteam : Steam;
        }
        
        flow throttleSteam.controlledSteam to performExpansion.workingSteam;
        
        then action performExpansion : PerformExpansion {
            in workingSteam : Steam;
            in cylinderVolume : VolumeValue;
            out mechanicalForce : ForceValue;
            out lowPressureSteam : Steam;
        }
        
        flow performExpansion.mechanicalForce to transmitPower.pistonForce;
        flow performExpansion.lowPressureSteam to recycleSteam.exhaustedSteam;
        
        then action transmitPower : TransmitPower {
            in pistonForce : ForceValue;
            in mechanicalAdvantage : Real;
            out rotationalTorque : TorqueValue;
        }
        
        flow transmitPower.rotationalTorque to deliverWork.torque;
        
        then action deliverWork : DeliverWork {
            in torque : TorqueValue;
            in speed : AngularVelocityValue;
            out usefulPower : PowerValue;
        }
        
        then action recycleSteam : RecycleSteam {
            in exhaustedSteam : Steam;
            in coolingCapacity : PowerValue;
            out feedWater : Water;
        }
        
        flow recycleSteam.feedWater to heatWater.waterInput;
        
        then done;
    }
    
    state def EngineOperatingStates {
        entry;
        state stopped;
        
        transition stopped_to_starting
            first stopped
            accept StartCommand
            then starting;
        
        state starting;
        
        transition starting_to_warming
            first starting
            if boilerPressure >= 0.5
            then warming;
        
        state warming;
        
        transition warming_to_running
            first warming
            if boilerPressure >= 1.0
            then running;
        
        state running;
        
        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;
        
        state stopping;
        
        transition stopping_to_stopped
            first stopping
            if crankshaftSpeed < 10.0
            then stopped;
    }
    
    part steamEngine : SteamEngine {
        attribute ratedPower : PowerValue = 75.0 [kW];
        attribute operatingSpeed : AngularVelocityValue = 200.0 [SI::rpm];
        attribute thermalEfficiency : Real;
        
        part boiler : Boiler {
            attribute :>> operatingPressure = 1.2e6 [Pa];
            attribute :>> waterLevel = 0.8;
        }
        
        part throttleValve : ThrottleValve {
            attribute :>> position = 0.5;
        }
        
        part cylinder : Cylinder {
            attribute :>> bore = 300.0 [mm];
            attribute :>> stroke = 450.0 [mm];
            attribute :>> pistonPosition = 0.0 [mm];
        }
        
        part connectingRod : ConnectingRod {
            attribute :>> length = 600.0 [mm];
        }
        
        part crankshaft : Crankshaft {
            attribute :>> crankRadius = 225.0 [mm];
            attribute :>> angularVelocity = 200.0 [SI::rpm];
        }
        
        part flywheel : Flywheel {
            attribute :>> mass = 800.0 [kg];
            attribute :>> radius = 0.75 [m];
        }
        
        part governor : Governor {
            attribute :>> setpointSpeed = 200.0 [SI::rpm];
        }
        
        part condenser : Condenser {
            attribute :>> coolingWaterFlow = 5.0 [kg/s];
        }
        
        part feedPump : FeedPump {
            attribute :>> pumpPressure = 1.5e6 [Pa];
        }
        
        interface boilerToThrottle
            connect boiler.steamOutlet to throttleValve.steamInlet;
        
        interface throttleToCylinder
            connect throttleValve.steamOutlet to cylinder.steamAdmission;
        
        interface cylinderToCondenser
            connect cylinder.exhaustPort to condenser.exhaustInlet;
        
        interface condenserToPump
            connect condenser.waterOutlet to feedPump.waterInlet;
        
        interface pumpToBoiler
            connect feedPump.waterOutlet to boiler.waterInlet;
        
        perform action operateEngine : SteamEngineCycle;
        
        exhibit state engineStates : EngineOperatingStates;
    }
    
    requirement def EfficiencyRequirement {
        doc /* The steam engine shall achieve minimum thermal efficiency. */
        subject engine : SteamEngine;
        attribute minimumEfficiency : Real;
        require constraint {
            engine.thermalEfficiency >= minimumEfficiency
        }
    }
    
    requirement def PressureSafetyRequirement {
        doc /* The boiler operating pressure shall not exceed maximum safe limit. */
        subject engine : SteamEngine;
        attribute maxSafePressure : SteamPressure;
        require constraint {
            engine.boiler.operatingPressure <= maxSafePressure
        }
    }
    
    requirement def PowerOutputRequirement {
        doc /* The steam engine shall deliver minimum rated power output. */
        subject engine : SteamEngine;
        attribute minimumPower : PowerValue;
        attribute actualPower : PowerValue;
        require constraint {
            actualPower >= minimumPower
        }
    }
    
    requirement def SpeedRegulationRequirement {
        doc /* The governor shall maintain speed within tolerance. */
        subject engine : SteamEngine;
        attribute speedTolerance : AngularVelocityValue;
        attribute speedError : AngularVelocityValue;
        require constraint {
            speedError <= speedTolerance
        }
    }
    
    requirement engineEfficiency : EfficiencyRequirement {
        subject engine = steamEngine;
        attribute :>> minimumEfficiency = 0.12;
    }
    
    requirement boilerSafety : PressureSafetyRequirement {
        subject engine = steamEngine;
        attribute :>> maxSafePressure = 1.5e6 [Pa];
    }
    
    requirement powerOutput : PowerOutputRequirement {
        subject engine = steamEngine;
        attribute :>> minimumPower = 75.0 [kW];
        attribute :>> actualPower = steamEngine.ratedPower;
    }
    
    requirement speedRegulation : SpeedRegulationRequirement {
        subject engine = steamEngine;
        attribute :>> speedTolerance = 10.0 [SI::rpm];
        attribute :>> speedError = 5.0 [SI::rpm];
    }
    
    part def SteamEngine {
        attribute ratedPower : PowerValue;
        attribute operatingSpeed : AngularVelocityValue;
        attribute thermalEfficiency : Real;
        
        part boiler : Boiler;
        part throttleValve : ThrottleValve;
        part cylinder : Cylinder;
        part connectingRod : ConnectingRod;
        part crankshaft : Crankshaft;
        part flywheel : Flywheel;
        part governor : Governor;
        part condenser : Condenser;
        part feedPump : FeedPump;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SteamEngineSystem::*;

    part steamEngine : Boiler {
        exhibit state sm : EngineOperatingStates;
    }

    action orchestrator {
        item testWaterInput : Water {
            attribute mass : MassValue;
            attribute temperature : ThermodynamicTemperatureValue;
        }
        attribute testFuelEnergy : PowerValue;
        action actionProbe : HeatWater {
            in waterInput = testWaterInput;
            in fuelEnergy = testFuelEnergy;
        }
        attribute testStartCommand : StartCommand;
        attribute testStopCommand : StopCommand;
        action triggerStartCommand send testStartCommand to steamEngine;
        action triggerStopCommand send testStopCommand to steamEngine;
        first actionProbe;
        then triggerStartCommand;
        then triggerStopCommand;
    }
}
