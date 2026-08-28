package 'Wheel Speed Sensing Unit' {
    private import ScalarValues::*;
    
    attribute def AngularVelocity :> Real;
    attribute def AngularAcceleration :> Real;
    attribute def 'Confidence Score' :> Real;
    
    item def 'Raw Signal' {
        attribute frequency : Real;
        attribute amplitude : Real;
    }
    
    item def 'Wheel Data' {
        attribute angularVelocity : AngularVelocity;
        attribute angularAcceleration : AngularAcceleration;
        attribute status : 'Signal Status';
        attribute confidence : 'Confidence Score';
    }
    
    enum def 'Signal Status' {
        operational;
        degraded;
        failed;
    }
    
    part def 'Wheel Hub';
    
    part def 'Tone Ring' {
        attribute teethCount : Integer;
    }
    
    part def 'Magnetic Sensing Element' {
        out port rawSignalOut : 'Raw Signal';
        attribute operatingTempMin : Real = -40;
        attribute operatingTempMax : Real = 125;
        perform action 'generate raw signal' : 'Generate Raw Signal';
    }
    
    part def 'Signal Conditioner' {
        in port rawSignalIn : 'Raw Signal';
        out port wheelDataOut : 'Wheel Data';
        perform action 'process signal' : 'Process Signal';
    }
    
    part def 'ABS Sensor' {
        part magneticSensingElement : 'Magnetic Sensing Element';
        part signalConditioner : 'Signal Conditioner';
        connect magneticSensingElement.rawSignalOut to signalConditioner.rawSignalIn;
        
        out port dataOut : 'Wheel Data';
        connect signalConditioner.wheelDataOut to dataOut;
        
        perform action 'run self test' : 'Run Self Test';
        perform action 'safe shutdown' : 'Safe Shutdown';
        
        exhibit state 'sensor states' : 'Sensor States';
    }
    
    part def 'Vehicle Control System' {
        in port dataIn : 'Wheel Data';
    }
    
    part def 'Wheel Speed Sensing Unit' {
        part wheelHub : 'Wheel Hub';
        part toneRing : 'Tone Ring';
        connect wheelHub to toneRing;
        
        part absSensor : 'ABS Sensor';
        out port dataOut : 'Wheel Data';
        connect absSensor.dataOut to dataOut;
    }
    
    action def 'Generate Raw Signal' {
        out rawSignal : 'Raw Signal';
    }
    
    action def 'Amplify Signal' {
        in input : 'Raw Signal';
        out output : 'Raw Signal';
    }
    
    action def 'Filter Noise' {
        in input : 'Raw Signal';
        out output : 'Raw Signal';
    }
    
    action def 'Calculate Measurements' {
        in input : 'Raw Signal';
        out angularVelocity : AngularVelocity;
        out angularAcceleration : AngularAcceleration;
    }
    
    action def 'Validate Signal' {
        in input : 'Raw Signal';
        out status : 'Signal Status';
        out confidence : 'Confidence Score';
    }
    
    action def 'Process Signal' {
        in rawSignal : 'Raw Signal';
        out wheelData : 'Wheel Data';
        
        action amplify : 'Amplify Signal';
        action filterNoise : 'Filter Noise';
        action calculateMeasurements : 'Calculate Measurements';
        action validateSignal : 'Validate Signal';
        
        flow from rawSignal to amplify.input;
        flow from amplify.output to filterNoise.input;
        flow from filterNoise.output to calculateMeasurements.input;
        flow from filterNoise.output to validateSignal.input;
        flow from calculateMeasurements.angularVelocity to wheelData.angularVelocity;
        flow from calculateMeasurements.angularAcceleration to wheelData.angularAcceleration;
        flow from validateSignal.status to wheelData.status;
        flow from validateSignal.confidence to wheelData.confidence;
    }
    
    action def 'Run Self Test' {
        out passed : Boolean;
    }
    
    action def 'Safe Shutdown';
    
    state def 'Sensor States';
    
    event def 'Power On';
    event def 'Self Test Pass';
    event def 'Self Test Fail';
    event def 'Signal Quality Drop';
    event def 'Signal Restored';
    event def 'Critical Fault';
    event def 'Fault Cleared';
    
    state 'sensor states' : 'Sensor States' {
        entry; then off;
        
        state off {
            accept 'Power On' then selfTest;
        }
        
        state selfTest {
            entry 'run self test';
            accept 'Self Test Pass' then operational;
            accept 'Self Test Fail' then fault;
        }
        
        state operational {
            do 'generate raw signal';
            do 'process signal';
            accept 'Signal Quality Drop' then degraded;
            accept 'Critical Fault' then fault;
        }
        
        state degraded {
            do 'generate raw signal';
            do 'process signal';
            accept 'Signal Restored' then operational;
            accept 'Critical Fault' then fault;
        }
        
        state fault {
            entry 'safe shutdown';
            accept 'Fault Cleared' then off;
        }
    }
    
    part wheelSpeedSensingUnit : 'Wheel Speed Sensing Unit';
    part vehicleControlSystem : 'Vehicle Control System';
    connect wheelSpeedSensingUnit.dataOut to vehicleControlSystem.dataIn;
    
    requirement def 'Measure Wheel Speed' {
        doc /* The wheel speed sensing unit shall accurately measure the rotational speed of the wheel. */
        subject wheelSpeedSensingUnit : 'Wheel Speed Sensing Unit';
        constraint { wheelSpeedSensingUnit.dataOut.angularVelocity >= 0 }
    }
    
    requirement def 'Report Health Status' {
        doc /* The sensing unit shall report its health status as part of the wheel data. */
        subject wheelSpeedSensingUnit : 'Wheel Speed Sensing Unit';
        constraint { wheelSpeedSensingUnit.dataOut.status == 'Signal Status'::operational }
    }
    
    requirement def 'Operate in Temperature Range' {
        doc /* The magnetic sensing element shall operate from -40C to 125C. */
        subject sensor : 'Magnetic Sensing Element';
        constraint { sensor.operatingTempMax <= 125 and sensor.operatingTempMin >= -40 }
    }
}
