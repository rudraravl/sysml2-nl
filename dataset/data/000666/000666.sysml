package LiftwareStabilizationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TremorFrequency :> ISQ::FrequencyValue {
        doc /* Frequency of pathological hand tremor, typically 4-12 Hz */
    }
    
    attribute def TremorAmplitude :> ISQ::LengthValue {
        doc /* Peak-to-peak displacement amplitude of tremor motion */
    }
    
    attribute def StabilizationAngle :> ISQ::PlaneAngleValue {
        doc /* Angular correction applied by stabilization mechanism */
    }
    
    attribute def BatteryCharge :> Real {
        doc /* Battery state of charge as percentage 0-100 */
    }
    
    attribute def MotorTorque :> ISQ::TorqueValue {
        doc /* Torque command for stabilization motors */
    }
    
    attribute def AngularRate :> ISQ::AngularVelocityValue {
        doc /* Angular velocity measurement from gyroscope */
    }
    
    item def UtensilHead {
        attribute mass : ISQ::MassValue;
        attribute material : String;
    }
    
    item def BatteryPack {
        attribute chargeLevel : BatteryCharge;
        attribute capacity : ISQ::EnergyValue;
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    port def TremorDataPort {
        out frequency : TremorFrequency;
        out amplitude : TremorAmplitude;
        out angularRate : AngularRate;
    }
    
    port def ControlSignalPort {
        in frequency : TremorFrequency;
        in amplitude : TremorAmplitude;
        in angularRate : AngularRate;
        out correctionAngle : StabilizationAngle;
        out motorTorque : MotorTorque;
    }
    
    port def ActuatorPort {
        in correctionAngle : StabilizationAngle;
        in motorTorque : MotorTorque;
    }
    
    port def PowerPort {
        out voltage : ISQ::ElectricPotentialValue;
        out current : ISQ::ElectricCurrentValue;
    }
    
    signal def PowerOnEvent;
    signal def TremorDetectedEvent;
    signal def NoMotionEvent;
    signal def LowBatteryEvent;
    signal def ChargerConnectedEvent;
    signal def CriticalBatteryEvent;
    signal def FullyChargedEvent;
    
    part def InertialSensor {
        doc /* High-precision IMU detecting hand tremor motion */
        out port tremorData : TremorDataPort;
        attribute sampleRate : ISQ::FrequencyValue;
        attribute sensitivity : ISQ::AccelerationValue;
    }
    
    part def StabilizationProcessor {
        doc /* Real-time processor computing counteracting motion */
        in port sensorInput : TremorDataPort;
        out port controlOutput : ControlSignalPort;
        attribute processingDelay : ISQ::TimeValue;
        attribute filterCutoff : ISQ::FrequencyValue;
    }
    
    part def GimbalActuator {
        doc /* Two-axis motorized gimbal providing stabilization */
        in port commandInput : ActuatorPort;
        attribute maxTorque : ISQ::TorqueValue;
        attribute responseTime : ISQ::TimeValue;
    }
    
    part def PowerSystem {
        doc /* Rechargeable battery and power management */
        ref item battery : BatteryPack;
        out port powerSupply : PowerPort;
        attribute chargingTime : ISQ::TimeValue;
    }
    
    part def HandleAssembly {
        doc /* Ergonomic handle housing electronics */
        attribute gripDiameter : ISQ::LengthValue;
        attribute totalMass : ISQ::MassValue;
    }
    
    part def UtensilMount {
        doc /* Attachment mechanism for interchangeable utensils */
        ref item attachedUtensil : UtensilHead;
        attribute mountingTorque : ISQ::TorqueValue;
    }
    
    action def SenseTremorMotion {
        doc /* Continuously measure hand tremor characteristics */
        out tremorFreq : TremorFrequency;
        out tremorAmp : TremorAmplitude;
        out angRate : AngularRate;
    }
    
    action def ComputeCorrection {
        doc /* Calculate inverse motion to cancel tremor */
        in tremorFreq : TremorFrequency;
        in tremorAmp : TremorAmplitude;
        in angRate : AngularRate;
        out corrAngle : StabilizationAngle;
        out motorCmd : MotorTorque;
    }
    
    action def ApplyStabilization {
        doc /* Execute countermovement via gimbal motors */
        in corrAngle : StabilizationAngle;
        in motorCmd : MotorTorque;
    }
    
    action def MonitorBattery {
        doc /* Track battery state and manage power */
        out chargeLevel : BatteryCharge;
    }
    
    action def StabilizeEatingUtensil {
        doc /* Primary stabilization control loop */
        first start;
        then merge stabilizationCycle;
        then action sense : SenseTremorMotion {
            out tremorFreq : TremorFrequency;
            out tremorAmp : TremorAmplitude;
            out angRate : AngularRate;
        }
        then action compute : ComputeCorrection {
            in tremorFreq = sense.tremorFreq;
            in tremorAmp = sense.tremorAmp;
            in angRate = sense.angRate;
            out corrAngle : StabilizationAngle;
            out motorCmd : MotorTorque;
        }
        then action apply : ApplyStabilization {
            in corrAngle = compute.corrAngle;
            in motorCmd = compute.motorCmd;
        }
        then action checkBattery : MonitorBattery {
            out chargeLevel : BatteryCharge;
        }
        then decide;
            if checkBattery.chargeLevel > 15.0 then stabilizationCycle;
            if checkBattery.chargeLevel <= 15.0 then lowPowerMode;
        action lowPowerMode;
        then done;
    }
    
    state def OperationalStates {
        doc /* System operational state machine */
        entry; then off;
        
        state off {
            doc /* System powered down */
        }
        
        transition off_to_standby
            first off
            accept PowerOnEvent
            then standby;
        
        state standby {
            doc /* Powered but not actively stabilizing */
        }
        
        transition standby_to_active
            first standby
            accept TremorDetectedEvent
            then activeStabilization;
        
        state activeStabilization {
            doc /* Actively counteracting hand tremor */
            entry action stabilize : StabilizeEatingUtensil;
        }
        
        transition active_to_standby
            first activeStabilization
            accept NoMotionEvent
            then standby;
        
        transition active_to_lowBattery
            first activeStabilization
            accept LowBatteryEvent
            then lowBattery;
        
        state lowBattery {
            doc /* Reduced performance to conserve power */
        }
        
        transition lowBattery_to_charging
            first lowBattery
            accept ChargerConnectedEvent
            then charging;
        
        transition lowBattery_to_off
            first lowBattery
            accept CriticalBatteryEvent
            then off;
        
        state charging {
            doc /* Battery recharging via USB */
        }
        
        transition charging_to_standby
            first charging
            accept FullyChargedEvent
            then standby;
    }
    
    requirement def PerformanceRequirement {
        doc /* Stabilization performance specifications */
        subject device : LiftwareDevice;
        
        require constraint tremorReduction {
            doc /* System shall reduce tremor-induced motion by minimum 70% */
        }
        
        require constraint frequencyRange {
            doc /* System shall stabilize tremors from 4 Hz to 12 Hz */
        }
        
        require constraint latency {
            doc /* System response time shall be less than 50 milliseconds */
        }
    }
    
    requirement def UsabilityRequirement {
        doc /* User experience and ergonomic requirements */
        subject device : LiftwareDevice;
        
        require constraint weight {
            doc /* Total device weight shall not exceed 200 grams */
        }
        
        require constraint batteryLife {
            doc /* Device shall operate continuously for minimum 60 minutes */
        }
        
        require constraint cleanability {
            doc /* Utensil attachment shall be dishwasher safe */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Safety and regulatory compliance */
        subject device : LiftwareDevice;
        
        require constraint foodContact {
            doc /* All food-contact materials shall be FDA approved */
        }
        
        require constraint motorSafety {
            doc /* Motors shall limit torque to prevent user injury */
        }
        
        require constraint electricalSafety {
            doc /* Device shall meet IEC 60601-1 medical device standards */
        }
    }
    
    part def LiftwareDevice {
        doc /* Handheld stabilizing utensil system for tremor management */
        
        part sensor : InertialSensor {
            attribute :>> sampleRate = 200.0 [Hz];
            attribute :>> sensitivity = 0.001 [m/(s^2)];
            perform action sense : SenseTremorMotion;
        }
        
        part processor : StabilizationProcessor {
            attribute :>> processingDelay = 10.0 [s];
            attribute :>> filterCutoff = 15.0 [Hz];
            perform action compute : ComputeCorrection;
        }
        
        part gimbal : GimbalActuator {
            attribute :>> maxTorque = 0.5 [N*m];
            attribute :>> responseTime = 20.0 [s];
            perform action apply : ApplyStabilization;
        }
        
        part power : PowerSystem {
            attribute :>> chargingTime = 180.0 [min];
            part batteryCell : BatteryPack {
                attribute :>> chargeLevel = 100.0;
                attribute :>> capacity = 15.0 [J];
                attribute :>> voltage = 7.4 [V];
            }
            perform action monitor : MonitorBattery;
        }
        
        part handle : HandleAssembly {
            attribute :>> gripDiameter = 35.0 [mm];
            attribute :>> totalMass = 120.0 [kg];
        }
        
        part mount : UtensilMount {
            attribute :>> mountingTorque = 2.0 [N*m];
            ref item spoon : UtensilHead {
                attribute :>> mass = 25.0 [kg];
                attribute :>> material = "Stainless Steel 18/10";
            }
        }
        
        connect sensor.tremorData to processor.sensorInput;
        connect processor.controlOutput to gimbal.commandInput;
        
        exhibit state operationStateMachine : OperationalStates;
        
        satisfy requirement performanceReq : PerformanceRequirement;
        satisfy requirement usabilityReq : UsabilityRequirement;
        satisfy requirement safetyReq : SafetyRequirement;
    }
    
    part liftwareSystem : LiftwareDevice {
        doc /* Liftware stabilizing utensil system instance - Primary function: 
               Continuously detect and counteract pathological hand tremor in real-time, 
               enabling individuals with essential tremor or Parkinson's disease to eat 
               independently by maintaining stable utensil orientation and reducing 
               spillage through active electronic stabilization */
    }
    
    action provideTremorStabilization : StabilizeEatingUtensil {
        doc /* High-level system function: Sense hand tremor motion via inertial sensors, 
               compute inverse motion trajectory using real-time signal processing, 
               and apply precise counteracting movement through motorized gimbal actuators 
               to maintain stable utensil position during eating activities */
    }
}
