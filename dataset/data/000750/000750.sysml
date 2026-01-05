package ROTIGS_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CommandSignal;
    attribute def VideoSignal;
    attribute def TelemetryData;
    attribute def TargetCoordinates {
        azimuth : AngleValue;
        elevation : AngleValue;
        range : LengthValue;
    }
    
    item def ThermalImage;
    item def TargetingData {
        coordinates : TargetCoordinates;
        locked : Boolean;
    }
    
    port def ControlPort {
        in commands : CommandSignal;
        out status : TelemetryData;
    }
    
    port def VideoPort {
        out video : VideoSignal;
    }
    
    port def TargetingPort {
        out targetData : TargetingData;
    }
    
    port def WeaponPort {
        in fireCommand : Boolean;
        out weaponStatus : TelemetryData;
    }
    
    part def OperatorStation {
        port controlOut : ControlPort;
        port videoIn : VideoPort;
        port targetingIn : TargetingPort;
        
        part display;
        part controlInterface;
        part communicationLink;
    }
    
    part def ThermalSight {
        port controlIn : ControlPort;
        port videoOut : VideoPort;
        port targetingOut : TargetingPort;
        
        part thermalImager;
        part imageProcessor;
        part trackingComputer;
        part gimbalSystem;
    }
    
    part def WeaponSystem {
        port fireControlIn : WeaponPort;
        
        part gun;
        part ammunition;
        part firingMechanism;
        part safetyInterlock;
    }
    
    part def ROTIGS {
        doc /* Remotely Operated Thermal Imaging Gun Sight system for remote target acquisition and engagement */
        
        part operatorStation : OperatorStation;
        part thermalSight : ThermalSight;
        part weaponSystem : WeaponSystem;
        
        connect operatorStation.controlOut to thermalSight.controlIn;
        connect thermalSight.videoOut to operatorStation.videoIn;
        connect thermalSight.targetingOut to operatorStation.targetingIn;
        
        perform action primaryMission;
    }
    
    action def AcquireTarget {
        in searchCommands : CommandSignal;
        out thermalVideo : VideoSignal;
        out targetFound : Boolean;
    }
    
    action def TrackTarget {
        in trackCommands : CommandSignal;
        in targetPosition : TargetCoordinates;
        out trackingData : TargetingData;
    }
    
    action def EngageTarget {
        in fireAuthorization : Boolean;
        in targetLock : TargetingData;
        out fireExecuted : Boolean;
    }
    
    action def RemoteTargetEngagement {
        doc /* Primary mission action: remotely detect, track, and engage targets using thermal imaging */
        
        in operatorCommands : CommandSignal;
        out missionStatus : TelemetryData;
        
        first start;
        then merge searchLoop;
        
        action acquire : AcquireTarget {
            in searchCommands = operatorCommands;
            out thermalVideo;
            out targetFound;
        }
        
        then decide;
            if acquire.targetFound then track;
            if not acquire.targetFound then searchLoop;
        
        action track : TrackTarget {
            in trackCommands = operatorCommands;
            in targetPosition;
            out trackingData;
        }
        
        then decide;
            if track.trackingData.locked then engage;
            if not track.trackingData.locked then searchLoop;
        
        action engage : EngageTarget {
            in fireAuthorization;
            in targetLock = track.trackingData;
            out fireExecuted;
        }
        
        then searchLoop;
        then done;
    }
    
    state def SightOperationalStates {
        entry; then powerOff;
        
        state powerOff;
        accept at powerOff then initializing;
        
        state initializing {
            doc /* System startup and self-test */
        }
        accept at initializing then standby;
        
        state standby {
            doc /* Ready to receive operator commands */
        }
        accept at standby then searching;
        
        state searching {
            doc /* Scanning for potential targets */
        }
        accept at searching then tracking;
        
        state tracking {
            doc /* Maintaining lock on identified target */
        }
        accept at tracking then locked;
        
        state locked {
            doc /* Target locked and ready for engagement */
        }
        accept at locked then engaging;
        
        state engaging {
            doc /* Weapon firing sequence active */
        }
        accept at engaging then searching;
    }
    
    requirement def SystemCapability {
        doc /* The ROTIGS shall provide remote observation, targeting, and engagement capability using thermal imaging technology */
        
        require remoteOperation;
        require thermalImaging;
        require targetTracking;
        require weaponControl;
    }
    
    requirement remoteOperation {
        doc /* All system functions shall be controllable from a remote operator station */
        subject rotigs : ROTIGS;
    }
    
    requirement thermalImaging {
        doc /* The system shall provide continuous thermal video feed to the operator */
        subject sight : ROTIGS::thermalSight;
        
        attribute frameRate : FrequencyValue = 30 [Hz];
        attribute resolution : Real = 640;
    }
    
    requirement targetTracking {
        doc /* The system shall automatically track detected targets and maintain lock */
        subject sight : ROTIGS::thermalSight;
        
        attribute trackingAccuracy : AngleValue = 0.5 [mrad];
        attribute maxRange : LengthValue = 3000 [m];
    }
    
    requirement weaponControl {
        doc /* The system shall enable controlled weapon engagement under operator authorization */
        subject weapon : ROTIGS::weaponSystem;
        
        constraint safetyInterlock {
            doc /* Firing shall only occur when target is locked and operator authorizes */
        }
    }
    
    part rotigs : ROTIGS {
        perform action primaryMission : RemoteTargetEngagement {
            in operatorCommands;
            out missionStatus;
        }
        
        part thermalSight : ThermalSight {
            state sightStates : SightOperationalStates;
        }
    }
    
    satisfy SystemCapability by rotigs;
}
