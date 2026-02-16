package 'Airlock System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    
    enum def DoorPosition {
        closed;
        open;
        locked;
    }
    
    enum def ChamberState {
        vacuum;
        pressurized;
        equalizing;
    }
    
    enum def CycleType {
        egress;
        ingress;
        idle;
    }
    
    item def Atmosphere;
    
    port def AtmospherePort {
        out attribute pressure : PressureValue;
        flow atmosphere : Atmosphere;
    }
    
    port def ControlPort {
        in attribute command : CycleType;
        out attribute status : ChamberState;
    }
    
    action def LockDoor {
        out newPosition : DoorPosition;
    }
    
    action def UnlockDoor {
        in chamberPressure : PressureValue;
        in adjacentPressure : PressureValue;
        out newPosition : DoorPosition;
    }
    
    action def OpenDoor {
        out newPosition : DoorPosition;
    }
    
    action def CloseDoor {
        out newPosition : DoorPosition;
    }
    
    part def Door {
        attribute position : DoorPosition;
        attribute maxPressureDifferential : PressureValue;
    }
    
    action def MeasurePressure {
        out currentPressure : PressureValue;
    }
    
    part def PressureSensor {
        port sensorPort : AtmospherePort;
        attribute reading : PressureValue;
    }
    
    action def OpenValve {
        out valveOpen : Boolean;
    }
    
    action def CloseValve {
        out valveOpen : Boolean;
    }
    
    part def PressureValve {
        attribute isOpen : Boolean;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    part def AirlockChamber {
        attribute volume : VolumeValue;
        attribute currentPressure : PressureValue;
        attribute chamberState : ChamberState;
        
        part innerDoor : Door {
            position = DoorPosition::locked;
            maxPressureDifferential = 10.0;
        }
        
        part outerDoor : Door {
            position = DoorPosition::locked;
            maxPressureDifferential = 10.0;
        }
        
        part chamberSensor : PressureSensor;
        part ventValve : PressureValve;
        part pressurizeValve : PressureValve;
        
        port habitatInterface : AtmospherePort;
        port spaceInterface : AtmospherePort;
        port controlInterface : ControlPort;
    }
    
    action def DepressurizeChamber {
        in initialPressure : PressureValue;
        in targetPressure : PressureValue;
        in ventRate : ISQ::VolumeFlowRateValue;
        out finalPressure : PressureValue;
        out depressTime : TimeValue;
    }
    
    action def PressurizeChamber {
        in initialPressure : PressureValue;
        in targetPressure : PressureValue;
        in fillRate : ISQ::VolumeFlowRateValue;
        out finalPressure : PressureValue;
        out pressTime : TimeValue;
    }
    
    action def VerifyDoorInterlock {
        in innerDoorPosition : DoorPosition;
        in outerDoorPosition : DoorPosition;
        out interlockSafe : Boolean;
    }
    
    action def CheckPressureEqualization {
        in chamberPressure : PressureValue;
        in targetPressure : PressureValue;
        in tolerance : PressureValue;
        out isEqualized : Boolean;
    }
    
    action def AirlockCycleOperation {
        in cycleRequest : CycleType;
        in habitatPressure : PressureValue;
        in spacePressure : PressureValue;
        in pressureTolerance : PressureValue;
        out cycleSuccess : Boolean;
        
        first start;
        then merge awaitCommand;
        
        then action receiveCommand {
            accept cmd : CycleType;
        }
        
        then decide;
            if receiveCommand.cmd == CycleType::egress then performEgress;
            if receiveCommand.cmd == CycleType::ingress then performIngress;
            if receiveCommand.cmd == CycleType::idle then awaitCommand;
        
        action performEgress {
            first action verifyInitialState : VerifyDoorInterlock {
                in innerDoorPosition;
                in outerDoorPosition;
                out interlockSafe;
            }
            
            then action closeInner : CloseDoor {
                out newPosition;
            }
            
            then action lockInner : LockDoor {
                out newPosition;
            }
            
            then action openVentValve : OpenValve {
                out valveOpen;
            }
            
            then action depressurize : DepressurizeChamber {
                in initialPressure = habitatPressure;
                in targetPressure = spacePressure;
                in ventRate;
                out finalPressure;
                out depressTime;
            }
            
            then action closeVentValve : CloseValve {
                out valveOpen;
            }
            
            then action checkEqualization : CheckPressureEqualization {
                in chamberPressure = depressurize.finalPressure;
                in targetPressure = spacePressure;
                in tolerance = pressureTolerance;
                out isEqualized;
            }
            
            then action unlockOuter : UnlockDoor {
                in chamberPressure = depressurize.finalPressure;
                in adjacentPressure = spacePressure;
                out newPosition;
            }
            
            then action openOuter : OpenDoor {
                out newPosition;
            }
        }
        then egressComplete;
        
        action performIngress {
            first action verifyInitialState : VerifyDoorInterlock {
                in innerDoorPosition;
                in outerDoorPosition;
                out interlockSafe;
            }
            
            then action closeOuter : CloseDoor {
                out newPosition;
            }
            
            then action lockOuter : LockDoor {
                out newPosition;
            }
            
            then action openPressValve : OpenValve {
                out valveOpen;
            }
            
            then action pressurize : PressurizeChamber {
                in initialPressure = spacePressure;
                in targetPressure = habitatPressure;
                in fillRate;
                out finalPressure;
                out pressTime;
            }
            
            then action closePressValve : CloseValve {
                out valveOpen;
            }
            
            then action checkEqualization : CheckPressureEqualization {
                in chamberPressure = pressurize.finalPressure;
                in targetPressure = habitatPressure;
                in tolerance = pressureTolerance;
                out isEqualized;
            }
            
            then action unlockInner : UnlockDoor {
                in chamberPressure = pressurize.finalPressure;
                in adjacentPressure = habitatPressure;
                out newPosition;
            }
            
            then action openInner : OpenDoor {
                out newPosition;
            }
        }
        then ingressComplete;
        
        action egressComplete {
            assign cycleSuccess := true;
        }
        then awaitCommand;
        
        action ingressComplete {
            assign cycleSuccess := true;
        }
        then awaitCommand;
    }
    
    part def AirlockSystem {
        doc /* An airlock system provides controlled transfer of personnel and equipment 
               between two environments with different atmospheric pressures, typically 
               between a pressurized habitat and the vacuum of space. The system maintains 
               safety through pressure equalization and door interlocks. */
        
        attribute habitatPressure : PressureValue;
        attribute externalPressure : PressureValue;
        attribute safetyTolerance : PressureValue;
        attribute chamberVolume : VolumeValue;
        attribute maxCycleTime : TimeValue;
        
        part chamber : AirlockChamber {
            volume = chamberVolume;
        }
        
        port habitatPort : AtmospherePort {
            pressure = habitatPressure;
        }
        
        port spacePort : AtmospherePort {
            pressure = externalPressure;
        }
        
        port systemControl : ControlPort;
        
        perform action cycleControl[*] ordered references AirlockCycleOperation;
    }
    
    requirement def SafetyInterlockRequirement {
        doc /* The airlock shall prevent both doors from being unlocked or open simultaneously 
               to maintain atmospheric integrity. */
        
        subject airlockSubject : AirlockSystem;
        
        require constraint doorMutualExclusion {
            not (airlockSubject.chamber.innerDoor.position == DoorPosition::open and 
                 airlockSubject.chamber.outerDoor.position == DoorPosition::open) and
            not (airlockSubject.chamber.innerDoor.position == DoorPosition::open and 
                 airlockSubject.chamber.outerDoor.position != DoorPosition::locked) and
            not (airlockSubject.chamber.outerDoor.position == DoorPosition::open and 
                 airlockSubject.chamber.innerDoor.position != DoorPosition::locked)
        }
    }
    
    requirement def PressureEqualizationRequirement {
        doc /* The airlock shall equalize chamber pressure to within specified tolerance 
               of the target environment before permitting door opening. */
        
        subject airlockSubject : AirlockSystem;
        
        require constraint pressureMatch {
            airlockSubject.chamber.currentPressure >= 
                (airlockSubject.habitatPressure - airlockSubject.safetyTolerance) or
            airlockSubject.chamber.currentPressure <= 
                (airlockSubject.externalPressure + airlockSubject.safetyTolerance)
        }
    }
    
    requirement def CyclePerformanceRequirement {
        doc /* The airlock shall complete a full pressurization or depressurization cycle 
               within the maximum specified time under nominal conditions. */
        
        subject cycleSubject : AirlockCycleOperation;
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* The airlock chamber and doors shall withstand the maximum pressure differential 
               between internal and external environments. */
        
        subject airlockSubject : AirlockSystem;
    }
    
    requirement <'AIR-SYS-001'> airlockSystemRequirement {
        doc /* The airlock system shall provide safe, controlled transfer of personnel and 
               equipment between pressurized and unpressurized environments while maintaining 
               atmospheric integrity and crew safety through automated pressure management 
               and safety interlocks. */
        
        assume constraint operationalEnvironment {
            airlock.habitatPressure == 101.325 and
            airlock.externalPressure == 0.0 and
            airlock.safetyTolerance == 2.0
        }
        
        require SafetyInterlockRequirement;
        require PressureEqualizationRequirement;
        require CyclePerformanceRequirement;
        require StructuralIntegrityRequirement;
    }
    
    part airlock : AirlockSystem {
        habitatPressure = 101.325;
        externalPressure = 0.0;
        safetyTolerance = 2.0;
        chamberVolume = 15.0;
        maxCycleTime = 300.0;
        
        satisfy airlockSystemRequirement;
    }
}
