package 'Urinal System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def UserPresenceSignal;
    attribute def FlushTrigger;
    attribute def MaintenanceAlert;
    
    item def LiquidWaste;
    item def FreshWater;
    item def Wastewater {
        part waste : LiquidWaste;
        part water : FreshWater;
    }
    
    port def WaterSupplyPort {
        in attribute supplyPressure : PressureValue;
        out item waterFlow : FreshWater;
        out attribute flowRate : VolumetricFlowRateValue;
    }
    
    port def WasteDischargePort {
        in item wastewater : Wastewater;
        in attribute dischargeRate : VolumetricFlowRateValue;
    }
    
    port def SensorSignalPort {
        out attribute userDetected : Boolean;
        out attribute detectionTime : TimeValue;
    }
    
    port def ControlSignalPort {
        in attribute activationCommand : Boolean;
        out attribute valveStatus : Boolean;
    }
    
    part def InfraredSensor {
        port signalOut : SensorSignalPort;
        attribute detectionRange : LengthValue;
        attribute responseTime : TimeValue;
        attribute currentState : Boolean;
    }
    
    part def FlushController {
        port sensorIn : SensorSignalPort;
        port valveControl : ControlSignalPort;
        attribute userPresentFlag : Boolean;
        attribute flushDelayTime : TimeValue;
        attribute minimumFlushInterval : TimeValue;
        attribute lastFlushTime : TimeValue;
        
        state controlBehavior {
            entry; then idle;
            
            state idle {
                entry assign userPresentFlag := false;
                entry assign valveControl.activationCommand := false;
            }
            
            transition idle_to_detected
                first idle
                accept at sensorIn
                if sensorIn.userDetected
                then userDetected;
            
            state userDetected {
                entry assign userPresentFlag := true;
            }
            
            transition detected_to_waiting
                first userDetected
                accept at sensorIn
                if not sensorIn.userDetected
                then waitingToFlush;
            
            state waitingToFlush {
                entry assign userPresentFlag := false;
            }
            
            transition waiting_to_flushing
                first waitingToFlush
                accept after flushDelayTime
                then flushing;
            
            state flushing {
                entry assign valveControl.activationCommand := true;
            }
            
            transition flushing_to_complete
                first flushing
                accept after 5.0 [s]
                then flushComplete;
            
            state flushComplete {
                entry assign valveControl.activationCommand := false;
            }
            
            transition complete_to_idle
                first flushComplete
                accept after 1.0 [s]
                then idle;
        }
    }
    
    part def SolenoidValve {
        port waterIn : WaterSupplyPort;
        port waterOut : WaterSupplyPort;
        port control : ControlSignalPort;
        attribute isOpen : Boolean;
        attribute nominalFlowRate : VolumetricFlowRateValue;
        attribute operatingPressure : PressureValue;
        attribute actuationTime : TimeValue;
    }
    
    part def FixtureBowl {
        port waterInlet : WaterSupplyPort;
        port wasteInlet {
            in item waste : LiquidWaste;
        }
        port drainOutlet : WasteDischargePort;
        attribute bowlCapacity : VolumeValue;
        attribute surfaceArea : AreaValue;
        attribute drainDiameter : LengthValue;
    }
    
    part def PTrap {
        port inletPort : WasteDischargePort;
        port outletPort : WasteDischargePort;
        attribute sealDepth : LengthValue;
        attribute trapVolume : VolumeValue;
        attribute pipeDiameter : LengthValue;
    }
    
    part def DrainPipe {
        port inlet : WasteDischargePort;
        port outlet : WasteDischargePort;
        attribute pipeLength : LengthValue;
        attribute pipeDiameter : LengthValue;
        attribute slope : Real;
    }
    
    action def DetectUserPresence {
        in detectionRange : LengthValue;
        out userPresent : Boolean;
        out timestamp : TimeValue;
    }
    
    action def ControlFlushSequence {
        in userDetected : Boolean;
        in delayTime : TimeValue;
        out flushCommand : Boolean;
    }
    
    action def ActivateValve {
        in command : Boolean;
        in duration : TimeValue;
        out waterVolume : VolumeValue;
        out flowRate : VolumetricFlowRateValue;
    }
    
    action def DischargeWaste {
        in inflowRate : VolumetricFlowRateValue;
        in wasteVolume : VolumeValue;
        out drainageComplete : Boolean;
    }
    
    action def PerformAutomatedFlushCycle {
        first start;
        
        then merge monitorLoop;
        
        then action detectUser : DetectUserPresence {
            in detectionRange;
            out userPresent : Boolean;
            out timestamp : TimeValue;
        }
        
        then decide;
            if detectUser.userPresent then trackPresence;
            if not detectUser.userPresent then checkPreviousState;
        
        action trackPresence {
            accept presence : UserPresenceSignal;
        }
        then monitorLoop;
        
        action checkPreviousState;
        then decide;
            if previousUserPresent then initiateFlush;
            else monitorLoop;
        
        action initiateFlush;
        then action delayBeforeFlush;
        
        then action activateValve : ActivateValve {
            in command := true;
            in duration := 5.0 [s];
            out waterVolume : VolumeValue;
            out flowRate : VolumetricFlowRateValue;
        }
        
        then action dischargeWaste : DischargeWaste {
            in inflowRate = activateValve.flowRate;
            in wasteVolume = activateValve.waterVolume;
            out drainageComplete : Boolean;
        }
        
        then action completeFlush;
        then monitorLoop;
        
        private attribute previousUserPresent : Boolean := false;
    }
    
    requirement def SanitationRequirement {
        doc /* The urinal system shall maintain hygienic conditions through automated waste removal. */
    }
    
    requirement def WaterConservationRequirement {
        doc /* The urinal system shall minimize water usage while ensuring effective waste disposal. */
    }
    
    requirement def OdorPreventionRequirement {
        doc /* The urinal system shall prevent sewer gas escape through proper trap seal maintenance. */
    }
    
    requirement def HandsFreeOperationRequirement {
        doc /* The urinal system shall operate without requiring user contact for activation. */
    }
    
    requirement <'REQ-001'> automaticFlushRequirement : SanitationRequirement {
        doc /* The system shall automatically initiate a flush cycle within 3 seconds after user departure. */
        subject urinalSystem : UrinalSystem;
    }
    
    requirement <'REQ-002'> waterUsageRequirement : WaterConservationRequirement {
        doc /* Each flush cycle shall use no more than 3.8 liters of water. */
        subject urinalSystem : UrinalSystem;
    }
    
    requirement <'REQ-003'> trapSealRequirement : OdorPreventionRequirement {
        doc /* The trap seal depth shall be maintained at minimum 50mm to prevent odor escape. */
        subject urinalSystem : UrinalSystem;
    }
    
    requirement <'REQ-004'> touchlessOperationRequirement : HandsFreeOperationRequirement {
        doc /* The system shall detect user presence and absence without physical contact. */
        subject urinalSystem : UrinalSystem;
    }
    
    part def UrinalSystem {
        doc /* 
            An automated urinal system designed for sanitary liquid waste disposal in public 
            and commercial facilities. The system provides touchless operation through infrared 
            sensing technology, automatically flushing after user departure to maintain hygiene 
            while conserving water through controlled flush volumes and timing.
            
            Primary Function:
            The urinal system detects user presence via infrared sensor, collects liquid waste 
            in a ceramic bowl fixture, and automatically initiates a timed flush cycle after 
            the user departs. Fresh water is delivered through a solenoid valve to rinse the 
            bowl and transport waste through a P-trap into the drainage system, preventing 
            sewer gas escape while minimizing water consumption.
        */
        
        part sensor : InfraredSensor {
            attribute detectionRange = 600.0 [mm];
            attribute responseTime = 0.2 [s];
            attribute currentState = false;
        }
        
        part controller : FlushController {
            attribute userPresentFlag = false;
            attribute flushDelayTime = 2.0 [s];
            attribute minimumFlushInterval = 10.0 [s];
            attribute lastFlushTime = 0.0 [s];
        }
        
        part flushValve : SolenoidValve {
            attribute isOpen = false;
            attribute nominalFlowRate = 0.76 [L / s];
            attribute operatingPressure = 350000.0 [Pa];
            attribute actuationTime = 0.15 [s];
        }
        
        part bowl : FixtureBowl {
            attribute bowlCapacity = 2.5 [L];
            attribute drainDiameter = 50.0 [mm];
        }
        
        part trap : PTrap {
            attribute sealDepth = 50.0 [mm];
            attribute trapVolume = 0.4 [L];
            attribute pipeDiameter = 50.0 [mm];
        }
        
        part drainPipe : DrainPipe {
            attribute pipeLength = 2000.0 [mm];
            attribute pipeDiameter = 75.0 [mm];
            attribute slope = 0.02;
        }
        
        connect sensor.signalOut to controller.sensorIn;
        connect controller.valveControl to flushValve.control;
        connect flushValve.waterOut to bowl.waterInlet;
        connect bowl.drainOutlet to trap.inletPort;
        connect trap.outletPort to drainPipe.inlet;
        
        perform action operationCycle : PerformAutomatedFlushCycle[*] ordered;
    }
    
    part urinalSystem : UrinalSystem;
}
