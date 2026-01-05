package IncentiveSpirometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def InhalationDepth;
    attribute def BreathHoldDuration;
    attribute def TherapySessionCount;
    
    attribute def VolumeCapacity :> ISQ::VolumeValue;
    
    attribute def AirFlowRate :> ISQ::VolumeFlowValue;
    
    attribute def PistonDisplacement :> ISQ::LengthValue;
    
    attribute def SessionDuration :> ISQ::TimeValue;
    
    enum def IndicatorState {
        idle;
        lowFlow;
        optimalFlow;
        targetReached;
        holding;
    }
    
    item def Air {
        attribute flowRate : AirFlowRate;
        attribute volume : VolumeCapacity;
    }
    
    port def AirFlowPort {
        in item airIn : Air;
        out item airOut : Air;
    }
    
    part def MouthpieceAssembly {
        attribute isSealed : Boolean;
        port patientConnection : AirFlowPort;
        port tubeConnection : AirFlowPort;
    }
    
    part def FlexibleTubing {
        attribute length : ISQ::LengthValue;
        port mouthpieceEnd : AirFlowPort;
        port chamberEnd : AirFlowPort;
    }
    
    part def MeasurementChamber {
        attribute currentVolume : VolumeCapacity;
        attribute maxCapacity : VolumeCapacity;
        attribute targetVolume : VolumeCapacity;
        port airInlet : AirFlowPort;
        port pistonInterface;
        
        part flowIndicatorBall {
            attribute position : PistonDisplacement;
            attribute targetPosition : PistonDisplacement;
        }
        
        part volumeScale {
            attribute markings : VolumeCapacity[*];
            attribute currentReading : VolumeCapacity;
        }
    }
    
    part def FlowRateCoach {
        attribute optimalFlowMin : AirFlowRate;
        attribute optimalFlowMax : AirFlowRate;
        attribute currentFlow : AirFlowRate;
        attribute coachingState : IndicatorState;
    }
    
    part def BaseUnit {
        attribute isStable : Boolean;
        port chamberMount;
    }
    
    action def DetectInhalation {
        in sealStatus : Boolean;
        out inhalationStarted : Boolean;
        out initialFlow : AirFlowRate;
    }
    
    action def MeasureVolume {
        in flowRate : AirFlowRate;
        in timeInterval : SessionDuration;
        in previousVolume : VolumeCapacity;
        out accumulatedVolume : VolumeCapacity;
    }
    
    action def UpdatePistonPosition {
        in inhaledVolume : VolumeCapacity;
        in chamberGeometry : ISQ::LengthValue;
        out pistonHeight : PistonDisplacement;
    }
    
    action def EvaluateFlowRate {
        in currentFlow : AirFlowRate;
        in optimalMin : AirFlowRate;
        in optimalMax : AirFlowRate;
        out coachingFeedback : IndicatorState;
    }
    
    action def CheckTargetAchievement {
        in currentVolume : VolumeCapacity;
        in targetVolume : VolumeCapacity;
        out targetReached : Boolean;
    }
    
    action def ResetDevice {
        out systemReady : Boolean;
    }
    
    action def PerformBreathingExercise {
        in targetInhalationVolume : VolumeCapacity;
        in holdDuration : SessionDuration;
        out achievedVolume : VolumeCapacity;
        out exerciseSuccessful : Boolean;
        
        first start;
        then merge awaitInhalation;
        
        then action detectBreath : DetectInhalation {
            in sealStatus : Boolean;
            out inhalationStarted : Boolean;
            out initialFlow : AirFlowRate;
        }
        
        then decide;
            if detectBreath.inhalationStarted then measurePhase;
            else awaitInhalation;
        
        action measurePhase {
            private attribute accumulatedVol : VolumeCapacity;
            private attribute currentFlowRate : AirFlowRate;
            
            action measureVolume : MeasureVolume {
                in flowRate = currentFlowRate;
                in timeInterval : SessionDuration;
                in previousVolume = accumulatedVol;
                out accumulatedVolume : VolumeCapacity;
            }
            then assign accumulatedVol := measureVolume.accumulatedVolume;
            
            then action updatePiston : UpdatePistonPosition {
                in inhaledVolume = accumulatedVol;
                in chamberGeometry : ISQ::LengthValue;
                out pistonHeight : PistonDisplacement;
            }
            
            then action evaluateFlow : EvaluateFlowRate {
                in currentFlow = currentFlowRate;
                in optimalMin : AirFlowRate;
                in optimalMax : AirFlowRate;
                out coachingFeedback : IndicatorState;
            }
            
            then action checkTarget : CheckTargetAchievement {
                in currentVolume = accumulatedVol;
                in targetVolume = targetInhalationVolume;
                out targetReached : Boolean;
            }
            
            then decide;
                if checkTarget.targetReached then holdPhase;
                else resetPhase;
        }
        
        action holdPhase {
            out holdComplete : Boolean;
        }
        then assign exerciseSuccessful := true;
        then resetPhase;
        
        action resetPhase : ResetDevice {
            out systemReady : Boolean;
        }
        then assign achievedVolume := measurePhase.accumulatedVol;
        then done;
    }
    
    state def SpirometerOperationalStates {
        entry; then ready;
        
        state ready {
            doc /* Device is ready for patient use. */
        }
        
        transition ready_to_detecting
            first ready
            accept patientSealed
            then detecting;
        
        state detecting {
            doc /* Monitoring for start of inhalation. */
            entry; do action sense : DetectInhalation;
        }
        
        transition detecting_to_measuring
            first detecting
            accept inhalationDetected
            then measuring;
        
        state measuring {
            doc /* Actively measuring inhalation volume and flow rate. */
            entry; do action measure : MeasureVolume;
            do action updateDisplay : UpdatePistonPosition;
            do action coach : EvaluateFlowRate;
        }
        
        transition measuring_to_targetAchieved
            first measuring
            accept volumeTargetReached
            then targetAchieved;
        
        transition measuring_to_ready
            first measuring
            accept inhalationStopped
            then ready;
        
        state targetAchieved {
            doc /* Target volume reached, patient should hold breath. */
        }
        
        transition targetAchieved_to_resetting
            first targetAchieved
            accept holdDurationElapsed
            then resetting;
        
        state resetting {
            doc /* Returning device to ready state. */
            entry; do action reset : ResetDevice;
        }
        
        transition resetting_to_ready
            first resetting
            accept resetComplete
            then ready;
    }
    
    part incentiveSpirometerDevice {
        doc /* A medical device that encourages patients to take slow, deep breaths 
               to improve lung function and prevent respiratory complications. */
        
        attribute prescribedTargetVolume : VolumeCapacity;
        attribute recommendedHoldTime : SessionDuration;
        attribute optimalFlowRateMin : AirFlowRate;
        attribute optimalFlowRateMax : AirFlowRate;
        attribute dailySessionGoal : TherapySessionCount;
        
        part mouthpiece : MouthpieceAssembly {
            attribute isSealed = false;
        }
        
        part tubing : FlexibleTubing;
        
        part chamber : MeasurementChamber {
            attribute currentVolume : VolumeCapacity;
            attribute maxCapacity : VolumeCapacity;
            attribute targetVolume : VolumeCapacity;
            
            part flowIndicatorBall {
                attribute position : PistonDisplacement;
                attribute targetPosition : PistonDisplacement;
            }
            
            part volumeScale {
                attribute markings : VolumeCapacity[*];
                attribute currentReading : VolumeCapacity;
            }
        }
        
        part flowCoach : FlowRateCoach {
            attribute optimalFlowMin : AirFlowRate;
            attribute optimalFlowMax : AirFlowRate;
            attribute currentFlow : AirFlowRate;
            attribute coachingState : IndicatorState;
        }
        
        part base : BaseUnit {
            attribute isStable = true;
        }
        
        connection airPathway1 connect 
            mouthpiece.tubeConnection to tubing.mouthpieceEnd;
        
        connection airPathway2 connect 
            tubing.chamberEnd to chamber.airInlet;
        
        connection pistonConnection connect 
            chamber.pistonInterface to chamber.flowIndicatorBall;
        
        connection structuralMount connect 
            base.chamberMount to chamber;
        
        perform action therapyExercise : PerformBreathingExercise {
            in targetInhalationVolume = incentiveSpirometerDevice.prescribedTargetVolume;
            in holdDuration = incentiveSpirometerDevice.recommendedHoldTime;
            out achievedVolume : VolumeCapacity;
            out exerciseSuccessful : Boolean;
        }
        
        exhibit state deviceOperation : SpirometerOperationalStates;
    }
    
    requirement def PulmonaryTherapyEffectiveness {
        doc /* The incentive spirometer shall enable patients to perform sustained 
               maximal inspiration exercises to prevent or treat atelectasis and 
               other pulmonary complications. */
        
        require volumeMeasurementRequirement;
        require visualFeedbackRequirement;
        require flowRateGuidanceRequirement;
        require adjustableTargetRequirement;
    }
    
    requirement volumeMeasurementRequirement {
        doc /* The system shall accurately measure and display inhaled air volume 
               in the range of 0 to 4000 mL with resolution of 100 mL. */
        
        subject device : IncentiveSpirometerSystem::incentiveSpirometerDevice;
    }
    
    requirement visualFeedbackRequirement {
        doc /* The system shall provide continuous visual feedback of inhalation 
               progress through a rising indicator ball or piston. */
        
        subject device : IncentiveSpirometerSystem::incentiveSpirometerDevice;
    }
    
    requirement flowRateGuidanceRequirement {
        doc /* The system shall provide visual coaching to guide the patient toward 
               an optimal inhalation flow rate between 100 and 300 mL/s. */
        
        subject device : IncentiveSpirometerSystem::incentiveSpirometerDevice;
    }
    
    requirement adjustableTargetRequirement {
        doc /* The system shall allow healthcare providers to set target inhalation 
               volumes appropriate to individual patient needs. */
        
        subject device : IncentiveSpirometerSystem::incentiveSpirometerDevice;
    }
    
    requirement <'REQ-IS-001'> primaryFunctionRequirement : PulmonaryTherapyEffectiveness {
        doc /* The incentive spirometer system shall assist patients in performing 
               deep breathing exercises by measuring inhaled air volume, providing 
               real-time visual feedback on inhalation depth and flow rate, and 
               encouraging sustained maximal inspiration to promote lung expansion, 
               prevent atelectasis, and reduce postoperative pulmonary complications. */
        
        subject system : IncentiveSpirometerSystem::incentiveSpirometerDevice;
        
        require volumeMeasurementRequirement;
        require visualFeedbackRequirement;
        require flowRateGuidanceRequirement;
        require adjustableTargetRequirement;
    }
}
