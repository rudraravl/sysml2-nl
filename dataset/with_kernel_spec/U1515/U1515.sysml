package ThunderboltSirenSystem {
    private import ScalarValues::*;
    private import SI::*;
    
    package Definitions {
        attribute def ActivateCmd;
        attribute def DeactivateCmd;
        attribute def TestCmd;
        attribute def PowerControlSignal;
        
        item def ElectricPower;
        item def MechanicalRotation;
        item def Airflow;
        item def SoundWave;
        
        action def 'Convert Utility Power' {
            in item utilityPower : ElectricPower;
            out item highCurrentPower : ElectricPower;
        }
        
        action def 'Energize Motor' {
            in item power : ElectricPower;
            out item rotation : MechanicalRotation;
        }
        
        action def 'Cut Motor Power';
        
        action def 'Spin Up Rotor' {
            in item rotation : MechanicalRotation;
        }
        
        action def 'Modulate Airflow' {
            in item rotation : MechanicalRotation;
            out item modulatedAirflow : Airflow;
        }
        
        action def 'Produce Warning Sound' {
            out item projectedSound : SoundWave;
        }
        
        part def PowerSupply {
            in item utilityPower : ElectricPower;
            in item controlSignal : PowerControlSignal;
            out item highCurrentPower : ElectricPower;
            perform action 'convert utility power' : 'Convert Utility Power';
        }
        
        part def ElectricMotor {
            in item power : ElectricPower;
            in item control : PowerControlSignal;
            out item rotation : MechanicalRotation;
            attribute spinUpTime : Real = 10;
            perform action 'energize motor' : 'Energize Motor';
            perform action 'cut motor power' : 'Cut Motor Power';
        }
        
        part def RotorAssembly {
            in item rotation : MechanicalRotation;
            in item modulatedAirflow : Airflow;
            out item projectedSound : SoundWave;
            attribute hornCount : Integer = 5;
            perform action 'spin up rotor' : 'Spin Up Rotor';
        }
        
        part def MechanicalChopper {
            in item rotation : MechanicalRotation;
            out item modulatedAirflow : Airflow;
            attribute chopFrequency : Real = 460;
            perform action 'modulate airflow' : 'Modulate Airflow';
        }
        
        part def ControlUnit {
            in item activate : ActivateCmd;
            in item test : TestCmd;
            in item deactivate : DeactivateCmd;
            out item controlSignal : PowerControlSignal;
        }
        
        state def 'Siren Control States' {
            entry; then standby;
            state standby;
            transition 'standby-to-startup'
                first standby
                accept activate : ActivateCmd
                then startup;
            state startup;
            transition 'startup-to-active'
                first startup
                then active;
            state active;
            transition 'active-to-cooldown'
                first active
                accept deactivate : DeactivateCmd
                then cooldown;
            state cooldown;
            transition 'cooldown-to-standby'
                first cooldown
                then standby;
            transition 'standby-to-test'
                first standby
                accept test : TestCmd
                then testMode;
            state testMode;
            transition 'testMode-to-standby'
                first testMode
                then standby;
        }
        
        part def ThunderboltSiren {
            part powerSupply : PowerSupply;
            part controlUnit : ControlUnit;
            part electricMotor : ElectricMotor;
            part rotorAssembly : RotorAssembly;
            part mechanicalChopper : MechanicalChopper;
            
            port utilityPowerPort {
                in item utilityPower : ElectricPower;
            }
            port commandPort {
                in item activate : ActivateCmd;
                in item test : TestCmd;
                in item deactivate : DeactivateCmd;
            }
            port soundPort {
                out item projectedSound : SoundWave;
            }
            
            exhibit state 'siren states' : 'Siren Control States';
        }
        
        requirement def 'Spin Up Time Requirement' {
            doc /* The motor shall spin up the heavy rotor assembly to full operating speed in less than 10 seconds. */
            attribute maxSpinUpTime : Real = 10;
            subject siren : ThunderboltSiren;
            constraint { siren.electricMotor.spinUpTime < maxSpinUpTime; }
        }
        
        requirement def 'Omnidirectional Sound Requirement' {
            doc /* The siren shall generate an extremely loud, omnidirectional warning sound using five projecting horns. */
            subject siren : ThunderboltSiren;
            constraint { siren.rotorAssembly.hornCount == 5; }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part sirenSystem : ThunderboltSiren {
            flow utilityPowerPort.utilityPower to powerSupply.utilityPower;
            flow commandPort.activate to controlUnit.activate;
            flow commandPort.test to controlUnit.test;
            flow commandPort.deactivate to controlUnit.deactivate;
            
            flow controlUnit.controlSignal to powerSupply.controlSignal;
            flow controlUnit.controlSignal to electricMotor.control;
            flow powerSupply.highCurrentPower to electricMotor.power;
            
            flow electricMotor.rotation to rotorAssembly.rotation;
            flow electricMotor.rotation to mechanicalChopper.rotation;
            
            flow mechanicalChopper.modulatedAirflow to rotorAssembly.modulatedAirflow;
            flow rotorAssembly.projectedSound to soundPort.projectedSound;
            
            satisfy 'Spin Up Time Requirement';
            satisfy 'Omnidirectional Sound Requirement';
        }
    }
}
