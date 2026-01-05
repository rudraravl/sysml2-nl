package IntermittentPneumaticCompressionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    
    item def CompressedAir {
        attribute pressure : PressureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    item def PressureCommand {
        attribute targetPressure : PressureValue;
        attribute duration : ISQ::TimeValue;
    }
    
    item def SensorData {
        attribute measuredPressure : PressureValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def PneumaticPort {
        inout item air : CompressedAir;
    }
    
    port def ControlPort {
        out item command : PressureCommand;
        in item feedback : SensorData;
    }
    
    port def PowerPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def Controller {
        port controlOut : ControlPort;
        port powerIn : PowerPort;
        
        attribute inflationPressure : PressureValue;
        attribute inflationDuration : ISQ::TimeValue;
        attribute holdDuration : ISQ::TimeValue;
        attribute deflationDuration : ISQ::TimeValue;
        attribute restDuration : ISQ::TimeValue;
        
        perform action executeTherapy;
    }
    
    part def AirCompressor {
        port pneumaticOut : PneumaticPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        
        attribute maxPressure : PressureValue;
        attribute maxFlowRate : ISQ::VolumeFlowRateValue;
        
        perform action generatePressure;
    }
    
    part def PressureSensor {
        port sensePort : PneumaticPort;
        port dataOut : ControlPort;
        
        attribute accuracy : PressureValue;
        attribute samplingRate : ISQ::FrequencyValue;
        
        perform action measurePressure;
    }
    
    part def ValveManifold {
        port pneumaticIn : PneumaticPort;
        port pneumaticOut : PneumaticPort[3];
        port controlIn : ControlPort;
        
        attribute numberOfValves : Integer;
        attribute responseTime : ISQ::TimeValue;
        
        perform action routeAirflow;
    }
    
    part def CompressionChamber {
        port airInlet : PneumaticPort;
        
        attribute chamberVolume : ISQ::VolumeValue;
        attribute maxPressure : PressureValue;
        attribute currentPressure : PressureValue;
        
        perform action applyPressure;
    }
    
    part def CompressionSleeve {
        port pneumaticInterface : PneumaticPort[3];
        
        part distalChamber : CompressionChamber {
            attribute :>> chamberVolume = 0.4;
            attribute :>> maxPressure = 60.0;
        }
        
        part middleChamber : CompressionChamber {
            attribute :>> chamberVolume = 0.5;
            attribute :>> maxPressure = 60.0;
        }
        
        part proximalChamber : CompressionChamber {
            attribute :>> chamberVolume = 0.6;
            attribute :>> maxPressure = 60.0;
        }
        
        attribute chambers[3] ordered : CompressionChamber = (distalChamber, middleChamber, proximalChamber);
    }
    
    part def SafetyMonitor {
        port monitorPort : ControlPort;
        
        attribute maxSafePressure : PressureValue;
        attribute emergencyShutoffEnabled : Boolean;
        
        perform action monitorSafety;
    }
    
    action def InflateSequentially {
        in chambers[*] ordered : CompressionChamber;
        in targetPressure : PressureValue;
        in inflationRate : ISQ::VolumeFlowRateValue;
        out allInflated : Boolean;
        
        for chamber in chambers {
            perform action inflateChamber {
                in chamberRef = chamber;
                in pressure = targetPressure;
                out inflated : Boolean;
            }
        }
        then assign allInflated := true;
    }
    
    action def MaintainPressure {
        in targetPressure : PressureValue;
        in holdDuration : ISQ::TimeValue;
        in tolerance : PressureValue;
        
        first start;
        then merge monitorLoop;
        
        action checkPressure {
            out currentPressure : PressureValue;
        }
        then decide;
            if checkPressure.currentPressure < (targetPressure - tolerance) then increasePressure;
            if checkPressure.currentPressure > (targetPressure + tolerance) then decreasePressure;
            if checkPressure.currentPressure >= (targetPressure - tolerance) and 
               checkPressure.currentPressure <= (targetPressure + tolerance) then continueMonitoring;
        
        action increasePressure;
        then monitorLoop;
        
        action decreasePressure;
        then monitorLoop;
        
        action continueMonitoring;
        then monitorLoop;
    }
    
    action def DeflateAllChambers {
        in chambers[*] : CompressionChamber;
        in deflationDuration : ISQ::TimeValue;
        out deflated : Boolean;
        
        action openExhaustValves;
        then action waitForDeflation {
            in duration = deflationDuration;
        }
        then action closeExhaustValves;
        then assign deflated := true;
    }
    
    action def MonitorSafety {
        in maxAllowedPressure : PressureValue;
        in currentPressure : PressureValue;
        out safetyViolation : Boolean;
        
        first start;
        then merge continuousMonitor;
        
        action checkSafety {
            out pressureExceeded : Boolean;
        }
        then decide;
            if checkSafety.pressureExceeded then triggerShutdown;
            if not checkSafety.pressureExceeded then normalOperation;
        
        action triggerShutdown {
            then assign safetyViolation := true;
        }
        then done;
        
        action normalOperation;
        then continuousMonitor;
    }
    
    action def ExecuteTherapySession {
        in sessionDuration : ISQ::TimeValue;
        in cycleParameters : PressureCommand;
        out cyclesCompleted : Integer;
        
        first start;
        then action initialize;
        then merge cycleLoop;
        
        action performCycle {
            first action inflate : InflateSequentially;
            then action hold : MaintainPressure;
            then action deflate : DeflateAllChambers;
            then action rest;
        }
        then action incrementCounter;
        then decide;
            if sessionDuration > 0 then cycleLoop;
            if sessionDuration <= 0 then endSession;
        
        action endSession;
        then done;
    }
    
    part ipcDevice : IPCTherapySystem {
        doc /*
            Intermittent Pneumatic Compression (IPC) System for Deep Vein Thrombosis (DVT) Prevention
            
            Primary Function: The system applies sequential, cyclical compression to patient limbs 
            through multi-chamber inflatable sleeves to enhance venous blood flow and prevent blood 
            stasis in immobilized or post-surgical patients. The therapy operates by inflating chambers 
            in a distal-to-proximal sequence, maintaining therapeutic pressure, then rapidly deflating 
            to allow venous refill, repeating this cycle to simulate natural muscle pump action.
        */
        
        attribute operatingVoltage : ISQ::ElectricPotentialValue = 120.0;
        attribute sessionDuration : ISQ::TimeValue = 60.0;
        attribute therapeuticPressure : PressureValue = 45.0;
        attribute cycleFrequency : ISQ::FrequencyValue = 0.05;
        
        part controller : Controller {
            attribute :>> inflationPressure = 45.0;
            attribute :>> inflationDuration = 12.0;
            attribute :>> holdDuration = 3.0;
            attribute :>> deflationDuration = 2.0;
            attribute :>> restDuration = 3.0;
            
            perform action therapyControl : ExecuteTherapySession;
        }
        
        part compressor : AirCompressor {
            attribute :>> maxPressure = 80.0;
            attribute :>> maxFlowRate = 15.0;
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> accuracy = 0.5;
            attribute :>> samplingRate = 10.0;
        }
        
        part valveManifold : ValveManifold {
            attribute :>> numberOfValves = 6;
            attribute :>> responseTime = 0.1;
        }
        
        part sleeve : CompressionSleeve;
        
        part safetyMonitor : SafetyMonitor {
            attribute :>> maxSafePressure = 65.0;
            attribute :>> emergencyShutoffEnabled = true;
            
            perform action safetyCheck : MonitorSafety;
        }
        
        connection compressorToManifold : PneumaticPort
            connect compressor.pneumaticOut to valveManifold.pneumaticIn;
        
        connection manifoldToSleeve1 : PneumaticPort
            connect valveManifold.pneumaticOut[1] to sleeve.pneumaticInterface[1];
        
        connection manifoldToSleeve2 : PneumaticPort
            connect valveManifold.pneumaticOut[2] to sleeve.pneumaticInterface[2];
        
        connection manifoldToSleeve3 : PneumaticPort
            connect valveManifold.pneumaticOut[3] to sleeve.pneumaticInterface[3];
        
        connection controlToCompressor : ControlPort
            connect controller.controlOut to compressor.controlIn;
        
        connection sensorToController : ControlPort
            connect pressureSensor.dataOut to controller.controlOut;
        
        port mainPower : PowerPort;
    }
    
    part def IPCTherapySystem;
    
    requirement def TherapeuticEfficacy {
        doc /* The IPC system shall provide effective sequential compression therapy to enhance venous return. */
        
        require pressureDeliveryRequirement;
        require sequentialCompressionRequirement;
        require cycleTimingRequirement;
    }
    
    requirement <'IPC-REQ-001'> pressureDeliveryRequirement {
        doc /* The system shall deliver therapeutic compression pressure between 40-50 mmHg to each chamber. */
        
        subject ipcDevice;
        
        require constraint {
            ipcDevice.therapeuticPressure >= 40.0 and
            ipcDevice.therapeuticPressure <= 50.0
        }
    }
    
    requirement <'IPC-REQ-002'> sequentialCompressionRequirement {
        doc /* The system shall inflate chambers in sequential distal-to-proximal order. */
        
        subject ipcDevice.sleeve;
        
        require constraint {
            ipcDevice.sleeve.chambers->size() == 3
        }
    }
    
    requirement <'IPC-REQ-003'> cycleTimingRequirement {
        doc /* The system shall complete full compression cycles at regular intervals between 15-25 seconds. */
        
        subject ipcDevice.controller;
        
        require constraint {
            (ipcDevice.controller.inflationDuration + 
             ipcDevice.controller.holdDuration + 
             ipcDevice.controller.deflationDuration + 
             ipcDevice.controller.restDuration) >= 15.0 and
            (ipcDevice.controller.inflationDuration + 
             ipcDevice.controller.holdDuration + 
             ipcDevice.controller.deflationDuration + 
             ipcDevice.controller.restDuration) <= 25.0
        }
    }
    
    requirement <'IPC-REQ-004'> safetyPressureLimit {
        doc /* The system shall not exceed 65 mmHg pressure in any chamber to prevent tissue damage. */
        
        subject ipcDevice.safetyMonitor;
        
        require constraint {
            ipcDevice.safetyMonitor.maxSafePressure <= 65.0 and
            ipcDevice.safetyMonitor.emergencyShutoffEnabled == true
        }
    }
    
    requirement <'IPC-REQ-005'> continuousOperationRequirement {
        doc /* The system shall operate continuously for therapy sessions up to 120 minutes without interruption. */
        
        subject ipcDevice;
        
        require constraint {
            ipcDevice.sessionDuration <= 120.0
        }
    }
    
    requirement <'IPC-REQ-006'> pressureAccuracyRequirement {
        doc /* The system shall maintain pressure within ±2 mmHg of target therapeutic pressure. */
        
        subject ipcDevice.pressureSensor;
        
        require constraint {
            ipcDevice.pressureSensor.accuracy <= 2.0
        }
    }
}
