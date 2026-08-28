package 'Ultrasonic Sensing Unit' {
    private import ScalarValues::*;
    
    attribute def Distance :> Real;
    attribute def TimeDuration :> Real;
    attribute def Temperature :> Real;
    attribute def Speed :> Real;
    
    item def TriggerPulse;
    item def EchoSignal;
    item def TimeoutSignal;
    item def StartMeasurement;
    item def DistanceReport {
        attribute distance : Distance;
        attribute isValid : Boolean;
    }
    
    part def UltrasonicTransducer {
        port pulseTxPort {
            out pulse : TriggerPulse;
        }
        port echoRxPort {
            in echo : EchoSignal;
        }
    }
    
    part def TemperatureCompensator {
        port tempOutPort {
            out temp : Temperature;
            out speed : Speed;
        }
    }
    
    action def EmitPulse;
    action def RecordEchoTime;
    action def ComputeDistance {
        in flightTime : TimeDuration;
        in soundSpeed : Speed;
        out distance : Distance;
    }
    action def ValidateRange {
        in distance : Distance;
        out isValid : Boolean;
    }
    action def ReportDistance {
        in distance : Distance;
        in isValid : Boolean;
    }
    
    state def MeasurementStateMachine {
        entry; then idle;
        state idle;
        transition idle_to_transmitting
            first idle
            accept StartMeasurement
            then transmitting;
        state transmitting;
        transition transmitting_to_listening
            first transmitting
            then listening;
        state listening;
        transition listening_to_computing
            first listening
            accept EchoSignal
            then computing;
        transition listening_to_idle
            first listening
            accept TimeoutSignal
            then idle;
        state computing;
        transition computing_to_validating
            first computing
            then validating;
        state validating;
        transition validating_to_reporting
            first validating
            then reporting;
        transition validating_to_idle
            first validating
            then idle;
        state reporting;
        transition reporting_to_idle
            first reporting
            then idle;
    }
    
    part def SignalProcessor {
        port triggerInPort {
            in startMeasure : StartMeasurement;
        }
        port pulseOutPort {
            out pulse : TriggerPulse;
        }
        port echoInPort {
            in echo : EchoSignal;
        }
        port tempInPort {
            in temp : Temperature;
            in speed : Speed;
        }
        port distanceOutPort {
            out report : DistanceReport;
        }
        
        attribute flightTime : TimeDuration;
        attribute soundSpeed : Speed;
        attribute rawDistance : Distance;
        attribute measurementValid : Boolean;
        
        state measurementState : MeasurementStateMachine;
    }
    
    part def UltrasonicSensingUnit {
        port triggerPort {
            in startMeasure : StartMeasurement;
        }
        port reportPort {
            out report : DistanceReport;
        }
        
        part transducer : UltrasonicTransducer;
        part processor : SignalProcessor;
        part compensator : TemperatureCompensator;
        
        flow startFlow of StartMeasurement
            from triggerPort.startMeasure to processor.triggerInPort.startMeasure;
        flow pulseFlow of TriggerPulse
            from processor.pulseOutPort.pulse to transducer.pulseTxPort.pulse;
        flow echoFlow of EchoSignal
            from transducer.echoRxPort.echo to processor.echoInPort.echo;
        flow tempFlow of Temperature
            from compensator.tempOutPort.temp to processor.tempInPort.temp;
        flow speedFlow of Speed
            from compensator.tempOutPort.speed to processor.tempInPort.speed;
        flow reportFlow of DistanceReport
            from processor.distanceOutPort.report to reportPort.report;
    }
    
    requirement def DistanceMeasurementRequirement {
        doc /* The sensor shall measure distance without physical contact. */
    }
    requirement def TemperatureCompensationRequirement {
        doc /* The sensor shall compensate for air temperature from -20 C to 60 C. */
    }
    requirement def EffectiveRangeRequirement {
        doc /* The sensor shall report distances within 2 cm to 4 m. */
    }
    
    requirement distanceMeasurement : DistanceMeasurementRequirement {
        subject sensor : UltrasonicSensingUnit;
    }
    requirement temperatureCompensation : TemperatureCompensationRequirement {
        subject sensor : UltrasonicSensingUnit;
    }
    requirement effectiveRange : EffectiveRangeRequirement {
        subject sensor : UltrasonicSensingUnit;
    }
    
    part sensingUnit : UltrasonicSensingUnit;
    
    satisfy distanceMeasurement by sensingUnit;
    satisfy temperatureCompensation by sensingUnit;
    satisfy effectiveRange by sensingUnit;
}
