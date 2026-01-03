package CentrifugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def GForce :> ScalarValues::Real;
    
    attribute def SampleVolume :> ISQ::VolumeValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeUnit;
    }
    
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue {
        attribute :>> num : Real;
        attribute :>> mRef : ThermodynamicTemperatureUnit;
    }
    
    enum def OperationalState {
        idle;
        loading;
        accelerating;
        separating;
        decelerating;
        unloading;
        fault;
    }
    
    item def Sample {
        attribute volume : SampleVolume;
        attribute density : ISQ::DensityValue;
        attribute components : Integer;
    }
    
    item def SeparatedMaterial {
        attribute pelletMass : ISQ::MassValue;
        attribute supernatantVolume : SampleVolume;
    }
    
    port def PowerPort {
        in attribute powerSupply : ISQ::PowerValue;
    }
    
    port def SamplePort {
        in item inputSample : Sample;
        out item outputMaterial : SeparatedMaterial;
    }
    
    port def ControlPort {
        in attribute speedSetpoint : RotationalSpeed;
        in attribute durationSetpoint : ISQ::TimeValue;
        in attribute temperatureSetpoint : Temperature;
        out attribute currentSpeed : RotationalSpeed;
        out attribute currentState : OperationalState;
    }
    
    part def Motor {
        attribute maxSpeed : RotationalSpeed;
        attribute currentSpeed : RotationalSpeed;
        attribute torque : ISQ::TorqueValue;
        
        port powerInput : PowerPort;
        
        action def Accelerate {
            in targetSpeed : RotationalSpeed;
            in currentSpeed : RotationalSpeed;
            out achievedSpeed : RotationalSpeed;
        }
        
        action def MaintainSpeed {
            in setpoint : RotationalSpeed;
            out actualSpeed : RotationalSpeed;
        }
        
        action def Decelerate {
            in initialSpeed : RotationalSpeed;
            out finalSpeed : RotationalSpeed;
        }
    }
    
    part def Rotor {
        attribute radius : ISQ::LengthValue;
        attribute maxCapacity : SampleVolume;
        attribute numberOfBuckets : Integer;
        attribute currentLoad : ISQ::MassValue;
        
        action def CalculateCentrifugalForce {
            in rotationalSpeed : RotationalSpeed;
            in sampleMass : ISQ::MassValue;
            in rotorRadius : ISQ::LengthValue;
            out centrifugalForce : ISQ::ForceValue;
            out gForce : GForce;
        }
        
        action def DistributeLoad {
            in samples : Sample[*];
            out balanced : Boolean;
        }
    }
    
    part def TemperatureControl {
        attribute setpoint : Temperature;
        attribute currentTemperature : Temperature;
        attribute coolingCapacity : ISQ::PowerValue;
        
        action def RegulateTemperature {
            in targetTemp : Temperature;
            in measuredTemp : Temperature;
            out coolingOutput : ISQ::PowerValue;
        }
    }
    
    part def SafetySystem {
        attribute lidLocked : Boolean;
        attribute loadBalanced : Boolean;
        attribute vibrationLevel : ISQ::AccelerationValue;
        attribute emergencyStop : Boolean;
        
        action def CheckSafety {
            in lidStatus : Boolean;
            in balanceStatus : Boolean;
            in vibration : ISQ::AccelerationValue;
            out safeToOperate : Boolean;
        }
        
        action def LockLid {
            in motorRunning : Boolean;
            out lidLocked : Boolean;
        }
    }
    
    part def ControlUnit {
        attribute operationMode : OperationalState;
        
        action def MonitorOperation {
            in currentSpeed : RotationalSpeed;
            in temperature : Temperature;
            in safetyStatus : Boolean;
            out systemState : OperationalState;
        }
        
        action def ExecuteProgram {
            in targetSpeed : RotationalSpeed;
            in duration : ISQ::TimeValue;
            in targetTemp : Temperature;
            out completed : Boolean;
        }
    }
    
    part def Centrifuge {
        doc /* A laboratory centrifuge system that separates sample components 
               by applying centrifugal force through controlled high-speed rotation.
               Primary function: Enable separation of heterogeneous mixtures into 
               distinct layers or fractions based on density differences, supporting 
               applications in clinical diagnostics, research, and industrial processing. */
        
        attribute operatingSpeed : RotationalSpeed;
        attribute operatingDuration : ISQ::TimeValue;
        attribute operatingTemperature : Temperature;
        
        part motor : Motor {
            attribute :>> maxSpeed : RotationalSpeed {
                :>> num = 20000.0;
                :>> mRef = SI::Hz;
            }
        }
        
        part rotor : Rotor {
            attribute :>> radius : ISQ::LengthValue {
                :>> num = 0.12;
                :>> mRef = SI::m;
            }
            attribute :>> maxCapacity : SampleVolume {
                :>> num = 0.0004;
                :>> mRef = SI::m3;
            }
            attribute :>> numberOfBuckets = 6;
        }
        
        part temperatureControl : TemperatureControl {
            attribute :>> coolingCapacity : ISQ::PowerValue {
                :>> num = 500.0;
                :>> mRef = SI::W;
            }
        }
        
        part safetySystem : SafetySystem;
        
        part controller : ControlUnit;
        
        port powerInterface : PowerPort;
        port sampleInterface : SamplePort;
        port controlInterface : ControlPort;
        
        connect motor.powerInput to powerInterface;
        
        perform action separateSample : SeparateSample;
    }
    
    action def LoadSamples {
        in samples : Sample[*];
        out loadedSamples : Sample[*];
        out loadSuccess : Boolean;
    }
    
    action def ApplyCentrifugalForce {
        in sample : Sample;
        in speed : RotationalSpeed;
        in duration : ISQ::TimeValue;
        in temperature : Temperature;
        out separatedMaterial : SeparatedMaterial;
        out separationComplete : Boolean;
    }
    
    action def UnloadSamples {
        in separatedMaterials : SeparatedMaterial[*];
        out retrievedMaterials : SeparatedMaterial[*];
    }
    
    action def SeparateSample {
        in inputSamples : Sample[*];
        in targetSpeed : RotationalSpeed;
        in runDuration : ISQ::TimeValue;
        in targetTemperature : Temperature;
        out outputMaterials : SeparatedMaterial[*];
        
        first start;
        
        then action loadAction : LoadSamples {
            in samples = inputSamples;
            out loadedSamples;
            out loadSuccess;
        }
        
        then decide;
            if loadAction.loadSuccess then checkSafety;
            if not loadAction.loadSuccess then abortOperation;
        
        action checkSafety : SafetySystem::CheckSafety {
            in lidStatus = true;
            in balanceStatus;
            in vibration;
            out safeToOperate;
        }
        
        then decide;
            if checkSafety.safeToOperate then accelerateMotor;
            if not checkSafety.safeToOperate then abortOperation;
        
        action accelerateMotor : Motor::Accelerate {
            in targetSpeed = targetSpeed;
            in currentSpeed {
                :>> num = 0.0;
                :>> mRef = SI::Hz;
            }
            out achievedSpeed;
        }
        
        then action regulateTemp : TemperatureControl::RegulateTemperature {
            in targetTemp = targetTemperature;
            in measuredTemp;
            out coolingOutput;
        }
        
        then action calculateForce : Rotor::CalculateCentrifugalForce {
            in rotationalSpeed = accelerateMotor.achievedSpeed;
            in sampleMass;
            in rotorRadius;
            out centrifugalForce;
            out gForce;
        }
        
        then action applySeparation : ApplyCentrifugalForce {
            in sample;
            in speed = accelerateMotor.achievedSpeed;
            in duration = runDuration;
            in temperature = targetTemperature;
            out separatedMaterial;
            out separationComplete;
        }
        
        then action decelerateMotor : Motor::Decelerate {
            in initialSpeed = accelerateMotor.achievedSpeed;
            out finalSpeed;
        }
        
        then action unloadAction : UnloadSamples {
            in separatedMaterials;
            out retrievedMaterials;
        }
        
        then assign outputMaterials := unloadAction.retrievedMaterials;
        
        then done;
        
        action abortOperation {
            doc /* Safety condition not met or load failure. */
        }
        then done;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'REQ-001'> separationCapability : FunctionalRequirement {
        doc /* The centrifuge shall separate heterogeneous sample mixtures into 
               distinct fractions based on density differences by applying 
               controlled centrifugal force. */
    }
    
    requirement <'REQ-002'> lidInterlock : SafetyRequirement {
        doc /* The centrifuge shall not operate unless the lid is securely 
               closed and locked. The lid shall remain locked during rotor motion. */
    }
    
    requirement <'REQ-003'> loadBalance : SafetyRequirement {
        doc /* The centrifuge shall detect unbalanced loads and prevent operation 
               if balance exceeds acceptable limits. */
    }
    
    requirement <'REQ-004'> speedCapability : PerformanceRequirement {
        doc /* The centrifuge shall achieve and maintain rotational speeds 
               up to 20,000 rpm with accuracy within ±50 rpm. */
    }
    
    requirement <'REQ-005'> temperatureControl : PerformanceRequirement {
        doc /* The centrifuge shall maintain sample temperature within 
               ±2°C of setpoint during operation. */
    }
    
    requirement centrifugeSystemRequirements {
        doc /* Top-level requirements for the centrifuge system. */
        
        require separationCapability;
        require lidInterlock;
        require loadBalance;
        require speedCapability;
        require temperatureControl;
    }
    
    part centrifugeSystem : Centrifuge {
        satisfy centrifugeSystemRequirements;
    }
}
