package AutomobileSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    public import Definitions::*;
    
    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;
        public import InterfaceDefinitions::*;
        
        package ItemDefinitions {
            item def Fuel;
            item def Torque;
            item def Power;
            item def BrakingForce;
            item def SteeringAngle;
            item def Speed;
            item def RPM;
            item def FuelFlow;
            item def StartSignal;
            item def StopSignal;
            item def ThrottleCmd;
            item def ReleaseThrottle;
            item def FuelDrop;
            item def FuelLowThreshold;
            item def FuelEmptyThreshold;
            item def IgnitionOn;
            item def EngineStarted;
            item def EngageGear;
            item def HardBrake;
            item def VehicleStopped;
            item def DisengageGear;
            item def IgnitionOff;
            item def EngineOff;
        }
        
        package PortDefinitions {
            port def ThrottleCmdPort;
            port def BrakeCmdPort;
            port def SteeringCmdPort;
            port def DrivePwrPort;
            port def FuelFlowPort;
            port def SpeedFeedbackPort;
            port def RPMFeedbackPort;
            port def WheelSpeedPort;
        }
        
        package ActionDefinitions {
            action def GeneratePower;
            action def ApplyBraking;
            action def AdjustSteering;
            action def CalculateFuelFlow;
            action def AmplifyTorque;
        }
        
        package StateDefinitions {
            state def EngineStates {
                entry action initial;
                state off;
                state idling;
                state running;
                transition initial then off;
                transition off_to_idling first off accept StartSignal then idling;
                transition idling_to_running first idling accept ThrottleCmd then running;
                transition running_to_idling first running accept ReleaseThrottle then idling;
                transition off_to_off first off accept StopSignal then off;
                transition idling_to_off first idling accept StopSignal then off;
                transition running_to_off first running accept StopSignal then off;
            }
            
            state def FuelTankStates {
                entry action initial;
                state full;
                state normal;
                state low;
                state empty;
                transition initial then full;
                transition full_to_normal first full accept FuelDrop then normal;
                transition normal_to_low first normal accept FuelLowThreshold then low;
                transition low_to_empty first low accept FuelEmptyThreshold then empty;
            }
            
            state def VehicleStates {
                entry action initial;
                state parked;
                state starting;
                state idling;
                state driving;
                state emergencyBraking;
                state shuttingDown;
                transition initial then parked;
                transition parked_to_starting first parked accept IgnitionOn then starting;
                transition starting_to_idling first starting accept EngineStarted then idling;
                transition idling_to_driving first idling accept EngageGear then driving;
                transition driving_to_emergencyBraking first driving accept HardBrake then emergencyBraking;
                transition emergencyBraking_to_parked first emergencyBraking accept VehicleStopped then parked;
                transition driving_to_idling first driving accept DisengageGear then idling;
                transition idling_to_shuttingDown first idling accept IgnitionOff then shuttingDown;
                transition shuttingDown_to_parked first shuttingDown accept EngineOff then parked;
            }
        }
        
        package PartDefinitions {
            part def Vehicle {
                attribute mass :> ISQ::mass;
                attribute maxSpeed :> ISQ::speed;
                
                exhibit state vehicleStates: VehicleStates;
                
                part driver: Driver;
                part acceleratorPedal: AcceleratorPedal;
                part brakePedal: BrakePedal;
                part steeringWheel: SteeringWheel;
                
                part powertrain: Powertrain;
                part brakeSystem: BrakeSystem;
                part steeringSystem: SteeringSystem;
                part speedometer: Speedometer;
                part frontWheels: Wheel[2];
                part rearWheels: Wheel[2];
                
                interface driverToAccel: DriverToAcceleratorInterface
                    connect driver.throttleCmdPort to acceleratorPedal.throttleCmdPort;
                interface driverToBrake: DriverToBrakeInterface
                    connect driver.brakeCmdPort to brakePedal.brakeCmdPort;
                interface driverToSteer: DriverToSteeringInterface
                    connect driver.steeringCmdPort to steeringWheel.steeringCmdPort;
                    
                interface accelToECU: ThrottleInterface
                    connect acceleratorPedal.throttleCmdPort to powertrain.ecu.throttleCmdPort;
                interface brakeToSys: BrakeInterface
                    connect brakePedal.brakeCmdPort to brakeSystem.brakeCmdPort;
                interface steerToSys: SteeringInterface
                    connect steeringWheel.steeringCmdPort to steeringSystem.steeringCmdPort;
                    
                interface ecuToEngine: ECUToEngineInterface
                    connect powertrain.ecu.fuelFlowPort to powertrain.engine.fuelFlowPort;
                interface engineToTrans: EngineToTransmissionInterface
                    connect powertrain.engine.drivePwrPort to powertrain.transmission.drivePwrPort;
                interface transToWheels: TransmissionToWheelInterface
                    connect powertrain.transmission.wheelDrivePort to frontWheels.wheelDrivePort;
                    connect powertrain.transmission.wheelDrivePort to rearWheels.wheelDrivePort;
                
                interface brakeToWheels: BrakeToWheelInterface
                    connect brakeSystem.wheelBrakePort to frontWheels.wheelBrakePort;
                    connect brakeSystem.wheelBrakePort to rearWheels.wheelBrakePort;
                interface steerToFrontWheels: SteeringToWheelInterface
                    connect steeringSystem.wheelSteerPort to frontWheels.wheelSteerPort;
                    
                interface wheelsToSpeedo: WheelToSpeedometerInterface
                    connect frontWheels.wheelSpeedPort to speedometer.wheelSpeedPort;
                    connect rearWheels.wheelSpeedPort to speedometer.wheelSpeedPort;
                interface speedoToECU: SpeedometerToECUInterface
                    connect speedometer.speedFeedbackPort to powertrain.ecu.speedFeedbackPort;
                interface engineToECU: EngineToECUInterface
                    connect powertrain.engine.rpmFeedbackPort to powertrain.ecu.rpmFeedbackPort;
            }
            
            part def Driver {
                port throttleCmdPort: ThrottleCmdPort;
                port brakeCmdPort: BrakeCmdPort;
                port steeringCmdPort: SteeringCmdPort;
            }
            
            part def AcceleratorPedal {
                port throttleCmdPort: ThrottleCmdPort;
            }
            
            part def BrakePedal {
                port brakeCmdPort: BrakeCmdPort;
            }
            
            part def SteeringWheel {
                port steeringCmdPort: SteeringCmdPort;
            }
            
            part def Powertrain {
                part engine: Engine;
                part transmission: Transmission;
                part fuelTank: FuelTank;
                part ecu: ECU;
            }
            
            part def Engine {
                exhibit state engineStates: EngineStates;
                port drivePwrPort: DrivePwrPort;
                port fuelFlowPort: FuelFlowPort;
                port rpmFeedbackPort: RPMFeedbackPort;
                perform action generatePower;
            }
            
            part def Transmission {
                attribute gearRatio: Real;
                port drivePwrPort: DrivePwrPort;
                port wheelDrivePort: DrivePwrPort;
                perform action amplifyTorque;
            }
            
            part def FuelTank {
                exhibit state fuelTankStates: FuelTankStates;
                attribute fuelCapacity :> ISQ::volume;
                attribute currentFuelLevel :> ISQ::volume;
                port fuelFlowPort: FuelFlowPort;
            }
            
            part def ECU {
                port throttleCmdPort: ThrottleCmdPort;
                port speedFeedbackPort: SpeedFeedbackPort;
                port rpmFeedbackPort: RPMFeedbackPort;
                port fuelFlowPort: FuelFlowPort;
                perform action calculateFuelFlow;
            }
            
            part def BrakeSystem {
                attribute totalBrakingForce :> ISQ::force;
                port brakeCmdPort: BrakeCmdPort;
                port wheelBrakePort: BrakeCmdPort;
                perform action applyBraking;
            }
            
            part def SteeringSystem {
                port steeringCmdPort: SteeringCmdPort;
                port wheelSteerPort: SteeringCmdPort;
                perform action adjustSteering;
            }
            
            part def Speedometer {
                port wheelSpeedPort: WheelSpeedPort;
                port speedFeedbackPort: SpeedFeedbackPort;
            }
            
            part def Wheel {
                port wheelSpeedPort: WheelSpeedPort;
                port wheelBrakePort: BrakeCmdPort;
                port wheelSteerPort: SteeringCmdPort;
                port wheelDrivePort: DrivePwrPort;
            }
        }
        
        package InterfaceDefinitions {
            interface def DriverToAcceleratorInterface {
                end driverThrottle: ThrottleCmdPort;
                end pedalThrottle: ThrottleCmdPort;
            }
            interface def DriverToBrakeInterface {
                end driverBrake: BrakeCmdPort;
                end pedalBrake: BrakeCmdPort;
            }
            interface def DriverToSteeringInterface {
                end driverSteer: SteeringCmdPort;
                end wheelSteer: SteeringCmdPort;
            }
            interface def ThrottleInterface {
                end pedalThrottle: ThrottleCmdPort;
                end ecuThrottle: ThrottleCmdPort;
            }
            interface def BrakeInterface {
                end pedalBrake: BrakeCmdPort;
                end sysBrake: BrakeCmdPort;
            }
            interface def SteeringInterface {
                end wheelSteer: SteeringCmdPort;
                end sysSteer: SteeringCmdPort;
            }
            interface def ECUToEngineInterface {
                end ecuFuel: FuelFlowPort;
                end engineFuel: FuelFlowPort;
            }
            interface def EngineToTransmissionInterface {
                end engineDrive: DrivePwrPort;
                end transDrive: DrivePwrPort;
            }
            interface def TransmissionToWheelInterface {
                end transWheel: DrivePwrPort;
                end wheelDrive: DrivePwrPort;
            }
            interface def BrakeToWheelInterface {
                end brakeOut: BrakeCmdPort;
                end wheelBrake: BrakeCmdPort;
            }
            interface def SteeringToWheelInterface {
                end steerOut: SteeringCmdPort;
                end wheelSteer: SteeringCmdPort;
            }
            interface def WheelToSpeedometerInterface {
                end wheelSpeed: WheelSpeedPort;
                end speedometerIn: WheelSpeedPort;
            }
            interface def SpeedometerToECUInterface {
                end speedometerOut: SpeedFeedbackPort;
                end ecuSpeed: SpeedFeedbackPort;
            }
            interface def EngineToECUInterface {
                end engineRPM: RPMFeedbackPort;
                end ecuRPM: RPMFeedbackPort;
            }
        }
        
        package RequirementDefinitions {
            requirement def MassLimitRequirement {
                doc /* The total mass of the vehicle shall be less than 2000 kg. */
                subject vehicle : Vehicle;
                attribute massLimit :> ISQ::mass = 2000 [kg];
                require constraint { vehicle.mass <= massLimit }
            }
            
            requirement def MaxSpeedRequirement {
                doc /* The maximum speed of the vehicle shall be at least 180 km/h. */
                subject vehicle : Vehicle;
                attribute minMaxSpeed :> ISQ::speed = 180 [km/h];
                require constraint { vehicle.maxSpeed >= minMaxSpeed }
            }
            
            requirement def BrakingForceRequirement {
                doc /* The braking system shall apply a minimum braking force. */
                subject brakeSystem : BrakeSystem;
                attribute minBrakingForce :> ISQ::force = 10000 [N];
                require constraint { brakeSystem.totalBrakingForce >= minBrakingForce }
            }
            
            requirement def FuelCapacityRequirement {
                doc /* The fuel tank capacity shall be sufficient for long-distance travel. */
                subject fuelTank : FuelTank;
                attribute minFuelCapacity :> ISQ::volume = 50 [L];
                require constraint { fuelTank.fuelCapacity >= minFuelCapacity }
            }
        }
    }
}
