package VelocityReceiverSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def VelocitySignal {
        attribute vx : SpeedValue;
        attribute vy : SpeedValue;
        attribute vz : SpeedValue;
        attribute timestamp : TimeValue;
        attribute signalQuality : Real;
    }
    
    item def ProcessedVelocityData {
        attribute velocity : VelocitySignal;
        attribute confidence : Real;
        attribute status : ReceiverStatusType;
    }
    
    item def ControlCommand;
    item def CalibrationData;
    
    enum def ReceiverStatusType {
        enum idle;
        enum acquiring;
        enum tracking;
        enum lost;
    }
    
    port def VelocityInputPort {
        in item signal : VelocitySignal;
    }
    
    port def VelocityOutputPort {
        out item data : ProcessedVelocityData;
    }
    
    port def ControlPort {
        in item command : ControlCommand;
        out item status : ReceiverStatusType;
    }
    
    part def SignalAcquisitionUnit {
        attribute searchBandwidth : FrequencyValue;
        attribute lockThreshold : Real;
        
        state def AcquisitionStates {
            entry; then searching;
            
            state searching {
                entry; then scanFrequencies;
                action scanFrequencies;
                accept at when signalDetected then locking;
                accept at when timeout then searching;
            }
            
            state locking {
                entry; then lockSignal;
                action lockSignal;
                accept at when lockAchieved then locked;
                accept at when lockFailed then searching;
            }
            
            state locked {
                do action maintainLock;
                accept at when signalLost then searching;
            }
        }
        
        event signalDetected;
        event lockAchieved;
        event lockFailed;
        event signalLost;
        event timeout;
    }
    
    part def SignalProcessor {
        attribute filterBandwidth : FrequencyValue;
        attribute noiseFloor : Real;
        
        action processVelocitySignal {
            in rawSignal : VelocitySignal;
            out processedSignal : VelocitySignal;
            
            first start;
            then action validateSignal {
                in signal : VelocitySignal = rawSignal;
                out isValid : Boolean;
            }
            then decide;
                if validateSignal.isValid then applyFilter;
                if not validateSignal.isValid then rejectSignal;
            
            action applyFilter {
                in signal : VelocitySignal = rawSignal;
                out filtered : VelocitySignal;
            }
            then action compensateErrors {
                in signal : VelocitySignal = applyFilter.filtered;
                out compensated : VelocitySignal;
            }
            then merge outputResult;
            
            action rejectSignal;
            then outputResult;
            then done;
        }
    }
    
    part def VelocityEstimator {
        attribute estimationWindow : TimeValue;
        attribute convergenceRate : Real;
        
        action estimateVelocity {
            in processedSignal : VelocitySignal;
            out velocityEstimate : ProcessedVelocityData;
            
            calc computeVelocity {
                in signal : VelocitySignal = processedSignal;
                return : ProcessedVelocityData;
            }
        }
    }
    
    part def ReceiverController {
        attribute operatingMode : ReceiverStatusType;
        
        event needsCalibration;
        event isOperational;
        
        action controlReceiverOperation {
            first start;
            then merge monitorStatus;
            
            action monitorStatus {
                out currentStatus : ReceiverStatusType;
            }
            then decide;
                if needsCalibration then performCalibration;
                if isOperational then continueOperation;
            
            action performCalibration {
                in calibrationParams : CalibrationData;
            }
            then monitorStatus;
            
            action continueOperation {
                out operationStatus : ReceiverStatusType;
            }
            then monitorStatus;
        }
    }
    
    part def VelocityReceiver {
        part acquisitionUnit : SignalAcquisitionUnit;
        part processor : SignalProcessor;
        part estimator : VelocityEstimator;
        part controller : ReceiverController;
        
        port velocityIn : VelocityInputPort;
        port velocityOut : VelocityOutputPort;
        port control : ControlPort;
        
        action receiveAndProcessVelocity {
            first start;
            then merge continuousReception;
            
            action continuousReception;
            then action acquireSignal {
                out rawSignal : VelocitySignal;
            }
            then action processSignal : SignalProcessor::processVelocitySignal {
                in rawSignal = acquireSignal.rawSignal;
                out processedSignal : VelocitySignal;
            }
            then action estimateVel : VelocityEstimator::estimateVelocity {
                in processedSignal = processSignal.processedSignal;
                out velocityEstimate : ProcessedVelocityData;
            }
            then action outputData {
                in estimate : ProcessedVelocityData = estimateVel.velocityEstimate;
                out result : ProcessedVelocityData;
            }
            then continuousReception;
        }
        
        perform action receiveAndProcessVelocity[*] ordered;
    }
    
    part def NavigationComputer {
        attribute targetVelocity : VelocitySignal;
        
        action computeNavigation {
            in velocityData : ProcessedVelocityData;
            out navigationOutput;
        }
    }
    
    part def VelocitySource {
        attribute transmitPower : PowerValue;
        
        action generateVelocitySignal {
            out signal : VelocitySignal;
        }
    }
    
    part context : VelocityReceiverSystemContext {
        part source : VelocitySource {
            perform generateVelocitySignal;
        }
        
        part receiver : VelocityReceiver {
            perform receiveAndProcessVelocity;
        }
        
        part navComputer : NavigationComputer {
            perform computeNavigation;
        }
        
        flow source.generateVelocitySignal.signal to receiver.velocityIn.signal;
        flow receiver.velocityOut.data to navComputer.computeNavigation.velocityData;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The velocity receiver shall continuously acquire incoming velocity signals,
               process them to remove noise and errors, estimate accurate velocity vectors,
               and provide processed velocity data to downstream navigation systems. */
        
        subject receiver : VelocityReceiver;
        
        require constraint {
            receiver.processor.processVelocitySignal.processedSignal.signalQuality >= 0.8
        }
    }
    
    requirement def SignalAcquisitionRequirement {
        doc /* The velocity receiver shall acquire and lock onto velocity signals
               within 60 seconds of system initialization. */
        
        subject receiver : VelocityReceiver;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The velocity receiver shall provide velocity measurements with
               accuracy better than 0.05 m/s per axis under nominal conditions. */
        
        subject receiver : VelocityReceiver;
    }
    
    requirement def ContinuousOperationRequirement {
        doc /* The velocity receiver shall operate continuously and update
               velocity estimates at a minimum rate of 20 Hz. */
        
        subject receiver : VelocityReceiver;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the velocity receiver system defining
               its primary function and operational characteristics. */
        
        require primaryFunction : PrimaryFunctionRequirement;
        require signalAcquisition : SignalAcquisitionRequirement;
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require continuousOperation : ContinuousOperationRequirement;
    }
}
