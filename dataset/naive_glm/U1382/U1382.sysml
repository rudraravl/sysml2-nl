package AutomobileSystem {
    import ScalarValues::*;
    
    // ===== Units =====
    unit kg;
    unit km_h;
    unit N;
    unit Nm;
    unit L;
    unit rpm;
    unit Lps;
    unit deg;
    unit ratio;
    unit kW;
    unit mps2;
    
    // ===== Value Types =====
    value type MassValue :> Real { unit kg; }
    value type SpeedValue :> Real { unit km_h; }
    value type ForceValue :> Real { unit N; }
    value type TorqueValue :> Real { unit Nm; }
    value type VolumeValue :> Real { unit L; }
    value type RotationalSpeedValue :> Real { unit rpm; }
    value type FuelFlowValue :> Real { unit Lps; }
    value type AngleValue :> Real { unit deg; }
    value type GearRatioValue :> Real { unit ratio; }
    value type PowerValue :> Real { unit kW; }
    value type AccelerationValue :> Real { unit mps2; }
    
    // ===== Item Definitions =====
    item def Fuel {
        attribute octaneRating : Integer = 91;
        attribute density : Real = 0.75;
    }
    
    item def ThrottleCommand {
        attribute position : Real[0..1] = 0;
    }
    
    item def BrakeCommand {
        attribute pressure : ForceValue = 0 [N];
    }
    
    item def SteeringCommand {
        attribute angle : AngleValue = 0 [deg];
    }
    
    item def SpeedFeedback {
        attribute speed : SpeedValue = 0 [km_h];
    }
    
    item def RPMFeedback {
        attribute rpm : RotationalSpeedValue = 0 [rpm];
    }
    
    item def FuelFlowCommand {
        attribute flow : FuelFlowValue = 0 [Lps];
    }
    
    item def TorqueFlow {
        attribute torque : TorqueValue = 0 [Nm];
    }
    
    item def PowerFlow {
        attribute power : PowerValue = 0 [kW];
    }
    
    item def BrakeForce {
        attribute force : ForceValue = 0 [N];
    }
    
    item def SteeringAngle {
        attribute angle : AngleValue = 0 [deg];
    }
    
    item def WheelRotation {
        attribute rpm : RotationalSpeedValue = 0 [rpm];
    }
    
    // ===== Port Definitions =====
    port def ThrottleInterface {
        in throttle : ThrottleCommand;
    }
    
    port def BrakeInterface {
        in brake : BrakeCommand;
    }
    
    port def SteeringInterface {
        in steering : SteeringCommand;
    }
    
    port def SpeedInterface {
        in speed : SpeedFeedback;
    }
    
    port def RPMInterface {
        in rpm : RPMFeedback;
    }
    
    port def FuelFlowInterface {
        in fuelFlow : FuelFlowCommand;
    }
    
    port def FuelSupplyInterface {
        in fuel : Fuel;
    }
    
    port def TorqueInterface {
        in torque : TorqueFlow;
    }
    
    port def PowerInterface {
        in power : PowerFlow;
    }
    
    port def BrakeForceInterface {
        in force : BrakeForce;
    }
    
    port def SteeringAngleInterface {
        in angle : SteeringAngle;
    }
    
    port def WheelRotationInterface {
        in rotation : WheelRotation;
    }
    
    // ===== Leaf Part Definitions =====
    
    part def Driver {
        port throttlePort : ~ThrottleInterface;
        port brakePort : ~BrakeInterface;
        port steeringPort : ~SteeringInterface;
        
        attribute alertness : Real = 1.0;
        attribute reactionTime : Real = 0.25;
        
        action def operateVehicle {
            in throttleInput : Real;
            in brakeInput : Real;
            in steeringInput : Real;
            out throttleCmd : ThrottleCommand;
            out brakeCmd : BrakeCommand;
            out steeringCmd : SteeringCommand;
        }
    }
    
    part def AcceleratorPedal {
        port driverInput : ThrottleInterface;
        port throttleOutput : ~ThrottleInterface;
        
        attribute maxTravel : Real = 1.0;
        attribute currentPosition : Real = 0;
        
        action def translatePosition {
            in driverPosition : Real;
            out throttleCmd : ThrottleCommand;
        }
    }
    
    part def BrakePedal {
        port driverInput : BrakeInterface;
        port brakeOutput : ~BrakeInterface;
        
        attribute maxForce : ForceValue = 500 [N];
        attribute currentPressure : ForceValue = 0 [N];
        
        action def translatePressure {
            in driverPressure : ForceValue;
            out brakeCmd : BrakeCommand;
        }
    }
    
    part def SteeringWheel {
        port driverInput : SteeringInterface;
        port steeringOutput : ~SteeringInterface;
        
        attribute maxAngle : AngleValue = 720 [deg];
        attribute currentAngle : AngleValue = 0 [deg];
        
        action def translateRotation {
            in driverRotation : AngleValue;
            out steeringCmd : SteeringCommand;
        }
    }
    
    part def Engine {
        port fuelSupply : FuelSupplyInterface;
        port fuelFlowCmd : FuelFlowInterface;
        port powerOutput : ~PowerInterface;
        port torqueOutput : ~TorqueInterface;
        port rpmOutput : ~RPMInterface;
        
        attribute maxPower : PowerValue = 150 [kW];
        attribute maxTorque : TorqueValue = 300 [Nm];
        attribute displacement : VolumeValue = 2.0 [L];
        attribute currentRPM : RotationalSpeedValue = 0 [rpm];
        attribute currentFuelFlow : FuelFlowValue = 0 [Lps];
        attribute isRunning : Boolean = false;
        
        action def generatePower {
            in fuel : Fuel;
            in fuelFlow : FuelFlowCommand;
            out power : PowerFlow;
            out torque : TorqueFlow;
            out rpm : RPMFeedback;
        }
        
        state machine EngineStates {
            state off;
            state idling;
            state running;
            
            transition off_to_idling
                first off
                if currentFuelFlow > 0 [Lps]
                then idling;
            
            transition idling_to_running
                first idling
                if currentRPM > 800 [rpm]
                then running;
            
            transition running_to_idling
                first running
                if currentRPM <= 800 [rpm]
                then idling;
            
            transition idling_to_off
                first idling
                if currentFuelFlow <= 0 [Lps]
                then off;
        }
    }
    
    part def Transmission {
        port powerInput : PowerInterface;
        port torqueInput : TorqueInterface;
        port torqueOutputLeft : ~TorqueInterface;
        port torqueOutputRight : ~TorqueInterface;
        
        attribute gearRatios : Real[6] = (4.5, 3.0, 2.0, 1.5, 1.2, 1.0);
        attribute currentGear : Integer = 1;
        attribute currentRatio : GearRatioValue = 4.5 [ratio];
        
        action def shiftGear {
            in targetGear : Integer;
            out newRatio : GearRatioValue;
        }
        
        action def transmitPower {
            in inputTorque : TorqueFlow;
            in ratio : GearRatioValue;
            out outputTorqueLeft : TorqueFlow;
            out outputTorqueRight : TorqueFlow;
        }
    }
    
    part def FuelTank {
        port fuelOutput : ~FuelSupplyInterface;
        
        attribute capacity : VolumeValue = 50 [L];
        attribute currentLevel : VolumeValue = 50 [L];
        
        action def supplyFuel {
            in requestedFlow : FuelFlowValue;
            out fuel : Fuel;
        }
        
        state machine FuelTankStates {
            state full;
            state normal;
            state low;
            state empty;
            
            transition full_to_normal
                first full
                if currentLevel < capacity * 0.8
                then normal;
            
            transition normal_to_low
                first normal
                if currentLevel < capacity * 0.2
                then low;
            
            transition low_to_empty
                first low
                if currentLevel <= 0 [L]
                then empty;
            
            transition low_to_normal
                first low
                if currentLevel >= capacity * 0.2
                then normal;
            
            transition normal_to_full
                first normal
                if currentLevel >= capacity * 0.8
                then full;
        }
    }
    
    part def ECU {
        port throttleInput : ThrottleInterface;
        port speedInput : SpeedInterface;
        port rpmInput : RPMInterface;
        port fuelFlowOutput : ~FuelFlowInterface;
        
        attribute processingSpeed : Real = 100;
        attribute targetFuelFlow : FuelFlowValue = 0 [Lps];
        attribute optimalAirFuelRatio : Real = 14.7;
        
        action def calculateFuelFlow {
            in throttle : ThrottleCommand;
            in speed : SpeedFeedback;
            in rpm : RPMFeedback;
            out fuelFlow : FuelFlowCommand;
        }
        
        action def monitorEngine {
            in rpm : RPMFeedback;
            in speed : SpeedFeedback;
            out adjustedFlow : FuelFlowCommand;
        }
    }
    
    part def BrakeSystem {
        port brakeInput : BrakeInterface;
        port frontLeftBrakeOut : ~BrakeForceInterface;
        port frontRightBrakeOut : ~BrakeForceInterface;
        port rearLeftBrakeOut : ~BrakeForceInterface;
        port rearRightBrakeOut : ~BrakeForceInterface;
        
        attribute maxBrakingForce : ForceValue = 15000 [N];
        attribute currentBrakingForce : ForceValue = 0 [N];
        attribute responseTime : Real = 0.05;
        
        action def applyBrakes {
            in command : BrakeCommand;
            out frontLeftForce : BrakeForce;
            out frontRightForce : BrakeForce;
            out rearLeftForce : BrakeForce;
            out rearRightForce : BrakeForce;
        }
    }
    
    part def SteeringSystem {
        port steeringInput : SteeringInterface;
        port frontLeftSteeringOut : ~SteeringAngleInterface;
        port frontRightSteeringOut : ~SteeringAngleInterface;
        
        attribute maxSteerAngle : AngleValue = 35 [deg];
        attribute currentSteerAngle : AngleValue = 0 [deg];
        
        action def adjustSteering {
            in command : SteeringCommand;
            out leftAngle : SteeringAngle;
            out rightAngle : SteeringAngle;
        }
    }
    
    part def Wheel {
        port torqueInput : TorqueInterface;
        port brakeInput : BrakeForceInterface;
        port steeringInput : SteeringAngleInterface;
        port rotationOutput : ~WheelRotationInterface;
        
        attribute radius : Real = 0.3;
        attribute position : String;
        attribute isDriven : Boolean = false;
        attribute isBraked : Boolean = false;
        attribute currentRotation : RotationalSpeedValue = 0 [rpm];
        
        action def rotate {
            in torque : TorqueFlow;
            in brakeForce : BrakeForce;
            out rotation : WheelRotation;
        }
    }
    
    part def Speedometer {
        port wheelRotationFL : WheelRotationInterface;
        port wheelRotationFR : WheelRotationInterface;
        port wheelRotationRL : WheelRotationInterface;
        port wheelRotationRR : WheelRotationInterface;
        port speedOutput : ~SpeedInterface;
        
        attribute currentSpeed : SpeedValue = 0 [km_h];
        attribute updateRate : Real = 10;
        
        action def calculateSpeed {
            in rotationFL : WheelRotation;
            in rotationFR : WheelRotation;
            in rotationRL : WheelRotation;
            in rotationRR : WheelRotation;
            out speed : SpeedFeedback;
        }
    }
    
    // ===== Composite Part Definitions =====
    
    part def Powertrain {
        part engine : Engine;
        part transmission : Transmission;
        part fuelTank : FuelTank;
        part ecu : ECU;
        
        connect ecu.fuelFlowOutput to engine.fuelFlowCmd;
        connect fuelTank.fuelOutput to engine.fuelSupply;
        connect engine.powerOutput to transmission.powerInput;
        connect engine.torqueOutput to transmission.torqueInput;
        connect engine.rpmOutput to ecu.rpmInput;
    }
    
    part def Automobile {
        attribute totalMass : MassValue = 1800 [kg];
        attribute maxSpeed : SpeedValue = 200 [km_h];
        attribute currentSpeed : SpeedValue = 0 [km_h];
        attribute ignitionOn : Boolean = false;
        attribute engineRunning : Boolean = false;
        attribute throttlePressed : Boolean = false;
        attribute brakePressed : Boolean = false;
        attribute emergencyBrakeActive : Boolean = false;
        
        part driver : Driver;
        part acceleratorPedal : AcceleratorPedal;
        part brakePedal : BrakePedal;
        part steeringWheel : SteeringWheel;
        part powertrain : Powertrain;
        part brakeSystem : BrakeSystem;
        part steeringSystem : SteeringSystem;
        part frontLeftWheel : Wheel { :>> position = "frontLeft"; }
        part frontRightWheel : Wheel { :>> position = "frontRight"; }
        part rearLeftWheel : Wheel { :>> position = "rearLeft"; :>> isDriven = true; }
        part rearRightWheel : Wheel { :>> position = "rearRight"; :>> isDriven = true; }
        part speedometer : Speedometer;
        
        connect driver.throttlePort to acceleratorPedal.driverInput;
        connect driver.brakePort to brakePedal.driverInput;
        connect driver.steeringPort to steeringWheel.driverInput;
        
        connect acceleratorPedal.throttleOutput to powertrain.ecu.throttleInput;
        connect brakePedal.brakeOutput to brakeSystem.brakeInput;
        connect steeringWheel.steeringOutput to steeringSystem.steeringInput;
        
        connect speedometer.speedOutput to powertrain.ecu.speedInput;
        
        connect powertrain.transmission.torqueOutputLeft to rearLeftWheel.torqueInput;
        connect powertrain.transmission.torqueOutputRight to rearRightWheel.torqueInput;
        
        connect brakeSystem.frontLeftBrakeOut to frontLeftWheel.brakeInput;
        connect brakeSystem.frontRightBrakeOut to frontRightWheel.brakeInput;
        connect brakeSystem.rearLeftBrakeOut to rearLeftWheel.brakeInput;
        connect brakeSystem.rearRightBrakeOut to rearRightWheel.brakeInput;
        
        connect steeringSystem.frontLeftSteeringOut to frontLeftWheel.steeringInput;
        connect steeringSystem.frontRightSteeringOut to frontRightWheel.steeringInput;
        
        connect frontLeftWheel.rotationOutput to speedometer.wheelRotationFL;
        connect frontRightWheel.rotationOutput to speedometer.wheelRotationFR;
        connect rearLeftWheel.rotationOutput to speedometer.wheelRotationRL;
        connect rearRightWheel.rotationOutput to speedometer.wheelRotationRR;
        
        state machine AutomobileLifecycle {
            state parked;
            state starting;
            state idling;
            state driving;
            state emergencyBraking;
            state shuttingDown;
            
            transition parked_to_starting
                first parked
                if ignitionOn
                then starting;
            
            transition starting_to_idling
                first starting
                if engineRunning
                then idling;
            
            transition idling_to_driving
                first idling
                if throttlePressed
                then driving;
            
            transition driving_to_emergencyBraking
                first driving
                if brakePressed and currentSpeed > 50 [km_h]
                then emergencyBraking;
            
            transition driving_to_idling
                first driving
                if not throttlePressed
                then idling;
            
            transition emergencyBraking_to_parked
                first emergencyBraking
                if currentSpeed <= 0 [km_h]
                then parked;
            
            transition idling_to_shuttingDown
                first idling
                if not ignitionOn
                then shuttingDown;
            
            transition shuttingDown_to_parked
                first shuttingDown
                if not engineRunning
                then parked;
        }
    }
    
    // ===== Requirements =====
    
    requirement def MassRequirement {
        doc /* The total mass of the automobile shall be less than 2000 kg. */
        subject automobile : Automobile;
        constraint { automobile.totalMass < 2000 [kg] }
    }
    
    requirement def MaxSpeedRequirement {
        doc /* The automobile shall achieve a maximum speed of at least 180 km/h. */
        subject automobile : Automobile;
        constraint { automobile.maxSpeed >= 180 [km_h] }
    }
    
    requirement def BrakingForceRequirement {
        doc /* The brake system shall provide a minimum braking force of 10000 N. */
        subject brakeSystem : BrakeSystem;
        constraint { brakeSystem.maxBrakingForce >= 10000 [N] }
    }
    
    requirement def FuelCapacityRequirement {
        doc /* The fuel tank shall have a capacity of at least 40 L for long-distance travel. */
        subject fuelTank : FuelTank;
        constraint { fuelTank.capacity >= 40 [L] }
    }
    
    requirement def EnginePowerRequirement {
        doc /* The engine shall produce at least 100 kW of maximum power. */
        subject engine : Engine;
        constraint { engine.maxPower >= 100 [kW] }
    }
    
    requirement def SafetyRequirement {
        doc /* The automobile shall meet all safety requirements including mass, speed, and braking. */
        subject automobile : Automobile;
        constraint { automobile.totalMass < 2000 [kg] }
        constraint { automobile.maxSpeed >= 180 [km_h] }
    }
    
    requirement automobileMassReq : MassRequirement;
    requirement automobileSpeedReq : MaxSpeedRequirement;
    requirement brakingForceReq : BrakingForceRequirement;
    requirement fuelCapacityReq : FuelCapacityRequirement;
    requirement enginePowerReq : EnginePowerRequirement;
    requirement automobileSafetyReq : SafetyRequirement;
}
