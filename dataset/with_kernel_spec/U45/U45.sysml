package LaboratoryCentrifugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def LiquidSample;
        item def SampleTube {
            attribute sample : LiquidSample;
        }
        
        attribute def RotationalSpeedValue :> Real;
        attribute def DurationValue :> Real;
        attribute def VibrationValue :> Real;
        attribute def TemperatureValue :> Real;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def EmergencyStop;
        attribute def RunComplete;
        attribute def StartSeparation;
        attribute def TargetSpeedReached;
        attribute def DurationElapsed;
        attribute def RotorStopped;
        
        port def PowerPort {
            attribute voltage : Real;
            attribute current : Real;
        }
        port def ControlSignalPort {
            attribute speedCommand : RotationalSpeedValue;
            attribute durationCommand : DurationValue;
            attribute tempSetpoint : TemperatureValue;
        }
        port def SafetySignalPort {
            attribute lidLocked : Boolean;
            attribute imbalanceDetected : Boolean;
            attribute vibrationLevel : VibrationValue;
            attribute emergencyStop : Boolean;
        }
        port def UserInterfacePort {
            attribute setSpeed : RotationalSpeedValue;
            attribute setDuration : DurationValue;
            attribute setTemp : TemperatureValue;
            attribute startCommand : Boolean;
            attribute stopCommand : Boolean;
            attribute statusDisplay : String;
        }
        port def MechanicalPort {
            attribute speed : RotationalSpeedValue;
        }
        
        action def AccelerateRotor {
            in targetSpeed : RotationalSpeedValue;
        }
        action def DecelerateRotor;
        action def SeparateSamples {
            in speed : RotationalSpeedValue;
            in duration : DurationValue;
        }
        action def CoolChamber {
            in setpoint : TemperatureValue;
        }
        action def LockLid;
        action def UnlockLid;
        
        state def CentrifugeStates;
        
        part def Motor {
            port powerIn : PowerPort;
            port controlIn : ControlSignalPort;
            port mechanicalOut : MechanicalPort;
            attribute currentSpeed : RotationalSpeedValue;
            perform action accelerate : AccelerateRotor;
            perform action decelerate : DecelerateRotor;
        }
        
        part def Rotor {
            attribute bucketCount : Integer;
            item buckets : SampleTube[6];
            port mechanicalIn : MechanicalPort;
            attribute isBalanced : Boolean;
        }
        
        part def ControlUnit {
            port uiPort : UserInterfacePort;
            port motorControlOut : ControlSignalPort;
            port tempControlOut : ControlSignalPort;
            port safetyIn : SafetySignalPort;
            exhibit state operationalStates : CentrifugeStates;
        }
        
        part def TemperatureControl {
            port controlIn : ControlSignalPort;
            port powerIn : PowerPort;
            attribute currentTemp : TemperatureValue;
            perform action cool : CoolChamber;
        }
        
        part def SafetySystem {
            port safetyOut : SafetySignalPort;
            port motorPowerOut : PowerPort;
            attribute lidLocked : Boolean;
            attribute vibrationSensor : VibrationValue;
            perform action lockLid : LockLid;
            perform action unlockLid : UnlockLid;
        }
        
        part def Centrifuge {
            port powerInterface : PowerPort;
            port userInterface : UserInterfacePort;
            
            part controlUnit : ControlUnit;
            part motor : Motor;
            part rotor : Rotor;
            part tempControl : TemperatureControl;
            part safetySystem : SafetySystem;
            
            connection powerToSafety connect powerInterface to safetySystem.motorPowerOut;
            connection safetyToMotor connect safetySystem.motorPowerOut to motor.powerIn;
            connection powerToTemp connect powerInterface to tempControl.powerIn;
            
            connection uiToControl connect userInterface to controlUnit.uiPort;
            connection controlToMotor connect controlUnit.motorControlOut to motor.controlIn;
            connection controlToTemp connect controlUnit.tempControlOut to tempControl.controlIn;
            connection safetyToControl connect safetySystem.safetyOut to controlUnit.safetyIn;
            
            connection motorToRotor connect motor.mechanicalOut to rotor.mechanicalIn;
        }
        
        requirement def SeparationReq {
            doc /* The centrifuge shall separate samples based on size, shape, and density using centrifugal force. */
            attribute targetSpeed : RotationalSpeedValue;
            attribute runTime : DurationValue;
            require constraint { targetSpeed > 0 and runTime > 0 }
        }
        
        requirement def SafetyReq {
            doc /* The lid shall remain locked until the rotor has come to a complete stop. */
            attribute lidLocked : Boolean;
            attribute rotorSpeed : RotationalSpeedValue;
            require constraint { rotorSpeed > 0 implies lidLocked == true }
        }
        
        requirement def TemperatureReq {
            doc /* The temperature control shall maintain the chamber at the setpoint to protect samples. */
            attribute setpoint : TemperatureValue;
            attribute actualTemp : TemperatureValue;
            require constraint { actualTemp >= setpoint - 1.0 and actualTemp <= setpoint + 1.0 }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part centrifuge1 : Centrifuge;
        
        action 'accelerate rotor': AccelerateRotor;
        action 'decelerate rotor': DecelerateRotor;
        action 'separate samples': SeparateSamples;
        action 'cool chamber': CoolChamber;
        action 'lock lid': LockLid;
        action 'unlock lid': UnlockLid;
        
        state 'centrifuge states': CentrifugeStates parallel {
            state 'operational states' {
                entry; then idle;
                state idle;
                accept 'StartCommand'
                    if centrifuge1.safetySystem.lidLocked
                    then loading;
                state loading {
                    entry 'lock lid';
                }
                accept 'StartSeparation'
                    then accelerating;
                state accelerating {
                    do 'accelerate rotor';
                }
                accept 'TargetSpeedReached'
                    then separating;
                state separating {
                    do 'separate samples';
                }
                accept 'DurationElapsed'
                    then decelerating;
                state decelerating {
                    do 'decelerate rotor';
                }
                accept 'RotorStopped'
                    then unloading;
                state unloading {
                    exit 'unlock lid';
                }
                accept 'RunComplete'
                    then idle;
            }
            state 'safety monitoring' {
                entry; then monitoring;
                state monitoring;
                accept when centrifuge1.safetySystem.vibrationSensor > 10.0
                    do send new 'EmergencyStop'() to centrifuge1.controlUnit.safetyIn
                    then emergencyStop;
                state emergencyStop {
                    do 'decelerate rotor';
                }
                accept 'RotorStopped'
                    then monitoring;
            }
        }
    }
}
