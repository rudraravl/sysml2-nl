package MechanicalEnergySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        alias Energy for ISQ::EnergyValue;
        alias Power for ISQ::PowerValue;
        alias Torque for ISQ::TorqueValue;
        alias AngularVelocity for ISQ::AngularVelocityValue;
        alias Mass for ISQ::MassValue;
        alias Length for ISQ::LengthValue;
        alias Force for ISQ::ForceValue;
        alias Pressure for ISQ::PressureValue;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def LoadDemand {
            requiredPower : Power;
        }
        
        port def MechanicalPowerPort {
            out torque : Torque;
            out angularVelocity : AngularVelocity;
        }
        
        port def HydraulicPort {
            out pressure : Pressure;
            out flowRate : Real;
        }
        
        port def ControlPort {
            in command : StartCommand;
            out operatingStatus : Real;
        }
        
        part def PrimeMovingEngine {
            port mechanicalOutput : MechanicalPowerPort;
            port controlInterface : ControlPort;
            attribute fuelConsumption : Real;
            attribute maxPower : Power;
            attribute currentTorque : Torque;
            attribute currentSpeed : AngularVelocity;
        }
        
        part def MechanicalTransmission {
            port inputShaft : ~MechanicalPowerPort;
            port outputShaft : MechanicalPowerPort;
            attribute transmissionRatio : Real;
            attribute mechanicalEfficiency : Real;
        }
        
        part def RotationalInertiaStorage {
            port rotationalInput : ~MechanicalPowerPort;
            attribute momentOfInertia : Real;
            attribute storedKineticEnergy : Energy;
            attribute rotationalSpeed : AngularVelocity;
            attribute maxSafeSpeed : AngularVelocity;
        }
        
        part def HydraulicPump {
            port mechanicalInput : ~MechanicalPowerPort;
            port hydraulicOutput : HydraulicPort;
            attribute displacement : Real;
            attribute volumetricEfficiency : Real;
            attribute outputPressure : Pressure;
        }
        
        part def HydraulicActuator {
            port hydraulicInput : ~HydraulicPort;
            attribute pistonArea : Real;
            attribute strokeLength : Length;
            attribute outputForce : Force;
            attribute position : Length;
        }
        
        action def InitiateOperation {
            in startCmd : StartCommand;
            out engineSpeed : AngularVelocity;
        }
        
        action def GenerateMechanicalPower {
            in targetSpeed : AngularVelocity;
            out engineTorque : Torque;
            out engineSpeed : AngularVelocity;
        }
        
        action def TransmitRotationalPower {
            in inputTorque : Torque;
            in inputSpeed : AngularVelocity;
            out outputTorque : Torque;
            out outputSpeed : AngularVelocity;
        }
        
        action def AccumulateKineticEnergy {
            in driveTorque : Torque;
            in driveSpeed : AngularVelocity;
            out accumulatedEnergy : Energy;
            out inertiaSpeed : AngularVelocity;
        }
        
        action def ConvertToHydraulicPower {
            in mechanicalTorque : Torque;
            in mechanicalSpeed : AngularVelocity;
            out hydraulicPressure : Pressure;
            out flowRate : Real;
        }
        
        action def PerformMechanicalWork {
            in hydraulicPressure : Pressure;
            in flowRate : Real;
            out actuatorForce : Force;
            out actuatorPosition : Length;
        }
        
        action def DeliverMechanicalWork {
            in operationCmd : StartCommand;
            out workOutput : Force;
            out displacement : Length;
        }
        
        state def SystemOperationalStates {
            entry; then standby;
            
            state standby;
            accept startCmd : StartCommand
                then startup;
            
            state startup;
            then running;
            
            state running;
            accept stopCmd : StopCommand
                then shutdown;
            
            state shutdown;
            then standby;
        }
    }
    
    package Requirements {
        requirement def MechanicalEnergySystemRequirement;
        
        requirement <'REQ-2000'> primaryFunction : MechanicalEnergySystemRequirement {
            doc /* The mechanical energy system shall convert chemical energy 
                 * from fuel into rotational mechanical energy, transmit and 
                 * store this energy temporarily in a rotating mass, then 
                 * convert it to hydraulic power to perform useful mechanical 
                 * work through linear actuation.
                 */
        }
        
        requirement <'REQ-2001'> energyStorageCapacity {
            doc /* The rotational inertia storage shall accumulate sufficient 
                 * kinetic energy to buffer power fluctuations and maintain 
                 * continuous operation during transient load variations.
                 */
        }
        
        requirement <'REQ-2002'> transmissionEfficiency {
            doc /* The mechanical transmission shall transfer rotational power 
                 * with mechanical efficiency not less than 92 percent to 
                 * minimize energy losses.
                 */
        }
        
        requirement <'REQ-2003'> hydraulicConversionCapacity {
            doc /* The hydraulic pump shall convert mechanical rotational power 
                 * to hydraulic power with output pressure sufficient to drive 
                 * the actuator under maximum load conditions.
                 */
        }
        
        requirement <'REQ-2004'> safeOperatingSpeed {
            doc /* The rotational inertia storage shall not exceed its maximum 
                 * safe rotational speed to prevent structural failure.
                 */
        }
    }
    
    package SystemArchitecture {
        import Definitions::*;
        
        part mechanicalPowerSystem {
            doc /* A mechanical energy system that converts fuel energy into 
                 * rotational mechanical power, stores it temporarily in a 
                 * flywheel, converts it to hydraulic power, and delivers 
                 * linear mechanical work through a hydraulic actuator.
                 */
            
            attribute systemEfficiency : Real = 0.78;
            attribute nominalOperatingSpeed : AngularVelocity = 1800.0;
            attribute maxCapacity : Power = 150000.0;
            
            part primeEngine : PrimeMovingEngine {
                attribute fuelConsumption = 25.0;
                attribute maxPower = 200000.0;
                attribute currentTorque = 800.0;
                attribute currentSpeed = 1800.0;
            }
            
            part powerTransmission : MechanicalTransmission {
                attribute transmissionRatio = 1.5;
                attribute mechanicalEfficiency = 0.94;
            }
            
            part energyBuffer : RotationalInertiaStorage {
                attribute momentOfInertia = 50.0;
                attribute storedKineticEnergy = 18000.0;
                attribute rotationalSpeed = 2700.0;
                attribute maxSafeSpeed = 3600.0;
            }
            
            part hydraulicConverter : HydraulicPump {
                attribute displacement = 0.0001;
                attribute volumetricEfficiency = 0.95;
                attribute outputPressure = 25000000.0;
            }
            
            part workOutput : HydraulicActuator {
                attribute pistonArea = 0.01;
                attribute strokeLength = 0.5;
                attribute outputForce = 250000.0;
                attribute position = 0.0;
            }
            
            connect primeEngine.mechanicalOutput to powerTransmission.inputShaft;
            connect powerTransmission.outputShaft to energyBuffer.rotationalInput;
            connect energyBuffer.rotationalInput to hydraulicConverter.mechanicalInput;
            connect hydraulicConverter.hydraulicOutput to workOutput.hydraulicInput;
            
            perform action deliverWork : DeliverMechanicalWork {
                in operationCmd : StartCommand;
                out workOutput : Force;
                out displacement : Length;
                
                first start;
                then action initiate : InitiateOperation {
                    in startCmd = deliverWork::operationCmd;
                    out engineSpeed : AngularVelocity;
                }
                then action generatePower : GenerateMechanicalPower {
                    in targetSpeed = initiate.engineSpeed;
                    out engineTorque : Torque;
                    out engineSpeed : AngularVelocity;
                }
                flow generatePower.engineTorque to transmitPower.inputTorque;
                flow generatePower.engineSpeed to transmitPower.inputSpeed;
                then action transmitPower : TransmitRotationalPower {
                    in inputTorque : Torque;
                    in inputSpeed : AngularVelocity;
                    out outputTorque : Torque;
                    out outputSpeed : AngularVelocity;
                }
                flow transmitPower.outputTorque to storeEnergy.driveTorque;
                flow transmitPower.outputSpeed to storeEnergy.driveSpeed;
                then action storeEnergy : AccumulateKineticEnergy {
                    in driveTorque : Torque;
                    in driveSpeed : AngularVelocity;
                    out accumulatedEnergy : Energy;
                    out inertiaSpeed : AngularVelocity;
                }
                flow storeEnergy.inertiaSpeed to convertPower.mechanicalSpeed;
                then action convertPower : ConvertToHydraulicPower {
                    in mechanicalTorque : Torque;
                    in mechanicalSpeed : AngularVelocity;
                    out hydraulicPressure : Pressure;
                    out flowRate : Real;
                }
                flow convertPower.hydraulicPressure to performWork.hydraulicPressure;
                flow convertPower.flowRate to performWork.flowRate;
                then action performWork : PerformMechanicalWork {
                    in hydraulicPressure : Pressure;
                    in flowRate : Real;
                    out actuatorForce : Force;
                    out actuatorPosition : Length;
                }
                flow performWork.actuatorForce to deliverWork::workOutput;
                flow performWork.actuatorPosition to deliverWork::displacement;
                then done;
            }
            
            exhibit state systemStateMachine : SystemOperationalStates;
        }
        
        satisfy Requirements::primaryFunction by mechanicalPowerSystem;
        satisfy Requirements::energyStorageCapacity by mechanicalPowerSystem.energyBuffer;
        satisfy Requirements::transmissionEfficiency by mechanicalPowerSystem.powerTransmission;
        satisfy Requirements::hydraulicConversionCapacity by mechanicalPowerSystem.hydraulicConverter;
        satisfy Requirements::safeOperatingSpeed by mechanicalPowerSystem.energyBuffer;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MechanicalEnergySystem::*;

    part testSubject = mechanicalPowerSystem {
        exhibit state sm : SystemOperationalStates;
    }

    action orchestrator {
        attribute testStartCmd : StartCommand;
        action actionProbe : InitiateOperation {
            in startCmd = testStartCmd;
        }
        first actionProbe;
    }
}
