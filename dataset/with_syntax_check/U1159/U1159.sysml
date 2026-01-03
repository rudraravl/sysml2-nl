package 'PMID 28738202 Closed Loop Insulin Delivery System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GlucoseConcentration :> Real {
        doc /* Blood glucose concentration measured in mg/dL */
    }
    
    attribute def InsulinDoseRate :> Real {
        doc /* Insulin delivery rate in units per hour */
    }
    
    attribute def BasalRate :> InsulinDoseRate {
        doc /* Baseline insulin delivery rate */
    }
    
    attribute def BolusAmount :> Real {
        doc /* Discrete insulin bolus amount in units */
    }
    
    attribute def SensorAccuracy :> Real {
        doc /* Continuous glucose monitor measurement accuracy percentage */
    }
    
    enum def SystemMode {
        off;
        manual;
        closedLoop;
        suspend;
        alarm;
    }
    
    enum def AlarmType {
        none;
        hyperglycemia;
        hypoglycemia;
        sensorFailure;
        pumpOcclusion;
        lowInsulin;
    }
    
    item def GlucoseReading {
        attribute timestamp :> ISQ::DurationValue;
        attribute value :> GlucoseConcentration;
        attribute trend :> Real;
        attribute quality :> Real;
    }
    
    item def InsulinCommand {
        attribute basalRate :> BasalRate;
        attribute bolusAmount :> BolusAmount;
        attribute timestamp :> ISQ::DurationValue;
    }
    
    item def PatientData {
        attribute weight :> ISQ::MassValue;
        attribute targetGlucose :> GlucoseConcentration;
        attribute insulinSensitivity :> Real;
        attribute carbRatio :> Real;
    }
    
    port def SensorPort {
        out item reading : GlucoseReading;
    }
    
    port def PumpPort {
        in item command : InsulinCommand;
        out attribute status : Boolean;
    }
    
    port def DataPort {
        inout item data : PatientData;
    }
    
    part def ContinuousGlucoseMonitor {
        doc /* Subcutaneous sensor measuring interstitial glucose every 5 minutes */
        
        port glucoseOut : SensorPort;
        
        attribute measurementInterval :> ISQ::DurationValue;
        attribute accuracy :> SensorAccuracy;
        attribute calibrationRequired :> Boolean;
        
        part sensor {
            attribute electrodeVoltage :> ISQ::VoltageValue;
            attribute currentOutput :> ISQ::ElectricCurrentValue;
        }
        
        part transmitter {
            attribute batteryLevel :> Real;
            attribute signalStrength :> Real;
        }
    }
    
    part def InsulinPump {
        doc /* Programmable pump delivering rapid-acting insulin subcutaneously */
        
        port commandIn : PumpPort;
        
        attribute reservoirCapacity :> Real;
        attribute currentReservoir :> Real;
        attribute maxBasalRate :> BasalRate;
        attribute maxBolus :> BolusAmount;
        attribute deliveryIncrement :> Real;
        
        part motor {
            attribute position :> ISQ::LengthValue;
            attribute speed :> ISQ::SpeedValue;
        }
        
        part reservoir {
            attribute volume :> Real;
        }
        
        part infusionSet {
            attribute cannulaLength :> ISQ::LengthValue;
            attribute tubeLength :> ISQ::LengthValue;
        }
    }
    
    part def ControlAlgorithm {
        doc /* Model predictive control algorithm adjusting insulin delivery based on predicted glucose */
        
        port sensorIn : SensorPort;
        port pumpOut : PumpPort;
        port patientDataPort : DataPort;
        
        attribute predictionHorizon :> ISQ::DurationValue;
        attribute controlInterval :> ISQ::DurationValue;
        attribute targetGlucose :> GlucoseConcentration;
        attribute targetRange :> GlucoseConcentration;
        attribute hypoglycemiaThreshold :> GlucoseConcentration;
        attribute hyperglycemiaThreshold :> GlucoseConcentration;
        
        part glucosePredictor {
            attribute modelParameters :> Real[*];
        }
        
        part pidController {
            attribute kp :> Real;
            attribute ki :> Real;
            attribute kd :> Real;
            attribute integralError :> Real;
        }
        
        part safetyConstraints {
            attribute maxInsulinOnBoard :> Real;
            attribute minSuspendDuration :> ISQ::DurationValue;
        }
    }
    
    part def UserInterface {
        doc /* Display and input device for patient interaction and data visualization */
        
        port dataPort : DataPort;
        
        attribute screenSize :> ISQ::LengthValue;
        attribute batteryLife :> ISQ::DurationValue;
        
        part display {
            attribute currentGlucose :> GlucoseConcentration;
            attribute glucoseTrend :> Real;
            attribute activeInsulin :> Real;
        }
        
        part inputButtons {
            attribute bolusButton : Boolean;
            attribute menuButton : Boolean;
        }
    }
    
    action def MeasureGlucose {
        doc /* Acquire glucose measurement from subcutaneous sensor */
        
        out reading : GlucoseReading;
        
        action sampleSensor {
            out rawVoltage :> ISQ::VoltageValue;
        }
        
        then action calibrateReading {
            in voltage : ISQ::VoltageValue;
            out calibratedValue :> GlucoseConcentration;
        }
        
        then action assessQuality {
            in value : GlucoseConcentration;
            out qualityScore :> Real;
        }
    }
    
    action def PredictGlucose {
        doc /* Forecast future glucose trajectory using physiological model */
        
        in currentGlucose : GlucoseConcentration;
        in glucoseHistory : GlucoseReading[*];
        in insulinHistory : InsulinCommand[*];
        in patientParams : PatientData;
        out predictedGlucose : GlucoseConcentration[*];
        
        action buildModel {
            in history : GlucoseReading[*];
            out modelCoefficients :> Real[*];
        }
        
        then action simulateForward {
            in model : Real[*];
            in current : GlucoseConcentration;
            in insulin : InsulinCommand[*];
            out forecast :> GlucoseConcentration[*];
        }
    }
    
    action def ComputeInsulinDose {
        doc /* Calculate optimal insulin delivery using model predictive control */
        
        in currentGlucose : GlucoseConcentration;
        in predictedGlucose : GlucoseConcentration[*];
        in targetGlucose : GlucoseConcentration;
        in patientData : PatientData;
        out insulinCommand : InsulinCommand;
        
        private attribute error :> Real;
        private attribute proposedBasal :> BasalRate;
        
        action calculateError;
        
        then action applyPIDControl {
            in errorValue : Real;
            out basalAdjustment :> BasalRate;
        }
        
        then action applySafetyLimits {
            in proposed : BasalRate;
            out limited :> BasalRate;
        }
        
        then decide;
            if currentGlucose < 70.0 then suspendInsulin;
            if currentGlucose >= 70.0 and currentGlucose <= 180.0 then normalDosing;
            if currentGlucose > 180.0 then increasedDosing;
        
        action suspendInsulin;
        then merge finalizeCommand;
        
        action normalDosing;
        then merge finalizeCommand;
        
        action increasedDosing;
        then merge finalizeCommand;
        
        merge finalizeCommand;
    }
    
    action def DeliverInsulin {
        doc /* Execute insulin infusion via pump motor control */
        
        in command : InsulinCommand;
        
        action validateCommand {
            in cmd : InsulinCommand;
            out isValid : Boolean;
        }
        
        then decide;
            if validateCommand.isValid then activateMotor;
            else rejectCommand;
        
        action activateMotor {
            in rate : BasalRate;
        }
        then done;
        
        action rejectCommand;
        then done;
    }
    
    attribute def PowerOnSignal;
    attribute def EnableClosedLoopSignal;
    attribute def CriticalAlarmSignal;
    attribute def AcknowledgeAlarmSignal;
    
    state def ClosedLoopControlStates {
        doc /* State machine governing automated insulin delivery system operation */
        
        attribute currentMode : SystemMode;
        attribute sensorCalibrated : Boolean;
        attribute pumpPrimed : Boolean;
        attribute glucoseLevel : GlucoseConcentration;
        attribute sensorFailure : Boolean;
        attribute sensorOperational : Boolean;
        
        entry; then systemOff;
        
        state systemOff;
        
        transition off_to_manual
            first systemOff
            accept powerOn : PowerOnSignal
            then manualMode;
        
        state manualMode {
            do action manualBasalDelivery;
        }
        
        transition manual_to_closedLoop
            first manualMode
            accept enableClosedLoop : EnableClosedLoopSignal
            if sensorCalibrated and pumpPrimed
            then closedLoopMode;
        
        state closedLoopMode {
            do action automaticControl {
                action measure : MeasureGlucose {
                    out reading;
                }
                
                action predict : PredictGlucose {
                    in currentGlucose;
                    in glucoseHistory;
                    in insulinHistory;
                    in patientParams;
                    out predictedGlucose;
                }
                
                action compute : ComputeInsulinDose {
                    in currentGlucose;
                    in predictedGlucose;
                    in targetGlucose;
                    in patientData;
                    out insulinCommand;
                }
                
                action deliver : DeliverInsulin {
                    in command;
                }
            }
        }
        
        transition closedLoop_to_suspend
            first closedLoopMode
            if glucoseLevel < 65.0 or sensorFailure
            then suspendMode;
        
        state suspendMode {
            do action haltInsulinDelivery;
        }
        
        transition suspend_to_closedLoop
            first suspendMode
            if glucoseLevel >= 80.0 and sensorOperational
            then closedLoopMode;
        
        transition any_to_alarm
            first closedLoopMode
            accept criticalAlarm : CriticalAlarmSignal
            then alarmState;
        
        state alarmState {
            do action activateAlarm;
            do action notifyUser;
        }
        
        transition alarm_to_manual
            first alarmState
            accept acknowledgeAlarm : AcknowledgeAlarmSignal
            then manualMode;
    }
    
    action def ClosedLoopOperation {
        doc /* Primary system function: automated glucose-responsive insulin delivery */
        
        in patientData : PatientData;
        out systemStatus : SystemMode;
        
        first start;
        
        then action initialize {
            action calibrateSensor;
            then action primePump;
            then action loadPatientProfile {
                in profile : PatientData;
            }
        }
        
        then merge controlCycle;
        
        loop {
            action measureGlucose : MeasureGlucose {
                out reading;
            }
            
            action predictGlucose : PredictGlucose {
                in currentGlucose;
                in glucoseHistory;
                in insulinHistory;
                in patientParams;
                out predictedGlucose;
            }
            
            action computeDose : ComputeInsulinDose {
                in currentGlucose;
                in predictedGlucose;
                in targetGlucose;
                in patientData;
                out insulinCommand;
            }
            
            action deliverInsulin : DeliverInsulin {
                in command;
            }
            
            then action waitInterval;
            
            then action checkContinue {
                out shouldContinue : Boolean;
            }
            
            then decide;
                if checkContinue.shouldContinue then controlCycle;
                else shutdown;
        }
        
        action shutdown {
            action stopInsulin;
            then action saveData;
        }
        
        then done;
    }
    
    part def ArtificialPancreasSystem;
    
    part closedLoopSystem : ArtificialPancreasSystem {
        doc /* Automated insulin delivery system implementing closed-loop glucose control 
                based on PMID 28738202: Artificial Pancreas Systems */
        
        attribute systemId : String;
        attribute firmwareVersion : String;
        
        part cgm : ContinuousGlucoseMonitor;
        
        part pump : InsulinPump;
        
        part controller : ControlAlgorithm;
        
        part ui : UserInterface;
        
        connect cgm.glucoseOut to controller.sensorIn;
        connect controller.pumpOut to pump.commandIn;
        connect controller.patientDataPort to ui.dataPort;
        
        perform action mainOperation : ClosedLoopOperation {
            in patientData;
            out systemStatus;
        }
        
        exhibit state systemBehavior : ClosedLoopControlStates;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The closed-loop insulin delivery system shall automatically regulate blood glucose 
                by continuously measuring glucose levels and adjusting insulin delivery in real-time 
                to maintain target glycemic range, as described in PMID 28738202 */
        
        subject systemUnderTest : ArtificialPancreasSystem;
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall prevent hypoglycemia by suspending insulin delivery when 
                glucose falls below 70 mg/dL or is predicted to fall below threshold */
        
        subject controllerUnderTest : ControlAlgorithm;
    }
    
    requirement def MeasurementRequirement {
        doc /* Continuous glucose monitor shall provide measurements every 5 minutes 
                with minimum 92% accuracy */
        
        subject cgmUnderTest : ContinuousGlucoseMonitor;
    }
    
    requirement def ControlAlgorithmRequirement {
        doc /* Model predictive control algorithm shall predict glucose trajectory 
                60 minutes ahead and adjust insulin delivery every 5 minutes */
        
        subject algorithmUnderTest : ControlAlgorithm;
    }
}
